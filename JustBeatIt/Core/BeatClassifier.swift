import Foundation
import CoreML

struct BeatPrediction {
    let rIndex: Int
    let label: String
    let probs: [String: Double]
}

final class BeatClassifierService {
    private let model: ECGBeatClassifier

    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        self.model = try ECGBeatClassifier(configuration: config)
    }

    private func makeBeatArray(_ beat: [Float]) throws -> MLMultiArray {
        precondition(beat.count == 216)
        let arr = try MLMultiArray(shape: [1, 1, 216], dataType: .float32)

        // Fast fill
        let ptr = arr.dataPointer.bindMemory(to: Float32.self, capacity: 216)
        for i in 0..<216 { ptr[i] = beat[i] }

        return arr
    }

    func predict(beats: [BeatWindow]) throws -> [BeatPrediction] {
        var outArr: [BeatPrediction] = []
        outArr.reserveCapacity(beats.count)

        for b in beats {
            let x = try makeBeatArray(b.samples)
            let out = try model.prediction(beat: x)

            outArr.append(
                BeatPrediction(rIndex: b.rIndex, label: out.classLabel, probs: out.classLabel_probs)
            )
        }
        return outArr
    }
}
