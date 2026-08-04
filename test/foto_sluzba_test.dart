import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/nabijeni/application/foto_sluzba.dart';
import 'package:renocharge/features/nabijeni/domain/foto_metadata.dart';
import 'package:renocharge/features/nabijeni/domain/porizena_fotografie.dart';

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
