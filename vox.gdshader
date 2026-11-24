// Material de los aviones de voxeles: color por vertice (ya oscurecido por la oclusion ambiental) con la
// oclusion ambiental activable. La malla guarda en UV.x cuanto oscurece la oclusion a cada vertice (1 = nada).
shader_type spatial;

uniform bool ao_on = true;   // false = se deshace el oscurecimiento y se ve el color sin oclusion
uniform float specular_amount = 0.0;   // brillo especular (VoxModels.VOX_SPECULAR)

void fragment() {
	vec3 col = COLOR.rgb;
	if (!ao_on) {
		col /= UV.x;
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = specular_amount;
}
