import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../common/chyby.dart';
import '../../../common/formatovani.dart';
import '../../auth/application/auth_providery.dart';
import '../../nabijeni/application/nabijeni_providery.dart';
import '../../nabijeni/domain/relace.dart';
import '../../vozidla/application/vozidla_providery.dart';
import '../domain/report.dart';
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

      state = const ReportPripraven();
      return polozky.length;
    } catch (chyba) {
      state = ReportChyba(AppChyba.zFirebase(chyba));
      return null;
    }
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

  /// `report-nabijeni-jan-svihalek-2026-07-01-2026-07-31.pdf`
  static String nazevSouboru(String jmeno, Obdobi obdobi) {
    final kdo = bezDiakritiky(
      jmeno,
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    String den(DateTime d) =>
        '${d.year}-${_dvojciferne(d.month)}-${_dvojciferne(d.day)}';
    return 'report-nabijeni-$kdo-${den(obdobi.od)}-'
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
