/// Co se na odběrném místě měří. Určuje jednotku odečtu a skupinu
/// v seznamu.
///
/// Evidence začínala jen elektroměry, proto dokumenty bez pole `druh`
/// jsou elektřina – viz [zKlice].
enum DruhMista {
  elektrina('elektrina', 'Elektřina', 'kWh'),
  plyn('plyn', 'Plyn', 'm³'),

  /// Elektroměr na klimatizační jednotce – měří se elektřina, ale firma
  /// ji vede jako samostatnou skupinu.
  klimatizace('klimatizace', 'Klimatizace', 'kWh'),
  nabijecka('nabijecka', 'Nabíječky', 'kWh');

  const DruhMista(this.klic, this.nazev, this.jednotka);

  /// Hodnota pole `druh` ve Firestore.
  final String klic;

  /// Název skupiny v seznamu a na štítku.
  final String nazev;
  final String jednotka;

  /// Chybějící i neznámý klíč je elektřina: dokumenty z doby před druhy
  /// pole nemají a neznámá hodnota nesmí místo ze seznamu vyhodit.
  static DruhMista zKlice(String? klic) {
    for (final d in values) {
      if (d.klic == klic) return d;
    }
    return elektrina;
  }
}
