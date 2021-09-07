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
  let now = Date()
  
  // Create the end date components.
  let tomorrow = Date().addingTimeInterval(60 * 60 * 24)
  
  // Create the predicate from the event store's instance method.
  var predicate: NSPredicate? = nil
  predicate = eventStore.predicateForEvents(withStart: now, end: tomorrow, calendars: nil)
  
  // Fetch all events that match the predicate.
  var events: [EKEvent]? = nil
  if let aPredicate = predicate {
    events = eventStore.events(matching: aPredicate)
  }

  let topEventTitle = events?.first?.title ?? "No more events"
  return topEventTitle
}
