import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmBypass = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let session = model.activeSession {
                    RoutineSessionView(session: session)
                } else {
                    dashboard
                }
                if BuildMode.usesShortcuts && !model.redirectSettings.setupConfirmed {
                    NavigationLink { ShortcutSetupView() } label: {
                        Label("Set up app redirects · step-by-step guide", systemImage: "list.number")
                    }.frame(minHeight: 44)
                }
            }.padding(24).frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
        }
        .background(ResetTheme.background).navigationTitle("Today")
        .toolbarBackground(ResetTheme.background, for: .navigationBar)
        .confirmationDialog("Skip this redirect period?", isPresented: $confirmBypass, titleVisibility: .visible) {
            Button("Skip without completing", role: .destructive) { model.bypass() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Redirects stop for the current period. This is recorded as a bypass, without protected streak credit.") }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "A calmer start")
                Text("Make room\nfor your morning.").font(.largeTitle.bold())
                Text("A few small tasks. A little space before the scroll.")
                    .font(.body).foregroundStyle(.secondary)
            }
            ResetCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        Image(systemName: model.shieldApplied ? "moon.fill" : "sun.horizon.fill")
                            .font(.system(size: 38)).foregroundStyle(ResetTheme.accent).accessibilityHidden(true)
                        Spacer()
                        Text(BuildMode.usesShortcuts ? "SHORTCUTS" : BuildMode.isDemo ? "DEMO" : model.shieldApplied ? "PROTECTED" : "STATUS")
                            .font(.caption.weight(.semibold)).foregroundStyle(ResetTheme.accent)
                            .padding(9).background(ResetTheme.accent.opacity(0.10), in: Capsule())
                    }
                    Text(statusTitle).font(.title2.bold())
                    Text(statusDetail).foregroundStyle(.secondary)
                    if BuildMode.usesShortcuts {
                        PrimaryButton(title: "I’m awake", symbol: "arrow.right", disabled: model.state.routine.isEmpty) { model.startMorning() }
                        if model.redirectSettings.enabled {
                            Text("Starting a routine also starts a redirect period. Your automation must be connected.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if model.redirectSettings.period?.active == true {
                            Button("Skip this redirect period") { confirmBypass = true }.frame(minHeight: 44)
                        }
                    } else if BuildMode.isDemo {
                        PrimaryButton(title: "I’m awake", symbol: "arrow.right", disabled: model.state.routine.isEmpty) { model.startMorning() }
                    } else if model.shieldApplied && model.state.protection?.active == true {
                        PrimaryButton(title: "I’m awake", symbol: "arrow.right", disabled: model.state.routine.isEmpty) { model.startMorning() }
                        if model.state.protection?.isPrototype == true {
                            Text("Prototype protection · real shields, no streak credit").font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Button("Try the routine in demo mode") { model.startMorning(demo: true) }
                            .frame(minHeight: 44)
                        Text("Demo mode does not restrict apps or count toward your streak.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if model.state.session?.phase == .released {
                Label(model.state.session?.successRecorded == true ? "Your morning routine is complete." : "Session complete.", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(ResetTheme.accent)
            }
            if BuildMode.usesShortcuts { shortcutsHistoryCard } else { streakCard }
            ResetCard {
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: "Your routine")
                    ForEach(model.state.routine) { task in
                        HStack {
                            Image(systemName: ResetTheme.symbol(for: task.title)).frame(width: 24).foregroundStyle(ResetTheme.accent)
                            Text(task.title)
                            Spacer()
                            Text(ResetTheme.duration(task.duration)).font(.subheadline).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                    }
                    if model.state.routine.isEmpty { Text("Add a task in Routine to get started.").foregroundStyle(.secondary) }
                }
            }
        }
    }

    private var statusTitle: String {
        if BuildMode.usesShortcuts {
            if !model.redirectSettings.setupConfirmed { return "Connect your distracting apps" }
            if !model.redirectSettings.enabled { return "App redirects are paused" }
            if model.redirectSettings.period?.active == true { return "Time for your morning routine" }
            return "Ready for tonight"
        }
        if BuildMode.isDemo { return "Your demo is ready" }
        if !model.state.accessAvailable { return "Screen Time access is off" }
        if model.state.selectionCount == 0 { return "Choose your distracting apps" }
        if model.shieldApplied { return "Your selected apps are shielded" }
        if model.monitoringActive { return "Ready for tonight" }
        return "Nightly protection is inactive"
    }
    private var statusDetail: String {
        if BuildMode.usesShortcuts {
            if !model.redirectSettings.setupConfirmed { return "Follow the one-time tutorial to connect your apps in Shortcuts. Until then, this app cannot interrupt scrolling." }
            if !model.redirectSettings.enabled { return "Enable app redirects in Settings when you’re ready. Your routine remains available." }
            if model.redirectSettings.period?.active == true { return "Your automation should send you back here when you open selected apps. Complete your routine and ten-minute pause, or choose to skip." }
            let next = CalendarRules.nextNight(in: model.state, at: Date(), calendar: CalendarRules.localCalendar())
            return "Next redirect period: \(next.formatted(date: .abbreviated, time: .shortened)). Setup is confirmed by you; the app cannot verify the automation is still enabled."
        }
        if BuildMode.isDemo { return "Try your routine with saved timers and a ten-minute pause. Other apps stay available, and demo sessions do not earn protected streak credit." }
        if !model.state.accessAvailable { return "Restore access in Settings to enable real app protection." }
        if model.state.selectionCount == 0 { return "Select individual apps in Settings. Only your selection will be restricted." }
        if model.shieldApplied { return "Start when you’re awake. Your apps stay shielded through your routine and the ten-minute wait." }
        if model.monitoringActive {
            let next = CalendarRules.nextNight(in: model.state, at: Date(), calendar: CalendarRules.localCalendar())
            return "Your next nightly lock is \(next.formatted(date: .abbreviated, time: .shortened))."
        }
        return "Enable your recurring schedule in Settings."
    }
    private var streakCard: some View {
        ResetCard {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(text: "Routine streak")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) { streakItems }
                    VStack(alignment: .leading, spacing: 16) { streakItems }
                }
                Text(BuildMode.usesShortcuts ? "Shortcuts routines appear in history but do not earn protected streak credit. Activities are self-confirmed." : BuildMode.isDemo ? "Protected streaks stay at zero in this demo. Your sessions still appear in history." : "Timed and self-confirmed. Activities aren’t physically verified.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var shortcutsHistoryCard: some View {
        ResetCard {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "Your mornings")
                Text("\(model.state.history.filter { $0.outcome == .released }.count)").font(.title.bold()).monospacedDigit()
                Text("Completed routines").foregroundStyle(.secondary)
                NavigationLink("View routine history") { HistoryView() }.frame(minHeight: 44)
                Text("History records your self-confirmed routines. It does not verify that other apps stayed unused.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    @ViewBuilder private var streakItems: some View {
        stat(model.streak.current, label: "Current")
        stat(model.streak.best, label: "Best")
        stat(model.streak.thisWeek, label: "This week")
    }
    private func stat(_ count: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(count)").font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}
