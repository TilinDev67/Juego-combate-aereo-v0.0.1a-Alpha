## Aviones que el jugador puede elegir en el menu. Las cifras se basan en sus contrapartes reales
## (velocidad a baja altura, velocidad de perdida, armamento y blindaje) llevadas a la escala del juego.
class_name PlaneModels
extends RefCounted

const IL2 := 0
const BF109 := 1
const SPITFIRE := 2
const P51 := 3
const ZERO := 4
const STUKA := 5
const FW190 := 6

const KMH := 1.0 / 3.6           # de km/h a m/s
const HEALTH_BAR_MAX := 220.0    # salud que llena la barra de blindaje del menu
const AGILITY_BAR_MAX := 1.4     # agilidad que llena la barra del menu
const SPEED_BAR_MAX := 165.0     # velocidad maxima (m/s) que llena la barra del menu
const FIREPOWER_BAR_MAX := 140.0 # potencia de fuego (dano por segundo) que llena la barra del menu
const STALL_BEST := 30.0         # velocidad de perdida (m/s) con la que la barra de estabilidad esta llena
const STALL_WORST := 50.0        # velocidad de perdida (m/s) con la que la barra de estabilidad esta vacia

class Spec:
	var id := 0
	var title := ""
	var short := ""                  # nombre corto para la lista del menu
	var role := ""                   # clase o papel del avion, en pocas palabras
	var country := ""                # pais del avion: decide su musica (ussr, germany, uk, usa, japan)
	var model := ""                  # ficha del modelo en aviones.json
	var desc := ""                   # armamento y caracter, en una linea
	var health := 100.0
	var agility := 1.0               # multiplicador de la autoridad de los mandos
	var max_speed := 115.0           # velocidad maxima en vuelo recto a todo gas (m/s)
	var stall_speed := 45.0          # por debajo pierde sustentacion (m/s)
	var wing_tip := Vector3.ZERO     # punta del ala derecha respecto al avion (m)
	var box_half := Vector3.ONE      # caja de impactos (semiejes) y su centro, en ejes del avion
	var box_center := Vector3.ZERO
	var mag_size := 120              # descargas antes de recargar
	var cannon_guns := 0             # canones: 0 = sin, 1 = en el eje, 2 = uno por ala (disparan a la vez)
	var cannon_rate := 0.0           # descargas por segundo
	var cannon_dmg := 0.0            # dano de un proyectil a corta distancia
	var cannon_x := 0.0              # separacion lateral de los canones respecto al eje (m)
	var mg_guns := 0                 # ametralladoras: 0 = sin, 1 = en el eje, 2 = alternan entre las alas
	var mg_rate := 0.0               # disparos por segundo
	var mg_dmg := 0.0
	var mg_x := 0.0

	## Codigo de modelo de la ficha, al estilo de un numero de serie.
	func code() -> String:
		return "AC-%02d" % (id + 1)

	## Dano por segundo a corta distancia: los canones disparan a la vez; las ametralladoras alternan, asi que no se multiplican.
	func firepower() -> float:
		return cannon_guns * cannon_rate * cannon_dmg + (mg_rate * mg_dmg if mg_guns > 0 else 0.0)

static func _spec(d: Dictionary) -> Spec:
	var s := Spec.new()
	for key in d:
		s.set(key, d[key])
	# punta del ala y caja de impactos salen de la ficha del modelo
	var card := VoxModels.info(s.model)
	s.wing_tip = Vector3(card["wing_tip"][0], card["wing_tip"][1], card["wing_tip"][2])
	s.box_half = Vector3(card["box_half"][0], card["box_half"][1], card["box_half"][2])
	s.box_center = Vector3(card["box_center"][0], card["box_center"][1], card["box_center"][2])
	return s

