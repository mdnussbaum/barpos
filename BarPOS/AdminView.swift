// ===== REPLACEMENT: AdminView.swift =====
import SwiftUI

struct AdminView: View {
    @EnvironmentObject var vm: InventoryVM

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Data & Backup
                Section("Data") {
                    NavigationLink {
                        AdminBackupsView()
                            .environmentObject(vm)
                    } label: {
                        Label("Backups", systemImage: "externaldrive.fill.badge.icloud")
                    }
                }

                // MARK: - Catalog
                Section("Catalog") {
                    NavigationLink {
                        AdminProductsView()
                            .environmentObject(vm)
                    } label: {
                        Label("Products", systemImage: "shippingbox")
                    }
                }

                // MARK: - Operations
                Section("Operations") {
                    NavigationLink {
                        AdminChipsView()
                            .environmentObject(vm)
                    } label: {
                        Label("Chips", systemImage: "circle.grid.2x2.fill")
                    }

                    NavigationLink {
                        AdminReportsView()
                            .environmentObject(vm)
                    } label: {
                        Label("Reports", systemImage: "doc.plaintext")
                    }
                }

                // MARK: - Staff
                Section("Staff") {
                    ForEach(vm.bartenders, id: \.id) { b in
                        Text(b.name)
                    }
                }
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
