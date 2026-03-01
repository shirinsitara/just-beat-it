import Foundation

struct BeatExplanation: Equatable {
    let title: String                 // e.g. "Normal beat", "PVC-like beat", "Uncertain beat"
    let confidenceText: String?       // e.g. "Confidence: 0.91"
    let bullets: [String]             // reasons
    let note: String?                 // safety / caveat line
}

extension Double {
    func asPercent0() -> String { String(format: "%.0f%%", self * 100.0) }
    func fmt(_ dp: Int) -> String { String(format: "%.\(dp)f", self) }
}

extension Array where Element == Float {
    func mean() -> Double? {
        guard !isEmpty else { return nil }
        return Double(reduce(0, +)) / Double(count)
    }

    func rms() -> Double? {
        guard !isEmpty else { return nil }
        let s = reduce(0.0) { acc, v in
            let d = Double(v)
            return acc + d*d
        }
        return sqrt(s / Double(count))
    }

    func peakAbs() -> Double? {
        guard !isEmpty else { return nil }
        return map { abs(Double($0)) }.max()
    }
}
