import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/motiv/barvy.dart';
import '../features/nabijeni/presentation/domovska_obrazovka.dart';
import '../features/nabijeni/presentation/historie_obrazovka.dart';
import '../features/nastaveni/presentation/nastaveni_obrazovka.dart';

/// Vozidla mají vlastní sekci v nastavení, ne vlastní záložku – jinak by
/// totéž bylo v aplikaci na dvou místech.
enum Zalozka { domu, historie, nastaveni }

/// Vybraná záložka. Je v provideru, aby na ni mohly sáhnout i obrazovky
/// (např. prázdný stav, který posílá uživatele přidat si vozidlo).
class ZalozkaController extends Notifier<Zalozka> {
  @override
  Zalozka build() => Zalozka.domu;

  void prepni(Zalozka zalozka) => state = zalozka;
}

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
    final zalozka = ref.watch(zalozkaProvider);

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: zalozka.index,
          children: const [
            DomovskaObrazovka(),
            HistorieObrazovka(),
            NastaveniObrazovka(),
          ],
        ),
      ),
      bottomNavigationBar: _TabBar(
        aktivni: zalozka,
        onZmena: (z) => ref.read(zalozkaProvider.notifier).prepni(z),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.aktivni, required this.onZmena});

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
              _Tab(
                ikona: Icons.home_outlined,
                popisek: 'Domů',
                aktivni: aktivni == Zalozka.domu,
                onTap: () => onZmena(Zalozka.domu),
              ),
              _Tab(
                ikona: Icons.access_time,
                popisek: 'Historie',
                aktivni: aktivni == Zalozka.historie,
                onTap: () => onZmena(Zalozka.historie),
              ),
              _Tab(
                ikona: Icons.settings_outlined,
                popisek: 'Nastavení',
                aktivni: aktivni == Zalozka.nastaveni,
                onTap: () => onZmena(Zalozka.nastaveni),
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
