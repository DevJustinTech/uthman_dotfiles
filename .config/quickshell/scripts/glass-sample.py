#!/usr/bin/env python3
"""glass-sample.py [wallpaper] — sample the scene under each shell surface.

The liquid-glass material reads its density (tint band) and, in light themes,
its ink from the wallpaper the surface floats over. This is the one-time
sampler: it reads the wallpaper image, covers the focused monitor with it,
and averages a 5x3 grid inside each surface's rectangle.

Rules (from the material brief):
  - drop the 2 darkest and 2 brightest cells, average the remaining 11
  - luminance = (0.299R + 0.587G + 0.114B) / 255
  - texture   = brightest - darkest (all 15 cells)
  - chroma    = (max channel - min channel) of the average / 255
  - density   = 0.55 * bg/ink brightness closeness + 0.7 * texture + 0.3 * chroma
  - light themes flip ink under luminance 0.5, with ±0.05 hysteresis;
    dark themes are always light ink

Output: ~/.cache/quickshell/glass-sample.json, one object per surface.
Runs on theme/wallpaper changes (getTheme) and shell start. No PIL: ffmpeg
decodes the image to raw RGB, which also handles GIFs (first frame).

Usage: glass-sample.py /path/to/wallpaper
"""
import json
import os
import subprocess
import sys


def monitor_size():
    try:
        out = subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True, check=True).stdout
        monitors = json.loads(out)
    except Exception:
        return 1366, 768
    mon = next((m for m in monitors if m.get("focused")), monitors[0] if monitors else None)
    if not mon:
        return 1366, 768
    return int(mon.get("width") or 1366), int(mon.get("height") or 768)


def theme_is_dark():
    """Same test Colors.qml and glass-apply use: background luminance."""
    try:
        with open(os.path.expanduser("~/.config/quickshell/colors.css")) as f:
            for line in f:
                if "@define-color background" in line:
                    h = line.split("#")[-1].strip().rstrip(";").strip()[:6]
                    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
                    return (299 * r + 587 * g + 114 * b) / 1000 < 128
    except Exception:
        pass
    return True


