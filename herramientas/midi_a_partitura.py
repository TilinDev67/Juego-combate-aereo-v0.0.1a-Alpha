"""Convierte un archivo MIDI en la melodia y los acordes que usa la musica del juego (music_scores.gd).

Uso:
    python herramientas/midi_a_partitura.py cancion.mid                 # lista las pistas y propone una
    python herramientas/midi_a_partitura.py cancion.mid --pista 1       # saca la melodia de la pista 1
    python herramientas/midi_a_partitura.py cancion.mid --pista 1 --transponer -2 --compases 16

Solo usa la biblioteca estandar. Hace esto:
  - Lee las pistas y el tempo. Solo admite compas de 4 tiempos.
  - Deja la melodia a una sola voz (la nota mas aguda de cada instante) y la cuantiza a semicorcheas.
  - Mueve toda la melodia las octavas necesarias para que quede en el rango suave de la musica del juego
    (Re4 a Fa5), salvo que se pida otra cosa con --transponer.
  - Calcula un acorde por compas mirando las notas de TODAS las pistas.
  - Escribe el trozo para pegar en music_scores.gd ("bpm", "melody" y "chords"); el "style" lo eliges tu.
"""
import argparse
import struct
import sys

NOTAS = ['C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B']
RANGO = (62, 77)            # Re4 a Fa5: lo que usa la musica del juego (notas MIDI)
CUANTO = 0.25               # rejilla de cuantizacion (tiempos): semicorchea
TIEMPOS_COMPAS = 4
PLANTILLAS = {'': (0, 4, 7), 'm': (0, 3, 7)}   # triadas mayor y menor
BEMOL7 = 10                 # semitonos de la septima menor


def leer_vlq(datos, i):
    valor = 0
    while True:
        b = datos[i]
        i += 1
        valor = (valor << 7) | (b & 0x7F)
        if not b & 0x80:
            return valor, i


def leer_midi(ruta):
    """Devuelve (ticks por negra, tempo en us por negra, compas, pistas); cada pista es una lista de (inicio, fin, nota)."""
    datos = open(ruta, 'rb').read()
    if datos[:4] != b'MThd':
        sys.exit('No es un archivo MIDI.')
    _, ntrk, division = struct.unpack('>HHH', datos[8:14])   # formato, numero de pistas y ticks por negra
    if division & 0x8000:
        sys.exit('MIDI con tiempo SMPTE: no soportado.')
    tempo = 500000
    compas = (4, 4)
    pistas = []
    i = 14
    for _ in range(ntrk):
        if datos[i:i + 4] != b'MTrk':
            sys.exit('Pista MIDI corrupta.')
        largo = struct.unpack('>I', datos[i + 4:i + 8])[0]
        fin = i + 8 + largo
        j = i + 8
        t = 0
        estado = 0
        activas = {}
        notas = []
        while j < fin:
            delta, j = leer_vlq(datos, j)
            t += delta
            if datos[j] & 0x80:
                estado = datos[j]
                j += 1
            tipo = estado & 0xF0
            if estado == 0xFF:
                meta = datos[j]
                n, j2 = leer_vlq(datos, j + 1)
                cuerpo = datos[j2:j2 + n]
                if meta == 0x51 and n == 3 and not pistas:
                    tempo = int.from_bytes(cuerpo, 'big')
                elif meta == 0x58 and n >= 2 and not pistas:
                    compas = (cuerpo[0], 2 ** cuerpo[1])
                j = j2 + n
            elif estado in (0xF0, 0xF7):
                n, j = leer_vlq(datos, j)
                j += n
            elif tipo in (0x80, 0x90):
                nota, vel = datos[j], datos[j + 1]
                j += 2
                canal = estado & 0x0F
                if canal == 9:
                    continue                      # percusion: no es melodia
                if tipo == 0x90 and vel > 0:
                    activas[nota] = t
                elif nota in activas:
                    notas.append((activas.pop(nota), t, nota))
            elif tipo in (0xC0, 0xD0):
                j += 1
            else:
                j += 2
        pistas.append(notas)
        i = fin
    return division, tempo, compas, pistas


