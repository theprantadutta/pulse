import 'dart:async';

import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse/presentations/ping_screen/charts_tab_view.dart';
import 'package:pulse/presentations/ping_screen/history_tab_view.dart';

import '../ping_screen/results_tab_view.dart';
import '../widgets/app_bar_layout.dart';

class PingScreen extends ConsumerStatefulWidget {
  static const kRouteName = '/ping';
  const PingScreen({super.key});

  @override
  ConsumerState<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends ConsumerState<PingScreen>
    with TickerProviderStateMixin {
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

  late TabController _tabController;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    _tabController = TabController(length: 3, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _pingTimer?.cancel();
    _scrollController.dispose();
    _tabController.dispose();
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

    // // Apply saved settings if provided
    // if (interval != null) {
    //   setState(() => _interval = interval);
    // }
    // if (timeout != null) {
    //   setState(() => _timeout = timeout);
    // }

    setState(() {
      if (interval != null) _interval = interval;
      if (timeout != null) _timeout = timeout;
      _selectedTabIndex = 0;
      _tabController.animateTo(0);
    });

    _startPing();
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBarLayout(title: 'Ping Tool'),
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
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _isPinging ? _stopPing : _startPing,
                  child: Container(
                    height: 50,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
            ],
          ),

          SizedBox(height: 16),

          // Ping options - First row
          Row(
            children: [
              // Number of pings
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Number of Pings',
                      border: OutlineInputBorder(),
                    ),
                    padding: EdgeInsets.zero,
                    value: _pingCount,
                    items:
                        [4, 8, 16, 32, 64].map((count) {
                          return DropdownMenuItem<int>(
                            value: count,
                            child: Text(
                              '$count pings',
                              style: TextStyle(fontSize: 13),
                            ),
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
              ),
              const SizedBox(width: 8),
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
                    const Expanded(
                      // Wrap the Text widget in Expanded
                      child: Text(
                        'Continuous Ping',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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
                child: SizedBox(
                  height: 50,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Timeout (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    padding: EdgeInsets.zero,
                    value: _timeout,
                    items:
                        [1, 2, 3, 5, 10, 15, 30].map((timeout) {
                          return DropdownMenuItem<int>(
                            value: timeout,
                            child: Text(
                              '$timeout sec',
                              style: TextStyle(fontSize: 13),
                            ),
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
              ),
              const SizedBox(width: 8),
              // Interval
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Interval (seconds)',
                      border: OutlineInputBorder(),
                    ),
                    padding: EdgeInsets.zero,
                    value: _interval,
                    items:
                        [1, 2, 3, 5, 10].map((interval) {
                          return DropdownMenuItem<int>(
                            value: interval,
                            child: Text(
                              '$interval sec',
                              style: TextStyle(fontSize: 13),
                            ),
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
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Results display
          Expanded(
            child: DefaultTabController(
              initialIndex: _selectedTabIndex,
              length: 3,
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    onTap:
                        (value) => setState(() {
                          _selectedTabIndex = value;
                          _tabController.animateTo(value);
                        }),
                    tabs: [
                      Tab(text: 'Results'),
                      Tab(text: 'Chart'),
                      Tab(text: 'History'),
                    ],
                    labelColor: kPrimaryColor,
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Results tab
                        ResultsTabView(
                          currentResults: _currentResults,
                          scrollController: _scrollController,
                        ),

                        // Chart tab
                        ChartsTabView(chartData: _chartData),

                        // History tab
                        HistoryTabView(
                          history: _history,
                          rePing:
                              (address, {interval, timeout}) => _rePing(
                                address,
                                interval: interval,
                                timeout: timeout,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
