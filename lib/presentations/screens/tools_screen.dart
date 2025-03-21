import 'dart:async';

import 'package:flutter/material.dart';

class ToolsScreen extends StatefulWidget {
  static const kRouteName = '/tools';
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isDarkMode = false;
  Color primaryColor = Colors.blue;

  // Ping settings
  int packetSize = 32;
  int pingInterval = 1000; // milliseconds
  int pingTimeout = 5000; // milliseconds
  String pingTarget = '8.8.8.8';
  List<int> pingResults = [];
  bool isPinging = false;
  Timer? pingTimer;

  // Geolocation
  String geoIpAddress = '';
  Map<String, dynamic> geoResults = {};
  bool isLoadingGeo = false;

  // Network monitoring
  bool isMonitoring = false;
  List<Map<String, dynamic>> networkStats = [];
  Timer? monitorTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    pingTimer?.cancel();
    monitorTimer?.cancel();
    super.dispose();
  }

  // Simulate ping functionality
  void startPing() {
    if (isPinging) return;

    setState(() {
      isPinging = true;
      pingResults.clear();
    });

    pingTimer = Timer.periodic(Duration(milliseconds: pingInterval), (timer) {
      // In a real app, you would use a platform channel to perform actual pings
      // This is just a simulation
      final pingTime = 20 + (DateTime.now().millisecondsSinceEpoch % 80);

      setState(() {
        pingResults.add(pingTime);
        if (pingResults.length > 100) {
          pingResults.removeAt(0);
        }
      });
    });
  }

  void stopPing() {
    pingTimer?.cancel();
    setState(() {
      isPinging = false;
    });
  }

  // Simulate geolocation lookup
  Future<void> lookupGeolocation() async {
    if (geoIpAddress.isEmpty) return;

    setState(() {
      isLoadingGeo = true;
    });

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // In a real app, you would make an API call to a geolocation service
    setState(() {
      isLoadingGeo = false;
      geoResults = {
        'ip': geoIpAddress,
        'country': 'United States',
        'region': 'California',
        'city': 'Mountain View',
        'lat': 37.4223,
        'lng': -122.0846,
        'isp': 'Google LLC',
      };
    });
  }

  // Simulate network monitoring
  void startNetworkMonitoring() {
    if (isMonitoring) return;

    setState(() {
      isMonitoring = true;
      networkStats.clear();
    });

    monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      // In a real app, you would gather actual network statistics
      final timestamp = DateTime.now();
      final latency = 30 + (timestamp.millisecondsSinceEpoch % 50);
      final packetLoss = (timestamp.millisecondsSinceEpoch % 5) / 100;

      setState(() {
        networkStats.add({
          'timestamp': timestamp,
          'latency': latency,
          'packetLoss': packetLoss,
          'jitter': (timestamp.millisecondsSinceEpoch % 10).toDouble(),
        });

        if (networkStats.length > 100) {
          networkStats.removeAt(0);
        }
      });
    });
  }

  void stopNetworkMonitoring() {
    monitorTimer?.cancel();
    setState(() {
      isMonitoring = false;
    });
  }

  // Toggle between light and dark themes
  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  // Change the primary color
  void changeColor(Color color) {
    setState(() {
      primaryColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).copyWith(
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      colorScheme: (isDarkMode
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(primary: primaryColor),
    );

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Network Tools'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Ping', icon: Icon(Icons.sensors)),
              Tab(text: 'Geolocation', icon: Icon(Icons.location_on)),
              Tab(text: 'Network Monitor', icon: Icon(Icons.speed)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
              onPressed: toggleTheme,
              tooltip: 'Toggle theme',
            ),
            PopupMenuButton<Color>(
              icon: const Icon(Icons.palette),
              tooltip: 'Change theme color',
              onSelected: changeColor,
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: Colors.blue,
                      child: ColorOption(color: Colors.blue, name: 'Blue'),
                    ),
                    PopupMenuItem(
                      value: Colors.red,
                      child: ColorOption(color: Colors.red, name: 'Red'),
                    ),
                    PopupMenuItem(
                      value: Colors.green,
                      child: ColorOption(color: Colors.green, name: 'Green'),
                    ),
                    PopupMenuItem(
                      value: Colors.purple,
                      child: ColorOption(color: Colors.purple, name: 'Purple'),
                    ),
                    PopupMenuItem(
                      value: Colors.orange,
                      child: ColorOption(color: Colors.orange, name: 'Orange'),
                    ),
                  ],
            ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPingTab(),
            _buildGeolocationTab(),
            _buildNetworkMonitorTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPingTab() {
    final avgPing =
        pingResults.isEmpty
            ? 0.0
            : pingResults.reduce((a, b) => a + b) / pingResults.length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Custom Ping Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Target IP or Domain',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          pingTarget = value;
                        });
                      },
                      initialValue: pingTarget,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Packet Size: ${packetSize}B'),
                              Slider(
                                value: packetSize.toDouble(),
                                min: 16,
                                max: 1024,
                                divisions: 50,
                                onChanged: (value) {
                                  setState(() {
                                    packetSize = value.round();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Interval: ${pingInterval}ms'),
                              Slider(
                                value: pingInterval.toDouble(),
                                min: 100,
                                max: 5000,
                                divisions: 49,
                                onChanged: (value) {
                                  setState(() {
                                    pingInterval = value.round();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Timeout: ${pingTimeout}ms'),
                              Slider(
                                value: pingTimeout.toDouble(),
                                min: 1000,
                                max: 10000,
                                divisions: 9,
                                onChanged: (value) {
                                  setState(() {
                                    pingTimeout = value.round();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(isPinging ? Icons.stop : Icons.play_arrow),
                          label: Text(isPinging ? 'Stop' : 'Start Ping'),
                          onPressed: isPinging ? stopPing : startPing,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ping Results',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Target: $pingTarget${isPinging ? " (pinging)" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Average: ${avgPing.toStringAsFixed(2)}ms',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Samples: ${pingResults.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child:
                          pingResults.isEmpty
                              ? const Center(child: Text('No ping data yet'))
                              : _buildPingChart(),
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

  Widget _buildPingChart() {
    // In a real app, you would use a proper charting library
    // This is a simple visualization
    return CustomPaint(painter: PingChartPainter(pingResults));
  }

  Widget _buildGeolocationTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'IP Geolocation',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Enter IP Address',
                            hintText: 'e.g. 8.8.8.8',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            setState(() {
                              geoIpAddress = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: isLoadingGeo ? null : lookupGeolocation,
                        child:
                            isLoadingGeo
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Lookup'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child:
                    geoResults.isEmpty
                        ? const Center(
                          child: Text('Enter an IP address and click Lookup'),
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'IP: ${geoResults['ip']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Location: ${geoResults['city']}, ${geoResults['region']}, ${geoResults['country']}',
                            ),
                            Text('ISP: ${geoResults['isp']}'),
                            Text(
                              'Coordinates: ${geoResults['lat']}, ${geoResults['lng']}',
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    // In a real app, you would use a proper map widget
                                    // like Google Maps or MapBox
                                    Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: Text('Map would appear here'),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: Center(
                                        child: Icon(
                                          Icons.location_on,
                                          color: primaryColor,
                                          size: 32,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkMonitorTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Network Monitor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(
                            isMonitoring ? Icons.stop : Icons.play_arrow,
                          ),
                          label: Text(
                            isMonitoring
                                ? 'Stop Monitoring'
                                : 'Start Monitoring',
                          ),
                          onPressed:
                              isMonitoring
                                  ? stopNetworkMonitoring
                                  : startNetworkMonitoring,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Network Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isMonitoring)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child:
                          networkStats.isEmpty
                              ? const Center(
                                child: Text('No monitoring data yet'),
                              )
                              : _buildNetworkStatsChart(),
                    ),
                    const SizedBox(height: 16),
                    if (networkStats.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Latest Measurements',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      _buildNetworkStatsTable(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStatsChart() {
    // In a real app, you would use a proper charting library
    // This is a simple visualization
    return CustomPaint(painter: NetworkStatsPainter(networkStats));
  }

  Widget _buildNetworkStatsTable() {
    final latestStats =
        networkStats.length > 5
            ? networkStats.sublist(networkStats.length - 5)
            : networkStats;

    return Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFEEEEEE)),
          children: [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Time',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Latency',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Packet Loss',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Jitter',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        ...latestStats.reversed.map(
          (stat) => TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '${(stat['timestamp'] as DateTime).hour}:${(stat['timestamp'] as DateTime).minute}:${(stat['timestamp'] as DateTime).second}',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('${stat['latency']}ms'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  '${((stat['packetLoss'] as double) * 100).toStringAsFixed(1)}%',
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('${stat['jitter']}ms'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Simple widget for color selection in the popup menu
class ColorOption extends StatelessWidget {
  final Color color;
  final String name;

  const ColorOption({required this.color, required this.name, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 16),
        Text(name),
      ],
    );
  }
}

// Custom painter for ping chart
class PingChartPainter extends CustomPainter {
  final List<int> pingResults;

  PingChartPainter(this.pingResults);

  @override
  void paint(Canvas canvas, Size size) {
    if (pingResults.isEmpty) return;

    final paint =
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    final path = Path();
    final maxPing = pingResults.reduce((a, b) => a > b ? a : b).toDouble();
    final minPing = pingResults.reduce((a, b) => a < b ? a : b).toDouble();
    final range = maxPing - minPing + 10; // Add padding

    final dx = size.width / (pingResults.length - 1);
    final dy = size.height / range;

    path.moveTo(0, size.height - (pingResults[0] - minPing) * dy);

    for (int i = 1; i < pingResults.length; i++) {
      path.lineTo(i * dx, size.height - (pingResults[i] - minPing) * dy);
    }

    canvas.drawPath(path, paint);

    // Draw grid lines
    final gridPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.5)
          ..strokeWidth = 0.5;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      final pingValue = minPing + (range - range * i / 4);
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${pingValue.round()}ms',
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - 12));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// Custom painter for network stats
class NetworkStatsPainter extends CustomPainter {
  final List<Map<String, dynamic>> networkStats;

  NetworkStatsPainter(this.networkStats);

  @override
  void paint(Canvas canvas, Size size) {
    if (networkStats.isEmpty) return;

    final latencyPaint =
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    final jitterPaint =
        Paint()
          ..color = Colors.orange
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    final packetLossPaint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

    final latencyPath = Path();
    final jitterPath = Path();
    final packetLossPath = Path();

    final maxLatency =
        networkStats
            .map((s) => s['latency'] as int)
            .reduce((a, b) => a > b ? a : b)
            .toDouble();
    final maxJitter = networkStats
        .map((s) => s['jitter'] as double)
        .reduce((a, b) => a > b ? a : b);
    final maxPacketLoss = networkStats
        .map((s) => s['packetLoss'] as double)
        .reduce((a, b) => a > b ? a : b);

    final dx = size.width / (networkStats.length - 1);
    final latencyDy = size.height / (maxLatency + 10); // Add padding
    final jitterDy = size.height / (maxJitter + 1); // Add padding
    final packetLossDy = size.height / (maxPacketLoss + 0.01); // Add padding

    latencyPath.moveTo(0, size.height - networkStats[0]['latency'] * latencyDy);
    jitterPath.moveTo(0, size.height - networkStats[0]['jitter'] * jitterDy);
    packetLossPath.moveTo(
      0,
      size.height - networkStats[0]['packetLoss'] * packetLossDy,
    );

    for (int i = 1; i < networkStats.length; i++) {
      latencyPath.lineTo(
        i * dx,
        size.height - networkStats[i]['latency'] * latencyDy,
      );

      jitterPath.lineTo(
        i * dx,
        size.height - networkStats[i]['jitter'] * jitterDy,
      );

      packetLossPath.lineTo(
        i * dx,
        size.height - networkStats[i]['packetLoss'] * packetLossDy,
      );
    }

    canvas.drawPath(latencyPath, latencyPaint);
    canvas.drawPath(jitterPath, jitterPaint);
    canvas.drawPath(packetLossPath, packetLossPaint);

    // Draw legend
    final legendPaint = Paint()..style = PaintingStyle.fill;

    // Latency
    legendPaint.color = Colors.blue;
    canvas.drawRect(const Rect.fromLTWH(10, 10, 14, 14), legendPaint);
    final latencyText = TextPainter(
      text: const TextSpan(
        text: 'Latency',
        style: TextStyle(color: Colors.black, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    latencyText.layout();
    latencyText.paint(canvas, const Offset(30, 11));

    // Jitter
    legendPaint.color = Colors.orange;
    canvas.drawRect(const Rect.fromLTWH(90, 10, 14, 14), legendPaint);
    final jitterText = TextPainter(
      text: const TextSpan(
        text: 'Jitter',
        style: TextStyle(color: Colors.black, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    jitterText.layout();
    jitterText.paint(canvas, const Offset(110, 11));

    // Packet Loss
    legendPaint.color = Colors.red;
    canvas.drawRect(const Rect.fromLTWH(160, 10, 14, 14), legendPaint);
    final packetLossText = TextPainter(
      text: const TextSpan(
        text: 'Packet Loss',
        style: TextStyle(color: Colors.black, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    packetLossText.layout();
    packetLossText.paint(canvas, const Offset(180, 11));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
