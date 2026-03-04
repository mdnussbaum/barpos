import SwiftUI

struct PricingRulesView: View {
    @EnvironmentObject var vm: InventoryVM

    // Local string state for each editable field
    @State private var liquorPourString: String = ""
    @State private var beerServingString: String = ""
    @State private var liquorRatioString: String = ""
    @State private var beerRatioString: String = ""
    @State private var kegRatioString: String = ""
    @State private var kegDepositString: String = ""
    @State private var roundingString: String = ""

    var body: some View {
        Form {
            // MARK: - Serving Sizes
            Section("Serving Sizes") {
                HStack {
                    Text("Liquor pour size")
                    Spacer()
                    TextField("1.125", text: $liquorPourString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: liquorPourString) { _, new in
                            if let v = Decimal(string: new), v > 0 {
                                vm.pricingRules.defaultLiquorServingSizeOz = v
                            }
                        }
                    Text("oz")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Beer serving size")
                    Spacer()
                    TextField("1.0", text: $beerServingString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: beerServingString) { _, new in
                            if let v = Decimal(string: new), v > 0 {
                                vm.pricingRules.defaultBeerServingSizeOz = v
                            }
                        }
                    Text("bottle")
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Suggested Price Formula
            Section {
                ratioRow(
                    label: "Liquor target cost",
                    text: $liquorRatioString
                ) { pct in vm.pricingRules.liquorTargetCostRatio = Decimal(pct / 100.0) }

                ratioRow(
                    label: "Beer target cost",
                    text: $beerRatioString
                ) { pct in vm.pricingRules.beerTargetCostRatio = Decimal(pct / 100.0) }

                ratioRow(
                    label: "Keg target cost",
                    text: $kegRatioString
                ) { pct in vm.pricingRules.kegTargetCostRatio = Decimal(pct / 100.0) }

                HStack {
                    Text("Keg deposit deduction")
                    Spacer()
                    Text("$")
                        .foregroundStyle(.secondary)
                    TextField("30.00", text: $kegDepositString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: kegDepositString) { _, new in
                            if let v = Decimal(string: new), v >= 0 {
                                vm.pricingRules.kegDepositAmount = v
                            }
                        }
                }

                HStack {
                    Text("Price rounding increment")
                    Spacer()
                    Text("$")
                        .foregroundStyle(.secondary)
                    TextField("0.50", text: $roundingString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: roundingString) { _, new in
                            if let v = Decimal(string: new), v > 0 {
                                vm.pricingRules.priceRoundingIncrement = v
                            }
                        }
                }
            } header: {
                Text("Suggested Price Formula")
            } footer: {
                Text("Suggested price = (cost per serving) ÷ (target cost %), rounded up to the nearest increment.")
                    .font(.caption)
            }

            // MARK: - Preview
            Section {
                liquorPreviewRow
                beerPreviewRow
                kegPreviewRow
            } header: {
                Text("Preview")
            } footer: {
                Text("Live examples using the settings above. Updates as you change any value.")
                    .font(.caption)
            }
        }
        .navigationTitle("Pricing Rules")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadStrings() }
    }

    // MARK: - Shared ratio row builder

    @ViewBuilder
    private func ratioRow(
        label: String,
        text: Binding<String>,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("33", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onChange(of: text.wrappedValue) { _, new in
                    if let pct = Double(new), pct > 0, pct <= 100 {
                        onChange(pct)
                    }
                }
            Text("%")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Preview rows

    private var liquorPreviewRow: some View {
        let rules = vm.pricingRules
        // Liter bottle: 33.81 oz, $25.38, poured in configured oz
        let bottleOz: Decimal = 33.81
        let cost: Decimal = 25.38
        let pourOz = rules.defaultLiquorServingSizeOz
        let costPerServing = (cost / bottleOz) * pourOz
        let suggested = roundUp(costPerServing / rules.liquorTargetCostRatio, increment: rules.priceRoundingIncrement)
        return previewLine(
            label: "Liquor: $25.38 liter",
            detail: "→ \(suggested.currencyString()) per \(pourOz.plainString())oz shot"
        )
    }

    private var beerPreviewRow: some View {
        let rules = vm.pricingRules
        // Case of 24 bottles, $21.95
        let caseSize: Decimal = 24
        let cost: Decimal = 21.95
        let servingSize = rules.defaultBeerServingSizeOz
        let costPerServing = (cost / caseSize) / servingSize
        let suggested = roundUp(costPerServing / rules.beerTargetCostRatio, increment: rules.priceRoundingIncrement)
        return previewLine(
            label: "Beer: $21.95 case of 24",
            detail: "→ \(suggested.currencyString()) per bottle"
        )
    }

    private var kegPreviewRow: some View {
        let rules = vm.pricingRules
        // 1/6 barrel: 661 oz, $119.00, 16oz pint
        let kegOz: Decimal = 661
        let cost: Decimal = 119.00
        let servingOz: Decimal = 16
        let adjustedCost = cost - rules.kegDepositAmount
        let costPerPint = (adjustedCost / kegOz) * servingOz
        let suggested = roundUp(costPerPint / rules.kegTargetCostRatio, increment: rules.priceRoundingIncrement)
        return previewLine(
            label: "Keg: $119.00 1/6 barrel (661 oz)",
            detail: "→ \(suggested.currencyString()) per pint"
        )
    }

    @ViewBuilder
    private func previewLine(label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.blue)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func roundUp(_ value: Decimal, increment: Decimal) -> Decimal {
        let inc = (increment as NSDecimalNumber).doubleValue
        guard inc > 0 else { return value }
        let increments = ((value as NSDecimalNumber).doubleValue / inc).rounded(.up)
        return Decimal(increments * inc)
    }

    private func pctString(_ ratio: Decimal) -> String {
        let pct = (ratio as NSDecimalNumber).doubleValue * 100
        return pct.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(pct))
            : String(pct)
    }

    private func loadStrings() {
        let r = vm.pricingRules
        liquorPourString  = r.defaultLiquorServingSizeOz.plainString()
        beerServingString = r.defaultBeerServingSizeOz.plainString()
        liquorRatioString = pctString(r.liquorTargetCostRatio)
        beerRatioString   = pctString(r.beerTargetCostRatio)
        kegRatioString    = pctString(r.kegTargetCostRatio)
        kegDepositString  = r.kegDepositAmount.plainString()
        roundingString    = r.priceRoundingIncrement.plainString()
    }
}
