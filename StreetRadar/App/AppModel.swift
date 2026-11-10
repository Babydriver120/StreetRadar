import SwiftUI
import MapKit
import Combine

enum Phase {
    case browse, results, place, preview, navigating
}

struct CameraRequest {
    enum Kind {
        case center(CLLocationCoordinate2D, Double)
        case fit([CLLocationCoordinate2D])
        case follow
        case navigate
    }
    let id = UUID()
    let kind: Kind
}

struct RouteOverlay {
    var id = UUID()
    var main: [CLLocationCoordinate2D] = []
    var alternates: [[CLLocationCoordinate2D]] = []
}

struct MarkerOverlay {
    var id = UUID()
    var results: [Place] = []
    var pin: Place?
}

/// Zentraler App-Zustand: verbindet Karte, Suche, GPS und Navigation.
/// Alle Aufrufe erfolgen auf dem Main-Thread (MapKit/CoreLocation liefern dort).
final class AppModel: ObservableObject {
    let location = LocationService()
    let search = SearchService()
    let nav = NavigationEngine()

    @Published var phase: Phase = .browse
    @Published var results: [Place] = []
    @Published var selected: Place?
    @Published var routes: [MKRoute] = []
    @Published var selectedRoute = 0
    @Published var transport: MKDirectionsTransportType = .automobile
    @Published var isLoadingRoute = false
    @Published var errorText: String?
    @Published var arrived: String?
    @Published var isFollowing = true
    @Published private(set) var camera: CameraRequest?
    @Published private(set) var routeOverlay = RouteOverlay()
    @Published private(set) var markers = MarkerOverlay()

    private(set) var visibleRegion: MKCoordinateRegion?
    private let geocoder = CLGeocoder()
    private var bag = Set<AnyCancellable>()

