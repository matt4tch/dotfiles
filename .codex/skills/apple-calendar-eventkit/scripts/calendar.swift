#!/usr/bin/env swift

import EventKit
import Foundation

struct CalendarCLIError: Error {
    let message: String
}

let iso8601 = ISO8601DateFormatter()
iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

func emit(_ value: Any, to handle: FileHandle = .standardOutput) {
    guard JSONSerialization.isValidJSONObject(value),
          let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    else {
        handle.write(Data("{\"error\":\"Could not encode JSON output\"}\n".utf8))
        return
    }
    handle.write(data)
    handle.write(Data("\n".utf8))
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    emit(["error": message], to: .standardError)
    exit(code)
}

func requireValue(_ options: [String: String], _ key: String) throws -> String {
    guard let value = options[key], !value.isEmpty else {
        throw CalendarCLIError(message: "Missing required option \(key)")
    }
    return value
}

func parseOptions(_ arguments: ArraySlice<String>) throws -> ([String: String], Set<String>) {
    var options: [String: String] = [:]
    var flags: Set<String> = []
    var index = arguments.startIndex

    while index < arguments.endIndex {
        let argument = arguments[index]
        guard argument.hasPrefix("--") else {
            throw CalendarCLIError(message: "Unexpected positional argument: \(argument)")
        }

        let next = arguments.index(after: index)
        if next < arguments.endIndex, !arguments[next].hasPrefix("--") {
            options[argument] = arguments[next]
            index = arguments.index(after: next)
        } else {
            flags.insert(argument)
            index = next
        }
    }

    return (options, flags)
}

func timeZone(named identifier: String?) throws -> TimeZone {
    guard let identifier else {
        return .current
    }
    guard let zone = TimeZone(identifier: identifier) else {
        throw CalendarCLIError(message: "Unknown time zone: \(identifier)")
    }
    return zone
}

func parseDate(_ value: String, in zone: TimeZone) throws -> Date {
    let preciseISO = ISO8601DateFormatter()
    preciseISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = preciseISO.date(from: value) {
        return date
    }

    let standardISO = ISO8601DateFormatter()
    standardISO.formatOptions = [.withInternetDateTime]
    if let date = standardISO.date(from: value) {
        return date
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = zone

    for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd"] {
        formatter.dateFormat = format
        if let date = formatter.date(from: value) {
            return date
        }
    }

    throw CalendarCLIError(
        message: "Invalid date '\(value)'. Use ISO 8601, optionally with --timezone (for example, 2026-09-02T15:00:00+02:00)."
    )
}

func localString(_ date: Date, in zone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = zone
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"
    return formatter.string(from: date)
}

func calendarJSON(_ calendar: EKCalendar) -> [String: Any] {
    [
        "id": calendar.calendarIdentifier,
        "title": calendar.title,
        "source": calendar.source.title,
        "type": calendar.type.rawValue,
        "writable": calendar.allowsContentModifications,
    ]
}

func eventJSON(_ event: EKEvent) -> [String: Any] {
    let zone = event.timeZone ?? .current
    var result: [String: Any] = [
        "id": event.eventIdentifier ?? "",
        "calendar_id": event.calendar.calendarIdentifier,
        "calendar": event.calendar.title,
        "title": event.title ?? "",
        "start": iso8601.string(from: event.startDate),
        "end": iso8601.string(from: event.endDate),
        "start_local": localString(event.startDate, in: zone),
        "end_local": localString(event.endDate, in: zone),
        "time_zone": zone.identifier,
        "all_day": event.isAllDay,
        "recurring": !(event.recurrenceRules ?? []).isEmpty,
    ]

    if let location = event.location, !location.isEmpty {
        result["location"] = location
    }
    if let notes = event.notes, !notes.isEmpty {
        result["notes"] = notes
    }
    if let url = event.url {
        result["url"] = url.absoluteString
    }

    return result
}

