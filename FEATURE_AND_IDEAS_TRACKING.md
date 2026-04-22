# Feature and New Ideas Tracking

Track delivered features, planned enhancements, and future ideas.

## Current Delivered Features
- Visitor registration form with required identity, company, host, and optional car registration.
- Visitor check-out flow via `I'm Leaving` search and confirmation.
- Sign In Book with active and archived visitor records.
- Fire Alarm Roll Call with confirm-out actions.
- CSV export of visitor data.
- Automatic weekday auto-checkout for previous-day active visitors.
- Automatic daily backups to Documents with retention cleanup.
- Manual backup export.
- CSV import/restore with preview, duplicate skipping, parse-failure reporting, and safe defaults.
- About/settings with version/build display and operational toggles.


## New Ideas Backlog

### IDEA-001
- Title: Inline field-level validation on registration form
- Type: UX / Data Quality
- Priority: High
- Status: Proposed
- Summary: Add inline validation messages and field highlighting for missing or invalid required fields before register action.
- Value: Reduces invalid submissions and improves receptionist guidance.

### IDEA-002
- Title: Advanced Sign In Book search and sorting
- Type: Usability
- Priority: Medium
- Status: Proposed
- Summary: Add richer filtering (date range, host, company, status) and sortable columns for faster audit lookups.
- Value: Speeds up compliance/history access and day-to-day operations.

### IDEA-003
- Title: Automated test coverage for core workflows
- Type: Quality / Reliability
- Priority: High
- Status: Proposed
- Summary: Add unit tests for CSV parsing, duplicate detection, and auto-checkout logic using Apple Testing framework.
- Value: Prevents regressions and increases confidence for future changes.
