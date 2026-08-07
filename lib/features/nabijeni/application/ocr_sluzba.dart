import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Přečtení stavu počítadla z fotky. Běží na zařízení, bez odesílání
/// snímku kamkoli.
///
/// Výsledek je **pomůcka, ne autorita**: pole s hodnotou je vždy
/// editovatelné a uživatel ji musí potvrdit. Když OCR nic nenajde,
/// ruční zadání je rovnocenná cesta, ne nouzové řešení.
class OcrSluzba {
  OcrSluzba({TextRecognizer? rozpoznavac})
    : _rozpoznavac =
          rozpoznavac ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _rozpoznavac;

  /// Vrátí nejpravděpodobnější hodnotu počítadla, nebo `null`.
  Future<double?> najdiHodnotu(String cestaKSouboru) async {
    try {
      final vysledek = await _rozpoznavac.processImage(
        InputImage.fromFilePath(cestaKSouboru),
      );
      final radky = <String>[
        for (final blok in vysledek.blocks)
          for (final radek in blok.lines) radek.text,
      ];
      return vyberHodnotu(radky.isEmpty ? [vysledek.text] : radky);
    } catch (_) {
      // Selhání OCR není chyba, kterou by měl uživatel řešit – prostě
      // hodnotu zadá ručně.
      return null;
    }
  }

  /// Surový text ze snímku. Používá se u štítku elektroměru, kde se
  /// nehledá stav počítadla, ale výrobní číslo – vytáhnout ho z textu
  /// umí až volající.
  Future<String> prectiText(String cestaKSouboru) async {
    try {
      final vysledek = await _rozpoznavac.processImage(
        InputImage.fromFilePath(cestaKSouboru),
      );
      return vysledek.text;
    } catch (_) {
      // Selhání OCR není chyba, kterou by měl uživatel řešit – prostě
      // se nic nenajde a nabídne se výběr ze seznamu.
      return '';
    }
  }

  Future<void> zavri() => _rozpoznavac.close();

  /// Vybere z rozpoznaných řádků číslo, které nejspíš je stavem
  /// počítadla. Čistá funkce, aby se dala testovat bez ML Kitu.
  static double? vyberHodnotu(List<String> radky) {
    double? nejlepsi;
    int nejlepsiSkore = -1;

    for (final radek in radky) {
      final maJednotku = RegExp(
        r'kwh|kw\s*h',
        caseSensitive: false,
      ).hasMatch(radek);

      for (final shoda in _cislo.allMatches(radek)) {
        final token = shoda.group(0)!;
        final hodnota = parsujToken(token);
        if (hodnota == null) continue;

        final cislic = token.replaceAll(RegExp(r'\D'), '').length;
        var skore = cislic * 5;
        if (maJednotku) skore += 100;
        // Stav počítadla se skoro vždy ukazuje s desetinami.
        if (RegExp(r'[.,]\d{1,2}$').hasMatch(token)) skore += 30;
        // Jednociferné údaje bývají popisky, ne stav počítadla.
        if (cislic <= 2) skore -= 40;

        if (skore > nejlepsiSkore) {
          nejlepsiSkore = skore;
          nejlepsi = hodnota;
        }
      }
    }
    return nejlepsi;
  }

  static final RegExp _cislo = RegExp(r'\d[\d.,  ]*\d|\d');

  /// Převede rozpoznaný token na číslo. Rozlišuje desetinnou čárku
  /// a oddělovač tisíců: `18 342,4` → 18342.4, `12.345` → 12345.
  static double? parsujToken(String token) {
    var text = token.replaceAll(RegExp(r'[\s ]'), '');
    if (text.isEmpty) return null;

    final posledniCarka = text.lastIndexOf(',');
    final posledniTecka = text.lastIndexOf('.');
    final posledni = posledniCarka > posledniTecka
        ? posledniCarka
        : posledniTecka;

    if (posledni >= 0) {
      final zaOddelovacem = text.length - posledni - 1;
      final jeDesetinny = zaOddelovacem >= 1 && zaOddelovacem <= 2;
      if (jeDesetinny) {
        final celaCast = text
            .substring(0, posledni)
            .replaceAll(RegExp(r'[.,]'), '');
        text = '$celaCast.${text.substring(posledni + 1)}';
      } else {
        text = text.replaceAll(RegExp(r'[.,]'), '');
      }
    }

    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) return null;
    final hodnota = double.tryParse(text);
    if (hodnota == null || hodnota <= 0) return null;
    // Nad tímhle řádem už nejde o stav počítadla, ale o špatné čtení.
    if (hodnota >= 10000000) return null;
    return hodnota;
  }
}

final ocrSluzbaProvider = Provider<OcrSluzba>((ref) {
  final sluzba = OcrSluzba();
  ref.onDispose(sluzba.zavri);
  return sluzba;
});
