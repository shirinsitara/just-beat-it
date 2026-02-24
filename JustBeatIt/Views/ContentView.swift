import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @StateObject private var viewModel = ECGViewModel()
    @State private var showImporter = false
    @State private var dragStartTime: Double? = nil
    @State private var lastMagnification: Double = 1.0
    @State private var showBeatInspector = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                
                // Status line
                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Waveform + toggles
                if viewModel.ecgData != nil {

                    VStack(alignment: .leading, spacing: 12) {

                        // Toggles
                        HStack(alignment: .top, spacing: 8) {
                            Toggle("Processed Signal", isOn: $viewModel.showProcessed)
                            Toggle("Show R-Peaks", isOn: $viewModel.showPeaks)
                                .disabled(viewModel.rPeaks.isEmpty)
                            Toggle("Show Beat Windows", isOn: $viewModel.showWindows)
                        }
                        .font(.subheadline.weight(.semibold))
                        .toggleStyle(.switch)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onChange(of: viewModel.showProcessed) { _ in viewModel.clampViewport() }
                        .onChange(of: viewModel.showPeaks) { _ in viewModel.clampViewport() }
                        .onChange(of: viewModel.showWindows) { _ in viewModel.clampViewport() }

                        // Interactive waveform (drag to pan, pinch to zoom)
                        GeometryReader { geo in
                            let viewWidth = max(1, geo.size.width)
                            let secondsPerPoint = viewModel.zoomSeconds / Double(viewWidth)

                            ECGWaveformView(
                                samples: viewModel.visibleSamples,
                                color: viewModel.showProcessed ? .orange : .green,
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
                                        
                                        // zoom in/out controls
                                        viewModel.zoomSeconds /= delta
                                        viewModel.clampViewport()
                                    }
                                    .onEnded { _ in
                                        lastMagnification = 1.0
                                    }
                            )
                            // Scrub bar right under waveform (inside)
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
                        .padding(.vertical, 6)

                        // Zoom slider
                        let total = viewModel.totalDuration
                        let zoomMin: Double = 2.0
                        let zoomMaxHard: Double = 12.0
                        let zoomMax = max(zoomMin, min(zoomMaxHard, total))

                        HStack {
                            Text("Zoom")
                            Slider(value: $viewModel.zoomSeconds, in: zoomMin...zoomMax)
                            Text("\(Int(viewModel.zoomSeconds.rounded()))s")
                                .foregroundStyle(.secondary)
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
                        
                        // Beat Inspector toggle button
                        HStack {
                            Button {
                                withAnimation(.easeInOut) {
                                    showBeatInspector.toggle()
                                }
                            } label: {
                                Label(
                                    showBeatInspector ? "Hide Beat Inspector" : "Show Beat Inspector",
                                    systemImage: showBeatInspector ? "chevron.down" : "chevron.up"
                                )
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.beatWindows.isEmpty)

                            if viewModel.beatWindows.isEmpty {
                                Text("Detect beats to inspect.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        
                        // MARK: - Beat Inspector (only when user asks)
                        if showBeatInspector, let beat = viewModel.selectedBeat {

                            VStack(alignment: .leading, spacing: 8) {

                                Divider()

                                HStack {
                                    Text("Beat Inspector")
                                        .font(.headline)

                                    Spacer()

                                    Button("Hide") {
                                        withAnimation(.easeInOut) {
                                            showBeatInspector = false
                                        }
                                    }
                                    .font(.subheadline)
                                }

                                Text("Viewing Beat #\(viewModel.selectedBeatIndex + 1) of \(viewModel.beatWindows.count)")
                                    .font(.caption)
                                    .bold()

                                // RR + HR display
                                if let rr = viewModel.rrForSelectedBeat(),
                                   let hr = viewModel.hrForSelectedBeat() {

                                    Text(String(format: "RR: %.3f s   HR: %.1f bpm", rr, hr))
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
                                    color: .pink,
                                    peakIndices: [],
                                    windowSpans: []
                                )
                                .frame(height: 140)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }

                } else {
                    ContentUnavailableView(
                        "No ECG Loaded",
                        systemImage: "waveform.path.ecg",
                        description: Text("Import a JSON/CSV file to view the signal.")
                    )
                    .frame(maxHeight: 320)
                }
                
                // Buttons
                HStack(spacing: 12) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Load ECG File", systemImage: "doc")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.loadDummyData()
                    } label: {
                        Label("Dummy", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Error display (if any)
                if let err = viewModel.lastErrorText {
                    Text("⚠️ \(err)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("ECG Explorer")
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json, .commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.loadFromFile(url: url)

            case .failure(let error):
                viewModel.lastErrorText = error.localizedDescription
                print("❌ Importer error:", error)
            }
        }
    }
}

#Preview {
    ContentView()
}
