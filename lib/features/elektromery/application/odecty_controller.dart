import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../auth/application/auth_providery.dart';
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

/// Zapsání odečtu transakcí. Bez fotky – hodnota se zadává ručně po
/// načtení QR, viz `otevriZapisOdectu`.
class OdectyController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Vrací `true` při úspěchu. Chyba zůstává ve stavu pro obrazovku.
  Future<bool> zapis({
    required Elektromer elektromer,
    required double hodnota,
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
      await repo.zapis(
        odecetId: repo.noveId(),
        elektromer: elektromer,
        uid: uid,
        hodnota: hodnota,
        // Bez fotky není EXIF – odečítá se u měřidla, takže okamžik
        // zápisu je okamžik odečtu.
        odectenoAt: DateTime.now(),
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
