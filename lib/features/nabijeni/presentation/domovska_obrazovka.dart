import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/konfigurace.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rezim_motivu.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../../navigace/toky.dart';
import '../../auth/application/auth_providery.dart';
import '../application/nabijeni_providery.dart';
import '../domain/relace.dart';
import 'widgety/relace_widgety.dart';

/// Domovská obrazovka ve dvou podobách: buď nabízí zahájení nabíjení,
/// nebo ukazuje kartu probíhající relace.
class DomovskaObrazovka extends ConsumerWidget {
  const DomovskaObrazovka({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider).value;
    final otevrena = ref.watch(otevrenaRelaceProvider);
    final historie = ref.watch(historieProvider).value ?? const <Relace>[];

    final relace = otevrena.value;
    final posledni = historie
        .where((r) => !r.probiha)
        .take(Konfigurace.poslednichRelaciNaDomovske)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Rozmery.okrajStranky,
        0,
        Rozmery.okrajStranky,
        24,
      ),
      children: [
        _Hlavicka(jmeno: profil?.krestniJmeno),
        if (otevrena.hasError)
          ChybovyBlok(
            zprava: 'Stav nabíjení se nepodařilo načíst.',
            onZkusitZnovu: () => ref.invalidate(otevrenaRelaceProvider),
          )
        else if (relace != null)
          _KartaProbihajiciRelace(relace: relace)
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 26),
            child: PrimarniTlacitko(
              popisek: 'Zahájit nabíjení',
              ikona: Icons.bolt,
              vyska: Rozmery.tlacitkoVelke,
              onTap: () => otevriZahajeni(context),
            ),
          ),
        const NadpisSekce('Posledních 5 relací'),
        if (relace != null)
          RadekRelace(
            relace: relace,
            onTap: () => otevriDetail(context, relace.id),
          ),
        if (posledni.isEmpty && relace == null)
          const PrazdnyStav(
            text:
                'Zatím tu nic není.\nPrvní nabíjení zahájíte tlačítkem nahoře.',
            ikona: Icons.ev_station_outlined,
          )
        else
          for (final r in posledni)
            RadekRelace(relace: r, onTap: () => otevriDetail(context, r.id)),
      ],
    );
  }
}

class _Hlavicka extends ConsumerWidget {
  const _Hlavicka({required this.jmeno});

  final String? jmeno;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jeTmavy = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ahoj, ${jmeno ?? 'kolego'}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'Areál – nabíjecí stanice',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IkonoveTlacitko(
            ikona: jeTmavy
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            popisPristupnosti: jeTmavy
                ? 'Přepnout na světlý režim'
                : 'Přepnout na tmavý režim',
            onTap: () => ref
                .read(rezimMotivuProvider.notifier)
                .prepni(jeTedTmavy: jeTmavy),
          ),
        ],
      ),
    );
  }
}

class _KartaProbihajiciRelace extends ConsumerWidget {
  const _KartaProbihajiciRelace({required this.relace});

  final Relace relace;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vozidlo = popisekVozidla(ref, relace);
    final ted = ref.watch(tikProvider).value ?? DateTime.now();
    final b = context.barvy;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Karta(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OdznakStavu(StavRelace.probiha),
            const SizedBox(height: 12),
            Text(vozidlo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Udaj(
                    popisek: 'Zahájeno',
                    hodnota:
                        '${Format.cas(relace.zahajeno)} · '
                        '${Format.doba(relace.doba(ted: ted))}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Udaj(
                    popisek: 'Počáteční stav',
                    hodnota: '${Format.kwh(relace.kwhStart)} kWh',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimarniTlacitko(
              popisek: 'Ukončit nabíjení',
              barvaPozadi: b.stop,
              barvaTextu: b.stopText,
              onTap: () => otevriUkonceni(context, relace),
            ),
          ],
        ),
      ),
    );
  }
}

class _Udaj extends StatelessWidget {
  const _Udaj({required this.popisek, required this.hodnota});

  final String popisek;
  final String hodnota;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(popisek, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(hodnota, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}
