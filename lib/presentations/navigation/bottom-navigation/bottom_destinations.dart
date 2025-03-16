import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

const kBottomDestinations = <Widget>[
  NavigationDestination(icon: Icon(Symbols.network_ping), label: 'Ping'),
  NavigationDestination(icon: Icon(Symbols.wifi), label: 'Network Info'),
  NavigationDestination(
    icon: Icon(Symbols.monitor_heart),
    label: 'Diagnostics',
  ),
  NavigationDestination(icon: Icon(Symbols.settings_ethernet), label: 'Tools'),
];
