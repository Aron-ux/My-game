"""幽影树怪 / 幽影树怪·幼年.

New direction: a stooped, ancient grey-brown willow-oak that shuffles on a
skirt of roots, wearing a carved dead-wood mask; its hollow trunk holds a
shadow heart, and violet seed-pods (the ones it throws) hang from drooping
mossy branches.  The young one is a pod that sprouted legs and a leaf cap.

Fine grain (exported x2), faces right.
Tree rows: walk (6), throw (6).  Young rows: run (6).
(The thrown tree seed lives in effects.py and is unchanged.)
"""
from __future__ import annotations

import math

import numpy as np

from pixelkit import Canvas, hex_color, mix, ramp

BARK = ramp("#17130f", "#2a231b", "#41372b", "#5c4f3e", "#7a6b55", "#9a8a70")
DEADWOOD = ramp("#3e3a33", "#6b665a", "#9a9482", "#c5bfac", "#e3decd")
MOSS = ramp("#1c2a18", "#2e4424", "#466233", "#638346", "#86a65e")
HANG = ramp("#202c1c", "#34452b", "#4d6240")
POD = ramp("#2a1838", "#4a2a62", "#6e3f8e", "#9763b8")
SHADOW = hex_color("#0b0710")
GLOW = hex_color("#c58cff")
GLOW_CORE = hex_color("#f2e2ff")
EYE = hex_color("#e9d6ff")

TREE_W, TREE_H = 152, 158
TREE_TOP = 8  # headroom for the canopy
YOUNG_W, YOUNG_H = 80, 72
FRAMES = 6


def _limb(c: Canvas, points, w0, w1, colors=BARK, depth=1):
    mask = c.taper(points, w0, w1)
    c.shade(mask, colors, depth=depth, highlight=1)
    return mask


def _bark_grain(c: Canvas, mask, x0, x1, y0, y1, seed):
    rng = np.random.default_rng(seed)
    for x in range(int(x0), int(x1), 4):
        wobble = rng.uniform(-1.5, 1.5)
        pts = [(x + wobble, y0), (x + wobble * 0.5 + rng.uniform(-1, 1), (y0 + y1) / 2), (x - wobble, y1)]
        c.fill(c.line(pts) & mask, BARK[1])
        c.fill(c.line([(p[0] + 1, p[1]) for p in pts]) & mask & ~c.line(pts), BARK[3], 0.5)


def _moss_cap(c: Canvas, mask, cut_y):
    cap = mask & (c.yy < cut_y)
    c.shade(cap, MOSS, depth=1, highlight=1, edge=False)
    # Ragged drip edge.
    for x in range(c.w):
        col = np.nonzero(cap[:, x])[0]
        if len(col) and (x * 7) % 5 < 2:
            y = col.max()
            c.fill(c.rect(x, y + 1, 1, 1 + (x * 3) % 3) & mask, MOSS[1])


def _hanging(c: Canvas, x, y, length, sway):
    pts = [(x, y), (x + sway * 0.5, y + length * 0.5), (x + sway, y + length)]
    c.fill(c.taper(pts, 2, 1), HANG[1])
    c.px(x + sway, y + length, HANG[2])


