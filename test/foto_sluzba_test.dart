import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:renocharge/common/konfigurace.dart';
import 'package:renocharge/features/nabijeni/application/foto_sluzba.dart';
import 'package:renocharge/features/nabijeni/application/zmenseni_snimku.dart';
import 'package:renocharge/features/nabijeni/domain/foto_metadata.dart';
import 'package:renocharge/features/nabijeni/domain/porizena_fotografie.dart';

Uint8List _jpeg({required int sirka, required int vyska}) {
  final obrazek = img.Image(width: sirka, height: vyska);
  img.fill(obrazek, color: img.ColorRgb8(120, 140, 160));
  return img.encodeJpg(obrazek, quality: 95);
}

void main() {
  group('rozparsujExifCas', () {
    test('rozumí formátu z EXIF', () {
      expect(
        FotoSluzba.rozparsujExifCas('2026:08:03 14:22:51'),
        DateTime(2026, 8, 3, 14, 22, 51),
      );
    });

    test('s posunem převede na lokální čas', () {
      final cas = FotoSluzba.rozparsujExifCas(
        '2026:08:03 14:22:51',
        posun: '+02:00',
      );
      expect(cas, DateTime.utc(2026, 8, 3, 12, 22, 51).toLocal());
    });

    test('neplatný nebo chybějící údaj vrací null', () {
      expect(FotoSluzba.rozparsujExifCas(null), isNull);
      expect(FotoSluzba.rozparsujExifCas('    :  :     :  :  '), isNull);
      expect(FotoSluzba.rozparsujExifCas('1899:12:31 23:59:59'), isNull);
    });
  });

  group('spocitejOtisk', () {
    test('odpovídá známému SHA-256', () {
      final bajty = Uint8List.fromList(utf8.encode('abc'));
      expect(
        FotoSluzba.spocitejOtisk(bajty),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('jiné bajty dají jiný otisk', () {
      final a = FotoSluzba.spocitejOtisk(Uint8List.fromList([1, 2, 3]));
      final b = FotoSluzba.spocitejOtisk(Uint8List.fromList([1, 2, 4]));
      expect(a, isNot(b));
    });
  });

  group('zmensiProUlozeni', () {
    // Vlastní hledáček dodává plné rozlišení. Fotky ve Storage musí
    // vypadat stejně bez ohledu na to, kudy do aplikace přišly.
    test('srovná široký snímek na limit z konfigurace', () {
      final zmenseny = zmensiProUlozeni(_jpeg(sirka: 4032, vyska: 3024));
      final obrazek = img.decodeJpg(zmenseny)!;

      expect(obrazek.width, Konfigurace.maxSirkaFoto.round());
      expect(obrazek.height, 1200, reason: 'poměr stran zůstává');
    });

    test('užší snímek se nezvětšuje', () {
      final vysledek = zmensiProUlozeni(_jpeg(sirka: 800, vyska: 600));
      expect(img.decodeJpg(vysledek)!.width, 800);
    });

    // Kdyby snímek nešel rozkódovat, je větší soubor pořád lepší než
    // chybějící důkaz – nesmí se ztratit ani spadnout.
    test('nerozkódovatelný vstup se vrátí beze změny', () {
      final nesmysl = Uint8List.fromList([1, 2, 3, 4, 5]);
      expect(zmensiProUlozeni(nesmysl), nesmysl);
    });
  });

  group('zdroj fotky', () {
    test('projde tam a zpátky přes mapu', () {
      final metadata = FotoMetadata(
        path: 'nabijeni/r1/start.jpg',
        sha256: 'a' * 64,
        porizenoAt: DateTime(2026, 8, 3, 14, 22),
        zdroj: ZdrojFoto.galerie,
      );
      expect(FotoMetadata.zMapy(metadata.naMapu())!.zdroj, ZdrojFoto.galerie);
    });

    test('záznam bez pole zdroj bereme jako snímek z fotoaparátu', () {
      // Relace založené před přidáním výběru z galerie pole nemají.
      final stary = FotoMetadata.zMapy({
        'path': 'nabijeni/r0/start.jpg',
        'sha256': 'b' * 64,
      });
      expect(stary!.zdroj, ZdrojFoto.fotoaparat);
    });
  });
}
