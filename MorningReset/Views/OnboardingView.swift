import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    private let titles = ["A calmer morning", "Choose your distractions", "Set it once", "Make it your routine", "Gentle reminders"]
    private var stages: [Int] { BuildMode.isDemo ? [0, 3, 4] : [0, 1, 2, 3, 4] }
    private var stage: Int { stages[step] }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(step + 1), total: Double(stages.count)).tint(ResetTheme.accent).padding(.horizontal, 24)
                Group {
                    switch stage {
                    case 0: introduction
                    case 1:
                        if BuildMode.usesShortcuts { redirectSetup } else { permissions }
                    case 2: schedule
                    case 3: routine
                    default: reminders
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 8) {
                    PrimaryButton(title: stage == 4 ? (BuildMode.isDemo ? "Start my demo" : "Start my mornings") : "Continue", symbol: "arrow.right",
                                  disabled: stage == 3 && model.state.routine.isEmpty) {
                        if stage == 4 { model.finishOnboarding() } else { step += 1 }
                    }
                    if stage == 1 && BuildMode.usesShortcuts && !model.redirectSettings.setupConfirmed {
                        Text("You can finish onboarding and set up redirects later in Settings. Apps won’t redirect until you connect the automation and enable redirects.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    } else if stage == 1 && !BuildMode.usesShortcuts && (!model.state.accessAvailable || model.state.selectionCount == 0) {
                        Text("You can continue in demo mode and enable protection later.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                }.padding(24).background(ResetTheme.background)
            }.background(ResetTheme.background).navigationTitle(stage == 1 && BuildMode.usesShortcuts ? "Connect your apps" : titles[stage])
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if step > 0 { ToolbarItem(placement: .topBarLeading) { Button("Back") { step -= 1 } } }
                }
        }
    }
    private var introduction: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: "sun.horizon.fill").font(.system(size: 70)).foregroundStyle(ResetTheme.accent).accessibilityHidden(true)
                Text("Your morning,\nbefore the scroll.").font(.largeTitle.bold())
                Text(BuildMode.usesShortcuts ? "Connect a Shortcuts automation once. During your nightly routine period, it sends you back here when you open a distracting app. Finish your routine, then take ten minutes for yourself." : BuildMode.isDemo ? "Explore a short morning routine with timed, self-confirmed tasks and a ten-minute pause. This demo keeps other apps available." : "Shield distracting apps overnight. When you’re awake, complete a short routine, then take ten minutes for yourself.")
                    .font(.title3).foregroundStyle(.secondary)
                ResetCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Label(BuildMode.usesShortcuts ? "Connect your apps with a guided setup" : BuildMode.isDemo ? "Choose your morning tasks" : "Choose the apps and lock time", systemImage: "moon")
                        Label("Start and confirm each timed task", systemImage: "checkmark.circle")
                        Label(BuildMode.usesShortcuts ? "Redirects stop after the ten-minute pause" : BuildMode.isDemo ? "Take ten minutes for yourself" : "Return after ten minutes to release", systemImage: "sun.max")
                    }
                }
                Text("Self-confirmed habits. On-device data. An escape option whenever you need it.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
    private var redirectSetup: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "arrow.uturn.backward").font(.system(size: 56)).foregroundStyle(ResetTheme.accent).accessibilityHidden(true)
                Text("A small detour before the scroll.").font(.largeTitle.bold())
                Text("You create one automation in Apple’s Shortcuts app and choose several distracting apps together. We’ll guide you through each step, then test the redirect.")
                    .foregroundStyle(.secondary)
                NavigationLink { ShortcutSetupView() } label: {
                    Label(model.redirectSettings.setupConfirmed ? "Review setup tutorial" : "Start step-by-step tutorial", systemImage: "list.number")
                }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                if model.redirectSettings.setupConfirmed {
                    Label("Setup confirmed by you", systemImage: "checkmark.circle").foregroundStyle(ResetTheme.accent)
                }
                Text("One-time setup per device. No daily configuration. Redirects are voluntary and can be disabled; they do not lock other apps.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
    private var permissions: some View {
        Form {
            Section {
                Text("Screen Time lets Morning Reset shield only the apps you choose. Access is voluntary and can be revoked.")
                Label(model.state.accessAvailable ? "Screen Time access available" : "Screen Time access is off",
                      systemImage: model.state.accessAvailable ? "checkmark.circle" : "lock.open")
                Button("Enable Screen Time access") { Task { await model.authorize() } }
                AppSelectionControl()
            }
        }.scrollContentBackground(.hidden)
    }
    private var schedule: some View {
        Form {
            Section {
                Text(BuildMode.usesShortcuts ? "Choose when your nightly redirect period begins. Each attempt to open a selected app checks this schedule. Redirects continue until the routine and ten-minute pause finish, or you bypass." : "Choose your daily lock time. Protection continues until you finish your morning flow or explicitly unlock.")
                    .foregroundStyle(.secondary)
                ScheduleControl()
            }
        }.scrollContentBackground(.hidden)
    }
    private var routine: some View {
        RoutineView().navigationTitle(titles[3])
    }
    private var reminders: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "bell.badge").font(.system(size: 56)).foregroundStyle(ResetTheme.accent).accessibilityHidden(true)
                Text("A nudge, if you want one.").font(.largeTitle.bold())
                Text(BuildMode.usesShortcuts ? "Get a reminder when a task timer finishes and when your ten-minute pause ends. Confirm each task here. The automation stops redirecting when its next check finds the pause finished." : BuildMode.isDemo ? "Get a reminder when a task timer finishes and when your ten-minute pause ends. Open the demo to confirm tasks and finish your session." : "Get a reminder when a task timer finishes and when your ten-minute wait ends. You’ll open Morning Reset to confirm tasks and release apps.")
                    .foregroundStyle(.secondary)
                Button(model.state.notificationsEnabled ? "Reminders enabled" : "Enable optional reminders") {
                    Task { await model.enableNotifications() }
                }.buttonStyle(.bordered).frame(minHeight: 44)
                Text("Declining reminders won’t affect your routine. Saved deadlines keep your progress when you put your phone down.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
}
