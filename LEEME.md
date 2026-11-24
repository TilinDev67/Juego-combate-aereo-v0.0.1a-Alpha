# Juego de aviones (combate aereo con voxeles)

Juego de combate aereo 3D hecho con Godot 4.7 (GDScript). Cooperativo contra la IA, solo o por red (2 a 4 jugadores).

## Como abrirlo
1. Instala Godot 4.7 (https://godotengine.org) y abre esta carpeta como proyecto (archivo `project.godot`).
2. La primera vez Godot importa los recursos (un momento). Pulsa F5 para jugar.

## Controles
- Raton: mover el punto de mira; el avion gira hacia el. Clic izquierdo o Espacio: disparar. R: recargar.
- Shift / Ctrl: acelerar / frenar. W/S/A/D/Q/E: ajuste manual. Clic derecho (mantener): zoom. C o clic central: mirada libre.
- Enter (derribado): volver al hangar y elegir avion. M: volver al hangar en vuelo. Esc: pausa con opciones de graficos y volumen de sonidos.

## Multijugador
En la primera pantalla: "Jugar solo", "Ser anfitrion" o "Unirse" (con la IP del anfitrion). Puerto UDP 24680.
Detalles y como probarlo con dos ventanas: `MULTIJUGADOR.md`. Esta sin probar en el motor: pueden salir errores al abrirlo.

## Documentacion
`AJUSTES.md` (que tocar para afinar vuelo, imagen, sonido y red), `HUD.md`, `HANGAR.md`, `SONIDO.md`, `MUSICA.md`.
`herramientas/` tiene los scripts de Python que generan los modelos y las partituras.

Licencias: fuente PixelifySans bajo OFL (ver `fuentes/OFL-PixelifySans.txt`). La musica es original, en el estilo de cada pais.
