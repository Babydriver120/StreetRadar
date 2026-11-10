import SwiftUI
import MapKit

struct SearchHeader: View {
    @ObservedObject var model: AppModel
    @ObservedObject var search: SearchService
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                TextField("", text: $search.query,
                          prompt: Text("ORT ODER ADRESSE SUCHEN").foregroundColor(.white.opacity(0.45)))
                    .font(Theme.hud(19, .bold))
                    .foregroundStyle(.white)
                    .tint(Theme.gold)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit {
                        focused = false
                        model.runSearch(text: search.query)
                    }
                if !search.query.isEmpty || model.phase == .results {
                    Button {
                        focused = false
                        model.closeResults()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .hudPanel()

            if focused && !search.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(search.suggestions.prefix(6).enumerated()), id: \.offset) { _, s in
                        Button {
                            focused = false
                            model.runSearch(completion: s)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(Theme.gold)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.title).font(Theme.hud(17, .bold)).foregroundStyle(.white).lineLimit(1)
                                    if !s.subtitle.isEmpty {
                                        Text(s.subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    }
                }
                .hudPanel()
            } else if model.phase == .browse || model.phase == .results {
                CategoryChips(model: model)
            }
        }
        .padding(.horizontal, 12)
    }
}

struct CategoryChips: View {
    struct Category: Identifiable {
        let key: String
        let label: String
        let query: String
        var id: String { key }
    }

    static let items: [Category] = [
        Category(key: "fuel", label: "TANKSTELLEN", query: "Tankstelle"),
        Category(key: "restaurant", label: "ESSEN", query: "Restaurant"),
        Category(key: "grocery", label: "SUPERMÄRKTE", query: "Supermarkt"),
        Category(key: "cafe", label: "CAFÉS", query: "Café"),
        Category(key: "bank", label: "GELDAUTOMATEN", query: "Geldautomat"),
        Category(key: "clothing_store", label: "KLEIDUNG", query: "Bekleidungsgeschäft"),
        Category(key: "pharmacy", label: "APOTHEKEN", query: "Apotheke"),
        Category(key: "lodging", label: "HOTELS", query: "Hotel"),
        Category(key: "parking", label: "PARKEN", query: "Parkplatz"),
        Category(key: "car", label: "WERKSTÄTTEN", query: "Autowerkstatt"),
    ]

    let model: AppModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.items) { item in
                    Button {
                        model.runCategory(item.query, blip: item.key)
                    } label: {
                        HStack(spacing: 6) {
                            BlipImage(key: item.key, size: 22)
                            Text(item.label).font(Theme.hud(14)).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .hudPanel()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ResultsPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(model.results.count) ERGEBNISSE")
                .font(Theme.hud(16))
                .foregroundStyle(Theme.gold)
                .padding(14)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.results) { place in
                        Button { model.select(place) } label: {
                            HStack(spacing: 12) {
                                BlipImage(key: place.blip, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name).font(Theme.hud(17, .bold)).foregroundStyle(.white).lineLimit(1)
                                    if !place.subtitle.isEmpty {
                                        Text(place.subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                                if let d = model.distanceText(to: place) {
                                    Text(d).font(Theme.hud(14, .bold)).foregroundStyle(Theme.gold)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .hudPanel()
        .padding(.horizontal, 12)
    }
}

struct PlacePanel: View {
    @ObservedObject var model: AppModel
    let place: Place

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                BlipImage(key: place.blip, size: 42)
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name.uppercased())
                        .font(Theme.hud(25, .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if !place.subtitle.isEmpty {
                        Text(place.subtitle).font(.system(size: 13)).foregroundStyle(.white.opacity(0.65)).lineLimit(2)
                    }
                    if let d = model.distanceText(to: place) {
                        Text(d).font(Theme.hud(15, .bold)).foregroundStyle(Theme.gold)
                    }
                }
                Spacer(minLength: 0)
                CloseButton { model.clearSelection() }
            }

            HStack(spacing: 8) {
                Button { model.requestRoutes() } label: {
                    if model.isLoadingRoute {
                        ProgressView().tint(.black).frame(maxWidth: .infinity, minHeight: 50).background(Theme.gold)
                    } else {
                        HUDButtonLabel(title: "ROUTE", icon: "arrow.triangle.turn.up.right.diamond.fill", primary: true)
                    }
                }
                .buttonStyle(.plain)

                if let phone = place.mapItem.phoneNumber,
                   let url = URL(string: "tel:" + phone.filter { "+0123456789".contains($0) }) {
                    Link(destination: url) { HUDButtonLabel(icon: "phone.fill") }
                }
                if let url = place.mapItem.url {
                    Link(destination: url) { HUDButtonLabel(icon: "safari.fill") }
                }
                ShareLink(item: place.shareURL) { HUDButtonLabel(icon: "square.and.arrow.up") }
            }
        }
        .padding(16)
        .hudPanel()
        .padding(.horizontal, 12)
    }
}

struct RoutePreviewPanel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TransportTab(icon: "car.fill", title: "AUTO", active: model.transport == .automobile) {
                    model.setTransport(.automobile)
                }
                TransportTab(icon: "figure.walk", title: "ZU FUSS", active: model.transport == .walking) {
                    model.setTransport(.walking)
                }
                Spacer()
                CloseButton { model.backToPlace() }
            }

            if model.isLoadingRoute {
                ProgressView().tint(Theme.gold).frame(maxWidth: .infinity)
            }

            ForEach(Array(model.routes.enumerated()), id: \.offset) { i, route in
                let active = i == model.selectedRoute
                Button { model.selectRoute(i) } label: {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Fmt.duration(route.expectedTravelTime))
                                .font(Theme.hud(26, .black))
                                .foregroundStyle(active ? Theme.gold : Color.white)
                            Text(route.name.isEmpty ? Fmt.distance(route.distance) : "\(Fmt.distance(route.distance)) · \(route.name)")
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                        Spacer()
                        if i == 0 {
                            Text("SCHNELLSTE")
                                .font(Theme.hud(12))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Theme.gold)
                        }
                    }
                    .padding(10)
                    .background(active ? Color.white.opacity(0.08) : Color.clear)
                    .overlay(alignment: .leading) {
                        if active { Rectangle().fill(Theme.waypoint).frame(width: 4) }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Button { model.startNavigation() } label: {
                HUDButtonLabel(title: "LOS", icon: "location.north.fill", primary: true)
            }
            .buttonStyle(.plain)
            .disabled(model.routes.isEmpty)
        }
        .padding(16)
        .hudPanel()
        .padding(.horizontal, 12)
    }
}

struct TransportTab: View {
    let icon: String
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .heavy))
                Text(title).font(Theme.hud(15))
            }
            .foregroundStyle(active ? Color.black : Color.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(active ? Theme.gold : Color.white.opacity(0.1))
        }
        .buttonStyle(.plain)
    }
}
