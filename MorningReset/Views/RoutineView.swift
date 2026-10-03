import SwiftUI

struct RoutineView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showPresets = false
    @State private var editing: RoutineTask?
    var body: some View {
        List {
            Section {
                Text("Keep it short. Start each timer, do the task, then confirm when you’re done.")
                    .foregroundStyle(.secondary).listRowBackground(Color.clear)
                if model.activeSession != nil {
                    Label("Edits apply to your next session. Your active routine keeps its saved tasks and durations.", systemImage: "info.circle")
                        .font(.subheadline).listRowBackground(Color.clear)
                }
            }
            Section {
                ForEach(model.state.routine) { task in
                    Button { editing = task } label: {
                        HStack(spacing: 14) {
                            Image(systemName: ResetTheme.symbol(for: task.title))
                                .font(.title3).foregroundStyle(ResetTheme.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(task.title).foregroundStyle(.primary)
                                Text(ResetTheme.duration(task.duration)).font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        }.padding(.vertical, 8).frame(minHeight: 44)
                    }
                }
                .onDelete { indices in var tasks = model.state.routine; tasks.remove(atOffsets: indices); model.saveRoutine(tasks) }
                .onMove { indices, destination in var tasks = model.state.routine; tasks.move(fromOffsets: indices, toOffset: destination); model.saveRoutine(tasks) }
                Button { showPresets = true } label: { Label("Add a task", systemImage: "plus.circle.fill").frame(minHeight: 44) }
            } header: { Text("Your morning tasks") } footer: {
                Text(model.state.routine.isEmpty ? "Add at least one task before starting a morning routine." : "Minimum 15 seconds per task. Tap Edit to reorder or remove tasks.")
            }
            Section {
                Label("Timed and self-confirmed", systemImage: "hand.raised")
                Text("Morning Reset records your confirmations. It does not verify exercise, brushing, or any other physical activity.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden).background(ResetTheme.background)
        .navigationTitle("Routine").toolbar { EditButton() }
        .sheet(isPresented: $showPresets) {
            NavigationStack { TaskPresetsView() }.environmentObject(model)
        }
        .sheet(item: $editing) { task in
            NavigationStack { TaskEditorView(task: task) }.environmentObject(model)
        }
    }
}

struct TaskPresetsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: RoutineTask?
    private let presets = [
        RoutineTask(title: "10 push-ups", duration: 30), RoutineTask(title: "20 jumping jacks", duration: 30),
        RoutineTask(title: "Stretching", duration: 60), RoutineTask(title: "Brush teeth", duration: 120),
        RoutineTask(title: "Use the bathroom", duration: 60), RoutineTask(title: "Drink water", duration: 30),
        RoutineTask(title: "Make the bed", duration: 60)
    ]
    var body: some View {
        List {
            Section("Start with a small habit") {
                ForEach(presets) { task in
                    Button { selected = task } label: {
                        Label(task.title, systemImage: ResetTheme.symbol(for: task.title)).frame(minHeight: 44)
                    }
                }
            }
            Section {
                Button { selected = RoutineTask(title: "", duration: 30) } label: {
                    Label("Write your own", systemImage: "square.and.pencil").frame(minHeight: 44)
                }
            }
        }.navigationTitle("Add a task").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selected) { task in
                NavigationStack { TaskEditorView(task: task, afterSave: { dismiss() }) }
            }
    }
}

struct TaskEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let task: RoutineTask
    var afterSave: (() -> Void)? = nil
    @State private var title: String
    @State private var durationText: String

    init(task: RoutineTask, afterSave: (() -> Void)? = nil) {
        self.task = task; self.afterSave = afterSave
        _title = State(initialValue: task.title)
        _durationText = State(initialValue: String(Int(task.duration)))
    }
    private var duration: Double? { Double(durationText) }
    private var valid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && duration.map { $0.isFinite && $0 >= 15 && $0 < Double(Int.max) } == true
    }
    var body: some View {
        Form {
            Section("Task") {
                TextField("Title, including repetitions if needed", text: $title)
                    .textInputAutocapitalization(.sentences)
            }
            Section {
                HStack {
                    Text("Duration in seconds")
                    Spacer()
                    TextField("30", text: $durationText).keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing).frame(minWidth: 60)
                        .accessibilityLabel("Duration in seconds")
                }
                HStack {
                    ForEach([30, 60, 120], id: \.self) { value in
                        Button(ResetTheme.duration(Double(value))) { durationText = String(value) }
                            .buttonStyle(.bordered).frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            } header: { Text("Give yourself time") } footer: { Text("At least 15 seconds. You can always take longer before confirming.") }
        }.navigationTitle("Edit task").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let duration, valid else { return }
                        let updated = RoutineTask(id: task.id, title: title, duration: duration)
                        var tasks = model.state.routine
                        if let index = tasks.firstIndex(where: { $0.id == task.id }) { tasks[index] = updated }
                        else { tasks.append(updated) }
                        model.saveRoutine(tasks)
                        dismiss(); afterSave?()
                    }.disabled(!valid)
                }
            }
    }
}
