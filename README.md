# StreetRadar – iOS-Karten-App im Open-World-Spiele-Look

Funktioniert wie eine normale Karten-App (Suche, Orte, Routen, Turn-by-Turn mit Sprache,
Navigation läuft weiter, wenn man die App verlässt) – sieht aber aus wie das Radar/HUD
eines Open-World-Spiels: dunkle Karte, graue Straßen, lila Route, Spieler-Pfeil, Blip-Icons,
Minikarte mit grünem/blauem Balken, großes „ZIEL ERREICHT“-Banner.

## Was du brauchst

- Einen **Mac** mit **Xcode 16** oder neuer (iOS-Apps lassen sich nur auf macOS bauen).
  Ohne Mac: gemieteter Cloud-Mac (z. B. MacinCloud) oder GitHub Actions mit macOS-Runner.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Eine Apple-ID (kostenlos reicht zum Testen auf dem eigenen iPhone, 7 Tage gültig).
  Für den App Store: Apple Developer Program (99 €/Jahr).

## Bauen

```bash
cd StreetRadar
xcodegen generate
open StreetRadar.xcodeproj
```

In Xcode: Target **StreetRadar → Signing & Capabilities → Team** wählen,
Bundle-ID ggf. ändern (`com.example.streetradar` → deine eigene), iPhone anschließen, ▶︎ drücken.
MapLibre wird beim ersten Öffnen automatisch per Swift Package Manager geladen.

## Funktionen

| Funktion | Umsetzung |
|---|---|
| Karte | MapLibre Native + Vektorkacheln von OpenFreeMap (kostenlos, ohne API-Key), eigener Stil `Map/radar_style.json` |
| POIs mit passenden Icons | Jede OSM-Kategorie (Tankstelle, Supermarkt, Kleidung, Friseur, Bank, Krankenhaus, Polizei …) bekommt ein eigenes Blip-Icon → `Map/Blips.swift` |
| Suche + Autovervollständigung | Apple MapKit (`MKLocalSearchCompleter` / `MKLocalSearch`) |
| Kategorie-Schnellsuche | Chips unter der Suchleiste (Tankstellen, Essen, Supermärkte …) |
| Ort antippen | Name, Adresse, Entfernung, Anrufen, Website, Teilen |
| Wegpunkt setzen | Lange auf die Karte drücken → lila Wegpunkt |
| Routen | Apple `MKDirections`, Auto / zu Fuß, Alternativrouten, Verkehrslage in der Fahrzeit |
| Navigation | Manöver-Banner, „Danach …“, Ankunftszeit, Restzeit, Sprachansagen (Deutsch), automatische Neuberechnung |
| App verlassen / iPhone sperren | Hintergrund-Standort + Audio: Ansagen laufen weiter, blaue Statusleisten-Anzeige wie bei Google Maps |
| Spiele-HUD | Gekippte Fahrkarte, Radar-Minikarte unten links mit Tempo, Akku- und Fortschrittsbalken |

## Wichtig: Icons & Rechtliches

Die Original-Icons, Schriften, Logos und Namen aus GTA gehören Rockstar Games / Take-Two.
Sie 1:1 zu übernehmen wäre eine Urheber- und Markenrechtsverletzung – Apple lehnt solche
Apps im Review ab (Richtlinie 5.2). Deshalb sind **alle Icons hier eigene Zeichnungen**
(SF Symbols mit dicker schwarzer Kontur im Blip-Stil), der App-Name ist neutral und das
Banner heißt „ZIEL ERREICHT“. Der Look ist „im Stil von“, nicht kopiert.

Die Karte nutzt OpenStreetMap-Daten → der ⓘ-Attributionsknopf unten rechts muss sichtbar bleiben.

## Was im Vergleich zu Google Maps noch fehlt

- Street View, Fotos und Bewertungen von Orten (bräuchte z. B. Google Places API – kostenpflichtig)
- ÖPNV- und Fahrrad-Routen (MapKit liefert dafür keine Turn-by-Turn-Routen)
- Offline-Karten, Live Activity auf dem Sperrbildschirm, CarPlay
- Spurassistent und Tempolimits
- App-Icon (in `Assets.xcassets` ergänzen)

## Projektstruktur

```
StreetRadar/
├─ project.yml                  XcodeGen-Konfiguration (Berechtigungen, Hintergrundmodi, MapLibre)
└─ StreetRadar/
   ├─ App/        StreetRadarApp, AppModel (zentraler Zustand)
   ├─ Map/        MapContainer (Karte + Gesten), Blips (Icons), PlayerArrowView, radar_style.json
   ├─ Services/   LocationService, SearchService, NavigationEngine
   ├─ Support/    Place, Formatierung
   └─ UI/         Theme, ContentView, Such-/Orts-/Routen-Panels, Navigations-HUD
```
