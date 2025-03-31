import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:syncfusion_flutter_charts/charts.dart';

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

  // Geolocation
  String geoIpAddress = '';
  Map<String, dynamic> geoResults = {};
  bool isLoadingGeo = false;

  // Network monitoring
  bool isMonitoring = false;
  List<Map<String, dynamic>> networkStats = [];
  Timer? monitorTimer;

  var _markers = <Marker>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    monitorTimer?.cancel();
    super.dispose();
  }

  // geolocation lookup
  Future<void> lookupGeolocation() async {
    if (geoIpAddress.isEmpty) return;

    setState(() {
      isLoadingGeo = true;
    });

    try {
      final token = dotenv.get('IP_INFO_TOKEN', fallback: null);

      // Make an API call to ipinfo.io
      final response = await http.get(
        Uri.parse('https://ipinfo.io/$geoIpAddress?token=$token'),
      );

      if (response.statusCode == 200) {
        // Parse the JSON response
        final data = json.decode(response.body);

        // Update the state with real data
        setState(() {
          isLoadingGeo = false;
          geoResults = {
            'ip': data['ip'],
            'country': data['country'],
            'region': data['region'],
            'city': data['city'],
            'lat': data['loc']?.split(',')[0], // Extract latitude
            'lng': data['loc']?.split(',')[1], // Extract longitude
            'isp': data['org'],
          };
          _markers = [
            Marker(
              point: latlong2.LatLng(
                double.tryParse(geoResults['lat'] ?? '') ?? 51.509364,
                double.tryParse(geoResults['lng'] ?? '') ?? -0.128928,
              ),
              child: IconButton(
                onPressed: () {},
                icon: Icon(Icons.location_on, color: Colors.black87),
              ),
            ),
          ];
        });
      } else {
        // Handle API errors
        setState(() {
          isLoadingGeo = false;
          geoResults = {
            'error':
                'Failed to fetch geolocation data. Status code: ${response.statusCode}',
          };
        });
      }
    } catch (e) {
      // Handle network or parsing errors
      setState(() {
        isLoadingGeo = false;
        geoResults = {'error': 'An error occurred: $e'};
      });
    }
  }

  void startNetworkMonitoring() {
    if (isMonitoring) return;

    setState(() {
      isMonitoring = true;
      networkStats.clear();
    });

    // List of reliable servers to ping
    final servers = ['google.com', 'cloudflare.com', '1.1.1.1', '8.8.8.8'];

    // Use a slightly longer interval to reduce load
    monitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final timestamp = DateTime.now();
      final results = await _gatherNetworkMetrics(servers);

      setState(() {
        networkStats.add({
          'timestamp': timestamp,
          'latency': results['latency'],
          'packetLoss': results['packetLoss'],
          'jitter': results['jitter'],
        });

        if (networkStats.length > 30) {
          // Keep fewer data points
          networkStats.removeAt(0);
        }
      });
    });
  }

  Future<Map<String, double>> _gatherNetworkMetrics(
    List<String> servers,
  ) async {
    List<double> latencies = [];
    int failedPings = 0;

    // Only test a subset of servers each time to reduce load
    final serversToTest = servers.take(2).toList();

    // Run pings in parallel instead of sequentially
    List<Future<double?>> pingFutures =
        serversToTest.map((server) async {
          try {
            final stopwatch = Stopwatch()..start();

            stopwatch.stop();
            return stopwatch.elapsedMilliseconds.toDouble();
          } catch (e) {
            return null; // Return null for failed pings
          }
        }).toList();

    // Wait for all pings to complete
    final results = await Future.wait(pingFutures);

    // Process results
    for (final result in results) {
      if (result != null) {
        latencies.add(result);
      } else {
        failedPings++;
      }
    }

    // Calculate metrics
    double avgLatency =
        latencies.isEmpty
            ? 0
            : latencies.reduce((a, b) => a + b) / latencies.length;
    double jitter = 0;
    if (latencies.length > 1) {
      double sum = 0;
      for (int i = 0; i < latencies.length - 1; i++) {
        sum += (latencies[i] - latencies[i + 1]).abs();
      }
      jitter = sum / (latencies.length - 1);
    }

    double packetLoss =
        serversToTest.isEmpty ? 0 : failedPings / serversToTest.length;

    return {'latency': avgLatency, 'packetLoss': packetLoss, 'jitter': jitter};
  }

  void stopNetworkMonitoring() {
    monitorTimer?.cancel();
    setState(() {
      isMonitoring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Column(
      children: [
        // TabBar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Geolocation', icon: Icon(Icons.location_on)),
            Tab(text: 'Network Monitor', icon: Icon(Icons.speed)),
            Tab(text: 'Alerts', icon: Icon(Icons.notifications)),
          ],
        ),

        // TabBarView (expanded to fill remaining space)
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGeolocationTab(kPrimaryColor),
              _buildNetworkMonitorTab(kPrimaryColor),
              _buildAlertsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertsTab() {
    return Center(
      child: Center(
        child: SizedBox(
          width: 400,
          child: Column(
            spacing: 10,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 80),
              Text(
                'Not Implemented Yet',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              Text(
                'This feature is not implemented yet. We are working on it and it will be available soon.',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeolocationTab(Color kPrimaryColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 10),
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
                        decoration: InputDecoration(
                          labelText: 'Enter IP Address',
                          hintText: 'e.g. 8.8.8.8',
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
                              color:
                                  Colors
                                      .red
                                      .shade700, // Darker red when focused
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
                        onChanged: (value) {
                          setState(() {
                            geoIpAddress = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: isLoadingGeo ? null : lookupGeolocation,
                        child: Container(
                          height: 50,
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 15,
                          ),
                          decoration: BoxDecoration(
                            color: kPrimaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child:
                                isLoadingGeo
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(
                                      'Lookup',
                                      style: TextStyle(
                                        color: kPrimaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
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
                                color: kPrimaryColor.withValues(alpha: 0.05),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: StatefulBuilder(
                                key: Key(geoResults.toString()),
                                builder: (context, setMapState) {
                                  return FlutterMap(
                                    options: MapOptions(
                                      initialCenter: latlong2.LatLng(
                                        double.tryParse(
                                              geoResults['lat'] ?? '',
                                            ) ??
                                            51.509364,
                                        double.tryParse(
                                              geoResults['lng'] ?? '',
                                            ) ??
                                            -0.128928,
                                      ),
                                      initialZoom: 9.2,
                                    ),
                                    children: [
                                      TileLayer(
                                        // Bring your own tiles
                                        urlTemplate:
                                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // For demonstration only
                                        userAgentPackageName:
                                            'com.example.app', // Add your app identifier
                                        // And many more recommended properties!
                                      ),
                                      RichAttributionWidget(
                                        // Include a stylish prebuilt attribution widget that meets all requirments
                                        attributions: [
                                          TextSourceAttribution(
                                            'OpenStreetMap contributors',
                                            // onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')), // (external)
                                            onTap: () {}, // (external)
                                          ),
                                          // Also add images...
                                        ],
                                      ),
                                      MarkerLayer(markers: _markers),
                                    ],
                                  );
                                },
                              ),
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

  Widget _buildNetworkMonitorTab(Color kPrimaryColor) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Network Monitor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ElevatedButton.icon(
                      //   icon: Icon(
                      //     isMonitoring ? Icons.stop : Icons.play_arrow,
                      //   ),
                      //   label: Text(
                      //     isMonitoring ? 'Stop Monitoring' : 'Start Monitoring',
                      //   ),
                      //   onPressed:
                      //       isMonitoring
                      //           ? stopNetworkMonitoring
                      //           : startNetworkMonitoring,
                      //   style: ElevatedButton.styleFrom(
                      //     padding: const EdgeInsets.symmetric(
                      //       horizontal: 24,
                      //       vertical: 12,
                      //     ),
                      //   ),
                      // ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap:
                              isMonitoring
                                  ? stopNetworkMonitoring
                                  : startNetworkMonitoring,
                          child: Container(
                            height: 50,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMonitoring
                                      ? Colors.red.withOpacity(0.1)
                                      : kPrimaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isMonitoring
                                        ? Icons.stop
                                        : Icons.play_arrow,
                                    color:
                                        isMonitoring
                                            ? Colors.red
                                            : kPrimaryColor,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    isMonitoring
                                        ? 'Stop Monitoring'
                                        : 'Start Monitoring',
                                    style: TextStyle(
                                      color:
                                          isMonitoring
                                              ? Colors.red
                                              : kPrimaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 5.0,
                vertical: 10.0,
              ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkStatsChart() {
    // Convert your map data to typed objects for better performance
    final chartData =
        networkStats
            .map(
              (stat) => NetworkData(
                timestamp: stat['timestamp'] as DateTime,
                latency: (stat['latency'] as num).toDouble(),
                packetLoss:
                    (stat['packetLoss'] as num).toDouble() *
                    100, // Convert to percentage
                jitter: (stat['jitter'] as num).toDouble(),
              ),
            )
            .toList();

    return SfCartesianChart(
      legend: Legend(isVisible: true, position: LegendPosition.top),
      tooltipBehavior: TooltipBehavior(enable: true),
      primaryXAxis: DateTimeAxis(
        majorGridLines: const MajorGridLines(width: 0),
        intervalType: DateTimeIntervalType.auto,
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Latency (ms)'),
        majorGridLines: const MajorGridLines(width: 0.5),
      ),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'packetLossAxis',
          opposedPosition: true,
          title: AxisTitle(text: 'Packet Loss (%)'),
          majorGridLines: const MajorGridLines(width: 0),
        ),
        NumericAxis(
          name: 'jitterAxis',
          opposedPosition: true,
          title: AxisTitle(text: 'Jitter (ms)'),
          majorGridLines: const MajorGridLines(width: 0),
        ),
      ],
      series: <CartesianSeries>[
        LineSeries<NetworkData, DateTime>(
          name: 'Latency',
          dataSource: chartData,
          xValueMapper: (NetworkData data, _) => data.timestamp,
          yValueMapper: (NetworkData data, _) => data.latency,
          color: Colors.blue,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
        LineSeries<NetworkData, DateTime>(
          name: 'Packet Loss',
          dataSource: chartData,
          xValueMapper: (NetworkData data, _) => data.timestamp,
          yValueMapper: (NetworkData data, _) => data.packetLoss,
          yAxisName: 'packetLossAxis',
          color: Colors.red,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
        LineSeries<NetworkData, DateTime>(
          name: 'Jitter',
          dataSource: chartData,
          xValueMapper: (NetworkData data, _) => data.timestamp,
          yValueMapper: (NetworkData data, _) => data.jitter,
          yAxisName: 'jitterAxis',
          color: Colors.green,
          markerSettings: const MarkerSettings(isVisible: true),
        ),
      ],
    );
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

// Custom painter for network stats
class NetworkStatsPainter extends CustomPainter {
  final List<Map<String, dynamic>> networkStats;

  // Cache values to avoid recomputing every frame
  double _maxLatency = 1.0;
  double _maxPacketLoss = 0.01;
  double _maxJitter = 1.0;

  NetworkStatsPainter(this.networkStats) {
    // Compute max values only once during construction
    _computeMaxValues();
  }

  void _computeMaxValues() {
    if (networkStats.isEmpty) return;

    for (var stat in networkStats) {
      _maxLatency = math.max(_maxLatency, stat['latency'].toDouble());
      _maxPacketLoss = math.max(_maxPacketLoss, stat['packetLoss'].toDouble());
      _maxJitter = math.max(_maxJitter, stat['jitter'].toDouble());
    }

    // Add padding to max values
    _maxLatency *= 1.2;
    _maxPacketLoss *= 1.2;
    _maxJitter *= 1.2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (networkStats.isEmpty) return;
  }

  @override
  bool shouldRepaint(NetworkStatsPainter oldDelegate) {
    // Only repaint if the data length changes (new data point added)
    return oldDelegate.networkStats.length != networkStats.length;
  }
}

class NetworkData {
  final DateTime timestamp;
  final double latency;
  final double packetLoss;
  final double jitter;

  NetworkData({
    required this.timestamp,
    required this.latency,
    required this.packetLoss,
    required this.jitter,
  });
}
