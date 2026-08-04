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

/// Výběr období a vytvoření PDF reportu. Hotové PDF se předá
/// systémovému sdílení, odkud se dá poslat mailem.
class ExportObrazovka extends ConsumerStatefulWidget {
  const ExportObrazovka({super.key});

  @override
  ConsumerState<ExportObrazovka> createState() => _ExportObrazovkaState();
}

class _ExportObrazovkaState extends ConsumerState<ExportObrazovka> {
  Obdobi _obdobi = Obdobi.tentoMesic();
  bool _sFotkami = true;

  Future<void> _vyberObdobi() async {
    final ted = DateTime.now();
    final rozsah = await showDateRangePicker(
      context: context,
      // Aplikace vznikla v roce 2026, dřív žádná relace být nemůže.
      firstDate: DateTime(2026),
      lastDate: DateTime(ted.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _obdobi.od, end: _obdobi.doVcetne),
      helpText: 'Zvolte období',
      saveText: 'Potvrdit',
    );
    if (rozsah == null) return;
    setState(() => _obdobi = Obdobi(od: rozsah.start, doVcetne: rozsah.end));
  }

  Future<void> _vytvor() async {
    final rizeni = ref.read(reportControllerProvider.notifier);
    final pocet = await rizeni.vytvorASdilej(
      obdobi: _obdobi,
      sFotkami: _sFotkami,
    );
    if (!mounted || pocet == null) return;

    if (pocet == 0) {
      ukazVarovani(
        context,
        'Ve zvoleném období není žádné dokončené nabíjení.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final stav = ref.watch(reportControllerProvider);
    final probiha = ref.read(reportControllerProvider.notifier).probiha;

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HlavickaToku(
              titulek: 'Export do PDF',
              onZpet: probiha ? null : () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Rozmery.okrajStranky,
                  0,
                  Rozmery.okrajStranky,
                  24,
                ),
                children: [
                  const NadpisSekce('Období'),
                  _RychlaVolba(
                    obdobi: _obdobi,
                    onZmena: (nove) => setState(() => _obdobi = nove),
                  ),
                  const SizedBox(height: 10),
                  Karta(
                    child: RadekDat(
                      popisek: 'Vybrané období',
                      hodnota:
                          '${Format.datum(_obdobi.od)} – '
                          '${Format.datum(_obdobi.doVcetne)}',
                      posledni: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  OdkazoveTlacitko(
                    popisek: 'Zvolit jiné období',
                    onTap: probiha ? null : _vyberObdobi,
                  ),
                  const NadpisSekce('Obsah'),
                  Karta(
                    padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _sFotkami,
                      onChanged: probiha
                          ? null
                          : (zapnuto) => setState(() => _sFotkami = zapnuto),
                      title: Text(
                        'Včetně fotografií počítadla',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        'Fotky se do PDF vloží zmenšené, aby se report dal '
                        'poslat mailem. Bez nich je soubor o poznání menší '
                        'a vytvoří se hned.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                  if (stav case ReportChyba(:final chyba)) ...[
                    const SizedBox(height: 18),
                    ChybovyBlok(zprava: chyba.zprava),
                  ],
                  const SizedBox(height: 18),
                  _Prubeh(stav),
                ],
              ),
            ),
            _Pata(probiha: probiha, onVytvorit: _vytvor),
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
      ReportSestavuje() => ('Sestavuji PDF…', null),
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

class _Pata extends StatelessWidget {
  const _Pata({required this.probiha, required this.onVytvorit});

  final bool probiha;
  final VoidCallback onVytvorit;

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
          popisek: 'Vytvořit PDF',
          nacita: probiha,
          onTap: probiha ? null : onVytvorit,
        ),
      ),
    );
  }
}
