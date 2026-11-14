import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The 52 stroke icons from the redesign kit (24 px grid, 2.2 px stroke).
/// Files live in `assets/icons/<name>.svg` and render in [PulseIcon.color].
enum PulseIcons {
  auto,
  back,
  bell,
  bulb,
  camera,
  check,
  chevD,
  chevR,
  clock,
  cloud,
  code,
  console,
  copy,
  data,
  down,
  edit,
  export,
  filter,
  gauge,
  gift,
  globe,
  grid,
  heart,
  help,
  info,
  lan,
  laptop,
  loss,
  monitor,
  moon,
  more,
  motion,
  palette,
  pause,
  phone,
  pin,
  play,
  plus,
  port,
  power,
  printer,
  pulse,
  refresh,
  route,
  router,
  search,
  server,
  settings,
  share,
  shield,
  signal,
  speaker,
  star,
  stop,
  sun,
  tablet,
  timer,
  trash,
  tune,
  tv,
  up,
  wifi,
  x;

  String get asset => 'assets/icons/$name.svg';
}

/// An icon from [PulseIcons]. Defaults to the ambient [IconTheme] colour and size
/// so it drops into NavigationBar, IconButton and friends like a Material icon.
class PulseIcon extends StatelessWidget {
  const PulseIcon(this.icon, {super.key, this.size, this.color, this.semanticLabel});

  final PulseIcons icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    return SvgPicture.asset(
      icon.asset,
      width: s,
      height: s,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
