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
import '../domain/elektromer.dart';
import '../domain/pobocka.dart';

/// Založení nového elektroměru nebo úprava stávajícího.
///
/// Pobočka se u úpravy nemění – přestěhovaný elektroměr je jiný
/// elektroměr a míchaly by se mu odečty přes dva areály.
class FormularElektromeru extends ConsumerStatefulWidget {
  const FormularElektromeru({super.key, required this.pobocka, this.upravuje});

  final Pobocka pobocka;
  final Elektromer? upravuje;

  bool get jeUprava => upravuje != null;

  @override
  ConsumerState<FormularElektromeru> createState() => _FormularState();
}

class _FormularState extends ConsumerState<FormularElektromeru> {
  late final _cislo = TextEditingController(text: widget.upravuje?.cislo ?? '');
  late final _nazev = TextEditingController(text: widget.upravuje?.nazev ?? '');
  late bool _aktivni = widget.upravuje?.aktivni ?? true;

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
    if (cislo.isEmpty || nazev.isEmpty) {
      setState(() => _chyba = 'Vyplňte prosím číslo ze štítku i umístění.');
      return;
    }

    final rizeni = ref.read(elektromeryControllerProvider.notifier);
    final upravovany = widget.upravuje;
    final povedlo = upravovany == null
        ? await rizeni.pridej(
                pobocka: widget.pobocka,
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
        upravovany == null ? 'Elektroměr byl přidán.' : 'Změny byly uloženy.',
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
                  ? 'Upravit elektroměr'
                  : 'Nový elektroměr',
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
                    child: RadekDat(
                      popisek: 'Pobočka',
                      hodnota: pobocka,
                      posledni: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PoleSPopiskem(
                    popisek: 'Číslo ze štítku',
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
                    'Umístění pište tak, aby podle něj elektroměr našel '
                    'i někdo jiný.',
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
                          'Vyřazený elektroměr zmizí z obchůzky, ale jeho '
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
                      : 'Přidat elektroměr',
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
