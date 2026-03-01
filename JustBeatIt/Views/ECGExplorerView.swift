import SwiftUI
import UniformTypeIdentifiers

struct ECGExplorerView: View {

    let entryURL: URL?

    init(entryURL: URL? = nil) {
        self.entryURL = entryURL
    }

    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var viewModel = ECGViewModel()
    @State private var showImporter = false
    @State private var dragStartTime: Double? = nil
    @State private var lastMagnification: Double = 1.0
    @State private var showBeatInspector = false
    @State private var didLoadOnce = false
    @State private var showInspectorBanner = false
    @State private var scrollToInspectorRequest = 0

    var body: some View {
        ZStack {
            AppTheme.background(for: colorScheme)

            // ✅ A: ScrollViewReader for auto-scroll to inspector
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {

                        // Status line
                        Text(viewModel.statusText)
                            .font(.subheadline)
                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.78) : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let s = viewModel.rhythmSummary {
                            RhythmSummaryCard(summary: s)
                        }
                        
                        if let s = viewModel.rhythmSummary, (s.counts["PVC"] ?? 0) > 0 {
                            HStack {
                                Button {
                                    if let idx = viewModel.firstIndex(of: "PVC") {
                                        viewModel.selectedBeatIndex = idx
                                    }

                                    // 1️⃣ Open inspector
                                    withAnimation(.easeInOut) {
                                        showBeatInspector = true
                                    }

                                    // 2️⃣ Slight delay → then scroll page to inspector
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                                        scrollToInspectorRequest += 1
                                    }

                                    // 3️⃣ Also center waveform on that beat
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        viewModel.scrollToSelectedBeat()
                                    }

                                } label: {
                                    Label("Jump to first PVC-marked beat", systemImage: "arrowshape.turn.up.right.fill")
                                }
                                .buttonStyle(.borderedProminent)

                                Spacer()
                            }
                            .card()
                        }

