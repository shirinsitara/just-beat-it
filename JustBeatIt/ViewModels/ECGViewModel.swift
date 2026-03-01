import Foundation
import Combine

@MainActor
final class ECGViewModel: ObservableObject {
    
    // MARK: - Published state (UI)
    
    @Published var ecgData: ECGData?
    @Published var statusText: String = "No file loaded."
    @Published var lastErrorText: String?
    
    @Published var showProcessed: Bool = true
    
    @Published var rPeaks: [Int] = []
    @Published var showPeaks: Bool = false
    
    @Published var beatWindows: [BeatWindow] = []
    @Published var showWindows: Bool = false
    @Published var selectedBeatIndex: Int = 0
    
    @Published var zoomSeconds: Double = 6.0
    @Published var startTime: Double = 0.0
    
    @Published var beatPredictions: [String] = []
    @Published var beatProbs: [[String: Double]] = []
    
    @Published var rhythmSummary: RhythmSummary? = nil
    
    private let loader = ECGFileLoader()
    private var classifier: BeatClassifierService?
    
    init() {
        NSLog("🟣 ECGViewModel init()")
    }
    
    var displaySamples: [Float] {
        guard let d = ecgData else { return [] }
        return showProcessed ? d.processedSamples : d.rawSamples
    }
    
    var displayPeaks: [Int] { showPeaks ? rPeaks : [] }
    var displayBeatWindows: [BeatWindow] { showWindows ? beatWindows : [] }
    
    var selectedBeat: BeatWindow? {
        guard beatWindows.indices.contains(selectedBeatIndex) else { return nil }
        return beatWindows[selectedBeatIndex]
    }
    
    // MARK: - Viewport (zoom + pan)
    
    var totalDuration: Double {
        guard let d = ecgData, d.samplingRate > 0 else { return 0 }
        return Double(displaySamples.count) / d.samplingRate
    }
    
    var visibleRange: Range<Int> {
        guard let d = ecgData, d.samplingRate > 0 else { return 0..<0 }
        
        let fs = d.samplingRate
        let startIdx = max(0, Int(startTime * fs))
        let count = max(10, Int(zoomSeconds * fs))
        let endIdx = min(displaySamples.count, startIdx + count)
        
        return startIdx..<endIdx
    }
    
    var visibleSamples: [Float] {
        let r = visibleRange
        guard r.lowerBound < r.upperBound else { return [] }
        return Array(displaySamples[r])
    }
    
    /// Peaks mapped into visible slice indices (local indices)
    var visiblePeaks: [Int] {
        let r = visibleRange
        guard r.lowerBound < r.upperBound else { return [] }
        
        return displayPeaks
            .filter { $0 >= r.lowerBound && $0 < r.upperBound }
            .map { $0 - r.lowerBound }
    }
    
    /// Window spans mapped into visible slice indices (local indices)
    var visibleWindowSpans: [WindowSpan] {
        let r = visibleRange
        guard r.lowerBound < r.upperBound else { return [] }
        
        return displayBeatWindows.enumerated().compactMap { (i, w) -> WindowSpan? in
            guard w.endIndex > r.lowerBound, w.startIndex < r.upperBound else { return nil }
            
            let s = max(w.startIndex, r.lowerBound) - r.lowerBound
            let e = min(w.endIndex, r.upperBound) - r.lowerBound
            let label = beatPredictions.indices.contains(i) ? beatPredictions[i] : nil
            
            return WindowSpan(startIndex: s, endIndex: e, beatNumber: i + 1, NNLabels: label)
        }
    }
    
    /// Beat number labels placed at each beat’s R index (local indices)
    var visibleBeatLabels: [(index: Int, number: Int)] {
        let r = visibleRange
        guard r.lowerBound < r.upperBound else { return [] }
        
        return beatWindows.enumerated().compactMap { (i, w) in
            guard w.rIndex >= r.lowerBound, w.rIndex < r.upperBound else { return nil }
            return (index: w.rIndex - r.lowerBound, number: i + 1)
        }
    }
    
