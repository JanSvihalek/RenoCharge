import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:renocharge/features/nabijeni/application/zahajeni_controller.dart';
import 'package:renocharge/features/nabijeni/domain/foto_metadata.dart';
import 'package:renocharge/features/nabijeni/domain/relace.dart';
import 'package:renocharge/features/vozidla/application/vozidla_providery.dart';
import 'package:renocharge/features/vozidla/data/vozidla_repository.dart';
import 'package:renocharge/features/vozidla/domain/vozidlo.dart';

FotoMetadata _foto(String path) =>
    FotoMetadata(path: path, sha256: 'x', porizenoAt: DateTime(2026, 8, 3, 7));

Relace _relace({double? kwhEnd, DateTime? ukonceno, StavRelace? stav}) =>
    Relace(
      id: 'r1',
      uid: 'u1',
      spz: '2AB 3344',
      vozidloId: 'v1',
      kwhStart: 18342.4,
      kwhEnd: kwhEnd,
      zahajeno: DateTime(2026, 8, 3, 7, 12),
      ukonceno: ukonceno,
      fotoStart: _foto('nabijeni/r1/start.jpg'),
      stav:
          stav ?? (kwhEnd == null ? StavRelace.probiha : StavRelace.dokonceno),
    );

void main() {
  group('Relace', () {
    test('spotřeba je rozdíl stavů počítadla', () {
      expect(_relace(kwhEnd: 18369.8).spotreba, closeTo(27.4, 0.001));
    });

    test('u běžící relace spotřeba ještě není', () {
      final relace = _relace();
      expect(relace.spotreba, isNull);
      expect(relace.probiha, isTrue);
    });

    test('doba běžící relace se počítá k aktuálnímu času', () {
      final relace = _relace();
      final doba = relace.doba(ted: DateTime(2026, 8, 3, 9, 42));
      expect(doba, const Duration(hours: 2, minutes: 30));
    });

    test('doba ukončené relace se počítá k času ukončení', () {
      final relace = _relace(
        kwhEnd: 18369.8,
        ukonceno: DateTime(2026, 8, 3, 12, 44),
      );
      final doba = relace.doba(ted: DateTime(2026, 8, 4));
      expect(doba, const Duration(hours: 5, minutes: 32));
    });
  });

  group('StavRelace', () {
    test('zná klíče z Firestore', () {
      expect(StavRelace.zKlice('probiha'), StavRelace.probiha);
      expect(StavRelace.zKlice('dokonceno'), StavRelace.dokonceno);
      expect(StavRelace.zKlice('schvaleno'), StavRelace.schvaleno);
    });

    test('neznámý klíč nepovažuje za probíhající', () {
      expect(StavRelace.zKlice(null), StavRelace.dokonceno);
      expect(StavRelace.zKlice('nesmysl'), StavRelace.dokonceno);
    });
  });

  group('Vozidlo', () {
    test('bez názvu je popisem samotná SPZ', () {
      expect(const Vozidlo(id: 'v1', spz: '2AB 3344').popis, '2AB 3344');
    });

    test('s názvem se popis skládá z obojího', () {
      const vozidlo = Vozidlo(
        id: 'v1',
        spz: '2AB 3344',
        znackaModel: 'Škoda Octavia',
      );
      expect(vozidlo.popis, 'Škoda Octavia · 2AB 3344');
    });
  });

  group('normalizujSpz', () {
    test('sjednotí velikost písmen a mezery', () {
      expect(VozidlaRepository.normalizujSpz('  5ab   1234 '), '5AB 1234');
    });
  });

  group('ZahajeniStav', () {
    test('bez vozidla se nedá pokračovat', () {
      expect(const ZahajeniStav().jeKompletni, isFalse);
      expect(const ZahajeniStav(vozidloId: 'v1').jeKompletni, isTrue);
    });
  });

  group('předvýběr vozidla', () {
    // Stanice ani konektor se nezadávají, takže vozidlo je jediná volba.
    // S jedním autem je i ta zbytečná – uživatel u nabíječky jen potvrdí.
    ProviderContainer sKontejnerem(List<Vozidlo> vozidla) {
      final kontejner = ProviderContainer.test(
        overrides: [
          vozidlaProvider.overrideWith((ref) => Stream.value(vozidla)),
        ],
      );
      // Bez posluchače se stream neodebírá a `future` by nikdy nedoběhl.
      kontejner.listen(vozidlaProvider, (_, _) {});
      kontejner.listen(zahajeniControllerProvider, (_, _) {});
      return kontejner;
    }

    test('jediné vozidlo se předvybere', () async {
      final kontejner = sKontejnerem(const [
        Vozidlo(id: 'v1', spz: '2AB 3344'),
      ]);
      kontejner.read(zahajeniControllerProvider);
      await kontejner.read(vozidlaProvider.future);

      expect(kontejner.read(zahajeniControllerProvider).vozidloId, 'v1');
    });

    test('při více vozidlech si uživatel vybírá sám', () async {
      final kontejner = sKontejnerem(const [
        Vozidlo(id: 'v1', spz: '2AB 3344'),
        Vozidlo(id: 'v2', spz: '5CD 1234'),
      ]);
      kontejner.read(zahajeniControllerProvider);
      await kontejner.read(vozidlaProvider.future);

      expect(kontejner.read(zahajeniControllerProvider).vozidloId, isNull);
    });

    test('vlastní volba se předvýběrem nepřepíše', () async {
      final kontejner = sKontejnerem(const [
        Vozidlo(id: 'v1', spz: '2AB 3344'),
        Vozidlo(id: 'v2', spz: '5CD 1234'),
      ]);
      kontejner.read(zahajeniControllerProvider.notifier).vyberVozidlo('v2');
      await kontejner.read(vozidlaProvider.future);

      expect(kontejner.read(zahajeniControllerProvider).vozidloId, 'v2');
    });
  });
}
