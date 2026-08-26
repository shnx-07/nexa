#!/usr/bin/env python3

import json
import re
from pathlib import Path


SOURCE_DIR = Path.home() / ".config/matugen/presets-qml"
OUTPUT_DIR = Path.home() / ".config/matugen/presets"


COLOR_PATTERN = re.compile(
    r'readonly\s+property\s+color\s+'
    r'([A-Za-z_][A-Za-z0-9_]*)'
    r'\s*:\s*'
    r'["\'](#[0-9A-Fa-f]{6,8})["\']'
)


def camel_to_snake(name: str) -> str:
    # surfaceContainerHigh -> surface_container_high
    # inverseSurface       -> inverse_surface
    # on_primary           -> on_primary

    name = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)
    name = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", name)

    return name.lower()


def extract_colors(path: Path) -> dict[str, str]:
    content = path.read_text(encoding="utf-8")

    colors = {}

    for property_name, value in COLOR_PATTERN.findall(content):
        colors[camel_to_snake(property_name)] = value.lower()

    return colors


def make_metadata(relative_path: Path) -> dict:
    parts = relative_path.parts

    # First directory is always the category.
    #
    # ColdArctic/Abyss/Dark.qml -> ColdArctic
    # extras/Foo.qml            -> extras
    category = parts[0] if len(parts) > 1 else "uncategorized"

    stem = relative_path.stem

    # Standard paired presets:
    #
    # Abyss/Dark.qml
    # Abyss/Light.qml
    if stem.lower() in ("dark", "light"):
        variant = stem.lower()

        if len(parts) >= 2:
            name = relative_path.parent.name
        else:
            name = stem

    # Extras or any other non-paired preset.
    else:
        name = stem
        variant = None

    preset_id = relative_path.with_suffix("").as_posix()

    return {
        "id": preset_id,
        "category": category,
        "name": name,
        "variant": variant,
    }

def hex_to_rgb(hex_color: str) -> str:
    value = hex_color.lstrip("#")

    if len(value) < 6:
        raise ValueError(f"Invalid hex color: {hex_color}")

    r = int(value[0:2], 16)
    g = int(value[2:4], 16)
    b = int(value[4:6], 16)

    return f"{r},{g},{b}"


def convert_file(path: Path) -> bool:
    relative_path = path.relative_to(SOURCE_DIR)

    colors = extract_colors(path)

    rgb = {
        key: hex_to_rgb(value)
        for key, value in colors.items()
    }

    if not colors:
        print(f"[SKIP] {relative_path}: no color properties found")
        return False

    metadata = make_metadata(relative_path)

    output_path = OUTPUT_DIR / relative_path.with_suffix(".json")
    output_path.parent.mkdir(parents=True, exist_ok=True)

    data = {
        "meta": metadata,
        "colors": colors,
        "rgb": rgb,
    }
    output_path.write_text(
        json.dumps(data, indent=2) + "\n",
        encoding="utf-8",
    )

    variant = metadata["variant"] or "-"

    print(
        f"[OK] {relative_path} "
        f"-> {output_path.relative_to(OUTPUT_DIR)} "
        f"| {len(colors)} colors "
        f"| variant={variant}"
    )

    return True


def main():
    print()
    print("NEXA QML preset -> JSON converter")
    print("=================================")

    if not SOURCE_DIR.exists():
        print()
        print("ERROR: source directory does not exist:")
        print(SOURCE_DIR)
        raise SystemExit(1)

    files = sorted(SOURCE_DIR.rglob("*.qml"))

    if not files:
        print()
        print("ERROR: no QML files found.")
        raise SystemExit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Source : {SOURCE_DIR}")
    print(f"Output : {OUTPUT_DIR}")
    print(f"Found  : {len(files)} QML presets")
    print()

    converted = 0
    skipped = 0
    errors = 0

    color_counts = {}

    for path in files:
        try:
            colors = extract_colors(path)

            if not colors:
                relative = path.relative_to(SOURCE_DIR)
                print(f"[SKIP] {relative}: no colors found")
                skipped += 1
                continue

            count = len(colors)
            color_counts[count] = color_counts.get(count, 0) + 1

            if convert_file(path):
                converted += 1

        except Exception as error:
            relative = path.relative_to(SOURCE_DIR)
            print(f"[ERROR] {relative}: {error}")
            errors += 1

    print()
    print("=================================")
    print(f"Converted : {converted}")
    print(f"Skipped   : {skipped}")
    print(f"Errors    : {errors}")
    print(f"Total     : {len(files)}")

    print()
    print("Color field counts:")

    for count in sorted(color_counts):
        print(f"  {count:>3} colors : {color_counts[count]} preset(s)")

    print()

    if errors:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
