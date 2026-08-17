#!/usr/bin/env python3
"""Build the payloads that `-fixtures` serves, from the real captures in Tests/Fixtures.

App Store screenshots have to be reproducible: the Ukrainian and English capture of one screen
must show the same buses in the same places and the same arrivals, or the pair looks sloppy on
the store page. Live polling cannot give that, so the screenshot run reads these files instead.

Routes, roster and positions stay real and self-consistent (the roster and the positions come
from the same capture, and `VehicleFeed.loadPositions` only moves vehicles it already knows),
with one cosmetic edit: buses of the *same* route sitting within THIN_METRES of each other are
dropped. Real rosters park a dozen vehicles at a terminus, and `VehicleMarker` draws each as a
route badge, so the capture came out with a stack of overlapping "2" pills covering the map.
Thinning is per route — two different routes meeting at a junction is meaningful and is kept.
Each route's `active` count is recomputed to match, so the picker's "N в русі" agrees with the
number of pins actually on the map.

Only the arrivals are rebuilt, because the captured ones cannot render:

  * all four are `reverse: true`, so `StationSheet` would draw one direction section, not two;
  * they are on rids 4/9/11/14, none of which is in the selection we feature, and
    `StationSheet.visible` filters to the selected routes — the sheet would show "Немає прогнозів";
  * every one has `speed: -1`, which makes `subtitle(for:)` drop the speed half of every row.

Timestamps are deliberately left stale. Nothing renders them: the connection chip reads
`VehicleFeed.lastUpdate`, which is `Date()` on fetch success, and `StationSheet.remaining()`
counts down from `feed.lastUpdate`, not from the payload's `generatedTime`.
"""

import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Tests" / "Fixtures"
OUT = ROOT / "build" / "screenshot-fixtures"

# «Центральний ринок» — a 25-route hub, and the stop the captured arrivals already cover.
STOP_SID = 305

# Minimum gap between two pins of one route. A route badge is ~44 pt wide, which at the 8000 m
# camera the map shot uses covers roughly this much ground.
THIN_METRES = 400

# Routes we put on the map and in the arrivals list. Every one is verified against
# routes.sample.json as genuinely serving STOP_SID, and each has a high `active` count so the
# map fills. Buses and trolleybuses are mixed so the picker's two sections both show.
FEATURED = {
    2: "17",
    6: "3-а",
    7: "15",
    14: "16",
    20: "Т 2",   # trolleybus
    27: "А 25",
}

# (rid, seconds away, metres away, km/h, reverse). Ordered so each direction section opens with
# an imminent arrival — `row` tints anything under 60 s in the accent colour.
ARRIVALS = [
    (7, 45, 260, 21, False),
    (2, 190, 1120, 24, False),
    (20, 415, 2380, 19, False),
    (27, 660, 3940, 27, False),
    (14, 80, 470, 18, True),
    (6, 305, 1780, 22, True),
    (2, 590, 3410, 25, True),
]


def metres(a, b) -> float:
    """Equirectangular approximation — plenty at city scale."""
    lat = math.radians((a["lat"] + b["lat"]) / 2)
    dx = math.radians(a["lng"] - b["lng"]) * math.cos(lat)
    dy = math.radians(a["lat"] - b["lat"])
    return math.hypot(dx, dy) * 6_371_000


def thin(buses: list) -> list:
    """Drop same-route vehicles that would draw as overlapping badges."""
    kept: list = []
    by_route: dict = {}
    for bus in buses:
        # Offline vehicles are not drawn unless `showOffline` is on, which it is not by default.
        if bus.get("offline"):
            kept.append(bus)
            continue
        near = by_route.setdefault(bus["rid"], [])
        if any(metres(bus, other) < THIN_METRES for other in near):
            continue
        near.append(bus)
        kept.append(bus)
    return kept


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    buses = thin(json.loads((SOURCE / "buses.sample.json").read_text()))
    tids = {b["tid"] for b in buses}
    (OUT / "buses.json").write_text(json.dumps(buses, ensure_ascii=False))

    # Positions must not name a vehicle the roster dropped: an unknown tid makes VehicleFeed
    # refetch the roster (see CLAUDE.md), which would be a pointless loop against a fixture.
    locations = json.loads((SOURCE / "locations.sample.json").read_text())
    locations = {tid: xy for tid, xy in locations.items() if tid in tids}
    (OUT / "locations.json").write_text(json.dumps(locations))

    routes = json.loads((SOURCE / "routes.sample.json").read_text())
    running = {}
    for bus in buses:
        if not bus.get("offline"):
            running[bus["rid"]] = running.get(bus["rid"], 0) + 1
    for route in routes:
        route["active"] = running.get(route["rid"], 0)
    (OUT / "routes.json").write_text(json.dumps(routes, ensure_ascii=False))

    template = json.loads((SOURCE / "prediction.sample.json").read_text())[0]
    predictions = []
    for rid, seconds, distance, speed, reverse in ARRIVALS:
        item = dict(template)
        item.update(
            rid=rid,
            sid=STOP_SID,
            prediction=seconds,
            distance=distance,
            speed=speed,
            avgSpeed=speed,
            reverse=reverse,
            # A tid per row, so nothing looks like the same vehicle arriving twice.
            tid=f"{int(template['tid']) + rid * 1000 + (1 if reverse else 0)}",
        )
        predictions.append(item)

    (OUT / "prediction.json").write_text(
        json.dumps(predictions, ensure_ascii=False, indent=1)
    )

    total = sum(f.stat().st_size for f in OUT.glob("*.json"))
    print(f"{OUT.relative_to(ROOT)}: 4 files, {total // 1024} KB")
    print(f"vehicles kept: {len(buses)}, of which running: {sum(running.values())}")
    featured = ", ".join(f"{n} ({running.get(r, 0)})" for r, n in FEATURED.items())
    print(f"featured routes (pins on the map): {featured}")


if __name__ == "__main__":
    main()
