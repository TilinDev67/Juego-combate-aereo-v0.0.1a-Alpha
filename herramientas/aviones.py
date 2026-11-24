"""Genera los modelos de voxeles de los aviones (carpeta modelos/) y sus vistas previas.

Uso:  python herramientas/aviones.py [nombre ...] [--preview DIRECTORIO]
Cada avion se guarda como .vox (modelo 0 = casco, modelo 1 = helice) y se describe en modelos/aviones.json
(ficha con el pivote, el eje de la helice, la punta del ala y la caja de impactos).
Los aviones enemigos son las mismas piezas con marcas rojas (sufijo _enemigo).
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from voxlib import Model, blotch, hash01, mix, prop_model, preview, sh, write_vox

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'modelos')
VS = 0.25                                  # tamano de un voxel (m)

BLACK = (22, 22, 26)
WHITE = (232, 232, 226)
GLASS = (120, 170, 205)
FRAME = (40, 46, 52)
METAL_DARK = (52, 54, 60)
EXHAUST = (64, 46, 38)
RED = (200, 35, 30)
YELLOW = (235, 200, 40)
TEAM_ENEMY = RED
BOX_MARGIN = 0.92                          # la caja de impactos es algo mas pequena que el modelo (margen de tolerancia)


# ---------------------------------------------------------------- piezas comunes
def cross_side(m, x, y, z, size, fill, edge):
    """Cruz vista de lado (plano XZ) pegada a la cara y: contorno claro y cruz oscura."""
    arm = max(1, size // 3)
    for dx in range(-size - 1, size + 2):
        for dz in range(-size - 1, size + 2):
            if abs(dx) <= arm or abs(dz) <= arm:
                m.put(x + dx, y, z + dz, edge)
    for dx in range(-size, size + 1):
        for dz in range(-size, size + 1):
            if abs(dx) <= arm - 1 or abs(dz) <= arm - 1:
                m.put(x + dx, y, z + dz, fill)


def cross_top(m, xc, yc, size, fill, edge, up=True):
    """Cruz sobre un ala: pinta el voxel superior (o inferior) de cada columna."""
    arm = max(1, size // 3)
    for dx in range(-size - 1, size + 2):
        for dy in range(-size - 1, size + 2):
            if abs(dx) <= arm or abs(dy) <= arm:
                zs = [k[2] for k in m.v if k[0] == xc + dx and k[1] == yc + dy]
                if zs:
                    z = max(zs) if up else min(zs)
                    inner = abs(dx) <= size and abs(dy) <= size and (abs(dx) <= arm - 1 or abs(dy) <= arm - 1)
                    m.put(xc + dx, yc + dy, z, fill if inner else edge)


def roundel_top(m, xc, yc, rings, up=True):
    """Escarapela sobre un ala: rings = [(radio, color), ...] de fuera a dentro."""
    for dx in range(-8, 9):
        for dy in range(-8, 9):
            zs = [k[2] for k in m.v if k[0] == xc + dx and k[1] == yc + dy]
            if not zs:
                continue
            d2 = dx * dx + dy * dy
            col = None
            for r, c in rings:
                if d2 <= r * r + 0.5:
                    col = c
            if col:
                m.put(xc + dx, yc + dy, max(zs) if up else min(zs), col)


def roundel_side(m, x, y, z, rings):
    for dx in range(-8, 9):
        for dz in range(-8, 9):
            d2 = dx * dx + dz * dz
            col = None
            for r, c in rings:
                if d2 <= r * r + 0.5:
                    col = c
            if col:
                m.put(x + dx, y, z + dz, col)


def canopy(m, x0, x1, zbase, hw, height, frames=(), power=2.4, glass=GLASS, frame=FRAME):
    """Cabina de cristal sobre el fuselaje: crece de atras (x0) a delante (x1) y vuelve a bajar."""
    for x in range(x0, x1 + 1):
        t = (x - x0) / max(1, x1 - x0)
        prof = math.sin(math.pi * (0.1 + 0.8 * t)) ** 0.75
        h = height * prof
        w = hw * (0.55 + 0.45 * prof)
        for y in range(-math.ceil(w), math.ceil(w) + 1):
            for z in range(zbase, zbase + math.ceil(h) + 1):
                zr = (z - zbase) / max(h, 0.01)
                if (abs(y) / max(w, 0.01)) ** power + zr ** power <= 1.001:
                    m.put(x, y, z, frame if x in frames else glass)


def barrel(m, x0, x1, y, z, c=METAL_DARK):
    """Tubo de canon: una fila de voxeles a lo largo de X."""
    for x in range(x0, x1 + 1):
        m.put(x, y, z, c)
        m.put(x, -y, z, c)


def finish(name, hull, nose_x, pivot_x, axis_z, blades, radius, hub_color, blade_color, tip_color):
    """Desplaza el casco a coordenadas positivas, escribe el .vox y devuelve su ficha."""
    v = hull.v
    minx = min(k[0] for k in v); miny = min(k[1] for k in v); minz = min(k[2] for k in v)
    maxx = max(k[0] for k in v); maxy = max(k[1] for k in v); maxz = max(k[2] for k in v)
    sx, sy, sz = -minx, -miny, -minz
    hull_out = {(k[0] + sx, k[1] + sy, k[2] + sz): c for k, c in v.items()}
    prop, hub = prop_model(blades, radius, hub_color, blade_color, tip_color)
    os.makedirs(OUT, exist_ok=True)
    ncol = write_vox(os.path.join(OUT, name + '.vox'), [hull_out, prop])
    # punta del ala (ejes del juego: x = a lo ancho, y = arriba, z = hacia atras desde el pivote)
    tip_y = max(abs(k[1]) for k in v)
    tip_pts = [k for k in v if abs(k[1]) == tip_y]
    tip_x = sum(k[0] for k in tip_pts) / len(tip_pts)
    tip_z = sum(k[2] for k in tip_pts) / len(tip_pts)
    half_w = (tip_y + 0.5) * VS
    height = (maxz - minz + 1) * VS
    length = (maxx - minx + 1) * VS
    meta = {
        'file': 'res://modelos/%s.vox' % name,
        'pivot_x': pivot_x + sx,               # voxel X del casco que queda en el origen del avion
        'span_y': sy,                          # voxel Y del eje central
        'axis_z': axis_z + sz,                 # voxel Z del eje de la helice
        'prop_hub': [hub, hub],                # buje dentro del modelo de la helice (y, z)
        'prop_z': -(maxx + 1 - pivot_x),       # posicion de la helice en voxeles, delante del morro
        'wing_tip': [round(half_w, 2), round((tip_z - axis_z) * VS, 2), round((pivot_x - tip_x) * VS, 2)],
        'box_half': [round(half_w * BOX_MARGIN, 2), round(height / 2 * BOX_MARGIN, 2), round(length / 2 * BOX_MARGIN, 2)],
        'box_center': [0.0, round(((maxz + minz) / 2 - axis_z) * VS, 2), round((pivot_x - (maxx + minx) / 2) * VS, 2)],
    }
    print('%-18s voxeles %6d  colores %3d  largo %4.1f m  envergadura %4.1f m  alto %3.1f m' % (
        name, len(hull_out), ncol, length, half_w * 2, height))
    return meta, v


def camo(a, b, scale=3.5, salt=1, speckle=0.94):
    """Funcion de color de camuflaje de dos tonos con motas."""
    def f(x, y, z):
        c = a if blotch(x, y, z, scale, salt) > 0.5 else b
        if hash01(x, y, z, salt + 4) > speckle:
            c = sh(c, 0.8)
        return c
    return f


# ====================================================================================== Bf 109 G-6
def bf109(team=None):
    accent = team or YELLOW
    top = camo((92, 100, 96), (74, 80, 92), 3.5, 11)
    light = (168, 186, 198)
    m = Model()

    def body(x, y, z, zc, hw, ht, hb):
        if x >= 15:
            return accent
        if x >= 12 and z > zc - hb * 0.5:
            return accent if x >= 13 else BLACK
        if z < zc - hb * 0.3:
            return light
        if x in (-14, -15, -16):
            return accent
        return top(x, y, z)

    m.fuselage([(17, 0.3, 0.3, 0.3, 0), (15, 1.8, 1.8, 1.8, 0), (13, 2.4, 2.6, 2.4, 0), (6, 2.6, 2.7, 2.5, 0),
                (4, 2.5, 3.7, 2.5, 0), (-3, 2.4, 3.4, 2.3, 0), (-9, 1.9, 2.4, 1.7, 0.2), (-14, 1.1, 1.7, 1.1, 0.5),
                (-19, 0.5, 1.0, 0.6, 0.8)], body)
    m.wing(2, 19, lambda y: 3 - 0.1 * y, lambda y: 9.5 - 0.27 * y, -1, 0.11, lambda y: 3 if y < 5 else 2,
           top=lambda x, y, z: WHITE if abs(y) == 19 else top(x, y, z), bottom=lambda x, y, z: light)
    for sy in (1, -1):
        m.box(-1, 1, sy * 5, sy * 5, -2, -2, sh(light, 0.85))
        m.box(-1, 1, sy * 7, sy * 7, -2, -2, sh(light, 0.85))
        cross_top(m, 0, sy * 13, 3, BLACK, WHITE)
        cross_side(m, -9, sy * 2, 0, 2, BLACK, WHITE)
        m.box(-3, 0, sy * 8, sy * 10, -3, -2, METAL_DARK)          # radiadores
        m.box(1, 5, sy * 12, sy * 12, -2, -2, METAL_DARK)          # carenados de los canones
        m.box(5, 10, sy * 1, sy * 1, 3, 3, METAL_DARK)             # culatas de las MG 131
        for x in range(7, 12):
            m.put(x, sy * 3, 0 if x % 2 else -1, EXHAUST)           # escapes
    m.wing(1, 7, lambda y: -13 - 0.2 * y, lambda y: 5 - 0.3 * y, 2, 0.0, lambda y: 1,
           top=lambda x, y, z: top(x, y, z), bottom=lambda x, y, z: light)
    m.fin(-13, 2, 11, lambda z: -12 - 0.6 * (z - 2), lambda z: 6.5 - 0.35 * (z - 2),
          lambda x, y, z: accent if x < -15 - (z - 2) * 0.6 else top(x, y, z))
    canopy(m, -4, 6, 3, 2.1, 3.0, frames=(-2, 1, 4))
    return finish('Bf109' + ('_enemigo' if team else ''), m, 17, 0, 0, 3, 7, METAL_DARK, (40, 40, 44), accent)


# ====================================================================================== Zero A6M2
def zero(team=None):
    accent = team or RED
    top = camo((170, 178, 150), (158, 168, 138), 4.0, 21, 0.95)
    under = (190, 196, 176)
    cowl = (28, 30, 42)
    m = Model()

    def body(x, y, z, zc, hw, ht, hb):
        if x >= 15:
            return cowl
        if x >= 9:
            return cowl
        if z < zc - hb * 0.25:
            return under
        if x in (-12, -13):
            return accent if team else top(x, y, z)
        return top(x, y, z)

    m.fuselage([(18, 0.3, 0.3, 0.3, 0), (16, 2.0, 2.0, 2.0, 0), (14, 2.8, 2.9, 2.7, 0), (9, 2.8, 2.9, 2.7, 0),
                (6, 2.5, 3.0, 2.4, 0), (0, 2.4, 3.5, 2.3, 0), (-6, 2.0, 2.8, 1.8, 0.2), (-12, 1.4, 2.0, 1.3, 0.4),
                (-18, 0.5, 1.0, 0.6, 0.7)], body)
    # alas anchas de puntas redondeadas
    m.wing(2, 24, lambda y: 4 - 0.05 * y, lambda y: 3 + 7.5 * math.sqrt(max(0.0, 1 - (y / 25.0) ** 2)),
           -1, 0.08, lambda y: 3 if y < 6 else 2,
           top=lambda x, y, z: top(x, y, z), bottom=lambda x, y, z: under)
    for sy in (1, -1):
        roundel_top(m, 1, sy * 12, [(4, RED if not team else WHITE), (2, WHITE if not team else RED)])
        roundel_top(m, 1, sy * 12, [(3, RED)], up=False)
        roundel_side(m, -8, sy * 2, 0, [(3, WHITE), (2, RED)])
        barrel(m, 5, 8, sy * 9, -1)                                 # canones de 20 mm en el borde de ataque
        m.box(-1, 5, sy * 9, sy * 9, -2, -2, METAL_DARK)
        for x in range(9, 13):
            m.put(x, sy * 3, -1 if x % 2 else 0, EXHAUST)           # escapes
    m.wing(1, 8, lambda y: -13 - 0.15 * y, lambda y: 5 - 0.3 * y, 2, 0.0, lambda y: 1,
           top=lambda x, y, z: top(x, y, z), bottom=lambda x, y, z: under)
    m.fin(-13, 2, 10, lambda z: -12 - 0.5 * (z - 2), lambda z: 6 - 0.4 * (z - 2), lambda x, y, z: top(x, y, z))
    canopy(m, -7, 7, 3, 2.1, 3.4, frames=(-4, -1, 2, 5))
    return finish('Zero' + ('_enemigo' if team else ''), m, 18, 0, 0, 3, 7, cowl, (60, 54, 48), accent)


# ====================================================================================== Spitfire Mk V
def spitfire():
    top = camo((60, 80, 50), (96, 80, 52), 4.5, 31, 0.95)
    sky = (150, 192, 172)
    blue, white, red = (40, 60, 150), WHITE, (190, 30, 40)
    m = Model()

    def body(x, y, z, zc, hw, ht, hb):
        if x >= 16:
            return sky
        if z < zc - hb * 0.3:
            return sky
        return top(x, y, z)

    m.fuselage([(18, 0.3, 0.3, 0.3, 0), (16, 1.8, 1.8, 1.8, 0), (14, 2.2, 2.4, 2.2, 0.2), (6, 2.4, 2.8, 2.4, 0.3),
                (2, 2.5, 3.4, 2.5, 0), (-4, 2.2, 3.2, 2.2, 0.2), (-10, 1.6, 2.2, 1.5, 0.5), (-18, 0.5, 1.0, 0.5, 1.0)],
               body)
    chord = lambda y: 1 + 10.5 * math.sqrt(max(0.0, 1 - (y / 22.5) ** 2))
    m.wing(2, 22, lambda y: 4 - 0.5 * (10.5 - (chord(y) - 1)) * 0.0 - 0.12 * y, chord, -1, 0.07,
           lambda y: 3 if y < 6 else 2, top=lambda x, y, z: top(x, y, z), bottom=lambda x, y, z: sky)
    for sy in (1, -1):
        roundel_top(m, -1, sy * 11, [(5, blue), (4, white), (3, red), (1, white)])
        roundel_side(m, -9, sy * 2, 0, [(4, blue), (3, white), (2, red)])
        barrel(m, 4, 8, sy * 8, -1)
        barrel(m, 4, 7, sy * 6, -1)
        m.box(-1, 4, sy * 8, sy * 8, -2, -2, METAL_DARK)
    m.box(-2, 1, 6, 9, -3, -2, METAL_DARK)                      # radiador grande bajo el ala
    m.box(-2, 1, -9, -7, -3, -2, sh(METAL_DARK, 1.3))
    for x in range(8, 12):
        for sy in (1, -1):
            m.put(x, sy * 3, 1 if x % 2 else 0, EXHAUST)
    m.wing(1, 8, lambda y: -12 - 0.2 * y, lambda y: 4.5 - 0.3 * y * (5 / 4.5), 2, 0.0, lambda y: 1,
           top=lambda x, y, z: top(x, y, z), bottom=lambda x, y, z: sky)
    m.fin(-12, 3, 12, lambda z: -11 - 0.55 * (z - 3), lambda z: 7 - 0.45 * (z - 3), lambda x, y, z: top(x, y, z))
    canopy(m, -5, 7, 3, 2.0, 3.0, frames=(-3, 0, 3))
    return finish('Spitfire', m, 18, 0, 0, 3, 7, (30, 30, 34), (46, 44, 40), (60, 60, 64))


# ====================================================================================== P-51D Mustang
def p51():
    accent = (40, 60, 150)
    metal = (176, 180, 188)
    olive = (74, 80, 54)

    def pulido(x, y, z):
        c = sh(metal, 0.93 + 0.14 * blotch(x, y, z, 2.5, 41))
        if hash01(x, y, z, 9) > 0.97:
            c = sh(c, 0.88)
        return c

    def stripe(x, y, z):
        # franjas de invasion (negro y blanco) en la cola y las alas
        return None

    m = Model()

    def body(x, y, z, zc, hw, ht, hb):
        if x >= 17:
            return accent
        if 7 <= x <= 15 and z >= zc + ht * 0.45:
            return olive                                  # panel antirreflejo del capo
        if x >= 15:
            return accent
        if -16 <= x <= -9:
            return BLACK if (x % 4) in (0, 1) else WHITE   # franjas
        return pulido(x, y, z)

    m.fuselage([(20, 0.3, 0.3, 0.3, 0), (18, 1.8, 1.8, 1.8, 0), (15, 2.4, 2.6, 2.2, 0.2), (8, 2.5, 3.0, 2.3, 0.2),
                (3, 2.6, 3.4, 2.5, 0), (-2, 2.3, 3.0, 2.5, 0), (-10, 1.8, 2.2, 1.7, 0.3), (-19, 0.5, 1.0, 0.5, 0.8)],
               body)
    def wing_top(x, y, z):
        if 9 <= abs(y) <= 16 and -2 <= x <= 5:
            return BLACK if ((abs(y) - 9) // 2) % 2 == 0 else WHITE
        return pulido(x, y, z)
    m.wing(2, 22, lambda y: 4 - 0.06 * y, lambda y: 10.5 - 0.25 * y, -1, 0.07, lambda y: 3 if y < 8 else 2,
           top=wing_top, bottom=lambda x, y, z: pulido(x, y, z))
    for sy in (1, -1):
        roundel_top(m, 0, sy * 18, [(4, accent), (2, WHITE)])
        roundel_side(m, -7, sy * 2, 0, [(3, accent), (1, WHITE)])
        m.box(-1, 5, sy * 8, sy * 8, -2, -2, METAL_DARK)         # alojamientos de las Browning
        for k in range(3):
            barrel(m, 4, 5, sy * (6 + k * 2), 0 if k % 2 else -1)
        for x in range(10, 14):
            m.put(x, sy * 3, 0 if x % 2 else -1, EXHAUST)
    m.box(-4, 2, -1, 1, -4, -3, (96, 98, 104))                   # toma de aire ventral
    m.wing(1, 8, lambda y: -14 - 0.1 * y, lambda y: 5 - 0.3 * y, 2, 0.0, lambda y: 1,
           top=lambda x, y, z: pulido(x, y, z), bottom=lambda x, y, z: pulido(x, y, z))
    m.fin(-14, 3, 12, lambda z: -12 - 0.5 * (z - 3), lambda z: 7 - 0.35 * (z - 3),
          lambda x, y, z: (BLACK if x % 4 in (0, 1) else WHITE) if x < -14 else pulido(x, y, z))
    # aleta dorsal que une la cabina con la deriva
    for x in range(-12, -5):
        for z in range(3, 3 + max(0, 6 - (x + 12))):
            m.put(x, 0, z, pulido(x, 0, z))
    canopy(m, -8, 5, 3, 2.0, 3.8, frames=(-2,), power=2.2)
    return finish('P51', m, 20, 0, 0, 4, 7, (50, 52, 58), (36, 36, 40), (70, 70, 76))


# ====================================================================================== Ju 87 G Stuka
def stuka(team=None):
    accent = team or YELLOW
    top = camo((50, 64, 44), (66, 82, 50), 4.0, 51, 0.94)
    under = (150, 175, 190)
    m = Model()

    def body(x, y, z, zc, hw, ht, hb):
        if x >= 19:
            return accent
        if x >= 15 and z > zc - hb * 0.4:
            return accent if x >= 17 else BLACK
        if z < zc - hb * 0.3:
            return under
        return top(x, y, z)

    m.fuselage([(22, 0.3, 0.3, 0.3, 0), (20, 1.8, 1.8, 1.8, 0), (17, 2.4, 2.6, 2.2, 0), (10, 2.4, 2.8, 2.4, 0),
                (6, 2.6, 3.6, 2.8, 0.3), (-4, 2.3, 4.4, 2.6, 0.6), (-10, 1.8, 3.0, 2.0, 0.5), (-16, 1.2, 2.0, 1.4, 0.3),
                (-22, 0.5, 1.0, 0.5, 0.5)], body)
    gull = lambda y: -round(3 * min(y, 8) / 8) + (round(4 * (y - 8) / 19) if y > 8 else 0)
    m.wing(2, 27, lambda y: 4 - 0.02 * y, lambda y: 11 - 0.17 * y, 0, 0.0, lambda y: 2,
           top=lambda x, y, z: accent if abs(y) >= 26 else top(x, y, z), bottom=lambda x, y, z: under, gull=gull)
    for sy in (1, -1):
        cross_top(m, 0, sy * 17, 3, BLACK, WHITE)
        cross_side(m, -12, sy * 2, 1, 2, BLACK, WHITE)
        # patas fijas con carenados
        m.box(-3, 3, sy * 7, sy * 8, -9, -4, sh(top(0, 0, 0), 0.9))
        m.box(-3, 3, sy * 7, sy * 8, -11, -10, BLACK)
        # canones BK 37 bajo las alas
        m.box(-4, 6, sy * 12, sy * 12, gull(12) - 2, gull(12) - 1, METAL_DARK)
        barrel(m, 7, 12, sy * 12, gull(12) - 1)
        for x in range(10, 14):
            m.put(x, sy * 3, 0 if x % 2 else -1, EXHAUST)
    m.wing(1, 9, lambda y: -17 - 0.1 * y, lambda y: 5 - 0.3 * y, 2, 0.0, lambda y: 1,
           top=lambda x, y, z: top(x, y, z), bottom=lambda x, y, z: under)
    m.fin(-14, 4, 15, lambda z: -14 - 0.3 * (z - 4), lambda z: 8 - 0.3 * (z - 4),
          lambda x, y, z: accent if (team and x < -20) else top(x, y, z))
    canopy(m, -13, 6, 4, 2.1, 3.6, frames=(-10, -7, -4, -1, 2, 5), power=2.2)
    return finish('Stuka' + ('_enemigo' if team else ''), m, 22, 0, 0, 3, 7, (50, 52, 58), (44, 42, 40), accent)


# ====================================================================================== Fw 190 A-8
def fw190(team=None):
    accent = team or (205, 190, 60)
    top = camo((88, 98, 92), (70, 78, 90), 3.5, 61, 0.94)
    light = (168, 186, 198)
    m = Model()

    def body(x, y, z, zc, hw, ht, hb):
        if x >= 16:
            return METAL_DARK
        if x >= 14 and z > zc - hb * 0.3:
            return accent
        if z < zc - hb * 0.3:
            return light
        if x in (-12, -13, -14) and team:
            return accent
        return top(x, y, z)

    m.fuselage([(18, 0.3, 0.3, 0.3, 0), (16, 2.6, 2.6, 2.6, 0), (14, 3.0, 3.1, 2.9, 0), (8, 2.9, 3.0, 2.8, 0),
                (4, 2.5, 3.6, 2.5, 0), (-2, 2.3, 3.4, 2.2, 0.2), (-9, 1.6, 2.4, 1.5, 0.4), (-18, 0.5, 1.0, 0.5, 0.9)],
               body)
    m.wing(2, 21, lambda y: 3 - 0.06 * y, lambda y: 10 - 0.25 * y, -1, 0.06, lambda y: 3 if y < 7 else 2,
           top=lambda x, y, z: top(x, y, z), bottom=lambda x, y, z: light)
    for sy in (1, -1):
        cross_top(m, 0, sy * 13, 3, BLACK, WHITE)
        cross_side(m, -8, sy * 2, 0, 2, BLACK, WHITE)
        barrel(m, 4, 7, sy * 5, -1)                                # canones MG 151 en la raiz del ala
        barrel(m, 3, 6, sy * 9, -1)                                # y en el ala
        m.box(0, 4, sy * 9, sy * 9, -2, -2, METAL_DARK)
        m.box(4, 8, sy * 1, sy * 1, 3, 3, METAL_DARK)              # MG 131 sobre el capo
    m.wing(1, 8, lambda y: -13 - 0.15 * y, lambda y: 5 - 0.3 * y, 2, 0.0, lambda y: 1,
           top=lambda x, y, z: top(x, y, z), bottom=lambda x, y, z: light)
    m.fin(-13, 3, 12, lambda z: -12 - 0.55 * (z - 3), lambda z: 7 - 0.4 * (z - 3),
          lambda x, y, z: top(x, y, z))
    canopy(m, -5, 6, 3, 2.1, 3.7, frames=(-3, 0, 3), power=2.2)
    return finish('Fw190' + ('_enemigo' if team else ''), m, 18, 0, 0, 3, 8, METAL_DARK, (36, 36, 40), accent)


MODELOS = {
    'Bf109': lambda: bf109(), 'Bf109_enemigo': lambda: bf109(TEAM_ENEMY),
    'Zero': lambda: zero(), 'Zero_enemigo': lambda: zero(TEAM_ENEMY),
    'Spitfire': lambda: spitfire(),
    'P51': lambda: p51(),
    'Stuka': lambda: stuka(), 'Stuka_enemigo': lambda: stuka(TEAM_ENEMY),
    'Fw190': lambda: fw190(), 'Fw190_enemigo': lambda: fw190(TEAM_ENEMY),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    prev_dir = None
    if '--preview' in args:
        i = args.index('--preview')
        prev_dir = args[i + 1]
        args = args[:i] + args[i + 2:]
    names = args or list(MODELOS)
    path_json = os.path.join(OUT, 'aviones.json')
    fichas = json.load(open(path_json)) if os.path.exists(path_json) else {}
    for n in names:
        meta, v = MODELOS[n]()
        fichas[n] = meta
        if prev_dir:
            os.makedirs(prev_dir, exist_ok=True)
            preview(os.path.join(prev_dir, n + '.png'), v, 9)
    json.dump(fichas, open(path_json, 'w'), indent=1)
