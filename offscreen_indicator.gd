## Indicadores de aviones fuera de pantalla: una flecha que orbita alrededor del centro, sobre un circulo
## invisible, apuntando hacia el avion. Es mas grande cuanto mas cerca esta y lleva su distancia. Los enemigos van en
## rojo y los demas jugadores en verde, con su nombre y en una orbita algo menor para que no se pisen.
class_name OffscreenIndicator
extends RefCounted

const ORBIT_FRAC := 0.36          # radio de la orbita relativo al alto de la pantalla
const ARROW_NEAR := 8.0           # largo (px) de la flecha de un enemigo pegado
const ARROW_FAR := 3.0            # largo (px) de la flecha de un enemigo lejano
const FAR_RANGE := 2000.0         # distancia (m) a partir de la cual la flecha tiene el tamano minimo
const ARROW_SPREAD := 0.6         # apertura (rad) de cada ala de la flecha respecto a su eje
const LABEL_GAP := 6.0            # separacion de la distancia al vertice de la flecha, hacia el centro (px)
const LABEL_W := 40.0             # ancho de la caja del texto de distancia
const PLAYER_ORBIT_FRAC := 0.31   # radio de la orbita de los jugadores aliados relativo al alto de la pantalla (menor que ORBIT_FRAC)
const PLAYER_LABEL_W := 96.0      # ancho de la caja del nombre y la distancia de un jugador aliado

func draw(hud: Hud) -> void:
	var g := hud.g
	for e in g.ai.enemies:
		if not e.dead:
			_arrow(hud, e.root.position, HudStyle.ALERT, "%d" % int(e.root.position.distance_to(g.plane.position)), ORBIT_FRAC, LABEL_W)
	# solo los jugadores, no la IA aliada
	for id in g.pilots.pilots:
		var p: RemotePilots.Pilot = g.pilots.pilots[id]
		if p.root != null and p.root.visible:
			var text := "%s %d" % [g.pilots.pilot_name(id), int(p.root.position.distance_to(g.plane.position))]
			_arrow(hud, p.root.position, HudStyle.PHOSPHOR, text, PLAYER_ORBIT_FRAC, PLAYER_LABEL_W)

## Flecha de un avion fuera de pantalla (si esta en pantalla no hace nada: lo marcan los corchetes de Hud).
func _arrow(hud: Hud, world: Vector3, col: Color, label: String, orbit_frac: float, label_w: float) -> void:
	if hud.visible_point(world).is_finite():
		return
	var g := hud.g
	var design := hud.design_size()
	var center := design / 2.0
	var radius := design.y * orbit_frac
	# direccion en pantalla segun la camara: sirve tambien para los que estan detras
	var v := g.cam.global_transform.basis.inverse() * (world - g.cam.global_position)
	var dir := Vector2(v.x, -v.y)
	dir = dir.normalized() if dir.length() > 0.001 else Vector2.UP
	var dist: float = world.distance_to(g.plane.position)
	var length := lerpf(ARROW_NEAR, ARROW_FAR, clampf(dist / FAR_RANGE, 0.0, 1.0))
	var tip := center + dir * radius
	for side in [-1.0, 1.0]:
		HudStyle.line(hud, tip, tip + (-dir).rotated(side * ARROW_SPREAD) * length, col)
	var label_at := tip - dir * (length + LABEL_GAP)
	HudStyle.text(hud, hud.font, Vector2(label_at.x - label_w * 0.5, label_at.y + 3.0), label, Hud.TEXT_SMALL, col, HORIZONTAL_ALIGNMENT_CENTER, label_w)
