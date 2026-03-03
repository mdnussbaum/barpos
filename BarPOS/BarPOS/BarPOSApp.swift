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

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(vm)
                .preferredColorScheme(resolvedColorScheme)
                .onAppear {
                    DemoSeeder.seed(into: vm)
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
