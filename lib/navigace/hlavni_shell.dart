import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/motiv/barvy.dart';
import '../features/nabijeni/presentation/domovska_obrazovka.dart';
import '../features/auth/application/auth_providery.dart';
import '../features/auth/domain/uzivatel.dart';
import '../features/elektromery/presentation/elektromery_obrazovka.dart';
import '../features/nastaveni/presentation/nastaveni_obrazovka.dart';

/// Vozidla mají vlastní sekci v nastavení, ne vlastní záložku – jinak by
/// totéž bylo v aplikaci na dvou místech.
///
/// `elektromery` vidí jen role `udrzba`. Záložky se proto neberou
/// z tohohle výčtu napřímo, ale ze [zalozkyProRoli].
enum Zalozka { nabijeni, elektromery, nastaveni }

/// Které záložky se dané roli ukážou, v pořadí zleva doprava.
///
/// Každá záložka je **jedna evidence**, ne pohled na ni. Historie
/// nabíjení proto vlastní záložku nemá – bydlí pod tlačítkem v Nabíjení,
/// stejně jako odečty bydlí v detailu svého elektroměru. Samostatná
/// „Historie" vedle Elektroměrů neříkala, čeho.
List<Zalozka> zalozkyProRoli(Role role) => [
  Zalozka.nabijeni,
  if (role.spravujeElektromery) Zalozka.elektromery,
  Zalozka.nastaveni,
];

/// Vybraná záložka. Je v provideru, aby na ni mohly sáhnout i obrazovky
/// (např. prázdný stav, který posílá uživatele přidat si vozidlo).
class ZalozkaController extends Notifier<Zalozka> {
  @override
  Zalozka build() => Zalozka.nabijeni;

  void prepni(Zalozka zalozka) => state = zalozka;
}

/// Obsah záložky. Oddělené od [Zalozka], aby shell nemusel skládat
/// `IndexedStack` s pevným pořadím – to by se s podmíněnou záložkou
/// rozešlo a uživatel by po přihlášení viděl cizí obrazovku.
Widget obrazovkaZalozky(Zalozka zalozka) => switch (zalozka) {
  Zalozka.nabijeni => const DomovskaObrazovka(),
  Zalozka.elektromery => const ElektromeryObrazovka(),
  Zalozka.nastaveni => const NastaveniObrazovka(),
};

({IconData ikona, String popisek}) popisZalozky(
  Zalozka zalozka,
) => switch (zalozka) {
  Zalozka.nabijeni => (ikona: Icons.ev_station_outlined, popisek: 'Nabíjení'),
  Zalozka.elektromery => (
    ikona: Icons.electric_meter_outlined,
    popisek: 'Elektroměry',
  ),
  Zalozka.nastaveni => (ikona: Icons.settings_outlined, popisek: 'Nastavení'),
};

final zalozkaProvider = NotifierProvider<ZalozkaController, Zalozka>(
  ZalozkaController.new,
);

/// Rámec se spodním tab barem. Toky (zahájení, focení, rekapitulace,
/// detail) se otevírají nad ním, tab bar v nich vidět není.
class HlavniShell extends ConsumerWidget {
  const HlavniShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final zalozky = zalozkyProRoli(ref.watch(roleProvider));
    var zalozka = ref.watch(zalozkaProvider);

    // Role dorazí z Firestore až po prvním vykreslení. Kdyby uživatel
    // mezitím stál na záložce, kterou po načtení vidět nemá, spadne
    // zpátky na nabíjení – jinak by `indexOf` vrátilo -1.
    if (!zalozky.contains(zalozka)) zalozka = Zalozka.nabijeni;

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: zalozky.indexOf(zalozka),
          children: [for (final z in zalozky) obrazovkaZalozky(z)],
        ),
      ),
      bottomNavigationBar: _TabBar(
        zalozky: zalozky,
        aktivni: zalozka,
        onZmena: (z) => ref.read(zalozkaProvider.notifier).prepni(z),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.zalozky,
    required this.aktivni,
    required this.onZmena,
  });

  final List<Zalozka> zalozky;
  final Zalozka aktivni;
  final ValueChanged<Zalozka> onZmena;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Container(
      decoration: BoxDecoration(
        color: b.surface,
        border: Border(top: BorderSide(color: b.border)),
      ),
      child: SafeArea(
        top: false,
        // Odsazení kvůli indikátoru domovské obrazovky telefonu.
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              for (final z in zalozky)
                _Tab(
                  ikona: popisZalozky(z).ikona,
                  popisek: popisZalozky(z).popisek,
                  aktivni: aktivni == z,
                  onTap: () => onZmena(z),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.ikona,
    required this.popisek,
    required this.aktivni,
    required this.onTap,
  });

  final IconData ikona;
  final String popisek;
  final bool aktivni;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final barva = aktivni ? b.accent : b.textFaint;
    return Expanded(
      child: Semantics(
        button: true,
        selected: aktivni,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(ikona, size: 24, color: barva),
                const SizedBox(height: 4),
                Text(
                  popisek,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: barva,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
