import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../application/report_controller.dart';
import '../domain/report.dart';
import '../domain/zaznam_exportu.dart';

/// Otevře export jako panel zespodu nad obrazovkou, ze které se vychází.
Future<void> otevriExportPanel(BuildContext context, Widget panel) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.barvy.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => panel,
  );
}

/// Řádek v historii reportů.
class ReportVPanelu {
  const ReportVPanelu({
    required this.export,
    required this.pocet,
    this.hodnota,
  });

  final ZaznamExportu export;

  /// `12 nabíjení`, `3 odečty`.
  final String pocet;

  /// Částka nebo spotřeba vpravo; `null`, když ji neznáme.
  final String? hodnota;
}

/// Export: období, formáty a historie vytvořených reportů. Stejný pro
/// nabíjení i odběrná místa, data mu dodávají jejich panely – tři skoro
/// stejné obrazovky by se časem rozešly.
///
/// Typicky se jede „jen nové" v obou formátech, proto je to předvybrané
/// a stačí potvrdit.
class ExportPanel extends ConsumerStatefulWidget {
  const ExportPanel({
    super.key,
    required this.titulek,
    required this.popisPdf,
    required this.popisExcel,
    required this.prazdneObdobi,
    required this.reporty,
    required this.onVytvor,
    required this.onSdiletZnovu,
    this.podtitulek,
    this.nove,
    this.nabizetFotky = false,
  });

  final String titulek;
  final String? podtitulek;

  /// Období pokrývající to, co ještě v žádném reportu není, a popis toho,
  /// co v něm je. `null`, když není nic nového – volí se vlastní období.
  final ({Obdobi obdobi, String popis})? nove;

  final String popisPdf;
  final String popisExcel;

  /// Přepínač fotek do PDF. Jen u nabíjení: odečty se nefotí.
  final bool nabizetFotky;

  /// Upozornění, když v období nic není.
  final String prazdneObdobi;

  final List<ReportVPanelu> reporty;

  /// Vrátí počet záznamů, `null` při chybě – tu si panel přečte ze stavu
  /// [reportControllerProvider].
  final Future<int?> Function(
    Obdobi obdobi,
    Set<FormatExportu> formaty,
    bool sFotkami,
  )
  onVytvor;

  final Future<int?> Function(ZaznamExportu export) onSdiletZnovu;

  @override
  ConsumerState<ExportPanel> createState() => _ExportPanelState();
}

class _ExportPanelState extends ConsumerState<ExportPanel> {
  bool _vlastniObdobi = false;
  Obdobi _vlastni = Obdobi.tentoMesic();
  Set<FormatExportu> _formaty = {FormatExportu.pdf, FormatExportu.xlsx};

  /// Vypnuté: s fotkami se report stahuje a sestavuje výrazně déle a do
  /// mailu se hůř vejde.
  bool _sFotkami = false;

  void _prepniFormat(FormatExportu format) => setState(
    () => _formaty = _formaty.contains(format)
        ? ({..._formaty}..remove(format))
        : {..._formaty, format},
  );

  Future<void> _vyberVlastni() async {
    final ted = DateTime.now();
    final rozsah = await showDateRangePicker(
      context: context,
      // Aplikace vznikla v roce 2026, dřív žádný záznam být nemůže.
      firstDate: DateTime(2026),
      lastDate: DateTime(ted.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: _vlastni.od,
        end: _vlastni.doVcetne,
      ),
      helpText: 'Zvolte období',
      saveText: 'Potvrdit',
    );
    if (rozsah != null) {
      setState(() => _vlastni = Obdobi(od: rozsah.start, doVcetne: rozsah.end));
    }
  }

