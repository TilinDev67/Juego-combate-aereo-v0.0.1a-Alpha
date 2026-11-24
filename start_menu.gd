## Menu de inicio (hangar), de estetica retro-militar en verde olivo: registro de aeronaves a la izquierda,
## telemetria a la derecha y el pulsador de salida abajo, dejando libre el avion del centro. Se dibuja a baja
## resolucion (unos 640x360) ampliada por un factor entero, con la misma tecnica pixel-perfect que el HUD: la
## ventana recibe el raton y el teclado, y el dibujo se escala con una transformacion.
class_name StartMenu
extends Control

signal chosen(index: int)        # se ha elegido otro avion
signal armed                     # el raton entra en el pulsador de empezar (para conectar un clic mecanico)
signal launching                 # se pulsa empezar y arranca la secuencia de salida
signal confirmed                 # acaba la secuencia: hay que cargar la partida
signal shop_buy(kind: int)       # se pulsa una mejora de la tienda (Shop.DAMAGE, RATE o HEALTH)

const TITLE := "COMBATE AEREO"
const ICON_SIZE := 14            # lado de la mini-silueta de cada fila (px)
const MARGIN := 12.0             # separacion de los paneles al borde de la pantalla
const PANEL_PAD := 7.0           # margen interior de los paneles
const HEADER_GAP := 5.0          # separacion del rotulo de cada panel a su borde superior
const TITLE_Y := 22.0            # linea base del titulo
const DESIGNATION_Y := 36.0      # linea base de la designacion del avion elegido
const DESC_Y := 48.0             # linea base de su descripcion
const TYPE_RATE := 220.0         # caracteres por segundo con los que se "mecanografia" la ficha al elegir un avion
const LIST_TOP := 80.0           # arriba de las filas de la lista y de las filas de telemetria
const LIST_W := 160.0            # ancho del panel de la lista
const ROW_H := 22.0              # alto de una fila de la lista
const ROW_GAP := 2.0             # separacion entre filas
const TAB_W := 3.0               # ancho de la pestana ambar de la fila elegida
const ICON_X := 7.0              # sangria de la mini-silueta dentro de la fila
const ICON_Y := 4.0              # altura de la mini-silueta dentro de la fila
const ROW_NAME_X := 25.0         # sangria del nombre (tras la mini-silueta)
const ROW_NAME_Y := 9.0          # linea base del nombre dentro de su fila
const ROW_ROLE_Y := 18.0         # linea base del rol
const PILOT_SIZE := 3.0          # lado de la luz piloto de la fila elegida (px)
const PILOT_INSET := 7.0         # distancia de la luz piloto al borde derecho de la fila
const PILOT_RATE := 1.0          # parpadeos por segundo de la luz piloto
const SEGMENTS := 10             # segmentos de cada barra de telemetria
const SEGMENT_W := 15.0          # ancho de un segmento
const SEGMENT_H := 5.0           # alto de un segmento
const SEGMENT_GAP := 1.0         # separacion entre segmentos
const STATS_BAR_W := SEGMENTS * SEGMENT_W + (SEGMENTS - 1) * SEGMENT_GAP   # ancho de una barra completa
const STATS_W := STATS_BAR_W + 2.0 * PANEL_PAD   # ancho del panel de telemetria
const STAT_COUNT := 5            # metricas de telemetria
const STAT_ROW_H := 26.0         # alto de una fila de telemetria
const STAT_LABEL_Y := 8.0        # linea base de la etiqueta dentro de su fila
const STAT_BAR_Y := 12.0         # donde empieza la barra dentro de su fila
const SWEEP_RATE := 40.0         # segmentos por segundo del barrido de izquierda a derecha al actualizar una barra
const SWEEP_TAIL := 2            # segmentos por detras de la cabeza del barrido que mantienen el destello ambar si cambian
const BAR_FOLLOW := 14.0         # rapidez con que las cifras alcanzan su valor (1/s)
const OPEN_STAGGER := 0.06       # retraso (s) entre una barra y la siguiente al llenarse al abrir el menu
const DELTA_TIME := 1.2          # segundos que se ve el indicador de cambio (+/-) tras cambiar de avion
const DELTA_FADE := 0.4          # fraccion final de ese tiempo en la que el indicador se desvanece
const DELTA_X := 74.0            # sangria del indicador respecto al inicio de la fila (tras la etiqueta)
const FLASH_TIME := 0.3          # segundos que destella el valor al cambiar
const BUTTON_SIZE := Vector2(140.0, 28.0)
const BUTTON_BOTTOM := 44.0      # distancia del pulsador al borde inferior
const BUTTON_TEXT_Y := 19.0      # linea base del texto del pulsador
const BUTTON_STATE_GAP := 11.0   # separacion del rotulo de estado al pulsador
const BUTTON_INNER := 3.0        # separacion del segundo marco, interior, al borde del pulsador
const HINT_BOTTOM := 8.0         # distancia de la ayuda al borde inferior
const SHOP_GAP := 16.0           # separacion de la tienda al panel de telemetria (deja sitio al rotulo)
const SHOP_ROW_H := 18.0         # alto de una fila de la tienda
const SHOP_TEXT_Y := 12.0        # linea base del texto de una fila de la tienda
const SHOP_TEXT_X := 3.0         # sangria del nombre y margen derecho del precio
const SHOP_PIPS_X := 56.0        # donde empiezan los indicadores de nivel de una fila
const SHOP_PIP := 6.0            # lado de un indicador de nivel
const SHOP_PIP_GAP := 2.0        # separacion entre indicadores
const SHOP_BONUS_X := 88.0       # donde empieza el aumento actual de una fila
const SHOP_NOTE_Y := 9.0         # altura de la nota bajo la tienda respecto a su borde inferior
const SHOP_FLASH_TIME := 0.35    # segundos que destella una fila al comprar (ambar) o al no poder (oxido)
const HOVER_ALPHA := 0.5         # opacidad del marco de la fila bajo el raton
const DIM := 0.65                # opacidad del texto secundario
const PULSE_TIME := 0.25         # segundos que tarda en apagarse el pulso de la fila elegida
const NUDGE_TIME := 0.15         # segundos que dura el retroceso de la fila elegida
const NUDGE_PX := 2.0            # desplazamiento maximo (px) de ese retroceso
const LOCK_TIME := 0.18          # segundos que tardan los corchetes en cerrarse sobre la fila y el avion
const LOCK_GROW := 10.0          # px de mas con los que empiezan los corchetes de la fila
const PLANE_LOCK_GROW := 24.0    # igual, para los corchetes que fijan el avion
const PLANE_LOCK_R := 22.0       # semilado de los corchetes que fijan el avion (px)
const BRACKET_LEN := 4.0         # largo de cada brazo de un corchete (px)
const CROSS_LEN := 3.0           # largo de cada brazo de la cruz de punteria sobre el avion (px)
const LOCK_BLINK_TIME := 0.12    # segundos de parpadeo tras cerrarse los corchetes
const LOCK_BLINK_FRAMES := 2     # fotogramas encendido y apagado en ese parpadeo
const GUIDE_STEP := 3.0          # separacion de los puntos de la linea guia al avion (px)
const GUIDE_ALPHA := 0.5         # opacidad de la linea guia
const LOCK_DONE := 1000.0        # tope del reloj de la fijacion (s): evita que crezca sin limite
const BUTTON_GROW := 8.0         # px de mas con los que empiezan los corchetes del pulsador al enfocarlo
const HOVER_TIME := 0.15         # segundos que tardan en converger los corchetes del pulsador
const HOVER_BLINK_TIME := 0.1    # segundos de parpadeo al cerrarse esos corchetes
const HOVER_OFFSET := 1.0        # px que se hunde el pulsador al enfocarlo
const PRESS_TIME := 0.1          # segundos del retroceso del pulsador al pulsarlo
const PRESS_RECOIL := 2.0        # px que se hunde el pulsador al pulsarlo
const LAUNCH_TIME := 0.4         # duracion total de la secuencia de salida (s)
const LAUNCH_SHUTTER_DELAY := 0.15 # segundos antes de que la persiana empiece a cerrarse: el pulsador y la camara van primero