def draw_tree(frame: int, throwing: bool) -> Canvas:
    c = Canvas(TREE_W, TREE_H)
    phase = frame / FRAMES * math.tau
    oy = round(abs(math.sin(phase)) * -2)
    cx = 70
    ground = 142
    sway = math.sin(phase) * 2

    # Thick root-legs: three on each side, alternating.
    for k, (bx, spread) in enumerate(((cx - 18, -1.0), (cx - 6, -0.4), (cx + 6, 0.4), (cx + 18, 1.0))):
        step = math.sin(phase + k * math.pi) * 5
        lift = max(0.0, math.sin(phase + k * math.pi)) * 3
        knee = (bx + spread * 12 + step * 0.5, 120 + oy)
        foot = (bx + spread * 16 + step, ground - lift)
        _limb(c, [(bx, 104 + oy), knee, foot], 13, 5, depth=2)
        for toe in (-1, 1):
            c.fill(c.taper([foot, (foot[0] + toe * 6 + spread * 3, ground + 1)], 3, 1), BARK[2])

    # Weeping canopy behind the trunk: drooping masses of grey-green leaves.
    canopy = c.empty()
    for lx, ly, rx_, ry_ in ((cx - 30, 30, 22, 16), (cx + 28, 26, 24, 15), (cx - 4, 16, 28, 16), (cx - 42, 50, 12, 18), (cx + 44, 46, 12, 18)):
        canopy |= c.ellipse(lx + sway * 0.5, ly + oy, rx_, ry_)
    # Ragged lower edge.
    for x in range(c.w):
        col = np.nonzero(canopy[:, x])[0]
        if len(col):
            extra = 3 + int(3 * (1 + math.sin(x * 0.9 + phase)))
            canopy[col.max():min(c.h, col.max() + extra), x] = True
    c.sphere(cx - 10, 14 + oy, 70, 46, MOSS, mask=canopy, bands=(-0.3, 0.05, 0.4, 0.75))
    c.hatch(canopy, MOSS[1], 5, 1.7, 3, seed=2)
    c.hatch(canopy & (c.yy < 30 + oy), MOSS[4], 7, 1.6, 2, seed=9)

    # Back branch arm (drooping).
    back_arm = [(cx - 18, 58 + oy), (cx - 34, 62 + oy), (cx - 44, 76 + oy + sway * 0.5), (cx - 46, 90 + oy + sway)]
    _limb(c, back_arm, 12, 4)
    for k, (hx, hy) in enumerate(((cx - 38, 66), (cx - 45, 80))):
        _hanging(c, hx, hy + oy, 12 + k * 4, sway)

    # Hunched trunk leaning forward, flaring at the base.
    trunk = c.poly([
        (cx - 16, 34 + oy), (cx - 4, 26 + oy), (cx + 14, 28 + oy), (cx + 26, 40 + oy),
        (cx + 24, 62 + oy), (cx + 18, 84 + oy), (cx + 26, 106 + oy), (cx + 10, 110 + oy),
        (cx - 12, 110 + oy), (cx - 28, 106 + oy), (cx - 20, 84 + oy), (cx - 24, 60 + oy),
    ])
    c.shade(trunk, BARK, depth=3, highlight=2)
    _bark_grain(c, trunk, cx - 26, cx + 26, 28 + oy, 108 + oy, seed=4)
    # Twisting bark ridges.
    for k in range(3):
        x0 = cx - 14 + k * 12
        ridge = [(x0, 34 + oy), (x0 + 6, 60 + oy), (x0 - 2, 84 + oy), (x0 + 4, 106 + oy)]
        c.fill(c.line(ridge, 2) & trunk, BARK[3])
        c.fill(c.line([(p[0] + 2, p[1]) for p in ridge]) & trunk, BARK[1])
    # Moss collar where the canopy meets the trunk.
    collar = trunk & (c.yy < 40 + oy)
    c.shade(collar, MOSS, depth=1, highlight=1, edge=False)
    # Knots.
    for kx, ky in ((cx - 15, 96), (cx + 17, 74)):
        knot = c.ellipse(kx, ky + oy, 3, 2.4)
        c.fill(knot, BARK[1])
        c.px(kx, ky + oy, BARK[0])
    # Hollow with the shadow heart.
    hollow = c.poly([(cx - 8, 70 + oy), (cx - 2, 62 + oy), (cx + 6, 64 + oy), (cx + 9, 78 + oy), (cx + 4, 92 + oy), (cx - 6, 92 + oy), (cx - 10, 82 + oy)])
    c.fill(hollow, SHADOW)
    c.fill(c.line([(cx - 9, 82 + oy), (cx - 8, 70 + oy), (cx - 2, 62 + oy)]) & hollow, BARK[0])

    # Dead-wood mask nailed onto the trunk.
    mask = c.poly([(cx - 8, 36 + oy), (cx + 16, 35 + oy), (cx + 18, 46 + oy), (cx + 12, 59 + oy), (cx + 4, 62 + oy), (cx - 4, 59 + oy), (cx - 10, 47 + oy)])
    c.shade(mask, DEADWOOD, depth=2, highlight=1)
    c.fill(c.line([(cx, 37 + oy), (cx - 2, 48 + oy)]) & mask, DEADWOOD[1])
    c.fill(c.line([(cx + 12, 38 + oy), (cx + 14, 49 + oy), (cx + 10, 57 + oy)]) & mask, DEADWOOD[1])
    # Angled, frowning eye slits and a jagged mouth.
    for ex, tilt in ((cx - 1, 1), (cx + 10, -1)):
        c.fill(c.poly([(ex - 3, 43 + oy - tilt), (ex + 3, 43 + oy + tilt), (ex + 2, 47 + oy), (ex - 2, 47 + oy)]), SHADOW)
    c.fill(c.poly([(cx - 1, 53 + oy), (cx + 1, 51 + oy), (cx + 3, 53 + oy), (cx + 5, 51 + oy), (cx + 7, 53 + oy), (cx + 9, 51 + oy), (cx + 10, 54 + oy), (cx + 6, 57 + oy), (cx + 2, 57 + oy)]), SHADOW)
    c.rivet(cx - 6, 40 + oy, BARK[0], DEADWOOD[2])
    c.rivet(cx + 15, 39 + oy, BARK[0], DEADWOOD[2])

    # Front arm: long drooping branch; lifts and flings when throwing.
    if throwing:
        t = frame / (FRAMES - 1)
        wind = math.sin(t * math.pi)
        elbow = (cx + 36, 46 + oy - wind * 14)
        hand = (cx + 48 + wind * 6, 30 + oy - wind * 18)
    else:
        elbow = (cx + 38, 62 + oy + sway * 0.3)
        hand = (cx + 48, 80 + oy + sway)
    front = [(cx + 18, 52 + oy), elbow, hand]
    _limb(c, front, 13, 4, depth=2)
    for k in range(3):
        a = -0.6 + k * 0.6
        tip = (hand[0] + math.cos(a + 1.2) * 7, hand[1] + math.sin(a + 1.2) * 7)
        c.fill(c.taper([hand, tip], 3, 1), BARK[3])
    if not throwing:
        _hanging(c, cx + 34, 60 + oy, 14, sway)
    # Violet seed-pods hanging in the crown and on the arm.
    pods = [(cx - 30, 40 + oy + sway * 0.5), (cx + 30, 36 + oy + sway * 0.5), (cx + 6, 28 + oy + sway * 0.5), (cx - 44, 94 + oy + sway)]
    if not throwing:
        pods.append((hand[0] - 2, hand[1] + 6))
    for px_, py_ in pods:
        c.fill(c.line([(px_, py_ - 5), (px_, py_ - 1)]), HANG[1])
        pod = c.ellipse(px_, py_ + 2, 3.2, 4)
        c.sphere(px_ - 1, py_ + 1, 4, 5, POD, mask=pod)

    c.outline(darkness=0.2, tint=(0.05, 0.04, 0.03))

    flicker = 0.5 + 0.5 * math.sin(phase * 2)
    for ex in (cx - 1, cx + 10):
        c.glow(ex, 45 + oy, 3.4, GLOW, 0.4 + 0.1 * flicker)
        c.fill(c.rect(ex - 1, 44 + oy, 2, 2), EYE)
    heart_y = 80 + oy
    c.glow(cx, heart_y, 7 + flicker * 2, GLOW, 0.3)
    c.fill(c.ellipse(cx, heart_y, 2.5 + flicker * 0.6, 3), GLOW)
    c.fill(c.rect(cx, heart_y - 1, 1, 2), GLOW_CORE)
    for px_, py_ in pods:
        c.px(px_ - 1, py_ + 1, GLOW, 0.9)
    if throwing:
        t = frame / (FRAMES - 1)
        if t < 0.85:
            c.glow(hand[0], hand[1], 5, GLOW, 0.5)
            seed = c.ellipse(hand[0], hand[1] + 1, 3.5, 4.2)
            c.sphere(hand[0] - 1, hand[1], 4.5, 5, POD, mask=seed)
            c.px(hand[0], hand[1], GLOW_CORE)
    c.rgba = np.roll(c.rgba, TREE_TOP, axis=0)
    return c


