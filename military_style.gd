## Estilo retro-militar del menu del hangar: paleta de verde olivo y primitivas de chapa remachada, ranuras de
## instrumento, marcas de telemetro y una capa de scanlines con grano. Es independiente del estilo del HUD de vuelo.
class_name MilitaryStyle

# Paleta (hex entre parentesis)
const OLIVE_BASE := Color(0.2314, 0.2667, 0.1686)    # #3B442B: carcasa de los paneles
const OLIVE_PANEL := Color(0.2902, 0.3333, 0.2078)   # #4A5535: chapa mas clara (fila elegida, boton)
const OLIVE_DARK := Color(0.1176, 0.1412, 0.0863)    # #1E2416: sombra, borde y contorno del texto
const OLIVE_BEVEL := Color(0.4196, 0.4706, 0.3059)   # #6B784E: bisel claro (arriba e izquierda)
const KHAKI := Color(0.7216, 0.6902, 0.5412)         # #B8B08A: texto secundario y etiquetas
const KHAKI_LIGHT := Color(0.7843, 0.7451, 0.5882)   # #C8BE96: texto principal
const GAUGE := Color(0.5608, 0.6588, 0.2902)         # #8FA84A: fosforo de instrumento vintage (segmentos activos)
const GAUGE_LIGHT := Color(0.6392, 0.7216, 0.3608)   # #A3B85C: fosforo claro (valores, boton enfocado)
const AMBER := Color(0.7882, 0.5412, 0.1804)         # #C98A2E: seleccion y luz piloto
const RUST := Color(0.7216, 0.2275, 0.1765)          # #B83A2D: alerta y cambio a peor
const SLOT := Color(0.1020, 0.1216, 0.0745)          # #1A1F13: ranura oscura de las barras
const PAINT_YELLOW := Color(0.78, 0.62, 0.18)        # pintura amarilla gastada de la pista (3D)
const PAINT_WHITE := Color(0.82, 0.8, 0.72)          # pintura blanca gastada de la pista (3D)

const RIVET_INSET := 3.0              # distancia de los remaches a las esquinas de un panel (px)
const RIVET_SIZE := 2.0               # lado de un remache (px)
const TEXT_OUTLINE := 1               # grosor del contorno oscuro del texto (px)
const TICK_SPACING := 6.0             # separacion de las marcas de grado de unos corchetes de telemetro (px)
const TICK_LEN := 2.0                 # largo de esas marcas (px)
const SCANLINE_ALPHA := 0.07          # opacidad de las scanlines
const SCANLINE_STEP := 2              # una scanline cada tantos pixeles
const GRAIN_COUNT := 160              # puntos de grano de papel o metal
const GRAIN_ALPHA := 0.06             # opacidad del grano
const SLAT_RIVET_STEP := 48.0         # separacion de los remaches de una lama de la cortina (px)
const FIELD_PAD := Vector2i(5, 3)     # margen interior de botones y campos de texto (px)
const SLIDER_GRABBER := Vector2i(3, 9)    # tamano del tirador de un deslizador (px)
const DIM := 0.65                     # opacidad del texto secundario
const SLAT_RIVET_MIN_H := 8.0         # alto minimo de una lama para que lleve remaches (px)

