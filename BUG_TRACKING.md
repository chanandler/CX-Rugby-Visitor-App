# Bug Tracking

Track confirmed issues here.

## Status Legend
- `Open`: Reported and not yet fixed
- `In Progress`: Actively being worked on
- `Blocked`: Waiting on dependency or clarification
- `Resolved`: Fix completed and verified

## Bugs

### BUG-009 (Priority: P2)
- Status: `Open`
- Title: Auto-checkout processes all pre-today active visitors, not only previous-day visitors
- Area: Operations / Auto-checkout
- Reported By: Code review
- Date Reported: 2026-04-24
- Severity: High
- File/Reference: `CX Rugby Visitor App/ContentView.swift` (auto-checkout logic around lines 1124-1137)
- Steps to Reproduce:
1. Create an active visitor record dated multiple days in the past (not just yesterday).
2. Launch app on a weekday with auto-checkout enabled.
- Expected Result: Only previous-day active visitors are auto-checked out.
- Actual Result: Any active visitor with `checkInAt < startOfToday` is checked out.
- Notes: This behavior conflicts with the settings label "Auto-checkout previous-day active visitors (weekdays)" and can unexpectedly close older in-progress records.

### BUG-010 (Priority: P2)
- Status: `Open`
- Title: CSV import rejects valid ISO8601 timestamps without fractional seconds
- Area: Import/Restore
- Reported By: Code review
- Date Reported: 2026-04-24
- Severity: High
- File/Reference: `CX Rugby Visitor App/ContentView.swift` (`VisitorCSVService.isoFormatter` and date parsing around lines 1405-1408, 1602-1609)
- Steps to Reproduce:
1. Import CSV with `check_in_at` formatted like `2026-04-24T12:34:56Z`.
2. Open import preview.
- Expected Result: Timestamp parses successfully as a valid ISO8601 value.
- Actual Result: Row fails with `Invalid date for check_in_at...`.
- Notes: `ISO8601DateFormatter` is configured with `.withFractionalSeconds`, so non-fractional ISO strings are rejected. Confirmed via `ExecuteSnippet` run.

### BUG-001 (Priority: P1)
- Status: ✅ Resolved
- Title: SwiftData schema changes have no migration plan and risk upgrade failure/data loss
- Area: Data Persistence
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: Critical
- File/Reference: `CX Rugby Visitor App/VisitorSchema.swift`, `CX Rugby Visitor App/CX_Rugby_Visitor_AppApp.swift`, `CX Rugby Visitor App/VisitorRecord.swift`
- Steps to Reproduce:
1. Install an older build that used previous `VisitorRecord` fields.
2. Create visitor data.
3. Upgrade to the current build.
- Expected Result: Existing data migrates safely.
- Actual Result (Before Fix): No explicit migration/versioning was defined.
- Resolution: Added explicit `VisitorSchemaV1` -> `VisitorSchemaV2` migration via `VisitorMigrationPlan`, switched app startup to a `ModelContainer` initialized with that migration plan, and aliased runtime `VisitorRecord` to the current schema model.
- Verified: Project builds successfully after migration wiring.

### BUG-002 (Priority: P2)
- Status: ✅ Resolved
- Title: CSV import may fail for external file providers due to missing security-scoped access
- Area: Import/Restore
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: High
- File/Reference: `CX Rugby Visitor App/ContentView.swift`
- Steps to Reproduce:
1. Import CSV from Files app provider (e.g., iCloud/third-party provider).
2. Attempt import on constrained file provider access.
- Expected Result: Import reads file reliably.
- Actual Result (Before Fix): `Data(contentsOf:)` was called directly without security-scoped resource lifecycle management.
- Resolution: Added `readImportData(from:)` helper that calls `startAccessingSecurityScopedResource()`, reads data, and guarantees `stopAccessingSecurityScopedResource()` via `defer`.
- Verified: Project builds successfully with updated import flow.

### BUG-003 (Priority: P2)
- Status: ✅ Resolved
- Title: Duplicate detection key is too coarse and can drop legitimate visits
- Area: Import/Restore
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: High
- File/Reference: `CX Rugby Visitor App/ContentView.swift`
- Steps to Reproduce:
1. Import two valid visits on same day for same person/company (e.g., leaves and returns later).
2. Import preview marks later entry as duplicate.
- Expected Result: Distinct visits are retained.
- Actual Result (Before Fix): Duplicate key used low precision (`first+last+company+day`) and caused false suppression.
- Resolution: Duplicate detection now uses both record `id` (when present) and a higher-precision visit signature (`first+last+company+host+exact check-in timestamp`) for existing and incoming records.
- Verified: Project builds successfully with updated duplicate handling.

