# Кременчук Транспорт / Kremenchuk Transport

Native iOS app showing Kremenchuk's buses and trolleybuses live on a map.

- **Bundle id** `dev.kremen.transport`
- **Version** 1.5 (a native SwiftUI rewrite of the 1.4 React Native app)
- **Minimum iOS** 17.0 · **Map** MapKit · **Languages** Ukrainian (default) and English

## Getting started

`project.yml` is the source of truth; the `.xcodeproj` is generated and not committed.
Xcode lives outside the active command-line developer directory here, so every invocation
sets `DEVELOPER_DIR` — the `Makefile` does it for you.

```sh
make gen     # regenerate KremenTransport.xcodeproj
make build   # build for the iPhone 17 Pro simulator
make test    # run the unit tests
make run     # build, install and launch on the simulator
```

Add a source file by dropping it under `App/Sources/` and running `make gen`.

Debug builds accept launch arguments that open a screen directly, which is how the UI gets
inspected and screenshotted without driving the simulator by hand:

```sh
xcrun simctl launch booted dev.kremen.transport -openPicker
xcrun simctl launch booted dev.kremen.transport -openStop 305
xcrun simctl launch booted dev.kremen.transport -cameraDistance 2200
xcrun simctl launch booted dev.kremen.transport -AppleLanguages '(en)' -AppleLocale en_US
```

## API

Read-only, unauthenticated, `https://api.husky-dev.me/`:

| Endpoint | Poll | Notes |
|---|---|---|
| `transport/routes` | hourly, cache-first | 565 KB; stops are embedded here (the dedicated stations endpoints are broken upstream) |
| `transport/buses` | 60 s | full roster, 78 KB |
| `transport/buses/locations` | 5 s | `{ tid: [lat, lng, direction, speed] }`, 14 KB |
| `transport/stations/{sid}/prediction` | 5 s while the stop sheet is open | `prediction` in seconds, `distance` in metres |

The backend rebuilds vehicle data every 10 s and route data hourly, so polling faster buys
nothing. There is no websocket.

## Layout

```
App/Sources/Models      # Codable DTOs, route-number normalisation
App/Sources/Networking  # APIClient actor, error and date decoding
App/Sources/Store       # observable stores, disk cache, polling, selection
App/Sources/Map         # map view, markers, viewport culling, polyline simplification
App/Sources/Features    # route picker, stop arrivals, vehicle detail, map controls
App/Resources           # asset catalog, String Catalog, InfoPlist.strings, privacy manifest
Tests                   # decoding tests run against real captured API payloads
```
