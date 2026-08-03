import 'package:flutter/material.dart';

import '../chyby.dart';
import '../motiv/barvy.dart';

/// Zobrazí chybu uživateli česky. Přijímá i syrovou výjimku – převod na
/// srozumitelnou hlášku řeší [AppChyba.zFirebase].
void ukazChybu(BuildContext context, Object chyba) {
  final prevedena = AppChyba.zFirebase(chyba);
  // Zrušené focení ani přihlášení není chyba, se kterou by měl uživatel
  // něco dělat – jen se vrátíme zpátky.
  if (prevedena is FoceniZruseno || prevedena is PrihlaseniZruseno) return;
  _ukaz(context, prevedena.zprava, context.barvy.danger);
}

/// Potvrzení úspěšné akce.
void ukazInfo(BuildContext context, String zprava) {
  _ukaz(context, zprava, context.barvy.accent);
}

/// Upozornění, které nepřichází z Firebase – typicky nevyplněné pole.
void ukazVarovani(BuildContext context, String zprava) {
  _ukaz(context, zprava, context.barvy.danger);
}

void _ukaz(BuildContext context, String zprava, Color pruh) {
  final b = context.barvy;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(zprava, style: TextStyle(color: b.text, fontSize: 15)),
        backgroundColor: b.surface2,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: pruh, width: 2),
        ),
      ),
    );
}
