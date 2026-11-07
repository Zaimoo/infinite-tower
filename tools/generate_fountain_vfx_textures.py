#!/usr/bin/env python3
"""
Generates custom RGBA water VFX textures for the Gothic Goddess Fountain:
  1. fountain_waterfall_streaks_u.png (512x512): Silky waterfall strands running along U (X)
     for Roblox Beams where U is along the beam length and V is across the beam width.
  2. fountain_waterfall_streaks_v.png (512x512): Silky waterfall strands running along V (Y).
  3. fountain_splash_foam_ring.png (512x512): Frothy white/cyan splash boil + concentric
     water ripple rings for waterfall impact zones.
  4. fountain_water_caustics.png (512x512): Seamless tileable water caustics + sparkles.
  5. fountain_water_sparkle.png (256x256): Pinpoint glowing water droplet / sparkle mote.
"""

import math
import os
import random
from PIL import Image, ImageDraw, ImageFilter

OUT_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "vfx", "fountain")
os.makedirs(OUT_DIR, exist_ok=True)


def make_waterfall_streaks_v(size: int = 512) -> Image.Image:
    """
    Streaks run vertically (along Y, seamless top-to-bottom), feathered along left/right X edges.
    """
    rng = random.Random(42)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()

    # Precompute 22 vertical strand profiles across X (0..1)
    strands = []
    for _ in range(26):
        cx = rng.uniform(0.08, 0.92)
        width = rng.uniform(0.018, 0.055)
        intensity = rng.uniform(0.55, 1.0)
        freq = rng.choice([1, 2, 3, 4])
        phase = rng.uniform(0, math.tau)
        wobble_amp = rng.uniform(0.004, 0.014)
        foam_freq = rng.choice([2, 3, 5, 6])
        foam_phase = rng.uniform(0, math.tau)
        strands.append((cx, width, intensity, freq, phase, wobble_amp, foam_freq, foam_phase))

    # Droplet highlights (seamless in Y)
    droplets = []
    for _ in range(95):
        dx = rng.uniform(0.12, 0.88)
        dy = rng.uniform(0.0, 1.0)
        rx = rng.uniform(0.006, 0.016)
        ry = rng.uniform(0.035, 0.095)
        d_int = rng.uniform(0.65, 1.0)
        droplets.append((dx, dy, rx, ry, d_int))

    for y in range(size):
        v = y / size
        ang_v = v * math.tau
        for x in range(size):
            u = x / size
            # Soft horizontal edge fade so Beam edges never look like hard rectangles
            edge_fade = math.sin(u * math.pi) ** 1.35
            if edge_fade <= 0.01:
                continue

            # Base translucent cyan water sheet
            sheet_val = 0.28 * (math.sin(u * math.pi) ** 0.85)

            # Sum silky vertical water strands
            strand_sum = 0.0
            foam_highlight = 0.0
            for cx, width, intensity, freq, phase, wobble_amp, foam_freq, foam_phase in strands:
                wobble = math.sin(ang_v * freq + phase) * wobble_amp
                dist = abs(u - (cx + wobble))
                if dist < width * 2.2:
                    g = math.exp(-((dist / width) ** 2) * 1.8)
                    pulse = 0.72 + 0.28 * math.sin(ang_v * foam_freq + foam_phase)
                    contrib = g * intensity * pulse
                    strand_sum += contrib
                    if g > 0.55:
                        foam_highlight += (g - 0.55) * 1.6 * pulse

            # Add elongated falling water droplets (wrapping in v)
            for dx, dy, rx, ry, d_int in droplets:
                du = abs(u - dx)
                if du < rx * 2.0:
                    dv = abs(v - dy)
                    dv = min(dv, 1.0 - dv)
                    if dv < ry * 2.0:
                        dg = math.exp(-((du / rx) ** 2 + (dv / ry) ** 2) * 1.6)
                        strand_sum += dg * d_int * 0.65
                        foam_highlight += dg * d_int * 0.85

            total = min(1.0, (sheet_val + strand_sum * 0.62) * edge_fade)
            foam = min(1.0, foam_highlight * edge_fade)

            # Color ramp: deep cyan (#0EA5E9) -> sky cyan (#7DD3FC) -> pure white foam (#FFFFFF)
            r = int(min(255, 14 + total * 145 + foam * 96))
            g_col = int(min(255, 165 + total * 68 + foam * 22))
            b = int(min(255, 233 + total * 22))
            a = int(min(255, (total * 215 + foam * 40)))
            px[x, y] = (r, g_col, b, a)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.8))
    return img


