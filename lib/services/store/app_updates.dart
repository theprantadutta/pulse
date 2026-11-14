import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/constants/shared_preference_keys.dart';
import '../../providers/settings_provider.dart';
import '../update_checker.dart';

enum UpdateStatus { idle, checking, upToDate, available, downloading, readyToInstall, failed }

/// Where the update comes from: Google Play's in-app update flow, or the
/// latest GitHub release (desktop, and Android builds not installed by Play).
enum UpdateSource { play, github }

class AppUpdateState {
  const AppUpdateState({
    this.status = UpdateStatus.idle,
    this.source,
    this.currentVersion,
    this.latestVersion,
    this.url,
    this.message,
    this.checkedAt,
  });

  final UpdateStatus status;
  final UpdateSource? source;
  final String? currentVersion;

  /// "1.2.0" from GitHub; Play only reports a version code.
  final String? latestVersion;

  /// Release page (GitHub source).
  final String? url;
  final String? message;
  final DateTime? checkedAt;

  bool get busy => status == UpdateStatus.checking || status == UpdateStatus.downloading;

  AppUpdateState copyWith({
    UpdateStatus? status,
    UpdateSource? source,
    String? currentVersion,
    String? latestVersion,
    String? url,
    String? message,
    DateTime? checkedAt,
    bool clearMessage = false,
  }) => AppUpdateState(
    status: status ?? this.status,
    source: source ?? this.source,
    currentVersion: currentVersion ?? this.currentVersion,
    latestVersion: latestVersion ?? this.latestVersion,
    url: url ?? this.url,
    message: clearMessage ? null : message ?? this.message,
    checkedAt: checkedAt ?? this.checkedAt,
  );
}

final appUpdateProvider = NotifierProvider<AppUpdateNotifier, AppUpdateState>(AppUpdateNotifier.new);

/// In-app updates for the whole app. On Android installs from Google Play it
/// uses Play's in-app update API (a flexible download in the background, or an
/// immediate full-screen update when the release is urgent); everywhere else
/// it compares with the latest GitHub release.
class AppUpdateNotifier extends Notifier<AppUpdateState> {
  AppUpdateInfo? _play;
  StreamSubscription<InstallStatus>? _installs;

  /// Automatic checks run at most this often.
  static const autoCheckEvery = Duration(hours: 12);

  @override
  AppUpdateState build() {
    ref.onDispose(() => _installs?.cancel());
    return const AppUpdateState();
  }

  /// Checks for an update. [silent] checks (app start) keep failures quiet
  /// and skip when one ran in the last [autoCheckEvery].
  Future<void> check({bool silent = false}) async {
    if (state.busy) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final now = DateTime.now();
    if (silent) {
      final last = prefs.getInt(kUpdateLastCheckKey);
      if (last != null && now.difference(DateTime.fromMillisecondsSinceEpoch(last)) < autoCheckEvery) return;
    }
    final current = state.currentVersion ?? (await PackageInfo.fromPlatform()).version;
    state = state.copyWith(status: UpdateStatus.checking, currentVersion: current, clearMessage: true);
    try {
      if (Platform.isAndroid && await _checkPlay(now)) {
        await prefs.setInt(kUpdateLastCheckKey, now.millisecondsSinceEpoch);
        return;
      }
      final info = await const UpdateChecker().check(current);
      state = state.copyWith(
        status: info.newer ? UpdateStatus.available : UpdateStatus.upToDate,
        source: UpdateSource.github,
        latestVersion: info.latest,
        url: info.url,
        checkedAt: now,
      );
      await prefs.setInt(kUpdateLastCheckKey, now.millisecondsSinceEpoch);
    } on Object {
      state = state.copyWith(
        status: silent ? UpdateStatus.idle : UpdateStatus.failed,
        message: "Couldn't check for updates. Check your connection and try again.",
      );
    }
  }

