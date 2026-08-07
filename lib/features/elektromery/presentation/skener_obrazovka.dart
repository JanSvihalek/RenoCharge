import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../common/chyby.dart';
import '../../../common/widgety/hlaseni.dart';
import '../../../common/widgety/tlacitka.dart';
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

  void _naslo(NalezenyElektromer nalez) {
    if (_hotovo) return;
    setState(() => _hotovo = true);
    Navigator.of(context).pop(nalez);
  }

  void _zQr(BarcodeCapture zachyt) {
    if (_hotovo) return;
    for (final kod in zachyt.barcodes) {
      final obsah = kod.rawValue;
      if (obsah == null) continue;
      final nalez = najdiPodleQr(obsah, widget.elektromery);
      if (nalez != null) return _naslo(nalez);
    }
  }

  /// Vyfotí štítek a zkusí z něj přečíst výrobní číslo.
  Future<void> _zeStitku() async {
    if (_ctuStitek || _hotovo) return;
    setState(() => _ctuStitek = true);
    try {
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
        'elektroměrem. Zkuste to znovu, nebo ho vyberte ze seznamu.',
      );
    } on FoceniZruseno {
      if (mounted) setState(() => _ctuStitek = false);
    } catch (chyba) {
      if (!mounted) return;
      setState(() => _ctuStitek = false);
      ukazChybu(context, chyba);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _ovladac, onDetect: _zQr),

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
                        'Namiřte na QR kód elektroměru',
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
                    'Nemá kód nebo je poškozený?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      shadows: [Shadow(blurRadius: 6)],
                    ),
                  ),
                  const SizedBox(height: 8),
                  PrimarniTlacitko(
                    popisek: 'Vyfotit štítek',
                    ikona: Icons.text_fields,
                    nacita: _ctuStitek,
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

class _Zamerovac extends StatelessWidget {
  const _Zamerovac();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white70, width: 3),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
