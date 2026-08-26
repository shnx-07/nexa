#!/usr/bin/env bash

set -u

# NEXA theme dispatcher
# ---------------------
# NEXA owns theme state and source selection only.
# Matugen owns presets, templates, application outputs, and rendering.

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nexa"
THEME_CACHE="$CACHE_DIR/theme"
STATE_FILE="$CACHE_DIR/theme.state"
LOG_FILE="$CACHE_DIR/theme.log"
PALETTE_FILE="$THEME_CACHE/palette"

NEXA_CONFIG_DIR="$HOME/.config/nexa/config"
THEME_CONFIG="$NEXA_CONFIG_DIR/theme.conf"
WALLPAPER_CONFIG="$NEXA_CONFIG_DIR/wallpaper.conf"

MATUGEN_DIR="$HOME/.config/matugen"
MATUGEN_CONFIG="$MATUGEN_DIR/config.toml"
MATUGEN_EXPORT_CONFIG="$MATUGEN_DIR/config-export.toml"
PRESET_ROOT="$MATUGEN_DIR/presets"
CANONICAL_CONVERTER="$HOME/.config/nexa/scripts/wallpaper-json-to-canonical.py"

mkdir -p "$THEME_CACHE" "$NEXA_CONFIG_DIR"

log() {
  printf '[NEXA theme] %s\n' "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "$*"
  exit 1
}

require_runtime() {
  command -v matugen >/dev/null 2>&1 || fail "Matugen is not installed."
  command -v python3 >/dev/null 2>&1 || fail "python3 is not installed."

  [[ -f "$MATUGEN_CONFIG" ]] ||
    fail "Matugen config not found: $MATUGEN_CONFIG"

  [[ -d "$PRESET_ROOT" ]] ||
    fail "Matugen preset directory not found: $PRESET_ROOT"
}

# -----------------------------------------------------------------------------
# Persistent state
# -----------------------------------------------------------------------------

if [[ ! -f "$THEME_CONFIG" ]]; then
  cat >"$THEME_CONFIG" <<'STATE'
STYLE="wallpaperFull"
PRESET="extras/CatppuccinMacchiato"
MODE="dark"
STATE
fi

load_theme_config() {
  STYLE="wallpaperFull"
  PRESET="extras/CatppuccinMacchiato"
  MODE="dark"

  # shellcheck disable=SC1090
  source "$THEME_CONFIG"
}

save_theme_config() {
  cat >"$THEME_CONFIG" <<STATE
STYLE="$STYLE"
PRESET="$PRESET"
MODE="$MODE"
STATE
}

valid_style() {
  case "$1" in
  preset | wallpaperAccents | wallpaperFull)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

valid_mode() {
  case "$1" in
  dark | light)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

set_gtk_color_preference() {
  local mode="$1"
  local prefer_dark=1

  [[ "$mode" == "light" ]] && prefer_dark=0

  local gtk3_settings="$HOME/.config/gtk-3.0/settings.ini"

  if [[ -f "$gtk3_settings" ]]; then
    if grep -q '^gtk-application-prefer-dark-theme=' "$gtk3_settings"; then
      sed -i \
        "s/^gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=$prefer_dark/" \
        "$gtk3_settings"
    else
      printf '\ngtk-application-prefer-dark-theme=%s\n' \
        "$prefer_dark" >>"$gtk3_settings"
    fi
  fi

  log "GTK dark preference set to: $prefer_dark"
}

# -----------------------------------------------------------------------------
# Dynamic Matugen preset discovery
# -----------------------------------------------------------------------------

