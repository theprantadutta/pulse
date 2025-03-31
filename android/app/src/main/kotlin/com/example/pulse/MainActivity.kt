package com.example.pulse

import io.flutter.embedding.android.FlutterActivity
import com.example.pulse.NetworkInfoPlugin
import io.flutter.embedding.engine.FlutterEngine
import androidx.annotation.NonNull

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(NetworkInfoPlugin())
    }
}
