## Red: anfitrion o cliente por ENet, lista de pilotos conectados y avisos de conexion.
## El anfitrion (id 1) manda sobre la batalla; los clientes se registran con su nombre al conectar.
class_name Net
extends Node

const PORT := 24680              # puerto de la partida
const MAX_PLAYERS := 4           # jugadores a la vez, el anfitrion incluido
const HOST_ID := 1               # id del anfitrion en el multijugador de Godot
const MAX_PORT := 65535          # puerto UDP mas alto valido
const JOIN_TIMEOUT := 8.0        # segundos que se espera la respuesta del anfitrion antes de dar la conexion por fallida

signal roster_changed            # cambia la lista de pilotos
signal joined                    # el cliente se ha conectado y registrado en el anfitrion
signal join_failed               # no se pudo conectar al anfitrion
signal link_lost                 # el cliente pierde al anfitrion
signal port_opened(ok: bool, public_ip: String)   # resultado de abrir el puerto en el router por UPnP

var my_name := "Piloto"
var roster := {}                 # id de jugador -> nombre
var _upnp: UPNP                  # router con el puerto abierto (null si no se abrio)
var _thread: Thread              # hilo que busca el router: tarda unos segundos y no debe parar el juego
var _join_id := 0                # numero del ultimo intento de union: un temporizador viejo no corta uno nuevo
var _joining := false            # true = esperando la respuesta del anfitrion

## True si hay una partida en red (anfitrion o cliente); false si se juega solo.
func is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer

## True si este equipo manda sobre la batalla: el anfitrion, o jugando solo.
func is_authority() -> bool:
	return not is_online() or multiplayer.is_server()

## Id de este jugador (1 si juega solo).
func my_id() -> int:
	return multiplayer.get_unique_id()

## Abre una partida: los demas se unen a esta IP y al puerto PORT.
func host(player_name: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	my_name = player_name
	multiplayer.multiplayer_peer = peer
	roster = {HOST_ID: my_name}
	_listen()
	roster_changed.emit()
	return OK

## Se une a la partida del anfitrion. "address" es una IP o nombre, con puerto opcional ("1.2.3.4:5000": lo da un tunel);
## sin puerto se usa PORT. El resultado llega con las senales joined o join_failed.
func join(address: String, player_name: String) -> Error:
	var host := address.strip_edges()
	var port := PORT
	var colon := host.rfind(":")
	if colon > 0 and host.substr(colon + 1).is_valid_int():
		port = host.substr(colon + 1).to_int()
		host = host.substr(0, colon)
	if host.is_empty() or port < 1 or port > MAX_PORT:
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		return err
	my_name = player_name
	multiplayer.multiplayer_peer = peer
	_listen()
	_join_id += 1
	_joining = true
	get_tree().create_timer(JOIN_TIMEOUT).timeout.connect(_on_join_timeout.bind(_join_id))
	return OK

func _on_join_timeout(id: int) -> void:
	if _joining and id == _join_id:
		_on_connection_failed()

## Intenta abrir el puerto de la partida en el router por UPnP (para jugar por internet sin tocar el router).
## Lo hace en un hilo; el resultado llega con la senal port_opened.
func open_port() -> void:
	if _thread != null:
		return
	_thread = Thread.new()
	_thread.start(_search_router)

func _search_router() -> void:
	var upnp := UPNP.new()
	var ok := false
	var ip := ""
	if upnp.discover() == UPNP.UPNP_RESULT_SUCCESS:
		var gateway := upnp.get_gateway()
		if gateway != null and gateway.is_valid_gateway():
			ok = upnp.add_port_mapping(PORT, PORT, "Combate aereo", "UDP") == UPNP.UPNP_RESULT_SUCCESS
			ip = upnp.query_external_address()
	_port_result.call_deferred(upnp, ok, ip)

func _port_result(upnp: UPNP, ok: bool, ip: String) -> void:
	_thread.wait_to_finish()
	_thread = null
	_upnp = upnp if ok else null
	port_opened.emit(ok, ip)

## Cierra el puerto abierto en el router, si se abrio.
func _close_port() -> void:
	if _upnp != null:
		_upnp.delete_port_mapping(PORT, "UDP")
		_upnp = null

func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
	_close_port()

## Cierra la conexion y vuelve a jugar solo.
func leave() -> void:
	_close_port()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	roster.clear()

func _listen() -> void:
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		return
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connected() -> void:
	_joining = false
	_register.rpc_id(HOST_ID, my_name)
	joined.emit()

func _on_connection_failed() -> void:
	_joining = false
	leave()
	join_failed.emit()

func _on_server_disconnected() -> void:
	leave()
	link_lost.emit()

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	roster.erase(id)
	_sync_roster.rpc(roster)
	roster_changed.emit()

## Un cliente da su nombre al anfitrion, que anota al piloto y reparte la lista nueva.
@rpc("any_peer", "call_remote", "reliable")
func _register(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	roster[multiplayer.get_remote_sender_id()] = player_name
	_sync_roster.rpc(roster)
	roster_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _sync_roster(new_roster: Dictionary) -> void:
	roster = new_roster
	roster_changed.emit()
