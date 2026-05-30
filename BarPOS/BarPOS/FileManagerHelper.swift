//
//  FileManagerHelper.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 11/21/25.
//


//
//  FileManagerHelper.swift
//  BarPOS
//

import Foundation

struct FileManagerHelper {
    
    // Get iCloud ubiquity container directory for backups
        static var iCloudDocumentsURL: URL? {
            guard let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.Me.BarPOS") else {
                print("⚠️ iCloud not available")
                return nil
            }
            
            let documentsURL = iCloudURL.appendingPathComponent("Documents/BarPOS Reports")
            
            // Create directory if needed
            try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            
            return documentsURL
        }
    // Save file to iCloud Drive
    static func saveToiCloud(fileURL: URL, filename: String) -> URL? {
        guard let iCloudURL = iCloudDocumentsURL else {
            print("iCloud not available")
            return nil
        }
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
        
        let destinationURL = iCloudURL.appendingPathComponent(filename)
        
        do {
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy file to iCloud
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            print("✅ Saved to iCloud: \(destinationURL.path)")
            return destinationURL
        } catch {
            print("❌ Error saving to iCloud: \(error)")
            return nil
        }
    }
    
    /// Watched file: user drops this into iCloud Drive to trigger an import
    static var pendingImportURL: URL? {
        iCloudDocumentsURL?.appendingPathComponent("products_import.csv")
    }

    /// After a successful import, rename so the file doesn't re-trigger
    static func markImportProcessed() {
        guard let src = pendingImportURL else { return }
        let dst = src.deletingLastPathComponent()
            .appendingPathComponent("products_import.processed.csv")
        try? FileManager.default.removeItem(at: dst)
        try? FileManager.default.moveItem(at: src, to: dst)
    }

    // Check if iCloud is available
    static var isiCloudAvailable: Bool {
        FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil
    }
}
