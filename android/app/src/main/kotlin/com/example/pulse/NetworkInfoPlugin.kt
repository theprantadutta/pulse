package com.example.pulse

import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.net.NetworkCapabilities
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.net.Inet4Address
import java.net.Inet6Address

class NetworkInfoPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var wifiManager: WifiManager

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "network_info")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
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
