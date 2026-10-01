import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/chyby.dart';
import '../../auth/application/auth_providery.dart';
import '../../vozidla/application/vozidla_providery.dart';
import '../../vozidla/domain/vozidlo.dart';
import '../data/foto_uloziste.dart';
import '../data/nabijeni_repository.dart';
import '../domain/foto_metadata.dart';
import '../domain/porizena_fotografie.dart';
import 'nabijeni_providery.dart';

/// Rozpracovaná volba na obrazovce zahájení nabíjení.
class ZahajeniStav {
  const ZahajeniStav({this.vozidloId, this.odesilani = false, this.chyba});

  final String? vozidloId;
  final bool odesilani;
  final AppChyba? chyba;

  /// Dokud není vybrané vozidlo, tlačítko dál nepustí.
  bool get jeKompletni => vozidloId != null;

  ZahajeniStav kopiruj({
    String? vozidloId,
    bool? odesilani,
    AppChyba? chyba,
    bool vymazatChybu = false,
  }) => ZahajeniStav(
    vozidloId: vozidloId ?? this.vozidloId,
    odesilani: odesilani ?? this.odesilani,
    chyba: vymazatChybu ? null : (chyba ?? this.chyba),
  );
}

/// Řídí výběr vozidla a samotné založení relace.
class ZahajeniController extends Notifier<ZahajeniStav> {
  @override
  ZahajeniStav build() {
    // Seznam vozidel může v tuhle chvíli ještě běžet ze sítě, proto se
    // předvýběr dohání i po jeho dorazení. `listen` místo `watch` schválně:
    // `watch` by při každé změně seznamu spustil build znovu a smazal tím
    // rozdělaný výběr.
    ref.listen(vozidlaProvider, (_, novy) {
      if (state.vozidloId == null) {
        final jedine = _jedineVozidlo(novy.value);
        if (jedine != null) state = state.kopiruj(vozidloId: jedine);
      }
    });
    return _vychozi();
  }

  /// S jediným vozidlem není co vybírat – předvybere se, ať uživatel
  /// u nabíječky jen potvrdí. Obrazovka zůstává, aby bylo vidět, na které
  /// auto se záznam píše.
  ZahajeniStav _vychozi() =>
      ZahajeniStav(vozidloId: _jedineVozidlo(ref.read(vozidlaProvider).value));

  static String? _jedineVozidlo(List<Vozidlo>? vozidla) =>
      vozidla != null && vozidla.length == 1 ? vozidla.single.id : null;

  void zacniZnovu() => state = _vychozi();

  void vyberVozidlo(String id) =>
      state = state.kopiruj(vozidloId: id, vymazatChybu: true);

  /// Nahraje počáteční fotku a založí relaci ve stavu `probiha`.
  /// Vrací `true`, pokud se to povedlo.
  Future<bool> zahaj({
    required double kwhStart,
    required PorizenaFotografie foto,
  }) => _zapis(
    typFoto: TypFoto.start,
    foto: foto,
    zapis: (repo, relaceId, uid, vozidlo, metadata) => repo.zahaj(
      relaceId: relaceId,
      uid: uid,
      spz: vozidlo.spz,
      vozidloId: vozidlo.id,
      kwhStart: kwhStart,
      fotoStart: metadata,
    ),
  );

  /// Nabíječka bez počítadla: nahraje fotku displeje a zapíše rovnou
  /// dokončené nabíjení s energií z displeje. Vrací `true` při úspěchu.
  ///
  /// Fotka jde na místo koncové (`end.jpg`) – je pořízená po nabití
  /// a ukazuje výsledek, stejně jako koncová fotka počítadla.
  Future<bool> zapisPrimo({
    required double kwhNabito,
    required PorizenaFotografie foto,
  }) => _zapis(
    typFoto: TypFoto.end,
    foto: foto,
    zapis: (repo, relaceId, uid, vozidlo, metadata) => repo.zapisPrimo(
      relaceId: relaceId,
      uid: uid,
      spz: vozidlo.spz,
      vozidloId: vozidlo.id,
      kwhNabito: kwhNabito,
      foto: metadata,
    ),
  );

  Future<bool> _zapis({
    required TypFoto typFoto,
    required PorizenaFotografie foto,
    required Future<void> Function(
      NabijeniRepository repo,
      String relaceId,
      String uid,
      Vozidlo vozidlo,
      FotoMetadata metadata,
    )
    zapis,
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
        cil: CilFotky.nabijeni(uid: uid, relaceId: relaceId, typ: typFoto),
        foto: foto,
      );
      // Fotka je ve Storage dřív než záznam v Firestore, protože cesta
      // se odvozuje z ID relace vygenerovaného dopředu. Když zápis
      // selže, snímek tam zůstane osiřelý – mazat ho nejde a schválně:
      // pravidla nedovolují smazat žádnou fotku nikomu, jinak by z důkazu
      // bylo jen přání. Jde o stovky kB a uklidí se to dávkově zvenčí.
      await zapis(repo, relaceId, uid, vozidlo, metadata);
      state = _vychozi();
      return true;
    } catch (chyba) {
      state = state.kopiruj(odesilani: false, chyba: AppChyba.zFirebase(chyba));
      return false;
    }
  }
}

final zahajeniControllerProvider =
    NotifierProvider<ZahajeniController, ZahajeniStav>(ZahajeniController.new);