    var visibleBeatClassLabels: [(index: Int, text: String)] {
        let r = visibleRange
        guard r.lowerBound < r.upperBound else { return [] }

        return beatWindows.enumerated().compactMap { (i, w) in
            guard w.rIndex >= r.lowerBound, w.rIndex < r.upperBound else { return nil }
            let label = beatPredictions.indices.contains(i) ? beatPredictions[i] : "—"
            let short = (label == "Other") ? "O" : label
            return (index: w.rIndex - r.lowerBound, text: short)
        }
    }
    
    // MARK: - RR / HR
    
    var rrIntervals: [Double] {
        guard let d = ecgData, d.samplingRate > 0 else { return [] }
        guard rPeaks.count > 1 else { return [] }
        
        let fs = d.samplingRate
        return zip(rPeaks.dropFirst(), rPeaks).map { Double($0 - $1) / fs }
    }
    
    func rrForSelectedBeat() -> Double? {
        let i = selectedBeatIndex
        guard i > 0, rrIntervals.indices.contains(i - 1) else { return nil }
        return rrIntervals[i - 1]
    }
    
    func hrForSelectedBeat() -> Double? {
        guard let rr = rrForSelectedBeat(), rr > 0 else { return nil }
        return 60.0 / rr
    }
    
    // MARK: - Public actions
    
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
        guard let d = ecgData,
              beatWindows.indices.contains(selectedBeatIndex),
              d.samplingRate > 0 else { return }
        
        let fs = d.samplingRate
        let rIdx = beatWindows[selectedBeatIndex].rIndex
        let rTime = Double(rIdx) / fs
        
        startTime = max(0, rTime - zoomSeconds * 0.33) // roughly center-left
        clampViewport()
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
        
