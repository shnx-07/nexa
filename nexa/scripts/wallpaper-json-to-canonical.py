#!/usr/bin/env python3

import json
import sys
from pathlib import Path


def get_role(data: dict, role: str, *fallbacks: str) -> str:
    for key in (role, *fallbacks):
        entry = data.get("colors", {}).get(key)
        if not isinstance(entry, dict):
            continue

        preferred = entry.get("default") or entry.get("dark") or entry.get("light")
        if isinstance(preferred, dict) and "color" in preferred:
            return preferred["color"].lower()

    raise KeyError(f"Missing role: {role}")


def hex_to_rgb(hex_color: str) -> str:
    value = hex_color.lstrip("#")
    r = int(value[0:2], 16)
    g = int(value[2:4], 16)
    b = int(value[4:6], 16)
    return f"{r},{g},{b}"


def main():
    if len(sys.argv) != 3:
        print("Usage:")
        print("  wallpaper-json-to-canonical.py <input-json> <output-json>")
        raise SystemExit(1)

    input_path = Path(sys.argv[1]).expanduser()
    output_path = Path(sys.argv[2]).expanduser()

    data = json.loads(input_path.read_text(encoding="utf-8"))

    mode = str(data.get("mode", "dark")).lower()

    colors = {
        "primary": get_role(data, "primary"),
        "on_primary": get_role(data, "on_primary"),
        "primary_container": get_role(data, "primary_container"),
        "on_primary_container": get_role(data, "on_primary_container"),

        "secondary": get_role(data, "secondary"),
        "on_secondary": get_role(data, "on_secondary"),
        "secondary_container": get_role(data, "secondary_container"),
        "on_secondary_container": get_role(data, "on_secondary_container"),

        "tertiary": get_role(data, "tertiary"),
        "on_tertiary": get_role(data, "on_tertiary"),
        "tertiary_container": get_role(data, "tertiary_container"),
        "on_tertiary_container": get_role(data, "on_tertiary_container"),

        "background": get_role(data, "background"),
        "on_background": get_role(data, "on_background"),

        "surface": get_role(data, "surface"),
        "surface_dim": get_role(data, "surface_dim", "surface"),
        "surface_bright": get_role(data, "surface_bright", "surface_container_highest"),
        "surface_container_lowest": get_role(data, "surface_container_lowest", "surface_dim", "surface"),
        "surface_container_low": get_role(data, "surface_container_low", "surface"),
        "surface_container": get_role(data, "surface_container"),
        "surface_container_high": get_role(data, "surface_container_high", "surface_container"),
        "surface_container_highest": get_role(data, "surface_container_highest", "surface_container_high"),

        "on_surface": get_role(data, "on_surface"),
        "on_surface_variant": get_role(data, "on_surface_variant"),

        "inverse_surface": get_role(data, "inverse_surface"),
        "inverse_on_surface": get_role(data, "inverse_on_surface"),
        "inverse_primary": get_role(data, "inverse_primary"),

        "outline": get_role(data, "outline"),
        "outline_variant": get_role(data, "outline_variant"),
        "shadow": get_role(data, "shadow"),
        "scrim": get_role(data, "scrim", "shadow"),

        "error": get_role(data, "error"),
        "on_error": get_role(data, "on_error"),
        "error_container": get_role(data, "error_container"),
        "on_error_container": get_role(data, "on_error_container"),

        # Derived semantic additions for NEXA unified schema
        "success": get_role(data, "tertiary"),
        "on_success": get_role(data, "on_tertiary"),
        "success_container": get_role(data, "tertiary_container"),
        "on_success_container": get_role(data, "on_tertiary_container"),

        "warning": get_role(data, "secondary"),
        "on_warning": get_role(data, "on_secondary"),
        "warning_container": get_role(data, "secondary_container"),
        "on_warning_container": get_role(data, "on_secondary_container"),

        "info": get_role(data, "primary"),
        "on_info": get_role(data, "on_primary"),
        "info_container": get_role(data, "primary_container"),
        "on_info_container": get_role(data, "on_primary_container"),
    }

    rgb = {key: hex_to_rgb(value) for key, value in colors.items()}

    canonical = {
        "meta": {
            "id": f"wallpaper/generated/{mode}",
            "category": "wallpaper",
            "name": "generated",
            "variant": mode,
        },
        "colors": colors,
        "rgb": rgb,
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(canonical, indent=2) + "\n", encoding="utf-8")

    print(f"[OK] {input_path} -> {output_path}")
    print(f"[OK] mode={mode} colors={len(colors)}")


if __name__ == "__main__":
    main()
