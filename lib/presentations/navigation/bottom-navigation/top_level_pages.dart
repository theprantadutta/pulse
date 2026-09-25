import 'package:material_ui/material_ui.dart';

import '../../screens/diagnostics_screen.dart';
import '../../screens/network_screen.dart';
import '../../screens/ping_screen.dart';
import '../../screens/tools_screen.dart';

/// Top Level Pages
const List<Widget> kTopLevelPages = [
  PingScreen(),
  NetworkScreen(),
  DiagnosticsScreen(),
  ToolsScreen(),
];
