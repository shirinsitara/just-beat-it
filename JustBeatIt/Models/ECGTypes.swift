import Foundation

struct ECGRecording {
    let samples: [Float]
    let fs: Float   // 360
}

func zscoreRecording(_ x: [Float], eps: Float = 1e-8) -> [Float] {
    guard !x.isEmpty else { return [] }
    let mean = x.reduce(0, +) / Float(x.count)
    var varSum: Float = 0
    for v in x { let d = v - mean; varSum += d * d }
    let std = max(sqrt(varSum / Float(x.count)), eps)
    return x.map { ($0 - mean) / std }
}
