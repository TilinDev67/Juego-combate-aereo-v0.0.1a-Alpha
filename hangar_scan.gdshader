// Entrada mecanica del avion en el hangar: persiana de lineas. Solo se ve lo que queda por debajo de "reveal_y"
// (altura del mundo) y, en la franja justo bajo ese borde, solo unas lineas horizontales, como las lamas de una
// persiana que se abre. Pinta con el color de vertice, como los modelos.
shader_type spatial;

uniform float reveal_y;                                       // altura del mundo por debajo de la que se ve el avion
uniform float band = 1.2;                                     // altura (m) bajo el borde donde solo se ven lineas
uniform float slat_density = 6.0;                             // lineas de la persiana por metro
uniform float slat_duty = 0.5;                                // fraccion de cada linea que se ve (0..1)
uniform float specular_amount = 0.0;                          // brillo especular: lo fija el hangar con el valor de los modelos (VoxModels.VOX_SPECULAR)

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (world_y > reveal_y) {
		discard;
	}
	if (world_y > reveal_y - band && fract(world_y * slat_density) > slat_duty) {
		discard;
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = specular_amount;
}
