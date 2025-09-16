import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let backgroundChannel = FlutterMethodChannel(name: "com.parachute.audio/background",
                                                  binaryMessenger: controller.binaryMessenger)

    backgroundChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "startBackgroundTask":
        self?.beginBackgroundTask()
        result(nil)
      case "endBackgroundTask":
        self?.endBackgroundTask()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)

    // Configure audio session for background recording with long-form content
    do {
      let audioSession = AVAudioSession.sharedInstance()
      // Use .playAndRecord category for recording with playback capability
      try audioSession.setCategory(.playAndRecord,
                                   mode: .default,
                                   options: [.defaultToSpeaker,
                                           .allowBluetooth,
                                           .mixWithOthers])
      try audioSession.setActive(true)

      // Request maximum recording duration
      try audioSession.setPreferredIOBufferDuration(0.005)
    } catch {
      print("Failed to set up audio session: \(error)")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Background task management for long recordings
  func beginBackgroundTask() {
    backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
      self?.endBackgroundTask()
    }
  }

  func endBackgroundTask() {
    if backgroundTask != .invalid {
      UIApplication.shared.endBackgroundTask(backgroundTask)
      backgroundTask = .invalid
    }
  }

  override func applicationDidEnterBackground(_ application: UIApplication) {
    super.applicationDidEnterBackground(application)
    // Begin background task to keep app alive during recording
    beginBackgroundTask()
  }

  override func applicationWillEnterForeground(_ application: UIApplication) {
    super.applicationWillEnterForeground(application)
    // End background task when returning to foreground
    endBackgroundTask()
  }
}
