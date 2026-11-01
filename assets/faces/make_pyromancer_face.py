"""
=============================================================================
Infinite Towers: Become a Master! - Face Decal Pipeline
Asset: Crimson Pyromancer Face Decal (hero_pyromancer_face.png)
Reference: media_1793475933976_84236ceb.jpg
Target Engine: Roblox Studio Decal / SurfaceAppearance (512x512 Transparent PNG)
=============================================================================
Generates the 2D anime face decal specification and texture map matching the
attached crimson pyromancer artwork using NumPy SDF rasterization
(runs inside Blender Python or standalone Python with zero PIL dependency):
  - Sharp, intense crimson-amber anime eyes with dual-tone glowing fiery irises
  - Confident, slightly parted anime smirk with subtle upper teeth gleam
  - Arched fiery-orange/chestnut eyebrows
  - Soft warm anime nose & blush accents
=============================================================================
"""

import math
import struct
import zlib
from pathlib import Path
import numpy as np

SIZE = 512
OUT_DIR = Path(r"c:\WORK\infinite-tower\assets\faces")
OUT = OUT_DIR / "hero_pyromancer_face.png"
PREVIEW = OUT_DIR / "hero_pyromancer_face_preview.png"


def write_png(path: Path, rgba: np.ndarray):
    """Writes an (H, W, 4) uint8 RGBA array to a standard PNG file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    h, w, _ = rgba.shape
    raw_rows = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (
            struct.pack("!I", len(data))
            + tag
            + data
            + struct.pack("!I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack("!IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png_bytes = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw_rows, 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png_bytes)


def alpha_over(dst: np.ndarray, src_rgb: tuple, src_alpha: np.ndarray):
    """Alpha-composites src_rgb (0..255) with src_alpha (0..1 float) over dst (H,W,4 float)."""
    a = np.clip(src_alpha, 0.0, 1.0)[..., None]
    rgb = np.array(src_rgb, dtype=np.float32).reshape((1, 1, 3))
    out_a = a + dst[..., 3:4] * (1.0 - a)
    safe_a = np.where(out_a > 1e-6, out_a, 1.0)
    dst[..., :3] = (rgb * a + dst[..., :3] * dst[..., 3:4] * (1.0 - a)) / safe_a
    dst[..., 3:4] = out_a


def alpha_over_rgba(dst: np.ndarray, src_rgba: np.ndarray):
    """Alpha-composites an (H,W,4) float array (RGB 0..255, A 0..1) over dst."""
    a = np.clip(src_rgba[..., 3:4], 0.0, 1.0)
    out_a = a + dst[..., 3:4] * (1.0 - a)
    safe_a = np.where(out_a > 1e-6, out_a, 1.0)
    dst[..., :3] = (src_rgba[..., :3] * a + dst[..., :3] * dst[..., 3:4] * (1.0 - a)) / safe_a
    dst[..., 3:4] = out_a


def generate_face_textures():
    H, W = SIZE, SIZE
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    canvas = np.zeros((H, W, 4), dtype=np.float32)

    # 1. Soft warm cheek blush
    for cx in (128.0, W - 128.0):
        cy = 292.0
        d_blush = np.sqrt(((xx - cx) / 40.0) ** 2 + ((yy - cy) / 18.0) ** 2)
        a_blush = np.clip(1.0 - d_blush, 0.0, 1.0) ** 1.6 * 0.22
        alpha_over(canvas, (242, 95, 78), a_blush)

    # 2. Both sharp crimson-amber cat-eyes (using exact shared y_top / y_bot analytical curves)
    for side in (-1, 1):
        cx = 256.0 + side * 98.0
        cy = 248.0
        inner_x = 256.0 + side * 44.0
        outer_x = 256.0 + side * 160.0

        # Normalized horizontal coordinate t_x from inner corner (0.0) to outer corner (1.0)
        t_raw = (xx - inner_x) / (outer_x - inner_x)
        t_x = np.clip(t_raw, 0.0, 1.0)

        # Exact upper and lower lid curves (angled fiercely upward toward outer wing)
        y_top = 262.0 - 40.0 * np.sin(t_x * math.pi * 0.92) - 16.0 * t_x
        y_bot = 262.0 + 22.0 * np.sin(t_x * math.pi * 0.95) - 14.0 * t_x

        in_x = (t_raw >= 0.0) & (t_raw <= 1.0)
        sd_eye = np.maximum(y_top - yy, yy - y_bot)
        eye_mask = np.where(in_x, np.clip(1.0 - sd_eye * 0.85, 0.0, 1.0), 0.0)

        # Sclera fill with soft warm-grey upper lash shadow
        sclera_layer = np.zeros((H, W, 4), dtype=np.float32)
        lid_shade = np.clip((yy - y_top) / 15.0, 0.0, 1.0)
        sclera_layer[..., 0] = 225.0 + 29.0 * lid_shade
        sclera_layer[..., 1] = 212.0 + 38.0 * lid_shade
        sclera_layer[..., 2] = 216.0 + 34.0 * lid_shade
        sclera_layer[..., 3] = eye_mask
        alpha_over_rgba(canvas, sclera_layer)

        # Glowing Crimson-Amber Iris (clipped strictly to eye_mask)
        irx, iry = 32.0, 35.0
        icx = cx - side * 4.0
        icy = cy - 2.0
        d_iris = np.sqrt(((xx - icx) / irx) ** 2 + ((yy - icy) / iry) ** 2)
        iris_mask = np.clip((1.0 - d_iris) * irx * 0.85, 0.0, 1.0) * eye_mask

        # Vertical gradient inside iris: deep crimson top -> fiery orange mid -> molten gold bottom
        v_grad = np.clip((yy - (icy - iry)) / (2.0 * iry), 0.0, 1.0)
        iris_layer = np.zeros((H, W, 4), dtype=np.float32)
        iris_layer[..., 0] = np.where(v_grad < 0.45, 138 + v_grad * 235, 244 + (v_grad - 0.45) * 20)
        iris_layer[..., 1] = np.where(v_grad < 0.45, 16 + v_grad * 205, 108 + (v_grad - 0.45) * 220)
        iris_layer[..., 2] = np.where(v_grad < 0.45, 16 + v_grad * 30, 30 + (v_grad - 0.45) * 145)

        # Dark crimson limbal ring around outer edge of iris + upper iris shadow
        rim_factor = np.clip((d_iris - 0.76) / 0.24, 0.0, 1.0)
        top_shade = np.clip(1.0 - (yy - y_top) / 14.0, 0.0, 1.0) * 0.55
        darken = np.clip(rim_factor * 0.72 + top_shade, 0.0, 0.85)
        iris_layer[..., 0] *= 1.0 - darken * 0.85
        iris_layer[..., 1] *= 1.0 - darken
        iris_layer[..., 2] *= 1.0 - darken
        iris_layer[..., 3] = iris_mask
        alpha_over_rgba(canvas, iris_layer)

        # Sharp vertical oval pupil
        d_pupil = np.sqrt(((xx - icx) / 9.0) ** 2 + ((yy - icy) / 16.5) ** 2)
        pupil_mask = np.clip((1.0 - d_pupil) * 8.0, 0.0, 1.0) * iris_mask
        alpha_over(canvas, (22, 8, 10), pupil_mask)

        # Lower fiery crescent glow inside iris
        d_glow = np.sqrt(((xx - icx) / 19.0) ** 2 + ((yy - (icy + 13.0)) / 9.0) ** 2)
        glow_mask = np.clip(1.0 - d_glow, 0.0, 1.0) ** 1.5 * iris_mask * 0.75
        alpha_over(canvas, (255, 236, 140), glow_mask)

        # Crisp anime specular catchlights
        hl1_d = np.sqrt(((xx - (icx - 10.5)) / 8.0) ** 2 + ((yy - (icy - 11.5)) / 8.5) ** 2)
        hl1_mask = np.clip((1.0 - hl1_d) * 7.0, 0.0, 1.0) * eye_mask
        alpha_over(canvas, (255, 255, 255), hl1_mask)

        hl2_d = np.sqrt(((xx - (icx + 9.5)) / 4.2) ** 2 + ((yy - (icy + 10.5)) / 4.2) ** 2)
        hl2_mask = np.clip((1.0 - hl2_d) * 5.0, 0.0, 1.0) * eye_mask
        alpha_over(canvas, (255, 248, 225), hl2_mask)

        # Bold winged upper eyelash built directly along y_top (zero gap!)
        t_ext = np.clip(t_raw, -0.04, 1.15)
        y_lash_center = (
            262.0
            - 40.0 * np.sin(np.clip(t_ext, 0.0, 1.0) * math.pi * 0.92)
            - 16.0 * t_ext
            - np.maximum(0.0, t_ext - 0.92) * 55.0  # upward cat-eye flick at outer wing
        )
        # Thickness tapers at inner corner and swells at outer wing before flicking to a sharp tip
        lash_half_w = np.where(
            t_ext <= 1.0,
            2.2 + 4.2 * (t_x ** 0.8),
            np.maximum(0.0, 6.4 * (1.0 - (t_ext - 1.0) / 0.15)),
        )
        in_lash_x = (t_raw >= -0.03) & (t_raw <= 1.15)
        d_ulash = np.abs(yy - (y_lash_center - lash_half_w * 0.35))
        ulash_mask = np.where(in_lash_x, np.clip(lash_half_w - d_ulash + 0.5, 0.0, 1.0), 0.0)
        alpha_over(canvas, (28, 10, 12), ulash_mask)

        # Delicate lower lash line along y_bot
        in_ll_x = (t_raw >= 0.08) & (t_raw <= 0.96)
        d_llash = np.abs(yy - y_bot)
        llash_mask = np.where(in_ll_x, np.clip(2.0 - d_llash, 0.0, 1.0) * 0.85, 0.0)
        alpha_over(canvas, (46, 16, 16), llash_mask)

        # Upper eyelid crease line (parallel above y_top)
        in_cr_x = (t_raw >= 0.08) & (t_raw <= 0.90)
        y_crease = y_top - 11.0 - 3.0 * np.sin(t_x * math.pi)
        d_crease = np.abs(yy - y_crease)
        crease_mask = np.where(in_cr_x, np.clip(1.6 - d_crease, 0.0, 1.0) * 0.55, 0.0)
        alpha_over(canvas, (135, 55, 42), crease_mask)

        # 3. Fierce arched fiery-copper eyebrows (furrowed inward toward bridge)
        t_brow = (xx - (256.0 + side * 34.0)) / ((256.0 + side * 168.0) - (256.0 + side * 34.0))
        t_b = np.clip(t_brow, 0.0, 1.0)
        in_brow_x = (t_brow >= 0.0) & (t_brow <= 1.0)
        y_brow = 204.0 - 24.0 * np.sin(t_b * math.pi * 0.82) - 12.0 * t_b
        brow_half_w = 4.0 * (1.0 - 0.55 * (t_b ** 1.4))
        d_brow = np.abs(yy - y_brow)
        brow_mask = np.where(in_brow_x, np.clip(brow_half_w - d_brow + 0.5, 0.0, 1.0), 0.0)
        brow_edge = np.where(
            in_brow_x,
            np.clip(brow_half_w + 1.1 - d_brow, 0.0, 1.0) * (1.0 - brow_mask) * 0.65,
            0.0,
        )
        alpha_over(canvas, (192, 58, 24), brow_mask)
        alpha_over(canvas, (64, 20, 14), brow_edge)

    # 4. Crisp anime nose shadow & highlight tick
    in_nose_y = (yy >= 306.0) & (yy <= 328.0)
    t_nose = np.clip((yy - 306.0) / 22.0, 0.0, 1.0)
    x_nose = 255.0 - 3.0 * np.sin(t_nose * math.pi)
    nose_mask = np.where(in_nose_y, np.clip(1.7 - np.abs(xx - x_nose), 0.0, 1.0) * 0.78, 0.0)
    alpha_over(canvas, (92, 40, 32), nose_mask)
    d_nose_shade = np.sqrt(((xx - 259.5) / 5.5) ** 2 + ((yy - 323.0) / 4.5) ** 2)
    alpha_over(canvas, (175, 92, 74), np.clip(1.0 - d_nose_shade, 0.0, 1.0) * 0.45)

    # 5. Expressive parted anime mouth / confident smirk (matching reference image)
    m_left_x, m_right_x = 220.0, 296.0
    mt_raw = (xx - m_left_x) / (m_right_x - m_left_x)
    mt_x = np.clip(mt_raw, 0.0, 1.0)
    in_mouth_x = (mt_raw >= 0.0) & (mt_raw <= 1.0)

    y_m_top = 380.0 - 7.0 * mt_x - 8.5 * np.sin(mt_x * math.pi)
    y_m_bot = 380.0 - 7.0 * mt_x + 17.5 * np.sin(mt_x * math.pi)
    sd_mouth = np.maximum(y_m_top - yy, yy - y_m_bot)
    mouth_mask = np.where(in_mouth_x, np.clip(1.0 - sd_mouth * 0.9, 0.0, 1.0), 0.0)

    # Warm rose-red inner mouth cavity
    alpha_over(canvas, (124, 34, 36), mouth_mask)
    # Soft lower tongue highlight
    tongue_d = np.sqrt(((xx - 258.0) / 23.0) ** 2 + ((yy - 391.0) / 11.0) ** 2)
    alpha_over(canvas, (208, 84, 82), np.clip(1.0 - tongue_d, 0.0, 1.0) * mouth_mask * 0.85)
    # Crisp white upper teeth gleam strip
    teeth_mask = np.clip((y_m_top + 6.5) - yy, 0.0, 1.0) * mouth_mask
    alpha_over(canvas, (254, 250, 246), teeth_mask)

    # Mouth lip outlines
    top_lip_mask = np.where(in_mouth_x, np.clip(2.3 - np.abs(yy - y_m_top), 0.0, 1.0), 0.0)
    bot_lip_mask = np.where(in_mouth_x, np.clip(2.0 - np.abs(yy - y_m_bot), 0.0, 1.0), 0.0)
    alpha_over(canvas, (42, 14, 14), top_lip_mask)
    alpha_over(canvas, (42, 14, 14), bot_lip_mask)

    # Save transparent decal PNG
    out_rgba = np.zeros((H, W, 4), dtype=np.uint8)
    out_rgba[..., :3] = np.clip(np.round(canvas[..., :3]), 0, 255).astype(np.uint8)
    out_rgba[..., 3] = np.clip(np.round(canvas[..., 3] * 255.0), 0, 255).astype(np.uint8)
    write_png(OUT, out_rgba)
    print(f"[SAVED] Transparent Face Decal: {OUT}")

    # Save skin-composited preview PNG (also used directly on the Head UV in Blender!)
    preview = np.zeros((H, W, 4), dtype=np.float32)
    preview[..., 0] = 247.0  # #F7DFC6 Warm porcelain-ivory
    preview[..., 1] = 223.0
    preview[..., 2] = 198.0
    preview[..., 3] = 1.0
    alpha_over_rgba(preview, canvas)
    prev_rgba = np.zeros((H, W, 4), dtype=np.uint8)
    prev_rgba[..., :3] = np.clip(np.round(preview[..., :3]), 0, 255).astype(np.uint8)
    prev_rgba[..., 3] = 255
    write_png(PREVIEW, prev_rgba)
    print(f"[SAVED] Skin-Composited Face Texture: {PREVIEW}")


if __name__ == "__main__":
    generate_face_textures()
