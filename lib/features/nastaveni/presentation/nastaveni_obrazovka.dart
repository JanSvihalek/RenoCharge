import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/formatovani.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/pole.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../auth/application/auth_providery.dart';
import '../../auth/domain/uzivatel.dart';
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

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider).value;
    final ukladani = ref.watch(cenaControllerProvider).isLoading;
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
