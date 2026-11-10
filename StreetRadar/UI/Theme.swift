import SwiftUI

/// Spiele-HUD-Look: dunkle, kantige Panels, fette schmale Großbuchstaben,
/// Gold für Highlights, Lila für die Route.
enum Theme {
    static let panel = Color.black.opacity(0.78)
    static let panelStroke = Color.white.opacity(0.08)
    static let gold = Color(red: 0.95, green: 0.78, blue: 0.31)
    static let waypoint = Color(red: 0.66, green: 0.33, blue: 0.97)
    static let health = Color(red: 0.36, green: 0.69, blue: 0.29)
    static let armor = Color(red: 0.29, green: 0.56, blue: 0.85)
    static let danger = Color(red: 0.80, green: 0.18, blue: 0.16)
    static let routeUI = UIColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1)

    static func hud(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }
}

extension View {
    func hudPanel() -> some View {
        background(Theme.panel)
            .overlay(Rectangle().stroke(Theme.panelStroke, lineWidth: 1))
    }
}

struct HUDButtonLabel: View {
    var title: String? = nil
    var icon: String
    var primary = false
    var tint: Color? = nil

    var body: some View {
        let label = HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 16, weight: .heavy))
            if let title { Text(title).font(Theme.hud(19)) }
        }
        .foregroundStyle(primary ? Color.black : Color.white)

        if title == nil {
            label.frame(width: 50, height: 50).background(tint ?? Color.white.opacity(0.1))
        } else {
            label.frame(maxWidth: .infinity, minHeight: 50).background(tint ?? (primary ? Theme.gold : Color.white.opacity(0.1)))
        }
    }
}

struct MapRoundButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .hudPanel()
        }
        .buttonStyle(.plain)
    }
}

struct CloseButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.1))
        }
        .buttonStyle(.plain)
    }
}

struct BlipImage: View {
    let key: String
    var size: CGFloat = 24
    var body: some View {
        Image(uiImage: Blips.image(named: "blip-" + key) ?? UIImage())
            .resizable()
            .frame(width: size, height: size)
    }
}
