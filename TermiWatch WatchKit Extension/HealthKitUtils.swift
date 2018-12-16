import Foundation
import HealthKit
import PMKHealthKit
import PromiseKit

func fetchSample(
  forSampleType sampleType: HKSampleType,
  healthStore: HKHealthStore = .init()
) -> Promise<HKSample?> {
  return Promise { seal in
    let predicate = HKQuery.predicateForSamples(
      withStart: .distantPast,
      end: Date(),
      options: .strictEndDate
    )

    let sortDescriptors: [NSSortDescriptor]? = [NSSortDescriptor(
      key: HKSampleSortIdentifierStartDate,
      ascending: false
    )]

    firstly {
      HKSampleQuery.promise(
        sampleType: sampleType,
        predicate: predicate,
        limit: 1,
        sortDescriptors: sortDescriptors,
        healthStore: healthStore
      )
    }.done {
      seal.fulfill($0.first)
    }.catch {
      print("Error:", $0)
    }
  }
}

func subscribeToSample(
  forSampleType sampleType:
  HKSampleType, unit: HKUnit?,
  healthStore: HKHealthStore = .init(),
  completion: @escaping (_ sample: HKSample?) -> Void
) {
  let query = HKObserverQuery(sampleType: sampleType, predicate: nil) {
    _, _, error in
    guard error == nil else {
      print("Error:", error!)

      return
    }

    firstly {
      fetchSample(forSampleType: sampleType, healthStore: healthStore)
    }.done {
      completion($0)
    }.catch {
      print("Error:", $0)
    }
  }

  healthStore.execute(query)
}

func subscribeToQuantityType(
  forSampleType sampleType: HKQuantityType,
  unit: HKUnit,
  healthStore: HKHealthStore = .init(),
  completion: @escaping (Double) -> Void
) {
  subscribeToSample(
    forSampleType: sampleType,
    unit: unit,
    healthStore: healthStore
  ) {
    let value = ($0 as? HKQuantitySample)?.quantity.doubleValue(for: unit) ?? 0

    completion(value)
  }
}

func subscribeToCategoryType(
  forSampleType sampleType: HKCategoryType,
  healthStore: HKHealthStore = .init(),
  completion: @escaping (Int) -> Void
) {
  subscribeToSample(
    forSampleType: sampleType,
    unit: nil,
    healthStore: healthStore
  ) {
    let value = ($0 as? HKCategorySample)?.value ?? 0

    completion(value)
  }
}

func fetchStatistics(
  forQuantityType quantityType: HKQuantityType,
  options: HKStatisticsOptions,
  startDate: Date,
  endDate: Date,
  interval: DateComponents,
  healthStore: HKHealthStore = .init()
) -> Promise<HKStatistics> {
  return Promise { seal in
    let query = HKStatisticsCollectionQuery(
      quantityType: quantityType,
      quantitySamplePredicate: nil,
      options: options,
      anchorDate: startDate,
      intervalComponents: interval
    )

    firstly {
      query.promise(healthStore: healthStore)
    }.done {
      $0.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
        seal.fulfill(statistics)
      }
    }.catch {
      print("Error:", $0)
    }
  }
}

func subscribeToStatisticsForToday(
  forQuantityType quantityType:
  HKQuantityType,
  unit: HKUnit,
  options: HKStatisticsOptions,
  healthStore: HKHealthStore = .init(),
  completion: @escaping (Double) -> Void
) {
  let query = HKObserverQuery(
    sampleType: quantityType,
    predicate: nil
  ) { _, _, error in
    guard error == nil else {
      print(error!)

      return
    }

    firstly {
      fetchStatistics(
        forQuantityType: quantityType,
        options: options,
        startDate: Calendar.current.startOfDay(for: Date()),
        endDate: Date(),
        interval: DateComponents(day: 1),
        healthStore: healthStore
      )
    }.done {
      let value = $0.sumQuantity()?.doubleValue(for: unit) ?? 0

      completion(value)
    }.catch {
      print("Error:", $0)
    }
  }

  healthStore.execute(query)
}

extension DateComponents {
  init(
    calendar: Calendar = .autoupdatingCurrent,
    components: Set<Calendar.Component>,
    date: Date
  ) {
    self = calendar.dateComponents(components, from: date)
    self.calendar = calendar
  }
}

func fetchActivitySummary(healthStore: HKHealthStore = .init())
  -> Promise<HKActivitySummary?> {
  return Promise { seal in
    let query = HKQuery.predicateForActivitySummary(
      with: DateComponents(components: [.year, .month, .day], date: Date())
    )

    firstly {
      HKActivitySummaryQuery.promise(predicate: query, healthStore: healthStore)
    }.done {
      seal.fulfill($0.first)
    }.catch {
      print("Error:", $0)
    }
  }
}

func subscribeToActivitySummary(
  forSampleType sampleType: HKSampleType,
  healthStore: HKHealthStore,
  completion: @escaping (_ summary: HKActivitySummary) -> Void
) {
  let query = HKObserverQuery(
    sampleType: sampleType,
    predicate: nil
  ) { _, _, error in
    guard error == nil else {
      print(error!)

      return
    }

    firstly {
      fetchActivitySummary(healthStore: healthStore)
    }.done {
      let value = $0 ?? HKActivitySummary()

      completion(value)
    }.catch {
      print("Error:", $0)
    }
  }

  healthStore.execute(query)
}
