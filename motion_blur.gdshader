shader_type spatial;
render_mode unshaded, fog_disabled;

// Desenfoque de movimiento de camara a pantalla completa: reproyecta cada pixel con la posicion que
// tenia la camara en el paso de fisica anterior y promedia la imagen a lo largo de ese desplazamiento.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform mat4 prev_view;          // inversa de la transformacion de la camara en el paso anterior
uniform float strength = 1.0;    // 0 = sin desenfoque; 1 = el desplazamiento de un paso de fisica
uniform float max_blur = 0.08;   // longitud maxima del desenfoque (fraccion de la pantalla)
uniform float clear_dist = 0.0;  // distancia a la camara por debajo de la cual no hay desenfoque (el avion del jugador)
const float MIN_BLUR = 0.0003;   // por debajo de este desplazamiento (fraccion de pantalla) no se desenfoca
const int SAMPLES = 16;         // muestras por pixel: con un desenfoque mas largo hacen falta mas para que no se vean las copias

uniform float vibrance = 0.0;    // 0 = sin cambio; 0.3 = los colores apagados ganan hasta un 30% de saturacion

// Rayos de sol (god rays) en pantalla: desde cada pixel se camina hacia el sol sumando el resplandor solar
// del cielo visible (aunque el sol quede fuera de pantalla); lo que tapa la profundidad (terreno, bosque,
// aviones, nubes) va apagando el rayo y deja las franjas de luz entre medias.
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);  // direccion hacia el sol en el mundo
uniform vec3 sun_color = vec3(1.0);
uniform float ray_intensity = 0.0;  // brillo global de los rayos (0 = apagado)
uniform float ray_density = 0.9;    // largo del rayo: fraccion de la distancia pixel-sol que se recorre
uniform float ray_decay = 0.95;     // lo que pesa cada muestra respecto a la anterior (menor = rayos mas cortos)
uniform float ray_weight = 0.6;     // peso de cada muestra
uniform float ray_spread = 12.0;    // concentracion del resplandor alrededor del sol (mayor = mas estrecho)
uniform float ray_streaks = 0.0;    // 0 = rayos solo por las nubes; 1 = radios fijos muy marcados alrededor del sol
uniform float flare_intensity = 0.0; // brillo del destello de lente del sol (0 = apagado)
uniform float ray_absorb = 0.3;     // lo que apaga el rayo cada muestra que cae en una nube o en el terreno (0-1)
const int RAY_SAMPLES = 32;         // muestras por pixel de los rayos
const float RAY_MAX_LEN = 1.0;      // largo maximo del rayo en pantalla: con el sol muy lejos o fuera, las muestras no se estiran
const float RAY_STREAKS_A = 23.0;   // frecuencias enteras de los radios fijos alrededor del sol (mas = mas radios)
const float RAY_STREAKS_B = 9.0;
const float FLARE_VIS_RADIUS = 0.006;  // separacion (fraccion de pantalla) de las lecturas que miden si el sol esta tapado
const int GHOSTS = 4;               // reflejos de lente
const float GHOST_POS[4] = float[4](-0.4, -0.9, 0.55, -1.6);  // posicion sobre la recta sol-centro (1 = el sol, 0 = centro, negativo = lado opuesto)
const float GHOST_RADIUS[4] = float[4](0.05, 0.09, 0.035, 0.12);
const vec3 GHOST_TINT[4] = vec3[4](vec3(1.0, 0.7, 0.4), vec3(0.5, 0.8, 1.0), vec3(0.8, 1.0, 0.6), vec3(1.0, 0.6, 0.8));
const float SKY_DEPTH = 0.00001;    // profundidad (Z invertida: 0 = lejos) por debajo de la cual el pixel es cielo

