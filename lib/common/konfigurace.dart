/// Nastavení, která se ladí podle prostředí, ne podle kódu obrazovek.
abstract final class Konfigurace {
  /// Region Firebase projektu. Firestore i Storage musí být založené
  /// v `europe-west3` – klient region nenastavuje, řídí se tím, jak byl
  /// projekt vytvořen. Konstanta je tu jako doklad záměru a pro kontrolu
  /// při nasazení.
  static const String region = 'europe-west3';

  /// ID tenanta Microsoft Entra ID (Azure AD).
  ///
  /// Ve fázi 1 se nepoužívá – přihlašuje se e-mailem a heslem. Až se
  /// zapne přihlášení firemním účtem, vyplňte sem ID firemního tenanta,
  /// aby se do aplikace nedostaly cizí účty. `null` znamená společný
  /// endpoint `organizations`, tedy jakoukoli organizaci.
  static const String? microsoftTenantId = null;

  /// Fotografie: shodné s limitem v storage.rules.
  static const int maxVelikostFotoBajtu = 5 * 1024 * 1024;
  static const double maxSirkaFoto = 1600;
  static const int kvalitaFoto = 80;

  /// Kolik posledních relací se ukazuje na domovské obrazovce.
  static const int poslednichRelaciNaDomovske = 5;

  /// Strop pro načtení historie – fáze 1 stránkování neřeší.
  static const int limitHistorie = 100;
}
