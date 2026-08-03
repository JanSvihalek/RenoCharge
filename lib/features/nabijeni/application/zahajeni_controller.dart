import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../auth/application/auth_providery.dart';
import '../../vozidla/application/vozidla_providery.dart';
import '../../vozidla/domain/vozidlo.dart';
import '../data/foto_uloziste.dart';
import '../domain/porizena_fotografie.dart';
import 'nabijeni_providery.dart';

/// Rozpracovaná volba na obrazovce zahájení nabíjení.
class ZahajeniStav {
  const ZahajeniStav({
    this.vozidloId,
    this.staniceId,
    this.konektor,
    this.odesilani = false,
    this.chyba,
  });

  final String? vozidloId;
  final String? staniceId;
  final String? konektor;
  final bool odesilani;
  final AppChyba? chyba;

  /// Dokud nejsou vybrané všechny tři volby, tlačítko dál nepustí.
  bool get jeKompletni =>
      vozidloId != null && staniceId != null && konektor != null;

  ZahajeniStav kopiruj({
    String? vozidloId,
    String? staniceId,
    String? konektor,
    bool? odesilani,
    AppChyba? chyba,
    bool vymazatChybu = false,
  }) => ZahajeniStav(
    vozidloId: vozidloId ?? this.vozidloId,
    staniceId: staniceId ?? this.staniceId,
    konektor: konektor ?? this.konektor,
    odesilani: odesilani ?? this.odesilani,
    chyba: vymazatChybu ? null : (chyba ?? this.chyba),
  );
}

/// Řídí výběr vozidla/stanice/konektoru a samotné založení relace.
class ZahajeniController extends Notifier<ZahajeniStav> {
  @override
  ZahajeniStav build() => const ZahajeniStav();

  void zacniZnovu() => state = const ZahajeniStav();

  void vyberVozidlo(String id) =>
      state = state.kopiruj(vozidloId: id, vymazatChybu: true);

  void vyberStanici(String id) {
    // Konektor patří ke konkrétní stanici – při změně stanice se výběr
    // konektoru ruší, ať uživatel nepotvrdí kombinaci, kterou neviděl.
    state = ZahajeniStav(vozidloId: state.vozidloId, staniceId: id);
  }

  void vyberKonektor(String konektor) =>
      state = state.kopiruj(konektor: konektor, vymazatChybu: true);

  /// Nahraje počáteční fotku a založí relaci ve stavu `probiha`.
  /// Vrací `true`, pokud se to povedlo.
  Future<bool> zahaj({
    required double kwhStart,
    required PorizenaFotografie foto,
  }) async {
    final volba = state;
    if (!volba.jeKompletni || volba.odesilani) return false;

    final uid = ref.read(uidProvider);
    if (uid == null) {
      state = volba.kopiruj(chyba: const NeniPrihlasen());
      return false;
    }

    final vozidla = ref.read(vozidlaProvider).value ?? const <Vozidlo>[];
    Vozidlo? vozidlo;
    for (final v in vozidla) {
      if (v.id == volba.vozidloId) {
        vozidlo = v;
        break;
      }
    }
    if (vozidlo == null) {
      state = volba.kopiruj(
        chyba: const NeznamaChyba('Vybrané vozidlo už není v seznamu.'),
      );
      return false;
    }

    state = volba.kopiruj(odesilani: true, vymazatChybu: true);

    final repo = ref.read(nabijeniRepositoryProvider);
    final uloziste = ref.read(fotoUlozisteProvider);
    final relaceId = repo.noveIdRelace();

    try {
      final metadata = await uloziste.nahraj(
        relaceId: relaceId,
        typ: TypFoto.start,
        foto: foto,
      );
      try {
        await repo.zahaj(
          relaceId: relaceId,
          uid: uid,
          spz: vozidlo.spz,
          vozidloId: volba.vozidloId!,
          staniceId: volba.staniceId!,
          konektor: volba.konektor!,
          kwhStart: kwhStart,
          fotoStart: metadata,
        );
      } catch (chyba) {
        // Relace nevznikla – ať po ní ve Storage nezůstává fotka.
        await uloziste.smazTiseji(metadata.path);
        rethrow;
      }
      state = const ZahajeniStav();
      return true;
    } catch (chyba) {
      state = state.kopiruj(odesilani: false, chyba: AppChyba.zFirebase(chyba));
      return false;
    }
  }
}

final zahajeniControllerProvider =
    NotifierProvider<ZahajeniController, ZahajeniStav>(ZahajeniController.new);