var font: FontFile
var models: Array[PlaneModels.Spec] = []
var silhouettes: Array[PlaneZones] = []   # mini-silueta de cada avion, en el mismo orden que models
var index := 0                   # avion elegido
var hover := -1                  # fila bajo el raton (-1 = ninguna)
var credits := 0                 # creditos del jugador, para la tienda
var tiers := PackedInt32Array([0, 0, 0])   # nivel comprado de cada mejora de la tienda
var shop_hover := -1             # fila de la tienda bajo el raton (-1 = ninguna)
var _shop_flash := PackedFloat32Array([0.0, 0.0, 0.0])   # tiempo que le queda al destello de cada fila de la tienda
var _shop_ok := [true, true, true]       # si el ultimo intento de compra de cada fila funciono
var button_hover := false
var focus := Vector2.ZERO        # posicion del avion en la ventana (px); la fija el hangar cada fotograma
var _clock := 0.0                # tiempo del menu abierto, para la luz piloto
var _lock_time := 0.0            # segundos desde que se eligio el avion actual (o se abrio el menu)
var _hover_time := 0.0           # segundos que lleva el raton sobre el pulsador
var _launch_t := -1.0            # segundos de la secuencia de salida; negativo = no hay salida en curso
var _old_lit := PackedInt32Array()        # segmentos encendidos de cada barra antes del ultimo cambio
var _new_lit := PackedInt32Array()        # segmentos que debe tener cada barra para el avion elegido
var _sweep := PackedFloat32Array()        # posicion (segmentos) del barrido de cada barra; negativa = aun no ha empezado
var _shown_raw := PackedFloat32Array()    # valor mostrado de cada metrica, amortiguado
var _delta := PackedInt32Array()          # cambio de cada barra (en segmentos) al cambiar de avion
var _delta_t := PackedFloat32Array()      # tiempo que le queda al indicador de cambio de cada barra
var _flash_t := PackedFloat32Array()      # tiempo que le queda al destello del valor de cada barra

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = HudStyle.load_font()
	_old_lit.resize(STAT_COUNT)
	_new_lit.resize(STAT_COUNT)
	_sweep.resize(STAT_COUNT)
	_shown_raw.resize(STAT_COUNT)
	_delta.resize(STAT_COUNT)
	_delta_t.resize(STAT_COUNT)
	_flash_t.resize(STAT_COUNT)
	_open()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_open()

