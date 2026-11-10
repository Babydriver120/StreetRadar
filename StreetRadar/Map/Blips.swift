import UIKit
import MapKit
import MapLibre

/// Eigene "Blip"-Icons im Stil eines Spiele-Radars:
/// weißes (oder farbiges) Piktogramm mit dicker schwarzer Kontur, ohne Hintergrund.
/// Die Piktogramme basieren auf SF Symbols – es werden KEINE Original-Spielgrafiken verwendet.
enum Blips {
    struct Spec {
        let symbol: String
        let color: UIColor
    }

    static let white  = UIColor.white
    static let green  = UIColor(red: 0.42, green: 0.78, blue: 0.36, alpha: 1)
    static let red    = UIColor(red: 0.90, green: 0.25, blue: 0.22, alpha: 1)
    static let blue   = UIColor(red: 0.36, green: 0.62, blue: 0.95, alpha: 1)
    static let gold   = UIColor(red: 0.95, green: 0.78, blue: 0.31, alpha: 1)
    static let purple = UIColor(red: 0.66, green: 0.33, blue: 0.97, alpha: 1)
    static let orange = UIColor(red: 0.98, green: 0.55, blue: 0.20, alpha: 1)

    /// Schlüssel = OpenMapTiles-POI-Klasse (siehe radar_style.json → poi-blips)
    static let specs: [String: Spec] = [
        "fuel":           Spec(symbol: "fuelpump.fill", color: white),
        "shop":           Spec(symbol: "bag.fill", color: white),
        "grocery":        Spec(symbol: "basket.fill", color: white),
        "clothing_store": Spec(symbol: "tshirt.fill", color: white),
        "hairdresser":    Spec(symbol: "scissors", color: white),
        "restaurant":     Spec(symbol: "fork.knife", color: white),
        "fast_food":      Spec(symbol: "takeoutbag.and.cup.and.straw.fill", color: white),
        "cafe":           Spec(symbol: "cup.and.saucer.fill", color: white),
        "bakery":         Spec(symbol: "birthday.cake.fill", color: white),
        "bar":            Spec(symbol: "wineglass.fill", color: white),
        "beer":           Spec(symbol: "mug.fill", color: white),
        "alcohol_shop":   Spec(symbol: "wineglass", color: white),
        "hospital":       Spec(symbol: "cross.fill", color: red),
        "pharmacy":       Spec(symbol: "pills.fill", color: green),
        "doctors":        Spec(symbol: "stethoscope", color: white),
        "dentist":        Spec(symbol: "stethoscope", color: white),
        "veterinary":     Spec(symbol: "pawprint.fill", color: white),
        "bank":           Spec(symbol: "dollarsign", color: green),
        "police":         Spec(symbol: "shield.fill", color: blue),
        "fire_station":   Spec(symbol: "flame.fill", color: orange),
        "car":            Spec(symbol: "wrench.and.screwdriver.fill", color: white),
        "bicycle":        Spec(symbol: "bicycle", color: white),
        "parking":        Spec(symbol: "p.square.fill", color: blue),
        "lodging":        Spec(symbol: "bed.double.fill", color: white),
        "cinema":         Spec(symbol: "film.fill", color: white),
        "theatre":        Spec(symbol: "theatermasks.fill", color: white),
        "music":          Spec(symbol: "music.note", color: white),
        "stadium":        Spec(symbol: "sportscourt.fill", color: white),
        "swimming":       Spec(symbol: "figure.pool.swim", color: blue),
        "golf":           Spec(symbol: "figure.golf", color: white),
        "park":           Spec(symbol: "tree.fill", color: green),
        "zoo":            Spec(symbol: "pawprint.fill", color: green),
        "attraction":     Spec(symbol: "star.fill", color: gold),
        "museum":         Spec(symbol: "building.columns.fill", color: white),
        "school":         Spec(symbol: "graduationcap.fill", color: white),
        "college":        Spec(symbol: "graduationcap.fill", color: white),
        "library":        Spec(symbol: "books.vertical.fill", color: white),
        "post":           Spec(symbol: "envelope.fill", color: white),
        "town_hall":      Spec(symbol: "building.2.fill", color: white),
        "bus":            Spec(symbol: "bus.fill", color: white),
        "railway":        Spec(symbol: "tram.fill", color: white),
        "harbor":         Spec(symbol: "ferry.fill", color: white),
        "laundry":        Spec(symbol: "washer.fill", color: white),
        "campsite":       Spec(symbol: "tent.fill", color: green),
        "airport":        Spec(symbol: "airplane", color: white),
    ]