def draw_young(frame: int) -> Canvas:
    c = Canvas(YOUNG_W, YOUNG_H)
    phase = frame / FRAMES * math.tau
    hop = round(abs(math.sin(phase * 2)) * -3)
    cx, ground = 40, 66
    oy = hop

    # Six skittering root legs.
    for k in range(6):
        side = -1 if k < 3 else 1
        t = (k % 3) / 2
        step = math.sin(phase * 2 + k * 1.1) * 4
        hip = (cx + side * (4 + t * 7), 46 + oy + t * 2)
        knee = (cx + side * (13 + t * 9), 42 + oy + t * 3)
        foot = (cx + side * (11 + t * 10) + step, ground - max(0.0, math.sin(phase * 2 + k * 1.1)) * 3)
        _limb(c, [hip, knee, foot], 4.5 - t, 1.6, colors=BARK, depth=1)

    # Pod body (same violet pod as the thrown seed, now split open).
    body = c.ellipse(cx, 38 + oy, 17, 15)
    c.sphere(cx - 4, 33 + oy, 20, 18, POD, mask=body)
    for k in range(4):
        x = cx - 12 + k * 8
        c.fill(c.line([(x, 25 + oy), (x - 2 + k, 50 + oy)]) & body, POD[1])
    # Husk split showing a gaping maw.
    maw = c.poly([(cx - 9, 40 + oy), (cx + 11, 39 + oy), (cx + 8, 47 + oy), (cx - 6, 47 + oy)])
    c.fill(maw, SHADOW)
    for tx in range(cx - 7, cx + 9, 3):
        c.fill(c.poly([(tx, 40 + oy), (tx + 2, 40 + oy), (tx + 1, 43 + oy)]), DEADWOOD[3])
        c.fill(c.poly([(tx + 1, 47 + oy), (tx + 3, 47 + oy), (tx + 2, 44 + oy)]), DEADWOOD[2])
    # Leaf cap + sprout.
    sway = math.sin(phase) * 2
    cap = c.poly([(cx - 14, 28 + oy), (cx - 6, 18 + oy), (cx + 8, 17 + oy), (cx + 16, 27 + oy), (cx + 4, 25 + oy)])
    c.shade(cap, MOSS, depth=1, highlight=1)
    c.fill(c.taper([(cx, 19 + oy), (cx + sway * 0.4, 10 + oy)], 2.6, 1.6), BARK[3])
    for side in (-1, 1):
        leaf = c.poly([(cx + sway * 0.4, 11 + oy), (cx + side * 9 + sway, 3 + oy), (cx + side * 14 + sway, 7 + oy), (cx + side * 7 + sway, 12 + oy)])
        c.shade(leaf, MOSS, depth=1, highlight=1)
        c.fill(c.line([(cx + sway * 0.4, 11 + oy), (cx + side * 11 + sway, 6 + oy)]) & leaf, MOSS[1])

    c.outline(darkness=0.2, tint=(0.05, 0.03, 0.06))
    # Single big eye peeking above the maw.
    eye = (cx + 4, 33 + oy)
    c.glow(*eye, 4, GLOW, 0.45)
    c.fill(c.ellipse(*eye, 3, 2.6), EYE)
    c.fill(c.rect(int(eye[0]), int(eye[1]) - 1, 2, 3), SHADOW)
    c.glow(cx, 44 + oy, 4, GLOW, 0.25)
    return c


def build_tree():
    return {
        "walk": [draw_tree(i, False) for i in range(FRAMES)],
        "throw": [draw_tree(i, True) for i in range(FRAMES)],
    }


def build_young():
    return {"run": [draw_young(i) for i in range(FRAMES)]}
