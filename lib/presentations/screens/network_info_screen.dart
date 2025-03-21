import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class NetworkInfoScreen extends StatefulWidget {
  static const kRouteName = '/network-info';
  const NetworkInfoScreen({super.key});

  @override
  State<NetworkInfoScreen> createState() => _NetworkInfoScreenState();
}

class _NetworkInfoScreenState extends State<NetworkInfoScreen> {
  final NetworkInfo _networkInfo = NetworkInfo();

  // Network information
  String _connectionType = 'Unknown';
  String _wifiName = 'Unknown';
  String _wifiIP = 'Unknown';
  String _wifiGateway = 'Unknown';
  String _wifiSubnet = '255.255.255.0'; // Default value
  String _wifiDNS = 'Unknown';
  String _macAddress = 'Unknown';
  String _publicIP = 'Fetching...';
  String _signalStrength = 'Unknown';
  String _geolocation = 'Unknown';

  bool _isLoading = true;
  bool _hasLocationPermission = false;

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    if (!context.mounted) return;
    // Location permission is often needed for network info on newer Android versions
    if (Platform.isAndroid) {
      final status = await Permission.location.status;
      setState(() {
        _hasLocationPermission = status.isGranted;
      });
    } else {
      setState(() {
        _hasLocationPermission = true;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.location.request();
      setState(() {
        _hasLocationPermission = status.isGranted;
      });
      if (status.isGranted) {
        _loadNetworkInfo();
      }
    }
  }

  Future<void> _loadNetworkInfo() async {
    if (!context.mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // In a real app, you would use the network_info_plus package and other APIs
      // to get the actual network information from the device

      // For demo purposes, we'll use simulated data
      await Future.delayed(const Duration(seconds: 1));

      // Connection type detection
      _connectionType = await _getConnectionType();

      // WiFi info
      if (_connectionType == 'WiFi') {
        _wifiName = await _networkInfo.getWifiName() ?? 'Unknown';
        // Remove quotes that sometimes appear around SSID
        _wifiName = _wifiName.replaceAll('"', '');

        _wifiIP = await _networkInfo.getWifiIP() ?? '192.168.1.105';
        _wifiGateway =
            '192.168.1.1'; // In real app, this would come from platform-specific code
        _wifiSubnet = '255.255.255.0';
        _wifiDNS = '8.8.8.8, 8.8.4.4'; // Primary and secondary DNS
      } else if (_connectionType == 'Cellular') {
        _wifiIP = '10.123.45.67'; // Simulated cellular IP
      }

      // MAC address
      _macAddress = await _networkInfo.getWifiBSSID() ?? 'XX:XX:XX:XX:XX:XX';

      // Public IP (in a real app, this would use an API call)
      _publicIP = '203.0.113.42';

      // Signal strength (would use platform channels in a real app)
      _signalStrength = _getRandomSignalStrength();

      // Geolocation
      if (_hasLocationPermission) {
        await _getGeolocation();
      }
    } catch (e) {
      print('Error fetching network info: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _getConnectionType() async {
    // This would use Connectivity package in a real app
    // For demo, we'll randomly select a connection type
    final random = DateTime.now().millisecondsSinceEpoch % 3;
    switch (random) {
      case 0:
        return 'WiFi';
      case 1:
        return 'Cellular';
      default:
        return 'Ethernet';
    }
  }

  String _getRandomSignalStrength() {
    // Simulate signal strength for demo
    if (_connectionType == 'WiFi') {
      final strength = DateTime.now().millisecondsSinceEpoch % 5;
      switch (strength) {
        case 0:
          return 'Weak (-85 dBm)';
        case 1:
          return 'Fair (-75 dBm)';
        case 2:
          return 'Good (-65 dBm)';
        case 3:
          return 'Very Good (-55 dBm)';
        default:
          return 'Excellent (-45 dBm)';
      }
    } else if (_connectionType == 'Cellular') {
      final bars = (DateTime.now().millisecondsSinceEpoch % 5) + 1;
      return '$bars/5 bars';
    } else {
      return 'N/A';
    }
  }

  Future<void> _getGeolocation() async {
    try {
      // In a real app, this would use the geolocator package
      // For demo purposes, we'll use a simulated location
      _geolocation = 'New York, NY, USA';
    } catch (e) {
      _geolocation = 'Permission denied';
    }
  }

  Future<void> _copyToClipboard(String data, String label) async {
    await Clipboard.setData(ClipboardData(text: data));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
  }

  void _openNetworkSettings() {
    // In a real app, this would open system settings using platform channels
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening network settings...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Information'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNetworkInfo,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openNetworkSettings,
            tooltip: 'Network Settings',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadNetworkInfo,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildConnectionStatusCard(),
                      const SizedBox(height: 16),
                      _buildNetworkDetailsCard(),
                      const SizedBox(height: 16),
                      _buildAdvancedDetailsCard(),
                      if (!_hasLocationPermission) ...[
                        const SizedBox(height: 16),
                        _buildPermissionCard(),
                      ],
                      const SizedBox(height: 16),
                      _buildQuickActionsCard(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildConnectionStatusCard() {
    IconData connectionIcon;
    Color connectionColor;

    switch (_connectionType) {
      case 'WiFi':
        connectionIcon = Icons.wifi;
        connectionColor = Colors.blue;
        break;
      case 'Cellular':
        connectionIcon = Icons.signal_cellular_alt;
        connectionColor = Colors.green;
        break;
      case 'Ethernet':
        connectionIcon = Icons.settings_ethernet;
        connectionColor = Colors.orange;
        break;
      default:
        connectionIcon = Icons.signal_wifi_off;
        connectionColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(connectionIcon, size: 48, color: connectionColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _connectionType,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_connectionType == 'WiFi')
                        Text(_wifiName, style: const TextStyle(fontSize: 16)),
                      Text(
                        'Signal: $_signalStrength',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkDetailsCard() {
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
                const Text(
                  'Network Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed:
                      () => _copyToClipboard(
                        _getAllNetworkDetailsAsText(),
                        'All network details',
                      ),
                  tooltip: 'Copy all details',
                ),
              ],
            ),
            const Divider(),
            _buildDetailRow(
              'IP Address',
              _wifiIP,
              Icons.computer,
              onTap: () => _copyToClipboard(_wifiIP, 'IP Address'),
            ),
            _buildDetailRow(
              'Subnet Mask',
              _wifiSubnet,
              Icons.lens,
              onTap: () => _copyToClipboard(_wifiSubnet, 'Subnet Mask'),
            ),
            _buildDetailRow(
              'Gateway',
              _wifiGateway,
              Icons.router,
              onTap: () => _copyToClipboard(_wifiGateway, 'Gateway'),
            ),
            _buildDetailRow(
              'DNS',
              _wifiDNS,
              Icons.dns,
              onTap: () => _copyToClipboard(_wifiDNS, 'DNS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedDetailsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildDetailRow(
              'MAC Address',
              _macAddress,
              Icons.perm_device_information,
              onTap: () => _copyToClipboard(_macAddress, 'MAC Address'),
            ),
            _buildDetailRow(
              'Public IP',
              _publicIP,
              Icons.public,
              onTap: () => _copyToClipboard(_publicIP, 'Public IP'),
            ),
            if (_hasLocationPermission)
              _buildDetailRow(
                'Geolocation',
                _geolocation,
                Icons.location_on,
                onTap: () => _copyToClipboard(_geolocation, 'Geolocation'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      elevation: 2,
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  'Location Permission Required',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Some network details require location permission to access on this device.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _requestLocationPermission,
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                  icon: Icons.wifi,
                  label: 'Wi-Fi Settings',
                  onTap: _openNetworkSettings,
                ),
                _buildActionButton(
                  icon: Icons.speed,
                  label: 'Speed Test',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Speed test not implemented in demo'),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.vpn_key,
                  label: 'VPN Status',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('VPN status not implemented in demo'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(value, style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
              const Icon(Icons.content_copy, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, size: 28, color: Colors.blue),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getAllNetworkDetailsAsText() {
    return '''
Connection Type: $_connectionType
${_connectionType == 'WiFi' ? 'WiFi Name: $_wifiName' : ''}
IP Address: $_wifiIP
Subnet Mask: $_wifiSubnet
Gateway: $_wifiGateway
DNS Servers: $_wifiDNS
MAC Address: $_macAddress
Public IP: $_publicIP
Signal Strength: $_signalStrength
${_hasLocationPermission ? 'Geolocation: $_geolocation' : ''}
''';
  }
}
