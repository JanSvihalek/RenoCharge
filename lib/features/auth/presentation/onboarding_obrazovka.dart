import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/pole.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../application/auth_providery.dart';
import '../application/onboarding_controller.dart';
import '../domain/uzivatel.dart';

/// Úvodní nastavení po prvním přihlášení.
///
/// Sbírá to, co aplikace potřebuje a co jí přihlašovací účet nedá:
/// jméno do pozdravu, osobní číslo pro párování při fakturaci a první
/// vozidlo, bez kterého nejde nabíjení zahájit.
class OnboardingObrazovka extends ConsumerStatefulWidget {
  const OnboardingObrazovka({super.key, required this.profil});

  final Uzivatel? profil;

  @override
  ConsumerState<OnboardingObrazovka> createState() =>
      _OnboardingObrazovkaState();
}

class _OnboardingObrazovkaState extends ConsumerState<OnboardingObrazovka> {
  late final TextEditingController _jmeno;
  final _osobniCislo = TextEditingController();
  final _spz = TextEditingController();
  final _znacka = TextEditingController();

  final _osobniCisloFokus = FocusNode();
  final _spzFokus = FocusNode();
  final _znackaFokus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Jméno odvozené z e-mailu je jen návrh – uživatel ho přepíše
    // na tvar s diakritikou.
    _jmeno = TextEditingController(text: widget.profil?.jmeno ?? '');
  }

  @override
  void dispose() {
    _jmeno.dispose();
    _osobniCislo.dispose();
    _spz.dispose();
    _znacka.dispose();
    _osobniCisloFokus.dispose();
    _spzFokus.dispose();
    _znackaFokus.dispose();
    super.dispose();
  }

  bool get _lzeDokoncit =>
      _jmeno.text.trim().isNotEmpty &&
      _osobniCislo.text.trim().isNotEmpty &&
      _spz.text.trim().isNotEmpty;

  Future<void> _dokonci() async {
    if (!_lzeDokoncit) return;
    FocusScope.of(context).unfocus();
    // Po úspěchu se změní profil a obrazovku vystřídá hlavní rámec;
    // případná chyba zůstane ve stavu a vykreslí se nad patou.
    await ref
        .read(onboardingControllerProvider.notifier)
        .dokonci(
          jmeno: _jmeno.text,
          osobniCislo: _osobniCislo.text,
          spz: _spz.text,
          znackaModel: _znacka.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final stav = ref.watch(onboardingControllerProvider);

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Rozmery.okrajStranky,
                  32,
                  Rozmery.okrajStranky,
                  8,
                ),
                children: [
                  Text(
                    'Ještě než začneme',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tyhle údaje potřebujeme jen jednou. Vozidel si můžete '
                    'později přidat víc v záložce Vozidla.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: b.textDim),
                  ),
                  const NadpisSekce('O vás'),
                  PoleSPopiskem(
                    popisek: 'Jméno a příjmení',
                    ovladac: _jmeno,
                    napoveda: 'Jana Nováková',
                    velkaPismena: TextCapitalization.words,
                    maxZnaku: 80,
                    dalsiPole: _osobniCisloFokus,
                    onZmena: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  PoleSPopiskem(
                    popisek: 'Osobní číslo',
                    ovladac: _osobniCislo,
                    fokus: _osobniCisloFokus,
                    napoveda: 'podle firemní evidence',
                    velkaPismena: TextCapitalization.characters,
                    maxZnaku: 40,
                    dalsiPole: _spzFokus,
                    onZmena: () => setState(() {}),
                  ),
                  const NadpisSekce('Vaše vozidlo'),
                  PoleSPopiskem(
                    popisek: 'SPZ',
                    ovladac: _spz,
                    fokus: _spzFokus,
                    napoveda: 'např. 5AB 1234',
                    velkaPismena: TextCapitalization.characters,
                    maxZnaku: 20,
                    dalsiPole: _znackaFokus,
                    onZmena: () => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  PoleSPopiskem(
                    popisek: 'Značka a model (nepovinné)',
                    ovladac: _znacka,
                    fokus: _znackaFokus,
                    napoveda: 'Škoda Octavia',
                    velkaPismena: TextCapitalization.words,
                    maxZnaku: 60,
                    onOdeslat: _dokonci,
                    onZmena: () => setState(() {}),
                  ),
                  if (stav.hasError) ...[
                    const SizedBox(height: 18),
                    ChybovyBlok(zprava: AppChyba.zFirebase(stav.error!).zprava),
                  ],
                ],
              ),
            ),
            _Pata(
              povoleno: _lzeDokoncit,
              nacita: stav.isLoading,
              onDokoncit: _dokonci,
              onOdhlasit: () =>
                  ref.read(prihlaseniControllerProvider.notifier).odhlas(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pata extends StatelessWidget {
  const _Pata({
    required this.povoleno,
    required this.nacita,
    required this.onDokoncit,
    required this.onOdhlasit,
  });

  final bool povoleno;
  final bool nacita;
  final VoidCallback onDokoncit;
  final VoidCallback onOdhlasit;

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
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          children: [
            PrimarniTlacitko(
              popisek: 'Pokračovat do aplikace',
              nacita: nacita,
              onTap: povoleno ? onDokoncit : null,
            ),
            // Záchranná cesta, když se někdo přihlásí pod cizím účtem.
            OdkazoveTlacitko(
              popisek: 'Odhlásit se',
              onTap: nacita ? null : onOdhlasit,
            ),
          ],
        ),
      ),
    );
  }
}
