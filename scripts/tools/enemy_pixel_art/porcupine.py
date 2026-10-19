"""愤怒豪猪 - stocky crested porcupine with banded black/ivory quills and tusks.

Side view facing right, fine grain (exported x2).  Rows: run, run_enraged.
Enraged: quills bristle upright with ember tips, fur flushes red, steam snorts.
"""
from __future__ import annotations

import math

import numpy as np

from pixelkit import Canvas, hex_color, mix, ramp

W, H = 140, 108
FRAMES = 6
GROUND = 100
OX = 8  # shift right so the tail quills stay in frame

FUR = ramp("#24160f", "#3f2717", "#5f3c21", "#83552c", "#a8733a", "#c99a5a")
FUR_RAGE = ramp("#2c1110", "#4c1b14", "#702a1a", "#963d22", "#ba5a2e", "#d8834a")
SKIN = ramp("#2e1d18", "#553629", "#7c5440", "#a07558")
QUILL_BLACK = ramp("#0e0b0c", "#1f1a1b", "#332c2b")
QUILL_IVORY = ramp("#8f8574", "#c9bfa6", "#efe7d0", "#fffaf0")
EMBER = ramp("#7a1d0c", "#d4441a", "#ff8a2a", "#ffd36a")
TUSK = ramp("#8b8068", "#cfc4a6", "#f3ecd8")
EYE = hex_color("#1a0f0c")
EYE_SHINE = hex_color("#fff3d8")
EYE_RAGE = hex_color("#ff3a1c")
STEAM = hex_color("#e8e4dc")


def _quill_specs(enraged: bool, phase: float):
    """(root, angle, length, layer) - quills fanned along the back and crest."""
    specs = []
    for layer in range(3):
        count = 15 - layer * 2
        for index in range(count):
            t = (index + 0.5 * (layer % 2)) / (count - 0.5)
            arc = math.pi * (0.97 - 0.66 * t)
            shrink = layer * 4.5
            root = (60 + math.cos(arc) * (36 - shrink), 62 - math.sin(arc) * (22 - shrink))
            sweep = 0.22 if enraged else 0.85
            angle = arc + sweep * (0.25 + 0.75 * (1 - t)) - 0.1
            angle += math.sin(phase * 2 + index * 1.3 + layer) * (0.06 if enraged else 0.025)
            length = (34 if enraged else 28) + 8 * math.sin(t * math.pi) - 10 * t - layer * 3
            specs.append((root, angle, length, layer))
    # Long crest over the neck (crested porcupine).
    for index in range(5):
        t = index / 4
        root = (88 + t * 8, 50 + t * 4)
        angle = math.pi * (0.62 - 0.12 * t) + (0.15 if enraged else 0.45)
        angle += math.sin(phase * 2 + index) * 0.05
        specs.append((root, angle, (22 if enraged else 18) - t * 6, 3))
    return specs


def _draw_quill(c: Canvas, root, angle, length, bob, enraged: bool, back: bool) -> None:
    def at(d):
        return root[0] + math.cos(angle) * d, root[1] - math.sin(angle) * d + bob

    width = 3.4 if not back else 3.0
    shaft = c.taper([at(0), at(length)], width, 1.0)
    if back:
        c.fill(shaft, QUILL_BLACK[0])
        c.fill(c.taper([at(length * 0.45), at(length * 0.75)], width * 0.7, 1.2) & shaft, QUILL_IVORY[0])
        return
    # Black root, ivory band, black band, ivory tip - like a real crested porcupine.
    bands = ((0.0, 0.3, QUILL_BLACK[1]), (0.3, 0.62, QUILL_IVORY[2]), (0.62, 0.8, QUILL_BLACK[1]), (0.8, 1.0, QUILL_IVORY[2]))
    for start, end, color in bands:
        c.fill(c.taper([at(length * start), at(length * end)], width, 1.0) & shaft, color)
    # Lit upper edge.
    c.fill(c.taper([at(length * 0.32), at(length * 0.6)], 1.0, 0.8) & shaft, QUILL_IVORY[3])
    c.fill(c.taper([at(length * 0.82), at(length * 0.97)], 1.0, 0.8) & shaft, QUILL_IVORY[3])
    if enraged:
        c.fill(c.taper([at(length * 0.86), at(length)], 2.0, 1.0) & shaft, EMBER[2])
        c.px(*at(length), EMBER[3])


def _leg(c: Canvas, hip_x, hip_y, phase, colors, near: bool) -> None:
    swing = math.sin(phase) * 6
    lift = max(0.0, math.cos(phase)) * 4
    knee = (hip_x + swing * 0.4 - 3, hip_y + 11 - lift * 0.5)
    paw = (hip_x + swing + 1, GROUND - 2 - lift)
    thigh = c.ellipse(hip_x, hip_y + 2, 9 if near else 8, 10)
    leg = thigh | c.taper([(hip_x, hip_y + 4), knee, paw], 10 if near else 8, 7 if near else 6)
    c.shade(leg, colors, depth=2 if near else 1, highlight=1 if near else 0)
    foot = c.ellipse(paw[0] + 3, paw[1] + 1, 6, 2.6)
    c.shade(foot, colors, depth=1, highlight=0)
    if near:
        for dx in (0, 3, 6):
            c.fill(c.taper([(paw[0] + dx + 2, paw[1] + 2), (paw[0] + dx + 4, paw[1] + 3.5)], 1.8, 1), TUSK[1])


