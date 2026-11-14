import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/pulse/pulse.dart';
import '../../services/store/app_reviews.dart';
import '../../services/store/app_updates.dart';

/// App-wide update and review prompts, around the shell:
/// * a quiet update check at start (at most every 12 h), then "Update" when
///   one is out and "Restart" once a background download finished;
/// * after a saved run, the store's review sheet when one is due.
class StorePrompts extends ConsumerStatefulWidget {
  const StorePrompts({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<StorePrompts> createState() => _StorePromptsState();
}

class _StorePromptsState extends ConsumerState<StorePrompts> with WidgetsBindingObserver {
  Timer? _reviewTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Let the first screen settle before talking to the store.
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) unawaited(ref.read(appUpdateProvider.notifier).check(silent: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reviewTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A flexible download may have finished while Pulse was in the background.
    if (state == AppLifecycleState.resumed) {
      final u = ref.read(appUpdateProvider);
      if (u.source == UpdateSource.play && u.status == UpdateStatus.downloading) {
        unawaited(ref.read(appUpdateProvider.notifier).check());
      }
    }
  }

  void _onUpdate(AppUpdateState? prev, AppUpdateState next) {
    final notifier = ref.read(appUpdateProvider.notifier);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (next.status == UpdateStatus.readyToInstall && prev?.status != UpdateStatus.readyToInstall) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(days: 1),
            content: const Text('Update downloaded. Restart Pulse to finish.'),
            action: SnackBarAction(label: 'Restart', onPressed: notifier.install),
          ),
        );
    } else if (next.status == UpdateStatus.available &&
        prev?.status == UpdateStatus.checking &&
        notifier.shouldPrompt()) {
      unawaited(notifier.markPrompted());
      final v = next.latestVersion;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text(v == null ? 'A new version of Pulse is available.' : 'Pulse $v is available.'),
            action: SnackBarAction(label: 'Update', onPressed: () => startAppUpdate(context, ref)),
          ),
        );
    } else if (next.status == UpdateStatus.failed && prev?.status == UpdateStatus.downloading) {
      showPulseToast(context, next.message ?? 'The update failed.', icon: PulseIcons.refresh);
    }
  }

  void _onMoment() {
    final reviews = ref.read(appReviewProvider);
    unawaited(
      reviews.recordMoment().then((_) {
        if (!reviews.isDue()) return;
        // After the result has been on screen for a moment, never mid-run.
        _reviewTimer?.cancel();
        _reviewTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
            unawaited(reviews.maybeAsk());
          }
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(appUpdateProvider, _onUpdate);
    ref.listen(reviewMomentsProvider, (_, _) => _onMoment());
    return widget.child;
  }
}

/// Starts whatever update the last check found: Play's in-app flow, or the
/// GitHub release page.
Future<void> startAppUpdate(BuildContext context, WidgetRef ref) async {
  final s = ref.read(appUpdateProvider);
  if (s.source == UpdateSource.play) {
    await ref.read(appUpdateProvider.notifier).startUpdate();
  } else if (s.url != null && context.mounted) {
    await openExternalLink(context, s.url!);
  }
}
