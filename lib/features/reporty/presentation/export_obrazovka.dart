import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../elektromery/domain/elektromer.dart';
import '../application/exporty_providery.dart';
import '../application/report_controller.dart';
import '../domain/report.dart';
import '../domain/zaznam_exportu.dart';

/// Výběr období a vytvoření PDF reportu. Hotové PDF se předá
/// systémovému sdílení, odkud se dá poslat mailem.
///
/// Jedna obrazovka pro obojí: bez [elektromer] vyrobí report vlastních
/// nabíjení, s ním report toho elektroměru. Pro uživatele je to tatáž
/// operace, jen nad jinými daty – dvě skoro stejné obrazovky by se
/// časem rozešly.
class ExportObrazovka extends ConsumerStatefulWidget {
  const ExportObrazovka({super.key, this.elektromer});

  final Elektromer? elektromer;

  @override
  ConsumerState<ExportObrazovka> createState() => _ExportObrazovkaState();
}

/// Co z exportu vypadne. Tabulka je jen u nabíjení – u elektroměru je
/// zajímavý vývoj spotřeby s fotkami, ne sloupec čísel do Excelu.
enum _Format {
  pdf('PDF', 'Přehled se souhrnem, volitelně s fotkami počítadla.'),
  xlsx('Excel', 'Tabulka: datum, vozidlo, stavy počítadla a součet.');

  const _Format(this.popisek, this.popis);

  final String popisek;
  final String popis;
}

class _ExportObrazovkaState extends ConsumerState<ExportObrazovka> {
  Obdobi _obdobi = Obdobi.tentoMesic();
  bool _sFotkami = true;
  _Format _format = _Format.pdf;

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
    final elektromer = widget.elektromer;

    final pocet = switch ((elektromer, _format)) {
      (final e?, _) => await rizeni.vytvorProElektromer(
        elektromer: e,
        obdobi: _obdobi,
        sFotkami: _sFotkami,
      ),
      (_, _Format.xlsx) => await rizeni.vytvorTabulku(obdobi: _obdobi),
      _ => await rizeni.vytvorASdilej(obdobi: _obdobi, sFotkami: _sFotkami),
    };
    if (!mounted || pocet == null) return;

    if (pocet == 0) {
      ukazVarovani(
        context,
        elektromer == null
            ? 'Ve zvoleném období není žádné dokončené nabíjení.'
            : 'Ve zvoleném období není u tohoto elektroměru žádný odečet.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final stav = ref.watch(reportControllerProvider);
    final probiha = ref.read(reportControllerProvider.notifier).probiha;
    // Poslední report se hlídá jen u nabíjení – u elektroměru se exportuje
    // podle potřeby, ne měsíc po měsíci bez děr.
    final posledni = widget.elektromer == null
        ? ref.watch(posledniExportProvider)
        : null;

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HlavickaToku(
              titulek: widget.elektromer == null
                  ? 'Export nabíjení'
                  : 'Export odečtů',
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
                    const NadpisSekce('Elektroměr'),
                    Karta(
                      child: Column(
                        children: [
                          RadekDat(popisek: 'Umístění', hodnota: e.nazev),
                          RadekDat(
                            popisek: 'Číslo',
                            hodnota: e.cislo,
                            posledni: true,
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  if (posledni != null) ...[
                    const SizedBox(height: 10),
                    _PosledniExport(
                      export: posledni,
                      onNavazat: probiha
                          ? null
                          : (nove) => setState(() => _obdobi = nove),
                    ),
                  ],
                  const SizedBox(height: 10),
                  OdkazoveTlacitko(
                    popisek: 'Zvolit jiné období',
                    onTap: probiha ? null : _vyberObdobi,
                  ),
                  if (widget.elektromer == null) ...[
                    const NadpisSekce('Formát'),
                    _VolbaFormatu(
                      vybrany: _format,
                      onZmena: probiha
                          ? null
                          : (novy) => setState(() => _format = novy),
                    ),
                  ],

                  // Fotky jsou jen v PDF. Do tabulky nepatří a přepínač,
                  // který na výsledek nemá vliv, jen mate.
                  if (_format == _Format.pdf) ...[
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
                          'Fotky počítadla se do PDF vloží zmenšené, aby se '
                          'report dal poslat mailem. Bez nich je soubor '
                          'o poznání menší a vytvoří se hned.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                  if (stav case ReportChyba(:final chyba)) ...[
                    const SizedBox(height: 18),
                    ChybovyBlok(zprava: chyba.zprava),
                  ],
                  const SizedBox(height: 18),
                  _Prubeh(stav),
                ],
              ),
            ),
            _Pata(
              probiha: probiha,
              onVytvorit: _vytvor,
              popisek: widget.elektromer == null && _format == _Format.xlsx
                  ? 'Vytvořit tabulku'
                  : 'Vytvořit PDF',
            ),
          ],
        ),
      ),
    );
  }
}

/// Volba mezi PDF a tabulkou. Popis pod názvem schválně: „Excel" sám
/// o sobě neřekne, že v něm nebudou fotky ani souhrn, jen řádky a součet.
class _VolbaFormatu extends StatelessWidget {
  const _VolbaFormatu({required this.vybrany, required this.onZmena});

  final _Format vybrany;
  final ValueChanged<_Format>? onZmena;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final format in _Format.values) ...[
          if (format != _Format.values.first) const SizedBox(height: 10),
          VolbaKarta(
            vybrano: vybrany == format,
            onTap: () => onZmena?.call(format),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  format.popisek,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  format.popis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Kdy vznikl poslední report a nabídka navázat na něj.
///
/// Tohle je odpověď na otázku „od kdy mám dělat příští report". Bez ní
/// si ji člověk musí pamatovat sám, nebo dohledávat v odeslané poště.
class _PosledniExport extends StatelessWidget {
  const _PosledniExport({required this.export, required this.onNavazat});

  final ZaznamExportu export;

  /// `null`, když právě běží vytváření reportu.
  final ValueChanged<Obdobi>? onNavazat;

  @override
  Widget build(BuildContext context) {
    final navazujici = Obdobi.navazujici(export.obdobi.doVcetne);

    return Karta(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Neutrální formulace schválně – aplikaci používají muži i ženy
          // a „vytvořil jste" by polovinu z nich oslovovalo špatně.
          Text(
            'Reporty zatím pokryly nabíjení do '
            '${Format.datum(export.obdobi.doVcetne)} '
            '(vytvořeno ${Format.datum(export.vytvorenoAt)}).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (navazujici == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Všechna nabíjení do dneška už report pokrývá.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            OdkazoveTlacitko(
              popisek:
                  'Navázat: ${Format.datum(navazujici.od)} – '
                  '${Format.datum(navazujici.doVcetne)}',
              onTap: onNavazat == null ? null : () => onNavazat!(navazujici),
            ),
        ],
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