    private static let specials = ["result", "destination", "waypoint"]
    private static var cache: [String: UIImage] = [:]

    /// `name` z. B. "blip-fuel"
    static func image(named name: String) -> UIImage? {
        if let cached = cache[name] { return cached }
        let key = name.hasPrefix("blip-") ? String(name.dropFirst(5)) : name
        let img: UIImage?
        switch key {
        case "result":      img = dot(color: gold)
        case "destination": img = glyph("flag.fill", color: gold, size: 36)
        case "waypoint":    img = glyph("flag.fill", color: purple, size: 36)
        default:            img = specs[key].map { glyph($0.symbol, color: $0.color) }
        }
        if let img { cache[name] = img }
        return img
    }

    static func register(in style: MLNStyle) {
        for key in Array(specs.keys) + specials {
            let name = "blip-" + key
            if let img = image(named: name) { style.setImage(img, forName: name) }
        }
    }

    /// Apple-Suchergebnis-Kategorie → Blip-Schlüssel
    static func key(for category: MKPointOfInterestCategory?) -> String {
        guard let category else { return "result" }
        switch category {
        case .gasStation, .evCharger:          return "fuel"
        case .restaurant:                      return "restaurant"
        case .cafe:                            return "cafe"
        case .bakery:                          return "bakery"
        case .nightlife, .brewery, .winery:    return "bar"
        case .foodMarket:                      return "grocery"
        case .store:                           return "shop"
        case .bank, .atm:                      return "bank"
        case .hospital:                        return "hospital"
        case .pharmacy:                        return "pharmacy"
        case .police:                          return "police"
        case .fireStation:                     return "fire_station"
        case .parking:                         return "parking"
        case .hotel, .campground:              return category == .hotel ? "lodging" : "campsite"
        case .movieTheater:                    return "cinema"
        case .theater:                         return "theatre"
        case .stadium:                         return "stadium"
        case .fitnessCenter:                   return "stadium"
        case .park, .nationalPark:             return "park"
        case .zoo, .amusementPark, .aquarium:  return "attraction"
        case .museum:                          return "museum"
        case .school, .university:             return "school"
        case .library:                         return "library"
        case .postOffice:                      return "post"
        case .publicTransport:                 return "bus"
        case .airport:                         return "airport"
        case .marina:                          return "harbor"
        case .laundry:                         return "laundry"
        case .carRental:                       return "car"
        case .beach:                           return "swimming"
        default:                               return "result"
        }
    }

    // MARK: - Rendering

    private static func glyph(_ symbol: String, color: UIColor, size: CGFloat = 30) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: size * 0.55, weight: .black)
        let base = UIImage(systemName: symbol, withConfiguration: config)
            ?? UIImage(systemName: "mappin", withConfiguration: config)!
        let maxSide = size - 7
        let scale = min(1, maxSide / max(base.size.width, base.size.height))
        let w = base.size.width * scale, h = base.size.height * scale
        let rect = CGRect(x: (size - w) / 2, y: (size - h) / 2, width: w, height: h)

        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { _ in
            // dicke schwarze Kontur: Symbol mehrfach versetzt in Schwarz zeichnen
            let outline = base.withTintColor(.black, renderingMode: .alwaysOriginal)
            let r: CGFloat = 2.2
            for i in 0..<16 {
                let a = CGFloat(i) / 16 * 2 * .pi
                outline.draw(in: rect.offsetBy(dx: cos(a) * r, dy: sin(a) * r))
            }
            base.withTintColor(color, renderingMode: .alwaysOriginal).draw(in: rect)
        }
    }

    private static func dot(color: UIColor, size: CGFloat = 26) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let rect = CGRect(x: 0, y: 0, width: size, height: size).insetBy(dx: 5, dy: 5)
            ctx.cgContext.setFillColor(color.cgColor)
            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setLineWidth(3)
            ctx.cgContext.addEllipse(in: rect)
            ctx.cgContext.drawPath(using: .fillStroke)
        }
    }
}
