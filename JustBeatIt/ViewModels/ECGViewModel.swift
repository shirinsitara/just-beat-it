import Foundation
import Combine

@MainActor
final class ECGViewModel: ObservableObject {
    
    @Published var ecgData: ECGData?
    @Published var statusText: String = "No file loaded."
    @Published var lastErrorText: String?
    @Published var showProcessed: Bool = true
    
    private let loader = ECGFileLoader()
    
    init() {
        NSLog("🟣 ECGViewModel init()")
        loadDummyData()
    }
    
    var displaySamples: [Float] {
        guard let d = ecgData else { return [] }
        return showProcessed ? d.processedSamples : d.rawSamples
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
        
        let processed = ECGProcessor.zScoreNormalize(samples)
        let data = ECGData(rawSamples: samples, processedSamples: processed, samplingRate: samplingRate)
        applyLoadedECG(rawSamples: samples, samplingRate: samplingRate, sourceName: "Dummy")
    }
    
    func loadFromFile(url: URL) {
        do {
            let data = try loader.load(from: url)
            applyLoadedECG(rawSamples: data.rawSamples, samplingRate: data.samplingRate, sourceName: url.lastPathComponent)
            lastErrorText = nil
        } catch {
            lastErrorText = error.localizedDescription
            statusText = "Failed to load."
            print("❌ Load error:", error)
        }
    }
    
    private func applyLoadedECG(rawSamples: [Float], samplingRate: Double, sourceName: String) {
        let processed = ECGProcessor.zScoreNormalize(rawSamples)
        
        let rawStats = ECGProcessor.stats(rawSamples)
        print(String(format: "RAW  → mean: %.6f, std: %.6f, min: %.6f, max: %.6f",
                     rawStats.mean, rawStats.std, rawStats.min, rawStats.max))
        
        let procStats = ECGProcessor.stats(processed)
        print(String(format: "PROC → mean: %.6f, std: %.6f, min: %.6f, max: %.6f",
                     procStats.mean, procStats.std, procStats.min, procStats.max))
        
        ecgData = ECGData(rawSamples: rawSamples, processedSamples: processed, samplingRate: samplingRate)
        
        statusText = "\(sourceName) — \(rawSamples.count) samples @ \(Int(samplingRate)) Hz"
        print("✅ Loaded:", statusText)
        
        let n = min(20, rawSamples.count)
        print("First \(n) RAW samples:", rawSamples.prefix(n))
        print("First \(n) PROC samples:", processed.prefix(n))
    }
}


