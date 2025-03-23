import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/constants/hero_tags.dart';
import '../../screens/create_new_ping_screen.dart';

class SideNavigationBar extends StatefulWidget {
  final int selectedIndex;
  final void Function(int index) updateCurrentPageIndex;
  final bool isSidebarExpanded;
  final void Function() toggleSidebar;

  const SideNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.updateCurrentPageIndex,
    required this.isSidebarExpanded,
    required this.toggleSidebar,
  });

  @override
  State<SideNavigationBar> createState() => _SideNavigationBarState();
}

class _SideNavigationBarState extends State<SideNavigationBar> {
  // Helper method to build navigation items
  Widget _buildNavItem({
    required IconData icon,
    required String title,
    required int index,
    required bool isExpanded,
    required Color selectedColor,
  }) {
    final isSelected = widget.selectedIndex == index;
    return InkWell(
      onTap: () => widget.updateCurrentPageIndex(index),
      child: Container(
        width: isExpanded ? 200 : 60,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? selectedColor.withValues(alpha: 0.2)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? selectedColor : Colors.grey),
            if (isExpanded) ...[
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? selectedColor : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final kPrimaryColor = Theme.of(context).primaryColor;
    final isSidebarExpanded = widget.isSidebarExpanded;
    return AnimatedContainer(
      width: isSidebarExpanded ? 220 : 80,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      color: isDarkTheme ? Colors.grey.shade900 : Colors.grey.shade200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Toggle Button to Expand/Collapse Sidebar
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.toggleSidebar,
                child: Container(
                  // backgroundColor: kPrimaryColor.withValues(alpha: 0.1),
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      if (isSidebarExpanded)
                        Row(
                          children: [
                            Text(
                              'Collapse',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 5),
                          ],
                        ),
                      Icon(
                        isSidebarExpanded
                            ? Icons.arrow_back_ios
                            : Icons.arrow_forward_ios,
                        color: Colors.grey,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Navigation Items
            _buildNavItem(
              icon: Symbols.network_ping,
              title: 'Ping',
              index: 0,
              isExpanded: isSidebarExpanded,
              selectedColor: kPrimaryColor,
            ),
            _buildNavItem(
              icon: Symbols.wifi,
              title: 'Network',
              index: 1,
              isExpanded: isSidebarExpanded,
              selectedColor: kPrimaryColor,
            ),
            _buildNavItem(
              icon: Symbols.monitor_heart,
              title: 'Diagnostics',
              index: 2,
              isExpanded: isSidebarExpanded,
              selectedColor: kPrimaryColor,
            ),
            _buildNavItem(
              icon: Symbols.settings_ethernet,
              title: 'Tools',
              index: 3,
              isExpanded: isSidebarExpanded,
              selectedColor: kPrimaryColor,
            ),
            const Spacer(),
            // Floating Action Button
            FloatingActionButton(
              heroTag: kAddNewPing,
              shape: const CircleBorder(),
              onPressed: () => context.push(CreateNewPingScreen.kRouteName),
              backgroundColor: kPrimaryColor.withValues(alpha: 0.9),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
