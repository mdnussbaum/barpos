//
//  BarPOSApp.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 11/18/25.
//

import SwiftUI

@main
struct BarPOSApp: App {
    @StateObject private var vm = InventoryVM()
    @State private var cloudImportMessage: String? = nil

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(vm)
                .preferredColorScheme(resolvedColorScheme)
                .overlay(alignment: .top) {
                    if let msg = cloudImportMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundStyle(.white)
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                cloudImportMessage = nil
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: cloudImportMessage)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                cloudImportMessage = nil
                            }
                        }
                    }
                }
                .onAppear {
                    DemoSeeder.seed(into: vm)
                    Task {
                        await EpsonPrinterManager.shared.discoverAndConnect()
                    }
                    if let message = vm.checkAndApplyCloudProductImport() {
                        cloudImportMessage = message
                    } else if let message = vm.checkAndApplyCloudBartenderImport() {
                        cloudImportMessage = message
                    }
                }
        }
    }
    
    private var resolvedColorScheme: ColorScheme? {
        switch vm.colorScheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }
}
