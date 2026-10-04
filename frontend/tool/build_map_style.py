"""Builds assets/maps/khojlo_style.json: OpenFreeMap's "Positron" style in Khojlo's palette.

Positron is a quiet base map with no points of interest, so Khojlo's own pins stand out.
This script only recolours it (same palette as the old Google `khojloMapStyle`) and hides
transit and road shields. Re-run it after changing a colour:

    python3 tool/build_map_style.py
"""

import json
import urllib.request
from pathlib import Path

BASE_STYLE = "https://tiles.openfreemap.org/styles/positron"
OUT = Path(__file__).resolve().parent.parent / "assets" / "maps" / "khojlo_style.json"

LAND = "#f3eee4"
TEXT = "#6e665b"
HALO = "#fbf6ee"

# Layer id → paint values to set.
PAINT = {
    "background": {"background-color": LAND},
    "park": {"fill-color": "#dfe8d6"},
    "water": {"fill-color": "#c5dfd8"},
    "landuse_residential": {"fill-color": "#efe8db"},
    "landcover_wood": {"fill-color": "#e4e6d3"},
    "waterway": {"line-color": "#b5d3cb"},
    "building": {"fill-color": "#ebe3d5", "fill-outline-color": "#dfd5c4"},
    "tunnel_motorway_casing": {"line-color": "#eadbbd"},
    "tunnel_motorway_inner": {"line-color": "#f8ecd2"},
    "aeroway-taxiway": {"line-color": "#e6dccb"},
    "aeroway-runway-casing": {"line-color": "#e6dccb"},
    "aeroway-area": {"fill-color": "#ebe4d6"},
    "aeroway-runway": {"line-color": HALO},
    "road_area_pier": {"fill-color": LAND},
    "road_pier": {"line-color": LAND},
    "highway_path": {"line-color": "#e9e0d0"},
    "highway_minor": {"line-color": "#ffffff"},
    "highway_major_casing": {"line-color": "#e4dacb"},
    "highway_major_inner": {"line-color": "#ffffff"},
    "highway_major_subtle": {"line-color": "rgba(255,255,255,0.75)"},
    "highway_motorway_casing": {"line-color": "#e8cf9a"},
    "highway_motorway_inner": {
        "line-color": ["interpolate", ["linear"], ["zoom"], 5.8, "rgba(246,226,184,0.6)", 6, "#f6e2b8"]
    },
    "highway_motorway_subtle": {"line-color": "rgba(246,226,184,0.6)"},
    "highway_motorway_bridge_casing": {"line-color": "#e8cf9a"},
    "highway_motorway_bridge_inner": {
        "line-color": ["interpolate", ["linear"], ["zoom"], 5.8, "rgba(246,226,184,0.6)", 6, "#f6e2b8"]
    },
    "boundary_3": {"line-color": "#d9cfbf"},
    "boundary_2": {"line-color": "#d9cfbf"},
    "boundary_disputed": {"line-color": "#d9cfbf"},
    "waterway_line_label": {"text-color": "#7fa59b", "text-halo-color": HALO},
    "water_name_point_label": {"text-color": "#5f8a80", "text-halo-color": HALO},
    "water_name_line_label": {"text-color": "#5f8a80", "text-halo-color": HALO},
    "highway-name-path": {"text-color": "#a39a8c", "text-halo-color": HALO},
    "highway-name-minor": {"text-color": "#8a8174", "text-halo-color": HALO},
    "highway-name-major": {"text-color": "#8a8174", "text-halo-color": HALO},
    "airport": {"text-color": "#8a8174", "text-halo-color": HALO},
    "label_other": {"text-color": TEXT, "text-halo-color": HALO},
    "label_village": {"text-color": TEXT, "text-halo-color": HALO},
    "label_town": {"text-color": "#544d44", "text-halo-color": HALO},
    "label_state": {"text-color": TEXT, "text-halo-color": HALO},
    "label_city": {"text-color": "#3f3a33", "text-halo-color": HALO},
    "label_city_capital": {"text-color": "#3f3a33", "text-halo-color": HALO},
    "label_country_3": {"text-color": "#544d44", "text-halo-color": HALO},
    "label_country_2": {"text-color": "#544d44", "text-halo-color": HALO},
    "label_country_1": {"text-color": "#544d44", "text-halo-color": HALO},
}

LATIN_NAME = ["coalesce", ["get", "name:latin"], ["get", "name_en"], ["get", "name"]]

# Hidden, as in the old Google style: transit, and US-style road shields.
HIDDEN_PREFIXES = ("railway", "highway-shield", "road_shield")


def main() -> None:
    request = urllib.request.Request(BASE_STYLE, headers={"User-Agent": "khojlo-style-build/1.0"})
    with urllib.request.urlopen(request) as response:
        style = json.load(response)

    style["name"] = "Khojlo"
    # Only the vector tiles are used; drop the unused shaded-relief raster.
    style["sources"] = {"openmaptiles": style["sources"]["openmaptiles"]}

    seen = set()
    for layer in style["layers"]:
        layer_id = layer["id"]
        if layer_id in PAINT:
            layer.setdefault("paint", {}).update(PAINT[layer_id])
            seen.add(layer_id)
        if layer_id.startswith(HIDDEN_PREFIXES):
            layer.setdefault("layout", {})["visibility"] = "none"
        # One name per place, in Latin script (Positron prints "Jinnah Avenue جناح ایونیو").
        layout = layer.get("layout", {})
        if isinstance(layout.get("text-field"), list) and layout["text-field"][0] == "case":
            layout["text-field"] = LATIN_NAME
        if layer["type"] == "symbol" and "text-halo-color" in layer.get("paint", {}):
            layer["paint"]["text-halo-width"] = max(layer["paint"].get("text-halo-width", 1), 1.2)

    missing = sorted(set(PAINT) - seen)
    if missing:
        raise SystemExit(f"Positron no longer has these layers; update PAINT: {missing}")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(style, separators=(",", ":")) + "\n")
    print(f"Wrote {OUT} ({OUT.stat().st_size // 1024} KB, {len(style['layers'])} layers)")


if __name__ == "__main__":
    main()
