import SwiftUI

@main
struct BarPOSv2App: App {
    @StateObject private var vm = InventoryVM()

    var body: some Scene {
        WindowGroup {
            AppShell() // or RegisterView() if that’s your root
                .environmentObject(vm)
                .onAppear {
                    DemoSeeder.seed(into: vm)
                }
        }
    }
}
