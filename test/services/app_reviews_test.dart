import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/constants/shared_preference_keys.dart';
import 'package:pulse/services/store/app_reviews.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<(AppReviews, SharedPreferences)> make(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    return (AppReviews(prefs), prefs);
  }

  final day = const Duration(days: 1).inMilliseconds;
  final now = DateTime(2026, 11, 20);
  int daysAgo(int d) => now.millisecondsSinceEpoch - d * day;

  test('not before enough successful runs and a few days of use', () async {
    final (r, _) = await make({kReviewMomentsKey: 4, kReviewFirstMomentKey: daysAgo(10)});
    expect(r.isDue(now: now), isFalse, reason: 'only 4 runs');
    final (r2, _) = await make({kReviewMomentsKey: 9, kReviewFirstMomentKey: daysAgo(1)});
    expect(r2.isDue(now: now), isFalse, reason: 'first run was yesterday');
    final (r3, _) = await make({kReviewMomentsKey: 5, kReviewFirstMomentKey: daysAgo(3)});
    expect(r3.isDue(now: now), isTrue);
  });

  test('never twice within four months, and at most three times', () async {
    final base = {kReviewMomentsKey: 20, kReviewFirstMomentKey: daysAgo(400)};
    final (recent, _) = await make({...base, kReviewLastAskedKey: daysAgo(30), kReviewTimesAskedKey: 1});
    expect(recent.isDue(now: now), isFalse);
    final (later, _) = await make({...base, kReviewLastAskedKey: daysAgo(121), kReviewTimesAskedKey: 1});
    expect(later.isDue(now: now), isTrue);
    final (done, _) = await make({...base, kReviewLastAskedKey: daysAgo(300), kReviewTimesAskedKey: 3});
    expect(done.isDue(now: now), isFalse);
  });

  test('recording a moment counts it and remembers the first one', () async {
    final (r, prefs) = await make({});
    await r.recordMoment();
    await r.recordMoment();
    expect(prefs.getInt(kReviewMomentsKey), 2);
    expect(prefs.getInt(kReviewFirstMomentKey), isNotNull);
  });
}
