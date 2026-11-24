shader_type spatial;
render_mode cull_back;

// Nubes de voxeles: dithering ordenado (Bayer 4x4) con 30% de cobertura.
// El 70% de pixeles descartados las deja muy transparentes y deja ver el cielo.
const float COVERAGE = 0.3;

void fragment() {
	int px = int(FRAGCOORD.x) % 4;
	int py = int(FRAGCOORD.y) % 4;
	float bayer[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0);
	float t = (bayer[py * 4 + px] + 0.5) / 16.0;
	if (t > COVERAGE) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