  Future<void> _vytvor(Obdobi obdobi) async {
    final pocet = await widget.onVytvor(
      obdobi,
      _formaty,
      widget.nabizetFotky && _formaty.contains(FormatExportu.pdf) && _sFotkami,
    );
    if (!mounted || pocet == null) return;

    if (pocet == 0) {
      ukazVarovani(context, widget.prazdneObdobi);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stav = ref.watch(reportControllerProvider);
    final probiha = ref.read(reportControllerProvider.notifier).probiha;
    final nove = widget.nove;
    final vlastni = _vlastniObdobi || nove == null;
    final obdobi = vlastni ? _vlastni : nove.obdobi;
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
          Text(widget.titulek, style: Theme.of(context).textTheme.titleLarge),
          if (widget.podtitulek != null) ...[
            const SizedBox(height: 2),
            Text(
              widget.podtitulek!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const NadpisSekce('Období'),
          if (nove != null) ...[
            _VolbaObdobi(
              vybrano: !vlastni,
              titulek: 'Jen nové od ${Format.denAMesic(nove.obdobi.od)}',
              popis: nove.popis,
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
            _RychlaVolba(
              obdobi: _vlastni,
              onZmena: (nove) => setState(() => _vlastni = nove),
            ),
            OdkazoveTlacitko(
              popisek: 'Zvolit od – do',
              onTap: probiha ? null : _vyberVlastni,
            ),
          ],
          const _NadpisFormatu(),
          // IntrinsicHeight kvůli stejně vysokým kartám, i když se popis
          // jedné z nich zalomí.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _VolbaFormatu(
                    titulek: FormatExportu.pdf.popisek,
                    popis: widget.popisPdf,
                    vybrano: maPdf,
                    onTap: () => _prepniFormat(FormatExportu.pdf),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VolbaFormatu(
                    titulek: FormatExportu.xlsx.popisek,
                    popis: widget.popisExcel,
                    vybrano: _formaty.contains(FormatExportu.xlsx),
                    onTap: () => _prepniFormat(FormatExportu.xlsx),
                  ),
                ),
              ],
            ),
          ),
          // Fotky jsou jen v PDF. Do tabulky nepatří a přepínač, který
          // na výsledek nemá vliv, jen mate.
          if (widget.nabizetFotky && maPdf) ...[
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
          if (probiha) ...[const SizedBox(height: 14), _Prubeh(stav)],
          if (widget.reporty.isNotEmpty) ...[
            const NadpisSekce('Historie reportů'),
            for (final (i, r) in widget.reporty.indexed)
              _RadekReportu(
                report: r,
                posledni: i == widget.reporty.length - 1,
                onSdilet: probiha ? null : () => widget.onSdiletZnovu(r.export),
              ),
          ],
        ],
      ),
    );
  }
}

/// Nadpis s poznámkou vpravo, že se dají vybrat oba formáty.
class _NadpisFormatu extends StatelessWidget {
  const _NadpisFormatu();

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

/// Typický požadavek je „minulý měsíc k fakturaci", proto zkratky.
class _RychlaVolba extends StatelessWidget {
  const _RychlaVolba({required this.obdobi, required this.onZmena});

  final Obdobi obdobi;
  final ValueChanged<Obdobi> onZmena;

  @override
  Widget build(BuildContext context) {
    final tento = Obdobi.tentoMesic();
    final minuly = Obdobi.minulyMesic();

    Widget volba(String popisek, Obdobi cil) => Expanded(
      child: VolbaKarta(
        vybrano: obdobi.od == cil.od && obdobi.doVcetne == cil.doVcetne,
        vycentrovat: true,
        vyska: Rozmery.dotykMin,
        onTap: () => onZmena(cil),
        child: Text(popisek, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );

    return Row(
      children: [
        volba('Tento měsíc', tento),
        const SizedBox(width: 10),
        volba('Minulý měsíc', minuly),
      ],
    );
  }
}

/// Průběh vytváření. Stahování fotek je jediná pomalá část, proto s čísly.
class _Prubeh extends StatelessWidget {
  const _Prubeh(this.stav);

  final StavReportu stav;

  @override
  Widget build(BuildContext context) {
    final (text, podil) = switch (stav) {
      ReportNacitaZaznamy() => ('Načítám záznamy…', null),
      ReportStahujeFotky(:final hotovo, :final celkem, :final podil) => (
        'Stahuji fotografie $hotovo z $celkem…',
        podil,
      ),
      ReportSestavuje() => ('Sestavuji soubor…', null),
      _ => (null, null),
    };
    if (text == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: podil,
            minHeight: 6,
            backgroundColor: context.barvy.surface2,
          ),
        ),
      ],
    );
  }
}

/// Vytvořený report v historii, s možností poslat ho znovu.
class _RadekReportu extends StatelessWidget {
  const _RadekReportu({
    required this.report,
    required this.posledni,
    required this.onSdilet,
  });

  final ReportVPanelu report;
  final bool posledni;
  final VoidCallback? onSdilet;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final export = report.export;
    final popis = [
      Format.denAMesic(export.vytvorenoAt),
      report.pocet,
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
          if (report.hodnota != null) ...[
            const SizedBox(width: 8),
            Text(
              report.hodnota!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
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
