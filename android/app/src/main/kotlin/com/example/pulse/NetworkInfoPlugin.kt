package com.example.pulse

import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.wifi.WifiManager
import android.net.wifi.WifiInfo
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.EventChannel.StreamHandler
import java.net.Inet4Address
import java.net.Inet6Address
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets

class NetworkInfoPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var tracerouteEventChannel: EventChannel
    private lateinit var wifiManager: WifiManager

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "network_info")
        channel.setMethodCallHandler(this)
        tracerouteEventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "traceroute_stream")
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        tracerouteEventChannel.setStreamHandler(null)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "getNetworkDetails" -> {
                try {
                    result.success(networkDetails())
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to read network details", e.toString())
                }
            }
            "getWifiDns" -> {
                try {
                    val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val activeNetwork: Network? = connectivityManager.activeNetwork
                    val linkProperties: LinkProperties? = connectivityManager.getLinkProperties(activeNetwork)

                    val dnsServers = linkProperties?.dnsServers?.map { it.hostAddress } ?: emptyList()
                    result.success(dnsServers)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get DNS servers", e.toString())
                }
            }
            "getWifiSignalStrength" -> {
                try {
                    val wifiInfo: WifiInfo = wifiManager.connectionInfo
                    val rssi = wifiInfo.rssi
                    val signalStrength = WifiManager.calculateSignalLevel(rssi, 5) // Returns 0-4
                    result.success(signalStrength)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get signal strength", e.toString())
                }
            }
            "traceroute" -> {
                try {
                    val host = call.arguments as String
                    val maxHops = 30
                    
                    tracerouteEventChannel.setStreamHandler(
                        object : StreamHandler {
                            private val handler = Handler(Looper.getMainLooper())
                            private var process: Process? = null
                            
                            override fun onListen(arguments: Any?, events: EventSink) {
                                Thread {
                                    try {
                                        // Get gateway info
                                        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                                        val linkProperties = connectivityManager.getLinkProperties(connectivityManager.activeNetwork)
                                        val gateway = linkProperties?.routes?.firstOrNull { it.isDefaultRoute }?.gateway?.hostAddress
                                        
                                        // Send gateway info if available
                                        gateway?.let {
                                            handler.post {
                                                events.success("Hop 1 (gateway): $it")
                                            }
                                            Thread.sleep(500)
                                        }

                                        // Traceroute logic
                                        var destinationReached = false
                                        for (ttl in 2..maxHops) {
                                            if (destinationReached) break
                                            
                                            process = Runtime.getRuntime().exec("ping -c 1 -t $ttl $host")
                                            val reader = process?.inputStream?.bufferedReader()
                                            var foundIp: String? = null

                                            reader?.use {
                                                it.forEachLine { line ->
                                                    // Parse response for intermediate hops
                                                    val ipRegex = Regex("From ([0-9.]+)")
                                                    ipRegex.find(line)?.let { match ->
                                                        foundIp = match.groupValues[1]
                                                    }
                                                }
                                            }

                                            process?.destroy()
                                            
                                            // Only send meaningful results
                                            foundIp?.let { ip ->
                                                handler.post {
                                                    events.success("Hop $ttl: $ip")
                                                    if (ip == host) {
                                                        events.success("Destination reached")
                                                        destinationReached = true
                                                    }
                                                }
                                                Thread.sleep(500)
                                            }
                                        }
                                        
                                        handler.post {
                                            events.endOfStream()
                                        }
                                    } catch (e: Exception) {
                                        handler.post {
                                            events.error("TRACEROUTE_ERROR", e.message, null)
                                        }
                                    } finally {
                                        process?.destroy()
                                    }
                                }.start()
                            }

                            override fun onCancel(arguments: Any?) {
                                process?.destroy()
                            }
                        }
                    )
                    
                    result.success(null)
                } catch (e: Exception) {
                    result.error("TRACEROUTE_INIT_ERROR", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("DEPRECATION")
    private fun networkDetails(): Map<String, Any?> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork
        val caps = cm.getNetworkCapabilities(network)
        val lp = cm.getLinkProperties(network)
        val out = HashMap<String, Any?>()
        out["interface"] = lp?.interfaceName
        val v6 = ArrayList<String>()
        lp?.linkAddresses?.forEach { la ->
            val a = la.address
            if (a is Inet4Address && out["ipv4"] == null) {
                out["ipv4"] = a.hostAddress
                out["prefix"] = la.prefixLength
            } else if (a is Inet6Address && !a.isLinkLocalAddress) {
                a.hostAddress?.substringBefore('%')?.let { v6.add(it) }
            }
        }
        out["ipv6"] = v6
        out["gateway"] = lp?.routes
            ?.firstOrNull { it.isDefaultRoute && it.gateway is Inet4Address }
            ?.gateway?.hostAddress
        out["dns"] = lp?.dnsServers?.mapNotNull { it.hostAddress } ?: emptyList<String>()
        out["vpn"] = cm.allNetworks.any {
            cm.getNetworkCapabilities(it)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true
        }
        if (caps?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true) {
            // WifiManager.connectionInfo still carries the SSID when location
            // permission is granted; NetworkCapabilities redacts it.
            val info = wifiManager.connectionInfo
            if (info != null) {
                out["ssid"] = info.ssid
                out["bssid"] = info.bssid?.takeIf { it != "02:00:00:00:00:00" }
                out["rssi"] = info.rssi
                out["linkSpeed"] = info.linkSpeed
                out["frequency"] = info.frequency
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    out["wifiStandard"] = info.wifiStandard
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    out["security"] = securityName(info.currentSecurityType)
                }
            }
        }
        return out
    }

    private fun securityName(type: Int): String? = when (type) {
        0 -> "OPEN"
        1 -> "WEP"
        2 -> "WPA2"
        3 -> "WPA2-EAP"
        4 -> "WPA3"
        5, 9 -> "WPA3-EAP"
        6 -> "OWE"
        7, 8 -> "WAPI"
        else -> null
    }
}
