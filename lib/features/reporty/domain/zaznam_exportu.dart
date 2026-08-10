import 'package:cloud_firestore/cloud_firestore.dart';

import 'report.dart';

/// Stopa po vytvořeném PDF reportu nabíjení.
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
    );
  }

  static Map<String, dynamic> mapaProZalozeni({
    required String uid,
    required Obdobi obdobi,
    required int pocetZaznamu,
    required bool sFotkami,
    required DateTime vytvorenoAt,
  }) => {
    'uid': uid,
    'od': Timestamp.fromDate(obdobi.od),
    'do_vcetne': Timestamp.fromDate(obdobi.doVcetne),
    'pocet_zaznamu': pocetZaznamu,
    's_fotkami': sFotkami,
    'vytvoreno_at': Timestamp.fromDate(vytvorenoAt),
  };
}
