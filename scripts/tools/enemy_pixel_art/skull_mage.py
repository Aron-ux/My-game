"""骷髅法师 - a bone scholar: a tall skeleton in a patched slate-blue scholar's
coat and fur-trimmed collar, horned skull with a rusty iron circlet, an open
grimoire chained to its hip and a forked bone staff holding a cyan crystal.

Fine grain (exported x2), faces right.
Rows: walk, cast, walk_ice, cast_ice (6 frames each).
"""
from __future__ import annotations

import math

import numpy as np

from pixelkit import Canvas, hex_color, mix, ramp

W, H = 112, 160
FRAMES = 6
GROUND = 144
TOP = 10  # headroom for the raised staff

COAT = ramp("#14181f", "#222935", "#323c4c", "#465366", "#5f6d82")
COAT_ICE = ramp("#13263a", "#1d3d5c", "#2b5a82", "#4381ad", "#73b1d8")
PATCH = ramp("#2a2018", "#4a3826", "#6b5236")
FUR = ramp("#3d3a35", "#6b665c", "#9a9486", "#c7c1b0")
FUR_ICE = ramp("#5d7486", "#93b4c8", "#c6e2ef", "#f0fbff")
BONE = ramp("#4a463d", "#7a7466", "#aaa38f", "#d4cdb7", "#f1ecdd")
BONE_ICE = ramp("#4d6878", "#7c9db0", "#aacbdc", "#d4ecf5", "#f2fbff")
IRON = ramp("#1f1612", "#3d2a20", "#62402c", "#8a5b3a")
LEATHER = ramp("#1b1210", "#33221a", "#4e3426", "#6c4a34")
PAGE = ramp("#7c705a", "#b4a785", "#ddd2b2")
INK = hex_color("#2c4f5e")
EYE = hex_color("#5ff0ff")
EYE_CORE = hex_color("#e0feff")
CRYSTAL = ramp("#0f4d63", "#1b88a6", "#3fd0e6", "#a8f6ff")
FROST = ramp("#6fa8c8", "#a9dcf0", "#e2f8ff", "#ffffff")
VOID = hex_color("#07080c")


