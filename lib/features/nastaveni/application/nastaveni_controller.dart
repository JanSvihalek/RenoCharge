import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../auth/application/auth_providery.dart';
import '../../nabijeni/application/zaloha_fotek.dart';

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

/// Přepínání záloh fotek do galerie telefonu.
class ZalohaController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Vrací `true` při úspěchu. Při zapínání si nejdřív řekne o právo
  /// zapisovat do galerie – tady je na to správné místo, protože
  /// odmítnutí jde vysvětlit. U nabíječky už by na to bylo pozdě.
  Future<bool> nastav({required bool zapnuto}) async {
    final uid = ref.read(uidProvider);
    if (uid == null) {
      state = AsyncValue.error(const NeniPrihlasen(), StackTrace.current);
      return false;
    }

    if (zapnuto) {
      state = const AsyncValue.loading();
      final smi = await ref.read(zalohaFotekProvider).zajistiPravo();
      if (!smi) {
        state = AsyncValue.error(const GalerieNedostupna(), StackTrace.current);
        return false;
      }
    }

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(uzivateleRepositoryProvider)
          .nastavZalohovaniFotek(uid: uid, zalohovat: zapnuto),
    );
    return !state.hasError;
  }

  void vymazChybu() => state = const AsyncValue.data(null);
}

final zalohaControllerProvider = AsyncNotifierProvider<ZalohaController, void>(
  ZalohaController.new,
);
