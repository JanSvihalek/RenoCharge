import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../common/chyby.dart';
import '../../../common/formatovani.dart';
import '../../auth/application/auth_providery.dart';
import '../../elektromery/application/odecty_controller.dart';
import '../../elektromery/domain/druh_mista.dart';
import '../../elektromery/domain/elektromer.dart';
import '../../elektromery/domain/odecet.dart';
import '../../elektromery/domain/pobocka.dart';
import '../../nabijeni/application/nabijeni_providery.dart';
import '../../nabijeni/domain/relace.dart';
import '../../vozidla/application/vozidla_providery.dart';
import '../domain/report.dart';
import '../domain/zaznam_exportu.dart';
import 'exporty_providery.dart';
import 'report_pdf.dart';
import 'report_xlsx.dart';
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

/// Vytvoření reportů a jejich předání do systémového sdílení.
class ReportController extends Notifier<StavReportu> {
  @override
  StavReportu build() => const ReportPripraven();

  bool get probiha => state is! ReportPripraven && state is! ReportChyba;

  void vymazChybu() {
    if (state is ReportChyba) state = const ReportPripraven();
  }

  /// Vytvoří report nabíjení v zadaných formátech a předá ho systémovému
  /// sdílení – oba soubory najednou, ať se dají poslat v jednom mailu.
  ///
  /// Vrací počet nabíjení v reportu, nebo `null` při chybě. Prázdné
  /// období není chyba – report se vytvoří a řekne, že nic nenašel.
  Future<int?> vytvorNabijeni({
    required Obdobi obdobi,
    required Set<FormatExportu> formaty,
    required bool sFotkami,
  }) async {
    final pocet = await _sestavASdilej(
      obdobi: obdobi,
      formaty: formaty,
      sFotkami: sFotkami,
    );
    final uid = ref.read(uidProvider);
    if (pocet != null && uid != null) {
      _zapisStopu(
        uid: uid,
        obdobi: obdobi,
        pocet: pocet,
        sFotkami: sFotkami,
        formaty: formaty,
      );
    }
    return pocet;
  }

  /// Znovu vyrobí a nasdílí report z historie.
  ///
  /// Hotové soubory se nikam neukládají, takže se skládají z aktuálních
  /// dat. Dokončené záznamy se nemění, ale nabíjení do období dopsané
  /// později v novém souboru bude. Nová stopa nevzniká: je to tentýž
  /// report a v historii by jinak byl dvakrát.
  ///
  /// U reportů z doby, kdy se formát neukládal, se vytvoří PDF.
  Future<int?> sdilejZnovu(ZaznamExportu export) => _sestavASdilej(
    obdobi: export.obdobi,
    formaty: export.formaty.isEmpty
        ? const {FormatExportu.pdf}
        : export.formaty,
    sFotkami: export.sFotkami,
  );

