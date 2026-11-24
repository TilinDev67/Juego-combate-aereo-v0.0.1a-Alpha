class_name FxGen
extends RefCounted
## Sprites y texturas de efectos dibujados por codigo (sin archivos de imagen): bocanadas de humo con
## volumen, llamas, estrella de destello, anillo de onda de choque y chapa quemada. Cada textura se
## genera la primera vez que se pide y se guarda.

const CELL := 64                 # lado de cada sprite de un atlas (px)
const GRID := 3                  # sprites por lado de un atlas (9 variantes distintas)
const SMOKE_FREQ := 0.045        # escala del ruido del humo: mas alto = bocanada mas rugosa
const FIRE_FREQ := 0.06          # escala del ruido del fuego
const NOISE_OCTAVES := 4         # capas del ruido fractal
const CORE_BASE := 0.8           # opacidad minima del interior de una bocanada de humo
const SMOKE_EDGE_NOISE := 0.4    # cuanto deforma el ruido la silueta de una bocanada (0 = circulo; mayor = contorno de coliflor)
const SMOKE_DETAIL_FREQ := 0.13  # escala del ruido fino que motea el humo por dentro (mayor = grano mas fino)
const SMOKE_DETAIL := 0.45       # cuanto motean ese ruido fino la opacidad y el brillo (0 = liso)
const CORE_NOISE := 0.65          # cuanto modula el ruido la opacidad del humo
const FALLOFF := 0.55            # anchura del borde que se desvanece (0..1 del radio): bajo = bocanada mas llena
const SHADE_DARK := 0.62         # brillo del humo en la parte sombreada (abajo a la derecha)
const FIRE_CORE_GAIN := 1.6      # fuerza del nucleo de las llamas respecto a su borde
const FIRE_NOISE_GAIN := 0.9     # cuanto deforma el ruido la silueta de las llamas
const STAR_SIZE := 64            # lado de la estrella de destello (px)
const STAR_CORE := 18.0          # estrechez del nucleo de la estrella (mayor = mas pequeno)
const STAR_RAY := 18.0           # estrechez de los rayos rectos de la estrella
const STAR_DIAG := 0.5           # intensidad de los rayos diagonales
const FLAME_W := 32              # ancho de la textura de la lengua del fogonazo (px)
const FLAME_H := 96              # largo de esa textura (px); la fila 0 es la punta de la llama
const FLAME_PROFILE := 0.6       # exponente que adelanta la parte mas ancha de la lengua (menor = mas cerca de la punta)
const FLAME_NOISE := 0.5         # cuanto rompe el ruido la lengua del fogonazo
const FLAME_CORE_COLOR := Color(1.0, 0.95, 0.7)   # nucleo de la lengua: amarillo palido
const FLAME_EDGE_COLOR := Color(1.0, 0.5, 0.12)   # borde de la lengua: naranja
const GLOW_SIZE := 64             # lado de la textura del resplandor redondo (px)
const GLOW_FALLOFF := 6.0        # lo rapido que cae el resplandor hacia el borde (mayor = nucleo mas pequeno y concentrado)
const RING_SIZE := 128           # lado del anillo de onda de choque (px)
const RING_RADIUS := 0.82        # radio del anillo (0..1 del lado/2)
const RING_WIDTH := 0.09         # grosor del anillo
const SCRAP_SIZE := 64           # lado de la textura de chapa (px)

static var _smoke: ImageTexture
static var _fire: ImageTexture
static var _star: ImageTexture
static var _flame: ImageTexture
static var _glow: ImageTexture
static var _ring: ImageTexture
static var _scrap: ImageTexture

## Atlas de bocanadas de humo (grises con volumen y alfa); el color final lo da cada particula.
static func smoke() -> ImageTexture:
	if _smoke == null:
		_smoke = _atlas(false)
	return _smoke

## Atlas de llamas (nucleo muy brillante y borde turbulento); se usa con mezcla aditiva.
static func fire() -> ImageTexture:
	if _fire == null:
		_fire = _atlas(true)
	return _fire

