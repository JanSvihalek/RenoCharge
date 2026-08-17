import 'package:cloud_firestore/cloud_firestore.dart';

/// Co uživatel v aplikaci smí.
///
/// Roli **nastavuje výhradně správce v konzoli**; uživatel si ji sám
/// změnit nemůže, hlídají to `firestore.rules`.
///
/// Chybějící i neznámá hodnota znamená [uzivatel] – nová role v datech
/// tak nikdy nedá práva, o kterých aplikace neví.
enum Role {
  uzivatel('user', 'Uživatel'),
  udrzba('udrzba', 'Údržba'),
  admin('admin', 'Správce');

  const Role(this.klic, this.popisek);

  /// Hodnota v poli `role` ve Firestore.
  final String klic;
  final String popisek;

  /// Kdo smí do části s elektroměry. Ptát se takhle, a ne na konkrétní
  /// roli, je schválně – přidání další role pak znamená úpravu na jednom
  /// místě, ne hledání všech porovnání v aplikaci.
  bool get spravujeElektromery => this == udrzba || this == admin;

  /// Správce vidí všechno, co vidí ostatní role.
  bool get videVse => this == admin;

  static Role zKlice(String? klic) => switch (klic) {
    'udrzba' => udrzba,
    'admin' => admin,
    _ => uzivatel,
  };
}

/// Profil uživatele – dokument `uzivatele/{uid}`.
class Uzivatel {
  const Uzivatel({
    required this.uid,
    required this.jmeno,
    required this.email,
    this.osobniCislo,
    this.vytvorenoAt,
    this.onboardingAt,
    this.aktivniNabijeniId,
    this.cenaZaKwh,
    this.zalohovatFotky = false,
    this.role = Role.uzivatel,
  });

  final String uid;
  final String jmeno;
  final String email;

  /// Osobní firemní číslo zaměstnance. Slouží k párování při fakturaci
  /// mimo aplikaci, sama s ním nepracuje.
  final String? osobniCislo;
  final DateTime? vytvorenoAt;

  /// Kdy uživatel dokončil úvodní nastavení. Dokud je `null`, aplikace
  /// ho pustí jen na onboarding.
  final DateTime? onboardingAt;

  /// ID otevřené relace. Drží se přímo na profilu, aby se dalo transakcí
  /// vynutit pravidlo „jeden uživatel = nejvýš jedna otevřená relace“.
  /// Prázdné, pokud uživatel právě nenabíjí.
  final String? aktivniNabijeniId;

  /// Předpokládaná cena za kWh, kterou si uživatel zadal v nastavení.
  ///
  /// Slouží **výhradně k orientačnímu přepočtu** zobrazenému v aplikaci.
  /// Fakturuje se mimo aplikaci a možná jinou sazbou, proto se spočítaná
  /// částka nikam neukládá – dopočítává se z aktuálního nastavení a do
  /// PDF reportu se nedostane. `null`, dokud si sazbu nikdo nezadal;
  /// v tom případě aplikace o penězích nemluví vůbec.
  final double? cenaZaKwh;

  /// Ukládat kopie vyfocených počítadel i do galerie telefonu.
  ///
  /// Záloha pro uživatele, ne pro aplikaci – ta si fotky drží ve Storage
  /// a z galerie je nikdy nečte. Výchozí je vypnuto: cizí snímky
  /// v galerii jsou nezvyklé a člověk o ně má požádat sám.
  final bool zalohovatFotky;

  final Role role;

  bool get spravujeElektromery => role.spravujeElektromery;

  bool get maOtevrenouRelaci => aktivniNabijeniId != null;

  bool get maZadanouCenu => cenaZaKwh != null && cenaZaKwh! > 0;

  /// Orientační částka za daný odběr, nebo `null`, když sazba není
  /// zadaná nebo relace ještě neskončila.
  double? castkaZa(double? spotrebaKwh) {
    if (!maZadanouCenu || spotrebaKwh == null) return null;
    return spotrebaKwh * cenaZaKwh!;
  }

  bool get maHotovyOnboarding => onboardingAt != null;

  /// Křestní jméno pro pozdrav na domovské obrazovce.
  String get krestniJmeno {
    final ocistene = jmeno.trim();
    if (ocistene.isEmpty) return 'kolego';
    return ocistene.split(RegExp(r'\s+')).first;
  }

  factory Uzivatel.zDokumentu(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Uzivatel(
      uid: doc.id,
      jmeno: data['jmeno'] as String? ?? '',
      email: data['email'] as String? ?? '',
      osobniCislo: data['osobni_cislo'] as String?,
      vytvorenoAt: (data['vytvoreno_at'] as Timestamp?)?.toDate(),
      onboardingAt: (data['onboarding_at'] as Timestamp?)?.toDate(),
      aktivniNabijeniId: data['aktivni_nabijeni_id'] as String?,
      cenaZaKwh: (data['cena_za_kwh'] as num?)?.toDouble(),
      zalohovatFotky: data['zalohovat_fotky'] as bool? ?? false,
      role: Role.zKlice(data['role'] as String?),
    );
  }
}
