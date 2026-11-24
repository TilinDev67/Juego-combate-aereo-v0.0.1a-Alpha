"""Saca un borrador de la melodia de una grabacion (mp3, wav...) en el formato de music_scores.gd.

Requiere: pip install numpy miniaudio   (miniaudio decodifica mp3 sin ffmpeg)

Uso:
    python herramientas/mp3_a_partitura.py cancion.mp3                          # analiza: tempo y compases que se repiten
    python herramientas/mp3_a_partitura.py cancion.mp3 --rangos 1-4,5-12,21-28   # saca esos compases
    python herramientas/mp3_a_partitura.py cancion.mp3 --rangos 5-12 --wav prueba.wav

Como funciona (y sus limites):
  - Busca el tempo y la fase de la rejilla maximizando la fuerza de los inicios de nota en los tiempos. Funciona
    bien en renders de MIDI y grabaciones con tempo estable; con un tempo que oscila no sirve.
  - Divide el audio en semicorcheas y en cada una elige la nota cuyo conjunto de armonicos suena mas fuerte (una
    "saliencia" armonica) y suaviza con una mediana de 5. En una banda de metales suele ser la melodia, pero NO siempre:
    una voz de armonia, o varias voces a la vez, la confunden. Es lo que mejor funciono de las variantes probadas, pero
    "suave" no significa "correcta": solo el oido lo confirma.
  - Una marcha repite sus frases: la herramienta muestra que compases son identicos para que elijas rangos limpios.
  - Mueve la melodia las octavas necesarias al rango suave de la musica del juego (Re4 a Fa5).
  - Calcula un acorde por compas con todas las voces.
  - Con --wav escribe la melodia sola, para compararla de oido con la grabacion. Es un BORRADOR: hay que escucharlo.
"""
import argparse
import struct
import sys
import wave

import numpy as np

SR = 22050
NOMBRES = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']
RANGO_JUEGO = (62, 77)         # Re4 a Fa5 (notas MIDI)
VOZ_MIN, VOZ_MAX = 60, 84      # donde se busca la melodia (notas MIDI)
ARMONICOS = 5                  # armonicos que se suman para puntuar cada nota candidata
PESO_ARMONICO = 0.7            # cuanto pesa cada armonico respecto al anterior
MEDIANA = 5                    # ventana (semicorcheas) de la mediana que quita errores sueltos
SEMICORCHEAS = 16              # por compas
TRIADAS = {'': (0, 4, 7), 'm': (0, 3, 7)}
BEMOL7 = 10


def cargar(ruta):
    import miniaudio
    d = miniaudio.decode_file(ruta, output_format=miniaudio.SampleFormat.SIGNED16, nchannels=1, sample_rate=SR)
    return np.array(d.samples, dtype=np.float32) / 32768.0


