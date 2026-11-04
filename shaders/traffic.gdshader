shader_type spatial;
// Flygande trafik: mörk kropp, vita ljus fram, röda bak. Polisbilar blinkar.

varying vec3 lpos;
varying vec4 cdata;

void vertex() {
	lpos = VERTEX;
	cdata = INSTANCE_CUSTOM;
}

void fragment() {
	ALBEDO = vec3(0.03);
	METALLIC = 0.8;
	ROUGHNESS = 0.3;
	vec3 e = vec3(0.0);
	if (lpos.z < -0.42) { e = vec3(1.0, 0.95, 0.85) * 8.0; }
	if (lpos.z > 0.42) { e = vec3(1.0, 0.05, 0.05) * 6.0; }
	if (cdata.x > 0.9 && lpos.y > 0.3) {
		float b = step(0.5, fract(TIME * 3.0 + cdata.y));
		e += mix(vec3(1.0, 0.0, 0.0), vec3(0.0, 0.2, 1.0), b) * 10.0;
	}
	if (abs(lpos.x) > 0.45 && abs(lpos.z) < 0.3) { e += vec3(0.2, 0.8, 1.0) * 2.0 * cdata.z; }
	EMISSION = e;
}
