import Foundation
import HealthKit
import EventKit
import PMKCoreLocation
import PMKHealthKit
import PromiseKit
import Swizzle
import WatchKit
import WatchConnectivity

// MARK: - UIKit stubs

// watchOS 5
private extension NSObject {
  @objc class func sharedApplication() -> NSObject? { fatalError() }
  @objc func keyWindow() -> NSObject? { fatalError() }
  @objc func rootViewController() -> NSObject? { fatalError() }
  @objc func viewControllers() -> [NSObject]? { fatalError() }
  @objc func view() -> NSObject? { fatalError() }
  @objc func subviews() -> [NSObject]? { fatalError() }
  @objc func timeLabel() -> NSObject? { fatalError() }
  @objc func layer() -> NSObject? { fatalError() }
  @objc func setOpacity(_ opacity: CDouble) { fatalError() }
}

// watchOS 6 or later
private extension NSObject {
  @objc class func sharedPUICApplication() -> NSObject? { fatalError() }
  @objc func _setStatusBarTimeHidden(_ hidden: Bool, animated: Bool, completion: NSObject? = nil) { fatalError() }
}

// MARK: - CLKTimeFormatter

private typealias CLKTimeFormatter = NSObject

private extension CLKTimeFormatter {
  @objc func swizzled_timeText() -> NSString {
    return NSString(string: " ")
  }
}

// MARK: - TimeLabel

func getSPFullScreenView() -> NSObject? {
  let UIApplication = NSClassFromString("UIApplication") as? NSObject.Type

  if let views = UIApplication?.sharedApplication()?.keyWindow()?
    .rootViewController()?.viewControllers()?.first?.view()?.subviews() {
    for view in views {
      if type(of: view) == NSClassFromString("SPFullScreenView") {
        return view
      }
    }
  }

  return nil
}

func hideDefaultTimeLabelWatchOS5() {
  getSPFullScreenView()?.timeLabel()?.layer()?.setOpacity(0)
}

func hideDefaultTimeLabelWatchOS6() {
  try! swizzleInstanceMethodObjcString(
    of: "CLKTimeFormatter",
    from: "timeText",
    to: #selector(CLKTimeFormatter.swizzled_timeText)
  )
}

func hideDefaultTimeLabelWatchOS7() {
  let application = NSClassFromString("PUICApplication") as? NSObject.Type
  application?.sharedPUICApplication()?._setStatusBarTimeHidden(true, animated: false)
}

var hideTimeOnce: () -> Void = {
  if #available(watchOS 7, *) {
    hideDefaultTimeLabelWatchOS7()
  } else if #available(watchOS 6, *) {
    hideDefaultTimeLabelWatchOS6()
  } else {
    hideDefaultTimeLabelWatchOS5()
  }

  return {}
}()

// MARK: - Activity string

struct ActivityRingColors {
  static let excercise = UIColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1.0)
  static let move = UIColor(red: 0.016, green: 0.871, blue: 0.443, alpha: 1.0)
  static let stand = UIColor(red: 0.353, green: 0.784, blue: 0.98, alpha: 1.0)
}

struct BatteryStateColors {
  static let normal = UIColor(red: 0.569, green: 0.831, blue: 0.384, alpha: 1.0)
  static let low = UIColor.red
}

func colorAttributedString(string: String, color: UIColor)
  -> NSAttributedString {
  let colorAttribute = [NSAttributedString.Key.foregroundColor: color]

  return NSAttributedString(string: string, attributes: colorAttribute)
}

