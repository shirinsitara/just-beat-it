import SwiftUI

struct RhythmSummaryCard: View {
    let summary: RhythmSummary
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Rhythm Summary", systemImage: "heart.text.square")
                    .font(.headline)
                    .foregroundStyle(scheme == .dark ? .white : .primary)

                Spacer()

                Text(summary.badge.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(AppTheme.panelFill(for: scheme).opacity(0.75))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(AppTheme.panelStroke(for: scheme), lineWidth: 1)
                    )
            }

            // Key stats row
            HStack(spacing: 16) {
                stat("Beats", "\(summary.totalBeats)")
                stat("Avg HR", summary.avgHR.map { String(format: "%.0f bpm", $0) } ?? "—")
                InfoPopoverLabel(
                    title: "RR Variation (SD)",
                    value: summary.rrStd.map { String(format: "%.3f s", $0) } ?? "—",
                    helpTitle: "RR SD (beat-to-beat variability)",
                    helpBody: """
                        RR SD measures beat-to-beat variability.

                        • RR interval = time between heartbeats
                        • SD = how much those intervals vary
                        • Higher value = more irregular timing

                        Short recordings do not represent full HRV analysis.
                        """
                )
                
            }

            // Counts by label (simple)
            if !summary.counts.isEmpty {
                let sorted = summary.counts.sorted { $0.key < $1.key }
                HStack(spacing: 10) {
                    ForEach(sorted, id: \.key) { k, v in
                        Text("\(k): \(v)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
            }

            Text(summary.narrative)
                .font(.subheadline)
                .foregroundStyle(scheme == .dark ? .white.opacity(0.85) : .secondary)

            Text("Educational only — not a diagnosis.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoPopoverLabel: View {
    let title: String
    let value: String
    let helpTitle: String
    let helpBody: String

    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
            }

            Button {
                showHelp.toggle()
            } label: {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showHelp, arrowEdge: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(helpTitle)
                            .font(.headline)

                        Text(helpBody)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Educational only — not a diagnosis.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
            }
            .accessibilityLabel("More info about \(title)")
        }
    }
}