  /// True when Google Play answered (the app was installed by Play).
  Future<bool> _checkPlay(DateTime now) async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      _play = info;
      final status = switch (info) {
        _ when info.installStatus == InstallStatus.downloaded => UpdateStatus.readyToInstall,
        _ when info.installStatus == InstallStatus.downloading || info.installStatus == InstallStatus.pending =>
          UpdateStatus.downloading,
        _
            when info.updateAvailability == UpdateAvailability.updateAvailable ||
                info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress =>
          UpdateStatus.available,
        _ => UpdateStatus.upToDate,
      };
      state = state.copyWith(status: status, source: UpdateSource.play, checkedAt: now);
      if (status == UpdateStatus.downloading) _listen();
      return true;
    } on PlatformException {
      // Not installed by Google Play (debug, sideloaded): use GitHub instead.
      return false;
    }
  }

  /// Starts the update the last check found. Play: urgent releases (priority
  /// 4+ or 30 days old) update immediately, others download in the
  /// background. GitHub updates are opened by the caller ([state.url]).
  Future<void> startUpdate() async {
    final info = _play;
    if (state.source != UpdateSource.play || info == null) return;
    final urgent = info.updatePriority >= 4 || (info.clientVersionStalenessDays ?? 0) >= 30;
    try {
      if ((urgent || !info.flexibleUpdateAllowed) && info.immediateUpdateAllowed) {
        final r = await InAppUpdate.performImmediateUpdate();
        if (r == AppUpdateResult.inAppUpdateFailed) _failed();
        return;
      }
      if (info.flexibleUpdateAllowed) {
        _listen();
        final r = await InAppUpdate.startFlexibleUpdate();
        state = switch (r) {
          AppUpdateResult.success => state.copyWith(status: UpdateStatus.downloading, clearMessage: true),
          AppUpdateResult.userDeniedUpdate => state.copyWith(status: UpdateStatus.available),
          AppUpdateResult.inAppUpdateFailed => state.copyWith(
            status: UpdateStatus.failed,
            message: "The update didn't start. Try again, or update from Google Play.",
          ),
        };
        return;
      }
      await InAppReview.instance.openStoreListing();
    } on PlatformException {
      _failed();
    }
  }

  /// Restarts into the downloaded update (flexible flow).
  Future<void> install() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } on PlatformException {
      _failed();
    }
  }

  void _listen() {
    _installs ??= InAppUpdate.installUpdateListener.listen((s) {
      state = switch (s) {
        InstallStatus.pending || InstallStatus.downloading => state.copyWith(status: UpdateStatus.downloading),
        InstallStatus.downloaded => state.copyWith(status: UpdateStatus.readyToInstall),
        InstallStatus.failed => state.copyWith(
          status: UpdateStatus.failed,
          message: 'The download failed. Try again, or update from Google Play.',
        ),
        InstallStatus.canceled => state.copyWith(status: UpdateStatus.available),
        _ => state,
      };
    }, onError: (Object _) {});
  }

  void _failed() => state = state.copyWith(
    status: UpdateStatus.failed,
    message: "The update didn't finish. Try again, or update from Google Play.",
  );

  /// Whether the app-start prompt for this update should show: once per
  /// version, then again after three days.
  bool shouldPrompt() {
    if (state.status != UpdateStatus.available) return false;
    final key = state.latestVersion ?? '${_play?.availableVersionCode ?? ''}';
    final raw = ref.read(sharedPreferencesProvider).getString(kUpdatePromptedKey);
    if (raw == null) return true;
    final [version, at] = raw.contains('|') ? raw.split('|') : [raw, '0'];
    final since = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(int.tryParse(at) ?? 0));
    return version != key || since > const Duration(days: 3);
  }

  Future<void> markPrompted() async {
    final key = state.latestVersion ?? '${_play?.availableVersionCode ?? ''}';
    await ref
        .read(sharedPreferencesProvider)
        .setString(kUpdatePromptedKey, '$key|${DateTime.now().millisecondsSinceEpoch}');
  }
}
