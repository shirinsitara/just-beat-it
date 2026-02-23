import Foundation

struct BeatSegmenter {

    struct Config {
        var preSeconds: Double = 0.20
        var postSeconds: Double = 0.40
    }

    static func segment(
        samples: [Float],
        rPeaks: [Int],
        fs: Double,
        config: Config = .init()
    ) -> [BeatWindow] {

        guard fs > 0, !samples.isEmpty, !rPeaks.isEmpty else { return [] }

        let pre = Int(config.preSeconds * fs)   // 72 at 360 Hz
        let post = Int(config.postSeconds * fs) // 144 at 360 Hz

        var out: [BeatWindow] = []
        out.reserveCapacity(rPeaks.count)

        for r in rPeaks {
            let start = r - pre
            let end = r + post

            // Skip edge cases that would clip
            guard start >= 0, end <= samples.count else { continue }

            let windowSamples = Array(samples[start..<end])

            out.append(
                BeatWindow(
                    rIndex: r,
                    startIndex: start,
                    endIndex: end,
                    samples: windowSamples
                )
            )
        }

        return out
    }
}
