import Foundation
import MapKit

struct Place: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var subtitle: String
    var coordinate: CLLocationCoordinate2D
    var blip: String
    var mapItem: MKMapItem

    init(mapItem: MKMapItem, fallbackBlip: String = "result") {
        let name = mapItem.name ?? "Unbenannter Ort"
        let address = mapItem.placemark.title ?? ""
        self.name = name
        self.subtitle = address == name ? "" : address
        self.coordinate = mapItem.placemark.coordinate
        let key = Blips.key(for: mapItem.pointOfInterestCategory)
        self.blip = key == "result" ? fallbackBlip : key
        self.mapItem = mapItem
    }

    init(name: String, subtitle: String, coordinate: CLLocationCoordinate2D, blip: String) {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.blip = blip
        self.mapItem = item
    }

    static func == (l: Place, r: Place) -> Bool { l.id == r.id }

    var shareURL: URL {
        let q = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)&q=\(q)")
            ?? URL(string: "https://maps.apple.com")!
    }
}

extension MKMultiPoint {
    var coordinates: [CLLocationCoordinate2D] {
        var result = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&result, range: NSRange(location: 0, length: pointCount))
        return result
    }
}

enum Fmt {
    private static let de = Locale(identifier: "de_DE")

    static func distance(_ m: Double) -> String {
        if m < 1000 {
            let r = m < 100 ? (m / 10).rounded() * 10 : (m / 50).rounded() * 50
            return "\(Int(r)) m"
        }
        let km = (m / 1000).formatted(.number.precision(.fractionLength(m < 10_000 ? 1 : 0)).locale(de))
        return "\(km) km"
    }

    static func spokenDistance(_ m: Double) -> String {
        if m < 1000 {
            let r = m < 100 ? max(10, (m / 10).rounded() * 10) : (m / 50).rounded() * 50
            return "\(Int(r)) Metern"
        }
        let km = (m / 1000).formatted(.number.precision(.fractionLength(m < 10_000 ? 1 : 0)).locale(de))
        return "\(km) Kilometern"
    }

    static func duration(_ t: TimeInterval) -> String {
        let minutes = Int((t / 60).rounded())
        if minutes < 60 { return "\(max(minutes, 1)) MIN" }
        return "\(minutes / 60) STD \(minutes % 60) MIN"
    }

    static func clock(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// Pfeil-Symbol aus dem Anweisungstext ableiten (MapKit liefert keinen Manöver-Typ).
    static func maneuverSymbol(_ instruction: String) -> String {
        let t = instruction.lowercased()
        if t.contains("ziel") || t.contains("destination") || t.contains("ankunft") { return "flag.checkered" }
        if t.contains("kreisverkehr") || t.contains("roundabout") { return "arrow.triangle.turn.up.right.circle" }
        if t.contains("wenden") || t.contains("u-turn") { return "arrow.uturn.down" }
        if t.contains("halb links") || t.contains("leicht links") || t.contains("slight left") { return "arrow.up.left" }
        if t.contains("halb rechts") || t.contains("leicht rechts") || t.contains("slight right") { return "arrow.up.right" }
        if t.contains("links") || t.contains("left") { return "arrow.turn.up.left" }
        if t.contains("rechts") || t.contains("right") { return "arrow.turn.up.right" }
        if t.contains("ausfahrt") || t.contains("exit") { return "arrow.up.right" }
        return "arrow.up"
    }
}
