import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

SystemUiOverlayStyle getDefaultSystemUiStyle(bool isDarkTheme) {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDarkTheme ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDarkTheme ? Brightness.dark : Brightness.light,
  );
}

BoxDecoration getBackgroundDecoration(Color kPrimaryColor) {
  return BoxDecoration(color: kPrimaryColor.withValues(alpha: 0));
}
