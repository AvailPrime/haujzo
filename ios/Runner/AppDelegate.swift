import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if DEBUG
    setenv("FIRAAppCheckDebugToken", "955ae9a9-10ef-467b-8c0f-970cc5331f88", 1)
    #endif
    GMSServices.provideAPIKey("AIzaSyCVSLhxgrwxBICeF_xY-4WCpFVGKjkkWaU")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
