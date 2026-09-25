import 'package:material_ui/material_ui.dart';

import '../../theme/wire_theme.dart';

/// Window-width layout modes.
enum WireMode {
  /// ≥1024px: sidebar + top bar, right panels beside the main area.
  desktop,

  /// 600–1023px: index-number rail, right panels stacked below.
  compact,

  /// <600px: bordered content container + bottom tab bar.
  mobile,
}

extension WireModeContext on BuildContext {
  WireMode get wireMode {
    final width = MediaQuery.sizeOf(this).width;
    if (width >= WireLayout.desktop) return WireMode.desktop;
    if (width >= WireLayout.compact) return WireMode.compact;
    return WireMode.mobile;
  }

  bool get isMobileLayout => wireMode == WireMode.mobile;
}

/// Desktop/compact page: 64px top bar, main area and an optional right
/// panel (beside on desktop, stacked below on compact).
class WireDesktopPage extends StatelessWidget {
  const WireDesktopPage({
    super.key,
    required this.topBar,
    required this.body,
    this.panel,
    this.panelWidth = 360,
    this.scrollBody = false,
  });

  final Widget topBar;
  final Widget body;
  final Widget? panel;
  final double panelWidth;

  /// Wrap [body] in a scroll view (for content-height bodies).
  final bool scrollBody;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final compact = context.wireMode == WireMode.compact;
    final bar = Container(
      height: WireLayout.topBar,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: w.ink, width: kWireBorder)),
      ),
      child: topBar,
    );

    if (panel == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(child: scrollBody ? SingleChildScrollView(child: body) : body),
        ],
      );
    }

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: scrollBody ? null : MediaQuery.sizeOf(context).height * 0.72,
                    child: body,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: w.ink, width: kWireBorder)),
                    ),
                    child: panel,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: scrollBody ? SingleChildScrollView(child: body) : body,
              ),
              Container(width: kWireBorder, color: w.ink),
              SizedBox(width: panelWidth, child: panel),
            ],
          ),
        ),
      ],
    );
  }
}

/// Mobile page inside the bordered shell container: header, body and an
/// optional full-width action bar.
class WireMobilePage extends StatelessWidget {
  const WireMobilePage({
    super.key,
    required this.header,
    required this.body,
    this.action,
  });

  final Widget header;
  final Widget body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
        if (action != null)
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: w.ink, width: kWireBorder)),
            ),
            child: action,
          ),
      ],
    );
  }
}

/// Picks the mobile or desktop/compact build for the current window.
class WireAdaptive extends StatelessWidget {
  const WireAdaptive({super.key, required this.mobile, required this.desktop});

  final WidgetBuilder mobile;
  final WidgetBuilder desktop;

  @override
  Widget build(BuildContext context) =>
      context.isMobileLayout ? mobile(context) : desktop(context);
}

/// Top-bar title cell (e.g. SETTINGS, HISTORY).
class WireTopTitle extends StatelessWidget {
  const WireTopTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title.toUpperCase(), style: WireType.title(28).copyWith(color: w.ink)),
          if (subtitle != null) ...[
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: WireType.body(13).copyWith(color: w.text3),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
