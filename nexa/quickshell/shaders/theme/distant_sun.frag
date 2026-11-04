#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// =============================================================================
// NEXA Substrate & Live Theme: Astral Deep Space with Distant Sun
// =============================================================================
// Features:
//  - Brilliant distant sun with pulsing coronal flare & diffraction spikes
//  - Dynamic solar lens glow illuminating cosmic dust and swirling nebulae
//  - 3-tier parallax starfield with chromatic twinkling
//  - Smooth SDF corner mask & premultiplied alpha for HyprGlass blur
// =============================================================================
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;      // 0..63
    float qt_Opacity;    // 64..67
    float itemWidth;     // 68..71  (Surface pixel width)
    float itemHeight;    // 72..75  (Surface pixel height)
    float iTime;         // 76..79  (Global shared millisecond clock)
    float speed;         // 80..83  (Configured speed factor 0.1 - 3.0)
    float intensity;     // 84..87  (Configured intensity factor 0.1 - 1.5)
    float veilAlpha;     // 88..91  (Contrast veil factor 0.0 - 1.0)
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

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = p * 2.15 + vec2(5.2, 1.3);
        a *= 0.5;
    }
    return v;
}

// Parallax star generator
vec3 starLayer(vec2 p, float density, float size, float t, float seed) {
    vec2 cell = floor(p);
    float h = hash(cell + seed);
    if (h > density) return vec3(0.0);

    vec2 pos = vec2(hash(cell + seed + 1.3), hash(cell + seed + 7.9)) * 0.8 + 0.1;
    float d = length(fract(p) - pos);
    float twinkle = 0.60 + 0.40 * sin(t * (1.2 + h * 2.5) + h * 60.0);
    float core = smoothstep(size, 0.0, d);
    float halo = smoothstep(size * 4.5, 0.0, d) * 0.25;

    // Chromatic star tinting (warm solar gold to cold stellar cyan)
    vec3 tint = mix(vec3(0.80, 0.90, 1.0), vec3(1.0, 0.92, 0.75), hash(cell + seed + 3.7));
    return tint * (core + halo) * twinkle * (0.40 + 0.60 * hash(cell + seed + 5.1));
}

void main() {
    vec2 res = vec2(max(1.0, ubuf.itemWidth), max(1.0, ubuf.itemHeight));
    vec2 uv = qt_TexCoord0;
    float aspect = res.x / res.y;
    vec2 p = uv;
    p.x *= aspect;

    // Live animation clock in seconds
    float t = ubuf.iTime * 0.001 * max(0.1, ubuf.speed);

    // ── 1. DISTANT SUN POSITION & CORONA ─────────────────────────────────────
    // Distant sun nestled in the upper-right quadrant with subtle orbital drift
    vec2 sunPos = vec2(aspect * 0.78 + sin(t * 0.08) * 0.03, 0.28 + cos(t * 0.06) * 0.02);
    vec2 toSun = p - sunPos;
    float dSun = length(toSun);

    // Core solar sphere
    float sunRadius = 0.038 * ubuf.intensity;
    float sunCore = smoothstep(sunRadius, 0.0, dSun);

    // Coronal breathing & atmospheric bloom
    float coronaPulse = 1.0 + 0.08 * sin(t * 1.5) + 0.04 * cos(t * 2.8);
    float sunCorona = exp(-dSun * 6.5 / coronaPulse) * 0.85;
    float sunDeepGlow = exp(-dSun * 2.2) * 0.45;

    // Four-point diffraction spikes radiating from the distant sun
    float spikeAngle = atan(toSun.y, toSun.x);
    float spikes = pow(max(0.0, cos(spikeAngle * 2.0)), 32.0) * exp(-dSun * 8.0) * 0.70;
    spikes += pow(max(0.0, sin(spikeAngle * 2.0)), 48.0) * exp(-dSun * 12.0) * 0.45;

    // Solar palette: Brilliant white core -> Solar gold -> Theme accent amber/crimson
    vec3 cSunCore = vec3(1.0, 0.98, 0.94);
    vec3 cSolarGold = mix(vec3(1.0, 0.78, 0.32), ubuf.accentA.rgb, 0.40);
    vec3 cSunHalo = mix(cSolarGold, ubuf.accentB.rgb, 0.50);

    vec3 sunLight = cSunCore * sunCore * 2.0;
    sunLight += cSolarGold * (sunCorona + spikes) * 1.4;
    sunLight += cSunHalo * sunDeepGlow * 1.0;
    sunLight *= ubuf.intensity;

    // ── 2. SWIRLING NEBULA LIT BY THE SUN ────────────────────────────────────
    vec2 nebCoord1 = p * 1.5 + vec2(t * 0.012, -t * 0.006);
    vec2 nebCoord2 = p * 2.6 - vec2(t * 0.008, t * 0.010) + vec2(17.4, 8.2);

    float neb1 = fbm(nebCoord1);
    float neb2 = fbm(nebCoord2);

    // Sunlight scattering through the cosmic dust
    float sunScattering = exp(-dSun * 1.6);
    vec3 cNebulaA = mix(ubuf.accentB.rgb, cSolarGold, 0.45 * sunScattering);
    vec3 cNebulaB = mix(ubuf.accentA.rgb, vec3(0.08, 0.04, 0.16), 0.55);

    vec3 nebulaCol = cNebulaA * smoothstep(0.38, 0.92, neb1) * (0.35 + 0.30 * sunScattering);
    nebulaCol += cNebulaB * smoothstep(0.44, 0.98, neb2) * 0.28;
    nebulaCol *= ubuf.intensity;

    // ── 3. PARALLAX DRIFTING STARFIELD ───────────────────────────────────────
    vec3 stars = vec3(0.0);
    // Background deep stars
    stars += starLayer(p * 85.0 + vec2(t * 0.25, 0.0), 0.16, 0.04, t, 3.0) * 0.55;
    // Midground stars
    stars += starLayer(p * 45.0 + vec2(t * 0.60, 0.0), 0.12, 0.06, t, 19.0) * 0.85;
    // Foreground bright stars
    stars += starLayer(p * 20.0 + vec2(t * 1.20, 0.0), 0.06, 0.08, t, 42.0) * 1.25;
    stars *= ubuf.intensity;

    // ── 4. COMPOSITING WITH HYPRGLASS TRANSLUCENCY ───────────────────────────
    // Base space substrate
    vec3 col = mix(ubuf.veilColor.rgb, vec3(0.02, 0.03, 0.06), 0.65);
    col += nebulaCol;
    col += stars;
    col += sunLight;

    // Vignette
    vec2 c = uv - 0.5;
    c.x *= aspect;
    col *= mix(1.0, 0.70, smoothstep(0.35, 1.2, length(c)));

    // Translucency & corner clipping
    float alpha = clamp(0.22 + ubuf.veilAlpha * 0.16 + (sunCorona + sunCore) * 0.25, 0.14, 0.65) * ubuf.qt_Opacity;
    float mask = cornerMask(uv, res, ubuf.radius);
    alpha *= mask;

    // Premultiplied alpha for Qt Quick SceneGraph
    fragColor = vec4(col * alpha, alpha);
}

