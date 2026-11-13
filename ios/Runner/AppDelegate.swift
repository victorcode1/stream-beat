import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var backgroundTaskChannel: BackgroundTaskChannel?

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackgroundTaskChannel") {
      backgroundTaskChannel = BackgroundTaskChannel(messenger: registrar.messenger())
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
