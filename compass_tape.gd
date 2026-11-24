## Brujula del HUD: cinta horizontal fina arriba al centro con el rumbo, los puntos cardinales y marcas de
## los enemigos y aliados que caen en el tramo visible. El norte es el eje -Z del mundo.
class_name CompassTape
extends RefCounted

const TOP_Y := 22.0               # altura del eje de la cinta (px)
const HALF_W := 100.0             # semianchura visible de la cinta (px)
const PX_PER_DEG := 1.5           # desplazamiento de la cinta por grado
const TICK_MINOR := 2.0           # largo de la muesca cada 5 grados (px)
const TICK_MEDIUM := 4.0          # muesca cada 10 grados
const TICK_CARDINAL := 6.0        # muesca de un punto cardinal
const MINOR_DEG := 5              # grados entre muescas menores
const MEDIUM_DEG := 10            # grados entre muescas medias
const CARDINAL_DEG := 90          # grados entre puntos cardinales
const CARDINALS := ["N", "E", "S", "O"]  # norte, este, sur, oeste
const CARET := 3.0                # tamano de la flecha del rumbo actual (px)
const MARK_DROP := 10.0           # separacion de las marcas de objetivos bajo el eje (px)
const HEADING_ACTIVE_RATE := 20.0 # grados por segundo a partir de los que la cinta se ilumina

var _fade := HudFade.new()
var _unwrapped := 0.0             # rumbo acumulado sin saltos de 360 a 0, para medir cuanto gira
var _has_last := false
var _last_heading := 0.0

## Rumbo (0..360, 0 = -Z, 90 = +X) de un vector del mundo.
static func bearing_of(v: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(v.x, -v.z)), 360.0)

func draw(hud: Hud) -> void:
	var g := hud.g
	var delta := hud.get_process_delta_time()
	var heading := bearing_of(-g.plane.transform.basis.z)
	if _has_last:
		_unwrapped += wrapf(heading - _last_heading, -180.0, 180.0)
	_last_heading = heading
	_has_last = true
	var alpha := _fade.update(_unwrapped, delta, HEADING_ACTIVE_RATE, false)
	var ink := Color(HudStyle.PHOSPHOR, alpha)
	var cx := hud.design_size().x / 2.0
	HudStyle.line(hud, Vector2(cx - HALF_W, TOP_Y), Vector2(cx + HALF_W, TOP_Y), ink)
	var half_deg := int(HALF_W / PX_PER_DEG)
	var first := int(floorf(heading)) - half_deg
	first -= posmod(first, MINOR_DEG)
	for d in range(first, int(ceilf(heading)) + half_deg + 1, MINOR_DEG):
		var x := cx + (float(d) - heading) * PX_PER_DEG
		if absf(x - cx) > HALF_W:
			continue
		var is_cardinal := posmod(d, CARDINAL_DEG) == 0
		var tick_len := TICK_CARDINAL if is_cardinal else (TICK_MEDIUM if posmod(d, MEDIUM_DEG) == 0 else TICK_MINOR)
		HudStyle.line(hud, Vector2(x, TOP_Y), Vector2(x, TOP_Y + tick_len), ink)
		if is_cardinal:
			var letter: String = CARDINALS[posmod(roundi(float(d) / CARDINAL_DEG), CARDINALS.size())]
			HudStyle.text(hud, hud.font, Vector2(x - 8.0, TOP_Y - 3.0), letter, Hud.TEXT_SMALL, ink, HORIZONTAL_ALIGNMENT_CENTER, 16.0)
	# rumbo actual: flecha bajo el eje y numero
	var tip := Vector2(cx, TOP_Y + 2.0)
	HudStyle.line(hud, tip, tip + Vector2(-CARET, CARET), ink)
	HudStyle.line(hud, tip, tip + Vector2(CARET, CARET), ink)
	HudStyle.text(hud, hud.font, Vector2(cx - 12.0, TOP_Y + 2.0 * CARET + 8.0), "%03d" % int(heading), Hud.TEXT_SMALL, ink, HORIZONTAL_ALIGNMENT_CENTER, 24.0)
	_draw_marks(hud, heading, cx)

## Marcas bajo la cinta: puntos para los enemigos y aliados en el tramo visible, y un rombo para el objetivo marcado.
func _draw_marks(hud: Hud, heading: float, cx: float) -> void:
	var g := hud.g
	for e in g.ai.enemies:
		if not e.dead:
			_mark(hud, heading, cx, e.root.position, HudStyle.ALERT, 2.0)
	for a in g.ai.allies:
		if not a.dead:
			_mark(hud, heading, cx, a.root.position, HudStyle.PHOSPHOR, 1.0)
	var target: AiPlanes.AiPlane = g.weapons.lead_target
	if target != null and not target.dead:
		var x := _x_of(heading, cx, target.root.position - g.plane.position)
		if absf(x - cx) <= HALF_W:
			HudStyle.diamond(hud, Vector2(x, TOP_Y + MARK_DROP), 3.0, HudStyle.ALERT)

func _mark(hud: Hud, heading: float, cx: float, world_pos: Vector3, col: Color, radius: float) -> void:
	var x := _x_of(heading, cx, world_pos - hud.g.plane.position)
	if absf(x - cx) <= HALF_W:
		HudStyle.circle(hud, Vector2(x, TOP_Y + MARK_DROP), int(radius), col)

## Posicion horizontal en la cinta del rumbo de un vector relativo al avion.
func _x_of(heading: float, cx: float, rel: Vector3) -> float:
	return cx + wrapf(bearing_of(rel) - heading, -180.0, 180.0) * PX_PER_DEG
