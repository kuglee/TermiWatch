import CoreLocation
import HealthKit
import PMKCoreLocation
import PMKHealthKit
import PromiseKit
import UIKit

let hkDataTypesOfInterest = Set([
  HKObjectType.activitySummaryType(),
  HKCategoryType.categoryType(forIdentifier: .appleStandHour)!,
  HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
  HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!,
  HKObjectType.quantityType(forIdentifier: .heartRate)!,
  HKObjectType.quantityType(forIdentifier: .stepCount)!,
])

class ViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()

    firstly {
      CLLocationManager.requestAuthorization()
    }.then { _ in
      HKHealthStore().requestAuthorization(toShare: nil, read: hkDataTypesOfInterest)
    }.catch {
      print("Error:", $0)
    }
  }
}
