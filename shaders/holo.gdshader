shader_type spatial;
// Hologramskylt: färgskiftande mönster, scanlines och flimmer.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 col_a : source_color = vec3(1.0, 0.2, 0.7);
uniform vec3 col_b : source_color = vec3(0.0, 0.9, 1.0);
uniform float seed = 0.0;
uniform int pattern = 0;

void fragment() {
	vec2 uv = UV;
	float t = TIME + seed * 10.0;
	float scan = 0.65 + 0.35 * sin(uv.y * 220.0 + t * 8.0);
	float glitch = step(0.97, fract(sin(floor(t * 6.0) * 12.9898 + seed) * 43758.5));
	uv.x += glitch * 0.03 * sin(uv.y * 40.0);
	float v = 0.0;
	vec2 c = uv - 0.5;
	if (pattern == 0) {
		float r = length(c * vec2(1.6, 1.0));
		v = smoothstep(0.03, 0.0, abs(fract(r * 4.0 - t * 0.4) - 0.5) - 0.18) * step(r, 0.48);
	} else if (pattern == 1) {
		float w = sin(uv.x * 18.0 + t * 2.0) * 0.18 + sin(uv.x * 7.0 - t) * 0.1;
		v = smoothstep(0.03, 0.0, abs(c.y - w)) + 0.15 * step(abs(c.y), 0.4);
	} else if (pattern == 2) {
		vec2 g = fract(uv * vec2(8.0, 5.0) + vec2(0.0, t * 0.3));
		float cell = step(0.5, fract(sin(dot(floor(uv * vec2(8.0, 5.0) + vec2(0.0, t * 0.3)), vec2(12.9, 78.2))) * 43758.0));
		v = cell * step(0.1, g.x) * step(0.1, g.y) * 0.8;
	} else {
		float a = atan(c.y, c.x);
		v = step(0.5, fract(a * 1.2732 + t * 0.5)) * step(length(c), 0.45) * step(0.18, length(c));
	}
	float frame = step(abs(c.x), 0.49) * step(abs(c.y), 0.49) * (1.0 - step(abs(c.x), 0.47) * step(abs(c.y), 0.46));
	vec3 col = mix(col_a, col_b, uv.y + 0.3 * sin(t));
	float flick = 0.85 + 0.15 * sin(t * 37.0);
	ALBEDO = col * (v * scan * 0.8 + frame * 1.2 + 0.03) * flick * 0.9;
}
