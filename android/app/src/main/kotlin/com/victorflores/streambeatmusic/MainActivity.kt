package com.victorflores.streambeatmusic

import android.webkit.CookieManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lee las cookies que dejo el inicio de sesion en la vista web,
        // incluidas las HttpOnly que JavaScript no ve.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "streambeat/web_cookies",
        ).setMethodCallHandler { call, result ->
            val domain = call.arguments as? String
            if (call.method != "cookieHeader" || domain == null) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            result.success(CookieManager.getInstance().getCookie("https://$domain") ?: "")
        }
    }
}
