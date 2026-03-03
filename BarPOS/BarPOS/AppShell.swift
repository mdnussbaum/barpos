import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case register, history, admin
    var id: String { rawValue }
    var title: String {
        switch self {
        case .register:  return "Register"
        case .history:   return "History"
        case .admin:     return "Admin"
        }
    }
    var systemImage: String {
        switch self {
        case .register:  return "creditcard"
        case .history:   return "clock.arrow.circlepath"
        case .admin:     return "gearshape"
        }
    }
}

struct AppShell: View {
    @EnvironmentObject var vm: InventoryVM
    @State private var section: MainSection = .register

    // Settings
    @State private var showingSettings = false
    
    // Admin PIN Protection
    @State private var showingAdminPINPrompt = false
    @State private var pendingAdminAccess = false

    // Auto-lock timer state
    @State private var lastActivityDate: Date = Date()
    @State private var showingLockWarning: Bool = false
    @State private var lockWarningCountdown: Int = 30
    @State private var lockWarningTimer: Timer? = nil
    @State private var inactivityTimer: Timer? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Auto-lock warning banner
                if showingLockWarning && section == .admin && vm.isAdminUnlocked {
                    HStack {
                        Image(systemName: "lock.trianglebadge.exclamationmark")
                            .foregroundStyle(.orange)
                        Text("Admin locking in \(lockWarningCountdown)s due to inactivity")
                            .font(.footnote)
                            .foregroundStyle(.primary)
                        Spacer()
                        Button("Stay") {
                            resetAutoLockTimer()
                        }
                        .font(.footnote.bold())
                        .foregroundStyle(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.15))
                    .overlay(alignment: .bottom) {
                        Divider()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Picker("Section", selection: $section) {
                    ForEach(MainSection.allCases) { s in
                        Label(s.title, systemImage: s.systemImage).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .zIndex(1000)
                .onChange(of: section) { oldValue, newValue in
                    handleSectionChange(from: oldValue, to: newValue)
                }

                Group {
                    switch section {
                    case .register:
                        RegisterView().environmentObject(vm)
                    case .history:
                        HistoryView().environmentObject(vm)
                    case .admin:
                        if vm.isAdminUnlocked {
                            AdminView().environmentObject(vm)
                        } else {
                            // Show locked placeholder
                            adminLockedPlaceholder
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.2), value: showingLockWarning)
            .navigationTitle(section == .admin ? section.title : "")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if section == .register {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet().environmentObject(vm)
            }
            .sheet(isPresented: $showingAdminPINPrompt) {
                AdminPINPromptView(
                    isPresented: $showingAdminPINPrompt,
                    onSuccess: {
                        pendingAdminAccess = false
                        resetAutoLockTimer()
                    },
                    onCancel: {
                        // Go back to previous section
                        section = .register
                        pendingAdminAccess = false
                    }
                )
                .environmentObject(vm)
            }
        }
        .onAppear {
            vm.loadState()
            vm.ensureAtLeastOneTab()
        }
        .onChange(of: vm.isAdminUnlocked) { _, isUnlocked in
            if isUnlocked {
                startInactivityTimer()
            } else {
                stopAutoLockTimers()
            }
        }
        .onChange(of: section) { _, newSection in
            if newSection == .admin && vm.isAdminUnlocked {
                resetAutoLockTimer()
            } else if newSection != .admin {
                stopAutoLockTimers()
            }
        }
        .onChange(of: vm.autoLockTimeout) { _, _ in
            if section == .admin && vm.isAdminUnlocked {
                resetAutoLockTimer()
            }
        }
    }
    
    // MARK: - Auto-Lock Timer Logic

    private func startInactivityTimer() {
        stopAutoLockTimers()
        lastActivityDate = Date()
        let timeoutSeconds = Double(vm.autoLockTimeout) * 60.0
        let warningThreshold = 30.0

        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(lastActivityDate)
            let remaining = timeoutSeconds - elapsed

            if remaining <= 0 {
                // Lock now
                lockAdminNow()
            } else if remaining <= warningThreshold && !showingLockWarning {
                // Show warning
                withAnimation {
                    showingLockWarning = true
                }
                startLockWarningCountdown(seconds: Int(remaining))
            }
        }
    }

    private func startLockWarningCountdown(seconds: Int) {
        lockWarningCountdown = max(1, seconds)
        lockWarningTimer?.invalidate()
        lockWarningTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if lockWarningCountdown > 1 {
                lockWarningCountdown -= 1
            }
        }
    }

    private func lockAdminNow() {
        stopAutoLockTimers()
        vm.lockAdmin()
        if section == .admin {
            section = .register
        }
    }

    func resetAutoLockTimer() {
        lastActivityDate = Date()
        if showingLockWarning {
            withAnimation {
                showingLockWarning = false
            }
            lockWarningTimer?.invalidate()
            lockWarningTimer = nil
        }
        // Restart inactivity timer if admin is unlocked
        if section == .admin && vm.isAdminUnlocked {
            startInactivityTimer()
        }
    }

    private func stopAutoLockTimers() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        lockWarningTimer?.invalidate()
        lockWarningTimer = nil
        showingLockWarning = false
    }
    
    // MARK: - Helper Methods
    
    private func handleSectionChange(from oldValue: MainSection, to newValue: MainSection) {
        // If switching to Admin and not unlocked, show PIN prompt
        if newValue == .admin && !vm.isAdminUnlocked {
            pendingAdminAccess = true
            showingAdminPINPrompt = true
        }
    }
    
    // MARK: - Admin Locked Placeholder
    
    @ViewBuilder
    private var adminLockedPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Admin Access Required")
                .font(.title2)
                .bold()
            Text("Enter the manager PIN to access admin features.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func placeholder(icon: String, title: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 48)).foregroundStyle(.secondary)
            Text(title).font(.title2).bold()
            Text("Coming soon.").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
// MARK: - Admin PIN Prompt View

struct AdminPINPromptView: View {
    @EnvironmentObject var vm: InventoryVM
    @Binding var isPresented: Bool
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    @State private var pinInput: String = ""
    @State private var errorMessage: String = ""
    @FocusState private var isPINFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)
                
                Text("Admin Access")
                    .font(.title)
                    .bold()
                
                Text("Enter the manager PIN to access admin features")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    SecureField("Enter PIN", text: $pinInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .focused($isPINFocused)
                        .onChange(of: pinInput) { _, _ in
                            errorMessage = ""
                        }
                        .onSubmit {
                            attemptUnlock()
                        }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 40)
                
                Button(action: attemptUnlock) {
                    Text("Unlock")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pinInput.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(pinInput.isEmpty)
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        onCancel()
                    }
                }
            }
            .onAppear {
                isPINFocused = true
            }
        }
    }
    
    private func attemptUnlock() {
        let success = vm.unlockAdmin(with: pinInput)
        if success {
            isPresented = false
            onSuccess()
            pinInput = ""
        } else {
            errorMessage = "Incorrect PIN. Please try again."
            pinInput = ""
            // Add a slight shake animation effect with haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}

#Preview {
    AppShell()
        .environmentObject(InventoryVM())
}

