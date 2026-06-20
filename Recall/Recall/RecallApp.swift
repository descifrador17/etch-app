import SwiftUI
import RecallKit

@main
struct RecallApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .tint(Theme.Palette.accent)
                .preferredColorScheme(.dark)
        }
    }
}