  Future<int?> _sestavASdilej({
    required Obdobi obdobi,
    required Set<FormatExportu> formaty,
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

      final pdf = formaty.contains(FormatExportu.pdf);
      // Fotky jsou jen v PDF, kvůli samotné tabulce se nestahují.
      final polozky = await _slozPolozky(relace, sFotkami: pdf && sFotkami);

      state = const ReportSestavuje();
      final podklad = PodkladReportu(
        jmeno: profil.jmeno,
        osobniCislo: profil.osobniCislo,
        obdobi: obdobi,
        polozky: polozky,
        vytvorenoAt: DateTime.now(),
      );

      await _sdilej(
        soubory: [
          if (pdf)
            ('pdf', _mimePdf, await (await ReportPdf.nacti()).sestav(podklad)),
          if (formaty.contains(FormatExportu.xlsx))
            ('xlsx', _mimeXlsx, ReportXlsx.sestav(podklad)),
        ],
        nazev: (pripona) =>
            nazevSouboru(profil.jmeno, obdobi, pripona: pripona),
        predmet:
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

  /// Uloží soubory do dočasné složky a předá je systémovému sdílení jedním
  /// sdílením, ať se dají poslat v jednom mailu.
  ///
  /// Přes share_plus, ne přes Printing.sharePdf: ten umí jen jeden soubor
  /// a na Androidu má natvrdo typ application/pdf.
  Future<void> _sdilej({
    required List<(String pripona, String mime, List<int> bajty)> soubory,
    required String Function(String pripona) nazev,
    required String predmet,
  }) async {
    final slozka = (await getTemporaryDirectory()).path;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final (pripona, mime, bajty) in soubory)
            await () async {
              final soubor = File('$slozka/${nazev(pripona)}');
              await soubor.writeAsBytes(bajty, flush: true);
              return XFile(soubor.path, mimeType: mime);
            }(),
        ],
        subject: predmet,
      ),
    );
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
    required Set<FormatExportu> formaty,
    String? pobockaKod,
    DruhMista? druh,
    String? elektromerId,
  }) {
    unawaited(
      ref
          .read(exportyRepositoryProvider)
          .zapis(
            uid: uid,
            obdobi: obdobi,
            pocetZaznamu: pocet,
            sFotkami: sFotkami,
            formaty: formaty,
            pobockaKod: pobockaKod,
            druh: druh,
            elektromerId: elektromerId,
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
      final start = await stahni(r.fotoStart?.path);
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

  /// Přehled stavů odběrných míst – jeden řádek na místo, s minulým
  /// a novým stavem, spotřebou a změnou.
  ///
  /// [mista] jsou ta, která uživatel zrovna vidí v seznamu (pobočka
  /// a případně druh). Vrací počet míst, která mají v období odečet,
  /// nebo `null` při chybě. S [zapsatStopu] `false` je to opakované sdílení
  /// reportu, který už v historii je.
  Future<int?> vytvorStavy({
    required Pobocka pobocka,
    required DruhMista? druh,
    required List<Elektromer> mista,
    required Obdobi obdobi,
    required Set<FormatExportu> formaty,
    bool zapsatStopu = true,
  }) async {
    if (probiha) return null;

    try {
      state = const ReportNacitaZaznamy();
      final repo = ref.read(odectyRepositoryProvider);

      // Odečty v období jedním dotazem za celou pobočku. Minulé stavy
      // ale musí jít po místech: „poslední odečet před obdobím" je
      // u každého místa jindy a dotaz na pobočku by musel stáhnout celou
      // historii. Dotazy na místa běží souběžně, každý vrátí dva záznamy.
      final idcka = {for (final m in mista) m.id};
      final vObdobi = <String, List<Odecet>>{};
      for (final o in await repo.nactiPobockuZaObdobi(
        pobockaKod: pobocka.kod,
        od: obdobi.od,
        doKonce: obdobi.doExkluzivne,
      )) {
        if (idcka.contains(o.elektromerId)) {
          vObdobi.putIfAbsent(o.elektromerId, () => []).add(o);
        }
      }
      final predObdobim = {
        for (final (id, odecty) in await Future.wait([
          for (final m in mista)
            repo
                .nactiPred(elektromerId: m.id, pred: obdobi.od)
                .then((odecty) => (m.id, odecty)),
        ]))
          id: odecty,
      };

      state = const ReportSestavuje();
      final podklad = PodkladStavu(
        pobocka: pobocka,
        druh: druh,
        obdobi: obdobi,
        radky: slozPrehledStavu(
          mista: mista,
          predObdobim: predObdobim,
          vObdobi: vObdobi,
        ),
        vytvorenoAt: DateTime.now(),
      );
      final popis = druh == null ? pobocka.kod : '${pobocka.kod} ${druh.nazev}';
      await _sdilej(
        soubory: [
          if (formaty.contains(FormatExportu.pdf))
            (
              'pdf',
              _mimePdf,
              await (await ReportPdf.nacti()).sestavStavy(podklad),
            ),
          if (formaty.contains(FormatExportu.xlsx))
            ('xlsx', _mimeXlsx, ReportXlsx.sestavStavy(podklad)),
        ],
        nazev: (pripona) =>
            nazevSouboru(popis, obdobi, predpona: 'stavy', pripona: pripona),
        predmet:
            'Stavy odběrných míst · $popis · '
            '${Format.datum(obdobi.od)} – ${Format.datum(obdobi.doVcetne)}',
      );

      final uid = ref.read(uidProvider);
      if (zapsatStopu && uid != null) {
        _zapisStopu(
          uid: uid,
          obdobi: obdobi,
          pocet: vObdobi.length,
          sFotkami: false,
          formaty: formaty,
          pobockaKod: pobocka.kod,
          druh: druh,
        );
      }

      state = const ReportPripraven();
      return vObdobi.length;
    } catch (chyba) {
      state = ReportChyba(AppChyba.zFirebase(chyba));
      return null;
    }
  }

  static const _mimePdf = 'application/pdf';
  static const _mimeXlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Odečty jednoho odběrného místa. Sdílí stav i průběh s reportem
  /// nabíjení – pro uživatele je to tatáž operace, jen nad jinými daty.
  ///
  /// Fotky se do PDF přikládají, kde jsou: nové odečty je nemají, starší
  /// z doby, kdy se fotilo, ano. S [zapsatStopu] `false` je to opakované
  /// sdílení reportu, který už v historii je.
  Future<int?> vytvorProElektromer({
    required Elektromer elektromer,
    required Obdobi obdobi,
    required Set<FormatExportu> formaty,
    bool zapsatStopu = true,
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

      final pdf = formaty.contains(FormatExportu.pdf);
      final fotky = pdf
          ? await _stahniFotky(odecty)
          : const <String, Uint8List>{};

      state = const ReportSestavuje();
      final podklad = PodkladElektromeru(
        elektromer: elektromer,
        obdobi: obdobi,
        polozky: slozPolozkyOdectu(odecty, fotky: fotky),
        vytvorenoAt: DateTime.now(),
      );

      await _sdilej(
        soubory: [
          if (pdf)
            (
              'pdf',
              _mimePdf,
              await (await ReportPdf.nacti()).sestavElektromer(podklad),
            ),
          if (formaty.contains(FormatExportu.xlsx))
            ('xlsx', _mimeXlsx, ReportXlsx.sestavOdecty(podklad)),
        ],
        nazev: (pripona) => nazevSouboru(
          '${elektromer.druh.nazev} ${elektromer.nazev}',
          obdobi,
          predpona: 'report-misto',
          pripona: pripona,
        ),
        predmet:
            '${elektromer.druh.nazev} · ${elektromer.nazev} · '
            '${Format.datum(obdobi.od)} – ${Format.datum(obdobi.doVcetne)}',
      );

      final uid = ref.read(uidProvider);
      if (zapsatStopu && uid != null) {
        _zapisStopu(
          uid: uid,
          obdobi: obdobi,
          pocet: odecty.length,
          sFotkami: false,
          formaty: formaty,
          pobockaKod: elektromer.pobockaKod,
          elektromerId: elektromer.id,
        );
      }

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
      if (o.foto?.path case final cesta? when cesta.isNotEmpty) {
        final bajty = await uloziste.stahni(cesta);
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
    int preskocit = 0,
  }) async {
    if (probiha) return null;
    if (elektromery.isEmpty) return 0;

    try {
      state = const ReportSestavuje();
      final bajty = await (await ReportPdf.nacti()).sestavStitky(
        elektromery,
        preskocit: preskocit,
      );

      final jeden = elektromery.length == 1;

      await Printing.sharePdf(
        bytes: bajty,
        filename: nazevStitku(popis, jeden: jeden),
        subject: jeden
            ? 'QR štítek odběrného místa · $popis'
            : 'QR štítky odběrných míst · $popis',
      );

      state = const ReportPripraven();
      return elektromery.length;
    } catch (chyba) {
      state = ReportChyba(AppChyba.zFirebase(chyba));
      return null;
    }
  }

  /// `qr-stitek-plyn-kotelna.pdf`, pro pobočku `qr-stitky-bsl.pdf`.
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
    String pripona = 'pdf',
  }) {
    final kdo = bezDiakritiky(
      jmeno,
    ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    String den(DateTime d) =>
        '${d.year}-${_dvojciferne(d.month)}-${_dvojciferne(d.day)}';
    return '$predpona-$kdo-${den(obdobi.od)}-'
        '${den(obdobi.doVcetne)}.$pripona';
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
