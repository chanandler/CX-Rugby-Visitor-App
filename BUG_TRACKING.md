# Bug Tracking

Track confirmed issues here.

## Status Legend
- `Open`: Reported and not yet fixed
- `In Progress`: Actively being worked on
- `Blocked`: Waiting on dependency or clarification
- `Resolved`: Fix completed and verified

## Bugs

### BUG-001 (Priority: P1)
- Status: Open
- Title: SwiftData schema changes have no migration plan and risk upgrade failure/data loss
- Area: Data Persistence
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: Critical
- File/Reference: `CX Rugby Visitor App/VisitorRecord.swift`
- Steps to Reproduce:
1. Install an older build that used previous `VisitorRecord` fields.
2. Create visitor data.
3. Upgrade to the current build.
- Expected Result: Existing data migrates safely.
- Actual Result: No explicit migration/versioning is defined; schema evolution may fail at launch or lose prior fields.
- Notes: Add a versioned schema + migration plan before shipping further model changes.

### BUG-002 (Priority: P2)
- Status: Open
- Title: CSV import may fail for external file providers due to missing security-scoped access
- Area: Import/Restore
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: High
- File/Reference: `CX Rugby Visitor App/ContentView.swift:721-724`
- Steps to Reproduce:
1. Import CSV from Files app provider (e.g., iCloud/third-party provider).
2. Attempt import on constrained file provider access.
- Expected Result: Import reads file reliably.
- Actual Result: `Data(contentsOf:)` is used without `startAccessingSecurityScopedResource()`, which can fail on some providers.
- Notes: Wrap file read with security-scoped resource access lifecycle.

### BUG-003 (Priority: P2)
- Status: Open
- Title: Duplicate detection key is too coarse and can drop legitimate visits
- Area: Import/Restore
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: High
- File/Reference: `CX Rugby Visitor App/ContentView.swift:1013-1016`, `1086-1089`
- Steps to Reproduce:
1. Import two valid visits on same day for same person/company (e.g., leaves and returns later).
2. Import preview marks later entry as duplicate.
- Expected Result: Distinct visits are retained.
- Actual Result: Key uses `first+last+company+day`, causing false duplicate suppression.
- Notes: Include higher-precision visit identity (e.g., check-in timestamp + host + optional external ID).

### BUG-004 (Priority: P2)
- Status: Open
- Title: Import assumes first CSV row is header and drops row 1 data when header is missing
- Area: Import/Restore
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: Medium
- File/Reference: `CX Rugby Visitor App/ContentView.swift:1076`, `1091`
- Steps to Reproduce:
1. Import a CSV without headers where row 1 is a real visitor record.
2. Run preview/import.
- Expected Result: Row 1 is imported or user is warned and asked for mapping.
- Actual Result: Row 1 is treated as header and omitted from data import.
- Notes: Detect header presence or provide explicit “CSV has headers” option.

### BUG-005 (Priority: P3)
- Status: Open
- Title: Global drag gesture updates activity timestamp continuously, causing unnecessary UI churn
- Area: Performance
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: Medium
- File/Reference: `CX Rugby Visitor App/ContentView.swift:102-105`, `556-558`
- Steps to Reproduce:
1. Scroll lists/forms for several seconds.
2. Observe frequent state updates from root `DragGesture(minimumDistance: 0)`.
- Expected Result: Activity tracking should be lightweight and event-efficient.
- Actual Result: Every drag change updates state, increasing recomposition frequency and battery use.
- Notes: Throttle/debounce activity updates or use less chatty interaction hooks.

### BUG-006 (Priority: P3)
- Status: Open
- Title: Date parsing recreates `DateFormatter` objects repeatedly in hot path
- Area: Performance
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: Low
- File/Reference: `CX Rugby Visitor App/ContentView.swift:1216-1221`
- Steps to Reproduce:
1. Import large CSV with many date fields.
2. Profile import time/allocation behavior.
- Expected Result: Reuse cached formatters.
- Actual Result: New formatter instances are created for each parse attempt.
- Notes: Cache fallback formatters as static properties to reduce allocation overhead.
