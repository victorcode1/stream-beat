import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backgroundTaskChannel: BackgroundTaskChannel?
  private var webCookiesChannel: WebCookiesChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackgroundTaskChannel") {
      backgroundTaskChannel = BackgroundTaskChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "WebCookiesChannel") {
      webCookiesChannel = WebCookiesChannel(messenger: registrar.messenger())
    }
  }
}

/// Pide a iOS unos segundos extra en segundo plano mientras se pasa de una
/// cancion a la siguiente. Entre que termina una y suena la otra no hay audio,
/// y sin esta tarea iOS suspende la app antes de que la siguiente arranque.
final class BackgroundTaskChannel {
  private let channel: FlutterMethodChannel
  private var taskId: UIBackgroundTaskIdentifier = .invalid

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "streambeat/background_task",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "begin":
        self.begin()
        result(nil)
      case "end":
        self.end()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func begin() {
    end()
    taskId = UIApplication.shared.beginBackgroundTask(withName: "TrackTransition") {
      [weak self] in
      self?.end()
    }
  }

  private func end() {
    guard taskId != .invalid else { return }
    UIApplication.shared.endBackgroundTask(taskId)
    taskId = .invalid
  }
}

/// Lee las cookies que dejo el inicio de sesion en la vista web, incluidas las
/// HttpOnly que JavaScript no ve. La vista web usa el almacen por defecto.
final class WebCookiesChannel {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "streambeat/web_cookies",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "cookieHeader",
        let domain = call.arguments as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
        result(webCookieHeader(cookies, domain: domain))
      }
    }
  }
}

/// `nombre=valor; ...` de las cookies de [domain] y sus subdominios.
func webCookieHeader(_ cookies: [HTTPCookie], domain: String) -> String {
  cookies
    .filter { cookie in
      let cookieDomain = cookie.domain.hasPrefix(".")
        ? String(cookie.domain.dropFirst()) : cookie.domain
      return cookieDomain == domain || cookieDomain.hasSuffix("." + domain)
    }
    .map { "\($0.name)=\($0.value)" }
    .joined(separator: "; ")
}
