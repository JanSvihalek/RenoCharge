import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../auth/application/auth_providery.dart';
import '../../nabijeni/application/nabijeni_providery.dart';
import '../../nabijeni/data/foto_uloziste.dart';
import '../../nabijeni/domain/porizena_fotografie.dart';
import '../data/odecty_repository.dart';
import '../domain/elektromer.dart';
import '../domain/odecet.dart';

final odectyRepositoryProvider = Provider<OdectyRepository>((ref) {
  return OdectyRepository(db: ref.watch(firestoreProvider));
});

/// Historie odečtů jednoho elektroměru, od nejnovějšího, se spotřebou
/// dopočítanou mezi sousedními záznamy.
final historieOdectuProvider = StreamProvider.autoDispose
    .family<List<OdecetSeSpotrebou>, String>((ref, elektromerId) {
      return ref
          .watch(odectyRepositoryProvider)
          .sledujProElektromer(elektromerId)
          .map(dopocitejSpotrebu);
    });

/// Zapsání odečtu: nahrání fotky a zápis transakcí.
class OdectyController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Vrací `true` při úspěchu. Chyba zůstává ve stavu pro obrazovku.
  Future<bool> zapis({
    required Elektromer elektromer,
    required double hodnota,
    required PorizenaFotografie foto,
    bool vymenaMeridla = false,
    String? poznamka,
  }) async {
    final uid = ref.read(uidProvider);
    if (uid == null) {
      state = AsyncValue.error(const NeniPrihlasen(), StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(odectyRepositoryProvider);
      final odecetId = repo.noveId();

      // Fotka jde do Storage dřív než záznam, protože cesta se odvozuje
      // z ID vygenerovaného dopředu. Když transakce selže, snímek zůstane
      // osiřelý – mazat ho pravidla nedovolují nikomu, aby z důkazu
      // nebylo jen přání.
      final metadata = await ref
          .read(fotoUlozisteProvider)
          .nahraj(
            cil: CilFotky.odecet(uid: uid, odecetId: odecetId),
            foto: foto,
          );

      await repo.zapis(
        odecetId: odecetId,
        elektromer: elektromer,
        uid: uid,
        hodnota: hodnota,
        // Čas z EXIF – okamžik, kdy se počítadlo opravdu odečetlo.
        odectenoAt: foto.porizenoAt,
        foto: metadata,
        vymenaMeridla: vymenaMeridla,
        poznamka: poznamka,
      );
    });
    return !state.hasError;
  }

  void vymazChybu() => state = const AsyncValue.data(null);
}

final odectyControllerProvider = AsyncNotifierProvider<OdectyController, void>(
  OdectyController.new,
);
