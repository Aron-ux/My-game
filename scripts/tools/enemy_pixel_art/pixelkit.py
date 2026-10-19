"""Small pixel-art drawing kit used to author enemy sprite sheets.

Everything is drawn at native pixel resolution (one array cell = one art pixel)
and exported upscaled with nearest neighbour.  In game every sheet is shown at
0.375 scale, so the export factor sets the grain: monster bodies use x2
(0.75 world px per art pixel, close to the hand-made enemies), skill effects
use x4 (1.5 world px).
"""
from __future__ import annotations

import math
from typing import Iterable, Sequence

import numpy as np
from PIL import Image, ImageDraw

EXPORT_SCALE = 4
BODY_EXPORT_SCALE = 2


def hex_color(value: str, alpha: float = 1.0) -> np.ndarray:
    value = value.lstrip("#")
    return np.array([int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4)] + [alpha])


def ramp(*values: str) -> list[np.ndarray]:
    return [hex_color(v) for v in values]


def mix(a: np.ndarray, b: np.ndarray, t: float) -> np.ndarray:
    return a * (1.0 - t) + b * t


def shift(mask: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """Return mask moved by (dx, dy); cells moved in from outside are False."""
    h, w = mask.shape
    out = np.zeros_like(mask)
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    out[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx] = mask[ys0:ys1, xs0:xs1]
    return out


def erode(mask: np.ndarray, steps: int = 1) -> np.ndarray:
    out = mask.copy()
    for _ in range(steps):
        out = out & shift(out, 1, 0) & shift(out, -1, 0) & shift(out, 0, 1) & shift(out, 0, -1)
    return out


def dilate(mask: np.ndarray, steps: int = 1, diagonal: bool = False) -> np.ndarray:
    out = mask.copy()
    for _ in range(steps):
        grown = out | shift(out, 1, 0) | shift(out, -1, 0) | shift(out, 0, 1) | shift(out, 0, -1)
        if diagonal:
            grown |= shift(out, 1, 1) | shift(out, -1, -1) | shift(out, 1, -1) | shift(out, -1, 1)
        out = grown
    return out


def border(mask: np.ndarray) -> np.ndarray:
    return mask & ~erode(mask)


class Canvas:
    def __init__(self, width: int, height: int):
        self.w = width
        self.h = height
        self.rgba = np.zeros((height, width, 4), dtype=float)
        self.yy, self.xx = np.mgrid[0:height, 0:width]

    # ------------------------------------------------------------------ masks
    def empty(self) -> np.ndarray:
        return np.zeros((self.h, self.w), dtype=bool)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float) -> np.ndarray:
        rx = max(rx, 0.5)
        ry = max(ry, 0.5)
        return ((self.xx + 0.5 - cx) / rx) ** 2 + ((self.yy + 0.5 - cy) / ry) ** 2 <= 1.0

    def poly(self, points: Sequence[tuple[float, float]]) -> np.ndarray:
        image = Image.new("L", (self.w, self.h), 0)
        ImageDraw.Draw(image).polygon([(float(x), float(y)) for x, y in points], fill=255)
        return np.array(image) > 0

    def line(self, points: Sequence[tuple[float, float]], width: float = 1.0) -> np.ndarray:
        image = Image.new("L", (self.w, self.h), 0)
        draw = ImageDraw.Draw(image)
        pts = [(float(x), float(y)) for x, y in points]
        if width <= 1.0:
            draw.line(pts, fill=255, width=1)
        else:
            draw.line(pts, fill=255, width=int(round(width)), joint="curve")
            radius = width / 2.0 - 0.5
            for x, y in pts:
                draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=255)
        return np.array(image) > 0

    def taper(self, points: Sequence[tuple[float, float]], start_width: float, end_width: float) -> np.ndarray:
        """Polyline whose width tapers linearly; good for quills, roots and tendrils."""
        mask = self.empty()
        total = len(points) - 1
        for index in range(total):
            x0, y0 = points[index]
            x1, y1 = points[index + 1]
            steps = max(2, int(math.hypot(x1 - x0, y1 - y0) * 2))
            for step in range(steps + 1):
                t = step / steps
                along = (index + t) / total
                radius = (start_width + (end_width - start_width) * along) / 2.0
                mask |= self.ellipse(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, radius, radius)
        return mask

    def rect(self, x: int, y: int, w: int, h: int) -> np.ndarray:
        mask = self.empty()
        mask[max(0, y):max(0, y + h), max(0, x):max(0, x + w)] = True
        return mask

    def opaque(self) -> np.ndarray:
        return self.rgba[..., 3] > 0.01

    # ---------------------------------------------------------------- painting
    def fill(self, mask: np.ndarray, color: np.ndarray, alpha: float | None = None) -> None:
        if not mask.any():
            return
        c = np.array(color, dtype=float)
        if alpha is not None:
            c = c.copy()
            c[3] = alpha
        if c[3] >= 0.999:
            self.rgba[mask] = c
            return
        dst = self.rgba[mask]
        out_a = c[3] + dst[:, 3] * (1.0 - c[3])
        safe = np.where(out_a > 0, out_a, 1.0)
        rgb = (c[:3] * c[3] + dst[:, :3] * dst[:, 3:4] * (1.0 - c[3])) / safe[:, None]
        self.rgba[mask] = np.concatenate([rgb, out_a[:, None]], axis=1)

    def px(self, x: float, y: float, color: np.ndarray, alpha: float | None = None) -> None:
        ix, iy = int(math.floor(x)), int(math.floor(y))
        if 0 <= ix < self.w and 0 <= iy < self.h:
            mask = self.empty()
            mask[iy, ix] = True
            self.fill(mask, color, alpha)

    def shade(self, mask: np.ndarray, colors: Sequence[np.ndarray], light: tuple[int, int] = (-1, -1),
              depth: int = 2, highlight: int = 1, edge: bool = True, clip: np.ndarray | None = None) -> None:
        """Rim shading for arbitrary shapes.

        colors: dark -> light ramp (at least 4 entries).  Cells close to the
        edge facing away from the light get the dark tones; cells on the lit
        edge get the highlight tones.  When ``edge`` is set, the silhouette of
        the part is lined with the darkest tone so overlapping parts read as
        separate pieces, like the hand-drawn reference sheets.
        """
        if clip is not None:
            mask = mask & clip
        if not mask.any():
            return
        lx, ly = light
        n = len(colors)
        mid = n // 2
        self.fill(mask, colors[mid])
        for step in range(depth, 0, -1):
            away = mask & ~shift(mask, -lx * step, -ly * step)
            self.fill(away, colors[max(0, mid - (depth - step) - 1)])
        for step in range(highlight, 0, -1):
            toward = mask & ~shift(mask, lx * step, ly * step)
            self.fill(toward & ~(mask & ~shift(mask, -lx, -ly)), colors[min(n - 1, mid + (highlight - step) + 1)])
        if edge:
            self.fill(border(mask) & ~(mask & ~shift(mask, lx, ly)), colors[0])

    def sphere(self, cx: float, cy: float, rx: float, ry: float, colors: Sequence[np.ndarray],
               light: tuple[float, float, float] = (-0.55, -0.65, 0.52), mask: np.ndarray | None = None,
               edge: bool = True, bands: Sequence[float] | None = None) -> np.ndarray:
        """Banded ellipsoid lighting; returns the mask that was painted."""
        shape = self.ellipse(cx, cy, rx, ry) if mask is None else mask
        if not shape.any():
            return shape
        nx = (self.xx + 0.5 - cx) / max(rx, 0.5)
        ny = (self.yy + 0.5 - cy) / max(ry, 0.5)
        nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.0, 1.0))
        l = np.array(light, dtype=float)
        l /= np.linalg.norm(l)
        intensity = nx * l[0] + ny * l[1] + nz * l[2]
        n = len(colors)
        cuts = bands if bands is not None else np.linspace(-0.25, 0.85, n)[1:]
        index = np.zeros(intensity.shape, dtype=int)
        for cut in cuts:
            index += (intensity > cut).astype(int)
        index = np.clip(index, 0, n - 1)
        for i in range(n):
            self.fill(shape & (index == i), colors[i])
        if edge:
            self.fill(border(shape) & (index <= n // 2), colors[0])
        return shape

    def strokes(self, mask: np.ndarray, color: np.ndarray, lines: Iterable[Sequence[tuple[float, float]]],
                width: float = 1.0, alpha: float | None = None) -> None:
        """Texture strokes (bark grain, fur) clipped to a mask."""
        for pts in lines:
            self.fill(self.line(pts, width) & mask, color, alpha)

    def rivet(self, x: float, y: float, dark: np.ndarray, light: np.ndarray) -> None:
        self.px(x, y, light)
        self.px(x + 1, y + 1, dark)

    def hatch(self, mask: np.ndarray, color: np.ndarray, spacing: int, angle: float, length: float,
              seed: int = 0, alpha: float | None = None) -> None:
        """Short parallel strokes (fur, bark grain) scattered over a mask."""
        ys, xs = np.nonzero(mask)
        if len(xs) == 0:
            return
        dx, dy = math.cos(angle) * length, math.sin(angle) * length
        rng = np.random.default_rng(seed)
        for y in range(int(ys.min()), int(ys.max()) + 1, spacing):
            for x in range(int(xs.min()) + (y // spacing) % 2 * spacing // 2, int(xs.max()) + 1, spacing):
                if not mask[y, x]:
                    continue
                jx, jy = rng.integers(-1, 2), rng.integers(-1, 2)
                self.fill(self.line([(x + jx, y + jy), (x + jx + dx, y + jy + dy)]) & mask, color, alpha)

    # --------------------------------------------------------------- finishing
    def outline(self, darkness: float = 0.28, tint: tuple[float, float, float] = (0.05, 0.04, 0.09),
                diagonal: bool = False, skip: np.ndarray | None = None) -> None:
        """Selective dark outline around the whole silhouette."""
        solid = self.rgba[..., 3] > 0.5
        ring = dilate(solid, 1, diagonal) & ~solid
        if skip is not None:
            ring &= ~skip
        if not ring.any():
            return
        acc = np.zeros((self.h, self.w, 3))
        count = np.zeros((self.h, self.w))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            moved = np.zeros_like(self.rgba)
            src = self.rgba
            h, w = self.h, self.w
            moved[max(0, dy):h + min(0, dy), max(0, dx):w + min(0, dx)] = src[max(0, -dy):h - max(0, dy), max(0, -dx):w - max(0, dx)]
            valid = moved[..., 3] > 0.5
            acc[valid] += moved[valid][:, :3]
            count[valid] += 1
        count = np.where(count > 0, count, 1)
        neighbour = acc / count[..., None]
        out = neighbour * darkness + np.array(tint) * (1 - darkness)
        self.rgba[ring, :3] = out[ring]
        self.rgba[ring, 3] = 1.0

    def glow(self, cx: float, cy: float, radius: float, color: np.ndarray, strength: float = 0.45) -> None:
        """Soft stepped halo (2-3 alpha bands) - kept blocky on purpose."""
        for step, alpha in ((radius, strength * 0.35), (radius * 0.66, strength * 0.65)):
            self.fill(self.ellipse(cx, cy, step, step), color, alpha)

    def paste(self, other: "Canvas", ox: int, oy: int) -> None:
        mask = other.rgba[..., 3] > 0.01
        ys, xs = np.nonzero(mask)
        for y, x in zip(ys, xs):
            tx, ty = x + ox, y + oy
            if 0 <= tx < self.w and 0 <= ty < self.h:
                single = self.empty()
                single[ty, tx] = True
                self.fill(single, other.rgba[y, x])

    def flipped(self) -> "Canvas":
        out = Canvas(self.w, self.h)
        out.rgba = self.rgba[:, ::-1].copy()
        return out

    def image(self, scale: int = 1) -> Image.Image:
        data = (np.clip(self.rgba, 0, 1) * 255).round().astype(np.uint8)
        image = Image.fromarray(data, "RGBA")
        if scale != 1:
            image = image.resize((self.w * scale, self.h * scale), Image.NEAREST)
        return image


def sheet(rows: Sequence[Sequence[Canvas]], scale: int = EXPORT_SCALE) -> Image.Image:
    columns = max(len(r) for r in rows)
    fw, fh = rows[0][0].w, rows[0][0].h
    out = Image.new("RGBA", (fw * columns * scale, fh * len(rows) * scale), (0, 0, 0, 0))
    for row_index, row in enumerate(rows):
        for col_index, frame in enumerate(row):
            out.paste(frame.image(scale), (col_index * fw * scale, row_index * fh * scale))
    return out


def preview(rows: Sequence[Sequence[Canvas]], scale: int = 6, background=(46, 58, 44, 255)) -> Image.Image:
    image = sheet(rows, scale)
    bg = Image.new("RGBA", image.size, background)
    bg.alpha_composite(image)
    return bg
