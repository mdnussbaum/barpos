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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .navigationTitle(section == .admin ? section.title : "")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet().environmentObject(vm)
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
