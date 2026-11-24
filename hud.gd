## HUD de combate en pixel art: lineas finas, puntos y texto con contorno, sin paneles.
## Se dibuja en un SubViewport virtual (ver HudView): una unidad de este codigo es un pixel del arte.
class_name Hud
extends Control

const TEXT_SMALL := 8           # tamano de los datos (px virtuales): multiplo de 8, donde la fuente es nitida
const TEXT_BIG := 16            # tamano de los avisos grandes
const MARGIN := 8.0             # separacion de los datos al borde de la pantalla
const BAR_W := 80.0             # largo de las barras de salud y municion
const BAR_H := 5.0              # alto de las barras (marco, hueco, relleno, hueco, marco)
const BAR_LOW := 0.3            # fraccion por debajo de la cual una barra pasa a rojo
const LINE_H := 10.0            # separacion entre lineas de texto
const MARKER_R := 11.0          # semilado de los corchetes de un avion en pantalla
const PLAYER_DIAMOND_R := 3.0     # semidiagonal del rombo sobre los corchetes de un jugador aliado
const PLAYER_DIAMOND_GAP := 5.0   # separacion del rombo al corchete de arriba
const MARKER_TICK := 4.0        # largo de los brazos de cada corchete
const BANNER_TIME := 3.0         # segundos que se ve el cartel de una ronda nueva
const BANNER_Y := 0.3            # altura de los carteles de ronda en pantalla, relativa al alto
const ROSTER_DIM := 0.5          # cuanto se oscurece en la lista de pilotos el que esta en base
const MARKER_LABEL_W := 80.0    # ancho del texto bajo un marcador (px): cabe un nombre y la distancia
const MARKER_EDGE := 20.0       # margen del borde a partir del cual un avion cuenta como fuera de pantalla
const STALL_WARN := 0.2         # perdida (0..1) a partir de la cual se muestra el aviso PERDIDA
const STALL_WARN_Y := 0.3       # altura del aviso en pantalla, relativa al alto
const G_WARN := 7.0             # G a partir de las que el indicador se pone rojo
const G_VIGNETTE_START := 6.0   # G a partir de las que se oscurecen los bordes de la pantalla
const G_VIGNETTE_RANGE := 4.0   # G adicionales hasta el oscurecimiento maximo
const VIGNETTE_SIZE := 256      # lado de la textura de la vineta (px): es suave, no necesita mas
const VIGNETTE_OPEN := 1.8      # tamano de la vineta con pocas G (relativo a la pantalla): el borde oscuro queda fuera
const VIGNETTE_CLOSED := 0.9    # tamano con G maximas: el tunel se cierra dentro de la pantalla
const DEATH_DIM := 0.5          # oscurecimiento de la pantalla al ser derribado
const BAR_SMOOTH := 8.0         # rapidez con que una barra alcanza su valor (1/s): no salta al recibir dano
const HIT_BLINK_TIME := 0.25    # segundos que parpadea la barra de salud tras un impacto
const BLINK_FRAMES := 2         # fotogramas encendida y fotogramas apagada en un parpadeo rapido
const SHUTTER_TIME := 0.3       # segundos que tarda la persiana en abrirse (al empezar la partida) o cerrarse (al volver al hangar)

## Partes del HUD que se pueden apagar desde la pausa. La reticula (morro, cursor y arco de municion) no: hace falta para apuntar.
enum Part { TAPES, COMPASS, LADDER, DOLL, MARKERS, INFO, STATUS }

var g: Game
var parts_on: Array[bool] = [true, true, true, true, true, true, true]   # una por Part; todas visibles al empezar
var px_scale := 1               # pixeles de pantalla por unidad del diseno del HUD (lo fija HudView)
var k := 1.0                    # pixeles del lienzo por unidad del diseno (lo fija HudView); el lienzo es mas fino que el diseno
var font: FontFile
var reticle := AircraftReticle.new()   # nucleo de apuntado
var tapes := FlightTapes.new()         # cintas de velocidad y altitud
var compass := CompassTape.new()       # brujula
var ladder := PitchLadder.new()        # referencia de horizonte
var offscreen := OffscreenIndicator.new()  # flechas de enemigos y jugadores aliados fuera de pantalla
var inertia := HudInertia.new()        # desplazamiento elastico del HUD central
var doll := DamageDoll.new()           # silueta de dano por zonas
var health_shown := 1.0                # salud mostrada (0..1), suavizada
var _last_health := 1.0
var _hit_blink := 0.0                  # tiempo que queda de parpadeo tras un impacto
var _banner_t := 0.0                   # tiempo que le queda al cartel de ronda nueva
var _last_round := 0                   # ultima ronda vista: al cambiar sale el cartel
var _shutter_k := 0.0                  # cierre de la persiana: 0 = abierta, 1 = cerrada
var _shutter_goal := 0.0               # hacia donde se mueve la persiana
var vignette_tex: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = HudStyle.load_font()
	# vineta: degradado radial de transparente (centro) a negro (bordes)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 0.75, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6), Color(0, 0, 0, 1)])
	vignette_tex = GradientTexture2D.new()
	vignette_tex.gradient = grad
	vignette_tex.fill = GradientTexture2D.FILL_RADIAL
	vignette_tex.fill_from = Vector2(0.5, 0.5)
	vignette_tex.fill_to = Vector2(1.0, 0.5)
	vignette_tex.width = VIGNETTE_SIZE
	vignette_tex.height = VIGNETTE_SIZE

