import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../nabijeni/application/nabijeni_providery.dart';
import '../../nabijeni/domain/relace.dart';
import '../../nabijeni/presentation/widgety/relace_widgety.dart';
import '../application/exporty_providery.dart';
import '../application/report_controller.dart';
import '../domain/report.dart';
import '../domain/zaznam_exportu.dart';
import 'export_obrazovka.dart';

/// Otevře export nabíjení jako panel zespodu nad přehledem.
Future<void> otevriExportNabijeni(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.barvy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const ExportNabijeniPanel(),
  );
}

/// Export nabíjení: období, formáty a historie vytvořených reportů.
///
/// Typicky se jede „jen nové" v obou formátech, proto je to předvybrané
/// a stačí potvrdit. Fotky jsou vypnuté: s nimi se soubor stahuje
/// a sestavuje výrazně déle a do mailu se hůř vejde.
class ExportNabijeniPanel extends ConsumerStatefulWidget {
  const ExportNabijeniPanel({super.key});

  @override
  ConsumerState<ExportNabijeniPanel> createState() =>
      _ExportNabijeniPanelState();
}

class _ExportNabijeniPanelState extends ConsumerState<ExportNabijeniPanel> {
  bool _vlastniObdobi = false;
  Obdobi _vlastni = Obdobi.tentoMesic();
  Set<FormatExportu> _formaty = {FormatExportu.pdf, FormatExportu.xlsx};
  bool _sFotkami = false;

  void _prepniFormat(FormatExportu format) => setState(
    () => _formaty = _formaty.contains(format)
        ? ({..._formaty}..remove(format))
        : {..._formaty, format},
  );

  Future<void> _vytvor(Obdobi obdobi) async {
    final pocet = await ref
        .read(reportControllerProvider.notifier)
        .vytvorNabijeni(
          obdobi: obdobi,
          formaty: _formaty,
          sFotkami: _formaty.contains(FormatExportu.pdf) && _sFotkami,
        );
    if (!mounted || pocet == null) return;

    if (pocet == 0) {
      ukazVarovani(
        context,
        'Ve zvoleném období není žádné dokončené nabíjení.',
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stav = ref.watch(reportControllerProvider);
    final probiha = ref.read(reportControllerProvider.notifier).probiha;
    final historie = ref.watch(historieProvider).value ?? const <Relace>[];
    final exporty = ref.watch(historieExportuProvider).value;

    // Dokud nejsou reporty načtené, nedá se říct, co je nové.
    final nabidka = exporty == null ? null : NabidkaNovych.z(historie, exporty);
    final vlastni = _vlastniObdobi || nabidka == null;
    final obdobi = vlastni ? _vlastni : nabidka.obdobi;
    final maPdf = _formaty.contains(FormatExportu.pdf);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Rozmery.okrajStranky,
        0,
        Rozmery.okrajStranky,
        24,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            'Export nabíjení',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const NadpisSekce('Období'),
          if (nabidka != null) ...[
            _VolbaObdobi(
              vybrano: !vlastni,
              titulek: 'Jen nové od ${Format.denAMesic(nabidka.obdobi.od)}',
              popis: [
                '${nabidka.pocet} nabíjení',
                orientacniCastka(ref, nabidka.celkemKwh) ??
                    '${Format.kwh(nabidka.celkemKwh)} kWh',
              ].join(' · '),
              onTap: () => setState(() => _vlastniObdobi = false),
            ),
            const SizedBox(height: 10),
          ],
          _VolbaObdobi(
            vybrano: vlastni,
            titulek: 'Vlastní období',
            popis: vlastni
                ? Format.rozsahDnu(_vlastni.od, _vlastni.doVcetne)
                : 'Tento měsíc, minulý měsíc, od – do',
            onTap: () => setState(() => _vlastniObdobi = true),
          ),
          if (vlastni) ...[
            const SizedBox(height: 10),
            RychlaVolbaObdobi(
              obdobi: _vlastni,
              onZmena: (nove) => setState(() => _vlastni = nove),
            ),
            OdkazoveTlacitko(
              popisek: 'Zvolit od – do',
              onTap: probiha
                  ? null
                  : () async {
                      final vybrane = await vyberObdobi(context, _vlastni);
                      if (vybrane != null) setState(() => _vlastni = vybrane);
                    },
            ),
          ],
          _NadpisFormatu(),
          // IntrinsicHeight kvůli stejně vysokým kartám, i když se popis
          // jedné z nich zalomí.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _VolbaFormatu(
                    titulek: FormatExportu.pdf.popisek,
                    popis: 'Přehled se souhrnem',
                    vybrano: maPdf,
                    onTap: () => _prepniFormat(FormatExportu.pdf),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VolbaFormatu(
                    titulek: FormatExportu.xlsx.popisek,
                    popis: 'Tabulka se stavy počítadla',
                    vybrano: _formaty.contains(FormatExportu.xlsx),
                    onTap: () => _prepniFormat(FormatExportu.xlsx),
                  ),
                ),
              ],
            ),
          ),
          // Fotky jsou jen v PDF. Do tabulky nepatří a přepínač, který
          // na výsledek nemá vliv, jen mate.
          if (maPdf) ...[
            const SizedBox(height: 10),
            Karta(
              padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _sFotkami,
                onChanged: probiha
                    ? null
                    : (zapnuto) => setState(() => _sFotkami = zapnuto),
                title: Text(
                  'Přiložit do PDF fotky počítadla',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
          if (stav case ReportChyba(:final chyba)) ...[
            const SizedBox(height: 14),
            ChybovyBlok(zprava: chyba.zprava),
          ],
          const SizedBox(height: 14),
          PrimarniTlacitko(
            popisek: _formaty.isEmpty
                ? 'Vyberte formát'
                : 'Vytvořit ${FormatExportu.popisVyberu(_formaty)}',
            nacita: probiha,
            onTap: probiha || _formaty.isEmpty ? null : () => _vytvor(obdobi),
          ),
          if (probiha) ...[const SizedBox(height: 14), PrubehReportu(stav)],
          if (exporty != null && exporty.isNotEmpty) ...[
            const NadpisSekce('Historie reportů'),
            for (final (i, e) in exporty.indexed)
              _RadekReportu(
                export: e,
                historie: historie,
                posledni: i == exporty.length - 1,
                onSdilet: probiha
                    ? null
                    : () => ref
                          .read(reportControllerProvider.notifier)
                          .sdilejZnovu(e),
              ),
          ],
        ],
      ),
    );
  }
}