def make_splash_foam_ring(size: int = 512) -> Image.Image:
    """
    Radial frothy white/cyan splash boil in the center + concentric glowing ripple rings
    and scattered foam droplets around the perimeter.
    """
    rng = random.Random(108)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()

    # Precompute radial foam lobes and droplets
    lobes = [(rng.uniform(0, math.tau), rng.uniform(3, 9), rng.uniform(0.04, 0.12)) for _ in range(14)]
    foam_dots = []
    for _ in range(140):
        ang = rng.uniform(0, math.tau)
        rad = rng.uniform(0.12, 0.86)
        dot_r = rng.uniform(0.015, 0.048)
        dot_i = rng.uniform(0.5, 1.0)
        foam_dots.append((math.cos(ang) * rad, math.sin(ang) * rad, dot_r, dot_i))

    for y in range(size):
        ny = (y / size) * 2.0 - 1.0
        for x in range(size):
            nx = (x / size) * 2.0 - 1.0
            r = math.hypot(nx, ny)
            if r >= 0.98:
                continue

            theta = math.atan2(ny, nx)
            # Angular organic perturbation
            r_pert = r
            for phase, freq, amp in lobes:
                r_pert += math.sin(theta * freq + phase) * amp * (0.3 + 0.7 * r)

            # 1. Central aerated white-cyan impact boil (r < 0.42)
            core = math.exp(-((r_pert / 0.34) ** 2) * 1.65)

            # 2. Concentric frothy splash rings at r ~ 0.44, 0.64, 0.80
            ring1 = math.exp(-(((r_pert - 0.44) / 0.075) ** 2)) * 0.85
            ring2 = math.exp(-(((r_pert - 0.64) / 0.065) ** 2)) * 0.62
            ring3 = math.exp(-(((r_pert - 0.81) / 0.055) ** 2)) * 0.38

            # 3. Scattered foam bubbles / droplets
            dots_val = 0.0
            for dx, dy, dr, di in foam_dots:
                dd = math.hypot(nx - dx, ny - dy)
                if dd < dr * 1.8:
                    dots_val += math.exp(-((dd / dr) ** 2) * 1.8) * di

            edge_falloff = max(0.0, 1.0 - (r / 0.96) ** 2.4)
            intensity = min(1.0, (core * 0.95 + ring1 + ring2 + ring3 + dots_val * 0.45) * edge_falloff)
            whiteness = min(1.0, (core * 0.9 + ring1 * 0.75 + dots_val * 0.5) * edge_falloff)

            red = int(min(255, 35 + intensity * 145 + whiteness * 75))
            green = int(min(255, 185 + intensity * 50 + whiteness * 20))
            blue = int(min(255, 242 + intensity * 13))
            alpha = int(min(255, intensity * 240))
            px[x, y] = (red, green, blue, alpha)

    img = img.filter(ImageFilter.GaussianBlur(radius=1.0))
    return img


