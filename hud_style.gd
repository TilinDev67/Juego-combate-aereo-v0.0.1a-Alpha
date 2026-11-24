## Estilo del HUD: paleta tactica y primitivas de 1 px con contorno oscuro (sin cajas ni fondos).
## Las posiciones y medidas son del diseno del HUD ("unidades"); cada primitiva las convierte a pixeles del lienzo con "k"
## (pixeles del lienzo por unidad) y dibuja con 1 px de grosor del lienzo. Con k = 1 una unidad es un pixel y todo sale
## como siempre; con k > 1 el diseno es el mismo pero las lineas, puntos y texto son mas finos.
class_name HudStyle

const PHOSPHOR := Color(0.2902, 0.9647, 0.1490)   # #4AF626: color principal de los datos
const FONT_PATH := "res://fuentes/PixelifySans.ttf"  # fuente pixel moderna (licencia OFL en la misma carpeta)
const AMBER := Color(1.0, 0.6902, 0.0)            # #FFB000: precaucion, antes de que algo sea critico
const ALERT := Color(1.0, 0.1647, 0.2941)         # #FF2A4B: estados criticos
const TRACK_ALPHA := 0.3                          # opacidad del carril vacio de una barra o un arco
const SHADOW := Color(0.0392, 0.0588, 0.0510, 0.8) # #0A0F0D al 80 %: contorno que da contraste sobre cielo, nubes y tierra
const TEXT_OUTLINE := 1                           # grosor (px) del contorno del texto
const SHADOW_OFFSET := Vector2(1.0, 1.0)          # desplazamiento de la sombra de lineas y marcos
const SHUTTER_SLATS := 12                         # lamas de la persiana de transicion
const SHUTTER_STAGGER := 0.35                     # fraccion del recorrido que se reparte en el desfase entre lamas (0 = todas a la vez)

## Pixeles del lienzo por unidad del diseno. Hud._draw lo fija mientras dibuja y lo deja en 1 al acabar (los menus no lo cambian).
static var k := 1.0

## Centro del pixel del lienzo que contiene a p (en unidades): una linea de 1 px solo sale nitida ahi.
static func snap(p: Vector2) -> Vector2:
	return (p * k).floor() + Vector2(0.5, 0.5)

## Sombra de un color: su opacidad baja con la del color, para que lo que se desvanece no deje la sombra suelta.
static func _shadow(col: Color) -> Color:
	return Color(SHADOW, SHADOW.a * col.a)

## Linea de 1 px con sombra.
static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color) -> void:
	ci.draw_line(snap(a) + SHADOW_OFFSET, snap(b) + SHADOW_OFFSET, _shadow(col), 1.0)
	ci.draw_line(snap(a), snap(b), col, 1.0)

## Linea punteada de 1 px: un pixel de cada "step" pixeles del lienzo.
static func dotted_line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, step: float) -> void:
	var n := maxi(ceili(a.distance_to(b) * k / step), 1)   # "step" son pixeles del lienzo: los puntos siguen la misma proporcion con lienzo fino
	for i in n + 1:
		dot(ci, a.lerp(b, float(i) / n), col)

## Arco de pixeles (angulos en radianes de pantalla, y hacia abajo) con sombra.
static func arc(ci: CanvasItem, center: Vector2, radius: float, from: float, to: float, col: Color) -> void:
	var n := maxi(ceili(radius * k * absf(to - from)), 1)
	for i in n + 1:
		var ang := lerpf(from, to, float(i) / n)
		dot(ci, center + Vector2(cos(ang), sin(ang)) * radius, col)

## Rombo de 1 px.
static func diamond(ci: CanvasItem, center: Vector2, r: float, col: Color) -> void:
	var pts := [Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)]
	for i in 4:
		line(ci, center + pts[i], center + pts[(i + 1) % 4], col)

## Pixel suelto con sombra.
static func dot(ci: CanvasItem, p: Vector2, col: Color) -> void:
	var cell := (p * k).floor()
	ci.draw_rect(Rect2(cell + SHADOW_OFFSET, Vector2.ONE), _shadow(col))
	ci.draw_rect(Rect2(cell, Vector2.ONE), col)

## Circulo de 1 px (algoritmo del punto medio) con sombra: primero se dibuja toda la sombra y luego el color.
static func circle(ci: CanvasItem, center: Vector2, radius: int, col: Color) -> void:
	var c := (center * k).floor()
	var r_px := roundi(radius * k)
	for pass_shadow: bool in [true, false]:
		var off := SHADOW_OFFSET if pass_shadow else Vector2.ZERO
		var tint := _shadow(col) if pass_shadow else col
		var x := r_px
		var y := 0
		var err := 1 - r_px
		while x >= y:
			for p: Vector2 in [Vector2(x, y), Vector2(y, x), Vector2(-y, x), Vector2(-x, y),
					Vector2(-x, -y), Vector2(-y, -x), Vector2(y, -x), Vector2(x, -y)]:
				ci.draw_rect(Rect2(c + off + p, Vector2.ONE), tint)
			y += 1
			if err < 0:
				err += 2 * y + 1
			else:
				x -= 1
				err += 2 * (y - x) + 1