        applyLoadedECG(rawSamples: samples, samplingRate: samplingRate, sourceName: "Dummy")
    }
    
    // MARK: - Pipeline
    
    private func applyLoadedECG(rawSamples: [Float], samplingRate: Double, sourceName: String) {
        let processed = ECGProcessor.zScoreNormalize(rawSamples)
        
#if DEBUG
        let rawStats = ECGProcessor.stats(rawSamples)
        print(String(format: "RAW  → mean: %.6f, std: %.6f, min: %.6f, max: %.6f",
                     rawStats.mean, rawStats.std, rawStats.min, rawStats.max))
        
        let procStats = ECGProcessor.stats(processed)
        print(String(format: "PROC → mean: %.6f, std: %.6f, min: %.6f, max: %.6f",
                     procStats.mean, procStats.std, procStats.min, procStats.max))
#endif
        
        ecgData = ECGData(rawSamples: rawSamples, processedSamples: processed, samplingRate: samplingRate)
        showProcessed = true
        
        statusText = "\(sourceName) — \(rawSamples.count) samples @ \(Int(samplingRate)) Hz"
        print("✅ Loaded:", statusText)
        
        clampViewport()
        runRPeakDetectionAndSegmentation()
    }
    
    private func runRPeakDetectionAndSegmentation() {
        guard let d = ecgData else {
            rPeaks = []
            beatWindows = []
            beatPredictions = []
            beatProbs = []
            return
        }
        
        let rawPeaks = RPeakDetector.detect(samples: d.processedSamples, fs: d.samplingRate)
        let peaks = postprocessPeaks(peaks: rawPeaks, samples: d.processedSamples, fs: d.samplingRate)
        
        rPeaks = peaks
        print("🔵 Number of R-peaks detected:", rPeaks.count)
        
        beatWindows = BeatSegmenter.segment(
            samples: d.processedSamples,
            rPeaks: peaks,
            fs: d.samplingRate
        )
        print("🟦 Windows created:", beatWindows.count)
        
#if DEBUG
        let rr = rrIntervals
        print("🟢 RR intervals (seconds):")
        for (i, val) in rr.prefix(10).enumerated() {
            print("  RR[\(i)] = \(String(format: "%.3f", val)) s")
        }
        if !rr.isEmpty {
            let meanRR = rr.reduce(0, +) / Double(rr.count)
            print("📊 Mean RR:", String(format: "%.3f", meanRR), "s")
            print("❤️ Mean HR:", String(format: "%.1f", 60.0 / meanRR), "bpm")
        }
#endif
        
        runBeatClassification()
    }
    
    private func runBeatClassification() {
        guard !beatWindows.isEmpty else {
            beatPredictions = []
            beatProbs = []
            return
        }
        
        do {
            if classifier == nil { classifier = try BeatClassifierService() }
            let preds = try classifier!.predict(beats: beatWindows)
            
            beatPredictions = []
            beatPredictions.reserveCapacity(preds.count)
            
            beatProbs = []
            beatProbs.reserveCapacity(preds.count)
            
            for (i, p) in preds.enumerated() {
                let rawLabel = p.label
                
                let probs = softmax(p.probs)
                let pvcProb = probs["PVC"] ?? 0
                
                let finalLabel = pvcProb >= 0.80 ? "PVC" : rawLabel
                
                beatProbs.append(probs)
                beatPredictions.append(finalLabel)
                
#if DEBUG
                let nProb = p.probs["N"] ?? 0
                let oProb = p.probs["Other"] ?? 0
                print("""
                🫀 Beat \(i + 1)
                    Raw label: \(rawLabel)
                    N: \(String(format: "%.3f", nProb))
                    PVC: \(String(format: "%.3f", pvcProb))
                    Other: \(String(format: "%.3f", oProb))
                    Final label: \(finalLabel)
                """)
#endif
            }
            
            statusText = "\(statusText) — Classified \(preds.count) beats"
            computeRhythmSummary()
            print("🧠 Classified beats:", preds.count)
            computeRhythmSummary()
            
        } catch {
            print("❌ Core ML classification error:", error)
            beatPredictions = Array(repeating: "Other", count: beatWindows.count)
            beatProbs = Array(repeating: [:], count: beatWindows.count)
            statusText = "\(statusText) — Model error"
            computeRhythmSummary()
        }
    }
    
    // MARK: - Peak postprocessing (refine + min-distance)
    
    private func postprocessPeaks(peaks: [Int], samples: [Float], fs: Double) -> [Int] {
        guard !peaks.isEmpty, fs > 0 else { return [] }
        
        let minDistance = Int(0.30 * fs)   // ~300 ms
        let refineSearch = Int(0.04 * fs)  // ~40 ms
        
        // 1) sort + refine each peak to nearest local max (abs)
        let refined = peaks.sorted().map { refinePeak($0, samples: samples, search: refineSearch) }
        
        // 2) enforce min distance; choose by QRS sharpness (tie-break by amplitude)
        var kept: [Int] = []
        kept.reserveCapacity(refined.count)
        
        var current = refined[0]
        for p in refined.dropFirst() {
            if p - current < minDistance {
                let sharpC = qrsSharpness(at: current, samples: samples)
                let sharpP = qrsSharpness(at: p, samples: samples)
                
                if sharpP > sharpC {
                    current = p
                } else if sharpP == sharpC {
                    if abs(samples[p]) > abs(samples[current]) { current = p }
                }
            } else {
                kept.append(current)
                current = p
            }
        }
        kept.append(current)
        return kept
    }
    
    private func refinePeak(_ p: Int, samples: [Float], search: Int) -> Int {
        guard samples.indices.contains(p) else { return p }
        
        let start = max(0, p - search)
        let end = min(samples.count - 1, p + search)
        
        var best = p
        var bestVal = abs(samples[p])
        
        if start <= end {
            for i in start...end {
                let v = abs(samples[i])
                if v > bestVal {
                    bestVal = v
                    best = i
                }
            }
        }
        return best
    }
    
    private func qrsSharpness(at p: Int, samples: [Float]) -> Float {
        // Sum absolute first differences in a small window
        let w = 6 // ~17 ms each side at 360 Hz
        let start = max(1, p - w)
        let end = min(samples.count - 2, p + w)
        
        guard start <= end else { return 0 }
        
        var s: Float = 0
        for i in start...end {
            s += abs(samples[i + 1] - samples[i - 1])
        }
        return s
    }
    
    func computeRhythmSummary() {
        guard let d = ecgData, d.samplingRate > 0 else {
            rhythmSummary = nil
            return
        }

        let total = beatWindows.count
        guard total > 0 else {
            rhythmSummary = RhythmSummary(
                totalBeats: 0,
                avgHR: nil, meanRR: nil, rrStd: nil, rrCV: nil,
                counts: [:],
                badge: .insufficientData,
                narrative: "Load a signal and detect beats to generate a rhythm summary."
            )
            return
        }

        // Counts by label
        var counts: [String: Int] = [:]
        for label in beatPredictions {
            counts[label, default: 0] += 1
        }

        // RR metrics (seconds)
        let rr = rrIntervals
        let meanRR = rr.mean()
        let rrStd = rr.std()
        let rrCV = (meanRR != nil && rrStd != nil && meanRR! > 0) ? (rrStd! / meanRR!) : nil
        let avgHR = (meanRR != nil && meanRR! > 0) ? (60.0 / meanRR!) : nil

        // Simple badge rules (tune thresholds later)
        let pvcCount = counts["PVC"] ?? 0
        let abnormalCount = total - (counts["N"] ?? 0)

        let badge: RhythmSummary.Badge
        if total < 3 || rr.count < 2 {
            badge = .insufficientData
        } else if pvcCount > 0 {
            badge = .ectopyDetected
        } else if let cv = rrCV, cv > 0.12 {   // ~ rough “irregularity” heuristic
            badge = .irregular
        } else {
            badge = .regular
        }

        // Narrative text
        let narrative: String = {
            switch badge {
            case .insufficientData:
                return "Not enough beats to summarize rhythm."
            case .regular:
                return "Rhythm appears mostly regular in this segment."
            case .irregular:
                return "RR intervals vary noticeably, suggesting an irregular pattern in this segment."
            case .ectopyDetected:
                if pvcCount == 1 {
                    return "A premature ventricular-like beat was detected."
                } else {
                    return "\(pvcCount) premature ventricular-like beats were detected."
                }
            }
        }()

        rhythmSummary = RhythmSummary(
            totalBeats: total,
            avgHR: avgHR,
            meanRR: meanRR,
            rrStd: rrStd,
            rrCV: rrCV,
            counts: counts,
            badge: badge,
            narrative: narrative
        )
    }
    
    func explainBeat(at index: Int) -> BeatExplanation? {
        guard beatWindows.indices.contains(index) else { return nil }

        let label = beatPredictions.indices.contains(index) ? beatPredictions[index] : "Unclassified"
        let probs = beatProbs.indices.contains(index) ? beatProbs[index] : [:]
        let conf = probs[label] ?? probs.max(by: { $0.value < $1.value })?.value

        // RR context
        let rr = rrIntervals
        let meanRR = rr.mean()
        let currentRR: Double? = (index > 0 && rr.indices.contains(index - 1)) ? rr[index - 1] : nil
        let nextRR: Double? = (rr.indices.contains(index)) ? rr[index] : nil

        // Beat morphology: compare selected beat vs neighbors (simple but effective)
        let thisBeat = beatWindows[index].samples
        let prevBeat = (index > 0) ? beatWindows[index - 1].samples : nil
        let nextBeat = (index + 1 < beatWindows.count) ? beatWindows[index + 1].samples : nil

        let thisRMS = thisBeat.rms()
        let thisPeak = thisBeat.peakAbs()
        let prevRMS = prevBeat?.rms()
        let nextRMS = nextBeat?.rms()

        // "Morphology difference" heuristic: change in energy vs neighbors
        // (Not clinical morphology, but a good interpretable demo proxy)
        var morphFlags: [String] = []
        if let a = thisRMS, let p = prevRMS {
            let ratio = a / max(p, 1e-9)
            if ratio > 1.25 || ratio < 0.80 {
                morphFlags.append("Waveform energy differs from the previous beat.")
            }
        }
        if let a = thisRMS, let n = nextRMS {
            let ratio = a / max(n, 1e-9)
            if ratio > 1.25 || ratio < 0.80 {
                morphFlags.append("Waveform energy differs from the next beat.")
            }
        }

        // Timing heuristics
        var timingFlags: [String] = []
        if let cur = currentRR, let m = meanRR, m > 0 {
            if cur < 0.85 * m {
                timingFlags.append("This beat occurred earlier than expected (short RR interval).")
            } else if cur > 1.15 * m {
                timingFlags.append("This beat occurred later than expected (long RR interval).")
            } else {
                timingFlags.append("Beat timing is close to the local average (RR is consistent).")
            }
        } else {
            timingFlags.append("Not enough surrounding beats to evaluate timing.")
        }

        // Compensatory pause (common with PVCs, but not guaranteed)
        if let nxt = nextRR, let m = meanRR, m > 0, nxt > 1.15 * m {
            timingFlags.append("The following interval is longer, consistent with a pause after this beat.")
        }

        // Confidence string
        let confidenceText: String? = {
            guard let c = conf else { return nil }
            return "Confidence: \(c.asPercent0())"
        }()

        // Build explanation per label
        switch label {

        case "N":

            var bullets: [String] = []

            if let cur = currentRR, let m = meanRR, m > 0 {
                if abs(cur - m) / m < 0.15 {
                    bullets.append("Beat-to-beat timing is consistent with the local average.")
                } else if cur < 0.85 * m {
                    bullets.append("This beat occurs slightly earlier than the surrounding average.")
                } else {
                    bullets.append("This beat occurs slightly later than the surrounding average.")
                }
            } else {
                bullets.append("Timing context is limited in this segment.")
            }

            if morphFlags.isEmpty {
                bullets.append("Waveform morphology appears consistent with neighboring beats.")
            } else {
                bullets.append("Minor waveform variation is present compared to adjacent beats.")
            }

            if let peak = thisPeak {
                bullets.append("Signal amplitude proxy (peak): \(peak.fmt(2)) (normalized units).")
            }

            return BeatExplanation(
                title: "Normal sinus-pattern beat (N)",
                confidenceText: confidenceText?.replacingOccurrences(of: "Confidence:", with: "Model support:"),
                bullets: bullets,
                note: "Educational only — short segments and noise can influence interpretation."
            )

        case "PVC":

            var bullets: [String] = []

            if let cur = currentRR, let m = meanRR, m > 0, cur < 0.85 * m {
                bullets.append("Timing suggests an early beat relative to the local average.")
            } else {
                bullets.append("Timing differs modestly from the surrounding rhythm.")
            }

            if let nxt = nextRR, let m = meanRR, m > 0, nxt > 1.15 * m {
                bullets.append("A longer following interval is observed, which can occur after an ectopic beat.")
            }

            if morphFlags.isEmpty {
                bullets.append("Waveform differences are subtle using this simple morphology proxy.")
            } else {
                bullets.append("Waveform morphology differs from adjacent beats by a simple energy-based proxy.")
            }

            if let peak = thisPeak {
                bullets.append("Signal amplitude proxy (peak): \(peak.fmt(2)) (normalized units).")
            }

            return BeatExplanation(
                title: "Ventricular ectopic pattern (PVC)",
                confidenceText: confidenceText?.replacingOccurrences(of: "Confidence:", with: "Model support:"),
                bullets: bullets,
                note: "Educational only — this indicates a PVC-like pattern in this segment, not a clinical diagnosis."
            )

        case "Other":

            var bullets: [String] = []

            bullets.append("This beat does not strongly align with the primary trained categories (normal vs PVC).")

            if let cur = currentRR, let m = meanRR, m > 0 {
                if abs(cur - m) / m < 0.15 {
                    bullets.append("Timing is broadly consistent with the surrounding rhythm.")
                } else {
                    bullets.append("Timing differs from the surrounding average.")
                }
            }

            if morphFlags.isEmpty {
                bullets.append("Waveform variation is limited by this simple morphology proxy.")
            } else {
                bullets.append("Waveform characteristics differ from neighboring beats.")
            }

            if let c = conf, c < 0.70 {
                bullets.append("Model support is lower in this segment, which can occur with noise or atypical morphology.")
            }

            return BeatExplanation(
                title: "Atypical or mixed pattern (Other)",
                confidenceText: confidenceText?.replacingOccurrences(of: "Confidence:", with: "Model support:"),
                bullets: bullets,
                note: "Educational only — review waveform context and signal quality."
            )

        default:

            return BeatExplanation(
                title: "Unclassified beat",
                confidenceText: confidenceText?.replacingOccurrences(of: "Confidence:", with: "Model support:"),
                bullets: ["No classification available for this beat."],
                note: nil
            )
        }
    }
    
    func softmax(_ logits: [String: Double]) -> [String: Double] {
        guard !logits.isEmpty else { return [:] }
        let maxLogit = logits.values.max() ?? 0
        let exps = logits.mapValues { exp($0 - maxLogit) }
        let sum = exps.values.reduce(0, +)
        guard sum > 0 else { return [:] }
        return exps.mapValues { $0 / sum }
    }
    
    // PVC markers
    func firstIndex(of label: String) -> Int? {
        beatPredictions.firstIndex(where: { $0 == label })
    }

    func nextIndex(of label: String, from current: Int) -> Int? {
        guard !beatPredictions.isEmpty else { return nil }
        let start = min(max(current + 1, 0), beatPredictions.count)
        if start < beatPredictions.count {
            if let i = beatPredictions[start...].firstIndex(where: { $0 == label }) { return i }
        }
        // wrap-around
        if let i = beatPredictions.firstIndex(where: { $0 == label }) { return i }
        return nil
    }

    func prevIndex(of label: String, from current: Int) -> Int? {
        guard !beatPredictions.isEmpty else { return nil }
        let end = min(max(current - 1, -1), beatPredictions.count - 1)
        if end >= 0 {
            for i in stride(from: end, through: 0, by: -1) {
                if beatPredictions[i] == label { return i }
            }
        }
        // wrap-around
        for i in stride(from: beatPredictions.count - 1, through: 0, by: -1) {
            if beatPredictions[i] == label { return i }
        }
        return nil
    }
    
    // Demo data
    private struct DemoECGFile: Decodable {
        let samplingRate: Double
        let samples: [Float]
    }

    func loadBundledDemo(named fileName: String) {
        do {
            let data = try loadBundledData(named: fileName, ext: "json")
            let decoded = try JSONDecoder().decode(DemoECGFile.self, from: data)

            applyLoadedECG(
                rawSamples: decoded.samples,
                samplingRate: decoded.samplingRate,
                sourceName: "Demo: \(fileName)"
            )
            lastErrorText = nil

        } catch {
            lastErrorText = "Failed to load demo: \(error.localizedDescription)"
            statusText = "Demo load failed."
            print("❌ Demo load error:", error)
        }
    }

    private func loadBundledData(named name: String, ext: String) throws -> Data {
        #if SWIFT_PACKAGE
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            throw NSError(domain: "Demo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing \(name).\(ext) in Bundle.module"])
        }
        #else
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw NSError(domain: "Demo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing \(name).\(ext) in Bundle.main"])
        }
        #endif

        return try Data(contentsOf: url)
    }
}
