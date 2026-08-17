# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Native iOS app (SwiftUI + MapKit) showing Kremenchuk's buses and trolleybuses live on a map.
Version 1.5 — a full native rewrite of the React Native 1.4 app that still sits in
`/Users/husky/Projects/kremen-transport-mob`. The web sibling is
`/Users/husky/Projects/kremen-transport-web`; it uses the same backend and is the better
reference of the two, but neither app's design should be copied.

## Build and test

**`xcode-select` points at CommandLineTools, not Xcode.** Every `xcodebuild` / `xcrun` call must
be prefixed with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. The `Makefile`
exports it — prefer `make`, and do **not** run `sudo xcode-select -s` to "fix" this.

```sh
make gen     # regenerate KremenTransport.xcodeproj from project.yml
make build   # Debug build for the iPhone 17 Pro simulator
make test    # full unit test suite
make run     # build, install and launch on the simulator
make clean
```

Single test (or class, or target — drop trailing components to widen):

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project KremenTransport.xcodeproj -scheme KremenTransport \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO \
  -only-testing:KremenTransportTests/RouteNumberTests/testSortsNumerically test
```

`CODE_SIGNING_ALLOWED=NO` keeps simulator builds from stalling on provisioning.

### Project generation

`project.yml` is the source of truth; `KremenTransport.xcodeproj` and `App/Supporting/Info.plist`
are generated and git-ignored. **Adding a source file requires `make gen`** — it will not appear
in the build otherwise. Never hand-edit the `.xcodeproj` or the generated `Info.plist`; edit
`project.yml`.

Two settings there are load-bearing and easy to break:

- `GENERATE_INFOPLIST_FILE: NO` with a real `info:` block. Under a real plist, every
  `INFOPLIST_KEY_*` build setting is **silently ignored** — pick one system, not both.
- `SWIFT_VERSION: "5.0"` with `SWIFT_STRICT_CONCURRENCY: complete`. Concurrency problems surface
  as warnings rather than hard errors. Do not set `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`;
  implicit main-actor isolation would drag the 565 KB JSON decode onto the main thread.

## Verifying UI changes

Simulator tap automation is not available in this environment (macOS accessibility control is
blocked). Debug builds therefore accept launch arguments that open a screen directly — see
`App/Sources/App/DebugLaunch.swift`:

```sh
xcrun simctl launch booted dev.kremen.transport -openPicker
xcrun simctl launch booted dev.kremen.transport -openStop 305
xcrun simctl launch booted dev.kremen.transport -cameraDistance 2200
xcrun simctl launch booted dev.kremen.transport -AppleLanguages '(uk)' -AppleLocale uk_UA
xcrun simctl io booted screenshot shot.png
```

Set a location with `xcrun simctl location booted set 49.07041,33.42282`.

## API

Read-only and unauthenticated at `https://api.husky-dev.me/` (`APIEndpoint` in
`App/Sources/Networking/APIClient.swift`). Several properties of this backend are not visible
from the code and have bitten before:

- **There is no websocket and no marker-image service.** The 1.4 app used
  `wss://api.kremen.dev/transport/realtime` and `/img/transport/bus/pin`; that host is dead and
  the new one 404s both. All movement comes from polling and all markers are drawn client-side.
- **`transport/stations?rids=` and `transport/routes/{rid}/stations` are broken upstream** — they
  return one station per route. Stops must only ever be read from the `stations` array embedded
  in `transport/routes`.
- **Poll intervals are tied to the backend's own cadence**, which rebuilds vehicles every 10 s and
  routes hourly. Positions 5 s, roster 60 s, routes 1 h, stop predictions 5 s while the sheet is
  open. Polling faster buys nothing.
- **`transport/buses/locations` only moves vehicles it already knows about.** A vehicle that
  appears mid-session shows up as an unknown `tid`; only a full roster fetch can name it, which is
  why `VehicleFeed` refetches (debounced) on an unknown id.
- **Route IDs were renumbered** (now 1–42). Anything carried over from the 1.4 app — cached data,
  default selections — is meaningless against this API. Hence `selection.routeIDs.v2` in
  `SelectionStore`.

Data quirks encoded in the models:

- `type` is `"B"`/`"T"`. **Group by `route.type`, never by string-matching the number** — the web
  app's `number.indexOf('Т')` misclassifies the Latin-`T` routes. A *vehicle's* `type` is derived
  server-side from a free-text name and is unreliable; prefer the route's.
