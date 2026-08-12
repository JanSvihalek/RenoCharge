import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../nabijeni/presentation/prohlizec_fotky.dart';
import '../../reporty/application/report_controller.dart';
import '../../reporty/presentation/export_obrazovka.dart';
import '../application/elektromery_providery.dart';
import '../application/odecty_controller.dart';
import '../domain/elektromer.dart';
import '../domain/odecet.dart';
import '../domain/pobocka.dart';
import 'formular_elektromeru.dart';
import 'tok_odectu.dart';

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

class _Obsah extends ConsumerWidget {
  const _Obsah({required this.elektromer});

  final Elektromer elektromer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historie = ref.watch(historieOdectuProvider(elektromer.id));
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
        if (elektromer.aktivni) ...[
          const SizedBox(height: 16),
          PrimarniTlacitko(
            popisek: 'Zapsat odečet',
            ikona: Icons.photo_camera_outlined,
            onTap: () => otevriZapisOdectu(context, ref, elektromer),
          ),
        ],

        const NadpisSekce('Historie odečtů'),
        switch (historie) {
          AsyncError() => ChybovyBlok(
            zprava: 'Odečty se nepodařilo načíst.',
            onZkusitZnovu: () =>
                ref.invalidate(historieOdectuProvider(elektromer.id)),
          ),
          AsyncData(:final value) when value.isEmpty => const PrazdnyStav(
            text: 'Zatím tu není žádný odečet.',
            ikona: Icons.electric_meter_outlined,
          ),
          AsyncData(:final value) => Column(
            children: [for (final o in value) _RadekOdectu(o)],
          ),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        },

        const SizedBox(height: 8),
        OdkazoveTlacitko(
          popisek: 'Export odečtů do PDF',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ExportObrazovka(elektromer: elektromer),
            ),
          ),
        ),
        // Jednotlivý štítek se hodí, když se ten nalepený poškodí nebo
        // když elektroměr přibude po hromadném tisku za pobočku.
        OdkazoveTlacitko(
          popisek: 'Vytisknout QR štítek',
          onTap: () => ref
              .read(reportControllerProvider.notifier)
              .vytvorStitky(
                popis: 'elektromer ${elektromer.cislo}',
                elektromery: [elektromer],
              ),
        ),
        OdkazoveTlacitko(
          popisek: 'Upravit elektroměr',
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

/// Jeden odečet v historii. Spotřeba je dopočítaná proti předchozímu
/// záznamu, neukládá se – viz [dopocitejSpotrebu].
class _RadekOdectu extends StatelessWidget {
  const _RadekOdectu(this.polozka);

  final OdecetSeSpotrebou polozka;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final o = polozka.odecet;
    final spotreba = polozka.spotreba;
    final maFotku = o.foto.path.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: !maFotku
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => ProhlizecFotky(
                    cesta: o.foto.path,
                    popisek:
                        '${Format.datum(o.odectenoAt)} · '
                        '${Format.kwh(o.hodnota)} kWh',
                  ),
                ),
              ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: b.surface,
            borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
            border: Border.all(color: b.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${Format.kwh(o.hodnota)} kWh',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Format.datum(o.odectenoAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (o.vymenaMeridla) ...[
                      const SizedBox(height: 2),
                      Text(
                        'nové měřidlo',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: b.stop),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (spotreba != null)
                Text(
                  '+${Format.kwh(spotreba)} kWh',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: b.accent),
                ),
              if (maFotku) ...[
                const SizedBox(width: 8),
                Icon(Icons.photo_outlined, size: 18, color: b.textFaint),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
