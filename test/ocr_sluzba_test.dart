import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/nabijeni/application/ocr_sluzba.dart';

void main() {
  group('parsujToken', () {
    test('bere desetinnou čárku i tečku', () {
      expect(OcrSluzba.parsujToken('18342,4'), 18342.4);
      expect(OcrSluzba.parsujToken('18342.4'), 18342.4);
    });

    test('mezera i tečka slouží jako oddělovač tisíců', () {
      expect(OcrSluzba.parsujToken('18 342,4'), 18342.4);
      expect(OcrSluzba.parsujToken('18.342,4'), 18342.4);
      expect(OcrSluzba.parsujToken('12.345'), 12345);
    });

    test('odmítne nesmysly a nulu', () {
      expect(OcrSluzba.parsujToken(''), isNull);
      expect(OcrSluzba.parsujToken(',,'), isNull);
      expect(OcrSluzba.parsujToken('0'), isNull);
      expect(OcrSluzba.parsujToken('99999999'), isNull);
    });
  });

  group('vyberHodnotu', () {
    test('dá přednost číslu na řádku s jednotkou', () {
      final hodnota = OcrSluzba.vyberHodnotu([
        'STANICE 07',
        '18342,4 kWh',
        '2026',
      ]);
      expect(hodnota, 18342.4);
    });

    test('bez jednotky vezme nejdelší číslo s desetinami', () {
      final hodnota = OcrSluzba.vyberHodnotu(['A 12', '9 118,0', '31']);
      expect(hodnota, 9118.0);
    });

    test('krátké údaje nepovažuje za stav počítadla', () {
      expect(OcrSluzba.vyberHodnotu(['A', 'B', '7']), isNull);
    });

    test('když není co číst, vrátí null', () {
      expect(OcrSluzba.vyberHodnotu(const []), isNull);
      expect(OcrSluzba.vyberHodnotu(['zcela nečitelné']), isNull);
    });
  });
}
