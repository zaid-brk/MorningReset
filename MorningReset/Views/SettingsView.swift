import SwiftUI
#if !MORNING_RESET_DEMO && !MORNING_RESET_SHORTCUTS
import FamilyControls
#endif
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmBypass = false
    var body: some View {
        Form {
            protectionSections
            Section("Optional reminders") {
                Toggle("Timer reminders", isOn: Binding(get: { model.state.notificationsEnabled }, set: { value in
                    if value { Task { await model.enableNotifications() } } else { model.disableNotifications() }
                }))
                Text(BuildMode.usesShortcuts ? "Task reminders invite you to confirm. After the ten-minute pause, the next automation check stops redirecting for that period. Reminders do not execute a redirect or unlock." : BuildMode.isDemo ? "Reminders ask you to return to the demo to confirm a task or finish your ten-minute pause." : "Task reminders invite you to confirm. Wait reminders ask you to open Morning Reset to release apps after ten minutes.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Open iPhone Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            }
            Section {
                if !BuildMode.usesLocalStorage { NavigationLink("Screen Time feasibility checks") { FeasibilityView() } }
                NavigationLink("Routine history") { HistoryView() }
            } header: { Text("About & testing") } footer: {
                Text("Your routine and history stay on this iPhone. No account, backend, or activity verification.")
            }
        }.scrollContentBackground(.hidden).background(ResetTheme.background).navigationTitle("Settings")
            .confirmationDialog(BuildMode.usesShortcuts ? "Skip this redirect period?" : BuildMode.isDemo ? "End this demo session?" : "Unlock without completing?", isPresented: $confirmBypass, titleVisibility: .visible) {
                Button(BuildMode.usesShortcuts ? "Skip without completing" : BuildMode.isDemo ? "End demo" : "Unlock without completing", role: .destructive) { model.bypass() }
                Button("Cancel", role: .cancel) {}
            } message: { Text(BuildMode.usesShortcuts ? "Redirects stop for the current period. The bypass is saved without protected streak credit." : BuildMode.isDemo ? "The demo session will be recorded as bypassed." : "The current protection period will end. This bypass won’t add to your streak.") }
    }

    @ViewBuilder private var protectionSections: some View {
        if BuildMode.usesShortcuts {
            Section("App redirects") {
                Label(model.redirectSettings.setupConfirmed ? "Setup confirmed by you" : "Setup not confirmed",
                      systemImage: model.redirectSettings.setupConfirmed ? "checkmark.circle" : "exclamationmark.circle")
                NavigationLink { ShortcutSetupView() } label: {
                    Label("Step-by-step setup & test", systemImage: "list.number")
                }
                Text("Selected apps are chosen in Shortcuts, not here. Reopen your automation there to change them. This app cannot verify that it is still connected or enabled.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Nightly redirects") { ScheduleControl() }
            Section("Right now") {
                Label(model.redirectSettings.period?.active == true && model.redirectSettings.enabled ? "A redirect period is active" : "No active routine redirect period",
                      systemImage: "arrow.uturn.backward")
                if let requested = model.redirectSettings.lastCheckRequestedRedirect,
                   let checked = model.redirectSettings.lastCheckAt {
                    LabeledContent("Last check", value: requested ? "Yes · return here" : "No · allow other apps")
                    Text("Checked at \(checked.formatted(date: .omitted, time: .standard)).")
                        .font(.caption).foregroundStyle(.secondary)
                    if !requested {
                        Text("If an app still sends you here, check the automation in Shortcuts: Open App belongs inside If, and If must test the Boolean result, not whether a value exists. Also check for a second automation for the same apps.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text("Your automation checks the schedule when a selected app opens. It does not close an app already on screen or impose an iOS lock. Redirects may be delayed or fail if the automation or installation is unavailable.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if model.activeSession != nil || model.redirectSettings.period?.active == true {
                    Button("Skip without completing", role: .destructive) { confirmBypass = true }.frame(minHeight: 44)
                }
            }
        } else if BuildMode.isDemo {
            Section("About this demo") {
                Label("Other apps stay available", systemImage: "info.circle")
                Text("Test your routine, saved timers, and history. This free demo does not block apps, run nightly protection, or award protected streaks.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if model.activeSession != nil {
                    Button("End demo without completing", role: .destructive) { confirmBypass = true }.frame(minHeight: 44)
                }
            }
            Section("Schedule preview") { ScheduleControl() }
        } else {
            Section {
                Label(model.state.accessAvailable ? "Access available" : "Access unavailable", systemImage: model.state.accessAvailable ? "checkmark.circle" : "exclamationmark.circle")
                Button(model.state.accessAvailable ? "Review Screen Time access" : "Restore Screen Time access") {
                    Task { await model.authorize() }
                }.frame(minHeight: 44)
                AppSelectionControl()
            } header: { Text("Screen Time") } footer: { Text("Individual authorization is voluntary. You can revoke access or remove this app. Morning Reset cannot prevent those choices.") }
            Section("Nightly schedule") { ScheduleControl() }
            Section("Protection right now") {
                Label(model.shieldApplied ? "Selected apps are shielded" : "Restrictions are inactive",
                      systemImage: model.shieldApplied ? "lock.shield" : "lock.open")
                Text(model.monitoringActive ? "Nightly monitoring is registered with iOS." : "Nightly monitoring is inactive. Enable the schedule after restoring access and selecting apps.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if model.shieldApplied || model.activeSession != nil {
                    Button("Unlock without completing", role: .destructive) { confirmBypass = true }.frame(minHeight: 44)
                }
            }
        }
    }
}

struct AppSelectionControl: View {
    #if MORNING_RESET_DEMO || MORNING_RESET_SHORTCUTS
    var body: some View { Text("App selection is available in the full Screen Time build.").foregroundStyle(.secondary) }
    #else
    @EnvironmentObject private var model: AppModel
    @State private var selection = FamilyActivitySelection()
    @State private var presentingPicker = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                selection = ScreenTimeBridge.selection(in: model.state)
                presentingPicker = true
            } label: {
                Label("Choose apps · \(model.state.selectionCount) selected", systemImage: "apps.iphone")
                    .frame(minHeight: 44)
            }.disabled(!model.state.accessAvailable)
            Text("Expand categories and select individual apps. Category-wide restrictions and websites aren’t saved.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .familyActivityPicker(isPresented: $presentingPicker, selection: $selection)
        .onChange(of: presentingPicker) { wasPresented, isPresented in
            if wasPresented && !isPresented { model.saveSelection(selection) }
        }
    }
    #endif
}

struct ScheduleControl: View {
    @EnvironmentObject private var model: AppModel
    @State private var chosenTime = ResetTheme.timeDate(LockTime())
    @State private var showingTonight = false
    var body: some View {
        Group {
            if BuildMode.usesShortcuts {
                Toggle("Enable app redirects", isOn: Binding(get: { model.redirectSettings.enabled }, set: { model.setRedirectsEnabled($0) }))
                    .disabled(!model.redirectSettings.setupConfirmed)
            } else if !BuildMode.isDemo {
            Toggle("Enable nightly protection", isOn: Binding(get: { model.state.scheduleEnabled }, set: { enabled in
                model.setSchedule(time: ResetTheme.lockTime(chosenTime), override: model.state.tonightOverride, enabled: enabled)
            })).disabled(!model.state.accessAvailable || model.state.selectionCount == 0)
            }
            DatePicker(BuildMode.usesShortcuts ? "Nightly redirect time" : "Usual lock time", selection: $chosenTime, displayedComponents: .hourAndMinute)
            Button("Save usual time") {
                model.setSchedule(time: ResetTheme.lockTime(chosenTime), override: model.state.tonightOverride,
                                  enabled: model.state.scheduleEnabled)
            }.frame(minHeight: 44)
            Text(BuildMode.usesShortcuts ? "Repeats daily. Enabling starts with the next nightly time; starting a routine also starts redirects. Changing the time does not end an active period. No nightly automation is needed." : BuildMode.isDemo ? "This saves a preview time only. No nightly restriction runs in the demo." : "Repeats every day. Changing the schedule does not end protection that has already started.")
                .font(.caption).foregroundStyle(.secondary)
            if !BuildMode.usesLocalStorage {
            Button("Adjust tonight only") { showingTonight = true }.frame(minHeight: 44)
            if let adjustment = model.state.tonightOverride,
               adjustment.dateKey == CalendarRules.dateKey(Date(), calendar: CalendarRules.localCalendar()) {
                Text("Tonight: \(ResetTheme.timeDate(adjustment.time).formatted(date: .omitted, time: .shortened))")
                Button("Use usual time tonight") {
                    model.setSchedule(time: model.state.lockTime, override: nil, enabled: model.state.scheduleEnabled)
                }
            }
            }
        }.onAppear { chosenTime = ResetTheme.timeDate(model.state.lockTime) }
            .sheet(isPresented: $showingTonight) {
                NavigationStack { TonightAdjustmentView() }.environmentObject(model)
            }
    }
}

struct TonightAdjustmentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var time = Date().addingTimeInterval(3600)
    @State private var message: String?
    var body: some View {
        Form {
            Section {
                DatePicker("Tonight’s lock time", selection: $time, displayedComponents: .hourAndMinute)
                Text("Choose a later time today. Your usual daily schedule stays the same. An active restriction stays active.")
                    .foregroundStyle(.secondary)
                if let message { Text(message).foregroundStyle(.red) }
            }
        }.navigationTitle("Tonight only").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let calendar = CalendarRules.localCalendar()
                        let lock = ResetTheme.lockTime(time)
                        let target = CalendarRules.night(on: Date(), time: lock, calendar: calendar)
                        guard target > Date() else { message = SetupError.pastOverride.localizedDescription; return }
                        model.setSchedule(time: model.state.lockTime,
                            override: TonightOverride(dateKey: CalendarRules.dateKey(Date(), calendar: calendar), time: lock),
                            enabled: model.state.scheduleEnabled)
                        dismiss()
                    }
                }
            }
    }
}