## Al abrir el menu: la fijacion se cierra de nuevo y las barras se vacian para llenarse en secuencia.
func _open() -> void:
	_lock_time = 0.0
	_hover_time = 0.0
	_launch_t = -1.0
	if _sweep.size() < STAT_COUNT or models.is_empty():
		return
	var rows := _stat_rows(models[index])
	for k in STAT_COUNT:
		_old_lit[k] = 0
		_new_lit[k] = _lit_segments(rows[k]["frac"])
		_sweep[k] = -k * OPEN_STAGGER * SWEEP_RATE
		_shown_raw[k] = 0.0
		_delta[k] = 0
		_delta_t[k] = 0.0
		_flash_t[k] = 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	size = get_viewport_rect().size
	_clock += delta
	_lock_time = minf(_lock_time + delta, LOCK_DONE)
	_hover_time = _hover_time + delta if button_hover else 0.0
	for k in Shop.COUNT:
		_shop_flash[k] = maxf(_shop_flash[k] - delta, 0.0)
	if _launch_t >= 0.0:
		_launch_t += delta
		if _launch_t >= LAUNCH_TIME:
			_finish_launch()
	if not models.is_empty():
		_update_stats(delta)
	queue_redraw()

## El barrido de cada barra avanza de izquierda a derecha, las cifras se deslizan hacia las del avion elegido y
## corren los temporizadores de destello e indicador de cambio.
func _update_stats(delta: float) -> void:
	var rows := _stat_rows(models[index])
	var follow := 1.0 - exp(-BAR_FOLLOW * delta)
	for k in STAT_COUNT:
		_delta_t[k] = maxf(_delta_t[k] - delta, 0.0)
		_flash_t[k] = maxf(_flash_t[k] - delta, 0.0)
		_sweep[k] = minf(_sweep[k] + SWEEP_RATE * delta, float(SEGMENTS + SWEEP_TAIL + 1))   # sigue un poco mas para que se apague el destello de la cola
		if _sweep[k] >= 0.0:
			_shown_raw[k] = lerpf(_shown_raw[k], rows[k]["raw"], follow)

## Pixeles de pantalla por pixel del arte.
func _factor() -> float:
	return float(HudView.scale_for(size))

## Tamano del menu en pixeles del arte.
func _virtual_size() -> Vector2:
	return (size / _factor()).floor()

func _list_panel() -> Rect2:
	var n := models.size()
	return Rect2(MARGIN, LIST_TOP - PANEL_PAD, LIST_W, n * ROW_H + (n - 1) * ROW_GAP + 2.0 * PANEL_PAD)

func _row_rect(i: int) -> Rect2:
	return Rect2(MARGIN + PANEL_PAD, LIST_TOP + i * (ROW_H + ROW_GAP), LIST_W - 2.0 * PANEL_PAD, ROW_H)

func _stats_panel(S: Vector2) -> Rect2:
	return Rect2(S.x - MARGIN - STATS_W, LIST_TOP - PANEL_PAD, STATS_W, STAT_COUNT * STAT_ROW_H + 2.0 * PANEL_PAD)

