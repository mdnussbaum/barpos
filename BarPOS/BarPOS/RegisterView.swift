import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var vm: InventoryVM
    
    // UI State
    @State private var cashGivenString: String = ""
    @State private var showingSummary = false
    @State private var showingBeginSheet = false
    @State private var showingEndSheet = false
    @State private var showingShiftSummary = false
    @State private var payMethod: PaymentMethod = .cash
    @State private var showingReorderSheet = false
    @State private var selectedCategory: ProductCategory? = nil
    @State private var categoryToReorder: ProductCategory? = nil
    @State private var showingChangePINSheet = false
    
    var body: some View {
        ZStack {
            VStack {
                // Top bar with Shift Status chip
                HStack {
                    Spacer()
                    shiftStatusChip
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Main 1/3 : 2/3 layout
                HStack(alignment: .top, spacing: 16) {
                    leftColumn
                        .frame(maxWidth: .infinity)   // 1/3
                    rightColumn
                        .frame(maxWidth: .infinity)   // 2/3
                }
            }
            // Disable + blur the register when not on shift
            .disabled(vm.currentShift == nil)
            .blur(radius: vm.currentShift == nil ? 2 : 0)
            
            // Overlay when not on shift
            if vm.currentShift == nil {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .zIndex(1)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                        
                        Text("Start a shift to use the register")
                            .font(.title3).bold()
                            .foregroundColor(.white)
                        
                        Button {
                            showingBeginSheet = true
                        } label: {
                            Text("Begin Shift")
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(.white)
                                .foregroundColor(.black)
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel("Begin Shift")
                    }
                    .zIndex(2)
                }
            }
        }
        .padding()
        .onAppear {
            print("🔍 All bartenders: \(vm.bartenders.map { "\($0.name) - active: \($0.isActive)" })")
            print("🔍 Active only: \(vm.bartenders.filter { $0.isActive }.map { $0.name })")
        }
        
        // MARK: Sheets
        .sheet(isPresented: $showingBeginSheet) {
            BeginShiftSheet(
                carryoverTabs: Array(vm.tabs.values).filter { !$0.lines.isEmpty },
                onStart: { bartender, openingCash in
                    vm.beginShift(bartender: bartender, openingCash: openingCash)
                }
            )
            .environmentObject(vm)
        }
        .sheet(isPresented: $showingEndSheet) {
            EndShiftSheet()
                .environmentObject(vm)
        }
        .sheet(isPresented: $showingSummary) {
            if let res = vm.lastCloseResult {
                SummarySheet(result: res) { showingSummary = false }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingShiftSummary) {
            if let s = vm.currentShift {
                ShiftSummarySheet(shift: s) {
                    showingShiftSummary = false
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { vm.lastShiftReport != nil },
                set: { if !$0 { vm.lastShiftReport = nil } }
            )
        ) {
            if let rep = vm.lastShiftReport {
                ShiftReportSheet(report: rep) {
                    vm.lastShiftReport = nil
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingChangePINSheet) {
            if let bartender = vm.currentShift?.openedBy {
                ChangePINSheet(bartender: bartender)
                    .environmentObject(vm)
            }
        }
    }
    // MARK: - Left column (tabs + current ticket + totals/checkout)
    private var leftColumn: some View {
        VStack(spacing: 0) {
            // Tab strip - fixed at top
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.tabIDsForUI, id: \.self) { id in
                        Button { vm.selectTab(id: id) } label: {
                            Text(vm.tabDisplayName(id: id))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background((id == vm.activeTabID) ? Color.blue.opacity(0.2) : Color(.tertiarySystemFill))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 8)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    // Rename + trash (trash only deletes when EMPTY)
                    HStack {
                        TextField("Tab name", text: Binding(
                            get: { vm.activeTab?.name ?? "" },
                            set: { vm.renameActiveTab($0) }
                        ))
                        .textFieldStyle(.roundedBorder)
                        
                        Button(role: .destructive) {
                            vm.deleteActiveTabIfEmpty()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .disabled(!vm.activeLines.isEmpty)
                    }
                    
                    // New Tab
                    Button { vm.createNewTab() } label: {
                        Label("New Tab", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 6)
                    
                    // Current ticket lines
                    if vm.activeLines.isEmpty {
                        Text("No items yet")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        List {
                            ForEach(vm.activeLines) { line in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(line.product.name)
                                        Text("@ \(line.product.price.currencyString())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    
                                    // quantity badge
                                    Text("×\(line.qty)")
                                        .font(.headline)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.tertiarySystemFill))
                                        .clipShape(Capsule())
                                    
                                    // MINUS only
                                    Button {
                                        vm.decrementLine(lineID: line.id)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .imageScale(.large)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 4)
                                    .accessibilityLabel("Decrease \(line.product.name)")
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button {
                                        vm.decrementLine(lineID: line.id)
                                    } label: {
                                        Label("Decrease", systemImage: "minus.circle")
                                    }
                                    
                                    Button(role: .destructive) {
                                        vm.removeLine(lineID: line.id)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .frame(minHeight: 400)
                    }
                    
                }
                .padding(.bottom, 240)
            }
            
            // Totals + Chips - anchored at bottom as one unit
            VStack(spacing: 4) {
                totalsCard
                chipActionsSection
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Right column (category + products OR chips)
    private var rightColumn: some View {
        VStack(spacing: 12) {
            HStack {
                categoryBar
                // Reorder button with category menu
                Menu {
                    Button {
                        categoryToReorder = nil
                        showingReorderSheet = true
                    } label: {
                        Label("All Products", systemImage: "square.grid.2x2")
                    }
                    
                    Divider()
                    
                    ForEach(ProductCategory.allCases.filter { $0 != .chips }) { category in
                        Button {
                            categoryToReorder = category
                            showingReorderSheet = true
                        } label: {
                            Label(category.displayName, systemImage: "square.grid.2x2")
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            if selectedCategory == .chips {
                chipsGrid()
            } else {
                productGrid(visibleProducts)
            }
            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showingReorderSheet) {
            NavigationStack {
                ReorderProductsSheet(
                    category: categoryToReorder,
                    items: vm.sortedProductsForCurrentBartender(category: categoryToReorder),
                    onSave: { ids in
                        vm.setBartenderProductOrder(
                            bartender: vm.currentShift!.openedBy!,
                            category: categoryToReorder,
                            productIDs: ids
                        )
                    }
                )
            }
        }
    }
    
    // Products shown based on selectedCategory (uses per-bartender order)
    private var visibleProducts: [Product] {
        vm.sortedProductsForCurrentBartender(category: selectedCategory)
    }
    
    // Compact segmented picker for categories (nil = All)
    private var categoryBar: some View {
        Picker("Category", selection: $selectedCategory) {
            Text("All").tag(ProductCategory?.none)
            ForEach(ProductCategory.allCases.filter { $0 != .chips }) { c in
                Text(c.displayName).tag(ProductCategory?.some(c))
            }
        }
        .pickerStyle(.segmented)
    }
    
    // Reusable grid for a given product list
    private func productGrid(_ products: [Product]) -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
            spacing: 12
        ) {
            ForEach(products) { p in
                Button { vm.addLine(product: p) } label: {
                    VStack(spacing: 6) {
                        Text(p.name)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(p.price.currencyString())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Chips Grid (used when category == .chips)
    private func chipsGrid() -> some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
            spacing: 12
        ) {
            ForEach(ChipType.allCases, id: \.self) { chip in
                VStack(spacing: 6) {
                    Text(chip.displayName)
                        .multilineTextAlignment(.center)
                    Text(vm.price(for: chip).currencyString())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture { vm.addChipSold(chip) }
                .contextMenu {
                    Button("Redeem 1") { vm.addChipRedeemed(chip) }
                    Button("Sell 5") { vm.addChipSold(chip, count: 5) }
                    Button("Redeem 5") { vm.addChipRedeemed(chip, count: 5) }
                }
            }
        }
    }
    // MARK: - Totals + Checkout (Quick Actions)
    private var totalsCard: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(vm.totalActive.currencyString())
                    .font(.system(size: 24, weight: .bold))
                
                if payMethod == .cash {
                    TextField("Tendered", text: $cashGivenString)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                }
            }
            
            if payMethod == .cash, let tendered = Decimal(string: cashGivenString), tendered >= vm.totalActive {
                let change = tendered - vm.totalActive
                Text("Change: \(change.currencyString())")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            
            HStack(spacing: 4) {
                paymentButton(method: .cash, icon: "dollarsign.circle.fill", label: "Cash")
                paymentButton(method: .card, icon: "creditcard.fill", label: "Card")
                paymentButton(method: .other, icon: "ellipsis.circle.fill", label: "Other")
            }
            
            Button {
                switch payMethod {
                case .cash:
                    guard let cash = Decimal(string: cashGivenString) else { return }
                    if vm.closeActiveTab(cashTendered: cash, method: .cash) != nil {
                        cashGivenString = ""
                        showingSummary = true
                    }
                case .card:
                    if vm.closeActiveTab(cashTendered: 0, method: .card) != nil {
                        showingSummary = true
                    }
                case .other:
                    if vm.closeActiveTab(cashTendered: 0, method: .other) != nil {
                        showingSummary = true
                    }
                }
            } label: {
                Label("Close Tab", systemImage: "checkmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled({
                if vm.activeLines.isEmpty { return true }
                if payMethod == .cash {
                    let tendered = Decimal(string: cashGivenString) ?? 0
                    return tendered < vm.totalActive
                }
                return false
            }())
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func paymentButton(method: PaymentMethod, icon: String, label: String) -> some View {
        Button {
            payMethod = method
        } label: {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(payMethod == method ? Color.accentColor : Color(.tertiarySystemFill))
            .foregroundStyle(payMethod == method ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Chip Actions Section
    private var chipActionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Sell row
            HStack(spacing: 6) {
                Text("Sell")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .leading)
                chipButton(type: .white, action: .sell)
                chipButton(type: .gray, action: .sell)
                chipButton(type: .black, action: .sell)
            }
            
            // Redeem row
            HStack(spacing: 8) {
                Text("Redeem")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(width: 60, alignment: .leading)
                chipButton(type: .white, action: .redeem)
                chipButton(type: .gray, action: .redeem)
                chipButton(type: .black, action: .redeem)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
    
    private func chipButton(type: ChipType, action: ChipAction) -> some View {
        Button {
            switch action {
            case .sell:
                vm.addChipSold(type, count: 1)
            case .redeem:
                vm.addChipRedeemed(type, count: 1)
            }
        } label: {
            VStack(spacing: 4) {
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(vm.price(for: type).currencyString())
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    
    private enum ChipAction {
        case sell, redeem
    }
    
    // MARK: - Shift chip (smart)
    private var shiftStatusChip: some View {
        Group {
            if let shift = vm.currentShift, let bartender = shift.openedBy {
                // On shift
                Menu {
                    Button {
                        showingShiftSummary = true
                    } label: {
                        Label("Shift Summary", systemImage: "list.bullet.rectangle")
                    }
                    
                    Button {
                        showingChangePINSheet = true
                    } label: {
                        Label("Change PIN", systemImage: "lock.rotation")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingEndSheet = true
                    } label: {
                        Label("End Shift…", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Text("On Shift – \(bartender.name) • \(elapsedString(since: shift.startedAt)) • \(vm.currentShiftGross.currencyString())")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .accessibilityLabel("On shift. Elapsed \(elapsedString(since: shift.startedAt)). Gross \(vm.currentShiftGross.currencyString()).")
                }
                
            } else {
                // No shift
                Button { showingBeginSheet = true } label: {
                    Text("No Active Shift")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .accessibilityLabel("No active shift. Begin shift.")
            }
        }
    }
    
    // MARK: - Small helpers
    private func elapsedString(since start: Date) -> String {
        let secs = max(0, Int(Date().timeIntervalSince(start)))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    
    // MARK: - Reorder sheet (drag-and-drop per bartender)
    struct ReorderProductsSheet: View {
        let category: ProductCategory?
        @State var items: [Product]
        var onSave: ([UUID]) -> Void
        
        @Environment(\.dismiss) private var dismiss
        @State private var editMode: EditMode = .active
        
        var body: some View {
            List {
                ForEach(items) { p in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(p.name)
                        Spacer()
                        Text(p.price.currencyString())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onMove { from, to in
                    items.move(fromOffsets: from, toOffset: to)
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(items.map(\.id))
                        dismiss()
                    }
                }
            }
        }
        
        private var title: String {
            if let c = category, c != .chips {
                return "Reorder \(c.displayName)"
            } else {
                return "Reorder All"
            }
        }
    }
}
