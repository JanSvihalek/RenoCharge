import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/prvky.dart';
import '../application/nabijeni_providery.dart';
import '../domain/relace.dart';
import 'widgety/relace_widgety.dart';

/// Detail jedné relace včetně obou fotek počítadla.
/// Ukončený záznam je jen ke čtení – měnit se už nedá.
class DetailRelaceObrazovka extends ConsumerWidget {
  const DetailRelaceObrazovka({super.key, required this.relaceId});

  final String relaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final relace = ref.watch(relaceProvider(relaceId));

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HlavickaToku(
              titulek: 'Detail relace',
              onZpet: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: switch (relace) {
                AsyncError() => Padding(
                  padding: const EdgeInsets.all(Rozmery.okrajStranky),
                  child: ChybovyBlok(
                    zprava: 'Detail se nepodařilo načíst.',
                    onZkusitZnovu: () =>
                        ref.invalidate(relaceProvider(relaceId)),
                  ),
                ),
                AsyncData(:final value) when value == null => const PrazdnyStav(
                  text: 'Záznam se nepodařilo najít.',
                ),
                AsyncData(:final value) => _Obsah(relace: value!),
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
  const _Obsah({required this.relace});

  final Relace relace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vozidlo = popisekVozidla(ref, relace);
    final spotreba = relace.spotreba;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Rozmery.okrajStranky,
        0,
        Rozmery.okrajStranky,
        24,
      ),
      children: [
        Align(alignment: Alignment.centerLeft, child: OdznakStavu(relace.stav)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Nahled(
                popisek: 'Před nabíjením',
                cesta: relace.fotoStart.path,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Nahled(
                popisek: 'Po nabíjení',
                cesta: relace.fotoEnd?.path,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Karta(
          // Blok se spotřebou má sahat až k okrajům karty, proto
          // odsazení řeší až vnitřní sloupec.
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  children: [
                    RadekDat(popisek: 'Vozidlo', hodnota: vozidlo),
                    RadekDat(
                      popisek: 'Datum',
                      hodnota: Format.datum(relace.zahajeno),
                    ),
                    RadekDat(
                      popisek: 'Zahájeno / ukončeno',
                      hodnota: Format.rozsahCasu(
                        relace.zahajeno,
                        relace.ukonceno,
                      ),
                    ),
                    RadekDat(
                      popisek: 'Počáteční stav',
                      hodnota: '${Format.kwh(relace.kwhStart)} kWh',
                    ),
                    RadekDat(
                      popisek: 'Koncový stav',
                      hodnota: relace.kwhEnd == null
                          ? '–'
                          : '${Format.kwh(relace.kwhEnd!)} kWh',
                      posledni: true,
                    ),
                  ],
                ),
              ),
              if (spotreba != null)
                BlokSpotreby(kwh: Format.kwh(spotreba))
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 18),
                  child: PrazdnyStav(
                    text:
                        'Nabíjení stále probíhá – spotřeba se spočítá '
                        'po jeho ukončení.',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Náhled fotky počítadla ze Storage.
class _Nahled extends ConsumerWidget {
  const _Nahled({required this.popisek, required this.cesta});

  final String popisek;
  final String? cesta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final cestaKFotce = cesta;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 4 / 3,
          child: Container(
            decoration: BoxDecoration(
              color: b.surface2,
              borderRadius: BorderRadius.circular(Rozmery.radiusMale),
              border: Border.all(color: b.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: cestaKFotce == null || cestaKFotce.isEmpty
                ? Icon(Icons.photo_camera_outlined, color: b.textFaint)
                : switch (ref.watch(odkazNaFotkuProvider(cestaKFotce))) {
                    AsyncData(:final value) => Image.network(
                      value,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.broken_image_outlined, color: b.textFaint),
                    ),
                    AsyncError() => Icon(
                      Icons.broken_image_outlined,
                      color: b.textFaint,
                    ),
                    _ => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  },
          ),
        ),
        const SizedBox(height: 6),
        Text(popisek, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
