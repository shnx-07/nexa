#!/usr/bin/env bash
# ==============================================================================
# NEXA Universal Shader Manager
# ==============================================================================
# Manage, build, and register substrate shaders dynamically without editing QML.
#
# Usage:
#   nexa_shader.sh list
#   nexa_shader.sh build [id]
#   nexa_shader.sh add <file.frag> [name] [subtitle] [icon]
#   nexa_shader.sh remove <id>
#   nexa_shader.sh set <id>
# ==============================================================================

set -e

SHADERS_DIR="$HOME/.config/nexa/quickshell/shaders/theme"
CONFIG_FILE="$HOME/.config/nexa/config/shaders.json"
QSB_BIN="/usr/lib/qt6/bin/qsb"

# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BOLD="\033[1m"
RESET="\033[0m"

mkdir -p "$SHADERS_DIR"
mkdir -p "$(dirname "$CONFIG_FILE")"

do_list() {
    echo -e "${BOLD}${CYAN}==> Registered NEXA Substrate Shaders:${RESET}"
    python3 -c '
import json
with open("'"$CONFIG_FILE"'", "r") as f:
    cfg = json.load(f)
active = cfg.get("active", "off")
presets = cfg.get("presets", {})
for k, v in presets.items():
    prefix = "  • \033[1;32m[ACTIVE]\033[0m" if k == active else "  •         "
    name = v.get("name", k)
    sub = v.get("subtitle", "")
    icon = v.get("icon", "󰄛")
    qsb = v.get("file", "")
    target_str = qsb if qsb else "(disabled/clean)"
    print(f"{prefix} \033[1m{k}\033[0m ({icon} {name} | {sub}) -> {target_str}")
'
}

