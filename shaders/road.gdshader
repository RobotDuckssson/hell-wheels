shader_type spatial;
// Våt asfalt med körfältslinjer, lysande kantlinjer, pölar och schackrutig startlinje.

uniform float width = 18.0;
uniform float lanes = 3.0;
uniform vec3 edge_color : source_color = vec3(0.0, 0.9, 1.0);
uniform float wetness = 1.0;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = UV.x;
	float v = UV.y;
	float n = noise(wpos.xz * 0.15) * 0.55 + noise(wpos.xz * 0.7) * 0.3 + noise(wpos.xz * 4.0) * 0.15;
	vec3 col = vec3(0.1, 0.1, 0.115) * (0.75 + 0.5 * n);
	float rough = 0.6 - 0.15 * n;
	// pölar
	float puddle = smoothstep(0.5, 0.62, noise(wpos.xz * 0.06 + vec2(3.1, 7.7)) * 0.7 + noise(wpos.xz * 0.3) * 0.3);
	rough = mix(rough, 0.03, max(puddle, 0.35) * wetness);
	col = mix(col, vec3(0.05, 0.05, 0.06), puddle * wetness);
	float um = u * width;
	vec3 emit = vec3(0.0);
	// körfältslinjer (streckade)
	float lane_w = width / lanes;
	float dl = abs(fract(um / lane_w + 0.5) - 0.5) * lane_w;
	float dash = step(0.45, fract(v / 10.0));
	float lane_line = (1.0 - smoothstep(0.07, 0.11, dl)) * dash * step(0.6, um) * step(um, width - 0.6);
	// lysande kantlinjer
	float de = min(abs(um - 0.55), abs(um - (width - 0.55)));
	float edge = 1.0 - smoothstep(0.08, 0.14, de);
	// startlinje
	float start = step(v, 3.0);
	float checker = mod(floor(um / 1.0) + floor(v / 1.0), 2.0);
	col = mix(col, vec3(0.75), lane_line * (1.0 - puddle * 0.5));
	rough = mix(rough, 0.4, lane_line);
	emit += vec3(0.25) * lane_line;
	col = mix(col, edge_color * 0.6, edge);
	emit += edge_color * 2.5 * edge;
	col = mix(col, vec3(checker * 0.85), start);
	emit += vec3(checker) * 0.6 * start;
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	EMISSION = emit;
}
