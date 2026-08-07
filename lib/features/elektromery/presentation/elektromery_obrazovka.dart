import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../application/elektromery_providery.dart';
import '../domain/elektromer.dart';
import '../domain/pobocka.dart';
import 'elektromer_obrazovka.dart';
import 'formular_elektromeru.dart';

/// Seznam elektroměrů zvolené pobočky.
///
/// Až přibudou odečty, stane se z téhle obrazovky zároveň obchůzka –
/// rozdělení na „zbývá / hotovo" se dopočítá z posledního odečtu, žádná
/// zvláštní entita nevznikne.
class ElektromeryObrazovka extends ConsumerWidget {
  const ElektromeryObrazovka({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pobocka = ref.watch(vybranaPobockaProvider);
    final dotaz = ref.watch(hledaniProvider);
    final elektromery = ref.watch(elektromeryProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Rozmery.okrajStranky,
        0,
        Rozmery.okrajStranky,
        24,
      ),
      children: [
        VelkyNadpis(
          'Elektroměry',
          akce: IkonoveTlacitko(
            ikona: Icons.add,
            popisPristupnosti: 'Přidat elektroměr',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FormularElektromeru(pobocka: pobocka),
              ),
            ),
          ),
        ),
        _VyberPobocky(
          vybrana: pobocka,
          onZmena: (nova) =>
              ref.read(vybranaPobockaProvider.notifier).vyber(nova),
        ),
        const SizedBox(height: 12),
        _PoleHledani(
          hodnota: dotaz,
          onZmena: (text) => ref.read(hledaniProvider.notifier).nastav(text),
        ),
        const SizedBox(height: 16),
        switch (elektromery) {
          AsyncError() => ChybovyBlok(
            zprava: 'Elektroměry se nepodařilo načíst.',
            onZkusitZnovu: () => ref.invalidate(elektromeryProvider),
          ),
          AsyncData(:final value) => _Seznam(vsechny: value, dotaz: dotaz),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

class _Seznam extends StatelessWidget {
  const _Seznam({required this.vsechny, required this.dotaz});

  final List<Elektromer> vsechny;
  final String dotaz;

  @override
  Widget build(BuildContext context) {
    final nalezene = [
      for (final e in vsechny)
        if (e.odpovidaHledani(dotaz)) e,
    ];
    final vProvozu = [
      for (final e in nalezene)
        if (e.aktivni) e,
    ];
    final vyrazene = [
      for (final e in nalezene)
        if (!e.aktivni) e,
    ];

    if (vsechny.isEmpty) {
      return const PrazdnyStav(
        text:
            'Na této pobočce zatím není žádný elektroměr.\n'
            'Přidejte ho tlačítkem nahoře.',
        ikona: Icons.electric_meter_outlined,
      );
    }
    if (nalezene.isEmpty) {
      return const PrazdnyStav(
        text: 'Hledání neodpovídá žádný elektroměr.',
        ikona: Icons.search_off,
      );
    }

    return Column(
      children: [
        for (final e in vProvozu) _Radek(elektromer: e),
        if (vyrazene.isNotEmpty) ...[
          const NadpisSekce('Vyřazené'),
          for (final e in vyrazene) _Radek(elektromer: e),
        ],
      ],
    );
  }
}

class _Radek extends StatelessWidget {
  const _Radek({required this.elektromer});

  final Elektromer elektromer;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ElektromerObrazovka(elektromerId: elektromer.id),
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: Rozmery.vyskaRadku),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      elektromer.nazev,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: elektromer.aktivni ? b.text : b.textFaint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'č. ${elektromer.cislo}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right, size: 20, color: b.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Údržbář obchází pořád tentýž areál, proto si výběr drží zvolenou
/// pobočku po celou dobu běhu aplikace.
class _VyberPobocky extends StatelessWidget {
  const _VyberPobocky({required this.vybrana, required this.onZmena});

  final Pobocka vybrana;
  final ValueChanged<Pobocka> onZmena;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
        border: Border.all(color: b.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Pobocka>(
          value: vybrana,
          isExpanded: true,
          dropdownColor: b.surface,
          borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
          icon: Icon(Icons.expand_more, color: b.textDim),
          style: Theme.of(context).textTheme.bodyLarge,
          items: [
            for (final p in Pobocka.values)
              DropdownMenuItem(value: p, child: Text(p.popisek)),
          ],
          onChanged: (nova) {
            if (nova != null) onZmena(nova);
          },
        ),
      ),
    );
  }
}

/// Bez hledání se osmdesát elektroměrů používat nedá.
class _PoleHledani extends StatefulWidget {
  const _PoleHledani({required this.hodnota, required this.onZmena});

  final String hodnota;
  final ValueChanged<String> onZmena;

  @override
  State<_PoleHledani> createState() => _PoleHledaniState();
}

class _PoleHledaniState extends State<_PoleHledani> {
  late final _ovladac = TextEditingController(text: widget.hodnota);

  @override
  void dispose() {
    _ovladac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return TextField(
      controller: _ovladac,
      onChanged: widget.onZmena,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Hledat podle čísla nebo umístění',
        prefixIcon: Icon(Icons.search, size: 20, color: b.textFaint),
        suffixIcon: widget.hodnota.isEmpty
            ? null
            : IconButton(
                icon: Icon(Icons.close, size: 18, color: b.textFaint),
                onPressed: () {
                  _ovladac.clear();
                  widget.onZmena('');
                },
              ),
      ),
    );
  }
}
