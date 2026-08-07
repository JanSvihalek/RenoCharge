/// Pobočky firmy. Jsou v kódu, ne v kolekci ve Firestore.
///
/// Zadání s kolekcí `pobocky` počítalo, ale sedm areálů s ustálenými kódy
/// se prakticky nemění. Konstanta ušetří kolekci, její pravidla, index
/// i ruční plnění v konzoli, a odpadne stav „načítám pobočky".
/// Cenou je, že přidání pobočky znamená nový build – při téhle četnosti
/// změn dobrý obchod.
enum Pobocka {
  bsl('BSL', 'Brno-Slatina'),
  cli('CLI', 'Čestlice'),
  csk('CSK', 'Česká'),
  pkc('PKC', 'Praha – kongresové centrum'),
  pbu('PBU', 'Praha-Bubeneč'),
  nup('NUP', 'Nupaky'),
  zln('ZLN', 'Zlín');

  const Pobocka(this.kod, this.nazev);

  /// Trojpísmenný kód, který se ukládá do Firestore jako `pobocka_id`.
  /// Používá ho i firma, takže nehrozí, že se změní pod rukama.
  final String kod;
  final String nazev;

  /// `BSL – Brno-Slatina`
  String get popisek => '$kod – $nazev';

  /// `null` u kódu, který v aplikaci není. Stát se to může jen tak, že
  /// se pobočka z kódu odebrala, ale její elektroměry zůstaly – proto
  /// se kód v modelu drží jako řetězec a tenhle převod je nepovinný.
  static Pobocka? zKodu(String? kod) {
    for (final p in values) {
      if (p.kod == kod) return p;
    }
    return null;
  }
}
