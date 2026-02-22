import Foundation

struct BeatSegmenter {

    struct Config {
        var preSeconds: Double = 0.20
        var postSeconds: Double = 0.40
    }

    static func windows(rPeaks: [Int], signalCount: Int, fs: Double, config: Config = .init()) -> [BeatWindow] {
        guard fs > 0, signalCount > 0, !rPeaks.isEmpty else { return [] }

        let pre = Int(config.preSeconds * fs)   // 72 at 360 Hz
        let post = Int(config.postSeconds * fs) // 144 at 360 Hz

        var out: [BeatWindow] = []
        out.reserveCapacity(rPeaks.count)

        for r in rPeaks {
            let start = r - pre
            let end = r + post

            // Skip edge cases that would clip
            guard start >= 0, end <= signalCount else { continue }

            out.append(BeatWindow(rIndex: r, startIndex: start, endIndex: end))
        }

        return out
    }
}

