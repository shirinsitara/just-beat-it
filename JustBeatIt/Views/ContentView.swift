import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @StateObject private var viewModel = ECGViewModel()
    @State private var showImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {

                // Status line
                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Waveform
                if let data = viewModel.ecgData {
                    ECGWaveformView(samples: data.samples)
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .padding(.vertical, 6)
                } else {
                    ContentUnavailableView("No ECG Loaded", systemImage: "waveform.path.ecg", description: Text("Import a JSON/CSV file to view the signal."))
                        .frame(maxHeight: 320)
                }

                // Buttons
                HStack(spacing: 12) {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Load ECG File", systemImage: "doc")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        viewModel.loadDummyData()
                    } label: {
                        Label("Dummy", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Error display (if any)
                if let err = viewModel.lastErrorText {
                    Text("⚠️ \(err)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("ECG Explorer")
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [
                .json,
                .commaSeparatedText,
                .plainText
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                viewModel.loadFromFile(url: url)

            case .failure(let error):
                viewModel.lastErrorText = error.localizedDescription
                print("❌ Importer error:", error)
            }
        }
    }
}


#Preview {
    ContentView()
}
