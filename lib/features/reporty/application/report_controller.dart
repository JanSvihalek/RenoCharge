import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../common/chyby.dart';
import '../../../common/formatovani.dart';
import '../../auth/application/auth_providery.dart';
import '../../elektromery/application/odecty_controller.dart';
import '../../elektromery/domain/elektromer.dart';
import '../../elektromery/domain/odecet.dart';
import '../../nabijeni/application/nabijeni_providery.dart';
import '../../nabijeni/domain/relace.dart';
import '../../vozidla/application/vozidla_providery.dart';
import '../domain/report.dart';
import 'exporty_providery.dart';
import 'report_pdf.dart';
import 'zmenseni_fotky.dart';

/// Průběh vytváření reportu. Stahování fotek je jediná pomalá část,
/// proto se počítají zvlášť – uživatel u dvaceti snímků potřebuje vidět,
/// že se něco děje.
sealed class StavReportu {
  const StavReportu();
}

class ReportPripraven extends StavReportu {
  const ReportPripraven();
}

class ReportNacitaZaznamy extends StavReportu {
  const ReportNacitaZaznamy();
}

class ReportStahujeFotky extends StavReportu {
  const ReportStahujeFotky({required this.hotovo, required this.celkem});

  final int hotovo;
  final int celkem;

  double get podil => celkem == 0 ? 0 : hotovo / celkem;
}

class ReportSestavuje extends StavReportu {
  const ReportSestavuje();
}

class ReportChyba extends StavReportu {
  const ReportChyba(this.chyba);

  final AppChyba chyba;
}

/// Vytvoření PDF reportu a jeho předání do systémového sdílení.
class ReportController extends Notifier<StavReportu> {
  @override
  StavReportu build() => const ReportPripraven();

  bool get probiha => state is! ReportPripraven && state is! ReportChyba;

  void vymazChybu() {
    if (state is ReportChyba) state = const ReportPripraven();
  }

  /// Vrací počet nabíjení v reportu, nebo `null` při chybě. Prázdné
  /// období není chyba – report se vytvoří a řekne, že nic nenašel.
  Future<int?> vytvorASdilej({
    required Obdobi obdobi,
    required bool sFotkami,
  }) async {
    if (probiha) return null;

    final uid = ref.read(uidProvider);
    final profil = ref.read(profilProvider).value;
    if (uid == null || profil == null) {
      state = const ReportChyba(NeniPrihlasen());
      return null;
    }

    try {
      state = const ReportNacitaZaznamy();
      final relace = await ref
          .read(nabijeniRepositoryProvider)
          .nactiZaObdobi(uid: uid, od: obdobi.od, doKonce: obdobi.doExkluzivne);

      final polozky = await _slozPolozky(relace, sFotkami: sFotkami);

      state = const ReportSestavuje();
      final bajty = await (await ReportPdf.nacti()).sestav(
        PodkladReportu(
          jmeno: profil.jmeno,
          osobniCislo: profil.osobniCislo,
          obdobi: obdobi,
          polozky: polozky,
          vytvorenoAt: DateTime.now(),
        ),
      );

      await Printing.sharePdf(
        bytes: bajty,
        filename: nazevSouboru(profil.jmeno, obdobi),
        subject:
            'Nabíjení ${Format.datum(obdobi.od)} – '
            '${Format.datum(obdobi.doVcetne)}',
      );

      _zapisStopu(
        uid: uid,
        obdobi: obdobi,
        pocet: polozky.length,
        sFotkami: sFotkami,
      );

      state = const ReportPripraven();
      return polozky.length;
    } catch (chyba) {
      state = ReportChyba(AppChyba.zFirebase(chyba));
      return null;
    }
  }

  /// Poznamená do historie, že report za tohle období vznikl.
  ///
  /// Nečeká se na dokončení schválně. Firestore zapíše do místní
  /// mezipaměti hned a posluchač historie se ozve, ale bez signálu
  /// nedokončí zápis, dokud nedosáhne na server – čekáním by se export
  /// bez internetu zasekl na hotovém PDF.
  ///
  /// Neúspěch se sem taky nedostane: report už je vytvořený a předaný
  /// ke sdílení, chybová hláška po dokončené práci by jen mátla.
  void _zapisStopu({
    required String uid,
    required Obdobi obdobi,
    required int pocet,
    required bool sFotkami,
  }) {
    unawaited(
      ref
          .read(exportyRepositoryProvider)
          .zapis(
            uid: uid,
            obdobi: obdobi,
            pocetZaznamu: pocet,
            sFotkami: sFotkami,
          )
          .catchError((Object _) {}),
    );
  }

  Future<List<PolozkaReportu>> _slozPolozky(
    List<Relace> relace, {
    required bool sFotkami,
  }) async {
    // Značka se bere z aktuálního profilu, SPZ z relace – historie tak
    // zůstane čitelná i po smazání vozidla.
    final vozidla = ref.read(vozidlaProvider).value ?? const [];
    String popis(Relace r) {
      for (final v in vozidla) {
        if (v.id == r.vozidloId && v.znackaModel != null) {
          return '${v.znackaModel} · ${r.spz}';
        }
      }
      return r.spz;
    }

    if (!sFotkami) {
      return [
        for (final r in relace) PolozkaReportu(relace: r, vozidlo: popis(r)),
      ];
    }

    final uloziste = ref.read(fotoUlozisteProvider);
    final celkem = relace.length * 2;
    var hotovo = 0;
    state = ReportStahujeFotky(hotovo: hotovo, celkem: celkem);

    Future<Uint8List?> stahni(String? cesta) async {
      final bajty = cesta == null ? null : await uloziste.stahni(cesta);
      hotovo++;
      state = ReportStahujeFotky(hotovo: hotovo, celkem: celkem);
      // Zmenšení běží v jiné izolaci, ať se UI nezasekne.
      return bajty == null ? null : compute(zmensiProPdf, bajty);
    }

    final polozky = <PolozkaReportu>[];
    for (final r in relace) {
      // Sekvenčně schválně: dvacet paralelních stahování zahltí spojení
      // a ukazatel průběhu by skákal.
      final start = await stahni(r.fotoStart.path);
      final konec = await stahni(r.fotoEnd?.path);
      polozky.add(
        PolozkaReportu(
          relace: r,
          vozidlo: popis(r),
          fotoStart: start,
          fotoEnd: konec,
        ),
      );
    }
    return polozky;
  }

