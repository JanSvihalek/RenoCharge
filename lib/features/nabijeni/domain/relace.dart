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
class Relace {
  const Relace({
    required this.id,
    required this.uid,
    required this.spz,
    required this.vozidloId,
    required this.staniceId,
    required this.konektor,
    required this.kwhStart,
    required this.zahajeno,
    required this.fotoStart,
    required this.stav,
    this.kwhEnd,
    this.ukonceno,
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
  final String staniceId;

  /// `A` nebo `B`.
  final String konektor;
  final double kwhStart;
  final double? kwhEnd;
  final DateTime zahajeno;
  final DateTime? ukonceno;
  final FotoMetadata fotoStart;
  final FotoMetadata? fotoEnd;
  final StavRelace stav;
  final DateTime? vytvorenoAt;
  final DateTime? aktualizovanoAt;

  bool get probiha => stav == StavRelace.probiha;

  /// Spotřeba v kWh, dokud relace běží, tak `null`.
  double? get spotreba => kwhEnd == null ? null : kwhEnd! - kwhStart;

  /// Doba nabíjení – u běžící relace čas od zahájení do teď.
  Duration doba({DateTime? ted}) =>
      (ukonceno ?? ted ?? DateTime.now()).difference(zahajeno);

  factory Relace.zDokumentu(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final fotoStart = FotoMetadata.zMapy(data['foto_start']);
    return Relace(
      id: doc.id,
      uid: data['uid'] as String? ?? '',
      spz: data['spz'] as String? ?? '',
      vozidloId: data['vozidlo_id'] as String? ?? '',
      staniceId: data['stanice_id'] as String? ?? '',
      konektor: data['konektor'] as String? ?? '',
      kwhStart: (data['kwh_start'] as num?)?.toDouble() ?? 0,
      kwhEnd: (data['kwh_end'] as num?)?.toDouble(),
      zahajeno:
          (data['zahajeno'] as Timestamp?)?.toDate() ??
          (data['vytvoreno_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      ukonceno: (data['ukonceno'] as Timestamp?)?.toDate(),
      fotoStart:
          fotoStart ??
          FotoMetadata(path: '', sha256: '', porizenoAt: DateTime.now()),
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
    required String staniceId,
    required String konektor,
    required double kwhStart,
    required DateTime zahajeno,
    required FotoMetadata fotoStart,
  }) => {
    'uid': uid,
    'spz': spz,
    'vozidlo_id': vozidloId,
    'stanice_id': staniceId,
    'konektor': konektor,
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
}