- Route numbers mix Cyrillic `Т` and Latin `T`, hyphens and stray spaces (`"Т 1+"`, `"3-б"`,
  `"T15Б"`). `RouteNumber` normalises for badges, sorting and search — search deliberately
  tolerates the Т/T mix-up so a Latin keyboard finds Cyrillic routes.
- `path` is `[lat, lng]`, lat first. A single malformed pair must not sink the 565 KB payload —
  `Route` decodes it through a failable wrapper.
- **A stop's `sid` maps 1:1 to a coordinate (1994 station entries fold to 433 stops), but the API
  returns the same `sid` for both travel directions.** The stop therefore carries no usable
  direction. `StationSheet` splits arrivals on each *prediction's* `reverse` flag; the web app's
  `reverse !== directionForward` filter would drop about half the real arrivals here.

## Architecture

### Three observable stores, deliberately separate

Splitting them is the point — a 5-second position tick must not invalidate the polyline layer or
the route picker.

| Store | Owns | Changes |
|---|---|---|
| `TransportStore` | routes, deduplicated stops | launch, then hourly |
| `VehicleFeed` | live vehicles keyed by `tid` | every 5 s |
| `SelectionStore` | selected route ids, show-offline | user action |
| `PredictionFeed` | one stop's arrivals; created *with* the sheet | every 5 s while open |

`PredictionFeed` is scoped to the sheet so its poll can never outlive the UI that asked for it.
All polling goes through `Poller.loop`, whose `Task.sleep` is cancellation-aware — tearing the
task down is the whole shutdown mechanism. `MapScreen` drives this with `.task(id: isPolling)`
keyed on `scenePhase`.

### Launch path

Never block the map on the 565 KB routes download. `TransportStore.load()` reads `RouteCache`
(raw bytes in Application Support, plus ETag/Last-Modified) and paints immediately, then
revalidates conditionally; a 304 only touches the timestamp.

### Map performance contract

`TransportMapView` is the only file that knows how the map is drawn — it takes items, a
selection and camera commands. If SwiftUI `Map` ever proves too slow, it can be swapped for an
`MKMapView` `UIViewRepresentable` without touching stores or models.

Selecting all 38 routes would mean ~200 vehicles, 433 stops and 38 polylines of up to 664 points.
Three mechanisms keep that bounded, and changes to the map layer must preserve them:

- `MapViewportModel` culls to the padded visible rect and caps vehicles/stops, recomputed only on
  `.onMapCameraChange(frequency: .onEnd)`.
- `MapDetail` gates stops and vehicle labels by camera distance, with hysteresis so markers don't
  strobe at a threshold.
- `RoutePathCache` memoises Douglas–Peucker–simplified paths per route per detail level.

Annotations are selected via `.tag(MapTarget...)` and one binding, not per-marker gestures —
that is where SwiftUI `Map` annotation cost explodes. Note `MapTarget` is named to avoid
colliding with SwiftUI's own generic `MapSelection`.

## Localization

Ukrainian is the development language; English is secondary. A device in any third language falls
back to Ukrainian. Three places must agree: `options.developmentLanguage: uk`,
`CFBundleDevelopmentRegion: uk`, and `"sourceLanguage": "uk"` in the catalog. Do **not** add a
`Base.lproj` — it would win over `uk`.

Two separate mechanisms:

- **UI strings** → `App/Resources/Localizable.xcstrings`. Plain JSON, hand-writable; `xcodebuild`
  compiles it via `xcstringstool` with no IDE involved. Use **symbolic keys**
  (`routes.title`, not a Ukrainian sentence) — with `sourceLanguage: uk` a missing unit falls back
  to the raw key, so a symbolic key makes the failure loud instead of silently correct-looking in
  Ukrainian and broken in English. Set `"extractionState": "manual"` on hand-added entries or the
  extractor may prune them. Ukrainian plurals need `one/few/many/other`.
- **Info.plist strings** → `App/Resources/{uk,en}.lproj/InfoPlist.strings` (display name, location
  permission). XcodeGen auto-detects `*.lproj` under a `sources` path and builds the variant group.

Verify a change reached the bundle:

```sh
APP=build/Build/Products/Debug-iphonesimulator/KremenTransport.app
ls "$APP"/*.lproj/                       # expect Localizable.strings + .stringsdict in uk and en
plutil -p "$APP/uk.lproj/InfoPlist.strings"
```

