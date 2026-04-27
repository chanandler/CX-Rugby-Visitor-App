# Bug Tracking

Track confirmed issues here.

## Status Legend
- `Open`: Reported and not yet fixed
- `In Progress`: Actively being worked on
- `Blocked`: Waiting on dependency or clarification
- `Resolved`: Fix completed and verified

## Bugs

### BUG-011 (Priority: P1)
- Status: Open
- Title: User-facing success flows proceed even when `modelContext.save()` fails
- Evidence:
  - `saveContext()` catches errors internally and does not return failure state (`ContentView.swift:1333`).
  - `registerVisitor()` always continues to clear fields and show success copy after `saveContext()` (`ContentView.swift:1116`).
  - `applyImport()` always reports “Import complete” after `saveContext()` (`ContentView.swift:1284`).
- Impact: Data may not be persisted, but operators receive success confirmation and can lose traceability/compliance records.
- Recommended fix: Make `saveContext` throw (or return `Bool`) and gate all success UI/cleanup paths on successful persistence only.

### BUG-012 (Priority: P3)
- Status: Open
- Title: PIN setup error message can persist across later setup sessions after policy state changes
- Evidence:
  - Policy re-evaluation can force setup and set `pinSetupErrorMessage` (`ContentView.swift:1057`).
  - When policy returns to valid state, `evaluatePinPolicy()` does not clear `pinSetupErrorMessage` (`ContentView.swift:1064`).
- Impact: Users can see stale/incorrect validation messaging when opening PIN setup later, reducing trust in the flow.
- Recommended fix: Clear `pinSetupErrorMessage` when entering a non-mandatory policy state and on sheet presentation for fresh sessions.

### BUG-009 (Priority: P2)
- Status: ✅ Resolved
- Title: Auto-checkout processes all pre-today active visitors, not only previous-day visitors

### BUG-010 (Priority: P2)
- Status: ✅ Resolved
- Title: CSV import rejects valid ISO8601 timestamps without fractional seconds

### BUG-001 (Priority: P1)
- Status: ✅ Resolved
- Title: SwiftData schema changes have no migration plan and risk upgrade failure/data loss

### BUG-002 (Priority: P2)
- Status: ✅ Resolved
- Title: CSV import may fail for external file providers due to missing security-scoped access

### BUG-003 (Priority: P2)
- Status: ✅ Resolved
- Title: Duplicate detection key is too coarse and can drop legitimate visits

### BUG-004 (Priority: P2)
- Status: ✅ Resolved
- Title: Import assumes first CSV row is header and drops row 1 data when header is missing

### BUG-005 (Priority: P3)
- Status: ✅ Resolved
- Title: Global drag gesture updates activity timestamp continuously, causing unnecessary UI churn

### BUG-006 (Priority: P3)
- Status: ✅ Resolved
- Title: Date parsing recreates `DateFormatter` objects repeatedly in hot path

### BUG-007 (Priority: P2)
- Status: ✅ Resolved
- Title: Headerless CSV with 9+ columns can be mis-mapped because parser assumes first column is `id`

### BUG-008 (Priority: P2)
- Status: ✅ Resolved
- Title: PIN security controls are weak (plain storage, default PIN, no retry lockout)
