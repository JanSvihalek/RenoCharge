import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/motiv/barvy.dart';
import '../../../common/motiv/rozmery.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/prvky.dart';
import '../../../common/widgety/tlacitka.dart';
import '../../../common/formatovani.dart';
import '../../../common/chyby.dart';
import '../application/elektromery_providery.dart';
import '../domain/druh_mista.dart';
import '../domain/elektromer.dart';
import '../domain/pobocka.dart';
import '../domain/vychozi_mista.dart';
import '../../reporty/application/report_controller.dart';
import '../domain/identifikace.dart';
import 'elektromer_obrazovka.dart';
import 'formular_elektromeru.dart';
import 'ikona_druhu.dart';
import 'skener_obrazovka.dart';
import 'tok_odectu.dart';

/// Seznam odběrných míst zvolené pobočky – elektřina, plyn, klimatizace
/// a nabíječky, s filtrem podle druhu.
///
/// Obrazovka je zároveň obchůzka – rozdělení na „zbývá / hotovo" se
/// dopočítá z posledního odečtu, žádná zvláštní entita nevznikne.
class ElektromeryObrazovka extends ConsumerWidget {
  const ElektromeryObrazovka({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pobocka = ref.watch(vybranaPobockaProvider);
    final druh = ref.watch(vybranyDruhProvider);
    final dotaz = ref.watch(hledaniProvider);
    final elektromery = ref.watch(elektromeryProvider);
    final chybejici = ref.watch(chybejiciVychoziProvider);
    // Štítky i seznam berou jen zvolený druh – plynoměry se obcházejí
    // jinudy než elektroměry.
    final zobrazena = [
      for (final e in elektromery.value ?? const <Elektromer>[])
        if (druh == null || e.druh == druh) e,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Rozmery.okrajStranky,
        0,
        Rozmery.okrajStranky,
        24,
      ),
      children: [
        VelkyNadpis(
          'Odběrná místa',
          akce: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IkonoveTlacitko(
                ikona: Icons.qr_code_2,
                popisPristupnosti: druh == null
                    ? 'Vytisknout QR štítky pobočky'
                    : 'Vytisknout QR štítky: ${druh.nazev}',
                onTap: () async {
                  final pocet = await ref
                      .read(reportControllerProvider.notifier)
                      .vytvorStitky(
                        popis: druh == null
                            ? pobocka.kod
                            : '${pobocka.kod} ${druh.nazev}',
                        elektromery: zobrazena,
                      );
                  if (context.mounted && pocet == 0) {
                    ukazVarovani(context, 'Zatím tu není co oštítkovat.');
                  }
                },
              ),
              const SizedBox(width: 8),
              IkonoveTlacitko(
                ikona: Icons.add,
                popisPristupnosti: 'Přidat odběrné místo',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FormularElektromeru(pobocka: pobocka, druh: druh),
                  ),
                ),
              ),
            ],
          ),
        ),
        _VyberPobocky(
          vybrana: pobocka,
          onZmena: (nova) =>
              ref.read(vybranaPobockaProvider.notifier).vyber(nova),
        ),
        const SizedBox(height: 12),
        _FiltrDruhu(
          vybrany: druh,
          vsechna: elektromery.value ?? const [],
          onZmena: (novy) => ref.read(vybranyDruhProvider.notifier).vyber(novy),
        ),
        const SizedBox(height: 12),
        _PoleHledani(
          hodnota: dotaz,
          onZmena: (text) => ref.read(hledaniProvider.notifier).nastav(text),
        ),
        const SizedBox(height: 14),
        // Zkratka přes celou šířku: sken QR je hlavní cesta k zápisu,
        // seznam pod ním zůstává pro případ, že kód chybí.
        //
        // Skener hledá ve všech místech pobočky, ne jen ve zvoleném druhu –
        // kdo naskenuje plynoměr s filtrem na elektřinu, chce plynoměr.
        PrimarniTlacitko(
          popisek: 'Načíst odběrné místo',
          ikona: Icons.qr_code_scanner,
          onTap: () => _skenuj(context, ref, elektromery.value ?? const []),
        ),
        if (chybejici.isNotEmpty) ...[
          const SizedBox(height: 16),
          _VychoziSeznam(chybejici: chybejici),
        ],
        const SizedBox(height: 16),
        switch (elektromery) {
          AsyncError() => ChybovyBlok(
            zprava: 'Odběrná místa se nepodařilo načíst.',
            onZkusitZnovu: () => ref.invalidate(elektromeryProvider),
          ),
          AsyncData() => _Seznam(vsechny: zobrazena, dotaz: dotaz, druh: druh),
          _ => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

/// Otevře skener a po nalezení pustí rovnou zápis odečtu – na jeden
/// elektroměr tak vyjde sken a potvrzení, nic mezi tím.
Future<void> _skenuj(
  BuildContext context,
  WidgetRef ref,
  List<Elektromer> evidence,
) async {
  if (evidence.isEmpty) {
    ukazVarovani(
      context,
      'Na této pobočce zatím není žádné odběrné místo, které by šlo načíst.',
    );
    return;
  }

  final nalez = await Navigator.of(context).push<NalezenyElektromer>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SkenerObrazovka(elektromery: evidence),
    ),
  );
  if (nalez == null || !context.mounted) return;

  // U čísla ze štítku je identifikace odhad, ne jistota – ať člověk
  // vidí, co se mu načetlo, než začne fotit počítadlo.
  if (nalez.zpusob == ZpusobNalezeni.cisloZeStitku) {
    ukazInfo(
      context,
      'Načteno: ${nalez.elektromer.druh.nazev} · ${nalez.elektromer.nazev}',
    );
  }
  await otevriZapisOdectu(context, ref, nalez.elektromer);
}

