import SwiftUI
import Combine

struct RegisterView: View {
    @EnvironmentObject var vm: InventoryVM

    // UI State
    @State private var cashGivenString: String = ""
    @FocusState private var cashGivenFocused: Bool
    @State private var showingBeginSheet = false
    @State private var showingEndSheet = false
    @State private var payMethod: PaymentMethod = .cash
    @State private var showingReorderSheet = false
    @State private var selectedCategory: ProductCategory? = nil
    @State private var categoryToReorder: ProductCategory? = nil
    @State private var showingChangePINSheet = false
    @State private var showingBuildCocktail = false

    // Tab name suggestion state
    @FocusState private var tabNameFocused: Bool

    // Size variant picker state
    @State private var selectedProduct: Product? = nil

    // Per-shift low stock warning tracking
    @State private var warnedLowStockIDs: Set<UUID> = []

    // Product button scale animation state
    @State private var tappedProductID: UUID? = nil

    // Close tab sheet
    @State private var showingCloseTabSheet = false

    // On-screen clock
    @State private var currentTime: String = RegisterView.formattedTime()
    private let clockTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private static func formattedTime() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }

    // Printer state
    @StateObject private var printer = EpsonPrinterManager()
    @State private var showingSavedReceiptURL: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        GeometryReader { geometry in
            Group {
            if vm.currentShift == nil {
                // Not on shift - show overlay
                ZStack {
                    registerContent
                        .disabled(true)
                        .blur(radius: 2)
                    
                    Color.black.opacity(0.45)
                        .ignoresSafeArea(.all, edges: [.bottom, .leading, .trailing])
                    
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
                }
            } else {
                // On shift - normal view
                registerContent
            }
            }
        }
        .onAppear {
            print("🔍 All bartenders: \(vm.bartenders.map { "\($0.name) - active: \($0.isActive)" })")
            print("🔍 Active only: \(vm.bartenders.filter { $0.isActive }.map { $0.name })")
            currentTime = RegisterView.formattedTime()
        }
        .onReceive(clockTimer) { _ in
            currentTime = RegisterView.formattedTime()
        }
        .onChange(of: vm.currentShift?.id) { _, _ in
            // Reset low stock warnings when a new shift begins
            warnedLowStockIDs = []
        }
        
        // MARK: Sheets
        .sheet(isPresented: $showingBeginSheet) {
            BeginShiftSheet(
                carryoverTabs: Array(vm.tabs.values).filter { !$0.lines.isEmpty },
                onStart: { bartender, openingCash in
                    showingBeginSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        vm.beginShift(bartender: bartender, openingCash: openingCash)
                    }
                }
            )
            .environmentObject(vm)
        }
        .sheet(isPresented: $showingEndSheet) {
            EndShiftSheet()
                .environmentObject(vm)
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
        .sheet(isPresented: $showingBuildCocktail) {
            BuildCocktailSheet()
                .environmentObject(vm)
        }
        // MARK: Close tab sheet
        // Reads vm.activeTab live via the @EnvironmentObject reference so the
        // sheet always sees the correct tab regardless of SwiftUI render timing.
        .sheet(isPresented: $showingCloseTabSheet) {
            if let tab = vm.activeTab {
                CloseTabSheet(
                    tab: tab,
                    payMethod: payMethod,
                    cashGiven: Decimal(string: cashGivenString) ?? 0,
                    printer: printer,
                    onClose: { printReceipt in
                        let cash = payMethod == .cash ? (Decimal(string: cashGivenString) ?? 0) : 0
                        if let result = vm.closeActiveTab(cashTendered: cash, method: payMethod) {
                            if payMethod == .cash {
                                cashGivenString = ""
                                cashGivenFocused = false
                                Task { await printer.openCashDrawer() }
                            }
                            if printReceipt {
                                Task { await self.printReceipt(result, settings: vm.printerSettings) }
                            }
                            showingCloseTabSheet = false
                        }
                    },
                    onCancel: {
                        showingCloseTabSheet = false
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
            } else {
                Text("No active tab")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        
        // MARK: Share sheet for saved receipt
        .sheet(isPresented: $showingShareSheet) {
            if let url = showingSavedReceiptURL {
                ShareSheet(items: [url])
            }
        }
        
        // MARK: Alert showing receipt was saved
        .alert("Receipt Saved", isPresented: Binding(
            get: { showingSavedReceiptURL != nil },
            set: { if !$0 { showingSavedReceiptURL = nil } }
        )) {
            Button("View in Files") {
                if showingSavedReceiptURL != nil {
                    showingShareSheet = true
                }
            }
            Button("OK") {
                showingSavedReceiptURL = nil
            }
        } message: {
            Text("Receipt saved to Files app in Receipts folder")
        }
    }
    
    // MARK: - Print Receipt Helper
    private func printReceipt(_ result: CloseResult, settings: ReceiptSettings) async {
        let content = ReceiptFormatter.formatReceiptContent(result, settings: settings)
        if !printer.isConnected {
            print("⚠️ Printer not connected — attempting discovery before print...")
            await printer.discoverPrinter()
        }
        do {
            try await printer.printReceipt(content)
            print("✅ Receipt printed successfully")
        } catch {
            print("❌ Print receipt error: \(error)")
        }
    }
    
    // MARK: - Register Content
    private var registerContent: some View {
        VStack(spacing: 0) {
            // Happy Hour Banner
            if vm.isHappyHourActive() {
                HStack {
                    Image(systemName: "party.popper.fill")
                        .foregroundStyle(.orange)
                    Text("HAPPY HOUR ACTIVE")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.2))
            }
            
            // Top bar with Shift Status chip
            HStack {
                Spacer()
                shiftStatusChip
            }
            .padding(.horizontal, 6)
            .padding(.top, 2)

            // Main 1/3 : 2/3 layout
            HStack(alignment: .top, spacing: 8) {
                leftColumn
                    .frame(maxWidth: .infinity)
                rightColumn
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .navigationBarHidden(true)
    }
    
    // MARK: - Left column (tabs + current ticket + totals/checkout)
    private var leftColumn: some View {
        HStack(alignment: .top, spacing: 0) {
            // Vertical tab strip
            VStack(spacing: 0) {
                // New Tab (+) button pinned at top of strip
                Button { vm.createNewTab() } label: {
                    Label("New", systemImage: "plus")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 6)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(vm.tabIDsForUI, id: \.self) { id in
                            Button { vm.selectTab(id: id) } label: {
                                Text(vm.tabDisplayName(id: id))
                                    .font(.caption)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background((id == vm.activeTabID) ? Color.blue.opacity(0.25) : Color(.tertiarySystemFill))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
            }
            .frame(width: 80)
            .frame(maxHeight: .infinity)

            Divider()

            // Right side: rename field + order lines + totals
            VStack(spacing: 0) {
                // Tab name field + trash
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            TextField("Tab name", text: Binding(
                                get: { vm.activeTab?.name ?? "" },
                                set: { vm.renameActiveTab($0) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .focused($tabNameFocused)

                            Button(role: .destructive) {
                                vm.deleteActiveTabIfEmpty()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .disabled(!vm.activeLines.isEmpty)
                        }

                        // Tab name suggestion dropdown
                        let currentName = vm.activeTab?.name ?? ""
                        let suggestions = tabNameSuggestions(for: currentName)
                        if tabNameFocused && !suggestions.isEmpty && !currentName.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(suggestions.prefix(5), id: \.self) { name in
                                    Button {
                                        vm.renameActiveTab(name)
                                        tabNameFocused = false
                                    } label: {
                                        Text(name)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
                            }
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .shadow(radius: 4)
                            .zIndex(10)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)

                // Order lines - fills all available space between controls and totals
                if vm.activeLines.isEmpty {
                    Text("No items yet")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                } else {
                    List {
                        ForEach(vm.activeLines) { line in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.displayName)
                                    Text("@ \(line.unitPrice.currencyString())")
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
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.plain)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Totals + Chips - anchored at bottom as one unit
                VStack(spacing: 4) {
                    totalsCard
                    chipActionsSection
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Right column (category + products OR chips)
    private var rightColumn: some View {
        VStack(spacing: 8) {
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

            // Build Cocktail button
            if vm.currentShift != nil {
                Button {
                    showingBuildCocktail = true
                } label: {
                    Label("Build Cocktail", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 4)
            }

            if vm.currentShift != nil {
                HStack(spacing: 8) {
                    Button {
                        Task {
                            let testContent = EpsonReceiptContent(
                                header: "TEST RECEIPT",
                                lines: [
                                    ReceiptLine(quantity: 2, itemName: "Miller Lite", price: "$4.00"),
                                    ReceiptLine(quantity: 1, itemName: "Well Whiskey", price: "$6.00")
                                ],
                                subtotal: "$14.00",
                                tax: "$0.00",
                                total: "$14.00",
                                footer: "Thank You!"
                            )

                            do {
                                try await printer.printReceipt(testContent)
                            } catch {
                                print("Print error: \(error)")
                            }
                        }
                    } label: {
                        Label("Test Printer", systemImage: "printer.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.1))
                            .foregroundStyle(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            do {
                                try await printer.openDrawer()
                            } catch {
                                print("Drawer error: \(error)")
                            }
                        }
                    } label: {
                        Label("Test Drawer", systemImage: "tray.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
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
        // Size variant picker lives here so it has its own dedicated sheet host,
        // separate from the root GeometryReader which already chains 7+ other sheets.
        .sheet(item: $selectedProduct) { product in
            SizeVariantPicker(product: product) { variant in
                addLineItem(product: product, variant: variant)
                selectedProduct = nil
            }
        }
    }
    
    // Products shown based on selectedCategory (uses per-bartender order)
    private var visibleProducts: [Product] {
        let regularProducts = vm.sortedProductsForCurrentBartender(category: selectedCategory)
        let customCocktails = vm.currentBartenderCocktails().map { cocktail in
            Product(
                id: cocktail.id,
                name: cocktail.name + " ⭐",
                category: cocktail.category,
                price: cocktail.basePrice
            )
        }
        let allProducts = customCocktails + regularProducts
        return allProducts
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
        .controlSize(.large)
    }
    
    // Reusable grid for a given product list
    private func productGrid(_ products: [Product]) -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(products) { p in
                    ProductGridButton(
                        product: p,
                        displayPrice: displayPrice(for: p),
                        isLowStock: isLowStockWarning(p),
                        onTap: { handleProductTap(p) }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // Helper: Display price for product (handles variants + happy hour)
    private func displayPrice(for product: Product) -> String {
        let isHH = vm.isHappyHourActive()
        
        // Handle size variants
        if let variants = product.sizeVariants, !variants.isEmpty {
            let prices = variants.map { $0.price }
            if let minPrice = prices.min(), let maxPrice = prices.max(), minPrice != maxPrice {
                let display = "\(minPrice.currencyString()) - \(maxPrice.currencyString())"
                return isHH && product.happyHourPrice != nil ? display + " 🎉" : display
            } else if let firstPrice = prices.first {
                return isHH && product.happyHourPrice != nil ? firstPrice.currencyString() + " 🎉" : firstPrice.currencyString()
            }
        }
        
        // Regular products - show HH price if active
        if isHH, let hhPrice = product.happyHourPrice {
            return hhPrice.currencyString() + " 🎉"
        }
        
        return product.price.currencyString()
    }
    
    // Helper: Handle product tap (checks for variants)
    private func handleProductTap(_ product: Product) {
        // Mark low-stock warning as shown for this shift
        if let stock = product.stockQuantity, let par = product.parLevel, stock < par {
            warnedLowStockIDs.insert(product.id)
        }

        // Use effective price (HH if active, otherwise regular)
        var effectiveProduct = product
        if vm.isHappyHourActive(), let hhPrice = product.happyHourPrice {
            effectiveProduct.price = hhPrice
        }
        
        if let variants = effectiveProduct.sizeVariants, !variants.isEmpty {
            selectedProduct = effectiveProduct
        } else {
            vm.addLine(product: effectiveProduct)
        }
    }
    
    // Helper: Add line item with variant
    private func addLineItem(product: Product, variant: SizeVariant) {
        vm.addLine(product: product, variant: variant)
    }
    
    // MARK: - Chips Grid (used when category == .chips)
    private func chipsGrid() -> some View {
        ScrollView {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                spacing: 12
            ) {
                ForEach(ChipType.allCases, id: \.self) { chip in
                    VStack(spacing: 4) {
                        Text(chip.displayName)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text(vm.price(for: chip).currencyString())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .padding(.vertical, 8)
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
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Totals + Checkout (Quick Actions)
        private var totalsCard: some View {
            HStack(spacing: 8) {
                // Left side: Total + Cash entry
                VStack(spacing: 4) {
                    Text(vm.totalActive.currencyString())
                        .font(.system(size: 22, weight: .bold))
                    
                    if payMethod == .cash {
                        TextField("Cash", text: $cashGivenString)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .frame(height: 36)
                            .focused($cashGivenFocused)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") { cashGivenFocused = false }
                                }
                            }
                        
                        if let tendered = Decimal(string: cashGivenString), !cashGivenString.isEmpty {
                            let diff = tendered - vm.totalActive
                            if diff >= 0 {
                                Text("Change: \(diff.currencyString())")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text("Still owed: \((-diff).currencyString())")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    
                    HStack(spacing: 4) {
                        paymentButton(method: .cash, icon: "dollarsign.circle.fill", label: "Cash")
                        paymentButton(method: .card, icon: "creditcard.fill", label: "Card")
                        paymentButton(method: .other, icon: "ellipsis.circle.fill", label: "Other")
                    }
                    .frame(height: 36)
                }
                .frame(maxWidth: .infinity)
                
                // Right side: Close Tab button
                Button {
                    showingCloseTabSheet = true
                } label: {
                    Text("Close Tab")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled({
                    if vm.activeLines.isEmpty { return true }
                    if payMethod == .cash {
                        // Allow closing if total is $0 or negative (chip redemptions)
                        if vm.totalActive <= 0 { return false }
                        let tendered = Decimal(string: cashGivenString) ?? 0
                        return tendered < vm.totalActive
                    }
                    return false
                }())
            }
            .frame(height: 120)
            .padding(8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .onAppear {
                if payMethod == .cash {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        cashGivenFocused = true
                    }
                }
            }
            .onChange(of: payMethod) { _, newMethod in
                guard newMethod == .cash else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    cashGivenFocused = true
                }
            }
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
        VStack(alignment: .leading, spacing: 8) {
            // Sell row
            HStack(spacing: 8) {
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
        .padding(10)
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
                    Text("On Shift – \(bartender.name) • \(elapsedString(since: shift.startedAt)) • \(vm.currentShiftGross.currencyString()) • \(currentTime)")
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
    
    // MARK: - Low stock check
    private func isLowStockWarning(_ product: Product) -> Bool {
        guard let stock = product.stockQuantity,
              let par = product.parLevel,
              stock < par else { return false }
        return !warnedLowStockIDs.contains(product.id)
    }

    // MARK: - Small helpers
    private func tabNameSuggestions(for input: String) -> [String] {
        guard !input.isEmpty else { return [] }
        let allNames = vm.allClosedTabs.map { $0.tabName }
        let unique = Array(Set(allNames)).sorted()
        return unique.filter { $0.localizedCaseInsensitiveContains(input) && $0 != input }
    }

    private func elapsedString(since start: Date) -> String {
        let secs = max(0, Int(Date().timeIntervalSince(start)))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    // MARK: - Product Grid Button (with animation + low stock badge)
    struct ProductGridButton: View {
        let product: Product
        let displayPrice: String
        let isLowStock: Bool
        let onTap: () -> Void

        @State private var scale: CGFloat = 1.0

        var body: some View {
            Button {
                withAnimation(.easeInOut(duration: 0.075)) { scale = 1.15 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.075) {
                    withAnimation(.easeInOut(duration: 0.075)) { scale = 1.0 }
                }
                onTap()
            } label: {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text(displayPrice)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    if isLowStock {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 10, height: 10)
                            .padding(6)
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(scale)
        }
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

    // MARK: - Close Tab Sheet
    struct CloseTabSheet: View {
        let tab: TabTicket
        let payMethod: PaymentMethod
        let cashGiven: Decimal
        let printer: EpsonPrinterManager
        let onClose: (Bool) -> Void  // Bool = printReceipt
        let onCancel: () -> Void

        private var subtotal: Decimal { tab.subtotal }
        private var total: Decimal { tab.total }
        private var changeDue: Decimal {
            guard payMethod == .cash else { return 0 }
            return max(0, cashGiven - total)
        }
        private var payMethodLabel: String {
            switch payMethod {
            case .cash: return "Cash"
            case .card: return "Card"
            case .other: return "Other"
            }
        }

        var body: some View {
            NavigationStack {
                List {
                    // Tab header
                    Section {
                        HStack {
                            Text("Tab")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(tab.name.isEmpty ? "Unnamed" : tab.name)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("Payment")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(payMethodLabel)
                                .fontWeight(.semibold)
                        }
                    }

                    // Itemized lines
                    Section("Items") {
                        ForEach(tab.lines) { line in
                            HStack {
                                Text(line.displayName)
                                Spacer()
                                Text("×\(line.qty)")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                                Text(line.lineTotal.currencyString())
                                    .frame(width: 72, alignment: .trailing)
                            }
                            .font(.subheadline)
                        }
                    }

                    // Totals
                    Section {
                        HStack {
                            Text("Subtotal")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(subtotal.currencyString())
                        }
                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(total.currencyString())
                                .fontWeight(.semibold)
                        }
                        if payMethod == .cash {
                            HStack {
                                Text("Cash Tendered")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(cashGiven.currencyString())
                            }
                            HStack {
                                Text("Change Due")
                                    .foregroundStyle(changeDue > 0 ? .green : .secondary)
                                Spacer()
                                Text(changeDue.currencyString())
                                    .foregroundStyle(changeDue > 0 ? .green : .primary)
                                    .fontWeight(changeDue > 0 ? .semibold : .regular)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle("Close Tab")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    HStack(spacing: 12) {
                        Button {
                            onClose(false)
                        } label: {
                            Text("No Receipt")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(.secondarySystemBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onClose(true)
                        } label: {
                            Label("Print Receipt", systemImage: "printer.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .background(.regularMaterial)
                }
            }
        }
    }
}

