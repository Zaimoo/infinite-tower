"""Generate 4 sculpted low-poly/stylized-realistic Hub pond FBXs, PBR texture sets,
Cycles preview renders, and HubPonds.blend inspectable scene.

Models created in assets/meshes/environment/:
  1. HeroBridgePond.fbx        - Replaces Hub ReflectingPool with arched stone bridge & lotus basin
  2. WaterfallBoulderPond.fbx  - Tiered cliff waterfall boulder lagoon + driftwood, ducklings, cattails
  3. RockeryKoiPond.fbx        - Crescent Japanese/Zen garden rockery pond with spout & swimming Koi
  4. SteppingStreamPond.fbx    - Twin-tier spring pond with split cascade & walkable stepping stones

Texture sets created in assets/meshes/environment/textures/:
  Tex_PondRock, Tex_BridgeMasonry, Tex_PondBed, Tex_PondWater (RGBA),
  Tex_WaterfallFoam (RGBA), Tex_PondFlora (Atlas)

Run via Blender CLI:
  "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b -P tools/blender/generate_hub_ponds.py
"""

from __future__ import annotations

import math
import os
import random
import struct
import zlib
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

REPO_ROOT = Path(r"c:\WORK\infinite-tower")
ENV_DIR = REPO_ROOT / "assets" / "meshes" / "environment"
TEX_DIR = ENV_DIR / "textures"
SCRATCH_DIR = Path(
    r"C:\Users\enter\.gemini\antigravity\brain\acb0e4c7-bcfb-4008-99fb-2546b64122c1\scratch"
)

MAX_TRIS_PER_MESHPART = 9000
MAX_FBX_BYTES = 18 * 1024 * 1024


# ---------------------------------------------------------------------------
# Fast compressed PNG writer (keeps embedded FBX well below 20 MB Open Cloud limit)
# ---------------------------------------------------------------------------

def save_png(path: Path, pixels_u8: np.ndarray, has_alpha: bool) -> None:
    """Save (H, W, C) uint8 array (row 0 = top of image) using Blender's native libpng writer."""
    h, w, c = pixels_u8.shape
    expected_c = 4 if has_alpha else 3
    if c != expected_c:
        raise ValueError(f"Expected {expected_c} channels for {path.name}, got {c}")
    path.parent.mkdir(parents=True, exist_ok=True)
    # Blender expects row 0 = bottom-left (flip vertically) and always 4 channels in img.pixels
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :c] = np.ascontiguousarray(pixels_u8[::-1], dtype=np.float32) * (1.0 / 255.0)
    img = bpy.data.images.new(f"_tmp_{path.stem}", width=w, height=h, alpha=has_alpha, float_buffer=False)
    try:
        img.colorspace_settings.name = "Non-Color"
        img.pixels.foreach_set(rgba.ravel())
        img.filepath_raw = str(path)
        img.file_format = "PNG"
        img.save()
    finally:
        bpy.data.images.remove(img)


# ---------------------------------------------------------------------------
# Periodic Procedural Texture Synthesis Helpers (100% seamless)
# ---------------------------------------------------------------------------

def periodic_fbm(res: int, octaves: list[tuple[float, float]], seed: int) -> np.ndarray:
    """Seamless periodic multi-octave gradient/spectral FBM in [0, 1]."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((res, res), dtype=np.float32)
    ky = np.fft.fftfreq(res)[:, None] * res
    kx = np.fft.fftfreq(res)[None, :] * res
    freq_r = np.sqrt(kx * kx + ky * ky)
    total_w = 0.0
    for cutoff, weight in octaves:
        white = rng.standard_normal((res, res)) + 1j * rng.standard_normal((res, res))
        # Smooth bandpass/lowpass bell centered near cutoff
        band = np.exp(-0.5 * ((freq_r - cutoff) / max(1.0, cutoff * 0.65)) ** 2)
        band[0, 0] = 0.0
        comp = np.fft.ifft2(white * band).real
        std = comp.std()
        if std > 1e-6:
            comp /= std
        acc += comp * weight
        total_w += weight
    acc /= max(1e-6, total_w)
    acc = (acc - acc.min()) / max(1e-6, acc.max() - acc.min())
    return acc.astype(np.float32)


def periodic_worley(res: int, cells: int, jitter: float, seed: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Return seamless periodic (F1_dist, F2_minus_F1_edge, cell_id_hash) in [0, 1]."""
    rng = np.random.default_rng(seed)
    pts_x = (np.arange(cells)[:, None] + 0.5 + (rng.random((cells, cells)) - 0.5) * jitter) % cells
    pts_y = (np.arange(cells)[None, :] + 0.5 + (rng.random((cells, cells)) - 0.5) * jitter) % cells
    # Actually shape (cells, cells): axis 0 = cy, axis 1 = cx
    px = (np.arange(cells)[None, :] + 0.5 + (rng.random((cells, cells)) - 0.5) * jitter) / cells
    py = (np.arange(cells)[:, None] + 0.5 + (rng.random((cells, cells)) - 0.5) * jitter) / cells
    cell_val = rng.random((cells, cells)).astype(np.float32)

    u = (np.arange(res, dtype=np.float32) + 0.5) / res
    v = (np.arange(res, dtype=np.float32) + 0.5) / res
    uu, vv = np.meshgrid(u, v)  # shape (res, res)

    cx = np.floor(uu * cells).astype(np.int32) % cells
    cy = np.floor(vv * cells).astype(np.int32) % cells

    d1 = np.full((res, res), 1e9, dtype=np.float32)
    d2 = np.full((res, res), 1e9, dtype=np.float32)
    cid = np.zeros((res, res), dtype=np.float32)

    for dy in (-1, 0, 1):
        ny = (cy + dy) % cells
        for dx in (-1, 0, 1):
            nx = (cx + dx) % cells
            fx = px[ny, nx]
            fy = py[ny, nx]
            # Wrap-around shortest distance in [0, 1) torus
            ddx = uu - fx
            ddx -= np.round(ddx)
            ddy = vv - fy
            ddy -= np.round(ddy)
            dist = np.sqrt(ddx * ddx + ddy * ddy) * cells
            smaller1 = dist < d1
            d2 = np.where(smaller1, d1, np.minimum(d2, dist))
            d1 = np.where(smaller1, dist, d1)
            cid = np.where(smaller1, cell_val[ny, nx], cid)

    f1 = np.clip(d1 / 1.15, 0.0, 1.0)
    edge = np.clip((d2 - d1) / 0.85, 0.0, 1.0)
    return f1, edge, cid


def height_to_normal(height: np.ndarray, strength: float, tile_wrap: bool = True) -> np.ndarray:
    """Convert [0, 1] heightfield (row 0 = top) to tangent-space RGB normal map uint8."""
    if tile_wrap:
        dx = 0.5 * (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1))
        # Image row 0 is top (+V direction in Blender tangent space means dy flips cleanly)
        dy = 0.5 * (np.roll(height, 1, axis=0) - np.roll(height, -1, axis=0))
    else:
        padded = np.pad(height, 1, mode="edge")
        dx = 0.5 * (padded[1:-1, 2:] - padded[1:-1, :-2])
        dy = 0.5 * (padded[:-2, 1:-1] - padded[2:, 1:-1])

    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    nrm = np.stack([nx * inv_len * 0.5 + 0.5, ny * inv_len * 0.5 + 0.5, nz * inv_len * 0.5 + 0.5], axis=-1)
    return np.clip(nrm * 255.0, 0, 255).astype(np.uint8)


def lerp_rgb(a: tuple[int, int, int], b: tuple[int, int, int], t: np.ndarray) -> np.ndarray:
    t3 = np.clip(t, 0.0, 1.0)[..., None]
    ca = np.array(a, dtype=np.float32)
    cb = np.array(b, dtype=np.float32)
    return ca * (1.0 - t3) + cb * t3


def bleed_gutter(rgb: np.ndarray, x0: int, y0: int, x1: int, y1: int, pad: int) -> None:
    """Extend tile border pixels outward by `pad` px to eliminate UV seam/mipmap bleed."""
    h, w, _ = rgb.shape
    px0, px1 = max(0, x0 - pad), min(w, x1 + pad)
    py0, py1 = max(0, y0 - pad), min(h, y1 + pad)
    for x in range(px0, x0):
        rgb[y0:y1, x] = rgb[y0:y1, x0]
    for x in range(x1, px1):
        rgb[y0:y1, x] = rgb[y0:y1, x1 - 1]
    for y in range(py0, y0):
        rgb[y, px0:px1] = rgb[y0, px0:px1]
    for y in range(y1, py1):
        rgb[y, px0:px1] = rgb[y1 - 1, px0:px1]


# ---------------------------------------------------------------------------
# Generate All 6 PBR Texture Sets
# ---------------------------------------------------------------------------