struct FeasibilityView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmLock = false
    var body: some View {
        List {
            Section("Real Screen Time prototype") {
                Text("These controls use actual iOS app shielding. Prototype sessions never count toward a protected routine streak.")
                Button("Shield selected apps now") { confirmLock = true }
                    .disabled(!model.state.accessAvailable || model.state.selectionCount == 0)
                Button("Release prototype restriction") {
                    if model.state.protection?.isPrototype == true { model.bypass() }
                }.disabled(model.state.protection?.isPrototype != true)
            }
            Section("Check on your iPhone") {
                Text("1. Authorize Screen Time and choose one distracting app.")
                Text("2. Shield it here, then try opening that app.")
                Text("3. Release the prototype restriction and try opening it again.")
                Text("4. Set tonight’s time a few minutes ahead, enable the schedule, and terminate Morning Reset. Check that the chosen app becomes shielded.")
                Text("5. Run the routine, background and relaunch during a task, then complete the ten-minute wait. Return after expiry to release.")
                Text("6. Repeat with restart, revoked permissions, and a new night during an unfinished session.")
            }
            Section("Platform limitation") {
                Text("Release occurs when you reopen Morning Reset after the ten-minute deadline. Notifications cannot execute an unlock, and a ten-minute DeviceActivity interval is below Apple’s documented minimum.")
            }
            Section("Recent local diagnostics") {
                ForEach(Array(model.state.diagnostics.reversed().enumerated()), id: \.offset) { item in
                    Text(item.element).font(.caption).textSelection(.enabled)
                }
            }
        }.navigationTitle("Feasibility checks").navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Start a real shielding prototype?", isPresented: $confirmLock, titleVisibility: .visible) {
                Button("Shield selected apps") { model.prototypeLock() }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This interrupts an active session. You can release the restriction here or use Unlock without completing.") }
    }
}

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        List {
            if model.state.history.isEmpty {
                ContentUnavailableView("Your mornings will appear here", systemImage: "sun.horizon",
                    description: Text("Completed, bypassed, and interrupted sessions are saved locally."))
            }
            ForEach(model.state.history.reversed()) { entry in
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.localDate).font(.headline)
                    Text(outcome(entry)).foregroundStyle(.secondary)
                    if entry.isDemo || entry.isPrototype {
                        Text(BuildMode.usesShortcuts ? "Shortcuts routine · no protected streak credit" : entry.isDemo ? "Demo · no streak credit" : "Prototype · no streak credit").font(.caption)
                    }
                }.padding(.vertical, 6).accessibilityElement(children: .combine)
            }
        }.navigationTitle("Routine history")
    }
    private func outcome(_ entry: HistoryEntry) -> String {
        if entry.protectedSuccess { return "Protected morning complete" }
        switch entry.outcome {
        case .bypassed: return "Bypassed"
        case .interrupted: return BuildMode.usesShortcuts ? "Interrupted by a new redirect period" : "Interrupted by a new protection period"
        default: return "Complete · no protected streak credit"
        }
    }
}
