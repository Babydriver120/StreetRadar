import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        ZStack {
            MapContainer(model: model)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                if model.phase == .navigating {
                    NavBanner(model: model)
                } else {
                    SearchHeader(model: model, search: model.search)
                }

                if let err = model.errorText {
                    Text(err.uppercased())
                        .font(Theme.hud(15, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .hudPanel()
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
                bottom
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
            .ignoresSafeArea(.keyboard)

            if let name = model.arrived {
                ArrivalBanner(name: name)
                    .transition(.opacity.combined(with: .scale(scale: 1.15)))
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.2), value: model.phase)
        .animation(.easeOut(duration: 0.35), value: model.arrived)
        .onAppear { model.location.requestPermission() }
    }

    @ViewBuilder
    private var bottom: some View {
        if model.phase == .navigating {
            NavBottom(model: model)
        } else {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    MapRoundButton(icon: model.isFollowing ? "location.fill" : "location") { model.recenter() }
                }
                .padding(.horizontal, 12)

                switch model.phase {
                case .results:
                    ResultsPanel(model: model)
                case .place:
                    if let place = model.selected { PlacePanel(model: model, place: place) }
                case .preview:
                    RoutePreviewPanel(model: model)
                default:
                    EmptyView()
                }
            }
        }
    }
}
