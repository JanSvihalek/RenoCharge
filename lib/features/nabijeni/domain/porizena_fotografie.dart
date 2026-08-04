import 'dart:typed_data';

/// Odkud snímek přišel. Ukládá se k relaci, protože fotka z galerie je
/// slabší doklad než snímek pořízený v aplikaci – mohla vzniknout kdykoli
/// a kdekoli.
enum ZdrojFoto {
  fotoaparat('fotoaparat'),
  galerie('galerie');

  const ZdrojFoto(this.klic);

  final String klic;

  static ZdrojFoto zKlice(String? klic) =>
      klic == galerie.klic ? galerie : fotoaparat;
}

/// Fotografie počítadla, která je pořízená, ale ještě nenahraná.
///
/// Nese už spočítaný otisk i čas pořízení, takže nahrání do Storage
/// a zápis do Firestore pracují se stejnými hodnotami.
class PorizenaFotografie {
  const PorizenaFotografie({
    required this.cestaVSouborovemSystemu,
    required this.bajty,
    required this.sha256,
    required this.porizenoAt,
    required this.casZExif,
    required this.zdroj,
  });

  final String cestaVSouborovemSystemu;
  final Uint8List bajty;
  final String sha256;
  final ZdrojFoto zdroj;

  /// Čas pořízení. Přednostně z EXIF snímku.
  final DateTime porizenoAt;

  /// `false`, pokud se EXIF nepodařilo přečíst a čas pochází z hodin
  /// telefonu v okamžiku, kdy fotoaparát vrátil snímek.
  final bool casZExif;

  int get velikostBajtu => bajty.length;
}
