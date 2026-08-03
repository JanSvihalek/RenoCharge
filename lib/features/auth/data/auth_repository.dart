import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../common/chyby.dart';
import '../../../common/firebase/firebase_providery.dart';
import '../../../common/konfigurace.dart';

/// Přihlašování zaměstnance.
///
/// Aplikace **neumí registraci** – účty zakládá správce (viz
/// `tools/vytvor_uzivatele.mjs`). Nepřihlášený uživatel se dostane
/// pouze na přihlašovací obrazovku.
///
/// Ve fázi 1 se přihlašuje e-mailem a heslem. Cílový stav je firemní
/// účet přes Microsoft OIDC – [prihlasFiremnimUctem] je připravená
/// a zapne se, jakmile bude hotová registrace aplikace v Entra ID.
class AuthRepository {
  AuthRepository({required FirebaseAuth auth, required FirebaseFirestore db})
    : _auth = auth,
      _db = db;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> zmenyPrihlaseni() => _auth.authStateChanges();

  User? get prihlasenyUzivatel => _auth.currentUser;

  String get uid {
    final u = _auth.currentUser;
    if (u == null) throw const NeniPrihlasen();
    return u.uid;
  }

  /// Přihlášení e-mailem a heslem. Po úspěchu doplní profil
  /// v `uzivatele/{uid}`.
  Future<void> prihlasEmailem({
    required String email,
    required String heslo,
  }) async {
    try {
      final vysledek = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: heslo,
      );
      final uzivatel = vysledek.user;
      if (uzivatel == null) throw const PrihlaseniSelhalo();
      await _zalozNeboAktualizujProfil(uzivatel, vysledek.additionalUserInfo);
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Pošle e-mail pro nastavení nového hesla.
  ///
  /// Firebase záměrně nedává vědět, jestli účet existuje – jinak by šlo
  /// zjišťovat, kdo je v systému. Uživateli proto hlásíme úspěch vždycky.
  Future<void> posliResetHesla(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (chyba) {
      if (chyba.code == 'user-not-found') return;
      throw AppChyba.zFirebase(chyba);
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Přihlášení firemním účtem přes Microsoft OIDC.
  ///
  /// Zatím se nepoužívá – čeká na registraci aplikace v Entra ID
  /// a na vyplnění [Konfigurace.microsoftTenantId]. Až se zapne,
  /// nahradí [prihlasEmailem] na přihlašovací obrazovce.
  Future<void> prihlasFiremnimUctem() async {
    try {
      final provider = OAuthProvider('microsoft.com')
        ..setCustomParameters({
          'prompt': 'select_account',
          if (Konfigurace.microsoftTenantId != null)
            'tenant': Konfigurace.microsoftTenantId!,
        });
      final vysledek = await _auth.signInWithProvider(provider);
      final uzivatel = vysledek.user;
      if (uzivatel == null) throw const PrihlaseniSelhalo();
      await _zalozNeboAktualizujProfil(uzivatel, vysledek.additionalUserInfo);
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  Future<void> odhlas() async {
    try {
      await _auth.signOut();
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Profil vzniká při prvním přihlášení, pokud ho správce nezaložil už
  /// při zakládání účtu. `vytvoreno_at` se zapisuje jen jednou, jméno
  /// a e-mail se při dalších přihlášeních srovnají s účtem.
  Future<void> _zalozNeboAktualizujProfil(
    User uzivatel,
    AdditionalUserInfo? doplnujici,
  ) async {
    final profil = doplnujici?.profile ?? const <String, dynamic>{};
    final email =
        uzivatel.email ??
        profil['mail'] as String? ??
        profil['userPrincipalName'] as String? ??
        '';
    final jmeno =
        uzivatel.displayName ??
        profil['displayName'] as String? ??
        profil['name'] as String? ??
        jmenoZEmailu(email);

    final ref = _db.collection(Kolekce.uzivatele).doc(uzivatel.uid);
    final snimek = await ref.get();
    if (!snimek.exists) {
      await ref.set({
        'jmeno': jmeno,
        'email': email,
        'vytvoreno_at': FieldValue.serverTimestamp(),
      });
      return;
    }
    final data = snimek.data() ?? const <String, dynamic>{};
    final zmeny = <String, dynamic>{
      if (jmeno.isNotEmpty && data['jmeno'] != jmeno) 'jmeno': jmeno,
      if (email.isNotEmpty && data['email'] != email) 'email': email,
    };
    if (zmeny.isNotEmpty) await ref.update(zmeny);
  }

  /// Náhradní jméno pro pozdrav na domovské obrazovce, když účet nemá
  /// vyplněné `displayName`: `jana.novakova@firma.cz` → `Jana Nováková`.
  /// Účty zakládané skriptem jméno mají, tohle je záchranná síť.
  static String jmenoZEmailu(String email) {
    final zavinac = email.indexOf('@');
    if (zavinac <= 0) return '';
    return email
        .substring(0, zavinac)
        .split(RegExp(r'[._-]+'))
        .where((cast) => cast.isNotEmpty)
        .map((cast) => cast[0].toUpperCase() + cast.substring(1))
        .join(' ');
  }
}
