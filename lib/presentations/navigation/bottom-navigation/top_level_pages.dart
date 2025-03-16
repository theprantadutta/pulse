import 'package:flutter/material.dart';

import '../../screens/diagnostics_screen.dart';
import '../../screens/network_info_screen.dart';
import '../../screens/ping_screen.dart';
import '../../screens/tools_screen.dart';

/// Top Level Pages
const List<Widget> kTopLevelPages = [
  PingScreen(),
  NetworkInfoScreen(),
  DiagnosticsScreen(),
  ToolsScreen(),
];
