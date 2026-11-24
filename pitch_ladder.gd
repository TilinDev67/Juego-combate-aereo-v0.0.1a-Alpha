## Referencia de horizonte del HUD: dos segmentos cortos a los lados del centro que se inclinan con el
## alabeo y suben o bajan con el cabeceo, sin tapar el centro. Tenues mientras el avion esta estable.
class_name PitchLadder
extends RefCounted

const GAP := 36.0                 # distancia del centro a donde empieza cada segmento (px)
const LENGTH := 16.0              # largo de cada segmento (px)
const PX_PER_RAD := 90.0          # desplazamiento del horizonte por radian de cabeceo
const MAX_OFFSET := 70.0          # desplazamiento maximo del horizonte respecto al centro (px)
const ACTIVE_RATE := 0.8          # rad/s de cabeceo o alabeo a partir de los que se ilumina

var _pitch_fade := HudFade.new()
var _roll_fade := HudFade.new()

func draw(hud: Hud) -> void:
	var g := hud.g
	var delta := hud.get_process_delta_time()
	var b: Basis = g.plane.transform.basis
	var up_local: Vector3 = b.inverse() * Vector3.UP
	var roll: float = atan2(up_local.x, up_local.y)
	var pitch: float = asin(clampf((-b.z).y, -1.0, 1.0))
	var alpha := maxf(_pitch_fade.update(pitch, delta, ACTIVE_RATE, false), _roll_fade.update(roll, delta, ACTIVE_RATE, false))
	var ink := Color(HudStyle.PHOSPHOR, alpha)
	var center := hud.design_size() / 2.0
	var off := clampf(pitch * PX_PER_RAD, -MAX_OFFSET, MAX_OFFSET)
	for side in [-1.0, 1.0]:
		var from := center + Vector2(side * GAP, off).rotated(roll)
		var to := center + Vector2(side * (GAP + LENGTH), off).rotated(roll)
		HudStyle.line(hud, from, to, ink)
