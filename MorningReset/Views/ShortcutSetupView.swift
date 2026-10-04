import SwiftUI

/// The app supplies the check action; iOS requires the user to create the app trigger.
struct ShortcutSetupView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL
    @SceneStorage("morningRedirectTutorialStep") private var page = 0
    private let steps: [(title: String, instructions: [String], checkpoint: String, symbol: String)] = [
        ("Tap Automation, then +", [
            "Open Apple’s Shortcuts app on your iPhone.",
            "Tap Automation at the bottom of the screen.",
            "Tap + at the top, or New Automation if you have none yet.",
            "If you see Create Personal Automation, tap it."
        ], "You should now see a list with Time of Day, Alarm, and other options.", "square.stack.3d.up"),
        ("Find and tap App", [
            "On the list of automation options, scroll down until you see App. In the layout shown here, it is below CarPlay and above Wallet.",
            "Tap the row named App. The example underneath may say ‘When Weather is opened or closed’—that is just an example, not an app you have selected.",
            "On the next screen, tap Choose beside App.",
            "Select the distracting apps you want to redirect, then tap Done. You can choose several together. Leave Morning Reset Shortcuts and Shortcuts unselected to avoid a loop."
        ], "You should be back on the App screen, with your selected apps listed beside App. Stay on that screen for the next step.", "apps.iphone"),
        ("Select Is Opened and Run Immediately", [
            "On the same App screen, select Is Opened. Leave Is Closed unselected.",
            "Select Run Immediately so you will not have to approve each redirect.",
            "Tap Next. If your version shows Ask Before Running later instead, turn it off and confirm Don’t Ask when saving."
        ], "You should now see a screen where you can choose or create the actions to run.", "bolt"),
        ("Add Check Morning Redirect", [
            "Tap New Blank Automation if that option appears.",
            "Tap Add Action or the Search Actions field.",
            "Search for Check Morning Redirect. Tap the matching action from Morning Reset Shortcuts to add it."
        ], "Check Morning Redirect should now be the first action in the editor.", "sun.horizon"),
        ("Add If below the check", [
            "Use the action search again. Search for If and tap it to add it below Check Morning Redirect.",
            "Tap the If input and choose the result of Check Morning Redirect. Use Select Variable if needed.",
            "Set the condition to true or Yes. If you see Has Any Value, tap the input variable and change its type to Boolean first. Has Any Value is not the correct test: No is still a value. For a Boolean result, some versions simply show If Check Morning Redirect."
        ], "You should see If, Otherwise, and End If below the check action.", "arrow.triangle.branch"),
        ("Put Open App inside If", [
            "Search for Open App and add it.",
            "Drag Open App into the If section, above Otherwise.",
            "Tap the App field in Open App and choose Morning Reset Shortcuts.",
            "Leave Otherwise empty. Open App must be above Otherwise, not after End If, so finished routines allow your other apps."
        ], "Compare the order of your actions with the example below before continuing.", "arrow.uturn.backward"),
        ("Save, then test the redirect", [
            "Tap Done in Shortcuts to save the automation.",
            "Return to this guide and tap Start 60-second redirect test below.",
            "While the test is running, open one of the distracting apps you selected.",
            "If you are sent back here, tap I saw the redirect · finish setup. If you stay in the other app, return here and open If it doesn’t work below."
        ], "Confirm setup only after you have seen the redirect happen.", "checkmark.circle")
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
                        if currentPage == 1 { appTriggerPreview }
                        ForEach(Array(steps[currentPage].instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)").font(.subheadline.bold())
                                    .frame(minWidth: 28, minHeight: 28)
                                    .background(ResetTheme.accent.opacity(0.12), in: Circle())
                                    .accessibilityHidden(true)
                                Text(instruction).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Label(steps[currentPage].checkpoint, systemImage: "eye")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if currentPage == 5 { automationPreview }
                        if currentPage == 6 { testControls }
                    }
                }
                VStack(spacing: 12) {
                    if currentPage < steps.count - 1 {
                        Button(currentPage == 1 ? "I chose my apps · Next" : "Next step") { page = currentPage + 1 }
                            .buttonStyle(.borderedProminent).frame(minHeight: 44)
                    }
                    if currentPage > 0 { Button("Previous step") { page = currentPage - 1 }.frame(minHeight: 44) }
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
                        Text("After the test expires, open the selected app again. It should stay open unless a routine period is active. If Settings shows Last check: No but you are still sent back, make sure If tests the Boolean result rather than Has Any Value, Open App is above Otherwise, and there is only one automation for these apps.")
                        Text("If you use a free Personal Team build, an expired installation must be rebuilt in Xcode before its action can work again.")
                    }.font(.subheadline).padding(.top, 12)
                }
                Text("This is a voluntary redirect, not a system app lock. An app may appear briefly before the automation runs, and you can disable the automation. Morning Reset cannot inspect or install your personal automation.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }.background(ResetTheme.background).navigationTitle("Redirect setup").navigationBarTitleDisplayMode(.inline)
    }

    private var currentPage: Int { min(max(0, page), steps.count - 1) }

    /// A text-based guide to the trigger list, not an interactive Shortcuts screen.
    private var appTriggerPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In Shortcuts, look for this row").font(.subheadline.bold())
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("App").font(.headline)
                    Text("“When Weather is opened or closed”")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
            }.padding(16)
                .background(ResetTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(ResetTheme.accent, lineWidth: 2))
            Text("Can’t find it? Use Search at the bottom of that screen and type App.")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
    }

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
                Text("Last check: \(model.redirectSettings.lastCheckRequestedRedirect == true ? "Yes · return here" : "No · allow other apps") at \(checked.formatted(date: .omitted, time: .standard)). This alone does not confirm the Open App action.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(model.redirectSettings.setupConfirmed ? "Confirm setup again" : "I saw the redirect · finish setup") {
                model.confirmRedirectSetup()
            }.buttonStyle(.bordered).frame(minHeight: 44)
                .disabled(!model.redirectSettings.canConfirmSetup)
            if model.redirectSettings.canConfirmSetup && !model.redirectSettings.setupConfirmed {
                Text("The test check requested a redirect. If you saw it return you here, you can finish setup even after the test timer ends.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if !model.redirectSettings.canConfirmSetup {
                Text("To enable this button, start the test and open a selected app while the test is running.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.redirectSettings.setupConfirmed {
                Label("Setup confirmed by you", systemImage: "checkmark.circle").foregroundStyle(ResetTheme.accent)
                Text("Redirects are enabled. They begin at your nightly time or when you start a morning routine. You can reopen this guide from Settings.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
