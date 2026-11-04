shader_type spatial;
// Skyskrapor: fönsterrutnät där en del fönster lyser. INSTANCE_CUSTOM:
// x = slump, y = stil (0..1), z = ljusandel, w = neonfärgsval.

uniform vec3 neon_a : source_color = vec3(1.0, 0.15, 0.6);
uniform vec3 neon_b : source_color = vec3(0.0, 0.9, 1.0);
uniform float time_scale = 1.0;
uniform bool day = false;
uniform bool use_fac = false;
uniform sampler2D fac_a_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fac_a_emi : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fac_b_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fac_b_emi : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D conc_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_conc = false;

// Stockholmsfärger: ockra, gult, terrakotta, laxrosa, ljusgrönt, beige, vitgrått, tegelrött, blågrått
const vec3 PAL[9] = vec3[](vec3(0.82, 0.6, 0.28), vec3(0.9, 0.78, 0.42), vec3(0.7, 0.34, 0.2),
	vec3(0.86, 0.58, 0.48), vec3(0.62, 0.7, 0.52), vec3(0.84, 0.77, 0.64), vec3(0.84, 0.84, 0.8),
	vec3(0.52, 0.22, 0.15), vec3(0.58, 0.64, 0.7));

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 cdata;
varying vec3 lpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cdata = INSTANCE_CUSTOM;
	lpos = VERTEX;
}

void day_fragment(inout vec3 alb, inout float met, inout float rough) {
	float seed = cdata.x * 97.0;
	if (abs(wnrm.y) > 0.5) {
		alb = vec3(0.22, 0.22, 0.24);
		rough = 0.8;
		return;
	}
	vec2 uv = abs(wnrm.x) > 0.5 ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
	float face = abs(wnrm.x) > 0.5 ? sign(wnrm.x) * 2.0 : sign(wnrm.z) * 3.0;
	if (cdata.y > 0.88 && use_conc && hash(vec2(seed, 9.0)) < 0.5) {
		// moderna hus i betongpaneler med bandfönster
		vec3 cc = texture(conc_col, vec2(uv.x, -uv.y) / 2.1).rgb * 1.25;
		float band = step(0.45, fract(uv.y / 3.6)) * step(fract(uv.y / 3.6), 0.85);
		float mull = step(0.94, fract(uv.x / 2.1));
		float wn = band * (1.0 - mull);
		alb = mix(cc, vec3(0.1, 0.13, 0.17), wn);
		met = wn * 0.7;
		rough = mix(0.8, 0.08, wn);
		return;
	}
	if (cdata.y > 0.88) {
		// moderna glashus
		vec2 g = uv / vec2(1.6, 3.6);
		vec2 f = fract(g);
		float mull = step(f.x, 0.06) + step(f.y, 0.08);
		alb = mix(vec3(0.12, 0.18, 0.24), vec3(0.75, 0.78, 0.8), clamp(mull, 0.0, 1.0));
		met = mix(0.85, 0.6, clamp(mull, 0.0, 1.0));
		rough = mix(0.06, 0.4, clamp(mull, 0.0, 1.0));
		return;
	}
	int pi = int(floor(cdata.w * 8.999));
	vec3 base = PAL[pi] * (0.88 + 0.22 * hash(vec2(seed, 3.0)));
	vec2 cs = vec2(3.2, 3.4);
	vec2 cell = uv / cs;
	vec2 f = fract(cell);
	vec2 dd = fwidth(cell);
	float aa = clamp(1.0 - max(dd.x, dd.y) * 1.3, 0.0, 1.0);
	float win = step(0.3, f.x) * step(f.x, 0.7) * step(0.24, f.y) * step(f.y, 0.82);
	float frame = step(0.26, f.x) * step(f.x, 0.74) * step(0.2, f.y) * step(f.y, 0.86) - win;
	float cornice = 1.0 - step(0.05, f.y);
	// bottenvåning med butiksfönster
	if (wpos.y < 4.4) {
		float shop = step(0.12, fract(uv.x / 6.0)) * step(fract(uv.x / 6.0), 0.88) * step(0.6, wpos.y) * step(wpos.y, 3.6);
		win = shop;
		frame = 0.0;
		base *= 0.75;
		cornice = 0.0;
	}
	vec3 glass = vec3(0.07, 0.09, 0.12) + vec3(0.08, 0.06, 0.03) * step(0.8, hash(floor(cell) + vec2(seed, face)));
	vec3 detail = mix(base, vec3(0.93, 0.92, 0.88), frame);
	detail = mix(detail, base * 0.8, cornice);
	detail = mix(detail, glass, win);
	vec3 avg = mix(base * 0.92, glass, 0.16);
	alb = mix(avg, detail, aa);
	met = mix(0.0, 0.5, win * aa);
	rough = mix(0.8, 0.1, win * aa);
}

