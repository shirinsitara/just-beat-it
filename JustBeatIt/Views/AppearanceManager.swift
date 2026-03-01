import SwiftUI
import Combine

final class AppearanceManager: ObservableObject {
    @AppStorage("selectedAppearance") private var storedValue: Int = 2
    
    // 0 = system, 1 = light, 2 = dark
    var selected: Appearance {
        get { Appearance(rawValue: storedValue) ?? .system }
        set { storedValue = newValue.rawValue }
    }
    
    var colorScheme: ColorScheme? {
        switch selected {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum Appearance: Int, CaseIterable {
    case system = 0
    case light
    case dark
    
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
    
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
}
