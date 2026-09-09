---
name: apple-calendar-eventkit
description: View, search, create, update, and delete events in the user's local Apple Calendar using Swift and EventKit on macOS. Use for Apple Calendar schedules, availability checks, itinerary audits, event entry from text or images, accommodation and flight bookings, event corrections, duplicate detection, and explicit event deletion requests. Prefer this skill over AppleScript, JXA, or ICS-file generation for direct Apple Calendar work.
---

# Apple Calendar with EventKit

Use the bundled `scripts/calendar` launcher for deterministic EventKit access and JSON output. It prefers the installed `Codex Calendar Helper.app`, whose stable macOS identity allows EventKit access from persistent tmux sessions, and falls back to interpreting `calendar.swift` when the helper is not installed. Run it from the trusted `/Users/matthew4.tch/dotfiles` workspace:

```bash
.codex/skills/apple-calendar-eventkit/scripts/calendar help
```

Install or refresh the helper only when the user requests setup or maintenance:

```bash
.codex/skills/apple-calendar-eventkit/scripts/install_helper.sh
```

The helper is installed at `~/Applications/Codex Calendar Helper.app`. Its first EventKit operation may prompt for Full Calendar Access. Do not remove its permission, reset TCC, or reinstall it merely to retry a failed operation.

## Workflow

1. Identify the requested operation, calendar, dates, time zone, location, notes, and recurrence intent.
2. For reads, query the narrowest useful date range.
3. Before updating or deleting, find the event and use its exact `id`.
4. For mutations, run a dry run without `--commit`, inspect the JSON, then repeat with `--commit` when it matches the user's request.
5. Report the resulting calendar, local dates, title, and verification status.

If EventKit fails with Mach error 4099 or `NSXPCConnectionInvalid` inside the sandbox, rerun the same launcher command once with escalated execution. A trusted workspace and the helper's macOS Calendar permission are necessary for the approval path. If escalated EventKit still fails, report the exact error and stop; do not reinstall the helper, switch to AppleScript, or create an ICS file without the user's approval.

## Read operations

List available calendars:

```bash
.codex/skills/apple-calendar-eventkit/scripts/calendar calendars
```

List or search events:

```bash
.codex/skills/apple-calendar-eventkit/scripts/calendar events \
  --from 2026-08-01 --to 2026-09-01 \
  --timezone America/Toronto \
  --calendar Home \
  --query flight
```

Fetch one exact event:

```bash
.codex/skills/apple-calendar-eventkit/scripts/calendar get \
  --id 'EVENT_IDENTIFIER'
```

## Create events

Prefer ISO 8601 values with offsets. For a local date-time without an offset, always provide an IANA time zone such as `Europe/Warsaw`.

Dry run:

```bash
.codex/skills/apple-calendar-eventkit/scripts/calendar create \
  --calendar Home \
  --title 'Room in Kraków' \
  --start 2026-08-30T15:00 \
  --end 2026-09-02T10:00 \
  --timezone Europe/Warsaw \
  --location 'Krowoderska 6, Kraków, Poland'
```

Commit the same event by appending `--commit`. Exact title/start/end duplicates are returned with `status: "duplicate"` unless `--allow-duplicate` is explicitly supplied.

Use one spanning event for accommodations and other true intervals. For term-style start/end markers, create two discrete events unless the user explicitly asks for a spanning event. For all-day events, pass `--all-day`; treat the end date as exclusive.

## Update and delete events

Use an exact identifier obtained from `events` or `get`.

```bash
.codex/skills/apple-calendar-eventkit/scripts/calendar update \
  --id 'EVENT_IDENTIFIER' \
  --start 2026-09-02T16:00 \
  --timezone Europe/Zagreb
```

Append `--commit` only after inspecting the dry run. Clear optional values with `--clear-location`, `--clear-notes`, or `--clear-url`.

```bash
.codex/skills/apple-calendar-eventkit/scripts/calendar delete \
  --id 'EVENT_IDENTIFIER'
```

Deletion must reflect an explicit user request. Show the dry-run event before appending `--commit`. Recurring events require `--allow-recurring`; confirm the intended occurrence before using it.

## Safety and interpretation

- Do not infer authorization to modify Calendar from a request to inspect, summarize, or diagnose.
- Prefer a user-named calendar. Otherwise use EventKit's default calendar and report which calendar was chosen.
- Use the event location's time zone for travel and accommodation bookings, not the current Toronto time zone.
- Preserve booking references and useful notes when provided, but avoid repeating sensitive identifiers unnecessarily in chat.
- Treat script output as the source of truth. Mutating commands read the saved event back before returning success.
- Never submit a mutation twice merely because output was delayed; query by identifier or exact title/start/end first.
