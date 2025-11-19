//
//  AdminStaffView.swift
//  BarPOSv2
//
//  Created by Michael Nussbaum on 9/26/25.
//


import SwiftUI

struct AdminStaffView: View {
    @EnvironmentObject var vm: InventoryVM

    var body: some View {
        List {
            Section("Bartenders") {
                ForEach(vm.bartenders, id: \.id) { b in
                    Text(b.name)
                }
            }
        }
        .navigationTitle("Staff")
        .navigationBarTitleDisplayMode(.inline)
    }
}