static func _atlas(flames: bool) -> ImageTexture:
	var size := CELL * GRID
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := CELL * 0.5
	for variant in GRID * GRID:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_octaves = NOISE_OCTAVES
		noise.frequency = FIRE_FREQ if flames else SMOKE_FREQ
		noise.seed = (211 if flames else 101) + variant * 37
		var detail := FastNoiseLite.new()   # segundo ruido, mas fino, para las motas del humo
		detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		detail.frequency = SMOKE_DETAIL_FREQ
		detail.seed = 307 + variant * 53
		var ox := (variant % GRID) * CELL
		var oy := (variant / GRID) * CELL
		for y in CELL:
			for x in CELL:
				var dx := (x - half + 0.5) / half
				var dy := (y - half + 0.5) / half
				var base := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
				var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
				if flames:
					var heat := clampf(base * FIRE_CORE_GAIN + (n - 0.5) * FIRE_NOISE_GAIN, 0.0, 1.0)
					var a := smoothstep(0.05, 0.6, heat) * smoothstep(0.0, 0.25, base)
					var v := lerpf(0.55, 1.0, smoothstep(0.4, 1.0, heat))
					img.set_pixel(ox + x, oy + y, Color(v, v, v, a))
				else:
					# silueta irregular (el ruido grande empuja el borde) y motas finas por dentro; nada pasa del borde del cuadro
					var r := sqrt(dx * dx + dy * dy)
					var d := detail.get_noise_2d(x, y) * 0.5 + 0.5
					var shape := clampf(1.0 - (r - (n - 0.5) * 2.0 * SMOKE_EDGE_NOISE), 0.0, 1.0)
					var a := smoothstep(0.0, FALLOFF, shape) * clampf(CORE_BASE + CORE_NOISE * n + (d - 0.5) * SMOKE_DETAIL, 0.0, 1.0)
					a *= 1.0 - smoothstep(0.85, 1.0, r)
					var lit := clampf(0.5 - (dx + dy) * 0.35, 0.0, 1.0)
					var v := lerpf(SHADE_DARK, 1.0, lit) * lerpf(0.85, 1.0, n) * lerpf(1.0 - SMOKE_DETAIL * 0.5, 1.0, d)
					img.set_pixel(ox + x, oy + y, Color(v, v, v, a))
	return ImageTexture.create_from_image(img)

## Lengua de fuego de un fogonazo de boca: nace en la base (fila inferior), se ensancha un poco y acaba en punta
## (fila 0). Con mezcla aditiva: nucleo palido y borde naranja con el contorno roto por ruido.
static func muzzle_flame() -> ImageTexture:
	if _flame == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.09
		noise.seed = 613
		var img := Image.create(FLAME_W, FLAME_H, false, Image.FORMAT_RGBA8)
		for y in FLAME_H:
			var along := 1.0 - float(y) / float(FLAME_H - 1)   # 0 en la base, 1 en la punta
			var width := pow(maxf(sin(PI * pow(along, FLAME_PROFILE)), 0.0), 0.8)
			for x in FLAME_W:
				var dx := absf((float(x) + 0.5) / float(FLAME_W) * 2.0 - 1.0)
				var edge := clampf(1.0 - dx / maxf(width, 0.001), 0.0, 1.0)
				var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var a := clampf(smoothstep(0.0, 0.5, edge) * (1.0 - 0.4 * along) * (1.0 + (n - 0.5) * FLAME_NOISE * 2.0), 0.0, 1.0)
				var core := smoothstep(0.35, 1.0, edge) * (1.0 - 0.7 * along)
				var col := FLAME_EDGE_COLOR.lerp(FLAME_CORE_COLOR, core)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
		_flame = ImageTexture.create_from_image(img)
	return _flame

