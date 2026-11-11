import 'dart:async';

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/pulse/pulse.dart';
import '../../../providers/boot_provider.dart';
import '../../../services/desktop/desktop_host.dart';
import '../../navigation/destinations.dart';

/// 01 Splash: the in-app continuation of the native splash.
///
/// main() holds the OS splash with `FlutterNativeSplash.preserve`; this screen
/// is the single place that releases it, after its own first frame. The native
/// image is drawn with [PulseLogo]'s exact geometry at 168 dp on the same
/// surface colour, centred on the full screen, so the hand-off is invisible:
/// the static mark simply starts to spin and beat. Then the wordmark and
/// tagline rise in below it while the boot tasks run, and after at least one
/// full heartbeat (~900 ms) the app cross-fades in.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key, this.next = Routes.ping});
  final String next;

  /// Logo size shared with the native splash image (672 px at 4x).
  static const nativeLogo = 168.0;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  static const _minimum = Duration(milliseconds: 900);

  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  final _shown = Stopwatch()..start();
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Our first frame is on screen and identical to the native image:
      // release the OS splash and start the motion.
      FlutterNativeSplash.remove();
      if (!mounted) return;
      if (PulseMotion.reduced(context)) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
      ref.read(bootProvider.notifier).run();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    final wait = _minimum - _shown.elapsed;
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (DesktopHost.supported) DesktopHost.instance.openAppWindow();
    if (mounted) context.go(widget.next);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bootProvider, (prev, next) {
      if (next.done && !(prev?.done ?? false)) unawaited(_leave());
    });
    final boot = ref.watch(bootProvider);
    final c = context.colors;
    final size = MediaQuery.sizeOf(context);
    // Desktop launch window (720x440) and landscape phones need a smaller mark.
    final tight = size.height < 560;
    final large = !tight && size.shortestSide >= 600;
    final logo = tight ? 120.0 : SplashScreen.nativeLogo;
    final grow = large ? 220 / SplashScreen.nativeLogo : 1.0;
    final wordmark = large ? 72.0 : (tight ? 40.0 : 52.0);
    final barWidth = large ? 220.0 : 160.0;

    return Scaffold(
      backgroundColor: c.surface,
      body: AnimatedBuilder(
        animation: _intro,
        builder: (context, _) {
          final t = _intro.value;
          // Tablets: the mark grows from the native size to 220 with the spring.
          final scale = 1 + (grow - 1) * PulseMotion.spring.transform((t / .64).clamp(0, 1));
          final text = PulseMotion.emphasizedDecelerate.transform(((t - .32) / .68).clamp(0, 1));
          final logoBottom = size.height / 2 + logo * scale / 2;
          return Stack(
            children: [
              // Exactly centred on the full screen, like the native splash.
              Center(
                child: Transform.scale(
                  scale: scale,
                  child: PulseLogo(size: logo),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                top: logoBottom + (tight ? 12 : 28),
                child: Opacity(
                  opacity: text,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - text)),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pulse',
                          style: pulseText(
                            wordmark,
                            800,
                            wdth: 125,
                            height: 1,
                            tracking: -.02,
                          ).copyWith(color: c.onSurface),
                        ),
                        SizedBox(height: tight ? 4 : 10),
                        Text(
                          'Network tools that feel alive',
                          textAlign: TextAlign.center,
                          style: context.type.bodyLarge!.copyWith(fontSize: 15, color: c.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: tight ? 28 : 64,
                child: Opacity(
                  opacity: text,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulseWavyBar(value: boot.done ? 1 : boot.progress, width: barWidth, semanticLabel: 'Starting'),
                      const SizedBox(height: 10),
                      Text(
                        boot.error != null ? '${boot.status.replaceAll('…', '')} failed, continuing' : _label(boot),
                        style: context.type.labelMedium!.copyWith(color: c.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _label(BootState boot) => boot.done ? 'Ready' : boot.status;
}
