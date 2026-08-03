import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aplikace je čistě na výšku – uživatel ji ovládá jednou rukou.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  Intl.defaultLocale = 'cs_CZ';
  await initializeDateFormatting('cs_CZ');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (chyba) {
    runApp(ChybaStartuApp(podrobnosti: chyba.toString()));
    return;
  }

  runApp(const ProviderScope(child: NabijeciDenikApp()));
}
