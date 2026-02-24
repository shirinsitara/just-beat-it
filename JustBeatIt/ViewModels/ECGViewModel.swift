import Foundation
import Combine

@MainActor
final class ECGViewModel: ObservableObject {
    
    @Published var ecgData: ECGData?
    @Published var statusText: String = "No file loaded."
    @Published var lastErrorText: String?
    @Published var showProcessed: Bool = true
    @Published var rPeaks: [Int] = []
    @Published var showPeaks: Bool = false
    @Published var beatWindows: [BeatWindow] = []
    @Published var selectedBeatIndex: Int = 0
    @Published var showWindows: Bool = false
    @Published var zoomSeconds: Double = 6.0
    @Published var startTime: Double = 0.0
    
    private let loader = ECGFileLoader()
    
    init() {
        NSLog("🟣 ECGViewModel init()")
        loadDummyData()
    }
    
    var displaySamples: [Float] {
        guard let d = ecgData else { return [] }
        return showProcessed ? d.processedSamples : d.rawSamples
    }
    
    var displayPeaks: [Int] {
        return showPeaks ? rPeaks : []
    }
    
    var displayWindows: [BeatWindow] {
        showWindows ? beatWindows : []
    }
    
    var totalDuration: Double {
        guard let d = ecgData else { return 0 }
        return Double(displaySamples.count) / d.samplingRate
    }
    
    var selectedBeat: BeatWindow? {
        guard beatWindows.indices.contains(selectedBeatIndex) else { return nil }
        return beatWindows[selectedBeatIndex]
    }
    
    var visibleRange: Range<Int> {
        guard let data = ecgData, data.samplingRate > 0 else {
            return 0..<0
        }

        let fs = data.samplingRate

        let startIdx = max(0, Int(startTime * fs))
        let count = max(10, Int(zoomSeconds * fs))
        let endIdx = min(displaySamples.count, startIdx + count)

        return startIdx..<endIdx
    }

    var visibleSamples: [Float] {
        guard let d = ecgData else { return [] }
        let fs = d.samplingRate

        let startIdx = max(0, Int(startTime * fs))
        let count = max(10, Int(zoomSeconds * fs))
        let endIdx = min(displaySamples.count, startIdx + count)

        guard startIdx < endIdx else { return [] }
        return Array(displaySamples[startIdx..<endIdx])
    }

    var visiblePeaks: [Int] {
        guard let d = ecgData else { return [] }
        let fs = d.samplingRate
        let startIdx = max(0, Int(startTime * fs))
        let endIdx = min(displaySamples.count, startIdx + Int(zoomSeconds * fs))

        // Convert global indices -> local indices for the visible slice
        return displayPeaks
            .filter { $0 >= startIdx && $0 < endIdx }
            .map { $0 - startIdx }
    }
    
    var displayBeatWindows: [BeatWindow] {
        showWindows ? beatWindows : []
    }

    var visibleWindowSpans: [WindowSpan] {
        let r = visibleRange
        guard r.lowerBound < r.upperBound else { return [] }

        return displayBeatWindows.enumerated().compactMap { (i, w) in
            guard w.endIndex > r.lowerBound, w.startIndex < r.upperBound else { return nil }
            let s = max(w.startIndex, r.lowerBound) - r.lowerBound
            let e = min(w.endIndex, r.upperBound) - r.lowerBound
            return WindowSpan(startIndex: s, endIndex: e, beatNumber: i + 1)
        }
    }
    
    var visibleBeatLabels: [(index: Int, number: Int)] {
        let r = visibleRange

        return beatWindows.enumerated().compactMap { (i, w) in
            guard w.rIndex >= r.lowerBound,
                  w.rIndex < r.upperBound else { return nil }

            let localIndex = w.rIndex - r.lowerBound
            return (index: localIndex, number: i + 1)
        }
    }
    
    var rrIntervals: [Double] {
        guard let data = ecgData else { return [] }
        let fs = data.samplingRate

        guard rPeaks.count > 1 else { return [] }

        return zip(rPeaks.dropFirst(), rPeaks)
            .map { Double($0 - $1) / fs }
    }
    
    func rrForSelectedBeat() -> Double? {
        let i = selectedBeatIndex
        guard i > 0, rrIntervals.indices.contains(i - 1) else { return nil }
        return rrIntervals[i - 1]
    }

