import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'floating_theme_change_button.dart';

class MainLayout extends StatelessWidget {
  final String title;
  final Widget body;
  final PreferredSizeWidget? bottom;

  const MainLayout({
    super.key,
    required this.body,
    required this.title,
    this.bottom,
  });

  Future<bool> _onBackButtonPressed(BuildContext context) async {
    if (context.canPop()) context.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    return BackButtonListener(
      onBackButtonPressed: () => _onBackButtonPressed(context),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: kPrimaryColor.withValues(
            alpha: isDarkTheme ? 0.6 : 0.9,
          ),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: MainLayoutAppBar(title: title),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white, weight: 20),
          ),
          bottom: bottom,
        ),
        body: SingleChildScrollView(child: body),
        floatingActionButton:
            kReleaseMode
                ? null // Don't show FloatingActionButton in release (production) mode
                : const FloatingThemeChangeButton(),
      ),
    );
  }
}

class MainLayoutAppBar extends StatelessWidget {
  final String title;

  const MainLayoutAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}
