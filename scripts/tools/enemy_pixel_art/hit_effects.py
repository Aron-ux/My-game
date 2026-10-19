"""Hit effects for the six reworked monsters: a short material-specific burst
played where the monster is struck (5 frames, 40x40 art px, exported x2 like
the bodies).  Each sheet has one row.

    porcupine     fur tufts + snapped quill splinters
    necro_priest  porcelain mask chips + soul sparks
    shadow_tree   bark chips + violet sap
    young         violet husk shards + sap
    vine          green sap splash + leaf bits
    skull_mage    bone chips + cyan arcane sparks
"""
from __future__ import annotations

import math

from pixelkit import Canvas, hex_color, ramp

FRAMES = 5
SIZE = 40

WHITE = hex_color("#ffffff")


def _impact_star(c: Canvas, cx, cy, t, color, core):
    """Bright four-point impact flash in the first frames."""
    if t > 0.45:
        return
    size = 9 * (1 - t / 0.45) + 3
    for dx, dy in ((1, 0), (-1, 0), (0, 0.8), (0, -0.8)):
        c.fill(c.taper([(cx, cy), (cx + dx * size, cy + dy * size)], 3, 1), color, 0.9)
    c.fill(c.ellipse(cx, cy, 2.5, 2.5), core)


def _ring(c: Canvas, cx, cy, t, color):
    r = 4 + t * 14
    ring = c.ellipse(cx, cy, r, r * 0.8) & ~c.ellipse(cx, cy, r - 1.5, r * 0.8 - 1.5)
    c.fill(ring, color, max(0.0, 0.85 - t))


def _debris(c: Canvas, cx, cy, t, count, colors, seed, gravity=10.0, speed=15.0, shape="chip"):
    for k in range(count):
        a = -math.pi * 0.95 + (k + 0.5) / count * math.pi * 1.9 + math.sin(seed + k * 2.3) * 0.25
        v = speed * (0.6 + 0.4 * ((k * 7 + seed) % 5) / 4)
        x = cx + math.cos(a) * v * t
        y = cy + math.sin(a) * v * t * 0.8 + gravity * t * t
        color = colors[k % len(colors)]
        alpha = 1.0 if t < 0.6 else max(0.0, 1.0 - (t - 0.6) / 0.4)
        if shape == "chip":
            c.fill(c.rect(int(x), int(y), 2, 2), color, alpha)
            c.px(x + 1, y, colors[-1], alpha * 0.7)
        elif shape == "tuft":
            c.fill(c.line([(x, y), (x - math.cos(a) * 3, y - math.sin(a) * 3)]), color, alpha)
        elif shape == "splinter":
            c.fill(c.line([(x, y), (x + math.cos(a + 0.6) * 4, y + math.sin(a + 0.6) * 4)]), color, alpha)
        elif shape == "drop":
            c.fill(c.ellipse(x, y, 1.4, 1.8), color, alpha)
        elif shape == "spark":
            c.px(x, y, color, alpha)
            c.px(x - math.cos(a), y - math.sin(a), color, alpha * 0.5)
        elif shape == "leaf":
            c.fill(c.poly([(x - 2, y), (x, y - 1.5), (x + 2, y), (x, y + 1.5)]), color, alpha)


def porcupine(frame: int) -> Canvas:
    c = Canvas(SIZE, SIZE)
    t = frame / (FRAMES - 1)
    fur = ramp("#3f2717", "#83552c", "#c99a5a")
    quill = ramp("#1f1a1b", "#efe7d0")
    _impact_star(c, 20, 20, t, hex_color("#ffe2b0"), WHITE)
    _debris(c, 20, 20, t, 9, fur, seed=1, shape="tuft")
    _debris(c, 20, 20, t, 4, quill, seed=4, speed=18, gravity=6, shape="splinter")
    return c


