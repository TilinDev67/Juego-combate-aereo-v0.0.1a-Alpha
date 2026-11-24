shader_type spatial;

uniform sampler2D heightmap : filter_linear, repeat_enable;   // alturas (m) del relieve; se repite cada "tile" metros
uniform float tile = 16384.0;         // lado (m) del mapa de alturas
uniform float spacing = 32.0;         // separacion (m) entre vertices de la malla: sirve para calcular la pendiente
uniform vec3 rock_color = vec3(0.4, 0.37, 0.32);  // color de las laderas empinadas
uniform float slope_start = 0.1;      // pendiente (0 = llano, 1 = vertical) donde empieza a asomar la roca
uniform float slope_end = 0.3;        // pendiente donde la ladera es toda roca
uniform float patch_size = 400.0;     // tamano de las manchas grandes de color (m)
uniform float mid_size = 90.0;        // tamano de los matices medianos (m)
uniform float grain_size = 12.0;      // tamano del grano fino (m); se apaga de lejos para no parpadear
uniform vec3 dry_color = vec3(0.45, 0.42, 0.2);   // color de las manchas de tierra seca entre la hierba
uniform float dry_amount = 0.55;      // cuanto se tine la hierba de tierra seca donde hay mancha (0-1)
uniform float shade_range = 0.35;     // cuanto varia el brillo de un sitio a otro (0 = liso)

varying vec3 wpos;
varying float slope;

float height_at(vec2 xz) {
	return textureLod(heightmap, xz / tile, 0.0).r;
}

// Levanta cada vertice a la altura del mapa y saca la normal de las alturas vecinas.
void vertex() {
	vec2 xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float h = height_at(xz);
	VERTEX.y = h;
	wpos = vec3(xz.x, h, xz.y);
	float hl = height_at(xz - vec2(spacing, 0.0));
	float hr = height_at(xz + vec2(spacing, 0.0));
	float hd = height_at(xz - vec2(0.0, spacing));
	float hu = height_at(xz + vec2(0.0, spacing));
	NORMAL = normalize(vec3(hl - hr, 2.0 * spacing, hd - hu));
	slope = 1.0 - NORMAL.y;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Ruido de valor suave en 0..1.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 g = abs(fract(wpos.xz / 200.0 - 0.5) - 0.5) / fwidth(wpos.xz / 200.0);
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	vec2 c = floor(wpos.xz / 200.0);
	float checker = mod(c.x + c.y, 2.0);
	vec3 base = mix(vec3(0.22, 0.45, 0.2), vec3(0.27, 0.52, 0.24), checker);

	// ruido en tres escalas; las finas se desvanecen cuando un pixel abarca mas que su tamano
	float footprint = length(fwidth(wpos.xz));
	float coarse = vnoise(wpos.xz / patch_size);
	float mid = vnoise(wpos.xz / mid_size) * (1.0 - smoothstep(mid_size * 0.1, mid_size * 0.3, footprint));
	float grain = vnoise(wpos.xz / grain_size) * (1.0 - smoothstep(grain_size * 0.1, grain_size * 0.3, footprint));
	float n = coarse * 0.5 + mid * 0.3 + grain * 0.2;
	base = mix(base, dry_color, smoothstep(0.55, 0.8, coarse) * dry_amount);
	base = mix(base, rock_color, smoothstep(slope_start, slope_end, slope));
	base *= 1.0 + (n - 0.5) * 2.0 * shade_range;

	ALBEDO = mix(base, vec3(0.8, 0.9, 0.7), line * 0.35);
	ROUGHNESS = 1.0;
}
