shader_type spatial;
// Gatunivån långt nedanför: våt betong, ett rutnät av gator med strömmar av
// billjus (vita åt ena hållet, röda åt andra) och lysande övergångsställen.

uniform vec3 neon : source_color = vec3(1.0, 0.2, 0.6);
uniform bool day = false;
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

// En gata längs koordinat a (tvärs) med trafik längs b.
vec3 street(float a, float b, float seed, out float on) {
	float spacing = 90.0;
	float d = abs(fract(a / spacing) - 0.5) * spacing;
	on = 1.0 - smoothstep(6.0, 7.0, d);
	float lane = step(0.0, fract(a / spacing) - 0.5);   // vilken sida av gatan
	float row = floor(a / spacing);
	float spd = 14.0 + hash(vec2(row, seed)) * 10.0;
	float pos = b + (lane > 0.5 ? TIME * spd : -TIME * spd);
	float cell = floor(pos / 9.0);
	float car = step(0.55, hash(vec2(cell, row + seed)));
	float dot_ = (1.0 - smoothstep(0.0, 0.9, abs(fract(pos / 9.0) - 0.5) * 9.0 - 0.6));
	float in_lane = 1.0 - smoothstep(0.4, 0.8, abs(d - 3.0));
	vec3 c = lane > 0.5 ? vec3(1.0, 0.9, 0.75) : vec3(1.0, 0.08, 0.05);
	return c * car * dot_ * in_lane * on * 3.0;
}

float land_value(vec2 p) {
	return sin(p.x * 0.0045 + 1.3) + sin(p.y * 0.0052 + 0.7) + 0.7 * sin((p.x + p.y) * 0.0031 + 2.1) + 0.5 * sin((p.x - p.y) * 0.007 + 0.4);
}

void day_ground(vec2 p, out vec3 alb, out float rough, out vec3 nmap, out float spec) {
	float L = land_value(p);
	float land = smoothstep(-0.12, -0.1, L);
	// vatten med rörliga vågor
	vec2 q = p * 0.09 + vec2(TIME * 0.05, TIME * 0.03);
	vec2 q2 = p * 0.23 - vec2(TIME * 0.04, -TIME * 0.06);
	float e = 0.05;
	float h0 = noise(q) + 0.5 * noise(q2);
	float hx = noise(q + vec2(e, 0.0)) + 0.5 * noise(q2 + vec2(e, 0.0));
	float hz = noise(q + vec2(0.0, e)) + 0.5 * noise(q2 + vec2(0.0, e));
	vec3 wn = normalize(vec3((h0 - hx) * 3.0, (h0 - hz) * 3.0, 1.0));
	vec3 water = vec3(0.05, 0.16, 0.22);
	// land: stenläggning, gator och parker
	float n = noise(p * 0.3) * 0.6 + noise(p * 2.0) * 0.4;
	vec3 pave = vec3(0.56, 0.53, 0.49) * (0.85 + 0.3 * n);
	float on_x; float on_z;
	street(p.x, p.y, 1.0, on_x);
	street(p.y, p.x, 7.0, on_z);
	float road = max(on_x, on_z);
	pave = mix(pave, vec3(0.2, 0.2, 0.21), road);
	float park = smoothstep(0.62, 0.66, noise(p * 0.012 + vec2(4.0, 1.0))) * (1.0 - road);
	pave = mix(pave, vec3(0.22, 0.38, 0.15) * (0.8 + 0.4 * noise(p * 0.8)), park);
	// kajkant i granit
	float quay = smoothstep(-0.1, -0.08, L) * (1.0 - smoothstep(-0.02, 0.0, L));
	pave = mix(pave, vec3(0.62, 0.6, 0.58), quay);
	alb = mix(water, pave, land);
	rough = mix(0.03, mix(0.75, 0.9, park), land);
	nmap = mix(wn * 0.5 + 0.5, vec3(0.5, 0.5, 1.0), land);
	spec = mix(0.6, 0.4, land);
}

void fragment() {
	vec2 p = wpos.xz;
	if (day) {
		vec3 a; float r; vec3 nm; float sp;
		day_ground(p, a, r, nm, sp);
		ALBEDO = a;
		ROUGHNESS = r;
		NORMAL_MAP = nm;
		SPECULAR = sp;
	} else {
	vec2 tile = p / 3.0;
	vec2 f = abs(fract(tile) - 0.5);
	float aa = clamp(1.0 - length(fwidth(tile)) * 2.0, 0.0, 1.0);
	float joint = 1.0 - smoothstep(0.46, 0.49, max(f.x, f.y));
	float n = noise(p * 0.2) * 0.6 + noise(p * 1.3) * 0.4;
	float t = hash(floor(tile));
	vec3 col = vec3(0.09, 0.085, 0.095) * (0.7 + 0.5 * n) * (0.85 + 0.3 * t);
	col = mix(col * 0.5, col, mix(1.0, joint, aa));
	float puddle = smoothstep(0.55, 0.7, noise(p * 0.04 + vec2(9.0, 2.0)));
	float on_x; float on_z;
	vec3 e = street(p.x, p.y, 1.0, on_x) + street(p.y, p.x, 7.0, on_z);
	float road = max(on_x, on_z);
	col = mix(col, vec3(0.03, 0.03, 0.035), road);
	// övergångsställen i korsningarna
	float cross_ = on_x * on_z;
	e += neon * cross_ * 0.25;
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.5, 0.05, max(puddle, 0.25)), 0.1, road);
	SPECULAR = 0.55;
	EMISSION = e;
}
}
