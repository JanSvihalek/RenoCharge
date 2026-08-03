/// Rozměrové tokeny. Vychází z návrhových principů: uživatel je venku,
/// v rukavicích, ve spěchu a ovládá aplikaci jednou rukou.
abstract final class Rozmery {
  /// Absolutní minimum dotykové plochy.
  static const double dotykMin = 56;

  /// Primární akce (CTA) v dolní třetině obrazovky.
  static const double tlacitkoPrimarni = 60;
  static const double tlacitkoVelke = 64;
  static const double tlacitkoIkona = 44;
  static const double spoustZaverky = 76;

  static const double radiusKarty = 20;
  static const double radiusPolozky = 14;
  static const double radiusTlacitka = 16;
  static const double radiusMale = 12;

  static const double okrajStranky = 20;
  static const double mezeraMala = 8;
  static const double mezeraStredni = 12;
  static const double mezeraVelka = 20;

  /// Výška řádku v seznamech (relace, vozidla).
  static const double vyskaRadku = 64;

  /// Grid stanic: 3 sloupce, mezera 8 px, položka min. 56 px.
  static const int sloupcuStanic = 3;
  static const double mezeraStanic = 8;
}
