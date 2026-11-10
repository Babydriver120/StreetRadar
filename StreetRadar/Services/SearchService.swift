import Foundation
import MapKit

/// Suche mit Autovervollständigung (Apple MapKit – kostenlos, keine API-Keys).
final class SearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                completer.cancel()
                suggestions = []
            } else {
                completer.queryFragment = query
            }
        }
    }
    @Published private(set) var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private var active: MKLocalSearch?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func setRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    func resolve(_ completion: MKLocalSearchCompletion, region: MKCoordinateRegion?,
                 done: @escaping ([MKMapItem]) -> Void) {
        let req = MKLocalSearch.Request(completion: completion)
        if let region { req.region = region }
        run(req, done: done)
    }

    func search(text: String, region: MKCoordinateRegion?, done: @escaping ([MKMapItem]) -> Void) {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = text
        req.resultTypes = [.pointOfInterest, .address]
        if let region { req.region = region }
        run(req, done: done)
    }

    /// Findet zu einem auf der Karte angetippten POI die Apple-Daten (Adresse, Telefon, Website).
    func lookup(name: String, near c: CLLocationCoordinate2D, done: @escaping (MKMapItem?) -> Void) {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = name
        req.region = MKCoordinateRegion(center: c, latitudinalMeters: 500, longitudinalMeters: 500)
        req.resultTypes = .pointOfInterest
        let target = CLLocation(latitude: c.latitude, longitude: c.longitude)
        MKLocalSearch(request: req).start { resp, _ in
            let best = resp?.mapItems.min {
                (target.distance(from: $0.placemark.location ?? target)) < (target.distance(from: $1.placemark.location ?? target))
            }
            if let best, let loc = best.placemark.location, loc.distance(from: target) < 150 {
                done(best)
            } else {
                done(nil)
            }
        }
    }

    private func run(_ req: MKLocalSearch.Request, done: @escaping ([MKMapItem]) -> Void) {
        active?.cancel()
        let search = MKLocalSearch(request: req)
        active = search
        search.start { [weak self] resp, _ in
            guard let self, search === self.active else { return }   // überholte Suche ignorieren
            done(resp?.mapItems ?? [])
        }
    }

    // MARK: MKLocalSearchCompleterDelegate

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
