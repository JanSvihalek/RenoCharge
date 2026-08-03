import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motiv/barvy.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/pole.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../application/auth_providery.dart';

/// Jediná obrazovka, kam se dostane nepřihlášený uživatel.
///
/// Registrace tu záměrně není – účty zakládá správce. Přihlašuje se
/// e-mailem a heslem; až bude hotová registrace v Entra ID, nahradí to
/// tlačítko „Přihlásit se firemním účtem".
class PrihlaseniObrazovka extends ConsumerStatefulWidget {
  const PrihlaseniObrazovka({super.key});

  @override
  ConsumerState<PrihlaseniObrazovka> createState() =>
      _PrihlaseniObrazovkaState();
}

class _PrihlaseniObrazovkaState extends ConsumerState<PrihlaseniObrazovka> {
  final _email = TextEditingController();
  final _heslo = TextEditingController();
  final _hesloFokus = FocusNode();
  bool _hesloViditelne = false;

  @override
  void dispose() {
    _email.dispose();
    _heslo.dispose();
    _hesloFokus.dispose();
    super.dispose();
  }

  bool get _lzePrihlasit =>
      _email.text.trim().isNotEmpty && _heslo.text.isNotEmpty;

  Future<void> _prihlas() async {
    if (!_lzePrihlasit) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(prihlaseniControllerProvider.notifier)
        .prihlas(email: _email.text, heslo: _heslo.text);
    // Po úspěchu obrazovku vystřídá hlavní rámec, chybu vykreslíme níž.
  }

  Future<void> _zapomenuteHeslo() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ukazVarovani(context, 'Nejdřív prosím vyplňte e-mail.');
      return;
    }
    final odeslano = await ref
        .read(prihlaseniControllerProvider.notifier)
        .posliResetHesla(email);
    if (!mounted || !odeslano) return;
    ukazInfo(
      context,
      'Pokud účet s tímhle e-mailem existuje, poslali jsme na něj '
      'odkaz pro nastavení hesla.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final stav = ref.watch(prihlaseniControllerProvider);
    final chyba = PrihlaseniController.chybovaHlaska(stav);

    return Scaffold(
      backgroundColor: b.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 48, 28, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: b.accentDim,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.bolt, size: 30, color: b.accent),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Nabíjecí deník',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        'Evidence nabíjení firemních vozidel v areálu',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: b.textDim,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    PoleSPopiskem(
                      popisek: 'Pracovní e-mail',
                      ovladac: _email,
                      klavesnice: TextInputType.emailAddress,
                      napoveda: 'jmeno@firma.cz',
                      dalsiPole: _hesloFokus,
                      onZmena: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    PoleSPopiskem(
                      popisek: 'Heslo',
                      ovladac: _heslo,
                      fokus: _hesloFokus,
                      skryty: !_hesloViditelne,
                      onOdeslat: _prihlas,
                      onZmena: () => setState(() {}),
                      pripona: IkonoveTlacitko(
                        ikona: _hesloViditelne
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        popisPristupnosti: _hesloViditelne
                            ? 'Skrýt heslo'
                            : 'Zobrazit heslo',
                        sOramovanim: false,
                        barvaIkony: b.textDim,
                        onTap: () =>
                            setState(() => _hesloViditelne = !_hesloViditelne),
                      ),
                    ),
                    if (chyba != null) ...[
                      const SizedBox(height: 18),
                      ChybovyBlok(zprava: chyba),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              child: Column(
                children: [
                  PrimarniTlacitko(
                    popisek: 'Přihlásit se',
                    nacita: stav.isLoading,
                    onTap: _lzePrihlasit ? _prihlas : null,
                  ),
                  OdkazoveTlacitko(
                    popisek: 'Zapomenuté heslo',
                    onTap: stav.isLoading ? null : _zapomenuteHeslo,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Přístup pouze pro zaměstnance autosalonu. '
                    'Účet vám založí správce.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: b.textFaint,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
