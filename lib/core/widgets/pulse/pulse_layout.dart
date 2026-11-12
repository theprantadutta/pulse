import 'package:material_ui/material_ui.dart';

/// Window-size classes (DESIGN_SYSTEM.md §5).
///
/// * compact  < 600: phones. Navigation bar with 4 tabs.
/// * medium   600–839: rail, single pane.
/// * expanded ≥ 840: rail plus list-detail where a screen specifies it. Desktop
///   windows use this frame too.
enum PulseSize { compact, medium, expanded }

abstract final class PulseLayout {
  static const medium = 600.0;
  static const expanded = 840.0;

  /// Side gutter on phones, content padding on tablets.
  static const gutter = 16.0;
  static const tabletPadding = 24.0;

  /// List-detail pane.
  static const pane = 300.0;
  static const rail = 96.0;

  /// Space between stacked sections.
  static const section = 12.0;

  /// Gap inside segmented lists, stat rows and connected groups.
  static const seam = 3.0;

  /// Bottom padding that keeps the last list item clear of a FAB.
  static const fabClearance = 96.0;
}

extension PulseLayoutContext on BuildContext {
  PulseSize get pulseSize {
    final w = MediaQuery.sizeOf(this).width;
    if (w >= PulseLayout.expanded) return PulseSize.expanded;
    if (w >= PulseLayout.medium) return PulseSize.medium;
    return PulseSize.compact;
  }

  /// Phone frame: bottom navigation bar, single column.
  bool get isCompact => pulseSize == PulseSize.compact;

  /// Rail frame with room for list-detail panes.
  bool get isExpanded => pulseSize == PulseSize.expanded;

  /// Horizontal padding for screen content.
  double get pagePadding => isCompact ? PulseLayout.gutter : PulseLayout.tabletPadding;
}