class _Seznam extends StatelessWidget {
  const _Seznam({
    required this.vsechny,
    required this.dotaz,
    required this.druh,
  });

  /// Místa zvoleného druhu, nebo všechna, když je [druh] `null`.
  final List<Elektromer> vsechny;
  final String dotaz;
  final DruhMista? druh;

  @override
  Widget build(BuildContext context) {
    // Obchůzka se dopočítává, žádná entita nevzniká: hotový je ten,
    // jehož poslední odečet spadá do tohohle měsíce.
    final ted = DateTime.now();
    final nalezene = [
      for (final e in vsechny)
        if (e.odpovidaHledani(dotaz)) e,
    ];
    final zbyva = [
      for (final e in nalezene)
        if (e.aktivni && !e.maOdecetZa(ted)) e,
    ];
    final hotovo = [
      for (final e in nalezene)
        if (e.aktivni && e.maOdecetZa(ted)) e,
    ];
    final vyrazene = [
      for (final e in nalezene)
        if (!e.aktivni) e,
    ];

    final zvoleny = druh;
    if (vsechny.isEmpty) {
      return PrazdnyStav(
        text: zvoleny == null
            ? 'Na této pobočce zatím není žádné odběrné místo.\n'
                  'Přidejte ho tlačítkem nahoře.'
            : 'Druh „${zvoleny.nazev}“ tu zatím nemá žádné místo.\n'
                  'Přidejte ho tlačítkem nahoře.',
        ikona: zvoleny == null
            ? Icons.electric_meter_outlined
            : ikonaDruhu(zvoleny),
      );
    }
    if (nalezene.isEmpty) {
      return const PrazdnyStav(
        text: 'Hledání neodpovídá žádné odběrné místo.',
        ikona: Icons.search_off,
      );
    }

    // U výběru „vše" je druh vidět na řádku, jinak by se tři „Servisy"
    // pod sebou nedaly rozlišit.
    final ukazDruh = zvoleny == null;
    return Column(
      children: [
        if (zbyva.isNotEmpty) ...[
          NadpisSekce('Zbývá tento měsíc · ${zbyva.length}'),
          for (final e in zbyva) _Radek(elektromer: e, ukazDruh: ukazDruh),
        ],
        if (hotovo.isNotEmpty) ...[
          NadpisSekce('Hotovo · ${hotovo.length}'),
          for (final e in hotovo) _Radek(elektromer: e, ukazDruh: ukazDruh),
        ],
        if (vyrazene.isNotEmpty) ...[
          const NadpisSekce('Vyřazené'),
          for (final e in vyrazene) _Radek(elektromer: e, ukazDruh: ukazDruh),
        ],
      ],
    );
  }
}

