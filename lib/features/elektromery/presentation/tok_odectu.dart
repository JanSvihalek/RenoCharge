import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/formatovani.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../nabijeni/presentation/foceni_obrazovka.dart';
import '../application/odecty_controller.dart';
import '../domain/elektromer.dart';

/// Zapsání odečtu: fotka počítadla, kontrola hodnoty, zápis. Platí pro
/// všechny druhy odběrných míst, liší se jen jednotkou.
///
/// Používá **beze změny** tok focení od nabíjení – fotoaparát se otevře
/// hned, OCR předvyplní hodnotu, pole je vždy přepisovatelné a fotka jde
/// vzít z galerie.
Future<void> otevriZapisOdectu(
  BuildContext context,
  WidgetRef ref,
  Elektromer elektromer,
) async {
  final minule = elektromer.posledniOdecet;
  final jednotka = elektromer.druh.jednotka;

  final vysledek = await Navigator.of(context).push<VysledekFoceni>(
    MaterialPageRoute(
      builder: (_) => FoceniObrazovka(
        rezim: RezimFoceni.odecet,
        kwhStart: minule?.hodnota,
        jednotka: jednotka,
      ),
      fullscreenDialog: true,
    ),
  );
  if (vysledek == null || !context.mounted) return;

  final povedlo = await ref
      .read(odectyControllerProvider.notifier)
      .zapis(
        elektromer: elektromer,
        hodnota: vysledek.hodnota,
        foto: vysledek.foto,
      );
  if (!context.mounted) return;

  if (povedlo) {
    ukazInfo(
      context,
      'Odečet ${Format.kwh(vysledek.hodnota)} $jednotka byl uložen.',
    );
    return;
  }

  final chyba = ref.read(odectyControllerProvider).error;
  if (chyba == null) return;

  // Nižší hodnota než minulý odečet může být překlep, ale taky výměna
  // měřidla. Rozhodnout to umí jen člověk u elektroměru, proto se ptáme
  // místo abychom zápis odmítli.
  if (AppChyba.zFirebase(chyba) case NizsiNezMinulyOdecet(
    :final minulaHodnota,
  ) when context.mounted) {
    final vymena = await _potvrditVymenu(context, minulaHodnota, jednotka);
    if (vymena != true || !context.mounted) return;

    final naDruhy = await ref
        .read(odectyControllerProvider.notifier)
        .zapis(
          elektromer: elektromer,
          hodnota: vysledek.hodnota,
          foto: vysledek.foto,
          vymenaMeridla: true,
        );
    if (!context.mounted) return;
    if (naDruhy) {
      ukazInfo(context, 'Odečet byl uložen jako nové měřidlo.');
      return;
    }
  }

  ukazChybu(context, ref.read(odectyControllerProvider).error ?? chyba);
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
        'měřidlo. Jinak se prosím vraťte a hodnotu opravte.',
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
