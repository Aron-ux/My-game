"""Regenerate the pixel-art sheets for the reworked enemies and their skills.

Usage (from the repository root):
    python scripts/tools/enemy_pixel_art/generate.py [--preview DIR]

Sheets are written next to each enemy's visual scene under assets/enemies/.
Every sheet stores one animation per row and is displayed at 0.375 scale.
Monster bodies export at x2 (one art pixel == 0.75 world px, the grain of the
hand-made enemies); skill effects export at x4 (1.5 world px).
"""
from __future__ import annotations

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import effects  # noqa: E402
import hit_effects  # noqa: E402
import necro_priest  # noqa: E402
import pixelkit  # noqa: E402
import porcupine  # noqa: E402
import shadow_tree  # noqa: E402
import skull_mage  # noqa: E402
import vine  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ENEMY_ASSETS = os.path.join(ROOT, "assets", "enemies")


def _sheets():
    yield "porcupine/porcupine_sheet", list(porcupine.build().values()), pixelkit.BODY_EXPORT_SCALE
    yield "necropriest/necro_priest_sheet", list(necro_priest.build().values()), pixelkit.BODY_EXPORT_SCALE
    yield "plants/shadow_tree_sheet", list(shadow_tree.build_tree().values()), pixelkit.BODY_EXPORT_SCALE
    yield "plants/shadow_tree_young_sheet", list(shadow_tree.build_young().values()), pixelkit.BODY_EXPORT_SCALE
    yield "plants/vine_sheet", list(vine.build().values()), pixelkit.BODY_EXPORT_SCALE
    yield "skullmage/skull_mage_sheet", list(skull_mage.build().values()), pixelkit.BODY_EXPORT_SCALE
    for name, rows in effects.build().items():
        yield name, rows, pixelkit.EXPORT_SCALE
    for name, rows in hit_effects.build().items():
        yield name, rows, pixelkit.BODY_EXPORT_SCALE
    # The 300px-radius domain would be 1600px at x4; x2 keeps it light.
    yield "skullmage/unclean_domain", [[effects.domain()]], 2


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", help="also write x6 previews on a grass-coloured background to this folder")
    args = parser.parse_args()
    for name, rows, scale in _sheets():
        path = os.path.join(ENEMY_ASSETS, name + ".png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        pixelkit.sheet(rows, scale).save(path)
        frame = rows[0][0]
        print("%-36s frame %dx%d  x%d  rows %d  cols %d" % (name, frame.w, frame.h, scale, len(rows), max(len(r) for r in rows)))
        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            pixelkit.preview(rows, 6 if frame.w < 120 else 1).save(os.path.join(args.preview, name.replace("/", "_") + ".png"))


if __name__ == "__main__":
    main()