def generate_all_textures() -> dict[str, dict[str, Path]]:
    TEX_DIR.mkdir(parents=True, exist_ok=True)
    registry: dict[str, dict[str, Path]] = {}

    def _save_set(name: str, color_u8: np.ndarray, height_f32: np.ndarray, rough_f32: np.ndarray,
                  normal_strength: float, has_alpha: bool = False, wrap_normal: bool = True) -> None:
        c_path = TEX_DIR / f"{name}_Color.png"
        n_path = TEX_DIR / f"{name}_Normal.png"
        r_path = TEX_DIR / f"{name}_Roughness.png"
        save_png(c_path, color_u8, has_alpha=has_alpha)
        save_png(n_path, height_to_normal(height_f32, normal_strength, tile_wrap=wrap_normal), has_alpha=False)
        r_clamped = np.clip(rough_f32, 0.05, 0.96)
        r_u8 = np.repeat((r_clamped * 255.0).astype(np.uint8)[..., None], 3, axis=-1)
        save_png(r_path, r_u8, has_alpha=False)
        registry[name] = {"Color": c_path, "Normal": n_path, "Roughness": r_path}

    # 1. Tex_PondRock (1024x1024): Soft natural granite -> mossy meadow cap (NO sharp Worley lines!)
    R = 1024
    fbm_big = periodic_fbm(R, [(4, 1.0), (11, 0.7), (28, 0.4)], seed=101)
    fbm_mid = periodic_fbm(R, [(18, 0.8), (44, 0.55), (95, 0.3)], seed=105)
    fbm_fine = periodic_fbm(R, [(48, 0.8), (115, 0.55), (220, 0.35)], seed=102)
    f1_rock, edge_w, cid_w = periodic_worley(R, cells=8, jitter=0.92, seed=103)
    # Row 0 in image = top (V = 1.0), row R-1 = bottom (V = 0.0)
    v_grid = np.linspace(1.0, 0.0, R, dtype=np.float32)[:, None] * np.ones((1, R), dtype=np.float32)
    v_warped = np.clip(v_grid + (fbm_big - 0.5) * 0.22 + (fbm_mid - 0.5) * 0.08, 0.0, 1.0)

    # Soft marbled warm/cool alpine granite without geometric spiderweb cracks
    rock_var = 0.42 * fbm_big + 0.32 * fbm_mid + 0.14 * f1_rock + 0.12 * fbm_fine
    granite_col = lerp_rgb((82, 84, 84), (148, 144, 134), rock_var)
    subtle_fracture = np.clip((0.08 - edge_w) * 4.0, 0.0, 1.0) * fbm_mid
    granite_col = granite_col * (1.0 - 0.24 * subtle_fracture[..., None])
    wet_col = granite_col * np.array([0.44, 0.52, 0.58], dtype=np.float32)
    moss_col = lerp_rgb((44, 82, 32), (92, 138, 48), 0.55 * fbm_mid + 0.45 * fbm_fine)

    wet_t = np.clip((0.24 - v_warped) / 0.18, 0.0, 1.0)[..., None]
    moss_t = np.clip((v_warped - 0.62) / 0.26, 0.0, 1.0)[..., None]
    rock_rgb = granite_col * (1.0 - wet_t) + wet_col * wet_t
    rock_rgb = rock_rgb * (1.0 - moss_t) + moss_col * moss_t
    rock_h = (0.45 * fbm_big + 0.35 * fbm_mid + 0.20 * fbm_fine) * (1.0 - 0.35 * moss_t[..., 0]) + 0.22 * moss_t[..., 0] * fbm_fine
    rock_r = (0.66 + 0.14 * fbm_fine - 0.08 * fbm_big) * (1.0 - wet_t[..., 0]) + 0.16 * wet_t[..., 0]
    rock_r = rock_r * (1.0 - moss_t[..., 0]) + (0.86 + 0.06 * fbm_fine) * moss_t[..., 0]
    _save_set("Tex_PondRock", np.clip(rock_rgb, 0, 255).astype(np.uint8), rock_h, rock_r, normal_strength=5.0)

    # 2. Tex_BridgeMasonry (1024x1024): Bottom half (V<0.5)=Warm Cobble Pavers, Top half (V>0.5)=Rich Charcoal Slate
    R = 1024
    _, cob_edge, cob_cid = periodic_worley(R, cells=16, jitter=0.82, seed=201)
    stone_f = periodic_fbm(R, [(12, 0.8), (38, 0.5), (105, 0.35)], seed=202)
    warm_cob = lerp_rgb((108, 82, 72), (150, 120, 102), cob_cid)
    cool_cob = lerp_rgb((86, 90, 94), (118, 116, 114), stone_f)
    cob_stone = warm_cob * 0.74 + cool_cob * 0.26 + (stone_f[..., None] - 0.5) * 26.0
    cob_mortar = np.clip((0.12 - cob_edge) * 8.5, 0.0, 1.0)
    cob_rgb = cob_stone * (1.0 - cob_mortar[..., None]) + np.array([48, 54, 46], dtype=np.float32) * cob_mortar[..., None]
    cob_h = np.clip(cob_edge * 2.4, 0.0, 1.0) * (1.0 - cob_mortar) * 0.8 + stone_f * 0.2
    cob_r = 0.62 + 0.16 * cob_mortar + 0.12 * (1.0 - stone_f)

    # Running bond ashlar rich dark charcoal-slate blocks in top half (V in [0.5, 1.0])
    u_px = np.linspace(0.0, 1.0, R, endpoint=False)[None, :] * np.ones((R, 1), dtype=np.float32)
    v_px = np.linspace(1.0, 0.0, R, endpoint=False)[:, None] * np.ones((1, R), dtype=np.float32)
    rows = 12.0
    cols = 6.0
    row_i = np.floor(v_px * rows)
    u_shifted = (u_px * cols + 0.5 * (row_i % 2)) % cols
    col_i = np.floor(u_shifted)
    fx = u_shifted - col_i
    fy = v_px * rows - row_i
    b_seam = np.maximum(np.maximum(0.06 - fx, fx - 0.94), np.maximum(0.08 - fy, fy - 0.92)) / 0.08
    b_seam = np.clip(b_seam, 0.0, 1.0)
    block_hash = ((np.sin(row_i * 19.3 + col_i * 47.1) * 43758.5453) % 1.0).astype(np.float32)
    slate_rgb = lerp_rgb((32, 35, 40), (62, 66, 74), 0.55 * block_hash + 0.45 * stone_f)
    slate_rgb = slate_rgb * (1.0 - 0.58 * b_seam[..., None])
    slate_h = (1.0 - b_seam) * 0.72 + stone_f * 0.28
    slate_r = 0.42 + 0.26 * b_seam + 0.14 * (1.0 - stone_f)

    is_slate = (v_px >= 0.50).astype(np.float32)
    m_rgb = cob_rgb * (1.0 - is_slate[..., None]) + slate_rgb * is_slate[..., None]
    m_h = cob_h * (1.0 - is_slate) + slate_h * is_slate
    m_r = cob_r * (1.0 - is_slate) + slate_r * is_slate
    _save_set("Tex_BridgeMasonry", np.clip(m_rgb, 0, 255).astype(np.uint8), m_h, m_r, normal_strength=6.0, wrap_normal=False)

    # 3. Tex_PondBed (512x512): Underwater dark silt & rounded river pebbles
    R = 512
    f1_p, edge_p, cid_p = periodic_worley(R, cells=18, jitter=0.85, seed=301)
    silt_f = periodic_fbm(R, [(4, 1.0), (14, 0.6), (48, 0.3)], seed=302)
    pebble_col = lerp_rgb((36, 60, 62), (72, 92, 82), 0.6 * cid_p + 0.4 * silt_f)
    silt_col = lerp_rgb((20, 44, 48), (44, 74, 58), silt_f)
    peb_mask = np.clip((0.58 - f1_p) * 3.5, 0.0, 1.0)
    bed_rgb = silt_col * (1.0 - peb_mask[..., None]) + pebble_col * peb_mask[..., None]
    bed_h = np.clip(1.0 - f1_p, 0.0, 1.0) * peb_mask * 0.65 + silt_f * 0.35
    bed_r = 0.52 + 0.24 * (1.0 - peb_mask)
    _save_set("Tex_PondBed", np.clip(bed_rgb, 0, 255).astype(np.uint8), bed_h, bed_r, normal_strength=4.5)

    # 4. Tex_PondWater (512x512 RGBA): Azure-turquoise gentle wave ripples + clear translucent alpha
    R = 512
    w_a = periodic_fbm(R, [(3, 0.8), (8, 1.0), (20, 0.55), (42, 0.22)], seed=401)
    w_b = periodic_fbm(R, [(5, 0.9), (13, 0.7), (28, 0.35)], seed=402)
    wave_h = 0.62 * w_a + 0.38 * w_b
    crest = np.clip((wave_h - 0.58) / 0.42, 0.0, 1.0)
    w_rgb = lerp_rgb((58, 152, 214), (126, 210, 244), 0.65 * wave_h + 0.35 * crest)
    w_rgb = w_rgb * (1.0 - crest[..., None] * 0.35) + np.array([216, 244, 255], dtype=np.float32) * (crest[..., None] * 0.35)
    w_alpha = np.clip(148.0 + 62.0 * crest + 18.0 * w_a, 140.0, 224.0)[..., None]
    w_rgba = np.concatenate([w_rgb, w_alpha], axis=-1)
    w_rough = 0.07 + 0.07 * crest
    _save_set("Tex_PondWater", np.clip(w_rgba, 0, 255).astype(np.uint8), wave_h, w_rough, normal_strength=3.6, has_alpha=True)

    # 5. Tex_WaterfallFoam (512x512 RGBA): Directional streaking water + bright splash ring fading softly at V=0
    R = 512
    u_coords = np.linspace(0.0, 1.0, R, endpoint=False)[None, :]
    v_coords = np.linspace(1.0, 0.0, R, endpoint=False)[:, None]
    streak_base = periodic_fbm(R, [(10, 0.8), (24, 1.0), (54, 0.5)], seed=501)
    streaks = 0.5 + 0.28 * np.sin(u_coords * 2.0 * np.pi * 9.0 + streak_base * 4.5) \
              + 0.22 * np.sin(u_coords * 2.0 * np.pi * 21.0 - v_coords * 2.0 * np.pi * 2.0 + streak_base * 3.0)
    streaks = np.clip(streaks, 0.0, 1.0) * 0.7 + 0.3 * streak_base
    crest_foam = np.clip((v_coords - 0.84) / 0.16, 0.0, 1.0)
    splash_foam = np.clip((0.24 - np.abs(v_coords - 0.14)) / 0.18, 0.0, 1.0)
    foam_t = np.clip(np.maximum(crest_foam, splash_foam) * 0.88 + np.clip((streaks - 0.52) * 2.4, 0.0, 1.0) * 0.72, 0.0, 1.0)
    wf_rgb = lerp_rgb((82, 186, 234), (244, 253, 255), foam_t)
    # Softly fade alpha toward 0 right at V < 0.08 so splash rings dissolve gently into Pond_Water!
    rim_fade = np.clip(v_coords / 0.08, 0.0, 1.0)
    wf_alpha = np.clip((180.0 + 72.0 * foam_t) * rim_fade, 0.0, 252.0)[..., None]
    wf_rgba = np.concatenate([wf_rgb, wf_alpha], axis=-1)
    wf_h = 0.55 * streaks + 0.45 * foam_t
    wf_r = 0.12 + 0.22 * foam_t
    _save_set("Tex_WaterfallFoam", np.clip(wf_rgba, 0, 255).astype(np.uint8), wf_h, wf_r, normal_strength=4.5, has_alpha=True, wrap_normal=False)

    # 6. Tex_PondFlora (1024x1024 RGB Atlas): 4x2 clean tiles with 16px edge bleed
    R = 1024
    flora_rgb = np.zeros((R, R, 3), dtype=np.float32) + 80.0
    flora_h = np.full((R, R), 0.5, dtype=np.float32)
    flora_r = np.full((R, R), 0.5, dtype=np.float32)
    detail_n = periodic_fbm(R, [(24, 0.8), (64, 0.5), (140, 0.3)], seed=601)

    def _tile_coords(x0: int, y0: int, x1: int, y1: int) -> tuple[np.ndarray, np.ndarray]:
        tu = np.linspace(0.0, 1.0, x1 - x0, dtype=np.float32)[None, :]
        tv = np.linspace(1.0, 0.0, y1 - y0, dtype=np.float32)[:, None]
        return tu, tv

    # Top row in Blender V=[0.5..1.0] corresponds to image rows y=[0..512]!
    # Tile (0, top): Lily Pad [x: 16..240, y: 16..496] -> UV u=[0.0156..0.234], v=[0.5156..0.984]
    x0, y0, x1, y1 = 16, 16, 240, 496
    tu, tv = _tile_coords(x0, y0, x1, y1)
    dx_c = (tu - 0.5) * 2.0
    dy_c = (tv - 0.5) * 2.0
    rad = np.sqrt(dx_c * dx_c + dy_c * dy_c)
    ang = np.arctan2(dy_c, dx_c)
    vein = np.abs(np.sin(ang * 10.0)) ** 6
    l_rgb = lerp_rgb((46, 108, 38), (102, 156, 54), np.clip(rad * 0.85, 0.0, 1.0))
    l_rgb = l_rgb * (1.0 - 0.18 * vein[..., None]) + np.array([124, 174, 68], dtype=np.float32) * (0.20 * (1.0 - vein[..., None]) * rad[..., None])
    l_rgb += (detail_n[y0:y1, x0:x1, None] - 0.5) * 18.0
    flora_rgb[y0:y1, x0:x1] = l_rgb
    flora_h[y0:y1, x0:x1] = 0.5 + 0.35 * vein + 0.15 * detail_n[y0:y1, x0:x1]
    flora_r[y0:y1, x0:x1] = 0.36 + 0.14 * detail_n[y0:y1, x0:x1]
    bleed_gutter(flora_rgb, x0, y0, x1, y1, 14)

    # Tile (1, top): Pink Lotus Petal + Golden Center [x: 272..496, y: 16..496]
    # Note: bottom 22% of tile (tv < 0.22) = golden stamen pollen, tv >= 0.24 = blush->rose lotus petal!
    x0, y0, x1, y1 = 272, 16, 496, 496
    tu, tv = _tile_coords(x0, y0, x1, y1)
    stamen = (tv < 0.22).astype(np.float32)
    pt = np.clip((tv - 0.24) / 0.76, 0.0, 1.0)
    rib = 0.5 + 0.5 * np.sin(tu * np.pi * 16.0)
    petal_rgb = lerp_rgb((252, 232, 238), (218, 86, 134), pt ** 0.75) * (0.94 + 0.06 * rib[..., None])
    gold_rgb = lerp_rgb((212, 154, 24), (250, 212, 68), detail_n[y0:y1, x0:x1])
    lot_rgb = petal_rgb * (1.0 - stamen[..., None]) + gold_rgb * stamen[..., None]
    flora_rgb[y0:y1, x0:x1] = lot_rgb
    flora_h[y0:y1, x0:x1] = 0.45 + 0.25 * rib * (1.0 - stamen) + 0.3 * stamen * detail_n[y0:y1, x0:x1]
    flora_r[y0:y1, x0:x1] = 0.42 + 0.18 * stamen
    bleed_gutter(flora_rgb, x0, y0, x1, y1, 14)

    # Tile (2, top): Sedge Reeds (left tu<0.48) + Velvety Cattail Head & Stem (right tu>=0.52) [x: 528..752, y: 16..496]
    x0, y0, x1, y1 = 528, 16, 752, 496
    tu, tv = _tile_coords(x0, y0, x1, y1)
    is_cat = (tu >= 0.50).astype(np.float32)
    blade_rib = 0.5 + 0.5 * np.sin(tu * np.pi * 24.0)
    blade_rgb = lerp_rgb((46, 92, 34), (96, 144, 52), tv * 0.75 + 0.25 * blade_rib)
    # Cattail: bottom half tv<0.42 = ochre-green stalk, top tv>=0.44 = rich dark umber fuzzy seed head
    is_head = (tv >= 0.44).astype(np.float32)
    stalk_rgb = lerp_rgb((72, 102, 44), (118, 128, 56), tv * 2.0)
    head_rgb = lerp_rgb((56, 34, 20), (92, 54, 30), detail_n[y0:y1, x0:x1])
    cat_rgb = stalk_rgb * (1.0 - is_head[..., None]) + head_rgb * is_head[..., None]
    rc_rgb = blade_rgb * (1.0 - is_cat[..., None]) + cat_rgb * is_cat[..., None]
    flora_rgb[y0:y1, x0:x1] = rc_rgb
    flora_h[y0:y1, x0:x1] = (0.35 * blade_rib) * (1.0 - is_cat) + is_cat * (0.4 + 0.6 * detail_n[y0:y1, x0:x1] * is_head)
    flora_r[y0:y1, x0:x1] = 0.48 * (1.0 - is_cat) + is_cat * (0.55 + 0.35 * is_head)
    bleed_gutter(flora_rgb, x0, y0, x1, y1, 14)

    # Tile (3, top): Mossy Driftwood Bark [x: 784..1008, y: 16..496]
    x0, y0, x1, y1 = 784, 16, 1008, 496
    tu, tv = _tile_coords(x0, y0, x1, y1)
    grain = np.sin(tu * np.pi * 18.0 + detail_n[y0:y1, x0:x1] * 3.5) * 0.5 + 0.5
    wood_rgb = lerp_rgb((74, 54, 38), (118, 92, 66), grain * 0.65 + 0.35 * detail_n[y0:y1, x0:x1])
    moss_patch = np.clip((detail_n[y0:y1, x0:x1] - 0.52) * 3.2, 0.0, 1.0)
    moss_w = lerp_rgb((54, 96, 38), (88, 134, 48), grain)
    dw_rgb = wood_rgb * (1.0 - moss_patch[..., None]) + moss_w * moss_patch[..., None]
    flora_rgb[y0:y1, x0:x1] = dw_rgb
    flora_h[y0:y1, x0:x1] = 0.45 * grain + 0.35 * detail_n[y0:y1, x0:x1]
    flora_r[y0:y1, x0:x1] = 0.72 + 0.16 * moss_patch
    bleed_gutter(flora_rgb, x0, y0, x1, y1, 14)

    # Bottom row in Blender V=[0.0..0.5] corresponds to image rows y=[512..1024]!
    # Koi Carp Swatch (bottom-left half) [x: 16..496, y: 528..1008] -> u=[0.0156..0.484], v=[0.0156..0.484]
    # Left half (tu<0.48): Kohaku Red-White-Ink Koi, Right half (tu>=0.52): Golden Yamabuki Koi
    x0, y0, x1, y1 = 16, 528, 496, 1008
    tu, tv = _tile_coords(x0, y0, x1, y1)
    is_gold = (tu >= 0.50).astype(np.float32)
    scales = 0.5 + 0.5 * np.sin(tu * np.pi * 40.0) * np.sin(tv * np.pi * 24.0)
    blotch = periodic_fbm(R, [(6, 1.0), (14, 0.6)], seed=602)[y0:y1, x0:x1]
    red_patch = np.clip((blotch - 0.44) * 8.0, 0.0, 1.0)
    ink_spot = np.clip((0.26 - blotch) * 12.0, 0.0, 1.0)
    kohaku = lerp_rgb((244, 240, 232), (228, 62, 24), red_patch)
    kohaku = kohaku * (1.0 - ink_spot[..., None]) + np.array([26, 28, 34], dtype=np.float32) * ink_spot[..., None]
    yamabuki = lerp_rgb((248, 198, 56), (220, 118, 20), 0.5 * blotch + 0.5 * tv)
    koi_rgb = (kohaku * (1.0 - is_gold[..., None]) + yamabuki * is_gold[..., None]) * (0.90 + 0.10 * scales[..., None])
    flora_rgb[y0:y1, x0:x1] = koi_rgb
    flora_h[y0:y1, x0:x1] = 0.4 + 0.5 * scales
    flora_r[y0:y1, x0:x1] = 0.16 + 0.10 * (1.0 - scales)
    bleed_gutter(flora_rgb, x0, y0, x1, y1, 14)

    # Duckling & Duck Plumage Swatch (bottom-right half) [x: 528..1008, y: 528..1008]
    # tu<0.38: Buttercup Golden Duckling, 0.38..0.64: Orange Beak/Feet, tu>=0.64: Cream/Mallard Adult Duck
    x0, y0, x1, y1 = 528, 528, 1008, 1008
    tu, tv = _tile_coords(x0, y0, x1, y1)
    dn = detail_n[y0:y1, x0:x1]
    duckling = lerp_rgb((228, 174, 34), (252, 218, 68), dn * 0.6 + tv * 0.4)
    beak = lerp_rgb((218, 108, 22), (242, 142, 36), dn)
    adult = lerp_rgb((196, 184, 162), (96, 126, 98), np.clip((tv - 0.65) * 4.0, 0.0, 1.0))
    m_beak = ((tu >= 0.36) & (tu < 0.64)).astype(np.float32)
    m_adult = (tu >= 0.64).astype(np.float32)
    plumage = duckling * (1.0 - m_beak - m_adult)[..., None] + beak * m_beak[..., None] + adult * m_adult[..., None]
    flora_rgb[y0:y1, x0:x1] = plumage
    flora_h[y0:y1, x0:x1] = 0.45 + 0.35 * dn
    flora_r[y0:y1, x0:x1] = 0.56 + 0.16 * (1.0 - m_beak)
    bleed_gutter(flora_rgb, x0, y0, x1, y1, 14)

    _save_set("Tex_PondFlora", np.clip(flora_rgb, 0, 255).astype(np.uint8), flora_h, flora_r, normal_strength=3.5, wrap_normal=False)
    return registry


