import SwiftUI
import UIKit

@main
struct MorningResetApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(model).tint(ResetTheme.accent) }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if model.storageUnavailable {
                ContentUnavailableView(BuildMode.usesLocalStorage ? "Local storage unavailable" : "Shared storage unavailable", systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(BuildMode.usesLocalStorage ? "Relaunch the app to try again." : "Check signing and the App Group in Xcode, then relaunch Morning Reset."))
            } else if !model.state.onboardingComplete {
                OnboardingView()
            } else {
                TabView(selection: $model.selectedTab) {
                    NavigationStack { TodayView() }.id(model.todayNavigationID).tabItem { Label("Today", systemImage: "sun.horizon") }.tag(0)
                    NavigationStack { RoutineView() }.tabItem { Label("Routine", systemImage: "list.bullet") }.tag(1)
                    NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(2)
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if BuildMode.isDemo {
                Label("Demo · no app blocking or protected streaks", systemImage: "info.circle")
                    .font(.caption.weight(.medium)).foregroundStyle(ResetTheme.accent)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .frame(maxWidth: .infinity).background(ResetTheme.background)
            }
        }
        .alert("Morning Reset", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in model.refresh() }
        .task(id: scenePhase) {
            // Restart on foreground entry rather than capturing the initial inactive phase forever.
            guard scenePhase == .active else { return }
            model.refresh()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) }
                catch { return }
                guard !Task.isCancelled else { return }
                model.tick()
            }
        }
    }
}
