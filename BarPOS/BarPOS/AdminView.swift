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

                    NavigationLink {
                        InventoryOverviewView()
                            .environmentObject(vm)
                    } label: {
                        Label("Inventory", systemImage: "box.truck")
                    }

                    NavigationLink {
                        PendingCocktailsView()
                            .environmentObject(vm)
                    } label: {
                        Label("Pending Cocktails", systemImage: "clock.badge.checkmark")
                    }
                }
                
                // MARK: - Staff
                Section("Staff") {
                    NavigationLink {
                        AdminStaffView()
                            .environmentObject(vm)
                    } label: {
                        Label("Staff", systemImage: "person.2.fill")
                    }
                }

                // MARK: - Security
                Section("Security") {
                    NavigationLink {
                        AdminSecurityView()
                            .environmentObject(vm)
                    } label: {
                        Label("Security & PIN", systemImage: "lock.shield")
                    }
                }
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
