import SwiftUI
import LearnCore

enum Theme {
    static let background = Color(hex: 0x171A19)
    static let sidebar = Color(hex: 0x111413)
    static let surface = Color(hex: 0x202422)
    static let raised = Color(hex: 0x292E2B)
    static let border = Color.white.opacity(0.075)
    static let text = Color(hex: 0xEEEFE7)
    static let muted = Color(hex: 0x9AA59D)
    static let accent = Color(hex: 0xEDAB72)
    static let green = Color(hex: 0xABD1AA)
    static let red = Color(hex: 0xF19A91)
    static func color(_ name: String) -> Color {
        switch name { case "blue": return Color(hex: 0x9DC3DC); case "purple": return Color(hex: 0xC4B0E3); case "green": return green; case "pink": return Color(hex: 0xE2AEC6); case "yellow": return Color(hex: 0xDEC77F); default: return accent }
    }
    static let colors = ["orange", "blue", "purple", "green", "pink", "yellow"]
    static let icons = ["books.vertical", "sparkles", "terminal", "chart.xyaxis.line", "brain.head.profile", "atom", "function", "globe.europe.africa", "leaf", "bolt", "building.columns", "heart.text.square"]
}

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255, opacity: 1) }
}

extension Int {
    func counted(_ singular: String, _ plural: String) -> String { "\(self) \(self == 1 ? singular : plural)" }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var color: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.sidebar)
            .padding(.horizontal, 17).padding(.vertical, 12).background(color.opacity(configuration.isPressed ? 0.75 : 1), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .opacity(isEnabled ? 1 : 0.4)
    }
}

struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(configuration.isPressed ? Theme.raised : Theme.surface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border))
            .opacity(isEnabled ? 1 : 0.4)
    }
}

struct IconBadge: View {
    let icon: String
    var color: Color = Theme.accent
    var size: CGFloat = 44
    var body: some View {
        Image(systemName: icon).font(.system(size: size * 0.43, weight: .medium)).foregroundStyle(color)
            .frame(width: size, height: size).background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: size * 0.27))
    }
}

struct Pill: View {
    let text: String
    var color: Color = Theme.muted
    var body: some View { Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 5).background(color.opacity(0.1), in: Capsule()) }
}

struct SectionHeading: View {
    let title: String
    var caption: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 19, weight: .semibold)).foregroundStyle(Theme.text)
            if let caption { Text(caption).font(.system(size: 12)).foregroundStyle(Theme.muted) }
            Spacer()
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 15) {
            IconBadge(icon: icon, size: 64)
            Text(title).font(.system(size: 23, weight: .semibold))
            Text(message).font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 420)
            if let actionTitle, let action { Button(actionTitle, action: action).buttonStyle(PrimaryButtonStyle()).padding(.top, 6) }
        }.padding(50).frame(maxWidth: .infinity, minHeight: 320)
    }
}

extension View {
    func panel(padding: CGFloat = 22) -> some View { self.padding(padding).background(Theme.surface, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border)) }
    func fieldStyle() -> some View { self.textFieldStyle(.plain).padding(12).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border)) }
}

struct SheetHeader: View {
    let title: String
    var subtitle: String = ""
    var close: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 23, weight: .semibold))
                if !subtitle.isEmpty { Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted) }
            }
            Spacer()
            Button(action: close) { Image(systemName: "xmark").frame(width: 28, height: 28).background(Theme.raised, in: Circle()) }.buttonStyle(.plain).help("Schließen")
        }
    }
}