def make_water_caustics(size: int = 512) -> Image.Image:
    """
    Seamless tileable glowing water caustic network + pinpoint water sparkles.
    """
    rng = random.Random(77)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()

    # Seamless cellular Voronoise / caustic points in [0, 1) x [0, 1)
    pts = [(rng.random(), rng.random()) for _ in range(38)]
    sparkles = [(rng.random(), rng.random(), rng.uniform(0.008, 0.018), rng.uniform(0.7, 1.0)) for _ in range(55)]

    for y in range(size):
        v = y / size
        for x in range(size):
            u = x / size
            # Find 1st and 2nd nearest Voronoi points on unit torus
            d1 = 10.0
            d2 = 10.0
            for px_u, py_v in pts:
                du = abs(u - px_u)
                du = min(du, 1.0 - du)
                dv = abs(v - py_v)
                dv = min(dv, 1.0 - dv)
                d = math.hypot(du, dv)
                if d < d1:
                    d2 = d1
                    d1 = d
                elif d < d2:
                    d2 = d

            # Caustic ridge where d2 - d1 is small
            edge_dist = d2 - d1
            ridge = math.exp(-((edge_dist / 0.042) ** 2) * 1.6)

            # Pinpoint sparkles
            sp_val = 0.0
            for su, sv, sr, si in sparkles:
                du = abs(u - su)
                du = min(du, 1.0 - du)
                dv = abs(v - sv)
                dv = min(dv, 1.0 - dv)
                d = math.hypot(du, dv)
                if d < sr * 2.2:
                    sp_val += math.exp(-((d / sr) ** 2) * 1.8) * si

            val = min(1.0, ridge * 0.78 + sp_val * 0.95)
            r = int(min(255, 80 + val * 175))
            g = int(min(255, 205 + val * 50))
            b = 255
            a = int(min(255, val * 215))
            px[x, y] = (r, g, b, a)

    img = img.filter(ImageFilter.GaussianBlur(radius=0.9))
    return img


def make_water_sparkle(size: int = 256) -> Image.Image:
    """
    Soft glowing water droplet / 4-point star sparkle sprite for mist & floating water motes.
    """
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        ny = (y / size) * 2.0 - 1.0
        for x in range(size):
            nx = (x / size) * 2.0 - 1.0
            r = math.hypot(nx, ny)
            if r >= 1.0:
                continue
            core = math.exp(-((r / 0.22) ** 2) * 1.8)
            halo = math.exp(-((r / 0.55) ** 2) * 1.8) * 0.45
            ray_x = math.exp(-((ny / 0.06) ** 2)) * math.exp(-((nx / 0.65) ** 2)) * 0.75
            ray_y = math.exp(-((nx / 0.06) ** 2)) * math.exp(-((ny / 0.65) ** 2)) * 0.75
            val = min(1.0, core + halo + ray_x + ray_y)
            red = int(min(255, 160 + val * 95))
            green = int(min(255, 225 + val * 30))
            blue = 255
            alpha = int(min(255, val * 255))
            px[x, y] = (red, green, blue, alpha)
    return img


def main():
    v_img = make_waterfall_streaks_v(512)
    u_img = v_img.transpose(Image.Transpose.ROTATE_90)
    splash_img = make_splash_foam_ring(512)
    caustics_img = make_water_caustics(512)
    sparkle_img = make_water_sparkle(256)

    paths = {
        "waterfall_v": os.path.join(OUT_DIR, "fountain_waterfall_streaks_v.png"),
        "waterfall_u": os.path.join(OUT_DIR, "fountain_waterfall_streaks_u.png"),
        "splash_ring": os.path.join(OUT_DIR, "fountain_splash_foam_ring.png"),
        "caustics": os.path.join(OUT_DIR, "fountain_water_caustics.png"),
        "sparkle": os.path.join(OUT_DIR, "fountain_water_sparkle.png"),
    }
    v_img.save(paths["waterfall_v"])
    u_img.save(paths["waterfall_u"])
    splash_img.save(paths["splash_ring"])
    caustics_img.save(paths["caustics"])
    sparkle_img.save(paths["sparkle"])
    for k, p in paths.items():
        print(f"Saved {k}: {p}")


if __name__ == "__main__":
    main()
