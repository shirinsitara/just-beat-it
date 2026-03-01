import SwiftUI

struct ECGWaveformView: View {

    let samples: [Float]
    let color: Color
    let peakIndices: [Int]
    let windowSpans: [WindowSpan]
    let beatLabels: [(index: Int, number: Int)]
    let highlightedBeatNumber: Int?
    let showBeatLabels: Bool?
    let fixedMaxAbs: Float?
    let verticalFill: CGFloat

    // Grid + styling
    var showGrid: Bool = true
    var gridStyle: GridStyle = .darkGreen

    init(
        samples: [Float],
        color: Color = .green,
        peakIndices: [Int] = [],
        windowSpans: [WindowSpan] = [],
        beatLabels: [(index: Int, number: Int)] = [],
        highlightedBeatNumber: Int? = nil,
        showBeatLabels: Bool? = false,
        showGrid: Bool = true,
        gridStyle: GridStyle = .darkGreen,
        fixedMaxAbs: Float? = nil,
        verticalFill: CGFloat = 0.4,
    ) {
        self.samples = samples
        self.peakIndices = peakIndices
        self.color = color
        self.windowSpans = windowSpans
        self.beatLabels = beatLabels
        self.highlightedBeatNumber = highlightedBeatNumber
        self.showBeatLabels = showBeatLabels
        self.showGrid = showGrid
        self.gridStyle = gridStyle
        self.fixedMaxAbs = fixedMaxAbs
        self.verticalFill = verticalFill
    }
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                guard samples.count > 1 else { return }

                let width = size.width
                let height = size.height
                let midY = height / 2
                let stepX = width / CGFloat(samples.count - 1)

                // Auto scale
                let localMaxAbs = samples.map { abs($0) }.max() ?? 1
                let usedMaxAbs = CGFloat(fixedMaxAbs ?? localMaxAbs)
                let scale = (usedMaxAbs > 0) ? (verticalFill * height / usedMaxAbs) : 1

                // 0) Grid (behind everything)
                if showGrid {
                    drawECGGrid(context: &context, size: size, style: gridStyle)
                }

                // 0.5) Center baseline (slightly stronger, ECG feel)
                drawBaseline(context: &context, size: size, midY: midY, style: gridStyle)

                // 1) Beat windows - colour coded
                for w in windowSpans {
                    let x1 = CGFloat(w.startIndex) * stepX
                    let x2 = CGFloat(w.endIndex) * stepX

                    let rect = CGRect(
                        x: x1,
                        y: 6,
                        width: max(1, x2 - x1),
                        height: height - 12
                    )

                    let isSelected = (highlightedBeatNumber != nil && w.beatNumber == highlightedBeatNumber!)

                    if isSelected {
                        // Selected beat: slightly stronger fill
                        context.fill(Path(rect), with: .color(windowFill(w.NNLabels).opacity(1.2)))
                        context.stroke(
                            Path(rect.insetBy(dx: 0.8, dy: 0.8)),
                            with: .color(Color.pink.opacity(0.55)),
                            lineWidth: 1.2)
                            
                            // show beat class labels
                            if showBeatLabels ?? false, let lbl = w.NNLabels {
                                let textColor: Color
                                switch lbl {
                                case "PVC": textColor = .red
                                case "N": textColor = .green
                                case "Other": textColor = .orange
                                default: textColor = .white
                                }

                                // Place at top-right INSIDE the window
                                let padX: CGFloat = 6
                                let padY: CGFloat = 10
                                let labelX = rect.maxX - padX
                                let labelY = rect.minY + padY

                                let tag = Text(lbl == "Other" ? "O" : lbl)
                                    .font(.caption2.bold())
                                    .foregroundColor(textColor.opacity(0.95))

                                context.draw(tag, at: CGPoint(x: labelX, y: labelY), anchor: .trailing)
                            }
                    } else {
                        // Non-selected beats: very light fill
                        context.fill(Path(rect), with: .color(windowFill(w.NNLabels)))
                    }
                }

