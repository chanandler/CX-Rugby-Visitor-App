# Executive Summary: Cemex Rugby Cement Plant Visitor App

## Purpose
The app is an iPad-based visitor management solution for reception use at Cemex Rugby Cement Plant. It replaces paper-based sign-in with a structured digital process that supports operational control, emergency accountability, and audit/compliance reporting.

## What The App Does
- Registers visitors with required details (first name, last name, company, and who they are visiting) and optional car registration.
- Tracks active visitors currently on site.
- Supports visitor check-out through multiple workflows.
- Maintains a Sign In Book view for active, archived, and all records.
- Provides emergency roll-call tools for fire alarm accounting.
- Exports and imports visitor records via CSV.
- Performs automated maintenance tasks (auto-checkout and backups).
- Protects sensitive operational areas behind a PIN.

## App Flow
1. Launch
- User opens the app to a branded welcome/register experience with the site image and registration form.

2. Visitor Registration
- Reception enters required visitor details and selects Register.
- A new record is stored in SwiftData as active (checked-in).
- Confirmation message is displayed.

3. Visitor Departure
- Visitor can be checked out from "I'm Leaving" via search + confirmation.
- Visitor can also be checked out from management screens (e.g., roll call).

4. Sign In Book / History
- Reception opens Sign In Book and switches between Active, Archived, and All views.
- Data can be exported to CSV for reporting/compliance.

5. Emergency Roll Call
- Fire Roll Call screen shows active visitors.
- Users can confirm individual visitors out or confirm all out.

6. Settings & Administration
- Settings are opened via a separate bottom-left cog button.
- Access requires PIN authentication.
- From Settings, users manage operational toggles, PIN, import/restore, backup, and app information.

## Security & Access Control
- PIN-protected areas:
  - Sign In Book
  - Fire Roll Call
  - Settings
- Settings access uses a separate cog launcher and still enforces PIN.
- Session unlock is temporary and supports manual lock.
- Auto-relock triggers:
  - After 5 minutes of app inactivity.
  - After app returns from background/inactive if away for 5+ minutes.

## Data & Reporting
- Data store: SwiftData visitor records.
- CSV export: creates shareable CSV for compliance/reporting.
- CSV import/restore:
  - Preview before import.
  - Duplicate skipping.
  - Parse failure reporting.
  - Safe defaults for missing/partial fields.

## Business Continuity Features
- Weekday auto-checkout:
  - Automatically checks out prior-day active visitors.
- Daily automatic backups:
  - Writes backup files to Documents/VisitorBackups.
  - Applies retention cleanup based on configured retention days.
- Manual backup creation/export also available.

## Current Platform & UX Notes
- Targeted for iPad usage.
- Settings moved off the tab bar to a dedicated bottom-left cog action.
- Front-page branding reflects Cemex Rugby Cement Plant.

## Operational Outcomes
The app provides a controlled, auditable, and resilient visitor process that improves reception efficiency, enhances site safety response capability, and supports compliance reporting requirements.