/// Nadpis s poznámkou vpravo, že se dají vybrat oba formáty.
class _NadpisFormatu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(child: NadpisSekce('Formát')),
        Padding(
          // Na účaří nadpisu, který si nese vlastní odsazení dole.
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'lze vybrat oba',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Karta období s kolečkem vpravo – vybrat jde jen jedno.
class _VolbaObdobi extends StatelessWidget {
  const _VolbaObdobi({
    required this.vybrano,
    required this.titulek,
    required this.popis,
    required this.onTap,
  });

  final bool vybrano;
  final String titulek;
  final String popis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Semantics(
      selected: vybrano,
      child: VolbaKarta(
        vybrano: vybrano,
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titulek, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 2),
                  Text(popis, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              vybrano ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 24,
              color: vybrano ? b.accent : b.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Karta formátu se zaškrtávátkem – vybrat jde i oba.
class _VolbaFormatu extends StatelessWidget {
  const _VolbaFormatu({
    required this.titulek,
    required this.popis,
    required this.vybrano,
    required this.onTap,
  });

  final String titulek;
  final String popis;
  final bool vybrano;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Semantics(
      checked: vybrano,
      child: VolbaKarta(
        vybrano: vybrano,
        onTap: onTap,
        nahoru: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    titulek,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                Icon(
                  vybrano ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 24,
                  color: vybrano ? b.accent : b.textFaint,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(popis, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Vytvořený report v historii, s možností poslat ho znovu.
class _RadekReportu extends ConsumerWidget {
  const _RadekReportu({
    required this.export,
    required this.historie,
    required this.posledni,
    required this.onSdilet,
  });

  final ZaznamExportu export;
  final List<Relace> historie;
  final bool posledni;
  final VoidCallback? onSdilet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final kwh = export.spotrebaZ(historie);
    final popis = [
      Format.denAMesic(export.vytvorenoAt),
      if (export.pocetZaznamu == 0)
        'bez záznamů'
      else
        '${export.pocetZaznamu} nabíjení',
      if (export.formaty.isNotEmpty) FormatExportu.popisVyberu(export.formaty),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: posledni ? null : Border(bottom: BorderSide(color: b.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Format.rozsahDnu(export.obdobi.od, export.obdobi.doVcetne),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(popis, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Report starší, než kolik se načítá historie, by ukazoval nulu.
          // Částku neznáme, tak ji netvrdíme.
          if (kwh > 0)
            Text(
              orientacniCastka(ref, kwh) ?? '${Format.kwh(kwh)} kWh',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          const SizedBox(width: 4),
          IkonoveTlacitko(
            ikona: Icons.ios_share,
            popisPristupnosti: 'Znovu sdílet report',
            sOramovanim: false,
            onTap: onSdilet,
          ),
        ],
      ),
    );
  }
}