func _process(delta: float) -> void:
	size = get_viewport_rect().size
	_shutter_k = move_toward(_shutter_k, _shutter_goal, delta / SHUTTER_TIME)
	_banner_t = maxf(_banner_t - delta, 0.0)
	if g != null and g.ai.round_n != _last_round:
		_last_round = g.ai.round_n
		_banner_t = BANNER_TIME
	queue_redraw()

## Al empezar la partida la persiana del menu se abre: la pantalla estaba cerrada y se descubre en SHUTTER_TIME.
func open_shutter() -> void:
	_shutter_k = 1.0
	_shutter_goal = 0.0

## Cierra la persiana: transicion hacia el hangar tras ser derribado. shutter_closed() avisa de cuando ya cubre la pantalla.
func close_shutter() -> void:
	_shutter_goal = 1.0

func shutter_closed() -> bool:
	return _shutter_k >= 1.0

func _t(p: Vector2, s: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	HudStyle.text(self, font, p, s, sz, col, align, w)

## Muestra u oculta una parte del HUD.
func set_part(part: int, on: bool) -> void:
	parts_on[part] = on

## Tamano de la pantalla en unidades del diseno (el de "size" es en pixeles del lienzo, k veces mayor).
func design_size() -> Vector2:
	return size / k

## Posicion de pantalla (de la ventana, la que da la camara) en coordenadas del HUD virtual.
func to_hud(window_pos: Vector2) -> Vector2:
	return window_pos / float(px_scale)

## Posicion en el HUD de un punto del mundo si esta delante de la camara y dentro del margen de pantalla;
## si no, Vector2(INF, INF) (comprobar con is_finite).
func visible_point(world_pos: Vector3) -> Vector2:
	if g.cam.is_position_behind(world_pos):
		return Vector2(INF, INF)
	var p := to_hud(g.cam.unproject_position(world_pos))
	var edge := Rect2(Vector2(MARKER_EDGE, MARKER_EDGE), design_size() - Vector2(MARKER_EDGE, MARKER_EDGE) * 2.0)
	return p if edge.has_point(p) else Vector2(INF, INF)

## True durante la mitad apagada de un parpadeo rapido (BLINK_FRAMES fotogramas encendido y apagado).
func blink_off() -> bool:
	return HudStyle.blink_off(BLINK_FRAMES)

func _draw() -> void:
	if g == null or g.cam == null:
		return
	HudStyle.k = k   # las primitivas convierten unidades del diseno a pixeles del lienzo con esto; se deja en 1 al acabar
	var S := design_size()
	var C := S / 2.0
	if g.flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(HudStyle.ALERT, g.flash * 0.3))
	if not g.over:
		_draw_g_vignette(S, C)
		_draw_play(S)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, DEATH_DIM))
		_t(Vector2(0, C.y - 8.0), "DERRIBADO", TEXT_BIG, HudStyle.ALERT, HORIZONTAL_ALIGNMENT_CENTER, S.x)
		_t(Vector2(0, C.y + 8.0), "Derribos: %d" % g.score, TEXT_SMALL, HudStyle.PHOSPHOR, HORIZONTAL_ALIGNMENT_CENTER, S.x)
		_t(Vector2(0, C.y + 22.0), "Pulsa ENTER para volver al hangar", TEXT_SMALL, HudStyle.PHOSPHOR, HORIZONTAL_ALIGNMENT_CENTER, S.x)
		if g.upgrades_lost:
			_t(Vector2(0, C.y + 36.0), "Las mejoras de la tienda se han perdido", TEXT_SMALL, HudStyle.AMBER, HORIZONTAL_ALIGNMENT_CENTER, S.x)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))   # la persiana va en unidades del diseno, con sus pixeles gruesos de siempre
	HudStyle.shutter(self, S, _shutter_k, MilitaryStyle.AMBER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	HudStyle.k = 1.0

func _draw_play(S: Vector2) -> void:
	reticle.draw(self)
	if g.flight.stall_level > STALL_WARN:
		_t(Vector2(0, S.y * STALL_WARN_Y), "PERDIDA", TEXT_BIG, HudStyle.ALERT, HORIZONTAL_ALIGNMENT_CENTER, S.x)
	if parts_on[Part.MARKERS]:
		_draw_markers(g.ai.enemies, HudStyle.ALERT)
		_draw_markers(g.ai.allies, HudStyle.PHOSPHOR)
		_draw_pilots()
		offscreen.draw(self)
	if parts_on[Part.STATUS]:
		_draw_health(S)
		# municion: el nivel va en el arco junto al morro; aqui solo la cuenta, abajo a la derecha
		var ammo_text := "RECARGANDO" if g.weapons.reloading else "%d/%d" % [g.weapons.ammo, g.player_spec.mag_size]
		_t(Vector2(S.x - MARGIN - BAR_W, S.y - MARGIN), ammo_text, TEXT_SMALL, HudStyle.PHOSPHOR, HORIZONTAL_ALIGNMENT_RIGHT, BAR_W)
	if parts_on[Part.DOLL]:
		doll.draw(self)
	if parts_on[Part.INFO]:
		_t(Vector2(MARGIN, MARGIN + TEXT_SMALL), "DERRIBOS %d  CREDITOS %d" % [g.score, g.credits], TEXT_SMALL, HudStyle.PHOSPHOR)
		_draw_round(S)
		_draw_roster()
	# el HUD central (no el que va pegado al mundo 3D) se desplaza con el giro y las G
	draw_set_transform((inertia.update(g, get_process_delta_time()) * k).round(), 0.0, Vector2.ONE)   # el desplazamiento es en unidades: se pasa a pixeles del lienzo
	if parts_on[Part.LADDER]:
		ladder.draw(self)
	if parts_on[Part.TAPES]:
		tapes.draw(self)
	if parts_on[Part.COMPASS]:
		compass.draw(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Salud: barra fina abajo a la izquierda, suavizada; tras un impacto parpadea en rojo unos fotogramas.
func _draw_health(S: Vector2) -> void:
	var delta := get_process_delta_time()
	var h: float = clampf(g.health / g.max_health, 0.0, 1.0)
	if h < _last_health:
		_hit_blink = HIT_BLINK_TIME
	_last_health = h
	_hit_blink = maxf(_hit_blink - delta, 0.0)
	health_shown = lerpf(health_shown, h, 1.0 - exp(-delta * BAR_SMOOTH))
	if _hit_blink > 0.0 and blink_off():
		return
	var col := HudStyle.ALERT if _hit_blink > 0.0 or h < BAR_LOW else HudStyle.PHOSPHOR
	_t(Vector2(MARGIN, S.y - MARGIN - BAR_H - 3.0), "SALUD", TEXT_SMALL, col)
	HudStyle.bar(self, Rect2(MARGIN, S.y - MARGIN - BAR_H, BAR_W, BAR_H), health_shown, col)

## Marcadores de una lista de aviones que estan en pantalla: corchetes con la distancia.
## Los que estan fuera de pantalla (enemigos y jugadores) los marca OffscreenIndicator.
func _draw_markers(planes: Array[AiPlanes.AiPlane], col: Color) -> void:
	for e in planes:
		if not e.dead:
			_draw_marker(e.root.position, col, "%d m" % int(e.root.position.distance_to(g.plane.position)))

## Marcadores de los demas jugadores: corchetes con nombre y distancia, y un rombo encima para distinguirlos de la IA aliada.
func _draw_pilots() -> void:
	for id in g.pilots.pilots:
		var p: RemotePilots.Pilot = g.pilots.pilots[id]
		if p.root != null and p.root.visible:
			_draw_marker(p.root.position, HudStyle.PHOSPHOR, "%s %d m" % [g.pilots.pilot_name(id), int(p.root.position.distance_to(g.plane.position))])
			var at := visible_point(p.root.position)
			if at.is_finite():   # rombo sobre los corchetes: distingue a un jugador de la IA aliada
				HudStyle.diamond(self, at + Vector2(0.0, -MARKER_R - PLAYER_DIAMOND_GAP), PLAYER_DIAMOND_R, HudStyle.PHOSPHOR)

## Ronda en curso y enemigos que quedan; en la pausa entre rondas, un cartel con la cuenta atras, y al empezar una, su numero.
func _draw_round(S: Vector2) -> void:
	var ai := g.ai
	var line := "RONDA %d  QUEDAN %d" % [ai.round_n, ai.remaining] if not ai.between else "RONDA %d" % ai.round_n
	if ai.round_n > 0:
		_t(Vector2(MARGIN, MARGIN + TEXT_SMALL + LINE_H), line, TEXT_SMALL, HudStyle.PHOSPHOR)
	var y := S.y * BANNER_Y
	if ai.between:
		if ai.round_n > 0:
			_t(Vector2(0, y), "RONDA %d COMPLETADA" % ai.round_n, TEXT_BIG, HudStyle.AMBER, HORIZONTAL_ALIGNMENT_CENTER, S.x)
			y += TEXT_BIG + LINE_H
		_t(Vector2(0, y), "RONDA %d EN %d S" % [ai.round_n + 1, ceili(ai.round_cd)], TEXT_SMALL, HudStyle.PHOSPHOR, HORIZONTAL_ALIGNMENT_CENTER, S.x)
	elif _banner_t > 0.0:
		_t(Vector2(0, y), "RONDA %d" % ai.round_n, TEXT_BIG, HudStyle.PHOSPHOR, HORIZONTAL_ALIGNMENT_CENTER, S.x)

## Lista de pilotos de la partida en red: nombre y si vuelan o estan en base (hangar o derribados).
func _draw_roster() -> void:
	if not g.net.is_online():
		return
	var y := MARGIN + TEXT_SMALL + LINE_H * 2.0   # bajo DERRIBOS y la linea de la ronda
	for id in g.net.roster:
		var pid: int = id
		var flying := not g.over
		if pid != g.net.my_id():
			var pilot: RemotePilots.Pilot = g.pilots.pilots.get(pid)
			flying = pilot != null and pilot.alive
		var col := HudStyle.PHOSPHOR if flying else HudStyle.PHOSPHOR.darkened(ROSTER_DIM)
		_t(Vector2(MARGIN, y), "%s  %s" % [g.net.roster[pid], "VUELA" if flying else "EN BASE"], TEXT_SMALL, col)
		y += LINE_H

## Corchetes con un texto debajo sobre un punto del mundo, si esta en pantalla.
func _draw_marker(wp: Vector3, col: Color, label: String) -> void:
	var p := visible_point(wp)
	if not p.is_finite():
		return
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c: Vector2 = p + s * MARKER_R
		HudStyle.line(self, c, c - Vector2(s.x * MARKER_TICK, 0), col)
		HudStyle.line(self, c, c - Vector2(0, s.y * MARKER_TICK), col)
	_t(Vector2(p.x - MARKER_LABEL_W * 0.5, p.y + MARKER_R + LINE_H), label, TEXT_SMALL, col, HORIZONTAL_ALIGNMENT_CENTER, MARKER_LABEL_W)

## Vineta de G altas: los bordes se oscurecen y el tunel se cierra hacia el centro.
func _draw_g_vignette(S: Vector2, C: Vector2) -> void:
	var strength: float = clampf((g.g_force - G_VIGNETTE_START) / G_VIGNETTE_RANGE, 0.0, 1.0)
	if strength <= 0.0:
		return
	var sz: Vector2 = S * lerpf(VIGNETTE_OPEN, VIGNETTE_CLOSED, strength)
	var alpha := minf(strength * 2.0, 1.0)
	var tex_rect := Rect2(C - sz * 0.5, sz)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))   # la vineta es suave: se dibuja en unidades del diseno
	draw_texture_rect(vignette_tex, tex_rect, false, Color(1, 1, 1, alpha))
	# si la textura queda mas pequena que la pantalla, el resto se rellena de negro
	var black := Color(0, 0, 0, alpha)
	var screen := Rect2(Vector2.ZERO, S)
	for r in [
		Rect2(0, 0, S.x, tex_rect.position.y),
		Rect2(0, tex_rect.end.y, S.x, S.y - tex_rect.end.y),
		Rect2(0, tex_rect.position.y, tex_rect.position.x, tex_rect.size.y),
		Rect2(tex_rect.end.x, tex_rect.position.y, S.x - tex_rect.end.x, tex_rect.size.y)]:
		var fill: Rect2 = r
		if fill.size.x > 0.0 and fill.size.y > 0.0:
			draw_rect(fill.intersection(screen), black)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
