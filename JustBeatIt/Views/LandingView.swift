import SwiftUI
import UniformTypeIdentifiers

struct LandingView: View {
    enum Route: Hashable { case explorer }

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appearance: AppearanceManager

    @State private var path = NavigationPath()
    @State private var showImporter = false
    @State private var lastErrorText: String? = nil
    @State private var pendingURL: URL? = nil

    // Subtle “monitor mode” pulse when switching into Dark
    @State private var glowPulse = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .topTrailing) {
                AppTheme.background(for: colorScheme)

                VStack(spacing: 28) {
                    Spacer()
                    headerSection
                    Spacer()
                    actionSection
                    Spacer()
                    tailSection
                    Spacer()
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)

                appearanceToggle
            }
            // Smooth crossfade-ish feel when theme changes
            .animation(.easeInOut(duration: 0.25), value: appearance.selected)
            .onChange(of: appearance.selected) { newValue in
                guard newValue == .dark else { return }

                glowPulse = false
                withAnimation(.easeOut(duration: 0.25)) {
                    glowPulse = true
                }
                withAnimation(.easeIn(duration: 0.6).delay(0.25)) {
                    glowPulse = false
                }
            }
            .tint(AppTheme.tint(for: colorScheme))
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .explorer:
                    ECGExplorerView(entryURL: pendingURL)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    pendingURL = url
                    path.append(Route.explorer)

                case .failure(let error):
                    lastErrorText = error.localizedDescription
                    print("❌ Importer error:", error)
                }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 60, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppTheme.tint(for: colorScheme))
                .padding()
                .background(
                    Circle()
                        .fill(AppTheme.tint(for: colorScheme).opacity(colorScheme == .dark ? 0.12 : 0.10))
                )
                // Extra glow only in dark + on pulse
                .shadow(
                    color: AppTheme.tint(for: colorScheme)
                        .opacity(colorScheme == .dark ? (glowPulse ? 0.85 : 0.55) : 0.0),
                    radius: colorScheme == .dark ? (glowPulse ? 26 : 18) : 0,
                    x: 0, y: 0
                )
                .scaleEffect(glowPulse ? 1.02 : 1.0)

            Text("ECG Explorer")
                .font(.largeTitle.bold())
                .foregroundStyle(colorScheme == .dark ? .white : .primary)

            Text("Explore ECG waveforms with markers and beat inspection.\nEducational use only — not diagnostic.")
                .font(.subheadline)
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.78) : .secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }

    private var actionSection: some View {
        VStack(spacing: 14) {
            Button {
                pendingURL = nil
                path.append(Route.explorer)
            } label: {
                Label("Use Dummy Data", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: 360)

            Button {
                showImporter = true
            } label: {
                Label("Import Own Data", systemImage: "doc")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: 360)
        }
    }

    private var tailSection: some View {
        VStack(alignment: .leading, spacing: 14) {

            Text("Capabilities")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 24),
                    GridItem(.flexible(), spacing: 24)
                ],
                alignment: .leading,
                spacing: 18
            ) {

                featureColumn(
                    title: "Analysis",
                    items: [
                        ("R-peak detection & segmentation", "waveform.path.ecg"),
                        ("Beat windows + labels (N / PVC / O)", "tag")
                    ]
                )

                featureColumn(
                    title: "ML + Interpretation",
                    items: [
                        ("Neural network beat classification", "brain.head.profile"),
                        ("Rhythm summary & variability metrics", "chart.bar.xaxis")
                    ]
                )

                featureColumn(
                    title: "Beat Inspector",
                    items: [
                        ("Timing & morphology insights", "magnifyingglass.circle"),
                        ("Confidence display per beat", "percent")
                    ]
                )

                featureColumn(
                    title: "Explore",
                    items: [
                        ("Pan & zoom ECG grid", "arrow.up.left.and.down.right.magnifyingglass"),
                        ("Educational (non-diagnostic)", "info.circle")
                    ]
                )
            }
        }
        .font(.subheadline)
        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.82) : .secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .padding(.top, 6)
    }

    @ViewBuilder
    private func featureColumn(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.9) : .primary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.indices, id: \.self) { i in
                    let item = items[i]
                    Label(item.0, systemImage: item.1)
                }
            }
        }
    }

    // MARK: - Appearance Toggle (floating top-right)

    private var appearanceToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                switch appearance.selected {
                case .system:
                    appearance.selected = .light
                case .light:
                    appearance.selected = .dark
                case .dark:
                    appearance.selected = .light
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(
                        colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.05)
                    )

                Circle()
                    .stroke(
                        colorScheme == .dark
                        ? Color.white.opacity(0.15)
                        : Color.black.opacity(0.08),
                        lineWidth: 1
                    )

                Image(systemName: appearance.selected == .dark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)
                    .rotationEffect(.degrees(appearance.selected == .dark ? 360 : 0))
                    .animation(.easeInOut(duration: 0.4), value: appearance.selected)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .clipShape(Circle())
            .shadow(
                color: colorScheme == .dark
                ? AppTheme.tint(for: colorScheme).opacity(0.4)
                : .black.opacity(0.1),
                radius: 8,
                x: 0, y: 4
            )
        }
        .buttonStyle(.plain)
        #if os(macOS)
        .focusable(false)
        #endif
        .padding(.top, 20)
        .padding(.trailing, 20)
    }
}

#Preview {
    LandingView()
        .environmentObject(AppearanceManager())
}
