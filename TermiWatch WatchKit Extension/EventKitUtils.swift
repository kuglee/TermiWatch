import Foundation
import EventKit
import PromiseKit

func eventRequestAccess(eventStore: EKEventStore) {
  eventStore.requestAccess(to: .event) { granted, error in
    // Handle the response to the request.
  }
}

func fetchTopEvent(eventStore: EKEventStore, calendar: Calendar) -> String {
  // Create the start date components
  var oneDayAgoComponents = DateComponents()
  oneDayAgoComponents.day = -1
  let oneDayAgo = calendar.date(byAdding: oneDayAgoComponents, to: Date())
  
  // Create the end date components.
  var oneDayFromNowComponents = DateComponents()
  oneDayFromNowComponents.day = 1
  let oneDayFromNow = calendar.date(byAdding: oneDayFromNowComponents, to: Date())
  
  // Create the predicate from the event store's instance method.
  var predicate: NSPredicate? = nil
  if let anAgo = oneDayAgo, let aNow = oneDayFromNow {
    predicate = eventStore.predicateForEvents(withStart: anAgo, end: aNow, calendars: nil)
  }
  
  // Fetch all events that match the predicate.
  var events: [EKEvent]? = nil
  if let aPredicate = predicate {
    events = eventStore.events(matching: aPredicate)
  }

  let topEventTitle = events?[0].title ?? "No more events"
  return topEventTitle
}
