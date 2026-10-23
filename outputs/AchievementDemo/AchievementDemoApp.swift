import SwiftUI

@main
struct AchievementDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ReviewsView()
                .preferredColorScheme(.light)
        }
    }
}
