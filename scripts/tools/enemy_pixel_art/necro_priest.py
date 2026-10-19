"""亡灵牧师 - hunched grave priest: porcelain death mask, iron mitre with soul
candles, moth-eaten funeral cassock with brass trim, swinging a censer.

Fine grain (exported x2), faces right.  Rows: idle (6), cast (6).
"""
from __future__ import annotations

import math

import numpy as np

from pixelkit import Canvas, hex_color, mix, ramp

W, H = 108, 154
FRAMES = 6
GROUND = 136
TOP = 12  # headroom for the mitre and raised censer

CASSOCK = ramp("#121014", "#1f1b21", "#2e2830", "#423a42", "#5a5057")
LINING = ramp("#2a0f12", "#4a1a1d", "#6c2a2a")
BRASS = ramp("#3d2a12", "#6e4f20", "#a5803a", "#d6b660", "#f4e3a0")
IRON = ramp("#17171c", "#2b2b33", "#44444f", "#626270", "#8a8a98")
MASK = ramp("#5e574b", "#958c7a", "#c4bba6", "#e6dfcc", "#fbf7ec")
SKIN = ramp("#2b2a25", "#4a4840", "#6f6b5f", "#8f8a7b")
WAX = ramp("#8a7f66", "#bfb497", "#e4dcc3")
SOUL = hex_color("#6effc8")
SOUL_CORE = hex_color("#e4fff3")
SMOKE = hex_color("#5fcfae")


def _censer(c: Canvas, hand, swing, chain_len, phase, casting):
    angle = math.pi / 2 + swing
    pot = (hand[0] + math.cos(angle) * chain_len, hand[1] + math.sin(angle) * chain_len)
    for k in range(int(chain_len / 2.2)):
        t = k / (chain_len / 2.2)
        x = hand[0] + (pot[0] - hand[0]) * t
        y = hand[1] + (pot[1] - hand[1]) * t
        c.px(x, y, BRASS[1] if k % 2 else BRASS[3])
    body = c.ellipse(pot[0], pot[1] + 6, 7, 6.5) | c.poly([(pot[0] - 4, pot[1] + 1), (pot[0] + 4, pot[1] + 1), (pot[0] + 2, pot[1] - 2), (pot[0] - 2, pot[1] - 2)])
    c.sphere(pot[0] - 1, pot[1] + 4, 8, 8, BRASS, mask=body)
    c.fill(c.rect(int(pot[0] - 7), int(pot[1] + 5), 15, 1) & body, BRASS[1])
    for dx in (-4, 0, 4):
        c.fill(c.ellipse(pot[0] + dx, pot[1] + 8, 1.1, 1.3), CASSOCK[0])
    c.fill(c.rect(int(pot[0] - 1), int(pot[1] + 12), 3, 2), BRASS[2])
    return pot


