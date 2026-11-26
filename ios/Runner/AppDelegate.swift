import Flutter
import CoreMotion
import Foundation
import UIKit
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FLTFirebaseMessagingPlugin.configureNotificationCenterDelegate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CameraSettingsPlugin") {
      let channel = FlutterMethodChannel(name: "mosigame/camera_settings", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "open" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
          result(FlutterError(code: "settings_unavailable", message: nil, details: nil))
          return
        }
        UIApplication.shared.open(url, options: [:]) { opened in
          if opened { result(nil) }
          else { result(FlutterError(code: "settings_unavailable", message: nil, details: nil)) }
        }
      }
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YutMotionPlugin") {
      YutMotionPlugin.register(with: registrar)
    }
  }
}

final class YutMotionPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let motionManager = CMMotionManager()
  private var eventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = YutMotionPlugin()
    let channel = FlutterEventChannel(
      name: "mosigame/yut_motion/events",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(instance)
    registrar.publish(instance)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    guard motionManager.isAccelerometerAvailable else {
      return FlutterError(code: "motion_unavailable", message: "Accelerometer unavailable", details: nil)
    }
    eventSink = events
    motionManager.accelerometerUpdateInterval = 0.05
    motionManager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] data, error in
      guard let self = self, let acceleration = data?.acceleration, error == nil else { return }
      let scale = 9.80665
      self.eventSink?([
        acceleration.x * scale,
        acceleration.y * scale,
        acceleration.z * scale
      ])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    motionManager.stopAccelerometerUpdates()
    eventSink = nil
    return nil
  }
}
