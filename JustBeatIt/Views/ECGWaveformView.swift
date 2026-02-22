import SwiftUI

struct ECGWaveformView: View {

    let samples: [Float]
    let color: Color
    let peakIndices: [Int]
    
    init(samples: [Float], peakIndices: [Int] = [], color: Color = .green){
        self.samples = samples
        self.peakIndices = peakIndices
        self.color = color
    }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard samples.count > 1 else { return }

                let width = size.width
                let height = size.height
                let midY = height / 2
                let stepX = width / CGFloat(samples.count - 1)

                // Auto scale: map max |sample| to ~40% of the view height
                let maxAbs = samples.map { abs($0) }.max() ?? 1
                let scale = (maxAbs > 0) ? (0.4 * height / CGFloat(maxAbs)) : 1
                
                //Wave path
                var path = Path()
                path.move(to: CGPoint(x: 0, y: midY - CGFloat(samples[0]) * scale))

                for i in 1..<samples.count {
                    let x = CGFloat(i) * stepX
                    let y = midY - CGFloat(samples[i]) * scale
                    path.addLine(to: CGPoint(x: x, y: y))
                }

                context.stroke(path, with: .color(color), lineWidth: 1.5)
                
                //Peak markers
                if !peakIndices.isEmpty {
                    for idx in peakIndices where idx>=0 && idx < samples.count {
                        let x = CGFloat(idx) * stepX
                        let y = midY - CGFloat(samples[idx]) * scale
                        
                        let dotRect = CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)
                        context.fill(Path(ellipseIn: dotRect), with: .color(.white))
                    }
                }
                
            }
        }
        .background(Color.black)
        .cornerRadius(12)
        .padding()
    }
}
