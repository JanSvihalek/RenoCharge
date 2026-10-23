import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../common/chyby.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../nabijeni/application/foto_sluzba.dart';
import '../../nabijeni/application/ocr_sluzba.dart';
import '../../nabijeni/domain/porizena_fotografie.dart';
import '../domain/elektromer.dart';
import '../domain/identifikace.dart';

/// Načtení elektroměru QR kódem, se štítkem jako záchranou.
///
/// QR je jednoznačný a rychlý; když je kód poškrábaný nebo odlepený,
/// vyfotí se štítek a číslo se přečte OCR. Vybrat ze seznamu jde vždycky
/// – skenování je zkratka, ne jediná cesta.
class SkenerObrazovka extends ConsumerStatefulWidget {
  const SkenerObrazovka({super.key, required this.elektromery});

  /// Evidence, ve které se hledá. Předává ji volající, protože skener
  /// nemá co chodit do Firestore.
  final List<Elektromer> elektromery;

  @override
  ConsumerState<SkenerObrazovka> createState() => _SkenerObrazovkaState();
}

class _SkenerObrazovkaState extends ConsumerState<SkenerObrazovka> {
  final _ovladac = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
    // Android jinak skenuje v 640 × 480. QR na štítku má 20 mm a nese
    // dlouhé ID místa, takže jsou jeho moduly drobné – v nízkém rozlišení
    // se přečte, až když je telefon tak blízko, že už nezaostří. iOS
    // tohle nastavení nezná, skenuje ve vyšším rozlišení sám.
    cameraResolution: const Size(1920, 1080),
  );

  /// Po prvním nálezu se skener umlčí – jinak by kamera pálila další
  /// detekce, zatímco už odcházíme na další obrazovku.
  bool _hotovo = false;
  bool _ctuStitek = false;

  @override
  void dispose() {
    _ovladac.dispose();
    super.dispose();
  }

  /// Kameru skener pustí **dřív, než se odejde**, a počká na to.
  ///
  /// Volající hned po návratu otevírá focení počítadla s vlastní kamerou.
  /// Kdyby se skener zastavil až s koncem animace zavírání (tak to dělá
  /// widget sám), zastavení na Androidu odpojí z CameraX všechno, co je
  /// v tu chvíli navázané – tedy i kameru focení, které se mezitím
  /// rozběhlo. Hledáček pak zamrzne na posledním snímku.
  Future<void> _naslo(NalezenyElektromer nalez) async {
    if (_hotovo) return;
    setState(() => _hotovo = true);
    try {
      await _ovladac.stop();
    } catch (_) {
      // Nepovedené zastavení nesmí zablokovat nalezené místo – v horším
      // případě kameru uvolní až zavření obrazovky, jako dřív.
    }
    if (!mounted) return;
    Navigator.of(context).pop(nalez);
  }

  void _zQr(BarcodeCapture zachyt) {
    if (_hotovo) return;
    for (final kod in zachyt.barcodes) {
      final obsah = kod.rawValue;
      if (obsah == null) continue;
      final nalez = najdiPodleQr(obsah, widget.elektromery);
      if (nalez != null) {
        _naslo(nalez);
        return;
      }
    }
  }

  /// Má aspoň jedno místo vyplněné výrobní číslo? Jen pak má smysl
  /// nabízet čtení čísla z výrobního štítku – bez čísel v evidenci není
  /// s čím porovnávat a tlačítko jen matlo (vypadalo jako „vytvořit
  /// QR štítek").
  bool get _lzeHledatPodleCisla => widget.elektromery.any((e) => e.maCislo);

  /// Vyfotí výrobní štítek měřidla a zkusí z něj přečíst výrobní číslo.
  ///
  /// Skener se na tu dobu zastaví: systémový fotoaparát potřebuje kameru
  /// pro sebe, a kdyby ji skener dál držel, na části Androidů by se
  /// fotoaparát neotevřel nebo by po návratu zamrzl obraz skeneru.
  Future<void> _zeStitku() async {
    if (_ctuStitek || _hotovo) return;
    setState(() => _ctuStitek = true);
    try {
      await _ovladac.stop();
      final foto = await ref
          .read(fotoSluzbaProvider)
          .nactiPocitadlo(ZdrojFoto.fotoaparat);
      final text = await ref
          .read(ocrSluzbaProvider)
          .prectiText(foto.cestaVSouborovemSystemu);
      if (!mounted) return;

      final nalez = najdiPodleCisla(text, widget.elektromery);
      if (nalez != null) return _naslo(nalez);

      setState(() => _ctuStitek = false);
      ukazVarovani(
        context,
        'Číslo ze štítku se nepodařilo spárovat s žádným evidovaným '
        'měřidlem. Zkuste to znovu, nebo ho vyberte ze seznamu.',
      );
    } on FoceniZruseno {
      if (mounted) setState(() => _ctuStitek = false);
    } catch (chyba) {
      if (!mounted) return;
      setState(() => _ctuStitek = false);
      ukazChybu(context, chyba);
    } finally {
      // Když se místo nenašlo, skenuje se dál.
      if (mounted && !_hotovo) await _ovladac.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Kód se hledá jen v nakresleném rámečku – na archu jsou
          // etikety těsně vedle sebe a bez výřezu se občas načetla
          // sousední.
          //
          // Výřez je celý rámeček, ne menší: dokumentace knihovny sice
          // tvrdí, že stačí kód, který do výřezu zasahuje, ale Android
          // chce všechny čtyři rohy kódu uvnitř a iOS hledá jen ve
          // výřezu. S polovičním výřezem musel být kód v obraze malý
          // a načítal se pomalu. Celý rámeček soused stejně nepustí –
          // ten se do něj celý nevejde.
          LayoutBuilder(
            builder: (context, rozmery) => MobileScanner(
              controller: _ovladac,
              onDetect: _zQr,
              scanWindow: Rect.fromCenter(
                center: rozmery.biggest.center(Offset.zero),
                width: _Zamerovac.velikost,
                height: _Zamerovac.velikost,
              ),
            ),
          ),

          // Zaměřovací rámeček. Na rozdíl od dřívějšího hledáčku
          // u focení tady opravdu leží nad živým obrazem z kamery.
          const Center(child: _Zamerovac()),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Zavřít skener',
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0x66000000),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Namiřte QR kód doprostřed rámečku',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(blurRadius: 6)],
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Kód chybí nebo je poškozený?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      shadows: [Shadow(blurRadius: 6)],
                    ),
                  ),
                  // Záloha bez QR je seznam s hledáním – skener se zavře
                  // a člověk místo najde podle názvu.
                  _OdkazNadObrazem(
                    popisek: 'Vybrat ze seznamu',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  if (_lzeHledatPodleCisla)
                    _OdkazNadObrazem(
                      popisek: _ctuStitek
                          ? 'Čtu výrobní číslo…'
                          : 'Přečíst výrobní číslo z měřidla',
                      onTap: _ctuStitek ? null : _zeStitku,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Textové tlačítko nad živým obrazem kamery – bílé se stínem, aby bylo
/// čitelné na světlém i tmavém pozadí.
class _OdkazNadObrazem extends StatelessWidget {
  const _OdkazNadObrazem({required this.popisek, required this.onTap});

  final String popisek;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
      child: Text(
        popisek,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white,
          shadows: [Shadow(blurRadius: 6)],
        ),
      ),
    );
  }
}

class _Zamerovac extends StatelessWidget {
  const _Zamerovac();

  static const double velikost = 240;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: velikost,
      height: velikost,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white70, width: 3),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
