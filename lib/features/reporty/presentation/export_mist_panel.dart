import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../elektromery/application/odecty_controller.dart';
import '../../elektromery/domain/druh_mista.dart';
import '../../elektromery/domain/elektromer.dart';
import '../../elektromery/domain/pobocka.dart';
import '../application/exporty_providery.dart';
import '../application/report_controller.dart';
import '../domain/zaznam_exportu.dart';
import 'export_panel.dart';

/// `1 odečet`, `3 odečty`, `5 odečtů`.
String _pocetOdectu(int pocet) => switch (pocet) {
  1 => '1 odečet',
  >= 2 && <= 4 => '$pocet odečty',
  _ => '$pocet odečtů',
};

/// Otevře export stavů všech zobrazených míst.
Future<void> otevriExportStavu(
  BuildContext context, {
  required Pobocka pobocka,
  required DruhMista? druh,
  required List<Elektromer> mista,
}) => otevriExportPanel(
  context,
  ExportStavuPanel(pobocka: pobocka, druh: druh, mista: mista),
);

/// Otevře export odečtů jednoho místa.
Future<void> otevriExportOdectu(BuildContext context, Elektromer elektromer) =>
    otevriExportPanel(context, ExportOdectuPanel(elektromer: elektromer));

/// Přehled stavů za to, co je zrovna vidět v seznamu: pobočku a případně
/// jeden druh, stejně jako u QR štítků.
class ExportStavuPanel extends ConsumerWidget {
  const ExportStavuPanel({
    super.key,
    required this.pobocka,
    required this.druh,
    required this.mista,
  });

  final Pobocka pobocka;
  final DruhMista? druh;
  final List<Elektromer> mista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rizeni = ref.read(reportControllerProvider.notifier);
    // Historie jen téhož výřezu: report za plyn neříká nic o elektřině,
    // takže by u ní nesměl posouvat, co je nové.
    final exporty = ref
        .watch(exportyMistProvider)
        .value
        ?.where(
          (e) =>
              e.elektromerId == null &&
              e.pobockaKod == pobocka.kod &&
              e.druh == druh,
        )
        .toList();
    final nabidka = exporty == null
        ? null
        : NabidkaOdectu.zMist(mista, exporty);

    return ExportPanel(
      titulek: 'Export stavů',
      podtitulek: [
        pobocka.popisek,
        ?druh?.nazev,
        Format.pocetMist(mista.length),
      ].join(' · '),
      popisPdf: 'Přehled míst se souhrnem',
      popisExcel: 'Tabulka stavů k dopočítání',
      prazdneObdobi: 'Ve zvoleném období není u těchto míst žádný odečet.',
      nove: nabidka == null
          ? null
          : (
              obdobi: nabidka.obdobi,
              popis: '${Format.pocetMist(nabidka.pocet)} s odečtem',
            ),
      reporty: [
        for (final e in exporty ?? const <ZaznamExportu>[])
          ReportVPanelu(
            export: e,
            pocet: e.pocetZaznamu == 0
                ? 'bez odečtů'
                : '${Format.pocetMist(e.pocetZaznamu)} s odečtem',
          ),
      ],
      onVytvor: (obdobi, formaty, _) => rizeni.vytvorStavy(
        pobocka: pobocka,
        druh: druh,
        mista: mista,
        obdobi: obdobi,
        formaty: formaty,
      ),
      onSdiletZnovu: (e) => rizeni.vytvorStavy(
        pobocka: pobocka,
        druh: druh,
        mista: mista,
        obdobi: e.obdobi,
        formaty: e.formaty,
        zapsatStopu: false,
      ),
    );
  }
}

/// Odečty jednoho místa z jeho detailu.
class ExportOdectuPanel extends ConsumerWidget {
  const ExportOdectuPanel({super.key, required this.elektromer});

  final Elektromer elektromer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rizeni = ref.read(reportControllerProvider.notifier);
    final jednotka = elektromer.druh.jednotka;
    final odecty = ref.watch(historieOdectuProvider(elektromer.id)).value;
    final exporty = ref
        .watch(exportyMistProvider)
        .value
        ?.where((e) => e.elektromerId == elektromer.id)
        .toList();
    final nabidka = (odecty == null || exporty == null)
        ? null
        : NabidkaOdectu.zOdectu(odecty, exporty);

    return ExportPanel(
      titulek: 'Export odečtů',
      podtitulek: '${elektromer.druh.nazev} · ${elektromer.nazev}',
      popisPdf: 'Přehled odečtů se změnou',
      popisExcel: 'Tabulka odečtů k dopočítání',
      prazdneObdobi: 'Ve zvoleném období tu není žádný odečet.',
      nove: nabidka == null
          ? null
          : (
              obdobi: nabidka.obdobi,
              popis: [
                _pocetOdectu(nabidka.pocet),
                if (nabidka.spotreba case final s?)
                  '+${Format.kwh(s)} $jednotka',
              ].join(' · '),
            ),
      reporty: [
        for (final e in exporty ?? const <ZaznamExportu>[])
          ReportVPanelu(
            export: e,
            pocet: e.pocetZaznamu == 0
                ? 'bez odečtů'
                : _pocetOdectu(e.pocetZaznamu),
          ),
      ],
      onVytvor: (obdobi, formaty, _) => rizeni.vytvorProElektromer(
        elektromer: elektromer,
        obdobi: obdobi,
        formaty: formaty,
      ),
      onSdiletZnovu: (e) => rizeni.vytvorProElektromer(
        elektromer: elektromer,
        obdobi: e.obdobi,
        formaty: e.formaty,
        zapsatStopu: false,
      ),
    );
  }
}
