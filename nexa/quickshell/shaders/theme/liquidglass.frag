#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// std140: mat4 (64 B) + 8 floats (32 B) lands exactly on the 16 B boundary
// for the vec4s, so no padding is needed. Order MUST match the QML properties.
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float iTime;       // milliseconds
    float speed;
    float intensity;
    float veilAlpha;
    float radius;      // corner radius in pixels
    vec4 veilColor;
    vec4 accentA;
    vec4 accentB;
} ubuf;

// ---------------------------------------------------------------------------
// Liquid height field (smooth harmonic caustics)
// ---------------------------------------------------------------------------
float field(vec2 p, float t, float aspect) {
    p *= 2.5;
    float v = 0.0;
    v += sin(p.x * 1.2 + t * 0.4);
    v += sin(p.y * 1.5 - t * 0.3);
    v += sin((p.x + p.y) * 1.1 + t * 0.5);
    v += cos(length(p - vec2(0.5 * aspect, 0.5) * 2.5) * 3.0 - t * 0.6);
    return v * 0.25;
}

// Domain-warped field: fluid motion
float liquid(vec2 p, float t, float aspect) {
    float w1 = field(p, t, aspect);
    return field(p + vec2(w1 * 0.4, -w1 * 0.3), t * 1.2, aspect);
}

// Gradient of the liquid field = fake surface normal
vec2 liquidGrad(vec2 p, float t, float aspect) {
    float e = 0.01;
    return vec2(
        liquid(p + vec2(e, 0.0), t, aspect) - liquid(p - vec2(e, 0.0), t, aspect),
        liquid(p + vec2(0.0, e), t, aspect) - liquid(p - vec2(0.0, e), t, aspect)
    ) / (2.0 * e);
}

// ---------------------------------------------------------------------------
// Rounded rect SDF (negative inside)
// ---------------------------------------------------------------------------
float sdRoundRect(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 size = vec2(max(1.0, ubuf.itemWidth), max(1.0, ubuf.itemHeight));
    float aspect = size.x / size.y;
    float minHalf = 0.5 * min(size.x, size.y);

    float t = ubuf.iTime * 0.001 * max(0.1, ubuf.speed);
    float inten = ubuf.intensity;

    // -- Shape ---------------------------------------------------------------
    vec2 c = (uv - 0.5) * size;                       // pixel coords, centered
    float rad = clamp(ubuf.radius, 0.0, minHalf);
    float d = sdRoundRect(c, size * 0.5, rad);        // < 0 inside

    float mask = 1.0 - smoothstep(-1.0, 0.0, d);      // anti-aliased shape mask
    if (mask <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // SDF normal (points outward), used for bevel refraction and rim light
    vec2 ee = vec2(1.0, 0.0);
    vec2 n2 = normalize(vec2(
        sdRoundRect(c + ee.xy, size * 0.5, rad) - sdRoundRect(c - ee.xy, size * 0.5, rad),
        sdRoundRect(c + ee.yx, size * 0.5, rad) - sdRoundRect(c - ee.yx, size * 0.5, rad)
    ) + 1e-6);

    // Bevel: 1 at the rim, fading to 0 towards the interior
    float bevelW = clamp(minHalf * 0.45, 4.0, 18.0);
    float bevel = 1.0 - smoothstep(0.0, bevelW, -d);
    bevel = bevel * bevel;

    // -- Refraction of the pattern near the edge -----------------------------
    vec2 p = vec2(uv.x * aspect, uv.y);
    vec2 nUv = vec2(n2.x / aspect, n2.y);
    vec2 warp = -nUv * bevel * 0.12;                  // lens-like pull

    // -- Real per-channel dispersion -----------------------------------------
    float disp = 0.02 * inten * (0.4 + bevel * 1.6);  // stronger at the rim
    vec2 dirD = normalize(nUv + vec2(1e-5));
    float fr = liquid(p + warp + dirD * disp, t, aspect);
    float fg = liquid(p + warp,               t, aspect);
    float fb = liquid(p + warp - dirD * disp, t, aspect);

    // Each channel gets its own phase along the accent ramp
    vec3 ramp = vec3(
        mix(ubuf.accentA.r, ubuf.accentB.r, clamp(fr * 0.5 + 0.5, 0.0, 1.0)),
        mix(ubuf.accentA.g, ubuf.accentB.g, clamp(fg * 0.5 + 0.5, 0.0, 1.0)),
        mix(ubuf.accentA.b, ubuf.accentB.b, clamp(fb * 0.5 + 0.5, 0.0, 1.0))
    );

    // -- Caustics ------------------------------------------------------------
    float crest = smoothstep(0.1, 0.6, abs(fg));
    float caustic = pow(smoothstep(0.35, 0.7, abs(fg)), 3.0);

    // -- Surface lighting from the liquid normal ------------------------------
    vec2 g = liquidGrad(p + warp, t, aspect);
    vec3 N = normalize(vec3(-g * 0.35, 1.0));
    vec3 L = normalize(vec3(-0.45, -0.55, 0.70));     // top-left light (Qt y is down)
    vec3 V = vec3(0.0, 0.0, 1.0);
    vec3 H = normalize(L + V);
    float spec = pow(max(dot(N, H), 0.0), 40.0);
    float sheen = pow(1.0 - max(dot(N, V), 0.0), 2.0);

    // -- Rim light (liquid-glass signature) ----------------------------------
    float rimLine = (1.0 - smoothstep(0.0, 1.6, -d)) * mask;   // thin 1-2 px edge
    float rimGlow = bevel * 0.6;
    vec2 Ld = normalize(vec2(-0.6, -0.8));
    float key  = pow(max(dot(n2,  Ld), 0.0), 2.0);             // top-left bright
    float fill = pow(max(dot(n2, -Ld), 0.0), 2.0) * 0.55;      // bottom-right softer
    float rim = (key + fill) * (rimLine * 1.0 + rimGlow * 0.5);

    // -- Color ---------------------------------------------------------------
    vec3 col = mix(ubuf.veilColor.rgb, ramp, clamp(crest * inten * 0.55, 0.0, 0.85));
    col = mix(col, vec3(1.0), caustic * 0.25);
    col += vec3(spec * 0.35 * (0.5 + inten * 0.5));
    col += vec3(sheen * 0.05);
    col += vec3(rim * 0.9);

    // Soft inner vignette (shape-aware, not elliptical UV based)
    float inner = smoothstep(0.0, minHalf, -d);
    col *= mix(0.88, 1.0, inner);

    // -- Alpha: stays translucent so HyprGlass blur + wallpaper show through --
    float alpha = 0.16
                + crest * inten * 0.24
                + ubuf.veilAlpha * 0.12
                + caustic * 0.06;
    alpha = clamp(alpha, 0.10, 0.45);
    alpha = clamp(alpha + rim * 0.40 + spec * 0.15, 0.0, 0.85);
    alpha *= mask * ubuf.qt_Opacity;

    // Premultiplied alpha for the Qt Quick scene graph
    fragColor = vec4(col * alpha, alpha);
}
