shader_type spatial;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = abs(fract(wpos.xz / 200.0 - 0.5) - 0.5) / fwidth(wpos.xz / 200.0);
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	vec2 c = floor(wpos.xz / 200.0);
	float checker = mod(c.x + c.y, 2.0);
	vec3 base = mix(vec3(0.22, 0.45, 0.2), vec3(0.27, 0.52, 0.24), checker);
	ALBEDO = mix(base, vec3(0.8, 0.9, 0.7), line * 0.35);
	ROUGHNESS = 1.0;
}
