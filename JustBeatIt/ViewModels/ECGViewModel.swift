import Foundation
internal import Combine

class ECGViewModel: ObservableObject {
    
    @Published var ecgData: ECGData?
    
    init() {
        loadDummyData()
    }
    
    func loadDummyData() {
        let samplingRate = 360.0
        let duration = 5.0
        
        let totalSamples = Int(samplingRate * duration)
        
        var samples: [Float] = []
        
        for i in 0..<totalSamples {
            let t = Double(i) / samplingRate
            
            // Fake ECG-like signal
            let signal =
                sin(2 * .pi * 1.2 * t) * 0.1 +   // baseline oscillation
                exp(-pow((t.truncatingRemainder(dividingBy: 1.0) - 0.2) * 40, 2)) // fake R-peak
            
            samples.append(Float(signal))
        }
        
        ecgData = ECGData(samples: samples, samplingRate: samplingRate)
    }
}

