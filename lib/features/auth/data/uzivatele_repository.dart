import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../vozidla/data/vozidla_repository.dart';
import '../domain/uzivatel.dart';

/// Čtení profilu přihlášeného uživatele.
class UzivateleRepository {
  UzivateleRepository({required FirebaseFirestore db}) : _db = db;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String uid) =>
      _db.collection(Kolekce.uzivatele).doc(uid);

  Stream<Uzivatel?> sleduj(String uid) => _ref(uid)
      .snapshots()
      .map((doc) => doc.exists ? Uzivatel.zDokumentu(doc) : null)
      .handleError((Object chyba) => throw AppChyba.zFirebase(chyba));

  Future<Uzivatel?> nacti(String uid) async {
    try {
      final doc = await _ref(uid).get();
      return doc.exists ? Uzivatel.zDokumentu(doc) : null;
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Uloží údaje z úvodního nastavení včetně prvního vozidla.
  ///
  /// `onboarding_at` je zároveň příznak, že uživatel nastavením prošel –
  /// dokud chybí, aplikace ho dál nepustí.
  ///
  /// Profil i vozidlo se zapisují jednou dávkou. Kdyby se zapsalo jen
  /// vozidlo, uživatel by zůstal v onboardingu a na druhý pokus by si
  /// tutéž SPZ přidal podruhé.
  Future<void> dokonciOnboarding({
    required String uid,
    required String jmeno,
    required String osobniCislo,
    required String email,
    required String spz,
    String? znackaModel,
  }) async {
    final davka = _db.batch();

    davka.set(_ref(uid), {
      'jmeno': jmeno.trim(),
      'osobni_cislo': osobniCislo.trim(),
      'email': email,
      'onboarding_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final nazev = znackaModel?.trim();
    davka.set(_ref(uid).collection(Kolekce.vozidla).doc(), {
      'spz': VozidlaRepository.normalizujSpz(spz),
      'znacka_model': (nazev == null || nazev.isEmpty) ? null : nazev,
    });

    try {
      await davka.commit();
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Uloží předpokládanou cenu za kWh, nebo ji smaže (`null`).
  ///
  /// Bez zadané sazby aplikace o penězích nemluví, proto se maže hodnotou
  /// `null` a ne nulou – nula by znamenala „nabíjím zdarma".
  Future<void> nastavCenuZaKwh({required String uid, double? cena}) async {
    try {
      await _ref(uid).set({'cena_za_kwh': cena}, SetOptions(merge: true));
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }
}
