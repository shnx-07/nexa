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

// Anti-aliased SDF corner clipping for capsules, pills & rounded windows
float cornerMask(vec2 uv, vec2 size, float radius) {
    if (radius <= 0.0) return 1.0;
    vec2 p = uv * size;
    vec2 b = size * 0.5;
    vec2 d = abs(p - b) - (b - vec2(radius));
    float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
    return clamp(1.0 - smoothstep(-0.5, 0.5, dist), 0.0, 1.0);
}

// -----------------------------------------------------------------------------
// Hashing / noise
// -----------------------------------------------------------------------------
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
    float n = hash21(p);
    return vec2(n, hash21(p + n + 7.7));
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
               mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// -----------------------------------------------------------------------------
// Drops
// -----------------------------------------------------------------------------
struct Drop {
    float body;   // drop coverage 0..1
    float trail;  // wet trail coverage 0..1
    vec2 rel;     // offset from drop center, normalized by radius
    float rr;     // normalized distance from center 0..1
};

Drop emptyDrop() {
    Drop o;
    o.body = 0.0;
    o.trail = 0.0;
    o.rel = vec2(0.0);
    o.rr = 1.0;
    return o;
}

// Sliding drops with trails. One drop per tall cell (1 wide x 2 high).
// Life cycle: bead grows -> slides with stop-and-go -> fades, then respawns.
Drop slidingLayer(vec2 g, float t, float density) {
    Drop o = emptyDrop();

    const vec2 cell = vec2(1.0, 2.0);
    vec2 cid = floor(g / cell);
    vec2 loc = g / cell - cid;
    vec2 q = vec2((loc.x - 0.5) * cell.x, loc.y * cell.y); // x -0.5..0.5, y 0..2 (down)

    if (hash21(cid + 9.9) > density) return o;

    vec2 h = hash22(cid);
    float h3 = hash21(cid + 3.1);
    float rate = 0.10 + 0.12 * hash21(cid + 1.7);
    float life = fract(t * rate + h3);

    float r = 0.13 + 0.07 * h.y;
    float startY = 0.35 + 0.20 * h.y;

    float grow = smoothstep(0.0, 0.25, life);
    float slideT = clamp((life - 0.30) / 0.65, 0.0, 1.0);

    // stop-and-go slide: eased stair steps blended with a linear fall
    float n = 4.0;
    float k = slideT * n;
    float stair = (floor(k) + smoothstep(0.0, 1.0, fract(k))) / n;
    float s = pow(mix(slideT, stair, 0.6), 1.25);

    float yPos = startY + 1.10 * s;
    float fade = 1.0 - smoothstep(0.92, 1.0, life);
    float size = r * (0.55 + 0.45 * grow) * (1.0 - 0.25 * s);

    float dx = (h.x - 0.5) * 0.36;
    float wob = sin(q.y * 7.0 + h3 * 6.28) * 0.025 * s;

    // drop body
    vec2 d = vec2(q.x - (dx + sin(yPos * 7.0 + h3 * 6.28) * 0.025 * s), (q.y - yPos) * 0.85);
    float dist = length(d);
    o.body = (1.0 - smoothstep(size * 0.85, size, dist)) * fade;
    o.rel = d / max(size, 1e-4);
    o.rr = clamp(dist / size, 0.0, 1.0);

    // wet trail left above the drop
    float tw = size * 0.28 * (0.4 + 0.6 * smoothstep(startY, yPos + 1e-3, q.y));
    float trailX = 1.0 - smoothstep(tw * 0.6, tw, abs(q.x - (dx + wob)));
    float trailY = smoothstep(startY - 0.03, startY + 0.04, q.y)
                 * (1.0 - smoothstep(yPos - 0.02, yPos, q.y));
    o.trail = trailX * trailY * fade * smoothstep(0.0, 0.05, slideT);

    return o;
}

// Tiny static droplets (condensation) that slowly breathe.
Drop mistLayer(vec2 g, float t) {
    Drop o = emptyDrop();

    vec2 cid = floor(g);
    vec2 loc = fract(g) - 0.5;

    if (hash21(cid + 4.2) > 0.55) return o;

    vec2 h = hash22(cid + 0.5);
    vec2 off = (h - 0.5) * 0.5;
    float r = 0.12 + 0.14 * hash21(cid + 8.8);
    float breathe = 0.85 + 0.15 * sin(t * 0.5 + h.x * 6.28);
    float size = r * breathe;

    vec2 d = loc - off;
    float dist = length(d);
    o.body = 1.0 - smoothstep(size * 0.85, size, dist);
    o.rel = d / max(size, 1e-4);
    o.rr = clamp(dist / size, 0.0, 1.0);
    return o;
}