### BUG-004 (Priority: P2)
- Status: ✅ Resolved
- Title: Import assumes first CSV row is header and drops row 1 data when header is missing
- Area: Import/Restore
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: Medium
- File/Reference: `CX Rugby Visitor App/ContentView.swift`
- Steps to Reproduce:
1. Import a CSV without headers where row 1 is a real visitor record.
2. Run preview/import.
- Expected Result: Row 1 is imported or user is warned and asked for mapping.
- Actual Result (Before Fix): Row 1 was always treated as header and omitted from data import.
- Resolution: Added header detection (`rowLooksLikeHeader`) and fallback positional header guessing. When no header is detected, import now treats row 1 as data and applies safe default column mapping.
- Verified: Project builds successfully with updated import behavior.

### BUG-005 (Priority: P3)
- Status: ✅ Resolved
- Title: Global drag gesture updates activity timestamp continuously, causing unnecessary UI churn
- Area: Performance
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: Medium
- File/Reference: `CX Rugby Visitor App/ContentView.swift`
- Steps to Reproduce:
1. Scroll lists/forms for several seconds.
2. Observe frequent state updates from root `DragGesture(minimumDistance: 0)`.
- Expected Result: Activity tracking should be lightweight and event-efficient.
- Actual Result (Before Fix): Every drag change updated activity state and increased recomposition frequency.
- Resolution: Changed activity tracking drag hook from `.onChanged` to `.onEnded`, reducing updates to once per gesture.
- Verified: Project builds successfully with updated activity tracking.

### BUG-006 (Priority: P3)
- Status: ✅ Resolved
- Title: Date parsing recreates `DateFormatter` objects repeatedly in hot path
- Area: Performance
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: Low
- File/Reference: `CX Rugby Visitor App/ContentView.swift`
- Steps to Reproduce:
1. Import large CSV with many date fields.
2. Profile import time/allocation behavior.
- Expected Result: Reuse cached formatters.
- Actual Result (Before Fix): New formatter instances were created for each parse attempt.
- Resolution: Added static cached `fallbackDateFormatters` and reused them in `parseDateString(_:)`.
- Verified: Project builds successfully with cached formatter parsing.

### BUG-007 (Priority: P2)
- Status: ✅ Resolved
- Title: Headerless CSV with 9+ columns can be mis-mapped because parser assumes first column is `id`
- Area: Import/Restore
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: High
- File/Reference: `CX Rugby Visitor App/ContentView.swift`
- Steps to Reproduce:
1. Import a headerless CSV with 9 columns where column 1 is not a UUID `id`.
2. Preview/import the file.
- Expected Result: Columns map correctly to first/last/company/host/check-in fields.
- Actual Result (Before Fix): Positional header guesser preferred `id` at column 1 for 9+ columns and could shift mapping.
- Resolution: Added `likelyContainsIDColumn(_:)` detection for headerless imports and updated guessed-header logic to only include `id` when first-column UUID probability is high.
- Verified: Project builds successfully with updated headerless mapping logic.

### BUG-008 (Priority: P2)
- Status: ✅ Resolved
- Title: PIN security controls are weak (plain storage, default PIN, no retry lockout)
- Area: Security
- Reported By: Code review
- Date Reported: 2026-04-22
- Severity: High
- File/Reference: `CX Rugby Visitor App/ContentView.swift`, `CX Rugby Visitor App/PinSecurityService.swift`
- Steps to Reproduce:
1. Install app and inspect behavior with default settings.
2. Attempt repeated incorrect PIN entry.
- Expected Result: No insecure default, no plain-text credential storage, and brute-force mitigation.
- Actual Result (Before Fix): PIN defaulted to `1234`, was stored in `@AppStorage` (UserDefaults), and allowed unlimited retries.
- Resolution: Replaced `@AppStorage` PIN storage with Keychain-backed `PinSecurityService`, removed default PIN, added mandatory PIN setup flow when missing, and implemented escalating retry lockout/backoff.
- Verified: Project builds successfully with hardened PIN flow.
