import SwiftUI

struct HappyHourSettingsView: View {
    @ObservedObject var vm: InventoryVM
    @State private var showingAddSchedule = false
    @State private var editingSchedule: HappyHourSchedule?
    
    var body: some View {
        Form {
            // Status Section
            Section {
                Toggle("Happy Hour Enabled", isOn: $vm.happyHourConfig.isEnabled)
                    .onChange(of: vm.happyHourConfig.isEnabled) { _, _ in
                        vm.saveState()
                    }
                
                HStack {
                    Text("Current Status:")
                    Spacer()
                    if vm.isHappyHourActive() {
                        Text("ACTIVE 🎉")
                            .foregroundStyle(.green)
                            .bold()
                    } else {
                        Text("Inactive")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Manual Override Section
            Section("Manual Override") {
                Picker("Override Mode", selection: $vm.happyHourConfig.manualOverride) {
                    Text("Auto (Follow Schedule)").tag(nil as Bool?)
                    Text("Force ON").tag(true as Bool?)
                    Text("Force OFF").tag(false as Bool?)
                }
                .onChange(of: vm.happyHourConfig.manualOverride) { _, _ in
                    vm.saveState()
                }
                
                Text("Manual override ignores the schedule below")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Schedule Section
            Section {
                ForEach(vm.happyHourConfig.schedule) { schedule in
                    Button {
                        editingSchedule = schedule
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(schedule.displayDays)
                                .font(.headline)
                            Text(schedule.displayTime)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { indexSet in
                    vm.happyHourConfig.schedule.remove(atOffsets: indexSet)
                    vm.saveState()
                }
                
                Button {
                    showingAddSchedule = true
                } label: {
                    Label("Add Time Range", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Schedule")
            } footer: {
                Text("Happy hour will automatically activate during these times")
            }
        }
        .navigationTitle("Happy Hour Settings")
        .sheet(isPresented: $showingAddSchedule) {
            EditHappyHourScheduleSheet(
                schedule: HappyHourSchedule(),
                onSave: { newSchedule in
                    vm.happyHourConfig.schedule.append(newSchedule)
                    vm.saveState()
                    showingAddSchedule = false
                }
            )
        }
        .sheet(item: $editingSchedule) { schedule in
            EditHappyHourScheduleSheet(
                schedule: schedule,
                onSave: { updatedSchedule in
                    if let index = vm.happyHourConfig.schedule.firstIndex(where: { $0.id == schedule.id }) {
                        vm.happyHourConfig.schedule[index] = updatedSchedule
                    }
                    vm.saveState()
                    editingSchedule = nil
                }
            )
        }
    }
}

// MARK: - Edit Schedule Sheet
struct EditHappyHourScheduleSheet: View {
    let schedule: HappyHourSchedule
    let onSave: (HappyHourSchedule) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDays: Set<Int> = []
    @State private var startHour: Int = 16
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 19
    @State private var endMinute: Int = 0
    
    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private let hours = Array(0...23)
    private let minutes = [0, 15, 30, 45]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Days") {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(dayNames[day - 1], isOn: Binding(
                            get: { selectedDays.contains(day) },
                            set: { isOn in
                                if isOn {
                                    selectedDays.insert(day)
                                } else {
                                    selectedDays.remove(day)
                                }
                            }
                        ))
                    }
                }
                
                Section("Start Time") {
                    Picker("Hour", selection: $startHour) {
                        ForEach(hours, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    Picker("Minute", selection: $startMinute) {
                        ForEach(minutes, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                }
                
                Section("End Time") {
                    Picker("Hour", selection: $endHour) {
                        ForEach(hours, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    Picker("Minute", selection: $endMinute) {
                        ForEach(minutes, id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                }
            }
            .navigationTitle("Happy Hour Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(selectedDays.isEmpty)
                }
            }
            .onAppear {
                loadValues()
            }
        }
    }
    
    private func loadValues() {
        selectedDays = Set(schedule.daysOfWeek)
        startHour = schedule.startHour
        startMinute = schedule.startMinute
        endHour = schedule.endHour
        endMinute = schedule.endMinute
    }
    
    private func saveSchedule() {
        var updated = schedule
        updated.daysOfWeek = Array(selectedDays).sorted()
        updated.startHour = startHour
        updated.startMinute = startMinute
        updated.endHour = endHour
        updated.endMinute = endMinute
        
        onSave(updated)
        dismiss()
    }
    
    private func formatHour(_ hour: Int) -> String {
        if hour == 0 {
            return "12 AM"
        } else if hour < 12 {
            return "\(hour) AM"
        } else if hour == 12 {
            return "12 PM"
        } else {
            return "\(hour - 12) PM"
        }
    }
}