## Chapa de panel: relleno con las cuatro esquinas cortadas, bisel claro arriba e izquierda y oscuro abajo y a
## la derecha, y un remache en cada esquina.
static func panel(ci: CanvasItem, rect: Rect2, fill: Color = OLIVE_BASE) -> void:
	var r := Rect2(rect.position.floor(), rect.size.floor())
	ci.draw_rect(Rect2(r.position.x + 1.0, r.position.y, r.size.x - 2.0, r.size.y), fill)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1.0, 1.0, r.size.y - 2.0), fill)
	ci.draw_rect(Rect2(r.end.x - 1.0, r.position.y + 1.0, 1.0, r.size.y - 2.0), fill)
	ci.draw_rect(Rect2(r.position.x + 1.0, r.position.y, r.size.x - 2.0, 1.0), OLIVE_BEVEL)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1.0, 1.0, r.size.y - 2.0), OLIVE_BEVEL)
	ci.draw_rect(Rect2(r.position.x + 1.0, r.end.y - 1.0, r.size.x - 2.0, 1.0), OLIVE_DARK)
	ci.draw_rect(Rect2(r.end.x - 1.0, r.position.y + 1.0, 1.0, r.size.y - 2.0), OLIVE_DARK)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var at := r.position + r.size * corner
		var sx := 1.0 if corner.x == 0.0 else -1.0
		var sy := 1.0 if corner.y == 0.0 else -1.0
		var rivet := at + Vector2(sx * RIVET_INSET, sy * RIVET_INSET) - Vector2(RIVET_SIZE if sx < 0.0 else 0.0, RIVET_SIZE if sy < 0.0 else 0.0)
		ci.draw_rect(Rect2(rivet + Vector2.ONE, Vector2(RIVET_SIZE, RIVET_SIZE)), OLIVE_DARK)
		ci.draw_rect(Rect2(rivet, Vector2(RIVET_SIZE, RIVET_SIZE)), KHAKI)

## Lama de la cortina de transicion: chapa olivo con bisel claro arriba, sombra abajo y una hilera de remaches.
static func slat(ci: CanvasItem, rect: Rect2) -> void:
	ci.draw_rect(rect, OLIVE_BASE)
	ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), OLIVE_BEVEL)
	ci.draw_rect(Rect2(rect.position.x, rect.end.y - 1.0, rect.size.x, 1.0), OLIVE_DARK)
	if rect.size.y < SLAT_RIVET_MIN_H:
		return
	var y := rect.position.y + floorf(rect.size.y * 0.5)
	var x := SLAT_RIVET_STEP * 0.5
	while x < rect.end.x:
		ci.draw_rect(Rect2(x + 1.0, y + 1.0, RIVET_SIZE, RIVET_SIZE), OLIVE_DARK)
		ci.draw_rect(Rect2(x, y, RIVET_SIZE, RIVET_SIZE), KHAKI)
		x += SLAT_RIVET_STEP

## Ranura hundida de un instrumento: fondo oscuro con el borde de arriba e izquierda en sombra y el de abajo y derecha claro.
static func slot(ci: CanvasItem, rect: Rect2) -> void:
	var r := Rect2(rect.position.floor(), rect.size.floor())
	ci.draw_rect(r, SLOT)
	ci.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.0), OLIVE_DARK)
	ci.draw_rect(Rect2(r.position.x, r.position.y, 1.0, r.size.y), OLIVE_DARK)
	ci.draw_rect(Rect2(r.position.x + 1.0, r.end.y - 1.0, r.size.x - 1.0, 1.0), OLIVE_BASE)
	ci.draw_rect(Rect2(r.end.x - 1.0, r.position.y + 1.0, 1.0, r.size.y - 1.0), OLIVE_BASE)

## Texto con contorno oscuro de 1 px.
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var p := pos.floor()
	ci.draw_string_outline(font, p, s, align, width, size, TEXT_OUTLINE, Color(OLIVE_DARK, col.a))
	ci.draw_string(font, p, s, align, width, size, col)

## Corchetes de telemetro: los cuatro angulos de un rectangulo y, entre ellos, marcas de grado en los lados
## horizontales. Con "ticks" falso solo van los angulos.
static func brackets(ci: CanvasItem, rect: Rect2, col: Color, arm: float, ticks: bool = true) -> void:
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var c := rect.position + rect.size * corner
		var sx := 1.0 if corner.x == 0.0 else -1.0
		var sy := 1.0 if corner.y == 0.0 else -1.0
		HudStyle.line(ci, c, c + Vector2(sx * arm, 0.0), col)
		HudStyle.line(ci, c, c + Vector2(0.0, sy * arm), col)
	if not ticks:
		return
	var x := rect.position.x + arm + TICK_SPACING
	while x < rect.end.x - arm:
		HudStyle.line(ci, Vector2(x, rect.position.y), Vector2(x, rect.position.y + TICK_LEN), col)
		HudStyle.line(ci, Vector2(x, rect.end.y), Vector2(x, rect.end.y - TICK_LEN), col)
		x += TICK_SPACING

