import SwiftUI

@main
struct ReverseOmokApp: App {
    var body: some Scene {
        WindowGroup {
            MenuView()
                .tint(Theme.seal)
        }
    }
}
