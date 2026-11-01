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

// Pseudo-random hash
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// 2D Hash returning vec2
vec2 hash2(vec2 p) {
    float n = sin(dot(p, vec2(127.1, 311.7)));
    return fract(vec2(269.5, 183.3) * n);
}

// Background starfield layer with twinkling and diffraction
float starLayer(vec2 p, float scale, float t) {
    vec2 gridId = floor(p * scale);
    vec2 gridUv = fract(p * scale) - 0.5;

    float rnd = hash(gridId);
    if (rnd < 0.65) return 0.0; // Sparse distribution

    vec2 offset = (hash2(gridId) - 0.5) * 0.6;
    vec2 pos = gridUv - offset;
    float dist = length(pos);

    // Twinkling cycle
    float twinkle = sin(t * (2.0 + rnd * 4.0) + rnd * 6.2831) * 0.5 + 0.5;
    twinkle = pow(twinkle, 3.0);

    // Star core + subtle diffraction cross
    float core = smoothstep(0.06, 0.0, dist) * (0.8 + 0.6 * twinkle);
    float glow = 0.015 / (dist + 0.01) * twinkle;
    float cross = max(
        smoothstep(0.015, 0.0, abs(pos.x)) * smoothstep(0.12, 0.0, abs(pos.y)),
        smoothstep(0.015, 0.0, abs(pos.y)) * smoothstep(0.12, 0.0, abs(pos.x))
    ) * twinkle * 0.4;

    return (core + glow + cross) * (rnd * 0.7 + 0.3);
}