  /// Report jednoho elektroměru. Sdílí stav i průběh s reportem
  /// nabíjení – pro uživatele je to tatáž operace, jen nad jinými daty.
  Future<int?> vytvorProElektromer({
    required Elektromer elektromer,
    required Obdobi obdobi,
    required bool sFotkami,
  }) async {
    if (probiha) return null;

    try {
      state = const ReportNacitaZaznamy();
      final odecty = await ref
          .read(odectyRepositoryProvider)
          .nactiZaObdobi(
            elektromerId: elektromer.id,
            od: obdobi.od,
            doKonce: obdobi.doExkluzivne,
          );

      final fotky = sFotkami
          ? await _stahniFotky(odecty)
          : const <String, Uint8List>{};

      state = const ReportSestavuje();
      final bajty = await (await ReportPdf.nacti()).sestavElektromer(
        PodkladElektromeru(
          elektromer: elektromer,
          obdobi: obdobi,
          polozky: slozPolozkyOdectu(odecty, fotky: fotky),
          vytvorenoAt: DateTime.now(),
        ),
      );

      await Printing.sharePdf(
        bytes: bajty,
        filename: nazevSouboru(
          'elektromer ${elektromer.cislo}',
          obdobi,
          predpona: 'report-elektromer',
        ),
        subject:
            'Elektroměr ${elektromer.cislo} · '
            '${Format.datum(obdobi.od)} – ${Format.datum(obdobi.doVcetne)}',
      );

      state = const ReportPripraven();
      return odecty.length;
    } catch (chyba) {
      state = ReportChyba(AppChyba.zFirebase(chyba));
      return null;
    }
  }

  Future<Map<String, Uint8List>> _stahniFotky(List<Odecet> odecty) async {
    final uloziste = ref.read(fotoUlozisteProvider);
    final fotky = <String, Uint8List>{};
    var hotovo = 0;
    state = ReportStahujeFotky(hotovo: hotovo, celkem: odecty.length);

    for (final o in odecty) {
      if (o.foto.path.isNotEmpty) {
        final bajty = await uloziste.stahni(o.foto.path);
        if (bajty != null) fotky[o.id] = await compute(zmensiProPdf, bajty);
      }
      hotovo++;
      state = ReportStahujeFotky(hotovo: hotovo, celkem: odecty.length);
    }
    return fotky;
  }

  /// QR štítky k vytištění na samolepky – celá pobočka, nebo jediný
  /// elektroměr, když se štítek poškodí nebo přibude kus do evidence.
  ///
  /// [popis] jde do názvu souboru i do předmětu mailu, aby se dalo poznat,
  /// co je uvnitř, ještě než se PDF otevře.
  ///
  /// Vrací počet vysázených štítků, nebo `null` při chybě.
  Future<int?> vytvorStitky({
    required String popis,
    required List<Elektromer> elektromery,
  }) async {
    if (probiha) return null;
    if (elektromery.isEmpty) return 0;

    try {
      state = const ReportSestavuje();
      final bajty = await (await ReportPdf.nacti()).sestavStitky(elektromery);

      final jeden = elektromery.length == 1;

      await Printing.sharePdf(
        bytes: bajty,
        filename: nazevStitku(popis, jeden: jeden),
        subject: jeden
            ? 'QR štítek elektroměru · $popis'
            : 'QR štítky elektroměrů · $popis',
      );

      state = const ReportPripraven();
      return elektromery.length;
    } catch (chyba) {
      state = ReportChyba(AppChyba.zFirebase(chyba));
      return null;
    }
  }

  /// `qr-stitek-elektromer-18-342-771.pdf`, pro pobočku `qr-stitky-bsl.pdf`.
  static String nazevStitku(String popis, {required bool jeden}) {
    final nazev = bezDiakritiky(
      popis,
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return '${jeden ? 'qr-stitek' : 'qr-stitky'}-$nazev.pdf';
  }

  /// `report-nabijeni-jan-svihalek-2026-07-01-2026-07-31.pdf`
  static String nazevSouboru(
    String jmeno,
    Obdobi obdobi, {
    String predpona = 'report-nabijeni',
  }) {
    final kdo = bezDiakritiky(
      jmeno,
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    String den(DateTime d) =>
        '${d.year}-${_dvojciferne(d.month)}-${_dvojciferne(d.day)}';
    return '$predpona-$kdo-${den(obdobi.od)}-'
        '${den(obdobi.doVcetne)}.pdf';
  }

  static String _dvojciferne(int c) => c.toString().padLeft(2, '0');

  /// Název souboru putuje mailem a přes cizí systémy, takže z něj radši
  /// diakritiku odstraníme.
  static String bezDiakritiky(String text) {
    const s = 'áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ';
    const bez = 'acdeeinorstuuyzACDEEINORSTUUYZ';
    final buffer = StringBuffer();
    for (final znak in text.split('')) {
      final i = s.indexOf(znak);
      buffer.write(i >= 0 ? bez[i] : znak);
    }
    return buffer.toString();
  }
}

final reportControllerProvider =
    NotifierProvider<ReportController, StavReportu>(ReportController.new);
