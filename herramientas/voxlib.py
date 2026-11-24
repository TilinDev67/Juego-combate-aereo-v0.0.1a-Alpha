"""Biblioteca minima para modelar aviones de voxeles por codigo y guardarlos como .vox de MagicaVoxel.

Ejes del modelo: X hacia el morro, Y a lo ancho (simetrico respecto a Y = 0), Z hacia arriba.
Un voxel mide 0,25 m, como el IL-2 del juego.
"""
import math
import struct
import zlib

Color = tuple


def sh(c, k):
    """Oscurece (k < 1) o aclara (k > 1) un color."""
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))), max(0, min(255, int(c[2] * k))))


def mix(a, b, t):
    return (int(a[0] + (b[0] - a[0]) * t), int(a[1] + (b[1] - a[1]) * t), int(a[2] + (b[2] - a[2]) * t))


def hash01(x, y, z, salt=0):
    """Ruido determinista 0..1 por voxel (camuflaje, desgaste)."""
    h = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (salt * 2654435761)
    h &= 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def blotch(x, y, z, scale, salt):
    """Manchas suaves 0..1 (para camuflaje): ruido por celdas, mezclado con los vecinos."""
    fx, fy, fz = x / scale, y / scale, z / scale
    ix, iy, iz = math.floor(fx), math.floor(fy), math.floor(fz)
    tx, ty, tz = fx - ix, fy - iy, fz - iz
    tx, ty, tz = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty), tz * tz * (3 - 2 * tz)
    v = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (tx if dx else 1 - tx) * (ty if dy else 1 - ty) * (tz if dz else 1 - tz)
                v += w * hash01(ix + dx, iy + dy, iz + dz, salt)
    return v


