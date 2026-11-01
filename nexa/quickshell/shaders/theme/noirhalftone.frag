#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// =============================================================================
// NEXA Substrate Shader Uniform Buffer (unchanged from the template)
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

// Signed distance to a rounded rect (negative inside)
float sdRoundRect(vec2 uv, vec2 size, float radius) {
    vec2 p = uv * size;
    vec2 b = size * 0.5;
    float r = clamp(radius, 0.0, min(b.x, b.y));
    vec2 d = abs(p - b) - (b - vec2(r));
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Flowing "ink" field in 0..1 (domain-warped, 2 octaves)
float inkField(vec2 p, float t) {
    vec2 q = vec2(vnoise(p + vec2(0.0, t * 0.30)),
                  vnoise(p + vec2(5.2, 1.3) - vec2(t * 0.25, 0.0)));
    p += 2.2 * q;
    return 0.65 * vnoise(p + vec2(0.0, t * 0.10)) + 0.35 * vnoise(p * 2.0 - t * 0.15);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 size = vec2(max(1.0, ubuf.itemWidth), max(1.0, ubuf.itemHeight));
    vec2 px = uv * size;
    float t = ubuf.iTime * 0.001 * max(0.1, ubuf.speed);

    // -------------------------------------------------------------------------
    // 1. SHAPE MASK
    // -------------------------------------------------------------------------
    float sd = sdRoundRect(uv, size, ubuf.radius);
    float mask = clamp(1.0 - smoothstep(-0.5, 0.5, sd), 0.0, 1.0);
    if (mask <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // -------------------------------------------------------------------------
    // 2. ROTATED HALFTONE GRID (pixel based, so dots keep their size)
    // -------------------------------------------------------------------------
    float cell = clamp(min(size.x, size.y) * 0.045, 6.0, 14.0);
    const float ang = 0.5236; // 30 degrees
    mat2 R = mat2(cos(ang), -sin(ang), sin(ang), cos(ang));

    vec2 g = (R * px) / cell;
    vec2 id = floor(g);
    vec2 f = fract(g) - 0.5;

    // Cell center back in screen space -> sample the ink field once per cell
    vec2 cp = transpose(R) * ((id + 0.5) * cell);
    vec2 fp = cp / max(size.x, size.y) * 3.5;

    float v = inkField(fp, t);
    float pol = smoothstep(0.47, 0.53, inkField(fp * 0.5 + vec2(11.0, 3.0), t * 0.6));

    // Dot radius follows the ink field; intensity widens the contrast range
    float contrast = clamp(0.6 + 0.4 * ubuf.intensity, 0.4, 1.2);
    float lo = 0.5 - 0.30 * contrast;
    float hi = 0.5 + 0.30 * contrast;
    float r = mix(0.04, 0.70, smoothstep(lo, hi, v));

    float aa = 0.8 / cell;
    float dotShape = 1.0 - smoothstep(r - aa, r + aa, length(f));

    // Polarity: white dots on black in some regions, black dots on white in others
    float val = mix(1.0 - dotShape, dotShape, pol);

    // -------------------------------------------------------------------------
    // 3. FILM GRAIN + VIGNETTE + WHITE HAIRLINE EDGE
    // -------------------------------------------------------------------------
    float grain = hash21(px + floor(t * 12.0) * 17.0) - 0.5;
    val = clamp(val + grain * 0.08, 0.0, 1.0);

    float vig = 1.0 - smoothstep(0.35, 1.25, length(uv - 0.5) * 1.6);
    val *= mix(0.72, 1.0, vig);

    float edge = 1.0 - smoothstep(0.0, 1.4, -sd);          // 1px inner rim
    val = mix(val, 1.0, edge * 0.85);

    vec3 col = vec3(val);

    // -------------------------------------------------------------------------
    // 4. TRANSLUCENCY FOR HYPRGLASS
    // Same alpha for black and white, so the blur reads through both tones.
    // -------------------------------------------------------------------------
    float alpha = clamp(0.20 + ubuf.veilAlpha * 0.12 + ubuf.intensity * 0.04, 0.12, 0.45);
    alpha = clamp(alpha + edge * 0.20, 0.0, 0.6) * ubuf.qt_Opacity * mask;

    // Premultiplied alpha required by Qt Quick Scene Graph
    fragColor = vec4(col * alpha, alpha);
}