# ---------------------------------------------------------------------------
# Blender Materials & Cycles GPU Setup
# ---------------------------------------------------------------------------

def make_pbr_material(name: str, tex_entry: dict[str, Path], has_alpha: bool = False) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    uv_node = nt.nodes.new("ShaderNodeTexCoord")

    t_col = nt.nodes.new("ShaderNodeTexImage")
    t_col.image = bpy.data.images.load(str(tex_entry["Color"]), check_existing=True)
    t_col.image.colorspace_settings.name = "sRGB"

    t_nrm = nt.nodes.new("ShaderNodeTexImage")
    t_nrm.image = bpy.data.images.load(str(tex_entry["Normal"]), check_existing=True)
    t_nrm.image.colorspace_settings.name = "Non-Color"

    t_rgh = nt.nodes.new("ShaderNodeTexImage")
    t_rgh.image = bpy.data.images.load(str(tex_entry["Roughness"]), check_existing=True)
    t_rgh.image.colorspace_settings.name = "Non-Color"

    nrm_map = nt.nodes.new("ShaderNodeNormalMap")
    nrm_map.inputs["Strength"].default_value = 0.85

    nt.links.new(uv_node.outputs["UV"], t_col.inputs["Vector"])
    nt.links.new(uv_node.outputs["UV"], t_nrm.inputs["Vector"])
    nt.links.new(uv_node.outputs["UV"], t_rgh.inputs["Vector"])
    nt.links.new(t_col.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(t_rgh.outputs["Color"], bsdf.inputs["Roughness"])
    nt.links.new(t_nrm.outputs["Color"], nrm_map.inputs["Color"])
    nt.links.new(nrm_map.outputs["Normal"], bsdf.inputs["Normal"])

    if has_alpha:
        nt.links.new(t_col.outputs["Alpha"], bsdf.inputs["Alpha"])
        if hasattr(mat, "blend_method"):
            mat.blend_method = "BLEND"

    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def configure_cycles_gpu(samples: int = 36, res_x: int = 1280, res_y: int = 720) -> None:
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y

    prefs = bpy.context.preferences.addons.get("cycles")
    enabled_gpu = False
    if prefs is not None:
        cprefs = prefs.preferences
        for dev_type in ("OPTIX", "CUDA", "HIP"):
            try:
                cprefs.compute_device_type = dev_type
                cprefs.get_devices()
                gpus = [d for d in cprefs.devices if d.type != "CPU"]
                if gpus:
                    for d in cprefs.devices:
                        d.use = (d.type != "CPU")
                    scene.cycles.device = "GPU"
                    enabled_gpu = True
                    break
            except Exception:
                continue
    if not enabled_gpu:
        scene.cycles.device = "CPU"


# ---------------------------------------------------------------------------
# BMesh Organic & Architectural Geometry Builders
# ---------------------------------------------------------------------------

def _uv_layer(bm: bmesh.types.BMesh):
    return bm.loops.layers.uv.verify()


def _create_mesh_obj(bm: bmesh.types.BMesh, name: str, mat: bpy.types.Material,
                     collection: bpy.types.Collection, smooth: bool = True,
                     recalc_normals: bool = True) -> bpy.types.Object:
    if recalc_normals:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        f.smooth = smooth
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    tri_count = sum(max(1, len(p.vertices) - 2) for p in mesh.polygons)
    if tri_count > MAX_TRIS_PER_MESHPART:
        raise RuntimeError(f"{name} has {tri_count} triangles, exceeding cap {MAX_TRIS_PER_MESHPART}")
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return obj


def add_sculpted_boulder(
    bm: bmesh.types.BMesh,
    center: Vector,
    rx: float,
    ry: float,
    rz: float,
    yaw: float,
    tilt_x: float,
    seed: int,
    water_z: float,
    subdiv: int = 2,
    flatten_top: bool = False,
) -> None:
    """Append an angular-organic stratified granite boulder with continuous Rock UVs."""
    rng = random.Random(seed)
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)

    p1 = Vector((rng.uniform(-3, 3), rng.uniform(-3, 3), rng.uniform(-3, 3)))
    p2 = Vector((rng.uniform(-3, 3), rng.uniform(-3, 3), rng.uniform(-3, 3)))
    # Random cleavage plane directions
    planes = [Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.1, 0.9))).normalized() for _ in range(3)]
    plane_cut = [rng.uniform(0.62, 0.85) for _ in range(3)]

    rot = Euler((tilt_x, rng.uniform(-0.14, 0.14), yaw), "XYZ").to_matrix()

    for v in tmp.verts:
        d = v.co.copy()
        # Multi-frequency organic lumps
        n1 = math.sin(d.x * 2.7 + p1.x) * math.cos(d.y * 2.4 + p1.y) * math.sin(d.z * 2.1 + p1.z)
        n2 = math.sin(d.x * 5.2 - p2.x) * math.cos(d.y * 5.5 + p2.y)
        r_mult = 1.0 + 0.16 * n1 + 0.06 * n2
        # Cleavage plane flattening for natural rock facets
        for pn, cut in zip(planes, plane_cut):
            proj = d.dot(pn)
            if proj > cut:
                r_mult *= (cut + 0.38 * (proj - cut)) / max(1e-4, proj)
        p = Vector((d.x * rx * r_mult, d.y * ry * r_mult, d.z * rz * r_mult))
        # Wide grounded bottom + optional walkable stepping-stone top bevel
        if p.z < -0.25 * rz:
            p.x *= 1.12
            p.y *= 1.12
        if flatten_top and p.z > 0.35 * rz:
            p.z = 0.35 * rz + 0.18 * (p.z - 0.35 * rz)
        v.co = center + rot @ p

    tmp.normal_update()
    uv_lay = _uv_layer(bm)
    vmap = {}
    for v in tmp.verts:
        nv = bm.verts.new(v.co)
        vmap[v.index] = nv
    # Compute face-local clean UVs: U from horizontal/tangent world coord (zero vertical stretching!),
    # V smoothly mapped by face normal + waterline height (kept inside granite zone on stepping stones!)
    for f in tmp.faces:
        nf = bm.faces.new([vmap[v.index] for v in f.verts])
        nrm = f.normal
        ax, ay, az = abs(nrm.x), abs(nrm.y), abs(nrm.z)
        for loop in nf.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u = (co.x * 0.14 + co.y * 0.09) + seed * 0.17
                local_drift = (co.x * 0.05 - co.y * 0.05)
            elif ax >= ay:
                u = (co.y * 0.14) + seed * 0.17
                local_drift = (co.z * 0.06)
            else:
                u = (co.x * 0.14) + seed * 0.17
                local_drift = (co.z * 0.06)

            if flatten_top:
                # Stepping stone & low front viewing rocks: clean dry/damp natural granite (no bullseye moss rings)
                v_base = 0.28 + 0.18 * max(0.0, nrm.z)
            else:
                # Natural cliff/shore boulders: wet waterline near water_z -> granite face -> gentle moss cap on flat tops
                wet_or_cliff = min(0.55, max(0.06, 0.24 + (co.z - water_z) * 0.12))
                moss_bias = max(0.0, (nrm.z - 0.35) / 0.65)
                v_base = wet_or_cliff + 0.50 * (moss_bias ** 1.15)
            v_val = min(0.95, max(0.04, v_base + (local_drift % 0.08) - 0.04))
            loop[uv_lay].uv = (u, v_val)
    tmp.free()


def build_basin_and_water(
    bm_bed: bmesh.types.BMesh,
    bm_water: bmesh.types.BMesh,
    radius_fn,
    water_z: float,
    bed_z: float,
    center: Vector = Vector((0, 0, 0)),
    ang_steps: int = 52,
    water_scale: float = 1.03,
    bed_outer_scale: float = 1.15,
    berm_top_z: float | None = None,
    min_outer_z: float = -0.35,
    tile_uv: float = 0.10,
) -> None:
    """Create hole-free pond bed skirt (with outer earth berm down to grass) and water surface."""
    if berm_top_z is None:
        berm_top_z = water_z + 0.26

    # --- Bed mesh: stays submerged under water inside r<=1.01, seals cleanly under perimeter boulders ---
    uv_b = _uv_layer(bm_bed)
    ring_specs = [
        (0.08, bed_z),
        (0.45, bed_z + 0.03),
        (0.84, bed_z + 0.09),
        (1.00, water_z - 0.12),
        (1.045, berm_top_z - 0.16),
        (bed_outer_scale, min_outer_z),
    ]
    rings = []
    for r_fac, z_val in ring_specs:
        ring = []
        for i in range(ang_steps):
            th = (2.0 * math.pi * i) / ang_steps
            rad = radius_fn(th) * r_fac
            # Subtle organic basin depth undulation
            z_mod = z_val
            if r_fac < 0.85:
                z_mod += 0.03 * math.sin(th * 3.0 + r_fac * 5.0)
            p = center + Vector((rad * math.cos(th), rad * math.sin(th), z_mod))
            ring.append(bm_bed.verts.new(p))
        rings.append(ring)

    # Center cap vert
    c_vert = bm_bed.verts.new(center + Vector((0.0, 0.0, bed_z)))
    for i in range(ang_steps):
        j = (i + 1) % ang_steps
        f = bm_bed.faces.new([c_vert, rings[0][i], rings[0][j]])
        for l in f.loops:
            l[uv_b].uv = (l.vert.co.x * tile_uv, l.vert.co.y * tile_uv)
    for r_i in range(len(rings) - 1):
        r0, r1 = rings[r_i], rings[r_i + 1]
        for i in range(ang_steps):
            j = (i + 1) % ang_steps
            f = bm_bed.faces.new([r0[i], r1[i], r1[j], r0[j]])
            for l in f.loops:
                l[uv_b].uv = (l.vert.co.x * tile_uv, l.vert.co.y * tile_uv)

    # --- Water mesh: smooth gently rippled surface tucked into rim ---
    uv_w = _uv_layer(bm_water)
    w_radii = [0.10, 0.36, 0.68, 0.90, water_scale]
    w_rings = []
    for r_fac in w_radii:
        ring = []
        for i in range(ang_steps):
            th = (2.0 * math.pi * i) / ang_steps
            rad = radius_fn(th) * r_fac
            x = center.x + rad * math.cos(th)
            y = center.y + rad * math.sin(th)
            ripple = 0.015 * math.sin(x * 0.45 + y * 0.35) * math.cos(x * 0.25 - y * 0.5)
            ring.append(bm_water.verts.new(Vector((x, y, water_z + ripple))))
        w_rings.append(ring)

    wc_vert = bm_water.verts.new(center + Vector((0.0, 0.0, water_z)))
    for i in range(ang_steps):
        j = (i + 1) % ang_steps
        f = bm_water.faces.new([wc_vert, w_rings[0][i], w_rings[0][j]])
        for l in f.loops:
            l[uv_w].uv = (l.vert.co.x * 0.085, l.vert.co.y * 0.085)
    for r_i in range(len(w_rings) - 1):
        r0, r1 = w_rings[r_i], w_rings[r_i + 1]
        for i in range(ang_steps):
            j = (i + 1) % ang_steps
            f = bm_water.faces.new([r0[i], r1[i], r1[j], r0[j]])
            for l in f.loops:
                l[uv_w].uv = (l.vert.co.x * 0.085, l.vert.co.y * 0.085)