class Model:
    def __init__(self):
        self.v = {}

    def put(self, x, y, z, c):
        self.v[(x, y, z)] = c

    def put_sym(self, x, y, z, c):
        self.v[(x, y, z)] = c
        self.v[(x, -y, z)] = c

    def get(self, x, y, z):
        return self.v.get((x, y, z))

    def box(self, x0, x1, y0, y1, z0, z1, c):
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    self.v[(x, y, z)] = c

    def box_sym(self, x0, x1, y0, y1, z0, z1, c):
        """Caja a un lado (y0..y1 >= 0) y su espejo."""
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                for z in range(z0, z1 + 1):
                    self.v[(x, y, z)] = c
                    self.v[(x, -y, z)] = c

    # ------------------------------------------------------------ fuselaje por secciones
    def fuselage(self, sections, colorfn, power=2.6):
        """sections: lista de (x, semiancho, alto_arriba, alto_abajo, z_centro) de morro a cola (x decreciente)."""
        sections = sorted(sections, key=lambda s: -s[0])
        for (xa, *pa), (xb, *pb) in zip(sections, sections[1:]):
            for x in range(xa, xb - 1, -1):
                t = 0.0 if xa == xb else (xa - x) / (xa - xb)
                hw, ht, hb, zc = [pa[i] + (pb[i] - pa[i]) * t for i in range(4)]
                if hw <= 0.05 and ht <= 0.05:
                    continue
                for y in range(-math.ceil(hw), math.ceil(hw) + 1):
                    for z in range(math.floor(zc - hb), math.ceil(zc + ht) + 1):
                        zr = z - zc
                        nz = zr / ht if zr >= 0 and ht > 0 else (-zr / hb if hb > 0 else 9)
                        ny = abs(y) / hw if hw > 0 else 9
                        if ny ** power + abs(nz) ** power <= 1.0 + 0.001:
                            self.v[(x, y, z)] = colorfn(x, y, z, zc, hw, ht, hb)

    # ------------------------------------------------------------ alas y superficies
    def wing(self, y_root, y_tip, x_le, chord, z_root, dihedral, thick, top, bottom, gull=None):
        """Ala simetrica. x_le(y), chord(y), thick(y) son funciones de la posicion en la envergadura (0..y_tip)."""
        for yy in range(y_root, y_tip + 1):
            xle = x_le(yy)
            ch = max(1, round(chord(yy)))
            th = max(1, round(thick(yy)))
            zb = z_root + round(dihedral * yy) + (gull(yy) if gull else 0)
            for x in range(int(round(xle)) - ch + 1, int(round(xle)) + 1):
                for k in range(th):
                    z = zb + k
                    c = top(x, yy, z) if k == th - 1 else bottom(x, yy, z)
                    self.v[(x, yy, z)] = c
                    self.v[(x, -yy, z)] = c

    def fin(self, x_base, z0, z1, x_le_of_z, chord_of_z, color, thick=1):
        """Deriva vertical (en el plano XZ, centrada en Y = 0)."""
        for z in range(z0, z1 + 1):
            xle = x_le_of_z(z)
            ch = max(1, round(chord_of_z(z)))
            for x in range(int(round(xle)) - ch + 1, int(round(xle)) + 1):
                for y in range(-(thick // 2), thick - thick // 2):
                    self.v[(x, y, z)] = color(x, y, z) if callable(color) else color

    def disc(self, x, y, z, r, c, axis='x'):
        """Disco de radio r perpendicular al eje dado (marcas: escarapelas, cruces)."""
        for a in range(-r, r + 1):
            for b in range(-r, r + 1):
                if a * a + b * b <= r * r + 0.5:
                    if axis == 'x':
                        self.v[(x, y + a, z + b)] = c
                    elif axis == 'y':
                        self.v[(x + a, y, z + b)] = c
                    else:
                        self.v[(x + a, y + b, z)] = c

    def ring(self, x, y, z, r0, r1, c, axis='z'):
        for a in range(-r1, r1 + 1):
            for b in range(-r1, r1 + 1):
                d2 = a * a + b * b
                if r0 * r0 - 0.5 <= d2 <= r1 * r1 + 0.5:
                    if axis == 'x':
                        self.v[(x, y + a, z + b)] = c
                    elif axis == 'y':
                        self.v[(x + a, y, z + b)] = c
                    else:
                        self.v[(x + a, y + b, z)] = c

    def top_z(self, x, y):
        zs = [k[2] for k in self.v if k[0] == x and k[1] == y]
        return max(zs) if zs else None


def prop_model(blades, radius, hub_color, blade_color, tip_color, width=2):
    """Helice de palas conicas en el plano YZ (x = 0). Devuelve ({(0,y,z): color}, hub) con el buje en (hub, hub)."""
    hub = radius + 2
    d = {}
    for b in range(blades):
        ang = math.pi * 2 * b / blades + math.pi / 2
        for r in range(1, radius + 1):
            w = max(1, round(width * (1.0 - 0.45 * r / radius)))
            for k in range(-(w // 2), w - w // 2):
                y = hub + round(r * math.cos(ang) - k * math.sin(ang))
                z = hub + round(r * math.sin(ang) + k * math.cos(ang))
                d[(0, y, z)] = tip_color if r > radius * 0.85 else blade_color
    for a in range(-1, 2):
        for b in range(-1, 2):
            d[(0, hub + a, hub + b)] = hub_color
    return d, hub


# ---------------------------------------------------------------- exportar .vox
def _chunk(cid, content=b'', children=b''):
    return cid + struct.pack('<II', len(content), len(children)) + content + children


def write_vox(path, models):
    """models: lista de {(x,y,z): (r,g,b)} con coordenadas >= 0 y < 256."""
    pal = []
    index = {}
    for m in models:
        for c in m.values():
            if c not in index:
                index[c] = len(pal) + 1
                pal.append(c)
    if len(pal) > 255:
        raise ValueError('demasiados colores: %d' % len(pal))
    kids = b''
    for m in models:
        xs = [k[0] for k in m]
        ys = [k[1] for k in m]
        zs = [k[2] for k in m]
        size = (max(xs) + 1, max(ys) + 1, max(zs) + 1)
        kids += _chunk(b'SIZE', struct.pack('<III', *size))
        body = struct.pack('<I', len(m))
        for (x, y, z), c in m.items():
            body += struct.pack('BBBB', x, y, z, index[c])
        kids += _chunk(b'XYZI', body)
    rgba = b''.join(struct.pack('BBBB', c[0], c[1], c[2], 255) for c in pal) + b'\x00\x00\x00\xff' * (256 - len(pal))
    kids += _chunk(b'RGBA', rgba)
    data = b'VOX ' + struct.pack('<I', 150) + _chunk(b'MAIN', b'', kids)
    open(path, 'wb').write(data)
    return len(pal)


# ---------------------------------------------------------------- vista previa PNG (sin librerias externas)
def _png(path, w, h, pix):
    raw = b''.join(b'\x00' + bytes(pix[y * w * 3:(y + 1) * w * 3]) for y in range(h))
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def _render(v, axes, scale, shade_fn):
    """Proyeccion ortografica con buffer de profundidad. axes = (horizontal, vertical, profundidad) con signos."""
    (ha, hs), (va, vs), (da, ds) = axes
    pts = []
    for k, c in v.items():
        pts.append((k[ha] * hs, k[va] * vs, k[da] * ds, c))
    minh = min(p[0] for p in pts); maxh = max(p[0] for p in pts)
    minv = min(p[1] for p in pts); maxv = max(p[1] for p in pts)
    w = (maxh - minh + 1) * scale
    h = (maxv - minv + 1) * scale
    depth = [[-10 ** 9] * w for _ in range(h)]
    img = [[(30, 34, 44)] * w for _ in range(h)]
    for ph, pv, pd, c in pts:
        col = shade_fn(c, pd)
        x0 = (ph - minh) * scale
        y0 = (maxv - pv) * scale
        for yy in range(y0, y0 + scale):
            for xx in range(x0, x0 + scale):
                if pd > depth[yy][xx]:
                    depth[yy][xx] = pd
                    img[yy][xx] = col
    return w, h, img


def preview(path, v, scale=8):
    """Cuatro vistas: lateral, superior, frontal y una isometrica. Escribe un PNG."""
    def shade(c, pd):
        return c
    views = [
        _render(v, ((0, 1), (2, 1), (1, 1)), scale, shade),        # lateral (X horizontal, Z vertical)
        _render(v, ((0, 1), (1, 1), (2, 1)), scale, shade),        # superior (X, Y)
        _render(v, ((1, 1), (2, 1), (0, 1)), scale, shade),        # frontal (Y, Z)
    ]
    # isometrica: cada voxel es un cuadrado con el tamano justo para no dejar huecos
    iso_pts = []
    for k, c in v.items():
        x, y, z = k
        iso_pts.append(((x - y) * 0.866, z + (x + y) * 0.5, x + y + z, c))
    minu = min(p[0] for p in iso_pts); maxv = max(p[1] for p in iso_pts)
    minv = min(p[1] for p in iso_pts); maxu = max(p[0] for p in iso_pts)
    side = int(scale * 1.25)
    iw = int((maxu - minu) * scale) + side + 1
    ih = int((maxv - minv) * scale) + side + 1
    idepth = [[-10 ** 9] * iw for _ in range(ih)]
    iimg = [[(30, 34, 44)] * iw for _ in range(ih)]
    for u, vv, dd, c in iso_pts:
        x0 = int((u - minu) * scale)
        y0 = int((maxv - vv) * scale)
        for yy in range(y0, min(y0 + side, ih)):
            for xx in range(x0, min(x0 + side, iw)):
                if dd > idepth[yy][xx]:
                    idepth[yy][xx] = dd
                    iimg[yy][xx] = c
    views.append((iw, ih, iimg))
    gap = 12
    W = max(vw for vw, _, _ in views[:2]) + views[2][0] + gap * 3
    top_row_h = max(views[0][1], views[3][1])
    H = top_row_h + max(views[1][1], views[2][1]) + gap * 3
    pix = bytearray([20, 22, 30] * W * H)

    def blit(view, ox, oy):
        vw, vh, img = view
        for y in range(vh):
            for x in range(vw):
                c = img[y][x]
                i = ((oy + y) * W + ox + x) * 3
                pix[i], pix[i + 1], pix[i + 2] = c

    blit(views[0], gap, gap)
    blit(views[3], gap * 2 + views[0][0], gap)
    blit(views[1], gap, top_row_h + gap * 2)
    blit(views[2], gap * 2 + views[1][0], top_row_h + gap * 2)
    _png(path, W, H, pix)
