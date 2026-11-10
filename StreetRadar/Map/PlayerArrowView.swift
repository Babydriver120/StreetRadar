import UIKit
import MapLibre

/// Spieler-Pfeil statt des blauen Punkts: weißer Pfeil mit schwarzer Kontur,
/// dreht sich mit Fahrtrichtung / Kompass.
final class PlayerArrowView: MLNUserLocationAnnotationView {
    var size: CGFloat = 30
    private let arrow = CAShapeLayer()
    private var built = false

    override func update() {
        if !built { build() }

        var direction: Double = 0
        if let loc = userLocation?.location, loc.speed > 1.5, loc.course >= 0 {
            direction = loc.course
        } else if let h = userLocation?.heading?.trueHeading, h >= 0 {
            direction = h
        }
        let mapDirection = mapView?.direction ?? 0
        let angle = CGFloat((direction - mapDirection) * .pi / 180)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        arrow.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        CATransaction.commit()
    }

    private func build() {
        built = true
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        let s = size
        let path = UIBezierPath()
        path.move(to: CGPoint(x: s * 0.5, y: s * 0.06))
        path.addLine(to: CGPoint(x: s * 0.88, y: s * 0.92))
        path.addLine(to: CGPoint(x: s * 0.5, y: s * 0.72))
        path.addLine(to: CGPoint(x: s * 0.12, y: s * 0.92))
        path.close()

        arrow.frame = bounds
        arrow.path = path.cgPath
        arrow.fillColor = UIColor.white.cgColor
        arrow.strokeColor = UIColor.black.cgColor
        arrow.lineWidth = 2.2
        arrow.lineJoin = .round
        arrow.shadowColor = UIColor.black.cgColor
        arrow.shadowOpacity = 0.6
        arrow.shadowRadius = 3
        arrow.shadowOffset = .zero
        layer.addSublayer(arrow)
    }
}
