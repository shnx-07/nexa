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

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = ubuf.itemWidth / max(1.0, ubuf.itemHeight);
    vec2 p = uv;
    p.x *= aspect;

    float t = ubuf.iTime * 0.001 * max(0.1, ubuf.speed);

    // Ethereal curtain harmonic oscillations
    float wave1 = sin(p.x * 2.5 + t * 0.8) * 0.18 + cos(p.x * 1.8 - t * 0.5) * 0.12;
    float wave2 = sin(p.x * 3.2 - t * 0.7 + 1.5) * 0.14 + cos(p.x * 4.0 + t * 0.9) * 0.08;
    float wave3 = sin(p.x * 1.5 + t * 0.4 + 3.0) * 0.20;

    // Vertical ribbons
    float ribbon1 = exp(-abs(p.y - 0.35 - wave1) * 9.0);
    float ribbon2 = exp(-abs(p.y - 0.50 - wave2) * 8.0);
    float ribbon3 = exp(-abs(p.y - 0.65 - wave3) * 7.0);

    // Aurora curtain fold rays (vertical light flutes)
    float rays = sin(p.x * 30.0 + t * 2.0) * 0.5 + 0.5;
    rays = pow(rays, 2.0) * 0.35 + 0.65;

    // Palette: Emerald Green -> Cyan -> Violet Magenta
    vec3 cEmerald = vec3(0.15, 0.95, 0.60);
    vec3 cCyan = mix(vec3(0.10, 0.80, 0.95), ubuf.accentA.rgb, 0.4);
    vec3 cViolet = mix(vec3(0.70, 0.25, 0.95), ubuf.accentB.rgb, 0.5);

    vec3 aurora = cEmerald * ribbon1 * rays * 1.2;
    aurora += cCyan * ribbon2 * rays * 1.0;
    aurora += cViolet * ribbon3 * rays * 0.9;

    aurora *= ubuf.intensity;

    // Base glass tint from veilColor
    vec3 col = ubuf.veilColor.rgb + aurora;

    // Subtle edge vignette
    float vignette = 1.0 - smoothstep(0.4, 1.4, length(uv - 0.5));
    col *= mix(0.85, 1.0, vignette);

    // Translucent alpha for HyprGlass blur
    float auroraBrightness = max(aurora.r, max(aurora.g, aurora.b));
    float alpha = clamp(0.16 + auroraBrightness * 0.35 + ubuf.veilAlpha * 0.12, 0.10, 0.48) * ubuf.qt_Opacity;

    // Anti-aliased corner clipping
    float mask = cornerMask(uv, vec2(ubuf.itemWidth, ubuf.itemHeight), ubuf.radius);
    alpha *= mask;

    fragColor = vec4(col * alpha, alpha);
}