def add_waterfall_chute(
    bm: bmesh.types.BMesh,
    top_pos: Vector,
    dir_xy: Vector,
    width_top: float,
    width_bot: float,
    drop_dist: float,
    bot_z: float,
    segments_u: int = 7,
    segments_v: int = 12,
    add_splash_ring: bool = True,
) -> None:
    """Append a ballistic arched waterfall chute + frothy plunge apron into Pond_Waterfall."""
    uv_lay = _uv_layer(bm)
    fwd = Vector((dir_xy.x, dir_xy.y, 0.0)).normalized()
    right = Vector((fwd.y, -fwd.x, 0.0))

    grid = []
    for iv in range(segments_v + 1):
        t = iv / segments_v  # 0 = top crest, 1 = pond surface splash
        # Horizontal ease + gravity drop
        s_dist = drop_dist * (0.25 * t + 0.75 * (t ** 0.78))
        # Smooth crest lip curvature into fast fall
        z = top_pos.z - (top_pos.z - (bot_z + 0.04)) * (t ** 1.55)
        half_w = 0.5 * (width_top * (1.0 - t) + width_bot * t)
        row = []
        for iu in range(segments_u + 1):
            u = iu / segments_u
            lat = (u - 0.5) * 2.0 * half_w
            # Vertical riffle flutes along chute
            riffle = 0.14 * math.sin(u * math.pi * 4.0) * math.sin(t * math.pi)
            p = top_pos + fwd * (s_dist + riffle) + right * lat
            p.z = z
            row.append((bm.verts.new(p), u, 1.0 - t))
        grid.append(row)

    for iv in range(segments_v):
        for iu in range(segments_u):
            v00, u00, w00 = grid[iv][iu]
            v10, u10, w10 = grid[iv][iu + 1]
            v11, u11, w11 = grid[iv + 1][iu + 1]
            v01, u01, w01 = grid[iv + 1][iu]
            f = bm.faces.new([v00, v01, v11, v10])
            uvs = [(u00, w00), (u01, w01), (u11, w11), (u10, w10)]
            for loop, uv in zip(f.loops, uvs):
                loop[uv_lay].uv = uv

    if add_splash_ring:
        impact = top_pos + fwd * (drop_dist + 0.15)
        impact.z = bot_z + 0.04
        rx = width_bot * 0.82
        ry = width_bot * 0.56
        ang_n = 22
        center_v = bm.verts.new(impact + Vector((0.0, 0.0, 0.16)))
        mid = []
        outer = []
        for i in range(ang_n):
            th = (2.0 * math.pi * i) / ang_n
            wave = 1.0 + 0.12 * math.sin(th * 5.0)
            p_m = impact + right * (rx * 0.45 * math.cos(th)) + fwd * (ry * 0.45 * math.sin(th))
            p_o = impact + right * (rx * wave * math.cos(th)) + fwd * (ry * wave * math.sin(th))
            p_m.z = bot_z + 0.09
            p_o.z = bot_z + 0.025
            mid.append(bm.verts.new(p_m))
            outer.append(bm.verts.new(p_o))
        for i in range(ang_n):
            j = (i + 1) % ang_n
            # Inner frothy swirl cap (V in [0.10..0.18] bright white foam crest)
            f_in = bm.faces.new([center_v, mid[i], mid[j]])
            for loop, uv in zip(f_in.loops, [(i / ang_n, 0.16), (i / ang_n, 0.11), ((i + 1) / ang_n, 0.11)]):
                loop[uv_lay].uv = uv
            # Outer soft dissolve ring (V -> 0.01 fades alpha softly into Pond_Water!)
            f_out = bm.faces.new([mid[i], outer[i], outer[j], mid[j]])
            uvs = [(i / ang_n, 0.11), (i / ang_n, 0.01), ((i + 1) / ang_n, 0.01), ((i + 1) / ang_n, 0.11)]
            for loop, uv in zip(f_out.loops, uvs):
                loop[uv_lay].uv = uv


# ---------------------------------------------------------------------------
# Flora, Wildlife & Prop Appenders (Clean UV Atlas into Tex_PondFlora)
# ---------------------------------------------------------------------------

def _atlas_uv(tile_col: int, tile_row_from_bottom: int, u: float, v: float) -> tuple[float, float]:
    """Map [0..1]^2 local coords cleanly into 4x2 tile grid with 16px safe gutter inside 1024x1024."""
    px0 = tile_col * 256 + 18
    px1 = (tile_col + 1) * 256 - 18
    py_bot = tile_row_from_bottom * 512 + 18
    py_top = (tile_row_from_bottom + 1) * 512 - 18
    au = (px0 + min(1.0, max(0.0, u)) * (px1 - px0)) / 1024.0
    av = (py_bot + min(1.0, max(0.0, v)) * (py_top - py_bot)) / 1024.0
    return (au, av)


def add_lily_pad(
    bm: bmesh.types.BMesh,
    center: Vector,
    radius: float,
    yaw: float,
    seed: int,
) -> None:
    """Append notched cupped lily pad at center (uv -> tile (0, top))."""
    uv_lay = _uv_layer(bm)
    rng = random.Random(seed)
    segs = 14
    notch_half = 0.22
    cv = bm.verts.new(center + Vector((0.0, 0.0, 0.0)))
    ring = []
    for i in range(segs + 1):
        # Leave wedge notch between +notch_half and 2*pi - notch_half
        frac = i / segs
        ang = yaw + notch_half + frac * (2.0 * math.pi - 2.0 * notch_half)
        scallop = 1.0 + 0.045 * math.sin(frac * math.pi * 6.0 + seed)
        r = radius * scallop
        curl = 0.045 * radius + rng.uniform(-0.01, 0.015)
        ring.append((bm.verts.new(center + Vector((r * math.cos(ang), r * math.sin(ang), curl))), ang - yaw))
    for i in range(segs):
        v1, a1 = ring[i]
        v2, a2 = ring[i + 1]
        f = bm.faces.new([cv, v1, v2])
        f.loops[0][uv_lay].uv = _atlas_uv(0, 1, 0.5, 0.5)
        f.loops[1][uv_lay].uv = _atlas_uv(0, 1, 0.5 + 0.45 * math.cos(a1), 0.5 + 0.45 * math.sin(a1))
        f.loops[2][uv_lay].uv = _atlas_uv(0, 1, 0.5 + 0.45 * math.cos(a2), 0.5 + 0.45 * math.sin(a2))


def add_lotus_flower(
    bm: bmesh.types.BMesh,
    center: Vector,
    scale: float,
    yaw: float,
) -> None:
    """Append layered blooming pink-cream lotus with golden pollen center (uv -> tile (1, top))."""
    uv_lay = _uv_layer(bm)
    # Golden center dome
    dome_segs = 6
    c_top = bm.verts.new(center + Vector((0, 0, 0.24 * scale)))
    d_ring = []
    for i in range(dome_segs):
        a = yaw + 2.0 * math.pi * i / dome_segs
        d_ring.append(bm.verts.new(center + Vector((0.18 * scale * math.cos(a), 0.18 * scale * math.sin(a), 0.10 * scale))))
    for i in range(dome_segs):
        j = (i + 1) % dome_segs
        f = bm.faces.new([c_top, d_ring[i], d_ring[j]])
        uvs = [_atlas_uv(1, 1, 0.5, 0.12), _atlas_uv(1, 1, 0.2, 0.04), _atlas_uv(1, 1, 0.8, 0.04)]
        for l, uv in zip(f.loops, uvs):
            l[uv_lay].uv = uv

    # 2 layers of 6 curved diamond/teardrop petals
    layers = [
        (6, 0.0, 0.58 * scale, 0.34 * scale, 0.18 * scale),
        (6, math.pi / 6.0, 0.84 * scale, 0.18 * scale, 0.24 * scale),
    ]
    for n_pet, offset_a, p_len, p_lift, p_wid in layers:
        for k in range(n_pet):
            a = yaw + offset_a + 2.0 * math.pi * k / n_pet
            fwd = Vector((math.cos(a), math.sin(a), 0.0))
            side = Vector((-math.sin(a), math.cos(a), 0.0))
            b_v = bm.verts.new(center + fwd * (0.10 * scale) + Vector((0, 0, 0.03 * scale)))
            l_v = bm.verts.new(center + fwd * (0.50 * p_len) - side * p_wid + Vector((0, 0, 0.55 * p_lift)))
            r_v = bm.verts.new(center + fwd * (0.50 * p_len) + side * p_wid + Vector((0, 0, 0.55 * p_lift)))
            t_v = bm.verts.new(center + fwd * p_len + Vector((0, 0, p_lift)))
            for tri, uvs in (
                ([b_v, l_v, t_v], [_atlas_uv(1, 1, 0.5, 0.26), _atlas_uv(1, 1, 0.15, 0.62), _atlas_uv(1, 1, 0.5, 0.96)]),
                ([b_v, t_v, r_v], [_atlas_uv(1, 1, 0.5, 0.26), _atlas_uv(1, 1, 0.5, 0.96), _atlas_uv(1, 1, 0.85, 0.62)]),
            ):
                f = bm.faces.new(tri)
                for l, uv in zip(f.loops, uvs):
                    l[uv_lay].uv = uv


def add_cattail_reed_clump(
    bm: bmesh.types.BMesh,
    base: Vector,
    scale: float,
    seed: int,
    num_blades: int = 7,
    num_cattails: int = 2,
) -> None:
    """Append curving sedge grass blades + velvety brown cattail stalks (uv -> tile (2, top))."""
    uv_lay = _uv_layer(bm)
    rng = random.Random(seed)
    # Grass blades (left half of tile 2: u in [0.04..0.44])
    for _ in range(num_blades):
        a = rng.uniform(0, 2.0 * math.pi)
        h = rng.uniform(1.6, 2.9) * scale
        lean = rng.uniform(0.35, 0.95) * scale
        w0 = 0.08 * scale
        b_dir = Vector((math.cos(a), math.sin(a), 0.0))
        side = Vector((-math.sin(a), math.cos(a), 0.0))
        root_off = Vector((rng.uniform(-0.3, 0.3) * scale, rng.uniform(-0.3, 0.3) * scale, -0.05))
        p0 = base + root_off
        p1 = p0 + b_dir * (lean * 0.35) + Vector((0, 0, h * 0.55))
        p2 = p0 + b_dir * lean + Vector((0, 0, h))
        v0l = bm.verts.new(p0 - side * w0)
        v0r = bm.verts.new(p0 + side * w0)
        v1l = bm.verts.new(p1 - side * (w0 * 0.65))
        v1r = bm.verts.new(p1 + side * (w0 * 0.65))
        v2t = bm.verts.new(p2)
        f1 = bm.faces.new([v0l, v0r, v1r, v1l])
        for l, uv in zip(f1.loops, [_atlas_uv(2, 1, 0.06, 0.05), _atlas_uv(2, 1, 0.42, 0.05), _atlas_uv(2, 1, 0.42, 0.55), _atlas_uv(2, 1, 0.06, 0.55)]):
            l[uv_lay].uv = uv
        f2 = bm.faces.new([v1l, v1r, v2t])
        for l, uv in zip(f2.loops, [_atlas_uv(2, 1, 0.08, 0.55), _atlas_uv(2, 1, 0.40, 0.55), _atlas_uv(2, 1, 0.24, 0.96)]):
            l[uv_lay].uv = uv

    # Cattails (right half of tile 2: stalk v<0.40, fuzzy brown head v>0.48)
    for _ in range(num_cattails):
        a = rng.uniform(0, 2.0 * math.pi)
        lean_v = Vector((math.cos(a), math.sin(a), 0.0)) * rng.uniform(0.18, 0.45) * scale
        h = rng.uniform(2.4, 3.4) * scale
        pos = base + Vector((rng.uniform(-0.22, 0.22) * scale, rng.uniform(-0.22, 0.22) * scale, -0.05))
        # Slim 4-sided stem
        stem_r = 0.032 * scale
        hb = h * 0.65
        h_top = h * 0.92
        b_ring = []
        m_ring = []
        t_ring = []
        for s in range(4):
            sa = 2.0 * math.pi * s / 4.0
            ofs = Vector((math.cos(sa), math.sin(sa), 0.0))
            b_ring.append(bm.verts.new(pos + ofs * stem_r))
            m_ring.append(bm.verts.new(pos + lean_v * 0.65 + ofs * stem_r + Vector((0, 0, hb))))
            t_ring.append(bm.verts.new(pos + lean_v + ofs * (stem_r * 0.6) + Vector((0, 0, h))))
        for s in range(4):
            ns = (s + 1) % 4
            f = bm.faces.new([b_ring[s], b_ring[ns], m_ring[ns], m_ring[s]])
            for l, uv in zip(f.loops, [_atlas_uv(2, 1, 0.58, 0.05), _atlas_uv(2, 1, 0.90, 0.05), _atlas_uv(2, 1, 0.90, 0.36), _atlas_uv(2, 1, 0.58, 0.36)]):
                l[uv_lay].uv = uv
        # Velvety 6-sided brown head cylinder
        head_r = 0.115 * scale
        hd_b = []
        hd_t = []
        c_mid = pos + lean_v * 0.65 + Vector((0, 0, hb))
        c_top = pos + lean_v * 0.92 + Vector((0, 0, h_top))
        for s in range(6):
            sa = 2.0 * math.pi * s / 6.0
            ofs = Vector((math.cos(sa), math.sin(sa), 0.0)) * head_r
            hd_b.append(bm.verts.new(c_mid + ofs))
            hd_t.append(bm.verts.new(c_top + ofs))
        cap_b = bm.verts.new(c_mid + Vector((0, 0, -0.04 * scale)))
        cap_t = bm.verts.new(c_top + Vector((0, 0, 0.05 * scale)))
        for s in range(6):
            ns = (s + 1) % 6
            f = bm.faces.new([hd_b[s], hd_b[ns], hd_t[ns], hd_t[s]])
            for l, uv in zip(f.loops, [_atlas_uv(2, 1, 0.58, 0.50), _atlas_uv(2, 1, 0.92, 0.50), _atlas_uv(2, 1, 0.92, 0.94), _atlas_uv(2, 1, 0.58, 0.94)]):
                l[uv_lay].uv = uv
            f_cb = bm.faces.new([cap_b, hd_b[ns], hd_b[s]])
            for l in f_cb.loops:
                l[uv_lay].uv = _atlas_uv(2, 1, 0.75, 0.72)
            f_ct = bm.faces.new([cap_t, hd_t[s], hd_t[ns]])
            for l in f_ct.loops:
                l[uv_lay].uv = _atlas_uv(2, 1, 0.75, 0.72)


