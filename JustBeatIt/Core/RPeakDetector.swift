import Foundation

struct RPeakDetector {

    struct Config {
        /// Threshold in z-score units. Typical 0.8–1.5 depending on signal.
        var thresholdZ: Float = 1.0

        /// Minimum time between R peaks (seconds). 0.20s ~= 300 bpm upper bound.
        var refractorySeconds: Double = 0.20
    }

    /// Simple local-maximum peak detector for *processed/normalized* ECG.
    /// Returns indices of detected R-peaks.
    static func detect(samples: [Float], fs: Double, config: Config = .init()) -> [Int] {
        guard samples.count > 3, fs > 0 else { return [] }

        let refractory = max(1, Int(config.refractorySeconds * fs))
        var peaks: [Int] = []
        peaks.reserveCapacity(max(10, samples.count / Int(fs)))

        var lastAccepted = -refractory

        // Scan for local maxima above threshold
        for i in 1..<(samples.count - 1) {
            let x0 = samples[i - 1]
            let x1 = samples[i]
            let x2 = samples[i + 1]

            let isLocalMax = (x1 > x0) && (x1 >= x2)
            if !isLocalMax { continue }

            let aboveThresh = x1 >= config.thresholdZ
            if !aboveThresh { continue }

            let outsideRefractory = (i - lastAccepted) >= refractory
            if !outsideRefractory { continue }

            peaks.append(i)
            lastAccepted = i
        }

        return peaks
    }
}
