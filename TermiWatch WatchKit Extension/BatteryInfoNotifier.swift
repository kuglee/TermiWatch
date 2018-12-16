import Foundation
import WatchKit

public struct BatteryInfo {
  var state: WKInterfaceDeviceBatteryState
  var level: Float
}

func batteryInfo(forDevice device: WKInterfaceDevice = .current())
  -> BatteryInfo {
  let originalMonitoringValue = device.isBatteryMonitoringEnabled

  defer {
    device.isBatteryMonitoringEnabled = originalMonitoringValue
  }

  device.isBatteryMonitoringEnabled = true

  return BatteryInfo(
    state: device.batteryState,
    level: device.batteryLevel * 100.0
  )
}

public class BatteryInfoNotifier {
  public static let BatteryDidChangeNotification = Notification.Name(
    rawValue: "BatteryInfoNotifier.BatteryInfoDidChangeNotification"
  )

  public static let shared = BatteryInfoNotifier()
  private init() {}

  public private(set) var info = BatteryInfo(state: .unknown, level: -1)
  private var timer: Timer?

  public static let device = WKInterfaceDevice.current()

  public var isStarted: Bool {
    return timer != nil && timer!.isValid
  }

  public func start(withTimeInterval interval: TimeInterval = 60) {
    timer?.invalidate()

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) {
      [weak self] _ in

      let currentInfo = batteryInfo(forDevice: BatteryInfoNotifier.device)

      guard currentInfo.state != self?.info.state,
        currentInfo.level != self?.info.level else {
        return
      }

      self?.info = currentInfo

      NotificationCenter.default.post(Notification(
        name: BatteryInfoNotifier.BatteryDidChangeNotification,
        object: self?.info,
        userInfo: nil
      ))
    }

    timer!.fire()
  }

  public func stop() {
    timer?.invalidate()
    timer = nil
  }
}
