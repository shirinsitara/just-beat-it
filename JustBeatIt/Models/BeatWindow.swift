import Foundation

struct BeatWindow: Identifiable, Hashable {
    let id = UUID()

    let rIndex: Int
    let startIndex: Int
    let endIndex: Int
    
    let samples: [Float]    // 216 samples
}

func segmentBeatsSkipEdges(samples: [Float], rPeaks: [Int], fs: Float = 360,
                           preSeconds: Float = 0.20, postSeconds: Float = 0.40) -> [BeatWindow] {
    let pre = Int(preSeconds * fs)     // 72 (truncation matches Python)
    let post = Int(postSeconds * fs)   // 144
    let winLen = pre + post            // 216

    let n = samples.count
    var out: [BeatWindow] = []
    out.reserveCapacity(rPeaks.count)

    for r in rPeaks {
        let start = r - pre
        let end = r + post // end-exclusive
        if start < 0 || end > n { continue }
        let w = Array(samples[start..<end])
        if w.count != winLen { continue }
        out.append(BeatWindow(rIndex: r, startIndex: start, endIndex: end, samples: w))
    }
    return out
}