## Resplandor redondo y suave (mas brillante en el centro), para los carteles de bloom de las balas.
static func glow() -> ImageTexture:
	if _glow == null:
		var img := Image.create(GLOW_SIZE, GLOW_SIZE, false, Image.FORMAT_RGBA8)
		var half := GLOW_SIZE * 0.5
		for y in GLOW_SIZE:
			for x in GLOW_SIZE:
				var dx := (x - half + 0.5) / half
				var dy := (y - half + 0.5) / half
				var r2 := dx * dx + dy * dy
				var a := exp(-r2 * GLOW_FALLOFF) * (1.0 - smoothstep(0.8, 1.0, sqrt(r2)))   # cae a cero antes del borde del cuadro
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_glow = ImageTexture.create_from_image(img)
	return _glow

## Estrella de destello: nucleo brillante con cuatro rayos rectos y cuatro diagonales mas suaves.
static func star() -> ImageTexture:
	if _star == null:
		var img := Image.create(STAR_SIZE, STAR_SIZE, false, Image.FORMAT_RGBA8)
		var half := STAR_SIZE * 0.5
		for y in STAR_SIZE:
			for x in STAR_SIZE:
				var dx := (x - half + 0.5) / half
				var dy := (y - half + 0.5) / half
				var core := exp(-(dx * dx + dy * dy) * STAR_CORE)
				var ray_h := exp(-absf(dy) * STAR_RAY) * pow(maxf(1.0 - absf(dx), 0.0), 2.0)
				var ray_v := exp(-absf(dx) * STAR_RAY) * pow(maxf(1.0 - absf(dy), 0.0), 2.0)
				var u := (dx + dy) * 0.7071
				var w := (dx - dy) * 0.7071
				var diag := exp(-absf(w) * STAR_RAY * 1.3) * pow(maxf(1.0 - absf(u), 0.0), 2.0) \
					+ exp(-absf(u) * STAR_RAY * 1.3) * pow(maxf(1.0 - absf(w), 0.0), 2.0)
				var a := clampf(core + 0.8 * (ray_h + ray_v) + STAR_DIAG * diag, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_star = ImageTexture.create_from_image(img)
	return _star

## Anillo fino y algo irregular de onda de choque, con un velo tenue en el interior.
static func ring() -> ImageTexture:
	if _ring == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.05
		noise.seed = 307
		var img := Image.create(RING_SIZE, RING_SIZE, false, Image.FORMAT_RGBA8)
		var half := RING_SIZE * 0.5
		for y in RING_SIZE:
			for x in RING_SIZE:
				var dx := (x - half + 0.5) / half
				var dy := (y - half + 0.5) / half
				var r := sqrt(dx * dx + dy * dy)
				var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var edge := exp(-pow((r - RING_RADIUS) / RING_WIDTH, 2.0)) * lerpf(0.6, 1.0, n)
				var veil := 0.1 * clampf(1.0 - r / RING_RADIUS, 0.0, 1.0)
				var a := clampf(edge + veil, 0.0, 1.0) * (1.0 - smoothstep(0.95, 1.0, r))
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_ring = ImageTexture.create_from_image(img)
	return _ring

## Chapa quemada: gris oscuro con manchas de hollin, oxido y raspaduras claras.
static func scrap() -> ImageTexture:
	if _scrap == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.12
		noise.fractal_octaves = 3
		noise.seed = 409
		var img := Image.create(SCRAP_SIZE, SCRAP_SIZE, false, Image.FORMAT_RGBA8)
		for y in SCRAP_SIZE:
			for x in SCRAP_SIZE:
				var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var m := noise.get_noise_2d(x + 200.0, y + 200.0) * 0.5 + 0.5
				var c := Color(0.32, 0.32, 0.34) * lerpf(0.6, 1.2, n)
				c = c.lerp(Color(0.1, 0.09, 0.08), smoothstep(0.55, 0.8, m))      # hollin
				c = c.lerp(Color(0.45, 0.22, 0.1), smoothstep(0.7, 0.9, 1.0 - m) * 0.6)  # oxido
				if ((x * 73 + y * 151) ^ (x * y)) % 23 == 0:
					c = c.lightened(0.35)      # raspadura de metal desnudo
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
		_scrap = ImageTexture.create_from_image(img)
	return _scrap
