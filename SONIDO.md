# Sonido procedimental: recetas y mezcla

Todo el sonido de combate se genera por código (sin archivos de audio), en GDScript, al arrancar. Cada efecto es un **banco de variantes**: varias muestras generadas con parámetros algo distintos (±8 %), de las que se reproduce una al azar —nunca la misma dos veces seguidas— con un tono (±5 %) y un volumen (±1 dB) también al azar.

| Archivo | Qué hace |
|---|---|
| `synth_kit.gd` | Ruido blanco, filtro de un polo (pasa-bajos y pasa-altos), envolvente exponencial, saturación suave y cierre de cada muestra (fundidos de 0,3 ms y 2 ms y normalización) |
| `sfx_recipes.gd` | Una receta por sonido, con sus constantes arriba |
| `sfx_bank.gd` | Banco de variantes |
| `game_sound.gd` | API de reproducción: disparo, volea, impacto, derribo, caída, explosión |
| `voice_limit.gd` | Tope de voces por categoría y ganancia por número de voces |
| `audio_mixer.gd` | Buses, compresor, limitador y *ducking* |
| `synth.gd` | Motor y viento, en bucle |

Muestreo: 44,1 kHz en disparos, impactos y derribo (hace falta para un chasquido nítido); 16 kHz en explosiones y caídas (casi todo es grave).

## 1. Receta de síntesis por sonido

Convención: «ruido» = ruido blanco; `HP` pasa-altos, `LP` pasa-bajos; la envolvente es siempre `exp(-t · k)`, con ataque instantáneo (solo el fundido anti-clic de 0,3 ms).

### Disparos

| Sonido | Duración | Capas |
|---|---|---|
| **Ametralladora** | 70 ms | **Clic** de ataque (ruido HP 3 kHz, k = 900) · **timbre metálico** (dos senos inarmónicos, 2,8 kHz y ×1,52, k = 350) · **chasquido** (ruido en banda 1,5-7 kHz, k = 140) · **golpe grave** (seno 170 Hz con caída de tono, k = 130). Poca energía para poder repetirse a 22 disparos por segundo |
| **Cañón** | 280 ms | **Crujido** (ruido HP 2 kHz, k = 400) · **golpe grave** (seno 70 Hz que arranca al doble, + armónico ×2) · **golpe medio** (ruido LP 900 Hz, k = 30) · **cola** (ruido LP con corte de 3,5 kHz a 400 Hz, k = 12) · **saturación suave** final (tanh, 1,6) |

Cada variante cambia tonos, fase del timbre y ruido. Con varios cañones, cada uno suena con su variante y **4-14 ms de desfase**, y baja 3 dB.

### Impactos

| Sonido | Duración | Capas |
|---|---|---|
| **Chapa (blindaje)** | 250 ms | **Clic** (HP 4 kHz) · **tres parciales** inarmónicos ×1 / ×2,76 / ×5,4 del tono (1,3 kHz ±12 %), los agudos se apagan antes (k = 45 / 90 / 160) · **«clank»** de ruido en banda 0,8-3 kHz · LP final a 9 kHz |
| **Estructura (fuselaje)** | 220 ms | **Golpe sordo** (seno 110 Hz con caída de tono) · **crujido** (ruido en banda 0,3-2,5 kHz troceado en granos de 40 muestras con nivel al azar) · **2-4 esquirlas** (clics de 2 ms) · LP final a 6 kHz |

La severidad (daño / 12) sube el volumen de −14 a −3 dB y baja el tono de ×1,12 a ×0,88. Un impacto en chapa con severidad ≥ 0,6 suma el crujido de estructura 12 ms después. Los lejanos se apagan con un filtro de 20 kHz a 2,5 kHz a 600 m.

### Derribo

| Sonido | Duración | Capas |
|---|---|---|
| **Confirmación** (no posicional, +3 dB) | 360 ms | **Golpe final** (seno 150 Hz con caída de tono) · **chasquido** (HP 2,5 kHz) · **silbido** que cae de 2,6 kHz a 650 Hz · **dos pulsos tácticos** retro de onda casi cuadrada (armónicos impares): 880 Hz y 1320 Hz, una quinta ascendente |
| **Caída del avión** | 2,5 s | **Tres chasquidos** de metal al principio · **silbido** que cae de 1,1 kHz a 110 Hz · **chisporroteo** de 25 a 160 pops por segundo y volumen creciente |

### Explosiones (tres tamaños: pequeña, mediana, grande)

Capas: **transitorio** (ruido HP 600 Hz, dura unos ms) en t = 0 · **cuerpo sub-grave** (seno con caída de tono que arranca a 3-4 veces su tono final; 60 / 48 / 38 Hz) · **golpe medio** (ruido LP, 900 / 700 / 500 Hz) · **cola** (ruido LP cuyo corte se cierra de 2 kHz a 90 Hz) · **saturación suave** (1,4). Duran 0,6 / 1,0 / 1,9 s. La escala del efecto visual decide el tamaño: hasta 1,2 pequeña, hasta 2,5 mediana y el resto grande. Cada tamaño suena a −1 / +2 / +4 dB; las grandes se oyen de más lejos y las lejanas se apagan con un filtro de 20 kHz a 1,2 kHz a 1.500 m.

## 2. Mezcla anti-saturación

Cadena: `reproductor → bus SFX (compresor) → Master (−12 dB, limitador a −1 dB)`. El motor y el viento van a su propio bus (`Engine`), directo al Master.

1. **Topes de voces por categoría** (`voice_limit.gd`): impactos 8, explosiones 4, cañones enemigos 6, caídas 4. Con la categoría llena, un sonido nuevo solo entra si se oye más fuerte (con su atenuación por distancia) que el más flojo, al que le quita el sitio; si es aún más flojo, no suena. Los disparos del jugador usan un conjunto rotativo de 12 reproductores, que ya roba el más antiguo. El derribo tiene reproductor propio.
2. **Ganancia por número de voces:** cada sonido nuevo baja 1,5 dB cada vez que se duplica el número de voces de su categoría (2 voces −1,5 dB, 4 −3 dB, 8 −4,5 dB).
3. **Compresor del bus SFX:** umbral −3 dB, relación 3:1, ataque 0,5 ms y suelta 200 ms. El umbral es alto a propósito: un disparo suelto no se toca, solo se comprime cuando se acumulan muchos sonidos.
4. ***Ducking*:** una explosión baja el motor y el viento 0 / −3 / −8 dB (según su tamaño, y menos cuanto más lejos esté) durante 0,25 s y los devuelve en 0,8 s.
5. **Limitador final** a −1 dB como red de seguridad.

Simulación en Python de 6 s de caos (2 cañones, ametralladora, 3 enemigos, 20 impactos por segundo, 6 explosiones y 2 derribos, sin atenuación por distancia): el pico llega a +9,7 dB antes del volumen general (−2,3 dBFS tras el master), sin contar el compresor. Con los topes de voces y la ganancia por número de voces, el nivel medio baja 1 dB y se descartan 2 de las 6 explosiones.

## 3. Parámetros

Todos son constantes con comentario al principio de su archivo; la tabla «Sonido» de `AJUSTES.md` dice cuál tocar según lo que se oiga.
