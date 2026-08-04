import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../auth/application/auth_providery.dart';

/// Uložení předpokládané ceny za kWh do profilu.
class CenaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// `null` sazbu smaže – aplikace pak o penězích nemluví vůbec.
  /// Vrací `true` při úspěchu, chyba zůstává ve stavu pro obrazovku.
  Future<bool> uloz(double? cena) async {
    final uid = ref.read(uidProvider);
    if (uid == null) {
      state = AsyncValue.error(const NeniPrihlasen(), StackTrace.current);
      return false;
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(uzivateleRepositoryProvider)
          .nastavCenuZaKwh(uid: uid, cena: cena),
    );
    return !state.hasError;
  }

  void vymazChybu() => state = const AsyncValue.data(null);
}

final cenaControllerProvider = AsyncNotifierProvider<CenaController, void>(
  CenaController.new,
);
