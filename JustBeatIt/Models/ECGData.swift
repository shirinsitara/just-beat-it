import Foundation

struct ECGData: Identifiable, Codable {
    let id = UUID()

    let rawSamples: [Float]
    let processedSamples: [Float]
    let samplingRate: Double

    // Custom keys so we can support old JSON too
    enum CodingKeys: String, CodingKey {
        case rawSamples
        case processedSamples
        case samples        // legacy key
        case samplingRate
    }

    init(rawSamples: [Float], processedSamples: [Float], samplingRate: Double) {
        self.rawSamples = rawSamples
        self.processedSamples = processedSamples
        self.samplingRate = samplingRate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        samplingRate = try c.decode(Double.self, forKey: .samplingRate)

        // Prefer rawSamples, otherwise fall back to legacy "samples"
        if let raw = try c.decodeIfPresent([Float].self, forKey: .rawSamples) {
            rawSamples = raw
        } else if let legacy = try c.decodeIfPresent([Float].self, forKey: .samples) {
            rawSamples = legacy
        } else {
            rawSamples = []
        }

        // If processedSamples exists in the file, accept it; otherwise compute it
        if let proc = try c.decodeIfPresent([Float].self, forKey: .processedSamples),
           !proc.isEmpty {
            processedSamples = proc
        } else {
            processedSamples = ECGProcessor.zScoreNormalize(rawSamples)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(samplingRate, forKey: .samplingRate)
        try c.encode(rawSamples, forKey: .rawSamples)
        // You can choose whether to save processedSamples; keeping it is fine for debugging.
        try c.encode(processedSamples, forKey: .processedSamples)
    }
}
