"""Skill effect sprites for the six reworked enemies."""
from __future__ import annotations

import math

import numpy as np

from pixelkit import Canvas, hex_color, mix, ramp
import fx_palette as fx

# ---------------------------------------------------------------- porcupine

def quill(enraged: bool) -> Canvas:
    """Horizontal quill pointing right (rotated in engine)."""
    c = Canvas(18, 5)
    colors = fx.QUILL_RAGE if enraged else fx.QUILL
    shaft = c.taper([(1, 2.5), (16.5, 2.5)], 3.2, 0.8)
    c.fill(shaft, fx.QUILL_DARK)
    c.fill(c.taper([(4, 2.5), (14, 2.5)], 2.2, 1.0) & shaft, colors[2])
    c.fill(c.taper([(4, 2.0), (13, 2.0)], 1.0, 0.8) & shaft, colors[3])
    c.fill(c.taper([(14, 2.5), (17, 2.5)], 1.4, 0.8) & shaft, colors[1])
    c.outline(darkness=0.25)
    if enraged:
        c.px(16, 2, fx.QUILL_RAGE[3])
    return c


# ---------------------------------------------------------------- parasite seed (vine)

def parasite_seed(frame: int, landed: bool) -> Canvas:
    c = Canvas(24, 24)
    cx, cy = 12, 12
    t = frame / 4
    wobble = math.sin(t * math.tau) * (0.0 if landed else 0.8)
    if landed:
        # Roots clawing into the ground.
        for index, angle in enumerate((0.3, 1.2, 2.0, 2.9)):
            reach = 7 + math.sin(t * math.tau + index) * 1.0
            c.fill(c.taper([(cx, cy + 3), (cx + math.cos(angle) * reach, cy + 3 + math.sin(angle) * reach * 0.45)], 2, 0.8), fx.VINE[2])
    pod = c.ellipse(cx, cy + wobble, 5, 5.5)
    c.sphere(cx - 1, cy - 1 + wobble, 6.5, 7, fx.POD, mask=pod)
    for index in range(6):
        angle = index / 6 * math.tau + t * (0.0 if landed else math.tau / 6)
        base = (cx + math.cos(angle) * 4.5, cy + wobble + math.sin(angle) * 5)
        tip = (cx + math.cos(angle) * 8, cy + wobble + math.sin(angle) * 8.5)
        c.fill(c.taper([base, tip], 2, 0.7), fx.THORN[1])
    c.fill(c.line([(cx - 3, cy - 1 + wobble), (cx + 3, cy + 1 + wobble)]) & pod, fx.POD[0])
    c.outline()
    pulse = 0.5 + 0.5 * math.sin(t * math.tau * (2 if landed else 1))
    c.glow(cx, cy + wobble, 3 + pulse * (2 if landed else 1), fx.VINE_GLOW, 0.35 + pulse * 0.2)
    c.px(cx - 1, cy - 2 + wobble, fx.VINE_GLOW_CORE)
    c.px(cx + 1, cy + 1 + wobble, fx.VINE_GLOW)
    return c