def add_mossy_driftwood_log(
    bm: bmesh.types.BMesh,
    center: Vector,
    length: float,
    radius: float,
    yaw: float,
    pitch: float,
) -> None:
    """Append gnarled mossy fallen driftwood log (uv -> tile (3, top))."""
    uv_lay = _uv_layer(bm)
    rot = Euler((pitch, 0.0, yaw), "XYZ").to_matrix()
    stations = 6
    sides = 8
    rings = []
    for ista in range(stations + 1):
        t = ista / stations
        y_loc = (t - 0.5) * length
        bend_x = 0.25 * math.sin(t * math.pi * 1.4)
        taper = radius * (1.0 - 0.22 * t + 0.08 * math.sin(t * 7.0))
        ring = []
        for s in range(sides):
            sa = 2.0 * math.pi * s / sides
            p_loc = Vector((bend_x + taper * math.cos(sa), y_loc, taper * 0.88 * math.sin(sa)))
            ring.append(bm.verts.new(center + rot @ p_loc))
        rings.append(ring)

    for ista in range(stations):
        for s in range(sides):
            ns = (s + 1) % sides
            f = bm.faces.new([rings[ista][s], rings[ista][ns], rings[ista + 1][ns], rings[ista + 1][s]])
            uvs = [
                _atlas_uv(3, 1, s / sides, ista / stations),
                _atlas_uv(3, 1, (s + 1) / sides, ista / stations),
                _atlas_uv(3, 1, (s + 1) / sides, (ista + 1) / stations),
                _atlas_uv(3, 1, s / sides, (ista + 1) / stations),
            ]
            for l, uv in zip(f.loops, uvs):
                l[uv_lay].uv = uv
    # End caps
    for r_end, rev in [(rings[0], True), (rings[-1], False)]:
        pts = list(reversed(r_end)) if rev else r_end
        f = bm.faces.new(pts)
        for i, l in enumerate(f.loops):
            a = 2.0 * math.pi * i / len(pts)
            l[uv_lay].uv = _atlas_uv(3, 1, 0.5 + 0.35 * math.cos(a), 0.5 + 0.35 * math.sin(a))


def add_koi_fish(
    bm: bmesh.types.BMesh,
    center: Vector,
    length: float,
    yaw: float,
    gold_variant: bool = False,
    curve_dir: float = 1.0,
) -> None:
    """Append sleek curved swimming Koi carp below water level (uv -> bottom-left Koi atlas)."""
    uv_lay = _uv_layer(bm)
    rot = Euler((0.0, 0.0, yaw), "XYZ").to_matrix()
    u0, u1 = (0.28, 0.48) if gold_variant else (0.02, 0.22)
    # Note: Koi swatch lies inside bottom-left quad [u: 0.0156..0.484, v: 0.0156..0.484]
    def _koi_uv(su: float, sv: float) -> tuple[float, float]:
        gu = u0 + su * (u1 - u0)
        gv = 0.03 + sv * 0.43
        return (gu, gv)

    # Profile along spine t in [0..1]: (y, half_width, half_height)
    prof = [
        (0.50, 0.03, 0.02),   # Nose tip
        (0.32, 0.14, 0.11),   # Head
        (0.10, 0.18, 0.14),   # Shoulder
        (-0.15, 0.13, 0.11),  # Waist
        (-0.36, 0.06, 0.06),  # Peduncle
        (-0.52, 0.01, 0.14),  # Caudal tail base
    ]
    rings = []
    sides = 6
    for idx, (yl, hw, hh) in enumerate(prof):
        sway = curve_dir * 0.10 * length * math.sin(idx * 0.85)
        ring = []
        for s in range(sides):
            sa = 2.0 * math.pi * s / sides
            p = Vector((sway + hw * length * math.cos(sa), yl * length, hh * length * math.sin(sa)))
            ring.append(bm.verts.new(center + rot @ p))
        rings.append(ring)

    nose = bm.verts.new(center + rot @ Vector((0.0, 0.56 * length, 0.0)))
    for s in range(sides):
        ns = (s + 1) % sides
        f = bm.faces.new([nose, rings[0][s], rings[0][ns]])
        for l in f.loops:
            l[uv_lay].uv = _koi_uv(0.5, 0.92)
    for i in range(len(rings) - 1):
        for s in range(sides):
            ns = (s + 1) % sides
            f = bm.faces.new([rings[i][s], rings[i][ns], rings[i + 1][ns], rings[i + 1][s]])
            sv0 = 0.85 - 0.14 * i
            sv1 = 0.85 - 0.14 * (i + 1)
            for l, uv in zip(f.loops, [_koi_uv(s / sides, sv0), _koi_uv((s + 1) / sides, sv0), _koi_uv((s + 1) / sides, sv1), _koi_uv(s / sides, sv1)]):
                l[uv_lay].uv = uv

    # Flowing fan tail fin + side pectoral fins
    sw_t = curve_dir * 0.14 * length
    tb = bm.verts.new(center + rot @ Vector((sw_t * 0.7, -0.48 * length, 0.0)))
    tt = bm.verts.new(center + rot @ Vector((sw_t + 0.05 * length, -0.74 * length, 0.06 * length)))
    tl = bm.verts.new(center + rot @ Vector((sw_t - 0.12 * length, -0.70 * length, -0.04 * length)))
    tr = bm.verts.new(center + rot @ Vector((sw_t + 0.14 * length, -0.70 * length, -0.04 * length)))
    for tri in ([tb, tl, tt], [tb, tt, tr]):
        f = bm.faces.new(tri)
        for l in f.loops:
            l[uv_lay].uv = _koi_uv(0.5, 0.15)
    for side_s in (-1.0, 1.0):
        p0 = bm.verts.new(center + rot @ Vector((side_s * 0.14 * length, 0.12 * length, -0.02 * length)))
        p1 = bm.verts.new(center + rot @ Vector((side_s * 0.34 * length, -0.04 * length, -0.04 * length)))
        p2 = bm.verts.new(center + rot @ Vector((side_s * 0.18 * length, -0.10 * length, -0.02 * length)))
        f = bm.faces.new([p0, p1, p2] if side_s > 0 else [p0, p2, p1])
        for l in f.loops:
            l[uv_lay].uv = _koi_uv(0.3, 0.45)


def add_pond_duck(
    bm: bmesh.types.BMesh,
    center: Vector,
    scale: float,
    yaw: float,
    is_duckling: bool = True,
) -> None:
    """Append cute floating golden duckling or adult duck resting on water surface."""
    uv_lay = _uv_layer(bm)
    rot = Euler((0.0, 0.0, yaw), "XYZ").to_matrix()

    def _duck_uv(kind: str) -> tuple[float, float]:
        # Bottom-right quad: u=[0.52..0.98], v=[0.02..0.48]
        if kind == "beak":
            return (0.74, 0.25)
        if kind == "adult":
            return (0.90, 0.30)
        return (0.60, 0.25)  # Golden duckling down

    body_kind = "duckling" if is_duckling else "adult"
    b_uv = _duck_uv(body_kind)
    k_uv = _duck_uv("beak")

    def _add_ellipsoid(loc: Vector, rx: float, ry: float, rz: float, uv_pt: tuple[float, float], subdiv: int = 1):
        t = bmesh.new()
        bmesh.ops.create_icosphere(t, subdivisions=subdiv, radius=1.0)
        for v in t.verts:
            p = Vector((v.co.x * rx, v.co.y * ry, v.co.z * rz))
            v.co = center + rot @ (loc + p)
        vmap = {v.index: bm.verts.new(v.co) for v in t.verts}
        for f in t.faces:
            nf = bm.faces.new([vmap[v.index] for v in f.verts])
            for l in nf.loops:
                l[uv_lay].uv = uv_pt
        t.free()

    # Plump floating body (half tucked in water)
    _add_ellipsoid(Vector((0.0, 0.0, 0.14 * scale)), 0.30 * scale, 0.44 * scale, 0.24 * scale, b_uv, subdiv=2)
    # Tail tuft
    _add_ellipsoid(Vector((0.0, -0.40 * scale, 0.26 * scale)), 0.13 * scale, 0.19 * scale, 0.10 * scale, b_uv, subdiv=1)
    # Curved S-neck bridging chest seamlessly into head (zero detached floating head!)
    if not is_duckling:
        _add_ellipsoid(Vector((0.0, 0.28 * scale, 0.34 * scale)), 0.14 * scale, 0.15 * scale, 0.20 * scale, _duck_uv("adult"), subdiv=1)
    else:
        _add_ellipsoid(Vector((0.0, 0.22 * scale, 0.28 * scale)), 0.13 * scale, 0.13 * scale, 0.13 * scale, b_uv, subdiv=1)
    # Head + orange bill
    head_y = 0.30 * scale if is_duckling else 0.34 * scale
    head_z = 0.40 * scale if is_duckling else 0.54 * scale
    head_r = 0.19 * scale if is_duckling else 0.21 * scale
    _add_ellipsoid(Vector((0.0, head_y, head_z)), head_r, head_r * 1.06, head_r, b_uv if is_duckling else (0.94, 0.40), subdiv=2)
    _add_ellipsoid(Vector((0.0, head_y + head_r * 1.05, head_z - 0.04 * scale)), 0.09 * scale, 0.16 * scale, 0.048 * scale, k_uv, subdiv=1)


# ---------------------------------------------------------------------------
# POND 1: HeroBridgePond (Replaces Hub ReflectingPool, X-centered on NorthPath)
# ---------------------------------------------------------------------------

def bridge_deck_z(y: float) -> float:
    """Walkable arched cobblestone profile: 1.5-stud entry apron (41.5..43.0: 0.28->0.16) to crest z=5.60 at y=0."""
    ay = abs(y)
    if ay >= 41.5:
        apron_t = min(1.0, max(0.0, (ay - 41.5) / 1.5))
        return 0.28 - 0.12 * apron_t
    t = ay / 41.5
    u = 0.5 * (1.0 + math.cos(math.pi * t))
    return 0.28 + 5.32 * (u ** 0.82)


def bridge_arch_z(y: float) -> float:
    """Open stone arch vault underside spanning water (|y| <= 23.0), minimum 1.0 stud barrel thickness."""
    if abs(y) >= 23.0:
        return 0.20
    return 0.25 + 4.35 * ((1.0 - (y / 23.0) ** 2) ** 0.68)


def _add_prism_strip(
    bm: bmesh.types.BMesh,
    y0: float,
    y1: float,
    x_left: float,
    x_right: float,
    z0_bot: float,
    z0_top: float,
    z1_bot: float,
    z1_top: float,
    v_min: float,
    v_max: float,
    uv_scale: float = 0.14,
    cap_y0: bool = False,
    cap_y1: bool = False,
) -> None:
    """Add crisp hard-edged masonry segment with guaranteed outward CCW winding."""
    uv_lay = _uv_layer(bm)
    p00b = Vector((x_left, y0, z0_bot))
    p01b = Vector((x_right, y0, z0_bot))
    p01t = Vector((x_right, y0, z0_top))
    p00t = Vector((x_left, y0, z0_top))
    p10b = Vector((x_left, y1, z1_bot))
    p11b = Vector((x_right, y1, z1_bot))
    p11t = Vector((x_right, y1, z1_top))
    p10t = Vector((x_left, y1, z1_top))

    vmid = 0.5 * (v_min + v_max)
    quads = [
        ([p00t, p01t, p11t, p10t], [(x_left * uv_scale, v_min), (x_right * uv_scale, v_min), (x_right * uv_scale, v_max), (x_left * uv_scale, v_max)]),  # Top (+Z)
        ([p01b, p00b, p10b, p11b], [(x_right * uv_scale, v_min), (x_left * uv_scale, v_min), (x_left * uv_scale, v_max), (x_right * uv_scale, v_max)]),  # Bottom (-Z)
        ([p00b, p00t, p10t, p10b], [(y0 * uv_scale, v_min), (y0 * uv_scale, v_max), (y1 * uv_scale, v_max), (y1 * uv_scale, v_min)]),  # Left (-X)
        ([p01t, p01b, p11b, p11t], [(y0 * uv_scale, v_max), (y0 * uv_scale, v_min), (y1 * uv_scale, v_min), (y1 * uv_scale, v_max)]),  # Right (+X)
    ]
    if cap_y0:
        quads.append(([p00b, p01b, p01t, p00t], [(x_left * uv_scale, v_min), (x_right * uv_scale, v_min), (x_right * uv_scale, v_max), (x_left * uv_scale, v_max)]))  # Front (-Y)
    if cap_y1:
        quads.append(([p11b, p10b, p10t, p11t], [(x_right * uv_scale, v_min), (x_left * uv_scale, v_min), (x_left * uv_scale, v_max), (x_right * uv_scale, v_max)]))  # Back (+Y)
    for pts, uvs in quads:
        verts = [bm.verts.new(p) for p in pts]
        f = bm.faces.new(verts)
        for l, uv in zip(f.loops, uvs):
            l[uv_lay].uv = (uv[0], min(v_max, max(v_min, vmid + 0.42 * (uv[1] - vmid))))


