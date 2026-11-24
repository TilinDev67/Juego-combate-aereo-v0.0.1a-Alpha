## Pilotos de los demas jugadores: aviones sincronizados por red, con su modelo y su nombre.
## Cada equipo envia el estado de su avion unas SYNC_RATE veces por segundo; los demas lo dibujan interpolado (NetInterp).
## El anfitrion tambien valida los impactos que le avisan los clientes (accept_hit).
class_name RemotePilots
extends Node

const SYNC_RATE := 20.0          # envios de estado por segundo
const INTERP_DELAY := 0.1        # segundos en el pasado a los que se dibuja un avion remoto (dos intervalos de envio)
const PROP_SPIN := 35.0          # giro de la helice de un avion remoto (rad/s)
const PLAYER_EXPLOSION_SCALE := 3.0  # tamano de la explosion de un jugador derribado (la misma que ve el propio jugador)
const HIT_RANGE := 2300.0        # distancia maxima (m) de un impacto valido: lo que recorre una bala (1100 m/s x 1,8 s) mas el margen de la latencia
const RAM_RANGE := 60.0          # distancia maxima (m) de una embestida (dano por encima del de una bala)
const HIT_DMG_MARGIN := 1.5      # margen sobre el dano maximo de las armas del avion del jugador (cubre las mejoras de la tienda: hasta +35 %)
const HIT_RATE_MARGIN := 2.0     # margen sobre la cadencia de las armas: impactos por segundo que se aceptan (cubre la mejora de cadencia, hasta +35 %)
const HIT_BUDGET_MAX := 6.0      # impactos que se aceptan de golpe tras un rato sin disparar

## Un piloto remoto: su avion en esta escena y lo ultimo que se supo de el.
class Pilot:
	var model_idx := -1          # modelo elegido (indice en Game.models)
	var alive := false           # false = en el hangar o derribado: no se ve
	var root: Node3D
	var prop: Node3D
	var interp: NetInterp        # estados recibidos, para dibujarlo suave
	var target_pos := Vector3.ZERO   # ultimo estado recibido (lo usa la IA para apuntar)
	var target_rot := Quaternion.IDENTITY
	var speed := 0.0
	var hit_budget := 0.0        # impactos que aun se le aceptan (se recarga con el tiempo)
	var hit_stamp := 0.0         # instante del ultimo calculo de hit_budget

var g: Game
var net: Net
var pilots := {}                 # id de jugador -> Pilot
var _send_cd := 0.0

func _ready() -> void:
	net.roster_changed.connect(_prune)

## True si algun otro jugador esta en vuelo (y por tanto hay una batalla en curso).
func any_alive() -> bool:
	for id in pilots:
		var p: Pilot = pilots[id]
		if p.alive and p.root != null:
			return true
	return false

## Nombre del piloto con ese id.
func pilot_name(id: int) -> String:
	return str(net.roster.get(id, "?"))

func _physics_process(delta: float) -> void:
	if not net.is_online() or g.plane == null:
		return
	_send_cd -= delta
	if _send_cd > 0.0:
		return
	_send_cd = 1.0 / SYNC_RATE
	var alive := not g.menu_open and not g.over
	_state.rpc(g.models.find(g.player_spec), alive, g.plane.position, g.plane.transform.basis.get_rotation_quaternion(), g.speed)

