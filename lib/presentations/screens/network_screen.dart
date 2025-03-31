import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:open_settings_plus/core/open_settings_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pulse/core/utils/get_dns.dart';
import 'package:pulse/presentations/widgets/app_bar_layout.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/get_wifi_strength.dart';

class NetworkScreen extends ConsumerStatefulWidget {
  static const kRouteName = '/network';
  const NetworkScreen({super.key});

  @override
  ConsumerState<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends ConsumerState<NetworkScreen> {
  final NetworkInfo _networkInfo = NetworkInfo();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final Connectivity _connectivity = Connectivity();

  // Network information
  String _connectionType = 'Unknown';
  String _wifiName = 'Unknown';
  String _wifiIP = 'Unknown';
  String _wifiGateway = 'Unknown';
  String _wifiSubnet = 'Unknown';
  List<String> _wifiDNS = ['Unknown'];
  String _macAddress = 'Unknown';
  String _publicIP = 'Fetching...';
  String _signalStrength = 'Unknown';
  String _geolocation = 'Unknown';
  bool _isVpnActive = false;

  bool _isLoading = true;
  bool _hasLocationPermission = false;
  bool _hasNetworkPermission = false;

  // For tracking connectivity changes
  // StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initConnectivityListener();
  }

  // @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();

  //   // Ensure this only runs once
  //   if (!_isInitialized) {
  //     Future.delayed(Duration(seconds: 1), () {
  //       ref.read(appBarActionsProvider.notifier).changeAppBarList([
  //         IconButton(
  //           icon: const Icon(Icons.refresh),
  //           onPressed: _loadNetworkInfo,
  //           tooltip: 'Refresh',
  //         ),
  //         IconButton(
  //           icon: const Icon(Icons.settings),
  //           onPressed: () => _openNetworkSettings(context),
  //           tooltip: 'Network Settings',
  //         ),
  //       ]);
  //     });
  //     _isInitialized = true;
  //   }
  // }

  @override
  void dispose() {
    super.dispose();
    _connectivitySubscription?.cancel();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((_) {
      // Reload network info whenever connectivity changes
      if (mounted) {
        _loadNetworkInfo();
      }
    });
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;

    // Check location permission
    if (Platform.isAndroid || Platform.isIOS) {
      final locationStatus = await Permission.location.status;
      setState(() {
        _hasLocationPermission = locationStatus.isGranted;
      });
    } else {
      // On desktop platforms, location permission is handled differently
      setState(() {
        _hasLocationPermission = true;
      });
    }

    // Check network permission (for Android 13+)
    if (Platform.isAndroid) {
      // For Android we need to check SDK version
      final androidInfo = await _deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final networkStatus = await Permission.nearbyWifiDevices.status;
        setState(() {
          _hasNetworkPermission = networkStatus.isGranted;
        });
      } else {
        setState(() {
          _hasNetworkPermission = true;
        });
      }
    } else {
      setState(() {
        _hasNetworkPermission = true;
      });
    }