void vertex() {
	// cubre toda la pantalla, pegado al plano cercano
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	vec4 world_pos = INV_VIEW_MATRIX * vec4(view_pos.xyz, 1.0);
	vec4 prev_clip = PROJECTION_MATRIX * (prev_view * world_pos);
	vec2 vel = vec2(0.0);
	if (prev_clip.w > 0.0001) {
		vec2 prev_uv = prev_clip.xy / prev_clip.w * 0.5 + 0.5;
		vel = (SCREEN_UV - prev_uv) * strength;
	}
	// el avion del jugador se mueve con la camara: no se desenfoca, solo lo que esta mas lejos que el
	float dist = length(view_pos.xyz);
	float keep_blur = (isnan(dist) || isinf(dist)) ? 1.0 : smoothstep(clear_dist - 4.0, clear_dist, dist);
	vel *= keep_blur;
	float len = length(vel);
	if (len > max_blur) {
		vel *= max_blur / len;
	}
	vec3 col;
	if (len < MIN_BLUR) {
		col = texture(screen_texture, SCREEN_UV).rgb;   // casi quieto: una sola lectura en vez de 16
	} else {
		col = vec3(0.0);
		for (int i = 0; i < SAMPLES; i++) {
			float t = float(i) / float(SAMPLES - 1) - 0.5;
			col += texture(screen_texture, SCREEN_UV + vel * t).rgb;
		}
		col /= float(SAMPLES);
	}

	// el sol delante de la camara; detras (o casi de canto) los rayos se apagan
	vec3 sun_view = (VIEW_MATRIX * vec4(sun_dir, 0.0)).xyz;
	float facing = smoothstep(0.0, 0.3, -sun_view.z);
	if (facing > 0.0 && (ray_intensity > 0.0 || flare_intensity > 0.0)) {
		vec4 sun_clip = PROJECTION_MATRIX * vec4(sun_view, 0.0);
		vec2 sun_uv = sun_clip.xy / sun_clip.w * 0.5 + 0.5;
		vec2 aspect = vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0);
		if (ray_intensity > 0.0) {
			vec2 to_sun = sun_uv - SCREEN_UV;
			float to_sun_len = max(length(to_sun), 0.0001);
			float reach = min(to_sun_len * ray_density, RAY_MAX_LEN);
			vec2 step_uv = to_sun / to_sun_len * reach / float(RAY_SAMPLES);
			vec2 uv = SCREEN_UV;
			float trans = 1.0;
			float decay = 1.0;
			float acc = 0.0;
			for (int i = 0; i < RAY_SAMPLES; i++) {
				uv += step_uv;
				float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
				float sky = step(texture(depth_texture, uv).x, SKY_DEPTH);
				// resplandor del cielo en esa muestra: cuanto mas cerca de la direccion del sol, mas luz
				vec4 sample_view = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, 0.5, 1.0);
				float glow = pow(max(dot(normalize(sample_view.xyz / sample_view.w), sun_view), 0.0), ray_spread);
				acc += sky * glow * inside * trans * decay * ray_weight;
				trans *= mix(1.0 - ray_absorb, 1.0, sky);
				decay *= ray_decay;
			}
			// radios fijos alrededor del sol: dos senos de frecuencia entera dan franjas irregulares (y sin costura en el angulo pi)
			float ang = atan(to_sun.y, to_sun.x * aspect.x);
			float streak = smoothstep(-0.2, 0.6, sin(ang * RAY_STREAKS_A) * sin(ang * RAY_STREAKS_B + 1.3));
			col += sun_color * (acc / float(RAY_SAMPLES) * ray_intensity * mix(1.0, streak, ray_streaks) * facing);
		}
		if (flare_intensity > 0.0) {
			// el destello solo se ve si el sol esta en pantalla y no tapado: cruz de 9 lecturas de profundidad alrededor del sol
			float vis = 0.0;
			for (int k = 0; k < 9; k++) {
				vec2 o = vec2(float(k % 3) - 1.0, float(k / 3) - 1.0) * FLARE_VIS_RADIUS;
				vis += step(texture(depth_texture, sun_uv + o).x, SKY_DEPTH);
			}
			float edge = max(abs(sun_uv.x - 0.5), abs(sun_uv.y - 0.5)) * 2.0;
			float flare_k = vis / 9.0 * (1.0 - smoothstep(0.8, 1.1, edge)) * facing * flare_intensity;
			vec2 sp = (sun_uv - 0.5) * aspect;
			vec2 pp = (SCREEN_UV - 0.5) * aspect;
			float d_sun = length(pp - sp);
			vec3 flare = vec3(1.0, 0.95, 0.85) * (exp(-d_sun * 9.0) * 0.8 + exp(-d_sun * 40.0));   // resplandor suave y nucleo
			float ring = (d_sun - 0.2) / 0.015;
			flare += vec3(1.0, 0.8, 0.5) * exp(-ring * ring) * 0.25;           // halo en anillo
			for (int i = 0; i < GHOSTS; i++) {   // reflejos de lente: discos sobre la recta sol-centro de pantalla
				float r = GHOST_RADIUS[i];
				flare += GHOST_TINT[i] * (1.0 - smoothstep(r * 0.4, r, length(pp - sp * GHOST_POS[i]))) * 0.3;
			}
			col += sun_color * flare * flare_k;
		}
	}

	// vibrancia: satura mas los colores apagados que los ya vivos (cielo, vegetacion, camuflaje) sin quemarlos
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float hi = max(col.r, max(col.g, col.b));
	float lo = min(col.r, min(col.g, col.b));
	float chroma = (hi - lo) / max(hi, 0.0001);
	col = max(mix(vec3(luma), col, 1.0 + vibrance * (1.0 - chroma)), vec3(0.0));
	ALBEDO = col;
}
