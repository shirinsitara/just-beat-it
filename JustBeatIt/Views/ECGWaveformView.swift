import SwiftUI

struct ECGWaveformView: View {
    
    let samples: [Float]
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                
                guard samples.count > 1 else { return }
                
                let path = Path { path in
                    
                    let width = size.width
                    let height = size.height
                    
                    let stepX = width / CGFloat(samples.count - 1)
                    
                    let midY = height / 2
                    
                    path.move(to: CGPoint(x: 0, y: midY))
                    
                    for i in samples.indices {
                        let x = CGFloat(i) * stepX
                        let y = midY - CGFloat(samples[i]) * height * 0.4
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                
                context.stroke(path, with: .color(.green), lineWidth: 1.5)
            }
        }
        .background(Color.black)
        .cornerRadius(12)
        .padding()
    }
}
