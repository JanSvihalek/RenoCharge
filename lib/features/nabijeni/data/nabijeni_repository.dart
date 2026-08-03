import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../../common/konfigurace.dart';
import '../domain/foto_metadata.dart';
import '../domain/relace.dart';

/// Zápis a čtení nabíjecích relací.
///
/// Dvě pravidla se dají porušit jen souběhem dvou telefonů, proto je
/// obě hlídá Firestore transakce, ne dotaz před zápisem:
///  * uživatel smí mít nejvýš jednu otevřenou relaci,
///  * na jednom konektoru smí být nejvýš jedna otevřená relace.
///
/// Klientské SDK umí v transakci číst jen konkrétní dokument (ne dotaz),
/// proto k tomu slouží dvě pomocné evidence:
///  * `uzivatele/{uid}.aktivni_nabijeni_id`,
///  * `zamky_konektoru/{staniceId}__{konektor}`.
class NabijeniRepository {
  NabijeniRepository({required FirebaseFirestore db}) : _db = db;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _relace =>
      _db.collection(Kolekce.nabijeni);

  DocumentReference<Map<String, dynamic>> _profil(String uid) =>
      _db.collection(Kolekce.uzivatele).doc(uid);

  DocumentReference<Map<String, dynamic>> _zamek(
    String staniceId,
    String konektor,
  ) => _db
      .collection(Kolekce.zamkyKonektoru)
      .doc(Kolekce.zamekId(staniceId, konektor));

  /// ID nové relace se generuje dopředu: fotka se nahrává na cestu
  /// odvozenou z ID ještě předtím, než dokument vznikne.
  String noveIdRelace() => _relace.doc().id;

  /// Otevřená relace uživatele, nebo `null`.
  Stream<Relace?> sledujOtevrenou(String uid) => _relace
      .where('uid', isEqualTo: uid)
      .where('stav', isEqualTo: StavRelace.probiha.klic)
      .limit(1)
      .snapshots()
      .map(
        (snimek) =>
            snimek.docs.isEmpty ? null : Relace.zDokumentu(snimek.docs.first),
      )
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  /// Historie od nejnovější relace.
  Stream<List<Relace>> sledujHistorii(
    String uid, {
    int limit = Konfigurace.limitHistorie,
  }) => _relace
      .where('uid', isEqualTo: uid)
      .orderBy('zahajeno', descending: true)
      .limit(limit)
      .snapshots()
      .map((snimek) => snimek.docs.map(Relace.zDokumentu).toList())
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  Stream<Relace?> sleduj(String relaceId) => _relace
      .doc(relaceId)
      .snapshots()
      .map((doc) => doc.exists ? Relace.zDokumentu(doc) : null)
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  Future<Relace?> nacti(String relaceId) async {
    try {
      final doc = await _relace.doc(relaceId).get();
      return doc.exists ? Relace.zDokumentu(doc) : null;
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Založí relaci ve stavu `probiha`.
  ///
  /// Vyhodí [JizMateOtevrenouRelaci], pokud uživatel jednu rozdělanou má,
  /// nebo [KonektorObsazen], pokud na konektoru nabíjí někdo jiný.
  Future<void> zahaj({
    required String relaceId,
    required String uid,
    required String spz,
    required String vozidloId,
    required String staniceId,
    required String konektor,
    required double kwhStart,
    required FotoMetadata fotoStart,
  }) async {
    final relaceRef = _relace.doc(relaceId);
    final zamekRef = _zamek(staniceId, konektor);
    final profilRef = _profil(uid);

    try {
      await _db.runTransaction((tx) async {
        // Všechna čtení musí proběhnout před prvním zápisem.
        final profil = await tx.get(profilRef);
        final zamek = await tx.get(zamekRef);

        final rozdelanaId = profil.data()?['aktivni_nabijeni_id'] as String?;
        if (rozdelanaId != null && await _jeOtevrena(tx, rozdelanaId)) {
          throw JizMateOtevrenouRelaci(rozdelanaId);
        }

        if (zamek.exists) {
          final drziId = zamek.data()?['nabijeni_id'] as String?;
          final drziUid = zamek.data()?['uid'] as String?;
          // Cizí zámek konektor blokuje vždy – na relaci jiného uživatele
          // se ani podívat nesmíme. Vlastní zámek po doběhlé relaci ale
          // umíme uklidit sami.
          final jeMuj = drziUid == uid;
          if (!jeMuj || drziId == null || await _jeOtevrena(tx, drziId)) {
            throw const KonektorObsazen();
          }
        }

        tx.set(
          relaceRef,
          Relace.mapaProZalozeni(
            uid: uid,
            spz: spz,
            vozidloId: vozidloId,
            staniceId: staniceId,
            konektor: konektor,
            kwhStart: kwhStart,
            zahajeno: fotoStart.porizenoAt,
            fotoStart: fotoStart,
          ),
        );
        tx.set(zamekRef, {
          'nabijeni_id': relaceId,
          'uid': uid,
          'stanice_id': staniceId,
          'konektor': konektor,
          'zahajeno': Timestamp.fromDate(fotoStart.porizenoAt),
        });
        tx.set(profilRef, {
          'aktivni_nabijeni_id': relaceId,
        }, SetOptions(merge: true));
      });
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Doplní koncové hodnoty a překlopí relaci do stavu `dokonceno`.
  ///
  /// Vyhodí [NeplatnyKoncovyStav], pokud koncový stav počítadla není
  /// vyšší než počáteční, a [RelaceJizUkoncena], pokud už někdo relaci
  /// mezitím uzavřel.
  Future<void> ukonci({
    required String relaceId,
    required String uid,
    required double kwhEnd,
    required FotoMetadata fotoEnd,
  }) async {
    final relaceRef = _relace.doc(relaceId);
    final profilRef = _profil(uid);

    try {
      await _db.runTransaction((tx) async {
        final snimek = await tx.get(relaceRef);
        if (!snimek.exists) throw const ZaznamNenalezen();
        final relace = Relace.zDokumentu(snimek);
        if (relace.uid != uid) throw const NedostatecnaOpravneni();
        if (!relace.probiha) throw const RelaceJizUkoncena();
        if (kwhEnd <= relace.kwhStart) {
          throw NeplatnyKoncovyStav(relace.kwhStart);
        }

        final zamekRef = _zamek(relace.staniceId, relace.konektor);
        final zamek = await tx.get(zamekRef);

        tx.update(
          relaceRef,
          Relace.mapaProUkonceni(
            kwhEnd: kwhEnd,
            ukonceno: _casUkonceni(relace.zahajeno, fotoEnd.porizenoAt),
            fotoEnd: fotoEnd,
          ),
        );
        // Zámek mažeme jen tehdy, když opravdu patří téhle relaci.
        if (zamek.exists && zamek.data()?['nabijeni_id'] == relaceId) {
          tx.delete(zamekRef);
        }
        tx.set(profilRef, {
          'aktivni_nabijeni_id': null,
        }, SetOptions(merge: true));
      });
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Čas ukončení bereme z EXIF koncové fotky. Když jsou hodiny telefonu
  /// mimo a vyšel by záporný interval, sáhneme po aktuálním čase.
  static DateTime _casUkonceni(DateTime zahajeno, DateTime zExif) =>
      zExif.isAfter(zahajeno) ? zExif : DateTime.now();

  Future<bool> _jeOtevrena(Transaction tx, String relaceId) async {
    final snimek = await tx.get(_relace.doc(relaceId));
    if (!snimek.exists) return false;
    return snimek.data()?['stav'] == StavRelace.probiha.klic;
  }
}
