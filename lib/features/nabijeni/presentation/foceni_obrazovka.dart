import 'package:camera/camera.dart';
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
import '../../auth/application/auth_providery.dart';
import '../application/foto_sluzba.dart';
import '../application/ocr_sluzba.dart';
import '../application/zaloha_fotek.dart';
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

/// `hledacek` je živý obraz z fotoaparátu, `pracuje` pokrývá zpracování
/// snímku a čtení hodnoty, `zruseno` je stav bez snímku a bez hledáčku.
enum _Faze { hledacek, pracuje, zruseno, vysledek }

class _FoceniObrazovkaState extends ConsumerState<FoceniObrazovka>
    with WidgetsBindingObserver {
  final _pole = TextEditingController();

  /// Začíná se v `pracuje`, protože se rozbíhá kamera. Chvilku to trvá
  /// a prázdná černá plocha bez vysvětlení vypadá jako zaseknutá appka.
  _Faze _faze = _Faze.pracuje;
  String _prubeh = 'Spouštím fotoaparát…';

  /// Brání druhému spuštění, dokud první neskončí – dvě focení naráz
  /// nedávají smysl.
  bool _jizBezi = false;
  PorizenaFotografie? _foto;
  bool _ocrUspelo = false;
  bool _rucniZadavani = false;
  String? _chyba;

  /// Vlastní hledáček. `null`, dokud se kamera nerozběhne – nebo natrvalo,
  /// když se rozběhnout nepovede a jede se přes systémový fotoaparát.
  CameraController? _kamera;
  bool _hledacekNedostupny = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fotoaparát naskočí rovnou – uživatel stojí u nabíječky a nemá
    // důvod ťukat na další tlačítko.
    WidgetsBinding.instance.addPostFrameCallback((_) => _spustHledacek());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kamera?.dispose();
    _pole.dispose();
    super.dispose();
  }

  /// Systém kameru na pozadí zabaví jiné aplikaci, takže se při odchodu
  /// pouští a při návratu rozjíždí znovu. Bez toho se uživatel vrátí na
  /// zamrzlý obraz.
  @override
  void didChangeAppLifecycleState(AppLifecycleState stav) {
    if (_hledacekNedostupny || !mounted) return;
    if (stav == AppLifecycleState.inactive) {
      final stara = _kamera;
      if (stara == null) return;
      // Přes setState, ne potichu: `CameraPreview` by jinak zůstal
      // viset na zahozeném ovladači a spadl při dalším překreslení.
      setState(() => _kamera = null);
      stara.dispose();
    } else if (stav == AppLifecycleState.resumed && _kamera == null) {
      _spustHledacek();
    }
  }

  Future<void> _spustHledacek() async {
    if (_hledacekNedostupny) return;
    try {
      final kamery = await availableCameras();
      if (kamery.isEmpty) throw const KameraNedostupna();
      final zadni = kamery.firstWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
        orElse: () => kamery.first,
      );

      final ovladac = CameraController(
        zadni,
        // Počítadlo bývá malé a čte se z něj číslo, takže se šetřit
        // rozlišením nevyplácí. Snímek se stejně hned zmenší na 1600 px.
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await ovladac.initialize();
      if (!mounted) {
        await ovladac.dispose();
        return;
      }
      setState(() {
        _kamera = ovladac;
        // Do hledáčku jen tehdy, když se zrovna nic jiného neděje.
        // Návrat z galerie taky projde přes `resumed`, a to se čeká
        // vybraný snímek, ne živý obraz.
        if (_faze == _Faze.pracuje && _foto == null && !_jizBezi) {
          _faze = _Faze.hledacek;
        }
      });
    } catch (_) {
      if (!mounted) return;
      // Když vlastní hledáček nejde spustit, systémový fotoaparát pořád
      // funguje. Uživatel u nabíječky nesmí zůstat na prázdné obrazovce
      // jen proto, že se nepovedlo hezčí řešení.
      _hledacekNedostupny = true;
      await _nacti(ZdrojFoto.fotoaparat);
    }
  }

  /// Spoušť vlastního hledáčku; bez něj otevře systémový fotoaparát.
  Future<void> _vyfot() async {
    final kamera = _kamera;
    if (kamera == null) return _nacti(ZdrojFoto.fotoaparat);
    if (_jizBezi) return;
    _jizBezi = true;
    setState(() {
      _faze = _Faze.pracuje;
      _prubeh = 'Zpracovávám snímek…';
      _chyba = null;
    });
    try {
      final snimek = await kamera.takePicture();
      final foto = await ref.read(fotoSluzbaProvider).zHledacku(snimek.path);
      if (!mounted) return;
      await _prectiHodnotu(foto);
    } catch (chyba) {
      if (!mounted) return;
      setState(() => _faze = _foto == null ? _Faze.hledacek : _Faze.vysledek);
      ukazChybu(context, chyba);
    } finally {
      _jizBezi = false;
    }
  }

  /// Návrat k hledáčku po pořízeném snímku („Vyfotit znovu").
  void _znovu() {
    if (_kamera == null) {
      _nacti(ZdrojFoto.fotoaparat);
      return;
    }
    setState(() {
      _faze = _Faze.hledacek;
      _chyba = null;
    });
  }

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
      await _prectiHodnotu(foto);
    } on FoceniZruseno {
      if (!mounted) return;
      // Zrušený výběr obrazovku nezavírá – uživatel se vrátí k hledáčku,
      // nebo k volbě cesty, když hledáček není. Ven vede křížek nahoře.
      setState(() => _faze = _vychoziFaze);
    } catch (chyba) {
      if (!mounted) return;
      setState(() => _faze = _vychoziFaze);
      ukazChybu(context, chyba);
    } finally {
      _jizBezi = false;
    }
  }

  /// Kam se vrátit, když focení skončí bez snímku.
  _Faze get _vychoziFaze {
    if (_foto != null) return _Faze.vysledek;
    return _kamera == null ? _Faze.zruseno : _Faze.hledacek;
  }

  Future<void> _prectiHodnotu(PorizenaFotografie foto) async {
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
  }

  Future<void> _potvrd() async {
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

    await _zalohuj(foto);
    if (!mounted) return;
    Navigator.of(context).pop(VysledekFoceni(hodnota: hodnota, foto: foto));
  }

  /// Kopie do galerie, pokud si ji uživatel zapnul v nastavení.
  ///
  /// Ukládá se **při potvrzení**, ne při stisku spouště: zahozené pokusy
  /// tak v galerii neskončí, a zároveň je kopie na disku dřív, než se
  /// snímek začne nahrávat – takže funguje i jako záloha proti spadlému
  /// nahrávání.
  ///
  /// Neúspěch záznam nezdrží. Kopie do galerie je pohodlí, kdežto bez
  /// fotky ve Storage nemá záznam smysl – proto se jen upozorní.
  Future<void> _zalohuj(PorizenaFotografie foto) async {
    final chce = ref.read(profilProvider).value?.zalohovatFotky ?? false;
    if (!chce) return;
    try {
      await ref.read(zalohaFotekProvider).uloz(foto);
    } catch (_) {
      if (!mounted) return;
      // Hlášku ukazuje ScaffoldMessenger nad celou aplikací, takže
      // přežije zavření téhle obrazovky a uživatel si ji přečte
      // na té pod ní.
      ukazVarovani(
        context,
        'Kopii do galerie se nepodařilo uložit. Záznam se přesto '
        'založí – zkontrolujte oprávnění k fotkám v nastavení telefonu.',
      );
    }
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

  /// Plocha nad panelem: živý obraz z fotoaparátu, nebo pořízený snímek.
  ///
  /// Hledáček je vlastní, stejně jako u načítání elektroměru – rámeček
  /// i spoušť tak leží nad skutečným obrazem z kamery, ne nad tmavou
  /// plochou. Když se kamera nerozběhne, zůstane podklad prázdný a fotí
  /// systémový fotoaparát.
  Widget _nahled() {
    final foto = _foto;
    final ukazujeSnimek = foto != null && _faze == _Faze.vysledek;
    final kamera = _kamera;
    final zivyObraz = kamera != null && !ukazujeSnimek;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: switch ((ukazujeSnimek, zivyObraz)) {
            (true, _) => Image.memory(foto!.bajty, fit: BoxFit.cover),
            (_, true) => _ZivyObraz(kamera!),
            _ => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF262626), Color(0xFF0A0A0A)],
                  radius: 0.75,
                ),
              ),
            ),
          },
        ),
        if (_faze == _Faze.hledacek) ...[
          const _Zamerovac(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _Spoust(onVyfotit: _vyfot, onGalerie: _zGalerie),
          ),
        ],
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

  /// Stav po zavření systémového fotoaparátu bez snímku. Sem se dojde
  /// jen tehdy, když se vlastní hledáček nerozběhl – jinak je pod
  /// obrazem spoušť a tenhle panel není potřeba.
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
            onTap: _znovu,
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
    OdkazoveTlacitko(popisek: 'Vyfotit znovu', onTap: _znovu),
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
      PrimarniTlacitko(popisek: 'Vyfotit znovu', vyska: 58, onTap: _znovu),
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