                        if viewModel.ecgData != nil {
                            waveform

                            controls

                            // ✅ Anchor right before inspector so scroll lands nicely
                            Color.clear
                                .frame(height: 1)
                                .id("inspectorAnchor")

                            // MARK: - Beat Inspector
                            if showBeatInspector, let beat = viewModel.selectedBeat {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Beat Inspector")
                                            .font(.headline)
                                            .foregroundStyle(colorScheme == .dark ? .white : .primary)

                                        Spacer()

                                        Button("Close") {
                                            withAnimation(.easeInOut) {
                                                showBeatInspector = false
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    Text("Viewing Beat #\(viewModel.selectedBeatIndex + 1) of \(viewModel.beatWindows.count)")
                                        .font(.caption)
                                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.78) : .secondary)
                                        .bold()

                                    // RR + HR display
                                    if let rr = viewModel.rrForSelectedBeat(),
                                       let hr = viewModel.hrForSelectedBeat() {
                                        Text(String(format: "RR: %.3f s   HR: %.1f bpm", rr, hr))
                                            .font(.subheadline)
                                            .foregroundStyle(colorScheme == .dark ? .white : .primary)
                                    }
                                    
                                    if (viewModel.rhythmSummary?.counts["PVC"] ?? 0) > 0 {
                                        HStack(spacing: 10) {
                                            Button {
                                                if let idx = viewModel.prevIndex(of: "PVC", from: viewModel.selectedBeatIndex) {
                                                    viewModel.selectedBeatIndex = idx
                                                    viewModel.scrollToSelectedBeat()
                                                }
                                            } label: {
                                                Label("Prev PVC", systemImage: "chevron.left")
                                            }
                                            .buttonStyle(.bordered)

                                            Button {
                                                if let idx = viewModel.nextIndex(of: "PVC", from: viewModel.selectedBeatIndex) {
                                                    viewModel.selectedBeatIndex = idx
                                                    viewModel.scrollToSelectedBeat()
                                                }
                                            } label: {
                                                Label("Next PVC", systemImage: "chevron.right")
                                            }
                                            .buttonStyle(.bordered)

                                            Spacer()
                                        }
                                    }
                                    
                                    // Beat selector slider
                                    Slider(
                                        value: Binding(
                                            get: { Double(viewModel.selectedBeatIndex) },
                                            set: { viewModel.selectedBeatIndex = Int($0.rounded()) }
                                        ),
                                        in: 0...Double(max(0, viewModel.beatWindows.count - 1)),
                                        step: 1
                                    )
                                    .onChange(of: viewModel.selectedBeatIndex) { _ in
                                        viewModel.scrollToSelectedBeat()
                                    }

                                    // Mini beat waveform
                                    ECGWaveformView(
                                        samples: beat.samples,
                                        color: .white,
                                        peakIndices: [],
                                        windowSpans: []
                                    )
                                    .frame(height: 140)
                                    
                                    if viewModel.beatPredictions.indices.contains(viewModel.selectedBeatIndex) {
                                        Text("Label: \(viewModel.beatPredictions[viewModel.selectedBeatIndex])")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(colorScheme == .dark ? .white.opacity(0.90) : .primary)
                                    }
                                    
                                    // Beat explanation
                                    if let exp = viewModel.explainBeat(at: viewModel.selectedBeatIndex) {
                                        Divider().padding(.vertical, 4)
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Why this label?")
                                                    .font(.subheadline.weight(.semibold))

                                                Spacer()

                                                if let c = exp.confidenceText {
                                                    Text(c)
                                                        .font(.caption.weight(.semibold))
                                                        .foregroundStyle(colorScheme == .dark ? .white.opacity(0.78) : .secondary)
                                                }
                                            }

                                            Text(exp.title)
                                                .font(.headline)
                                                .foregroundStyle(colorScheme == .dark ? .white : .primary)

                                            ForEach(exp.bullets, id: \.self) { line in
                                                HStack(alignment: .top, spacing: 8) {
                                                    Text("•")
                                                    Text(line)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                        .multilineTextAlignment(.leading)
                                                }
                                                .font(.subheadline)
                                                .foregroundStyle(colorScheme == .dark ? .white.opacity(0.88) : .secondary)
                                            }

                                            if let note = exp.note {
                                                Text(note)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .padding(.top, 4)
                                            }
                                        }
                                    }

                                }
                                .card()
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                .id("beatInspector")
                            }

                        } else {
                            ContentUnavailableView(
                                "No ECG Loaded",
                                systemImage: "waveform.path.ecg",
                                description: Text("Import a JSON/CSV file to view the signal.")
                            )
                            .frame(maxHeight: 320)
                            .card()
                        }
                    }
                    .padding()
                    .frame(maxWidth: 820)      // helps iPad spacing
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: showBeatInspector) { isOn in
                    if isOn {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo("inspectorAnchor", anchor: .top)
                        }

                        // Flying banner
                        withAnimation(.easeInOut) { showInspectorBanner = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                            if showBeatInspector {
                                withAnimation(.easeInOut) { showInspectorBanner = false }
                            }
                        }
                    } else {
                        withAnimation(.easeInOut) { showInspectorBanner = false }
                    }
                }
                .overlay(alignment: .bottom) {
                    if showBeatInspector && showInspectorBanner {
                        inspectorBanner(proxy: proxy)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .onChange(of: scrollToInspectorRequest) { _ in
                    withAnimation(.easeInOut) {
                        proxy.scrollTo("inspectorAnchor", anchor: .top)
                    }
                }
            }
        }
        .tint(AppTheme.tint(for: colorScheme))
        .navigationTitle("ECG Explorer")
        .onAppear {
            guard !didLoadOnce else { return }
            didLoadOnce = true

            if let url = entryURL {
                viewModel.loadFromFile(url: url)
            } else {
                //viewModel.loadDummyData()
            }
        }
    }

    private var waveform: some View {

        // MARK: - Waveform (Clinic in light, Monitor glow in dark)
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("Waveform")
                    .font(.headline)
                    .foregroundStyle(colorScheme == .dark ? .white : .primary)

                Spacer()

                Button {
                    withAnimation(.easeInOut) {
                        showBeatInspector.toggle()
                    }
                } label: {
                    Label(
                        showBeatInspector ? "Hide Inspector" : "Inspect Beats",
                        systemImage: showBeatInspector ? "chevron.down.square" : "waveform"
                    )
                }
                .buttonStyle(.borderedProminent)
            }

            GeometryReader { geo in
                let viewWidth = max(1, geo.size.width)
                let secondsPerPoint = viewModel.zoomSeconds / Double(viewWidth)

                ECGWaveformView(
                    samples: viewModel.visibleSamples,
                    color: viewModel.showProcessed ? AppTheme.processedSignal : AppTheme.rawSignal,
                    peakIndices: viewModel.visiblePeaks,
                    windowSpans: viewModel.visibleWindowSpans,
                    beatLabels: viewModel.visibleBeatLabels,
                    highlightedBeatNumber: viewModel.selectedBeatIndex + 1,
                    showBeatLabels: viewModel.showWindows
                )
                .frame(width: geo.size.width, height: 280)
                .contentShape(Rectangle())
                // Pan
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if dragStartTime == nil { dragStartTime = viewModel.startTime }
                            let base = dragStartTime ?? viewModel.startTime

                            // Drag right => show earlier time (move window left)
                            let deltaSeconds = Double(value.translation.width) * secondsPerPoint
                            viewModel.startTime = base - deltaSeconds
                            viewModel.clampViewport()
                        }
                        .onEnded { _ in
                            dragStartTime = nil
                        }
                )
                // Pinch zoom
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { mag in
                            let delta = mag / lastMagnification
                            lastMagnification = mag

                            viewModel.zoomSeconds /= delta
                            viewModel.clampViewport()
                        }
                        .onEnded { _ in
                            lastMagnification = 1.0
                        }
                )
                // Scrub bar
                .overlay(alignment: .bottom) {
                    ECGScrubBar(
                        startTime: $viewModel.startTime,
                        totalDuration: viewModel.totalDuration,
                        zoomSeconds: viewModel.zoomSeconds
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
                }
            }
            .frame(height: 280)
            .padding(.vertical, 4)

        }
        .card()
        .shadow(
            color: (colorScheme == .dark ? AppTheme.tint(for: colorScheme).opacity(0.35) : .clear),
            radius: colorScheme == .dark ? 18 : 0,
            x: 0, y: 0
        )
    }

    private var controls: some View {

        // MARK: - Controls (Clinic style in light, Monitor panel in dark via .card())
        VStack(alignment: .leading, spacing: 10) {
            Text("Controls")
                .font(.headline)
                .foregroundStyle(colorScheme == .dark ? .white : .primary)

            HStack(alignment: .top, spacing: 12) {
                ControlToggleRow(
                    title: "Processed Signal",
                    isOn: $viewModel.showProcessed
                )

                ControlToggleRow(
                    title: "Show R-Peaks",
                    isOn: $viewModel.showPeaks
                )

                ControlToggleRow(
                    title: "Show Beat Windows",
                    isOn: $viewModel.showWindows
                )
            }
            .font(.subheadline.weight(.semibold))
            .toggleStyle(.switch)
            .onChange(of: viewModel.showProcessed) { _ in viewModel.clampViewport() }
            .onChange(of: viewModel.showPeaks) { _ in viewModel.clampViewport() }
            .onChange(of: viewModel.showWindows) { _ in viewModel.clampViewport() }

            // Zoom slider
            let total = viewModel.totalDuration
            let zoomMin: Double = 2.0
            let zoomMaxHard: Double = 12.0
            let zoomMax = max(zoomMin, min(zoomMaxHard, total))

            HStack {
                Text("Zoom")
                Slider(value: $viewModel.zoomSeconds, in: zoomMin...zoomMax)
                Text("\(Int(viewModel.zoomSeconds.rounded()))s")
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.78) : .secondary)
                    .monospacedDigit()
            }
            .font(.caption)
            .onChange(of: viewModel.zoomSeconds) { _ in
                viewModel.clampViewport()
            }
            .onChange(of: viewModel.ecgData?.id) { _ in
                viewModel.startTime = 0
                showBeatInspector = false
                viewModel.clampViewport()
            }
        }
        .card()
    }

    private struct ControlToggleRow: View {
        let title: String
        @Binding var isOn: Bool

        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Toggle("", isOn: $isOn)
                    .labelsHidden()

                Spacer(minLength: 12)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private func inspectorBanner(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")

            VStack(alignment: .leading, spacing: 2) {
                Text("Beat Inspector Open")
                    .font(.subheadline.weight(.semibold))
                Text("Tap Jump to view it")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.75) : .secondary)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut) {
                    proxy.scrollTo("inspectorAnchor", anchor: .top)
                }
            } label: {
                Label("Jump", systemImage: "chevron.down")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)

            Button {
                withAnimation(.easeInOut) {
                    showBeatInspector = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.panelStroke(for: colorScheme), lineWidth: 1)
        )
    }
}

#Preview {
    ECGExplorerView()
}
