import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../application/elektromery_providery.dart';
import '../domain/elektromer.dart';
import '../domain/pobocka.dart';
import 'formular_elektromeru.dart';

/// Detail elektroměru. Zatím jen údaje a úprava – historie odečtů
/// přibude s dalším krokem.
class ElektromerObrazovka extends ConsumerWidget {
  const ElektromerObrazovka({super.key, required this.elektromerId});

  final String elektromerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final elektromer = ref.watch(elektromerProvider(elektromerId));

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HlavickaToku(
              titulek: 'Detail elektroměru',
              onZpet: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: switch (elektromer) {
                AsyncError() => Padding(
                  padding: const EdgeInsets.all(Rozmery.okrajStranky),
                  child: ChybovyBlok(
                    zprava: 'Detail se nepodařilo načíst.',
                    onZkusitZnovu: () =>
                        ref.invalidate(elektromerProvider(elektromerId)),
                  ),
                ),
                AsyncData(:final value) when value == null => const PrazdnyStav(
                  text: 'Elektroměr se nepodařilo najít.',
                ),
                AsyncData(:final value) => _Obsah(elektromer: value!),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Obsah extends StatelessWidget {
  const _Obsah({required this.elektromer});

  final Elektromer elektromer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Rozmery.okrajStranky,
        0,
        Rozmery.okrajStranky,
        24,
      ),
      children: [
        if (!elektromer.aktivni) ...[
          ChybovyBlok(
            zprava:
                'Tento elektroměr je vyřazený z provozu. V obchůzce se '
                'neobjeví, jeho odečty ale zůstávají v historii.',
          ),
          const SizedBox(height: 16),
        ],
        Karta(
          child: Column(
            children: [
              RadekDat(popisek: 'Umístění', hodnota: elektromer.nazev),
              RadekDat(popisek: 'Číslo ze štítku', hodnota: elektromer.cislo),
              RadekDat(
                popisek: 'Pobočka',
                hodnota: elektromer.pobocka?.popisek ?? elektromer.pobockaKod,
              ),
              RadekDat(
                popisek: 'Evidován od',
                hodnota: elektromer.vytvorenoAt == null
                    ? '—'
                    : Format.datum(elektromer.vytvorenoAt!),
                posledni: true,
              ),
            ],
          ),
        ),
        const NadpisSekce('Odečty'),
        const PrazdnyStav(
          text:
              'Zapisování odečtů se teprve připravuje.\n'
              'Zatím tu elektroměry jen evidujeme.',
          ikona: Icons.electric_meter_outlined,
        ),
        const SizedBox(height: 8),
        PrimarniTlacitko(
          popisek: 'Upravit elektroměr',
          ikona: Icons.edit_outlined,
          vyska: Rozmery.dotykMin,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FormularElektromeru(
                pobocka: elektromer.pobocka ?? Pobocka.values.first,
                upravuje: elektromer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
