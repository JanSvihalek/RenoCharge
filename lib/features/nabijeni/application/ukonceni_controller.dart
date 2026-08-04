import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../auth/application/auth_providery.dart';
import '../data/foto_uloziste.dart';
import '../domain/porizena_fotografie.dart';
import '../domain/relace.dart';
import 'nabijeni_providery.dart';

/// Dokončení relace: nahraje koncovou fotku a doplní koncové hodnoty
/// do **téhož** dokumentu, který vznikl při zahájení.
class UkonceniController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  bool get probiha => state.isLoading;

  /// Vrací `true` při úspěchu. Chyba zůstává ve stavu, aby ji obrazovka
  /// mohla zobrazit.
  Future<bool> dokonci({
    required Relace relace,
    required double kwhEnd,
    required PorizenaFotografie foto,
  }) async {
    if (state.isLoading) return false;

    final uid = ref.read(uidProvider);
    if (uid == null) {
      state = AsyncValue.error(const NeniPrihlasen(), StackTrace.current);
      return false;
    }
    // Stejná podmínka platí i v transakci; tady jde o rychlou zpětnou
    // vazbu, ať uživatel nečeká na nahrání fotky kvůli překlepu.
    if (kwhEnd <= relace.kwhStart) {
      state = AsyncValue.error(
        NeplatnyKoncovyStav(relace.kwhStart),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();
    try {
      final metadata = await ref
          .read(fotoUlozisteProvider)
          .nahraj(uid: uid, relaceId: relace.id, typ: TypFoto.end, foto: foto);
      await ref
          .read(nabijeniRepositoryProvider)
          .ukonci(
            relaceId: relace.id,
            uid: uid,
            kwhEnd: kwhEnd,
            fotoEnd: metadata,
          );
      state = const AsyncValue.data(null);
      return true;
    } catch (chyba, stopa) {
      state = AsyncValue.error(AppChyba.zFirebase(chyba), stopa);
      return false;
    }
  }

  void vymazChybu() => state = const AsyncValue.data(null);
}

final ukonceniControllerProvider =
    AsyncNotifierProvider<UkonceniController, void>(UkonceniController.new);