func requestCalendarAccess(_ store: EKEventStore) {
    let semaphore = DispatchSemaphore(value: 0)
    var granted = false
    var accessError: Error?

    if #available(macOS 14.0, *) {
        store.requestFullAccessToEvents { allowed, error in
            granted = allowed
            accessError = error
            semaphore.signal()
        }
    } else {
        store.requestAccess(to: .event) { allowed, error in
            granted = allowed
            accessError = error
            semaphore.signal()
        }
    }

    semaphore.wait()
    guard granted else {
        let detail = accessError?.localizedDescription ?? "macOS denied Calendar access"
        fail("EventKit access failed: \(detail)", code: 2)
    }
}

func resolveCalendar(
    _ store: EKEventStore,
    selector: String?,
    requireWritable: Bool,
    useDefault: Bool
) throws -> EKCalendar? {
    guard let selector, !selector.isEmpty else {
        if useDefault {
            guard let calendar = store.defaultCalendarForNewEvents else {
                throw CalendarCLIError(message: "No default Calendar is available")
            }
            if requireWritable, !calendar.allowsContentModifications {
                throw CalendarCLIError(message: "The default Calendar is not writable")
            }
            return calendar
        }
        return nil
    }

    let calendars = store.calendars(for: .event)
    if let exactID = calendars.first(where: { $0.calendarIdentifier == selector }) {
        if requireWritable, !exactID.allowsContentModifications {
            throw CalendarCLIError(message: "Calendar '\(selector)' is not writable")
        }
        return exactID
    }

    let titleMatches = calendars.filter { $0.title.caseInsensitiveCompare(selector) == .orderedSame }
    guard !titleMatches.isEmpty else {
        throw CalendarCLIError(message: "No Calendar named or identified by '\(selector)'")
    }
    guard titleMatches.count == 1 else {
        let choices = titleMatches.map {
            "\($0.title) [\($0.source.title)] id=\($0.calendarIdentifier)"
        }.joined(separator: "; ")
        throw CalendarCLIError(message: "Calendar name is ambiguous. Use an id: \(choices)")
    }

    let calendar = titleMatches[0]
    if requireWritable, !calendar.allowsContentModifications {
        throw CalendarCLIError(message: "Calendar '\(selector)' is not writable")
    }
    return calendar
}

func intOption(_ options: [String: String], _ key: String, default defaultValue: Int) throws -> Int {
    guard let raw = options[key] else {
        return defaultValue
    }
    guard let value = Int(raw), value >= 0 else {
        throw CalendarCLIError(message: "\(key) must be a non-negative integer")
    }
    return value
}

func matchingEvents(
    _ store: EKEventStore,
    start: Date,
    end: Date,
    calendar: EKCalendar?,
    query: String?,
    limit: Int
) -> [EKEvent] {
    let predicate = store.predicateForEvents(
        withStart: start,
        end: end,
        calendars: calendar.map { [$0] }
    )
    let needle = query?.lowercased()

    return store.events(matching: predicate)
        .filter { event in
            guard let needle, !needle.isEmpty else {
                return true
            }
            return [
                event.title,
                event.location,
                event.notes,
                event.calendar.title,
            ]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains(needle) }
        }
        .sorted {
            if $0.startDate == $1.startDate {
                return ($0.title ?? "") < ($1.title ?? "")
            }
            return $0.startDate < $1.startDate
        }
        .prefix(limit)
        .map { $0 }
}

func applyEditableFields(
    to event: EKEvent,
    options: [String: String],
    flags: Set<String>,
    zone: TimeZone
) throws -> Bool {
    var changed = false

    if let title = options["--title"] {
        event.title = title
        changed = true
    }
    if let start = options["--start"] {
        event.startDate = try parseDate(start, in: zone)
        changed = true
    }
    if let end = options["--end"] {
        event.endDate = try parseDate(end, in: zone)
        changed = true
    }
    if let location = options["--location"] {
        event.location = location
        changed = true
    }
    if flags.contains("--clear-location") {
        event.location = nil
        changed = true
    }
    if let notes = options["--notes"] {
        event.notes = notes
        changed = true
    }
    if flags.contains("--clear-notes") {
        event.notes = nil
        changed = true
    }
    if let rawURL = options["--url"] {
        guard let url = URL(string: rawURL) else {
            throw CalendarCLIError(message: "Invalid URL: \(rawURL)")
        }
        event.url = url
        changed = true
    }
    if flags.contains("--clear-url") {
        event.url = nil
        changed = true
    }
    if flags.contains("--all-day") {
        event.isAllDay = true
        changed = true
    }
    if flags.contains("--timed") {
        event.isAllDay = false
        changed = true
    }
    if options["--timezone"] != nil {
        event.timeZone = zone
        changed = true
    }

    guard event.startDate < event.endDate else {
        throw CalendarCLIError(message: "Event end must be later than its start")
    }
    return changed
}