resolve_preset() {
  local requested="$1"
  local mode="$2"

  PRESET_ROOT="$PRESET_ROOT" \
    REQUESTED="$requested" \
    REQUESTED_MODE="$mode" \
    python3 <<'PY'
import json
import os
import re
import sys
from pathlib import Path

root = Path(os.environ["PRESET_ROOT"]).expanduser()
requested = os.environ["REQUESTED"].strip().replace("\\", "/")
mode = os.environ["REQUESTED_MODE"].strip().lower()

variant_filename = "Light" if mode == "light" else "Dark"


def norm(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def emit(path: Path):
    print(path)
    raise SystemExit(0)


raw = requested[:-5] if requested.lower().endswith(".json") else requested

# -------------------------------------------------------------------------
# Exact lookups first
# -------------------------------------------------------------------------

exact_candidates = [
    root / raw,
    root / f"{raw}.json",
    root / raw / f"{variant_filename}.json",
]

for path in exact_candidates:
    if path.is_file():
        emit(path)

# -------------------------------------------------------------------------
# Legacy-friendly extras lookup
#
# Example:
#   "ocean"
# resolves to:
#   presets/extras/Ocean.json
#
# No preset names are hardcoded.
# -------------------------------------------------------------------------

extras = root / "extras"

if extras.is_dir():
    for path in sorted(extras.glob("*.json")):
        if norm(path.stem) == norm(raw):
            emit(path)

# -------------------------------------------------------------------------
# Search entire library dynamically
# -------------------------------------------------------------------------

matches = []

for path in sorted(root.rglob("*.json")):
    relative_path = path.relative_to(root)

    rel = relative_path.with_suffix("").as_posix()

    # Dark.json / Light.json are variants ONLY for paths shaped like:
    #
    #   Category/Theme/Dark.json
    #   Category/Theme/Light.json
    #
    # These are NOT variants:
    #
    #   extras/Dark.json
    #   extras/Light.json
    #
    is_paired_variant = (
        path.stem.lower() in ("dark", "light")
        and len(relative_path.parts) >= 3
    )

    rel_no_variant = rel

    if is_paired_variant:
        rel_no_variant = path.parent.relative_to(root).as_posix()

    candidates = {
        rel,
        rel_no_variant,
        path.stem,
        path.parent.name,
    }

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        data = {}

    meta = data.get("meta", {}) if isinstance(data, dict) else {}

    for key in ("id", "name"):
        value = meta.get(key)

        if isinstance(value, str) and value:
            candidates.add(value)

    if any(norm(candidate) == norm(raw) for candidate in candidates):

        if is_paired_variant and path.stem.lower() != mode:
            continue

        matches.append(path)

if len(matches) == 1:
    emit(matches[0])

if not matches:
    print(f"Preset not found: {requested}", file=sys.stderr)
else:
    print(f"Preset is ambiguous: {requested}", file=sys.stderr)

    for path in matches[:20]:
        print(f"  {path.relative_to(root)}", file=sys.stderr)

raise SystemExit(1)
PY
}

preset_id_from_path() {
  local preset_path="$1"

  PRESET_ROOT="$PRESET_ROOT" \
    PRESET_PATH="$preset_path" \
    python3 <<'PY'
import os
from pathlib import Path

root = Path(os.environ["PRESET_ROOT"]).expanduser().resolve()
path = Path(os.environ["PRESET_PATH"]).expanduser().resolve()

rel = path.relative_to(root)

is_paired_variant = (
    path.stem.lower() in ("dark", "light")
    and len(rel.parts) >= 3
)

if is_paired_variant:
    print(path.parent.relative_to(root).as_posix())
else:
    print(rel.with_suffix("").as_posix())
PY
}

list_presets_json() {
  PRESET_ROOT="$PRESET_ROOT" python3 <<'PY'
import json
import os
from pathlib import Path


root = Path(
    os.environ["PRESET_ROOT"]
).expanduser()

entries = {}


def preview_colors(data):
    if not isinstance(data, dict):
        return None

    colors = data.get("colors")

    if not isinstance(colors, dict):
        return None

    primary = colors.get("primary")
    secondary = colors.get("secondary")
    tertiary = colors.get("tertiary")

    if not all(
        isinstance(value, str) and value
        for value in (
            primary,
            secondary,
            tertiary,
        )
    ):
        return None

    return [
        primary,
        secondary,
        tertiary,
    ]


for path in sorted(
    root.rglob("*.json")
):
    relative_path = path.relative_to(root)

    try:
        data = json.loads(
            path.read_text(
                encoding="utf-8"
            )
        )

        meta = (
            data.get("meta", {})
            if isinstance(data, dict)
            else {}
        )

    except Exception:
        data = {}
        meta = {}


    is_paired_variant = (
        path.stem.lower()
        in (
            "dark",
            "light",
        )
        and len(relative_path.parts) >= 3
    )


    if is_paired_variant:

        # Example:
        #
        # CyberTech/Synthwave/Dark.json
        #
        # preset id:
        # CyberTech/Synthwave

        preset_id = (
            path.parent
            .relative_to(root)
            .as_posix()
        )

        category = str(
            meta.get("category")
            or relative_path.parts[0]
        )

        name = str(
            meta.get("name")
            or path.parent.name
        )

        variant = (
            path.stem.lower()
        )

        preview_key = variant

    else:

        # Examples:
        #
        # extras/Ocean.json
        # extras/Dark.json
        # extras/Light.json

        preset_id = (
            relative_path
            .with_suffix("")
            .as_posix()
        )

        category = str(
            meta.get("category")
            or (
                relative_path.parts[0]
                if len(relative_path.parts) > 1
                else "uncategorized"
            )
        )

        name = str(
            meta.get("name")
            or path.stem
        )

        meta_variant = (
            meta.get("variant")
        )

        variant = (
            str(meta_variant).lower()
            if isinstance(
                meta_variant,
                str
            )
            and meta_variant
            else None
        )

        preview_key = (
            variant
            if variant in (
                "dark",
                "light",
            )
            else "default"
        )


    item = entries.setdefault(
        preset_id,
        {
            "id": preset_id,
            "category": category,
            "name": name,
            "variants": [],
            "previews": {},
        },
    )


    if (
        variant
        and variant
        not in item["variants"]
    ):
        item["variants"].append(
            variant
        )


    preview = preview_colors(data)

    if preview:
        item["previews"][
            preview_key
        ] = preview


for item in entries.values():

    item["variants"].sort(
        key=lambda value: (
            value != "dark",
            value != "light",
            value,
        )
    )


result = sorted(
    entries.values(),
    key=lambda item: (
        item["category"].lower(),
        item["name"].lower(),
    ),
)


print(
    json.dumps(
        result,
        indent=2,
    )
)
PY
}

list_presets_text() {
  list_presets_json |
    python3 -c '
import json
import sys

for item in json.load(sys.stdin):
    print(item["id"])
'
}

# -----------------------------------------------------------------------------
# Canonical rendering
# -----------------------------------------------------------------------------

validate_canonical_json() {
  local file="$1"

  python3 - "$file" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])

