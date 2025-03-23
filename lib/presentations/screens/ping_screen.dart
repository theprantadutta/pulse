import 'dart:async';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

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
  final List<PingHistoryItem> _history = [];
  Timer? _pingTimer;
  late final ScrollController _scrollController = ScrollController();

  // For the chart
  final List<PingDataPoint> _chartData = [];
  final int _maxChartPoints = 20;

  // New parameters
  int _interval = 1;
  int _timeout = 5;

  @override
  void dispose() {
    _addressController.dispose();
    _pingTimer?.cancel();
    _scrollController.dispose();
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

    // Setup ping timer with selected interval
    _pingTimer = Timer.periodic(Duration(seconds: _interval), (timer) async {
      _performSinglePing();

      // Stop after reaching count unless continuous
      if (!_continuousPing && _currentResults.length >= _pingCount - 1) {
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

  void _performSinglePing() async {
    final address = _addressController.text;
    // Create a Ping object with the desired host and parameters
    final ping = Ping(
      address,
      count: 1,
      interval: _interval,
      timeout: _timeout,
    );

    // Listen to the ping stream
    ping.stream.listen(
      (event) {
        if (event.response != null) {
          final response = event.response!;
          // Handle PingResponse
          final bool success = response.time != null;
          // final int responseTime = response.time?.round() ?? 0;
          final int responseTime = response.time?.inMilliseconds ?? 0;
          final int ttl = response.ttl ?? 0;
          final bool timedOut = !success;

          final result = PingResult(
            timestamp: DateTime.now(),
            success: success,
            responseTime: responseTime,
            ttl: ttl,
            timedOut: timedOut,
          );

          setState(() {
            _currentResults.add(result);

            // Add to chart data
            _chartData.add(
              PingDataPoint(
                time: _chartData.length.toString(),
                responseTime: responseTime.toDouble(),
                success: success,
                timedOut: timedOut,
              ),
            );

            // Keep chart data limited to max points
            if (_chartData.length > _maxChartPoints) {
              _chartData.removeAt(0);
            }

            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent + 50,
                duration: Duration(milliseconds: 500),
                curve: Curves.easeOut,
              );
            }
          });
        } else if (event.summary != null) {
          // final summary = event.summary!;
          // Handle PingSummary if needed
          // print(
          //   'Ping Summary: ${summary.transmitted} transmitted, ${summary.received} received',
          // );
        }
      },
      onError: (error) {
        // Handle any errors that occur during the ping process
        print('Ping error: $error');

        final result = PingResult(
          timestamp: DateTime.now(),
          success: false,
          responseTime: 0,
          ttl: 0,
          timedOut: true,
        );

        setState(() {
          _currentResults.add(result);

          // Add to chart data
          _chartData.add(
            PingDataPoint(
              time: _chartData.length.toString(),
              responseTime: 0.0,
              success: false,
              timedOut: true,
            ),
          );

          // Keep chart data limited to max points
          if (_chartData.length > _maxChartPoints) {
            _chartData.removeAt(0);
          }

          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent + 50,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
      },
    );
  }

  void _addToHistory(String address) {
    // Check if already in history
    if (!_history.any((item) => item.address == address)) {
      setState(() {
        _history.insert(
          0,
          PingHistoryItem(
            address: address,
            timestamp: DateTime.now(),
            interval: _interval,
            timeout: _timeout,
          ),
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
          PingHistoryItem(
            address: address,
            timestamp: DateTime.now(),
            interval: _interval,
            timeout: _timeout,
          ),
        );
      });
    }
  }

  void _rePing(String address, {int? interval, int? timeout}) {
    _addressController.text = address;

    // Apply saved settings if provided
    if (interval != null) {
      setState(() => _interval = interval);
    }
    if (timeout != null) {
      setState(() => _timeout = timeout);
    }

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

            // Ping options - First row
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

            SizedBox(height: 16),

            // New options - Second row
            Row(
              children: [
                // Timeout
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Timeout (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    value: _timeout,
                    items:
                        [1, 2, 3, 5, 10, 15, 30].map((timeout) {
                          return DropdownMenuItem<int>(
                            value: timeout,
                            child: Text('$timeout sec'),
                          );
                        }).toList(),
                    onChanged:
                        _isPinging
                            ? null
                            : (value) {
                              if (value != null) {
                                setState(() {
                                  _timeout = value;
                                });
                              }
                            },
                  ),
                ),
                const SizedBox(width: 16),
                // Interval
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Interval (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    value: _interval,
                    items:
                        [1, 2, 3, 5, 10].map((interval) {
                          return DropdownMenuItem<int>(
                            value: interval,
                            child: Text('$interval sec'),
                          );
                        }).toList(),
                    onChanged:
                        _isPinging
                            ? null
                            : (value) {
                              if (value != null) {
                                setState(() {
                                  _interval = value;
                                });
                              }
                            },
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
                flex: 3,
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
                    controller: _scrollController,
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
                              flex: 3,
                              child: Text(
                                DateFormat(
                                  "hh:mm:ss a",
                                ).format(result.timestamp),
                              ),
                            ),
                            Expanded(
                              flex: 2,
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
                      '${_currentResults.where((r) => !r.success && !r.timedOut).length}',
                      Colors.red,
                    ),
                    _buildSummaryItem(
                      'Timeout',
                      '${_currentResults.where((r) => r.timedOut).length}',
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
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'Response Time (ms)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SfCartesianChart(
            primaryXAxis: NumericAxis(
              title: AxisTitle(text: 'Ping Sequence'),
              majorGridLines: const MajorGridLines(width: 0),
            ),
            primaryYAxis: NumericAxis(
              title: AxisTitle(text: 'Response Time (ms)'),
            ),
            tooltipBehavior: TooltipBehavior(enable: true),
            legend: Legend(isVisible: true, position: LegendPosition.bottom),
            series: <CartesianSeries>[
              ColumnSeries<PingDataPoint, int>(
                animationDuration: 1000,
                name: 'Success',
                dataSource:
                    _chartData
                        .where((data) => data.success && !data.timedOut)
                        .toList(),
                xValueMapper:
                    (PingDataPoint data, _) => _chartData.indexOf(data),
                yValueMapper: (PingDataPoint data, _) => data.responseTime,
                color: Colors.green,
                width: 0.8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              ColumnSeries<PingDataPoint, int>(
                animationDuration: 1000,
                name: 'Failed',
                dataSource:
                    _chartData
                        .where((data) => !data.success && !data.timedOut)
                        .toList(),
                xValueMapper:
                    (PingDataPoint data, _) => _chartData.indexOf(data),
                yValueMapper:
                    (PingDataPoint data, _) =>
                        data.responseTime > 0 ? data.responseTime : 10,
                color: Colors.red,
                width: 0.8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
              ColumnSeries<PingDataPoint, int>(
                animationDuration: 1000,
                name: 'Timeout',
                dataSource: _chartData.where((data) => data.timedOut).toList(),
                xValueMapper:
                    (PingDataPoint data, _) => _chartData.indexOf(data),
                yValueMapper:
                    (PingDataPoint data, _) =>
                        data.responseTime > 0 ? data.responseTime : 10,
                color: Colors.orange,
                width: 0.8,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
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
                    () => _rePing(
                      item.address,
                      interval: item.interval,
                      timeout: item.timeout,
                    ),
              ),
              onTap:
                  () => _rePing(
                    item.address,
                    interval: item.interval,
                    timeout: item.timeout,
                  ),
              isThreeLine: true,
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
  final bool timedOut;

  PingResult({
    required this.timestamp,
    required this.success,
    required this.responseTime,
    required this.ttl,
    required this.timedOut,
  });
}

class PingHistoryItem {
  final String address;
  final DateTime timestamp;
  final int interval;
  final int timeout;

  PingHistoryItem({
    required this.address,
    required this.timestamp,
    required this.interval,
    required this.timeout,
  });
}

class PingDataPoint {
  final String time;
  final double responseTime;
  final bool success;
  final bool timedOut;

  PingDataPoint({
    required this.time,
    required this.responseTime,
    required this.success,
    required this.timedOut,
  });
}
