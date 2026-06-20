import SwiftUI
import RecallKit

/// TabView host: Decks (home) + Create. Each tab owns its own NavigationStack.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Decks", systemImage: "rectangle.stack") {
                DecksView()
            }
            Tab("Create", systemImage: "sparkles") {
                GenerateView()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppContainer())
}