def build_hero_bridge_pond(materials: dict[str, bpy.types.Material], col: bpy.types.Collection) -> list[bpy.types.Object]:
    water_z = 0.64
    bed_z = 0.34  # Safely above NorthPath Cobble top (Y=12.24 -> 0.24) and CommonsSurface (0.0)

    def radius_fn(th: float) -> float:
        # Wide scalloped heart-oval lagoon: broader X coves (34.5) and slightly tucked N/S near Willows (31.5)
        r = 32.8 + 1.8 * math.cos(2.0 * th) + 1.35 * math.sin(3.0 * th + 0.4) + 0.85 * math.cos(5.0 * th - 0.6)
        return r

    bm_bed = bmesh.new()
    bm_water = bmesh.new()
    build_basin_and_water(
        bm_bed, bm_water, radius_fn, water_z=water_z, bed_z=bed_z,
        ang_steps=56, water_scale=1.02, bed_outer_scale=1.10, berm_top_z=water_z + 0.20, min_outer_z=-0.22,
    )

    # Dense overlapping shoreline granite/moss boulders: hug radius_fn(th)*0.98..1.04 cleanly!
    bm_rocks = bmesh.new()
    rng = random.Random(1001)
    n_boulders = 72
    for i in range(n_boulders):
        th = (2.0 * math.pi * i) / n_boulders + rng.uniform(-0.02, 0.02)
        rad = radius_fn(th) * rng.uniform(0.97, 1.03)
        cx = rad * math.cos(th)
        cy = rad * math.sin(th)
        if abs(cx) < 8.4 and abs(cy) > 22.0:
            # Skip bridge approach lane so NorthPath cobblestone meets bridge straight on!
            continue
        rx = rng.uniform(2.2, 3.3)
        ry = rng.uniform(2.0, 3.0)
        rz = rng.uniform(1.15, 1.95)
        add_sculpted_boulder(
            bm_rocks, Vector((cx, cy, water_z - 0.14 + 0.26 * rz)),
            rx, ry, rz, yaw=th + rng.uniform(-0.6, 0.6), tilt_x=rng.uniform(-0.2, 0.2),
            seed=2000 + i, water_z=water_z, subdiv=2,
        )
    # Approach flanking shoulder boulders right beside bridge piers at |x| = 8.4..10.5
    for idx, (ax, ay) in enumerate([(-8.8, 30.5), (8.8, 30.5), (-8.8, -30.5), (8.8, -30.5), (-9.4, 34.5), (9.4, 34.5), (-9.4, -34.5), (9.4, -34.5)]):
        add_sculpted_boulder(
            bm_rocks, Vector((ax, ay, water_z + 0.2)),
            2.4, 2.2, 1.45, yaw=idx * 0.7, tilt_x=0.1,
            seed=2300 + idx, water_z=water_z, subdiv=2,
        )
    # 6 partially submerged accent rocks peeking nicely from inside the lagoon
    for idx, (ax, ay, ar) in enumerate([(-21.0, 9.5, 1.7), (-18.0, -15.5, 2.0), (20.5, 13.0, 1.8), (19.0, -12.0, 2.1), (-13.5, 20.5, 1.4), (14.5, -21.0, 1.5)]):
        add_sculpted_boulder(
            bm_rocks, Vector((ax, ay, water_z - 0.25)),
            ar * 1.25, ar * 0.95, ar * 0.72, yaw=idx * 1.1, tilt_x=0.1,
            seed=2500 + idx, water_z=water_z, subdiv=2,
        )

    # --- Bridge Deck (Pond_BridgeDeck): constant graceful arched cobblestone span + stone parapet piers ---
    bm_deck = bmesh.new()
    uv_d = _uv_layer(bm_deck)
    n_seg = 44
    ys = [-43.0] + [-41.5 + (83.0 * k) / n_seg for k in range(n_seg + 1)] + [43.0]
    deck_hw = 5.65  # Clear interior walkable width 11.3 studs; outer piers +-6.8 fit neatly inside NorthPath 16-stud road

    def _deck_hw(y: float) -> float:
        return deck_hw

    for k in range(len(ys) - 1):
        y0, y1 = ys[k], ys[k + 1]
        z0t, z1t = bridge_deck_z(y0), bridge_deck_z(y1)
        z0b = max(-0.12, bridge_arch_z(y0)) if abs(y0) < 23.0 else -0.12
        z1b = max(-0.12, bridge_arch_z(y1)) if abs(y1) < 23.0 else -0.12
        w0, w1 = _deck_hw(y0), _deck_hw(y1)

        deck_faces = [
            ([Vector((-w0, y0, z0t)), Vector((w0, y0, z0t)), Vector((w1, y1, z1t)), Vector((-w1, y1, z1t))],
             [(y0 * 0.036, 0.25 - w0 * 0.035), (y0 * 0.036, 0.25 + w0 * 0.035),
              (y1 * 0.036, 0.25 + w1 * 0.035), (y1 * 0.036, 0.25 - w1 * 0.035)]),
            ([Vector((w0, y0, z0b)), Vector((-w0, y0, z0b)), Vector((-w1, y1, z1b)), Vector((w1, y1, z1b))],
             [(y0 * 0.036, 0.44), (y0 * 0.036, 0.06), (y1 * 0.036, 0.06), (y1 * 0.036, 0.44)]),
            ([Vector((-w0, y0, z0b)), Vector((-w0, y0, z0t)), Vector((-w1, y1, z1t)), Vector((-w1, y1, z1b))],
             [(y0 * 0.036, 0.06), (y0 * 0.036, 0.28), (y1 * 0.036, 0.28), (y1 * 0.036, 0.06)]),
            ([Vector((w0, y0, z0t)), Vector((w0, y0, z0b)), Vector((w1, y1, z1b)), Vector((w1, y1, z1t))],
             [(y0 * 0.036, 0.28), (y0 * 0.036, 0.06), (y1 * 0.036, 0.06), (y1 * 0.036, 0.28)]),
        ]
        if k == 0:
            deck_faces.append((
                [Vector((-w0, y0, z0b)), Vector((w0, y0, z0b)), Vector((w0, y0, z0t)), Vector((-w0, y0, z0t))],
                [(0.06, 0.06), (0.44, 0.06), (0.44, 0.14), (0.06, 0.14)],
            ))
        if k == len(ys) - 2:
            deck_faces.append((
                [Vector((w1, y1, z1b)), Vector((-w1, y1, z1b)), Vector((-w1, y1, z1t)), Vector((w1, y1, z1t))],
                [(0.44, 0.06), (0.06, 0.06), (0.06, 0.14), (0.44, 0.14)],
            ))
        for pts, uvs in deck_faces:
            f = bm_deck.faces.new([bm_deck.verts.new(p) for p in pts])
            for l, uv in zip(f.loops, uvs):
                l[uv_d].uv = (uv[0], min(0.46, max(0.04, uv[1])))

    # --- Bridge Parapet Walls, Arch Voussoir Trim & Capped Stone Piers ---
    bm_rails = bmesh.new()
    for k in range(len(ys) - 1):
        y0, y1 = ys[k], ys[k + 1]
        if abs(y0) > 41.5001 or abs(y1) > 41.5001:
            continue
        is_start = (k == 1)
        is_end = (k == len(ys) - 3)
        z0t, z1t = bridge_deck_z(y0), bridge_deck_z(y1)
        w0 = _deck_hw(y0)
        def _rail_h(y: float) -> float:
            if abs(y) <= 38.5:
                return 1.55
            return max(0.35, 1.55 * (1.0 - (abs(y) - 38.5) / 3.0))

        rh0, rh1 = _rail_h(y0), _rail_h(y1)
        for sign in (-1.0, 1.0):
            xc = sign * (w0 + 0.42)
            _add_prism_strip(bm_rails, y0, y1, xc - 0.52, xc + 0.52, z0t - 0.05, z0t + rh0, z1t - 0.05, z1t + rh1, 0.54, 0.95, cap_y0=is_start, cap_y1=is_end)
            _add_prism_strip(bm_rails, y0, y1, xc - 0.66, xc + 0.66, z0t + rh0 - 0.02, z0t + rh0 + 0.24, z1t + rh1 - 0.02, z1t + rh1 + 0.24, 0.56, 0.94, cap_y0=is_start, cap_y1=is_end)
            if abs(y0) <= 23.0 and abs(y1) <= 23.0:
                a0 = bridge_arch_z(y0)
                a1 = bridge_arch_z(y1)
                outer_x = sign * (deck_hw + 0.15)
                _add_prism_strip(bm_rails, y0, y1, outer_x - 0.16, outer_x + 0.16, a0 - 0.05, a0 + 0.42, a1 - 0.05, a1 + 0.42, 0.54, 0.96, cap_y0=abs(y0 + 23.0) < 1.9, cap_y1=abs(y1 - 23.0) < 1.9)

    # 6 Carved Capped Stone Pillars cleanly framing South entry (-38.5), Center crown (0.0), North entry (+38.5)
    for py in (-38.5, 0.0, 38.5):
        p_hw = _deck_hw(py)
        pz = bridge_deck_z(py)
        for sign in (-1.0, 1.0):
            px = sign * (p_hw + 0.42)
            _add_prism_strip(bm_rails, py - 0.85, py + 0.85, px - 0.82, px + 0.82, pz - 0.15, pz + 2.25, pz - 0.15, pz + 2.25, 0.54, 0.96, cap_y0=True, cap_y1=True)
            _add_prism_strip(bm_rails, py - 1.00, py + 1.00, px - 0.98, px + 0.98, pz + 2.22, pz + 2.52, pz + 2.22, pz + 2.52, 0.55, 0.95, cap_y0=True, cap_y1=True)

    # --- Botanical Flora & Koi ---
    bm_flora = bmesh.new()
    lily_spots = [
        (-14.5, -9.0, 2.0, True), (-18.5, -5.5, 1.65, False), (-21.0, -11.5, 1.8, True),
        (-13.0, 7.5, 1.9, True), (-17.0, 11.5, 1.6, False), (-23.5, 3.0, 2.1, True),
        (-25.0, -3.5, 1.5, False), (-11.0, -17.5, 1.75, True), (-15.0, 17.0, 1.65, False),
        (13.5, 6.0, 1.95, True), (18.0, 9.5, 1.65, False), (22.5, 4.5, 1.85, True),
        (15.0, -8.5, 2.05, True), (19.5, -13.0, 1.55, False), (24.5, -5.0, 1.75, True),
        (12.0, 16.5, 1.8, True), (16.5, -18.5, 1.6, False), (26.0, 11.0, 1.5, False),
    ]
    for idx, (lx, ly, lr, has_lotus) in enumerate(lily_spots):
        add_lily_pad(bm_flora, Vector((lx, ly, water_z + 0.03)), lr, yaw=idx * 0.92, seed=3100 + idx)
        if has_lotus:
            add_lotus_flower(bm_flora, Vector((lx, ly, water_z + 0.05)), scale=lr * 0.58, yaw=idx * 0.7)

    for idx, (cx, cy) in enumerate([
        (-28.0, -15.0), (-30.5, 0.0), (-27.0, 16.0), (-19.5, 23.5), (-18.5, -24.0),
        (-25.5, -22.0), (-26.0, 21.5), (-32.0, -7.5), (-32.0, 7.5),
        (28.0, 15.0), (31.0, -2.0), (26.5, -17.0), (19.5, -23.5), (18.5, 24.0),
        (25.5, 22.0), (26.0, -21.5), (32.0, 7.5), (32.0, -7.5),
    ]):
        add_cattail_reed_clump(bm_flora, Vector((cx, cy, water_z - 0.04)), scale=1.30, seed=3200 + idx, num_blades=8, num_cattails=2)

    koi_spots = [
        (-16.0, -2.0, 2.2, 0.6, False), (-20.0, 5.5, 1.9, -0.4, True), (-12.5, 12.5, 2.0, 2.1, False),
        (16.5, 1.5, 2.3, -1.9, True), (20.5, -7.0, 1.95, 1.1, False), (13.0, -13.0, 1.85, 2.6, True),
    ]
    for idx, (kx, ky, kl, kyaw, is_g) in enumerate(koi_spots):
        add_koi_fish(bm_flora, Vector((kx, ky, water_z - 0.22)), kl, yaw=kyaw, gold_variant=is_g, curve_dir=1.0 if idx % 2 == 0 else -1.0)

    return [
        _create_mesh_obj(bm_rocks, "Pond_Rocks", materials["Rock"], col, smooth=True),
        _create_mesh_obj(bm_bed, "Pond_Bed", materials["Bed"], col, smooth=True),
        _create_mesh_obj(bm_water, "Pond_Water", materials["Water"], col, smooth=True),
        _create_mesh_obj(bm_deck, "Pond_BridgeDeck", materials["Masonry"], col, smooth=False, recalc_normals=False),
        _create_mesh_obj(bm_rails, "Pond_BridgeRails", materials["Masonry"], col, smooth=False, recalc_normals=False),
        _create_mesh_obj(bm_flora, "Pond_Flora", materials["Flora"], col, smooth=True),
    ]


# ---------------------------------------------------------------------------
# POND 2: WaterfallBoulderPond (NE Glade, Cliff Back at +Y, Faces -Y / South at yaw=0)
# ---------------------------------------------------------------------------

