import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/firebase/firebase_providery.dart';
import '../../auth/application/auth_providery.dart';
import '../data/foto_uloziste.dart';
import '../data/nabijeni_repository.dart';
import '../domain/relace.dart';

final nabijeniRepositoryProvider = Provider<NabijeniRepository>((ref) {
  return NabijeniRepository(db: ref.watch(firestoreProvider));
});

final fotoUlozisteProvider = Provider<FotoUloziste>((ref) {
  return FotoUloziste(storage: ref.watch(storageProvider));
});

/// Otevřená relace přihlášeného uživatele, nebo `null`.
final otevrenaRelaceProvider = StreamProvider<Relace?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(nabijeniRepositoryProvider).sledujOtevrenou(uid);
});

/// Historie relací uživatele, od nejnovější.
final historieProvider = StreamProvider<List<Relace>>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(const <Relace>[]);
  return ref.watch(nabijeniRepositoryProvider).sledujHistorii(uid);
});

/// Jedna relace pro detail. Sleduje se, aby se detail sám srovnal,
/// když relaci mezitím ukončíme.
final relaceProvider = StreamProvider.autoDispose.family<Relace?, String>((
  ref,
  relaceId,
) {
  return ref.watch(nabijeniRepositoryProvider).sleduj(relaceId);
});

/// Tik pro průběžné dopočítávání doby běžící relace. Půlminuta stačí –
/// doba se stejně ukazuje v minutách.
final tikProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

/// Odkaz ke stažení fotky ze Storage.
final odkazNaFotkuProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  cesta,
) {
  return ref.watch(fotoUlozisteProvider).odkazKeStazeni(cesta);
});
