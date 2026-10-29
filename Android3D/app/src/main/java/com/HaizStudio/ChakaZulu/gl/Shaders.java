package com.HaizStudio.ChakaZulu.gl;

/** GLSL ES 3.0 sources. */
public final class Shaders {

    private Shaders() {
    }

    /**
     * Golden-hour sky, shared by the sky and by the fog so distant objects melt into the
     * exact colour of the sky behind them.
     */
    private static final String SKY_FUNCTION =
            "uniform vec3 uSunDir;\n" +
            "vec3 skyColor(vec3 d) {\n" +
            "  float h = d.y;\n" +
            "  vec3 zenith = vec3(0.20, 0.42, 0.78);\n" +
            "  vec3 mid = vec3(0.56, 0.74, 0.92);\n" +
            "  vec3 horizon = vec3(1.00, 0.82, 0.60);\n" +
            "  vec3 col = mix(horizon, mid, smoothstep(0.0, 0.22, h));\n" +
            "  col = mix(col, zenith, smoothstep(0.22, 0.85, h));\n" +
            "  float s = max(dot(d, uSunDir), 0.0);\n" +
            "  col += vec3(1.0, 0.50, 0.20) * pow(s, 6.0) * 0.55 * (1.0 - smoothstep(-0.1, 0.45, h));\n" +
            "  col = mix(col, vec3(0.93, 0.72, 0.52), smoothstep(0.0, -0.25, h));\n" +
            "  return col;\n" +
            "}\n";

    public static final String LIT_VERTEX =
            "#version 300 es\n" +
            "layout(location = 0) in vec3 aPos;\n" +
            "layout(location = 1) in vec3 aNormal;\n" +
            "layout(location = 2) in vec3 aColor;\n" +
            "uniform mat4 uModel;\n" +
            "uniform mat4 uViewProj;\n" +
            "uniform mat4 uLightViewProj;\n" +
            "uniform float uTime;\n" +
            "uniform float uWave;\n" +
            "out vec3 vNormal;\n" +
            "out vec3 vColor;\n" +
            "out vec3 vWorld;\n" +
            "out vec4 vLight;\n" +
            "void main() {\n" +
            "  vec4 w = uModel * vec4(aPos, 1.0);\n" +
            "  vec3 n = mat3(uModel) * aNormal;\n" +
            "  if (uWave > 0.0) {\n" +
            "    float a = sin(w.x * 0.9 + uTime * 1.6) * 0.5 + cos(w.z * 0.7 + uTime * 1.3) * 0.5;\n" +
            "    w.y += a * 0.12 * uWave;\n" +
            "    n = normalize(vec3(-cos(w.x * 0.9 + uTime * 1.6) * 0.05, 1.0, sin(w.z * 0.7 + uTime * 1.3) * 0.05));\n" +
            "  }\n" +
            "  vWorld = w.xyz;\n" +
            "  vNormal = n;\n" +
            "  vColor = aColor;\n" +
            "  vLight = uLightViewProj * w;\n" +
            "  gl_Position = uViewProj * w;\n" +
            "}\n";

    public static final String LIT_FRAGMENT =
            "#version 300 es\n" +
            "precision highp float;\n" +
            "precision highp sampler2DShadow;\n" +
            "in vec3 vNormal;\n" +
            "in vec3 vColor;\n" +
            "in vec3 vWorld;\n" +
            "in vec4 vLight;\n" +
            SKY_FUNCTION +
            "uniform vec3 uCamPos;\n" +
            "uniform vec3 uSunColor;\n" +
            "uniform vec3 uSkyAmbient;\n" +
            "uniform vec3 uGroundAmbient;\n" +
            "uniform vec2 uFog;\n" +
            "uniform sampler2DShadow uShadowMap;\n" +
            "uniform float uShadowTexel;\n" +
            "uniform float uEmissive;\n" +
            "uniform float uSpecular;\n" +
            "uniform float uFlash;\n" +
            "uniform float uAlpha;\n" +
            "uniform vec3 uTint;\n" +
            "out vec4 fragColor;\n" +
            "float shadow() {\n" +
            "  vec3 p = vLight.xyz / vLight.w * 0.5 + 0.5;\n" +
            "  if (p.x <= 0.0 || p.x >= 1.0 || p.y <= 0.0 || p.y >= 1.0 || p.z >= 1.0) return 1.0;\n" +
            "  float s = 0.0;\n" +
            "  for (int x = -1; x <= 1; x++)\n" +
            "    for (int y = -1; y <= 1; y++)\n" +
            "      s += texture(uShadowMap, vec3(p.xy + vec2(float(x), float(y)) * uShadowTexel, p.z - 0.0015));\n" +
            "  return s / 9.0;\n" +
            "}\n" +
            "void main() {\n" +
            "  vec3 N = normalize(vNormal);\n" +
            "  vec3 V = normalize(uCamPos - vWorld);\n" +
            "  float ndl = dot(N, uSunDir);\n" +
            "  float diff = smoothstep(-0.05, 0.5, ndl);\n" +
            "  float sh = shadow();\n" +
            "  vec3 albedo = vColor * uTint;\n" +
            "  vec3 ambient = mix(uGroundAmbient, uSkyAmbient, N.y * 0.5 + 0.5);\n" +
            "  vec3 col = albedo * (ambient + uSunColor * diff * sh);\n" +
            "  float rim = pow(1.0 - max(dot(N, V), 0.0), 3.0);\n" +
            "  col += rim * vec3(1.0, 0.80, 0.55) * 0.28 * (0.35 + 0.65 * sh);\n" +
            "  if (uSpecular > 0.0) {\n" +
            "    vec3 H = normalize(uSunDir + V);\n" +
            "    col += uSunColor * pow(max(dot(N, H), 0.0), 48.0) * uSpecular * sh;\n" +
            "  }\n" +
            "  col += albedo * uEmissive;\n" +
            "  col = mix(col, vec3(1.0), uFlash);\n" +
            "  vec3 toFrag = vWorld - uCamPos;\n" +
            "  float f = smoothstep(uFog.x, uFog.y, length(toFrag));\n" +
            "  col = mix(col, skyColor(normalize(toFrag)), f);\n" +
            "  fragColor = vec4(col, uAlpha);\n" +
            "}\n";