## Capa final de la pantalla: scanlines muy suaves y un grano fijo de papel o metal envejecido.
static func overlay(ci: CanvasItem, area: Vector2) -> void:
	var y := 0
	while y < int(area.y):
		ci.draw_rect(Rect2(0.0, y, area.x, 1.0), Color(0.0, 0.0, 0.0, SCANLINE_ALPHA))
		y += SCANLINE_STEP
	for i in GRAIN_COUNT:
		var gx := _hash(i * 2) % maxi(int(area.x), 1)
		var gy := _hash(i * 2 + 1) % maxi(int(area.y), 1)
		var light := _hash(i * 7) % 2 == 0
		ci.draw_rect(Rect2(gx, gy, 1.0, 1.0), Color(1.0, 1.0, 0.85, GRAIN_ALPHA) if light else Color(0.0, 0.0, 0.0, GRAIN_ALPHA))

## Hash entero estable: el grano no cambia entre fotogramas.
static func _hash(i: int) -> int:
	return absi((i * 73856093) ^ (i * 19349663 + 83492791))

## Caja plana de 1 px sin esquinas redondeadas ni suavizado, para que el borde salga nitido al ampliar.
static func box(fill: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.anti_aliasing = false
	sb.content_margin_left = FIELD_PAD.x
	sb.content_margin_right = FIELD_PAD.x
	sb.content_margin_top = FIELD_PAD.y
	sb.content_margin_bottom = FIELD_PAD.y
	return sb

## Tema de los menus con controles: fuente pixel, botones de chapa olivo con borde ambar al enfocarlos y campos de ranura oscura.
static func menu_theme(font: Font, text_size: int) -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = text_size
	t.set_stylebox("normal", "Button", box(OLIVE_PANEL, OLIVE_DARK))
	t.set_stylebox("hover", "Button", box(OLIVE_PANEL, AMBER))
	t.set_stylebox("pressed", "Button", box(OLIVE_DARK, GAUGE_LIGHT))
	t.set_stylebox("disabled", "Button", box(OLIVE_BASE, OLIVE_DARK))
	var focus := box(Color.TRANSPARENT, AMBER)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", KHAKI_LIGHT)
	t.set_color("font_hover_color", "Button", GAUGE_LIGHT)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_focus_color", "Button", KHAKI_LIGHT)
	t.set_color("font_disabled_color", "Button", Color(KHAKI, DIM * 0.7))
	t.set_stylebox("normal", "LineEdit", box(SLOT, OLIVE_DARK))
	t.set_stylebox("focus", "LineEdit", box(SLOT, AMBER))
	t.set_stylebox("read_only", "LineEdit", box(SLOT, OLIVE_DARK))
	t.set_color("font_color", "LineEdit", KHAKI_LIGHT)
	t.set_color("caret_color", "LineEdit", GAUGE_LIGHT)
	t.set_color("selection_color", "LineEdit", Color(AMBER, 0.4))
	t.set_constant("caret_width", "LineEdit", 1)
	t.set_stylebox("slider", "HSlider", box(SLOT, OLIVE_DARK))
	t.set_stylebox("grabber_area", "HSlider", box(GAUGE, OLIVE_DARK))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GAUGE_LIGHT, OLIVE_DARK))
	t.set_icon("grabber", "HSlider", _grabber(KHAKI_LIGHT))
	t.set_icon("grabber_highlight", "HSlider", _grabber(AMBER))
	t.set_icon("grabber_disabled", "HSlider", _grabber(OLIVE_BEVEL))
	return t

## Tirador rectangular liso de un deslizador.
static func _grabber(col: Color) -> ImageTexture:
	var img := Image.create_empty(SLIDER_GRABBER.x, SLIDER_GRABBER.y, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)
