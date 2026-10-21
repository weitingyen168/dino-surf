"""Turns an animated pixel-art GIF into a game-ready horizontal strip PNG (Godot can't read GIFs).

Shrinks it back to 1 px per art pixel (the art is usually exported blown up, e.g. 32x) and lays the frames
out left to right. Needs Pillow (pip install pillow). Run from the project folder:
    python tools/gif_to_strip.py "<artist folder>/Animation.GIF" art/ui/title_handheld_01.png
"""
import sys

from PIL import Image, ImageSequence


def _differ(a, b):
    """Clearly different colours; a fine dither between two near-identical shades doesn't count."""
    return sum(abs(p - q) for p, q in zip(a, b)) > 48


def block_size(frame):
    """Biggest block size the art was blown up by: (nearly) every block of that size is one flat colour.
    A few stray pixels are allowed, since some exports add a faint texture."""
    w, h = frame.size
    px = frame.load()
    for s in (64, 50, 40, 32, 25, 20, 16, 10, 8, 5, 4, 2):
        if w % s or h % s:
            continue
        samples = [(x, y) for y in range(0, h, 7) for x in range(0, w, 7)]
        off = sum(1 for x, y in samples if _differ(px[x, y], px[x - x % s + s // 2, y - y % s + s // 2]))
        if off < len(samples) * 0.08:
            return s
    return 1


def main(src, dst):
    gif = Image.open(src)
    frames = [f.convert("RGBA") for f in ImageSequence.Iterator(gif)]
    s = block_size(frames[0])
    w, h = frames[0].width // s, frames[0].height // s
    strip = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        strip.paste(f.resize((w, h), Image.BOX), (i * w, 0))  # each block's average evens out the texture
    strip.save(dst)
    print(f"{len(frames)} frames of {w}x{h} ({s}x blocks), {gif.info.get('duration')} ms each -> {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
