import SwiftUI

extension Color {
    static let fireballBackground = Color(red: 0.027, green: 0.035, blue: 0.027)
    static let fireballPanel = Color(red: 0.063, green: 0.078, blue: 0.059)
    static let fireballRaised = Color(red: 0.094, green: 0.118, blue: 0.090)
    static let fireballGreen = Color(red: 0.72, green: 1.0, blue: 0.24)
    static let fireballOrange = Color(red: 1.0, green: 0.35, blue: 0.12)
    static let fireballCream = Color(red: 0.96, green: 0.95, blue: 0.91)
    static let fireballMuted = Color(red: 0.66, green: 0.70, blue: 0.65)
    static let fireballBorder = Color(red: 0.18, green: 0.22, blue: 0.18)
}

struct FireballPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.fireballPanel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.fireballBorder, lineWidth: 1)
            }
    }
}

extension View {
    func fireballPanel() -> some View {
        modifier(FireballPanelModifier())
    }
}

struct FireballSectionLabel: View {
    let title: String
    let index: String

    var body: some View {
        HStack(spacing: 10) {
            Text(index)
                .foregroundStyle(Color.fireballOrange)
            Rectangle()
                .fill(Color.fireballOrange)
                .frame(width: 18, height: 2)
            Text(title.uppercased())
                .foregroundStyle(Color.fireballMuted)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer()
        }
        .font(.caption.monospaced().weight(.bold))
        .accessibilityElement(children: .combine)
    }
}

struct FireballBrandMark: View {
    var size: CGFloat = 44

    var body: some View {
        Image("FireballMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct FireballTrajectory: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: -24, y: proxy.size.height * 0.92))
                path.addCurve(
                    to: CGPoint(x: proxy.size.width + 30, y: proxy.size.height * 0.08),
                    control1: CGPoint(x: proxy.size.width * 0.30, y: proxy.size.height * 0.82),
                    control2: CGPoint(x: proxy.size.width * 0.72, y: proxy.size.height * 0.24)
                )
            }
            .stroke(
                Color.fireballOrange.opacity(0.16),
                style: StrokeStyle(lineWidth: 1, dash: [7, 11])
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
