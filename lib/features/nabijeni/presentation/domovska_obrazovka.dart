import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rezim_motivu.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../../navigace/toky.dart';
import '../../auth/application/auth_providery.dart';
import '../../reporty/application/exporty_providery.dart';
import '../application/nabijeni_providery.dart';
import '../domain/mesicni_skupina.dart';
import '../domain/relace.dart';
import 'widgety/relace_widgety.dart';

/// Nabíjení: zahájení nebo běžící relace nahoře, pod tím celá historie.
///
/// Historie sem patří proto, že je to historie **tohohle**. Vlastní
/// záložka „Historie" vedle Elektroměrů neříkala, čeho – a odečty
/// elektroměrů to mají stejně, taky bydlí v detailu svého zařízení.
class DomovskaObrazovka extends ConsumerWidget {
  const DomovskaObrazovka({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider).value;
    final otevrena = ref.watch(otevrenaRelaceProvider);
    final historie = ref.watch(historieProvider);
    // Chybu tady neřešíme: bez seznamu reportů je historie pořád historie,
    // jen se u ní neukazuje, co už v nějakém je.
    final exporty = ref.watch(historieExportuProvider).value;
    final nove = ref.watch(noveKExportuProvider);

    final relace = otevrena.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Rozmery.okrajStranky,
        0,
        Rozmery.okrajStranky,
        24,
      ),
      children: [
        _Hlavicka(
          jmeno: profil?.krestniJmeno,
          maNove: nove != null && nove.isNotEmpty,
        ),
        if (otevrena.hasError)
          ChybovyBlok(
            zprava: 'Stav nabíjení se nepodařilo načíst.',
            onZkusitZnovu: () => ref.invalidate(otevrenaRelaceProvider),
          )
        else if (relace != null)
          _KartaProbihajiciRelace(relace: relace)
        else
          PrimarniTlacitko(
            popisek: 'Zahájit nabíjení',
            ikona: Icons.bolt,
            vyska: Rozmery.tlacitkoVelke,
            onTap: () => otevriZahajeni(context),
          ),
        // Nabíječka bez počítadla se zapisuje až po nabití a relaci
        // neotevírá, proto je k dispozici i vedle běžícího nabíjení.
        if (!otevrena.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: OdkazoveTlacitko(
              popisek: 'Zapsat nabíjení bez počítadla',
              onTap: () => otevriPrimyZapis(context),
            ),
          ),
        if (nove != null && nove.isNotEmpty) _KartaNovych(pocet: nove.length),
        switch (historie) {
          AsyncError() => ChybovyBlok(
            zprava: 'Historii se nepodařilo načíst.',
            onZkusitZnovu: () => ref.invalidate(historieProvider),
          ),
          AsyncData(:final value) when value.isEmpty => const PrazdnyStav(
            text:
                'Zatím tu nic není.\nPrvní nabíjení zahájíte tlačítkem nahoře.',
            ikona: Icons.ev_station_outlined,
          ),
          // Předěly po měsících se součtem – typická otázka nad historií
          // je „kolik jsem nabil minulý měsíc", ne „kolik celkem".
          AsyncData(:final value) => Column(
            children: [
              for (final skupina in seskupPoMesicich(value)) ...[
                PredelMesice(skupina),
                for (final relace in skupina.relace)
                  RadekRelace(
                    relace: relace,
                    vReportu: exporty?.any((e) => e.zahrnuje(relace)),
                    onTap: () => otevriDetail(context, relace.id),
                  ),
              ],
            ],
          ),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

/// Kolik nabíjení ještě nezahrnul žádný report, a cesta k exportu.
class _KartaNovych extends ConsumerWidget {
  const _KartaNovych({required this.pocet});

  final int pocet;

  static String _nadpis(int pocet) => switch (pocet) {
    1 => '1 nové nabíjení k exportu',
    >= 2 && <= 4 => '$pocet nová nabíjení k exportu',
    _ => '$pocet nových nabíjení k exportu',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posledni = ref.watch(posledniExportProvider);
    return Karta(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _nadpis(pocet),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  posledni == null
                      ? 'Zatím žádný report'
                      : 'Poslední report '
                            '${Format.denAMesic(posledni.vytvorenoAt)} · do '
                            '${Format.denAMesic(posledni.obdobi.doVcetne)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 112,
            child: PrimarniTlacitko(
              popisek: 'Exportovat',
              vyska: 44,
              onTap: () => otevriExport(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hlavicka extends ConsumerWidget {
  const _Hlavicka({required this.jmeno, required this.maNove});

  final String? jmeno;

  /// Tečka u ikony exportu: je co exportovat.
  final bool maNove;

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
          // Export je tu proto, že historie je hned pod hlavičkou –
          // vyjede se z ní report, takže tlačítko patří k ní.
          Stack(
            clipBehavior: Clip.none,
            children: [
              IkonoveTlacitko(
                ikona: Icons.ios_share,
                popisPristupnosti: maNove
                    ? 'Exportovat nabíjení, jsou nová k exportu'
                    : 'Exportovat nabíjení',
                onTap: () => otevriExport(context),
              ),
              if (maNove)
                Positioned(
                  top: 5,
                  right: 5,
                  child: IgnorePointer(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: context.barvy.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
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
      padding: const EdgeInsets.only(bottom: 4),
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
                    hodnota: '${Format.kwh(relace.kwhStart ?? 0)} kWh',
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
