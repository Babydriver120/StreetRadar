import Foundation
import CoreLocation

/// GPS. Im Navigationsmodus laufen Updates auch weiter, wenn die App verlassen
/// oder das iPhone gesperrt wird (blaue Statusleisten-Anzeige wie bei Google Maps).
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorization: CLAuthorizationStatus

    /// Wird bei jedem neuen Standort aufgerufen – auch im Hintergrund.
    var onUpdate: ((CLLocation) -> Void)?

    private let manager = CLLocationManager()
    private var backgroundSession: CLBackgroundActivitySession?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.headingFilter = 5
    }

    func requestPermission() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func startNavigationMode(driving: Bool) {
        manager.activityType = driving ? .automotiveNavigation : .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        backgroundSession = CLBackgroundActivitySession()
        manager.startUpdatingLocation()
    }

    func stopNavigationMode() {
        backgroundSession?.invalidate()
        backgroundSession = nil
        manager.allowsBackgroundLocationUpdates = false
        manager.activityType = .other
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if authorization == .authorizedWhenInUse || authorization == .authorizedAlways {
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        location = last
        onUpdate?(last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Kurzzeitige Fehler (z. B. kein GPS-Fix) ignorieren – der Manager versucht es weiter.
    }
}
