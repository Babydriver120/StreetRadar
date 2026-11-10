import Foundation
import MapKit
import AVFoundation

/// Turn-by-Turn-Navigation mit Sprachansagen, Neuberechnung bei Abweichung
/// und Ankunftserkennung. Läuft auch im Hintergrund weiter (getrieben von LocationService).
final class NavigationEngine: NSObject, ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var route: MKRoute?
    @Published private(set) var nextIndex = 0
    @Published private(set) var distanceToManeuver: CLLocationDistance = 0
    @Published private(set) var remainingDistance: CLLocationDistance = 0
    @Published private(set) var remainingTime: TimeInterval = 0
    @Published private(set) var speedKmh: Double = 0
    @Published private(set) var isRerouting = false
    @Published var voiceEnabled = true {
        didSet { if !voiceEnabled { synth.stopSpeaking(at: .immediate) } }
    }

    var onArrive: ((String) -> Void)?
    var onRouteChanged: (() -> Void)?

    private var destination: MKMapItem?
    private var destinationName = ""
    private var transport: MKDirectionsTransportType = .automobile
    private var steps: [MKRoute.Step] = []
    private var stepStart: [Double] = []          // Streckenposition (m) jedes Manövers
    private var coords: [CLLocationCoordinate2D] = []
    private var cumulative: [Double] = []         // Streckenlänge bis zu jedem Polyline-Punkt
    private var polyScale = 1.0
    private var lastSegment = 0
    private var spoken = Set<String>()
    private var offRouteHits = 0
    private var lastRerouteAt = Date.distantPast
    private var arrived = false
    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    var nextInstruction: String {
        steps.indices.contains(nextIndex) ? steps[nextIndex].instructions : ""
    }

    /// "Danach …" – nur wenn das nächste Manöver kurz auf das aktuelle folgt.
    var thenInstruction: String? {
        let i = nextIndex + 1
        guard steps.indices.contains(i), steps[nextIndex].distance < 400 else { return nil }
        let text = steps[i].instructions
        return text.isEmpty ? nil : text
    }

    var progress: Double {
        guard let r = route, r.distance > 0 else { return 0 }
        return min(max(1 - remainingDistance / r.distance, 0), 1)
    }

    // MARK: Steuerung

    func start(route: MKRoute, destination: MKMapItem, name: String, transport: MKDirectionsTransportType) {
        self.destination = destination
        self.destinationName = name
        self.transport = transport
        arrived = false
        isActive = true
        load(route)
        speak("Route zu \(name) gestartet.")
    }

    func stop() {
        isActive = false
        isRerouting = false
        route = nil
        steps = []
        coords = []
        synth.stopSpeaking(at: .immediate)
    }

    func update(location: CLLocation) {
        speedKmh = max(location.speed, 0) * 3.6
        guard isActive, !arrived, coords.count > 1, let route, !steps.isEmpty else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy < 100 else { return }

        let (offset, along) = project(location.coordinate)
        let traveled = along * polyScale
        remainingDistance = max(route.distance - traveled, 0)
        remainingTime = route.distance > 0 ? route.expectedTravelTime * remainingDistance / route.distance : 0

        // Ankunft
        let destCoord = destination?.placemark.coordinate ?? coords[coords.count - 1]
        let destLoc = CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)
        if remainingDistance < 25 || location.distance(from: destLoc) < 25 {
            arrive()
            return
        }

        // Manöver abhaken, an denen wir vorbei sind
        while nextIndex < steps.count - 1, stepStart[nextIndex] - traveled < 10 {
            nextIndex += 1
        }
        distanceToManeuver = max(stepStart[nextIndex] - traveled, 0)
        announce()

        // Von der Route abgekommen? → neu berechnen
        let tolerance = max(35, location.horizontalAccuracy * 1.5)
        offRouteHits = offset > tolerance ? offRouteHits + 1 : 0
        if offRouteHits >= 3, Date().timeIntervalSince(lastRerouteAt) > 10 {
            reroute(from: location)
        }
    }

    // MARK: Intern

    private func load(_ route: MKRoute) {
        self.route = route
        steps = route.steps
        var acc = 0.0
        stepStart = steps.map { step in
            defer { acc += step.distance }
            return acc
        }

        coords = route.polyline.coordinates
        cumulative = [0]
        if coords.count > 1 {
            for i in 1..<coords.count {
                let a = CLLocation(latitude: coords[i - 1].latitude, longitude: coords[i - 1].longitude)
                let b = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
                cumulative.append(cumulative[i - 1] + a.distance(from: b))
            }
        }
        let polyLength = cumulative.last ?? 0
        polyScale = polyLength > 0 ? route.distance / polyLength : 1

        lastSegment = 0
        nextIndex = steps.count > 1 ? 1 : 0
        remainingDistance = route.distance
        remainingTime = route.expectedTravelTime
        distanceToManeuver = steps.indices.contains(nextIndex) ? stepStart[nextIndex] : 0
        spoken.removeAll()
        offRouteHits = 0
    }

    /// Projiziert die Position auf die Routen-Linie.
    /// Rückgabe: Abstand zur Route (m) und zurückgelegte Strecke entlang der Route (m).
    private func project(_ c: CLLocationCoordinate2D) -> (offset: Double, along: Double) {
        let mPerLat = 110_540.0
        let mPerLon = 111_320.0 * cos(c.latitude * .pi / 180)
        func xy(_ p: CLLocationCoordinate2D) -> (Double, Double) {
            ((p.longitude - c.longitude) * mPerLon, (p.latitude - c.latitude) * mPerLat)
        }

        var best = (d: Double.greatestFiniteMagnitude, along: 0.0, seg: lastSegment)
        func scan(_ range: ClosedRange<Int>) {
            for i in range {
                let (ax, ay) = xy(coords[i])
                let (bx, by) = xy(coords[i + 1])
                let dx = bx - ax, dy = by - ay
                let len2 = dx * dx + dy * dy
                let t = len2 > 0 ? min(max(-(ax * dx + ay * dy) / len2, 0), 1) : 0
                let px = ax + t * dx, py = ay + t * dy
                let d = (px * px + py * py).squareRoot()
                if d < best.d {
                    let segLen = cumulative[i + 1] - cumulative[i]
                    best = (d, cumulative[i] + t * segLen, i)
                }
            }
        }

        let last = coords.count - 2
        scan(max(0, lastSegment - 10)...min(last, lastSegment + 300))
        if best.d > 200 { scan(0...last) }
        lastSegment = best.seg
        return (best.d, best.along)
    }

    private func announce() {
        guard steps.indices.contains(nextIndex) else { return }
        let text = steps[nextIndex].instructions
        guard !text.isEmpty else { return }
        let thresholds: [Double] = transport == .walking ? [100, 20] : [1500, 500, 150]
        guard let t = thresholds.last(where: { distanceToManeuver <= $0 }) else { return }
        let key = "\(nextIndex)-\(Int(t))"
        guard !spoken.contains(key) else { return }
        for other in thresholds where other >= t { spoken.insert("\(nextIndex)-\(Int(other))") }

        if t == thresholds.last {
            speak(text)
        } else {
            speak("In \(Fmt.spokenDistance(distanceToManeuver)) \(text)")
        }
    }

    private func reroute(from location: CLLocation) {
        guard let destination, !isRerouting else { return }
        isRerouting = true
        lastRerouteAt = Date()
        offRouteHits = 0
        speak("Route wird neu berechnet.")

        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        req.destination = destination
        req.transportType = transport
        MKDirections(request: req).calculate { [weak self] resp, _ in
            guard let self, self.isActive else { return }
            self.isRerouting = false
            if let newRoute = resp?.routes.first {
                self.load(newRoute)
                self.onRouteChanged?()
            }
        }
    }

    private func arrive() {
        arrived = true
        remainingDistance = 0
        distanceToManeuver = 0
        speak("Sie haben Ihr Ziel erreicht.")
        onArrive?(destinationName)
    }

    private func speak(_ text: String) {
        guard voiceEnabled else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt,
                                 options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        utterance.rate = 0.52
        synth.speak(utterance)
    }
}

extension NavigationEngine: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if !synthesizer.isSpeaking {
            // Musik/Podcasts wieder auf volle Lautstärke
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