## App Store listing (fastlane)

The store text lives in the repo, next to the app's own localizations:

```sh
make metadata        # download the live listing into fastlane/metadata
make metadata-push   # upload fastlane/metadata back (no binary, no screenshots)
make screenshots     # download the current screenshots
```

`fastlane` comes from Homebrew (`brew install fastlane`), so no Gemfile or bundler here.
Auth is an App Store Connect API key described by `fastlane/private/asc_key.json`
(see `fastlane/asc_key.json.example`); `fastlane/private/` is git-ignored, as is
`fastlane/metadata/review_information/` — it holds reviewer contact details.

`fastlane/metadata/<locale>/*.txt` is one string per file, so a listing change reads as a diff.
Locales are App Store codes (`uk`, `en-US`), not the app's `uk`/`en` bundle locales.

## Release notes

- Bundle `dev.kremen.transport`, `DEVELOPMENT_TEAM` `BLVWV6S9PP`, marketing version 1.5.
- Universal: `TARGETED_DEVICE_FAMILY: "1,2"`. iPad multitasking demands all four orientations, so
  `UISupportedInterfaceOrientations~ipad` adds upside-down; the iPhone list stays three.
  `make run-ipad` installs on the iPad simulator (`IPAD` in the `Makefile`).
- The app icon is the 1.4 artwork **flattened over an opaque background**. The original has an
  alpha channel, which fails App Store upload validation — keep any replacement opaque.
- `PrivacyInfo.xcprivacy` declares `UserDefaults` (`CA92.1`) and file timestamps (`C617.1`).

## Launch screen

`App/Resources/LaunchScreen.storyboard` (wired by `UILaunchStoryboardName` in `project.yml`) draws
`LaunchBus` at a fixed 140×140 pt over `LaunchBackground`: a white bus on brand blue `#3E7FE8` in
light, a `#3E7FE8` bus on black in dark. Four things about it are load-bearing:

- **Storyboard, not the `UILaunchScreen` plist dict.** `UILaunchScreen.UIImageName` renders the
  image full-bleed aspect-fit; only the storyboard can pin the glyph size.
- **Both variants come from appearance-qualified assets**, since a storyboard cannot express an
  adaptive literal colour: `LaunchBackground.colorset` and `LaunchBus.imageset` each carry a
  `luminosity: dark` entry. The storyboard also archives a fallback colour for the named colour —
  keep it in step with the colorset's light value.
- `LaunchBus` sets `template-rendering-intent: original`. The light glyph is pure white, which the
  catalog compiles to a greyscale mask; without that key it is treated as a template and tinted
  system blue.
- The PNGs are rendered from `AppIcon.icon/Assets/Bus.svg` (recoloured for the dark variant) with
  the icon's padding cropped off, at 140/280/420 px.

**Verifying it is painful and misleading — read this before debugging a wrong-looking launch
screen.** SpringBoard rejects the launch storyboard of an unsigned build (`make build` passes
`CODE_SIGNING_ALLOWED=NO`) and shows plain black instead — the log says
`Resource validation error: Security error -67056`. Worse, a simulator caches an app's launch
assets by bundle id in a way that survives uninstall, reinstall and `CFBundleVersion` bumps, so a
simulator that ran an older build keeps painting the *old* colours forever. To actually see a
change:

```sh
codesign --force --deep --sign - build/Build/Products/Debug-iphonesimulator/KremenTransport.app
xcrun simctl create LaunchProbe "iPhone 17 Pro"   # a device that has never seen the app
```

then boot it, install, launch, and screenshot in a tight loop (`xcrun simctl io <id> screenshot`) —
the launch screen is on screen for well under a second. Delete the probe device afterwards. To hold
the launch screen still, add a temporary `Thread.sleep` to `KremenTransportApp.init()`.

## Tests

`Tests/Fixtures/*.sample.json` are real payloads captured from the live API. `DecodingTests`
asserts against their actual shape (38 routes, 319 vehicles, the 1994→433 stop fold), so an
upstream shape change fails here rather than on a user's map. Refresh a fixture by re-fetching the
endpoint and updating the counts.

## Codex config detected

There is an OpenAI Codex config at `~/.codex/config.toml`. If you want its MCP servers, prompts
or instructions brought over, reply `/import` to see what's importable, then
`/import --yes=<digest>` to apply it. (If `/import` isn't available on this surface, run
`claude import` from a terminal.)
