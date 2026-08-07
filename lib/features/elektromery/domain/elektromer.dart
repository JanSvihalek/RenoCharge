import 'package:cloud_firestore/cloud_firestore.dart';

import 'pobocka.dart';

/// Elektroměr v areálu – dokument `elektromery/{id}`.
///
/// Zakládá a upravuje ho výhradně údržba; ostatní ho jen vidí.
class Elektromer {
  const Elektromer({
    required this.id,
    required this.pobockaKod,
    required this.cislo,
    required this.nazev,
    this.aktivni = true,
    this.vytvorenoAt,
    this.vytvorilUid,
  });

  final String id;

  /// Kód pobočky. Drží se jako řetězec, ne jako [Pobocka] – kdyby se
  /// pobočka z aplikace odebrala, elektroměry pod ní nesmí zmizet.
  final String pobockaKod;

  /// Výrobní číslo ze štítku.
  final String cislo;

  /// Kde elektroměr je, například „Hala B – rozvaděč R3".
  final String nazev;

  /// Vyřazený elektroměr se z obchůzky ztratí, ale historie odečtů
  /// zůstane čitelná. Proto příznak, ne smazání.
  final bool aktivni;

  final DateTime? vytvorenoAt;
  final String? vytvorilUid;

  Pobocka? get pobocka => Pobocka.zKodu(pobockaKod);

  /// Text, ve kterém se v seznamu hledá – číslo i umístění dohromady.
  /// Při osmdesáti kusech je hledání podmínka použitelnosti.
  String get hledanyText => '$cislo $nazev'.toLowerCase();

  bool odpovidaHledani(String dotaz) {
    final ocisteny = dotaz.trim().toLowerCase();
    if (ocisteny.isEmpty) return true;
    // Mezery v čísle na štítku bývají jinde než v tom, co člověk napíše.
    final bezMezer = hledanyText.replaceAll(' ', '');
    return hledanyText.contains(ocisteny) ||
        bezMezer.contains(ocisteny.replaceAll(' ', ''));
  }

  factory Elektromer.zDokumentu(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Elektromer(
      id: doc.id,
      pobockaKod: data['pobocka_id'] as String? ?? '',
      cislo: data['cislo'] as String? ?? '',
      nazev: data['nazev'] as String? ?? '',
      aktivni: data['aktivni'] as bool? ?? true,
      vytvorenoAt: (data['vytvoreno_at'] as Timestamp?)?.toDate(),
      vytvorilUid: data['vytvoril_uid'] as String?,
    );
  }

  static Map<String, dynamic> mapaProZalozeni({
    required String pobockaKod,
    required String cislo,
    required String nazev,
    required String uid,
  }) => {
    'pobocka_id': pobockaKod,
    'cislo': cislo,
    'nazev': nazev,
    'aktivni': true,
    'vytvoreno_at': FieldValue.serverTimestamp(),
    'vytvoril_uid': uid,
    'aktualizovano_at': FieldValue.serverTimestamp(),
  };

  /// Pobočka se po založení nemění – přestěhovaný elektroměr je jiný
  /// elektroměr a míchaly by se mu odečty přes dva areály.
  static Map<String, dynamic> mapaProUpravu({
    required String cislo,
    required String nazev,
    required bool aktivni,
  }) => {
    'cislo': cislo,
    'nazev': nazev,
    'aktivni': aktivni,
    'aktualizovano_at': FieldValue.serverTimestamp(),
  };

  /// Číslo se porovnává bez mezer a bez ohledu na velikost písmen –
  /// „18 342 771" a „18342771" je tentýž elektroměr.
  static String normalizujCislo(String cislo) =>
      cislo.trim().replaceAll(RegExp(r'\s+'), ' ');

  static String klicCisla(String cislo) =>
      cislo.replaceAll(RegExp(r'\s+'), '').toLowerCase();
}
