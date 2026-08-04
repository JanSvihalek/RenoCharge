import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:exif/exif.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../common/chyby.dart';
import '../../../common/konfigurace.dart';
import '../domain/porizena_fotografie.dart';

/// Pořízení fotografie počítadla – fotoaparátem, nebo výběrem z galerie.
///
/// Ke snímku rovnou počítá SHA-256 (otisk pro pozdější ověření, že se
/// fotka nezměnila) a hledá čas pořízení v EXIF – ne čas nahrání.
class FotoSluzba {
  FotoSluzba({ImagePicker? vyberFotky}) : _picker = vyberFotky ?? ImagePicker();

  final ImagePicker _picker;

  /// Otevře fotoaparát, nebo galerii. Vyhodí [FoceniZruseno], když
  /// uživatel výběr zavře, jinak [KameraNedostupna] / [GalerieNedostupna]
  /// (typicky chybějící oprávnění).
  ///
  /// U snímku z galerie je EXIF čas obzvlášť podstatný: fotka mohla
  /// vzniknout před hodinou i před týdnem a je to jediný údaj, ze kterého
  /// jde poznat kdy. Proto se ukládá i [PorizenaFotografie.zdroj].
  Future<PorizenaFotografie> nactiPocitadlo(ZdrojFoto zdroj) async {
    final zFotoaparatu = zdroj == ZdrojFoto.fotoaparat;
    final XFile? snimek;
    try {
      snimek = await _picker.pickImage(
        source: zFotoaparatu ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: Konfigurace.maxSirkaFoto,
        imageQuality: Konfigurace.kvalitaFoto,
        requestFullMetadata: true,
      );
    } catch (_) {
      throw zFotoaparatu ? const KameraNedostupna() : const GalerieNedostupna();
    }
    if (snimek == null) throw const FoceniZruseno();

    // Záložní čas se bere hned – čím dřív, tím blíž okamžiku pořízení.
    // U galerie je to ale jen nouzovka: říká, kdy uživatel snímek vybral,
    // ne kdy vznikl.
    final casVraceni = DateTime.now();
    final bajty = await snimek.readAsBytes();
    final casZExif = await prectiCasZExif(bajty);

    return PorizenaFotografie(
      cestaVSouborovemSystemu: snimek.path,
      bajty: bajty,
      sha256: spocitejOtisk(bajty),
      porizenoAt: casZExif ?? casVraceni,
      casZExif: casZExif != null,
      zdroj: zdroj,
    );
  }

  /// SHA-256 přesně těch bajtů, které se nahrají do Storage.
  static String spocitejOtisk(Uint8List bajty) =>
      sha256.convert(bajty).toString();

  /// Čas pořízení z EXIF. `null`, pokud snímek EXIF nemá – to se stává,
  /// protože zmenšení a překomprimování ve fotopickeru EXIF na některých
  /// zařízeních zahodí. V takovém případě se použije čas, kdy fotoaparát
  /// snímek vrátil.
  static Future<DateTime?> prectiCasZExif(Uint8List bajty) async {
    try {
      final tagy = await readExifFromBytes(bajty);
      if (tagy.isEmpty) return null;
      final hodnota =
          tagy['EXIF DateTimeOriginal']?.printable ??
          tagy['EXIF DateTimeDigitized']?.printable ??
          tagy['Image DateTime']?.printable;
      final posun =
          tagy['EXIF OffsetTimeOriginal']?.printable ??
          tagy['EXIF OffsetTime']?.printable;
      return rozparsujExifCas(hodnota, posun: posun);
    } catch (_) {
      return null;
    }
  }

  /// EXIF čas má tvar `2026:08:03 14:22:51`, případný posun `+02:00`.
  /// Vrací lokální čas.
  static DateTime? rozparsujExifCas(String? hodnota, {String? posun}) {
    if (hodnota == null) return null;
    final shoda = RegExp(
      r'^(\d{4})[:-](\d{2})[:-](\d{2})[ T](\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(hodnota.trim());
    if (shoda == null) return null;
    int c(int i) => int.parse(shoda.group(i)!);

    final bezPosunu = DateTime(c(1), c(2), c(3), c(4), c(5), c(6));
    if (bezPosunu.year < 2000) return null;

    final posunShoda = posun == null
        ? null
        : RegExp(r'^([+-])(\d{2}):?(\d{2})$').firstMatch(posun.trim());
    if (posunShoda == null) return bezPosunu;

    // S posunem známe skutečný okamžik, takže ho převedeme na lokální čas.
    final znamenko = posunShoda.group(1) == '-' ? -1 : 1;
    final rozdil = Duration(
      hours: int.parse(posunShoda.group(2)!),
      minutes: int.parse(posunShoda.group(3)!),
    );
    final utc = DateTime.utc(
      c(1),
      c(2),
      c(3),
      c(4),
      c(5),
      c(6),
    ).subtract(rozdil * znamenko);
    return utc.toLocal();
  }
}

final fotoSluzbaProvider = Provider<FotoSluzba>((ref) => FotoSluzba());
