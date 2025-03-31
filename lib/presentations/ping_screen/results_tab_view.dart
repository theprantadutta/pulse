import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/ping_screen.dart';

class ResultsTabView extends StatelessWidget {
  final ScrollController scrollController;
  final List<PingResult> currentResults;

  const ResultsTabView({
    super.key,
    required this.currentResults,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: const [
                Expanded(
                  flex: 2,
                  child: Text(
                    'No.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Text(
                    'Time',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'Time (ms)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TTL',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Results list
          Expanded(
            child:
                currentResults.isEmpty
                    ? const Center(child: Text('No results yet'))
                    : ListView.builder(
                      itemCount: currentResults.length,
                      controller: scrollController,
                      itemBuilder: (context, index) {
                        final result = currentResults[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          color:
                              index % 2 == 0
                                  ? Colors.grey.withValues(alpha: 0.1)
                                  : null,
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text('${index + 1}')),
                              Expanded(
                                flex: 5,
                                child: Text(
                                  DateFormat(
                                    "hh:mm:ss",
                                  ).format(result.timestamp),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  result.timedOut
                                      ? 'Timeout'
                                      : (result.success ? 'Success' : 'Failed'),
                                  style: TextStyle(
                                    color:
                                        result.timedOut
                                            ? Colors.orange
                                            : (result.success
                                                ? Colors.green
                                                : Colors.red),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  result.success
                                      ? '${result.responseTime}ms'
                                      : '-',
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  result.success ? '${result.ttl}' : '-',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
          // Summary
          if (currentResults.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem('Packets', '${currentResults.length}'),
                      _buildSummaryItem(
                        'Success',
                        '${currentResults.where((r) => r.success).length}',
                        Colors.green,
                      ),
                      _buildSummaryItem(
                        'Failed',
                        '${currentResults.where((r) => !r.success && !r.timedOut).length}',
                        Colors.red,
                      ),
                      _buildSummaryItem(
                        'Timeout',
                        '${currentResults.where((r) => r.timedOut).length}',
                        Colors.orange,
                      ),
                      _buildSummaryItem(
                        'Avg Time',
                        '${_calculateAverageTime()}ms',
                        kPrimaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, [Color? color]) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _calculateAverageTime() {
    final successfulPings = currentResults.where((r) => r.success).toList();
    if (successfulPings.isEmpty) return '0';

    final totalTime = successfulPings.fold<int>(
      0,
      (prev, result) => prev + result.responseTime,
    );
    return (totalTime / successfulPings.length).toStringAsFixed(1);
  }
}
