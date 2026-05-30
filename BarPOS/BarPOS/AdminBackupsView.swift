//
//  AdminBackupsView.swift
//  BarPOSv2
//

import SwiftUI
import UniformTypeIdentifiers

struct AdminBackupsView: View {
    @EnvironmentObject var vm: InventoryVM
    
    @State private var showingExporter = false
    @State private var exportURL: URL?
    @State private var showingImporter = false
    @State private var importStatus: String?
    
    var body: some View {
        List {
            // MARK: - Export
            Section {
                Button {
                    if let url = vm.exportBackup() {
                        exportURL = url
                        showingExporter = true
                    }
                } label: {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }
                .fileExporter(
                    isPresented: $showingExporter,
                    document: exportURL.map { URLDocument(url: $0) },
                    contentType: .json,
                    defaultFilename: "BarPOS-Backup"
                ) { _ in }
            } header: {
                Text("Export")
            }
            
            // MARK: - Import
            Section {
                Button {
                    showingImporter = true
                } label: {
                    Label("Import Backup…", systemImage: "square.and.arrow.down")
                }
                .fileImporter(
                    isPresented: $showingImporter,
                    allowedContentTypes: [.json]
                ) { result in
                    switch result {
                    case .success(let url):
                        restore(from: url)
                    case .failure(let err):
                        importStatus = "Import failed: \(err.localizedDescription)"
                    }
                }
                
                if let msg = importStatus {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(msg.localizedCaseInsensitiveContains("failed") ? .red : .secondary)
                }
            } header: {
                Text("Import")
            }

            Section {
                Button {
                    if let message = vm.checkAndApplyCloudProductImport() {
                        importStatus = message
                    } else {
                        importStatus = "No products_import.csv found in iCloud Drive."
                    }
                } label: {
                    Label("Check iCloud for Product Import", systemImage: "icloud.and.arrow.down")
                }
            } header: {
                Text("iCloud Auto-Import")
            } footer: {
                Text("Drop a file named \"products_import.csv\" into iCloud Drive → BarPOS Reports. The app checks automatically on launch.")
                    .font(.caption)
            }
        }
        .navigationTitle("Backups")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // ===== REPLACEMENT: restore(from:) uses InventoryVM.PersistedState =====
    private func restore(from url: URL) {
        do {
            let s = try Persistence.loadJSON(from: url, as: InventoryVM.PersistedState.self)
            vm.applyState(s)   // apply everything, including products
            vm.saveState()     // persist immediately
            importStatus = "Import successful."
            print("✅ Import successful")
        } catch {
            importStatus = "Import failed: \(error.localizedDescription)"
            print("❌ Import failed:", error)
        }
    }
    
    // Helper wrapper to export an existing file URL
    struct URLDocument: FileDocument {
        static var readableContentTypes: [UTType] { [.json] }
        var url: URL
        
        init(url: URL) { self.url = url }
        init(configuration: ReadConfiguration) throws { self.url = URL(fileURLWithPath: "") }
        
        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            try FileWrapper(url: url, options: .immediate)
        }
    }
}