def draw(frame: int, enraged: bool) -> Canvas:
    c = Canvas(W, H)
    phase = frame / FRAMES * math.tau
    bob = round(math.sin(phase * 2) * 1.5)
    fur = FUR_RAGE if enraged else FUR
    dark_fur = [mix(col, hex_color("#000000"), 0.45) for col in fur]

    # Far legs.
    for hip_x, offset in ((46, math.pi), (80, 0.0)):
        _leg(c, hip_x, 74 + bob, phase + offset, dark_fur, near=False)

    specs = _quill_specs(enraged, phase)
    for root, angle, length, layer in specs:
        if layer == 0:
            _draw_quill(c, root, angle, length + 4, bob, enraged, True)

    # Barrel body.
    body = c.ellipse(60, 66 + bob, 38, 23)
    c.sphere(58, 60 + bob, 42, 28, fur, mask=body)
    c.hatch(body & ~c.ellipse(52, 54 + bob, 32, 14), fur[1], 7, 2.3, 2, seed=3)
    c.hatch(body & c.ellipse(52, 56 + bob, 30, 14), fur[4], 9, 2.4, 2, seed=5)
    belly = c.ellipse(64, 82 + bob, 28, 8) & body
    c.sphere(64, 78 + bob, 30, 12, SKIN, mask=belly, edge=False)

    for root, angle, length, layer in specs:
        if layer == 1:
            _draw_quill(c, root, angle, length, bob, enraged, False)

    # Head: blunt wide snout like a hog.
    head = c.ellipse(96, 66 + bob, 18, 16)
    c.sphere(93, 61 + bob, 20, 19, fur, mask=head)
    c.hatch(head, fur[1], 8, 2.2, 2, seed=11)
    snout = c.poly([(100, 60 + bob), (122, 66 + bob), (124, 74 + bob), (118, 80 + bob), (102, 80 + bob)])
    c.shade(snout, SKIN, depth=2, highlight=1)
    nose = c.ellipse(121, 71 + bob, 3.5, 4.5)
    c.sphere(120, 70 + bob, 4, 5, SKIN[:3] + [SKIN[1]], mask=nose)
    c.px(121, 70 + bob, SKIN[0])
    c.px(121, 73 + bob, SKIN[0])
    # Tusk curling up from the lower jaw.
    tusk = c.taper([(108, 79 + bob), (113, 77 + bob), (115, 71 + bob)], 3.4, 1.4)
    c.shade(tusk, TUSK, depth=1, highlight=1)
    c.fill(c.line([(103, 80 + bob), (114, 79 + bob)]), SKIN[0])
    # Ear.
    ear = c.ellipse(86, 52 + bob, 4, 3.5)
    c.sphere(85, 51 + bob, 5, 4, SKIN, mask=ear)
    c.px(86, 53 + bob, SKIN[0])
    # Eye + brow.
    brow = c.poly([(97, 56 + bob), (107, 59 + bob), (106, 61 + bob), (97, 59 + bob)]) if enraged else c.line([(98, 57 + bob), (105, 58 + bob)], 2)
    c.fill(brow, fur[0])
    eye_center = (102, 63 + bob)
    c.fill(c.ellipse(*eye_center, 2.6, 2.6), EYE)
    if enraged:
        c.fill(c.ellipse(*eye_center, 1.6, 1.6), EYE_RAGE)
        c.px(eye_center[0] - 1, eye_center[1] - 1, EMBER[3])
    else:
        c.px(eye_center[0] - 1, eye_center[1] - 1, EYE_SHINE)

    for root, angle, length, layer in specs:
        if layer >= 2:
            _draw_quill(c, root, angle, length, bob, enraged, False)

    # Near legs with pale claws.
    for hip_x, offset in ((40, 0.0), (74, math.pi)):
        _leg(c, hip_x, 76 + bob, phase + offset, fur, near=True)

    c.outline(darkness=0.22, tint=(0.07, 0.04, 0.03))
    c.rgba = np.roll(c.rgba, OX, axis=1)

    if enraged:
        c.glow(eye_center[0] + OX, eye_center[1], 5, EYE_RAGE, 0.45)
        # Steam snorted from the nostril, drifting forward.
        for index in range(3):
            t = (frame / FRAMES + index / 3) % 1.0
            x = 124 + OX + t * 6
            y = 70 + bob - t * 10
            puff = c.ellipse(x, y, 1.5 + t * 2.5, 1.2 + t * 2)
            c.fill(puff, STEAM, 0.65 * (1 - t))
    return c


def build():
    return {
        "run": [draw(i, False) for i in range(FRAMES)],
        "run_enraged": [draw(i, True) for i in range(FRAMES)],
    }
