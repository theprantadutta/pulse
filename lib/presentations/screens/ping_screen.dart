import 'dart:async';
import 'dart:math'; // For demo data generation

import 'package:flutter/material.dart';

class PingScreen extends StatefulWidget {
  static const kRouteName = '/ping';
  const PingScreen({super.key});

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  final TextEditingController _addressController = TextEditingController();
  bool _isPinging = false;
  int _pingCount = 4;
  bool _continuousPing = false;
  List<PingResult> _currentResults = [];
  List<PingHistoryItem> _history = [];
  Timer? _pingTimer;

  // For the chart
  final List<PingDataPoint> _chartData = [];
  final int _maxChartPoints = 20;

  @override
  void dispose() {
    _addressController.dispose();
    _pingTimer?.cancel();
    super.dispose();
  }

  void _startPing() {
    if (_addressController.text.isEmpty) return;

    setState(() {
      _isPinging = true;
      _currentResults = [];
      _chartData.clear();
    });

    // Add to history if not already there
    _addToHistory(_addressController.text);

    // Setup ping timer
    _pingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _performSinglePing();

      // Stop after reaching count unless continuous
      if (!_continuousPing && _currentResults.length >= _pingCount) {
        _stopPing();
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    setState(() {
      _isPinging = false;
    });
  }

  void _performSinglePing() {
    // In a real app, this would use a platform channel to perform actual pings
    // For demo purposes, we'll generate random results
    final bool success = Random().nextDouble() > 0.2; // 80% success rate
    final int responseTime = success ? Random().nextInt(100) + 10 : 0;
    final int ttl = success ? 64 : 0;

    final result = PingResult(
      timestamp: DateTime.now(),
      success: success,
      responseTime: responseTime,
      ttl: ttl,
    );

    setState(() {
      _currentResults.add(result);

      // Add to chart data
      _chartData.add(
        PingDataPoint(
          time: _chartData.length.toString(),
          responseTime: responseTime.toDouble(),
          success: success,
        ),
      );

      // Keep chart data limited to max points
      if (_chartData.length > _maxChartPoints) {
        _chartData.removeAt(0);
      }
    });
  }

  void _addToHistory(String address) {
    // Check if already in history
    if (!_history.any((item) => item.address == address)) {
      setState(() {
        _history.insert(
          0,
          PingHistoryItem(address: address, timestamp: DateTime.now()),
        );

        // Keep history limited to 10 items
        if (_history.length > 10) {
          _history.removeLast();
        }
      });
    } else {
      // Move to top if already exists
      setState(() {
        _history.removeWhere((item) => item.address == address);
        _history.insert(
          0,
          PingHistoryItem(address: address, timestamp: DateTime.now()),
        );
      });
    }
  }

  void _rePing(String address) {
    _addressController.text = address;
    _startPing();
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(title: const Text('Ping Tool'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input field and ping button
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _addressController,
                    enabled: !_isPinging,
                    decoration: InputDecoration(
                      labelText: 'IP Address or Domain',
                      hintText: 'e.g., google.com or 192.168.1.1',
                      floatingLabelBehavior: FloatingLabelBehavior.always,

                      // Default border
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          12,
                        ), // Rounded corners
                        borderSide: BorderSide(
                          color: kPrimaryColor.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),

                      // Focused border (when tapped)
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: kPrimaryColor.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),

                      // Error border (when validation fails)
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.red, // Red for errors
                          width: 2,
                        ),
                      ),

                      // Border when the field is focused & has an error
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.red.shade700, // Darker red when focused
                          width: 2.5,
                        ),
                      ),

                      // Disabled border
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300, // Light gray
                          width: 1.5,
                        ),
                      ),

                      // Padding inside the input
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 8),
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _isPinging ? _stopPing : _startPing,
                      child: Container(
                        height: 50,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _isPinging
                                  ? Colors.red.withValues(alpha: 0.1)
                                  : kPrimaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Center(
                          child: Text(
                            _isPinging ? 'Stop' : 'Ping',
                            style: TextStyle(
                              color: _isPinging ? Colors.red : kPrimaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Ping options
            Row(
              children: [
                // Number of pings
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Number of Pings',
                      border: OutlineInputBorder(),
                    ),
                    value: _pingCount,
                    items:
                        [4, 8, 16, 32, 64].map((count) {
                          return DropdownMenuItem<int>(
                            value: count,
                            child: Text('$count pings'),
                          );
                        }).toList(),
                    onChanged:
                        _isPinging
                            ? null
                            : (value) {
                              if (value != null) {
                                setState(() {
                                  _pingCount = value;
                                });
                              }
                            },
                  ),
                ),
                const SizedBox(width: 16),
                // Continuous ping toggle
                Expanded(
                  child: Row(
                    children: [
                      Checkbox(
                        value: _continuousPing,
                        onChanged:
                            _isPinging
                                ? null
                                : (value) {
                                  setState(() {
                                    _continuousPing = value ?? false;
                                  });
                                },
                      ),
                      const Text('Continuous Ping'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Results display
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    TabBar(
                      tabs: [
                        Tab(text: 'Results'),
                        Tab(text: 'Chart'),
                        Tab(text: 'History'),
                      ],
                      labelColor: kPrimaryColor,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Results tab
                          _buildResultsTab(kPrimaryColor),

                          // Chart tab
                          _buildChartTab(),

                          // History tab
                          _buildHistoryTab(),
                        ],
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

  Widget _buildResultsTab(Color kPrimaryColor) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: const [
              Expanded(
                flex: 1,
                child: Text(
                  'No.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Time',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Time (ms)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 1,
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
              _currentResults.isEmpty
                  ? const Center(child: Text('No results yet'))
                  : ListView.builder(
                    itemCount: _currentResults.length,
                    itemBuilder: (context, index) {
                      final result = _currentResults[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color:
                            index % 2 == 0
                                ? Colors.grey.withValues(alpha: 0.1)
                                : null,
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Text('${index + 1}')),
                            Expanded(
                              flex: 4,
                              child: Text(
                                '${result.timestamp.hour}:${result.timestamp.minute}:${result.timestamp.second}',
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                result.success ? 'Success' : 'Failed',
                                style: TextStyle(
                                  color:
                                      result.success
                                          ? Colors.green
                                          : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                result.success
                                    ? '${result.responseTime}ms'
                                    : '-',
                              ),
                            ),
                            Expanded(
                              flex: 1,
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
        if (_currentResults.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('Packets', '${_currentResults.length}'),
                    _buildSummaryItem(
                      'Success',
                      '${_currentResults.where((r) => r.success).length}',
                      Colors.green,
                    ),
                    _buildSummaryItem(
                      'Failed',
                      '${_currentResults.where((r) => !r.success).length}',
                      Colors.red,
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

  Widget _buildChartTab() {
    return _chartData.isEmpty
        ? const Center(child: Text('No data to display'))
        : _buildResponseTimeChart();
  }

  Widget _buildResponseTimeChart() {
    // This is a simplified chart implementation
    // In a real app, you'd use a chart library like fl_chart
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Response Time (ms)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxHeight = constraints.maxHeight - 50;
              final double maxWidth = constraints.maxWidth;
              final double barWidth = maxWidth / _chartData.length - 4;
              final kPrimaryColor = Theme.of(context).primaryColor;

              // Find maximum response time for scaling
              final double maxResponseTime = _chartData
                  .map((d) => d.responseTime)
                  .reduce((a, b) => a > b ? a : b);

              return Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children:
                          _chartData.map((data) {
                            final double height =
                                data.success
                                    ? (data.responseTime / maxResponseTime) *
                                        maxHeight
                                    : 10; // Small bar for failed pings

                            return Container(
                              width: barWidth,
                              height: height,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color:
                                    data.success ? kPrimaryColor : Colors.red,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 30,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0'),
                        Text('Ping Sequence'),
                        Text('${_chartData.length}'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return _history.isEmpty
        ? const Center(child: Text('No ping history'))
        : ListView.builder(
          itemCount: _history.length,
          itemBuilder: (context, index) {
            final item = _history[index];
            return ListTile(
              title: Text(item.address),
              subtitle: Text(
                '${item.timestamp.day}/${item.timestamp.month}/${item.timestamp.year} ${item.timestamp.hour}:${item.timestamp.minute}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _rePing(item.address),
              ),
              onTap: () => _rePing(item.address),
            );
          },
        );
  }

  String _calculateAverageTime() {
    final successfulPings = _currentResults.where((r) => r.success).toList();
    if (successfulPings.isEmpty) return '0';

    final totalTime = successfulPings.fold<int>(
      0,
      (prev, result) => prev + result.responseTime,
    );
    return (totalTime / successfulPings.length).toStringAsFixed(1);
  }
}

// Models
class PingResult {
  final DateTime timestamp;
  final bool success;
  final int responseTime; // in milliseconds
  final int ttl;

  PingResult({
    required this.timestamp,
    required this.success,
    required this.responseTime,
    required this.ttl,
  });
}

class PingHistoryItem {
  final String address;
  final DateTime timestamp;

  PingHistoryItem({required this.address, required this.timestamp});
}

class PingDataPoint {
  final String time;
  final double responseTime;
  final bool success;

  PingDataPoint({
    required this.time,
    required this.responseTime,
    required this.success,
  });
}