func _button_rect(S: Vector2) -> Rect2:
	return Rect2((S.x - BUTTON_SIZE.x) * 0.5, S.y - BUTTON_BOTTOM - BUTTON_SIZE.y, BUTTON_SIZE.x, BUTTON_SIZE.y)

## Empieza la secuencia de salida: el pulsador se hunde, la camara se lanza al avion y la persiana se cierra.
## Al acabar se emite "confirmed". Pulsar cualquier tecla o clic durante la secuencia la salta.
func _launch() -> void:
	if _launch_t >= 0.0:
		return
	_launch_t = 0.0
	launching.emit()

func _finish_launch() -> void:
	_launch_t = -1.0
	confirmed.emit()

func _select(i: int) -> void:
	if _launch_t >= 0.0:
		return
	i = wrapi(i, 0, models.size())
	if i != index:
		var before := _stat_rows(models[index])
		index = i
		_lock_time = 0.0
		# cada barra barre de nuevo desde la izquierda; se anota cuanto cambia (en segmentos) respecto al avion anterior
		var after := _stat_rows(models[index])
		for k in STAT_COUNT:
			_old_lit[k] = _displayed_lit(k)
			_new_lit[k] = _lit_segments(after[k]["frac"])
			_sweep[k] = 0.0
			_delta[k] = _lit_segments(after[k]["frac"]) - _lit_segments(before[k]["frac"])
			_delta_t[k] = DELTA_TIME
			_flash_t[k] = FLASH_TIME
		chosen.emit(index)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and _launch_t >= 0.0:
		_finish_launch()   # un clic durante la salida la salta
		return
	if event is InputEventMouseMotion:
		var p: Vector2 = event.position / _factor()
		hover = -1
		for i in models.size():
			if _row_rect(i).has_point(p):
				hover = i
		shop_hover = -1
		for i in Shop.COUNT:
			if _shop_row(_virtual_size(), i).has_point(p):
				shop_hover = i
		var over_button := _button_rect(_virtual_size()).has_point(p)
		if over_button and not button_hover:
			armed.emit()
		button_hover = over_button
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position / _factor()
		for i in models.size():
			if _row_rect(i).has_point(p):
				_select(i)
				return
		for i in Shop.COUNT:
			if _shop_row(_virtual_size(), i).has_point(p):
				shop_buy.emit(i)
				return
		if _button_rect(_virtual_size()).has_point(p):
			_launch()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _launch_t >= 0.0:
		_finish_launch()   # cualquier tecla durante la salida la salta
		return
	var k: Key = event.keycode
	if k == KEY_UP or k == KEY_W or k == KEY_LEFT or k == KEY_A:
		_select(index - 1)
	elif k == KEY_DOWN or k == KEY_S or k == KEY_RIGHT or k == KEY_D:
		_select(index + 1)
	elif k >= KEY_1 and k < KEY_1 + models.size():
		_select(k - KEY_1)
	elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		_launch()

func _t(p: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	MilitaryStyle.text(self, font, p, s, sz, col, align, w)

func _draw() -> void:
	if models.is_empty():
		return
	var f := _factor()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, f))
	var S := _virtual_size()
	_draw_title(S)
	_draw_list()
	_draw_stats(S)
	_draw_shop(S)
	_draw_lock()
	_draw_button(S)
	_t(Vector2(0, S.y - HINT_BOTTOM), "W/S o flechas: elegir  -  1-%d: ir al avion  -  Enter: empezar  -  M: volver a este menu" % models.size(),
			Hud.TEXT_SMALL, Color(MilitaryStyle.KHAKI, DIM), HORIZONTAL_ALIGNMENT_CENTER, S.x)
	MilitaryStyle.overlay(self, S)
	if _launch_t >= 0.0:
		var closing := clampf((_launch_t - LAUNCH_SHUTTER_DELAY) / (LAUNCH_TIME - LAUNCH_SHUTTER_DELAY), 0.0, 1.0)
		HudStyle.shutter(self, S, closing, MilitaryStyle.AMBER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Cabecera: titulo y la ficha del avion elegido, escrita como a maquina al elegirlo.
func _draw_title(S: Vector2) -> void:
	var spec := models[index]
	_t(Vector2(0, TITLE_Y), TITLE, Hud.TEXT_BIG, MilitaryStyle.KHAKI_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, S.x)
	var designation := "%s   [%s / %s]" % [spec.title, spec.code(), spec.role]
	var typed := int(_lock_time * TYPE_RATE)
	_typed(S, DESIGNATION_Y, designation, typed, MilitaryStyle.AMBER)
	_typed(S, DESC_Y, spec.desc, typed - designation.length(), Color(MilitaryStyle.KHAKI, DIM + 0.2))

## Una linea centrada de la que solo se ven los primeros "chars" caracteres, con un cursor mientras se escribe.
func _typed(S: Vector2, y: float, line: String, chars: int, col: Color) -> void:
	if chars <= 0:
		return
	var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.TEXT_SMALL).x
	var shown := mini(chars, line.length())
	var text := line.substr(0, shown) + ("_" if shown < line.length() else "")
	_t(Vector2(floorf((S.x - width) * 0.5), y), text, Hud.TEXT_SMALL, col)

