import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../auth/application/auth_providery.dart';
import '../data/vozidla_repository.dart';
import '../domain/vozidlo.dart';

final vozidlaRepositoryProvider = Provider<VozidlaRepository>((ref) {
  return VozidlaRepository(db: ref.watch(firestoreProvider));
});

/// Vozidla přihlášeného uživatele.
final vozidlaProvider = StreamProvider<List<Vozidlo>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <Vozidlo>[]);
  return ref.watch(vozidlaRepositoryProvider).sleduj(uid);
});

/// Přidávání a odebírání vozidel.
class VozidlaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> pridej({required String spz, String? nazev}) async {
    final uid = ref.read(uidProvider);
    if (uid == null) throw const NeniPrihlasen();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(vozidlaRepositoryProvider)
          .pridej(uid: uid, spz: spz, znackaModel: nazev),
    );
    return !state.hasError;
  }

  Future<bool> odeber(String vozidloId) async {
    final uid = ref.read(uidProvider);
    if (uid == null) throw const NeniPrihlasen();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(vozidlaRepositoryProvider)
          .odeber(uid: uid, vozidloId: vozidloId),
    );
    return !state.hasError;
  }
}

final vozidlaControllerProvider =
    AsyncNotifierProvider<VozidlaController, void>(VozidlaController.new);
