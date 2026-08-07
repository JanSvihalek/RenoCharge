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
import '../application/foto_sluzba.dart';
import '../application/ocr_sluzba.dart';
import '../domain/porizena_fotografie.dart';
import 'widgety/puvod_fotky.dart';

enum RezimFoceni {
  zahajeni('Vyfoťte počítadlo', 'Koncový stav musí být vyšší než počáteční'),
  ukonceni(
    'Vyfoťte počítadlo po nabití',
    'Koncový stav musí být vyšší než počáteční',
  ),
  odecet('Vyfoťte stav elektroměru', 'Nový stav musí být vyšší než minulý');

  const RezimFoceni(this.titulek, this.chybaMinima);

  final String titulek;

  /// Úvod hlášky, když je zadaná hodnota nižší než dovolené minimum.
  /// U nabíjení je minimem počáteční stav relace, u elektroměru minulý
  /// odečet – text se proto liší.
  final String chybaMinima;
}

/// Potvrzená fotka i hodnota, se kterou dál pracuje volající obrazovka.
class VysledekFoceni {
  const VysledekFoceni({required this.hodnota, required this.foto});

  final double hodnota;
  final PorizenaFotografie foto;
}

/// Focení počítadla. Sdílená obrazovka pro zahájení i ukončení – liší se
/// jen titulkem a kontrolou proti počátečnímu stavu.
///
/// OCR je tu jako pomůcka: číslo je vždy přepisovatelné a bez potvrzení
/// tlačítkem se nikam nezapíše.
class FoceniObrazovka extends ConsumerStatefulWidget {
  const FoceniObrazovka({super.key, required this.rezim, this.kwhStart});

  final RezimFoceni rezim;

  /// Nejnižší přípustná hodnota. U ukončení nabíjení je to počáteční
  /// stav relace, u odečtu elektroměru minulý odečet. `null` znamená
  /// bez kontroly.
  final double? kwhStart;

  @override
  ConsumerState<FoceniObrazovka> createState() => _FoceniObrazovkaState();
}

/// `pracuje` pokrývá otevírání fotoaparátu i následné čtení snímku,
/// `zruseno` je stav po zavření fotoaparátu bez snímku.
enum _Faze { pracuje, zruseno, vysledek }

class _FoceniObrazovkaState extends ConsumerState<FoceniObrazovka> {
  final _pole = TextEditingController();

  /// Začíná se rovnou v `pracuje`, protože fotoaparát se otevírá hned.
  /// Kdyby byl výchozí stav se spouští, blikla by před systémovým
  /// fotoaparátem vlastní obrazovka fotoaparátu – dva fotoaparáty za
  /// sebou, které aplikace nikdy neuměla obsluhovat.
  _Faze _faze = _Faze.pracuje;
  String _prubeh = 'Otevírám fotoaparát…';

  /// Brání druhému spuštění, dokud první neskončí – dvě otevření
  /// fotoaparátu naráz nedávají smysl.
  bool _jizBezi = false;
  PorizenaFotografie? _foto;
  bool _ocrUspelo = false;
  bool _rucniZadavani = false;
  String? _chyba;

  @override
  void initState() {
    super.initState();
    // Fotoaparát se otevře rovnou – uživatel stojí u nabíječky
    // a nemá důvod ťukat na další tlačítko.
    WidgetsBinding.instance.addPostFrameCallback((_) => _vyfot());
  }

  @override
  void dispose() {
    _pole.dispose();
    super.dispose();
  }

  Future<void> _vyfot() => _nacti(ZdrojFoto.fotoaparat);

  Future<void> _zGalerie() => _nacti(ZdrojFoto.galerie);

