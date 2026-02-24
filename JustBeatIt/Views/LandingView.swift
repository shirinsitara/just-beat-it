import SwiftUI
import UniformTypeIdentifiers

struct LandingView: View {
    enum Route: Hashable {
        case explorer
    }

    @State private var path = NavigationPath()
    @State private var showImporter = false
    @State private var lastErrorText: String? = nil

    // If nil => dummy. If set => load file.
    @State private var pendingURL: URL? = nil

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.tint)

                Text("ECG Explorer")
                    .font(.largeTitle.bold())

                Text("Load a sample ECG or import your own file to explore beats and markers.\nEducational use only — not diagnostic.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        pendingURL = nil
                        path.append(Route.explorer)
                    } label: {
                        Label("Use Dummy Data", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Own Data", systemImage: "doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                if let err = lastErrorText {
                    Text("⚠️ \(err)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .explorer:
                    ECGExplorerView(entryURL: pendingURL)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json, .commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    pendingURL = url
                    path.append(Route.explorer)

                case .failure(let error):
                    lastErrorText = error.localizedDescription
                    print("❌ Importer error:", error)
                }
            }
        }
    }
}
