#!/bin/bash
# App Store screenshots: 3 screens x 2 devices x 2 locales, into fastlane/screenshots/<locale>/.
#
# Simulator tap automation is unavailable here (see CLAUDE.md), so every screen is reached with
# the DEBUG launch arguments in App/Sources/App/DebugLaunch.swift instead. `-fixtures` pins the
# data so the uk and en-US capture of a screen come out pixel-comparable.
#
# Assumes `make build` has produced the Debug .app. Run via `make screenshots-gen`.
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE=dev.kremen.transport
APP=build/Build/Products/Debug-iphonesimulator/KremenTransport.app
FIXTURES=build/screenshot-fixtures
OUT=fastlane/screenshots

# App Store Connect wants the 6.9" iPhone and, since TARGETED_DEVICE_FAMILY is "1,2", the 13"
# iPad. It scales those down for every smaller device. Note the Makefile's SIM (iPhone 17 Pro)
# is 6.3" and would be rejected.
IPHONE="iPhone 17 Pro Max"   # 1320x2868
IPAD="iPad Pro 13-inch (M5)" # 2064x2752

# The routes on screen. All six genuinely serve stop 305 and all are busy; see
# Scripts/make_screenshot_fixtures.py.
ROUTES=2,6,7,14,20,27
STOP=305

# Camera framing, found by fitting the fixture's vehicle positions: this centre and height put
# 79 of the 104 running vehicles and all six routes on screen at once. Above ~9000 m MapDetail
# drops to .city and vehicle labels disappear, so this is near the useful ceiling.
MAP_CENTRE=49.0975,33.4216
MAP_DISTANCE=8000

# The stop sheet covers the lower half, so its map only needs context: this frames «Центральний
# ринок» just under the 3000 m threshold where MapDetail starts drawing stop pins.
STOP_CENTRE=49.0730,33.4200
STOP_DISTANCE=2900

# Seconds to wait after launch before capturing. The 565 KB routes payload has to decode and the
# first position poll has to land, or the connection chip is still red.
SETTLE=9

[ -d "$APP" ] || { echo "missing $APP — run 'make build' first" >&2; exit 1; }
# Always regenerate: a directory left over from an older generator would silently win.
python3 Scripts/make_screenshot_fixtures.py

shoot() {
  local device="$1" prefix="$2" locale_dir="$3" lang="$4" region="$5"

  local udid
  udid=$(xcrun simctl list devices available -j \
    | python3 -c "import json,sys;d=json.load(sys.stdin)['devices'];print(next(x['udid'] for v in d.values() for x in v if x['name']=='$device'))")

  echo "==> $device ($locale_dir)"
  # Erase so RouteCache is empty and SelectionStore falls back to defaults — a stale cache from
  # an earlier run would paint before the fixtures land.
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  xcrun simctl erase "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null

  xcrun simctl ui "$udid" appearance light
  xcrun simctl install "$udid" "$APP"

  # Fixtures go into the app container rather than the bundle: ~700 KB of sample JSON has no
  # business in the app target, and this way it cannot reach a Release build.
  local container
  container=$(xcrun simctl get_app_container "$udid" "$BUNDLE" data)
  mkdir -p "$container/Documents/ScreenshotFixtures"
  cp "$FIXTURES"/*.json "$container/Documents/ScreenshotFixtures/"

  xcrun simctl status_bar "$udid" override --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100

  mkdir -p "$OUT/$locale_dir"

  # A freshly erased device posts a "Ready for Apple Intelligence" banner over the top of the
  # screen. Burn one launch to let it appear and auto-dismiss — which also warms RouteCache, so
  # the real captures paint without waiting on the 565 KB decode.
  xcrun simctl launch "$udid" "$BUNDLE" -fixtures >/dev/null
  sleep 20

  capture() {
    local name="$1"; shift
    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$udid" "$BUNDLE" \
      -fixtures -selectRoutes "$ROUTES" \
      -AppleLanguages "($lang)" -AppleLocale "$region" "$@" >/dev/null
    sleep "$SETTLE"
    xcrun simctl io "$udid" screenshot --type=png "$OUT/$locale_dir/${prefix}_${name}.png" 2>/dev/null
    echo "    $locale_dir/${prefix}_${name}.png"
  }

  capture 1_map -cameraCenter "$MAP_CENTRE" -cameraDistance "$MAP_DISTANCE"
  capture 2_routes -openPicker
  capture 3_stop -openStop "$STOP" -stopDetent medium \
    -cameraCenter "$STOP_CENTRE" -cameraDistance "$STOP_DISTANCE"

  xcrun simctl shutdown "$udid"
}

for locale in "uk uk uk_UA" "en-US en en_US"; do
  # shellcheck disable=SC2086
  set -- $locale
  shoot "$IPHONE" iPhone69 "$1" "$2" "$3"
  shoot "$IPAD" iPad13 "$1" "$2" "$3"
done

echo
echo "done — $(find "$OUT" -name '*.png' | wc -l | tr -d ' ') screenshots in $OUT"