## Lista de aviones elegibles, en el orden del menu.
static func all() -> Array[Spec]:
	var list: Array[Spec] = []
	list.append(_spec({
		"id": IL2, "country": "ussr", "role": "ATAQUE", "model": "Il-2", "title": "IL-2 Sturmovik", "short": "IL-2",
		"desc": "Avion de ataque blindado. 2 canones VYa-23 de 23 mm y 2 ametralladoras ShKAS.",
		"health": 140.0, "agility": 1.0, "max_speed": 414.0 * KMH, "stall_speed": 162.0 * KMH,
		"mag_size": 120, "cannon_guns": 2, "cannon_rate": 8.0, "cannon_dmg": 6.0, "cannon_x": 2.8,
		"mg_guns": 2, "mg_rate": 24.0, "mg_dmg": 1.2, "mg_x": 1.6}))
	list.append(_spec({
		"id": BF109, "country": "germany", "role": "CAZA", "model": "Bf109", "title": "Messerschmitt Bf 109 G-6", "short": "Bf 109 G-6",
		"desc": "Caza aleman rapido. 1 canon MK 108 de 30 mm en el eje (potente, de poca cadencia) y 2 MG 131.",
		"health": 85.0, "agility": 1.15, "max_speed": 530.0 * KMH, "stall_speed": 140.0 * KMH,
		"mag_size": 80, "cannon_guns": 1, "cannon_rate": 6.0, "cannon_dmg": 12.0, "cannon_x": 0.0,
		"mg_guns": 2, "mg_rate": 22.0, "mg_dmg": 1.8, "mg_x": 0.6}))
	list.append(_spec({
		"id": SPITFIRE, "country": "uk", "role": "CAZA LIGERO", "model": "Spitfire", "title": "Supermarine Spitfire Mk V", "short": "Spitfire Mk V",
		"desc": "Caza britanico muy manejable. 2 canones Hispano de 20 mm y 4 ametralladoras Browning de .303.",
		"health": 80.0, "agility": 1.25, "max_speed": 500.0 * KMH, "stall_speed": 130.0 * KMH,
		"mag_size": 120, "cannon_guns": 2, "cannon_rate": 8.0, "cannon_dmg": 5.0, "cannon_x": 2.4,
		"mg_guns": 2, "mg_rate": 30.0, "mg_dmg": 0.9, "mg_x": 3.4}))
	list.append(_spec({
		"id": P51, "country": "usa", "role": "ESCOLTA", "model": "P51", "title": "North American P-51D Mustang", "short": "P-51D Mustang",
		"desc": "Caza americano veloz y de largo alcance. 6 ametralladoras Browning de .50, sin canones.",
		"health": 95.0, "agility": 1.05, "max_speed": 580.0 * KMH, "stall_speed": 150.0 * KMH,
		"mag_size": 600, "cannon_guns": 0,
		"mg_guns": 2, "mg_rate": 45.0, "mg_dmg": 1.9, "mg_x": 2.6}))
	list.append(_spec({
		"id": ZERO, "country": "japan", "role": "CAZA AGIL", "model": "Zero", "title": "Mitsubishi A6M2 Zero", "short": "A6M2 Zero",
		"desc": "Caza japones agilisimo pero sin blindaje. 2 canones Type 99 de 20 mm y 2 ametralladoras de 7,7 mm.",
		"health": 55.0, "agility": 1.35, "max_speed": 510.0 * KMH, "stall_speed": 120.0 * KMH,
		"mag_size": 60, "cannon_guns": 2, "cannon_rate": 6.0, "cannon_dmg": 5.0, "cannon_x": 2.4,
		"mg_guns": 2, "mg_rate": 24.0, "mg_dmg": 1.0, "mg_x": 0.5}))
	list.append(_spec({
		"id": STUKA, "country": "germany", "role": "ANTITANQUE", "model": "Stuka", "title": "Junkers Ju 87 G Stuka", "short": "Ju 87 G Stuka",
		"desc": "Cazatanques lento y robusto. 2 canones BK 37 de 37 mm bajo las alas: pocos disparos, enorme dano.",
		"health": 110.0, "agility": 0.8, "max_speed": 380.0 * KMH, "stall_speed": 135.0 * KMH,
		"mag_size": 24, "cannon_guns": 2, "cannon_rate": 2.2, "cannon_dmg": 25.0, "cannon_x": 3.5,
		"mg_guns": 0}))
	list.append(_spec({
		"id": FW190, "country": "germany", "role": "CAZA PESADO", "model": "Fw190", "title": "Focke-Wulf Fw 190 A-8", "short": "Fw 190 A-8",
		"desc": "Caza aleman de motor radial, robusto y muy armado. 2 canones MG 151 de 20 mm y 2 MG 131 de 13 mm.",
		"health": 105.0, "agility": 1.1, "max_speed": 560.0 * KMH, "stall_speed": 150.0 * KMH,
		"mag_size": 120, "cannon_guns": 2, "cannon_rate": 8.0, "cannon_dmg": 5.5, "cannon_x": 3.0,
		"mg_guns": 2, "mg_rate": 22.0, "mg_dmg": 1.8, "mg_x": 0.6}))
	return list

## Construye el nodo del avion; enemy = con las marcas rojas de los enemigos (solo los modelos que las tienen);
## controls = con las superficies de mando animables (alerones y timones), solo para el avion del jugador.
static func build(spec: Spec, vox: VoxModels, enemy: bool = false, controls: bool = false) -> Node3D:
	return vox.make_model(spec.model + ("_enemigo" if enemy else ""), controls)
