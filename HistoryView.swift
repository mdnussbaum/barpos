import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var vm: InventoryVM

    enum Scope: String, CaseIterable, Identifiable {
        case thisShift = "This Shift"
        case myShifts  = "My Shifts"
        case allTime   = "All Time"
        var id: String { rawValue }
    }
    
    @State private var presentingTicket: CloseResult? = nil
    // UI state
    @State private var scope: Scope = .thisShift

    // Admin PIN
    @State private var showPIN = false
    @State private var pinText = ""
    @State private var pinError = ""

    var body: some View {
        VStack {
            // Segmented control — "All Time" only when admin is unlocked
            Picker("Scope", selection: $scope) {
                Text(Scope.thisShift.rawValue).tag(Scope.thisShift)
                Text(Scope.myShifts.rawValue).tag(Scope.myShifts)
                if vm.isAdminUnlocked {
                    Text(Scope.allTime.rawValue).tag(Scope.allTime)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            // iOS 17 onChange signature
            .onChange(of: scope) { _, newValue in
                guard newValue == .allTime else { return }
                if !vm.isAdminUnlocked {
                    scope = .myShifts
                    showPIN = true
                    pinText = ""
                    pinError = ""
                }
            }

            // Content for each scope
            switch scope {
            case .thisShift:
                // Tickets for the current (open) shift
                List(vm.closedTabs) { t in
                    Button {
                        presentingTicket = t
                    } label: {
                        ticketRow(t)
                    }
                }
                .listStyle(.insetGrouped)

            case .myShifts:
                // Group THIS bartender's tickets by calendar day
                let groups = groupMyTicketsByDay()
                List {
                    ForEach(groups, id: \.day) { group in
                        let total = group.tickets.reduce(0 as Decimal) { $0 + $1.total }
                        NavigationLink {
                            MyShiftDayView(
                                day: group.day,
                                tickets: group.tickets,
                                report: reportForMyDay(group.day)
                            )
                            .environmentObject(vm)
                        } label: {
                            // ▼▼ REPLACED LABEL STARTS HERE ▼▼
                            let rep = reportForMyDay(group.day)
                            let flagged = (rep?.flagged == true)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.day.formatted(date: .abbreviated, time: .omitted)).bold()
                                    Text("\(group.tickets.count) tickets")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Text(total.currencyString()).bold()
                                    if vm.isAdminUnlocked, flagged {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.yellow)
                                            .accessibilityLabel("Flagged discrepancy")
                                    }
                                }
                            }
                            // ▲▲ REPLACED LABEL ENDS HERE ▲▲
                        }
                    }
                }
                .listStyle(.insetGrouped)

            case .allTime:
                // Group ALL tickets by calendar day (across bartenders)
                let groups = groupAllTicketsByDay()
                List {
                    ForEach(groups, id: \.day) { group in
                        let total = group.tickets.reduce(0 as Decimal) { $0 + $1.total }
                        NavigationLink {
                            AdminDayView(
                                day: group.day,
                                tickets: group.tickets,
                                reports: reportsForDay(group.day)
                            )
                            .environmentObject(vm)
                        } label: {
                            // ▼▼ REPLACED LABEL STARTS HERE ▼▼
                            let dayReports = reportsForDay(group.day)
                            let flagged = dayReports.contains { $0.flagged }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.day.formatted(date: .complete, time: .omitted)).bold()
                                    Text("\(group.tickets.count) tickets")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 8) {
                                    Text(total.currencyString()).bold()
                                    if vm.isAdminUnlocked, flagged {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.yellow)
                                            .accessibilityLabel("Flagged discrepancy")
                                    }
                                }
                            }
                            // ▲▲ REPLACED LABEL ENDS HERE ▲▲
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("History")
        // Admin PIN sheet
        .sheet(isPresented: $showPIN) {
            VStack(spacing: 16) {
                Text("Manager Access").font(.title3).bold()
                Text("Enter manager PIN to view All Time.")
                    .foregroundStyle(.secondary)

                SecureField("PIN", text: $pinText)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                if !pinError.isEmpty {
                    Text(pinError).foregroundStyle(.red).font(.footnote)
                }

                HStack {
                    Button("Cancel") { showPIN = false }
                    Spacer()
                    Button("Unlock") {
                        if vm.unlockAdmin(with: pinText) {
                            showPIN = false
                            scope = .allTime
                        } else {
                            pinError = "Incorrect PIN. Try again."
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .presentationDetents([.medium])
        }
        // ✅ New ticket-details sheet
        .sheet(item: $presentingTicket) { res in
            SummarySheet(result: res) {
                presentingTicket = nil
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // Toolbar lock/unlock (icon shows the action)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if vm.isAdminUnlocked {
                    Button {
                        vm.lockAdmin()
                        if scope == .allTime { scope = .myShifts }
                    } label: {
                        Label("Lock Admin", systemImage: "lock.fill")
                    }
                } else {
                    Button {
                        pinText = ""
                        pinError = ""
                        showPIN = true
                    } label: {
                        Label("Unlock Admin", systemImage: "lock.open")
                    }
                }
            }
        }
    }

    // MARK: - Rows

    private func ticketRow(_ t: CloseResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(t.tabName).bold()
                Text(t.closedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(t.total.currencyString()).bold()
        }
    }

    // MARK: - Shared Day grouping model

    private struct DayGroup {
        let day: Date
        let tickets: [CloseResult]
    }

    // MARK: - My Shifts helpers

    private func groupMyTicketsByDay() -> [DayGroup] {
        let meID = vm.currentBartenderID
        let meName = vm.currentBartenderName

        let mine = vm.allClosedTabs.filter { r in
            if let id = meID { return r.bartenderID == id }
            if let name = meName { return r.bartenderName == name }
            return false
        }

        let cal = Calendar.current
        let dict = Dictionary(grouping: mine) { (res: CloseResult) -> Date in
            cal.startOfDay(for: res.closedAt)
        }

        return dict.keys.sorted(by: >).map { day in
            DayGroup(day: day, tickets: dict[day] ?? [])
        }
    }

    private func reportForMyDay(_ day: Date) -> ShiftReport? {
        let cal = Calendar.current
        if let me = vm.currentBartenderID {
            return vm.shiftReports.first { rep in
                rep.bartenderID == me && cal.isDate(rep.endedAt, inSameDayAs: day)
            }
        }
        if let myName = vm.currentBartenderName {
            return vm.shiftReports.first { rep in
                rep.bartenderName == myName && cal.isDate(rep.endedAt, inSameDayAs: day)
            }
        }
        return nil
    }

    // MARK: - All Time helpers

    // Group ALL tickets by day
    private func groupAllTicketsByDay() -> [DayGroup] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: vm.allClosedTabs) { (res: CloseResult) -> Date in
            cal.startOfDay(for: res.closedAt)
        }
        return dict.keys.sorted(by: >).map { day in
            DayGroup(day: day, tickets: dict[day] ?? [])
        }
    }

    // All shift reports (any bartender) occurring on `day`
    private func reportsForDay(_ day: Date) -> [ShiftReport] {
        let cal = Calendar.current
        return vm.shiftReports.filter { rep in
            cal.isDate(rep.endedAt, inSameDayAs: day)
        }
    }
}
