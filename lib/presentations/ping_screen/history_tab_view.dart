import 'package:flutter/material.dart';

import '../screens/ping_screen.dart';

class HistoryTabView extends StatelessWidget {
  final List<PingHistoryItem> history;
  final Function(String address, {int? interval, int? timeout}) rePing;

  const HistoryTabView({
    super.key,
    required this.history,
    required this.rePing,
  });

  @override
  Widget build(BuildContext context) {
    return history.isEmpty
        ? const Center(child: Text('No ping history'))
        : ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final item = history[index];
            return ListTile(
              title: Text(item.address),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year} ${item.timestamp.hour}:${item.timestamp.minute}',
                  ),
                  Text(
                    'Interval: ${item.interval}s | Timeout: ${item.timeout}s',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed:
                    () => rePing(
                      item.address,
                      interval: item.interval,
                      timeout: item.timeout,
                    ),
              ),
              onTap:
                  () => rePing(
                    item.address,
                    interval: item.interval,
                    timeout: item.timeout,
                  ),
              isThreeLine: true,
            );
          },
        );
  }
}
