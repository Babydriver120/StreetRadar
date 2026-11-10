import SwiftUI

/// Oben: nächstes Manöver
struct NavBanner: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let nav = model.nav
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: Fmt.maneuverSymbol(nav.nextInstruction))
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Fmt.distance(nav.distanceToManeuver))
                        .font(Theme.hud(34, .black))
                        .foregroundStyle(.white)
                    Text(nav.nextInstruction.uppercased())
                        .font(Theme.hud(18, .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Theme.panel)
            .overlay(alignment: .leading) { Rectangle().fill(Theme.waypoint).frame(width: 5) }

            if nav.isRerouting {
                Label("ROUTE WIRD NEU BERECHNET …", systemImage: "arrow.triangle.2.circlepath")
                    .font(Theme.hud(15))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.gold)
            } else if let then = nav.thenInstruction {
                HStack(spacing: 8) {
                    Text("DANACH").font(Theme.hud(14)).foregroundStyle(Theme.gold)
                    Image(systemName: Fmt.maneuverSymbol(then)).font(.system(size: 14, weight: .heavy))
                    Text(then.uppercased()).font(Theme.hud(14, .bold)).lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.9))
            }
        }
        .padding(.horizontal, 12)
    }
}

/// Unten: Radar-Minikarte links, Ankunft/Restzeit rechts
struct NavBottom: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let nav = model.nav
        HStack(alignment: .bottom, spacing: 10) {
            RadarView(model: model)

            VStack(alignment: .trailing, spacing: 8) {
                if !model.isFollowing {
                    Button { model.recenter() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.north.fill")
                            Text("ZENTRIEREN").font(Theme.hud(15))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(height: 38)
                        .hudPanel()
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(Fmt.clock(Date().addingTimeInterval(nav.remainingTime)))
                        .font(Theme.hud(32, .black))
                        .foregroundStyle(Theme.gold)
                    Text("\(Fmt.duration(nav.remainingTime)) · \(Fmt.distance(nav.remainingDistance))")
                        .font(Theme.hud(15, .bold))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Button { model.nav.voiceEnabled.toggle() } label: {
                            HUDButtonLabel(icon: nav.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        }
                        .buttonStyle(.plain)
                        Button { model.endNavigation() } label: {
                            HUDButtonLabel(title: "BEENDEN", icon: "xmark", tint: Theme.danger)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .hudPanel()
            }
        }
        .padding(.horizontal, 12)
    }
}

/// Kleine, mitdrehende Karte mit zwei Balken darunter
/// (grün = Akku, blau = Fortschritt der Route) und Tempo-Anzeige.
struct RadarView: View {
    @ObservedObject var model: AppModel
    @State private var battery: Float = -1

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topLeading) {
                MapContainer(model: model, isRadar: true)
                    .frame(width: 150, height: 106)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text("\(Int(model.nav.speedKmh.rounded())) KM/H")
                    .font(Theme.hud(13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.black.opacity(0.65))
                    .padding(5)
            }
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 3))

            HStack(spacing: 3) {
                HUDBar(value: battery < 0 ? 1 : Double(battery), color: Theme.health)
                    .frame(width: 96)
                HUDBar(value: model.nav.progress, color: Theme.armor)
            }
            .frame(width: 150, height: 7)
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            battery = UIDevice.current.batteryLevel
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            battery = UIDevice.current.batteryLevel
        }
    }
}

struct HUDBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(color.opacity(0.3))
                Rectangle().fill(color).frame(width: g.size.width * min(max(value, 0), 1))
            }
        }
        .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
    }
}

/// Großes Einblend-Banner bei Ankunft
struct ArrivalBanner: View {
    let name: String

    var body: some View {
        VStack(spacing: 6) {
            Text("ZIEL ERREICHT")
                .font(Theme.hud(46, .black))
                .foregroundStyle(Theme.gold)
                .shadow(color: .black, radius: 0, x: 2, y: 2)
            Text(name.uppercased())
                .font(Theme.hud(18, .bold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(
            LinearGradient(colors: [.clear, Color.black.opacity(0.8), Color.black.opacity(0.8), .clear],
                           startPoint: .leading, endPoint: .trailing)
        )
        .allowsHitTesting(false)
    }
}