    // Load network info if we have all needed permissions
    if (_hasLocationPermission && _hasNetworkPermission) {
      _loadNetworkInfo();
    }
  }

  Future<void> _requestLocationPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.location.request();
      setState(() {
        _hasLocationPermission = status.isGranted;
      });

      // Also request nearby WiFi devices permission on Android 13+
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        if (androidInfo.version.sdkInt >= 33) {
          final wifiStatus = await Permission.nearbyWifiDevices.request();
          setState(() {
            _hasNetworkPermission = wifiStatus.isGranted;
          });
        }
      }

      if (_hasLocationPermission && _hasNetworkPermission) {
        _loadNetworkInfo();
      }
    }
  }

  Future<void> _loadNetworkInfo() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Get connection type
      final connectivityResult = await _connectivity.checkConnectivity();
      _connectionType = _getConnectionTypeFromResult(connectivityResult[0]);

      // Get platform-specific network info
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await _loadDesktopNetworkInfo();
      } else {
        await _loadMobileNetworkInfo();
      }

      // These are cross-platform calls
      await _getPublicIP();
      await _checkVpnStatus();
      if (_hasLocationPermission) {
        await _getGeolocation();
      }
    } catch (e) {
      debugPrint('Error fetching network info: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getConnectionTypeFromResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Cellular';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        // Mark VPN as active, but actual connection type will be determined elsewhere
        _isVpnActive = true;
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.none:
        return 'Disconnected';
      default:
        return 'Unknown';
    }
  }

  Future<void> _loadMobileNetworkInfo() async {
    // WiFi info
    if (_connectionType == 'WiFi') {
      try {
        String? ssid = await _networkInfo.getWifiName();
        // Remove quotes that sometimes appear around SSID
        _wifiName = ssid != null ? ssid.replaceAll('"', '') : 'Unknown';
      } catch (e) {
        _wifiName = 'Permission denied';
      }

      try {
        _wifiIP = await _networkInfo.getWifiIP() ?? 'Unknown';
      } catch (e) {
        _wifiIP = 'Unknown';
      }

      try {
        // MAC address
        _macAddress = await _networkInfo.getWifiBSSID() ?? 'Unknown';
      } catch (e) {
        _macAddress = 'Permission denied';
      }

      // For gateway, subnet, and DNS, we need platform-specific implementations
      if (Platform.isAndroid) {
        await _getAndroidWifiDetails();
      } else if (Platform.isIOS) {
        await _getIOSWifiDetails();
      }
    } else if (_connectionType == 'Cellular') {
      // For cellular, we can only reliably get limited information
      try {
        _wifiIP = 'Cellular IP'; // Usually unavailable directly
        _wifiDNS = ['Carrier DNS']; // Usually unavailable directly
      } catch (e) {
        debugPrint('Error getting cellular info: $e');
      }
    }
  }

  Future<void> _getAndroidWifiDetails() async {
    try {
      _wifiGateway = await _networkInfo.getWifiGatewayIP() ?? 'Unknown';
      _wifiSubnet = await _networkInfo.getWifiSubmask() ?? 'Unknown';
      // _wifiDNS = [await _networkInfo.getWifiBroadcast() ?? 'Unknown'];
      final dnsServers = await getWifiDns();
      _wifiDNS = dnsServers;
      _signalStrength = await getWifiStrength();
    } catch (e) {
      // Fallback to sensible default values when platform channel fails
      _wifiGateway = 'Not available';
      _wifiSubnet = 'Not available';
      _wifiDNS = ['Not available'];
      _signalStrength = 'Not available';
    }
  }

  Future<void> _getIOSWifiDetails() async {
    try {
      const platform = MethodChannel('com/myapp/networkinfo');
      final Map<String, dynamic> wifiDetails =
          await platform.invokeMethod('getWifiDetails') ?? {};

      _wifiGateway = wifiDetails['gateway'] ?? 'Unknown';
      _wifiSubnet = wifiDetails['subnet'] ?? 'Unknown';
      _wifiDNS = [wifiDetails['dns'] ?? 'Unknown'];
      _signalStrength = wifiDetails['signalStrength'] ?? 'Unknown';
    } catch (e) {
      _wifiGateway = 'Not available';
      _wifiSubnet = 'Not available';
      _wifiDNS = ['Not available'];
      _signalStrength = 'Not available';
    }
  }

  Future<void> _loadDesktopNetworkInfo() async {
    try {
      // Fetch network information using the plugin
      final wifiName = await _networkInfo.getWifiName();
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiGateway = await _networkInfo.getWifiGatewayIP();
      final wifiSubnet = await _networkInfo.getWifiSubmask();
      final wifiDNS = await _networkInfo.getWifiBroadcast();
      final macAddress = await _networkInfo.getWifiBSSID();

      // Update your state variables
      _wifiName = wifiName ?? 'Unknown';
      _wifiIP = wifiIP ?? 'Unknown';
      _wifiGateway = wifiGateway ?? 'Unknown';
      _wifiSubnet = wifiSubnet ?? 'Unknown';
      _wifiDNS = [wifiDNS ?? 'Unknown'];
      _macAddress = macAddress ?? 'Unknown';
      _signalStrength =
          'Unknown'; // Signal strength is not supported by network_info_plus
    } catch (e) {
      debugPrint('Error fetching desktop network info: $e');

      // Fallback values
      _wifiName = 'Unknown';
      _wifiIP = '192.168.1.105';
      _wifiGateway = '192.168.1.1';
      _wifiSubnet = '255.255.255.0';
      _wifiDNS = ['8.8.8.8', '8.8.4.4'];
      _macAddress = 'XX:XX:XX:XX:XX:XX';
      _signalStrength = 'Unknown';
    }
  }

  Future<void> _getPublicIP() async {
    try {
      // Use a public API to get the public IP address
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _publicIP = data['ip'] ?? 'Unknown';
      } else {
        _publicIP = 'API Error';
      }
    } catch (e) {
      _publicIP = 'Request Failed';
      debugPrint('Error fetching public IP: $e');
    }
  }

  Future<void> _checkVpnStatus() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Use connectivity_plus to check VPN status on mobile
        final connectivityResult = await _connectivity.checkConnectivity();
        _isVpnActive = connectivityResult[0] == ConnectivityResult.vpn;
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // Use network_info_plus for desktop platforms
        final vpnIP =
            await _networkInfo
                .getWifiGatewayIP(); // Example: Check if VPN gateway is active

        // Simple heuristic to detect VPN (e.g., if the gateway IP is different from the default)
        _isVpnActive =
            vpnIP != null &&
            vpnIP != '192.168.1.1'; // Replace with your default gateway
      } else {
        // Unsupported platform
        _isVpnActive = false;
      }
    } catch (e) {
      _isVpnActive = false;
      debugPrint('Error checking VPN status: $e');
    }
  }

  Future<void> _getGeolocation() async {
    try {
      // Ensure _publicIP is not empty
      if (_publicIP.isEmpty) {
        _geolocation = 'Unknown (No IP)';
        return;
      }

      final token = dotenv.get('IP_INFO_TOKEN', fallback: null);

      // Fetch geolocation data from ipinfo.io API
      final response = await http
          .get(Uri.parse('https://ipinfo.io/$_publicIP?token=$token'))
          .timeout(const Duration(seconds: 5));

      // Check if the request was successful
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Extract location details from the response
        final city = data['city'] ?? 'Unknown';
        final region = data['region'] ?? '';
        final country = data['country'] ?? '';

        // Format the geolocation string
        _geolocation = '$city, $region, $country';
      } else {
        // Handle API errors
        _geolocation = 'API Error (${response.statusCode})';
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      // Handle network-related errors (e.g., no internet connection)
      _geolocation = 'Network Error';
      debugPrint('Network Error: $e');
    } on TimeoutException catch (e) {
      // Handle timeout errors
      _geolocation = 'Request Timeout';
      debugPrint('Timeout Error: $e');
    } catch (e) {
      // Handle all other errors
      _geolocation = 'Request Failed';
      debugPrint('Error fetching geolocation: $e');
    }
  }

  Future<void> _copyToClipboard(String data, String label) async {
    await Clipboard.setData(ClipboardData(text: data));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
  }

  // void _openNetworkSettings() {
  //   try {
  //     if (Platform.isAndroid) {
  //       const platform = MethodChannel('com/myapp/settings');
  //       platform.invokeMethod('openWifiSettings');
  //     } else if (Platform.isIOS) {
  //       const platform = MethodChannel('com/myapp/settings');
  //       platform.invokeMethod('openSettings');
  //     } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
  //       // Open desktop network settings
  //       if (Platform.isWindows) {
  //         Process.run('control.exe', ['ncpa.cpl']);
  //       } else if (Platform.isLinux) {
  //         Process.run('gnome-control-center', ['network']);
  //       } else if (Platform.isMacOS) {
  //         Process.run('open', [
  //           '/System/Library/PreferencePanes/Network.prefPane',
  //         ]);
  //       }
  //     }
  //   } catch (e) {
  //     debugPrint('Error opening network settings: $e');
  //     if (!mounted) return;

  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Could not open network settings')),
  //     );
  //   }
  // }

  void _openNetworkSettings(BuildContext context) async {
    Uri? settingsUri;

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        //   // Android: Open Wi-Fi settings
        //   settingsUri = Uri.parse('android.settings.WIFI_SETTINGS');
        // } else if (Platform.isIOS) {
        //   // iOS: Open Wi-Fi settings
        //   settingsUri = Uri.parse('App-Prefs:Wi-Fi');
        switch (OpenSettingsPlus.shared) {
          case OpenSettingsPlusAndroid settings:
            settings.wifi();
            return;
          case OpenSettingsPlusIOS settings:
            settings.wifi();
            return;
          default:
            throw Exception('Platform not supported');
        }
      } else if (Platform.isWindows) {
        // Windows: Network settings
        settingsUri = Uri.parse('ms-settings:network-wifi');
      } else if (Platform.isLinux) {
        // Linux: Typically uses gnome-control-center
        settingsUri = Uri.parse('settings://network');
      } else if (Platform.isMacOS) {
        // macOS: Network preferences
        settingsUri = Uri.parse(
          'x-apple.systempreferences:com.apple.preference.network',
        );
      }

      if (settingsUri != null) {
        if (await canLaunchUrl(settingsUri)) {
          await launchUrl(settingsUri);
        } else {
          _showErrorSnackBar(context, 'Could not open network settings');
        }
      } else {
        _showErrorSnackBar(context, 'Unsupported platform');
      }
    } catch (e) {
      print(e);
      _showErrorSnackBar(context, 'Error opening network settings');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _checkVpnConnection() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isVpnActive
              ? 'VPN is currently active'
              : 'No VPN connection detected',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
          onRefresh: _loadNetworkInfo,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBarLayout(
                  title: 'Network',
                  appBarActions: [
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadNetworkInfo,
                      tooltip: 'Refresh',
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () => _openNetworkSettings(context),
                      tooltip: 'Network Settings',
                    ),
                  ],
                ),
                SizedBox(height: 10),
                if (!_hasLocationPermission || !_hasNetworkPermission) ...[
                  _buildPermissionCard(),
                  SizedBox(height: 10),
                ],
                _buildConnectionStatusCard(),
                SizedBox(height: 10),
                _buildNetworkDetailsCard(),
                SizedBox(height: 10),
                _buildAdvancedDetailsCard(),
                SizedBox(height: 10),
                _buildQuickActionsCard(),
                SizedBox(height: 10),
              ],
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
      case 'VPN':
        connectionIcon = Icons.vpn_key;
        connectionColor = Colors.purple;
        break;
      case 'Disconnected':
        connectionIcon = Icons.signal_wifi_off;
        connectionColor = Colors.red;
        break;
      default:
        connectionIcon = Icons.question_mark;
        connectionColor = Colors.grey;
    }

    final kPrimaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
      ),
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
                    if (_isVpnActive && _connectionType != 'VPN')
                      Row(
                        children: [
                          Icon(Icons.vpn_key, size: 16, color: Colors.purple),
                          const SizedBox(width: 4),
                          const Text(
                            'VPN Active',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.purple,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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
    );
  }

  Widget _buildNetworkDetailsCard() {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
      ),
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
            _wifiDNS.join(','),
            Icons.dns,
            onTap: () => _copyToClipboard(_wifiDNS.join(','), 'DNS'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedDetailsCard() {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
      ),
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
          _buildDetailRow(
            'VPN Status',
            _isVpnActive ? 'Active' : 'Not Active',
            Icons.vpn_key,
            onTap:
                () => _copyToClipboard(
                  _isVpnActive ? 'Active' : 'Not Active',
                  'VPN Status',
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    List<Widget> permissionButtons = [];

    if (!_hasLocationPermission) {
      permissionButtons.add(
        ElevatedButton(
          onPressed: _requestLocationPermission,
          child: const Text('Grant Location Permission'),
        ),
      );
    }

    if (!_hasNetworkPermission && Platform.isAndroid) {
      if (permissionButtons.isNotEmpty) {
        permissionButtons.add(const SizedBox(height: 8));
      }
      permissionButtons.add(
        ElevatedButton(
          onPressed: () async {
            final status = await Permission.nearbyWifiDevices.request();
            setState(() {
              _hasNetworkPermission = status.isGranted;
            });
            if (_hasNetworkPermission && _hasLocationPermission) {
              _loadNetworkInfo();
            }
          },
          child: const Text('Grant Network Permission'),
        ),
      );
    }

    final kPrimaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning, color: Colors.amber),
              SizedBox(width: 8),
              Text(
                'Permissions Required',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Some network details require additional permissions to access on this device.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...permissionButtons,
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    final kPrimaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: kPrimaryColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(15),
      ),
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
                onTap: () => _openNetworkSettings(context),
              ),
              _buildActionButton(
                icon: Icons.vpn_key,
                label: 'VPN Status',
                onTap: _checkVpnConnection,
              ),
              _buildActionButton(
                icon: Icons.refresh,
                label: 'Refresh All',
                onTap: _loadNetworkInfo,
              ),
            ],
          ),
        ],
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
    return Expanded(
      child: InkWell(
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
VPN Status: ${_isVpnActive ? 'Active' : 'Not Active'}
${_hasLocationPermission ? 'Geolocation: $_geolocation' : ''}
''';
  }
}