def necro_priest(frame: int) -> Canvas:
    c = Canvas(SIZE, SIZE)
    t = frame / (FRAMES - 1)
    porcelain = ramp("#958c7a", "#e6dfcc", "#fbf7ec")
    soul = [hex_color("#6effc8"), hex_color("#e4fff3")]
    _impact_star(c, 20, 20, t, hex_color("#c9fff0"), WHITE)
    _ring(c, 20, 20, t, hex_color("#6effc8"))
    _debris(c, 20, 20, t, 6, porcelain, seed=2, shape="chip")
    _debris(c, 20, 20, t, 6, soul, seed=7, gravity=-8, speed=12, shape="spark")
    return c


def shadow_tree(frame: int) -> Canvas:
    c = Canvas(SIZE, SIZE)
    t = frame / (FRAMES - 1)
    bark = ramp("#41372b", "#7a6b55", "#9a8a70")
    sap = [hex_color("#9763b8"), hex_color("#c58cff")]
    _impact_star(c, 20, 20, t, hex_color("#efe0c8"), WHITE)
    _debris(c, 20, 20, t, 7, bark, seed=3, shape="splinter")
    _debris(c, 20, 20, t, 5, sap, seed=9, gravity=14, speed=11, shape="drop")
    return c


def young(frame: int) -> Canvas:
    c = Canvas(SIZE, SIZE)
    t = frame / (FRAMES - 1)
    husk = ramp("#4a2a62", "#6e3f8e", "#9763b8")
    _impact_star(c, 20, 20, t, hex_color("#ead6ff"), WHITE)
    _debris(c, 20, 20, t, 7, husk, seed=5, shape="chip")
    _debris(c, 20, 20, t, 4, [hex_color("#c58cff")], seed=11, gravity=14, speed=10, shape="drop")
    return c


def vine(frame: int) -> Canvas:
    c = Canvas(SIZE, SIZE)
    t = frame / (FRAMES - 1)
    sap = [hex_color("#9cc33a"), hex_color("#d6f27a")]
    leaf = [hex_color("#355226"), hex_color("#6d9244")]
    _impact_star(c, 20, 20, t, hex_color("#efffc0"), WHITE)
    # Sap splash blob in the centre that spreads out.
    if t < 0.7:
        r = 3 + t * 6
        c.fill(c.ellipse(20, 20 + t * 3, r, r * 0.7), sap[0], 0.6 * (1 - t / 0.7))
    _debris(c, 20, 20, t, 8, sap, seed=6, gravity=16, speed=13, shape="drop")
    _debris(c, 20, 20, t, 4, leaf, seed=13, gravity=4, speed=14, shape="leaf")
    return c


def skull_mage(frame: int) -> Canvas:
    c = Canvas(SIZE, SIZE)
    t = frame / (FRAMES - 1)
    bone = ramp("#7a7466", "#d4cdb7", "#f1ecdd")
    arcane = [hex_color("#3fd0e6"), hex_color("#a8f6ff")]
    _impact_star(c, 20, 20, t, hex_color("#c8fbff"), WHITE)
    _ring(c, 20, 20, t, hex_color("#3fd0e6"))
    _debris(c, 20, 20, t, 6, bone, seed=8, shape="chip")
    _debris(c, 20, 20, t, 6, arcane, seed=12, gravity=-4, speed=16, shape="spark")
    return c


def build():
    return {
        "porcupine/porcupine_hit": [[porcupine(i) for i in range(FRAMES)]],
        "necropriest/necro_priest_hit": [[necro_priest(i) for i in range(FRAMES)]],
        "plants/shadow_tree_hit": [[shadow_tree(i) for i in range(FRAMES)]],
        "plants/shadow_tree_young_hit": [[young(i) for i in range(FRAMES)]],
        "plants/vine_hit": [[vine(i) for i in range(FRAMES)]],
        "skullmage/skull_mage_hit": [[skull_mage(i) for i in range(FRAMES)]],
    }