  Future<void> _nacti(ZdrojFoto zdroj) async {
    if (_jizBezi) return;
    _jizBezi = true;
    setState(() {
      _faze = _Faze.pracuje;
      _prubeh = zdroj == ZdrojFoto.fotoaparat
          ? 'Otevírám fotoaparát…'
          : 'Otevírám galerii…';
      _chyba = null;
    });
    try {
      final foto = await ref.read(fotoSluzbaProvider).nactiPocitadlo(zdroj);
      if (!mounted) return;
      setState(() => _prubeh = 'Čtu hodnotu ze snímku…');
      final hodnota = await ref
          .read(ocrSluzbaProvider)
          .najdiHodnotu(foto.cestaVSouborovemSystemu);
      if (!mounted) return;
      setState(() {
        _foto = foto;
        _ocrUspelo = hodnota != null;
        _rucniZadavani = false;
        _pole.text = hodnota == null ? '' : Format.kwh(hodnota);
        _faze = _Faze.vysledek;
      });
    } on FoceniZruseno {
      if (!mounted) return;
      // Zrušený výběr obrazovku nezavírá – uživatel se tím dostane
      // k volbě mezi fotoaparátem a galerií. Ven vede křížek nahoře.
      setState(() => _faze = _foto == null ? _Faze.zruseno : _Faze.vysledek);
    } catch (chyba) {
      if (!mounted) return;
      setState(() => _faze = _foto == null ? _Faze.zruseno : _Faze.vysledek);
      ukazChybu(context, chyba);
    } finally {
      _jizBezi = false;
    }
  }

  void _potvrd() {
    final foto = _foto;
    if (foto == null) return;
    final hodnota = Format.parsujKwh(_pole.text);
    if (hodnota == null) {
      setState(
        () => _chyba =
            'Zadejte prosím stav počítadla jako číslo, například 12486,7.',
      );
      return;
    }
    final start = widget.kwhStart;
    if (start != null && hodnota <= start) {
      setState(
        () => _chyba =
            '${widget.rezim.chybaMinima} '
            '(${Format.kwh(start)} kWh). Zkontrolujte prosím hodnotu.',
      );
      return;
    }
    Navigator.of(context).pop(VysledekFoceni(hodnota: hodnota, foto: foto));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HorniPruh(
              titulek: widget.rezim.titulek,
              onZavrit: () => Navigator.of(context).pop(),
            ),
            Expanded(child: _nahled()),
            if (_faze == _Faze.zruseno) _panelZruseno(),
            if (_faze == _Faze.vysledek) _panelVysledku(),
          ],
        ),
      ),
    );
  }

  /// Plocha nad panelem. Dokud snímek není, je tu jen tmavý podklad –
  /// žádné rámečky ani spoušť, protože živý obraz z fotoaparátu tudy
  /// neteče. Fotí systémový fotoaparát ve vlastní obrazovce.
  Widget _nahled() {
    final foto = _foto;
    final ukazujeSnimek = foto != null && _faze == _Faze.vysledek;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: ukazujeSnimek
              ? Image.memory(foto.bajty, fit: BoxFit.cover)
              : const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xFF262626), Color(0xFF0A0A0A)],
                      radius: 0.75,
                    ),
                  ),
                ),
        ),
        if (_faze == _Faze.pracuje)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 14),
              Text(
                _prubeh,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
      ],
    );
  }

  /// Stav po zavření fotoaparátu bez snímku. Dřív tu byla vlastní
  /// spoušť s rámečkem, což vypadalo jako druhý fotoaparát – jenže
  /// aplikace vlastní hledáček nemá a klepnutí jen znovu otevře ten
  /// systémový. Radši se řekne, co se stalo, a nabídnou obě cesty.
  Widget _panelZruseno() {
    final b = context.barvy;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Zatím není co uložit',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          _Popisek(
            'Bez fotky počítadla se záznam založit nedá. '
            'Vyfoťte displej, nebo použijte snímek, který už máte '
            'v telefonu.',
          ),
          const SizedBox(height: 14),
          PrimarniTlacitko(
            popisek: 'Vyfotit počítadlo',
            ikona: Icons.photo_camera_outlined,
            vyska: 58,
            onTap: _vyfot,
          ),
          OdkazoveTlacitko(popisek: 'Vybrat fotku z galerie', onTap: _zGalerie),
        ],
      ),
    );
  }

  Widget _panelVysledku() {
    final b = context.barvy;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: b.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: _ocrUspelo ? _obsahPrecteno() : _obsahNeprecteno(),
        ),
      ),
    );
  }

  List<Widget> _obsahPrecteno() => [
    Text('Přečtená hodnota', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 10),
    _PoleHodnoty(pole: _pole, onZmena: _zahodChybu),
    const SizedBox(height: 8),
    _Popisek('Zkontrolujte číslo a v případě potřeby jej opravte.'),
    PuvodFotky(_foto!),
    ?_chybovyText(),
    const SizedBox(height: 4),
    PrimarniTlacitko(popisek: 'Potvrdit stav', vyska: 58, onTap: _potvrd),
    OdkazoveTlacitko(popisek: 'Vyfotit znovu', onTap: _vyfot),
    OdkazoveTlacitko(popisek: 'Vybrat jinou z galerie', onTap: _zGalerie),
  ];

  List<Widget> _obsahNeprecteno() {
    final b = context.barvy;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Icon(Icons.warning_amber_rounded, size: 28, color: b.danger),
      ),
      const SizedBox(height: 8),
      Text(
        'Číslo se nepodařilo přečíst',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      _Popisek(
        'Zkuste to znovu s lepším osvětlením, nebo zadejte hodnotu ručně. '
        'Ručně zadaná hodnota platí stejně jako přečtená.',
      ),
      PuvodFotky(_foto!),
      const SizedBox(height: 4),
      PrimarniTlacitko(popisek: 'Vyfotit znovu', vyska: 58, onTap: _vyfot),
      OdkazoveTlacitko(popisek: 'Vybrat jinou z galerie', onTap: _zGalerie),
      if (!_rucniZadavani)
        OdkazoveTlacitko(
          popisek: 'Zadat hodnotu ručně',
          onTap: () => setState(() {
            _rucniZadavani = true;
            _chyba = null;
          }),
        )
      else ...[
        const SizedBox(height: 12),
        _PoleHodnoty(
          pole: _pole,
          onZmena: _zahodChybu,
          napoveda: 'např. 12486,7',
          automatickyFokus: true,
        ),
        ?_chybovyText(),
        const SizedBox(height: 8),
        PrimarniTlacitko(popisek: 'Potvrdit ručně', vyska: 58, onTap: _potvrd),
      ],
    ];
  }

  void _zahodChybu() {
    if (_chyba != null) setState(() => _chyba = null);
  }

  Widget? _chybovyText() {
    final chyba = _chyba;
    if (chyba == null) return null;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        chyba,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.barvy.danger),
      ),
    );
  }
}

