shader_type spatial;
// Kenneys bilar: byter färgrutan för karossen mot bilens lack och mörknar vid skador.

uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform int body_cell = 29;
uniform vec3 paint : source_color = vec3(1.0, 0.0, 0.0);
uniform float dark = 0.0;

void fragment() {
	vec3 c = texture(colormap, UV).rgb;
	int idx = int(floor(UV.x * 16.0)) + int(floor(UV.y * 4.0)) * 16;
	bool body = idx == body_cell;
	if (body) {
		float l = dot(c, vec3(0.299, 0.587, 0.114));
		c = paint * (0.45 + l * 0.9);
	}
	c = mix(c, vec3(0.05, 0.045, 0.04), dark);
	ALBEDO = c;
	METALLIC = body ? 0.45 : 0.1;
	ROUGHNESS = body ? mix(0.28, 0.9, dark) : 0.6;
	SPECULAR = 0.5;
}
