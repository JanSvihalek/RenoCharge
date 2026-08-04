import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../../common/konfigurace.dart';
import '../domain/foto_metadata.dart';
import '../domain/relace.dart';

/// Zápis a čtení nabíjecích relací.
///
/// Uživatel smí mít nejvýš jednu otevřenou relaci. Porušit se to dá jen
/// souběhem dvou telefonů, proto to hlídá Firestore transakce, ne dotaz
/// před zápisem. Klientské SDK ale umí v transakci číst jen konkrétní
/// dokument (ne dotaz), odtud pomocné `uzivatele/{uid}.aktivni_nabijeni_id`.
class NabijeniRepository {
  NabijeniRepository({required FirebaseFirestore db}) : _db = db;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _relace =>
      _db.collection(Kolekce.nabijeni);

  DocumentReference<Map<String, dynamic>> _profil(String uid) =>
      _db.collection(Kolekce.uzivatele).doc(uid);

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
  /// Vyhodí [JizMateOtevrenouRelaci], pokud uživatel jednu rozdělanou má.
  Future<void> zahaj({
    required String relaceId,
    required String uid,
    required String spz,
    required String vozidloId,
    required double kwhStart,
    required FotoMetadata fotoStart,
  }) async {
    final relaceRef = _relace.doc(relaceId);
    final profilRef = _profil(uid);

    try {
      await _db.runTransaction((tx) async {
        // Všechna čtení musí proběhnout před prvním zápisem.
        final profil = await tx.get(profilRef);

        final rozdelanaId = profil.data()?['aktivni_nabijeni_id'] as String?;
        if (rozdelanaId != null && await _jeOtevrena(tx, rozdelanaId)) {
          throw JizMateOtevrenouRelaci(rozdelanaId);
        }

        tx.set(
          relaceRef,
          Relace.mapaProZalozeni(
            uid: uid,
            spz: spz,
            vozidloId: vozidloId,
            kwhStart: kwhStart,
            zahajeno: fotoStart.porizenoAt,
            fotoStart: fotoStart,
          ),
        );
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

        tx.update(
          relaceRef,
          Relace.mapaProUkonceni(
            kwhEnd: kwhEnd,
            ukonceno: _casUkonceni(relace.zahajeno, fotoEnd.porizenoAt),
            fotoEnd: fotoEnd,
          ),
        );
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
