## Nucleo de apuntado del HUD: cursor del raton, cruz del morro, linea elastica entre ambos,
## indicador de adelanto con arco de distancia eficaz y arco de municion junto al morro.
class_name AircraftReticle
extends RefCounted

const CURSOR_R := 8                     # radio del cursor del raton: circulo de 16 px
const NOSE_ARM := 3                     # brazos de la cruz del morro: cruz de 7x7 px
const TETHER_STEP := 3.0                # separacion de los puntos de la linea elastica (px)
const TETHER_FADE := Vector2(12.0, 48.0) # distancia (px) entre morro y cursor a la que la linea se apaga y a la que es plena
const AMMO_ARC_R := 12.0                # radio del arco de municion alrededor del morro (por fuera del cursor)
const AMMO_ARC_FROM := 0.62 * PI        # inicio del arco (abajo a la izquierda), en radianes de pantalla
const AMMO_ARC_TO := 1.38 * PI          # final del arco (arriba a la izquierda)
const LEAD_R := 3.0                     # semidiagonal del rombo de adelanto
const LEAD_ARC_R := 8.0                 # radio del arco de distancia eficaz alrededor del rombo
const LOCK_FLASH_TIME := 0.15           # segundos que parpadea el adelanto al fijar el blanco
const LOCK_FLASH_RATE := 30.0           # parpadeos por segundo mientras dura (2 fotogramas a 60 fps)
const NOSE_RANGE := 600.0               # distancia (m) a la que se proyecta la cruz del morro, con la caida de la bala
const HIT_R := Vector2(4.0, 10.0)       # radios interior y exterior del marcador de impacto
const HIT_KILL_R := Vector2(5.0, 17.0)  # igual, al derribar
const HIT_FADE := 0.3                   # segundos que tarda en apagarse el marcador de impacto

var lock_flash := 0.0                   # tiempo que queda de parpadeo tras fijar un blanco
var _was_locked := false
var _ammo_shown := 1.0                  # nivel de municion mostrado (0..1), suavizado

## Dibuja todo sobre "hud" (que es el lienzo) con el estado del juego de hud.g.
func draw(hud: Hud) -> void:
	var g := hud.g
	var cam: Camera3D = g.cam
	# cruz del morro: hacia donde apunta el canon, con la caida de la bala
	var aim_t: float = NOSE_RANGE / (Weapons.BULLET_SPEED + g.speed)
	var nose_world: Vector3 = g.plane.position + (-g.plane.transform.basis.z) * NOSE_RANGE + Vector3.DOWN * 0.5 * Weapons.GRAVITY * aim_t * aim_t
	var cursor_world: Vector3 = g.plane.position + g.aim_dir * Flight.AIM_DRAW_DIST
	var nose_ok := not cam.is_position_behind(nose_world)
	var cursor_ok := not cam.is_position_behind(cursor_world)
	var nose := hud.to_hud(cam.unproject_position(nose_world))
	var cursor := hud.to_hud(cam.unproject_position(cursor_world))
	var locked: bool = g.weapons.target_locked
	var ink := HudStyle.ALERT if locked else HudStyle.PHOSPHOR
	if nose_ok and cursor_ok:
		_draw_tether(hud, nose, cursor, ink)
	if cursor_ok:
		HudStyle.circle(hud, cursor, CURSOR_R, HudStyle.PHOSPHOR)
	if nose_ok:
		HudStyle.line(hud, nose + Vector2(-NOSE_ARM, 0), nose + Vector2(NOSE_ARM, 0), ink)
		HudStyle.line(hud, nose + Vector2(0, -NOSE_ARM), nose + Vector2(0, NOSE_ARM), ink)
		_draw_ammo_arc(hud, nose)
		_draw_hit(hud, nose)
	_draw_lead(hud, locked)

## Linea punteada de 1 px entre el morro y el cursor: se apaga al acercarse uno al otro.
func _draw_tether(hud: Hud, nose: Vector2, cursor: Vector2, ink: Color) -> void:
	var gap := nose.distance_to(cursor)
	var alpha := clampf(inverse_lerp(TETHER_FADE.x, TETHER_FADE.y, gap), 0.0, 1.0)
	if alpha <= 0.0 or gap <= CURSOR_R + NOSE_ARM + 2.0:
		return
	var dir := (cursor - nose) / gap
	HudStyle.dotted_line(hud, nose + dir * (NOSE_ARM + 2.0), cursor - dir * CURSOR_R, Color(ink, alpha), TETHER_STEP)

## Arco a la izquierda del morro: se vacia al disparar y se llena al recargar.
func _draw_ammo_arc(hud: Hud, nose: Vector2) -> void:
	var g := hud.g
	var frac: float = float(g.weapons.ammo) / g.player_spec.mag_size
	if g.weapons.reloading:
		frac = 1.0 - g.weapons.reload_t / Weapons.RELOAD_TIME
	var col := HudStyle.ALERT if g.weapons.reloading or frac < Hud.BAR_LOW else HudStyle.PHOSPHOR
	_ammo_shown = lerpf(_ammo_shown, frac, 1.0 - exp(-hud.get_process_delta_time() * Hud.BAR_SMOOTH))
	HudStyle.arc(hud, nose, AMMO_ARC_R, AMMO_ARC_FROM, AMMO_ARC_TO, Color(col, HudStyle.TRACK_ALPHA))
	if _ammo_shown > 0.0:
		HudStyle.arc(hud, nose, AMMO_ARC_R, AMMO_ARC_FROM, lerpf(AMMO_ARC_FROM, AMMO_ARC_TO, clampf(_ammo_shown, 0.0, 1.0)), col)

## Marcador de impacto alrededor del morro.
func _draw_hit(hud: Hud, nose: Vector2) -> void:
	var g := hud.g
	if g.hit_t <= 0.0:
		return
	var hc := Color(HudStyle.ALERT if g.hit_kill else HudStyle.PHOSPHOR, g.hit_t / HIT_FADE)
	var r := HIT_KILL_R if g.hit_kill else HIT_R
	for dgn in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		HudStyle.line(hud, nose + dgn * r.x, nose + dgn * r.y, hc)

## Rombo en el punto de adelanto del objetivo marcado, con un arco que se llena cuanto mas dentro de la
## distancia de tiro eficaz esta. Parpadea unos fotogramas al fijar el blanco.
func _draw_lead(hud: Hud, locked: bool) -> void:
	var g := hud.g
	if locked and not _was_locked:
		lock_flash = LOCK_FLASH_TIME
	_was_locked = locked
	lock_flash = maxf(lock_flash - hud.get_process_delta_time(), 0.0)
	var target: AiPlanes.AiPlane = g.weapons.lead_target
	if target == null or target.dead or g.cam.is_position_behind(g.weapons.lead_pos):
		return
	if lock_flash > 0.0 and int(lock_flash * LOCK_FLASH_RATE) % 2 == 0:
		return
	var p := hud.to_hud(g.cam.unproject_position(g.weapons.lead_pos))
	var col := HudStyle.ALERT if locked else HudStyle.PHOSPHOR
	HudStyle.diamond(hud, p, LEAD_R, col)
	var dist: float = target.root.position.distance_to(g.plane.position)
	var frac: float = g.weapons.effective_fraction(dist)
	HudStyle.arc(hud, p, LEAD_ARC_R, -PI * 0.5, PI * 1.5, Color(col, HudStyle.TRACK_ALPHA))
	if frac > 0.0:
		HudStyle.arc(hud, p, LEAD_ARC_R, -PI * 0.5, -PI * 0.5 + TAU * frac, col)
