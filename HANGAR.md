# Hangar (menú de inicio): estilo retro-militar

Estética de manual de campo y radio militar de mediados del siglo XX, dominada por el verde olivo. El HUD de vuelo mantiene su propia paleta (`HudStyle`); este menú usa `MilitaryStyle`.

## 1. Paleta

| Uso | Hex | Constante (`MilitaryStyle`) |
|---|---|---|
| Carcasa de los paneles | `#3B442B` | `OLIVE_BASE` |
| Chapa más clara (fila elegida, pulsador) | `#4A5535` | `OLIVE_PANEL` |
| Sombra, borde y contorno del texto | `#1E2416` | `OLIVE_DARK` |
| Bisel claro | `#6B784E` | `OLIVE_BEVEL` |
| Texto secundario y etiquetas | `#B8B08A` | `KHAKI` |
| Texto principal | `#C8BE96` | `KHAKI_LIGHT` |
| Fósforo de instrumento (segmentos activos) | `#8FA84A` | `GAUGE` |
| Fósforo claro (valores, pulsador enfocado) | `#A3B85C` | `GAUGE_LIGHT` |
| Selección, luz piloto y destellos | `#C98A2E` | `AMBER` |
| Alerta, cambio a peor | `#B83A2D` | `RUST` |
| Ranura de las barras | `#1A1F13` | `SLOT` |
| Pintura amarilla de pista (3D) | aprox. `#C79E2E` | `PAINT_YELLOW` |
| Pintura blanca de pista (3D) | aprox. `#D1CCB8` | `PAINT_WHITE` |

### Cómo se aplica el relieve en 1-2 px

- **Chapa (`MilitaryStyle.panel`):** relleno con las 4 esquinas cortadas (falta el píxel de cada esquina), una línea de 1 px de bisel claro `#6B784E` arriba e izquierda y de sombra `#1E2416` abajo y derecha, y un remache de 2×2 px caqui con sombra de 1 px a 3 px de cada esquina.
- **Ranura (`MilitaryStyle.slot`):** fondo `#1A1F13` con 1 px de sombra arriba e izquierda y 1 px de carcasa clara abajo y derecha: parece hundida. El segmento encendido se pinta 1 px más pequeño dentro.
- **Texto:** contorno de 1 px `#1E2416` y relleno caqui. Sin sombras largas ni brillos.
- **Pulsador:** chapa `#4A5535` con un segundo marco interior de 1 px a 3 px del borde: da el doble marco.
- **Capa final (`MilitaryStyle.overlay`):** una scanline negra al 7 % cada 2 px y 160 puntos de grano fijo (claros u oscuros al 6 %) para sugerir papel o metal envejecido.

## 2. Estructura del menú

| Archivo | Qué hace |
|---|---|
| `start_menu.gd` | Selección de aviones, registro, telemetría, pulsador y salida (entrada de ratón y teclado, dibujo pixel-perfect) |
| `military_style.gd` | Paleta y primitivas: chapa, ranura, texto con contorno, corchetes de telémetro, scanlines y grano |
| `hangar_scene.gd` | Losa de hormigón, pintura, luces, polvo, entrada del avión, arranque de motor y humo |
| `hangar_camera.gd` | Cámara con muelles: barrido, acercamiento, «clack» de enfoque y salida |
| `hangar_scan.gdshader` | Persiana de líneas que descubre el avión |
| `hud_style.gd` | Persiana de transición compartida con el HUD de juego |

Distribución (640×360 virtual):

```
+----------------------------------------------------------------------+
|                          COMBATE AEREO                               |
|          Messerschmitt Bf 109 G-6   [AC-02 / CAZA]_                  |
|          Caza aleman rapido. 1 canon MK 108 ...                      |
|  REGISTRO DE AERONAVES                           TELEMETRIA          |
| +--------------------+                      +--------------------+   |
| |#R01 IL-2        o  |  (luz piloto ambar)  | VELOCIDAD 414 km/h |   |
| | R02 Bf 109 G-6     |                      | [#][#][#][#]...    |   |
| | R03 Spitfire       |       .--[ ]--.      | MANIOBRA     x1.15 |   |
| | R04 P-51D Mustang  |     [   AVION   ]    | [#][#][#]....      |   |
| | R05 A6M2 Zero      |       '--[ ]--'      | BLINDAJE        85 |   |
| | R06 Ju 87 G        |                      | FUEGO          112 |   |
| | R07 Fw 190 A-8     |                      | ESTABILIDAD 504 .. |   |
| +--------------------+                      +--------------------+   |
|                       +=================+                            |
|                       |    EMPEZAR      |                            |
|                       +=================+                            |
|                              LISTO                                   |
|     W/S o flechas: elegir  -  1-7: ir al avion  -  Enter: empezar   |
+----------------------------------------------------------------------+
```

