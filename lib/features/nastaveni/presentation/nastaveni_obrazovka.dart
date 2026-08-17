import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/pole.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../auth/application/auth_providery.dart';
import '../../auth/domain/uzivatel.dart';
import '../../nabijeni/application/zaloha_fotek.dart';
import '../../vozidla/presentation/sekce_vozidel.dart';
import '../application/nastaveni_controller.dart';

/// Nastavení: předpokládaná cena za kWh a přehled údajů z profilu.
class NastaveniObrazovka extends ConsumerStatefulWidget {
  const NastaveniObrazovka({super.key});

  @override
  ConsumerState<NastaveniObrazovka> createState() => _NastaveniObrazovkaState();
}

class _NastaveniObrazovkaState extends ConsumerState<NastaveniObrazovka> {
  final _cena = TextEditingController();

  /// Dokud uživatel do pole nesáhl, drží se hodnoty z profilu. Po první
  /// úpravě už ne – jinak by mu příchozí snímek z Firestore přepsal
  /// rozepsané číslo pod rukama.
  bool _upravovano = false;
  String? _chyba;

  @override
  void dispose() {
    _cena.dispose();
    super.dispose();
  }

  void _predvyplnZProfilu(Uzivatel? profil) {
    if (_upravovano) return;
    final cena = profil?.cenaZaKwh;
    final text = cena == null ? '' : Format.kwh(cena).replaceAll(' ', '');
    if (_cena.text != text) _cena.text = text;
  }

  Future<void> _uloz() async {
    final hodnota = Format.parsujKwh(_cena.text);
    if (hodnota == null || hodnota <= 0) {
      setState(
        () => _chyba = 'Zadejte prosím cenu jako kladné číslo, například 6,50.',
      );
      return;
    }
    if (hodnota >= 1000) {
      setState(
        () => _chyba =
            'Tolik za kilowatthodinu opravdu neplatíte. '
            'Zkontrolujte prosím hodnotu.',
      );
      return;
    }

    final povedlo = await ref
        .read(cenaControllerProvider.notifier)
        .uloz(hodnota);
    if (!mounted) return;
    if (povedlo) {
      setState(() {
        _chyba = null;
        _upravovano = false;
      });
      FocusScope.of(context).unfocus();
      ukazInfo(context, 'Cena byla uložena.');
    }
  }

  Future<void> _smaz() async {
    final povedlo = await ref.read(cenaControllerProvider.notifier).uloz(null);
    if (!mounted) return;
    if (povedlo) {
      setState(() {
        _chyba = null;
        _upravovano = false;
        _cena.clear();
      });
      FocusScope.of(context).unfocus();
      ukazInfo(context, 'Cena byla odebrána, přepočet se přestane zobrazovat.');
    }
  }

  Future<void> _prepniZalohu(bool zapnuto) async {
    final povedlo = await ref
        .read(zalohaControllerProvider.notifier)
        .nastav(zapnuto: zapnuto);
    if (!mounted) return;
    if (povedlo) {
      ukazInfo(
        context,
        zapnuto
            ? 'Vyfocená počítadla se budou ukládat i do galerie.'
            : 'Kopie do galerie se přestanou ukládat.',
      );
      return;
    }
    final chyba = ref.read(zalohaControllerProvider).error;
    if (chyba != null) ukazChybu(context, chyba);
  }

  /// Odhlášení se ptá na potvrzení. Není destruktivní – žádná data
  /// nezmizí – ale zpátky se člověk dostane jen s heslem, které u sebe
  /// v terénu mít nemusí. Jedno klepnutí navíc je levnější než to.
  Future<void> _odhlas() async {
    final profil = ref.read(profilProvider).value;
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogOdhlaseni(
        email: profil?.email ?? '',
        maOtevrenouRelaci: profil?.maOtevrenouRelaci ?? false,
      ),
    );
    if (potvrzeno != true || !mounted) return;

