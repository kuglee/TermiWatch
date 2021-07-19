import CoreLocation
import HealthKit
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
  @IBOutlet weak var warningLabel: UILabel!
  
  var session: WCSession?

  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.warningLabel.isHidden = true
    
    createWCSession()

    firstly {
      CLLocationManager.requestAuthorization()
    }.then { _ in
      HKHealthStore().requestAuthorization(toShare: nil, read: hkDataTypesOfInterest)
    }.catch {
      print("Error:", $0)
    }
  }
  
  func createWCSession() {
    if WCSession.isSupported() {
      session = WCSession.default
      session?.delegate = self
      session?.activate()
    }
  }
  
  @IBAction func updateConfigToWatch(_ sender: UIButton) {
    let username: String = self.usernameTextfield.text!
    let hostname: String = self.hostnameTextfield.text!
    if !isInputLengthValid(username: username, hostname: hostname) { return }
    
    let data = ["username": username,
                "hostname": hostname]
    
    if let validSession = self.session, validSession.isReachable {
      validSession.sendMessage(data, replyHandler: nil, errorHandler: nil)
    }
  }
  
  func isInputLengthValid(username: String, hostname: String) -> Bool {
    self.warningLabel.isHidden = true
    if (username.count > 4 || hostname.count > 5) {
      self.warningLabel.isHidden = false
      return false
    }

    return true
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
