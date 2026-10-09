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
import '../domain/obchuzka.dart';
import '../domain/pobocka.dart';
import '../domain/vychozi_mista.dart';
import '../../reporty/application/report_controller.dart';
import '../../reporty/presentation/export_obrazovka.dart';
import '../domain/identifikace.dart';
import 'elektromer_obrazovka.dart';
import 'formular_elektromeru.dart';
import 'ikona_druhu.dart';
import 'skener_obrazovka.dart';
import 'tok_odectu.dart';

/// Seznam odběrných míst zvolené pobočky – elektřina, plyn, klimatizace
/// a nabíječky, s výběrem druhu.
///
/// Seznam má **pevné pořadí** (druh, pak umístění) a stav odečtu je jen
/// značka na řádku. Dřív se dělil na „zbývá tento měsíc" a „hotovo":
/// řádky po zápisu přeskakovaly jinam, prvního v měsíci se všechno
/// vrátilo do „zbývá" a na začátku obchůzky to vypadalo jako 76 dlužných
/// úkolů. Průběh obchůzky je teď jeden řádek nad seznamem, viz
/// [Obchuzka].
class ElektromeryObrazovka extends ConsumerWidget {
  const ElektromeryObrazovka({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pobocka = ref.watch(vybranaPobockaProvider);
    final druh = ref.watch(vybranyDruhProvider);
    final dotaz = ref.watch(hledaniProvider);
    final elektromery = ref.watch(elektromeryProvider);
    final chybejici = ref.watch(chybejiciVychoziProvider);
    final jenNeodectene = ref.watch(jenNeodecteneProvider);
    // Obchůzka je za celou pobočku, ne za zvolený druh – chodí se
    // naráz po všech měřidlech.
    final obchuzka = Obchuzka.posledni(elektromery.value ?? const []);
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
              // Export bere stejný výřez jako štítky – co je vidět,
              // to se exportuje.
              IkonoveTlacitko(
                ikona: Icons.table_chart_outlined,
                popisPristupnosti: 'Export stavů do Excelu',
                onTap: () {
                  if (zobrazena.isEmpty) {
                    ukazVarovani(context, 'Zatím tu není co exportovat.');
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExportObrazovka(
                        stavy: (pobocka: pobocka, druh: druh, mista: zobrazena),
                      ),
                    ),
                  );
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
        _Vybery(
          pobocka: pobocka,
          druh: druh,
          vsechna: elektromery.value ?? const [],
          onPobocka: (nova) =>
              ref.read(vybranaPobockaProvider.notifier).vyber(nova),
          onDruh: (novy) => ref.read(vybranyDruhProvider.notifier).vyber(novy),
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
        if (elektromery.hasValue && zobrazena.isNotEmpty)
          _StavObchuzky(
            obchuzka: obchuzka,
            mista: zobrazena,
            jenNeodectene: jenNeodectene,
            onPrepni: () => ref.read(jenNeodecteneProvider.notifier).prepni(),
          ),
        switch (elektromery) {
          AsyncError() => ChybovyBlok(
            zprava: 'Odběrná místa se nepodařilo načíst.',
            onZkusitZnovu: () => ref.invalidate(elektromeryProvider),
          ),
          AsyncData() => _Seznam(
            vsechny: zobrazena,
            dotaz: dotaz,
            druh: druh,
            obchuzka: obchuzka,
            jenNeodectene: jenNeodectene,
          ),
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

/// Jeden řádek s průběhem poslední obchůzky a přepínačem, který nechá
/// jen místa bez odečtu. Nahrazuje dřívější dvojí seznam
/// „zbývá / hotovo".
class _StavObchuzky extends StatelessWidget {
  const _StavObchuzky({
    required this.obchuzka,
    required this.mista,
    required this.jenNeodectene,
    required this.onPrepni,
  });

  final Obchuzka? obchuzka;

  /// Zobrazená místa – průběh se počítá za zvolený druh, ať sedí
  /// s tím, co je vidět pod ním.
  final List<Elektromer> mista;
  final bool jenNeodectene;
  final VoidCallback onPrepni;

  @override
  Widget build(BuildContext context) {
    final obchuzka = this.obchuzka;
    final aktivni = mista.where((e) => e.aktivni).toList();
    final hotovo = obchuzka == null
        ? 0
        : aktivni.where(obchuzka.zahrnuje).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              obchuzka == null
                  ? 'Zatím se tu neodečítalo.'
                  : 'Obchůzka od ${Format.datum(obchuzka.od)}: '
                        'odečteno $hotovo z ${aktivni.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (obchuzka != null) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: const Text('Jen neodečtené'),
              selected: jenNeodectene,
              onSelected: (_) => onPrepni(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Místa v pevném pořadí: podle druhu, uvnitř podle umístění (tak je
/// řadí už Firestore). Zápis odečtu s řádkem nehne, jen mu změní
/// značku – člověk v obchůzce neztratí, kde byl.
class _Seznam extends StatelessWidget {
  const _Seznam({
    required this.vsechny,
    required this.dotaz,
    required this.druh,
    required this.obchuzka,
    required this.jenNeodectene,
  });

  /// Místa zvoleného druhu, nebo všechna, když je [druh] `null`.
  final List<Elektromer> vsechny;
  final String dotaz;
  final DruhMista? druh;
  final Obchuzka? obchuzka;
  final bool jenNeodectene;

  bool _hotovo(Elektromer e) => obchuzka?.zahrnuje(e) ?? false;

  @override
  Widget build(BuildContext context) {
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

    final nalezene = [
      for (final e in vsechny)
        if (e.odpovidaHledani(dotaz)) e,
    ];
    if (nalezene.isEmpty) {
      return const PrazdnyStav(
        text: 'Hledání neodpovídá žádné odběrné místo.',
        ikona: Icons.search_off,
      );
    }

    final aktivni = [
      for (final e in nalezene)
        if (e.aktivni && !(jenNeodectene && _hotovo(e))) e,
    ];
    // Vyřazená místa do obchůzky nepatří, takže se při zúžení na
    // neodečtená neukazují vůbec.
    final vyrazene = jenNeodectene
        ? const <Elektromer>[]
        : [
            for (final e in nalezene)
              if (!e.aktivni) e,
          ];

    if (aktivni.isEmpty && vyrazene.isEmpty) {
      return const PrazdnyStav(
        text: 'V poslední obchůzce je všechno odečtené.',
        ikona: Icons.check_circle_outline,
      );
    }

    Widget radek(Elektromer e) => _Radek(elektromer: e, hotovo: _hotovo(e));
    final skupiny = zvoleny == null
        ? [
            for (final d in DruhMista.values)
              (
                d,
                [
                  for (final e in aktivni)
                    if (e.druh == d) e,
                ],
              ),
          ]
        : [(zvoleny, aktivni)];

    return Column(
      children: [
        // U „všech druhů" nadpis nad každým druhem – jinak by se tři
        // „Servisy" pod sebou nedaly rozlišit.
        for (final (d, mista) in skupiny)
          if (mista.isNotEmpty) ...[
            if (zvoleny == null) NadpisSekce(d.nazev),
            for (final e in mista) radek(e),
          ],
        if (vyrazene.isNotEmpty) ...[
          const NadpisSekce('Vyřazené'),
          for (final e in vyrazene) radek(e),
        ],
      ],
    );
  }
}

class _Radek extends ConsumerWidget {
  const _Radek({required this.elektromer, required this.hotovo});

  final Elektromer elektromer;

  /// Odečteno v poslední obchůzce.
  final bool hotovo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = context.barvy;
    final posledni = elektromer.posledniOdecet;
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
                    if (elektromer.maCislo) ...[
                      const SizedBox(height: 2),
                      Text(
                        'č. ${elektromer.cislo}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 2),
                    // Datum první: podle něj se pozná, jestli je místo
                    // odečtené, i bez barvy.
                    Text(
                      posledni == null
                          ? 'zatím bez odečtu'
                          : '${Format.datum(posledni.odectenoAt)} · '
                                '${Format.kwh(posledni.hodnota)} '
                                '${elektromer.druh.jednotka}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hotovo ? b.penize : b.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Zápis rovnou ze seznamu: na jeden elektroměr tak vyjdou
              // dvě klepnutí místo čtyř. Při desítkách kusů na pobočce
              // se to nasčítá.
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

/// Pobočka a druh jako dva rozbalovací seznamy vedle sebe. Dřív byl druh
/// řada čipů, která na telefonu zabrala dva řádky nad seznamem.
///
/// Údržbář obchází pořád tentýž areál, proto si výběr drží zvolenou
/// pobočku i druh po celou dobu běhu aplikace.
class _Vybery extends StatelessWidget {
  const _Vybery({
    required this.pobocka,
    required this.druh,
    required this.vsechna,
    required this.onPobocka,
    required this.onDruh,
  });

  final Pobocka pobocka;
  final DruhMista? druh;

  /// Všechna místa pobočky – kvůli počtům u druhů.
  final List<Elektromer> vsechna;
  final ValueChanged<Pobocka> onPobocka;
  final ValueChanged<DruhMista?> onDruh;

  @override
  Widget build(BuildContext context) {
    int pocet(DruhMista d) => vsechna.where((e) => e.druh == d).length;
    final styl = Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Expanded(
          child: _Rozbalovaci<Pobocka>(
            hodnota: pobocka,
            // V rozbalení celý popisek s kódem, ve vybrané podobě jen
            // název – vedle druhu by se celý nevešel.
            polozky: {for (final p in Pobocka.values) p: p.popisek},
            vybrana: (p) =>
                Text(p.nazev, style: styl, overflow: TextOverflow.ellipsis),
            onZmena: (nova) {
              if (nova != null) onPobocka(nova);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Rozbalovaci<DruhMista?>(
            hodnota: druh,
            polozky: {
              null: 'Všechny druhy · ${vsechna.length}',
              for (final d in DruhMista.values) d: '${d.nazev} · ${pocet(d)}',
            },
            vybrana: (d) => Text(
              d?.nazev ?? 'Všechny druhy',
              style: styl,
              overflow: TextOverflow.ellipsis,
            ),
            onZmena: onDruh,
          ),
        ),
      ],
    );
  }
}

/// Rozbalovací seznam v rámečku, jak ho používá výběr pobočky a druhu.
class _Rozbalovaci<T> extends StatelessWidget {
  const _Rozbalovaci({
    required this.hodnota,
    required this.polozky,
    required this.vybrana,
    required this.onZmena,
  });

  final T hodnota;

  /// Hodnota → text v rozbaleném seznamu.
  final Map<T, String> polozky;

  /// Jak vypadá vybraná hodnota v zavřeném seznamu.
  final Widget Function(T) vybrana;
  final ValueChanged<T?> onZmena;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Container(
      padding: const EdgeInsets.only(left: 14, right: 8),
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
        border: Border.all(color: b.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: hodnota,
          isExpanded: true,
          dropdownColor: b.surface,
          borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
          icon: Icon(Icons.expand_more, color: b.textDim),
          style: Theme.of(context).textTheme.bodyLarge,
          selectedItemBuilder: (_) => [
            for (final h in polozky.keys)
              Align(alignment: Alignment.centerLeft, child: vybrana(h)),
          ],
          items: [
            for (final MapEntry(:key, :value) in polozky.entries)
              DropdownMenuItem(value: key, child: Text(value)),
          ],
          onChanged: onZmena,
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
