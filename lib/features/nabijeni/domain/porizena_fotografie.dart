import 'dart:typed_data';

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
  });

  final String cestaVSouborovemSystemu;
  final Uint8List bajty;
  final String sha256;

  /// Čas pořízení. Přednostně z EXIF snímku.
  final DateTime porizenoAt;

  /// `false`, pokud se EXIF nepodařilo přečíst a čas pochází z hodin
  /// telefonu v okamžiku, kdy fotoaparát vrátil snímek.
  final bool casZExif;

  int get velikostBajtu => bajty.length;
}
