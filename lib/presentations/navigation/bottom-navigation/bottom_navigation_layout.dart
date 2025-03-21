import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:stylish_bottom_bar/stylish_bottom_bar.dart';

import '../../../core/constants/hero_tags.dart';
import '../../../core/constants/selectors.dart';
import '../../screens/create_new_ping_screen.dart';
import 'awesome_bottom_bar/top_level_page_view.dart';
import 'side_navigation_bar.dart';
import 'top_level_pages.dart';

class BottomNavigationLayout extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavigationLayout({super.key, required this.navigationShell});

  @override
  State<BottomNavigationLayout> createState() => _BottomNavigationLayoutState();

  // ignore: library_private_types_in_public_api
  static _BottomNavigationLayoutState of(BuildContext context) =>
      context.findAncestorStateOfType<_BottomNavigationLayoutState>()!;
}

class _BottomNavigationLayoutState extends State<BottomNavigationLayout> {
  int selectedIndex = 0;
  late PageController pageController;
  bool isSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: selectedIndex);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void _updateCurrentPageIndex(int index) {
    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _handlePageViewChanged(int currentPageIndex) {
    setState(() {
      selectedIndex = currentPageIndex;
    });
  }

  gotoPage(int index) {
    if (index < kTopLevelPages.length && index >= 0) {
      _updateCurrentPageIndex(index);
    }
  }

  gotoNextPage() {
    if (selectedIndex != kTopLevelPages.length - 1) {
      _updateCurrentPageIndex(selectedIndex + 1);
    }
  }

  gotoPreviousPage() {
    if (selectedIndex != 0) {
      _updateCurrentPageIndex(selectedIndex - 1);
    }
  }

  Future<bool> _onWillPop(BuildContext context) async {
    return (await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Are you sure?'),
                content: const Text('Do you want to exit the app?'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('No'),
                  ),
                  TextButton(
                    onPressed:
                        () => SystemChannels.platform.invokeMethod(
                          'SystemNavigator.pop',
                        ),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        )) ??
        true;
  }

  Future<bool> _onBackButtonPressed() async {
    debugPrint('Back button Pressed');
    if (selectedIndex == 0) {
      return await _onWillPop(context);
    } else {
      gotoPreviousPage();
      return true;
    }
  }

  void _toggleSidebar() {
    setState(() {
      isSidebarExpanded = !isSidebarExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final kPrimaryColor = Theme.of(context).primaryColor;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;

        return BackButtonListener(
          onBackButtonPressed: _onBackButtonPressed,
          child: Scaffold(
            extendBodyBehindAppBar: false,
            resizeToAvoidBottomInset: false,
            body: AnnotatedRegion(
              value: getDefaultSystemUiStyle(isDarkTheme),
              child: Container(
                decoration: getBackgroundDecoration(kPrimaryColor),
                child: Row(
                  children: [
                    if (isDesktop)
                      SideNavigationBar(
                        isSidebarExpanded: isSidebarExpanded,
                        selectedIndex: selectedIndex,
                        toggleSidebar: _toggleSidebar,
                        updateCurrentPageIndex: _updateCurrentPageIndex,
                      ),
                    Expanded(
                      child: TopLevelPageView(
                        pageController: pageController,
                        onPageChanged: _handlePageViewChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            floatingActionButton:
                isDesktop
                    ? null // Hide FAB for desktop
                    : FloatingActionButton(
                      heroTag: kAddNewPing,
                      shape: const CircleBorder(),
                      onPressed:
                          () => context.push(CreateNewPingScreen.kRouteName),
                      backgroundColor: kPrimaryColor.withValues(alpha: 0.9),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
            bottomNavigationBar:
                isDesktop
                    ? null // Hide bottom nav for desktop
                    : SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.085,
                      child: StylishBottomBar(
                        backgroundColor:
                            isDarkTheme
                                ? Colors.grey.shade900
                                : Colors.grey.shade200,
                        notchStyle: NotchStyle.circle,
                        option: DotBarOptions(dotStyle: DotStyle.circle),
                        items: [
                          BottomBarItem(
                            icon: Icon(Symbols.network_ping),
                            title: const Text('Ping'),
                            selectedColor: kPrimaryColor,
                          ),
                          BottomBarItem(
                            icon: Icon(Symbols.wifi),
                            title: const Text('Network Info'),
                            selectedColor: kPrimaryColor,
                          ),
                          BottomBarItem(
                            icon: Icon(Symbols.monitor_heart),
                            title: const Text('Diagnostics'),
                            selectedColor: kPrimaryColor,
                          ),
                          BottomBarItem(
                            icon: Icon(Symbols.settings_ethernet),
                            title: const Text('Tools'),
                            selectedColor: kPrimaryColor,
                          ),
                        ],
                        fabLocation: StylishBarFabLocation.center,
                        hasNotch: true,
                        currentIndex: selectedIndex,
                        onTap: _updateCurrentPageIndex,
                      ),
                    ),
          ),
        );
      },
    );
  }
}
