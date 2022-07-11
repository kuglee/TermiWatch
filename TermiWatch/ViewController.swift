import CoreLocation
import HealthKit
import EventKit
import PMKCoreLocation
import PMKHealthKit
import PromiseKit
import UIKit
import WatchConnectivity

let hkDataTypesOfInterest = Set([
  HKObjectType.activitySummaryType(),
  HKCategoryType.categoryType(forIdentifier: .appleStandHour)!,
  HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
  HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
  HKObjectType.quantityType(forIdentifier: .heartRate)!,
  HKObjectType.quantityType(forIdentifier: .stepCount)!,
])

class ViewController: UIViewController {
  @IBOutlet weak var usernameTextfield: UITextField!
  @IBOutlet weak var hostnameTextfield: UITextField!
  @IBOutlet weak var temperatureSwitch: UISwitch!
  @IBOutlet weak var batterySwitch: UISwitch!
  @IBOutlet weak var activitySwitch: UISwitch!
  @IBOutlet weak var stepSwitch: UISwitch!
  @IBOutlet weak var hrSwitch: UISwitch!
  @IBOutlet weak var calendarSwitch: UISwitch!
  @IBOutlet weak var warningLabel: UILabel!
  
  var session: WCSession?

  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.warningLabel.isHidden = true
    
    createWCSession()
    
    setDefaultSwitchesStatus()
    
    let dismissalTap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
    view.addGestureRecognizer(dismissalTap)

    firstly {
      CLLocationManager.requestAuthorization()
    }.then { _ in
      HKHealthStore().requestAuthorization(toShare: nil, read: hkDataTypesOfInterest)
    }.catch {
      print("Error:", $0)
    }
    
    EKEventStore().requestAccess(to: .event) { granted, error in
      // Handle the response to the request.
    }
  }
  
  func createWCSession() {
    if WCSession.isSupported() {
      session = WCSession.default
      session?.delegate = self
      session?.activate()
    }
  }
  
  func setDefaultSwitchesStatus() {
    self.temperatureSwitch.setOn(true, animated: false)
    self.batterySwitch.setOn(true, animated: false)
    self.activitySwitch.setOn(true, animated: false)
    self.stepSwitch.setOn(true, animated: false)
    self.hrSwitch.setOn(true, animated: false)
    self.calendarSwitch.setOn(false, animated: false)
  }
  
  @IBAction func updateConfigToWatch(_ sender: UIButton) {
    let username: String = self.usernameTextfield.text!
    let hostname: String = self.hostnameTextfield.text!
    if !isInputLengthValid(username: username, hostname: hostname) { return }
    
    let data = ["username": username,
                "hostname": hostname,
                "temperature": self.temperatureSwitch.isOn,
                "battery": self.batterySwitch.isOn,
                "activity": self.activitySwitch.isOn,
                "steps": self.stepSwitch.isOn,
                "heart-rate": self.hrSwitch.isOn,
                "calendar": self.calendarSwitch.isOn] as [String : Any]
    
    if let validSession = self.session, validSession.isReachable {
      validSession.sendMessage(data, replyHandler: nil, errorHandler: nil)
    }
  }
  
  func isInputLengthValid(username: String, hostname: String) -> Bool {
    self.warningLabel.isHidden = true
    if (username.count + hostname.count > 9) {
      self.warningLabel.text = "Max total Characters for username and hostname: 9"
      self.warningLabel.isHidden = false
      return false
    }

    return true
  }
  
  @objc func dismissKeyboard() {
      // Causes the view (or one of its embedded text fields) to resign the first responder status.
      view.endEditing(true)
  }
}

extension ViewController: WCSessionDelegate {
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    
  }
  
  func sessionDidBecomeInactive(_ session: WCSession) {
    
  }
  
  func sessionDidDeactivate(_ session: WCSession) {
    
  }
}
