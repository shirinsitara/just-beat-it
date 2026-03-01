import SwiftUI

@main
struct JustBeatItApp: App {
    
    @StateObject private var appearance = AppearanceManager()
    var body: some Scene {
        WindowGroup {
            LandingView()
                .tint(AppTheme.accent)
                .environmentObject(appearance)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
    
}