    public static final String DEPTH_VERTEX =
            "#version 300 es\n" +
            "layout(location = 0) in vec3 aPos;\n" +
            "uniform mat4 uModel;\n" +
            "uniform mat4 uViewProj;\n" +
            "void main() { gl_Position = uViewProj * uModel * vec4(aPos, 1.0); }\n";

    public static final String DEPTH_FRAGMENT =
            "#version 300 es\n" +
            "precision mediump float;\n" +
            "void main() { }\n";

    /** Full-screen triangle drawn behind everything. */
    public static final String SKY_VERTEX =
            "#version 300 es\n" +
            "out vec2 vNdc;\n" +
            "void main() {\n" +
            "  vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2)) * 2.0 - 1.0;\n" +
            "  vNdc = p;\n" +
            "  gl_Position = vec4(p, 1.0, 1.0);\n" +
            "}\n";

    public static final String SKY_FRAGMENT =
            "#version 300 es\n" +
            "precision highp float;\n" +
            "in vec2 vNdc;\n" +
            SKY_FUNCTION +
            "uniform mat4 uInvViewProj;\n" +
            "uniform vec3 uCamPos;\n" +
            "out vec4 fragColor;\n" +
            "void main() {\n" +
            "  vec4 far = uInvViewProj * vec4(vNdc, 1.0, 1.0);\n" +
            "  vec3 d = normalize(far.xyz / far.w - uCamPos);\n" +
            "  vec3 col = skyColor(d);\n" +
            "  float s = max(dot(d, uSunDir), 0.0);\n" +
            "  col += vec3(1.0, 0.85, 0.55) * pow(s, 90.0) * 0.6;\n" +
            "  col = mix(col, vec3(1.0, 0.97, 0.86), smoothstep(0.9982, 0.9990, s));\n" +
            "  fragColor = vec4(col, 1.0);\n" +
            "}\n";

    /** Camera-facing particles: position (3), corner uv (2), colour rgba (4), shape (1). */
    public static final String PARTICLE_VERTEX =
            "#version 300 es\n" +
            "layout(location = 0) in vec3 aPos;\n" +
            "layout(location = 1) in vec2 aUv;\n" +
            "layout(location = 2) in vec4 aColor;\n" +
            "layout(location = 3) in float aShape;\n" +
            "uniform mat4 uViewProj;\n" +
            "out vec2 vUv;\n" +
            "out vec4 vColor;\n" +
            "out float vShape;\n" +
            "void main() {\n" +
            "  vUv = aUv;\n" +
            "  vColor = aColor;\n" +
            "  vShape = aShape;\n" +
            "  gl_Position = uViewProj * vec4(aPos, 1.0);\n" +
            "}\n";

    public static final String PARTICLE_FRAGMENT =
            "#version 300 es\n" +
            "precision mediump float;\n" +
            "in vec2 vUv;\n" +
            "in vec4 vColor;\n" +
            "in float vShape;\n" +
            "out vec4 fragColor;\n" +
            "void main() {\n" +
            "  float a = 1.0;\n" +
            "  vec2 c = vUv * 2.0 - 1.0;\n" +
            "  if (vShape < 0.5) {\n" +
            "    a = smoothstep(1.0, 0.35, length(c));\n" +
            "  } else if (vShape < 1.5) {\n" +
            "    float d = length(c);\n" +
            "    float star = max(1.0 - abs(c.x * c.y) * 14.0, 0.0) * smoothstep(1.0, 0.0, d);\n" +
            "    a = max(star, smoothstep(0.45, 0.0, d));\n" +
            "  }\n" +
            "  fragColor = vec4(vColor.rgb, vColor.a * a);\n" +
            "}\n";
}
