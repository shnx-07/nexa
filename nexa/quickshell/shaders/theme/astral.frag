#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// =============================================================================
// NEXA Substrate & Theme: Astral Deep Space (Exact Lock Screen Port)
// =============================================================================
// Features:
//  - Deep-space cosmic backdrop identical to the lockscreen "Astral" theme
//  - 3 parallax layers of drifting and twinkling stars
//  - Two-tone drifting FBM nebula clouds tinted by active theme accents
//  - Diagonal galactic Milky Way band
//  - Cosmic edge vignette and smooth SDF corner clipping
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
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.1 + vec2(5.2, 1.3);
        a *= 0.5;
    }
    return v;
}

// One layer of stars: a random star in some grid cells.
vec3 stars(vec2 p, float density, float size, float t, float seed) {
    vec2 cell = floor(p);
    float h = hash(cell + seed);
    if (h > density)
        return vec3(0.0);
    vec2 pos = vec2(hash(cell + seed + 1.3), hash(cell + seed + 7.9)) * 0.8 + 0.1;
    float d = length(fract(p) - pos);
    float twinkle = 0.65 + 0.35 * sin(t * (1.0 + h * 3.0) + h * 60.0);
    float core = smoothstep(size, 0.0, d);
    float halo = smoothstep(size * 4.0, 0.0, d) * 0.25;
    vec3 tint = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), hash(cell + seed + 3.7));
    return tint * (core + halo) * twinkle * (0.45 + 0.55 * hash(cell + seed + 5.1));
}

void main() {
    vec2 res = vec2(max(1.0, ubuf.itemWidth), max(1.0, ubuf.itemHeight));
    vec2 uv = qt_TexCoord0;
    vec2 p = vec2(uv.x * res.x / res.y, uv.y);

    // Live GPU motion clock in elapsed seconds
    float t = ubuf.iTime * 0.001 * max(0.1, ubuf.speed);

    // Iconic deep cosmic navy/black base
    vec3 col = vec3(0.012, 0.020, 0.043);

    // Nebula: two tinted fbm clouds, drifting slowly
    float n1 = fbm(p * 1.6 + vec2(t * 0.006, -t * 0.003));
    float n2 = fbm(p * 2.8 - vec2(t * 0.004, t * 0.005) + 13.0);
    col += ubuf.accentA.rgb * smoothstep(0.45, 0.95, n1) * 0.35 * ubuf.intensity;
    col += ubuf.accentB.rgb * smoothstep(0.50, 1.00, n2) * 0.25 * ubuf.intensity;

    // Galactic band across the sky
    float band = exp(-pow((uv.y - 0.35 - 0.25 * uv.x) * 3.2, 2.0));
    col += mix(ubuf.accentA.rgb, vec3(0.8, 0.85, 1.0), 0.6) * band * 0.06 * (0.6 + 0.4 * n2) * ubuf.intensity;

    // Stars in three parallax layers
    col += stars(p * 90.0 + vec2(t * 0.35, 0.0), 0.16 + band * 0.1, 0.05, t, 1.0) * 0.55 * ubuf.intensity;
    col += stars(p * 48.0 + vec2(t * 0.80, 0.0), 0.12, 0.06, t, 17.0) * 0.85 * ubuf.intensity;
    col += stars(p * 22.0 + vec2(t * 1.60, 0.0), 0.07, 0.07, t, 31.0) * 1.20 * ubuf.intensity;

    // Vignette
    vec2 c = uv - 0.5;
    c.x *= res.x / res.y;
    col *= mix(1.0, 0.55, smoothstep(0.4, 1.2, length(c)));

    // Corner mask & translucency
    float mask = cornerMask(uv, res, ubuf.radius);
    float alpha = clamp(0.75 + ubuf.veilAlpha * 0.20, 0.45, 0.96) * ubuf.qt_Opacity * mask;

    // Premultiplied alpha for Qt Quick SceneGraph
    fragColor = vec4(col * alpha, alpha);
}
