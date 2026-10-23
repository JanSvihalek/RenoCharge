import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/formatovani.dart';
import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/motiv.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/tlacitka.dart';
import '../application/odecty_controller.dart';
import '../domain/elektromer.dart';

/// Zapsání odečtu: ruční zadání stavu, kontrola, zápis. Platí pro všechny
/// druhy odběrných míst, liší se jen jednotkou.
///
/// **Bez fotky.** Údržba ji podle zadavatele nepotřebuje – místo se pozná
/// načtením QR a stav se opíše z displeje. Fotku počítadla si nechává jen
/// nabíjení, kde slouží jako doklad k fakturaci.
///
/// Když je stav nižší než minule, aplikace se zeptá, jestli se měnilo
/// měřidlo. Při „Opravit hodnotu" se zadání otevře znovu s tím, co
/// člověk napsal – nemusí znovu skenovat.
Future<void> otevriZapisOdectu(
  BuildContext context,
  WidgetRef ref,
  Elektromer elektromer,
) async {
  final jednotka = elektromer.druh.jednotka;
  final rizeni = ref.read(odectyControllerProvider.notifier);
  String? predvyplneno;

  while (true) {
    final hodnota = await _zadejStav(context, elektromer, predvyplneno);
    if (hodnota == null || !context.mounted) return;

    if (await rizeni.zapis(elektromer: elektromer, hodnota: hodnota)) {
      if (context.mounted) {
        ukazInfo(context, 'Odečet ${Format.kwh(hodnota)} $jednotka uložen.');
      }
      return;
    }
    if (!context.mounted) return;

    final chyba = ref.read(odectyControllerProvider).error;
    if (chyba == null) return;

    // Nižší hodnota než minulý odečet může být překlep, ale taky výměna
    // měřidla. Rozhodnout to umí jen člověk u měřidla, proto se ptáme
    // místo abychom zápis odmítli.
    if (AppChyba.zFirebase(chyba) case NizsiNezMinulyOdecet(
      :final minulaHodnota,
    )) {
      final vymena = await _potvrditVymenu(context, minulaHodnota, jednotka);
      if (vymena == null || !context.mounted) return;

      if (!vymena) {
        predvyplneno = Format.kwh(hodnota);
        continue;
      }

      final naDruhy = await rizeni.zapis(
        elektromer: elektromer,
        hodnota: hodnota,
        vymenaMeridla: true,
      );
      if (!context.mounted) return;
      if (naDruhy) {
        ukazInfo(context, 'Odečet byl uložen jako nové měřidlo.');
        return;
      }
    }

    ukazChybu(context, ref.read(odectyControllerProvider).error ?? chyba);
    return;
  }
}

/// Panel zespodu s polem na stav. Panel, ne celá obrazovka: po načtení
/// QR je člověk u měřidla a potřebuje jen napsat číslo – klávesnice
/// naskočí rovnou a nad ní zůstane vidět, co se odečítá.
Future<double?> _zadejStav(
  BuildContext context,
  Elektromer elektromer,
  String? predvyplneno,
) {
  final b = context.barvy;
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: b.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        _ZadaniStavu(elektromer: elektromer, predvyplneno: predvyplneno),
  );
}

class _ZadaniStavu extends StatefulWidget {
  const _ZadaniStavu({required this.elektromer, this.predvyplneno});

  final Elektromer elektromer;
  final String? predvyplneno;

  @override
  State<_ZadaniStavu> createState() => _ZadaniStavuState();
}

class _ZadaniStavuState extends State<_ZadaniStavu> {
  late final _pole = TextEditingController(text: widget.predvyplneno ?? '');
  String? _chyba;

  @override
  void dispose() {
    _pole.dispose();
    super.dispose();
  }

  void _uloz() {
    final hodnota = Format.parsujKwh(_pole.text);
    if (hodnota == null) {
      setState(
        () => _chyba = 'Zadejte prosím stav jako číslo, například 12 486,7.',
      );
      return;
    }
    Navigator.of(context).pop(hodnota);
  }

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    final e = widget.elektromer;
    final jednotka = e.druh.jednotka;
    final minule = e.posledniOdecet;
    final zadano = Format.parsujKwh(_pole.text);
    // Spotřeba od minula hned pod polem. Bez fotky je překlep o řád
    // největší riziko a „+12 400 kWh" místo obvyklých stovek je vidět
    // na první pohled.
    final rozdil = (zadano != null && minule != null)
        ? zadano - minule.hodnota
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(e.nazev, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            [e.druh.nazev, if (e.maCislo) 'č. ${e.cislo}'].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Text(
            minule == null
                ? 'První odečet tohoto místa.'
                : 'Minule ${Format.kwh(minule.hodnota)} $jednotka '
                      '(${Format.datum(minule.odectenoAt)})',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: b.textDim),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: b.surface2,
              borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pole,
                    autofocus: true,
                    onChanged: (_) => setState(() => _chyba = null),
                    onSubmitted: (_) => _uloz(),
                    textInputAction: TextInputAction.done,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]')),
                    ],
                    style: Motiv.pocitadlo(b),
                    decoration: const InputDecoration(
                      hintText: 'Nový stav',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                Text(
                  jednotka,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: b.textDim),
                ),
              ],
            ),
          ),
          if (_chyba != null || rozdil != null) ...[
            const SizedBox(height: 8),
            Text(
              _chyba ??
                  (rozdil! < 0
                      ? 'Nižší než minule – zeptáme se na výměnu měřidla.'
                      : 'Od minula +${Format.kwh(rozdil)} $jednotka'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _chyba != null || rozdil! < 0 ? b.danger : b.accent,
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimarniTlacitko(popisek: 'Uložit odečet', vyska: 58, onTap: _uloz),
        ],
      ),
    );
  }
}

Future<bool?> _potvrditVymenu(
  BuildContext context,
  double minula,
  String jednotka,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        'Nižší než minulý odečet',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      content: Text(
        'Minule tu bylo ${Format.kwh(minula)} $jednotka. Pokud se měřidlo '
        'vyměnilo a počítadlo začalo od nuly, zapíšeme to jako nové '
        'měřidlo. Jinak hodnotu opravte.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Opravit hodnotu'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Měřidlo vyměněno'),
        ),
      ],
    ),
  );
}