## Registro de aeronaves: cada fila lleva su numero de registro, mini-silueta, nombre y rol. La elegida lleva una
## pestana ambar, una luz piloto que parpadea, un pulso de luz y un pequeno retroceso.
func _draw_list() -> void:
	var panel := _list_panel()
	_t(Vector2(panel.position.x, panel.position.y - HEADER_GAP), "REGISTRO DE AERONAVES", Hud.TEXT_SMALL, MilitaryStyle.KHAKI)
	MilitaryStyle.panel(self, panel)
	for i in models.size():
		var row := _row_rect(i)
		var shift := Vector2.ZERO
		var ink := Color(MilitaryStyle.KHAKI, DIM + 0.2)
		if i == index:
			var pulse := clampf(1.0 - _lock_time / PULSE_TIME, 0.0, 1.0)
			draw_rect(row, MilitaryStyle.OLIVE_PANEL.lerp(MilitaryStyle.KHAKI, pulse * 0.5))
			draw_rect(Rect2(row.position.x, row.position.y, row.size.x, 1.0), MilitaryStyle.OLIVE_BEVEL)
			draw_rect(Rect2(row.position, Vector2(TAB_W, row.size.y)), MilitaryStyle.AMBER)
			shift.x = (1.0 - clampf(_lock_time / NUDGE_TIME, 0.0, 1.0)) * NUDGE_PX
			ink = MilitaryStyle.KHAKI_LIGHT
			_draw_pilot(row)
		elif i == hover:
			HudStyle.frame(self, row, Color(MilitaryStyle.KHAKI, HOVER_ALPHA))
		_draw_icon(i, row.position + Vector2(ICON_X, ICON_Y) + shift, MilitaryStyle.KHAKI_LIGHT if i == index else ink)
		_t(row.position + Vector2(ROW_NAME_X, ROW_NAME_Y) + shift, "R%02d  %s" % [i + 1, models[i].short], Hud.TEXT_SMALL, ink)
		_t(row.position + Vector2(ROW_NAME_X, ROW_ROLE_Y) + shift, models[i].role, Hud.TEXT_SMALL, Color(MilitaryStyle.GAUGE, DIM + 0.2))

## Luz piloto de la fila elegida: un cuadrado ambar que parpadea como un indicador de instrumento.
func _draw_pilot(row: Rect2) -> void:
	var on := int(_clock * PILOT_RATE * 2.0) % 2 == 0
	var at := Vector2(row.end.x - PILOT_INSET, row.position.y + (row.size.y - PILOT_SIZE) * 0.5).floor()
	draw_rect(Rect2(at - Vector2.ONE, Vector2(PILOT_SIZE, PILOT_SIZE) + Vector2(2.0, 2.0)), MilitaryStyle.OLIVE_DARK)
	draw_rect(Rect2(at, Vector2(PILOT_SIZE, PILOT_SIZE)), MilitaryStyle.AMBER if on else MilitaryStyle.RUST.darkened(0.5))

## Mini-silueta cenital de un avion, centrada en su caja de ICON_SIZE.
func _draw_icon(i: int, origin: Vector2, col: Color) -> void:
	if i >= silhouettes.size():
		return
	var zones := silhouettes[i]
	var spare := Vector2(ICON_SIZE, ICON_SIZE) - Vector2(zones.silhouette_size)
	var at := origin + (spare * 0.5).floor()
	for cells in zones.pixels:
		for cell in cells:
			draw_rect(Rect2(at + cell, Vector2.ONE), col)

