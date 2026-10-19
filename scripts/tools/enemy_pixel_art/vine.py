"""藤蔓怪 - a walking pitcher plant: striped red-green pitcher body with a hinged
lid and fanged rim, nectar drooling, thorny whip tendrils, crawling on roots.

Fine grain (exported x2), faces right.  Rows: move (6), throw (6).
(Parasite seed / ring / burst / entangle live in effects.py and are unchanged.)
"""
from __future__ import annotations

import math

import numpy as np

from pixelkit import Canvas, hex_color, mix, ramp

W, H = 128, 136
FRAMES = 6
GROUND = 122
TOP = 10  # headroom for the open lid

STEM = ramp("#132112", "#22381c", "#355226", "#4d6f33", "#6d9244")
PITCHER = ramp("#1f2a12", "#384a1a", "#56702a", "#7c973b", "#a7bd57", "#cfdc86")
VEIN = ramp("#3a0f12", "#6a1a1e", "#952a2a", "#bd4a3a")
RIM = ramp("#3a1214", "#6e1f22", "#a23630", "#cf5d45", "#ef9a73")
FANG = ramp("#8e8566", "#cfc6a2", "#f4efda")
INSIDE = ramp("#0b0605", "#1e0d0a", "#3a1712")
NECTAR = ramp("#5f7a1c", "#9cc33a", "#d6f27a")
THORN = ramp("#5b5338", "#9a8f5e", "#cfc48a")
GLOW = hex_color("#c4f55a")
GLOW_CORE = hex_color("#f4ffd0")
POD = ramp("#2c3a14", "#4b6420", "#6f8d2c", "#97b83f")


def _thorny(c: Canvas, points, w0, w1, colors=STEM, every=5):
    mask = c.taper(points, w0, w1)
    c.shade(mask, colors, depth=1, highlight=1)
    total = 0.0
    for (x0, y0), (x1, y1) in zip(points, points[1:]):
        seg = math.hypot(x1 - x0, y1 - y0)
        if seg <= 0:
            continue
        nx, ny = -(y1 - y0) / seg, (x1 - x0) / seg
        d = every
        while d < seg:
            t = d / seg
            px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            side = 1 if int((total + d) / every) % 2 else -1
            width = w0 + (w1 - w0) * ((total + d) / max(1.0, _length(points)))
            base = (px + nx * side * width * 0.4, py + ny * side * width * 0.4)
            tip = (px + nx * side * (width * 0.5 + 3.5), py + ny * side * (width * 0.5 + 3.5) - 1)
            c.fill(c.taper([base, tip], 2.4, 0.8), THORN[1])
            c.px(tip[0], tip[1], THORN[2])
            d += every
        total += seg
    return mask


def _length(points):
    return sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(points, points[1:]))


def _whip(base, angle, length, curl, phase, segments=8):
    points = [base]
    for k in range(1, segments + 1):
        t = k / segments
        a = angle + curl * t * t + math.sin(phase + t * 3) * 0.3 * t
        px, py = points[-1]
        points.append((px + math.cos(a) * length / segments, py + math.sin(a) * length / segments))
    return points