void fragment() {
	if (day) {
		vec3 a = vec3(0.5);
		float m = 0.0;
		float r = 0.8;
		day_fragment(a, m, r);
		ALBEDO = a;
		METALLIC = m;
		ROUGHNESS = r;
	} else {
	float seed = cdata.x * 97.0;
	float style = cdata.y;
	float litf = cdata.z;
	vec3 base = mix(vec3(0.035, 0.035, 0.045), vec3(0.07, 0.065, 0.075), hash(vec2(seed, 1.0)));
	if (abs(wnrm.y) > 0.5) {
		ALBEDO = base * 0.6;
		ROUGHNESS = 0.8;
	} else {
		vec2 uv = abs(wnrm.x) > 0.5 ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
		float face = abs(wnrm.x) > 0.5 ? sign(wnrm.x) * 2.0 : sign(wnrm.z) * 3.0;
		vec2 cs = style < 0.5 ? vec2(2.4, 3.4) : vec2(1.6, 3.0);
		vec2 cell = uv / cs;
		vec2 id = floor(cell);
		vec2 f = fract(cell);
		float wx = style < 0.5 ? 0.18 : 0.06;
		float win = step(wx, f.x) * step(f.x, 1.0 - wx) * step(0.22, f.y) * step(f.y, 0.85);
		float r = hash(id + vec2(seed, face));
		// hela våningar som är tända eller släckta
		float floor_on = step(0.35, hash(vec2(id.y, seed + face)));
		float lit = step(1.0 - litf, r) * floor_on;
		float flick = 1.0;
		if (r > 0.985) { flick = 0.6 + 0.4 * sin(TIME * 13.0 + seed); }
		vec3 warm = vec3(1.0, 0.68, 0.38);
		vec3 cool = vec3(0.55, 0.75, 1.0);
		vec3 wc = mix(warm, cool, step(0.6, hash(id * 1.7 + seed)));
		if (hash(id * 3.1 + seed) > 0.93) { wc = mix(neon_a, neon_b, step(0.5, hash(id + 5.0))); }
		vec2 dd = fwidth(cell);
		float aa = clamp(1.0 - max(dd.x, dd.y) * 1.2, 0.0, 1.0);
		float avg = (1.0 - 2.0 * wx) * 0.63 * litf * 0.65;
		float lw = mix(avg, win * lit, aa);
		float glass = mix(0.55, win, aa);
		ALBEDO = mix(base, vec3(0.02, 0.025, 0.035), glass);
		METALLIC = mix(0.2, 0.8, glass);
		ROUGHNESS = mix(0.7, 0.12, glass);
		vec3 e = wc * lw * 2.2 * flick;
		// neonband längs kanterna på vissa hus
		if (style > 0.75) {
			float edge = abs(wnrm.x) > 0.5 ? abs(lpos.z) : abs(lpos.x);
			float band = smoothstep(0.47, 0.49, edge);
			vec3 nc = cdata.w > 0.5 ? neon_a : neon_b;
			e += nc * band * 3.0;
		}
		// horisontella ljusband
		if (style > 0.55 && style < 0.75) {
			float hb = 1.0 - smoothstep(0.15, 0.35, abs(fract(wpos.y / 24.0) - 0.5) * 24.0);
			e += mix(neon_a, neon_b, cdata.w) * hb * 1.8;
		}
		EMISSION = e;
		// Fototexturer från ambientCG (Facade008 = glas, Facade013 = kontorsrutnät)
		if (use_fac && style < 0.6) {
			bool glassy = style < 0.28;
			float tile = glassy ? 90.0 : 100.0;
			vec2 tuv = vec2(uv.x, -uv.y) / tile + vec2(cdata.x * 7.31 + face * 0.37, cdata.w * 3.17);
			vec3 tc = glassy ? texture(fac_a_col, tuv).rgb : texture(fac_b_col, tuv).rgb;
			vec3 te = glassy ? texture(fac_a_emi, tuv).rgb : texture(fac_b_emi, tuv).rgb;
			// tona färgen lite per hus så att de inte ser likadana ut
			vec3 tint = mix(vec3(1.0), mix(vec3(1.0, 0.85, 0.7), vec3(0.75, 0.9, 1.1), cdata.w), 0.35);
			ALBEDO = tc * tint;
			METALLIC = glassy ? 0.75 : 0.3;
			ROUGHNESS = glassy ? 0.15 : 0.5;
			float k = (glassy ? 3.0 : 2.0) * (0.55 + litf * 1.4);
			EMISSION = te * tint * k;
		}
	}
}
}
