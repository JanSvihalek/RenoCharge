import 'package:cloud_firestore/cloud_firestore.dart';

import '../../nabijeni/domain/relace.dart';
import 'report.dart';

/// Co report nabíjení obsahuje. Jde vybrat i obojí najednou.
enum FormatExportu {
  pdf('pdf', 'PDF'),
  xlsx('xlsx', 'Excel');

  const FormatExportu(this.klic, this.popisek);

  final String klic;
  final String popisek;

  /// `PDF + Excel` – pořadí podle výčtu, ať nezáleží na pořadí výběru.
  static String popisVyberu(Set<FormatExportu> formaty) => [
    for (final f in values)
      if (formaty.contains(f)) f.popisek,
  ].join(' + ');
}

/// Stopa po vytvořeném reportu nabíjení.
///
/// Existuje kvůli jediné otázce, kterou si člověk klade měsíc po měsíci:
/// **od kdy dělat příští report**. Bez záznamu se to dá zjistit jen
/// z odeslané pošty, a to už je pozdě.
///
/// Zaznamenává se **vytvoření**, ne odeslání. Co uživatel udělá se
/// systémovým sdílením – jestli soubor pošle mailem, uloží, nebo zavře –
/// se aplikace nedozví, takže by tvrdit odeslání bylo lhaní.
class ZaznamExportu {
  const ZaznamExportu({
    required this.id,
    required this.uid,
    required this.obdobi,
    required this.pocetZaznamu,
    required this.sFotkami,
    required this.vytvorenoAt,
    this.formaty = const {},
  });

  final String id;
  final String uid;

  /// Období, které report pokryl.
  final Obdobi obdobi;

  /// Kolik nabíjení se do reportu dostalo. Nula je platný výsledek –
  /// prázdné období není chyba a stejně se z něj report vytvoří.
  final int pocetZaznamu;

  final bool sFotkami;
  final DateTime vytvorenoAt;

  /// Co report obsahoval. Prázdné u reportů z doby, kdy se to neukládalo.
  final Set<FormatExportu> formaty;

  /// Bylo nabíjení v tomhle reportu?
  ///
  /// Nestačí, že do jeho období spadá. Report zahrnuje jen to, co v době
  /// vytvoření **bylo dokončené**: nabíjení zahájené v poslední den
  /// období a ukončené až po reportu, nebo záznam dopsaný zpětně, v něm
  /// není. Podle samotného data by se na něj tvrdilo „v reportu" a nikdy
  /// by se nevyfakturovalo.
  bool zahrnuje(Relace relace) {
    if (relace.probiha || !obdobi.obsahuje(relace.zahajeno)) return false;
    final zapsano =
        relace.aktualizovanoAt ?? relace.ukonceno ?? relace.zahajeno;
    return !zapsano.isAfter(vytvorenoAt);
  }

  /// Spotřeba nabíjení z tohoto reportu. Neukládá se, stejně jako částka,
  /// která se z ní počítá podle aktuální sazby. Bere se z **načtené**
  /// historie, takže u starých reportů nad její limit může být nižší.
  double spotrebaZ(List<Relace> historie) => historie
      .where(zahrnuje)
      .fold(0, (soucet, r) => soucet + (r.spotreba ?? 0));

  /// První den, který ještě žádný report nepokryl. Přesně tohle je ta
  /// odpověď, kvůli které se záznam vede.
  DateTime get navazujeOd => Obdobi.nasledujiciDen(obdobi.doVcetne);

  factory ZaznamExportu.zDokumentu(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return ZaznamExportu(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      obdobi: Obdobi(
        od: (data['od'] as Timestamp).toDate(),
        doVcetne: (data['do_vcetne'] as Timestamp).toDate(),
      ),
      pocetZaznamu: (data['pocet_zaznamu'] as num?)?.toInt() ?? 0,
      sFotkami: data['s_fotkami'] as bool? ?? false,
      vytvorenoAt: (data['vytvoreno_at'] as Timestamp).toDate(),
      formaty: {
        for (final f in FormatExportu.values)
          if ((data['formaty'] as List<dynamic>?)?.contains(f.klic) ?? false) f,
      },
    );
  }

  static Map<String, dynamic> mapaProZalozeni({
    required String uid,
    required Obdobi obdobi,
    required int pocetZaznamu,
    required bool sFotkami,
    required DateTime vytvorenoAt,
    required Set<FormatExportu> formaty,
  }) => {
    'uid': uid,
    'od': Timestamp.fromDate(obdobi.od),
    'do_vcetne': Timestamp.fromDate(obdobi.doVcetne),
    'pocet_zaznamu': pocetZaznamu,
    's_fotkami': sFotkami,
    'vytvoreno_at': Timestamp.fromDate(vytvorenoAt),
    'formaty': [for (final f in formaty) f.klic],
  };
}

/// Dokončená nabíjení, která ještě žádný report nezahrnul. Běžící ne –
/// do reportu jít nemůžou – a schválená taky ne, ta už jsou vyřízená.
List<Relace> noveKExportu(
  List<Relace> historie,
  List<ZaznamExportu> exporty,
) => [
  for (final r in historie)
    if (r.stav == StavRelace.dokonceno && !exporty.any((e) => e.zahrnuje(r))) r,
];

/// Nabídka „jen nové" v exportu: období a co v něm report najde.
class NabidkaNovych {
  const NabidkaNovych({
    required this.obdobi,
    required this.pocet,
    required this.celkemKwh,
  });

  final Obdobi obdobi;

  /// Kolik dokončených nabíjení do období spadá – to je to, co report
  /// bude obsahovat.
  final int pocet;
  final double celkemKwh;

  /// Období začíná dnem po konci posledního reportu, ať na něj navazuje.
  /// Když je ale nové nabíjení starší, začíná už jím: nabíjení zahájené
  /// v poslední den reportu a ukončené až po něm by jinak nedostal
  /// žádný report. Končí se dneškem.
  ///
  /// `null`, když není nic nového.
  static NabidkaNovych? z(
    List<Relace> historie,
    List<ZaznamExportu> exporty, {
    DateTime? ted,
  }) {
    final nove = noveKExportu(historie, exporty);
    if (nove.isEmpty) return null;

    var od = nove
        .map((r) => r.zahajeno)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    for (final e in exporty) {
      final jeNejdal = exporty.every(
        (jiny) => !jiny.obdobi.doVcetne.isAfter(e.obdobi.doVcetne),
      );
      if (jeNejdal && e.navazujeOd.isBefore(od)) od = e.navazujeOd;
    }

    final obdobi = Obdobi(od: od, doVcetne: ted ?? DateTime.now());
    final vObdobi = [
      for (final r in historie)
        if (!r.probiha && obdobi.obsahuje(r.zahajeno)) r,
    ];
    return NabidkaNovych(
      obdobi: obdobi,
      pocet: vObdobi.length,
      celkemKwh: vObdobi.fold(0, (soucet, r) => soucet + (r.spotreba ?? 0)),
    );
  }
}
