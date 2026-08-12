import SwiftUI
import AutonomyKit

/// Dark-first, low-contrast-where-it-can-be, one accent. The visual goal is a
/// surface you can read at 6am without being sold anything.
enum Theme {
    static let background = Color(.sRGB, red: 0.05, green: 0.05, blue: 0.06, opacity: 1)
    static let card = Color(.sRGB, red: 0.10, green: 0.10, blue: 0.12, opacity: 1)
    static let primaryText = Color(.sRGB, red: 0.94, green: 0.94, blue: 0.95, opacity: 1)
    static let secondaryText = Color(.sRGB, red: 0.62, green: 0.63, blue: 0.66, opacity: 1)
    static let accent = Color(.sRGB, red: 0.55, green: 0.78, blue: 0.68, opacity: 1)
    static let warm = Color(.sRGB, red: 0.86, green: 0.72, blue: 0.45, opacity: 1)

    static func color(for band: ReadinessBand?) -> Color {
        switch band {
        case .ready: return accent
        case .steady: return primaryText
        case .gentle: return warm
        case nil: return secondaryText
        }
    }
}

struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.secondaryText)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.card)
            )
            .foregroundStyle(Theme.primaryText)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}
