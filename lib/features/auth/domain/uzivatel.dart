import 'package:cloud_firestore/cloud_firestore.dart';

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

  bool get maOtevrenouRelaci => aktivniNabijeniId != null;

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
    );
  }
}