def parasite_ring(step: int, steps: int = 8) -> Canvas:
    """Ground warning: thorny roots grow around the blast radius as the fuse burns."""
    size = 72
    c = Canvas(size, size)
    cx = cy = size / 2
    radius = 33
    ring = c.ellipse(cx, cy, radius + 1, radius + 1) & ~c.ellipse(cx, cy, radius - 1, radius - 1)
    c.fill(c.ellipse(cx, cy, radius, radius), fx.VINE[2], 0.16 + 0.12 * step / steps)
    c.fill(ring, fx.VINE[1], 0.55)
    progress = (step + 1) / steps
    count = 28
    for index in range(int(count * progress)):
        angle = -math.pi / 2 + index / count * math.tau
        a2 = angle + math.tau / count * 1.15
        p0 = (cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
        p1 = (cx + math.cos(a2) * radius, cy + math.sin(a2) * radius)
        c.fill(c.line([p0, p1], 2), fx.VINE[3])
        if index % 2 == 0:
            out = (cx + math.cos(angle) * (radius + 3), cy + math.sin(angle) * (radius + 3))
            c.fill(c.taper([p0, out], 1.6, 0.7), fx.THORN[1])
        if index % 3 == 0:
            inner = (cx + math.cos(angle + 0.1) * (radius - 4), cy + math.sin(angle + 0.1) * (radius - 4))
            c.fill(c.taper([p0, inner], 1.8, 0.8), fx.LEAF[3])
    # Glowing tip of the growing vine.
    angle = -math.pi / 2 + progress * math.tau
    c.glow(cx + math.cos(angle) * radius, cy + math.sin(angle) * radius, 3, fx.VINE_GLOW, 0.6)
    return c


def parasite_burst(frame: int, frames: int = 6) -> Canvas:
    size = 76
    c = Canvas(size, size)
    cx = cy = size / 2
    t = (frame + 1) / frames
    radius = 10 + t * 26
    fade = 1.0 - max(0.0, t - 0.5) * 1.6
    c.fill(c.ellipse(cx, cy, radius, radius), fx.VINE_GLOW, 0.25 * fade)
    c.fill(c.ellipse(cx, cy, radius * 0.55, radius * 0.55), fx.VINE_GLOW_CORE, 0.35 * fade * (1 - t))
    ring = c.ellipse(cx, cy, radius, radius) & ~c.ellipse(cx, cy, radius - 2, radius - 2)
    c.fill(ring, fx.VINE_GLOW, 0.9 * fade)
    # Lashing thorn vines shooting outwards.
    for index in range(8):
        angle = index / 8 * math.tau + 0.2
        start = radius * 0.35
        pts = []
        for k in range(5):
            r = start + (radius - start) * k / 4
            a = angle + math.sin(k * 1.3 + index) * 0.18
            pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
        c.fill(c.taper(pts, 3, 1), fx.VINE[3], min(1.0, fade + 0.2))
        tip = pts[-1]
        c.px(tip[0], tip[1], fx.THORN[3], fade)
    # Leaf fragments.
    for index in range(10):
        angle = index / 10 * math.tau + 0.6
        r = radius * (0.6 + 0.4 * ((index * 7) % 5) / 5) + t * 4
        x, y = cx + math.cos(angle) * r, cy + math.sin(angle) * r
        c.fill(c.rect(int(x), int(y), 2, 1), fx.LEAF[4 if index % 2 else 3], fade)
    return c


def entangle(frame: int) -> Canvas:
    """Thorny vines curling up around the player's ankles (looping)."""
    c = Canvas(40, 20)
    t = frame / 4 * math.tau
    c.fill(c.ellipse(20, 16, 17, 3.5), fx.VINE[1], 0.6)
    # Curling tendrils on both sides of the legs; the middle stays open.
    for index, (x, side) in enumerate(((5, 1), (11, 1), (29, -1), (35, -1))):
        sway = math.sin(t + index * 1.4) * 1.2
        pts = [(x, 17), (x + side * 2 + sway, 11), (x + side * 6 + sway, 6 - (index % 2) * 2), (x + side * 9, 7 + sway * 0.5)]
        stalk = c.taper(pts, 3, 1)
        c.shade(stalk, fx.VINE, depth=1)
        c.px(pts[1][0] - side, pts[1][1], fx.THORN[2])
    # One coil hugging the front of the ankles.
    coil = [(8 + k * 3, 12 + math.sin(t + k * 0.9) * 1.2) for k in range(9)]
    c.shade(c.taper(coil, 2.2, 1.6), fx.VINE, depth=1)
    for lx, flip in ((6, -1), (33, 1)):
        leaf = c.poly([(lx, 9), (lx + flip * 4, 6), (lx + flip * 3, 10)])
        c.shade(leaf, fx.LEAF, depth=1)
    c.outline()
    c.px(14, 12 + round(math.sin(t)), fx.VINE_GLOW, 0.8)
    c.px(27, 11 + round(math.sin(t + 1)), fx.VINE_GLOW, 0.8)
    return c


# ---------------------------------------------------------------- shadow tree seed impact / hatch

def tree_hatch_burst(frame: int, frames: int = 6) -> Canvas:
    size = 48
    c = Canvas(size, size)
    cx = cy = size / 2
    t = (frame + 1) / frames
    fade = 1.0 - max(0.0, t - 0.4) * 1.5
    for index in range(10):
        angle = index / 10 * math.tau + 0.3
        r = 4 + t * 18 * (0.7 + 0.3 * (index % 3) / 2)
        x, y = cx + math.cos(angle) * r, cy + math.sin(angle) * r * 0.8
        c.fill(c.rect(int(x), int(y), 2, 2), fx.SEED_BARK[3] if index % 2 else fx.SEED_LEAF[3], fade)
    ring = c.ellipse(cx, cy, 6 + t * 16, (6 + t * 16) * 0.75) & ~c.ellipse(cx, cy, 4 + t * 16, (4 + t * 16) * 0.75)
    c.fill(ring, fx.SHADOW_GLOW, 0.8 * fade)
    c.glow(cx, cy, 4 + t * 6, fx.SHADOW_GLOW, 0.45 * fade)
    return c


# ---------------------------------------------------------------- tree seed projectile

def draw_seed(frame: int, mode: str) -> Canvas:
    """mode: fly (spinning), landed (pulsing), hatching (cracking open)."""
    c = Canvas(24, 24)
    cx, cy = 12, 12
    t = frame / 4
    if mode == "fly":
        angle = t * math.tau
        rx, ry = 5 + math.cos(angle) * 0.8, 6 - math.cos(angle) * 0.8
    else:
        rx, ry = 5.5, 6
    if mode != "fly":
        cy = 13
    pod = c.ellipse(cx, cy, rx, ry) | c.poly([(cx - 2, cy - ry + 1), (cx, cy - ry - 3), (cx + 2, cy - ry + 1)])
    c.sphere(cx - 1, cy - 1, rx + 2, ry + 2, fx.SEED_BARK, mask=pod)
    # Spiral husk grooves.
    offset = int(t * 4) if mode == "fly" else 0
    for index in range(3):
        y = cy - 3 + index * 3 + (offset % 2)
        c.fill(c.line([(cx - rx + 1.5, y), (cx + rx - 1.5, y - 1)]) & pod, fx.SEED_BARK[1])
    if mode == "hatching":
        # Cracks widen frame by frame; a sprout pokes out at the end.
        crack = [(cx, cy - ry + 1), (cx - 1, cy - 2), (cx + 1, cy + 1), (cx - 1, cy + ry - 1)]
        c.fill(c.line(crack, 1 + (frame >= 2)) & pod, fx.SHADOW_GLOW_DIM)
        if frame >= 1:
            c.fill(c.line([(cx + 1, cy + 1), (cx + rx - 1, cy + 2)]) & pod, fx.SHADOW_GLOW_DIM)
        if frame >= 3:
            c.fill(c.taper([(cx, cy - ry), (cx - 2, cy - ry - 4)], 1.6, 1), fx.SEED_LEAF[3])
            c.fill(c.taper([(cx, cy - ry), (cx + 3, cy - ry - 3)], 1.6, 1), fx.SEED_LEAF[3])
    c.outline()
    pulse = 0.5 + 0.5 * math.sin(t * math.tau)
    if mode == "fly":
        c.glow(cx, cy, 4, fx.SHADOW_GLOW, 0.35)
        c.px(cx - 1, cy - 1, fx.SHADOW_GLOW)
        c.px(cx, cy, fx.SHADOW_GLOW_CORE)
    elif mode == "landed":
        c.glow(cx, cy, 3 + pulse * 2, fx.SHADOW_GLOW, 0.3 + pulse * 0.25)
        c.px(cx - 1, cy - 1, fx.SHADOW_GLOW)
        c.px(cx, cy, fx.SHADOW_GLOW_CORE)
    else:
        c.glow(cx, cy, 4 + frame, fx.SHADOW_GLOW, 0.35 + frame * 0.08)
        crack = [(cx, cy - ry + 1), (cx - 1, cy - 2), (cx + 1, cy + 1), (cx - 1, cy + ry - 1)]
        c.fill(c.line(crack) & pod, fx.SHADOW_GLOW_CORE if frame >= 2 else fx.SHADOW_GLOW)
    return c



# ---------------------------------------------------------------- necro priest

def prayer_circle(frame: int, frames: int = 8) -> Canvas:
    """Expanding necrotic prayer circle cast from the priest."""
    size = 96
    c = Canvas(size, size)
    cx, cy = size / 2, size / 2
    t = (frame + 1) / frames
    rx = 14 + t * 30
    ry = rx * 0.55
    fade = 1.0 - max(0.0, t - 0.55) * 2.0
    outer = c.ellipse(cx, cy, rx, ry) & ~c.ellipse(cx, cy, rx - 1.5, ry - 1.2)
    inner = c.ellipse(cx, cy, rx * 0.72, ry * 0.72) & ~c.ellipse(cx, cy, rx * 0.72 - 1.2, ry * 0.72 - 1)
    c.fill(c.ellipse(cx, cy, rx, ry), fx.SOUL_DIM, 0.12 * fade)
    c.fill(outer, fx.SOUL, 0.9 * fade)
    c.fill(inner, fx.SOUL_DIM, 0.85 * fade)
    # Rune ticks between the rings.
    for index in range(12):
        angle = index / 12 * math.tau + t * 0.6
        x = cx + math.cos(angle) * rx * 0.86
        y = cy + math.sin(angle) * ry * 0.86
        c.fill(c.rect(int(x), int(y) - 1, 1, 3), fx.SOUL, fade)
        c.fill(c.rect(int(x) - 1, int(y), 3, 1), fx.SOUL, fade)
    # Rising souls.
    for index in range(6):
        angle = index / 6 * math.tau + 0.4
        x = cx + math.cos(angle) * rx * 0.6
        y = cy + math.sin(angle) * ry * 0.6 - t * 22
        wisp = c.taper([(x, y + 4), (x + math.sin(t * 6 + index) * 1.5, y - 2)], 2.6, 0.8)
        c.fill(wisp, fx.SOUL, 0.85 * fade)
        c.px(x, y + 3, fx.SOUL_CORE, fade)
    return c


def heal_wisp(frame: int, frames: int = 6) -> Canvas:
    """Green soul mending marker shown over each healed monster."""
    c = Canvas(20, 28)
    t = frame / (frames - 1)
    y = 20 - t * 12
    fade = 1.0 - max(0.0, t - 0.5) * 1.8
    cross = c.rect(8, int(y) - 3, 3, 9) | c.rect(5, int(y), 9, 3)
    c.fill(cross, fx.SOUL_DIM, fade)
    c.fill(c.rect(9, int(y) - 2, 1, 7) | c.rect(6, int(y) + 1, 7, 1), fx.SOUL_CORE, fade)
    for index in range(3):
        x = 3 + index * 7
        py = 25 - t * 18 - index * 3
        c.px(x, py, fx.SOUL, fade * 0.8)
    return c


def necro_mark(frame: int) -> Canvas:
    """Purple skull brand hovering above a marked player (loops)."""
    c = Canvas(22, 22)
    t = frame / 4 * math.tau
    purple = hex_color("#b45cff")
    purple_core = hex_color("#f0d8ff")
    purple_dim = hex_color("#5b2a86")
    bob = round(math.sin(t))
    ring = c.ellipse(11, 11 + bob, 10, 10) & ~c.ellipse(11, 11 + bob, 8.6, 8.6)
    c.fill(ring, purple_dim, 0.9)
    for index in range(4):
        angle = index / 4 * math.tau + t / 4
        c.fill(c.rect(int(11 + math.cos(angle) * 9.3), int(11 + bob + math.sin(angle) * 9.3), 2, 2), purple)
    skull = c.ellipse(11, 10 + bob, 5.5, 5)
    c.fill(skull, purple_dim)
    c.fill(skull & ~c.ellipse(10.5, 10.5 + bob, 4.3, 4), purple)
    c.fill(c.ellipse(11, 10 + bob, 4.5, 4) & skull, hex_color("#8a3fd0"))
    c.fill(c.rect(8, 15 + bob, 7, 2), purple)
    for x in (9, 11, 13):
        c.px(x, 16 + bob, purple_dim)
    for ex in (9, 13):
        c.fill(c.rect(ex - 1, 9 + bob, 2, 2), hex_color("#12061e"))
    c.outline(darkness=0.35, tint=(0.06, 0.0, 0.1))
    pulse = 0.5 + 0.5 * math.sin(t)
    for ex in (9, 13):
        c.px(ex - 1, 9 + bob, purple_core, 0.5 + 0.5 * pulse)
    return c


# ---------------------------------------------------------------- skull mage

def ice_shard() -> Canvas:
    c = Canvas(8, 14)
    shard = c.poly([(4, 0), (7.5, 5), (4.5, 13.5), (0.5, 6)])
    c.shade(shard, fx.FROST[:1] + list(fx.CRYSTAL[1:]) , depth=1, highlight=1, edge=False)
    c.fill(c.line([(4, 1), (4, 12)]) & shard, fx.FROST[2])
    c.outline(darkness=0.4, tint=(0.02, 0.1, 0.2))
    return c


def death_aura(frame: int) -> Canvas:
    """Necrotic body (死灵身躯): violet soul flames rising around the mage."""
    c = Canvas(48, 56)
    t = frame / 4 * math.tau
    violet = hex_color("#b77bff")
    core = hex_color("#f2e4ff")
    dim = hex_color("#5a2e8f")
    c.fill(c.ellipse(24, 47, 20, 6), dim, 0.45)
    for index in range(7):
        x = 6 + index * 6
        h = 16 + (index % 3) * 6 + math.sin(t + index * 1.7) * 4
        base = 48 - abs(index - 3) * 1.5
        flame = c.taper([(x, base), (x + math.sin(t + index) * 2, base - h * 0.5), (x - math.sin(t + index), base - h)], 4.5, 0.8)
        c.fill(flame, violet, 0.55)
        c.fill(c.taper([(x, base), (x, base - h * 0.5)], 2, 0.8) & flame, core, 0.6)
    return c


def domain(scale_hint: int = 1) -> Canvas:
    """不洁领域 ground circle (radius 300 world px == 200 art px at 1.5 px/art px)."""
    size = 404
    c = Canvas(size, size)
    cx = cy = size / 2
    r = 200
    purple = hex_color("#7d3bb0")
    purple_light = hex_color("#c07bff")
    purple_dark = hex_color("#2a0f40")
    sick_green = hex_color("#6e8f3a")
    disc = c.ellipse(cx, cy, r, r)
    # Mottled corrupted ground: bands of darker cells via a cheap hash pattern.
    yy, xx = c.yy, c.xx
    noise = ((xx // 6 * 73856093) ^ (yy // 6 * 19349663)) % 7
    c.fill(disc, purple_dark, 0.22)
    c.fill(disc & (noise == 0), purple, 0.14)
    c.fill(disc & (noise == 1), sick_green, 0.08)
    for ring_r, width, color, alpha in ((r, 3, purple_light, 0.9), (r - 6, 1.5, purple, 0.8), (r - 26, 1.5, purple, 0.7), (r - 30, 1, purple_light, 0.5)):
        ring = c.ellipse(cx, cy, ring_r, ring_r) & ~c.ellipse(cx, cy, ring_r - width, ring_r - width)
        c.fill(ring, color, alpha)
    # Rune glyphs between the two ring pairs.
    glyphs = [
        [(-2, -3), (2, -3), (0, -3), (0, 3), (-2, 3), (2, 3)],
        [(-2, -3), (2, 3), (0, 0), (-2, 3), (2, -3)],
        [(-2, 3), (0, -3), (2, 3), (-1, 0), (1, 0)],
        [(-2, -3), (-2, 3), (2, 3), (2, -3)],
        [(0, -3), (0, 3), (-2, -1), (2, 1)],
    ]
    count = 24
    for index in range(count):
        angle = index / count * math.tau
        gx = cx + math.cos(angle) * (r - 16)
        gy = cy + math.sin(angle) * (r - 16)
        shape = glyphs[index % len(glyphs)]
        pts = [(gx + x * 1.4, gy + y * 1.4) for x, y in shape]
        c.fill(c.line(pts, 1.5), purple_light, 0.85)
    # Inner pentagram-like sigil.
    star = []
    for index in range(5):
        angle = -math.pi / 2 + index * 2 * math.tau / 5
        star.append((cx + math.cos(angle) * (r - 60), cy + math.sin(angle) * (r - 60)))
    star.append(star[0])
    c.fill(c.line(star, 2), purple, 0.45)
    inner = c.ellipse(cx, cy, r - 60, r - 60) & ~c.ellipse(cx, cy, r - 62, r - 62)
    c.fill(inner, purple, 0.4)
    # Central skull mark.
    skull = c.ellipse(cx, cy - 3, 14, 12)
    c.fill(skull & ~c.ellipse(cx, cy - 3, 11, 9), purple_light, 0.5)
    for ex in (cx - 5, cx + 5):
        c.fill(c.ellipse(ex, cy - 3, 3, 3), purple_light, 0.55)
    c.fill(c.rect(int(cx - 7), int(cy + 8), 15, 3), purple_light, 0.5)
    # Crack spokes reaching out from the centre.
    for index in range(7):
        angle = index / 7 * math.tau + 0.3
        pts = [(cx + math.cos(angle) * 20, cy + math.sin(angle) * 20)]
        for k in range(1, 6):
            a = angle + math.sin(index * 3 + k) * 0.12
            pts.append((cx + math.cos(a) * (20 + k * 22), cy + math.sin(a) * (20 + k * 22)))
        c.fill(c.line(pts, 1.5), purple_dark, 0.6)
        c.fill(c.line([(p[0] + 1, p[1]) for p in pts], 1), purple, 0.45)
    return c


def frost_overlay(frame: int) -> Canvas:
    """寒冰侵蚀 on the player - crystals clinging to the body (loops)."""
    c = Canvas(36, 36)
    t = frame / 4 * math.tau
    for index, (x, y, s) in enumerate(((4, 26, 1.0), (32, 24, 0.9), (5, 12, 0.7), (31, 10, 0.8))):
        h = 6 * s
        shard = c.poly([(x, y - h), (x + 2.5 * s, y), (x, y + h * 0.5), (x - 2.5 * s, y)])
        c.shade(shard, fx.CRYSTAL, depth=1, highlight=1, edge=False)
        c.px(x - 0.5, y - h * 0.5, fx.FROST[3])
    c.outline(darkness=0.4, tint=(0.02, 0.1, 0.2))
    for index in range(3):
        p = (frame / 4 + index / 3) % 1.0
        c.px(6 + index * 11 + math.sin(p * 6) * 2, 32 - p * 26, fx.FROST[3], 0.9 - p * 0.6)
    return c


def build():
    return {
        "porcupine/quill": [[quill(False)], [quill(True)]],
        "plants/parasite_seed": [[parasite_seed(i, False) for i in range(4)], [parasite_seed(i, True) for i in range(4)]],
        "plants/parasite_ring": [[parasite_ring(i) for i in range(8)]],
        "plants/parasite_burst": [[parasite_burst(i) for i in range(6)]],
        "plants/entangle": [[entangle(i) for i in range(4)]],
        "plants/tree_seed_sheet": [[draw_seed(i, mode) for i in range(4)] for mode in ("fly", "landed", "hatching")],
        "plants/tree_hatch_burst": [[tree_hatch_burst(i) for i in range(6)]],
        "necropriest/prayer_circle": [[prayer_circle(i) for i in range(8)]],
        "necropriest/heal_wisp": [[heal_wisp(i) for i in range(6)]],
        "necropriest/necro_mark": [[necro_mark(i) for i in range(4)]],
        "skullmage/ice_shard": [[ice_shard()]],
        "skullmage/death_aura": [[death_aura(i) for i in range(4)]],
        "skullmage/frost_overlay": [[frost_overlay(i) for i in range(4)]],
    }
