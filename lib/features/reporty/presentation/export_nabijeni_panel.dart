import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../nabijeni/application/nabijeni_providery.dart';
import '../../nabijeni/domain/relace.dart';
import '../../nabijeni/presentation/widgety/relace_widgety.dart';
import '../application/exporty_providery.dart';
import '../application/report_controller.dart';
import '../domain/zaznam_exportu.dart';
import 'export_panel.dart';

/// Otevře export nabíjení jako panel zespodu nad přehledem.
Future<void> otevriExportNabijeni(BuildContext context) =>
    otevriExportPanel(context, const ExportNabijeniPanel());

/// Export vlastních nabíjení.
class ExportNabijeniPanel extends ConsumerWidget {
  const ExportNabijeniPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rizeni = ref.read(reportControllerProvider.notifier);
    final historie = ref.watch(historieProvider).value ?? const <Relace>[];
    final exporty = ref.watch(historieExportuProvider).value;

    // Dokud nejsou reporty načtené, nedá se říct, co je nové.
    final nabidka = exporty == null ? null : NabidkaNovych.z(historie, exporty);

    return ExportPanel(
      titulek: 'Export nabíjení',
      popisPdf: 'Přehled se souhrnem',
      popisExcel: 'Tabulka se stavy počítadla',
      nabizetFotky: true,
      prazdneObdobi: 'Ve zvoleném období není žádné dokončené nabíjení.',
      nove: nabidka == null
          ? null
          : (
              obdobi: nabidka.obdobi,
              popis: [
                '${nabidka.pocet} nabíjení',
                orientacniCastka(ref, nabidka.celkemKwh) ??
                    '${Format.kwh(nabidka.celkemKwh)} kWh',
              ].join(' · '),
            ),
      reporty: [
        for (final e in exporty ?? const <ZaznamExportu>[])
          ReportVPanelu(
            export: e,
            pocet: e.pocetZaznamu == 0
                ? 'bez záznamů'
                : '${e.pocetZaznamu} nabíjení',
            hodnota: _hodnota(ref, e.spotrebaZ(historie)),
          ),
      ],
      onVytvor: (obdobi, formaty, sFotkami) => rizeni.vytvorNabijeni(
        obdobi: obdobi,
        formaty: formaty,
        sFotkami: sFotkami,
      ),
      onSdiletZnovu: rizeni.sdilejZnovu,
    );
  }

  /// Report starší, než kolik se načítá historie, by ukazoval nulu. Částku
  /// neznáme, tak ji netvrdíme.
  static String? _hodnota(WidgetRef ref, double kwh) =>
      kwh > 0 ? orientacniCastka(ref, kwh) ?? '${Format.kwh(kwh)} kWh' : null;
}
