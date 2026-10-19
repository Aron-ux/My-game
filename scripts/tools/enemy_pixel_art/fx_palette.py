"""Frozen palettes for the enemy skill effects.

The skill effects were approved as-is; keep these values fixed so redrawing
the monster bodies never changes how a skill looks.
"""
from pixelkit import hex_color, ramp

# 愤怒豪猪 - quill burst
QUILL_DARK = hex_color("#2a2027")
QUILL = ramp("#5d5150", "#a39883", "#d4caae", "#f3ecd6")
QUILL_RAGE = ramp("#6b2516", "#c9481f", "#ff8d3c", "#ffe08a")

# 藤蔓怪 - parasite seed / ring / burst / entangle
VINE = ramp("#0f1f14", "#1a3420", "#28502c", "#3c7238", "#5a9a47")
LEAF = ramp("#11240f", "#1f4219", "#326624", "#4f8f30", "#78b846")
THORN = ramp("#5b5338", "#9a8f5e", "#cfc48a", "#efe7b6")
VINE_GLOW = hex_color("#c4f55a")
VINE_GLOW_CORE = hex_color("#f4ffd0")
POD = ramp("#2c3a14", "#4b6420", "#6f8d2c", "#97b83f")

# 幽影树怪 - tree seed / hatch burst
SEED_BARK = ramp("#15101b", "#2a2133", "#41354d", "#5f4e6b", "#86739a")
SEED_LEAF = ramp("#1a1229", "#2e1f4a", "#46306b", "#654294", "#8d66c4")
SHADOW_GLOW = hex_color("#c58cff")
SHADOW_GLOW_CORE = hex_color("#f2e2ff")
SHADOW_GLOW_DIM = hex_color("#7e4fc0")

# 亡灵牧师 - prayer circle / heal wisp
SOUL = hex_color("#6effc8")
SOUL_CORE = hex_color("#e4fff3")
SOUL_DIM = hex_color("#2fb08a")

# 骷髅法师 - ice shards / frost overlay
CRYSTAL = ramp("#0f4d63", "#1b88a6", "#3fd0e6", "#a8f6ff")
FROST = ramp("#6fa8c8", "#a9dcf0", "#e2f8ff", "#ffffff")
