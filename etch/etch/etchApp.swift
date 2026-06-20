import SwiftUI
import UIKit
import etchKit

@main
struct etchApp: App {
    @State private var container = AppContainer()

    init() {
        // Pushed-screen nav-bar titles (e.g. deck detail) render in monospace,
        // matching the terminal type system. Root tabs hide their bar entirely.
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        let ink = UIColor.white
        appearance.largeTitleTextAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 30, weight: .bold),
            .foregroundColor: ink,
        ]
        appearance.titleTextAttributes = [
            .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: ink,
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container)
                .tint(Theme.Palette.accent)
                .preferredColorScheme(.dark)
        }
    }
}
