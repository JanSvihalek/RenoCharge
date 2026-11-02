import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../elektromery/domain/druh_mista.dart';
import '../../elektromery/domain/elektromer.dart';
import '../../elektromery/domain/pobocka.dart';
import '../application/report_controller.dart';
import '../domain/report.dart';

/// Výběr období a vytvoření reportu odběrných míst. Hotový soubor se předá
/// systémovému sdílení, odkud se dá poslat mailem.
///
/// S [elektromer] vyrobí PDF jednoho místa, se [stavy] tabulku stavů všech
/// zobrazených míst. Export nabíjení má vlastní panel, viz
/// `ExportNabijeniPanel`.
class ExportObrazovka extends ConsumerStatefulWidget {
  const ExportObrazovka({super.key, this.elektromer, this.stavy});

  final Elektromer? elektromer;

  /// Místa pro hromadný export stavů – to, co je zrovna vidět v seznamu.
  final ({Pobocka pobocka, DruhMista? druh, List<Elektromer> mista})? stavy;

  @override
  ConsumerState<ExportObrazovka> createState() => _ExportObrazovkaState();
}

class _ExportObrazovkaState extends ConsumerState<ExportObrazovka> {
  Obdobi _obdobi = Obdobi.tentoMesic();

  Future<void> _vyberObdobi() async {
    final vybrane = await vyberObdobi(context, _obdobi);
    if (vybrane != null) setState(() => _obdobi = vybrane);
  }

  Future<void> _vytvor() async {
    final rizeni = ref.read(reportControllerProvider.notifier);

    if (widget.stavy case final stavy?) {
      final sOdectem = await rizeni.vytvorStavy(
        pobocka: stavy.pobocka,
        druh: stavy.druh,
        mista: stavy.mista,
        obdobi: _obdobi,
      );
      // Tabulka vznikne i tak – minulé stavy a seznam míst bez odečtu
      // jsou užitečné samy o sobě. Jen ať je jasné, proč je prázdná.
      if (mounted && sOdectem == 0) {
        ukazVarovani(
          context,
          'Ve zvoleném období není u těchto míst žádný odečet.',
        );
      }
      return;
    }

    final pocet = await rizeni.vytvorProElektromer(
      elektromer: widget.elektromer!,
      obdobi: _obdobi,
      // Přepínač tu není: nové odečty fotku nemají a ty starší s fotkou
      // ji v PDF mají mít.
      sFotkami: true,
    );
    if (mounted && pocet == 0) {
      ukazVarovani(context, 'Ve zvoleném období tu není žádný odečet.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final stav = ref.watch(reportControllerProvider);
    final probiha = ref.read(reportControllerProvider.notifier).probiha;
    final stavy = widget.stavy;

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HlavickaToku(
              titulek: stavy != null ? 'Export stavů' : 'Export odečtů',
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
                  if (widget.elektromer case final e?) ...[
                    const NadpisSekce('Odběrné místo'),
                    Karta(
                      child: Column(
                        children: [
                          RadekDat(popisek: 'Umístění', hodnota: e.nazev),
                          RadekDat(
                            popisek: 'Druh',
                            hodnota: e.druh.nazev,
                            posledni: !e.maCislo,
                          ),
                          if (e.maCislo)
                            RadekDat(
                              popisek: 'Číslo',
                              hodnota: e.cislo,
                              posledni: true,
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (stavy != null) ...[
                    const NadpisSekce('Odběrná místa'),
                    Karta(
                      child: Column(
                        children: [
                          RadekDat(
                            popisek: 'Pobočka',
                            hodnota: stavy.pobocka.popisek,
                          ),
                          RadekDat(
                            popisek: 'Druh',
                            hodnota: stavy.druh?.nazev ?? 'všechny',
                          ),
                          RadekDat(
                            popisek: 'Počet míst',
                            hodnota: '${stavy.mista.length}',
                            posledni: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Excel s jedním řádkem na místo: minulý a nový stav, '
                      'spotřeba za období a změna proti minulému. Místa '
                      'bez odečtu v období v tabulce zůstanou.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const NadpisSekce('Období'),
                  RychlaVolbaObdobi(
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
                  if (stav case ReportChyba(:final chyba)) ...[
                    const SizedBox(height: 18),
                    ChybovyBlok(zprava: chyba.zprava),
                  ],
                  const SizedBox(height: 18),
                  PrubehReportu(stav),
                ],
              ),
            ),
            _Pata(
              probiha: probiha,
              onVytvorit: _vytvor,
              popisek: stavy != null ? 'Vytvořit tabulku' : 'Vytvořit PDF',
            ),
          ],
        ),
      ),
    );
  }
}

/// Výběr vlastního období v kalendáři. `null`, když ho člověk zavře.
Future<Obdobi?> vyberObdobi(BuildContext context, Obdobi aktualni) async {
  final ted = DateTime.now();
  final rozsah = await showDateRangePicker(
    context: context,
    // Aplikace vznikla v roce 2026, dřív žádná relace být nemůže.
    firstDate: DateTime(2026),
    lastDate: DateTime(ted.year + 1, 12, 31),
    initialDateRange: DateTimeRange(start: aktualni.od, end: aktualni.doVcetne),
    helpText: 'Zvolte období',
    saveText: 'Potvrdit',
  );
  return rozsah == null ? null : Obdobi(od: rozsah.start, doVcetne: rozsah.end);
}

/// Typický požadavek je „minulý měsíc k fakturaci", proto zkratky.
class RychlaVolbaObdobi extends StatelessWidget {
  const RychlaVolbaObdobi({
    super.key,
    required this.obdobi,
    required this.onZmena,
  });

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

class PrubehReportu extends StatelessWidget {
  const PrubehReportu(this.stav, {super.key});

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

class _Pata extends StatelessWidget {
  const _Pata({
    required this.probiha,
    required this.onVytvorit,
    required this.popisek,
  });

  final bool probiha;
  final VoidCallback onVytvorit;
  final String popisek;

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
          popisek: popisek,
          nacita: probiha,
          onTap: probiha ? null : onVytvorit,
        ),
      ),
    );
  }
}
