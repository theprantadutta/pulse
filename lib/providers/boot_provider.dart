import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/background/notifications.dart';
import '../services/desktop/desktop_host.dart';
import '../services/desktop/launch_at_login.dart';
import 'connection_provider.dart';
import 'database_provider.dart';
import 'monitor_provider.dart';
import 'settings_provider.dart';

/// Set from main() when the OS launched Pulse at login (`--autostart`).
bool launchedAtLogin = false;

class BootState {
  const BootState({
    required this.step,
    required this.total,
    required this.status,
    this.version = '',
    this.done = false,
    this.error,
  });

  final int step;
  final int total;
  final String status;
  final String version;
  final bool done;
  final Object? error;

  double get progress => total == 0 ? 0 : step / total;
}

/// A named start-up task run while the launch route is visible.
typedef BootTask = ({String status, Future<void> Function(Ref ref) run});

/// Extra start-up tasks registered by services (background monitor, tray…).
final bootTasksProvider = Provider<List<BootTask>>((ref) => const []);

final bootProvider = NotifierProvider<BootNotifier, BootState>(BootNotifier.new);

class BootNotifier extends Notifier<BootState> {
  bool _started = false;

  @override
  BootState build() =>
      const BootState(step: 0, total: 1, status: 'Starting…');

  Future<void> run() async {
    if (_started) return;
    _started = true;
    final info = await PackageInfo.fromPlatform();
    final version = 'v${info.version}';
    final tasks = <BootTask>[
      (
        status: 'Opening database…',
        run: (ref) async {
          final db = ref.read(databaseProvider);
          await db.customSelect('SELECT 1').get();
          await db.applyRetention(ref.read(settingsProvider).retentionDays);
        },
      ),
      (
        status: 'Reading network interfaces…',
        run: (ref) async {
          await ref.read(connectionProvider.future).timeout(
            const Duration(seconds: 2),
            onTimeout: () => ConnectionSummary.offline,
          );
        },
      ),
      (
        status: 'Starting notifications…',
        run: (ref) async => PulseNotifications.init(),
      ),
      if (DesktopHost.supported)
        (
          status: 'Adding tray icon…',
          run: (ref) async {
            final host = DesktopHost.instance;
            final runner = ref.read(monitorRunnerProvider.notifier);
            host
              ..onTogglePause = runner.togglePaused
              ..onHint = (message) => PulseNotifications.show(id: 1, title: 'Pulse', body: message, sound: false);
            await host.initTray();
            await host.setCloseToTray(ref.read(settingsProvider).closeToTray);
            final wantLogin = ref.read(settingsProvider).launchAtStartup;
            if (await LaunchAtLogin.isEnabled() != wantLogin) await LaunchAtLogin.setEnabled(wantLogin);
          },
        ),
      (
        status: 'Starting monitor…',
        run: (ref) async => ref.read(monitorRunnerProvider.notifier).start(),
      ),
      ...ref.read(bootTasksProvider),
    ];
    for (var i = 0; i < tasks.length; i++) {
      state = BootState(
        step: i,
        total: tasks.length,
        status: tasks[i].status,
        version: version,
      );
      try {
        await tasks[i].run(ref);
      } catch (e) {
        // A failing optional task must not block the app from opening; the
        // failure is surfaced on the launch screen and in the relevant screen.
        state = BootState(
          step: i,
          total: tasks.length,
          status: tasks[i].status,
          version: version,
          error: e,
        );
      }
    }
    state = BootState(
      step: tasks.length,
      total: tasks.length,
      status: 'Ready',
      version: version,
      done: true,
    );
  }
}
