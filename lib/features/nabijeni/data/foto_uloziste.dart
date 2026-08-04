import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../common/chyby.dart';
import '../../../common/konfigurace.dart';
import '../domain/foto_metadata.dart';
import '../domain/porizena_fotografie.dart';

/// Která z dvojice fotek se nahrává.
enum TypFoto {
  start('start'),
  end('end');

  const TypFoto(this.nazevSouboru);

  final String nazevSouboru;
}

/// Fotografie počítadla ve Firebase Storage.
/// Cesta je vždy `nabijeni/{relaceId}/{start|end}.jpg`.
class FotoUloziste {
  FotoUloziste({required FirebaseStorage storage}) : _storage = storage;

  final FirebaseStorage _storage;

  static String cesta(String relaceId, TypFoto typ) =>
      'nabijeni/$relaceId/${typ.nazevSouboru}.jpg';

  /// Nahraje fotku a vrátí metadata pro zápis do dokumentu relace.
  Future<FotoMetadata> nahraj({
    required String relaceId,
    required TypFoto typ,
    required PorizenaFotografie foto,
  }) async {
    if (foto.velikostBajtu > Konfigurace.maxVelikostFotoBajtu) {
      throw const NahraniFotoSelhalo();
    }
    final cilovaCesta = cesta(relaceId, typ);
    try {
      await _storage
          .ref(cilovaCesta)
          .putData(
            foto.bajty,
            SettableMetadata(
              contentType: 'image/jpeg',
              customMetadata: {
                'sha256': foto.sha256,
                'porizeno_at': foto.porizenoAt.toUtc().toIso8601String(),
                'relace_id': relaceId,
                'zdroj': foto.zdroj.klic,
              },
            ),
          );
    } catch (chyba) {
      final prevedena = AppChyba.zFirebase(chyba);
      // Selhání uploadu má vlastní hlášku – uživateli neříkáme
      // „operace se nezdařila“, ale co má udělat.
      throw prevedena is NedostatecnaOpravneni
          ? prevedena
          : const NahraniFotoSelhalo();
    }
    return FotoMetadata(
      path: cilovaCesta,
      sha256: foto.sha256,
      porizenoAt: foto.porizenoAt,
      zdroj: foto.zdroj,
    );
  }

  /// Stáhne fotku do paměti – pro vložení do PDF reportu. Limit je
  /// stejný jako u nahrávání, nic většího ve Storage vzniknout nemělo.
  Future<Uint8List?> stahni(String cesta) async {
    try {
      return await _storage
          .ref(cesta)
          .getData(Konfigurace.maxVelikostFotoBajtu);
    } catch (_) {
      // Chybějící fotka nesmí shodit celý report – vynechá se a report
      // to u dané relace přizná.
      return null;
    }
  }

  /// Odkaz ke stažení pro zobrazení náhledu v detailu relace.
  Future<String> odkazKeStazeni(String cesta) async {
    try {
      return await _storage.ref(cesta).getDownloadURL();
    } catch (chyba) {
      throw AppChyba.zFirebase(chyba);
    }
  }

  /// Úklid po neúspěšném zahájení relace – ať ve Storage nezůstávají
  /// fotky bez záznamu. Chyba při mazání se ignoruje.
  Future<void> smazTiseji(String cesta) async {
    try {
      await _storage.ref(cesta).delete();
    } catch (_) {
      // Osiřelý soubor je menší problém než chyba nahlášená uživateli.
    }
  }
}