data = json.loads(
    path.read_text(encoding="utf-8")
)

colors = data.get("colors")
rgb = data.get("rgb")

if not isinstance(colors, dict):
    raise SystemExit(
        "canonical JSON must contain colors{}"
    )

if not isinstance(rgb, dict):
    raise SystemExit(
        "canonical JSON must contain rgb{}"
    )

required = [
    "primary",
    "on_primary",
    "primary_container",
    "on_primary_container",

    "secondary",
    "on_secondary",
    "secondary_container",
    "on_secondary_container",

    "tertiary",
    "on_tertiary",
    "tertiary_container",
    "on_tertiary_container",

    "background",
    "on_background",

    "surface",
    "surface_dim",
    "surface_bright",

    "surface_container_low",
    "surface_container",
    "surface_container_high",
    "surface_container_highest",

    "on_surface",
    "on_surface_variant",

    "outline",
    "outline_variant",
    "shadow",

    "error",
    "on_error",
    "error_container",

    "success",
    "on_success",

    "warning",
    "on_warning",

    "info",
    "on_info",
]

missing = [
    key
    for key in required
    if not colors.get(key)
]

if missing:
    raise SystemExit(
        "missing canonical colors: "
        + ", ".join(missing)
    )
PY
}

render_canonical() {
  local canonical_json="$1"

  validate_canonical_json "$canonical_json" || {
    log "Canonical theme validation failed: $canonical_json"
    return 1
  }

  log "Rendering canonical theme: $canonical_json"

  if ! matugen \
    -c "$MATUGEN_CONFIG" \
    json "$canonical_json" \
    >>"$LOG_FILE" 2>&1; then

    log "Matugen canonical rendering failed."
    return 1
  fi

  if [[ ! -f "$PALETTE_FILE" ]]; then
    log "Canonical palette output was not generated: $PALETTE_FILE"
    return 1
  fi

  return 0
}

render_preset() {
  local requested="$1"
  local mode="$2"

  local preset_json

  preset_json="$(
    resolve_preset "$requested" "$mode"
  )" || return 1

  log "Preset source: $preset_json"

  render_canonical "$preset_json"
}

# -----------------------------------------------------------------------------
# Matugen wallpaper/color -> canonical JSON
# -----------------------------------------------------------------------------