def draw(frame: int, throwing: bool) -> Canvas:
    c = Canvas(W, H)
    phase = frame / FRAMES * math.tau
    cx = 58
    lurch = math.sin(phase * 2) * 1.5
    oy = round(lurch)

    # Root feet: a tangle that pulls the plant along.
    for k in range(6):
        t = k / 5
        bx = cx - 18 + t * 36
        reach = math.sin(phase + k * 1.3) * 5
        lift = max(0.0, math.sin(phase + k * 1.3)) * 3
        mid = (bx + (t - 0.5) * 14, 108 + oy)
        tip = (bx + (t - 0.5) * 34 + reach, GROUND - lift)
        root = c.taper([(bx, 96 + oy), mid, tip], 7, 2)
        c.shade(root, STEM, depth=1, highlight=0)
        c.fill(c.taper([tip, (tip[0] + (t - 0.5) * 8, GROUND + 1)], 2, 1), STEM[1])

    # Back whip.
    back = _whip((cx - 18, 70 + oy), math.pi * 1.1, 34, -1.6, phase + 1.2)
    _thorny(c, back, 7, 2, colors=[mix(col, hex_color("#000000"), 0.3) for col in STEM])

    # Big leaves at the base.
    for side, ang in ((-1, 2.6), (1, 0.45)):
        a = ang + math.sin(phase + side) * 0.08
        base = (cx + side * 8, 98 + oy)
        tip = (base[0] + math.cos(a) * 30, base[1] + math.sin(a) * 12 - 4)
        normal = (-math.sin(a) * 7, math.cos(a) * 7)
        leaf = c.poly([base, (base[0] + (tip[0] - base[0]) * 0.5 + normal[0], base[1] + (tip[1] - base[1]) * 0.5 - abs(normal[1]) - 2), tip,
                       (base[0] + (tip[0] - base[0]) * 0.55, base[1] + (tip[1] - base[1]) * 0.5 + 3)])
        c.shade(leaf, STEM, depth=1, highlight=1)
        c.fill(c.line([base, tip]) & leaf, STEM[1])

    # Pitcher body: a tall swollen urn, slightly tilted forward.
    body = c.poly([(cx - 14, 96 + oy), (cx - 22, 78 + oy), (cx - 22, 58 + oy), (cx - 16, 40 + oy), (cx - 6, 30 + oy),
                   (cx + 14, 28 + oy), (cx + 22, 36 + oy), (cx + 24, 58 + oy), (cx + 22, 80 + oy), (cx + 14, 96 + oy)])
    c.sphere(cx - 6, 52 + oy, 34, 48, PITCHER, mask=body, bands=(-0.35, -0.05, 0.25, 0.5, 0.75))
    # Red veins: a few branching lines fading out towards the base.
    for k, x0 in enumerate((cx - 12, cx - 2, cx + 9)):
        vein = [(x0 + 1, 82 + oy), (x0 - 1 + k, 64 + oy), (x0 + 1, 48 + oy), (x0 + (k - 1) * 3, 34 + oy)]
        c.fill(c.line(vein) & body, VEIN[2])
        branch = [(x0 - 1 + k, 60 + oy), (x0 + 5, 52 + oy)]
        c.fill(c.line(branch) & body, VEIN[1])
    # Blush of red around the upper third.
    c.fill(body & (c.yy < 46 + oy) & ~c.ellipse(cx - 10, 44 + oy, 8, 10), VEIN[2], 0.35)

    # Speckles near the top (translucent windows of a real pitcher).
    for k in range(9):
        sx = cx - 14 + (k * 7) % 30
        sy = 38 + (k * 5) % 16 + oy
        c.fill(c.rect(sx, sy, 2, 1) & body, PITCHER[5])
    # Ventral wing ridge.
    ridge = c.line([(cx + 20, 40 + oy), (cx + 23, 60 + oy), (cx + 20, 86 + oy)], 2) & body
    c.fill(ridge, PITCHER[1])

    # Mouth: fanged red rim + hinged lid. The lid opens wide when throwing.
    if throwing:
        t = frame / (FRAMES - 1)
        open_amount = math.sin(t * math.pi)
    else:
        open_amount = 0.35 + 0.15 * math.sin(phase)
    rim_y = 32 + oy
    mouth = c.ellipse(cx + 4, rim_y, 17, 6)
    c.fill(mouth, INSIDE[0])
    c.fill(c.ellipse(cx + 4, rim_y + 1.5, 13, 3.5), INSIDE[1])
    rim = c.ellipse(cx + 4, rim_y, 19, 7.5) & ~c.ellipse(cx + 4, rim_y - 1, 15, 4.5)
    c.shade(rim, RIM, depth=1, highlight=1)
    # Fangs around the rim (peristome teeth).
    for k in range(11):
        a = math.pi * (0.05 + 0.9 * k / 10)
        bx = cx + 4 + math.cos(a) * 16
        by = rim_y + math.sin(a) * 5
        c.fill(c.poly([(bx - 1.2, by - 1), (bx + 1.2, by - 1), (bx, by + 3)]), FANG[1])
        c.px(bx, by, FANG[2])
    # Lid hinged at the back of the rim.
    hinge = (cx - 12, rim_y - 3)
    lid_angle = -0.15 - open_amount * 1.1
    lid_len = 30
    tip = (hinge[0] + math.cos(lid_angle) * lid_len, hinge[1] + math.sin(lid_angle) * lid_len)
    normal = (math.cos(lid_angle - math.pi / 2) * 8, math.sin(lid_angle - math.pi / 2) * 8)
    lid = c.poly([hinge, (hinge[0] + normal[0], hinge[1] + normal[1]),
                  (hinge[0] + (tip[0] - hinge[0]) * 0.6 + normal[0] * 1.2, hinge[1] + (tip[1] - hinge[1]) * 0.6 + normal[1] * 1.2),
                  tip, (hinge[0] + (tip[0] - hinge[0]) * 0.5, hinge[1] + (tip[1] - hinge[1]) * 0.5 + 2)])
    c.shade(lid, PITCHER, depth=1, highlight=1)
    c.fill(c.line([hinge, tip]) & lid, VEIN[2])
    for k in range(3):
        t = 0.3 + k * 0.22
        c.px(hinge[0] + (tip[0] - hinge[0]) * t + normal[0] * 0.5, hinge[1] + (tip[1] - hinge[1]) * t + normal[1] * 0.5, VEIN[3])

    # Nectar drool from the front of the rim.
    drool_len = 6 + 3 * math.sin(phase)
    drool = c.taper([(cx + 18, rim_y + 4), (cx + 19, rim_y + 4 + drool_len)], 2, 1.4)
    c.fill(drool, NECTAR[1])
    c.fill(c.ellipse(cx + 19, rim_y + 5 + drool_len, 1.6, 1.8), NECTAR[2])

    # Front whip: lashes forward on throw, otherwise coils and sways.
    if throwing:
        t = frame / (FRAMES - 1)
        front = _whip((cx + 18, 64 + oy), -2.1 + t * 2.6, 40, 0.6, phase)
    else:
        front = _whip((cx + 18, 66 + oy), -0.3 + math.sin(phase) * 0.25, 34, 1.9, phase)
    _thorny(c, front, 8, 2)

    c.outline(darkness=0.2, tint=(0.04, 0.05, 0.03))

    # Eyes glowing deep inside the pitcher.
    eye_y = rim_y + 1
    for ex in (cx, cx + 8):
        c.glow(ex, eye_y, 3, GLOW, 0.5)
        c.fill(c.rect(ex - 1, eye_y, 3, 1), GLOW)
        c.px(ex, eye_y, GLOW_CORE)
    if throwing:
        t = frame / (FRAMES - 1)
        if t < 0.8:
            tx, ty = front[-1]
            c.glow(tx, ty, 4, GLOW, 0.5)
            pod = c.ellipse(tx, ty, 3.5, 3.8)
            c.sphere(tx - 1, ty - 1, 4.5, 5, POD, mask=pod)
            c.px(tx, ty, GLOW_CORE)
    # Nectar droplet sparkle.
    c.px(cx + 18, rim_y + 5 + drool_len, GLOW_CORE, 0.8)
    c.rgba = np.roll(c.rgba, TOP, axis=0)
    return c


def build():
    return {
        "move": [draw(i, False) for i in range(FRAMES)],
        "throw": [draw(i, True) for i in range(FRAMES)],
    }
