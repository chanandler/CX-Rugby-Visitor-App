import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Charts
import UIKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: [SortDescriptor(\VisitorRecord.checkInAt, order: .reverse)]) private var visitors: [VisitorRecord]

    @AppStorage("autoCheckoutEnabled") private var autoCheckoutEnabled = true
    @AppStorage("autoBackupEnabled") private var autoBackupEnabled = true
    @AppStorage("backupRetentionDays") private var backupRetentionDays = 30
    @AppStorage("pinFailureCount") private var pinFailureCount = 0
    @AppStorage("pinLockoutUntilEpoch") private var pinLockoutUntilEpoch = 0.0

    @State private var selectedTab: AppTab = .register
    @State private var pendingProtectedArea: ProtectedArea?
    @State private var unlockedProtectedAreas: Set<ProtectedArea> = []
    @State private var storedPin: String? = PinSecurityService.loadPIN()
    @State private var pinInput = ""
    @State private var pinErrorMessage = ""
    @State private var showPinEntrySheet = false
    @State private var showPinSetupSheet = false
    @State private var showSettingsSheet = false
    @State private var newPinInput = ""
    @State private var setupPinInput = ""
    @State private var confirmSetupPinInput = ""
    @State private var pinSetupErrorMessage = ""
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
    @State private var showThankYouPopup = false
    @State private var thankYouPopupToken = UUID()
    @State private var didAttemptRegistration = false

    @State private var leavingSearch = ""
    @State private var checkoutCandidateID: UUID?
    @State private var showCheckoutConfirmation = false

    @State private var signInScope: SignInScope = .active
    @State private var exportURL: URL?

    @State private var backupURL: URL?
    @State private var settingsMessage = ""
    @State private var showSettingsAlert = false
    @State private var rollCallMessage = ""
    @State private var showRollCallAlert = false

    @State private var showingImporter = false
    @State private var importPreview: ImportPreview?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            currentTabContent

            bottomLauncherButtons
                .padding(.leading, 16)
                .padding(.bottom, 14)

            if showThankYouPopup {
                thankYouPopupView
                    .zIndex(1)
            }
        }
        .onAppear {
            markUserActivity()
            runMaintenance()
            if storedPin == nil {
                showPinSetupSheet = true
            }
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
            DragGesture(minimumDistance: 0).onEnded { _ in
                markUserActivity()
            }
        )
        .alert("Registration", isPresented: $showRegistrationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(registrationMessage)
        }
        .alert("Confirm Leaving", isPresented: $showCheckoutConfirmation) {
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
        .alert("Fire Roll Call", isPresented: $showRollCallAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(rollCallMessage)
        }
        .sheet(isPresented: $showPinEntrySheet) {
            PinEntrySheet(
                tabTitle: pendingProtectedArea?.title ?? "Protected Area",
                pinInput: $pinInput,
                errorMessage: pinErrorMessage,
                isUnlockDisabled: lockoutRemainingSeconds != nil,
                onCancel: {
                    pendingProtectedArea = nil
                    pinInput = ""
                    pinErrorMessage = ""
                    showPinEntrySheet = false
                },
                onUnlock: verifyPinAndUnlock
            )
        }
        .sheet(isPresented: $showPinSetupSheet) {
            PinSetupSheet(
                pinInput: $setupPinInput,
                confirmPinInput: $confirmSetupPinInput,
                errorMessage: pinSetupErrorMessage,
                canCancel: storedPin != nil,
                onCancel: {
                    setupPinInput = ""
                    confirmSetupPinInput = ""
                    pinSetupErrorMessage = ""
                    showPinSetupSheet = false
                },
                onSave: configurePinFromSetup
            )
        }
        .sheet(isPresented: $showSettingsSheet) {
            settingsTab
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

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .register:
            welcomeAndRegistrationTab
        case .leaving:
            leavingTab
        case .signInBook:
            signInBookTab
        case .fireRollCall:
            fireRollCallTab
        }
    }

    private var welcomeAndRegistrationTab: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ZStack {
                        Image("Rugby_Cement_Plant")
                            .resizable()
                            .scaledToFill()
                            .frame(height: 320)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .overlay(Color.black.opacity(0.25))
                            .overlay(
                                LinearGradient(
                                    colors: [cemexBlue.opacity(0.62), cemexBlue.opacity(0.86)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        VStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white)
                                .frame(width: 228, height: 92)
                                .overlay {
                                    Image("cemex_logo")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                }

                            Text("Welcome to Rugby Cement Plant")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text("Please sign in below")
                                .font(.system(size: 24, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                        }
                        .padding(.horizontal, 24)
                    }
                    .frame(height: 320)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 14) {
                            registrationField(
                                title: "FIRST NAME",
                                placeholder: "First name",
                                text: $firstName,
                                isRequired: true,
                                error: firstNameError
                            )

                            registrationField(
                                title: "LAST NAME",
                                placeholder: "Last name",
                                text: $lastName,
                                isRequired: true,
                                error: lastNameError
                            )
                        }

                        HStack(spacing: 14) {
                            registrationField(
                                title: "COMPANY",
                                placeholder: "Company",
                                text: $company,
                                isRequired: true,
                                error: companyError
                            )

                            registrationField(
                                title: "VISITING",
                                placeholder: "Who are you visiting",
                                text: $host,
                                isRequired: true,
                                error: hostError
                            )
                        }

                        HStack(spacing: 14) {
                            registrationField(
                                title: "CAR REGISTRATION",
                                placeholder: "Leave blank if not applicable",
                                text: $carRegistration,
                                isRequired: false,
                                error: nil,
                                normalization: .uppercase
                            )
                            Color.clear
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            registerVisitor()
                        } label: {
                            Label("Register", systemImage: "person.badge.plus")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(cemexBlue, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 14) {
                            Button {
                                selectedTab = .leaving
                            } label: {
                                Label("I'm Leaving", systemImage: "rectangle.portrait.and.arrow.right")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.orange, in: Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                selectedTab = .signInBook
                            } label: {
                                Label("Sign In Book", systemImage: "book.closed")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(cemexBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(red: 0.80, green: 0.84, blue: 0.90), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        HStack(spacing: 18) {
                            Text("Active: \(activeVisitors.count)")
                            Text("Total: \(visitors.count)")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                    .padding(22)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .padding(.horizontal, 32)
                    .offset(y: -40)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, -20)
            }
            .scrollIndicators(.hidden)
            .background(Color(red: 0.92, green: 0.93, blue: 0.96).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private var cemexBlue: Color {
        Color(red: 0.03, green: 0.23, blue: 0.61)
    }

    @ViewBuilder
    private func registrationField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        isRequired: Bool,
        error: String?,
        normalization: FieldTextNormalization = .titleCase
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(isRequired ? "\(title) *" : title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            CapitalizedUIKitTextField(placeholder: placeholder, text: text, normalization: normalization)
                .frame(height: 44)
                .padding(.horizontal, 12)
                .background(Color(red: 0.95, green: 0.95, blue: 0.97), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(error == nil ? Color.black.opacity(0.05) : .red.opacity(0.8), lineWidth: 1)
                )

            if let error {
                validationMessage(error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var leavingTab: some View {
        NavigationStack {
            List {
                Section {
                    Button("Back to Register <-") {
                        selectedTab = .register
                    }
                    .buttonStyle(.plain)
                    .font(.headline)
                    .foregroundStyle(cemexBlue)
                }

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
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var signInBookTab: some View {
        NavigationStack {
            List {
                Section {
                    Button("Back to Register <-") {
                        selectedTab = .register
                    }
                    .buttonStyle(.plain)
                    .font(.headline)
                    .foregroundStyle(cemexBlue)
                }

                Section {
                    HStack(spacing: 8) {
                        ForEach(SignInScope.allCases, id: \.self) { scope in
                            Button(scope.rawValue) {
                                signInScope = scope
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(signInScope == scope ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(signInScope == scope ? Color.accentColor : Color.gray.opacity(0.15))
                            )
                        }
                    }
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

                                if !visitor.isActive, visitor.checkoutMethod == "Fire Roll Call" {
                                    Text("Signed out via Fire Roll Call")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
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
                                    checkoutFromRollCall(visitor)
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
                            confirmAllOutFromRollCall()
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Section("Confirmed Out (\(rollCallConfirmedOutVisitors.count))") {
                    if rollCallConfirmedOutVisitors.isEmpty {
                        Text("No visitors confirmed out yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(rollCallConfirmedOutVisitors, id: \.id) { visitor in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(visitor.fullName)
                                    .font(.headline)
                                Text("\(visitor.company) • Host: \(visitor.host)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Confirmed out at \(visitor.checkedOutAt?.formatted(date: .omitted, time: .shortened) ?? "-")")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            .padding(.vertical, 2)
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

                Section("Analytics") {
                    NavigationLink("Open Analytics Dashboard") {
                        AnalyticsDashboardView(visitors: visitors)
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

    private var thankYouPopupView: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Thank you for visiting.")
                        .lineLimit(1)
                    Text("Have a safe journey")
                        .lineLimit(1)
                }
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.9)
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 30)
            .frame(width: 430, height: 300)
            .background(Color(red: 0.23, green: 0.77, blue: 0.35), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.24), radius: 12, y: 6)
        }
        .transition(.opacity.combined(with: .scale))
        .animation(.easeInOut(duration: 0.2), value: showThankYouPopup)
    }

    private var bottomLauncherButtons: some View {
        HStack(spacing: 10) {
            Button {
                openSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.black.opacity(0.65), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }
            .accessibilityLabel("Open Settings")

            Button {
                openFireRollCall()
            } label: {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.orange.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.65), lineWidth: 1))
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            }
            .accessibilityLabel("Open Fire Roll Call")
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

    private var rollCallConfirmedOutVisitors: [VisitorRecord] {
        let calendar = Calendar.current

        return visitors
            .filter { visitor in
                guard let checkedOutAt = visitor.checkedOutAt else { return false }
                guard visitor.checkoutMethod == "Fire Roll Call" else { return false }
                return calendar.isDateInToday(checkedOutAt)
            }
            .sorted { lhs, rhs in
                (lhs.checkedOutAt ?? .distantPast) > (rhs.checkedOutAt ?? .distantPast)
            }
    }

    private var checkoutConfirmationMessage: String {
        "Tap confirm if you are leaving."
    }

    private var firstNameError: String? {
        requiredFieldError(value: firstName, fieldLabel: "First name")
    }

    private var lastNameError: String? {
        requiredFieldError(value: lastName, fieldLabel: "Last name")
    }

    private var companyError: String? {
        requiredFieldError(value: company, fieldLabel: "Company")
    }

    private var hostError: String? {
        requiredFieldError(value: host, fieldLabel: "Visiting")
    }

    private func requiredFieldError(value: String, fieldLabel: String) -> String? {
        guard didAttemptRegistration else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(fieldLabel) is required." : nil
    }

    @ViewBuilder
    private func validationBorder(isError: Bool) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(isError ? Color.red : Color.clear, lineWidth: 1)
    }

    @ViewBuilder
    private func validationMessage(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
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
        guard scenePhase == .active, !unlockedProtectedAreas.isEmpty else { return }
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
        guard let protectedArea = newValue.protectedArea else {
            return
        }
        guard ensurePinConfigured() else {
            selectedTab = oldValue
            return
        }
        guard !unlockedProtectedAreas.contains(protectedArea) else {
            return
        }

        pendingProtectedArea = protectedArea
        pinInput = ""
        pinErrorMessage = ""
        selectedTab = oldValue
        showPinEntrySheet = true
    }

    private func verifyPinAndUnlock() {
        guard let pendingProtectedArea else { return }
        guard let storedPin else {
            showPinEntrySheet = false
            showPinSetupSheet = true
            return
        }

        if let remaining = lockoutRemainingSeconds {
            pinErrorMessage = "Too many attempts. Try again in \(remaining) seconds."
            return
        }

        if pinInput == storedPin {
            unlockedProtectedAreas = [.signInBook, .fireRollCall, .settings]
            self.pendingProtectedArea = nil
            pinInput = ""
            pinErrorMessage = ""
            showPinEntrySheet = false
            resetPinFailureState()
            switch pendingProtectedArea {
            case .signInBook:
                selectedTab = .signInBook
            case .fireRollCall:
                selectedTab = .fireRollCall
            case .settings:
                showSettingsSheet = true
            }
            markUserActivity()
        } else {
            registerFailedPinAttempt()
        }
    }

    private func relockProtectedAreas() {
        unlockedProtectedAreas.removeAll()
        pendingProtectedArea = nil
        pinInput = ""
        pinErrorMessage = ""
        showPinEntrySheet = false
        showSettingsSheet = false
        if selectedTab.isProtected {
            selectedTab = .register
        }
    }

    private func openSettings() {
        markUserActivity()
        guard ensurePinConfigured() else { return }
        if unlockedProtectedAreas.contains(.settings) {
            showSettingsSheet = true
            return
        }
        pendingProtectedArea = .settings
        pinInput = ""
        pinErrorMessage = ""
        showPinEntrySheet = true
    }

    private func openFireRollCall() {
        markUserActivity()
        selectedTab = .fireRollCall
    }

    private func updatePin() {
        let digitsOnly = newPinInput.filter { $0.isNumber }
        guard (4...8).contains(digitsOnly.count) else {
            settingsMessage = "PIN must be 4 to 8 digits."
            showSettingsAlert = true
            return
        }

        do {
            try PinSecurityService.savePIN(digitsOnly)
            storedPin = digitsOnly
            resetPinFailureState()
            newPinInput = ""
            settingsMessage = "PIN updated successfully."
            showSettingsAlert = true
        } catch {
            settingsMessage = "Could not update PIN: \(error.localizedDescription)"
            showSettingsAlert = true
        }
    }

    private var lockoutRemainingSeconds: Int? {
        let remaining = Int(ceil(pinLockoutUntilEpoch - Date().timeIntervalSince1970))
        return remaining > 0 ? remaining : nil
    }

    private func ensurePinConfigured() -> Bool {
        if storedPin == nil {
            showPinSetupSheet = true
            return false
        }
        return true
    }

    private func configurePinFromSetup() {
        let pin = setupPinInput.filter { $0.isNumber }
        let confirm = confirmSetupPinInput.filter { $0.isNumber }

        guard (4...8).contains(pin.count) else {
            pinSetupErrorMessage = "PIN must be 4 to 8 digits."
            return
        }
        guard pin == confirm else {
            pinSetupErrorMessage = "PIN values do not match."
            return
        }

        do {
            try PinSecurityService.savePIN(pin)
            storedPin = pin
            resetPinFailureState()
            setupPinInput = ""
            confirmSetupPinInput = ""
            pinSetupErrorMessage = ""
            showPinSetupSheet = false
            settingsMessage = "PIN configured successfully."
            showSettingsAlert = true
        } catch {
            pinSetupErrorMessage = "Could not save PIN: \(error.localizedDescription)"
        }
    }

    private func registerFailedPinAttempt() {
        pinFailureCount += 1

        let lockoutDuration: TimeInterval?
        if pinFailureCount >= 10 {
            lockoutDuration = 15 * 60
        } else if pinFailureCount >= 7 {
            lockoutDuration = 5 * 60
        } else if pinFailureCount >= 5 {
            lockoutDuration = 60
        } else {
            lockoutDuration = nil
        }

        if let lockoutDuration {
            pinLockoutUntilEpoch = Date().addingTimeInterval(lockoutDuration).timeIntervalSince1970
            pinErrorMessage = "Too many attempts. Try again in \(Int(lockoutDuration)) seconds."
        } else {
            pinErrorMessage = "Incorrect PIN. Please try again."
        }
    }

    private func resetPinFailureState() {
        pinFailureCount = 0
        pinLockoutUntilEpoch = 0
    }

    private func visitor(with id: UUID?) -> VisitorRecord? {
        guard let id else { return nil }
        return visitors.first(where: { $0.id == id })
    }

    private func registerVisitor() {
        didAttemptRegistration = true
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
        didAttemptRegistration = false

        registrationMessage = "Visitor \(visitor.fullName) registered successfully."
        showRegistrationAlert = true
    }

    private func confirmCheckoutCandidate() {
        guard let candidate = visitor(with: checkoutCandidateID) else { return }
        checkout(visitor: candidate, method: "I'm Leaving")
        checkoutCandidateID = nil
        presentThankYouAndReturnToRegister()
    }

    private func checkout(visitor: VisitorRecord, method: String) {
        guard visitor.isActive else { return }
        visitor.checkedOutAt = Date()
        visitor.checkoutMethod = method
        saveContext()
    }

    private func presentThankYouAndReturnToRegister() {
        thankYouPopupToken = UUID()
        let token = thankYouPopupToken
        showThankYouPopup = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            guard thankYouPopupToken == token else { return }
            showThankYouPopup = false
            selectedTab = .register
            leavingSearch = ""
        }
    }

    private func checkoutFromRollCall(_ visitor: VisitorRecord) {
        guard visitor.isActive else { return }
        visitor.checkedOutAt = Date()
        visitor.checkoutMethod = "Fire Roll Call"
        saveContext()
    }

    private func confirmAllOutFromRollCall() {
        let visitorsToCheckout = activeVisitors
        guard !visitorsToCheckout.isEmpty else {
            rollCallMessage = "There are no active visitors to confirm out."
            showRollCallAlert = true
            return
        }

        let now = Date()
        for visitor in visitorsToCheckout where visitor.isActive {
            visitor.checkedOutAt = now
            visitor.checkoutMethod = "Fire Roll Call"
        }
        saveContext()
        rollCallMessage = "Confirmed out \(visitorsToCheckout.count) visitor(s)."
        showRollCallAlert = true
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
                let data = try readImportData(from: url)
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

    private func readImportData(from url: URL) throws -> Data {
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
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
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) else {
            return
        }

        var changed = false

        for visitor in activeVisitors where visitor.checkInAt >= startOfYesterday && visitor.checkInAt < startOfToday {
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

    var isProtected: Bool {
        switch self {
        case .signInBook, .fireRollCall:
            return true
        case .register, .leaving:
            return false
        }
    }

    var protectedArea: ProtectedArea? {
        switch self {
        case .signInBook:
            return .signInBook
        case .fireRollCall:
            return .fireRollCall
        case .register, .leaving:
            return nil
        }
    }
}

private enum ProtectedArea: Hashable {
    case signInBook
    case fireRollCall
    case settings

    var title: String {
        switch self {
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
    let isUnlockDisabled: Bool
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
                        .disabled(pinInput.isEmpty || isUnlockDisabled)
                }
            }
        }
    }
}

private struct PinSetupSheet: View {
    @Binding var pinInput: String
    @Binding var confirmPinInput: String
    let errorMessage: String
    let canCancel: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Set PIN") {
                    Text("Set a 4 to 8 digit PIN to protect Sign In Book, Fire Roll Call, and Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SecureField("New PIN", text: $pinInput)
                        .keyboardType(.numberPad)
                    SecureField("Confirm PIN", text: $confirmPinInput)
                        .keyboardType(.numberPad)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("PIN Setup")
            .toolbar {
                if canCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(pinInput.isEmpty || confirmPinInput.isEmpty)
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

    var visitSignature: String {
        VisitorCSVService.visitSignature(
            firstName: firstName,
            lastName: lastName,
            company: company,
            host: host,
            checkInAt: checkInAt
        )
    }
}

private enum VisitorCSVService {
    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let isoFormatterWithoutFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let fallbackDateFormatters: [DateFormatter] = [
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm:ss",
        "MM/dd/yyyy HH:mm",
        "yyyy-MM-dd"
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

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

        let (header, dataRows, firstDataRowNumber) = resolveHeaderAndDataRows(rows)
        var previews: [ImportRowPreview] = []
        var failures: [ImportFailure] = []

        var seenRecordIDs = Set(existing.map(\.id))
        var seenVisitSignatures = Set(existing.map { existing in
            visitSignature(
                firstName: existing.firstName,
                lastName: existing.lastName,
                company: existing.company,
                host: existing.host,
                checkInAt: existing.checkInAt
            )
        })

        for (index, row) in dataRows.enumerated() {
            let rowNumber = firstDataRowNumber + index
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }

            do {
                let seed = try makeSeed(row: row, header: header, rowNumber: rowNumber)
                let isDuplicate = seenRecordIDs.contains(seed.id) || seenVisitSignatures.contains(seed.visitSignature)
                if !isDuplicate {
                    seenRecordIDs.insert(seed.id)
                    seenVisitSignatures.insert(seed.visitSignature)
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

        if let isoWithoutFractionalSeconds = isoFormatterWithoutFractionalSeconds.date(from: value) {
            return isoWithoutFractionalSeconds
        }

        for formatter in fallbackDateFormatters {
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

    nonisolated private static func normalizeHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func resolveHeaderAndDataRows(_ rows: [[String]]) -> ([String], [[String]], Int) {
        let firstRow = rows[0]
        if rowLooksLikeHeader(firstRow) {
            return (firstRow.map(normalizeHeader), Array(rows.dropFirst()), 2)
        }
        let includeID = likelyContainsIDColumn(rows)
        return (guessedHeader(forColumnCount: firstRow.count, includeID: includeID), rows, 1)
    }

    private static func rowLooksLikeHeader(_ row: [String]) -> Bool {
        let normalized = Set(row.map(normalizeHeader))
        let knownHeaders: Set<String> = [
            "id",
            "first_name",
            "last_name",
            "company",
            "host",
            "car_registration",
            "check_in_at",
            "checked_out_at",
            "checkout_method",
            "name",
            "full_name"
        ]
        return normalized.intersection(knownHeaders).count >= 2
    }

    private static func likelyContainsIDColumn(_ rows: [[String]]) -> Bool {
        let firstColumnSamples = rows
            .prefix(10)
            .compactMap { row in row.first?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard firstColumnSamples.count >= 2 else { return false }
        let uuidCount = firstColumnSamples.filter { UUID(uuidString: $0) != nil }.count
        return Double(uuidCount) / Double(firstColumnSamples.count) >= 0.8
    }

    private static func guessedHeader(forColumnCount count: Int, includeID: Bool) -> [String] {
        let withID = [
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

        let withoutID = [
            "first_name",
            "last_name",
            "company",
            "host",
            "car_registration",
            "check_in_at",
            "checked_out_at",
            "checkout_method"
        ]

        if includeID, count >= withID.count {
            return withID + (withID.count..<count).map { "column_\($0 + 1)" }
        }

        if !includeID, count >= withoutID.count {
            return withoutID + (withoutID.count..<count).map { "column_\($0 + 1)" }
        }

        if count == withoutID.count {
            return withoutID
        }

        if count < withoutID.count {
            return Array(withoutID.prefix(count))
        }

        return withoutID + (withoutID.count..<count).map { "column_\($0 + 1)" }
    }

    static func visitSignature(firstName: String, lastName: String, company: String, host: String, checkInAt: Date) -> String {
        let timestampKey = isoFormatter.string(from: checkInAt)
        return "\(firstName.lowercased())|\(lastName.lowercased())|\(company.lowercased())|\(host.lowercased())|\(timestampKey)"
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

private enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }
}

private struct AnalyticsBucket: Identifiable {
    let start: Date
    let label: String
    let total: Int
    let active: Int
    let checkedOut: Int

    var id: Date { start }
}

private struct AnalyticsDashboardView: View {
    let visitors: [VisitorRecord]
    @State private var period: AnalyticsPeriod = .week

    private var buckets: [AnalyticsBucket] {
        VisitorAnalyticsService.buckets(visitors: visitors, period: period)
    }

    private var totalVisitors: Int {
        buckets.reduce(0) { $0 + $1.total }
    }

    private var totalActive: Int {
        buckets.reduce(0) { $0 + $1.active }
    }

    private var totalCheckedOut: Int {
        buckets.reduce(0) { $0 + $1.checkedOut }
    }

    private var busiestBucket: AnalyticsBucket? {
        buckets.max { $0.total < $1.total }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Period", selection: $period) {
                    ForEach(AnalyticsPeriod.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    analyticsCard(title: "Total Visitors", value: "\(totalVisitors)", tint: .blue)
                    analyticsCard(title: "Currently Active", value: "\(totalActive)", tint: .green)
                    analyticsCard(title: "Checked Out", value: "\(totalCheckedOut)", tint: .orange)
                    analyticsCard(
                        title: "Peak \(period.rawValue)",
                        value: busiestBucket.map { "\($0.label) (\($0.total))" } ?? "No Data",
                        tint: .purple
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Visitor Trends")
                        .font(.headline)

                    if buckets.allSatisfy({ $0.total == 0 }) {
                        Text("No visitor activity for this period.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 30)
                    } else {
                        Chart {
                            ForEach(buckets) { bucket in
                                BarMark(
                                    x: .value("Bucket", bucket.label),
                                    y: .value("Visitors", bucket.total)
                                )
                                .foregroundStyle(.blue.gradient)
                            }

                            ForEach(buckets) { bucket in
                                LineMark(
                                    x: .value("Bucket", bucket.label),
                                    y: .value("Active", bucket.active)
                                )
                                .foregroundStyle(.green)
                                .symbol(Circle())
                            }
                        }
                        .frame(height: 260)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .navigationTitle("Analytics")
    }

    @ViewBuilder
    private func analyticsCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

private enum VisitorAnalyticsService {
    static func buckets(visitors: [VisitorRecord], period: AnalyticsPeriod, now: Date = Date(), calendar: Calendar = .current) -> [AnalyticsBucket] {
        guard let interval = periodInterval(for: period, now: now, calendar: calendar) else { return [] }
        let starts = bucketStarts(for: period, interval: interval, calendar: calendar)

        var totalByStart: [Date: Int] = [:]
        var activeByStart: [Date: Int] = [:]
        var checkedOutByStart: [Date: Int] = [:]

        for visitor in visitors where interval.contains(visitor.checkInAt) {
            let start = bucketStart(for: visitor.checkInAt, period: period, calendar: calendar)
            totalByStart[start, default: 0] += 1
            if visitor.isActive {
                activeByStart[start, default: 0] += 1
            } else {
                checkedOutByStart[start, default: 0] += 1
            }
        }

        return starts.map { start in
            AnalyticsBucket(
                start: start,
                label: bucketLabel(for: start, period: period),
                total: totalByStart[start, default: 0],
                active: activeByStart[start, default: 0],
                checkedOut: checkedOutByStart[start, default: 0]
            )
        }
    }

    private static func periodInterval(for period: AnalyticsPeriod, now: Date, calendar: Calendar) -> DateInterval? {
        switch period {
        case .day:
            return calendar.dateInterval(of: .day, for: now)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .month:
            return calendar.dateInterval(of: .month, for: now)
        case .year:
            return calendar.dateInterval(of: .year, for: now)
        }
    }

    private static func bucketStarts(for period: AnalyticsPeriod, interval: DateInterval, calendar: Calendar) -> [Date] {
        switch period {
        case .day:
            return (0..<24).compactMap { hour in
                calendar.date(byAdding: .hour, value: hour, to: interval.start)
            }
        case .week:
            return (0..<7).compactMap { day in
                calendar.date(byAdding: .day, value: day, to: interval.start)
            }
        case .month:
            let dayCount = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
            return (0..<dayCount).compactMap { day in
                calendar.date(byAdding: .day, value: day, to: interval.start)
            }
        case .year:
            return (0..<12).compactMap { month in
                calendar.date(byAdding: .month, value: month, to: interval.start)
            }
        }
    }

    private static func bucketStart(for date: Date, period: AnalyticsPeriod, calendar: Calendar) -> Date {
        switch period {
        case .day:
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            return calendar.date(from: components) ?? date
        case .week, .month:
            return calendar.startOfDay(for: date)
        case .year:
            let components = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: components) ?? date
        }
    }

    private static func bucketLabel(for date: Date, period: AnalyticsPeriod) -> String {
        switch period {
        case .day:
            return hourFormatter.string(from: date)
        case .week:
            return weekdayFormatter.string(from: date)
        case .month:
            return monthDayFormatter.string(from: date)
        case .year:
            return monthFormatter.string(from: date)
        }
    }

    private static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
}

enum FieldTextNormalization {
    case titleCase
    case uppercase

    var autocapitalizationType: UITextAutocapitalizationType {
        switch self {
        case .titleCase:
            return .words
        case .uppercase:
            return .allCharacters
        }
    }

    func normalize(_ value: String) -> String {
        switch self {
        case .titleCase:
            return value.localizedCapitalized
        case .uppercase:
            return value.uppercased()
        }
    }
}

struct CapitalizedUIKitTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let normalization: FieldTextNormalization

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField(frame: .zero)
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.placeholder = placeholder
        textField.autocapitalizationType = normalization.autocapitalizationType
        textField.autocorrectionType = .yes
        textField.spellCheckingType = .yes
        textField.keyboardType = .default
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange(_:)), for: .editingChanged)
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, normalization: normalization)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private var text: Binding<String>
        private let normalization: FieldTextNormalization

        init(text: Binding<String>, normalization: FieldTextNormalization) {
            self.text = text
            self.normalization = normalization
        }

        @objc func textDidChange(_ textField: UITextField) {
            let rawText = textField.text ?? ""
            let normalizedText = normalization.normalize(rawText)

            if normalizedText != rawText {
                textField.text = normalizedText
            }

            text.wrappedValue = normalizedText
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: VisitorRecord.self, inMemory: true)
}
