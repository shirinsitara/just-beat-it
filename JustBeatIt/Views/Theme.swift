import SwiftUI

enum AppTheme {
    // Layout
    static let cornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 14

    // Keep: existing shadow constant (used by CardModifier)
    // We'll also add a scheme-aware shadow helper below.
    static let cardShadow = Color.black.opacity(0.06)

    // MARK: - Brand / Theme Colors (kept)
    static let primary = Color(red: 0.05, green: 0.35, blue: 0.55)
    static let accent  = Color(red: 0.00, green: 0.65, blue: 0.60)

    // Your chosen medical green theme (kept)
    static let cardioGreen = Color(red: 0.05, green: 0.32, blue: 0.25)       // #0D5240
    static let cardioGreenAccent = Color(red: 0.10, green: 0.45, blue: 0.35) // #19735A

    // Dark-mode background gradient colors (kept)
    static let darkTop = Color(red: 0.02, green: 0.18, blue: 0.14)
    static let darkBottom = Color(red: 0.01, green: 0.10, blue: 0.08)

    // This existed but was a single color; keep it as-is for any existing references.
    static let background = Color(red: 0.05, green: 0.32, blue: 0.25)

    // MARK: - Semantic ECG Colors (kept names, improved tones)
    // Keep names so ECGWaveformView calls don’t break.
    // These are slightly more “medical UI” than pure system green/orange/red.
    static let rawSignal = Color(red: 0.07, green: 0.55, blue: 0.42)        // teal-green
    static let processedSignal = Color(red: 0.93, green: 0.58, blue: 0.20)  // warm amber
    static let peaks = Color(red: 0.95, green: 0.35, blue: 0.33)            // coral-red (less harsh)

    // Beat classes (kept names; tuned)
    static let pvc = Color(red: 0.93, green: 0.30, blue: 0.30)
    static let normal = Color(red: 0.10, green: 0.45, blue: 0.80)
    static let other = Color(red: 0.55, green: 0.35, blue: 0.85)

    // MARK: - Scheme-aware helpers (NEW, safe additions)
    static func tint(for scheme: ColorScheme) -> Color {
        scheme == .dark ? cardioGreenAccent : cardioGreen
    }

    static func background(for scheme: ColorScheme) -> AnyView {
        if scheme == .dark {
            return AnyView(
                LinearGradient(
                    colors: [darkTop, darkBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        } else {
            return AnyView(Color.white.ignoresSafeArea())
        }
    }

    /// Background fill used for cards. Use this instead of `.background` if you want the “same card look” in dark mode.
    static func cardFill(for scheme: ColorScheme) -> Color {
        panelFill(for: scheme)
    }

    /// Subtle outline for cards.
    static func cardStroke(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.12)
            : Color.black.opacity(0.06)
    }

    /// Shadow that won’t look dirty in dark mode.
    static func cardShadowColor(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.black.opacity(0.30)
            : cardShadow
    }

    static func primaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .primary
    }

    static func secondaryText(for scheme: ColorScheme) -> Color {
        scheme == .dark ? .white.opacity(0.78) : .secondary
    }
    
    // Explorer-specific surfaces (NEW)
    static func panelFill(for scheme: ColorScheme) -> Color {
        // Light: clean “clinic sheet”
        // Dark: monitor glass
        scheme == .dark
            ? Color.black.opacity(0.25)
            : Color(white: 0.97)
    }

    static func panelStroke(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? cardioGreenAccent.opacity(0.35)
            : Color.black.opacity(0.06)
    }

    static func waveformGlow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? cardioGreenAccent.opacity(0.35) : .clear
    }
}

struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .fill(AppTheme.panelFill(for: scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.panelStroke(for: scheme), lineWidth: 1)
            )
            .shadow(
                color: scheme == .dark ? .black.opacity(0.35) : AppTheme.cardShadow,
                radius: 12,
                x: 0, y: 6
            )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}
