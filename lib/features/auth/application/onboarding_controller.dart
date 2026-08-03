import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import 'auth_providery.dart';

/// Dokončení úvodního nastavení po prvním přihlášení.
class OnboardingController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Uloží jméno, osobní číslo a první vozidlo. Vrací `true` při úspěchu;
  /// obrazovku pak vystřídá hlavní rámec, protože se změní profil.
  Future<bool> dokonci({
    required String jmeno,
    required String osobniCislo,
    required String spz,
    String? znackaModel,
  }) async {
    if (state.isLoading) return false;

    final uzivatel = ref.read(authRepositoryProvider).prihlasenyUzivatel;
    if (uzivatel == null) {
      state = AsyncValue.error(const NeniPrihlasen(), StackTrace.current);
      return false;
    }
    if (jmeno.trim().isEmpty ||
        osobniCislo.trim().isEmpty ||
        spz.trim().isEmpty) {
      state = AsyncValue.error(
        const NeznamaChyba('Vyplňte prosím všechna povinná pole.'),
        StackTrace.current,
      );
      return false;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(uzivateleRepositoryProvider)
          .dokonciOnboarding(
            uid: uzivatel.uid,
            jmeno: jmeno,
            osobniCislo: osobniCislo,
            email: uzivatel.email ?? '',
            spz: spz,
            znackaModel: znackaModel,
          ),
    );
    return !state.hasError;
  }
}

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, void>(OnboardingController.new);
