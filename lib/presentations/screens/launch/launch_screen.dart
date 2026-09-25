import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/brand/pulse_mark.dart';
import '../../../core/widgets/wire/wire.dart';
import '../../../core/widgets/wire/wire_page.dart';
import '../../../providers/boot_provider.dart';
import '../../../services/desktop/desktop_host.dart';
import '../../navigation/destinations.dart';

/// Launch route shown while providers initialise. Desktop matches the
/// 720×440 launch window; mobile continues the native splash.
class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key, this.next = Routes.ping});
  final String next;

  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bootProvider.notifier).run();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bootProvider, (prev, next) async {
      if (!next.done || (prev?.done ?? false)) return;
      if (DesktopHost.supported) await DesktopHost.instance.openAppWindow();
      if (context.mounted) context.go(widget.next);
    });
    final boot = ref.watch(bootProvider);
    return context.isMobileLayout ? _MobileLaunch(boot: boot) : _DesktopLaunch(boot: boot);
  }
}

class _DesktopLaunch extends StatelessWidget {
  const _DesktopLaunch({required this.boot});
  final BootState boot;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    return Scaffold(
      backgroundColor: w.background,
      body: Container(
        decoration: BoxDecoration(border: Border.all(color: w.ink, width: kWireBorder)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 10,
              child: Container(
                color: w.signal,
                alignment: Alignment.center,
                child: LayoutBuilder(
                  builder: (context, box) => PulseMark(
                    size: (box.maxHeight * 0.4).clamp(48, 360),
                  ),
                ),
              ),
            ),
            Container(width: kWireBorder, color: w.ink),
            Expanded(
              flex: 14,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(56, 56, 56, 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(boot.version, style: WireType.data(15).copyWith(color: w.ink)),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PULSE',
                        style: WireType.display(230, width: 72).copyWith(color: w.ink),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'NETWORK DIAGNOSTICS',
                      style: WireType.label(15).copyWith(color: w.ink, letterSpacing: 3),
                    ),
                    const Spacer(),
                    WireProgress(value: boot.progress, height: 26, signal: false),
                    const SizedBox(height: 18),
                    Text(
                      boot.error != null ? '${boot.status} failed — continuing' : boot.status,
                      style: WireType.body(15).copyWith(
                        color: boot.error != null ? w.signal : w.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileLaunch extends StatelessWidget {
  const _MobileLaunch({required this.boot});
  final BootState boot;

  @override
  Widget build(BuildContext context) {
    final w = context.wire;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? w.background : w.signal;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            PulseMark(
              size: 150,
              colorway: dark ? PulseMarkColorway.dark : PulseMarkColorway.primary,
            ),
            const Spacer(),
            Text(
              'PULSE',
              style: WireType.display(56, width: 75).copyWith(
                color: dark ? w.ink : w.onSignal,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: WireProgress(value: boot.progress, height: 10, signal: false),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
