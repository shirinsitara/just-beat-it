import SwiftUI

struct ECGWaveformView: View {

    let samples: [Float]
    let color: Color
    let peakIndices: [Int]
    let windows: [BeatWindow]
    
    init(samples: [Float],color: Color = .green, peakIndices: [Int] = [], windows: [BeatWindow] = []){
        self.samples = samples
        self.peakIndices = peakIndices
        self.color = color
        self.windows = windows
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
                
                // 1) Draw beat window rectangles (behind signal)
                if !windows.isEmpty {
                    for w in windows where w.startIndex >= 0 && w.endIndex <= samples.count {
                        let x1 = CGFloat(w.startIndex) * stepX
                        let x2 = CGFloat(w.endIndex) * stepX
                        let rect = CGRect(x: x1, y: 6, width: max(1, x2 - x1), height: height - 12)

                        // translucent fill
                        context.fill(Path(rect), with: .color(Color.blue.opacity(0.08)))
                        // stroke border
                        context.stroke(Path(rect), with: .color(Color.blue.opacity(0.35)), lineWidth: 1)
                    }
                }
                
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