generate_matugen_canonical() {
  local source_type="$1"
  local source="$2"
  local mode="$3"
  local tag="$4"

  local raw_json="$THEME_CACHE/${tag}-matugen.json"
  local canonical_json="$THEME_CACHE/${tag}-canonical.json"

  if [[ ! -f "$MATUGEN_EXPORT_CONFIG" ]]; then
    log "Matugen export config not found: $MATUGEN_EXPORT_CONFIG"
    return 1
  fi

  if [[ ! -x "$CANONICAL_CONVERTER" ]]; then
    log "Wallpaper canonical converter is missing or not executable:"
    log "$CANONICAL_CONVERTER"
    return 1
  fi

  case "$source_type" in

  image)

    if ! matugen \
      -c "$MATUGEN_EXPORT_CONFIG" \
      image "$source" \
      --source-color-index 0 \
      -m "$mode" \
      --json hex \
      >"$raw_json" \
      2>>"$LOG_FILE"; then

      log "Matugen image JSON generation failed."
      return 1
    fi
    ;;

  color)

    source="${source#\#}"

    if [[ ! "$source" =~ ^[0-9A-Fa-f]{6}$ ]]; then
      log "Invalid color: #$source"
      return 1
    fi

    if ! matugen \
      -c "$MATUGEN_EXPORT_CONFIG" \
      color hex "$source" \
      -m "$mode" \
      --json hex \
      >"$raw_json" \
      2>>"$LOG_FILE"; then

      log "Matugen color JSON generation failed."
      return 1
    fi
    ;;

  *)

    log "Unsupported Matugen source type: $source_type"
    return 1
    ;;

  esac

  if ! "$CANONICAL_CONVERTER" \
    "$raw_json" \
    "$canonical_json" \
    >>"$LOG_FILE" 2>&1; then

    log "Matugen JSON -> canonical JSON conversion failed."
    return 1
  fi

  printf '%s\n' "$canonical_json"
}

# -----------------------------------------------------------------------------
# Wallpaper source
# -----------------------------------------------------------------------------

load_wallpaper_config() {
  WALLPAPER=""
  WALLPAPER_TYPE=""
  THEME_SOURCE=""
  MONITOR="*"

  if [[ -f "$WALLPAPER_CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$WALLPAPER_CONFIG"
  fi
}

get_theme_source() {
  if [[ -n "${THEME_SOURCE:-}" && -f "$THEME_SOURCE" ]]; then
    printf '%s\n' "$THEME_SOURCE"
    return 0
  fi

  if [[ -n "${WALLPAPER:-}" && -f "$WALLPAPER" ]]; then
    printf '%s\n' "$WALLPAPER"
    return 0
  fi

  return 1
}

# -----------------------------------------------------------------------------
# Wallpaper full
# -----------------------------------------------------------------------------

apply_wallpaper_full() {
  load_wallpaper_config

  local theme_source
  local canonical_json

  theme_source="$(get_theme_source)" || {
    log "No usable wallpaper theme source."
    return 1
  }

  log "Generating full wallpaper theme from: $theme_source"

  canonical_json="$(
    generate_matugen_canonical \
      image \
      "$theme_source" \
      "$MODE" \
      wallpaper
  )" || return 1

  render_canonical "$canonical_json"
}

# -----------------------------------------------------------------------------
# Wallpaper accents
# -----------------------------------------------------------------------------

apply_wallpaper_accents() {
  load_wallpaper_config

  local theme_source
  local preset_json
  local wallpaper_json
  local merged_json

  theme_source="$(get_theme_source)" || {
    log "No usable wallpaper theme source."
    return 1
  }

  preset_json="$(
    resolve_preset "$PRESET" "$MODE"
  )" || return 1

  wallpaper_json="$(
    generate_matugen_canonical \
      image \
      "$theme_source" \
      "$MODE" \
      wallpaper-accents
  )" || return 1

  merged_json="$THEME_CACHE/wallpaper-accents-canonical.json"

  python3 \
    - "$preset_json" \
    "$wallpaper_json" \
    "$merged_json" <<'PY'
import json
import sys
from pathlib import Path

base_path = Path(sys.argv[1])
wallpaper_path = Path(sys.argv[2])
output_path = Path(sys.argv[3])

base = json.loads(
    base_path.read_text(encoding="utf-8")
)

wallpaper = json.loads(
    wallpaper_path.read_text(encoding="utf-8")
)

roles = [
    "primary",
    "on_primary",
    "primary_container",
    "on_primary_container",

    "secondary",
    "on_secondary",
    "secondary_container",
    "on_secondary_container",

    "tertiary",
    "on_tertiary",
    "tertiary_container",
    "on_tertiary_container",
]

for role in roles:
    base["colors"][role] = wallpaper["colors"][role]
    base["rgb"][role] = wallpaper["rgb"][role]

meta = base.setdefault("meta", {})

meta["id"] = "wallpaper/accents"
meta["category"] = "wallpaper"
meta["name"] = "accents"

output_path.write_text(
    json.dumps(base, indent=2) + "\n",
    encoding="utf-8",
)
PY

  render_canonical "$merged_json"
}

# -----------------------------------------------------------------------------
# Public commands
# -----------------------------------------------------------------------------

