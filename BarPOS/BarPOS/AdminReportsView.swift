import SwiftUI

struct AdminReportsView: View {
    @EnvironmentObject var vm: InventoryVM

    // MARK: - Filters
    @State private var fromDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var toDate: Date = Date()
    @State private var showOnlyFlagged = false
    @State private var selectedBartender: String? = nil
    @State private var presentingDayReport: DayReport?

    // MARK: - Sheet
    @State private var presentingReport: ShiftReport?

    // MARK: - Filtered data
    private var filteredReports: [ShiftReport] {
        // Normalize bounds to full days
        let start = Calendar.current.startOfDay(for: min(fromDate, toDate))
        let endDay = Calendar.current.startOfDay(for: max(fromDate, toDate))
        let end = Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: endDay) ?? Date()

        return vm.shiftReports
            .filter { rep in
                rep.endedAt >= start && rep.endedAt <= end &&
                (!showOnlyFlagged || rep.flagged) &&
                (selectedBartender == nil || rep.bartenderName == selectedBartender!)
            }
            .sorted { $0.endedAt > $1.endedAt }
    }

    // Distinct bartender names for a quick filter
    private var bartenderNames: [String] {
        Array(Set(vm.shiftReports.map { $0.bartenderName })).sorted()
    }

    // MARK: - Body
    var body: some View {
        List {
            // MARK: Filters (compact)
            Section {
                // Date range row
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)

                    DatePicker("", selection: $fromDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()

                    Text("–").foregroundStyle(.secondary)

                    DatePicker("", selection: $toDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()

                    Spacer(minLength: 8)

                    Menu {
                        Button("Last 7 days") {
                            fromDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                            toDate = Date()
                        }
                        Button("Last 30 days") {
                            fromDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
                            toDate = Date()
                        }
                        Button("This month") {
                            let cal = Calendar.current
                            let comps = cal.dateComponents([.year, .month], from: Date())
                            if let start = cal.date(from: comps) {
                                fromDate = start
                                toDate = Date()
                            }
                        }
                        Button("All time") {
                            fromDate = Date.distantPast
                            toDate = Date()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                // Flagged only toggle
                Toggle(isOn: $showOnlyFlagged) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("Flagged only")
                    }
                }

                // Bartender quick filter
                                if !bartenderNames.isEmpty {
                                    Menu {
                                        Button("All bartenders") { selectedBartender = nil }
                                        ForEach(bartenderNames, id: \.self) { name in
                                            Button(name) { selectedBartender = name }
                                        }
                                    } label: {
                                        HStack {
                                            Label("Bartender", systemImage: "person.2.fill")
                                            Spacer()
                                            Text(selectedBartender ?? "All")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                
                                // Generate Day Report button
                                Button {
                                    generateDayReport()
                                } label: {
                                    Label("Generate Day Report", systemImage: "calendar.badge.plus")
                                }
                                .buttonStyle(.bordered)
                            } header: {
                                Text("Filters")
                            }

                            // MARK: Summary
                            if !filteredReports.isEmpty {
                                Section("Summary") {
                                    summaryCard(for: filteredReports)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                }
                            } else {
                                Section("Summary") {
                                    Text("No reports in this range.")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // MARK: Reports
                            ForEach(filteredReports) { rep in
                                Button {
                                    presentingReport = rep
                                } label: {
                                    reportRow(rep)
                                }
                            }
                        }
                        .navigationTitle("Reports")
                        .navigationBarTitleDisplayMode(.inline)
                        .sheet(item: $presentingReport) { rep in
                            ShiftReportSheet(report: rep) {
                                presentingReport = nil
                            }
                            .environmentObject(vm)
                        }
                        .sheet(item: $presentingDayReport) { dayReport in
                            DayReportSheet(report: dayReport) {
                                presentingDayReport = nil
                            }
                            .environmentObject(vm)
                        }
                    }
    // MARK: - Summary Card (with tiny analytics + chips)
    private func summaryCard(for reps: [ShiftReport]) -> some View {
        // Totals
        let totalGross   = reps.reduce(0 as Decimal) { $0 + $1.grossSales }
        let totalCash    = reps.reduce(0 as Decimal) { $0 + $1.cashSales }
        let totalCard    = reps.reduce(0 as Decimal) { $0 + $1.cardSales }
        let totalOther   = reps.reduce(0 as Decimal) { $0 + $1.otherSales }
        let flaggedCnt   = reps.filter { $0.flagged }.count
        let totalTickets = reps.reduce(0) { $0 + $1.tabsCount }

        // Averages
        let avgPerShift  = safeDiv(totalGross, Decimal(reps.count))
        let avgPerTicket = safeDiv(totalGross, Decimal(max(1, totalTickets)))

        // Mix (use tendered amounts)
        let tenderTotal  = totalCash + totalCard + totalOther
        let cashPct      = percent(totalCash,  of: tenderTotal)
        let cardPct      = percent(totalCard,  of: tenderTotal)
        let otherPct     = percent(totalOther, of: tenderTotal)
        let flagRate     = percent(Decimal(flaggedCnt), of: Decimal(max(1, reps.count)))

        // Chips (derived from ticket lines)
        let chips = chipStats(for: reps) // uses helper below

        return VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(alignment: .firstTextBaseline) {
                Text("\(reps.count) report\(reps.count == 1 ? "" : "s")")
                    .font(.headline)
                Spacer()
                if flaggedCnt > 0 {
                    Label("\(flaggedCnt) flagged", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.yellow)
                }
            }

            // Row 1 — Totals
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                pill("Gross", totalGross.currencyString())
                pill("Cash",  totalCash.currencyString())
                pill("Card",  totalCard.currencyString())
                pill("Other", totalOther.currencyString())
            }

            // Row 2 — Averages
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                pill("Avg / Shift",  avgPerShift.currencyString())
                pill("Avg / Ticket", avgPerTicket.currencyString())
                pill("Tickets", "\(totalTickets)")
            }

            // Row 3 — Mix & Quality
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                pill("Cash %",  cashPct)
                pill("Card %",  cardPct)
                pill("Other %", otherPct)
                pill("Flag rate", flagRate)
            }

            // Row 4 — Chips (only if any chip activity)
            if !(chips.sold.isEmpty && chips.redeemed.isEmpty) {
                Divider().padding(.vertical, 2)
                HStack(spacing: 12) {
                    Image(systemName: "circle.grid.2x2.fill").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            Text("Sold:").font(.caption).foregroundStyle(.secondary)
                            Text("W \(chips.sold[.white, default: 0])  G \(chips.sold[.gray, default: 0])  B \(chips.sold[.black, default: 0])")
                                .font(.caption).bold()
                        }
                        HStack(spacing: 10) {
                            Text("Redeemed:").font(.caption).foregroundStyle(.secondary)
                            Text("W \(chips.redeemed[.white, default: 0])  G \(chips.redeemed[.gray, default: 0])  B \(chips.redeemed[.black, default: 0])")
                                .font(.caption).bold()
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
    // MARK: - Tiny helpers used by the summary card
    private func percent(_ part: Decimal, of whole: Decimal) -> String {
        guard whole > 0 else { return "—" }
        let d = (part as NSDecimalNumber).doubleValue / (whole as NSDecimalNumber).doubleValue
        let pct = Int((d * 100).rounded())
        return "\(pct)%"
    }

    private func safeDiv(_ a: Decimal, _ b: Decimal) -> Decimal {
        guard b != 0 else { return 0 }
        let da = (a as NSDecimalNumber).doubleValue
        let db = (b as NSDecimalNumber).doubleValue
        return Decimal(da / db)
    }
    // MARK: - Chip stats (derived from ticket line names in CloseResult snapshots)
    // Identify chip type from a line title
    private func chipType(from title: String) -> ChipType? {
        let lower = title.lowercased()
        if lower.contains("white") { return .white }
        if lower.contains("gray")  { return .gray }
        if lower.contains("black") { return .black }
        return nil
    }

    // Aggregate chip sold/redeemed counts across reports
    private func chipStats(for reps: [ShiftReport]) -> (sold: [ChipType: Int], redeemed: [ChipType: Int]) {
        var sold: [ChipType: Int] = [.white: 0, .gray: 0, .black: 0]
        var redeemed: [ChipType: Int] = [.white: 0, .gray: 0, .black: 0]

        for rep in reps {
            for ticket in rep.tickets {
                for line in ticket.lines { // line is LineSnapshot
                    let title = line.productName   // ← key change
                    let qty   = line.qty

                    if title.localizedCaseInsensitiveContains("chip sold"),
                       let ct = chipType(from: title) {
                        sold[ct, default: 0] += qty
                    } else if title.localizedCaseInsensitiveContains("chip redeemed"),
                              let ct = chipType(from: title) {
                        redeemed[ct, default: 0] += qty
                    }
                }
            }
        }
        return (sold, redeemed)
    }
    // MARK: - UI helpers (non-local scope)

    private func reportRow(_ rep: ShiftReport) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rep.bartenderName)
                    .font(.headline)
                Text("\(rep.startedAt.formatted(date: .abbreviated, time: .shortened)) – \(rep.endedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Text(rep.grossSales.currencyString())
                    .font(.headline)
                if rep.flagged {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .accessibilityLabel("Flagged discrepancy")
                }
            }
        }
    }


    private func pill(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption).bold()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
    }
    
    private func generateDayReport() {
            // Group shifts by calendar day
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: filteredReports) { report in
                calendar.startOfDay(for: report.endedAt)
            }
            
            let dayReport: DayReport
            
            // If only one day, show that day's report
            if grouped.count == 1, let (date, shifts) = grouped.first {
                dayReport = DayReport(date: date, shifts: shifts)
            } else {
                // Multiple days - combine all into one report using the start date
                let allShifts = Array(filteredReports)
                dayReport = DayReport(date: fromDate, shifts: allShifts)
            }
            
            // Auto-backup to iCloud
            performDailyBackup(for: dayReport.date, dayReport: dayReport)
            
            presentingDayReport = dayReport
        }
    
    private func performDailyBackup(for date: Date, dayReport: DayReport) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: date)
            
            // Create backup folder in iCloud
            guard let iCloudURL = FileManagerHelper.iCloudDocumentsURL else {
                print("⚠️ iCloud not available")
                return
            }
            
            let backupFolder = iCloudURL.appendingPathComponent("Daily Backups").appendingPathComponent(dateString)
            
            do {
                // Create folder
                try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
                
                // 1. Save Day Report PDF
                if let pdfURL = PDFGenerator.generateDayReportPDF(report: dayReport) {
                    let pdfDest = backupFolder.appendingPathComponent("DayReport_\(dateString).pdf")
                    try? FileManager.default.copyItem(at: pdfURL, to: pdfDest)
                    print("✅ Saved Day Report PDF")
                }
                
                // 2. Save Full JSON Backup
                if let backupURL = vm.exportBackup() {
                    let jsonDest = backupFolder.appendingPathComponent("backup_\(dateString).json")
                    try? FileManager.default.copyItem(at: backupURL, to: jsonDest)
                    print("✅ Saved JSON backup")
                }
                
                // 3. Save Products CSV
                let csv = CSVImporter.exportProductsToCSV(products: vm.products)
                let csvDest = backupFolder.appendingPathComponent("products_\(dateString).csv")
                try csv.write(to: csvDest, atomically: true, encoding: .utf8)
                print("✅ Saved Products CSV")
                
                print("✅ Daily backup complete: \(backupFolder.path)")
                
                // Cleanup old backups (keep last 30 days)
                cleanupOldBackups()
                
            } catch {
                print("⚠️ Backup error: \(error)")
            }
        }
        
        private func cleanupOldBackups() {
            guard let iCloudURL = FileManagerHelper.iCloudDocumentsURL else { return }
            
            let backupsFolder = iCloudURL.appendingPathComponent("Daily Backups")
            
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: backupsFolder,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )
                
                let calendar = Calendar.current
                let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date())!
                
                for url in contents {
                    if let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
                       creationDate < cutoffDate {
                        try? FileManager.default.removeItem(at: url)
                        print("🗑️ Deleted old backup: \(url.lastPathComponent)")
                    }
                }
            } catch {
                print("⚠️ Cleanup error: \(error)")
            }
        }
}
