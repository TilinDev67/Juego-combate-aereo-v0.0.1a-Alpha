## Contenedor pixel-perfect del HUD: lo dibuja en un SubViewport de baja resolucion (unos 640x360)
## y lo estira con filtro de vecino mas cercano por un factor entero, asi cada pixel del arte es un
## cuadrado nitido en cualquier monitor (720p x2, 1080p x3, 4K x6...).
class_name HudView
extends TextureRect

const BASE_HEIGHT := 360.0      # alto virtual de referencia del HUD (px)
const DETAIL := 2               # cuantas veces mas fina que el diseno es la rejilla del HUD (lineas y texto): 2 = mitad de grueso

var hud: Hud                    # el HUD que se dibuja dentro (lo asigna quien crea la vista)
var viewport: SubViewport

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	viewport = SubViewport.new()
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = Vector2i(1, 1)
	viewport.add_child(hud)
	add_child(viewport)
	texture = viewport.get_texture()
	_fit()

func _process(_delta: float) -> void:
	_fit()

## Factor entero de escala para una ventana: pixeles de pantalla por pixel del arte (720p x2, 1080p x3...).
static func scale_for(window: Vector2) -> int:
	return maxi(roundi(window.y / BASE_HEIGHT), 1)

## Ajusta la ventana: el HUD se disena en unidades de "factor" pixeles de pantalla (720p x2, 1080p x3...), pero el
## lienzo es DETAIL veces mas fino (factor entero mas pequeno), asi lineas y texto son mas finos con el mismo tamano.
## Los pixeles siguen siendo cuadrados y enteros; "k" es cuantos pixeles de lienzo mide cada unidad del diseno.
func _fit() -> void:
	var win := get_viewport_rect().size
	var factor := scale_for(win)
	var canvas_factor := maxi(ceili(float(factor) / DETAIL), 1)
	var vsize := Vector2i(ceili(win.x / canvas_factor), ceili(win.y / canvas_factor))
	if viewport.size != vsize:
		viewport.size = vsize
	hud.px_scale = factor
	hud.k = float(factor) / canvas_factor
	position = Vector2.ZERO
	size = Vector2(vsize) * canvas_factor
