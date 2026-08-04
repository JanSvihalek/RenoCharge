import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Fotky jdou do Storage v 1600 px, což je zhruba 200–500 kB na snímek.
/// Měsíční report s dvaceti nabíjeními by tak měl 5–12 MB a přes leckterý
/// mailový server by neprošel. Pro PDF se proto přepočítají na užší
/// rozměr – číslo na displeji zůstane čitelné, ale soubor spadne
/// zhruba na pětinu.
const int sirkaProPdf = 1000;
const int kvalitaProPdf = 70;

/// Běží přes `compute()` v samostatné izolaci, proto to musí být funkce
/// nejvyšší úrovně s jediným argumentem. Dekódování a překódování JPEGu
/// trvá u každého snímku desítky až stovky milisekund a na hlavní
/// izolaci by to sekalo UI.
Uint8List zmensiProPdf(Uint8List puvodni) {
  final obrazek = img.decodeJpg(puvodni);
  // Nerozkódovaný snímek radši vložíme tak, jak je – větší soubor je
  // pořád lepší než chybějící důkaz.
  if (obrazek == null) return puvodni;
  if (obrazek.width <= sirkaProPdf) return puvodni;

  final zmenseny = img.copyResize(
    obrazek,
    width: sirkaProPdf,
    interpolation: img.Interpolation.average,
  );
  final vysledek = img.encodeJpg(zmenseny, quality: kvalitaProPdf);

  // U už tak malého snímku může překódování soubor naopak nafouknout.
  return vysledek.length < puvodni.length ? vysledek : puvodni;
}