func activitySummaryAttributedString(
  _ activitySummary: HKActivitySummary,
  separator: String = "•"
) -> NSAttributedString {
  let excerciseValue = activitySummary.activeEnergyBurned.doubleValue(
    for: HKUnit.kilocalorie()
  )
  let excerciseAttributedString = colorAttributedString(
    string: "\(Int(excerciseValue))",
    color: ActivityRingColors.excercise
  )

  let moveValue = activitySummary.appleExerciseTime.doubleValue(
    for: HKUnit.minute()
  )
  let moveAttributedString = colorAttributedString(
    string: "\(Int(moveValue))",
    color: ActivityRingColors.move
  )

  let standValue = activitySummary.appleStandHours.doubleValue(
    for: HKUnit.count()
  )
  let standAttributedString = colorAttributedString(
    string: "\(Int(standValue))",
    color: ActivityRingColors.stand
  )

  let separatorString = NSAttributedString(string: separator)

  let attributedString = NSMutableAttributedString()
  attributedString.append(excerciseAttributedString)
  attributedString.append(separatorString)
  attributedString.append(moveAttributedString)
  attributedString.append(separatorString)
  attributedString.append(standAttributedString)

  return attributedString
}

// MARK: - Temperature styling

let localizedTemperatureStyle: (MeasurementFormatter) -> Void = {
  $0.locale = Locale(identifier: Locale.preferredLanguages.first!)
  $0.numberFormatter.maximumFractionDigits = 0
  $0.unitStyle = .short
}

// MARK: - Battery indicator

func progressBarString(percent: UInt, steps: UInt) -> String? {
  let fillCount = Int((Float(steps) * (Float(percent) / 100.0)).rounded())
  let full = String(repeating: "#", count: fillCount)
  let empty = String(repeating: ".", count: Int(steps) - fillCount)

  return "[\(full + empty)]"
}

func batteryIndicatorString(percent: UInt) -> String {
  let percentString = "\(percent)%"

  if let batteryIndicator = progressBarString(percent: percent, steps: 5) {
    return ("\(batteryIndicator) \(percentString)")
  }

  return percentString
}

class InterfaceController: WKInterfaceController {
  @IBOutlet weak var userHostLabelNow: WKInterfaceLabel!
  @IBOutlet var batteryLabel: WKInterfaceLabel!
  @IBOutlet weak var batteryGroup: WKInterfaceGroup!
  @IBOutlet var activityLabel: WKInterfaceLabel!
  @IBOutlet weak var activityGroup: WKInterfaceGroup!
  @IBOutlet var stepsLabel: WKInterfaceLabel!
  @IBOutlet weak var stepsGroup: WKInterfaceGroup!
  @IBOutlet var heartRateLabel: WKInterfaceLabel!
  @IBOutlet weak var heartRateGroup: WKInterfaceGroup!
  @IBOutlet var temperatureLabel: WKInterfaceLabel!
  @IBOutlet weak var temperatureGroup: WKInterfaceGroup!
  @IBOutlet var calendarLabel: WKInterfaceLabel!
  @IBOutlet weak var calendarGroup: WKInterfaceGroup!
  @IBOutlet weak var userHostLabel: WKInterfaceLabel!
  
  let session = WCSession.default

