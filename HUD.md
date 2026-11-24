# HUD de combate: guía visual y técnica

## Técnica pixel-perfect (Godot 4)

- El HUD no se dibuja en la ventana: lo dibuja `Hud` dentro de un `SubViewport` de baja resolución (`HudView`).
- El alto virtual de referencia es 360 px. El factor de escala es un **entero** = `round(alto_ventana / 360)`, mínimo 1 (720p → ×2, 1080p → ×3, 1440p → ×4, 4K → ×6).
- El tamaño del SubViewport es `ceil(ventana / factor)`, así cada píxel del arte es un cuadrado exacto de `factor × factor` píxeles de pantalla, sin deformar la proporción. En ventanas que no son múltiplo exacto, sobra como mucho `factor - 1` px por la derecha/abajo, fuera de pantalla.
- El `TextureRect` que lo muestra usa `TEXTURE_FILTER_NEAREST` y el SubViewport `canvas_item_default_texture_filter = NEAREST`. Fondo transparente, sin 3D.
- Líneas de 1 px: se dibujan en el centro del píxel (`HudStyle.snap`), si no salen borrosas. Círculos con el algoritmo del punto medio, píxel a píxel.
- Fuente `PixelifySans` sin antialiasing, sin hinting y sin posiciones subpíxel, a 8 px (datos) y 16 px (avisos), múltiplos de 8 donde es nítida.
- Contraste: cada línea, punto y texto lleva una sombra/contorno de 1 px `#0A0F0D` al 80 %. No hay cajas ni fondos.
- Lo que el 3D proyecta (`unproject_position`) está en píxeles de ventana: se divide por `px_scale` (`Hud._to_hud`).

## Paleta

| Uso | Color |
|---|---|
| Datos | Verde fósforo `#4AF626` |
| Crítico / enemigos | Rojo alerta `#FF2A4B` |
| Contorno | `#0A0F0D` al 80 % |

## Disposición actual (640×360 virtual)

```
+----------------------------------------------------------------------+
| DERRIBOS 3                  N  .  .  E  .  .   <- brújula (arriba)   |
|                          ----------|----------                       |
|                                    v 042                             |
|                                  PERDIDA   (si hay pérdida)          |
|                                                                      |
|   300 -|                  [ ]  <- enemigo               |- 300       |
|   250 -|           ( o )  ·  <> arco/adelanto            |- 250       |
|   ~ 330>|     --       (+)       --     <- escalera     |<210        |
|   200 -|3px                                              |- 200       |
|   150 -|                                                 |- 150       |
|  GAS 60%                                                 +12 m/s     |
|                                                          2.3 G       |
| SALUD                                                       120/120  |
| [#####....]                                                          |
+----------------------------------------------------------------------+
  izq: cinta de velocidad + gas     centro libre     der: cinta de altitud
```

Márgenes de 8 px. Cintas a 150 px del centro, ±50 px de alto. Cada componente tiene sus constantes arriba:
`hud.gd`, `aircraft_reticle.gd`, `flight_tapes.gd`, `compass_tape.gd`, `pitch_ladder.gd`, `hud_fade.gd`.

## Estado del rediseño

- Paso 1 (hecho): base pixel-perfect, paleta, primitivas con contorno, paneles eliminados.
- Paso 2 (hecho, `aircraft_reticle.gd`): cursor del ratón (círculo de 16 px), cruz del morro (7×7), línea elástica punteada que se apaga al alinearse, rombo de adelanto con arco de distancia eficaz (lleno hasta 600 m, vacío a 1800 m, donde el daño baja al mínimo) y arco de munición a la izquierda del morro. El aro 3D se ha retirado.
- Paso 3 (hecho): `flight_tapes.gd` (cinta de velocidad a la izquierda con barra de gas fina de 3 px; cinta de altitud a la derecha con radar altímetro bajo 150 m; variómetro y G bajo la altitud), `compass_tape.gd` (rumbo arriba con N/E/S/O y marcas de enemigos y aliados; el norte es -Z) y `pitch_ladder.gd` (dos segmentos laterales que giran con el alabeo). `hud_fade.gd` los deja al 40 % mientras son estables y los ilumina al cambiar bruscamente o en peligro (ámbar cerca de la pérdida o el exceso de velocidad, rojo en la pérdida y bajo 40 m). El círculo de horizonte, el texto de velocidad y el gas antiguos se retiraron.
- Paso 4 (hecho): `offscreen_indicator.gd` (flecha roja que orbita a 0,36 del alto desde el centro hacia cada enemigo fuera de pantalla, más pequeña cuanto más lejos, con su distancia), `hud_inertia.gd` (las cintas, la brújula y la escalera de cabeceo se desplazan unos píxeles con el giro y las G y vibran con G altas o impactos; la mira y los corchetes no, porque van pegados al mundo 3D), barra de salud y arco de munición suavizados, y parpadeo de 2 fotogramas de la barra de salud al recibir impactos. Los aliados fuera de pantalla ya no llevan punto (están en la brújula).
- Paso 5 (hecho): `plane_zones.gd` proyecta el casco real del modelo desde arriba (caja de 32 px, morro arriba) y asigna cada píxel a una de 5 zonas (morro/motor, fuselaje, ala izquierda, ala derecha, cola) con la misma geometría que separa los alerones; `damage_doll.gd` la dibuja abajo a la izquierda, sobre la salud. Cada impacto al jugador se anota en la zona que toca (por su posición local); la zona pasa de verde a ámbar y rojo, parpadea 2 fotogramas al recibir daño y al destruirse deja un fantasma tenue. Es solo visual: el avión 3D no pierde vóxeles. El morro y el ala que tira del avión (`wing_side`) también muestran el daño que ya afecta al vuelo.
