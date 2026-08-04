import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../application/vozidla_providery.dart';
import '../domain/vozidlo.dart';

/// Správa vlastních vozidel. SPZ je povinná, název nepovinný.
///
/// Není to samostatná obrazovka, ale sekce vkládaná do nastavení –
/// proto vrací `Column` a ne `ListView`. Vnořený posuvník uvnitř
/// posuvníku by se choval divně.
class SekceVozidel extends ConsumerStatefulWidget {
  const SekceVozidel({super.key});

  @override
  ConsumerState<SekceVozidel> createState() => _SekceVozidelState();
}

class _SekceVozidelState extends ConsumerState<SekceVozidel> {
  final _spz = TextEditingController();
  final _nazev = TextEditingController();

  @override
  void dispose() {
    _spz.dispose();
    _nazev.dispose();
    super.dispose();
  }

  Future<void> _pridej() async {
    final povedlo = await ref
        .read(vozidlaControllerProvider.notifier)
        .pridej(spz: _spz.text, nazev: _nazev.text);
    if (!mounted) return;
    if (povedlo) {
      _spz.clear();
      _nazev.clear();
      FocusScope.of(context).unfocus();
      ukazInfo(context, 'Vozidlo bylo přidáno.');
    } else {
      final chyba = ref.read(vozidlaControllerProvider).error;
      if (chyba != null) ukazChybu(context, chyba);
    }
  }

  Future<void> _odeber(Vozidlo vozidlo) async {
    final potvrzeno = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogOdebrani(vozidlo: vozidlo),
    );
    if (potvrzeno != true || !mounted) return;

    final povedlo = await ref
        .read(vozidlaControllerProvider.notifier)
        .odeber(vozidlo.id);
    if (!mounted) return;
    if (povedlo) {
      ukazInfo(context, 'Vozidlo bylo odebráno.');
    } else {
      final chyba = ref.read(vozidlaControllerProvider).error;
      if (chyba != null) ukazChybu(context, chyba);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vozidla = ref.watch(vozidlaProvider);
    final probihaZapis = ref.watch(vozidlaControllerProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (vozidla) {
          AsyncError() => ChybovyBlok(
            zprava: 'Vozidla se nepodařilo načíst.',
            onZkusitZnovu: () => ref.invalidate(vozidlaProvider),
          ),
          AsyncData(:final value) when value.isEmpty => const PrazdnyStav(
            text:
                'Zatím tu žádné vozidlo není.\n'
                'Přidejte si ho formulářem níže.',
            ikona: Icons.directions_car_outlined,
          ),
          AsyncData(:final value) => Column(
            children: [
              for (final v in value)
                _RadekVozidla(
                  vozidlo: v,
                  onOdebrat: probihaZapis ? null : () => _odeber(v),
                ),
            ],
          ),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
        _KartaPridani(
          spz: _spz,
          nazev: _nazev,
          nacita: probihaZapis,
          onPridat: _pridej,
        ),
      ],
    );
  }
}

class _RadekVozidla extends StatelessWidget {
  const _RadekVozidla({required this.vozidlo, required this.onOdebrat});

  final Vozidlo vozidlo;
  final VoidCallback? onOdebrat;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        constraints: const BoxConstraints(minHeight: Rozmery.vyskaRadku),
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        decoration: BoxDecoration(
          color: b.surface,
          borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
          border: Border.all(color: b.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vozidlo.spz,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (vozidlo.znackaModel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      vozidlo.znackaModel!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            IkonoveTlacitko(
              ikona: Icons.close,
              barvaIkony: b.danger,
              pozadi: b.surface2,
              popisPristupnosti: 'Odebrat vozidlo ${vozidlo.spz}',
              onTap: onOdebrat,
            ),
          ],
        ),
      ),
    );
  }
}

class _KartaPridani extends StatefulWidget {
  const _KartaPridani({
    required this.spz,
    required this.nazev,
    required this.nacita,
    required this.onPridat,
  });

  final TextEditingController spz;
  final TextEditingController nazev;
  final bool nacita;
  final VoidCallback onPridat;

  @override
  State<_KartaPridani> createState() => _KartaPridaniState();
}

class _KartaPridaniState extends State<_KartaPridani> {
  @override
  Widget build(BuildContext context) {
    final lzePridat = widget.spz.text.trim().isNotEmpty && !widget.nacita;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Karta(
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Přidat vozidlo',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.spz,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'SPZ, např. 5AB 1234',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.nazev,
              decoration: const InputDecoration(hintText: 'Název (nepovinné)'),
            ),
            const SizedBox(height: 12),
            PrimarniTlacitko(
              popisek: 'Přidat vozidlo',
              ikona: Icons.add,
              vyska: Rozmery.dotykMin,
              nacita: widget.nacita,
              onTap: lzePridat ? widget.onPridat : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogOdebrani extends StatelessWidget {
  const _DialogOdebrani({required this.vozidlo});

  final Vozidlo vozidlo;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return AlertDialog(
      backgroundColor: b.surface,
      title: Text(
        'Odebrat vozidlo?',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      content: Text(
        '${vozidlo.spz} zmizí ze seznamu pro výběr při nabíjení. '
        'Už uložené relace zůstanou v historii beze změny.',
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
          child: Text('Odebrat', style: TextStyle(color: b.danger)),
        ),
      ],
    );
  }
}
