import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/db/app_database.dart';
import '../data/models/session_tool.dart';
import 'ping_provider.dart';

@immutable
class HistoryFilter {
  const HistoryFilter({this.tool, this.search = ''});
  final SessionTool? tool;
  final String search;
}

final historyFilterProvider = NotifierProvider<HistoryFilterNotifier, HistoryFilter>(HistoryFilterNotifier.new);

class HistoryFilterNotifier extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => const HistoryFilter();

  void setTool(SessionTool? t) => state = HistoryFilter(tool: t, search: state.search);
  void setSearch(String s) => state = HistoryFilter(tool: state.tool, search: s);
}

final historyProvider = StreamProvider<List<Session>>((ref) {
  final f = ref.watch(historyFilterProvider);
  return ref.watch(historyRepositoryProvider).watch(tool: f.tool, search: f.search);
});

/// Selected session id on the History screen.
final selectedSessionIdProvider = NotifierProvider<SelectedSession, int?>(SelectedSession.new);

class SelectedSession extends Notifier<int?> {
  @override
  int? build() => null;
  void select(int? id) => state = id;
}
