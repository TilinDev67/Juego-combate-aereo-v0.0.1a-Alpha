## Cintas laterales del HUD: velocidad a la izquierda (con la barra de gas) y altitud a la derecha
## (con el radar altimetro cerca del suelo). Muescas de 1 px que se desplazan; tenues mientras son estables.
class_name FlightTapes
extends RefCounted

const OFFSET_X := 150.0           # distancia de cada cinta al centro de la pantalla (px)
const HALF_H := 50.0              # semialtura visible de las cintas (px)
const TICK_MINOR := 3.0           # largo de una muesca menor (px)
const TICK_MAJOR := 6.0           # largo de una muesca mayor, que lleva numero
const LABEL_GAP := 7.0            # separacion entre la cinta y sus numeros (px)
const LABEL_W := 28.0             # ancho de la caja de un numero
const LABEL_CLEAR := 9.0          # los numeros a menos de esto del centro se omiten: ahi va la lectura actual
const CARET := 3.0                # tamano de la flecha que marca el valor actual (px)
const SPEED_PX_PER_KMH := 0.5     # desplazamiento de la cinta de velocidad por km/h
const SPEED_MINOR := 10           # km/h entre muescas menores
const SPEED_MAJOR := 50           # km/h entre muescas mayores
const ALT_PX_PER_M := 0.25        # desplazamiento de la cinta de altitud por metro
const ALT_MINOR := 20             # m entre muescas menores
const ALT_MAJOR := 100            # m entre muescas mayores
const SPEED_CAUTION_MARGIN := 10.0 # m/s sobre la perdida por debajo de los que la velocidad pasa a ambar
const OVERSPEED_CAUTION := 0.92   # fraccion de la velocidad maxima a partir de la que pasa a ambar
const OVERSPEED_ALERT := 0.98     # fraccion de la velocidad maxima a partir de la que pasa a rojo
const ALT_CAUTION := 80.0         # altitud (m) por debajo de la que la cinta pasa a ambar
const RADAR_MAX := 150.0          # altitud (m) por debajo de la que aparece la barra del radar altimetro
const RADAR_DANGER := 40.0        # altitud (m) por debajo de la que el radar parpadea en rojo
const RADAR_BLINK_RATE := 8.0     # parpadeos por segundo del radar en peligro
const SLIM_W := 3.0               # ancho de las barras finas de gas y radar (px)
const SLIM_GAP := 8.0             # separacion de esas barras a su cinta (px)
const SPEED_ACTIVE_RATE := 25.0   # km/h por segundo a partir de los que la cinta de velocidad se ilumina
const ALT_ACTIVE_RATE := 20.0     # m/s a partir de los que la cinta de altitud se ilumina
const THROTTLE_ACTIVE_RATE := 0.05 # fraccion de gas por segundo a partir de la que la barra se ilumina
const NOTE_Y := 10.0              # separacion del texto bajo cada cinta (px)

var _speed_fade := HudFade.new()
var _alt_fade := HudFade.new()
var _throttle_fade := HudFade.new()
var _clock := 0.0                 # tiempo acumulado, para el parpadeo del radar

func draw(hud: Hud) -> void:
	var g := hud.g
	var delta := hud.get_process_delta_time()
	_clock += delta
	var center := hud.design_size() / 2.0
	_draw_speed(hud, g, center, delta)
	_draw_altitude(hud, g, center, delta)

func _draw_speed(hud: Hud, g: Game, center: Vector2, delta: float) -> void:
	var stall: float = g.player_spec.stall_speed
	var vmax: float = g.player_spec.max_speed
	var kmh: float = g.speed * Flight.MS_TO_KMH
	var tone := HudStyle.PHOSPHOR
	if g.speed < stall or g.speed > vmax * OVERSPEED_ALERT:
		tone = HudStyle.ALERT
	elif g.speed < stall + SPEED_CAUTION_MARGIN or g.speed > vmax * OVERSPEED_CAUTION:
		tone = HudStyle.AMBER
	var alpha := _speed_fade.update(kmh, delta, SPEED_ACTIVE_RATE, tone != HudStyle.PHOSPHOR)
	var x := center.x - OFFSET_X
	_draw_tape(hud, Vector2(x, center.y), kmh, SPEED_PX_PER_KMH, SPEED_MINOR, SPEED_MAJOR, 1.0, Color(tone, alpha), stall * Flight.MS_TO_KMH)
	# gas: barra fina junto a la cinta, por su lado interior
	var throttle_alpha := _throttle_fade.update(g.throttle, delta, THROTTLE_ACTIVE_RATE, false)
	var ink := Color(HudStyle.PHOSPHOR, throttle_alpha)
	HudStyle.slim_bar(hud, Rect2(x + SLIM_GAP, center.y - HALF_H, SLIM_W, 2.0 * HALF_H), g.throttle, ink)
	_note(hud, Vector2(x, center.y + HALF_H + NOTE_Y), "GAS %d%%" % int(g.throttle * 100.0), ink)

