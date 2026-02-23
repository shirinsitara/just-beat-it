import SwiftUI

struct ECGScrubBar: View {
    @Binding var startTime: Double
    let totalDuration: Double
    let zoomSeconds: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let total = max(totalDuration, 0.000_001)
            let window = min(max(zoomSeconds, 0.000_001), total)
            let maxStart = max(0, total - window)

            // Thumb width represents visible fraction
            let thumbWidth = max(30, w * CGFloat(window / total))
            let trackWidth = max(0.000_001, w - thumbWidth)

            let progress = (maxStart > 0) ? (startTime / maxStart) : 0
            let thumbX = trackWidth * CGFloat(min(max(progress, 0), 1))

            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.25))
                Capsule()
                    .fill(.secondary.opacity(0.55))
                    .frame(width: thumbWidth)
                    .offset(x: thumbX)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard maxStart > 0 else { return }
                        let x = min(max(0, value.location.x - thumbWidth / 2), trackWidth)
                        let p = x / trackWidth
                        startTime = Double(p) * maxStart
                    }
            )
            .opacity(maxStart == 0 ? 0.35 : 1.0)
        }
        .frame(height: 10)
        .accessibilityLabel("ECG scrub bar")
    }
}
