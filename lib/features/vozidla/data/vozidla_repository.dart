import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../domain/vozidlo.dart';

/// CRUD nad vozidly uživatele – `uzivatele/{uid}/vozidla`.
class VozidlaRepository {
  VozidlaRepository({required FirebaseFirestore db}) : _db = db;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _kolekce(String uid) =>
      _db.collection(Kolekce.uzivatele).doc(uid).collection(Kolekce.vozidla);

  Stream<List<Vozidlo>> sleduj(String uid) => _kolekce(uid)
      .orderBy('spz')
      .snapshots()
      .map((snimek) => snimek.docs.map(Vozidlo.zDokumentu).toList())
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  Future<void> pridej({
    required String uid,
    required String spz,
    String? znackaModel,
  }) async {
    final ocistenaSpz = normalizujSpz(spz);
    final nazev = znackaModel?.trim();
    try {
      await _kolekce(uid).add({
        'spz': ocistenaSpz,
        'znacka_model': (nazev == null || nazev.isEmpty) ? null : nazev,
      });
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  Future<void> odeber({required String uid, required String vozidloId}) async {
    try {
      await _kolekce(uid).doc(vozidloId).delete();
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// SPZ se ukládá velkými písmeny a bez zdvojených mezer, ať se
  /// v historii nemíchají tvary zápisu.
  static String normalizujSpz(String vstup) =>
      vstup.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
}
