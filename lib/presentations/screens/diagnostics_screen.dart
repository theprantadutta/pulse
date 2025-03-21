import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class DiagnosticsScreen extends StatefulWidget {
  static const kRouteName = '/diagnostics';
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  // Controllers
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portRangeController = TextEditingController(
    text: '1-1000',
  );

  // Current active test
  String _activeTest = '';
  bool _isRunningTest = false;
  double _testProgress = 0.0;
  List<String> _currentResults = [];

  // Log history
  List<DiagnosticLog> _diagnosticLogs = [];

  @override
  void initState() {
    super.initState();
    _loadSavedLogs();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portRangeController.dispose();
    super.dispose();
  }

  // Load saved logs from storage (simulated)
  Future<void> _loadSavedLogs() async {
    // In a real app, you would load from shared preferences or a database
    setState(() {
      _diagnosticLogs = [
        DiagnosticLog(
          type: 'Ping',
          target: 'google.com',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          summary: 'Success: 4/4, Avg time: 36.2ms',
        ),
        DiagnosticLog(
          type: 'Traceroute',
          target: '8.8.8.8',
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          summary: '12 hops, completed successfully',
        ),
        DiagnosticLog(
          type: 'Speed Test',
          target: 'speedtest.net',
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          summary: 'Download: 85.4 Mbps, Upload: 24.2 Mbps',
        ),
      ];
    });
  }

  // Run traceroute test
  Future<void> _runTraceroute() async {
    if (_hostController.text.isEmpty) {
      _showErrorSnackBar('Please enter a host name or IP address');
      return;
    }

    setState(() {
      _activeTest = 'Traceroute';
      _isRunningTest = true;
      _testProgress = 0.0;
      _currentResults = [];
    });

    // Simulated traceroute - in a real app, you would use a platform channel
    // to execute the actual traceroute command
    final host = _hostController.text;
    final hopCount = Random().nextInt(10) + 5; // Between 5-15 hops

    for (int i = 1; i <= hopCount; i++) {
      // Simulate network delay
      await Future.delayed(Duration(milliseconds: 300 + Random().nextInt(500)));

      setState(() {
        _testProgress = i / hopCount;

        // Generate a random IP for this hop
        final ipParts = List.generate(4, (_) => Random().nextInt(256));
        final hopIp = ipParts.join('.');

        // Random response time between 5-100ms
        final responseTime = Random().nextInt(95) + 5;

        _currentResults.add('Hop $i: $hopIp - ${responseTime}ms');
      });
    }

    // Add final destination
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() {
      _testProgress = 1.0;
      _currentResults.add('Hop ${hopCount + 1}: $host - Destination reached');
      _isRunningTest = false;

      // Add to log history
      _diagnosticLogs.insert(
        0,
        DiagnosticLog(
          type: 'Traceroute',
          target: host,
          timestamp: DateTime.now(),
          summary: '${hopCount + 1} hops, completed successfully',
        ),
      );
    });
  }

  // Run speed test
  Future<void> _runSpeedTest() async {
    setState(() {
      _activeTest = 'Speed Test';
      _isRunningTest = true;
      _testProgress = 0.0;
      _currentResults = [];
    });

    // Simulate download test
    _currentResults.add('Testing download speed...');
    await _simulateProgressiveTest(0.0, 0.5, (progress) {
      setState(() {
        _testProgress = progress;
      });
    });

    // Simulate random download speed result
    final downloadSpeed = (Random().nextInt(200) + 50) + Random().nextDouble();
    setState(() {
      _currentResults.add(
        'Download speed: ${downloadSpeed.toStringAsFixed(2)} Mbps',
      );
    });

    // Simulate upload test
    setState(() {
      _currentResults.add('');
      _currentResults.add('Testing upload speed...');
    });

    await _simulateProgressiveTest(0.5, 1.0, (progress) {
      setState(() {
        _testProgress = progress;
      });
    });

    // Simulate random upload speed result
    final uploadSpeed = (Random().nextInt(100) + 10) + Random().nextDouble();

    setState(() {
      _currentResults.add(
        'Upload speed: ${uploadSpeed.toStringAsFixed(2)} Mbps',
      );
      _isRunningTest = false;

      // Add to log history
      _diagnosticLogs.insert(
        0,
        DiagnosticLog(
          type: 'Speed Test',
          target: 'speedtest.net',
          timestamp: DateTime.now(),
          summary:
              'Download: ${downloadSpeed.toStringAsFixed(1)} Mbps, Upload: ${uploadSpeed.toStringAsFixed(1)} Mbps',
        ),
      );
    });
  }

  // Run packet loss test
  Future<void> _runPacketLossTest() async {
    if (_hostController.text.isEmpty) {
      _showErrorSnackBar('Please enter a host name or IP address');
      return;
    }

    setState(() {
      _activeTest = 'Packet Loss Test';
      _isRunningTest = true;
      _testProgress = 0.0;
      _currentResults = [];
    });

    final host = _hostController.text;
    final packetCount = 100;
    int lostPackets = 0;

    _currentResults.add('Sending $packetCount packets to $host...');
    setState(() {});

    for (int i = 1; i <= packetCount; i++) {
      // Simulate sending a packet with random success/failure
      await Future.delayed(Duration(milliseconds: 50 + Random().nextInt(30)));

      final bool packetLost =
          Random().nextDouble() < 0.05; // 5% packet loss rate
      if (packetLost) {
        lostPackets++;
      }

      if (i % 10 == 0 || i == packetCount) {
        setState(() {
          _testProgress = i / packetCount;
          _currentResults = [
            'Sending $packetCount packets to $host...',
            'Progress: $i/$packetCount packets',
            'Current packet loss: ${(lostPackets / i * 100).toStringAsFixed(1)}%',
          ];
        });
      }
    }

    setState(() {
      _isRunningTest = false;
      final lossPercentage = (lostPackets / packetCount * 100).toStringAsFixed(
        1,
      );

      _currentResults.add('');
      _currentResults.add('Test complete!');
      _currentResults.add('Total packets sent: $packetCount');
      _currentResults.add('Packets lost: $lostPackets');
      _currentResults.add('Packet loss rate: $lossPercentage%');

      String quality;
      if (lostPackets == 0) {
        quality = 'Excellent';
      } else if (lostPackets < 2) {
        quality = 'Very Good';
      } else if (lostPackets < 5) {
        quality = 'Good';
      } else if (lostPackets < 10) {
        quality = 'Fair';
      } else {
        quality = 'Poor';
      }

      _currentResults.add('Connection quality: $quality');

      // Add to log history
      _diagnosticLogs.insert(
        0,
        DiagnosticLog(
          type: 'Packet Loss',
          target: host,
          timestamp: DateTime.now(),
          summary: 'Loss rate: $lossPercentage%, Quality: $quality',
        ),
      );
    });
  }

  // Run port scanner
  Future<void> _runPortScan() async {
    if (_hostController.text.isEmpty) {
      _showErrorSnackBar('Please enter a host name or IP address');
      return;
    }

    // Parse port range
    List<int> ports = [];
    try {
      final rangeParts = _portRangeController.text.split('-');
      if (rangeParts.length == 1) {
        // Single port
        ports = [int.parse(rangeParts[0])];
      } else {
        // Port range
        final startPort = int.parse(rangeParts[0]);
        final endPort = int.parse(rangeParts[1]);
        if (startPort > endPort || startPort < 1 || endPort > 65535) {
          throw const FormatException('Invalid port range');
        }
        ports = List.generate(endPort - startPort + 1, (i) => startPort + i);
      }
    } catch (e) {
      _showErrorSnackBar(
        'Invalid port range format. Use "start-end" or a single port number.',
      );
      return;
    }

    if (ports.length > 1000) {
      _showErrorSnackBar('Please limit scan to 1000 ports maximum');
      return;
    }

    setState(() {
      _activeTest = 'Port Scan';
      _isRunningTest = true;
      _testProgress = 0.0;
      _currentResults = [];
    });

    final host = _hostController.text;
    final openPorts = <int>[];

    _currentResults.add('Scanning ${ports.length} ports on $host...');
    setState(() {});

    for (int i = 0; i < ports.length; i++) {
      // Simulate port scan with random results
      await Future.delayed(Duration(milliseconds: 20 + Random().nextInt(30)));

      final port = ports[i];
      final isOpen = Random().nextDouble() < 0.1; // 10% chance of open port

      if (isOpen) {
        openPorts.add(port);
        setState(() {
          _currentResults.add('Port $port: OPEN');
        });
      }

      if (i % 10 == 0 || i == ports.length - 1) {
        setState(() {
          _testProgress = (i + 1) / ports.length;
        });
      }
    }

    setState(() {
      _isRunningTest = false;

      _currentResults.add('');
      _currentResults.add('Scan complete!');
      _currentResults.add('Total ports scanned: ${ports.length}');
      _currentResults.add('Open ports found: ${openPorts.length}');

      if (openPorts.isNotEmpty) {
        _currentResults.add('');
        _currentResults.add('Open ports:');
        openPorts.sort();
        for (final port in openPorts) {
          final service = _getCommonPortService(port);
          _currentResults.add('$port: $service');
        }
      }

      // Add to log history
      _diagnosticLogs.insert(
        0,
        DiagnosticLog(
          type: 'Port Scan',
          target: host,
          timestamp: DateTime.now(),
          summary:
              'Found ${openPorts.length} open ports out of ${ports.length} scanned',
        ),
      );
    });
  }

  // Utility for port scan to show common services
  String _getCommonPortService(int port) {
    final Map<int, String> commonPorts = {
      20: 'FTP Data',
      21: 'FTP Control',
      22: 'SSH',
      23: 'Telnet',
      25: 'SMTP',
      53: 'DNS',
      80: 'HTTP',
      110: 'POP3',
      143: 'IMAP',
      443: 'HTTPS',
      465: 'SMTPS',
      993: 'IMAPS',
      995: 'POP3S',
      3306: 'MySQL',
      3389: 'RDP',
      5432: 'PostgreSQL',
      8080: 'HTTP-Alt',
    };

    return commonPorts[port] ?? 'Unknown service';
  }

  // Helper for simulating a test with progress
  Future<void> _simulateProgressiveTest(
    double start,
    double end,
    Function(double) progressCallback,
  ) async {
    final steps = 20;
    final increment = (end - start) / steps;

    for (int i = 0; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      progressCallback(start + (increment * i));
    }
  }

  // Export logs functionality
  Future<void> _exportLogs() async {
    setState(() {
      _isRunningTest = true;
      _activeTest = 'Exporting Logs';
    });

    try {
      // Format logs as text
      final buffer = StringBuffer();
      buffer.writeln('Network Diagnostics Log Export');
      buffer.writeln(
        'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
      );
      buffer.writeln('');

      for (final log in _diagnosticLogs) {
        buffer.writeln(
          '${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp)} - ${log.type}',
        );
        buffer.writeln('Target: ${log.target}');
        buffer.writeln('Results: ${log.summary}');
        buffer.writeln('');
      }

      // In a real app, you would save this to a file
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/network_diagnostics_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.txt';

      final file = File(path);
      await file.writeAsString(buffer.toString());

      // Use share_plus to share the file
      await Share.shareXFiles([XFile(path)], text: 'Network Diagnostics Log');
    } catch (e) {
      _showErrorSnackBar('Failed to export logs: $e');
    } finally {
      setState(() {
        _isRunningTest = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Diagnostics'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (choice) {
              if (choice == 'export') {
                _exportLogs();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'export',
                  child: Text('Export Logs'),
                ),
              ];
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Input area
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _hostController,
                      decoration: const InputDecoration(
                        labelText: 'Host / IP Address',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., google.com or 192.168.1.1',
                      ),
                      enabled: !_isRunningTest,
                    ),
                    const SizedBox(height: 16),
                    if (_activeTest == 'Port Scan' || _activeTest == '')
                      TextField(
                        controller: _portRangeController,
                        decoration: const InputDecoration(
                          labelText: 'Port Range (for Port Scan)',
                          border: OutlineInputBorder(),
                          hintText: 'e.g., 1-1000 or 80',
                        ),
                        enabled: !_isRunningTest,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Diagnostics buttons
            _isRunningTest
                ? Column(
                  children: [
                    // Test progress
                    Text(
                      '$_activeTest in progress...',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: _testProgress),
                    const SizedBox(height: 16),
                  ],
                )
                : _buildDiagnosticTools(),

            const SizedBox(height: 16),

            // Results area
            Expanded(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Current Results'),
                        Tab(text: 'History'),
                      ],
                      labelColor: Colors.blue,
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Current results tab
                          _buildResultsView(),

                          // History tab
                          _buildHistoryView(),
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

  Widget _buildDiagnosticTools() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.route),
          label: const Text('Traceroute'),
          onPressed: _runTraceroute,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.speed),
          label: const Text('Speed Test'),
          onPressed: _runSpeedTest,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.trending_down),
          label: const Text('Packet Loss'),
          onPressed: _runPacketLossTest,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.filter_list),
          label: const Text('Port Scan'),
          onPressed: _runPortScan,
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    if (_currentResults.isEmpty) {
      return const Center(
        child: Text(
          'No results to display.\nRun a diagnostic test to see results here.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_activeTest Results',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.content_copy),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: _currentResults.join('\n')),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Results copied to clipboard'),
                      ),
                    );
                  },
                  tooltip: 'Copy results',
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _currentResults.length,
                itemBuilder: (context, index) {
                  final line = _currentResults[index];
                  if (line.isEmpty) {
                    return const SizedBox(height: 8);
                  }

                  // Highlight important results with colors
                  Color? textColor;
                  if (line.contains('OPEN')) {
                    textColor = Colors.green;
                  } else if (line.contains('Poor')) {
                    textColor = Colors.red;
                  } else if (line.contains('Excellent') ||
                      line.contains('Very Good')) {
                    textColor = Colors.green;
                  } else if (line.contains('Destination reached')) {
                    textColor = Colors.blue;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: textColor != null ? FontWeight.bold : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    if (_diagnosticLogs.isEmpty) {
      return const Center(
        child: Text(
          'No diagnostic history yet.\nRun tests to build up history.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      itemCount: _diagnosticLogs.length,
      itemBuilder: (context, index) {
        final log = _diagnosticLogs[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: _getIconForDiagnosticType(log.type),
            title: Text('${log.type} - ${log.target}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.summary),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            isThreeLine: true,
            // You could add actions here, like repeat test or delete log
          ),
        );
      },
    );
  }

  Widget _getIconForDiagnosticType(String type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'Traceroute':
        iconData = Icons.route;
        iconColor = Colors.orange;
        break;
      case 'Speed Test':
        iconData = Icons.speed;
        iconColor = Colors.blue;
        break;
      case 'Packet Loss':
        iconData = Icons.trending_down;
        iconColor = Colors.red;
        break;
      case 'Port Scan':
        iconData = Icons.filter_list;
        iconColor = Colors.purple;
        break;
      case 'Ping':
        iconData = Icons.network_ping;
        iconColor = Colors.green;
        break;
      default:
        iconData = Icons.language;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.2),
      child: Icon(iconData, color: iconColor),
    );
  }
}

// Model for diagnostic logs
class DiagnosticLog {
  final String type;
  final String target;
  final DateTime timestamp;
  final String summary;

  DiagnosticLog({
    required this.type,
    required this.target,
    required this.timestamp,
    required this.summary,
  });
}
