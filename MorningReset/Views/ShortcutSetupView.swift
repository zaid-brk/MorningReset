import SwiftUI

/// The app supplies the check action; iOS requires the user to create the app trigger.
struct ShortcutSetupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL
    @SceneStorage("morningRedirectTutorialStep") private var page = 0
    private let steps: [(title: String, detail: String, symbol: String)] = [
        ("Open Shortcuts", "Open Apple’s Shortcuts app. Tap Automation at the bottom, then + or New Automation. If asked, choose Create Personal Automation.", "square.stack.3d.up"),
        ("Choose your distractions", "Choose the App trigger, then tap Choose. Select all the apps you want to interrupt in one automation, then tap Done. Leave Morning Reset Shortcuts and Shortcuts unselected so you can return here without a loop.", "apps.iphone"),
        ("Let it run automatically", "Select Is Opened, leaving Is Closed off. Choose Run Immediately, then Next. If your iOS version shows Ask Before Running instead, turn it off and confirm Don’t Ask.", "bolt"),
        ("Add the morning check", "Choose New Blank Automation, then Add Action or Search Actions. Search for Check Morning Redirect and add the action from Morning Reset Shortcuts. It checks your saved schedule and routine without opening this app.", "sun.horizon"),
        ("Add an If action", "Search for If and add it below the morning check. Set its input to the result of Check Morning Redirect (use Select Variable if needed). Set the condition to true or Yes. For a Boolean result, some versions simply show If Check Morning Redirect.", "arrow.triangle.branch"),
        ("Send yourself back here", "Search for Open App and put it inside the If section, above Otherwise. Tap its App field and choose Morning Reset Shortcuts. Leave Otherwise empty. Don’t put Open App after End If—that would redirect even after your routine is finished.", "arrow.uturn.backward"),
        ("Save and try it", "Tap Done to save the automation. Return here and start the 60-second test below. Open one of the apps you selected. If the automation is connected, it should send you back here. Then confirm what you saw.", "checkmark.circle")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("One setup. Calmer mornings.").font(.title.bold())
                Text("Choose several apps together. After setup, the same automation checks each time you open them—no daily configuration.")
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(currentPage + 1), total: Double(steps.count)).tint(ResetTheme.accent)
                ResetCard {
                    VStack(alignment: .leading, spacing: 18) {
                        Eyebrow(text: "Step \(currentPage + 1) of \(steps.count)")
                        Image(systemName: steps[currentPage].symbol).font(.largeTitle).foregroundStyle(ResetTheme.accent).accessibilityHidden(true)
                        Text(steps[currentPage].title).font(.title2.bold())
                        Text(steps[currentPage].detail).fixedSize(horizontal: false, vertical: true)
                        if currentPage == 5 { automationPreview }
                        if currentPage == 6 { testControls }
                    }
                }
                HStack(spacing: 16) {
                    if currentPage > 0 { Button("Previous") { page = currentPage - 1 }.frame(minHeight: 44) }
                    Spacer()
                    if currentPage < steps.count - 1 {
                        Button("Next step") { page = currentPage + 1 }.buttonStyle(.borderedProminent).frame(minHeight: 44)
                    }
                }
                Button { openURL(URL(string: "shortcuts://")!) } label: {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                }.buttonStyle(.bordered).frame(minHeight: 44)
                Text("Switch back here whenever you need the next step. Your place in this guide is saved.")
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("If it doesn’t work") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Make sure the automation is enabled, the selected app is in its list, and Run Immediately is selected.")
                        Text("If the action is missing, launch Morning Reset Shortcuts once, then reopen Shortcuts and search under Apps. Install Shortcuts from Apple if it is missing.")
                        Text("Check that Open App is inside the true If branch and points to this installation—not Morning Reset Demo or the Screen Time version.")
                        Text("If you use a free Personal Team build, an expired installation must be rebuilt in Xcode before its action can work again.")
                    }.font(.subheadline).padding(.top, 12)
                }
                Text("This is a voluntary redirect, not a system app lock. An app may appear briefly before the automation runs, and you can disable the automation. Morning Reset cannot inspect or install your personal automation.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(ResetTheme.background).navigationTitle("Redirect setup").navigationBarTitleDisplayMode(.inline)
    }

    private var currentPage: Int { min(max(0, page), steps.count - 1) }

    private var automationPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your automation should look like this:").font(.subheadline.bold())
            Label("Check Morning Redirect", systemImage: "sun.horizon")
            Label("If result is true / Yes", systemImage: "arrow.triangle.branch")
            Label("Open Morning Reset Shortcuts", systemImage: "arrow.up.forward.app").padding(.leading, 20)
            Text("Otherwise: nothing").padding(.leading, 20).foregroundStyle(.secondary)
            Text("End If").foregroundStyle(.secondary)
        }.font(.subheadline).padding(16).background(ResetTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .combine)
    }

    private var testControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let deadline = model.redirectSettings.testDeadline, deadline > Date() {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text("Test time left: \(ResetTheme.countdown(max(0, deadline.timeIntervalSince(context.date))))")
                        .font(.headline).monospacedDigit()
                }
                Text("Now open a selected app. Return here to confirm the redirect.").font(.subheadline)
                Button("Stop test") { model.stopRedirectTest() }.frame(minHeight: 44)
            } else {
                Button("Start 60-second redirect test") { model.startRedirectTest() }
                    .buttonStyle(.borderedProminent).frame(minHeight: 44)
            }
            if let checked = model.redirectSettings.lastCheckAt {
                Text("The check action last ran \(checked.formatted(date: .omitted, time: .shortened)). This alone does not confirm the Open App action.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(model.redirectSettings.setupConfirmed ? "Confirm setup again" : "I saw the redirect · finish setup") {
                model.confirmRedirectSetup()
            }.buttonStyle(.bordered).frame(minHeight: 44)
                .disabled(model.redirectSettings.lastCheckWasTest != true || model.redirectSettings.lastCheckRequestedRedirect != true)
            if model.redirectSettings.setupConfirmed {
                Label("Setup confirmed by you", systemImage: "checkmark.circle").foregroundStyle(ResetTheme.accent)
                Text("Redirects are enabled. They begin at your nightly time or when you start a morning routine. You can reopen this guide from Settings.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
