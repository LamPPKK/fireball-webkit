import SwiftUI

extension Color {
    static let fireballBackground = Color(red: 0.035, green: 0.047, blue: 0.041)
    static let fireballPanel = Color(red: 0.065, green: 0.082, blue: 0.072)
    static let fireballRaised = Color(red: 0.095, green: 0.116, blue: 0.102)
    static let fireballGreen = Color(red: 0.40, green: 0.96, blue: 0.54)
    static let fireballOrange = Color(red: 0.96, green: 0.52, blue: 0.28)
    static let fireballMuted = Color(red: 0.66, green: 0.71, blue: 0.68)
}

struct FireballPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.fireballPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
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
                .foregroundStyle(Color.fireballGreen)
            Rectangle()
                .fill(Color.fireballGreen)
                .frame(width: 18, height: 2)
            Text(title.uppercased())
                .foregroundStyle(Color.fireballMuted)
            Spacer()
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .tracking(1.2)
        .accessibilityElement(children: .combine)
    }
}