## Fijacion del avion elegido: unos corchetes de telemetro se cierran con un "snap" sobre su fila y otros sobre el
## avion, unidos por una linea guia punteada; al cerrarse parpadean unos fotogramas. Tras eso quedan fijos.
func _draw_lock() -> void:
	var progress := clampf(_lock_time / LOCK_TIME, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 3.0)
	var closed_for := _lock_time - LOCK_TIME
	if closed_for > 0.0 and closed_for < LOCK_BLINK_TIME and HudStyle.blink_off(LOCK_BLINK_FRAMES):
		return
	var row := _row_rect(index)
	MilitaryStyle.brackets(self, row.grow(LOCK_GROW * (1.0 - eased)), MilitaryStyle.AMBER, BRACKET_LEN, false)
	if focus == Vector2.ZERO:
		return
	var plane_at := focus / _factor()
	var start := Vector2(_list_panel().end.x + 2.0, row.position.y + row.size.y * 0.5)
	var stop := plane_at - Vector2(PLANE_LOCK_R + 4.0, 0.0)
	HudStyle.dotted_line(self, start, start.lerp(stop, eased), Color(MilitaryStyle.KHAKI, GUIDE_ALPHA), GUIDE_STEP)
	var lock := Rect2(plane_at - Vector2(PLANE_LOCK_R, PLANE_LOCK_R), Vector2(PLANE_LOCK_R, PLANE_LOCK_R) * 2.0)
	MilitaryStyle.brackets(self, lock.grow(PLANE_LOCK_GROW * (1.0 - eased)), MilitaryStyle.KHAKI_LIGHT, BRACKET_LEN)
	# cruz de punteria en el centro del avion
	HudStyle.line(self, plane_at - Vector2(CROSS_LEN, 0.0), plane_at + Vector2(CROSS_LEN, 0.0), Color(MilitaryStyle.KHAKI_LIGHT, GUIDE_ALPHA * 2.0))
	HudStyle.line(self, plane_at - Vector2(0.0, CROSS_LEN), plane_at + Vector2(0.0, CROSS_LEN), Color(MilitaryStyle.KHAKI_LIGHT, GUIDE_ALPHA * 2.0))

## Telemetria del avion elegido: cinco metricas con barras segmentadas sobre ranuras oscuras.
func _draw_stats(S: Vector2) -> void:
	var panel := _stats_panel(S)
	_t(Vector2(panel.position.x, panel.position.y - HEADER_GAP), "TELEMETRIA", Hud.TEXT_SMALL, MilitaryStyle.KHAKI)
	MilitaryStyle.panel(self, panel)
	var rows := _stat_rows(models[index])
	for k in STAT_COUNT:
		var row: Dictionary = rows[k]
		var x := panel.position.x + PANEL_PAD
		var y := LIST_TOP + k * STAT_ROW_H
		# el valor destella en ambar al cambiar y vuelve a verde; sus cifras se deslizan con la barra
		var value_col := MilitaryStyle.GAUGE_LIGHT.lerp(MilitaryStyle.AMBER, _flash_t[k] / FLASH_TIME)
		_t(Vector2(x, y + STAT_LABEL_Y), row["label"], Hud.TEXT_SMALL, MilitaryStyle.KHAKI)
		_t(Vector2(x, y + STAT_LABEL_Y), _format_value(row, _shown_raw[k]), Hud.TEXT_SMALL, value_col, HORIZONTAL_ALIGNMENT_RIGHT, STATS_BAR_W)
		_draw_delta(Vector2(x + DELTA_X, y + STAT_LABEL_Y), k)
		_draw_segments(Vector2(x, y + STAT_BAR_Y), k)

## Actualiza los creditos y los niveles que muestra la tienda.
func set_shop(new_credits: int, new_tiers: PackedInt32Array) -> void:
	credits = new_credits
	tiers = new_tiers

## Resultado de un intento de compra, para el destello de la fila: ambar si se compro, oxido si no.
func shop_result(kind: int, ok: bool) -> void:
	_shop_flash[kind] = SHOP_FLASH_TIME
	_shop_ok[kind] = ok

func _shop_panel(S: Vector2) -> Rect2:
	var stats := _stats_panel(S)
	return Rect2(stats.position.x, stats.end.y + SHOP_GAP, STATS_W, Shop.COUNT * SHOP_ROW_H + 2.0 * PANEL_PAD)

func _shop_row(S: Vector2, i: int) -> Rect2:
	var panel := _shop_panel(S)
	return Rect2(panel.position.x + PANEL_PAD, panel.position.y + PANEL_PAD + i * SHOP_ROW_H, panel.size.x - 2.0 * PANEL_PAD, SHOP_ROW_H)