def build_waterfall_boulder_pond(materials: dict[str, bpy.types.Material], col: bpy.types.Collection) -> list[bpy.types.Object]:
    water_z = 0.44
    bed_z = 0.14

    def radius_fn(th: float) -> float:
        # Organic kidney lagoon (~32 x 28 outer boulder diameter, water radius ~11..13)
        return 11.8 + 1.5 * math.cos(2.0 * th - 0.3) + 1.25 * math.sin(th + 0.5) + 0.85 * math.cos(3.0 * th + 1.1)

    bm_bed = bmesh.new()
    bm_water = bmesh.new()
    build_basin_and_water(
        bm_bed, bm_water, radius_fn, water_z=water_z, bed_z=bed_z,
        ang_steps=48, water_scale=1.03, bed_outer_scale=1.18, berm_top_z=water_z + 0.24, min_outer_z=-0.35,
    )

    bm_rocks = bmesh.new()
    rng = random.Random(2002)
    n_boulders = 42
    for i in range(n_boulders):
        th = (2.0 * math.pi * i) / n_boulders + rng.uniform(-0.04, 0.04)
        # Keep waterfall landing notch slightly clear around th near +pi/2 (back +Y)
        rad = radius_fn(th) * rng.uniform(1.02, 1.10)
        cx, cy = rad * math.cos(th), rad * math.sin(th)
        if cy > 8.5 and abs(cx) < 3.4:
            continue
        is_back_hill = cy > 5.0
        rx = rng.uniform(1.8, 2.9)
        ry = rng.uniform(1.6, 2.5)
        rz = rng.uniform(2.0, 3.6) if is_back_hill else rng.uniform(0.95, 1.55)
        add_sculpted_boulder(
            bm_rocks, Vector((cx, cy, water_z - 0.22 + 0.36 * rz)),
            rx, ry, rz, yaw=th + rng.uniform(-0.7, 0.7), tilt_x=rng.uniform(-0.22, 0.22),
            seed=4000 + i, water_z=water_z, subdiv=2,
        )

    # Tall Dramatic Tiered Waterfall Cliff Backdrop (+Y side, crest ~7.8 studs high)
    cliff_specs = [
        # Main backing rock spire walls framing left & right of chute (|x| ~ 3.5..6.8)
        (-4.8, 12.2, 3.2, 2.8, 4.4, 3.8),
        (4.6, 11.8, 3.3, 2.9, 4.6, 4.1),
        (-2.6, 14.4, 3.0, 2.4, 4.8, 4.3),
        (2.6, 14.2, 3.0, 2.4, 4.7, 4.2),
        (0.0, 15.2, 3.4, 2.5, 4.2, 3.6),  # Upper spring basin back rock wall
        # Flanking buttresses stepping down nicely toward pond sides
        (-7.4, 9.6, 2.6, 2.4, 2.8, 2.2),
        (7.2, 9.4, 2.7, 2.3, 3.0, 2.4),
        # Supporting rocky sill tucked behind the waterfall chute (y=13.0, safely behind plunge sheet!)
        (0.0, 13.0, 2.6, 1.5, 2.2, 2.5),
    ]
    for idx, (cx, cy, rx, ry, rz, cz) in enumerate(cliff_specs):
        add_sculpted_boulder(
            bm_rocks, Vector((cx, cy, cz)), rx, ry, rz,
            yaw=idx * 0.6, tilt_x=0.12, seed=4500 + idx, water_z=water_z, subdiv=2,
        )

    # Upper small spring pool sheet + Frothy Cascade Waterfall Chute + Splash Ring
    bm_wf = bmesh.new()
    add_waterfall_chute(
        bm_wf,
        top_pos=Vector((0.0, 12.6, 5.45)),
        dir_xy=Vector((0.0, -1.0)),
        width_top=3.9,
        width_bot=5.0,
        drop_dist=4.2,
        bot_z=water_z,
        segments_u=8,
        segments_v=14,
        add_splash_ring=True,
    )
    # Upper catch-pool horizontal surface sitting atop the ledge behind top_pos
    uv_wf = _uv_layer(bm_wf)
    p_uc = [
        bm_wf.verts.new(Vector((-2.2, 14.2, 5.45))),
        bm_wf.verts.new(Vector((2.2, 14.2, 5.45))),
        bm_wf.verts.new(Vector((2.0, 12.5, 5.45))),
        bm_wf.verts.new(Vector((-2.0, 12.5, 5.45))),
    ]
    f_uc = bm_wf.faces.new(p_uc)
    for l, uv in zip(f_uc.loops, [(0.0, 0.98), (1.0, 0.98), (1.0, 0.72), (0.0, 0.72)]):
        l[uv_wf].uv = uv

    # Signature Flora & Wildlife from user's Bloxburg Waterfall Reference!
    bm_flora = bmesh.new()
    # Mossy driftwood log jutting into west side of lagoon + small floating timber stick
    add_mossy_driftwood_log(bm_flora, Vector((-6.0, -1.2, water_z + 0.12)), length=6.8, radius=0.62, yaw=0.72, pitch=0.06)
    add_mossy_driftwood_log(bm_flora, Vector((2.5, -2.8, water_z + 0.04)), length=2.8, radius=0.28, yaw=1.45, pitch=0.0)

    # Mother Duck + 3 Golden Ducklings cruising cleanly in open water near mossy log (media_1794626483214_39044c21.jpg!)
    add_pond_duck(bm_flora, Vector((-2.4, -4.4, water_z - 0.02)), scale=1.45, yaw=0.75, is_duckling=False)
    for idx, (dx, dy, dyaw) in enumerate([(-4.3, -3.7, 0.70), (-5.6, -3.1, 0.65), (-6.8, -2.5, 0.72)]):
        add_pond_duck(bm_flora, Vector((dx, dy, water_z - 0.02)), scale=0.88, yaw=dyaw, is_duckling=True)

    # Lily pads & pink blooming lotuses
    for idx, (lx, ly, lr, has_lot) in enumerate([
        (-8.2, -5.2, 1.5, True), (-6.8, -7.2, 1.25, False), (-3.8, -7.8, 1.6, True),
        (5.2, -5.5, 1.75, True), (7.6, -3.5, 1.4, False), (6.5, -8.0, 1.55, True),
        (2.8, 3.8, 1.35, True), (-4.2, 4.2, 1.45, False), (0.8, -5.2, 1.2, False),
        (7.5, 2.5, 1.4, False), (-8.5, 2.0, 1.35, True),
    ]):
        add_lily_pad(bm_flora, Vector((lx, ly, water_z + 0.03)), lr, yaw=idx * 1.15, seed=4800 + idx)
        if has_lot:
            add_lotus_flower(bm_flora, Vector((lx, ly, water_z + 0.05)), scale=lr * 0.56, yaw=idx * 0.8)

    # Rich Cattails & Sedge Reeds around boulders and waterfall sides
    for idx, (cx, cy, sc) in enumerate([
        (-9.6, 4.8, 1.15), (-10.8, -3.5, 1.1), (-7.2, -9.8, 1.25), (1.8, -10.4, 1.05),
        (9.5, -5.8, 1.3), (10.5, 2.4, 1.2), (6.8, 8.2, 1.25), (-6.6, 8.4, 1.15),
        (3.8, 13.0, 0.95), (-4.0, 12.8, 0.95),
    ]):
        add_cattail_reed_clump(bm_flora, Vector((cx, cy, water_z - 0.04)), scale=sc, seed=4900 + idx, num_blades=7, num_cattails=2)

    return [
        _create_mesh_obj(bm_rocks, "Pond_Rocks", materials["Rock"], col, smooth=True),
        _create_mesh_obj(bm_bed, "Pond_Bed", materials["Bed"], col, smooth=True),
        _create_mesh_obj(bm_water, "Pond_Water", materials["Water"], col, smooth=True),
        _create_mesh_obj(bm_wf, "Pond_Waterfall", materials["Waterfall"], col, smooth=True),
        _create_mesh_obj(bm_flora, "Pond_Flora", materials["Flora"], col, smooth=True),
    ]


# ---------------------------------------------------------------------------
# POND 3: RockeryKoiPond (SW Gazebo Glade, Zen Crescent Rockery + Swimming Koi)
# ---------------------------------------------------------------------------

def build_rockery_koi_pond(materials: dict[str, bpy.types.Material], col: bpy.types.Collection) -> list[bpy.types.Object]:
    water_z = 0.44
    bed_z = 0.14

    def radius_fn(th: float) -> float:
        # Serene asymmetrical oval-crescent koi basin (~30 x 25 outer diameter)
        return 11.2 + 1.8 * math.cos(2.0 * th) - 0.95 * math.sin(th) + 0.75 * math.cos(3.0 * th + 0.5)

    bm_bed = bmesh.new()
    bm_water = bmesh.new()
    build_basin_and_water(
        bm_bed, bm_water, radius_fn, water_z=water_z, bed_z=bed_z,
        ang_steps=48, water_scale=1.03, bed_outer_scale=1.16, berm_top_z=water_z + 0.22, min_outer_z=-0.35,
    )

    bm_rocks = bmesh.new()
    rng = random.Random(3003)
    # Front half (-Y): low flat-topped carved natural slate viewing stones (easy walk-up Koi viewing!)
    # Back half (+Y): layered Zen rockery embankment rising ~3.8 studs with gentle rock spout
    n_boulders = 44
    for i in range(n_boulders):
        th = (2.0 * math.pi * i) / n_boulders + rng.uniform(-0.03, 0.03)
        rad = radius_fn(th) * rng.uniform(1.01, 1.08)
        cx, cy = rad * math.cos(th), rad * math.sin(th)
        if cy > 6.5 and abs(cx) < 2.2:
            # Keep clear notch for visible Zen rockery waterfall spout
            continue
        is_back = cy > 2.0
        rx = rng.uniform(1.7, 2.6)
        ry = rng.uniform(1.5, 2.3)
        rz = rng.uniform(1.5, 2.6) if is_back else rng.uniform(0.65, 1.05)
        add_sculpted_boulder(
            bm_rocks, Vector((cx, cy, water_z - 0.16 + 0.35 * rz)),
            rx, ry, rz, yaw=th + rng.uniform(-0.5, 0.5), tilt_x=rng.uniform(-0.15, 0.15),
            seed=5000 + i, water_z=water_z, subdiv=2, flatten_top=(not is_back),
        )

    # Back Zenith terraced rockery ridge (+Y=9..12, z up to 3.8) framing open spout notch at X=0
    for idx, (cx, cy, rx, ry, rz, cz) in enumerate([
        (-4.8, 10.6, 2.6, 2.2, 2.8, 2.0), (0.0, 12.2, 2.8, 2.0, 3.2, 2.4), (4.8, 10.4, 2.5, 2.1, 2.7, 1.9),
        (-2.8, 11.4, 2.0, 1.8, 2.4, 2.4), (2.8, 11.3, 2.1, 1.9, 2.5, 2.5),
        (0.0, 10.2, 1.6, 1.4, 0.8, 2.2),  # Spill ledge slab projecting spout cleanly forward
    ]):
        add_sculpted_boulder(bm_rocks, Vector((cx, cy, cz)), rx, ry, rz, yaw=idx * 0.7, tilt_x=0.1, seed=5500 + idx, water_z=water_z, subdiv=2)

    # Visible trickling water spout spilling cleanly off the rockery ledge into cove
    bm_wf = bmesh.new()
    add_waterfall_chute(
        bm_wf,
        top_pos=Vector((0.0, 9.5, 2.72)),
        dir_xy=Vector((0.0, -1.0)),
        width_top=2.0,
        width_bot=2.8,
        drop_dist=2.6,
        bot_z=water_z,
        segments_u=6,
        segments_v=10,
        add_splash_ring=True,
    )

    bm_flora = bmesh.new()
    # 5 Vivid Swimming Koi cleanly submerged underneath translucent water!
    for idx, (kx, ky, kl, kyaw, is_g) in enumerate([
        (-3.2, -1.5, 2.3, 0.45, False),
        (2.4, -2.8, 2.1, -1.2, True),
        (-0.8, 2.5, 2.2, 2.3, False),
        (5.5, 1.2, 1.85, -2.5, True),
        (-6.2, 1.8, 1.9, 0.95, False),
    ]):
        add_koi_fish(bm_flora, Vector((kx, ky, water_z - 0.24)), kl, yaw=kyaw, gold_variant=is_g, curve_dir=1.0 if idx % 2 == 0 else -1.0)

    # Crescent Lily Pad & Pink Lotus Arcs framing East & West sides cleanly (leaving center Koi window clear!)
    for idx, (lx, ly, lr, has_lot) in enumerate([
        (-8.6, 2.5, 1.45, True), (-7.2, 5.2, 1.25, False), (-9.2, -1.2, 1.6, True),
        (-7.4, -4.8, 1.35, False), (-5.0, -6.5, 1.5, True),
        (8.4, 2.8, 1.5, True), (7.0, 5.4, 1.2, False), (9.0, -1.5, 1.65, True),
        (7.2, -5.0, 1.3, False), (4.8, -6.6, 1.45, True), (1.8, 6.2, 1.2, False), (-2.2, 6.4, 1.25, False),
    ]):
        add_lily_pad(bm_flora, Vector((lx, ly, water_z + 0.03)), lr, yaw=idx * 0.85, seed=5800 + idx)
        if has_lot:
            add_lotus_flower(bm_flora, Vector((lx, ly, water_z + 0.05)), scale=lr * 0.56, yaw=idx * 0.6)

    # Gentle shore reeds & ornamental moss-rockery tufts
    for idx, (cx, cy, sc) in enumerate([
        (-8.8, 7.6, 1.05), (8.6, 7.4, 1.05), (-11.2, 0.2, 1.15), (11.0, -0.4, 1.15),
        (-5.8, 10.6, 0.95), (5.6, 10.5, 0.95), (-8.4, -7.2, 0.9), (8.2, -7.4, 0.9),
    ]):
        add_cattail_reed_clump(bm_flora, Vector((cx, cy, water_z + (0.65 if cy > 9 else -0.05))), scale=sc, seed=5900 + idx, num_blades=6, num_cattails=1 if cy < 0 else 2)

    return [
        _create_mesh_obj(bm_rocks, "Pond_Rocks", materials["Rock"], col, smooth=True),
        _create_mesh_obj(bm_bed, "Pond_Bed", materials["Bed"], col, smooth=True),
        _create_mesh_obj(bm_water, "Pond_Water", materials["Water"], col, smooth=True),
        _create_mesh_obj(bm_wf, "Pond_Waterfall", materials["Waterfall"], col, smooth=True),
        _create_mesh_obj(bm_flora, "Pond_Flora", materials["Flora"], col, smooth=True),
    ]


