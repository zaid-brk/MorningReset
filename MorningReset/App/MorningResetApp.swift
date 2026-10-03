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
                ContentUnavailableView(BuildMode.isDemo ? "Local storage unavailable" : "Shared storage unavailable", systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(BuildMode.isDemo ? "Relaunch the demo to try again." : "Check signing and the App Group in Xcode, then relaunch Morning Reset."))
            } else if !model.state.onboardingComplete {
                OnboardingView()
            } else {
                TabView {
                    NavigationStack { TodayView() }.tabItem { Label("Today", systemImage: "sun.horizon") }
                    NavigationStack { RoutineView() }.tabItem { Label("Routine", systemImage: "list.bullet") }
                    NavigationStack { SettingsView() }.tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
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
        .onChange(of: scenePhase) { _, phase in if phase == .active { model.refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in model.refresh() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if scenePhase == .active { model.tick() }
            }
        }
    }
}