class _HorniPruh extends StatelessWidget {
  const _HorniPruh({required this.titulek, required this.onZavrit});

  final String titulek;
  final VoidCallback onZavrit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Zavřít focení',
            child: GestureDetector(
              onTap: onZavrit,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x26FFFFFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 20, color: Colors.white),
              ),
            ),
          ),
          Expanded(
            child: Text(
              titulek,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// Pole se stavem počítadla – monospace, vždy přepisovatelné.
class _PoleHodnoty extends StatelessWidget {
  const _PoleHodnoty({
    required this.pole,
    required this.onZmena,
    this.napoveda,
    this.automatickyFokus = false,
  });

  final TextEditingController pole;
  final VoidCallback onZmena;
  final String? napoveda;
  final bool automatickyFokus;

  @override
  Widget build(BuildContext context) {
    final b = context.barvy;
    return Container(
      decoration: BoxDecoration(
        color: b.surface2,
        borderRadius: BorderRadius.circular(Rozmery.radiusPolozky),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: pole,
              autofocus: automatickyFokus,
              onChanged: (_) => onZmena(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]')),
              ],
              style: Motiv.pocitadlo(b),
              decoration: InputDecoration(
                hintText: napoveda,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          Text(
            'kWh',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: b.textDim),
          ),
        ],
      ),
    );
  }
}

class _Popisek extends StatelessWidget {
  const _Popisek(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 13.5,
        color: context.barvy.textDim,
      ),
    );
  }
}
