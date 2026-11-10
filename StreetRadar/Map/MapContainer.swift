import SwiftUI
import MapKit
import MapLibre

/// Die Karte (MapLibre + eigener Stil). Wird zweimal verwendet:
/// als Vollbild-Karte und als kleines "Radar" unten links während der Navigation.
struct MapContainer: UIViewRepresentable {
    @ObservedObject var model: AppModel
    var isRadar = false

    func makeCoordinator() -> MapCoordinator {
        MapCoordinator(model: model, isRadar: isRadar)
    }

    func makeUIView(context: Context) -> MLNMapView {
        let styleURL = Bundle.main.url(forResource: "radar_style", withExtension: "json")
        let map = MLNMapView(frame: .zero, styleURL: styleURL)
        map.delegate = context.coordinator
        map.compassView.isHidden = true
        map.logoView.isHidden = true
        map.showsUserLocation = true
        map.showsUserHeadingIndicator = true
        map.minimumZoomLevel = 2
        context.coordinator.mapView = map

        if isRadar {
            map.isUserInteractionEnabled = false
            map.attributionButton.isHidden = true   // Attribution ist in der Hauptkarte sichtbar
            map.zoomLevel = 16
            map.userTrackingMode = .followWithCourse
        } else {
            map.setCenter(CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515), zoomLevel: 5, animated: false)
            map.userTrackingMode = .follow

            let tap = UITapGestureRecognizer(target: context.coordinator,
                                             action: #selector(MapCoordinator.handleTap(_:)))
            for r in map.gestureRecognizers ?? [] where (r as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 {
                tap.require(toFail: r)
            }
            map.addGestureRecognizer(tap)

            let longPress = UILongPressGestureRecognizer(target: context.coordinator,
                                                         action: #selector(MapCoordinator.handleLongPress(_:)))
            map.addGestureRecognizer(longPress)
        }
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.sync()
    }
}

final class MapCoordinator: NSObject, MLNMapViewDelegate {
    let model: AppModel
    let isRadar: Bool
    weak var mapView: MLNMapView?

    private var style: MLNStyle?
    private var appliedRoute: UUID?
    private var appliedMarkers: UUID?
    private var appliedCamera: UUID?

    init(model: AppModel, isRadar: Bool) {
        self.model = model
        self.isRadar = isRadar
    }

    // MARK: Zustand aus dem Model auf die Karte übertragen

    func sync() {
        guard let map = mapView else { return }
        if !isRadar, let req = model.camera, req.id != appliedCamera {
            appliedCamera = req.id
            apply(req, on: map)
        }
        guard let style else { return }
        if model.routeOverlay.id != appliedRoute {
            appliedRoute = model.routeOverlay.id
            applyRoute(style)
        }
        if model.markers.id != appliedMarkers {
            appliedMarkers = model.markers.id
            applyMarkers(style)
        }
    }

    private func apply(_ req: CameraRequest, on map: MLNMapView) {
        switch req.kind {
        case .center(let c, let zoom):
            map.setCenter(c, zoomLevel: zoom, animated: true)

        case .fit(let coords):
            guard !coords.isEmpty else { return }
            if coords.count == 1 {
                map.setCenter(coords[0], zoomLevel: 15, animated: true)
            } else {
                map.setVisibleCoordinates(coords, count: UInt(coords.count),
                                          edgePadding: UIEdgeInsets(top: 170, left: 40, bottom: 340, right: 40),
                                          animated: true)
            }

        case .follow:
            map.contentInset = .zero
            let cam = map.camera
            cam.pitch = 0
            cam.heading = 0
            map.setCamera(cam, animated: false)
            map.setUserTrackingMode(.follow, animated: true, completionHandler: nil)

        case .navigate:
            // Spieler-Pfeil ins untere Drittel, Karte gekippt – wie beim Fahren im Spiel
            map.contentInset = UIEdgeInsets(top: map.bounds.height * 0.4, left: 0, bottom: 0, right: 0)
            if let loc = map.userLocation?.location {
                let cam = MLNMapCamera(lookingAtCenter: loc.coordinate, altitude: 450,
                                       pitch: 50, heading: max(loc.course, 0))
                map.setCamera(cam, animated: false)
            }
            map.setUserTrackingMode(.followWithCourse, animated: true, completionHandler: nil)
        }
    }

    private func applyRoute(_ style: MLNStyle) {
        let o = model.routeOverlay
        let main = style.source(withIdentifier: "route-main") as? MLNShapeSource
        main?.shape = o.main.count > 1 ? MLNPolylineFeature(coordinates: o.main, count: UInt(o.main.count)) : nil

        let alts: [MLNShape & MLNFeature] = o.alternates
            .filter { $0.count > 1 }
            .map { MLNPolylineFeature(coordinates: $0, count: UInt($0.count)) }
        let alt = style.source(withIdentifier: "route-alt") as? MLNShapeSource
        alt?.shape = alts.isEmpty ? nil : MLNShapeCollectionFeature(shapes: alts)
    }

    private func applyMarkers(_ style: MLNStyle) {
        var features: [MLNShape & MLNFeature] = []
        for (i, place) in model.markers.results.enumerated() {
            let f = MLNPointFeature()
            f.coordinate = place.coordinate
            f.attributes = ["icon": "blip-" + place.blip, "title": place.name, "idx": i, "scale": 1.15]
            features.append(f)
        }
        if let pin = model.markers.pin {
            let f = MLNPointFeature()
            f.coordinate = pin.coordinate
            f.attributes = ["icon": pin.blip == "waypoint" ? "blip-waypoint" : "blip-destination",
                            "title": pin.name, "idx": -1, "scale": 1.3]
            features.append(f)
        }
        let src = style.source(withIdentifier: "markers") as? MLNShapeSource
        src?.shape = features.isEmpty ? nil : MLNShapeCollectionFeature(shapes: features)
    }

    private func installOverlays(_ style: MLNStyle) {
        let altSource = MLNShapeSource(identifier: "route-alt", shape: nil, options: nil)
        let mainSource = MLNShapeSource(identifier: "route-main", shape: nil, options: nil)
        let markerSource = MLNShapeSource(identifier: "markers", shape: nil, options: nil)
        style.addSource(altSource)
        style.addSource(mainSource)
        style.addSource(markerSource)

        let round = NSExpression(forConstantValue: "round")

        let altLine = MLNLineStyleLayer(identifier: "route-alt-line", source: altSource)
        altLine.lineColor = NSExpression(forConstantValue: UIColor(white: 0.6, alpha: 0.85))
        altLine.lineWidth = NSExpression(forConstantValue: 5)
        altLine.lineCap = round
        altLine.lineJoin = round

        let casing = MLNLineStyleLayer(identifier: "route-casing", source: mainSource)
        casing.lineColor = NSExpression(forConstantValue: UIColor.black)
        casing.lineWidth = NSExpression(forConstantValue: isRadar ? 8 : 11)
        casing.lineCap = round
        casing.lineJoin = round

        let line = MLNLineStyleLayer(identifier: "route-line", source: mainSource)
        line.lineColor = NSExpression(forConstantValue: Theme.routeUI)
        line.lineWidth = NSExpression(forConstantValue: isRadar ? 5 : 7)
        line.lineCap = round
        line.lineJoin = round

        let below = style.layer(withIdentifier: "road-label")
        for layer in [altLine, casing, line] {
            if let below { style.insertLayer(layer, below: below) } else { style.addLayer(layer) }
        }

        let markers = MLNSymbolStyleLayer(identifier: "markers-layer", source: markerSource)
        markers.iconImageName = NSExpression(forKeyPath: "icon")
        markers.iconScale = NSExpression(forKeyPath: "scale")
        markers.iconAllowsOverlap = NSExpression(forConstantValue: true)
        markers.iconIgnoresPlacement = NSExpression(forConstantValue: true)
        if !isRadar {
            markers.text = NSExpression(forKeyPath: "title")
            markers.textFontNames = NSExpression(forConstantValue: ["Noto Sans Bold"])
            markers.textFontSize = NSExpression(forConstantValue: 12)
            markers.textOffset = NSExpression(forConstantValue: NSValue(cgVector: CGVector(dx: 0, dy: 1.6)))
            markers.textAnchor = NSExpression(forConstantValue: "top")
            markers.textColor = NSExpression(forConstantValue: UIColor.white)
            markers.textHaloColor = NSExpression(forConstantValue: UIColor.black)
            markers.textHaloWidth = NSExpression(forConstantValue: 1.5)
            markers.textOptional = NSExpression(forConstantValue: true)
        }
        style.addLayer(markers)
    }

    // MARK: Gesten

    @objc func handleTap(_ g: UITapGestureRecognizer) {
        guard let map = mapView, model.phase != .navigating else { return }
        let p = g.location(in: map)
        let rect = CGRect(x: p.x - 22, y: p.y - 22, width: 44, height: 44)

        if let f = map.visibleFeatures(in: rect, styleLayerIdentifiers: ["markers-layer"]).first,
           let idx = (f.attribute(forKey: "idx") as? NSNumber)?.intValue,
           model.results.indices.contains(idx) {
            model.select(model.results[idx])
            return
        }
        if let f = map.visibleFeatures(in: rect, styleLayerIdentifiers: ["airport-blips"]).first {
            model.selectPOI(name: name(of: f), blip: "airport", coordinate: f.coordinate)
            return
        }
        if let f = map.visibleFeatures(in: rect, styleLayerIdentifiers: ["poi-blips"]).first {
            let cls = (f.attribute(forKey: "class") as? String) ?? "result"
            model.selectPOI(name: name(of: f), blip: cls, coordinate: f.coordinate)
            return
        }
        if model.phase == .place || model.phase == .preview {
            model.clearSelection()
        }
    }

    @objc func handleLongPress(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let map = mapView, model.phase != .navigating else { return }
        let c = map.convert(g.location(in: map), toCoordinateFrom: map)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        model.dropWaypoint(at: c)
    }

    private func name(of f: MLNFeature) -> String {
        (f.attribute(forKey: "name:de") as? String) ?? (f.attribute(forKey: "name") as? String) ?? "Ort"
    }

    // MARK: MLNMapViewDelegate

    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        self.style = style
        Blips.register(in: style)
        installOverlays(style)
        appliedRoute = nil
        appliedMarkers = nil
        sync()
    }

    func mapView(_ mapView: MLNMapView, didFailToLoadImage imageName: String) -> UIImage? {
        Blips.image(named: imageName)
    }

    func mapView(_ mapView: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
        guard annotation is MLNUserLocation else { return nil }
        let view = PlayerArrowView()
        view.size = isRadar ? 20 : 30
        return view
    }

    func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
        guard !isRadar else { return }
        let b = mapView.visibleCoordinateBounds
        let span = MKCoordinateSpan(latitudeDelta: abs(b.ne.latitude - b.sw.latitude),
                                    longitudeDelta: abs(b.ne.longitude - b.sw.longitude))
        model.updateVisibleRegion(MKCoordinateRegion(center: mapView.centerCoordinate, span: span))
    }

    func mapView(_ mapView: MLNMapView, didChange mode: MLNUserTrackingMode, animated: Bool) {
        if isRadar {
            if mode != .followWithCourse {
                DispatchQueue.main.async { mapView.userTrackingMode = .followWithCourse }
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.model.isFollowing = mode != .none
        }
    }
}
