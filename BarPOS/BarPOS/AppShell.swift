import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case register, history, inventory, admin
    var id: String { rawValue }
    var title: String {
        switch self {
        case .register:  return "Register"
        case .history:   return "History"
        case .inventory: return "Inventory"
        case .admin:     return "Admin"
        }
    }
    var systemImage: String {
        switch self {
        case .register:  return "creditcard"
        case .history:   return "clock.arrow.circlepath"
        case .inventory: return "shippingbox"
        case .admin:     return "gearshape"
        }
    }
}

struct AppShell: View {
    @EnvironmentObject var vm: InventoryVM
    @State private var section: MainSection = .register

    // Settings & PIN
    @State private var showingSettings = false
    @State private var showPINSheet = false
    @State private var pinText = ""
    @State private var pinError = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Section", selection: $section) {
                    ForEach(MainSection.allCases) { s in
                        Label(s.title, systemImage: s.systemImage).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch section {
                    case .register:
                        RegisterView().environmentObject(vm)
                    case .history:
                        HistoryView().environmentObject(vm)
                    case .inventory:
                        placeholder(icon: "shippingbox", title: "Inventory")
                    case .admin:
                        AdminView().environmentObject(vm)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle(section.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if vm.isAdminUnlocked {
                            showingSettings = true
                        } else {
                            pinText = ""
                            pinError = ""
                            showPINSheet = true
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet().environmentObject(vm)
            }
            .sheet(isPresented: $showPINSheet) {
                VStack(spacing: 16) {
                    Text("Manager Access").font(.title3).bold()
                    Text("Enter manager PIN to open Settings.")
                        .foregroundStyle(.secondary)
                    SecureField("PIN", text: $pinText)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .background(Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                    if !pinError.isEmpty {
                        Text(pinError).foregroundStyle(.red).font(.footnote)
                    }
                    HStack {
                        Button("Cancel") { showPINSheet = false }
                        Spacer()
                        Button("Unlock") {
                            if vm.unlockAdmin(with: pinText) {
                                showPINSheet = false
                                showingSettings = true
                            } else {
                                pinError = "Incorrect PIN. Try again."
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .presentationDetents([.medium])
            }
        }
        .onAppear {
            vm.loadState()
            vm.ensureAtLeastOneTab()
        }
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
