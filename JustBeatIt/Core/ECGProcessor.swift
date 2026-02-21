import Foundation

struct ECGProcessor {

    /// Z-score normalization (per recording)
    static func zScoreNormalize(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return samples }

        let mean = samples.reduce(0, +) / Float(samples.count)

        var sumSq: Float = 0
        for x in samples {
            let d = x - mean
            sumSq += d * d
        }

        let variance = sumSq / Float(samples.count)
        let std = sqrt(max(variance, 1e-12)) // avoid divide-by-zero
        return samples.map { ($0 - mean) / std }
    }

    static func stats(_ samples: [Float]) -> (mean: Float, std: Float, min: Float, max: Float) {
        guard !samples.isEmpty else { return (0, 0, 0, 0) }

        let mean = samples.reduce(0, +) / Float(samples.count)

        var sumSq: Float = 0
        for x in samples {
            let d = x - mean
            sumSq += d * d
        }

        let variance = sumSq / Float(samples.count)
        let std = sqrt(max(variance, 0))

        let minV = samples.min() ?? 0
        let maxV = samples.max() ?? 0
        return (mean, std, minV, maxV)
    }
}
