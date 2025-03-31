import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pulse/presentations/widgets/app_bar_layout.dart';
import 'package:share_plus/share_plus.dart';

// Fix for the extension method check
extension FutureExtension<T> on Future<T> {
  bool get isCompleted {
    bool completed = false;
    then((_) => completed = true).catchError((_) => completed = true);
    return completed;
  }
}

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

    final host = _hostController.text;

    setState(() {
      _activeTest = 'Traceroute';
      _isRunningTest = true;
      _testProgress = 0.0;
      _currentResults = [];
      _currentResults.add('Starting traceroute to $host...');
    });

    try {
      List<String> tracerouteResults = [];
      int totalHops = 0;
      bool success = false;

      if (Platform.isWindows) {
        tracerouteResults = await _executeWindowsTraceroute(host);
      } else if (Platform.isLinux || Platform.isMacOS) {
        tracerouteResults = await _executeUnixTraceroute(host);
      } else if (Platform.isAndroid) {
        await runNativeTraceroute(host);
      } else {
        throw Exception('Unsupported platform');
      }

      // Process and display results
      if (tracerouteResults.isNotEmpty) {
        totalHops = tracerouteResults.length;
        success = true;

        for (int i = 0; i < tracerouteResults.length; i++) {
          setState(() {
            _testProgress = (i + 1) / tracerouteResults.length;
            _currentResults.add(tracerouteResults[i]);
          });

          // Add a small delay to show progressive updates
          if (i < tracerouteResults.length - 1) {
            await Future.delayed(Duration(milliseconds: 100));
          }
        }
      } else {
        if (!Platform.isAndroid) {
          throw Exception('No traceroute results returned');
        }
      }

      setState(() {
        _testProgress = 1.0;
        _currentResults.add('Traceroute complete');

        // Add to log history
        _diagnosticLogs.insert(
          0,
          DiagnosticLog(
            type: 'Traceroute',
            target: host,
            timestamp: DateTime.now(),
            summary:
                '$totalHops hops, ${success ? "completed successfully" : "failed"}',
          ),
        );
        _isRunningTest = false;
      });
    } catch (e) {
      setState(() {
        _currentResults.add('Error: ${e.toString()}');
        _isRunningTest = false;
      });
    }
  }

  Future<List<String>> _executeWindowsTraceroute(String host) async {
    final result = await Process.run('tracert', ['-d', host]);

    if (result.exitCode != 0) {
      throw Exception('Traceroute failed: ${result.stderr}');
    }

    final output = result.stdout.toString();
    final lines = output.split('\n');
    final results = <String>[];

    // Skip header lines
    bool headerPassed = false;

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (!headerPassed) {
        if (trimmedLine.startsWith('1')) {
          headerPassed = true;
        } else {
          continue;
        }
      }

      // Parse the hop line
      if (trimmedLine.isNotEmpty && RegExp(r'^\s*\d+').hasMatch(trimmedLine)) {
        final hopMatch = RegExp(r'^\s*(\d+)').firstMatch(trimmedLine);
        final hopNumber = hopMatch?.group(1) ?? '';

        if (trimmedLine.contains('*')) {
          // Request timed out
          results.add('Hop $hopNumber: Request timed out');
        } else {
          // Extract IP and times
          final ipRegex = RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
          final ipMatch = ipRegex.firstMatch(trimmedLine);
          final ip = ipMatch?.group(1) ?? 'Unknown';

          // Extract response times
          final timeRegex = RegExp(r'(\d+)\s*ms');
          final allTimes =
              timeRegex
                  .allMatches(trimmedLine)
                  .map((m) => m.group(1))
                  .whereType<String>()
                  .toList();

          if (allTimes.isNotEmpty) {
            final avgTime =
                allTimes.map(int.parse).reduce((a, b) => a + b) /
                allTimes.length;
            results.add(
              'Hop $hopNumber: $ip - ${avgTime.toStringAsFixed(0)}ms',
            );
          } else {
            results.add('Hop $hopNumber: $ip');
          }
        }
      }
    }

    return results;
  }

  Future<List<String>> _executeUnixTraceroute(String host) async {
    final result = await Process.run('traceroute', ['-n', host]);

    if (result.exitCode != 0) {
      throw Exception('Traceroute failed: ${result.stderr}');
    }

    final output = result.stdout.toString();
    final lines = output.split('\n');
    final results = <String>[];

    // Skip header line
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Parse hop number
      final hopMatch = RegExp(r'^\s*(\d+)').firstMatch(line);
      if (hopMatch == null) continue;

      final hopNumber = hopMatch.group(1);

      if (line.contains('*')) {
        // Request timed out
        results.add('Hop $hopNumber: Request timed out');
      } else {
        // Extract IP
        final ipRegex = RegExp(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})');
        final ipMatch = ipRegex.firstMatch(line);
        final ip = ipMatch?.group(1) ?? 'Unknown';

        // Extract response times
        final timeRegex = RegExp(r'(\d+\.\d+)\s*ms');
        final allTimes =
            timeRegex
                .allMatches(line)
                .map((m) => m.group(1))
                .whereType<String>()
                .toList();

        if (allTimes.isNotEmpty) {
          final avgTime =
              allTimes.map(double.parse).reduce((a, b) => a + b) /
              allTimes.length;
          results.add('Hop $hopNumber: $ip - ${avgTime.toStringAsFixed(1)}ms');
        } else {
          results.add('Hop $hopNumber: $ip');
        }
      }
    }

    return results;
  }

  Future<void> runNativeTraceroute(
    String host, {
    Function(String)? onProgress, // Optional progress callback
  }) async {
    // final results = <String>[];

    try {
      // Start traceroute
      const channel = MethodChannel('network_info');
      await channel.invokeMethod('traceroute', host);

      // Listen to stream
      final eventChannel = EventChannel('traceroute_stream');
      final stream = eventChannel.receiveBroadcastStream().cast<String>();

      await for (final line in stream) {
        // results.add(line);
        setState(() {
          _currentResults.add(line);
        });
        // Update UI in real-time if callback provided
        onProgress?.call(line);

        // Optional: Add to debug log
        if (kDebugMode) print('Traceroute: $line');
      }
    } catch (e) {
      if (kDebugMode) print('Traceroute error: $e');

      // More graceful error handling
      if (e is PlatformException) {
        _currentResults.add('Error: ${e.message ?? 'Traceroute failed'}');
      } else {
        _currentResults.add('Error: ${e.toString()}');
      }

      // Still provide partial results if available
      if (_currentResults.isEmpty) {
        _currentResults.add('Could not complete traceroute');
      }
    }
  }

  Future<void> _runSpeedTest() async {
    setState(() {
      _activeTest = 'Speed Test';
      _isRunningTest = true;
      _testProgress = 0.0;
      _currentResults = [];
    });

    try {
      // Download test
      _currentResults.add('Testing download speed...');
      final downloadSpeed = await _measureDownloadSpeed();
      setState(() {
        _testProgress = 0.5;
        _currentResults.add(
          'Download speed: ${downloadSpeed.toStringAsFixed(2)} Mbps',
        );
      });

      // Upload test
      _currentResults.add('');
      _currentResults.add('Testing upload speed...');
      final uploadSpeed = await _measureUploadSpeed();

      setState(() {
        _testProgress = 1.0;
        _currentResults.add(
          'Upload speed: ${uploadSpeed.toStringAsFixed(2)} Mbps',
        );
        _isRunningTest = false;

        // Add to log history
        _diagnosticLogs.insert(
          0,
          DiagnosticLog(
            type: 'Speed Test',
            target: 'Speed Test Server',
            timestamp: DateTime.now(),
            summary:
                'Download: ${downloadSpeed.toStringAsFixed(1)} Mbps, Upload: ${uploadSpeed.toStringAsFixed(1)} Mbps',
          ),
        );
      });
    } catch (e) {
      setState(() {
        _currentResults.add('Error: ${e.toString()}');
        _isRunningTest = false;
      });
    }
  }

  // Measures actual download speed by downloading a test file
  Future<double> _measureDownloadSpeed() async {
    final testFileUrl =
        'https://speed.cloudflare.com/__down?bytes=10000000'; // 10MB test file from Cloudflare
    final client = HttpClient();
    final stopwatch = Stopwatch()..start();
    double totalBytes = 0;

    try {
      final request = await client.getUrl(Uri.parse(testFileUrl));
      final response = await request.close();

      // Update progress in real-time as data comes in
      await for (final chunk in response) {
        totalBytes += chunk.length;
        final elapsedSecs = stopwatch.elapsedMilliseconds / 1000;
        if (elapsedSecs > 0) {
          final currentSpeed = (totalBytes * 8 / 1000000) / elapsedSecs; // Mbps
          setState(() {
            _testProgress = 0.25; // Progressive update during download
            _currentResults[_currentResults.length - 1] =
                'Testing download speed... ${currentSpeed.toStringAsFixed(2)} Mbps';
          });
        }
      }

      // Calculate final speed
      final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
      final speedMbps =
          (totalBytes * 8 / 1000000) /
          elapsedSeconds; // Convert bytes to bits, then to Mbps

      return speedMbps;
    } finally {
      client.close();
      stopwatch.stop();
    }
  }

  // Measures actual upload speed by uploading random data
  Future<double> _measureUploadSpeed() async {
    final uploadUrl =
        'https://speed.cloudflare.com/__up'; // Cloudflare upload endpoint
    final client = HttpClient();
    final stopwatch = Stopwatch()..start();

    try {
      // Create a payload of random bytes (5MB)
      final random = Random();
      final payloadSize = 5 * 1024 * 1024; // 5MB
      final payload = Uint8List(payloadSize);
      for (int i = 0; i < payloadSize; i++) {
        payload[i] = random.nextInt(256);
      }

      // Set up request
      final request = await client.postUrl(Uri.parse(uploadUrl));
      request.headers.set('Content-Type', 'application/octet-stream');

      // Track progress
      int bytesSent = 0;
      final chunkSize = 256 * 1024; // 256KB chunks

      for (int offset = 0; offset < payload.length; offset += chunkSize) {
        final end =
            (offset + chunkSize > payload.length)
                ? payload.length
                : offset + chunkSize;
        final chunk = payload.sublist(offset, end);

        request.add(chunk);
        await request.flush(); // Force send

        bytesSent += chunk.length;
        final elapsedSecs = stopwatch.elapsedMilliseconds / 1000;
        if (elapsedSecs > 0) {
          final currentSpeed = (bytesSent * 8 / 1000000) / elapsedSecs; // Mbps
          setState(() {
            _testProgress =
                0.5 +
                (bytesSent / payloadSize) *
                    0.5; // Update progress (0.5-1.0 range)
            _currentResults[_currentResults.length - 1] =
                'Testing upload speed... ${currentSpeed.toStringAsFixed(2)} Mbps';
          });
        }
      }

      // Complete the request and get response
      final response = await request.close();
      await response.drain(); // Ensure we read the response

      // Calculate final speed
      final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000;
      final speedMbps = (payloadSize * 8 / 1000000) / elapsedSeconds;

      return speedMbps;
    } finally {
      client.close();
      stopwatch.stop();
    }
  }

  /// Runs a real packet loss test by sending actual ICMP ping requests
  /// Returns detailed results about packet loss statistics
  Future<Map<String, dynamic>> runPacketLossTest(
    String host, {
    int packetCount = 100,
    int timeoutMs = 1000,
    void Function(double progress, List<String> currentStatus)?
    onProgressUpdate,
  }) async {
    if (host.isEmpty) {
      throw ArgumentError('Host cannot be empty');
    }

    var results = <String>[];
    int sentPackets = 0;
    int receivedPackets = 0;
    int lostPackets = 0;
    List<int> responseTimes = [];

    results.add('Sending $packetCount packets to $host...');

    // Report initial status
    if (onProgressUpdate != null) {
      onProgressUpdate(0.0, List.from(results));
    }

    for (int i = 1; i <= packetCount; i++) {
      sentPackets++;
      bool received = false;
      int? responseTime;

      try {
        // Create a socket for ICMP (ping) requests
        final pingResult = await _sendPingRequest(host, timeoutMs);
        received = pingResult.received;
        responseTime = pingResult.responseTimeMs;

        if (received) {
          receivedPackets++;
          if (responseTime != null) {
            responseTimes.add(responseTime);
          }
        } else {
          lostPackets++;
        }
      } catch (e) {
        lostPackets++;
        // Socket or network error - count as packet loss
      }

      // Update status periodically
      if (i % 10 == 0 || i == packetCount) {
        final currentLossRate = (lostPackets / sentPackets * 100)
            .toStringAsFixed(1);

        results = [
          'Sending $packetCount packets to $host...',
          'Progress: $i/$packetCount packets',
          'Current packet loss: $currentLossRate%',
        ];

        if (responseTimes.isNotEmpty) {
          final avgResponseTime =
              responseTimes.reduce((a, b) => a + b) / responseTimes.length;
          results.add(
            'Avg response time: ${avgResponseTime.toStringAsFixed(1)}ms',
          );
        }

        // Report progress
        if (onProgressUpdate != null) {
          onProgressUpdate(i / packetCount, List.from(results));
        }
      }

      // Small delay between pings to avoid overwhelming the network
      if (i < packetCount) {
        await Future.delayed(Duration(milliseconds: 20));
      }
    }

    // Calculate final results
    final lossPercentage = (lostPackets / sentPackets * 100).toStringAsFixed(1);
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

    // Prepare final statistics
    double? avgResponseTime;
    double? minResponseTime;
    double? maxResponseTime;
    double? jitter;

    if (responseTimes.isNotEmpty) {
      avgResponseTime =
          responseTimes.reduce((a, b) => a + b) / responseTimes.length;
      minResponseTime =
          responseTimes.reduce((a, b) => a < b ? a : b).toDouble();
      maxResponseTime =
          responseTimes.reduce((a, b) => a > b ? a : b).toDouble();

      // Calculate jitter (standard deviation of response times)
      if (responseTimes.length > 1) {
        final variance =
            responseTimes
                .map((t) => math.pow(t - avgResponseTime!, 2))
                .reduce((a, b) => a + b) /
            responseTimes.length;
        jitter = math.sqrt(variance);
      }
    }

    // Complete result data
    final resultData = {
      'host': host,
      'timestamp': DateTime.now(),
      'packetsSent': sentPackets,
      'packetsReceived': receivedPackets,
      'packetsLost': lostPackets,
      'lossPercentage': double.parse(lossPercentage),
      'quality': quality,
      'avgResponseTime': avgResponseTime,
      'minResponseTime': minResponseTime,
      'maxResponseTime': maxResponseTime,
      'jitter': jitter,
      'summary': 'Loss rate: $lossPercentage%, Quality: $quality',
    };

    return resultData;
  }

  /// Sends a single ping request and waits for response
  Future<PingResult> _sendPingRequest(String host, int timeoutMs) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    bool received = false;
    int? responseTimeMs;

    try {
      // On most platforms, we can use ProcessRunner to execute the ping command
      final isWindows = Platform.isWindows;
      final pingArgs =
          isWindows
              ? ['-n', '1', '-w', timeoutMs.toString(), host]
              : ['-c', '1', '-W', (timeoutMs / 1000).toString(), host];

      final pingCommand = isWindows ? 'ping' : 'ping';
      final result = await Process.run(pingCommand, pingArgs);

      // Check the output to determine if the ping was successful
      final output = result.stdout.toString();
      if (isWindows) {
        received =
            output.contains('Reply from') || output.contains('bytes from');
      } else {
        received = output.contains('bytes from');
      }

      // Try to extract the response time
      if (received) {
        final regex = RegExp(r'time=(\d+\.?\d*)');
        final match = regex.firstMatch(output);
        if (match != null && match.groupCount >= 1) {
          responseTimeMs = double.parse(match.group(1)!).round();
        } else {
          // If we can't extract the time but got a response, estimate it from our stopwatch
          responseTimeMs = stopwatch.elapsedMilliseconds;
        }
      }
    } catch (e) {
      // Handle exceptions (command not found, network issues, etc.)
      received = false;
    } finally {
      stopwatch.stop();
    }

    return PingResult(received: received, responseTimeMs: responseTimeMs);
  }

  // Example of using the function in a Flutter context:
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

    try {
      final results = await runPacketLossTest(
        host,
        onProgressUpdate: (progress, currentStatus) {
          setState(() {
            _testProgress = progress;
            _currentResults = currentStatus;
          });
        },
      );

      setState(() {
        _isRunningTest = false;

        _currentResults.add('');
        _currentResults.add('Test complete!');
        _currentResults.add('Total packets sent: ${results['packetsSent']}');
        _currentResults.add('Packets received: ${results['packetsReceived']}');
        _currentResults.add('Packets lost: ${results['packetsLost']}');
        _currentResults.add('Packet loss rate: ${results['lossPercentage']}%');
        _currentResults.add('Connection quality: ${results['quality']}');

        if (results['avgResponseTime'] != null) {
          _currentResults.add(
            'Avg response time: ${results['avgResponseTime']!.toStringAsFixed(1)}ms',
          );
        }

        if (results['jitter'] != null) {
          _currentResults.add(
            'Jitter: ${results['jitter']!.toStringAsFixed(1)}ms',
          );
        }

        // Add to log history
        _diagnosticLogs.insert(
          0,
          DiagnosticLog(
            type: 'Packet Loss',
            target: host,
            timestamp: results['timestamp'],
            summary: results['summary'],
          ),
        );
      });
    } catch (e) {
      setState(() {
        _isRunningTest = false;
        _currentResults.add('Error: ${e.toString()}');
      });
    }
  }

  // Run port scanner
  // Future<void> _runPortScan() async {
  //   debugPrint('Starting port scan...');

  //   if (_hostController.text.isEmpty) {
  //     debugPrint('Host field is empty. Showing error snackbar.');
  //     _showErrorSnackBar('Please enter a host name or IP address');
  //     return;
  //   }

  //   // Parse port range
  //   List<int> ports = [];
  //   try {
  //     debugPrint('Parsing port range...');
  //     final rangeParts = _portRangeController.text.split('-');
  //     if (rangeParts.length == 1) {
  //       // Single port
  //       debugPrint('Single port detected: ${rangeParts[0]}');
  //       ports = [int.parse(rangeParts[0])];
  //     } else {
  //       // Port range
  //       debugPrint('Port range detected: ${rangeParts[0]}-${rangeParts[1]}');
  //       final startPort = int.parse(rangeParts[0]);
  //       final endPort = int.parse(rangeParts[1]);
  //       if (startPort > endPort || startPort < 1 || endPort > 65535) {
  //         debugPrint('Invalid port range: $startPort-$endPort');
  //         throw const FormatException('Invalid port range');
  //       }
  //       ports = List.generate(endPort - startPort + 1, (i) => startPort + i);
  //       debugPrint('Generated port list: $ports');
  //     }
  //   } catch (e) {
  //     debugPrint('Error parsing port range: $e');
  //     _showErrorSnackBar(
  //       'Invalid port range format. Use "start-end" or a single port number.',
  //     );
  //     return;
  //   }

  //   if (ports.length > 1000) {
  //     debugPrint('Port scan limit exceeded: ${ports.length} ports');
  //     _showErrorSnackBar('Please limit scan to 1000 ports maximum');
  //     return;
  //   }

  //   debugPrint('Setting up UI for port scan...');
  //   setState(() {
  //     _activeTest = 'Port Scan';
  //     _isRunningTest = true;
  //     _testProgress = 0.0;
  //     _currentResults = [];
  //   });

  //   final host = _hostController.text;
  //   final openPorts = <int>[];

  //   debugPrint('Starting scan on host: $host');
  //   _currentResults.add('Scanning ${ports.length} ports on $host...');
  //   setState(() {});

  //   // Set a reasonable timeout for connection attempts
  //   const timeout = Duration(milliseconds: 500);

  //   // Track scan progress
  //   int completedPorts = 0;

  //   // Limit concurrent connection attempts to avoid overwhelming the device
  //   final maxConcurrent = 20;
  //   final queue = <int>[...ports];
  //   final active = <Future<void>>[];

  //   debugPrint('Starting port scan with max concurrency: $maxConcurrent');
  //   while (queue.isNotEmpty || active.isNotEmpty) {
  //     // Start new scans up to the concurrent limit
  //     while (queue.isNotEmpty && active.length < maxConcurrent) {
  //       final port = queue.removeAt(0);
  //       debugPrint('Scanning port: $port');
  //       active.add(
  //         _scanPort(host, port, timeout).then((isOpen) {
  //           completedPorts++;
  //           debugPrint('Port $port scan completed. Open: $isOpen');

  //           if (isOpen) {
  //             openPorts.add(port);
  //             setState(() {
  //               _currentResults.add('Port $port: OPEN');
  //             });
  //           }

  //           // Update progress
  //           setState(() {
  //             _testProgress = completedPorts / ports.length;
  //           });
  //         }),
  //       );
  //     }

  //     // Wait for at least one scan to complete before continuing
  //     if (active.isNotEmpty) {
  //       debugPrint('Waiting for active scans to complete...');
  //       await Future.any(active);
  //       active.removeWhere((future) => future.isCompleted);
  //     }
  //   }

  //   debugPrint('Port scan completed. Updating UI...');
  //   setState(() {
  //     _isRunningTest = false;

  //     _currentResults.add('');
  //     _currentResults.add('Scan complete!');
  //     _currentResults.add('Total ports scanned: ${ports.length}');
  //     _currentResults.add('Open ports found: ${openPorts.length}');

  //     if (openPorts.isNotEmpty) {
  //       _currentResults.add('');
  //       _currentResults.add('Open ports:');
  //       openPorts.sort();
  //       for (final port in openPorts) {
  //         final service = _getCommonPortService(port);
  //         _currentResults.add('$port: $service');
  //       }
  //     }

  //     // Add to log history
  //     _diagnosticLogs.insert(
  //       0,
  //       DiagnosticLog(
  //         type: 'Port Scan',
  //         target: host,
  //         timestamp: DateTime.now(),
  //         summary:
  //             'Found ${openPorts.length} open ports out of ${ports.length} scanned',
  //       ),
  //     );
  //   });

  //   debugPrint('Port scan process finished.');
  // }

  // // Function to scan a single port
  // Future<bool> _scanPort(String host, int port, Duration timeout) async {
  //   debugPrint('Attempting to connect to $host:$port...');
  //   try {
  //     // Attempt to establish a socket connection
  //     final socket = await Socket.connect(host, port, timeout: timeout);

  //     // Connection successful, port is open
  //     debugPrint('Connection to $host:$port succeeded. Port is open.');
  //     await socket.close();
  //     return true;
  //   } catch (e) {
  //     // Connection failed, port is likely closed or filtered
  //     debugPrint(
  //       'Connection to $host:$port failed. Port is closed or filtered. Error: $e',
  //     );
  //     return false;
  //   }
  // }

  Future<void> _runPortScan() async {
    debugPrint('Starting port scan...');

    // Add a global timeout for the entire port scan operation
    const globalTimeout = Duration(seconds: 30); // Adjust as needed
    final globalTimeoutTimer = Timer(globalTimeout, () {
      debugPrint('Port scan timed out after $globalTimeout');
      setState(() {
        _isRunningTest = false;
        _currentResults.add('Port scan timed out after $globalTimeout');
      });
    });

    try {
      if (_hostController.text.isEmpty) {
        debugPrint('Host field is empty. Showing error snackbar.');
        _showErrorSnackBar('Please enter a host name or IP address');
        return;
      }

      // Parse port range
      List<int> ports = [];
      try {
        debugPrint('Parsing port range...');
        final rangeParts = _portRangeController.text.split('-');
        if (rangeParts.length == 1) {
          // Single port
          debugPrint('Single port detected: ${rangeParts[0]}');
          ports = [int.parse(rangeParts[0])];
        } else {
          // Port range
          debugPrint('Port range detected: ${rangeParts[0]}-${rangeParts[1]}');
          final startPort = int.parse(rangeParts[0]);
          final endPort = int.parse(rangeParts[1]);
          if (startPort > endPort || startPort < 1 || endPort > 65535) {
            debugPrint('Invalid port range: $startPort-$endPort');
            throw const FormatException('Invalid port range');
          }
          ports = List.generate(endPort - startPort + 1, (i) => startPort + i);
          debugPrint('Generated port list: $ports');
        }
      } catch (e) {
        debugPrint('Error parsing port range: $e');
        _showErrorSnackBar(
          'Invalid port range format. Use "start-end" or a single port number.',
        );
        return;
      }

      if (ports.length > 1000) {
        debugPrint('Port scan limit exceeded: ${ports.length} ports');
        _showErrorSnackBar('Please limit scan to 1000 ports maximum');
        return;
      }

      debugPrint('Setting up UI for port scan...');
      setState(() {
        _activeTest = 'Port Scan';
        _isRunningTest = true;
        _testProgress = 0.0;
        _currentResults = [];
      });

      final host = _hostController.text;
      final openPorts = <int>[];

      debugPrint('Starting scan on host: $host');
      _currentResults.add('Scanning ${ports.length} ports on $host...');
      setState(() {});

      // Set a reasonable timeout for connection attempts
      const timeout = Duration(milliseconds: 500);

      // Track scan progress
      int completedPorts = 0;

      // Limit concurrent connection attempts to avoid overwhelming the device
      final maxConcurrent = 20;
      final queue = <int>[...ports];

      debugPrint('Starting port scan with max concurrency: $maxConcurrent');
      while (queue.isNotEmpty) {
        // Create a batch of futures to process concurrently
        final batch = <Future<void>>[];

        // Fill the batch up to max concurrent limit
        while (queue.isNotEmpty && batch.length < maxConcurrent) {
          final port = queue.removeAt(0);
          debugPrint('Scanning port: $port');
          batch.add(
            _scanPort(host, port, timeout)
                .then((isOpen) {
                  completedPorts++;
                  debugPrint('Port $port scan completed. Open: $isOpen');

                  if (isOpen) {
                    openPorts.add(port);
                    setState(() {
                      _currentResults.add('Port $port: OPEN');
                    });
                  }

                  // Update progress
                  setState(() {
                    _testProgress = completedPorts / ports.length;
                  });
                })
                .timeout(
                  timeout,
                  onTimeout: () {
                    debugPrint('Port $port scan timed out.');
                    completedPorts++;
                    return;
                  },
                )
                .catchError((e) {
                  debugPrint('Error scanning port $port: $e');
                  completedPorts++;
                }),
          );
        }

        // Wait for all futures in the current batch to complete
        if (batch.isNotEmpty) {
          debugPrint(
            'Waiting for batch of ${batch.length} scans to complete...',
          );
          await Future.wait(batch);
        }
      }

      debugPrint('Port scan completed. Updating UI...');
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
    } finally {
      // Cancel the global timeout timer
      globalTimeoutTimer.cancel();
      debugPrint('Port scan process finished.');
    }
  }

  // Function to scan a single port
  Future<bool> _scanPort(String host, int port, Duration timeout) async {
    debugPrint('Attempting to connect to $host:$port...');
    try {
      // Attempt to establish a socket connection with a timeout
      final socket = await Socket.connect(host, port, timeout: timeout).timeout(
        timeout,
        onTimeout: () {
          debugPrint('Connection to $host:$port timed out.');
          throw TimeoutException('Connection timed out');
        },
      );

      // Connection successful, port is open
      debugPrint('Connection to $host:$port succeeded. Port is open.');
      await socket.close();
      return true;
    } catch (e) {
      // Connection failed, port is likely closed or filtered
      debugPrint(
        'Connection to $host:$port failed. Port is closed or filtered. Error: $e',
      );
      return false;
    }
  }

  // Utility for port scan to show common services
  String _getCommonPortService(int port) {
    debugPrint('Looking up service for port: $port');
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
      8443: 'HTTPS-Alt',
      1433: 'MS SQL',
      27017: 'MongoDB',
      6379: 'Redis',
      5672: 'AMQP',
      9092: 'Kafka',
      2181: 'ZooKeeper',
      9200: 'Elasticsearch',
      5601: 'Kibana',
    };

    return commonPorts[port] ?? 'Unknown service';
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
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppBarLayout(
            title: 'Diagnostics',
            appBarActions: [
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
          // Input area
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _hostController,
                decoration: InputDecoration(
                  labelText: 'Host / IP Address',
                  hintText: 'e.g., google.com or 192.168.1.1',
                  // Default border
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), // Rounded corners
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
                enabled: !_isRunningTest,
              ),
              const SizedBox(height: 16),
              if (_activeTest == 'Port Scan' || _activeTest == '')
                TextField(
                  controller: _portRangeController,
                  decoration: InputDecoration(
                    labelText: 'Port Range (for Port Scan)',
                    hintText: 'e.g., 1-1000 or 80',
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
                  enabled: !_isRunningTest,
                ),
            ],
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
              : _buildDiagnosticTools(kPrimaryColor),

          const SizedBox(height: 16),

          // Results area
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    tabs: [Tab(text: 'Current Results'), Tab(text: 'History')],
                    labelColor: kPrimaryColor,
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
    );
  }

  Widget _buildDiagnosticTools(Color kPrimaryColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use 600px as breakpoint between mobile and desktop
        final bool isDesktop = constraints.maxWidth > 600;

        if (isDesktop) {
          // Single row layout for desktop
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDiagnosticButton(
                iconData: Icons.route,
                title: 'Traceroute',
                color: kPrimaryColor,
                onPressed: _runTraceroute,
              ),
              _buildDiagnosticButton(
                iconData: Icons.speed,
                title: 'Speed Test',
                color: kPrimaryColor,
                onPressed: _runSpeedTest,
              ),
              _buildDiagnosticButton(
                iconData: Icons.trending_down,
                title: 'Packet Loss',
                color: kPrimaryColor,
                onPressed: _runPacketLossTest,
              ),
              _buildDiagnosticButton(
                iconData: Icons.filter_list,
                title: 'Port Scan',
                color: kPrimaryColor,
                onPressed: _runPortScan,
              ),
            ],
          );
        } else {
          // Two-row layout for mobile
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDiagnosticButton(
                    iconData: Icons.route,
                    title: 'Traceroute',
                    color: kPrimaryColor,
                    onPressed: _runTraceroute,
                  ),
                  _buildDiagnosticButton(
                    iconData: Icons.speed,
                    title: 'Speed Test',
                    color: kPrimaryColor,
                    onPressed: _runSpeedTest,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDiagnosticButton(
                    iconData: Icons.trending_down,
                    title: 'Packet Loss',
                    color: kPrimaryColor,
                    onPressed: _runPacketLossTest,
                  ),
                  _buildDiagnosticButton(
                    iconData: Icons.filter_list,
                    title: 'Port Scan',
                    color: kPrimaryColor,
                    onPressed: _runPortScan,
                  ),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildDiagnosticButton({
    required String title,
    required IconData iconData,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          margin: EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 5,
              children: [
                Icon(iconData, color: color),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                  overflow: TextOverflow.ellipsis,
                ),
                Expanded(
                  child: IconButton(
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
      backgroundColor: iconColor.withValues(alpha: 0.2),
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

// Class to hold probe result data
class ProbeResult {
  final String? ipAddress;
  final int? responseTime;

  ProbeResult({this.ipAddress, this.responseTime});
}

class PingResult {
  final bool received;
  final int? responseTimeMs;

  PingResult({required this.received, this.responseTimeMs});
}
