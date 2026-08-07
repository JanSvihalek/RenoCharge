import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../data/auth_repository.dart';
import '../data/uzivatele_repository.dart';
import '../domain/uzivatel.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    db: ref.watch(firestoreProvider),
  );
});

final uzivateleRepositoryProvider = Provider<UzivateleRepository>((ref) {
  return UzivateleRepository(db: ref.watch(firestoreProvider));
});

/// Stav přihlášení. Nepřihlášený uživatel se dostane pouze na login.
final stavPrihlaseniProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).zmenyPrihlaseni();
});

/// UID přihlášeného uživatele, nebo `null`.
final uidProvider = Provider<String?>((ref) {
  return ref.watch(stavPrihlaseniProvider).value?.uid;
});

/// Profil z Firestore. Drží mimo jiné informaci o otevřené relaci.
final profilProvider = StreamProvider<Uzivatel?>((ref) {
  final uid = ref.watch(uidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(uzivateleRepositoryProvider).sleduj(uid);
});

/// Role přihlášeného uživatele. Dokud se profil načítá, platí ta
/// nejslabší – nová část aplikace se tím nemihne uživateli, který na ni
/// nemá právo.
final roleProvider = Provider<Role>((ref) {
  return ref.watch(profilProvider).value?.role ?? Role.uzivatel;
});

/// Řízení průběhu přihlášení a odhlášení.
class PrihlaseniController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> prihlas({required String email, required String heslo}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .prihlasEmailem(email: email, heslo: heslo),
    );
  }

  /// Vrací `true`, když se e-mail podařilo odeslat. Kvůli ochraně proti
  /// zjišťování účtů se úspěch hlásí i u neexistujícího e-mailu.
  Future<bool> posliResetHesla(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).posliResetHesla(email),
    );
    return !state.hasError;
  }

  Future<void> odhlas() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).odhlas(),
    );
  }

  /// Chyba k zobrazení, nebo `null`.
  static String? chybovaHlaska(AsyncValue<void> stav) {
    final chyba = stav.error;
    if (chyba == null) return null;
    final prevedena = AppChyba.zFirebase(chyba);
    if (prevedena is PrihlaseniZruseno) return null;
    return prevedena.zprava;
  }
}

final prihlaseniControllerProvider =
    AsyncNotifierProvider<PrihlaseniController, void>(PrihlaseniController.new);