    init() {
        // Änderungen der Unter-Objekte an die Oberfläche weiterreichen
        for publisher in [location.objectWillChange, nav.objectWillChange, search.objectWillChange] {
            publisher.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &bag)
        }
        location.onUpdate = { [weak self] loc in
            self?.nav.update(location: loc)
        }
        nav.onRouteChanged = { [weak self] in
            self?.refreshRoute()
        }
        nav.onArrive = { [weak self] name in
            guard let self else { return }
            self.arrived = name
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                self.arrived = nil
                self.endNavigation()
            }
        }
    }

    // MARK: Karte

    func updateVisibleRegion(_ region: MKCoordinateRegion) {
        visibleRegion = region
        search.setRegion(region)
    }

    func recenter() {
        camera = CameraRequest(kind: phase == .navigating ? .navigate : .follow)
    }

    func distanceText(to place: Place) -> String? {
        guard let loc = location.location else { return nil }
        let d = loc.distance(from: CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude))
        return Fmt.distance(d)
    }

    // MARK: Suche

    func runSearch(completion: MKLocalSearchCompletion) {
        search.query = completion.title
        search.resolve(completion, region: visibleRegion) { [weak self] items in
            self?.showResults(items.map { Place(mapItem: $0) })
        }
    }

    func runSearch(text: String) {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        search.search(text: q, region: visibleRegion) { [weak self] items in
            self?.showResults(items.map { Place(mapItem: $0) })
        }
    }

    func runCategory(_ query: String, blip: String) {
        search.query = ""
        search.search(text: query, region: visibleRegion) { [weak self] items in
            self?.showResults(items.map { Place(mapItem: $0, fallbackBlip: blip) }, forceList: true)
        }
    }

    private func showResults(_ places: [Place], forceList: Bool = false) {
        guard !places.isEmpty else {
            flash("Nichts gefunden")
            return
        }
        if places.count == 1 && !forceList {
            results = []
            select(places[0])
            return
        }
        results = places
        selected = nil
        routes = []
        phase = .results
        refreshMarkers()
        refreshRoute()
        camera = CameraRequest(kind: .fit(places.map(\.coordinate)))
    }

    func closeResults() {
        search.query = ""
        results = []
        clearSelection()
    }

    // MARK: Auswahl

    func select(_ place: Place, moveCamera: Bool = true) {
        selected = place
        routes = []
        phase = .place
        refreshMarkers()
        refreshRoute()
        if moveCamera {
            camera = CameraRequest(kind: .center(place.coordinate, 16))
        }
    }

    func selectPOI(name: String, blip: String, coordinate: CLLocationCoordinate2D) {
        let provisional = Place(name: name, subtitle: "", coordinate: coordinate, blip: blip)
        select(provisional, moveCamera: false)
        search.lookup(name: name, near: coordinate) { [weak self] item in
            guard let self, let item, self.selected?.id == provisional.id, self.phase == .place else { return }
            var detailed = Place(mapItem: item, fallbackBlip: blip)
            detailed.blip = blip
            self.selected = detailed
            self.refreshMarkers()
        }
    }

    /// Langes Drücken auf die Karte setzt einen Wegpunkt.
    func dropWaypoint(at c: CLLocationCoordinate2D) {
        let p = Place(name: "Wegpunkt", subtitle: "Adresse wird ermittelt …", coordinate: c, blip: "waypoint")
        select(p, moveCamera: false)
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(CLLocation(latitude: c.latitude, longitude: c.longitude)) { [weak self] marks, _ in
            guard let self, self.selected?.id == p.id else { return }
            var updated = p
            if let m = marks?.first {
                let street = [m.thoroughfare, m.subThoroughfare].compactMap { $0 }.joined(separator: " ")
                let city = [m.postalCode, m.locality].compactMap { $0 }.joined(separator: " ")
                updated.subtitle = [street, city].filter { !$0.isEmpty }.joined(separator: ", ")
            } else {
                updated.subtitle = String(format: "%.5f, %.5f", c.latitude, c.longitude)
            }
            self.selected = updated
        }
    }

    func clearSelection() {
        selected = nil
        routes = []
        phase = results.isEmpty ? .browse : .results
        refreshMarkers()
        refreshRoute()
    }

    // MARK: Routen

    func requestRoutes() {
        guard let dest = selected else { return }
        guard let from = location.location else {
            flash("Standort nicht verfügbar")
            return
        }
        isLoadingRoute = true
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: from.coordinate))
        req.destination = dest.mapItem
        req.transportType = transport
        req.requestsAlternateRoutes = true
        MKDirections(request: req).calculate { [weak self] resp, _ in
            guard let self else { return }
            self.isLoadingRoute = false
            guard let found = resp?.routes, !found.isEmpty else {
                self.flash("Keine Route gefunden")
                return
            }
            self.routes = found.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
            self.selectedRoute = 0
            self.phase = .preview
            self.refreshRoute()
            self.camera = CameraRequest(kind: .fit(self.routes[0].polyline.coordinates))
        }
    }

    func setTransport(_ t: MKDirectionsTransportType) {
        guard t != transport else { return }
        transport = t
        requestRoutes()
    }

    func selectRoute(_ i: Int) {
        guard routes.indices.contains(i) else { return }
        selectedRoute = i
        refreshRoute()
    }

    func backToPlace() {
        routes = []
        phase = selected == nil ? .browse : .place
        refreshRoute()
    }

    // MARK: Navigation

    func startNavigation() {
        guard routes.indices.contains(selectedRoute), let dest = selected else { return }
        nav.start(route: routes[selectedRoute], destination: dest.mapItem, name: dest.name, transport: transport)
        location.startNavigationMode(driving: transport == .automobile)
        results = []
        phase = .navigating
        refreshMarkers()
        refreshRoute()
        camera = CameraRequest(kind: .navigate)
    }

    func endNavigation() {
        guard phase == .navigating else { return }
        nav.stop()
        location.stopNavigationMode()
        selected = nil
        routes = []
        phase = .browse
        refreshMarkers()
        refreshRoute()
        camera = CameraRequest(kind: .follow)
    }

    // MARK: Overlays

    private func refreshRoute() {
        if phase == .navigating, let r = nav.route {
            routeOverlay = RouteOverlay(main: r.polyline.coordinates)
        } else if phase == .preview, routes.indices.contains(selectedRoute) {
            let alts = routes.indices.filter { $0 != selectedRoute }.map { routes[$0].polyline.coordinates }
            routeOverlay = RouteOverlay(main: routes[selectedRoute].polyline.coordinates, alternates: alts)
        } else {
            routeOverlay = RouteOverlay()
        }
    }

    private func refreshMarkers() {
        markers = MarkerOverlay(results: results, pin: selected)
    }

    private func flash(_ text: String) {
        errorText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.errorText == text { self?.errorText = nil }
        }
    }
}
