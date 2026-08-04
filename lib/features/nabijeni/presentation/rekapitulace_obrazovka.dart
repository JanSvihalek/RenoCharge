import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../application/ukonceni_controller.dart';
import '../domain/porizena_fotografie.dart';
import '../domain/relace.dart';
import 'widgety/relace_widgety.dart';

/// Poslední pohled na relaci před uložením. Do Firestore se zapisuje až
/// tlačítkem „Dokončit“ – do té chvíle je relace pořád otevřená.
class RekapitulaceObrazovka extends ConsumerWidget {
  const RekapitulaceObrazovka({
    super.key,
    required this.relace,
    required this.kwhEnd,
    required this.fotoEnd,
  });

  final Relace relace;
  final double kwhEnd;
  final PorizenaFotografie fotoEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final vozidlo = popisekVozidla(ref, relace);
    final stav = ref.watch(ukonceniControllerProvider);
    final spotreba = kwhEnd - relace.kwhStart;
    final doba = fotoEnd.porizenoAt.isAfter(relace.zahajeno)
        ? fotoEnd.porizenoAt.difference(relace.zahajeno)
        : DateTime.now().difference(relace.zahajeno);

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const HlavickaToku(titulek: 'Ukončení nabíjení'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Rozmery.okrajStranky,
                  0,
                  Rozmery.okrajStranky,
                  24,
                ),
                children: [
                  const SizedBox(height: 16),
                  Karta(
                    // Blok se spotřebou má sahat až k okrajům karty,
                    // proto odsazení řeší až vnitřní sloupec.
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          child: Column(
                            children: [
                              RadekDat(popisek: 'Vozidlo', hodnota: vozidlo),
                              RadekDat(
                                popisek: 'Počáteční stav',
                                hodnota: '${Format.kwh(relace.kwhStart)} kWh',
                              ),
                              RadekDat(
                                popisek: 'Koncový stav',
                                hodnota: '${Format.kwh(kwhEnd)} kWh',
                              ),
                              RadekDat(
                                popisek: 'Doba nabíjení',
                                hodnota: Format.doba(doba),
                                posledni: true,
                              ),
                            ],
                          ),
                        ),
                        BlokSpotreby(
                          kwh: Format.kwh(spotreba),
                          castka: orientacniCastka(ref, spotreba),
                        ),
                      ],
                    ),
                  ),
                  if (stav.hasError) ...[
                    const SizedBox(height: 18),
                    ChybovyBlok(zprava: AppChyba.zFirebase(stav.error!).zprava),
                  ],
                ],
              ),
            ),
            _Pata(
              nacita: stav.isLoading,
              onDokoncit: () => _dokonci(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dokonci(BuildContext context, WidgetRef ref) async {
    final povedlo = await ref
        .read(ukonceniControllerProvider.notifier)
        .dokonci(relace: relace, kwhEnd: kwhEnd, foto: fotoEnd);
    if (!context.mounted) return;
    if (povedlo) {
      Navigator.of(context).pop();
      ukazInfo(context, 'Nabíjení bylo uloženo do historie.');
    }
  }
}

class _Pata extends StatelessWidget {
  const _Pata({required this.nacita, required this.onDokoncit});

  final bool nacita;
  final VoidCallback onDokoncit;

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
          popisek: 'Dokončit',
          nacita: nacita,
          onTap: nacita ? null : onDokoncit,
        ),
      ),
    );
  }
}