    func hrForSelectedBeat() -> Double? {
        guard let rr = rrForSelectedBeat() else { return nil }
        return 60.0 / rr
    }
    
    func clampViewport() {
        guard totalDuration.isFinite else { return }

        let zoomMin: Double = 2.0
        let zoomMaxHard: Double = 12.0
        let zoomMax = max(zoomMin, min(zoomMaxHard, totalDuration))

        if !zoomSeconds.isFinite || zoomSeconds <= 0 { zoomSeconds = 6.0 }
        zoomSeconds = min(max(zoomSeconds, zoomMin), zoomMax)

        if !startTime.isFinite || startTime < 0 { startTime = 0 }

        let maxStart = max(0, totalDuration - zoomSeconds)
        if startTime > maxStart { startTime = maxStart }
    }
    
    func scrollToSelectedBeat() {
        guard let data = ecgData,
              beatWindows.indices.contains(selectedBeatIndex) else { return }

        let fs = data.samplingRate
        let r = beatWindows[selectedBeatIndex].rIndex
        let rTime = Double(r) / fs

        // center selected beat in viewport
        startTime = max(0, rTime - zoomSeconds * 0.33)
        clampViewport()
    }
    
    func loadDummyData() {
        let samplingRate = 360.0
        let duration = 5.0
        let totalSamples = Int(samplingRate * duration)
        
        var samples: [Float] = []
        samples.reserveCapacity(totalSamples)
        
        for i in 0..<totalSamples {
            let t = Double(i) / samplingRate
            let signal =
            sin(2 * .pi * 1.2 * t) * 0.08 +
            exp(-pow((t.truncatingRemainder(dividingBy: 1.0) - 0.2) * 40, 2))
            samples.append(Float(signal))
        }
        
        let processed = ECGProcessor.zScoreNormalize(samples)
        let data = ECGData(rawSamples: samples, processedSamples: processed, samplingRate: samplingRate)
        applyLoadedECG(rawSamples: samples, samplingRate: samplingRate, sourceName: "Dummy")
    }
    
    func loadFromFile(url: URL) {
        do {
            let data = try loader.load(from: url)
            applyLoadedECG(rawSamples: data.rawSamples, samplingRate: data.samplingRate, sourceName: url.lastPathComponent)
            lastErrorText = nil
        } catch {
            lastErrorText = error.localizedDescription
            statusText = "Failed to load."
            print("❌ Load error:", error)
        }
    }
    
    private func applyLoadedECG(rawSamples: [Float], samplingRate: Double, sourceName: String) {
        let processed = ECGProcessor.zScoreNormalize(rawSamples)
        
        let rawStats = ECGProcessor.stats(rawSamples)
        print(String(format: "RAW  → mean: %.6f, std: %.6f, min: %.6f, max: %.6f",
                     rawStats.mean, rawStats.std, rawStats.min, rawStats.max))
        
        let procStats = ECGProcessor.stats(processed)
        print(String(format: "PROC → mean: %.6f, std: %.6f, min: %.6f, max: %.6f",
                     procStats.mean, procStats.std, procStats.min, procStats.max))
        
        ecgData = ECGData(rawSamples: rawSamples, processedSamples: processed, samplingRate: samplingRate)
        showProcessed = true
        runRPeakDetection()
        
        statusText = "\(sourceName) — \(rawSamples.count) samples @ \(Int(samplingRate)) Hz"
        print("✅ Loaded:", statusText)
        
        let n = min(20, rawSamples.count)
        print("First \(n) RAW samples:", rawSamples.prefix(n))
        print("First \(n) PROC samples:", processed.prefix(n))
    }
    
    private func runRPeakDetection() {
        guard let data = ecgData else {
            rPeaks = []
            return
        }

        // Detect on processed signal
        let peaks = RPeakDetector.detect(samples: data.processedSamples, fs: data.samplingRate)
        rPeaks = peaks
        
        beatWindows = BeatSegmenter.segment(
            samples: data.processedSamples,
                rPeaks: peaks,
                fs: data.samplingRate
            )

        print("❤️ R-peaks detected:", peaks.count, "🟦 windows:", beatWindows.count)
    }
}


