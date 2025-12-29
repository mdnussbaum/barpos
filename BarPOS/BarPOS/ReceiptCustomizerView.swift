//
//  ReceiptCustomizerView.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 12/29/25.
//


import SwiftUI

struct ReceiptCustomizerView: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var headerText: String = ""
    @State private var footerText: String = ""
    @State private var showDate: Bool = true
    @State private var showServer: Bool = true
    @State private var showTax: Bool = true
    
    var body: some View {
        Form {
            Section("Header") {
                TextField("Bar Name", text: $headerText)
                    .onChange(of: headerText) { _, newValue in
                        vm.printerSettings.headerText = newValue
                    }
                
                Text("Appears at the top of every receipt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Footer") {
                TextField("Thank You Message", text: $footerText)
                    .onChange(of: footerText) { _, newValue in
                        vm.printerSettings.footerText = newValue
                    }
                
                Text("Appears at the bottom of every receipt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Receipt Details") {
                Toggle("Show Date & Time", isOn: $showDate)
                    .onChange(of: showDate) { _, newValue in
                        vm.printerSettings.showDate = newValue
                    }
                
                Toggle("Show Server Name", isOn: $showServer)
                    .onChange(of: showServer) { _, newValue in
                        vm.printerSettings.showServer = newValue
                    }
                
                Toggle("Show Tax Breakdown", isOn: $showTax)
                    .onChange(of: showTax) { _, newValue in
                        vm.printerSettings.showTax = newValue
                    }
            }
            
            Section("Preview") {
                Button {
                    // Generate preview receipt
                } label: {
                    Label("Preview Receipt", systemImage: "doc.text.magnifyingglass")
                }
            }
        }
        .navigationTitle("Receipt Customizer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            headerText = vm.printerSettings.headerText
            footerText = vm.printerSettings.footerText
            showDate = vm.printerSettings.showDate
            showServer = vm.printerSettings.showServer
            showTax = vm.printerSettings.showTax
        }
    }
}