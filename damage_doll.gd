## Silueta de dano del HUD: el avion visto desde arriba, hecho con los voxeles reales de su modelo y dividido en
## zonas (morro, fuselaje, alas y cola). Cada zona pasa de verde a ambar y a rojo segun su dano, parpadea al
## recibir un impacto y desaparece (queda un fantasma tenue) al destruirse. Es solo informativa.
class_name DamageDoll
extends RefCounted

const GREEN_BELOW := 0.34         # dano (0..1) por debajo del cual la zona esta verde
const AMBER_BELOW := 0.67         # dano por debajo del cual esta ambar; por encima, roja
const GHOST_ALPHA := 0.15         # opacidad del fantasma de una zona destruida
const BLINK_TIME := 0.3           # segundos que parpadea una zona al recibir dano
const CHANGE_EPSILON := 0.001     # aumento de dano a partir del cual se considera que la zona ha recibido un impacto
const ABOVE_HEALTH := 20.0        # separacion de la silueta a la barra de salud (px), para dejar sitio a su texto

var _fade := HudFade.new()
var _zones: PlaneZones            # modelo para el que se guardaron los datos de abajo
var _last := PackedFloat32Array() # dano mostrado de cada zona en el fotograma anterior
var _blink := PackedFloat32Array()  # tiempo de parpadeo que le queda a cada zona

func draw(hud: Hud) -> void:
	var g := hud.g
	var delta := hud.get_process_delta_time()
	if g.zones != _zones:
		_zones = g.zones
		_last.resize(PlaneZones.COUNT)
		_last.fill(0.0)
		_blink.resize(PlaneZones.COUNT)
		_blink.fill(0.0)
	var shown := _shown_damage(g)
	var total := 0.0
	var blinking := false
	for i in PlaneZones.COUNT:
		if shown[i] > _last[i] + CHANGE_EPSILON:
			_blink[i] = BLINK_TIME
		_last[i] = shown[i]
		_blink[i] = maxf(_blink[i] - delta, 0.0)
		total += shown[i]
		blinking = blinking or _blink[i] > 0.0
	var alpha := _fade.update(total, delta, 0.0, blinking)
	var box_origin := Vector2(Hud.MARGIN, hud.design_size().y - Hud.MARGIN - Hud.BAR_H - ABOVE_HEALTH - PlaneZones.SILHOUETTE_SIZE)
	var spare := Vector2(PlaneZones.SILHOUETTE_SIZE, PlaneZones.SILHOUETTE_SIZE) - Vector2(_zones.silhouette_size)
	var origin := box_origin + (spare * 0.5).floor()   # centrada en su caja
	var blink_off := hud.blink_off()
	for i in PlaneZones.COUNT:
		if shown[i] >= 1.0:
			_draw_zone(hud, origin, i, Color(HudStyle.PHOSPHOR, GHOST_ALPHA), false)
		elif not (_blink[i] > 0.0 and blink_off):
			_draw_zone(hud, origin, i, Color(_tone(shown[i]), alpha), true)

## Dano que se muestra en cada zona: el acumulado por impactos y, ademas, el que ya afecta al vuelo
## (motor y morro con la salud baja, y el ala que tira del avion hacia su lado).
func _shown_damage(g: Game) -> PackedFloat32Array:
	var shown := g.zone_damage.duplicate()
	var flight_damage: float = g.flight.damage_level()
	shown[PlaneZones.Zone.NOSE] = maxf(shown[PlaneZones.Zone.NOSE], flight_damage)
	var wing := PlaneZones.Zone.WING_R if g.flight.wing_side > 0.0 else PlaneZones.Zone.WING_L
	shown[wing] = maxf(shown[wing], flight_damage)
	return shown

func _tone(damage: float) -> Color:
	if damage < GREEN_BELOW:
		return HudStyle.PHOSPHOR
	if damage < AMBER_BELOW:
		return HudStyle.AMBER
	return HudStyle.ALERT

## Dibuja los pixeles de una zona; con "shadow" lleva la sombra de 1 px que da contraste.
func _draw_zone(hud: Hud, origin: Vector2, zone: int, col: Color, shadow: bool) -> void:
	var cells := _zones.pixels[zone]
	if shadow:
		var dark := Color(HudStyle.SHADOW, HudStyle.SHADOW.a * col.a)
		for cell in cells:
			hud.draw_rect(Rect2(((origin + cell) * HudStyle.k).floor() + HudStyle.SHADOW_OFFSET, Vector2.ONE * ceilf(HudStyle.k)), dark)
	for cell in cells:
		hud.draw_rect(Rect2(((origin + cell) * HudStyle.k).floor(), Vector2.ONE * ceilf(HudStyle.k)), col)
