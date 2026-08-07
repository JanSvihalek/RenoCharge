import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../auth/application/auth_providery.dart';
import '../data/elektromery_repository.dart';
import '../domain/elektromer.dart';
import '../domain/pobocka.dart';

final elektromeryRepositoryProvider = Provider<ElektromeryRepository>((ref) {
  return ElektromeryRepository(db: ref.watch(firestoreProvider));
});

/// Zvolená pobočka. Údržbář obchází pořád ten samý areál, takže volba
/// vydrží po celou dobu běhu aplikace.
class VybranaPobocka extends Notifier<Pobocka> {
  @override
  Pobocka build() => Pobocka.values.first;

  void vyber(Pobocka pobocka) => state = pobocka;
}

final vybranaPobockaProvider = NotifierProvider<VybranaPobocka, Pobocka>(
  VybranaPobocka.new,
);

/// Hledaný text v seznamu elektroměrů.
class Hledani extends Notifier<String> {
  @override
  String build() => '';

  void nastav(String dotaz) => state = dotaz;
}

final hledaniProvider = NotifierProvider<Hledani, String>(Hledani.new);

/// Elektroměry zvolené pobočky, seřazené podle umístění.
final elektromeryProvider = StreamProvider<List<Elektromer>>((ref) {
  if (ref.watch(uidProvider) == null) {
    return Stream.value(const <Elektromer>[]);
  }
  final pobocka = ref.watch(vybranaPobockaProvider);
  return ref.watch(elektromeryRepositoryProvider).sleduj(pobocka.kod);
});

/// Jeden elektroměr pro detail. Sleduje se, aby se detail sám srovnal
/// po úpravě.
final elektromerProvider = StreamProvider.autoDispose
    .family<Elektromer?, String>((ref, id) {
      return ref.watch(elektromeryRepositoryProvider).sledujJeden(id);
    });

/// Zakládání a úprava elektroměrů.
class ElektromeryController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> pridej({
    required Pobocka pobocka,
    required String cislo,
    required String nazev,
  }) async {
    final uid = ref.read(uidProvider);
    if (uid == null) {
      state = AsyncValue.error(const NeniPrihlasen(), StackTrace.current);
      return null;
    }
    state = const AsyncValue.loading();
    final vysledek = await AsyncValue.guard(
      () => ref
          .read(elektromeryRepositoryProvider)
          .pridej(
            pobockaKod: pobocka.kod,
            cislo: cislo,
            nazev: nazev,
            uid: uid,
          ),
    );
    state = vysledek.hasError
        ? AsyncValue.error(vysledek.error!, vysledek.stackTrace!)
        : const AsyncValue.data(null);
    return vysledek.value;
  }

  Future<bool> uprav({
    required Elektromer elektromer,
    required String cislo,
    required String nazev,
    required bool aktivni,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(elektromeryRepositoryProvider)
          .uprav(
            elektromer: elektromer,
            cislo: cislo,
            nazev: nazev,
            aktivni: aktivni,
          ),
    );
    return !state.hasError;
  }

  void vymazChybu() => state = const AsyncValue.data(null);
}

final elektromeryControllerProvider =
    AsyncNotifierProvider<ElektromeryController, void>(
      ElektromeryController.new,
    );
