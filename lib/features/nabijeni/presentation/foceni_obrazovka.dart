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

enum RezimFoceni {
  zahajeni('Vyfoťte počítadlo'),
  ukonceni('Vyfoťte počítadlo po nabití');

  const RezimFoceni(this.titulek);

  final String titulek;
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

  /// Počáteční stav počítadla – jen v režimu ukončení, kvůli kontrole,
  /// že koncová hodnota je vyšší.
  final double? kwhStart;

  @override
  ConsumerState<FoceniObrazovka> createState() => _FoceniObrazovkaState();
}

enum _Faze { pripraveno, zpracovava, vysledek }

class _FoceniObrazovkaState extends ConsumerState<FoceniObrazovka> {
  final _pole = TextEditingController();

  _Faze _faze = _Faze.pripraveno;
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

  Future<void> _vyfot() async {
    if (_faze == _Faze.zpracovava) return;
    setState(() {
      _faze = _Faze.zpracovava;
      _chyba = null;
    });
    try {
      final foto = await ref.read(fotoSluzbaProvider).vyfotPocitadlo();
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
      // Zrušené focení vrací obrazovku do výchozího stavu; když ještě
      // žádná fotka není, nemá smysl tu uživatele držet.
      if (_foto == null) {
        Navigator.of(context).pop();
      } else {
        setState(() => _faze = _Faze.vysledek);
      }
    } catch (chyba) {
      if (!mounted) return;
      setState(() => _faze = _foto == null ? _Faze.pripraveno : _Faze.vysledek);
      ukazChybu(context, chyba);
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
            'Koncový stav musí být vyšší než počáteční '
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
            if (_faze == _Faze.pripraveno) _spoust(),
            if (_faze == _Faze.vysledek) _panelVysledku(),
          ],
        ),
      ),
    );
  }

  Widget _nahled() {
    final foto = _foto;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: foto == null || _faze == _Faze.zpracovava
              ? const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0xFF262626), Color(0xFF0A0A0A)],
                      radius: 0.75,
                    ),
                  ),
                )
              : Image.memory(foto.bajty, fit: BoxFit.cover),
        ),
        if (_faze == _Faze.zpracovava)
          const CircularProgressIndicator(color: Colors.white)
        else if (_faze == _Faze.pripraveno)
          const _VodiciRamecek(),
        if (_faze == _Faze.pripraveno)
          const Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Text(
              'Zarovnejte displej počítadla do rámečku',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
      ],
    );
  }

  Widget _spoust() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Semantics(
          button: true,
          label: 'Vyfotit počítadlo',
          child: GestureDetector(
            onTap: _vyfot,
            child: Container(
              width: Rozmery.spoustZaverky,
              height: Rozmery.spoustZaverky,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24, width: 5),
              ),
            ),
          ),
        ),
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
    ?_chybovyText(),
    const SizedBox(height: 4),
    PrimarniTlacitko(popisek: 'Potvrdit stav', vyska: 58, onTap: _potvrd),
    OdkazoveTlacitko(popisek: 'Vyfotit znovu', onTap: _vyfot),
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
      const SizedBox(height: 4),
      PrimarniTlacitko(popisek: 'Vyfotit znovu', vyska: 58, onTap: _vyfot),
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

/// Čtyři rohové značky, které naznačují, kam displej zamířit.
class _VodiciRamecek extends StatelessWidget {
  const _VodiciRamecek();

  @override
  Widget build(BuildContext context) {
    // Hledáček je vždy tmavý bez ohledu na motiv, proto se bere akcent
    // z tmavé palety napřímo, ne z Theme.
    final barva = AppBarvy.tmava.accent;
    Widget roh({required bool nahore, required bool vlevo}) => Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        border: Border(
          top: nahore ? BorderSide(color: barva, width: 3) : BorderSide.none,
          bottom: nahore ? BorderSide.none : BorderSide(color: barva, width: 3),
          left: vlevo ? BorderSide(color: barva, width: 3) : BorderSide.none,
          right: vlevo ? BorderSide.none : BorderSide(color: barva, width: 3),
        ),
      ),
    );

    return SizedBox(
      width: 260,
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              roh(nahore: true, vlevo: true),
              roh(nahore: true, vlevo: false),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              roh(nahore: false, vlevo: true),
              roh(nahore: false, vlevo: false),
            ],
          ),
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
