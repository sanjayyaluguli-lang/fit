import SwiftUI
import AutonomyKit

@main
struct AutonomyApp: App {
    @State private var model: AppModel?
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if let model {
                    RootView()
                        .environmentObject(model)
                } else {
                    // Opening a local JSON file is instant; this is a frame, not
                    // a splash screen.
                    Color.black.ignoresSafeArea()
                        .task { model = await AppModel.live() }
                }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let model else { return }
            Task { await model.sync() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Today", systemImage: "circle.dashed") }

            NavigationStack { TrainView() }
                .tabItem { Label("Train", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack { ProgressDashboardView() }
                .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .sheet(isPresented: .constant(model.data.profile.displayName.isEmpty && model.data.sessions.isEmpty)) {
            NavigationStack { OnboardingView() }
        }
    }
}
