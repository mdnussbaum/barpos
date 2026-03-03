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

                Group {
                    switch section {
                    case .register:
                        RegisterView().environmentObject(vm)
                    case .history:
                        HistoryView().environmentObject(vm)
                    case .admin:
                        AdminView().environmentObject(vm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.easeInOut(duration: 0.2), value: showingLockWarning)
            .navigationTitle(section == .admin ? section.title : "")
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
                lockAdminNow()
            } else if remaining <= warningThreshold && !showingLockWarning {
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
}

#Preview {
    AppShell()
        .environmentObject(InventoryVM())
}
