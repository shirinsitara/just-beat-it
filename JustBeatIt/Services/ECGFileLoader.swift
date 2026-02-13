import Foundation

enum ECGFileLoaderError: Error, LocalizedError {
    case unsupportedFileType
    case emptyData
    case csvParseFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType: return "Unsupported file type. Please use .json or .csv."
        case .emptyData: return "File appears to be empty."
        case .csvParseFailed: return "Could not parse CSV. Expected one column of numbers, or comma-separated numbers."
        }
    }
}

final class ECGFileLoader {

    func load(from url: URL) throws -> ECGData {
        // Security-scoped access (Files app)
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer {
            if gotAccess { url.stopAccessingSecurityScopedResource() }
        }

        let ext = url.pathExtension.lowercased()

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw ECGFileLoaderError.emptyData }

        switch ext {
        case "json":
            return try decodeJSON(data: data)

        case "csv", "txt":
            // Allow .txt as a convenience during dev
            let text = String(decoding: data, as: UTF8.self)
            return try decodeCSV(text: text)

        default:
            throw ECGFileLoaderError.unsupportedFileType
        }
    }

    private func decodeJSON(data: Data) throws -> ECGData {
        let decoder = JSONDecoder()
        // If you later add metadata keys, keep this strict for now.
        return try decoder.decode(ECGData.self, from: data)
    }

    /// CSV expectations:
    /// - Either one value per line:
    ///   0.1
    ///   0.2
    /// - or comma-separated values in one/many lines:
    ///   0.1,0.2,0.3
    ///
    /// Sampling rate in CSV: for now we default to 360 Hz.
    /// (We’ll add header support later if you want.)
    private func decodeCSV(text: String, defaultSamplingRate: Double = 360.0) throws -> ECGData {
        let cleaned = text
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else { throw ECGFileLoaderError.emptyData }

        // Split on commas OR newlines
        let tokens = cleaned
            .split { $0 == "," || $0 == "\n" || $0 == "\t" || $0 == " " }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Try Float parse
        var samples: [Float] = []
        samples.reserveCapacity(tokens.count)

        for tok in tokens {
            if let v = Float(tok) {
                samples.append(v)
            } else {
                // If the CSV has a header or non-numeric token, you can choose to skip it.
                // For now, if anything non-numeric exists, fail loudly (cleaner for MVP).
                throw ECGFileLoaderError.csvParseFailed
            }
        }

        guard !samples.isEmpty else { throw ECGFileLoaderError.emptyData }

        return ECGData(samples: samples, samplingRate: defaultSamplingRate)
    }
}
