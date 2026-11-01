#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float itemWidth;
    float itemHeight;
    float iTime;
    float speed;
    float intensity;
    float veilAlpha;
    float radius;
    vec4 veilColor;
    vec4 accentA;
    vec4 accentB;
} ubuf;

// Anti-aliased corner mask for rounded capsules and windows
float cornerMask(vec2 uv, vec2 size, float radius) {
    if (radius <= 0.0) return 1.0;
    vec2 p = uv * size;
    vec2 b = size * 0.5;
    vec2 d = abs(p - b) - (b - vec2(radius));
    float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
    return clamp(1.0 - smoothstep(-0.5, 0.5, dist), 0.0, 1.0);
}

// Smooth harmonic liquid caustics
float wave(vec2 p, float t) {
    p *= 2.5;
    float v = 0.0;
    v += sin(p.x * 1.2 + t * 0.4);
    v += sin(p.y * 1.5 - t * 0.3);
    v += sin((p.x + p.y) * 1.1 + t * 0.5);
    v += cos(length(p - vec2(0.5, 0.5)) * 3.0 - t * 0.6);
    return v * 0.25;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = ubuf.itemWidth / max(1.0, ubuf.itemHeight);
    vec2 p = uv;
    p.x *= aspect;

    float t = ubuf.iTime * 0.001 * max(0.1, ubuf.speed);

    // 1. Domain warping for fluid motion
    float w1 = wave(p, t);
    float w2 = wave(p + vec2(w1 * 0.4, -w1 * 0.3), t * 1.2);

    // 2. Chromatic aberration / dispersion offsets
    float disp = 0.025 * ubuf.intensity;
    float r = wave(p + vec2(disp, 0.0) + w2 * 0.2, t);
    float g = wave(p + w2 * 0.2, t);
    float b = wave(p - vec2(disp, 0.0) + w2 * 0.2, t);

    // 3. Caustic highlights and depth
    float crest = smoothstep(0.1, 0.6, abs(g));
    float highlight = pow(smoothstep(0.35, 0.7, abs(g)), 3.0) * 0.4;

    // 4. Color blending with Matugen accents
    vec3 liquid = mix(ubuf.accentA.rgb, ubuf.accentB.rgb, clamp(r * 0.5 + 0.5, 0.0, 1.0));
    liquid = mix(liquid, vec3(1.0), highlight * 0.5);

    // Base glass tint from veilColor or accent
    vec3 col = mix(ubuf.veilColor.rgb, liquid, clamp(crest * ubuf.intensity * 0.55, 0.0, 0.85));
    col += vec3(highlight * 0.25);

    // Subtle edge vignette
    float vignette = 1.0 - smoothstep(0.4, 1.4, length(uv - 0.5));
    col *= mix(0.85, 1.0, vignette);

    // 5. Translucent Alpha calculation for HyprGlass cooperation
    // Kept in translucent range (0.15 - 0.45) so HyprGlass blur and wallpaper shine through!
    float alpha = clamp(0.16 + crest * ubuf.intensity * 0.24 + ubuf.veilAlpha * 0.12, 0.10, 0.45) * ubuf.qt_Opacity;

    // 6. Anti-aliased corner clipping (discards pixels outside rounded capsules/corners)
    float mask = cornerMask(uv, vec2(ubuf.itemWidth, ubuf.itemHeight), ubuf.radius);
    alpha *= mask;

    // Premultiplied alpha for Qt Quick Scene Graph
    fragColor = vec4(col * alpha, alpha);
}