  override func awake(withContext context: Any?) {
    super.awake(withContext: context)
    
    session.delegate = self
    session.activate()

    // MARK: - Temperature

    firstly {
      CLLocationManager.requestAuthorization()
    }.done { _ in
      let temperatureFormatter = MeasurementFormatter()
      localizedTemperatureStyle(temperatureFormatter)

      NotificationCenter.default.addObserver(
        forName: TemperatureNotifier.TemperatureDidChangeNotification,
        object: nil,
        queue: nil
      ) { [weak self] notification in
        let temperature = notification.object as! Measurement<UnitTemperature>
        self?.temperatureLabel.setText(
          temperatureFormatter.string(from: temperature)
        )
      }

      TemperatureNotifier.shared.start()
    }.catch {
      print("Error:", $0)
    }
    
    // MARK: - Calendar
    
    let eventStore = EKEventStore()
    
    let ekStatus = EKEventStore.authorizationStatus(for: .event)
    switch ekStatus {
    case EKAuthorizationStatus.notDetermined:
      eventRequestAccess(eventStore: eventStore)
      self.calendarLabel.setText("notDetermined")
    case EKAuthorizationStatus.authorized:
      let calendar = Calendar.current
      self.calendarLabel.setText(fetchTopEvent(eventStore: eventStore, calendar: calendar))
    case EKAuthorizationStatus.restricted, EKAuthorizationStatus.denied:
      self.calendarLabel.setText("restricted")
    default:
      self.calendarLabel.setText("error")
    }
    
    // MARK: - Health

    let healthStore = HKHealthStore()
    let dummyHKDataType = HKObjectType.quantityType(forIdentifier: .stepCount)!

    firstly {
      healthStore.requestAuthorization(toShare: nil, read: [dummyHKDataType])
    }.done { _ in
      subscribeToActivitySummary(
        forSampleType: HKSampleType.quantityType(
          forIdentifier: .activeEnergyBurned
        )!, healthStore: healthStore
      ) { [weak self] in
        self?.activityLabel.setAttributedText(
          activitySummaryAttributedString($0)
        )
      }

      subscribeToActivitySummary(
        forSampleType: HKSampleType.quantityType(
          forIdentifier: .appleExerciseTime
        )!,
        healthStore: healthStore
      ) { [weak self] in
        self?.activityLabel.setAttributedText(
          activitySummaryAttributedString($0)
        )
      }

      subscribeToActivitySummary(
        forSampleType: HKCategoryType.categoryType(
          forIdentifier: .appleStandHour
        )!,
        healthStore: healthStore
      ) { [weak self] in
        self?.activityLabel.setAttributedText(
          activitySummaryAttributedString($0)
        )
      }

      subscribeToStatisticsForToday(
        forQuantityType: HKQuantityType.quantityType(
          forIdentifier: .stepCount
        )!,
        unit: HKUnit.count(),
        options: .cumulativeSum,
        healthStore: healthStore
      ) { [weak self] in

        self?.stepsLabel.setText("\(Int($0)) steps")
      }

      subscribeToQuantityType(
        forSampleType: HKSampleType.quantityType(
          forIdentifier: .heartRate
        )!,
        unit: HKUnit(from: "count/min"),
        healthStore: healthStore
      ) { [weak self] in
        self?.heartRateLabel.setText("\(Int($0)) BPM")
      }
    }.catch {
      print("Error:", $0)
    }

    // MARK: - Battery

    NotificationCenter.default.addObserver(
      forName: BatteryInfoNotifier.BatteryDidChangeNotification,
      object: nil,
      queue: nil
    ) { [weak self] notification in
      let batteryInfo = notification.object as! BatteryInfo

      guard batteryInfo.state != .unknown else {
        return
      }

      let batteryInfoAttributedString = colorAttributedString(
        string: batteryIndicatorString(percent: UInt(batteryInfo.level)),
        color: batteryInfo.level <= 20 ? BatteryStateColors.low
          : BatteryStateColors.normal
      )

      self?.batteryLabel.setAttributedText(batteryInfoAttributedString)
    }

    BatteryInfoNotifier.shared.start()
  }

  override func didAppear() {
    // Hack to make the digital time overlay disappear
    // from: https://github.com/steventroughtonsmith/SpriteKitWatchFace
    hideTimeOnce()
  }
}

extension InterfaceController: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    
  }

  func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
    let username = message["username"] as? String ?? "user"
    let hostname = message["hostname"] as? String ?? "watch"
    let showTemperature = message["temperature"] as? Bool ?? true
    let showBattery = message["battery"] as? Bool ?? true
    let showActivity = message["activity"] as? Bool ?? true
    let showSteps = message["steps"] as? Bool ?? true
    let showHeartRate = message["heart-rate"] as? Bool ?? true
    let showCalendar = message["calendar"] as? Bool ?? false
    
    self.userHostLabelNow.setText(username + "@" + hostname + ":~ $ now")
    self.userHostLabel.setText(username + "@" + hostname + ":~ $")
    self.temperatureGroup.setHidden(!showTemperature)
    self.batteryGroup.setHidden(!showBattery)
    self.activityGroup.setHidden(!showActivity)
    self.stepsGroup.setHidden(!showSteps)
    self.heartRateGroup.setHidden(!showHeartRate)
    self.calendarGroup.setHidden(!showCalendar)
  }
}
