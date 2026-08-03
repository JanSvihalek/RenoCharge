import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Režim motivu. Výchozí je systémový, uživatel jej může ručně přepnout
/// na domovské obrazovce. Přepnutí je okamžité, bez animace.
class RezimMotivu extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  /// Přepne mezi světlým a tmavým podle toho, co je právě vidět.
  void prepni({required bool jeTedTmavy}) {
    state = jeTedTmavy ? ThemeMode.light : ThemeMode.dark;
  }
}

final rezimMotivuProvider = NotifierProvider<RezimMotivu, ThemeMode>(
  RezimMotivu.new,
);
