import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../../navigace/hlavni_shell.dart';
import '../../../navigace/toky.dart';
import '../../vozidla/application/vozidla_providery.dart';
import '../application/nabijeni_providery.dart';
import '../application/zahajeni_controller.dart';
import '../domain/relace.dart';
import 'foceni_obrazovka.dart';

/// Výběr vozidla. Stanice ani konektor se nezadávají – nabíječky v areálu
/// zatím nejsou nijak označené, viz README.
class ZahajeniObrazovka extends ConsumerWidget {
  const ZahajeniObrazovka({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final otevrena = ref.watch(otevrenaRelaceProvider).value;

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HlavickaToku(
              titulek: 'Zahájení nabíjení',
              onZpet: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: otevrena != null
                  ? _RozdelaneNabijeni(relace: otevrena)
                  : const _Vyber(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Otevřená relace může být jen jedna – místo výběru proto nabídneme
/// dokončení té rozdělané.
class _RozdelaneNabijeni extends StatelessWidget {
  const _RozdelaneNabijeni({required this.relace});

  final Relace relace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Rozmery.okrajStranky),
      child: Column(
        children: [
          const SizedBox(height: 20),
          ChybovyBlok(
            zprava:
                'Máte rozdělané nabíjení. Nejdřív ho prosím ukončete, '
                'teprve pak můžete zahájit další.',
          ),
          const Spacer(),
          PrimarniTlacitko(
            popisek: 'Ukončit probíhající nabíjení',
            onTap: () {
              // Navigátor si podržíme, protože po popu už tenhle
              // context k ničemu není.
              final nav = Navigator.of(context);
              nav.pop();
              otevriUkonceniPres(nav, relace);
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Vyber extends ConsumerWidget {
  const _Vyber();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stav = ref.watch(zahajeniControllerProvider);
    final rizeni = ref.read(zahajeniControllerProvider.notifier);
    final vozidla = ref.watch(vozidlaProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Rozmery.okrajStranky,
              0,
              Rozmery.okrajStranky,
              24,
            ),
            children: [
              const NadpisSekce('Vozidlo'),
              switch (vozidla) {
                AsyncError() => ChybovyBlok(
                  zprava: 'Vozidla se nepodařilo načíst.',
                  onZkusitZnovu: () => ref.invalidate(vozidlaProvider),
                ),
                AsyncData(:final value) when value.isEmpty => _ZadneVozidlo(),
                AsyncData(:final value) => Column(
                  children: [
                    for (final v in value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: VolbaKarta(
                          vybrano: v.id == stav.vozidloId,
                          onTap: () => rizeni.vyberVozidlo(v.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                v.spz,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              if (v.znackaModel != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  v.znackaModel!,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                _ => const _Nacita(),
              },
              if (stav.chyba != null) ...[
                const SizedBox(height: 18),
                ChybovyBlok(zprava: stav.chyba!.zprava),
              ],
            ],
          ),
        ),
        _Pata(
          povoleno: stav.jeKompletni,
          odesilani: stav.odesilani,
          onPokracovat: () => _naFotografii(context, ref),
        ),
      ],
    );
  }

  Future<void> _naFotografii(BuildContext context, WidgetRef ref) async {
    final vysledek = await Navigator.of(context).push<VysledekFoceni>(
      MaterialPageRoute(
        builder: (_) => const FoceniObrazovka(rezim: RezimFoceni.zahajeni),
        fullscreenDialog: true,
      ),
    );
    if (vysledek == null || !context.mounted) return;

    final povedlo = await ref
        .read(zahajeniControllerProvider.notifier)
        .zahaj(kwhStart: vysledek.hodnota, foto: vysledek.foto);
    if (!context.mounted) return;

    if (povedlo) {
      Navigator.of(context).pop();
      ukazInfo(context, 'Nabíjení bylo zahájeno.');
    }
    // Chyba zůstává ve stavu a vykreslí se nad patou obrazovky.
  }
}

class _ZadneVozidlo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const PrazdnyStav(
          text: 'Nemáte přidané žádné vozidlo.',
          ikona: Icons.directions_car_outlined,
        ),
        PrimarniTlacitko(
          popisek: 'Přidat vozidlo',
          ikona: Icons.add,
          vyska: Rozmery.dotykMin,
          onTap: () {
            ref.read(zalozkaProvider.notifier).prepni(Zalozka.vozidla);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _Nacita extends StatelessWidget {
  const _Nacita();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// Fixní pata s hlavní akcí – primární akce patří do dolní třetiny.
class _Pata extends StatelessWidget {
  const _Pata({
    required this.povoleno,
    required this.odesilani,
    required this.onPokracovat,
  });

  final bool povoleno;
  final bool odesilani;
  final VoidCallback onPokracovat;

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
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        child: PrimarniTlacitko(
          popisek: 'Pokračovat na fotografii',
          nacita: odesilani,
          onTap: povoleno ? onPokracovat : null,
        ),
      ),
    );
  }
}
