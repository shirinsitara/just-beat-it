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

    var visibleWindows: [BeatWindow] {
        guard let d = ecgData else { return [] }
        let fs = d.samplingRate
        let startIdx = max(0, Int(startTime * fs))
        let endIdx = min(displaySamples.count, startIdx + Int(zoomSeconds * fs))

        // clip to viewport and shift indices to local coordinates
        return displayWindows.compactMap { w in
            guard w.endIndex > startIdx, w.startIndex < endIdx else { return nil }
            let s = max(w.startIndex, startIdx) - startIdx
            let e = min(w.endIndex, endIdx) - startIdx
            return BeatWindow(rIndex: w.rIndex - startIdx, startIndex: s, endIndex: e)
        }
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
        
        beatWindows = BeatSegmenter.windows(
                rPeaks: peaks,
                signalCount: data.processedSamples.count,
                fs: data.samplingRate,
                config: .init(preSeconds: 0.20, postSeconds: 0.40)
            )

        print("❤️ R-peaks detected:", peaks.count, "🟦 windows:", beatWindows.count)
    }
}


