import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/pole.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../application/elektromery_providery.dart';
import '../domain/druh_mista.dart';
import '../domain/elektromer.dart';
import '../domain/pobocka.dart';
import 'ikona_druhu.dart';

/// Založení nového odběrného místa nebo úprava stávajícího.
///
/// Pobočka ani druh se u úpravy nemění – přestěhovaný elektroměr je jiný
/// elektroměr a míchaly by se mu odečty přes dva areály. Plynoměr
/// a elektroměr v jedné místnosti jsou taky dvě místa, ne jedno.
class FormularElektromeru extends ConsumerStatefulWidget {
  const FormularElektromeru({
    super.key,
    required this.pobocka,
    this.druh,
    this.upravuje,
  });

  final Pobocka pobocka;

  /// Předvybraný druh u nového místa – ten, na který je zrovna
  /// filtrovaný seznam. `null` znamená, že si ho uživatel vybere.
  final DruhMista? druh;
  final Elektromer? upravuje;

  bool get jeUprava => upravuje != null;

  @override
  ConsumerState<FormularElektromeru> createState() => _FormularState();
}

class _FormularState extends ConsumerState<FormularElektromeru> {
  late final _cislo = TextEditingController(text: widget.upravuje?.cislo ?? '');
  late final _nazev = TextEditingController(text: widget.upravuje?.nazev ?? '');
  late bool _aktivni = widget.upravuje?.aktivni ?? true;
  late DruhMista? _druh = widget.upravuje?.druh ?? widget.druh;

  final _fokusNazev = FocusNode();
  String? _chyba;

  @override
  void dispose() {
    _cislo.dispose();
    _nazev.dispose();
    _fokusNazev.dispose();
    super.dispose();
  }

  Future<void> _uloz() async {
    final cislo = _cislo.text.trim();
    final nazev = _nazev.text.trim();
    final druh = _druh;
    // Číslo je nepovinné: výchozí seznam míst ho nemá a místo se pozná
    // podle QR. Bez umístění by ho ale nikdo nenašel.
    if (nazev.isEmpty) {
      setState(() => _chyba = 'Vyplňte prosím umístění.');
      return;
    }
    if (druh == null) {
      setState(() => _chyba = 'Vyberte prosím, co se tu měří.');
      return;
    }

    final rizeni = ref.read(elektromeryControllerProvider.notifier);
    final upravovany = widget.upravuje;
    final povedlo = upravovany == null
        ? await rizeni.pridej(
                pobocka: widget.pobocka,
                druh: druh,
                cislo: cislo,
                nazev: nazev,
              ) !=
              null
        : await rizeni.uprav(
            elektromer: upravovany,
            cislo: cislo,
            nazev: nazev,
            aktivni: _aktivni,
          );

    if (!mounted) return;
    if (povedlo) {
      Navigator.of(context).pop();
      ukazInfo(
        context,
        upravovany == null
            ? 'Odběrné místo bylo přidáno.'
            : 'Změny byly uloženy.',
      );
    } else {
      final chyba = ref.read(elektromeryControllerProvider).error;
      if (chyba != null) {
        setState(() => _chyba = AppChyba.zFirebase(chyba).zprava);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final uklada = ref.watch(elektromeryControllerProvider).isLoading;

    // U úpravy má přednost pobočka uložená u záznamu. Kdyby ji aplikace
    // neznala (pobočka se z kódu odebrala), ukáže se aspoň holý kód.
    final upravovany = widget.upravuje;
    final pobocka = upravovany == null
        ? widget.pobocka.popisek
        : upravovany.pobocka?.popisek ?? upravovany.pobockaKod;

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HlavickaToku(
              titulek: widget.jeUprava
                  ? 'Upravit odběrné místo'
                  : 'Nové odběrné místo',
              onZpet: uklada ? null : () => Navigator.of(context).pop(),
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
                  Karta(
                    child: Column(
                      children: [
                        RadekDat(
                          popisek: 'Pobočka',
                          hodnota: pobocka,
                          posledni: upravovany == null,
                        ),
                        if (upravovany != null)
                          RadekDat(
                            popisek: 'Druh',
                            hodnota:
                                '${upravovany.druh.nazev} '
                                '(${upravovany.druh.jednotka})',
                            posledni: true,
                          ),
                      ],
                    ),
                  ),
                  if (!widget.jeUprava) ...[
                    const NadpisSekce('Co se tu měří'),
                    for (final d in DruhMista.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: VolbaKarta(
                          vybrano: _druh == d,
                          onTap: () => setState(() {
                            _druh = d;
                            _chyba = null;
                          }),
                          child: Row(
                            children: [
                              Icon(ikonaDruhu(d), size: 20, color: b.textDim),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  d.nazev,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              Text(
                                d.jednotka,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  PoleSPopiskem(
                    popisek: 'Číslo ze štítku (nepovinné)',
                    ovladac: _cislo,
                    napoveda: 'např. 18 342 771',
                    klavesnice: TextInputType.text,
                    dalsiPole: _fokusNazev,
                    onZmena: () => setState(() => _chyba = null),
                  ),
                  const SizedBox(height: 14),
                  PoleSPopiskem(
                    popisek: 'Umístění',
                    ovladac: _nazev,
                    napoveda: 'např. Hala B – rozvaděč R3',
                    fokus: _fokusNazev,
                    maxZnaku: 80,
                    velkaPismena: TextCapitalization.sentences,
                    onZmena: () => setState(() => _chyba = null),
                    onOdeslat: uklada ? null : _uloz,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Podle čísla i umístění se v seznamu vyhledává. '
                    'Umístění pište tak, aby podle něj měřidlo našel '
                    'i někdo jiný. Číslo ze štítku pomůže, když se QR '
                    'kód poškodí.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (widget.jeUprava) ...[
                    const NadpisSekce('Stav'),
                    Karta(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _aktivni,
                        onChanged: uklada
                            ? null
                            : (zapnuto) => setState(() => _aktivni = zapnuto),
                        title: Text(
                          'V provozu',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        subtitle: Text(
                          'Vyřazené místo zmizí z obchůzky, ale jeho '
                          'odečty zůstanou v historii.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ],
                  if (_chyba != null) ...[
                    const SizedBox(height: 18),
                    ChybovyBlok(zprava: _chyba!),
                  ],
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: b.surface,
                border: Border(top: BorderSide(color: b.border)),
              ),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: PrimarniTlacitko(
                  popisek: widget.jeUprava
                      ? 'Uložit změny'
                      : 'Přidat odběrné místo',
                  nacita: uklada,
                  onTap: uklada ? null : _uloz,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