def draw(frame: int, casting: bool) -> Canvas:
    c = Canvas(W, H)
    phase = frame / FRAMES * math.tau
    breathe = round(math.sin(phase) * 1.0)
    raise_t = min(1.0, frame / 2.0) if casting else 0.0
    oy = breathe

    # Back arm with a skull rosary hanging from the fingers.
    back_hand = (24, 78 + oy - raise_t * 16)
    back_sleeve = c.taper([(38, 52 + oy), (28, 64 + oy), back_hand], 13, 10)
    c.shade(back_sleeve, [mix(col, hex_color("#000000"), 0.35) for col in CASSOCK], depth=1, highlight=0)
    for k in range(6):
        bx = back_hand[0] - 1 + math.sin(phase + k * 0.6) * 0.8
        by = back_hand[1] + 4 + k * 3.2
        c.fill(c.ellipse(bx, by, 1.4, 1.4), MASK[2] if k % 2 else BRASS[2])
    skull_bead = c.ellipse(back_hand[0] - 1, back_hand[1] + 25, 2.6, 2.4)
    c.fill(skull_bead, MASK[3])
    c.px(back_hand[0] - 2, back_hand[1] + 25, CASSOCK[0])
    c.px(back_hand[0], back_hand[1] + 25, CASSOCK[0])

    # Cassock: hunched bell that drags on the ground, ragged hem.
    hem = []
    for k in range(11):
        x = 16 + k * 7
        hem.append((x, GROUND + (3 if k % 2 else -1) + round(math.sin(phase + k) * 0.8)))
    cassock = c.poly([(40, 44 + oy), (68, 42 + oy), (78, 70 + oy), (86, 104), (90, GROUND)] + hem[::-1] + [(14, GROUND), (22, 100), (30, 68 + oy)])
    c.shade(cassock, CASSOCK, depth=3, highlight=1)
    # Moth holes showing the red lining.
    for hx, hy in ((26, 112), (74, 120), (34, 126), (62, 98)):
        hole = c.ellipse(hx, hy, 2.2, 1.6) & cassock
        c.fill(hole, LINING[1])
        c.px(hx - 1, hy - 1, LINING[0])
    # Long folds.
    c.strokes(cassock, CASSOCK[1], [[(36, 72 + oy), (28, GROUND - 2)], [(70, 74 + oy), (80, GROUND - 2)], [(52, 90 + oy), (50, GROUND - 4)]], 2)
    c.strokes(cassock, CASSOCK[4], [[(40, 74 + oy), (33, GROUND - 4)], [(56, 92 + oy), (55, GROUND - 6)]])
    # Brass-embroidered front panel with a gate-of-the-dead sigil.
    panel = c.poly([(48, 52 + oy), (60, 52 + oy), (66, GROUND - 2), (42, GROUND - 2)])
    c.shade(panel, CASSOCK[1:], depth=1, highlight=0, edge=False)
    for side in (-1, 1):
        x0 = 54 + side * 6
        c.fill(c.line([(x0, 54 + oy), (54 + side * 12, GROUND - 3)], 2) & cassock, BRASS[2])
        c.fill(c.line([(x0 - side, 54 + oy), (54 + side * 11, GROUND - 3)]) & cassock, BRASS[1])
    arch = c.ellipse(54, 104, 6, 7) & ~c.ellipse(54, 104, 4, 5) & ~c.rect(0, 105, W, 20)
    c.fill(arch, BRASS[3])
    c.fill(c.rect(48, 104, 2, 10) | c.rect(58, 104, 2, 10), BRASS[3])
    c.fill(c.rect(53, 100, 2, 2), SOUL)
    hem_band = c.rect(0, GROUND - 4, W, 2) & cassock
    c.fill(hem_band, BRASS[2])

    # Shoulder cape with brass clasp.
    cape = c.poly([(30, 50 + oy), (44, 38 + oy), (66, 37 + oy), (80, 50 + oy), (76, 62 + oy), (54, 66 + oy), (34, 62 + oy)])
    c.shade(cape, CASSOCK, depth=2, highlight=1)
    c.fill(c.line([(32, 60 + oy), (54, 65 + oy), (76, 60 + oy)], 2), BRASS[2])
    clasp = c.ellipse(55, 60 + oy, 3.4, 3.4)
    c.sphere(54, 59 + oy, 4, 4, BRASS, mask=clasp)

    # Head: thin neck, porcelain death mask, tall iron mitre.
    neck = c.rect(53, 33 + oy, 9, 8)
    c.shade(neck, SKIN, depth=1, highlight=0)
    face = c.ellipse(61, 27 + oy, 10, 12)
    c.sphere(58, 23 + oy, 13, 14, MASK, mask=face)
    hx = 3  # head leans forward
    # Crack across the mask.
    c.fill(c.line([(52 + hx, 18 + oy), (55 + hx, 22 + oy), (53 + hx, 27 + oy), (56 + hx, 31 + oy)]), MASK[1])
    # Hollow eyes with tear streaks, thin slit mouth.
    for ex in (55 + hx, 63 + hx):
        eye = c.poly([(ex - 2.5, 23 + oy), (ex + 2.5, 22 + oy), (ex + 2, 27 + oy), (ex - 2, 27 + oy)])
        c.fill(eye, CASSOCK[0])
        c.fill(c.line([(ex, 28 + oy), (ex, 33 + oy)]), MASK[1])
    c.fill(c.line([(55 + hx, 34 + oy), (64 + hx, 34 + oy)]), CASSOCK[1])
    # Mitre.
    mitre = c.poly([(47 + hx, 17 + oy), (52 + hx, 1 + oy), (59 + hx, -6 + oy), (66 + hx, 1 + oy), (71 + hx, 17 + oy), (68 + hx, 20 + oy), (50 + hx, 20 + oy)])
    c.shade(mitre, IRON, depth=2, highlight=1)
    c.fill(c.rect(47 + hx, 15 + oy, 25, 3) & dilate_rect(c, mitre), BRASS[2])
    c.fill(c.line([(59 + hx, -4 + oy), (59 + hx, 14 + oy)], 2) & mitre, BRASS[2])
    c.fill(c.line([(55 + hx, 6 + oy), (63 + hx, 6 + oy)], 2) & mitre, BRASS[2])
    for rx in (50 + hx, 56 + hx, 62 + hx, 68 + hx):
        c.rivet(rx, 16 + oy, BRASS[1], BRASS[4])
    # Candles on the mitre's shoulders.
    candles = []
    for cx_, h in ((48 + hx, 9), (70 + hx, 7)):
        stick = c.rect(cx_ - 1, 14 + oy - h, 3, h)
        c.shade(stick, WAX, depth=1, highlight=0, edge=False)
        c.px(cx_, 14 + oy - h + 2, WAX[2])
        c.px(cx_ + 1, 14 + oy - h + 4, WAX[0])
        candles.append((cx_ + 0.5, 14 + oy - h - 2))

    # Front arm swinging the censer.
    hand = (84, 56 + oy - raise_t * 26)
    sleeve = c.taper([(66, 48 + oy), (78, 54 + oy - raise_t * 12), hand], 14, 11)
    c.shade(sleeve, CASSOCK, depth=2, highlight=1)
    cuff = c.taper([(80, 55 + oy - raise_t * 22), hand], 10, 10) & sleeve
    c.fill(cuff & ~c.taper([(80.5, 55 + oy - raise_t * 22), hand], 7, 7), BRASS[2])
    claw = c.ellipse(hand[0] + 2, hand[1] + 1, 3.2, 3)
    c.shade(claw, SKIN, depth=1, highlight=1)
    swing = math.sin(phase) * 0.45 if not casting else math.sin(phase * 2) * 0.2
    pot = _censer(c, (hand[0] + 3, hand[1] + 2), swing, 26 if not casting else 18, phase, casting)

    c.outline(darkness=0.2, tint=(0.05, 0.04, 0.06))

    # Soul light: eyes, candle flames, censer smoke.
    eye_color = SOUL_CORE if casting else SOUL
    for ex in (58, 66):
        c.glow(ex, 25 + oy, 3.2, SOUL, 0.4 if not casting else 0.6)
        c.fill(c.rect(ex - 1, 24 + oy, 2, 2), eye_color)
    flame_scale = 1.0 + raise_t * 0.7
    for fx, fy in candles:
        flick = math.sin(phase * 3 + fx) * 0.8
        c.glow(fx, fy, 4 * flame_scale, SOUL, 0.35)
        flame = c.poly([(fx - 1.6 * flame_scale, fy + 2), (fx + flick * 0.5, fy - 4.5 * flame_scale), (fx + 1.6 * flame_scale, fy + 2)])
        c.fill(flame, SOUL)
        c.fill(c.ellipse(fx, fy + 0.5, 0.9, 1.4), SOUL_CORE)
    c.glow(pot[0], pot[1] + 7, 6 + raise_t * 4, SOUL, 0.25 + raise_t * 0.2)
    for k in range(4):
        t = (frame / FRAMES + k / 4) % 1.0
        sx = pot[0] - 2 + math.sin(t * 5 + k * 1.7) * (3 + t * 4)
        sy = pot[1] + 2 - t * (22 + raise_t * 10)
        puff = c.ellipse(sx, sy, 1.5 + t * 2.5, 1.2 + t * 2)
        c.fill(puff, SMOKE, 0.7 * (1 - t))
    if casting:
        c.glow(back_hand[0], back_hand[1], 4, SOUL, 0.5)
    c.rgba = np.roll(c.rgba, TOP, axis=0)
    return c


def dilate_rect(c: Canvas, mask):
    from pixelkit import dilate
    return dilate(mask, 1)


def build():
    return {
        "idle": [draw(i, False) for i in range(FRAMES)],
        "cast": [draw(i, True) for i in range(FRAMES)],
    }
