import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../common/konfigurace.dart';

/// Snímek z vlastního fotoaparátu chodí v plném rozlišení – u dnešních
/// telefonů to jsou jednotky megabajtů. Před uložením se srovná na stejný
/// rozměr a kvalitu, jaké dodával fotopicker, aby fotky ve Storage
/// vypadaly stejně bez ohledu na to, kudy do aplikace přišly.
///
/// Běží přes `compute()` v samostatné izolaci, proto to musí být funkce
/// nejvyšší úrovně s jediným argumentem – překódování JPEGu trvá stovky
/// milisekund a na hlavní izolaci by seklo UI.
Uint8List zmensiProUlozeni(Uint8List puvodni) {
  // Poškozený snímek radši uložíme tak, jak je – větší nebo divný soubor
  // je pořád lepší než chybějící důkaz. `decodeJpg` na nesmyslných datech
  // umí i vyhodit výjimku, nejen vrátit null.
  final img.Image? nacteny;
  try {
    nacteny = img.decodeJpg(puvodni);
  } catch (_) {
    return puvodni;
  }
  if (nacteny == null) return puvodni;

  // Fotoaparát na iOS ukládá otočení do EXIF a pixely nechává, jak jsou.
  // Bez tohohle kroku by fotka po překódování ležela na boku.
  final obrazek = img.bakeOrientation(nacteny);

  final sirka = Konfigurace.maxSirkaFoto.round();
  final zmenseny = obrazek.width <= sirka
      ? obrazek
      : img.copyResize(
          obrazek,
          width: sirka,
          interpolation: img.Interpolation.average,
        );

  return img.encodeJpg(zmenseny, quality: Konfigurace.kvalitaFoto);
}
