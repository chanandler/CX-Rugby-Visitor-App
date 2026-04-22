import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [SortDescriptor(\VisitorRecord.checkInAt, order: .reverse)]) private var visitors: [VisitorRecord]

    @AppStorage("autoCheckoutEnabled") private var autoCheckoutEnabled = true
    @AppStorage("autoBackupEnabled") private var autoBackupEnabled = true
    @AppStorage("backupRetentionDays") private var backupRetentionDays = 30
    @AppStorage("securityPin") private var securityPin = "1234"

    @State private var selectedTab: AppTab = .register
    @State private var pendingProtectedTab: AppTab?
    @State private var unlockedProtectedTabs: Set<AppTab> = []
    @State private var pinInput = ""
    @State private var pinErrorMessage = ""
    @State private var showPinEntrySheet = false
    @State private var newPinInput = ""
    @State private var lastUserActivityAt = Date()
    @State private var backgroundEnteredAt: Date?

    private let autoRelockInterval: TimeInterval = 5 * 60

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var host = ""
    @State private var carRegistration = ""

    @State private var registrationMessage = ""
    @State private var showRegistrationAlert = false

    @State private var leavingSearch = ""
    @State private var checkoutCandidateID: UUID?
    @State private var showCheckoutConfirmation = false

    @State private var signInScope: SignInScope = .active
    @State private var exportURL: URL?

    @State private var backupURL: URL?
    @State private var settingsMessage = ""
    @State private var showSettingsAlert = false

    @State private var showingImporter = false
    @State private var importPreview: ImportPreview?

    var body: some View {
        TabView(selection: $selectedTab) {
            welcomeAndRegistrationTab
                .tabItem {
                    Label("Register", systemImage: "person.badge.plus")
                }
                .tag(AppTab.register)

            leavingTab
                .tabItem {
                    Label("I'm Leaving", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .tag(AppTab.leaving)

            signInBookTab
                .tabItem {
                    Label("Sign In Book", systemImage: "book.closed")
                }
                .tag(AppTab.signInBook)

            fireRollCallTab
                .tabItem {
                    Label("Fire Roll Call", systemImage: "flame")
                }
                .tag(AppTab.fireRollCall)

            settingsTab
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .onAppear {
            markUserActivity()
            runMaintenance()
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            markUserActivity()
            handleTabSelectionChange(oldValue: oldValue, newValue: newValue)
        }
        .task {
            await monitorInactivity()
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                markUserActivity()
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { _ in
                markUserActivity()
            }
        )
        .alert("Registration", isPresented: $showRegistrationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(registrationMessage)
        }
        .alert("Confirm Check-Out", isPresented: $showCheckoutConfirmation) {
            Button("Confirm") {
                confirmCheckoutCandidate()
            }
            Button("Cancel", role: .cancel) {
                checkoutCandidateID = nil
            }
        } message: {
            Text(checkoutConfirmationMessage)
        }
        .alert("Settings", isPresented: $showSettingsAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(settingsMessage)
        }
        .sheet(isPresented: $showPinEntrySheet) {
            PinEntrySheet(
                tabTitle: pendingProtectedTab?.title ?? "Protected Area",
                pinInput: $pinInput,
                errorMessage: pinErrorMessage,
                onCancel: {
                    pendingProtectedTab = nil
                    pinInput = ""
                    pinErrorMessage = ""
                    showPinEntrySheet = false
                },
                onUnlock: verifyPinAndUnlock
            )
        }
        .sheet(item: $importPreview) { preview in
            ImportPreviewSheet(preview: preview) {
                applyImport(preview)
                importPreview = nil
            } onCancel: {
                importPreview = nil
            }
        }
    }

    private var welcomeAndRegistrationTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack(alignment: .bottomLeading) {
                        Image("Rugby_Cement_Plant")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 220)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .overlay(
                                LinearGradient(
                                    colors: [Color.clear, Color.black.opacity(0.68)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("CX Rugby Visitor Hub")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                            Text("Welcome. Please register before entering the site.")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.92))
                        }
                        .padding(16)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Visitor Registration")
                            .font(.title3.bold())

                        HStack(spacing: 12) {
                            TextField("First name *", text: $firstName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Last name *", text: $lastName)
                                .textFieldStyle(.roundedBorder)
                        }

                        TextField("Company *", text: $company)
                            .textFieldStyle(.roundedBorder)

                        TextField("Visiting *", text: $host)
                            .textFieldStyle(.roundedBorder)

                        TextField("Car registration (optional)", text: $carRegistration)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            registerVisitor()
                        } label: {
                            Label("Register", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 6)
                    }
                    .padding()
                    .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Visitors: \(activeVisitors.count)")
                            .font(.headline)
                        Text("Total Records: \(visitors.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.15), Color.green.opacity(0.12), Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Welcome")
        }
    }

    private var leavingTab: some View {
        NavigationStack {
            List {
                Section("Search Active Visitors") {
                    TextField("Search by name, company or host", text: $leavingSearch)
                }

                Section("Matches") {
                    if filteredLeavingVisitors.isEmpty {
                        Text("No matching active visitors")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredLeavingVisitors, id: \.id) { visitor in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(visitor.fullName)
                                    .font(.headline)
                                Text("\(visitor.company) • Host: \(visitor.host)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("Checked in: \(visitor.checkInAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button("Check Out") {
                                    checkoutCandidateID = visitor.id
                                    showCheckoutConfirmation = true
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("I'm Leaving")
        }
    }

    private var signInBookTab: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Scope", selection: $signInScope) {
                        ForEach(SignInScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Records") {
                    if scopedVisitors.isEmpty {
                        Text("No records for this view")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scopedVisitors, id: \.id) { visitor in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(visitor.fullName)
                                    .font(.headline)
                                Text("Company: \(visitor.company) • Host: \(visitor.host)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("In: \(visitor.checkInAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Out: \(visitor.checkedOutAt?.formatted(date: .abbreviated, time: .shortened) ?? "Active")")
                                    .font(.caption)
                                    .foregroundStyle(visitor.isActive ? .green : .secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if let exportURL {
                    Section("Export") {
                        ShareLink(item: exportURL) {
                            Label("Share Last CSV Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Sign In Book")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Export CSV") {
                        exportCSV()
                    }
                }
            }
        }
    }

    private var fireRollCallTab: some View {
        NavigationStack {
            List {
                Section {
                    Text("Use this for emergency accounting. Confirm out when each person is accounted for.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Active Visitors (\(activeVisitors.count))") {
                    if activeVisitors.isEmpty {
                        Text("No active visitors")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(activeVisitors, id: \.id) { visitor in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(visitor.fullName)
                                        .font(.headline)
                                    Text("\(visitor.company) • Host: \(visitor.host)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Confirm Out") {
                                    checkout(visitor: visitor, method: "Fire Roll Call")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }

                if !activeVisitors.isEmpty {
                    Section {
                        Button("Confirm All Out", role: .destructive) {
                            for visitor in activeVisitors {
                                checkout(visitor: visitor, method: "Fire Roll Call")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fire Alarm Roll Call")
        }
    }

    private var settingsTab: some View {
        NavigationStack {
            List {
                Section("Security") {
                    Text("PIN protects Sign In Book, Fire Roll Call, and Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    SecureField("Set new PIN (4 to 8 digits)", text: $newPinInput)
                        .keyboardType(.numberPad)

                    Button("Update PIN") {
                        updatePin()
                    }

                    Button("Lock Protected Areas Now") {
                        relockProtectedAreas()
                    }
                }

                Section("Operations") {
                    Toggle("Auto-checkout previous-day active visitors (weekdays)", isOn: $autoCheckoutEnabled)
                    Toggle("Automatic daily backups", isOn: $autoBackupEnabled)
                    Stepper("Backup retention: \(backupRetentionDays) days", value: $backupRetentionDays, in: 7...180)
                }

                Section("Import / Restore") {
                    Button("Import from CSV") {
                        showingImporter = true
                    }
                }

                Section("Backups") {
                    Button("Create Manual Backup") {
                        createManualBackup()
                    }
                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("Share Last Backup", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build", value: appBuild)
                    LabeledContent("Records", value: "\(visitors.count)")
                }
            }
            .navigationTitle("Settings")
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    private var activeVisitors: [VisitorRecord] {
        visitors.filter { $0.isActive }
    }

    private var archivedVisitors: [VisitorRecord] {
        visitors.filter { !$0.isActive }
    }

    private var scopedVisitors: [VisitorRecord] {
        switch signInScope {
        case .active:
            return activeVisitors
        case .archived:
            return archivedVisitors
        case .all:
            return visitors
        }
    }

    private var filteredLeavingVisitors: [VisitorRecord] {
        let term = leavingSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return activeVisitors }

        return activeVisitors.filter { visitor in
            let haystack = [visitor.fullName, visitor.company, visitor.host]
                .joined(separator: " ")
                .lowercased()
            return haystack.contains(term.lowercased())
        }
    }

    private var checkoutConfirmationMessage: String {
        guard let candidate = visitor(with: checkoutCandidateID) else {
            return "Confirm this visitor has left the site."
        }
        return "Check out \(candidate.fullName)?"
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            runMaintenance()
            if let backgroundEnteredAt,
               Date().timeIntervalSince(backgroundEnteredAt) >= autoRelockInterval {
                relockProtectedAreas()
            }
            self.backgroundEnteredAt = nil
            markUserActivity()
        case .inactive, .background:
            if backgroundEnteredAt == nil {
                backgroundEnteredAt = Date()
            }
        @unknown default:
            break
        }
    }

    private func performAutoRelockCheck() {
        guard scenePhase == .active, !unlockedProtectedTabs.isEmpty else { return }
        guard Date().timeIntervalSince(lastUserActivityAt) >= autoRelockInterval else { return }
        relockProtectedAreas()
    }

    private func monitorInactivity() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            performAutoRelockCheck()
        }
    }

    private func markUserActivity() {
        lastUserActivityAt = Date()
    }

    private func handleTabSelectionChange(oldValue: AppTab, newValue: AppTab) {
        guard newValue.isProtected, !unlockedProtectedTabs.contains(newValue) else {
            return
        }

        pendingProtectedTab = newValue
        pinInput = ""
        pinErrorMessage = ""
        selectedTab = oldValue
        showPinEntrySheet = true
    }

    private func verifyPinAndUnlock() {
        guard let pendingProtectedTab else { return }

        if pinInput == securityPin {
            unlockedProtectedTabs.insert(pendingProtectedTab)
            selectedTab = pendingProtectedTab
            self.pendingProtectedTab = nil
            pinInput = ""
            pinErrorMessage = ""
            showPinEntrySheet = false
            markUserActivity()
        } else {
            pinErrorMessage = "Incorrect PIN. Please try again."
        }
    }

    private func relockProtectedAreas() {
        unlockedProtectedTabs.removeAll()
        pendingProtectedTab = nil
        pinInput = ""
        pinErrorMessage = ""
        showPinEntrySheet = false
        if selectedTab.isProtected {
            selectedTab = .register
        }
    }

    private func updatePin() {
        let digitsOnly = newPinInput.filter { $0.isNumber }
        guard (4...8).contains(digitsOnly.count) else {
            settingsMessage = "PIN must be 4 to 8 digits."
            showSettingsAlert = true
            return
        }

        securityPin = digitsOnly
        newPinInput = ""
        settingsMessage = "PIN updated successfully."
        showSettingsAlert = true
    }

    private func visitor(with id: UUID?) -> VisitorRecord? {
        guard let id else { return nil }
        return visitors.first(where: { $0.id == id })
    }

    private func registerVisitor() {
        let cleanedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedLastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCompany = company.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanedFirstName.isEmpty,
              !cleanedLastName.isEmpty,
              !cleanedCompany.isEmpty,
              !cleanedHost.isEmpty else {
            registrationMessage = "Please complete all required fields marked with * before registering."
            showRegistrationAlert = true
            return
        }

        let visitor = VisitorRecord(
            firstName: cleanedFirstName,
            lastName: cleanedLastName,
            company: cleanedCompany,
            host: cleanedHost,
            carRegistration: carRegistration.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )

        modelContext.insert(visitor)
        saveContext()

        firstName = ""
        lastName = ""
        company = ""
        host = ""
        carRegistration = ""

        registrationMessage = "Visitor \(visitor.fullName) registered successfully."
        showRegistrationAlert = true
    }

    private func confirmCheckoutCandidate() {
        guard let candidate = visitor(with: checkoutCandidateID) else { return }
        checkout(visitor: candidate, method: "I'm Leaving")
        checkoutCandidateID = nil
    }

    private func checkout(visitor: VisitorRecord, method: String) {
        guard visitor.isActive else { return }
        visitor.checkedOutAt = Date()
        visitor.checkoutMethod = method
        saveContext()
    }

    private func exportCSV() {
        let csv = VisitorCSVService.csvString(from: visitors)
        do {
            exportURL = try VisitorFileService.writeExportCSV(csv)
        } catch {
            settingsMessage = "CSV export failed: \(error.localizedDescription)"
            showSettingsAlert = true
        }
    }

    private func createManualBackup() {
        do {
            backupURL = try BackupService.createBackup(
                visitors: visitors,
                retentionDays: backupRetentionDays,
                forceNewFile: true
            )
            settingsMessage = "Backup created in Documents/VisitorBackups."
            showSettingsAlert = true
        } catch {
            settingsMessage = "Backup failed: \(error.localizedDescription)"
            showSettingsAlert = true
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            settingsMessage = "Import failed: \(error.localizedDescription)"
            showSettingsAlert = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let data = try Data(contentsOf: url)
                guard let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                    settingsMessage = "Could not read CSV text."
                    showSettingsAlert = true
                    return
                }

                let preview = VisitorCSVService.previewImport(csv: content, existing: visitors)
                if preview.rowsReadyToImport == 0 && preview.parseFailures.isEmpty {
                    settingsMessage = "No importable rows found."
                    showSettingsAlert = true
                } else {
                    importPreview = preview
                }
            } catch {
                settingsMessage = "Import failed: \(error.localizedDescription)"
                showSettingsAlert = true
            }
        }
    }

    private func applyImport(_ preview: ImportPreview) {
        var importedCount = 0

        for row in preview.rows where !row.isDuplicate {
            modelContext.insert(
                VisitorRecord(
                    id: row.seed.id,
                    firstName: row.seed.firstName,
                    lastName: row.seed.lastName,
                    company: row.seed.company,
                    host: row.seed.host,
                    carRegistration: row.seed.carRegistration,
                    checkInAt: row.seed.checkInAt,
                    checkedOutAt: row.seed.checkedOutAt,
                    checkoutMethod: row.seed.checkoutMethod,
                    createdAt: Date()
                )
            )
            importedCount += 1
        }

        saveContext()
        settingsMessage = "Import complete. Added \(importedCount), skipped duplicates \(preview.duplicateRows), parse failures \(preview.parseFailures.count)."
        showSettingsAlert = true
    }

    private func runMaintenance() {
        if autoCheckoutEnabled {
            autoCheckoutPreviousDayActiveVisitors()
        }

        if autoBackupEnabled {
            do {
                _ = try BackupService.createBackup(
                    visitors: visitors,
                    retentionDays: backupRetentionDays,
                    forceNewFile: false
                )
            } catch {
                settingsMessage = "Automatic backup failed: \(error.localizedDescription)"
                showSettingsAlert = true
            }
        }
    }

    private func autoCheckoutPreviousDayActiveVisitors() {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let isWeekday = (2...6).contains(weekday)
        guard isWeekday else { return }

        let startOfToday = calendar.startOfDay(for: now)
        var changed = false

        for visitor in activeVisitors where visitor.checkInAt < startOfToday {
            visitor.checkedOutAt = startOfToday
            visitor.checkoutMethod = "Auto Weekday Checkout"
            changed = true
        }

        if changed {
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            settingsMessage = "Failed to save records: \(error.localizedDescription)"
            showSettingsAlert = true
        }
    }
}

private enum AppTab: Hashable {
    case register
    case leaving
    case signInBook
    case fireRollCall
    case settings

    var isProtected: Bool {
        switch self {
        case .signInBook, .fireRollCall, .settings:
            return true
        case .register, .leaving:
            return false
        }
    }

    var title: String {
        switch self {
        case .register:
            return "Register"
        case .leaving:
            return "I'm Leaving"
        case .signInBook:
            return "Sign In Book"
        case .fireRollCall:
            return "Fire Roll Call"
        case .settings:
            return "Settings"
        }
    }
}

private enum SignInScope: String, CaseIterable, Identifiable {
    case active = "Active"
    case archived = "Archived"
    case all = "All"

    var id: String { rawValue }
}

private struct PinEntrySheet: View {
    let tabTitle: String
    @Binding var pinInput: String
    let errorMessage: String
    let onCancel: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Protected Area") {
                    Text("Enter PIN to access \(tabTitle).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SecureField("PIN", text: $pinInput)
                        .keyboardType(.numberPad)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("PIN Required")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Unlock", action: onUnlock)
                        .disabled(pinInput.isEmpty)
                }
            }
        }
    }
}

private struct ImportPreviewSheet: View {
    let preview: ImportPreview
    let onImport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LabeledContent("Rows ready", value: "\(preview.rowsReadyToImport)")
                    LabeledContent("Duplicates skipped", value: "\(preview.duplicateRows)")
                    LabeledContent("Parse failures", value: "\(preview.parseFailures.count)")
                }

                Section("Preview") {
                    if preview.rows.isEmpty {
                        Text("No parsed rows")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(preview.rows.prefix(20)) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Row \(row.rowNumber): \(row.seed.firstName) \(row.seed.lastName)")
                                    .font(.headline)
                                Text("\(row.seed.company) • Host: \(row.seed.host)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if row.isDuplicate {
                                    Text("Duplicate (will skip)")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }

                if !preview.parseFailures.isEmpty {
                    Section("Parse Failures") {
                        ForEach(preview.parseFailures.prefix(20)) { failure in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Row \(failure.rowNumber)")
                                    .font(.headline)
                                Text(failure.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import Preview")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: onImport)
                        .disabled(preview.rowsReadyToImport == 0)
                }
            }
        }
    }
}

private struct ImportPreview: Identifiable {
    let id = UUID()
    let rows: [ImportRowPreview]
    let parseFailures: [ImportFailure]

    var duplicateRows: Int {
        rows.filter { $0.isDuplicate }.count
    }

    var rowsReadyToImport: Int {
        rows.filter { !$0.isDuplicate }.count
    }
}

private struct ImportRowPreview: Identifiable {
    let id = UUID()
    let rowNumber: Int
    let seed: VisitorSeed
    let isDuplicate: Bool
}

private struct ImportFailure: Identifiable {
    let id = UUID()
    let rowNumber: Int
    let reason: String
}

private struct VisitorSeed {
    let id: UUID
    let firstName: String
    let lastName: String
    let company: String
    let host: String
    let carRegistration: String
    let checkInAt: Date
    let checkedOutAt: Date?
    let checkoutMethod: String

    var duplicateKey: String {
        let dayKey = VisitorCSVService.dayFormatter.string(from: checkInAt)
        return "\(firstName.lowercased())|\(lastName.lowercased())|\(company.lowercased())|\(dayKey)"
    }
}

private enum VisitorCSVService {
    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func csvString(from visitors: [VisitorRecord]) -> String {
        let header = [
            "id",
            "first_name",
            "last_name",
            "company",
            "host",
            "car_registration",
            "check_in_at",
            "checked_out_at",
            "checkout_method"
        ]

        let rows = visitors.map { visitor in
            [
                visitor.id.uuidString,
                visitor.firstName,
                visitor.lastName,
                visitor.company,
                visitor.host,
                visitor.carRegistration,
                isoFormatter.string(from: visitor.checkInAt),
                visitor.checkedOutAt.map { isoFormatter.string(from: $0) } ?? "",
                visitor.checkoutMethod
            ]
            .map { field in
                var escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
                    escaped = "\"\(escaped)\""
                }
                return escaped
            }
            .joined(separator: ",")
        }

        return ([header.joined(separator: ",")] + rows).joined(separator: "\n")
    }

    static func previewImport(csv: String, existing: [VisitorRecord]) -> ImportPreview {
        let rows = parseCSVRows(csv)
        guard !rows.isEmpty else {
            return ImportPreview(rows: [], parseFailures: [ImportFailure(rowNumber: 1, reason: "No rows found in CSV")])
        }

        let header = rows[0].map {
            $0
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .replacingOccurrences(of: "-", with: "_")
                .replacingOccurrences(of: " ", with: "_")
        }
        var previews: [ImportRowPreview] = []
        var failures: [ImportFailure] = []

        var seenDuplicateKeys = Set(existing.map { existing in
            let day = dayFormatter.string(from: existing.checkInAt)
            return "\(existing.firstName.lowercased())|\(existing.lastName.lowercased())|\(existing.company.lowercased())|\(day)"
        })

        for (index, row) in rows.dropFirst().enumerated() {
            let rowNumber = index + 2
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }

            do {
                let seed = try makeSeed(row: row, header: header, rowNumber: rowNumber)
                let isDuplicate = seenDuplicateKeys.contains(seed.duplicateKey)
                if !isDuplicate {
                    seenDuplicateKeys.insert(seed.duplicateKey)
                }

                previews.append(
                    ImportRowPreview(
                        rowNumber: rowNumber,
                        seed: seed,
                        isDuplicate: isDuplicate
                    )
                )
            } catch {
                failures.append(
                    ImportFailure(
                        rowNumber: rowNumber,
                        reason: error.localizedDescription
                    )
                )
            }
        }

        return ImportPreview(rows: previews, parseFailures: failures)
    }

    private static func makeSeed(row: [String], header: [String], rowNumber: Int) throws -> VisitorSeed {
        let values = Dictionary(uniqueKeysWithValues: zip(header, row + Array(repeating: "", count: max(0, header.count - row.count))))

        let fullName = value(from: values, keys: ["name", "full_name"])
        let splitName = splitName(fullName)

        let firstName = nonEmpty(
            value(from: values, keys: ["first_name", "firstname", "first"]),
            fallback: splitName.first,
            defaultValue: "Unknown"
        )

        let lastName = nonEmpty(
            value(from: values, keys: ["last_name", "lastname", "surname", "family_name", "familyname"]),
            fallback: splitName.last,
            defaultValue: "Visitor"
        )

        let company = nonEmpty(
            value(from: values, keys: ["company", "organisation", "organization"]),
            defaultValue: "Unknown Company"
        )

        let host = nonEmpty(
            value(from: values, keys: ["host", "host_name", "meeting_with"]),
            defaultValue: "Unknown Host"
        )

        let carReg = nonEmpty(
            value(from: values, keys: ["car_registration", "car_reg", "vehicle", "registration"]),
            defaultValue: ""
        )

        let checkInRaw = value(from: values, keys: ["check_in_at", "checkin", "check_in", "arrival", "checked_in_at"])
        let checkOutRaw = value(from: values, keys: ["checked_out_at", "checkout", "check_out", "departure"])
        let checkoutMethod = nonEmpty(
            value(from: values, keys: ["checkout_method", "exit_method"]),
            defaultValue: ""
        )

        let checkInAt = try parseDate(checkInRaw, defaultDate: Date(), rowNumber: rowNumber, fieldName: "check_in_at")
        let checkedOutAt = try parseOptionalDate(checkOutRaw, rowNumber: rowNumber, fieldName: "checked_out_at")

        let id = UUID(uuidString: value(from: values, keys: ["id"])) ?? UUID()

        return VisitorSeed(
            id: id,
            firstName: firstName,
            lastName: lastName,
            company: company,
            host: host,
            carRegistration: carReg,
            checkInAt: checkInAt,
            checkedOutAt: checkedOutAt,
            checkoutMethod: checkoutMethod
        )
    }

    private static func parseDate(_ raw: String, defaultDate: Date, rowNumber: Int, fieldName: String) throws -> Date {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return defaultDate
        }
        if let parsed = parseDateString(trimmed) {
            return parsed
        }
        throw ImportError.message("Invalid date for \(fieldName) at row \(rowNumber): \(raw)")
    }

    private static func parseOptionalDate(_ raw: String, rowNumber: Int, fieldName: String) throws -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        if let parsed = parseDateString(trimmed) {
            return parsed
        }
        throw ImportError.message("Invalid date for \(fieldName) at row \(rowNumber): \(raw)")
    }

    private static func parseDateString(_ value: String) -> Date? {
        if let iso = isoFormatter.date(from: value) {
            return iso
        }

        let fallbackFormats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "MM/dd/yyyy HH:mm",
            "yyyy-MM-dd"
        ]

        for format in fallbackFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private static func value(from values: [String: String], keys: [String]) -> String {
        for key in keys {
            if let value = values[normalizeHeader(key)] {
                return value
            }
        }
        return ""
    }

    private static func normalizeHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func splitName(_ fullName: String) -> (first: String, last: String) {
        let parts = fullName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)

        guard !parts.isEmpty else {
            return ("", "")
        }

        if parts.count == 1 {
            return (parts[0], "")
        }

        return (parts.dropLast().joined(separator: " "), parts.last ?? "")
    }

    private static func nonEmpty(_ primary: String, fallback: String = "", defaultValue: String) -> String {
        let cleanedPrimary = primary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedPrimary.isEmpty {
            return cleanedPrimary
        }

        let cleanedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedFallback.isEmpty {
            return cleanedFallback
        }

        return defaultValue
    }

    private static func csvEscaped(_ value: String) -> String {
        var escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }

    private static func parseCSVRows(_ csv: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        let characters = Array(csv)
        var index = 0

        while index < characters.count {
            let character = characters[index]

            if insideQuotes {
                if character == "\"" {
                    if index + 1 < characters.count && characters[index + 1] == "\"" {
                        currentField.append("\"")
                        index += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    currentField.append(character)
                }
            } else {
                switch character {
                case "\"":
                    insideQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                case "\r":
                    break
                default:
                    currentField.append(character)
                }
            }
            index += 1
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
    }
}

private enum VisitorFileService {
    static func writeExportCSV(_ csv: String) throws -> URL {
        let fileName = "VisitorExport-\(timestampString()).csv"
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csv.write(to: destination, atomically: true, encoding: .utf8)
        return destination
    }

    private static func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private enum BackupService {
    private static let lastBackupKey = "lastAutomaticBackupDay"

    static func createBackup(visitors: [VisitorRecord], retentionDays: Int, forceNewFile: Bool) throws -> URL {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let defaults = UserDefaults.standard

        if !forceNewFile,
           let lastBackup = defaults.object(forKey: lastBackupKey) as? Date,
           calendar.isDate(lastBackup, inSameDayAs: today) {
            try cleanupOldBackups(retentionDays: retentionDays)
            return lastBackupURL() ?? backupDirectory().appendingPathComponent(backupFileName(for: today))
        }

        try FileManager.default.createDirectory(at: backupDirectory(), withIntermediateDirectories: true)

        let fileURL = backupDirectory().appendingPathComponent(backupFileName(for: today))
        let csv = VisitorCSVService.csvString(from: visitors)
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)

        defaults.set(today, forKey: lastBackupKey)
        try cleanupOldBackups(retentionDays: retentionDays)
        return fileURL
    }

    private static func cleanupOldBackups(retentionDays: Int) throws {
        let fileManager = FileManager.default
        let directory = backupDirectory()
        guard fileManager.fileExists(atPath: directory.path) else { return }

        let files = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast

        for file in files where file.lastPathComponent.hasPrefix("VisitorBackup-") {
            let values = try file.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values.contentModificationDate ?? .distantPast
            if modified < cutoff {
                try fileManager.removeItem(at: file)
            }
        }
    }

    private static func backupDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent("VisitorBackups", isDirectory: true)
    }

    private static func backupFileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "VisitorBackup-\(formatter.string(from: date)).csv"
    }

    private static func lastBackupURL() -> URL? {
        let directory = backupDirectory()
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return files
            .filter { $0.lastPathComponent.hasPrefix("VisitorBackup-") }
            .sorted { lhs, rhs in
                let leftDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let rightDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                return leftDate > rightDate
            }
            .first
    }
}

private enum ImportError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            return message
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: VisitorRecord.self, inMemory: true)
}
