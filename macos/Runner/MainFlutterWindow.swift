import Cocoa
import FlutterMacOS
import WebKit

class MainFlutterWindow: NSWindow {
  private var webCookiesChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    webCookiesChannel = makeWebCookiesChannel(
      messenger: flutterViewController.engine.binaryMessenger
    )

    self.title = "StreamBeat"

    // El diseno de escritorio ya no depende del ancho de la ventana: el shell
    // (sidebar de 232pt + contenido) se dibuja siempre en macOS, asi que el
    // limite para que no se rompa lo pone la ventana con un tamano minimo.
    self.contentMinSize = NSSize(width: 900, height: 600)
    if windowFrame.width < 900 || windowFrame.height < 600 {
      self.setContentSize(NSSize(width: max(windowFrame.width, 900),
                                 height: max(windowFrame.height, 600)))
    }

    super.awakeFromNib()
  }
}

/// Lee las cookies que dejo el inicio de sesion en la vista web, incluidas las
/// HttpOnly que JavaScript no ve. La vista web usa el almacen por defecto.
private func makeWebCookiesChannel(
  messenger: FlutterBinaryMessenger
) -> FlutterMethodChannel {
  let channel = FlutterMethodChannel(
    name: "streambeat/web_cookies",
    binaryMessenger: messenger
  )
  channel.setMethodCallHandler { call, result in
    guard call.method == "cookieHeader", let domain = call.arguments as? String
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
      let header = cookies
        .filter { cookie in
          let cookieDomain = cookie.domain.hasPrefix(".")
            ? String(cookie.domain.dropFirst()) : cookie.domain
          return cookieDomain == domain || cookieDomain.hasSuffix("." + domain)
        }
        .map { "\($0.name)=\($0.value)" }
        .joined(separator: "; ")
      result(header)
    }
  }
  return channel
}
