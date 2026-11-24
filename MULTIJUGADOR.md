# Multijugador cooperativo (en construccion)

Diseno: cooperativo contra la IA, anfitrion por IP (ENet), 2 a 4 jugadores. El anfitrion (id 1) manda sobre la IA y
los derribos; cada jugador controla su avion y lo envia ~20 veces por segundo. Todo esta SIN PROBAR en el motor.

## Pasos
1. Red y lobby (hecho, sin probar): `net.gd` (conexion, lista de pilotos), `lobby.gd` (pantalla previa al hangar), `main.gd`.
2. Otros jugadores (hecho, sin probar): `remote_pilots.gd` envia el estado del avion 20 veces por segundo y dibuja los aviones de los demas con su modelo, suavizados, y `hud.gd` les pone marcador con nombre y distancia. Solo se ven; aun no se les puede disparar.
3. Disparos (hecho, sin probar): cada disparo del jugador se envia (`RemotePilots.send_shot`) y los demas ven la bala y oyen el canon. Transitorio: esas balas aun NO danan, porque cada equipo lleva su propia IA hasta el paso 4; alli el anfitrion aplicara el dano de todas las balas aliadas.
4. IA en red (hecho, sin probar): la IA solo corre en el anfitrion (`ai_planes.gd`), que manda su estado 15 veces por segundo (`_snapshot`); los clientes crean y dibujan los aviones de la IA suavizados. Los clientes avisan de sus impactos con `request_hit` y el anfitrion aplica el dano. El anfitrion sigue simulando la batalla aunque este en el hangar si otro jugador vuela.
5. Muerte y lista de pilotos (hecho, sin probar): los demas ven la explosion de un jugador derribado (`announce_death`), el HUD lista a los pilotos (VUELA / EN BASE) y, en red, la batalla sigue aunque tu avion este derribado. La entrada a mitad de batalla y la reaparicion salieron en los pasos anteriores.

## Como probar el paso 1 (dos ventanas en el mismo PC)
1. Godot: Depurar > Ejecutar varias instancias > 2 instancias.
2. Ventana 1: "Ser anfitrion". Ventana 2: IP 127.0.0.1 y "Unirse". La 2 pasa al hangar; la 1 muestra el piloto en la lista y "Continuar al hangar".
3. Cierra la ventana 1: la 2 debe volver al lobby con el aviso de conexion perdida.
Para jugar con otro equipo: la IP de la red local que muestra el anfitrion y el puerto UDP 24680 abierto (por internet, abrirlo en el router o usar una VPN).

## Como probar el paso 2
Con 2 instancias unidas (ver arriba), cada una elige un avion y lanza. Cada ventana debe ver el avion de la otra con su modelo y un marcador
con el nombre y la distancia; al volar, el avion remoto se mueve suave. Si una vuelve al hangar o la derriban, desaparece en la otra.
En ambas la IA es independiente (cada una la corre por su cuenta) hasta el paso 4.

## Como probar el paso 3
Con 2 instancias en vuelo, dispara en una: la otra debe ver las trazadoras salir del avion remoto (y oir el canon si es de canon).
Las balas remotas atraviesan a los enemigos (es lo esperado hasta el paso 4). Tus propios disparos siguen danando a tu IA como antes.

## Como probar el paso 4
1. Anfitrion en vuelo y cliente en vuelo: los dos deben ver los MISMOS enemigos y el mismo aliado, en el mismo sitio, y los derribos deben coincidir (marcador compartido).
2. El cliente dispara a un enemigo: debe verse el impacto al instante y el enemigo debe perder salud/caer tambien en el anfitrion.
3. Los enemigos deben atacar al jugador mas cercano (a veces al anfitrion, a veces al cliente). Las balas enemigas se ven en ambos; cada uno solo recibe dano de las que le dan a su avion.
4. El anfitrion vuelve al hangar con el cliente en vuelo: la batalla del cliente no debe pararse.
5. Un cliente que entra con la batalla en curso reaparece lejos de los enemigos (como tras morir) y no reinicia nada.

## Como probar el paso 5
1. Deja que un enemigo derribe al cliente: el anfitrion debe ver una explosion donde estaba, y la lista del HUD debe poner al cliente en EN BASE mientras no vuela.
2. Con el cliente derribado, el anfitrion debe seguir con la batalla (la IA no se para). Si el que muere es el anfitrion, el cliente tambien debe seguir con la suya.
3. El cliente pulsa Enter, elige otro avion y vuelve: reaparece lejos de los enemigos y el anfitrion lo ve de nuevo con el modelo nuevo.
4. Cierra el cliente: el anfitrion lo quita de la lista y su avion desaparece. Cierra el anfitrion: el cliente vuelve al lobby con el aviso.

## Limitaciones y que se hizo con ellas
- Latencia: los aviones remotos y la IA de los clientes se dibujan unos 100 y 150 ms en el pasado, interpolando entre los dos ultimos estados (`net_interp.gd`) en vez de saltar al ultimo; si falta uno nuevo se extrapola hasta 0,25 s. Es la tecnica estandar; el avion propio no tiene retraso.
- Trampas: el anfitrion ya no se fia ciegamente de los avisos de impacto de un cliente: `RemotePilots.accept_hit` rechaza al que no vuela, danos mayores que los de sus armas (salvo embestida a menos de 60 m), impactos a mas de ~2300 m y mas impactos por segundo que su cadencia. No es a prueba de tramposos decididos (el cliente sigue decidiendo si acierta), pero frena lo burdo.
- Internet: el anfitrion intenta abrir el puerto UDP 24680 por UPnP al abrir la partida (`Net.open_port`) y muestra su IP publica; si el router no lo permite, avisa de que hay que abrirlo a mano o usar una VPN.
- Sigue sin resolverse: si el anfitrion se cae, la batalla se pierde y los clientes vuelven al lobby (haria falta migracion de anfitrion, que es un cambio mucho mayor). Todo el multijugador esta sin probar en el motor.

## Jugar por internet con un tunel (sin VPN ni abrir el router)
El anfitrion crea un tunel UDP hacia el puerto 24680 de su PC con un servicio como playit.gg (instala su programa, crea un tunel UDP al puerto
local 24680 y obtiene una direccion publica tipo `algo.gl.at.ply.gg:12345`). Los demas la escriben tal cual en "Direccion del anfitrion" (`direccion:puerto`)
y pulsan Unirse. El anfitrion abre su partida normalmente ("Ser anfitrion"). Depende de un tercero: puede anadir latencia o tener limites.

## Abrir el firewall (anfitrion)
`herramientas/abrir_firewall.ps1` crea en Windows una regla de entrada para el puerto UDP 24680 (pide permisos de administrador). Se ejecuta con clic derecho >
"Ejecutar con PowerShell". Para quitarla: `powershell -ExecutionPolicy Bypass -File herramientasbrir_firewall.ps1 -Quitar`.
