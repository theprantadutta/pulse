import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/pulse_motion.dart';
import '../../theme/pulse_theme.dart';
import 'pulse_icons.dart';
import 'pulse_layout.dart';

/// Screen scaffold used by every screen inside the shell.
///
/// * Top-level screens (Ping, Network, Tools, History) set [large]: a 72 dp app
///   bar with the title in headlineLarge.
/// * Pushed tool screens get a back arrow on phones (to [backTo], or a pop when
///   the navigator can) and a 64 dp app bar with the title in titleLarge.
/// * On tablets the header becomes a row: title (headlineMedium) and an optional
///   [subtitle] on the left, [actions] on the right, no back arrow.
///
/// Pass [children] for a padded scrolling column, or [body] for full control.
class PulsePage extends StatelessWidget {
  const PulsePage({
    super.key,
    required this.title,
    this.subtitle,
    this.large = false,
    this.backTo,
    this.showBack,
    this.actions = const [],
    this.children,
    this.body,
    this.fab,
    this.padding,
    this.controller,
    this.titleWidget,
  }) : assert(children != null || body != null, 'Pass children or body');

  final String title;
  final String? subtitle;

  /// Replaces the title text (e.g. a title with an inline badge).
  final Widget? titleWidget;
  final bool large;

  /// Where the back arrow goes when there is nothing to pop. Null with
  /// [showBack] unset means "top-level screen, no back arrow".
  final String? backTo;
  final bool? showBack;
  final List<Widget> actions;
  final List<Widget>? children;
  final Widget? body;
  final Widget? fab;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    final back = showBack ?? (compact && backTo != null);
    final header = compact
        ? _PhoneAppBar(
            title: title,
            titleWidget: titleWidget,
            subtitle: subtitle,
            large: large,
            back: back ? () => _goBack(context) : null,
            actions: actions,
          )
        : _TabletHeader(
            title: title,
            titleWidget: titleWidget,
            subtitle: subtitle,
            actions: actions,
            back: back ? () => _goBack(context) : null,
          );
    final pad = padding ?? EdgeInsets.fromLTRB(context.pagePadding, 4, context.pagePadding, fab != null ? 112 : 24);
    final content =
        body ??
        ListView(
          controller: controller,
          padding: pad,
          children: [for (var i = 0; i < children!.length; i++) PulseEntrance(index: i, child: children![i])],
        );
    return Scaffold(
      backgroundColor: context.colors.surface,
      floatingActionButton: fab,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  void _goBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(backTo ?? '/');
    }
  }
}

class _PhoneAppBar extends StatelessWidget {
  const _PhoneAppBar({
    required this.title,
    required this.titleWidget,
    required this.subtitle,
    required this.large,
    required this.back,
    required this.actions,
  });

  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final bool large;
  final VoidCallback? back;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.colors;
    final titleText =
        titleWidget ??
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: large ? t.headlineLarge : t.titleLarge);
    return SizedBox(
      height: large ? 72 : 64,
      child: Padding(
        padding: EdgeInsets.only(left: back != null ? 4 : 16, right: 8),
        child: Row(
          children: [
            if (back != null) ...[PulseBackButton(onPressed: back!), const SizedBox(width: 4)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: titleText),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall!.copyWith(color: c.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            for (final a in actions) Padding(padding: const EdgeInsets.only(left: 4), child: a),
          ],
        ),
      ),
    );
  }
}

class _TabletHeader extends StatelessWidget {
  const _TabletHeader({
    required this.title,
    required this.titleWidget,
    required this.subtitle,
    required this.actions,
    required this.back,
  });

  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? back;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PulseLayout.tabletPadding, 20, PulseLayout.tabletPadding, 16),
      child: Row(
        children: [
          if (back != null) ...[PulseBackButton(onPressed: back!), const SizedBox(width: 8)],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child:
                      titleWidget ?? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.headlineMedium),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall!.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          for (final a in actions) Padding(padding: const EdgeInsets.only(left: 8), child: a),
        ],
      ),
    );
  }
}

class PulseBackButton extends StatelessWidget {
  const PulseBackButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: onPressed,
    color: context.colors.onSurface,
    icon: const PulseIcon(PulseIcons.back, size: 24),
  );
}

/// The tablet list-detail pane: surfaceContainer, radius 28, 12 dp vertical
/// margin (DESIGN_SYSTEM.md §5). The detail sits on `surface` next to it.
class PulsePane extends StatelessWidget {
  const PulsePane({super.key, required this.child, this.width = PulseLayout.pane, this.padding});

  final Widget child;
  final double width;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: padding ?? const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(color: context.colors.surfaceContainer, borderRadius: BorderRadius.circular(28)),
      child: child,
    );
  }
}

/// Pane title row: headlineMedium title plus trailing actions.
class PulsePaneHeader extends StatelessWidget {
  const PulsePaneHeader({super.key, required this.title, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 0, 12),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: context.type.headlineMedium)),
        ),
        ...actions,
      ],
    ),
  );
}