## Tienda: una fila por mejora con su nombre, los tres indicadores de nivel, el aumento actual y el precio del
## siguiente nivel. Bajo el panel, el detalle de la fila bajo el raton o el aviso de que se pierden al ser derribado.
func _draw_shop(S: Vector2) -> void:
	var panel := _shop_panel(S)
	_t(Vector2(panel.position.x, panel.position.y - HEADER_GAP), "TIENDA", Hud.TEXT_SMALL, MilitaryStyle.KHAKI)
	_t(Vector2(panel.position.x, panel.position.y - HEADER_GAP), "CREDITOS %d" % credits, Hud.TEXT_SMALL, MilitaryStyle.GAUGE_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT, panel.size.x)
	MilitaryStyle.panel(self, panel)
	for i in Shop.COUNT:
		var row := _shop_row(S, i)
		var tier := tiers[i]
		var price := Shop.price(i, tier)
		var affordable := price > 0 and credits >= price
		var flash := _shop_flash[i] / SHOP_FLASH_TIME
		if flash > 0.0:
			draw_rect(row, Color(MilitaryStyle.AMBER if _shop_ok[i] else MilitaryStyle.RUST, flash * 0.5))
		if i == shop_hover:
			HudStyle.frame(self, row, Color(MilitaryStyle.KHAKI, HOVER_ALPHA))
		var ink := MilitaryStyle.KHAKI_LIGHT if (affordable or price < 0) else Color(MilitaryStyle.KHAKI, DIM)
		_t(row.position + Vector2(SHOP_TEXT_X, SHOP_TEXT_Y), Shop.NAMES[i], Hud.TEXT_SMALL, ink)
		for level in Shop.TIERS:
			var pip := Rect2(row.position.x + SHOP_PIPS_X + level * (SHOP_PIP + SHOP_PIP_GAP), row.position.y + (row.size.y - SHOP_PIP) * 0.5, SHOP_PIP, SHOP_PIP)
			MilitaryStyle.slot(self, pip)
			if level < tier:
				draw_rect(pip.grow(-1.0), MilitaryStyle.GAUGE_LIGHT)
		var bonus := "+%d%%" % roundi(Shop.bonus(i, tier) * 100.0) if tier > 0 else "-"
		_t(row.position + Vector2(SHOP_BONUS_X, SHOP_TEXT_Y), bonus, Hud.TEXT_SMALL, ink)
		var cost_text := "MAX" if price < 0 else "%d" % price
		var cost_col := MilitaryStyle.GAUGE_LIGHT if (affordable or price < 0) else MilitaryStyle.RUST
		_t(Vector2(row.position.x, row.position.y + SHOP_TEXT_Y), cost_text, Hud.TEXT_SMALL, cost_col, HORIZONTAL_ALIGNMENT_RIGHT, row.size.x - SHOP_TEXT_X)
	var note := "SE PIERDEN AL SER DERRIBADO"
	if shop_hover >= 0 and Shop.price(shop_hover, tiers[shop_hover]) > 0:
		var next := tiers[shop_hover] + 1
		note = "CLIC: NIVEL %d, +%d%%, %d CR" % [next, roundi(Shop.bonus(shop_hover, next) * 100.0), Shop.price(shop_hover, tiers[shop_hover])]
	_t(Vector2(panel.position.x, panel.end.y + SHOP_NOTE_Y), note, Hud.TEXT_SMALL, Color(MilitaryStyle.KHAKI, DIM))

## Indicador de cambio respecto al avion anterior: +N en verde si la barra sube, -N en rojo si baja, = si igual.
func _draw_delta(at: Vector2, k: int) -> void:
	if _delta_t[k] <= 0.0:
		return
	var alpha := clampf(_delta_t[k] / (DELTA_TIME * DELTA_FADE), 0.0, 1.0)
	var change := _delta[k]
	var col := MilitaryStyle.GAUGE_LIGHT if change > 0 else (MilitaryStyle.RUST if change < 0 else MilitaryStyle.KHAKI)
	var text := "%+d" % change if change != 0 else "="
	_t(at, text, Hud.TEXT_SMALL, Color(col, alpha))

## Segmentos que se encienden con una fraccion (0..1) de barra.
func _lit_segments(frac: float) -> int:
	return roundi(clampf(frac, 0.0, 1.0) * SEGMENTS)

## Si el segmento i de la barra k esta encendido ahora: los que ya paso el barrido muestran el estado nuevo y el resto el viejo.
func _segment_on(k: int, i: int) -> bool:
	return i < _new_lit[k] if float(i) < _sweep[k] else i < _old_lit[k]

## Segmentos encendidos que se ven ahora en la barra k (a medias de un barrido mezcla el estado viejo y el nuevo).
func _displayed_lit(k: int) -> int:
	var count := 0
	for i in SEGMENTS:
		if _segment_on(k, i):
			count += 1
	return count

