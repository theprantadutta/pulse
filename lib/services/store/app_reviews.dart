import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/share_config.dart';
import '../../core/constants/shared_preference_keys.dart';
import '../../core/widgets/pulse/pulse.dart';
import '../../providers/settings_provider.dart';

final appReviewProvider = Provider<AppReviews>((ref) => AppReviews(ref.watch(sharedPreferencesProvider)));

/// Bumps on every saved run; StorePrompts listens, records the moment and asks
/// for a review when one is due.
final reviewMomentsProvider = NotifierProvider<ReviewMoments, int>(ReviewMoments.new);

class ReviewMoments extends Notifier<int> {
  @override
  int build() => 0;

  void recorded() => state++;
}

/// In-app reviews. The native review sheet (Google Play / App Store) is only
/// asked for at a good moment: after several successful runs, a few days in,
/// at most three times and never twice within four months. Stores limit how
/// often it may appear and may show nothing, so the "Rate Pulse" buttons open
/// the store page instead, which always works.
class AppReviews {
  AppReviews(this._prefs);
  final SharedPreferences _prefs;

  static const momentsNeeded = 5;
  static const daysBeforeAsking = 3;
  static const daysBetweenAsks = 120;
  static const maxAsks = 3;

  /// The platforms with a native review sheet.
  static bool get supported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Counts a successful moment (a finished run saved to History).
  Future<void> recordMoment() async {
    await _prefs.setInt(kReviewMomentsKey, (_prefs.getInt(kReviewMomentsKey) ?? 0) + 1);
    if (!_prefs.containsKey(kReviewFirstMomentKey)) {
      await _prefs.setInt(kReviewFirstMomentKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Whether it's a good time to ask (see the class doc).
  bool isDue({DateTime? now}) {
    now ??= DateTime.now();
    final moments = _prefs.getInt(kReviewMomentsKey) ?? 0;
    final first = _prefs.getInt(kReviewFirstMomentKey);
    final last = _prefs.getInt(kReviewLastAskedKey);
    final times = _prefs.getInt(kReviewTimesAskedKey) ?? 0;
    if (moments < momentsNeeded || first == null || times >= maxAsks) return false;
    if (now.difference(DateTime.fromMillisecondsSinceEpoch(first)).inDays < daysBeforeAsking) return false;
    if (last != null && now.difference(DateTime.fromMillisecondsSinceEpoch(last)).inDays < daysBetweenAsks) {
      return false;
    }
    return true;
  }

  /// Shows the native review sheet when [isDue]. Returns whether it asked.
  Future<bool> maybeAsk() async {
    if (!supported || !isDue()) return false;
    final review = InAppReview.instance;
    try {
      if (!await review.isAvailable()) return false;
      await _prefs.setInt(kReviewLastAskedKey, DateTime.now().millisecondsSinceEpoch);
      await _prefs.setInt(kReviewTimesAskedKey, (_prefs.getInt(kReviewTimesAskedKey) ?? 0) + 1);
      await review.requestReview();
      return true;
    } on Object {
      return false;
    }
  }

  /// Where "Rate Pulse" can send people on this platform, or null.
  static String? get storeUrl {
    if (Platform.isAndroid) return PulseShareConfig.playStoreUrl;
    if (Platform.isIOS || Platform.isMacOS) return PulseShareConfig.appStoreUrl;
    return null;
  }

  /// Opens Pulse's store page to rate it (the "Rate Pulse" buttons).
  static Future<void> openStorePage(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        await InAppReview.instance.openStoreListing();
        return;
      }
      final id = PulseShareConfig.appStoreId;
      if ((Platform.isIOS || Platform.isMacOS) && id != null) {
        await InAppReview.instance.openStoreListing(appStoreId: id);
        return;
      }
    } on Object {
      // Fall back to the web page below.
    }
    final url = storeUrl;
    if (url != null && context.mounted) await openExternalLink(context, url);
  }
}