## Marco de 1 px con sombra (solo el contorno).
static func frame(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	_frame_px(ci, Rect2((rect.position * k).floor(), (rect.size * k).floor()), col)

## Marco de 1 px de un rectangulo ya en pixeles del lienzo.
static func _frame_px(ci: CanvasItem, rect: Rect2, col: Color) -> void:
	for pass_shadow: bool in [true, false]:
		var r := Rect2(rect.position + (SHADOW_OFFSET if pass_shadow else Vector2.ZERO), rect.size)
		var tint := _shadow(col) if pass_shadow else col
		ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), tint)
		ci.draw_rect(Rect2(r.position.x, r.end.y - 1.0, r.size.x, 1.0), tint)
		ci.draw_rect(Rect2(r.position.x, r.position.y + 1.0, 1.0, r.size.y - 2.0), tint)
		ci.draw_rect(Rect2(r.end.x - 1.0, r.position.y + 1.0, 1.0, r.size.y - 2.0), tint)

## Barra horizontal fina: marco de 1 px, un pixel de hueco y el relleno. Necesita al menos 5 px en cada lado.
static func bar(ci: CanvasItem, rect: Rect2, frac: float, col: Color) -> void:
	var r := Rect2((rect.position * k).floor(), (rect.size * k).floor())
	_frame_px(ci, r, col)
	var inner := r.grow(-2.0)
	var fill := Rect2(inner.position, Vector2(floorf(inner.size.x * clampf(frac, 0.0, 1.0)), inner.size.y))
	if fill.size.x > 0.0 and fill.size.y > 0.0:
		ci.draw_rect(fill, col)

## Persiana pixelada a pantalla completa: SHUTTER_SLATS lamas horizontales que se cierran de arriba abajo con un
## pequeno desfase entre ellas, con un filo de color "edge" en el borde de cada una. "closed" va de 0 (abierta) a 1 (cerrada).
static func shutter(ci: CanvasItem, area: Vector2, closed: float, edge: Color) -> void:
	if closed <= 0.0:
		return
	for k in SHUTTER_SLATS:
		var top := floorf(area.y * k / SHUTTER_SLATS)
		var slat_h := floorf(area.y * (k + 1) / SHUTTER_SLATS) - top
		var local := clampf((closed - float(k) / SHUTTER_SLATS * SHUTTER_STAGGER) / (1.0 - SHUTTER_STAGGER), 0.0, 1.0)
		var h := ceilf(slat_h * local)
		if h <= 0.0:
			continue
		MilitaryStyle.slat(ci, Rect2(0.0, top, area.x, h))
		if h < slat_h:
			ci.draw_rect(Rect2(0.0, top + h - 1.0, area.x, 1.0), edge)

## True durante la mitad apagada de un parpadeo rapido que alterna cada "frames" fotogramas.
static func blink_off(frames: int) -> bool:
	return int(Engine.get_process_frames() / float(frames)) % 2 == 1

## Fuente pixel sin suavizado, sin hinting y sin posiciones subpixel, para que el texto salga nitido.
static func load_font() -> FontFile:
	var font: FontFile = load(FONT_PATH)
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return font

## Barra vertical ultrafina (sin marco): carril tenue, relleno desde abajo y sombra de 1 px.
static func slim_bar(ci: CanvasItem, rect: Rect2, frac: float, col: Color) -> void:
	var r := Rect2((rect.position * k).floor(), (rect.size * k).floor())
	ci.draw_rect(Rect2(r.position + SHADOW_OFFSET, r.size), _shadow(col))
	ci.draw_rect(r, Color(col, col.a * TRACK_ALPHA))
	var h := floorf(r.size.y * clampf(frac, 0.0, 1.0))
	if h > 0.0:
		ci.draw_rect(Rect2(r.position.x, r.end.y - h, r.size.x, h), col)

## Texto con contorno oscuro de 1 px. "pos" es el inicio de la linea base (o, con ancho, la caja de alineacion).
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var p := (pos * k).floor()
	var size_px := roundi(size * k)
	var width_px := width * k if width > 0.0 else width
	ci.draw_string_outline(font, p, s, align, width_px, size_px, TEXT_OUTLINE, _shadow(col))
	ci.draw_string(font, p, s, align, width_px, size_px, col)