func _draw_altitude(hud: Hud, g: Game, center: Vector2, delta: float) -> void:
	var alt: float = g.plane.position.y
	var tone := HudStyle.PHOSPHOR
	if alt < RADAR_DANGER:
		tone = HudStyle.ALERT
	elif alt < ALT_CAUTION:
		tone = HudStyle.AMBER
	var alpha := _alt_fade.update(alt, delta, ALT_ACTIVE_RATE, tone != HudStyle.PHOSPHOR)
	var x := center.x + OFFSET_X
	_draw_tape(hud, Vector2(x, center.y), alt, ALT_PX_PER_M, ALT_MINOR, ALT_MAJOR, -1.0, Color(tone, alpha), -INF)
	# radar altimetro: solo cerca del suelo; parpadea en rojo en peligro
	if alt < RADAR_MAX:
		var blink_on := alt >= RADAR_DANGER or int(_clock * RADAR_BLINK_RATE * 2.0) % 2 == 0
		if blink_on:
			var radar_col := HudStyle.ALERT if alt < RADAR_DANGER else HudStyle.AMBER
			HudStyle.slim_bar(hud, Rect2(x - SLIM_GAP - SLIM_W, center.y - HALF_H, SLIM_W, 2.0 * HALF_H), 1.0 - alt / RADAR_MAX, radar_col)
	var ink := Color(HudStyle.PHOSPHOR, alpha)
	var vario: float = g.velocity().y
	_note(hud, Vector2(x, center.y + HALF_H + NOTE_Y), "%+d m/s" % int(vario), ink)
	var g_col := HudStyle.ALERT if g.g_force > Hud.G_WARN else ink
	_note(hud, Vector2(x, center.y + HALF_H + 2.0 * NOTE_Y), "%.1f G" % g.g_force, g_col)

func _note(hud: Hud, pos: Vector2, s: String, col: Color) -> void:
	HudStyle.text(hud, hud.font, Vector2(pos.x - LABEL_W, pos.y), s, Hud.TEXT_SMALL, col, HORIZONTAL_ALIGNMENT_CENTER, 2.0 * LABEL_W)

## Cinta vertical: eje, muescas que se desplazan con el valor y numeros en las mayores. "inward" es +1 si las
## muescas apuntan a la derecha (cinta izquierda) o -1 si a la izquierda. "danger_below" pinta de rojo el eje bajo ese valor.
func _draw_tape(hud: Hud, center: Vector2, value: float, px_per_unit: float, minor: int, major: int,
		inward: float, col: Color, danger_below: float) -> void:
	var half_units := HALF_H / px_per_unit
	HudStyle.line(hud, center + Vector2(0, -HALF_H), center + Vector2(0, HALF_H), col)
	if danger_below > value - half_units:
		var y0 := clampf(center.y - (danger_below - value) * px_per_unit, center.y - HALF_H, center.y + HALF_H)
		HudStyle.line(hud, Vector2(center.x - inward * 2.0, y0), Vector2(center.x - inward * 2.0, center.y + HALF_H), Color(HudStyle.ALERT, col.a))
	var v := ceili((value - half_units) / minor) * minor
	while v <= value + half_units:
		var y := center.y - (v - value) * px_per_unit
		var is_major := v % major == 0
		HudStyle.line(hud, Vector2(center.x, y), Vector2(center.x + inward * (TICK_MAJOR if is_major else TICK_MINOR), y), col)
		if is_major and absf(y - center.y) > LABEL_CLEAR:
			_label(hud, Vector2(center.x, y), v, inward, col)
		v += minor
	# valor actual: flecha hacia el eje y el numero exacto
	var tip := Vector2(center.x - inward * 1.0, center.y)
	HudStyle.line(hud, tip, tip + Vector2(-inward * CARET, -CARET), col)
	HudStyle.line(hud, tip, tip + Vector2(-inward * CARET, CARET), col)
	_label(hud, center, int(value), inward, col)

## Numero a un lado de la cinta (por fuera de las muescas), alineado a ella.
func _label(hud: Hud, at: Vector2, number: int, inward: float, col: Color) -> void:
	var x := at.x - LABEL_GAP - LABEL_W if inward > 0.0 else at.x + LABEL_GAP
	var align := HORIZONTAL_ALIGNMENT_RIGHT if inward > 0.0 else HORIZONTAL_ALIGNMENT_LEFT
	HudStyle.text(hud, hud.font, Vector2(x, at.y + 3.0), "%d" % number, Hud.TEXT_SMALL, col, align, LABEL_W)