    await ref.read(prihlaseniControllerProvider.notifier).odhlas();
    // Při úspěchu je tahle obrazovka pryč – kořen aplikace přepne na
    // přihlášení, jakmile se změní stav v Firebase Auth.
    if (!mounted) return;
    final chyba = ref.read(prihlaseniControllerProvider).error;
    if (chyba != null) ukazChybu(context, chyba);
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider).value;
    final ukladani = ref.watch(cenaControllerProvider).isLoading;
    final odhlasovani = ref.watch(prihlaseniControllerProvider).isLoading;
    final zalohovani = ref.watch(zalohaControllerProvider).isLoading;
    _predvyplnZProfilu(profil);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Rozmery.okrajStranky,
        0,
        Rozmery.okrajStranky,
        24,
      ),
      children: [
        const VelkyNadpis('Nastavení'),

        const NadpisSekce('Moje vozidla'),
        const SekceVozidel(),

        const NadpisSekce('Přepočet ceny'),
        Karta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PoleSPopiskem(
                popisek: 'Předpokládaná cena za kWh',
                ovladac: _cena,
                napoveda: 'např. 6,50',
                klavesnice: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                pripona: const Text('Kč'),
                onZmena: () => setState(() {
                  _upravovano = true;
                  _chyba = null;
                }),
                onOdeslat: ukladani ? null : _uloz,
              ),
              const SizedBox(height: 10),
              // Fakturuje se mimo aplikaci a možná jinou sazbou. Uživatel
              // to musí vědět dřív, než si částku splete s tou skutečnou.
              _Vysvetlivka(
                'Podle téhle sazby se u dokončených nabíjení ukáže '
                'orientační částka. Slouží jen pro vaši představu – '
                'fakturuje se mimo aplikaci a skutečná sazba se může lišit. '
                'Do PDF reportu se částka nedává.',
              ),
              if (_chyba != null) ...[
                const SizedBox(height: 12),
                ChybovyBlok(zprava: _chyba!),
              ],
              const SizedBox(height: 14),
              PrimarniTlacitko(
                popisek: 'Uložit cenu',
                nacita: ukladani,
                vyska: Rozmery.dotykMin,
                onTap: ukladani ? null : _uloz,
              ),
              if (profil?.maZadanouCenu ?? false)
                OdkazoveTlacitko(
                  popisek: 'Přestat zobrazovat ceny',
                  onTap: ukladani ? null : _smaz,
                ),
            ],
          ),
        ),

        const NadpisSekce('Fotografie'),
        Karta(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: profil?.zalohovatFotky ?? false,
            onChanged: zalohovani ? null : _prepniZalohu,
            title: Text(
              'Ukládat kopie do galerie',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            subtitle: Text(
              'Vyfocená počítadla nabíječky i elektroměrů se uloží také '
              'do telefonu, do albumu $albumZaloh. Aplikace je odtud '
              'nikdy nečte – je to záloha pro vás.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),

        const NadpisSekce('Účet'),
        Karta(
          child: Column(
            children: [
              RadekDat(popisek: 'Jméno', hodnota: profil?.jmeno ?? '—'),
              RadekDat(
                popisek: 'Osobní číslo',
                hodnota: profil?.osobniCislo ?? '—',
              ),
              RadekDat(popisek: 'E-mail', hodnota: profil?.email ?? '—'),
              // Role se ukazuje, aby si člověk mohl ověřit, co v aplikaci
              // smí, když mu něco chybí. Měnit ji tady nejde schválně.
              RadekDat(
                popisek: 'Oprávnění',
                hodnota: (profil?.role ?? Role.uzivatel).popisek,
                posledni: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _Vysvetlivka(
          'Jméno a osobní číslo mění správce. Pokud něco nesedí, ozvěte se mu.',
        ),
        const SizedBox(height: 16),
        // Tlumené, ne červené: odhlášení nic nesmaže. Červená by tu
        // znamenala nebezpečí, které tady není.
        PrimarniTlacitko(
          popisek: 'Odhlásit se',
          ikona: Icons.logout,
          vyska: Rozmery.dotykMin,
          barvaPozadi: context.barvy.surface2,
          barvaTextu: context.barvy.text,
          nacita: odhlasovani,
          onTap: odhlasovani ? null : _odhlas,
        ),
      ],
    );
  }
}

class _DialogOdhlaseni extends StatelessWidget {
  const _DialogOdhlaseni({
    required this.email,
    required this.maOtevrenouRelaci,
  });

  final String email;

  /// Rozjeté nabíjení se odhlášením neztratí – jen na něj po přihlášení
  /// musí uživatel nezapomenout navázat, jinak zůstane viset otevřené.
  final bool maOtevrenouRelaci;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return AlertDialog(
      backgroundColor: b.surface,
      title: Text(
        'Odhlásit se?',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      content: Text(
        [
          if (email.isNotEmpty)
            'Aplikace se odhlásí z účtu $email. Zpátky se dostanete '
                'jen s heslem.'
          else
            'Zpátky do aplikace se dostanete jen s heslem.',
          if (maOtevrenouRelaci)
            'Máte rozjeté nabíjení. Nezmizí – po přihlášení ho najdete '
                'otevřené a budete ho moct dokončit.',
        ].join('\n\n'),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Zrušit', style: TextStyle(color: b.textDim)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Odhlásit', style: TextStyle(color: b.danger)),
        ),
      ],
    );
  }
}

class _Vysvetlivka extends StatelessWidget {
  const _Vysvetlivka(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodySmall);
}