class _Radek extends ConsumerWidget {
  const _Radek({required this.elektromer, required this.ukazDruh});

  final Elektromer elektromer;
  final bool ukazDruh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final posledni = elektromer.posledniOdecet;
    final hotovo = elektromer.maOdecetZa(DateTime.now());
    final identifikace = [
      if (ukazDruh) elektromer.druh.nazev,
      if (elektromer.maCislo) 'č. ${elektromer.cislo}',
    ].join(' · ');
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
                    if (identifikace.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        identifikace,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      posledni == null
                          ? 'zatím bez odečtu'
                          : '${hotovo ? '' : 'naposledy '}'
                                '${Format.kwh(posledni.hodnota)} '
                                '${elektromer.druh.jednotka} · '
                                '${Format.datum(posledni.odectenoAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hotovo ? b.penize : b.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Zápis rovnou ze seznamu: na jeden elektroměr tak vyjdou
              // dvě klepnutí místo čtyř. Při jedenatřiceti kusech na
              // pobočce se to nasčítá.
              if (elektromer.aktivni)
                IkonoveTlacitko(
                  ikona: hotovo
                      ? Icons.check_circle_outline
                      : Icons.photo_camera_outlined,
                  barvaIkony: hotovo ? b.penize : b.accentText,
                  pozadi: hotovo ? b.surface2 : b.accent,
                  popisPristupnosti: 'Zapsat odečet: ${elektromer.nazev}',
                  onTap: () => otevriZapisOdectu(context, ref, elektromer),
                )
              else
                Icon(Icons.chevron_right, size: 20, color: b.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filtr podle druhu. U každého druhu je počet míst, ať je hned vidět,
/// kolik štítků se vytiskne a kolik toho obchůzka obnáší.
class _FiltrDruhu extends StatelessWidget {
  const _FiltrDruhu({
    required this.vybrany,
    required this.vsechna,
    required this.onZmena,
  });

  final DruhMista? vybrany;
  final List<Elektromer> vsechna;
  final ValueChanged<DruhMista?> onZmena;

  @override
  Widget build(BuildContext context) {
    int pocet(DruhMista d) => vsechna.where((e) => e.druh == d).length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('Vše · ${vsechna.length}'),
          selected: vybrany == null,
          onSelected: (_) => onZmena(null),
        ),
        for (final d in DruhMista.values)
          ChoiceChip(
            avatar: Icon(ikonaDruhu(d), size: 18),
            label: Text('${d.nazev} · ${pocet(d)}'),
            selected: vybrany == d,
            // Druhé klepnutí na vybraný druh filtr zruší.
            onSelected: (zapnout) => onZmena(zapnout ? d : null),
          ),
      ],
    );
  }
}

/// Nabídka založit místa z výchozího seznamu, dokud některá v evidenci
/// chybí. Po založení všech zmizí sama – porovnává se podle pevných ID.
class _VychoziSeznam extends ConsumerWidget {
  const _VychoziSeznam({required this.chybejici});

  final List<VychoziMisto> chybejici;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stav = ref.watch(elektromeryControllerProvider);
    final pocty = [
      for (final d in DruhMista.values)
        if (chybejici.where((m) => m.druh == d).length case final n when n > 0)
          '${d.nazev.toLowerCase()} $n',
    ].join(', ');

    return Karta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Výchozí seznam odběrných míst',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'V evidenci zatím chybí ${chybejici.length} míst ($pocty). '
            'Založí se bez výrobních čísel – ta jdou doplnit později '
            'úpravou místa.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          PrimarniTlacitko(
            popisek: 'Založit ${chybejici.length} míst',
            ikona: Icons.playlist_add,
            vyska: Rozmery.dotykMin,
            nacita: stav.isLoading,
            onTap: stav.isLoading
                ? null
                : () async {
                    final pocet = await ref
                        .read(elektromeryControllerProvider.notifier)
                        .zalozVychozi(chybejici);
                    if (!context.mounted) return;
                    if (pocet != null) {
                      ukazInfo(context, 'Založeno $pocet odběrných míst.');
                    } else {
                      ukazChybu(
                        context,
                        ref.read(elektromeryControllerProvider).error ??
                            const NeznamaChyba('Založení se nepovedlo.'),
                      );
                    }
                  },
          ),
        ],
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
