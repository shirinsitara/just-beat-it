import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel = ECGViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                Text("ECG Explorer")
                    .font(.title)
                    .bold()
                
                if let data = viewModel.ecgData {
                    ECGWaveformView(samples: data.samples)
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .padding()
                        .background(Color.black.opacity(0.9))
                        .cornerRadius(16)

                } else {
                    ProgressView()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}

#Preview {
    ContentView()
}