## Barra segmentada sobre ranuras oscuras: los segmentos encendidos en verde fosforo apagado. La cabeza del barrido y
## los segmentos que acaba de cambiar destellan en ambar.
func _draw_segments(origin: Vector2, k: int) -> void:
	var head := floori(_sweep[k])
	for i in SEGMENTS:
		var cell := Rect2(origin.x + i * (SEGMENT_W + SEGMENT_GAP), origin.y, SEGMENT_W, SEGMENT_H)
		MilitaryStyle.slot(self, cell)
		if not _segment_on(k, i):
			continue
		var changed := (i < _new_lit[k]) != (i < _old_lit[k])
		var flashing := changed and head >= i and head - i <= SWEEP_TAIL
		draw_rect(cell.grow(-1.0), MilitaryStyle.AMBER if flashing else MilitaryStyle.GAUGE)

## Texto de un valor de telemetria con su formato: los enteros se muestran sin decimales.
func _format_value(row: Dictionary, raw: float) -> String:
	var fmt: String = row["fmt"]
	return fmt % (int(raw) if row["is_int"] else raw)

## Las cinco metricas de un avion: etiqueta, valor, formato para mostrarlo y fraccion (0..1) de la barra.
func _stat_rows(spec: PlaneModels.Spec) -> Array[Dictionary]:
	return [
		{"label": "VELOCIDAD", "raw": spec.max_speed * Flight.MS_TO_KMH, "fmt": "%d km/h", "is_int": true, "frac": spec.max_speed / PlaneModels.SPEED_BAR_MAX},
		{"label": "MANIOBRA", "raw": spec.agility, "fmt": "x%.2f", "is_int": false, "frac": spec.agility / PlaneModels.AGILITY_BAR_MAX},
		{"label": "BLINDAJE", "raw": spec.health, "fmt": "%d", "is_int": true, "frac": spec.health / PlaneModels.HEALTH_BAR_MAX},
		{"label": "FUEGO", "raw": spec.firepower(), "fmt": "%d", "is_int": true, "frac": spec.firepower() / PlaneModels.FIREPOWER_BAR_MAX},
		{"label": "ESTABILIDAD", "raw": spec.stall_speed * Flight.MS_TO_KMH, "fmt": "%d km/h", "is_int": true,
			"frac": (PlaneModels.STALL_WORST - spec.stall_speed) / (PlaneModels.STALL_WORST - PlaneModels.STALL_BEST)},
	]

## Pulsador de salida, con tres estados: LISTO (verde), ARMADO (con el raton encima: se hunde 1 px, pasa a verde claro
## y unos corchetes de telemetro convergen y parpadean) y SALIDA (al pulsar: se hunde 2 px y pasa a ambar). Lleva
## doble marco y los remaches de la chapa.
func _draw_button(S: Vector2) -> void:
	var r := _button_rect(S)
	var launching_now := _launch_t >= 0.0
	var eased := 1.0 - pow(1.0 - clampf(_hover_time / HOVER_TIME, 0.0, 1.0), 3.0) if button_hover else 0.0
	if launching_now:
		eased = 1.0
		r.position.y += PRESS_RECOIL if _launch_t < PRESS_TIME else HOVER_OFFSET
	elif button_hover:
		r.position.y += HOVER_OFFSET
	var tone := MilitaryStyle.GAUGE.lerp(MilitaryStyle.GAUGE_LIGHT, eased)
	if launching_now:
		tone = MilitaryStyle.AMBER
	MilitaryStyle.panel(self, r, MilitaryStyle.OLIVE_PANEL)
	HudStyle.frame(self, r.grow(-BUTTON_INNER), Color(tone, 0.8))
	if eased > 0.0:
		var settled := _hover_time - HOVER_TIME
		var blinking := not launching_now and settled > 0.0 and settled < HOVER_BLINK_TIME and HudStyle.blink_off(LOCK_BLINK_FRAMES)
		if not blinking:
			MilitaryStyle.brackets(self, r.grow(BUTTON_GROW * (1.0 - eased)), tone, BRACKET_LEN)
	var state := "SALIDA" if launching_now else ("ARMADO" if button_hover else "LISTO")
	_t(Vector2(r.position.x, r.position.y + BUTTON_TEXT_Y), "EMPEZAR", Hud.TEXT_BIG, MilitaryStyle.KHAKI_LIGHT, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_t(Vector2(r.position.x, r.end.y + BUTTON_STATE_GAP), state, Hud.TEXT_SMALL, tone, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