def draw(frame: int, casting: bool, ice: bool) -> Canvas:
    c = Canvas(W, H)
    phase = frame / FRAMES * math.tau
    coat = COAT_ICE if ice else COAT
    fur = FUR_ICE if ice else FUR
    bone = BONE_ICE if ice else BONE
    step = 0 if casting else math.sin(phase)
    bob = round(abs(math.sin(phase)) * -1.5) if not casting else 0
    raise_t = min(1.0, frame / 2.0) if casting else 0.0
    cx = 50

    # Skeletal legs under the coat (long stride).
    for side, offset in ((-1, 0.0), (1, math.pi)):
        s = 0 if casting else math.sin(phase + offset)
        knee = (cx + side * 4 + s * 4, 122 + bob)
        foot = (cx + side * 4 + s * 8, GROUND - 2 - max(0.0, math.cos(phase + offset)) * 3 * (not casting))
        shin = c.taper([(cx + side * 4, 108 + bob), knee, foot], 3.4, 3)
        c.shade(shin, bone if side > 0 else [mix(col, hex_color("#000000"), 0.3) for col in bone], depth=1, highlight=0)
        boot = c.poly([(foot[0] - 3, foot[1] - 3), (foot[0] + 3, foot[1] - 3), (foot[0] + 7, foot[1] + 1), (foot[0] - 3, foot[1] + 1)])
        c.shade(boot, LEATHER, depth=1, highlight=1)

    # Back arm: holds the grimoire open in front when casting.
    back_hand = (cx - 18 + raise_t * 26, 84 + bob - raise_t * 22)
    back_arm = c.taper([(cx - 12, 52 + bob), (cx - 18 + raise_t * 10, 70 + bob - raise_t * 8), back_hand], 9, 7)
    c.shade(back_arm, [mix(col, hex_color("#000000"), 0.3) for col in coat], depth=1, highlight=0)

    # Long scholar's coat, split at the front, patched.
    hem = [(cx - 20 + k * 5, 114 + bob + (2 if k % 2 else 0) + round(math.sin(phase + k) * 0.8)) for k in range(9)]
    body = c.poly([(cx - 12, 46 + bob), (cx + 14, 46 + bob), (cx + 20, 80 + bob), (cx + 22, 114 + bob)] + hem[::-1] + [(cx - 22, 112 + bob), (cx - 18, 80 + bob)])
    c.shade(body, coat, depth=3, highlight=1)
    split = c.poly([(cx + 2, 80 + bob), (cx + 6, 80 + bob), (cx + 10, 116 + bob), (cx - 2, 116 + bob)])
    c.fill(split & body, VOID)
    c.strokes(body, coat[1], [[(cx - 12, 64 + bob), (cx - 16, 112 + bob)], [(cx + 12, 64 + bob), (cx + 16, 112 + bob)]], 2)
    c.strokes(body, coat[4], [[(cx - 8, 66 + bob), (cx - 11, 110 + bob)]])
    patch = c.rect(cx - 16, 92 + bob, 8, 7) & body
    c.shade(patch, PATCH, depth=1, highlight=0)
    for k in range(4):
        c.px(cx - 16 + k * 2, 92 + bob, FUR[2])
    # Ribcage peeking through the open collar.
    chest = c.poly([(cx - 5, 50 + bob), (cx + 8, 50 + bob), (cx + 6, 70 + bob), (cx - 3, 70 + bob)])
    c.fill(chest, VOID)
    for k in range(5):
        y = 53 + k * 3.4 + bob
        c.fill(c.line([(cx - 3, y + 1), (cx + 1, y), (cx + 6, y + 1)]) & chest, bone[2])
    c.fill(c.line([(cx + 1, 51 + bob), (cx + 1, 69 + bob)]) & chest, bone[3])
    # Belt with a chain to the grimoire.
    belt = c.rect(cx - 19, 76 + bob, 40, 4) & body
    c.shade(belt, LEATHER, depth=1, highlight=1, edge=False)
    c.fill(c.rect(cx + 2, 76 + bob, 5, 4), IRON[2])
    c.px(cx + 4, 77 + bob, IRON[3])

    # Fur collar.
    collar = c.ellipse(cx + 1, 47 + bob, 19, 7)
    c.sphere(cx - 2, 44 + bob, 20, 10, fur, mask=collar)
    c.hatch(collar, fur[0], 3, 1.6, 2, seed=6)

    # Skull: elongated, with curling ram horns and an iron circlet.
    head_y = 28 + bob
    for side in (-1, 1):
        horn = c.taper([(cx + side * 6, head_y - 8), (cx + side * 14, head_y - 12), (cx + side * 17, head_y - 4), (cx + side * 13, head_y + 1)], 5, 2)
        c.shade(horn, bone, depth=1, highlight=1)
        for k in range(3):
            c.px(cx + side * (9 + k * 2.5), head_y - 11 + k * 2, bone[1])
    skull = c.ellipse(cx + 2, head_y - 3, 11, 11)
    c.sphere(cx - 1, head_y - 7, 14, 14, bone, mask=skull)
    jaw = c.poly([(cx - 4, head_y + 4), (cx + 11, head_y + 3), (cx + 10, head_y + 11), (cx - 2, head_y + 11)])
    c.shade(jaw, bone, depth=1, highlight=0)
    for tx in range(int(cx - 2), int(cx + 10), 2):
        c.px(tx, head_y + 6, VOID)
    c.fill(c.rect(cx - 3, head_y + 5, 13, 1), VOID)
    for ex in (cx - 2, cx + 6):
        c.fill(c.poly([(ex - 2.5, head_y - 5), (ex + 3, head_y - 6), (ex + 3, head_y), (ex - 2, head_y)]), VOID)
    c.fill(c.poly([(cx + 2, head_y + 1), (cx + 4, head_y + 1), (cx + 3, head_y + 3)]), VOID)
    circlet = c.rect(cx - 9, head_y - 12, 23, 3) & c.ellipse(cx + 2, head_y - 6, 13, 13)
    c.shade(circlet, IRON, depth=1, highlight=1, edge=False)
    gem = c.poly([(cx + 2, head_y - 15), (cx + 5, head_y - 11), (cx + 2, head_y - 8), (cx - 1, head_y - 11)])
    c.shade(gem, CRYSTAL, depth=1, highlight=1, edge=False)

    # Grimoire: open book held by the back hand (closed at the hip when walking).
    if casting:
        book_c = (back_hand[0] + 2, back_hand[1] - 2)
        for side in (-1, 1):
            page = c.poly([(book_c[0], book_c[1]), (book_c[0] + side * 10, book_c[1] - 3), (book_c[0] + side * 10, book_c[1] + 6), (book_c[0], book_c[1] + 8)])
            c.shade(page, PAGE, depth=1, highlight=0)
            for k in range(3):
                y = book_c[1] + k * 2
                c.fill(c.line([(book_c[0] + side * 2, y), (book_c[0] + side * 8, y - 1)]) & page, INK)
        cover = c.poly([(book_c[0] - 11, book_c[1] + 6), (book_c[0], book_c[1] + 9), (book_c[0] + 11, book_c[1] + 6), (book_c[0] + 11, book_c[1] + 8), (book_c[0], book_c[1] + 11), (book_c[0] - 11, book_c[1] + 8)])
        c.shade(cover, LEATHER, depth=1, highlight=0)
    else:
        book = c.poly([(cx - 22, 80 + bob), (cx - 10, 80 + bob), (cx - 9, 95 + bob), (cx - 21, 95 + bob)])
        c.shade(book, LEATHER, depth=1, highlight=1)
        c.fill(c.rect(cx - 21, 81 + bob, 2, 13), PAGE[1])
        c.fill(c.rect(cx - 17, 85 + bob, 4, 4), IRON[3])
        for k in range(4):
            c.px(cx - 10 + k * 3, 79 + bob + k * 0.3, IRON[2])
    c.fill(c.ellipse(back_hand[0], back_hand[1], 2.4, 2.4), bone[3])

    # Forked bone staff with a crystal; raised when casting.
    staff_x = cx + 28
    top = 20 + bob - raise_t * 14
    shaft = c.taper([(staff_x, top + 10), (staff_x - 2, GROUND - 2)], 3.4, 3)
    c.shade(shaft, bone, depth=1, highlight=1)
    for y in range(int(top) + 20, GROUND - 4, 12):
        c.fill(c.rect(staff_x - 2, y, 4, 2), LEATHER[2])
    for side in (-1, 1):
        prong = c.taper([(staff_x, top + 12), (staff_x + side * 6, top + 4), (staff_x + side * 5, top - 4)], 3, 1.4)
        c.shade(prong, bone, depth=1, highlight=1)
    # Front arm grips the staff.
    grip_y = 70 + bob - raise_t * 14
    arm = c.taper([(cx + 12, 52 + bob), (cx + 20, 62 + bob - raise_t * 6), (staff_x - 1, grip_y)], 10, 8)
    c.shade(arm, coat, depth=2, highlight=1)
    cuff = c.ellipse(staff_x - 4, grip_y - 1, 4, 4) & arm
    c.shade(cuff, fur, depth=1, highlight=0, edge=False)
    hand = c.ellipse(staff_x, grip_y, 3, 3)
    c.shade(hand, bone, depth=1, highlight=1)

    if ice:
        # Hoarfrost crust on shoulders, horns and hem.
        for fx, fy in ((cx - 15, 46), (cx - 9, 42), (cx + 14, 44), (cx + 18, 48), (cx - 14, 20), (cx + 17, 18), (cx - 18, 112), (cx + 20, 112)):
            spike = c.poly([(fx - 2.5, fy + bob), (fx, fy - 5 + bob), (fx + 2.5, fy + bob)])
            c.fill(spike, FROST[1])
            c.px(fx, fy - 3 + bob, FROST[3])

    c.outline(darkness=0.2, tint=(0.03, 0.04, 0.07))

    # Glows: eyes, staff crystal, circlet gem, book runes.
    for ex in (cx - 2, cx + 6):
        c.glow(ex + 0.5, head_y - 3, 3.2, EYE, 0.5)
        c.fill(c.rect(ex, head_y - 4, 2, 2), EYE_CORE if casting else EYE)
    pulse = 0.5 + 0.5 * math.sin(phase * 2)
    gem_y = top
    c.glow(staff_x, gem_y, 6 + pulse * 1.5 + raise_t * 4, CRYSTAL[2], 0.35 + raise_t * 0.25)
    gem = c.poly([(staff_x, gem_y - 7), (staff_x + 4, gem_y), (staff_x, gem_y + 6), (staff_x - 4, gem_y)])
    c.shade(gem, CRYSTAL, depth=1, highlight=1, edge=False)
    c.fill(c.line([(staff_x - 1, gem_y - 5), (staff_x - 2, gem_y)]), CRYSTAL[3])
    if casting:
        book_c = (back_hand[0] + 2, back_hand[1] - 2)
        c.glow(book_c[0], book_c[1], 7, EYE, 0.35 * raise_t)
        for k in range(4):
            t = (frame / FRAMES + k / 4) % 1.0
            a = t * math.tau + k
            c.px(book_c[0] + math.cos(a) * (4 + t * 6), book_c[1] - 4 - t * 14, EYE_CORE, 0.95 - t * 0.6)
            c.px(staff_x + math.cos(a) * (3 + t * 6), gem_y - 6 - t * 12, CRYSTAL[3], 0.95 - t * 0.6)
    if ice:
        for k in range(3):
            t = (frame / FRAMES + k / 3) % 1.0
            c.px(cx - 20 + k * 20 + math.sin(t * 6) * 2, 70 + bob - t * 30, FROST[3], 0.85 - t * 0.6)
    c.rgba = np.roll(c.rgba, TOP, axis=0)
    return c


def build():
    return {
        "walk": [draw(i, False, False) for i in range(FRAMES)],
        "cast": [draw(i, True, False) for i in range(FRAMES)],
        "walk_ice": [draw(i, False, True) for i in range(FRAMES)],
        "cast_ice": [draw(i, True, True) for i in range(FRAMES)],
    }