- **Registro:** cada fila lleva número de registro (`R02`), mini-silueta, nombre y rol. La elegida tiene una pestaña ámbar a la izquierda, una luz piloto que parpadea una vez por segundo, un pulso de luz al elegirla y un retroceso de 2 px.
- **Telemetría:** 5 métricas con segmentos verde fósforo apagado sobre ranuras oscuras; valores a la derecha.
- **Cabecera:** el avión elegido se «mecanografía» (220 caracteres por segundo) con un cursor `_`.
- **Pulsador:** `LISTO` en reposo, `ARMADO` con el ratón encima y `SALIDA` al pulsar.

## 3. Animaciones y tiempos (todo ≤ 0,4 s)

| Animación | Duración | Detalle |
|---|---|---|
| Corchetes de telémetro (fila y avión) | 0,18 s | salida suave, parpadeo de 2 fotogramas; con marcas de grado sobre el avión y cruz de puntería |
| Pulso y retroceso de la fila | 0,25 s y 0,15 s (2 px) | |
| Barrido de la cámara al cambiar | ~0,4 s | muelle subamortiguado |
| Entrada del avión | 0,3 s | persiana de líneas que sube a saltos de 0,25 m |
| Arranque del motor | al acabar la entrada | la hélice coge vueltas, bocanada de humo de cubos y «clack» de 3° en el campo de visión |
| Barrido de segmentos | 0,25 s (40 segmentos/s) | de izquierda a derecha; la cabeza y los segmentos que cambian destellan en ámbar |
| Indicador `+`/`-` | 1,2 s | ámbar/verde/rojo; se desvanece al final |
| Llenado al abrir | 0,06 s entre barras | |
| Pulsador | corchetes en 0,15 s; se hunde 1 px al enfocar y 2 px al pulsar | verde → verde claro → ámbar |
| Salida | 0,4 s | cámara 12 m hacia el avión, motor revolucionado y persiana de 0,25 s con filo ámbar |

**Que no retrasen al jugador:** ninguna animación bloquea la entrada; cada cambio de avión reinicia las suyas y no las encola; `Enter` sale en 0,4 s y cualquier tecla o clic durante la salida la salta.

## 4. Checklist «adiós al look sci-fi / neón»

- [x] **Colores:** nada de cian, verde neón ni blanco puro en el menú. Los verdes son `#8FA84A`/`#A3B85C`; los acentos, ámbar y óxido.
- [x] **Brillo y post-procesado:** la plataforma no tiene emisión, así que el *glow* del entorno no la ilumina; no hay luces de colores saturados (focos en ámbar cálido).
- [x] **Luz:** atardecer con sol rasante (-16°) y cielo gris azulado con horizonte cálido; sin contraluz de color.
- [x] **Superficies:** hormigón agrietado de píxel gordo, bordillo, pintura amarilla y blanca saltada, numeración de pista. Sin tiras de luz.
- [x] **UI:** chapa remachada con bisel; sin paneles translúcidos ni marcos finos luminosos; texto caqui con contorno.
- [x] **Movimiento:** pasos y saltos (persiana por tramos, barrido de segmentos, corchetes con snap); nada de fundidos suaves ni holografías. Las únicas curvas suaves son los muelles de la cámara.
- [x] **Entrada del avión:** persiana, motor y humo en lugar del escaneo láser.
- [x] **Textura de pantalla:** scanlines al 7 % y grano fijo, sin distorsión ni aberración cromática.
- [ ] **Tipografía estarcida:** pendiente. Sigue `PixelifySans` en mayúsculas; un estarcido (*stencil*) real pide generar una fuente de bits.