// Single Comet calculation (Head + luminous tapering tail)
vec3 renderComet(
    vec2 uv,
    vec2 startPos,
    vec2 dir,
    float velocity,
    float cycleTime,
    float timeOffset,
    float tailLength,
    float headSize,
    float currentTime,
    vec3 cometColor
) {
    float t = currentTime + timeOffset;
    float phase = mod(t, cycleTime);
    float activeDuration = 2.2 / max(0.1, velocity);

    if (phase > activeDuration) {
        return vec3(0.0);
    }

    // Current head position
    float progress = phase / activeDuration;
    vec2 headPos = startPos + dir * (progress * 1.8);

    // Vector from head to current UV
    vec2 delta = uv - headPos;
    float dAlongTail = dot(delta, -dir);
    float dOrthogonal = length(delta + dir * dAlongTail);

    vec3 light = vec3(0.0);

    // 1. Comet Head (Brilliant nucleus and spherical halo)
    float distToHead = length(delta);
    float headCore = smoothstep(headSize * 0.35, 0.0, distToHead);
    float headHalo = 0.012 / (distToHead * 18.0 + 0.035);
    light += (vec3(1.0, 1.0, 1.0) * headCore * 2.2 + cometColor * headHalo * 1.4);

    // 2. Trailing Tail (Ion and dust trail tapering backwards)
    if (dAlongTail > 0.0 && dAlongTail < tailLength) {
        float tailFade = pow(1.0 - (dAlongTail / tailLength), 1.6);
        float currentTailWidth = 0.003 + (dAlongTail / tailLength) * 0.018;
        float tailGlow = smoothstep(currentTailWidth, 0.0, dOrthogonal) * tailFade;

        // Chromatic split on tail edge
        vec3 trailCol = mix(vec3(1.0), cometColor, clamp(dAlongTail * 3.0, 0.0, 1.0));
        light += trailCol * tailGlow * 1.5;

        // Soft outer ambient tail beam
        float beamGlow = (0.006 / (dOrthogonal * 55.0 + 0.04)) * tailFade;
        light += cometColor * beamGlow * 0.8;
    }

    return light;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = ubuf.itemWidth / max(1.0, ubuf.itemHeight);
    vec2 p = uv;
    p.x *= aspect;

    float t = ubuf.iTime * 0.001 * max(0.1, ubuf.speed);

    // 1. Starfield background (Two parallax layers)
    float stars = 0.0;
    stars += starLayer(p, 28.0, t * 0.7);
    stars += starLayer(p + vec2(0.33, 0.55), 45.0, t * 0.9) * 0.75;
    stars += starLayer(p + vec2(0.71, 0.19), 65.0, t * 1.2) * 0.5;

    // Celestial color accents from Matugen
    vec3 cStar = mix(vec3(0.85, 0.95, 1.0), ubuf.accentA.rgb, 0.35);
    vec3 finalLight = cStar * stars * ubuf.intensity;

    // 2. Four distinct comets streaking diagonally
    // Normalized diagonal direction vectors
    vec2 dir1 = normalize(vec2(-1.25, 0.75));
    vec2 dir2 = normalize(vec2(-1.10, 0.85));
    vec2 dir3 = normalize(vec2(-1.40, 0.65));
    vec2 dir4 = normalize(vec2(-1.18, 0.80));

    // Comet 1: Major brilliant comet across upper-middle
    vec3 col1 = mix(vec3(0.9, 0.95, 1.0), ubuf.accentA.rgb, 0.5);
    finalLight += renderComet(
        p,
        vec2(aspect * 1.15, -0.15),
        dir1,
        0.55,  // velocity
        4.8,   // cycle seconds
        0.0,   // time offset
        0.55,  // tail length
        0.022, // head size
        t,
        col1
    ) * ubuf.intensity;

    // Comet 2: Warm accent comet through center-lower
    vec3 col2 = mix(vec3(1.0, 0.85, 0.6), ubuf.accentB.rgb, 0.7);
    finalLight += renderComet(
        p,
        vec2(aspect * 0.95, 0.15),
        dir2,
        0.72,  // velocity
        3.9,   // cycle seconds
        1.6,   // time offset
        0.42,  // tail length
        0.018, // head size
        t,
        col2
    ) * ubuf.intensity;

    // Comet 3: Swift shooting star streaking across the top
    vec3 col3 = mix(vec3(0.7, 0.9, 1.0), ubuf.accentA.rgb, 0.4);
    finalLight += renderComet(
        p,
        vec2(aspect * 1.35, -0.05),
        dir3,
        0.95,  // velocity
        5.6,   // cycle seconds
        3.2,   // time offset
        0.35,  // tail length
        0.015, // head size
        t,
        col3
    ) * ubuf.intensity;

    // Comet 4: Graceful long-tail comet in the lower quadrant
    vec3 col4 = mix(ubuf.accentA.rgb, ubuf.accentB.rgb, 0.5);
    finalLight += renderComet(
        p,
        vec2(aspect * 0.75, 0.35),
        dir4,
        0.48,  // velocity
        4.4,   // cycle seconds
        2.5,   // time offset
        0.65,  // tail length
        0.020, // head size
        t,
        col4
    ) * ubuf.intensity;

    // 3. Cosmic deep-space tint and vignette
    vec3 baseGlass = ubuf.veilColor.rgb;
    vec3 col = baseGlass + finalLight;

    // 4. Soft subtle vignette towards window corners
    float vignette = 1.0 - smoothstep(0.4, 1.4, length(uv - 0.5));
    col *= mix(0.85, 1.0, vignette);

    // 5. Translucent Alpha calculation for HyprGlass cooperation
    // Base opacity remains translucent (0.15 - 0.22) so wallpaper blurs through,
    // brightening locally wherever a comet or star shines.
    float brightness = max(finalLight.r, max(finalLight.g, finalLight.b));
    float alpha = clamp(0.16 + brightness * 0.35 + ubuf.veilAlpha * 0.12, 0.10, 0.50) * ubuf.qt_Opacity;

    // 6. Anti-aliased corner clipping (discards pixels outside rounded capsules/corners)
    float mask = cornerMask(uv, vec2(ubuf.itemWidth, ubuf.itemHeight), ubuf.radius);
    alpha *= mask;

    // Premultiplied alpha for Qt Quick Scene Graph
    fragColor = vec4(col * alpha, alpha);
}
