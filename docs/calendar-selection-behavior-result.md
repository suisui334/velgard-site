# Calendar Initial Selection Behavior Result

Gate: CAL-01 calendar initial selection behavior fix

## Summary

- Plain `calendar.html` no longer initializes with a selected date.
- The calendar month still opens around the current Japan date, but the selected-date detail area starts in an unselected state.
- `calendar.html?date=YYYY-MM-DD` remains an explicit selection path and opens the target date.
- A one-shot `sessionStorage` key, `velgard.calendar.returnDate`, is supported and consumed once if present.
- Stale `localStorage` key `velgard.calendar.selectedDate` is not used for normal initial selection and is cleared on plain unselected load.

## Preserved Flows

- Session detail return links still use `calendar.html?date=<session.date>`, so returning from a session flow can restore the target date.
- User date clicks, date input submission, and the today button still set the selected date and update the URL query.
- Month navigation does not force a selected date.

## Cache Bust

- `calendar.html` now references `assets/js/main.js?v=20260703-calendar-explicit-selection`.
- `assets/js/main.js` now imports `renderCalendar.js?v=20260703-calendar-explicit-selection`.

## Verification

- `node --check assets/js/core/calendar/renderCalendar.js`: passed.
- `node --check assets/js/main.js`: passed.
- Static code review confirmed plain load does not read stale selected date from `localStorage`.

## Limited / Not Tested

- Browser-level manual checks for menu navigation, normal reload, and session edit/update return flow were not run in this gate.
- DB, SQL, Edge Function, Discord, secret, and `updates.json` changes were not performed.
