import 'package:cloud_firestore/cloud_firestore.dart';

import '../../elektromery/domain/druh_mista.dart';
import '../../elektromery/domain/elektromer.dart';
import '../../elektromery/domain/odecet.dart';
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

/// Stopa po vytvořeném reportu – nabíjení, nebo odběrných míst.
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
    this.pobockaKod,
    this.druh,
    this.elektromerId,
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

  /// Pobočka reportu odběrných míst. `null` znamená report nabíjení: ty
  /// vznikly dřív a pole nemají.
  final String? pobockaKod;

  /// Druh, na který byl report stavů zúžený; `null` znamená všechna místa.
  final DruhMista? druh;

  /// Místo, kterého se report týká; `null` u přehledu stavů za pobočku.
  final String? elektromerId;

  bool get jeNabijeni => pobockaKod == null;

  /// Spadá okamžik do období a byl dřív, než report vznikl? Co vzniklo až
  /// po něm, v něm není, i když datum sedí – report se dělá třeba v poledne
  /// a odečítat se může ještě odpoledne.
  bool zahrnujeCas(DateTime kdy) =>
      obdobi.obsahuje(kdy) && !kdy.isAfter(vytvorenoAt);

  /// Bylo nabíjení v tomhle reportu?
  ///
  /// Nestačí, že do jeho období spadá. Report zahrnuje jen to, co v době
  /// vytvoření **bylo dokončené**: nabíjení zahájené v poslední den
  /// období a ukončené až po reportu, nebo záznam dopsaný zpětně, v něm
  /// není. Podle samotného data by se na něj tvrdilo „v reportu" a nikdy
  /// by se nevyfakturovalo.
  bool zahrnuje(Relace relace) {
    if (!jeNabijeni || relace.probiha) return false;
    if (!obdobi.obsahuje(relace.zahajeno)) return false;
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
      pobockaKod: data['pobocka_id'] as String?,
      druh: switch (data['druh'] as String?) {
        final klic? => DruhMista.zKlice(klic),
        null => null,
      },
      elektromerId: data['elektromer_id'] as String?,
    );
  }

  static Map<String, dynamic> mapaProZalozeni({
    required String uid,
    required Obdobi obdobi,
    required int pocetZaznamu,
    required bool sFotkami,
    required DateTime vytvorenoAt,
    required Set<FormatExportu> formaty,
    String? pobockaKod,
    DruhMista? druh,
    String? elektromerId,
  }) => {
    'uid': uid,
    'od': Timestamp.fromDate(obdobi.od),
    'do_vcetne': Timestamp.fromDate(obdobi.doVcetne),
    'pocet_zaznamu': pocetZaznamu,
    's_fotkami': sFotkami,
    'vytvoreno_at': Timestamp.fromDate(vytvorenoAt),
    'formaty': [for (final f in formaty) f.klic],
    'pobocka_id': ?pobockaKod,
    'druh': ?druh?.klic,
    'elektromer_id': ?elektromerId,
  };
}

/// Období, které pokryje záznamy, jež ještě žádný report nezahrnul.
///
/// Začíná dnem po konci nejdál sahajícího reportu, ať na něj navazuje.
/// Když je ale nový záznam starší, začíná už jím: nabíjení zahájené
/// v poslední den reportu a ukončené až po něm by jinak nedostal žádný
/// report. Končí se dneškem.
///
/// [nove] nesmí být prázdné.
Obdobi obdobiNovych(
  List<DateTime> nove,
  List<ZaznamExportu> exporty, {
  DateTime? ted,
}) {
  var od = nove.reduce((a, b) => a.isBefore(b) ? a : b);
  for (final e in exporty) {
    final jeNejdal = exporty.every(
      (jiny) => !jiny.obdobi.doVcetne.isAfter(e.obdobi.doVcetne),
    );
    if (jeNejdal && e.navazujeOd.isBefore(od)) od = e.navazujeOd;
  }
  return Obdobi(od: od, doVcetne: ted ?? DateTime.now());
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

  /// `null`, když není nic nového.
  static NabidkaNovych? z(
    List<Relace> historie,
    List<ZaznamExportu> exporty, {
    DateTime? ted,
  }) {
    final nove = noveKExportu(historie, exporty);
    if (nove.isEmpty) return null;

    final obdobi = obdobiNovych(
      [for (final r in nove) r.zahajeno],
      exporty,
      ted: ted,
    );
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

/// Nabídka „jen nové" u odběrných míst.
class NabidkaOdectu {
  const NabidkaOdectu({
    required this.obdobi,
    required this.pocet,
    this.spotreba,
  });

  final Obdobi obdobi;

  /// Kolik toho report najde: u přehledu míst s odečtem, u jednoho místa
  /// odečtů.
  final int pocet;

  /// Spotřeba za období. Jen u jednoho místa – přes místa se nedá sečíst,
  /// kWh a m³ jsou každé jiné.
  final double? spotreba;

  /// Pro přehled stavů. Stačí poslední odečet, který si místa drží u sebe:
  /// místo, kde se od reportu odečítalo, má nový právě ten poslední.
  /// Vyřazená místa se do obchůzky nepočítají.
  static NabidkaOdectu? zMist(
    List<Elektromer> mista,
    List<ZaznamExportu> exporty, {
    DateTime? ted,
  }) {
    final casy = [
      for (final m in mista)
        if (m.aktivni) ?m.posledniOdecet?.odectenoAt,
    ];
    final nove = [
      for (final kdy in casy)
        if (!exporty.any((e) => e.zahrnujeCas(kdy))) kdy,
    ];
    if (nove.isEmpty) return null;

    final obdobi = obdobiNovych(nove, exporty, ted: ted);
    return NabidkaOdectu(
      obdobi: obdobi,
      pocet: casy.where(obdobi.obsahuje).length,
    );
  }

  /// Pro jedno místo, z jeho historie odečtů.
  static NabidkaOdectu? zOdectu(
    List<OdecetSeSpotrebou> odecty,
    List<ZaznamExportu> exporty, {
    DateTime? ted,
  }) {
    final nove = [
      for (final o in odecty)
        if (!exporty.any((e) => e.zahrnujeCas(o.odecet.odectenoAt)))
          o.odecet.odectenoAt,
    ];
    if (nove.isEmpty) return null;

    final obdobi = obdobiNovych(nove, exporty, ted: ted);
    final vObdobi = odecty.where((o) => obdobi.obsahuje(o.odecet.odectenoAt));
    return NabidkaOdectu(
      obdobi: obdobi,
      pocet: vObdobi.length,
      spotreba: vObdobi.fold<double>(
        0,
        (soucet, o) => soucet + (o.spotreba ?? 0),
      ),
    );
  }
}
