import Foundation

struct RhythmSummary: Equatable {
    enum Badge: String {
        case regular = "Regular"
        case irregular = "Irregular"
        case ectopyDetected = "Ectopy detected"
        case insufficientData = "Insufficient data"
    }

    let totalBeats: Int
    let avgHR: Double?            // bpm
    let meanRR: Double?           // seconds
    let rrStd: Double?            // seconds (SDNN-style)
    let rrCV: Double?// coefficient of variation (std/mean)

    let counts: [String: Int]     // label -> count
    let badge: Badge
    let narrative: String
}

extension Array where Element == Double {
    func mean() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }

    func std() -> Double? {
        guard count >= 2, let m = mean() else { return nil }
        let v = reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(count - 1)
        return sqrt(v)
    }
}
