import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../../navigace/toky.dart';
import '../../reporty/application/exporty_providery.dart';
import '../application/nabijeni_providery.dart';
import '../domain/mesicni_skupina.dart';
import 'widgety/relace_widgety.dart';

/// Všechny relace uživatele, od nejnovější. Probíhající je nahoře.
class HistorieObrazovka extends ConsumerWidget {
  const HistorieObrazovka({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historie = ref.watch(historieProvider);
    // Chybu tady neřešíme: bez seznamu exportů je historie pořád
    // historie, jen bez poznámek o vytvořených reportech.
    final exporty = ref.watch(historieExportuProvider).value ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Rozmery.okrajStranky,
        0,
        Rozmery.okrajStranky,
        24,
      ),
      children: [
        VelkyNadpis(
          'Historie',
          akce: IkonoveTlacitko(
            ikona: Icons.ios_share,
            popisPristupnosti: 'Exportovat období do PDF',
            sOramovanim: true,
            onTap: () => otevriExport(context),
          ),
        ),
        switch (historie) {
          AsyncError() => ChybovyBlok(
            zprava: 'Historii se nepodařilo načíst.',
            onZkusitZnovu: () => ref.invalidate(historieProvider),
          ),
          AsyncData(:final value) when value.isEmpty => const PrazdnyStav(
            text:
                'Zatím tu nic není.\n'
                'Po prvním dokončeném nabíjení se sem záznam uloží sám.',
            ikona: Icons.access_time,
          ),
          // Předěly po měsících se součtem – typická otázka nad historií
          // je „kolik jsem nabil minulý měsíc", ne „kolik celkem".
          AsyncData(:final value) => Column(
            children: [
              for (final skupina in seskupPoMesicich(
                value,
                exporty: exporty,
              )) ...[
                PredelMesice(skupina),
                // Report leží mezi relacemi podle konce svého období:
                // co je pod čarou, to už zahrnul.
                for (final polozka in skupina.polozky)
                  switch (polozka) {
                    PolozkaRelace(:final relace) => RadekRelace(
                      relace: relace,
                      onTap: () => otevriDetail(context, relace.id),
                    ),
                    PolozkaExportu(:final polozka) => RadekExportu(polozka),
                  },
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