func printHelp() {
    print(
        """
        Apple Calendar EventKit CLI

        Commands:
          calendars
          events --from DATE --to DATE [--timezone TZ] [--calendar NAME_OR_ID] [--query TEXT] [--limit N]
          get --id EVENT_ID
          create --title TEXT --start DATE --end DATE [--timezone TZ] [--calendar NAME_OR_ID]
                 [--location TEXT] [--notes TEXT] [--url URL] [--all-day]
                 [--alarm-minutes N] [--allow-duplicate] [--commit]
          update --id EVENT_ID [editable fields] [--calendar NAME_OR_ID]
                 [--clear-location] [--clear-notes] [--clear-url]
                 [--all-day|--timed] [--allow-recurring] [--commit]
          delete --id EVENT_ID [--allow-recurring] [--commit]

        DATE accepts ISO 8601 with an offset, a local date-time used with --timezone,
        or YYYY-MM-DD. Mutating commands are dry runs unless --commit is supplied.
        """
    )
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    printHelp()
    exit(0)
}

let command = arguments[1]
if command == "help" || command == "--help" || command == "-h" {
    printHelp()
    exit(0)
}

do {
    let (options, flags) = try parseOptions(arguments.dropFirst(2))
    let store = EKEventStore()
    requestCalendarAccess(store)

    switch command {
    case "calendars":
        let calendars = store.calendars(for: .event)
            .sorted {
                if $0.source.title == $1.source.title {
                    return $0.title < $1.title
                }
                return $0.source.title < $1.source.title
            }
            .map(calendarJSON)
        emit(["calendars": calendars])

    case "events":
        let zone = try timeZone(named: options["--timezone"])
        let start = try parseDate(try requireValue(options, "--from"), in: zone)
        let end = try parseDate(try requireValue(options, "--to"), in: zone)
        guard start < end else {
            throw CalendarCLIError(message: "--to must be later than --from")
        }
        let calendar = try resolveCalendar(
            store,
            selector: options["--calendar"],
            requireWritable: false,
            useDefault: false
        )
        let limit = try intOption(options, "--limit", default: 500)
        let events = matchingEvents(
            store,
            start: start,
            end: end,
            calendar: calendar,
            query: options["--query"],
            limit: limit
        )
        emit([
            "count": events.count,
            "events": events.map(eventJSON),
        ])

    case "get":
        let identifier = try requireValue(options, "--id")
        guard let event = store.event(withIdentifier: identifier) else {
            throw CalendarCLIError(message: "No event found with id '\(identifier)'")
        }
        emit(["event": eventJSON(event)])

    case "create":
        let zone = try timeZone(named: options["--timezone"])
        let calendar = try resolveCalendar(
            store,
            selector: options["--calendar"],
            requireWritable: true,
            useDefault: true
        )!
        let title = try requireValue(options, "--title")
        let start = try parseDate(try requireValue(options, "--start"), in: zone)
        let end = try parseDate(try requireValue(options, "--end"), in: zone)
        guard start < end else {
            throw CalendarCLIError(message: "Event end must be later than its start")
        }

        let duplicates = matchingEvents(
            store,
            start: start.addingTimeInterval(-1),
            end: end.addingTimeInterval(1),
            calendar: calendar,
            query: nil,
            limit: 500
        ).filter {
            ($0.title ?? "") == title
                && abs($0.startDate.timeIntervalSince(start)) < 1
                && abs($0.endDate.timeIntervalSince(end)) < 1
        }
        if let duplicate = duplicates.first, !flags.contains("--allow-duplicate") {
            emit([
                "status": "duplicate",
                "event": eventJSON(duplicate),
            ])
            exit(0)
        }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = title
        event.startDate = start
        event.endDate = end
        event.timeZone = zone
        event.isAllDay = flags.contains("--all-day")
        event.location = options["--location"]
        event.notes = options["--notes"]

        if let rawURL = options["--url"] {
            guard let url = URL(string: rawURL) else {
                throw CalendarCLIError(message: "Invalid URL: \(rawURL)")
            }
            event.url = url
        }
        if let rawAlarm = options["--alarm-minutes"] {
            guard let minutes = Double(rawAlarm), minutes >= 0 else {
                throw CalendarCLIError(message: "--alarm-minutes must be a non-negative number")
            }
            event.addAlarm(EKAlarm(relativeOffset: -(minutes * 60)))
        }

        guard flags.contains("--commit") else {
            emit([
                "status": "dry_run",
                "event": eventJSON(event),
            ])
            exit(0)
        }

        try store.save(event, span: .thisEvent, commit: true)
        guard let identifier = event.eventIdentifier,
              let verified = store.event(withIdentifier: identifier)
        else {
            throw CalendarCLIError(message: "EventKit saved the event but read-back verification failed")
        }
        emit([
            "status": "created",
            "event": eventJSON(verified),
        ])

    case "update":
        let identifier = try requireValue(options, "--id")
        guard let event = store.event(withIdentifier: identifier) else {
            throw CalendarCLIError(message: "No event found with id '\(identifier)'")
        }
        if !(event.recurrenceRules ?? []).isEmpty, !flags.contains("--allow-recurring") {
            throw CalendarCLIError(
                message: "This is a recurring event. Re-run with --allow-recurring only after confirming the intended occurrence."
            )
        }

        let zone = try timeZone(named: options["--timezone"] ?? event.timeZone?.identifier)
        let changed = try applyEditableFields(to: event, options: options, flags: flags, zone: zone)
        if let calendarSelector = options["--calendar"] {
            event.calendar = try resolveCalendar(
                store,
                selector: calendarSelector,
                requireWritable: true,
                useDefault: false
            )!
        }
        guard changed || options["--calendar"] != nil else {
            throw CalendarCLIError(message: "No update fields were supplied")
        }

        guard flags.contains("--commit") else {
            emit([
                "status": "dry_run",
                "event": eventJSON(event),
            ])
            exit(0)
        }

        try store.save(event, span: .thisEvent, commit: true)
        guard let updatedID = event.eventIdentifier,
              let verified = store.event(withIdentifier: updatedID)
        else {
            throw CalendarCLIError(message: "EventKit updated the event but read-back verification failed")
        }
        emit([
            "status": "updated",
            "event": eventJSON(verified),
        ])

    case "delete":
        let identifier = try requireValue(options, "--id")
        guard let event = store.event(withIdentifier: identifier) else {
            throw CalendarCLIError(message: "No event found with id '\(identifier)'")
        }
        if !(event.recurrenceRules ?? []).isEmpty, !flags.contains("--allow-recurring") {
            throw CalendarCLIError(
                message: "This is a recurring event. Re-run with --allow-recurring only after confirming the intended occurrence."
            )
        }
        let snapshot = eventJSON(event)

        guard flags.contains("--commit") else {
            emit([
                "status": "dry_run",
                "event": snapshot,
            ])
            exit(0)
        }

        try store.remove(event, span: .thisEvent, commit: true)
        emit([
            "status": "deleted",
            "verified_absent": store.event(withIdentifier: identifier) == nil,
            "event": snapshot,
        ])

    default:
        throw CalendarCLIError(message: "Unknown command '\(command)'. Run with help for usage.")
    }
} catch let error as CalendarCLIError {
    fail(error.message)
} catch {
    fail(error.localizedDescription)
}