                // 2) Wave path
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: midY - CGFloat(samples[0]) * scale))
                for i in 1..<samples.count {
                    let x = CGFloat(i) * stepX
                    let y = midY - CGFloat(samples[i]) * scale
                    wave.addLine(to: CGPoint(x: x, y: y))
                }
                
                // glow style
                let glowStyle = StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round)
                let mainStyle = StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)

                context.stroke(wave, with: .color(color.opacity(0.18)), style: glowStyle)
                context.stroke(wave, with: .color(color.opacity(0.95)), style: mainStyle)


                // 3) Peak markers (white dots)
                if !peakIndices.isEmpty {
                    for idx in peakIndices where idx >= 0 && idx < samples.count {
                        let x = CGFloat(idx) * stepX
                        let y = midY - CGFloat(samples[idx]) * scale
                        let dotRect = CGRect(x: x - 2.6, y: y - 2.6, width: 5.2, height: 5.2)
                        context.fill(Path(ellipseIn: dotRect), with: .color(.white))
                    }
                }

                // 4) Beat labels - numbers
                if showBeatLabels ?? false {
                    for label in beatLabels {
                        let x = CGFloat(label.index) * stepX
                        let text = Text("\(label.number)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.9))
                        context.draw(text, at: CGPoint(x: x, y: 14), anchor: .center)
                    }
                }
            }
        }
        .background(gridStyle.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding()
    }
}

// MARK: - Grid styling

enum GridStyle {
    case darkGreen

    var backgroundColor: Color {
        Color.black
    }

    var smallLine: Color {
        Color.green.opacity(0.10)
    }

    var largeLine: Color {
        Color.green.opacity(0.22)
    }

    var baseline: Color {
        // Slightly stronger than large grid
        Color.green.opacity(0.35)
    }
}

// MARK: - Grid drawing helpers

private func drawECGGrid(context: inout GraphicsContext, size: CGSize, style: GridStyle) {
    // Visual grid size (in points). Looks like ECG paper; not physically calibrated.
    let small: CGFloat = 10          // small box
    let big: CGFloat = small * 5     // large box

    // Small grid lines
    var smallPath = Path()
    var x: CGFloat = 0
    while x <= size.width {
        smallPath.move(to: CGPoint(x: x, y: 0))
        smallPath.addLine(to: CGPoint(x: x, y: size.height))
        x += small
    }
    var y: CGFloat = 0
    while y <= size.height {
        smallPath.move(to: CGPoint(x: 0, y: y))
        smallPath.addLine(to: CGPoint(x: size.width, y: y))
        y += small
    }
    context.stroke(smallPath, with: .color(style.smallLine), lineWidth: 0.6)

    // Large grid lines
    var bigPath = Path()
    x = 0
    while x <= size.width {
        bigPath.move(to: CGPoint(x: x, y: 0))
        bigPath.addLine(to: CGPoint(x: x, y: size.height))
        x += big
    }
    y = 0
    while y <= size.height {
        bigPath.move(to: CGPoint(x: 0, y: y))
        bigPath.addLine(to: CGPoint(x: size.width, y: y))
        y += big
    }
    context.stroke(bigPath, with: .color(style.largeLine), lineWidth: 1.0)
}

private func drawBaseline(context: inout GraphicsContext, size: CGSize, midY: CGFloat, style: GridStyle) {
    var baseline = Path()
    baseline.move(to: CGPoint(x: 0, y: midY))
    baseline.addLine(to: CGPoint(x: size.width, y: midY))

    // Slightly thicker + stronger opacity than grid
    context.stroke(baseline, with: .color(style.baseline), lineWidth: 1.4)
}

func windowFill(_ label: String?) -> Color {
    switch label {
    case "PVC": return Color.red.opacity(0.14)
    case "N": return Color.green.opacity(0.10)
    case "Other": return Color.orange.opacity(0.12)
    default: return Color.cyan.opacity(0.06)
    }
}
