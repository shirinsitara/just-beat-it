import Foundation

enum RPeakDetector {

    // MARK: - Public API

    /// Pan–Tompkins-lite detector
    /// - Parameters:
    ///   - samples: processed (z-scored) ECG preferred, single lead
    ///   - fs: sampling rate (e.g., 360)
    /// - Returns: indices of detected R-peaks (global sample indices)
    static func detect(samples: [Float], fs: Double) -> [Int] {
        guard samples.count > 10, fs > 0 else { return [] }

        // 1) QRS emphasis (cheap bandpass-ish): highpass (x - MA) then lowpass (MA)
        let hp = highpassMovingAverage(samples, fs: fs, cutoffHz: 5.0)
        let bp = lowpassMovingAverage(hp, fs: fs, cutoffHz: 15.0)

        // 2) Differentiate (slope)
        let diff = derivative5pt(bp)

        // 3) Square (energy)
        let squared = diff.map { $0 * $0 }

        // 4) Moving Window Integration (~150 ms)
        let mwiWindow = max(1, Int(0.150 * fs))
        let integrated = movingAverage(squared, window: mwiWindow)

        // 5) Adaptive threshold + refractory on integrated signal
        let refractory = max(1, Int(0.250 * fs)) // ~250 ms

        // init threshold from first ~2s
        let initLen = min(integrated.count, max(1, Int(2.0 * fs)))
        let initMax = integrated.prefix(initLen).max() ?? 0
        var thresh: Float = initMax * 0.35 // tune 0.25–0.45

        var peaks: [Int] = []
        peaks.reserveCapacity(max(16, Int(fs * 2)))

        var lastAccepted = -refractory

        // Simplified Pan–Tompkins levels
        var signalLevel: Float = thresh
        var noiseLevel: Float = thresh * 0.5

        let alpha: Float = 0.125
        let beta: Float = 0.125

        for i in 1..<(integrated.count - 1) {
            let v = integrated[i]

            let isLocalMax = (v >= integrated[i - 1]) && (v > integrated[i + 1])

            if isLocalMax, v > thresh {
                if i - lastAccepted >= refractory {
                    // refine to true R peak near i on bp signal
                    let refineRadius = max(1, Int(0.080 * fs)) // ~80 ms
                    let r = refinePeak(around: i, in: bp, radius: refineRadius)

                    peaks.append(r)
                    lastAccepted = i

                    signalLevel = (1 - alpha) * signalLevel + alpha * v
                }
            } else {
                noiseLevel = (1 - beta) * noiseLevel + beta * v
            }

            // Update threshold
            thresh = noiseLevel + 0.25 * (signalLevel - noiseLevel)
        }

        // 6) Final cleanup: enforce minimum distance on refined peaks
        let minDist = max(1, Int(0.30 * fs)) // ~300 ms
        return enforceMinDistanceByAmplitude(peaks.sorted(), samples: bp, minDistance: minDist)
    }

    // MARK: - Filters

    private static func lowpassMovingAverage(_ x: [Float], fs: Double, cutoffHz: Double) -> [Float] {
        let w = max(1, Int(fs / max(cutoffHz, 1.0)))
        return movingAverage(x, window: w)
    }

    /// Highpass via: x - movingAverage(x)
    private static func highpassMovingAverage(_ x: [Float], fs: Double, cutoffHz: Double) -> [Float] {
        let w = max(1, Int(fs / max(cutoffHz, 1.0)))
        let ma = movingAverage(x, window: w)
        var out = Array(repeating: Float(0), count: x.count)
        for i in 0..<x.count { out[i] = x[i] - ma[i] }
        return out
    }

    /// O(n) moving average with running sum
    private static func movingAverage(_ x: [Float], window: Int) -> [Float] {
        guard window > 1, !x.isEmpty else { return x }

        var out = Array(repeating: Float(0), count: x.count)
        var sum: Float = 0

        for i in 0..<x.count {
            sum += x[i]
            if i >= window {
                sum -= x[i - window]
                out[i] = sum / Float(window)
            } else {
                out[i] = sum / Float(i + 1) // warm-up
            }
        }
        return out
    }

    // MARK: - Derivative / Refinement / Cleanup

    /// 5-point derivative approximation (Pan–Tompkins-ish)
    private static func derivative5pt(_ x: [Float]) -> [Float] {
        let n = x.count
        guard n >= 5 else { return Array(repeating: 0, count: n) }

        var d = Array(repeating: Float(0), count: n)
        for i in 2..<(n - 2) {
            d[i] = (-x[i - 2] - 2 * x[i - 1] + 2 * x[i + 1] + x[i + 2]) / 8.0
        }
        return d
    }

    /// Find strongest abs peak near idx (bounds-safe)
    private static func refinePeak(around idx: Int, in signal: [Float], radius: Int) -> Int {
        guard !signal.isEmpty else { return idx }
        let clampedIdx = min(max(0, idx), signal.count - 1)

        let start = max(0, clampedIdx - radius)
        let end = min(signal.count - 1, clampedIdx + radius)

        var best = clampedIdx
        var bestVal = abs(signal[clampedIdx])

        if start <= end {
            for i in start...end {
                let v = abs(signal[i])
                if v > bestVal {
                    bestVal = v
                    best = i
                }
            }
        }
        return best
    }

    /// Enforce min distance; if too close keep higher abs amplitude
    private static func enforceMinDistanceByAmplitude(_ peaks: [Int], samples: [Float], minDistance: Int) -> [Int] {
        guard !peaks.isEmpty else { return [] }

        var kept: [Int] = []
        kept.reserveCapacity(peaks.count)

        var current = peaks[0]
        for p in peaks.dropFirst() {
            if p - current < minDistance {
                if abs(samples[p]) > abs(samples[current]) {
                    current = p
                }
            } else {
                kept.append(current)
                current = p
            }
        }
        kept.append(current)
        return kept
    }
}
