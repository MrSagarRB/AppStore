import SwiftUI

struct Card<Content: View>: View {
    let title: String
    let symbol: String
    var value: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let value {
                    Text(value).font(.title3.weight(.semibold)).monospacedDigit()
                }
            }
            content
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var tint: Color?

    var body: some View {
        HStack(spacing: 6) {
            if let tint { Circle().fill(tint).frame(width: 8, height: 8) }
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.callout)
    }
}

/// A right-aligned line chart; older samples scroll off the left edge.
struct Sparkline: View {
    let values: [Double]
    var maxValue: Double?
    var color: Color = .accentColor
    var filled = true

    var body: some View {
        GeometryReader { geo in
            let ceiling = max(maxValue ?? values.max() ?? 1, 0.0001)
            let step = geo.size.width / CGFloat(SystemMonitor.historyLength - 1)
            let offset = SystemMonitor.historyLength - values.count
            let points = values.enumerated().map { i, v in
                CGPoint(x: CGFloat(i + offset) * step,
                        y: geo.size.height * (1 - CGFloat(min(v / ceiling, 1))))
            }
            ZStack {
                if filled, let first = points.first, let last = points.last {
                    Path { p in
                        p.move(to: CGPoint(x: first.x, y: geo.size.height))
                        points.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                    }
                    .fill(color.opacity(0.18))
                }
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    points.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
        }
    }
}

struct Pill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

func loadColor(_ fraction: Double) -> Color {
    switch fraction {
    case ..<0.6: .green
    case ..<0.85: .orange
    default: .red
    }
}
