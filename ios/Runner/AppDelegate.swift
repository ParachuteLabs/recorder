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

    // Set up notification observers for audio interruptions
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioSessionInterruption),
      name: AVAudioSession.interruptionNotification,
      object: nil
    )

    // Set up notification observers for route changes
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleAudioSessionRouteChange),
      name: AVAudioSession.routeChangeNotification,
      object: nil
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  @objc private func handleAudioSessionInterruption(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSession.interruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
      return
    }

    switch type {
    case .began:
      // Recording was interrupted (e.g., phone call)
      print("Audio session interrupted")
    case .ended:
      // Interruption ended, resume recording if needed
      if let optionsValue = userInfo[AVAudioSession.interruptionOptionKey] as? UInt {
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        if options.contains(.shouldResume) {
          do {
            try AVAudioSession.sharedInstance().setActive(true)
            print("Audio session resumed")
          } catch {
            print("Failed to resume audio session: \(error)")
          }
        }
      }
    @unknown default:
      break
    }
  }

  @objc private func handleAudioSessionRouteChange(notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reasonValue = userInfo[AVAudioSession.routeChangeReasonKey] as? UInt,
          let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
      return
    }

    // Handle route changes (e.g., headphones disconnected)
    switch reason {
    case .oldDeviceUnavailable:
      // Resume recording with new route
      do {
        try AVAudioSession.sharedInstance().setActive(true)
      } catch {
        print("Failed to handle route change: \(error)")
      }
    default:
      break
    }
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
