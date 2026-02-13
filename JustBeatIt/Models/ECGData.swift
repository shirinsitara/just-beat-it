import Foundation

struct ECGData: Codable {
    let samples: [Float]
    let samplingRate: Double
}