def nombre(midi):
    return '%s%d' % (NOTAS[midi % 12], midi // 12 - 1)


def melodia(notas, division, transponer):
    """Melodia a una voz como lista de [nota o None, duracion en tiempos], cuantizada y cortada en las barras de compas."""
    eventos = sorted(set(inicio for inicio, _, _ in notas))
    voz = []
    for k, inicio in enumerate(eventos):
        siguiente = eventos[k + 1] if k + 1 < len(eventos) else None
        activas = [(n, f) for i, f, n in notas if i == inicio]
        nota = max(n for n, _ in activas)
        fin = max(f for n, f in activas if n == nota)
        if siguiente is not None:
            fin = min(fin, siguiente)
        voz.append((inicio / division, fin / division, nota))
    salida = []
    cursor = 0.0
    for ini, fin, nota in voz:
        ini = round(ini / CUANTO) * CUANTO
        fin = max(round(fin / CUANTO) * CUANTO, ini + CUANTO)
        if ini > cursor:
            salida.append([None, ini - cursor])
        salida.append([nota + transponer, fin - ini])
        cursor = fin
    # cortar las notas que cruzan una barra de compas
    cortado = []
    pos = 0.0
    for nota, dur in salida:
        while dur > 1e-9:
            hasta_barra = TIEMPOS_COMPAS - (pos % TIEMPOS_COMPAS)
            trozo = min(dur, hasta_barra)
            cortado.append([nota, trozo])
            pos += trozo
            dur -= trozo
    return cortado


def acordes(pistas, division, compases, transponer):
    """Un simbolo de acorde por compas, a partir de todas las notas de todas las pistas."""
    simbolos = []
    for c in range(compases):
        a, b = c * TIEMPOS_COMPAS, (c + 1) * TIEMPOS_COMPAS
        peso = [0.0] * 12
        for notas in pistas:
            for ini, fin, n in notas:
                solape = min(fin / division, b) - max(ini / division, a)
                if solape > 0:
                    peso[(n + transponer) % 12] += solape
        if sum(peso) == 0:
            simbolos.append(simbolos[-1] if simbolos else 'C')
            continue
        mejor = None
        for raiz in range(12):
            for sufijo, plantilla in PLANTILLAS.items():
                puntos = sum(peso[(raiz + s) % 12] for s in plantilla) - 0.4 * sum(
                    p for k, p in enumerate(peso) if (k - raiz) % 12 not in plantilla)
                if mejor is None or puntos > mejor[0]:
                    mejor = (puntos, raiz, sufijo)
        _, raiz, sufijo = mejor
        septima = peso[(raiz + BEMOL7) % 12] > 0.25 * max(peso) and sufijo == ''
        simbolos.append(NOTAS[raiz] + sufijo + ('7' if septima else ''))
    return simbolos


def formato(duracion):
    texto = '%g' % duracion
    return texto[1:] if texto.startswith('0.') else texto


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('midi')
    ap.add_argument('--pista', type=int, help='pista que lleva la melodia (sin esto solo se listan)')
    ap.add_argument('--transponer', type=int, help='semitonos a mover la melodia (por defecto, las octavas necesarias)')
    ap.add_argument('--compases', type=int, default=32, help='maximo de compases a convertir (por defecto 32)')
    args = ap.parse_args()
    division, tempo, compas, pistas = leer_midi(args.midi)
    bpm = 60000000 / tempo
    print('Tempo: %.1f bpm  |  compas: %d/%d  |  pistas: %d' % (bpm, compas[0], compas[1], len(pistas)))
    if compas != (4, 4):
        print('AVISO: el juego solo admite compas de 4/4; los compases saldran desalineados.')
    for k, notas in enumerate(pistas):
        if notas:
            print('  pista %d: %4d notas, de %s a %s' % (k, len(notas), nombre(min(n for _, _, n in notas)), nombre(max(n for _, _, n in notas))))
    if args.pista is None:
        print('\nElige la pista de la melodia con --pista N.')
        return
    notas = pistas[args.pista]
    if not notas:
        sys.exit('Esa pista no tiene notas.')
    transponer = args.transponer
    if transponer is None:
        mediana = sorted(n for _, _, n in notas)[len(notas) // 2]
        centro = (RANGO[0] + RANGO[1]) / 2
        transponer = 12 * round((centro - mediana) / 12)
    voz = melodia(notas, division, transponer)
    total = sum(d for _, d in voz)
    compases = min(int(-(-total // TIEMPOS_COMPAS)), args.compases)
    # recortar a "compases" compases y rellenar el ultimo con silencio
    barras, actual, suma = [], [], 0.0
    for nota, dur in voz:
        if len(barras) >= compases:
            break
        actual.append('%s:%s' % ('r' if nota is None else nombre(nota), formato(dur)))
        suma += dur
        if suma >= TIEMPOS_COMPAS - 1e-9:
            barras.append(actual)
            actual, suma = [], 0.0
    if actual and len(barras) < compases:
        actual.append('r:%s' % formato(TIEMPOS_COMPAS - suma))
        barras.append(actual)
    alturas = [n + transponer for _, _, n in notas]
    print('Transposicion: %+d semitonos  |  melodia de %s a %s  |  %d compases' % (transponer, nombre(min(alturas)), nombre(max(alturas)), len(barras)))
    if max(alturas) > 79 or min(alturas) < 55:
        print('AVISO: hay notas fuera del rango suave (Sol3 a Sol5). Prueba otra --transponer o otra pista.')
    lineas = [' | '.join(' '.join(b) for b in barras[k:k + 4]) for k in range(0, len(barras), 4)]
    melodia_txt = ' | " \\\n\t\t\t\t+ "'.join(lineas)
    print('\n--- pegar en music_scores.gd ---')
    print('\t\t"bpm": %.1f,' % bpm)
    print('\t\t"melody": "%s",' % melodia_txt)
    print('\t\t"chords": "%s",' % ' '.join(acordes(pistas, division, len(barras), transponer)))


if __name__ == '__main__':
    main()
