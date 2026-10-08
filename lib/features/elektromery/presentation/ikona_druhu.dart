import 'package:flutter/material.dart';

import '../domain/druh_mista.dart';

/// Ikona druhu odběrného místa – v seznamu, filtru a formuláři.
IconData ikonaDruhu(DruhMista druh) => switch (druh) {
  DruhMista.elektrina => Icons.electric_meter_outlined,
  DruhMista.plyn => Icons.local_fire_department_outlined,
  DruhMista.klimatizace => Icons.ac_unit,
  DruhMista.nabijecka => Icons.ev_station_outlined,
};
