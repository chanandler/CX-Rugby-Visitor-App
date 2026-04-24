# Executive Summary: Cemex Rugby Cement Plant Visitor App

## Purpose
This app is an iPad-based visitor management solution for reception at Cemex Rugby Cement Plant. It replaces paper sign-in/out with a controlled digital process that improves safety accountability, operational consistency, and reporting readiness.

## Current Scope
- Digital visitor registration with required fields:
  - First name
  - Last name
  - Company
  - Visiting
- Optional car registration capture.
- Visitor check-out via:
  - "I'm Leaving" search + confirm workflow
  - Fire Roll Call confirm-out actions
- Sign In Book with Active, Archived, and All views.
- Fire Alarm Roll Call emergency accounting view, including:
  - Individual confirm-out
  - Confirm all out
  - Session visibility of confirmed-out visitors
- CSV export for reporting/compliance.
- CSV import/restore with:
  - Preview before apply
  - Duplicate skipping
  - Parse-failure reporting
  - Safe defaults for missing columns
  - Support for ISO timestamps with and without fractional seconds
- Settings and About management, including version/build display.
- Analytics dashboard (Day / Week / Month / Year views).

## Security and Access Control
- PIN protection is enforced for:
  - Sign In Book
  - Fire Roll Call
  - Settings
- PIN is stored using Keychain service logic.
- Failed PIN attempts trigger escalating lockout windows.
- Auto-relock behavior:
  - After 5 minutes of inactivity
  - After returning from background/inactive when away for 5+ minutes
- Settings remain intentionally separated behind a dedicated bottom-left cog launcher.

## Data, Continuity, and Resilience
- Persistence uses SwiftData with migration plan support.
- Automatic weekday auto-checkout is implemented for previous-day active visitors only.
- Automatic daily backups write to `Documents/VisitorBackups` with retention cleanup.
- Manual backup generation and sharing is available.

## UX and Platform Notes
- Designed for iPad front-desk use.
- Branded welcome/registration screen includes:
  - Site photo hero background
  - Cemex logo treatment
  - Front-and-centre registration card

## Operational Outcome
The app provides a practical, auditable visitor control system that supports reception throughput, emergency response readiness, and compliance reporting, while reducing manual administrative overhead.