## Estado del avion de otro jugador. Se envia sin garantias: si se pierde uno, llega el siguiente.
@rpc("any_peer", "call_remote", "unreliable")
func _state(model_idx: int, alive: bool, pos: Vector3, rot: Quaternion, spd: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not net.roster.has(id):
		return   # aun no se conoce al piloto (la lista llega aparte) o ya se fue
	var p: Pilot = pilots.get(id)
	if p == null:
		p = Pilot.new()
		p.interp = NetInterp.new(INTERP_DELAY)
		p.hit_budget = HIT_BUDGET_MAX
		pilots[id] = p
	if model_idx != p.model_idx:
		_build(p, model_idx)
	if p.root == null:
		return
	if alive and not p.alive:
		p.interp.clear()   # acaba de aparecer: no hay que interpolar desde donde estaba antes
	p.alive = alive
	p.target_pos = pos
	p.target_rot = rot
	p.speed = spd
	p.interp.add(Time.get_ticks_msec() / 1000.0, pos, rot, -Basis(rot).z * spd)

func _build(p: Pilot, model_idx: int) -> void:
	if model_idx < 0 or model_idx >= g.models.size():
		return
	if p.root != null:
		p.root.queue_free()
	p.model_idx = model_idx
	p.root = PlaneModels.build(g.models[model_idx], g.vox)
	p.prop = p.root.get_node("Model/Prop")
	p.root.visible = false
	add_child(p.root)

func _process(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for id in pilots:
		var p: Pilot = pilots[id]
		if p.root == null:
			continue
		p.root.visible = p.alive and not g.menu_open and not p.interp.is_empty()   # en el hangar no se ve la batalla
		if not p.root.visible:
			continue
		p.root.transform = p.interp.sample(now)
		p.prop.rotation.z += PROP_SPIN * delta

## Solo el anfitrion: decide si acepta el aviso de impacto de un cliente sobre un avion de la IA en esa posicion.
## Rechaza al que no vuela, a un dano mayor que el de sus armas (salvo una embestida a quemarropa), a uno lejos
## del alcance de una bala y a mas impactos por segundo de los que sus armas pueden disparar.
func accept_hit(sender: int, target_pos: Vector3, dmg: float) -> bool:
	var p: Pilot = pilots.get(sender)
	if p == null or not p.alive or p.model_idx < 0:
		return false
	var spec: PlaneModels.Spec = g.models[p.model_idx]
	var dist := p.target_pos.distance_to(target_pos)
	if dmg > maxf(spec.cannon_dmg, spec.mg_dmg) * HIT_DMG_MARGIN:
		return dist < RAM_RANGE
	if dist > HIT_RANGE:
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	var rate: float = (spec.cannon_rate * spec.cannon_guns + spec.mg_rate * spec.mg_guns) * HIT_RATE_MARGIN
	p.hit_budget = minf(p.hit_budget + (now - p.hit_stamp) * rate, HIT_BUDGET_MAX)
	p.hit_stamp = now
	if p.hit_budget < 1.0:
		return false
	p.hit_budget -= 1.0
	return true

## Avisa a los demas de un disparo del jugador para que lo vean.
func send_shot(pos: Vector3, vel: Vector3, heavy: bool) -> void:
	if net.is_online():
		_shot.rpc(pos, vel, heavy)

## Disparo de otro jugador: se dibuja la bala y, si es de canon, se oye. No dana (ver Weapons.Bullet.remote).
@rpc("any_peer", "call_remote", "unreliable")
func _shot(pos: Vector3, vel: Vector3, heavy: bool) -> void:
	if g.menu_open or not net.roster.has(multiplayer.get_remote_sender_id()):
		return
	g.weapons.spawn_bullet(pos, vel, true, 0.0, heavy, false, true)
	var pilot: Pilot = pilots.get(multiplayer.get_remote_sender_id())
	if pilot != null and pilot.alive:   # el fogonazo cuelga de su avion para que lo siga durante el instante que dura
		g.fx.muzzle_flash(pilot.root, pilot.root.to_local(pos), 1.0 if heavy else Weapons.MG_FLASH_SCALE)
	if heavy:
		g.sound.play_bank_3d(g.sound.bank_cannon, pos, AiPlanes.ENEMY_GUN_DB, g.sound.limit_gun)

## Avisa a los demas de que este jugador ha sido derribado, para que vean la explosion.
func announce_death(pos: Vector3, vel: Vector3) -> void:
	if net.is_online():
		_died.rpc(pos, vel)

@rpc("any_peer", "call_remote", "reliable")
func _died(pos: Vector3, vel: Vector3) -> void:
	if g.menu_open or not net.roster.has(multiplayer.get_remote_sender_id()):
		return
	g.fx.explode(pos, PLAYER_EXPLOSION_SCALE, vel)
	g.sound.play_explosion(pos, PLAYER_EXPLOSION_SCALE)

## Quita los pilotos que ya no estan en la lista de la partida.
func _prune() -> void:
	for id in pilots.keys():
		if not net.roster.has(id):
			var p: Pilot = pilots[id]
			if p.root != null:
				p.root.queue_free()
			pilots.erase(id)
