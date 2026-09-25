import 'package:intl/intl.dart';

/// Milliseconds as shown in stats: "0.4", "8.2", "25", "112".
String fmtMs(double? v) {
  if (v == null) return '—';
  if (v < 10) return v.toStringAsFixed(1);
  return v.round().toString();
}

/// "0%", "2.5%", "100%".
String fmtPct(double? v) {
  if (v == null) return '—';
  if (v == 0 || v >= 100 || v % 1 == 0) return '${v.round()}%';
  return '${v.toStringAsFixed(1)}%';
}

String fmtCount(int n) {
  if (n >= 100000) return '${(n / 1000).round()}K';
  if (n >= 10000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

final _time = DateFormat('HH:mm:ss.SSS');
final _hm = DateFormat('HH:mm');
final _monthDay = DateFormat('MMM d');

String fmtTimestamp(DateTime t) => _time.format(t);

/// "TODAY 13:58", "YEST 22:41", "SEP 23 16:44".
String fmtWhen(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(t.year, t.month, t.day);
  final diff = today.difference(day).inDays;
  final hm = _hm.format(t);
  if (diff == 0) return 'TODAY $hm';
  if (diff == 1) return 'YEST $hm';
  return '${_monthDay.format(t).toUpperCase()} $hm';
}

/// "4 MIN", "1 HR", "2 D".
String fmtDuration(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} S';
  if (d.inMinutes < 60) return '${d.inMinutes} MIN';
  if (d.inHours < 48) return '${d.inHours} HR';
  return '${d.inDays} D';
}