// Fake lens lighting for a drop.
// x = specular, y = lit rim, z = dark rim, w = inner focus glow
vec4 lightDrop(Drop d) {
    if (d.body <= 0.0) return vec4(0.0);

    float z = sqrt(max(1.0 - d.rr * d.rr, 0.0));
    vec3 n = normalize(vec3(d.rel, max(z, 0.05)));

    vec3 L = normalize(vec3(-0.5, -0.6, 0.65));   // top-left (Qt y is down)
    vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));

    float spec = pow(max(dot(n, H), 0.0), 70.0);

    float rim = pow(d.rr, 2.5);
    float facing = dot(normalize(n.xy + 1e-4), normalize(L.xy));
    float rimLit = rim * max(facing, 0.0);
    float rimDark = rim * max(-facing, 0.0);

    // light focused through the drop lands on the side opposite the light
    float focus = pow(max(dot(n.xy, -L.xy), 0.0), 2.0) * (1.0 - rim);

    return vec4(spec, rimLit, rimDark, focus);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 size = vec2(max(1.0, ubuf.itemWidth), max(1.0, ubuf.itemHeight));
    vec2 px = uv * size;

    float t = ubuf.iTime * 0.001 * max(0.1, ubuf.speed);

    float mask = cornerMask(uv, size, ubuf.radius);
    if (mask <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // -------------------------------------------------------------------------
    // 1. DROP LAYERS (pixel-based, so drops keep their size on any surface)
    // -------------------------------------------------------------------------
    float cellW = clamp(min(size.x, size.y) * 0.20, 26.0, 64.0);
    float density = clamp(0.25 + 0.50 * ubuf.intensity, 0.10, 0.90);

    Drop a = slidingLayer(px / cellW, t, density);
    Drop b = slidingLayer(px / (cellW * 0.60) + vec2(31.7, 12.3), t * 1.2 + 13.0, density * 0.8);
    Drop m = mistLayer(px / (cellW * 0.22) + vec2(5.0, 9.0), t);

    vec4 la = lightDrop(a);
    vec4 lb = lightDrop(b);
    vec4 lm = lightDrop(m);

    vec4 Lsum = la * a.body + lb * b.body + lm * (m.body * 0.8);
    float trailMax = max(a.trail, b.trail);
    float bodyMax = max(a.body, max(b.body, m.body * 0.8));

    // Where a drop or trail passes, the "fog" is wiped clear
    float clear = max(bodyMax, trailMax * 0.7);

    // -------------------------------------------------------------------------
    // 2. FOG + COLOR (Matugen accents)
    // -------------------------------------------------------------------------
    float fogN = vnoise(px / 90.0 + vec2(0.0, t * 0.15));
    float gradT = clamp(uv.y * 0.8 + 0.1 + (fogN - 0.5) * 0.3, 0.0, 1.0);
    vec3 fogCol = mix(ubuf.accentA.rgb, ubuf.accentB.rgb, gradT);

    vec3 col = mix(ubuf.veilColor.rgb, fogCol, clamp(0.28 * ubuf.intensity, 0.0, 0.7));
    col = mix(col, fogCol * 1.25, clear * 0.35);               // brighter inside drops
    col += vec3(Lsum.x * 0.90);                                // specular glint
    col += vec3(Lsum.y * 0.25);                                // lit rim
    col -= vec3(Lsum.z * 0.25);                                // dark rim
    col += ubuf.accentB.rgb * Lsum.w * 0.35;                   // focused light
    col += vec3(trailMax * 0.10);                              // wet trail sheen
    col = clamp(col, 0.0, 1.0);

    // -------------------------------------------------------------------------
    // 3. TRANSLUCENCY FOR HYPRGLASS
    // Fog stays in the translucent range; drops wipe it thinner so the
    // HyprGlass blur / wallpaper shows through them more.
    // -------------------------------------------------------------------------
    float fogA = clamp(0.20 + ubuf.veilAlpha * 0.12 + (fogN - 0.5) * 0.05, 0.10, 0.40);
    float alpha = fogA * (1.0 - 0.65 * clear);
    alpha += Lsum.y * 0.18 + Lsum.z * 0.22 + Lsum.w * 0.08 + Lsum.x * 0.45 + trailMax * 0.03;
    alpha = clamp(alpha, 0.04, 0.60) * ubuf.qt_Opacity;

    // -------------------------------------------------------------------------
    // 4. CORNER CLIPPING & PREMULTIPLIED ALPHA
    // -------------------------------------------------------------------------
    alpha *= mask;
    fragColor = vec4(col * alpha, alpha);
}

