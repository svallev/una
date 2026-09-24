// SPIKE S2 — papel arrugado: desplazamiento por ruido fractal + sombreado de pliegues.
// Equivalente al filtro SVG del prototipo (feTurbulence + feDisplacementMap + feDiffuseLighting).
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uProgress; // 0..1 (ya con easing)
uniform sampler2D uTexture;

out vec4 fragColor;

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
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
    p *= 2.03;
    a *= 0.5;
  }
  return v;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / uSize;
  // Frecuencia base similar a baseFrequency="0.021 0.016" del prototipo.
  vec2 p = frag * vec2(0.021, 0.016);
  float h = fbm(p);
  float hx = fbm(p + vec2(0.35, 0.0));
  float hy = fbm(p + vec2(0.0, 0.35));
  // Desplazamiento (scale 46 px en el prototipo).
  vec2 disp = (vec2(hx, hy) - 0.5) * 46.0 * uProgress / uSize;
  vec4 color = texture(uTexture, clamp(uv + disp, 0.0, 1.0));
  // Luz difusa sobre la "altura" del pliegue (surfaceScale 7).
  vec3 n = normalize(vec3((h - hx) * 7.0 * uProgress, (h - hy) * 7.0 * uProgress, 0.25));
  float light = clamp(dot(n, normalize(vec3(-0.4, -0.5, 0.75))), 0.0, 1.0);
  float shade = mix(1.0, 0.55 + 0.6 * light, uProgress);
  fragColor = vec4(color.rgb * shade, color.a) ;
}