COMMAND="${1:-}"

case "$COMMAND" in

style)

  NEW_STYLE="${2:-}"

  valid_style "$NEW_STYLE" ||
    fail "Invalid theme style: $NEW_STYLE"

  load_theme_config

  STYLE="$NEW_STYLE"

  save_theme_config

  log "Style set to: $STYLE"

  exit 0
  ;;

preset)

  NEW_PRESET="${2:-}"

  [[ -n "$NEW_PRESET" ]] ||
    fail "Usage: theme.sh preset <preset-id>"

  load_theme_config

  PRESET_PATH="$(
    resolve_preset "$NEW_PRESET" "$MODE"
  )" || exit 1

  PRESET="$(
    preset_id_from_path "$PRESET_PATH"
  )" || exit 1

  save_theme_config

  log "Preset set to: $PRESET"

  exit 0
  ;;

mode)

  NEW_MODE="${2:-}"

  valid_mode "$NEW_MODE" ||
    fail "Invalid mode: $NEW_MODE (expected dark or light)"

  load_theme_config

  MODE="$NEW_MODE"

  save_theme_config

  log "Mode set to: $MODE"

  exit 0
  ;;

status)

  load_theme_config

  printf \
    'NEXA Theme\n----------\nStyle  : %s\nPreset : %s\nMode   : %s\n' \
    "$STYLE" \
    "$PRESET" \
    "$MODE"

  load_wallpaper_config

  printf \
    'Wallpaper: %s\n' \
    "${WALLPAPER:-none}"

  exit 0
  ;;

presets)

  require_runtime

  list_presets_text

  exit 0
  ;;

presets-json)

  require_runtime

  list_presets_json

  exit 0
  ;;

apply)

  require_runtime

  load_theme_config

  valid_style "$STYLE" ||
    fail "Invalid saved style: $STYLE"

  valid_mode "$MODE" ||
    fail "Invalid saved mode: $MODE"

  set_gtk_color_preference "$MODE"

  log "Applying theme: style=$STYLE preset=$PRESET mode=$MODE"

  case "$STYLE" in

  preset)

    render_preset \
      "$PRESET" \
      "$MODE" ||
      exit 1
    ;;

  wallpaperAccents)

    apply_wallpaper_accents ||
      exit 1
    ;;

  wallpaperFull)

    apply_wallpaper_full ||
      exit 1
    ;;

  esac

  cat >"$STATE_FILE" <<STATE
style=$STYLE
preset=$PRESET
mode=$MODE
STATE

  log "Theme applied successfully."

  exit 0
  ;;

image)

  require_runtime

  SOURCE="${2:-}"
  MODE_ARG="${3:-dark}"

  [[ -n "$SOURCE" ]] ||
    fail "Usage: theme.sh image <path> [dark|light]"

  valid_mode "$MODE_ARG" ||
    fail "Invalid mode: $MODE_ARG"

  SOURCE="${SOURCE/#\~\//$HOME/}"

  [[ -f "$SOURCE" ]] ||
    fail "Theme image does not exist: $SOURCE"

  canonical="$(
    generate_matugen_canonical \
      image \
      "$SOURCE" \
      "$MODE_ARG" \
      direct-image
  )" || exit 1

  set_gtk_color_preference "$MODE_ARG"

  render_canonical "$canonical" ||
    exit 1

  log "Theme generated successfully from image."

  exit 0
  ;;

color)

  require_runtime

  SOURCE="${2:-}"
  MODE_ARG="${3:-dark}"

  [[ -n "$SOURCE" ]] ||
    fail "Usage: theme.sh color <hex> [dark|light]"

  valid_mode "$MODE_ARG" ||
    fail "Invalid mode: $MODE_ARG"

  canonical="$(
    generate_matugen_canonical \
      color \
      "$SOURCE" \
      "$MODE_ARG" \
      direct-color
  )" || exit 1

  set_gtk_color_preference "$MODE_ARG"

  render_canonical "$canonical" ||
    exit 1

  log "Theme generated successfully from color."

  exit 0
  ;;

*)

  cat <<'USAGE'
Usage:

  theme.sh apply

  theme.sh style preset
  theme.sh style wallpaperAccents
  theme.sh style wallpaperFull

  theme.sh preset <dynamic-preset-id>

  theme.sh mode dark
  theme.sh mode light

  theme.sh status

  theme.sh presets
  theme.sh presets-json

  theme.sh image <path> [dark|light]
  theme.sh color <hex> [dark|light]
USAGE

  exit 1
  ;;

esac
