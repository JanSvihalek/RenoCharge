import 'elektromer.dart';

/// Poslední obchůzka pobočky – odečty, které patří k sobě.
///
/// Místa se odečítají jednou měsíčně naráz, ale ne nutně uvnitř
/// kalendářního měsíce: obchůzka může běžet od 28. do 3. Kdyby se „hotovo"
/// počítalo podle měsíce, prvního by se všechno vrátilo do „zbývá",
/// i co se odečetlo včera. Obchůzka se proto odvozuje z odečtů samotných:
/// je to nejnovější odečet na pobočce a všechno, co se odečetlo
/// v [okno] před ním.
///
/// Neukládá se a nic se nezakládá – stejně jako dřív „zbývá / hotovo"
/// se dopočítá z `posledni_odecet` a nemůže se rozejít se skutečností.
class Obchuzka {
  const Obchuzka._({required this.od, required this.hranice});

  /// Jak daleko před nejnovějším odečtem ještě sahá stejná obchůzka.
  ///
  /// Dvacet dní, ne týden: odečet navíc mezi obchůzkami (třeba po výměně
  /// měřidla) by s krátkým oknem vypadal jako začátek nové obchůzky
  /// „1 z 76". Dvacet dní ho k předchozí obchůzce přibalí, a přitom při
  /// měsíčním rytmu spolehlivě oddělí jednu obchůzku od další.
  static const okno = Duration(days: 20);

  /// Kdy obchůzka začala – první odečet, který do ní patří. Tohle se
  /// ukazuje uživateli.
  final DateTime od;

  /// Odečty od tohoto okamžiku patří do obchůzky.
  final DateTime hranice;

  /// Má místo odečet z téhle obchůzky?
  bool zahrnuje(Elektromer misto) {
    final kdy = misto.posledniOdecet?.odectenoAt;
    return kdy != null && !kdy.isBefore(hranice);
  }

  /// Poslední obchůzka podle odečtů zadaných míst, nebo `null`, když
  /// se na nich ještě nikdy neodečítalo.
  ///
  /// Vyřazená místa se nepočítají – jejich poslední odečet je starý
  /// a s obchůzkou nemá co dělat.
  static Obchuzka? posledni(Iterable<Elektromer> mista) {
    final casy = [
      for (final m in mista)
        if (m.aktivni) ?m.posledniOdecet?.odectenoAt,
    ];
    if (casy.isEmpty) return null;

    final nejnovejsi = casy.reduce((a, b) => a.isAfter(b) ? a : b);
    final hranice = nejnovejsi.subtract(okno);
    final od = casy
        .where((kdy) => !kdy.isBefore(hranice))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return Obchuzka._(od: od, hranice: hranice);
  }
}
