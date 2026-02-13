import Foundation
import Combine

@MainActor
final class ECGViewModel: ObservableObject {

    @Published var ecgData: ECGData?
    @Published var statusText: String = "No file loaded."
    @Published var lastErrorText: String?

    private let loader = ECGFileLoader()

    init() {
        loadDummyData()
    }

    func loadDummyData() {
        let samplingRate = 360.0
        let duration = 5.0
        let totalSamples = Int(samplingRate * duration)

        var samples: [Float] = []
        samples.reserveCapacity(totalSamples)

        for i in 0..<totalSamples {
            let t = Double(i) / samplingRate
            let signal =
                sin(2 * .pi * 1.2 * t) * 0.08 +
                exp(-pow((t.truncatingRemainder(dividingBy: 1.0) - 0.2) * 40, 2))
            samples.append(Float(signal))
        }

        let data = ECGData(samples: samples, samplingRate: samplingRate)
        applyLoadedECG(data, sourceName: "Dummy")
    }

    func loadFromFile(url: URL) {
        do {
            let data = try loader.load(from: url)
            applyLoadedECG(data, sourceName: url.lastPathComponent)
            lastErrorText = nil
        } catch {
            lastErrorText = error.localizedDescription
            statusText = "Failed to load."
            print("❌ Load error:", error)
        }
    }

    private func applyLoadedECG(_ data: ECGData, sourceName: String) {
        ecgData = data
        statusText = "\(sourceName) — \(data.samples.count) samples @ \(Int(data.samplingRate)) Hz"
        print("✅ Loaded:", statusText)

        let n = min(100, data.samples.count)
        let preview = data.samples.prefix(n)
        print("First \(n) samples:")
        for (i, v) in preview.enumerated() {
            print(String(format: "%03d: %.6f", i, v))
        }
    }
}