def nombre(m):
    return '%s%d' % (NOMBRES[int(m) % 12], int(m) // 12 - 1)


def fuerza_inicios(x):
    hop, n = 128, 1024
    marcos = (len(x) - n) // hop
    esp = np.array([np.abs(np.fft.rfft(x[i * hop:i * hop + n] * np.hanning(n))) for i in range(marcos)])
    flujo = np.maximum(np.diff(np.log1p(esp * 10), axis=0), 0).sum(axis=1)
    fps = SR / hop
    ventana = int(fps * 0.5)
    flujo = np.maximum(flujo - np.convolve(flujo, np.ones(ventana) / ventana, 'same'), 0)
    return flujo, fps


def buscar_tempo(x):
    """Tempo (bpm) y primer tiempo (s) cuya rejilla cae mas sobre los inicios de nota."""
    flujo, fps = fuerza_inicios(x)
    dur = len(x) / SR
    mejor = (-1, 120.0, 0.0)
    for bpm in np.arange(60, 180.01, 0.1):
        tiempo = 60 / bpm
        for fase in np.arange(0, tiempo, 0.01):
            ts = np.arange(fase, dur - 1, tiempo)
            idx = np.minimum((ts * fps).astype(int), len(flujo) - 1)
            puntos = flujo[idx].sum() / len(idx)
            if puntos > mejor[0]:
                mejor = (puntos, float(bpm), float(fase))
    return mejor[1], mejor[2]


def semicorcheas(x, bpm, fase):
    """Energia de cada semitono (MIDI 40..95) en cada semicorchea, y la fuerza de inicio de cada una."""
    corchea = 60 / bpm / 4
    n_slots = int((len(x) / SR - fase) / corchea) - 1
    nf = 8192
    freqs = np.fft.rfftfreq(nf, 1 / SR)
    semis = np.arange(40, 96)
    bandas = [(440 * 2 ** ((m - 0.5 - 69) / 12), 440 * 2 ** ((m + 0.5 - 69) / 12)) for m in semis]
    energia = np.zeros((n_slots, len(semis)))
    for s in range(n_slots):
        a = int((fase + s * corchea + 0.02) * SR)
        seg = x[a:a + int(corchea * SR) - int(0.03 * SR)]
        if len(seg) < 512:
            continue
        mg = np.abs(np.fft.rfft(seg * np.hanning(len(seg)), nf))
        for k, (lo, hi) in enumerate(bandas):
            m = (freqs >= lo) & (freqs < hi)
            energia[s, k] = mg[m].max() if m.any() else 0
    flujo, fps = fuerza_inicios(x)
    inicio = np.array([flujo[max(int((fase + s * corchea) * fps) - 1, 0):int((fase + s * corchea) * fps) + 4].max() for s in range(n_slots)])
    return energia, semis, inicio


def voz_superior(energia, semis):
    """Melodia por semicorchea: la nota cuyos armonicos suman mas energia, suavizada con una mediana."""
    indice = {int(m): k for k, m in enumerate(semis)}
    candidatas = [int(m) for m in semis if VOZ_MIN <= m <= VOZ_MAX]
    voz = np.full(len(energia), -1)
    for s, fila in enumerate(energia):
        mejor, nota = -1.0, -1
        for m in candidatas:
            puntos = 0.0
            for h in range(1, ARMONICOS + 1):
                mh = int(round(m + 12 * np.log2(h)))
                if mh in indice:
                    puntos += (PESO_ARMONICO ** (h - 1)) * fila[indice[mh]]
            if puntos > mejor:
                mejor, nota = puntos, m
        voz[s] = nota
    suave = voz.copy()
    mitad = MEDIANA // 2
    for s in range(mitad, len(voz) - mitad):
        suave[s] = sorted(voz[s - mitad:s + mitad + 1])[mitad]
    return suave


def similitud_compases(voz):
    nb = len(voz) // SEMICORCHEAS
    compases = voz[:nb * SEMICORCHEAS].reshape(nb, SEMICORCHEAS) % 12
    return np.array([[(compases[i] == compases[j]).mean() for j in range(nb)] for i in range(nb)])


def acorde(energia, semis, c):
    """Simbolo de acorde del compas c a partir de todas las voces."""
    bloque = energia[c * SEMICORCHEAS:(c + 1) * SEMICORCHEAS]
    croma = np.zeros(12)
    for k, m in enumerate(semis):
        croma[m % 12] += bloque[:, k].sum()
    mejor = None
    for raiz in range(12):
        for sufijo, plantilla in TRIADAS.items():
            fuera = sum(v for p, v in enumerate(croma) if (p - raiz) % 12 not in plantilla)
            puntos = sum(croma[(raiz + s) % 12] for s in plantilla) - 0.4 * fuera
            if mejor is None or puntos > mejor[0]:
                mejor = (puntos, raiz, sufijo)
    _, raiz, sufijo = mejor
    septima = sufijo == '' and croma[(raiz + BEMOL7) % 12] > 0.35 * croma.max()
    return NOMBRES[raiz] + sufijo + ('7' if septima else '')


def notas_de_compas(voz, inicio, c, transponer):
    """Notas de un compas como lista de [nota o None, duracion en tiempos]; separa las notas repetidas por su inicio."""
    umbral = inicio.mean() + 0.7 * inicio.std()
    notas = []
    for s in range(c * SEMICORCHEAS, (c + 1) * SEMICORCHEAS):
        m = int(voz[s])
        nuevo = not notas or notas[-1][0] != (m + transponer if m > 0 else None) or (m > 0 and inicio[s] > umbral)
        valor = m + transponer if m > 0 else None
        if nuevo:
            notas.append([valor, 0.25])
        else:
            notas[-1][1] += 0.25
    return notas


def texto(duracion):
    t = '%g' % duracion
    return t[1:] if t.startswith('0.') else t


def escribir_wav(ruta, melodia, bpm):
    corchea = 60 / bpm
    muestras = []
    for valor, dur in melodia:
        n = int(dur * corchea * SR)
        if valor is None:
            muestras.extend([0.0] * n)
            continue
        f = 440 * 2 ** ((valor - 69) / 12)
        t = np.arange(n) / SR
        onda = np.sign(np.sin(2 * np.pi * f * t)) * 0.25
        onda *= np.minimum(1, t / 0.005) * np.minimum(1, (n / SR - t) / 0.02)
        muestras.extend(onda.tolist())
    datos = struct.pack('<%dh' % len(muestras), *[int(max(-1, min(1, v)) * 32767) for v in muestras])
    with wave.open(ruta, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('audio')
    ap.add_argument('--rangos', help='compases a sacar, por ejemplo 1-4,5-12,21-28 (empiezan en 1)')
    ap.add_argument('--bpm', type=float, help='fuerza el tempo en vez de buscarlo')
    ap.add_argument('--fase', type=float, help='segundo del primer tiempo (con --bpm)')
    ap.add_argument('--transponer', type=int, help='semitonos (por defecto, las octavas necesarias)')
    ap.add_argument('--wav', help='escribe la melodia sola en este wav para compararla de oido')
    args = ap.parse_args()
    x = cargar(args.audio)
    if args.bpm:
        bpm, fase = args.bpm, args.fase or 0.0
    else:
        print('Buscando el tempo (tarda unos segundos)...')
        bpm, fase = buscar_tempo(x)
    print('Tempo: %.1f bpm  |  primer tiempo en %.2f s  |  duracion %.1f s  |  unos %.1f compases de 4/4' % (
        bpm, fase, len(x) / SR, (len(x) / SR - fase) / (4 * 60 / bpm)))
    energia, semis, inicio = semicorcheas(x, bpm, fase)
    voz = voz_superior(energia, semis)
    sim = similitud_compases(voz)
    nb = len(sim)
    print('\nCompases que se repiten (compas -> gemelo y parecido de la voz superior):')
    fila = []
    for i in range(nb):
        s = sim[i].copy()
        s[i] = -1
        j = int(s.argmax())
        fila.append('%2d->%2d %3.0f%%' % (i + 1, j + 1, 100 * s[j]))
    for k in range(0, nb, 6):
        print('  ' + '   '.join(fila[k:k + 6]))
    if not args.rangos:
        print('\nElige compases limpios (parecidos del 100 %) con --rangos.')
        return
    compases = []
    for tramo in args.rangos.split(','):
        a, b = (int(v) for v in tramo.split('-'))
        compases.extend(range(a - 1, b))
    alturas = [int(voz[s]) for c in compases for s in range(c * SEMICORCHEAS, (c + 1) * SEMICORCHEAS) if voz[s] > 0]
    transponer = args.transponer
    if transponer is None:
        mediana = sorted(alturas)[len(alturas) // 2]
        transponer = 12 * round(((RANGO_JUEGO[0] + RANGO_JUEGO[1]) / 2 - mediana) / 12)
    barras, melodia, acordes = [], [], []
    for c in compases:
        notas = notas_de_compas(voz, inicio, c, transponer)
        melodia.extend(notas)
        barras.append(' '.join('%s:%s' % ('r' if v is None else nombre(v), texto(d)) for v, d in notas))
        acordes.append(acorde(energia, semis, c))
    sonando = [v for v, _ in melodia if v is not None]
    print('\nTransposicion %+d semitonos | melodia de %s a %s | %d compases' % (transponer, nombre(min(sonando)), nombre(max(sonando)), len(compases)))
    lineas = [' | '.join(barras[k:k + 4]) for k in range(0, len(barras), 4)]
    print('\n--- pegar en music_scores.gd ---')
    print('\t\t"bpm": %.1f,' % bpm)
    print('\t\t"melody": "%s",' % (' | " \\\n\t\t\t\t+ "'.join(lineas)))
    print('\t\t"chords": "%s",' % ' '.join(acordes))
    if args.wav:
        escribir_wav(args.wav, melodia, bpm)
        print('\nMelodia sola escrita en', args.wav)


if __name__ == '__main__':
    main()