/// Živý obraz roztažený přes celou plochu.
///
/// `previewSize` chodí v orientaci na šířku bez ohledu na to, jak telefon
/// držíme, proto se rozměry prohazují – jinak by byl obraz rozplácnutý.
class _ZivyObraz extends StatelessWidget {
  const _ZivyObraz(this.kamera);

  final CameraController kamera;

  @override
  Widget build(BuildContext context) {
    final velikost = kamera.value.previewSize;
    if (velikost == null) return CameraPreview(kamera);

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: velikost.height,
        height: velikost.width,
        child: CameraPreview(kamera),
      ),
    );
  }
}

/// Rámeček na displej počítadla. Naležato, protože počítadlo je široké
/// a nízké – čtverec jako u QR kódu by sváděl k focení zdálky.
class _Zamerovac extends StatelessWidget {
  const _Zamerovac();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 280,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white70, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Displej do rámečku, ať je číslo ostré',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              shadows: [Shadow(blurRadius: 6)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Spoušť a cesta do galerie, obojí nad živým obrazem.
class _Spoust extends StatelessWidget {
  const _Spoust({required this.onVyfotit, required this.onGalerie});

  final VoidCallback onVyfotit;
  final VoidCallback onGalerie;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            label: 'Vyfotit počítadlo',
            child: GestureDetector(
              onTap: onVyfotit,
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0x33FFFFFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Center(
                  child: Icon(
                    Icons.photo_camera,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onGalerie,
            child: const Text(
              'Vybrat fotku z galerie',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 6)],
              ),
            ),
          ),
        ],
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