do_build() {
    local target="$1"
    if [ ! -x "$QSB_BIN" ]; then
        echo -e "${RED}[ERROR] Qt Shader Baker ($QSB_BIN) not found.${RESET}"
        exit 1
    fi

    if [ -n "$target" ]; then
        local src=""
        if [ -f "$target" ]; then
            src="$target"
        elif [ -f "$SHADERS_DIR/$target" ]; then
            src="$SHADERS_DIR/$target"
        elif [ -f "$SHADERS_DIR/${target}.frag" ]; then
            src="$SHADERS_DIR/${target}.frag"
        fi

        if [ -z "$src" ] || [ ! -f "$src" ]; then
            echo -e "${RED}[ERROR] Shader source not found for: '$target'${RESET}"
            exit 1
        fi
        local dst="${src}.qsb"
        echo -e "${CYAN}Compiling $src -> $dst ...${RESET}"
        "$QSB_BIN" --qt6 -o "$dst" "$src"
        echo -e "${GREEN}[✔] Compiled: $dst${RESET}"
    else
        echo -e "${CYAN}==> Compiling all theme shaders in $SHADERS_DIR ...${RESET}"
        for frag in "$SHADERS_DIR"/*.frag; do
            if [ -f "$frag" ]; then
                dst="${frag}.qsb"
                echo -e "  Compiling $(basename "$frag") -> $(basename "$dst")"
                "$QSB_BIN" --qt6 -o "$dst" "$frag"
            fi
        done
        echo -e "${GREEN}[✔] All theme shaders compiled successfully.${RESET}"
    fi
}

do_add() {
    local raw_src="$1"
    local name="$2"
    local subtitle="$3"
    local icon="${4:-󰄛}"

    if [ -z "$raw_src" ]; then
        echo -e "${RED}Usage: nexa_shader.sh add <file.frag> [name] [subtitle] [icon]${RESET}"
        exit 1
    fi

    # Smart path search
    local resolved_src=""
    if [ -f "$raw_src" ]; then
        resolved_src="$raw_src"
    elif [ -f "$SHADERS_DIR/$raw_src" ]; then
        resolved_src="$SHADERS_DIR/$raw_src"
    elif [ -f "$SHADERS_DIR/${raw_src}.frag" ]; then
        resolved_src="$SHADERS_DIR/${raw_src}.frag"
    elif [ -f "$(pwd)/$raw_src" ]; then
        resolved_src="$(pwd)/$raw_src"
    elif [ -f "$(pwd)/${raw_src}.frag" ]; then
        resolved_src="$(pwd)/${raw_src}.frag"
    elif [ -f "$HOME/$raw_src" ]; then
        resolved_src="$HOME/$raw_src"
    fi

    if [ -z "$resolved_src" ] || [ ! -f "$resolved_src" ]; then
        echo -e "${RED}[ERROR] File not found: '$raw_src'${RESET}"
        echo -e "${YELLOW}Searched paths:${RESET}"
        echo "  • $(pwd)/$raw_src"
        echo "  • $SHADERS_DIR/$raw_src"
        echo "  • $SHADERS_DIR/${raw_src}.frag"
        exit 1
    fi

    # Clean up icon: fallback if dot, dash or blank
    if [ "$icon" = "." ] || [ "$icon" = "-" ] || [ -z "$icon" ]; then
        icon="󰄛"
    fi

    local base_name
    base_name=$(basename "$resolved_src" .frag)
    local target_frag="$SHADERS_DIR/${base_name}.frag"
    local target_qsb="$SHADERS_DIR/${base_name}.frag.qsb"
    local rel_qsb="theme/${base_name}.frag.qsb"

    if [ "$resolved_src" != "$target_frag" ]; then
        cp -f "$resolved_src" "$target_frag"
    fi

    echo -e "${CYAN}Compiling $base_name.frag with Qt Shader Baker...${RESET}"
    "$QSB_BIN" --qt6 -o "$target_qsb" "$target_frag"

    [ -z "$name" ] && name="${base_name//_/ }"
    [ -z "$subtitle" ] && subtitle="Custom GPU Shader"

    python3 -c '
import json
path = "'"$CONFIG_FILE"'"
with open(path, "r") as f:
    cfg = json.load(f)
if "presets" not in cfg:
    cfg["presets"] = {}
cfg["presets"]["'"$base_name"'"] = {
    "name": "'"$name"'",
    "subtitle": "'"$subtitle"'",
    "icon": "'"$icon"'",
    "file": "'"$rel_qsb"'"
}
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
print("Registered \033[1m'"$base_name"'\033[0m into shaders.json")
'
    echo -e "${GREEN}[✔] Shader '$base_name' added successfully and ready to use in UI!${RESET}"
}

do_remove() {
    local id="$1"
    if [ -z "$id" ] || [ "$id" = "off" ]; then
        echo -e "${RED}Cannot remove '$id'${RESET}"
        exit 1
    fi
    python3 -c '
import json
path = "'"$CONFIG_FILE"'"
with open(path, "r") as f:
    cfg = json.load(f)
if "presets" in cfg and "'"$id"'" in cfg["presets"]:
    del cfg["presets"]["'"$id"'"]
    if cfg.get("active") == "'"$id"'":
        cfg["active"] = "off"
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
    print("Removed \033[1m'"$id"'\033[0m from shaders.json")
else:
    print("Shader ID not found")
'
}

do_new() {
    local name="$1"
    if [ -z "$name" ]; then
        echo -e "${RED}Usage: nexa_shader.sh new <shader_name>${RESET}"
        exit 1
    fi

    # Strip .frag if present
    name="${name%.frag}"
    local outfile="$SHADERS_DIR/${name}.frag"

    if [ -f "$outfile" ]; then
        echo -e "${YELLOW}[!] File already exists: $outfile${RESET}"
        exit 1
    fi

    cat << 'EOF' > "$outfile"
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// =============================================================================
// NEXA Substrate Shader Uniform Buffer
// std140 layout: mat4 (64 B) + 8 floats (32 B) lands on 16 B boundary for vec4s.
// The order MUST match the QML ShaderEffect property definitions!
// =============================================================================
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;      // 0..63
    float qt_Opacity;    // 64..67
    float itemWidth;     // 68..71  (Surface pixel width)
    float itemHeight;    // 72..75  (Surface pixel height)
    float iTime;         // 76..79  (Global shared millisecond clock)
    float speed;         // 80..83  (Configured speed factor)
    float intensity;     // 84..87  (Configured intensity factor)
    float veilAlpha;     // 88..91  (Contrast veil factor)
    float radius;        // 92..95  (Active corner radius in pixels)
    vec4 veilColor;      // 96..111 (Nexa background tint color)
    vec4 accentA;        // 112..127(Matugen primary theme color)
    vec4 accentB;        // 128..143(Matugen secondary theme color)
} ubuf;

// Anti-aliased SDF corner clipping for capsules, pills & rounded windows
float cornerMask(vec2 uv, vec2 size, float radius) {
    if (radius <= 0.0) return 1.0;
    vec2 p = uv * size;
    vec2 b = size * 0.5;
    vec2 d = abs(p - b) - (b - vec2(radius));
    float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
    return clamp(1.0 - smoothstep(-0.5, 0.5, dist), 0.0, 1.0);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = ubuf.itemWidth / max(1.0, ubuf.itemHeight);
    vec2 p = uv;
    p.x *= aspect; // Aspect-corrected coordinates

    float t = ubuf.iTime * 0.001 * max(0.1, ubuf.speed);

    // -------------------------------------------------------------------------
    // 1. YOUR GRAPHICS LOGIC HERE
    // Example: Soft color wave using Matugen accents
    // -------------------------------------------------------------------------
    float wave = sin(p.x * 3.0 + t) * 0.5 + 0.5;
    vec3 col = mix(ubuf.accentA.rgb, ubuf.accentB.rgb, wave);

    // Blend gently with background veil color
    col = mix(ubuf.veilColor.rgb, col, 0.35 * ubuf.intensity);

    // -------------------------------------------------------------------------
    // 2. TRANSLUCENCY FOR HYPRGLASS
    // Keep alpha in translucent range (0.12 - 0.45) so HyprGlass blur shows through
    // -------------------------------------------------------------------------
    float alpha = clamp(0.18 + ubuf.veilAlpha * 0.12, 0.10, 0.45) * ubuf.qt_Opacity;

    // -------------------------------------------------------------------------
    // 3. CORNER CLIPPING & PREMULTIPLIED ALPHA
    // -------------------------------------------------------------------------
    float mask = cornerMask(uv, vec2(ubuf.itemWidth, ubuf.itemHeight), ubuf.radius);
    alpha *= mask;

    // Premultiplied alpha required by Qt Quick Scene Graph
    fragColor = vec4(col * alpha, alpha);
}
EOF

    echo -e "${GREEN}[✔] Created boilerplate shader: ${outfile}${RESET}"
    echo -e "To compile and register it in NEXA, run:"
    echo -e "  ${BOLD}./nexa_shader.sh add ${name}.frag \"Display Name\" \"Subtitle\" \"󰄛\"${RESET}"
}

do_set() {
    local id="$1"
    if [ -z "$id" ]; then
        echo -e "${RED}Usage: nexa_shader.sh set <id>${RESET}"
        exit 1
    fi
    qs -p "$HOME/.config/nexa/quickshell" ipc call shader set "$id"
    echo -e "${GREEN}[✔] Active shader set to '$id'${RESET}"
}

case "$1" in
    new)
        do_new "$2"
        ;;
    list)
        do_list
        ;;
    build)
        do_build "$2"
        ;;
    add)
        shift
        do_add "$@"
        ;;
    remove)
        do_remove "$2"
        ;;
    set)
        do_set "$2"
        ;;
    *)
        echo -e "${BOLD}${CYAN}NEXA Shader Manager${RESET}"
        echo "Commands:"
        echo "  new <name>                              Generate a pre-formatted shader template"
        echo "  list                                    List all registered shaders"
        echo "  build [id]                              Compile shader(s) to Qt QSB"
        echo "  add <file.frag> [name] [sub] [icon]     Add and compile a new shader"
        echo "  remove <id>                             Remove shader from registry"
        echo "  set <id>                                Switch active shader live"
        ;;
esac
