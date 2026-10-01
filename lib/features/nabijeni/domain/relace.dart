import 'package:cloud_firestore/cloud_firestore.dart';

import 'foto_metadata.dart';

/// Stav relace. Schvalování ani fakturace v aplikaci neprobíhá – stav
/// `schvaleno` může doplnit budoucí webový portál, aplikace ho umí jen
/// zobrazit.
enum StavRelace {
  probiha('probiha', 'PROBÍHÁ'),
  dokonceno('dokonceno', 'DOKONČENO'),
  schvaleno('schvaleno', 'SCHVÁLENO');

  const StavRelace(this.klic, this.popisek);

  final String klic;
  final String popisek;

  static StavRelace zKlice(String? klic) => switch (klic) {
    'probiha' => StavRelace.probiha,
    'schvaleno' => StavRelace.schvaleno,
    _ => StavRelace.dokonceno,
  };
}

/// Jedna nabíjecí relace – dokument `nabijeni/{id}`.
///
/// Relace je **jeden dokument** po celou dobu svého života: vzniká při
/// zahájení se stavem `probiha` a při ukončení se doplní koncové hodnoty.
/// Nikdy nevznikají dva samostatné záznamy.
///
/// Výjimkou je nabíjení na nabíječce **bez počítadla**, která ukazuje
/// jen energii nabitou za jedno nabíjení. Tam není co odečítat na začátku,
/// takže záznam vzniká až po nabití, rovnou dokončený: nese [kwhNabito]
/// a fotku displeje ve [fotoEnd], počáteční ani koncový stav nemá.
class Relace {
  const Relace({
    required this.id,
    required this.uid,
    required this.spz,
    required this.vozidloId,
    required this.zahajeno,
    required this.stav,
    this.kwhStart,
    this.kwhEnd,
    this.kwhNabito,
    this.ukonceno,
    this.fotoStart,
    this.fotoEnd,
    this.vytvorenoAt,
    this.aktualizovanoAt,
  });

  final String id;
  final String uid;

  /// Kopie textu SPZ v době zahájení – ne odkaz. Historie tak zůstane
  /// čitelná i po smazání vozidla z profilu.
  final String spz;
  final String vozidloId;

  /// Stav počítadla na začátku. `null` jen u nabíječky bez počítadla –
  /// běžící relace ho má vždycky.
  final double? kwhStart;
  final double? kwhEnd;

  /// Energie přečtená přímo z displeje nabíječky bez počítadla.
  final double? kwhNabito;
  final DateTime zahajeno;
  final DateTime? ukonceno;
  final FotoMetadata? fotoStart;
  final FotoMetadata? fotoEnd;
  final StavRelace stav;
  final DateTime? vytvorenoAt;
  final DateTime? aktualizovanoAt;

  bool get probiha => stav == StavRelace.probiha;

  /// Záznam z nabíječky bez počítadla – zadaný přímo nabitou energií.
  bool get bezPocitadla => kwhNabito != null;

  /// Spotřeba v kWh, dokud relace běží, tak `null`.
  double? get spotreba {
    if (kwhNabito case final nabito?) return nabito;
    final (start, konec) = (kwhStart, kwhEnd);
    return start == null || konec == null ? null : konec - start;
  }

  /// Doba nabíjení – u běžící relace čas od zahájení do teď.
  Duration doba({DateTime? ted}) =>
      (ukonceno ?? ted ?? DateTime.now()).difference(zahajeno);

  factory Relace.zDokumentu(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Relace(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      spz: data['spz'] as String? ?? '',
      vozidloId: data['vozidlo_id'] as String? ?? '',
      kwhStart: (data['kwh_start'] as num?)?.toDouble(),
      kwhEnd: (data['kwh_end'] as num?)?.toDouble(),
      kwhNabito: (data['kwh_nabito'] as num?)?.toDouble(),
      zahajeno:
          (data['zahajeno'] as Timestamp?)?.toDate() ??
          (data['vytvoreno_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      ukonceno: (data['ukonceno'] as Timestamp?)?.toDate(),
      fotoStart: FotoMetadata.zMapy(data['foto_start']),
      fotoEnd: FotoMetadata.zMapy(data['foto_end']),
      stav: StavRelace.zKlice(data['stav'] as String?),
      vytvorenoAt: (data['vytvoreno_at'] as Timestamp?)?.toDate(),
      aktualizovanoAt: (data['aktualizovano_at'] as Timestamp?)?.toDate(),
    );
  }

  /// Podklad pro založení relace. Stav je vždy `probiha` – jinak zápis
  /// neprojde security rules.
  static Map<String, dynamic> mapaProZalozeni({
    required String uid,
    required String spz,
    required String vozidloId,
    required double kwhStart,
    required DateTime zahajeno,
    required FotoMetadata fotoStart,
  }) => {
    'uid': uid,
    'spz': spz,
    'vozidlo_id': vozidloId,
    'kwh_start': kwhStart,
    'kwh_end': null,
    'zahajeno': Timestamp.fromDate(zahajeno),
    'ukonceno': null,
    'foto_start': fotoStart.naMapu(),
    'foto_end': null,
    'stav': StavRelace.probiha.klic,
    'vytvoreno_at': FieldValue.serverTimestamp(),
    'aktualizovano_at': FieldValue.serverTimestamp(),
  };

  /// Podklad pro ukončení relace. Doplňuje jen koncové hodnoty –
  /// `kwh_start` ani `uid` se nikdy nepřepisují.
  static Map<String, dynamic> mapaProUkonceni({
    required double kwhEnd,
    required DateTime ukonceno,
    required FotoMetadata fotoEnd,
  }) => {
    'kwh_end': kwhEnd,
    'ukonceno': Timestamp.fromDate(ukonceno),
    'foto_end': fotoEnd.naMapu(),
    'stav': StavRelace.dokonceno.klic,
    'aktualizovano_at': FieldValue.serverTimestamp(),
  };

  /// Podklad pro záznam z nabíječky bez počítadla. Vzniká rovnou
  /// dokončený – nemá začátek, který by se dal odečíst, jen výsledek.
  /// Zahájení i ukončení je čas fotky displeje; skutečnou dobu nabíjení
  /// aplikace nezná a netvrdí ji.
  static Map<String, dynamic> mapaProPrimyZapis({
    required String uid,
    required String spz,
    required String vozidloId,
    required double kwhNabito,
    required FotoMetadata foto,
  }) {
    final kdy = Timestamp.fromDate(foto.porizenoAt);
    return {
      'uid': uid,
      'spz': spz,
      'vozidlo_id': vozidloId,
      'kwh_start': null,
      'kwh_end': null,
      'kwh_nabito': kwhNabito,
      'zahajeno': kdy,
      'ukonceno': kdy,
      'foto_start': null,
      'foto_end': foto.naMapu(),
      'stav': StavRelace.dokonceno.klic,
      'vytvoreno_at': FieldValue.serverTimestamp(),
      'aktualizovano_at': FieldValue.serverTimestamp(),
    };
  }
}