def regions(width, height):
    """Approximate shell-surface rectangles in logical screen pixels.

    These are the places the surfaces occupy when open. A little slack is
    fine: the sampler only needs the character of the scene, and a surface
    not listed here falls back to density 0.35 + theme ink.
    """
    w, h = width, height
    return {
        "bar":            (int(w * 0.16), 0, int(w * 0.68), 58),
        "wifi":           (w - 418, 52, 410, 640),
        "notify":         (w - 388, 52, 380, 520),
        "controlcenter":  ((w - 700) // 2, (h - 540) // 2, 700, 540),
        "themeedit":      ((w - 440) // 2, (h - 620) // 2, 440, 620),
        "launcher":       ((w - 750) // 2, (h - 520) // 2, 750, 520),
        "power":          ((w - 520) // 2, (h - 200) // 2, 520, 200),
        "keybinds":       ((w - 640) // 2, (h - 520) // 2, 640, 520),
        "sysmon":         ((w - 840) // 2, (h - 560) // 2, 840, 560),
        "wallshelf":      ((w - 1000) // 2, 70, 1000, 620),
        "clipboard":      ((w - 470) // 2, 70, 470, 600),
        "theme":          ((w - 720) // 2, (h - 640) // 2, 720, 640),
        "passprompt":     ((w - 420) // 2, int(h * 0.38), 420, 140),
        "toast":          (w - 410, 70, 390, 280),
        "osd":            (w // 2 - 160, int(h * 0.62), 320, 120),
        "mediaosd":       (w // 2 - 160, h - 150, 320, 100),
        "nowplaying":     ((w - 430) // 2, 54, 430, 170),
    }


def main():
    wallpaper = sys.argv[1] if len(sys.argv) > 1 else ""
    if not wallpaper:
        wallpaper = os.path.realpath(os.path.expanduser("~/.config/theme/current/background"))
    if not wallpaper or not os.path.isfile(wallpaper):
        return 0

    w, h = monitor_size()
    raw = subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-i", wallpaper,
         "-vf", f"scale={w}:{h}:force_original_aspect_ratio=increase,crop={w}:{h}",
         "-frames:v", "1", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=False,
    ).stdout
    if len(raw) < w * h * 3:
        return 0

    out_path = os.path.expanduser("~/.cache/quickshell/glass-sample.json")
    previous = {}
    try:
        with open(out_path) as f:
            previous = json.load(f)
    except Exception:
        pass

    dark = theme_is_dark()

    def block(x, y):
        """Average a small block around a point (flat-ish, cheap)."""
        x = max(0, min(w - 1, int(x)))
        y = max(0, min(h - 1, int(y)))
        r = g = b = n = 0
        for yy in range(max(0, y - 2), min(h, y + 3)):
            base = (yy * w) * 3
            for xx in range(max(0, x - 2), min(w, x + 3)):
                i = base + xx * 3
                r += raw[i]
                g += raw[i + 1]
                b += raw[i + 2]
                n += 1
        return r / n, g / n, b / n

    def lum(rgb):
        return (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255.0

    result = {}
    for name, (x, y, rw, rh) in regions(w, h).items():
        if rw < 8 or rh < 8:
            continue
        cells = []
        for row in range(3):
            for col in range(5):
                cx = x + rw * (col + 0.5) / 5.0
                cy = y + rh * (row + 0.5) / 3.0
                cells.append(block(cx, cy))

        lums = sorted(lum(c) for c in cells)
        texture = max(0.0, min(1.0, lums[-1] - lums[0]))
        # drop the two darkest and two brightest, average the rest
        kept = cells[2:-2] if len(cells) == 15 else cells
        ar = sum(c[0] for c in kept) / len(kept) / 255.0
        ag = sum(c[1] for c in kept) / len(kept) / 255.0
        ab = sum(c[2] for c in kept) / len(kept) / 255.0
        chroma = max(0.0, max(ar, ag, ab) - min(ar, ag, ab))
        avg_lum = 0.299 * ar + 0.587 * ag + 0.114 * ab

        if dark:
            ink = "light"
        else:
            old = (previous.get(name) or {}).get("ink")
            threshold = 0.55 if old == "light" else 0.45 if old == "dark" else 0.5
            ink = "light" if avg_lum < threshold else "dark"

        ink_brightness = 1.0 if ink == "light" else 0.0
        closeness = 1.0 - abs(avg_lum - ink_brightness)
        density = 0.55 * closeness + 0.7 * texture + 0.3 * chroma
        density = max(0.0, min(1.0, density))

        def rel_lum(c):
            def f(v):
                return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
            r, g, b = (f(c[0]), f(c[1]), f(c[2]))
            return 0.2126 * r + 0.7152 * g + 0.0722 * b

        def composite(fg, a, bg):
            return tuple(fg[i] * a + bg[i] * (1.0 - a) for i in range(3))

        def tint_for(d):
            band = int(round(d * 4))
            if dark:
                return (20 / 255, 20 / 255, 24 / 255), 0.16 + band * 0.055
            if ink == "light":
                return (16 / 255, 18 / 255, 22 / 255), 0.10 + band * 0.05
            return (1.0, 1.0, 1.0), 0.06 + band * 0.04

        def contrast_for(d):
            tcol, ta = tint_for(d)
            bg = composite(tcol, min(1.0, ta), (ar, ag, ab))
            ink_rgb = (1.0, 1.0, 1.0) if ink == "light" else (0.0, 0.0, 0.0)
            ink_a = 0.94 if ink == "light" else 0.86
            fg = composite(ink_rgb, ink_a, bg)
            l1, l2 = rel_lum(fg), rel_lum(bg)
            return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

        # Accessibility: raise density (not ink alpha) until text passes 4.5:1.
        for _ in range(24):
            if contrast_for(density) >= 4.5 or density >= 1.0:
                break
            density = min(1.0, density + 0.05)
        contrast = contrast_for(density)

        result[name] = {
            "lum": round(avg_lum, 3),
            "texture": round(texture, 3),
            "chroma": round(chroma, 3),
            "density": round(density, 3),
            "ink": ink,
            "contrast": round(contrast, 2),
            "rgb": [round(ar * 255), round(ag * 255), round(ab * 255)],
            # saturation kept = 1 - 0.75*chroma, floored at 0.45; the
            # compositor vibrance is global, so this is recorded for the
            # one-day per-surface filter and for glass-check.
            "sat": round(max(0.45, 1.0 - 0.75 * chroma), 3),
        }

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    tmp = out_path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(result, f, separators=(",", ":"), sort_keys=True)
    os.replace(tmp, out_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
