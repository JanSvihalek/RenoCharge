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

/// Kam fotka ve Storage patří.
///
/// Uid je v cestě u obou stromů, a ne jen pro pořádek – díky němu si
/// `storage.rules` ověří vlastníka přímo z cesty a nemusí se doptávat
/// Firestore. Viz komentář v pravidlech.
class CilFotky {
  const CilFotky._({required this.cesta, required this.popisZdroje});

  final String cesta;

  /// Dvojice do metadat souboru, ať se dá u osiřelé fotky poznat,
  /// ke kterému záznamu měla patřit.
  final MapEntry<String, String> popisZdroje;

  /// `nabijeni/{uid}/{relaceId}/{start|end}.jpg`
  factory CilFotky.nabijeni({
    required String uid,
    required String relaceId,
    required TypFoto typ,
  }) => CilFotky._(
    cesta: 'nabijeni/$uid/$relaceId/${typ.nazevSouboru}.jpg',
    popisZdroje: MapEntry('relace_id', relaceId),
  );

  /// `odecty/{uid}/{odecetId}.jpg`
  factory CilFotky.odecet({required String uid, required String odecetId}) =>
      CilFotky._(
        cesta: 'odecty/$uid/$odecetId.jpg',
        popisZdroje: MapEntry('odecet_id', odecetId),
      );
}

/// Fotografie počítadel ve Firebase Storage – nabíjecích i elektroměrů.
class FotoUloziste {
  FotoUloziste({required FirebaseStorage storage}) : _storage = storage;

  final FirebaseStorage _storage;

  /// Nahraje fotku a vrátí metadata pro zápis do dokumentu záznamu.
  Future<FotoMetadata> nahraj({
    required CilFotky cil,
    required PorizenaFotografie foto,
  }) async {
    if (foto.velikostBajtu > Konfigurace.maxVelikostFotoBajtu) {
      throw const NahraniFotoSelhalo();
    }
    final cilovaCesta = cil.cesta;
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
                cil.popisZdroje.key: cil.popisZdroje.value,
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
}