# ---------------------------------------------------------------------------
# POND 4: SteppingStreamPond (East Oak-Sakura Glade, Split Cascade + 5 Walkable Stepping Stones)
# ---------------------------------------------------------------------------

def build_stepping_stream_pond(materials: dict[str, bpy.types.Material], col: bpy.types.Collection) -> list[bpy.types.Object]:
    water_z = 0.42
    bed_z = 0.14

    def radius_fn(th: float) -> float:
        # Compact figure-8 / pinched-waist spring lagoon (~27.5 x 22 outer studs -> fits E glade 24.8 R comfortably!)
        return 9.6 + 2.4 * math.cos(2.0 * th) - 0.85 * math.cos(4.0 * th) + 0.65 * math.sin(th)

    bm_bed = bmesh.new()
    bm_water = bmesh.new()
    build_basin_and_water(
        bm_bed, bm_water, radius_fn, water_z=water_z, bed_z=bed_z,
        ang_steps=48, water_scale=1.03, bed_outer_scale=1.18, berm_top_z=water_z + 0.22, min_outer_z=-0.35,
    )

    bm_rocks = bmesh.new()
    rng = random.Random(4004)
    n_boulders = 40
    for i in range(n_boulders):
        th = (2.0 * math.pi * i) / n_boulders + rng.uniform(-0.03, 0.03)
        rad = radius_fn(th) * rng.uniform(1.01, 1.09)
        cx, cy = rad * math.cos(th), rad * math.sin(th)
        # Keep entrance & exit banks near x~0, y=+-9 flat & low so avatars easily step onto stepping stones!
        near_crossing = abs(cx) < 2.8 and abs(cy) > 5.0
        rx = rng.uniform(1.5, 2.2)
        ry = rng.uniform(1.4, 2.0)
        rz = rng.uniform(0.55, 0.78) if near_crossing else rng.uniform(0.95, 1.75)
        add_sculpted_boulder(
            bm_rocks, Vector((cx, cy, water_z - 0.18 + 0.34 * rz)),
            rx, ry, rz, yaw=th + rng.uniform(-0.5, 0.5), tilt_x=rng.uniform(-0.14, 0.14),
            seed=6000 + i, water_z=water_z, subdiv=2, flatten_top=near_crossing,
        )

    # Upper rocky spring ledge at West-North lobe (x ~ -11.5, y ~ +2.0, z ~ 2.4) spilling split cascade Eastward!
    for idx, (cx, cy, rx, ry, rz, cz) in enumerate([
        (-12.2, 2.4, 2.6, 2.6, 2.4, 1.65),
        (-13.6, 0.5, 2.2, 2.0, 2.7, 2.15),
        (-13.2, 4.4, 2.1, 2.0, 2.5, 2.00),
        (-10.4, 0.8, 1.4, 1.6, 1.2, 0.85),  # Middle weir splitter rock splitting waterfall into twin falls!
    ]):
        add_sculpted_boulder(bm_rocks, Vector((cx, cy, cz)), rx, ry, rz, yaw=idx * 0.8, tilt_x=0.08, seed=6400 + idx, water_z=water_z, subdiv=2)

    # 5 Flat-Topped Walkable Mossy Stepping Stones winding across narrow waist (y = -6.0 .. +6.0)
    # Top surface sits reliably at z ~ 0.62 (+0.20 above water_z=0.42), width ~ 3.4 studs!
    step_coords = [
        (-0.55, -5.8, 0.25),
        (0.55, -2.9, -0.35),
        (-0.35, 0.0, 0.18),
        (0.65, 2.9, -0.25),
        (-0.30, 5.8, 0.40),
    ]
    for idx, (sx, sy, syaw) in enumerate(step_coords):
        add_sculpted_boulder(
            bm_rocks, Vector((sx, sy, 0.22)),
            1.75, 1.55, 0.95, yaw=syaw, tilt_x=0.0,
            seed=6600 + idx, water_z=water_z, subdiv=2, flatten_top=True,
        )

    # Twin split-cascade chutes rushing off upper basin around center splitter rock into lagoon!
    bm_wf = bmesh.new()
    add_waterfall_chute(
        bm_wf, top_pos=Vector((-11.0, 2.7, 2.35)), dir_xy=Vector((1.0, -0.15)),
        width_top=1.6, width_bot=2.2, drop_dist=2.4, bot_z=water_z, segments_u=5, segments_v=9, add_splash_ring=True,
    )
    add_waterfall_chute(
        bm_wf, top_pos=Vector((-11.2, -0.4, 2.10)), dir_xy=Vector((1.0, 0.10)),
        width_top=1.4, width_bot=2.0, drop_dist=2.2, bot_z=water_z, segments_u=5, segments_v=9, add_splash_ring=True,
    )

    bm_flora = bmesh.new()
    # Curved driftwood timber + 3 Koi in the wider +X lobe + Lily/Lotus/Cattails!
    add_mossy_driftwood_log(bm_flora, Vector((7.6, 5.2, water_z + 0.14)), length=5.2, radius=0.48, yaw=-0.55, pitch=0.08)

    for idx, (kx, ky, kl, kyaw, is_g) in enumerate([
        (5.5, -1.5, 2.0, 1.2, True),
        (8.0, 0.8, 1.85, -0.7, False),
        (-5.8, -3.2, 1.8, 2.4, False),
    ]):
        add_koi_fish(bm_flora, Vector((kx, ky, water_z - 0.22)), kl, yaw=kyaw, gold_variant=is_g, curve_dir=1.0 if idx % 2 == 0 else -1.0)

    for idx, (lx, ly, lr, has_lot) in enumerate([
        (5.8, -4.5, 1.4, True), (8.2, -3.2, 1.2, False), (9.0, 1.6, 1.5, True),
        (4.5, 4.4, 1.3, False), (-5.0, 5.2, 1.35, True), (-6.8, -5.2, 1.45, True),
        (-3.5, -5.8, 1.15, False), (2.2, -5.5, 1.25, False),
    ]):
        add_lily_pad(bm_flora, Vector((lx, ly, water_z + 0.03)), lr, yaw=idx * 0.9, seed=6800 + idx)
        if has_lot:
            add_lotus_flower(bm_flora, Vector((lx, ly, water_z + 0.05)), scale=lr * 0.56, yaw=idx * 0.7)

    for idx, (cx, cy, sc) in enumerate([
        (-11.4, -4.4, 1.1), (-11.6, 5.8, 1.1), (10.6, -5.2, 1.15), (10.8, 4.6, 1.1),
        (7.0, -7.2, 1.0), (-6.8, -7.2, 1.0), (-9.8, 0.8, 0.9),
    ]):
        add_cattail_reed_clump(bm_flora, Vector((cx, cy, water_z - 0.05)), scale=sc, seed=6900 + idx, num_blades=6, num_cattails=2)

    return [
        _create_mesh_obj(bm_rocks, "Pond_Rocks", materials["Rock"], col, smooth=True),
        _create_mesh_obj(bm_bed, "Pond_Bed", materials["Bed"], col, smooth=True),
        _create_mesh_obj(bm_water, "Pond_Water", materials["Water"], col, smooth=True),
        _create_mesh_obj(bm_wf, "Pond_Waterfall", materials["Waterfall"], col, smooth=True),
        _create_mesh_obj(bm_flora, "Pond_Flora", materials["Flora"], col, smooth=True),
    ]


# ---------------------------------------------------------------------------
# Export FBX & Render Preview
# ---------------------------------------------------------------------------

def export_collection_fbx(col: bpy.types.Collection, out_path: Path) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in col.objects:
        obj.hide_viewport = False
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = col.objects[0]

    bpy.ops.export_scene.fbx(
        filepath=str(out_path),
        use_selection=True,
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z",
        axis_up="Y",
        bake_space_transform=False,
        object_types={"MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
    )
    size_bytes = out_path.stat().st_size
    if size_bytes >= MAX_FBX_BYTES:
        raise RuntimeError(f"{out_path.name} is {size_bytes / (1024 * 1024):.2f} MB >= {MAX_FBX_BYTES / (1024 * 1024):.1f} MB limit")
    print(f"[EXPORT] {out_path.name}: {size_bytes / (1024 * 1024):.2f} MB")


def setup_preview_studio() -> tuple[bpy.types.Object, bpy.types.Object]:
    scene = bpy.context.scene
    # Clean sunny meadow world sky + grass backdrop plane so renders look natural
    world = bpy.data.worlds.new("PondPreviewSky")
    world.use_nodes = True
    nt = world.node_tree
    bg = nt.nodes["Background"]
    bg.inputs["Color"].default_value = (0.48, 0.72, 0.94, 1.0)
    bg.inputs["Strength"].default_value = 0.85
    scene.world = world

    sun_data = bpy.data.lights.new("PreviewSun", type="SUN")
    sun_data.energy = 3.8
    sun_data.angle = math.radians(2.2)
    sun_obj = bpy.data.objects.new("PreviewSun", sun_data)
    sun_obj.rotation_euler = Euler((math.radians(48), math.radians(15), math.radians(-38)), "XYZ")
    scene.collection.objects.link(sun_obj)

    # Meadow grass backdrop quad at Z = -0.02
    bpy.ops.mesh.primitive_plane_add(size=180.0, location=(0, 0, -0.02))
    ground = bpy.context.active_object
    ground.name = "_PreviewGrassPlane"
    gmat = bpy.data.materials.new("PreviewGrass")
    gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.14, 0.30, 0.08, 1.0)
    gmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.88
    ground.data.materials.append(gmat)

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 34.0
    cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj
    return cam_obj, ground


def render_collection_preview(
    col: bpy.types.Collection,
    cam_obj: bpy.types.Object,
    cam_pos: tuple[float, float, float],
    target_pos: tuple[float, float, float],
    all_cols: list[bpy.types.Collection],
    out_png: Path,
) -> None:
    for c in all_cols:
        hide = (c != col)
        for obj in c.objects:
            obj.hide_render = hide
            obj.hide_viewport = hide

    cam_obj.location = Vector(cam_pos)
    direction = Vector(target_pos) - Vector(cam_pos)
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    bpy.context.scene.render.filepath = str(out_png)
    bpy.ops.render.render(write_still=True)
    print(f"[RENDER] {out_png}")


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SCRATCH_DIR.mkdir(parents=True, exist_ok=True)
    ENV_DIR.mkdir(parents=True, exist_ok=True)

    print("[POND GEN] Synthesizing 6 seamless/atlas PBR texture sets...")
    tex_reg = generate_all_textures()

    materials = {
        "Rock": make_pbr_material("Mat_PondRock", tex_reg["Tex_PondRock"], has_alpha=False),
        "Masonry": make_pbr_material("Mat_BridgeMasonry", tex_reg["Tex_BridgeMasonry"], has_alpha=False),
        "Bed": make_pbr_material("Mat_PondBed", tex_reg["Tex_PondBed"], has_alpha=False),
        "Water": make_pbr_material("Mat_PondWater", tex_reg["Tex_PondWater"], has_alpha=True),
        "Waterfall": make_pbr_material("Mat_WaterfallFoam", tex_reg["Tex_WaterfallFoam"], has_alpha=True),
        "Flora": make_pbr_material("Mat_PondFlora", tex_reg["Tex_PondFlora"], has_alpha=False),
    }

    builders = [
        ("HeroBridgePond", build_hero_bridge_pond, (-44.0, -48.0, 34.0), (0.0, 0.0, 2.2), "pond_1_bridge.png"),
        ("WaterfallBoulderPond", build_waterfall_boulder_pond, (-19.0, -23.0, 17.5), (0.0, 1.5, 2.4), "pond_2_waterfall.png"),
        ("RockeryKoiPond", build_rockery_koi_pond, (18.0, -21.0, 15.0), (0.0, 0.5, 1.0), "pond_3_rockery.png"),
        ("SteppingStreamPond", build_stepping_stream_pond, (14.0, -22.5, 16.5), (-1.0, 0.0, 1.0), "pond_4_stream.png"),
    ]

    collections: list[bpy.types.Collection] = []
    for name, fn, _, _, _ in builders:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
        objs = fn(materials, col)
        tri_total = sum(sum(max(1, len(p.vertices) - 2) for p in o.data.polygons) for o in objs)
        print(f"[BUILD] {name}: {len(objs)} MeshParts, {tri_total} total triangles")
        export_collection_fbx(col, ENV_DIR / f"{name}.fbx")
        collections.append(col)

    configure_cycles_gpu(samples=36, res_x=1280, res_y=720)
    cam_obj, _ = setup_preview_studio()

    for col, (_, _, cam_pos, tgt, png_name) in zip(collections, builders):
        render_collection_preview(col, cam_obj, cam_pos, tgt, collections, SCRATCH_DIR / png_name)

    # Restore visibility & save inspectable .blend file
    for c in collections:
        for obj in c.objects:
            obj.hide_render = False
            obj.hide_viewport = False
    blend_path = SCRATCH_DIR / "HubPonds.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    print(f"[DONE] Saved {blend_path}")


if __name__ == "__main__":
    main()
