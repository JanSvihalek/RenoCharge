import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/widgety/hlaseni.dart';
import '../../reporty/application/report_controller.dart';
import '../../reporty/application/report_pdf.dart';
import '../domain/elektromer.dart';

/// Tisk QR štítků na arch etiket 4 × 10 – ze seznamu i z detailu místa.
///
/// Před tiskem se zeptá, od které etikety začít. Arch má 40 etiket
/// a dotisk jednoho poškozeného štítku by jinak spotřeboval celý nový
/// arch, nebo by se tiskl na místo, kde už etiketa chybí.
Future<void> vytiskniStitky(
  BuildContext context,
  WidgetRef ref, {
  required String popis,
  required List<Elektromer> mista,
}) async {
  if (mista.isEmpty) {
    ukazVarovani(context, 'Zatím tu není co oštítkovat.');
    return;
  }

  final prvni = await showDialog<int>(
    context: context,
    builder: (_) => _OdKtereEtikety(pocet: mista.length),
  );
  if (prvni == null || !context.mounted) return;

  await ref
      .read(reportControllerProvider.notifier)
      .vytvorStitky(popis: popis, elektromery: mista, preskocit: prvni - 1);
}

class _OdKtereEtikety extends StatefulWidget {
  const _OdKtereEtikety({required this.pocet});

  /// Kolik štítků se bude tisknout.
  final int pocet;

  @override
  State<_OdKtereEtikety> createState() => _OdKtereEtiketyState();
}

class _OdKtereEtiketyState extends State<_OdKtereEtikety> {
  final _pole = TextEditingController(text: '1');
  String? _chyba;

  @override
  void dispose() {
    _pole.dispose();
    super.dispose();
  }

  void _potvrd() {
    final cislo = int.tryParse(_pole.text.trim());
    if (cislo == null || cislo < 1 || cislo > ArchStitku.naArch) {
      setState(() => _chyba = 'Zadejte číslo 1 až ${ArchStitku.naArch}.');
      return;
    }
    Navigator.of(context).pop(cislo);
  }

  @override
  Widget build(BuildContext context) {
    final archu =
        ((int.tryParse(_pole.text.trim()) ?? 1) - 1 + widget.pocet - 1) ~/
            ArchStitku.naArch +
        1;
    return AlertDialog(
      title: Text(
        widget.pocet == 1 ? 'Tisk štítku' : 'Tisk ${widget.pocet} štítků',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Arch etiket 52,5 × 29,7 mm, 4 × 10 na A4. Pokud už jsou '
            'z archu některé etikety použité, začněte za nimi – etikety '
            'se počítají po řádcích zleva doprava.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pole,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() => _chyba = null),
            onSubmitted: (_) => _potvrd(),
            decoration: InputDecoration(
              labelText: 'Začít od etikety č.',
              errorText: _chyba,
              helperText: archu > 1
                  ? 'Vytiskne se na $archu ${archu < 5 ? 'archy' : 'archů'}.'
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tiskněte ve skutečné velikosti (100 %), bez přizpůsobení '
            'stránce – jinak štítky nesednou na etikety.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        TextButton(onPressed: _potvrd, child: const Text('Vytvořit PDF')),
      ],
    );
  }
}
