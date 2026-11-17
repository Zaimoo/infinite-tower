"""
Procedural Blender 5.x Generator for the Infinite Tower Merchant Bazaar.

Generates:
  1. Two 1024x1024 PBR Texture Sets (Color, Normal, Roughness):
     - assets/models/facilities/textures/merchant_bazaar/Tex_BazaarGround_*.png
     - assets/models/facilities/textures/merchant_bazaar/Tex_BazaarProps_*.png
  2. One multi-object FBX prefab (< 4,500 tris total) under collection `MerchantBazaar_Prefab`:
     - Bazaar_FlagstonePath (organic jigsaw flagstones + thin central earth bed, NO concrete pad)
     - Bazaar_GrassTufts (low-poly double-sided grass clusters between flagstones & outer seams)
     - Stall_TimberFrame (3 interconnected curved corner stalls + left signboard arm + iron hooks)
     - Stall_Counters (3 bevelled wooden counters + 9 produce bin trays + rear stool)
     - Awning_Left_RedYellow (5-stripe Red #C82829 & Yellow #F2B705 awning)
     - Awning_Center_Tan (draped dual-bay sagging Warm Tan #D9B382 canopy)
     - Awning_Right_GreenWhite (5-stripe Green #2E8B57 & White #F4F1EA awning)
     - Sign_HangingBoard (separate mesh pivoted at top iron hinge rings for breeze sway)
     - Bazaar_Props_Clutter (barrels, tied sacks, crates, slanted fruit boxes, produce bins)
     - Lantern_Housing_1, Lantern_Housing_2, Lantern_Housing_3 (each pivoted at top hook ring)
  3. Metadata manifest:
     - assets/models/facilities/merchant_bazaar_manifest.json
  4. EEVEE verification screenshots in the scratch artifact folder (when available or `--renders`).

Coordinate Mapping:
  Roblox (rx, ry, rz) [+X right, +Y up, +Z forward toward courtyard]
  -> Blender (bx, by, bz) = (rx, -rz, ry)
  FBX Exported with axis_forward='Z', axis_up='Y' matching generate_training_grounds.py.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import struct
import sys
import zlib
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector
import numpy as np


# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = REPO_ROOT / "assets" / "models" / "facilities"
TEX_DIR = ASSET_DIR / "textures" / "merchant_bazaar"
FBX_PATH = ASSET_DIR / "MerchantBazaar.fbx"
MANIFEST_PATH = ASSET_DIR / "merchant_bazaar_manifest.json"
DEFAULT_RENDER_DIR = REPO_ROOT / "tools" / "blender" / "renders" / "merchant_bazaar"

TEX_SIZE = 1024
CELL_PX = 256
CELL_PAD_PX = 14


# ---------------------------------------------------------------------------
# Coordinate & Math Helpers
# ---------------------------------------------------------------------------
def rbx_to_blender(rx: float, ry: float, rz: float) -> Vector:
    return Vector((rx, -rz, ry))


def stall_to_rbx(
    cx: float,
    cz: float,
    yaw_deg: float,
    sx: float,
    sy: float,
    sz: float,
) -> tuple[float, float, float]:
    """Convert stall-local (sx, sy, sz) to Market-local Roblox (rx, ry, rz).
    Follows Roblox CFrame.Angles(0, rad(yaw_deg), 0):
      Right (+X) = (cos, 0, -sin)
      Back  (+Z) = (sin, 0,  cos)  (courtyard-facing front)
    """
    a = math.radians(yaw_deg)
    ca = math.cos(a)
    sa = math.sin(a)
    rx = cx + sx * ca + sz * sa
    rz = cz - sx * sa + sz * ca
    return (rx, sy, rz)


def stall_to_blender(
    cx: float,
    cz: float,
    yaw_deg: float,
    sx: float,
    sy: float,
    sz: float,
) -> Vector:
    rx, ry, rz = stall_to_rbx(cx, cz, yaw_deg, sx, sy, sz)
    return rbx_to_blender(rx, ry, rz)


def cell_uv_bounds(col: int, row_from_top: int, pad_px: int = CELL_PAD_PX) -> tuple[float, float, float, float]:
    """Return (u0, u1, v0, v1) with pixel gutter so mipmaps never bleed across cells."""
    px0 = col * CELL_PX + pad_px
    px1 = (col + 1) * CELL_PX - pad_px
    py0_top = row_from_top * CELL_PX + pad_px
    py1_bot = (row_from_top + 1) * CELL_PX - pad_px
    u0 = px0 / TEX_SIZE
    u1 = px1 / TEX_SIZE
    v1 = 1.0 - (py0_top / TEX_SIZE)
    v0 = 1.0 - (py1_bot / TEX_SIZE)
    return (u0, u1, v0, v1)


def map_cell_uv(cell: tuple[int, int], lu: float, lv: float) -> tuple[float, float]:
    u0, u1, v0, v1 = cell_uv_bounds(cell[0], cell[1])
    return (u0 + lu * (u1 - u0), v0 + lv * (v1 - v0))


# ---------------------------------------------------------------------------
# Fast Lossless PNG Writer (RGBA/RGB uint8 -> PNG)
# ---------------------------------------------------------------------------
def write_png_rgba(path: Path, rgba: np.ndarray) -> None:
    """Write an (H, W, 4) uint8 numpy array to a compressed PNG file."""
    h, w, c = rgba.shape
    assert c == 4 and rgba.dtype == np.uint8
    raw_rows = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))
    compressed = zlib.compress(raw_rows, level=6)

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def _hash_noise_2d(h: int, w: int, scale: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    gh = max(4, h // scale + 2)
    gw = max(4, w // scale + 2)
    grid = rng.random((gh, gw), dtype=np.float32)
    yy = np.linspace(0.0, gh - 1.001, h, dtype=np.float32)[:, None]
    xx = np.linspace(0.0, gw - 1.001, w, dtype=np.float32)[None, :]
    y0 = np.floor(yy).astype(np.int32)
    x0 = np.floor(xx).astype(np.int32)
    fy = yy - y0
    fx = xx - x0
    fy = fy * fy * (3.0 - 2.0 * fy)
    fx = fx * fx * (3.0 - 2.0 * fx)
    v00 = grid[y0, x0]
    v10 = grid[y0, x0 + 1]
    v01 = grid[y0 + 1, x0]
    v11 = grid[y0 + 1, x0 + 1]
    return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy


def fbm_grid(h: int, w: int, seed: int, octaves: tuple[int, ...] = (64, 32, 16, 8)) -> np.ndarray:
    acc = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for idx, sc in enumerate(octaves):
        acc += amp * _hash_noise_2d(h, w, sc, seed + idx * 97)
        norm += amp
        amp *= 0.5
    return acc / max(norm, 1e-6)


def height_to_normal_rgb(height: np.ndarray, strength: float = 2.0) -> np.ndarray:
    gx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    gy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(height)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    rgb = np.stack([
        np.clip((nx * inv * 0.5 + 0.5) * 255.0, 0, 255),
        np.clip((ny * inv * 0.5 + 0.5) * 255.0, 0, 255),
        np.clip((nz * inv * 0.5 + 0.5) * 255.0, 0, 255),
    ], axis=-1)
    return rgb.astype(np.uint8)


# ---------------------------------------------------------------------------
# Procedural 1024x1024 PBR Atlas Generators
# ---------------------------------------------------------------------------
def _cell_coords() -> tuple[np.ndarray, np.ndarray]:
    lin = np.linspace(0.0, 1.0, CELL_PX, dtype=np.float32)
    uu, vv = np.meshgrid(lin, 1.0 - lin)  # vv=1 at top of cell (py=0), vv=0 at bottom
    return uu, vv


def _make_atlas_buffers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    col = np.zeros((TEX_SIZE, TEX_SIZE, 4), dtype=np.uint8)
    col[..., 3] = 255
    height = np.full((TEX_SIZE, TEX_SIZE), 0.5, dtype=np.float32)
    rough = np.full((TEX_SIZE, TEX_SIZE), 200, dtype=np.uint8)
    return col, height, rough


def _put_cell(
    atlas_col: np.ndarray,
    atlas_h: np.ndarray,
    atlas_r: np.ndarray,
    cell: tuple[int, int],
    rgb: np.ndarray,
    h: np.ndarray,
    r: np.ndarray,
) -> None:
    cx, cy = cell
    x0, x1 = cx * CELL_PX, (cx + 1) * CELL_PX
    y0, y1 = cy * CELL_PX, (cy + 1) * CELL_PX
    atlas_col[y0:y1, x0:x1, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    atlas_h[y0:y1, x0:x1] = h.astype(np.float32)
    atlas_r[y0:y1, x0:x1] = np.clip(r * 255.0, 0, 255).astype(np.uint8)


def generate_bazaar_ground_textures() -> tuple[Path, Path, Path]:
    """Generate Tex_BazaarGround_{Color,Normal,Roughness}.png (4x4 stone & grass atlas matching castle courtyard granite)."""
    col, height, rough = _make_atlas_buffers()
    uu, vv = _cell_coords()
    radial = np.hypot(uu - 0.5, vv - 0.5)
    # Soft outer bevel AO covering Voronoi f_top rims & f_side skirts (lv in [0.08, 0.28]) without staining top faces
    edge_ao = np.clip(1.0 - np.clip((radial - 0.30) / 0.16, 0.0, 1.0) * 0.22, 0.78, 1.0)

    # 5 weathered cool-neutral castle granite cells used by stone_cells [(0,0), (1,0), (2,0), (3,0), (0,1)]
    stone_specs = [
        ((0, 0), -0.60, 0.05, 0.00, True,  0.48,  0.04, 101),  # Darker slate-ash granite
        ((1, 0),  0.30, 0.10, 0.00, False, 0.00,  0.00, 102),  # Lighter weathered castle stone
        ((2, 0), -0.18, -0.08, 0.14, True, 2.15, -0.05, 103),  # Mid neutral grey stone w/ hairline crack
        ((3, 0),  0.65, 0.12, 0.00, False, 0.00,  0.00, 104),  # Pale weathered flagstone grey
        ((0, 1), -0.08, -0.05, 0.22, True, 1.25,  0.03, 201),  # Weathered ash stone w/ subtle crack & trace lichen
    ]

    for cell, tone, warmth, moss_hint, has_crack, crack_ang, crack_off, seed in stone_specs:
        n_stone = fbm_grid(CELL_PX, CELL_PX, seed, (48, 24, 12, 6))
        n_grain = fbm_grid(CELL_PX, CELL_PX, seed + 50, (6, 3, 2))

        base_grey = np.array([99.0, 101.0, 104.0], dtype=np.float32)
        tone_shift = tone * np.array([12.0, 12.0, 12.0], dtype=np.float32)
        warm_shift = warmth * np.array([3.5, 2.5, 0.0], dtype=np.float32)
        weather_var = (n_stone[..., None] - 0.5) * np.array([24.0, 24.0, 23.5], dtype=np.float32)
        grain_var = (n_grain[..., None] - 0.5) * np.array([11.0, 11.0, 11.0], dtype=np.float32)

        pitting = np.clip((0.36 - n_stone) * 2.1, 0.0, 1.0)[..., None]
        lichen = np.clip((n_stone - 0.60) * moss_hint * 1.1, 0.0, 0.08)[..., None]
        crack = np.zeros_like(n_stone)
        if has_crack:
            ca = math.cos(crack_ang)
            sa = math.sin(crack_ang)
            c_dist = np.abs((uu - 0.5) * ca + (vv - 0.5) * sa - crack_off + (n_stone - 0.5) * 0.065)
            inside = radial < 0.42
            crack = np.where(inside, np.clip(1.0 - c_dist / 0.0085, 0.0, 1.0), 0.0)

        rgb = (base_grey + tone_shift + warm_shift + weather_var + grain_var) * edge_ao[..., None]
        rgb = rgb * (1.0 - pitting * 0.14)
        rgb = rgb * (1.0 - lichen) + np.array([82.0, 86.0, 79.0], dtype=np.float32) * lichen
        rgb = rgb * (1.0 - crack[..., None] * 0.24)

        h_map = (
            0.58
            + tone * 0.03
            + 0.16 * (n_stone - 0.5)
            + 0.07 * (n_grain - 0.5)
            - 0.09 * pitting[..., 0]
            - 0.18 * crack
        ) * (0.76 + 0.24 * edge_ao)
        r_map = np.clip(0.79 - 0.05 * (n_stone - 0.5) + 0.07 * crack - tone * 0.02, 0.70, 0.89)
        _put_cell(col, height, rough, cell, rgb, h_map, r_map)

    # (1,1): Stylized grass blade gradient (root -> sunlit blade tip, fine striated veins)
    n_grass = fbm_grid(CELL_PX, CELL_PX, 211, (32, 16, 8))
    # Vertical striations along uu
    streak = _hash_noise_2d(CELL_PX, CELL_PX, 6, 215)
    blade_grad = np.clip(vv * 0.85 + 0.15 * streak, 0.0, 1.0)
    root_c = np.array([46.0, 74.0, 34.0])
    mid_c = np.array([75.0, 114.0, 52.0])
    tip_c = np.array([104.0, 146.0, 70.0])
    lo_blend = np.clip(blade_grad * 2.0, 0.0, 1.0)[..., None]
    hi_blend = np.clip((blade_grad - 0.5) * 2.0, 0.0, 1.0)[..., None]
    rgb_grass = np.where(
        blade_grad[..., None] < 0.5,
        root_c * (1.0 - lo_blend) + mid_c * lo_blend,
        mid_c * (1.0 - hi_blend) + tip_c * hi_blend,
    )
    rgb_grass *= (0.90 + 0.16 * n_grass[..., None])
    _put_cell(col, height, rough, (1, 1), rgb_grass, 0.45 + 0.25 * streak, np.full((CELL_PX, CELL_PX), 0.84))

    # (2,1): Dark packed mortar/gravel earth between cobblestones
    n_dirt = fbm_grid(CELL_PX, CELL_PX, 221, (16, 8, 4))
    rgb_dirt = np.array([46.0, 48.0, 52.0]) + n_dirt[..., None] * np.array([16.0, 16.0, 16.0])
    _put_cell(col, height, rough, (2, 1), rgb_dirt, 0.30 + 0.25 * n_dirt, np.full((CELL_PX, CELL_PX), 0.93))

    # (3,1): Charcoal curb granite matching courtyard ash tones
    n_curb = fbm_grid(CELL_PX, CELL_PX, 231, (24, 12, 6))
    rgb_curb = np.array([72.0, 74.0, 78.0]) + n_curb[..., None] * np.array([22.0, 22.0, 22.0])
    _put_cell(col, height, rough, (3, 1), rgb_curb, 0.48 + 0.30 * n_curb, np.full((CELL_PX, CELL_PX), 0.84))

    # Fill unused bottom cells with clean fallback granite so no blank black pixels exist
    for cy in (2, 3):
        for cx in range(4):
            _put_cell(col, height, rough, (cx, cy), rgb_dirt if cy == 3 else rgb_curb, 0.45 + 0.25 * n_curb, np.full((CELL_PX, CELL_PX), 0.86))

    norm_rgb = height_to_normal_rgb(height, strength=2.8)
    norm_rgba = np.dstack([norm_rgb, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])
    rough_rgba = np.dstack([rough, rough, rough, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])

    p_col = TEX_DIR / "Tex_BazaarGround_Color.png"
    p_nrm = TEX_DIR / "Tex_BazaarGround_Normal.png"
    p_rgh = TEX_DIR / "Tex_BazaarGround_Roughness.png"
    write_png_rgba(p_col, col)
    write_png_rgba(p_nrm, norm_rgba)
    write_png_rgba(p_rgh, rough_rgba)
    return p_col, p_nrm, p_rgh


def generate_bazaar_props_textures() -> tuple[Path, Path, Path]:
    """Generate Tex_BazaarProps_{Color,Normal,Roughness}.png (4x4 wood, canvas, crate, barrel, burlap, produce, iron, lantern)."""
    col, height, rough = _make_atlas_buffers()
    uu, vv = _cell_coords()

    def make_wood(
        seed: int,
        base_rgb: tuple[float, float, float],
        seam_rgb: tuple[float, float, float],
        n_planks: int,
        rough_val: float,
        vertical_grain: bool = False,
    ):
        grain_u = _hash_noise_2d(CELL_PX, CELL_PX, 4, seed)
        streak = _hash_noise_2d(CELL_PX, CELL_PX, 32, seed + 11)
        grain = 0.55 * streak + 0.45 * grain_u
        rgb = np.array(base_rgb) * (0.86 + 0.24 * grain[..., None])
        h_map = 0.55 + 0.18 * grain
        r_map = np.full((CELL_PX, CELL_PX), rough_val)
        if not vertical_grain and n_planks > 1:
            plank_pos = (vv * n_planks) % 1.0
            seam = (plank_pos < 0.045) | (plank_pos > 0.955)
            rgb[seam] = np.array(seam_rgb) * 0.85
            h_map[seam] = 0.25
            r_map[seam] = min(0.95, rough_val + 0.12)
        return rgb, h_map, r_map

    def make_canvas(seed: int, hex_rgb: tuple[float, float, float], rough_val: float = 0.86):
        w_x = np.sin(uu * math.pi * 48.0) * 0.5 + 0.5
        w_y = np.sin(vv * math.pi * 48.0) * 0.5 + 0.5
        weave = 0.5 * w_x + 0.5 * w_y
        wear = fbm_grid(CELL_PX, CELL_PX, seed, (64, 32, 16))
        rgb = np.array(hex_rgb) * (0.93 + 0.12 * wear[..., None] + 0.015 * (weave[..., None] - 0.5))
        h_map = 0.5 + 0.06 * weave + 0.12 * wear
        return rgb, h_map, np.full((CELL_PX, CELL_PX), rough_val)

    # Row 0: Timber, Oak, Crate, Barrel
    # (0,0) Dark Structural Timber (#6B4728, clean vertical timber grain with no cross-rings)
    _put_cell(col, height, rough, (0, 0), *make_wood(301, (104.0, 68.0, 39.0), (58.0, 36.0, 20.0), 1, 0.82, vertical_grain=True))
    # (1,0) Warm Oak Counter Planks (#8E5D36)
    _put_cell(col, height, rough, (1, 0), *make_wood(302, (144.0, 96.0, 56.0), (88.0, 56.0, 32.0), 4, 0.72))

    # (2,0) Panelled Pine Crate with diagonal cross-brace
    c_rgb, c_h, c_r = make_wood(303, (146.0, 102.0, 58.0), (96.0, 64.0, 34.0), 4, 0.80)
    border = (uu < 0.15) | (uu > 0.85) | (vv < 0.15) | (vv > 0.85)
    diag = np.abs((uu - 0.5) - (vv - 0.5)) < 0.09
    frame = border | diag
    c_rgb[frame] = np.array([112.0, 74.0, 40.0]) * (0.92 + 0.12 * fbm_grid(CELL_PX, CELL_PX, 304, (16, 8))[..., None])[frame]
    c_h[frame] = 0.78
    # Corner brass/iron nail heads
    for nx, ny in ((0.09, 0.09), (0.91, 0.09), (0.09, 0.91), (0.91, 0.91)):
        nail = ((uu - nx) ** 2 + (vv - ny) ** 2) < (0.025 ** 2)
        c_rgb[nail] = np.array([42.0, 44.0, 48.0])
        c_h[nail] = 0.88
    _put_cell(col, height, rough, (2, 0), c_rgb, c_h, c_r)

    # (3,0) Barrel Vertical Oak Staves + Dual Wrought-Iron Hoops
    b_grain = fbm_grid(CELL_PX, CELL_PX, 305, (32, 16, 8))
    stave_pos = (uu * 8.0) % 1.0
    stave_seam = (stave_pos < 0.05) | (stave_pos > 0.95)
    b_rgb = np.array([118.0, 76.0, 44.0]) * (0.86 + 0.22 * b_grain[..., None])
    b_rgb[stave_seam] = np.array([62.0, 38.0, 20.0])
    b_h = 0.52 + 0.16 * b_grain
    b_h[stave_seam] = 0.25
    b_r = np.full((CELL_PX, CELL_PX), 0.80)
    hoop = ((vv > 0.16) & (vv < 0.26)) | ((vv > 0.74) & (vv < 0.84))
    b_rgb[hoop] = np.array([40.0, 43.0, 49.0]) * (0.9 + 0.16 * b_grain[..., None])[hoop]
    b_h[hoop] = 0.84
    b_r[hoop] = 0.36
    _put_cell(col, height, rough, (3, 0), b_rgb, b_h, b_r)

    # Row 1: Canopy Awning Colors
    _put_cell(col, height, rough, (0, 1), *make_canvas(311, (200.0, 40.0, 41.0), 0.86))   # Crimson #C82829
    _put_cell(col, height, rough, (1, 1), *make_canvas(312, (242.0, 183.0, 5.0), 0.86))   # Gold Yellow #F2B705
    _put_cell(col, height, rough, (2, 1), *make_canvas(313, (46.0, 139.0, 87.0), 0.86))   # Forest Green #2E8B57
    _put_cell(col, height, rough, (3, 1), *make_canvas(314, (244.0, 241.0, 234.0), 0.87)) # Warm White #F4F1EA

    # Row 2: Tan Canopy, Burlap Sack + Rope, Cream Grain Bag, Signboard Plaque
    tan_rgb, tan_h, tan_r = make_canvas(321, (217.0, 179.0, 130.0), 0.88)                 # Warm Tan #D9B382
    _put_cell(col, height, rough, (0, 2), tan_rgb, tan_h, tan_r)

    # (1,2) Coarse Burlap Sack + Dark Rope Band near neck (vv in 0.68..0.78)
    s_rgb, s_h, s_r = make_canvas(322, (176.0, 142.0, 96.0), 0.93)
    rope = (vv > 0.68) & (vv < 0.78)
    twist = np.sin(uu * math.pi * 24.0 + vv * math.pi * 16.0) * 0.5 + 0.5
    s_rgb[rope] = (np.array([112.0, 82.0, 46.0]) * (0.82 + 0.3 * twist[..., None]))[rope]
    s_h[rope] = 0.78
    _put_cell(col, height, rough, (1, 2), s_rgb, s_h, s_r)

    # (2,2) Cream Folded Grain Bags (#D4BE92)
    _put_cell(col, height, rough, (2, 2), *make_canvas(323, (212.0, 190.0, 146.0), 0.89))

    # (3,2) Cream Painted Signboard Plaque (#EDE4CF) with subtle dark trim border
    p_rgb, p_h, p_r = make_wood(324, (237.0, 228.0, 207.0), (204.0, 194.0, 172.0), 1, 0.72, vertical_grain=True)
    p_trim = (uu < 0.08) | (uu > 0.92) | (vv < 0.08) | (vv > 0.92)
    p_rgb[p_trim] = np.array([86.0, 56.0, 32.0])
    p_h[p_trim] = 0.68
    _put_cell(col, height, rough, (3, 2), p_rgb, p_h, p_r)

    # Row 3: Iron, Amber Glass, Red/Orange Produce, Yellow/Green Produce
    # (0,3) Dark Wrought Iron (#24272E)
    n_iron = fbm_grid(CELL_PX, CELL_PX, 331, (32, 16, 8))
    i_rgb = np.array([36.0, 39.0, 46.0]) * (0.85 + 0.3 * n_iron[..., None])
    _put_cell(col, height, rough, (0, 3), i_rgb, 0.5 + 0.25 * n_iron, np.full((CELL_PX, CELL_PX), 0.36))

    # (1,3) Warm Amber Lantern Glass (#F59E0B -> #FDE68A center glow)
    rad = np.sqrt((uu - 0.5) ** 2 + (vv - 0.5) ** 2) * 2.0
    glow = np.clip(1.0 - rad * 0.72, 0.0, 1.0)
    g_rgb = (np.array([245.0, 158.0, 11.0]) * (1.0 - glow[..., None])
             + np.array([254.0, 232.0, 146.0]) * glow[..., None])
    # Faint iron mullion border around edges
    mullion = (uu < 0.08) | (uu > 0.92) | (vv < 0.08) | (vv > 0.92)
    g_rgb[mullion] = np.array([40.0, 42.0, 48.0])
    _put_cell(col, height, rough, (1, 3), g_rgb, np.where(mullion, 0.75, 0.45), np.where(mullion, 0.4, 0.18))

    # (2,3) Left half Crimson Red (#DC322F), Right half Mandarin Orange (#F97316)
    n_fr1 = fbm_grid(CELL_PX, CELL_PX, 332, (24, 12))
    red_c = np.array([220.0, 48.0, 45.0]) * (0.88 + 0.2 * n_fr1[..., None])
    ora_c = np.array([246.0, 118.0, 22.0]) * (0.88 + 0.2 * n_fr1[..., None])
    fr1_rgb = np.where(uu[..., None] < 0.5, red_c, ora_c)
    _put_cell(col, height, rough, (2, 3), fr1_rgb, 0.5 + 0.12 * n_fr1, np.full((CELL_PX, CELL_PX), 0.38))

    # (3,3) Left half Sunny Yellow (#F5C518), Right half Fresh Green (#62AD32)
    n_fr2 = fbm_grid(CELL_PX, CELL_PX, 333, (24, 12))
    yel_c = np.array([245.0, 198.0, 28.0]) * (0.90 + 0.18 * n_fr2[..., None])
    grn_c = np.array([102.0, 178.0, 48.0]) * (0.88 + 0.2 * n_fr2[..., None])
    fr2_rgb = np.where(uu[..., None] < 0.5, yel_c, grn_c)
    _put_cell(col, height, rough, (3, 3), fr2_rgb, 0.5 + 0.12 * n_fr2, np.full((CELL_PX, CELL_PX), 0.40))

    norm_rgb = height_to_normal_rgb(height, strength=2.2)
    norm_rgba = np.dstack([norm_rgb, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])
    rough_rgba = np.dstack([rough, rough, rough, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])

    p_col = TEX_DIR / "Tex_BazaarProps_Color.png"
    p_nrm = TEX_DIR / "Tex_BazaarProps_Normal.png"
    p_rgh = TEX_DIR / "Tex_BazaarProps_Roughness.png"
    write_png_rgba(p_col, col)
    write_png_rgba(p_nrm, norm_rgba)
    write_png_rgba(p_rgh, rough_rgba)
    return p_col, p_nrm, p_rgh


# ---------------------------------------------------------------------------
# Material Creation
# ---------------------------------------------------------------------------
def create_pbr_material(name: str, p_col: Path, p_nrm: Path, p_rgh: Path) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def load_img(path: Path, colorspace: str) -> bpy.types.Image:
        img = bpy.data.images.load(str(path), check_existing=True)
        img.colorspace_settings.name = colorspace
        img.pack()
        return img

    tex_c = nt.nodes.new("ShaderNodeTexImage")
    tex_c.image = load_img(p_col, "sRGB")
    nt.links.new(tex_c.outputs["Color"], bsdf.inputs["Base Color"])

    tex_r = nt.nodes.new("ShaderNodeTexImage")
    tex_r.image = load_img(p_rgh, "Non-Color")
    nt.links.new(tex_r.outputs["Color"], bsdf.inputs["Roughness"])

    tex_n = nt.nodes.new("ShaderNodeTexImage")
    tex_n.image = load_img(p_nrm, "Non-Color")
    nrm = nt.nodes.new("ShaderNodeNormalMap")
    nrm.inputs["Strength"].default_value = 0.85
    nt.links.new(tex_n.outputs["Color"], nrm.inputs["Color"])
    nt.links.new(nrm.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


# ---------------------------------------------------------------------------
# BMesh Primitives
# ---------------------------------------------------------------------------
def add_box_rbx(
    bm: bmesh.types.BMesh,
    uv_layer,
    center_rbx: tuple[float, float, float],
    size_rbx: tuple[float, float, float],
    cell: tuple[int, int],
    rot_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
    origin_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    """Create a box in Roblox space transformed to Blender (optionally shifted relative to origin_rbx)."""
    res = bmesh.ops.create_cube(bm, size=1.0)
    verts = res["verts"]
    sx, sy, sz = size_rbx
    rx, ry, rz = center_rbx
    ox, oy, oz = origin_rbx
    pitch, yaw, roll = rot_rbx

    # Build rotation in Roblox YXZ -> transform each local box corner -> rbx_to_blender
    rot_mat = Euler((pitch, yaw, roll), "YXZ").to_matrix()
    for v in verts:
        local_rbx = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz))
        p_rbx = Vector((rx - ox, ry - oy, rz - oz)) + (rot_mat @ local_rbx)
        v.co = rbx_to_blender(p_rbx.x, p_rbx.y, p_rbx.z)

    seen_faces = set()
    for v in verts:
        for f in v.link_faces:
            if f in seen_faces:
                continue
            seen_faces.add(f)
            coords = [(0.05, 0.05), (0.95, 0.05), (0.95, 0.95), (0.05, 0.95)]
            for idx, loop in enumerate(f.loops):
                lu, lv = coords[idx % 4]
                loop[uv_layer].uv = map_cell_uv(cell, lu, lv)


def add_cylinder_rbx(
    bm: bmesh.types.BMesh,
    uv_layer,
    center_rbx: tuple[float, float, float],
    radius: float,
    height: float,
    segments: int,
    cell: tuple[int, int],
    rot_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
    origin_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bulge: float = 0.0,
) -> None:
    """Create a vertical Roblox Y-cylinder (or slightly bulged barrel/peg) mapped onto cell UV."""
    ox, oy, oz = origin_rbx
    rx, ry, rz = center_rbx
    rot_mat = Euler(rot_rbx, "YXZ").to_matrix()

    rings_y = [-0.5 * height, 0.0, 0.5 * height] if bulge > 0.0 else [-0.5 * height, 0.5 * height]
    rings_r = [
        radius * (1.0 - bulge * 0.6),
        radius * (1.0 + bulge),
        radius * (1.0 - bulge * 0.6),
    ] if bulge > 0.0 else [radius, radius]

    ring_verts: list[list[bmesh.types.BMVert]] = []
    for y_off, rad in zip(rings_y, rings_r):
        ring = []
        for s in range(segments):
            ang = (2.0 * math.pi * s) / segments
            lp = Vector((math.cos(ang) * rad, y_off, math.sin(ang) * rad))
            wp = Vector((rx - ox, ry - oy, rz - oz)) + (rot_mat @ lp)
            ring.append(bm.verts.new(rbx_to_blender(wp.x, wp.y, wp.z)))
        ring_verts.append(ring)

    # Side quads
    n_rings = len(ring_verts)
    for r_idx in range(n_rings - 1):
        lv0 = r_idx / (n_rings - 1)
        lv1 = (r_idx + 1) / (n_rings - 1)
        for s in range(segments):
            sn = (s + 1) % segments
            f = bm.faces.new([
                ring_verts[r_idx][s],
                ring_verts[r_idx][sn],
                ring_verts[r_idx + 1][sn],
                ring_verts[r_idx + 1][s],
            ])
            u0 = s / segments
            u1 = (s + 1) / segments
            f.loops[0][uv_layer].uv = map_cell_uv(cell, u0, lv0)
            f.loops[1][uv_layer].uv = map_cell_uv(cell, u1, lv0)
            f.loops[2][uv_layer].uv = map_cell_uv(cell, u1, lv1)
            f.loops[3][uv_layer].uv = map_cell_uv(cell, u0, lv1)

    # Caps
    f_bot = bm.faces.new(list(reversed(ring_verts[0])))
    for s, loop in enumerate(f_bot.loops):
        ang = (2.0 * math.pi * s) / segments
        loop[uv_layer].uv = map_cell_uv(cell, 0.5 + 0.35 * math.cos(ang), 0.1 + 0.08 * math.sin(ang))

    f_top = bm.faces.new(ring_verts[-1])
    for s, loop in enumerate(f_top.loops):
        ang = (2.0 * math.pi * s) / segments
        loop[uv_layer].uv = map_cell_uv(cell, 0.5 + 0.35 * math.cos(ang), 0.5 + 0.18 * math.sin(ang))


def add_fruit_orb_rbx(
    bm: bmesh.types.BMesh,
    uv_layer,
    center_rbx: tuple[float, float, float],
    radius: float,
    color_kind: str,
    squash_y: float = 0.90,
    low_poly: bool = False,
) -> None:
    """Create a rounded orchard fruit (20-tri icosphere or 12-tri faceted gem orb) mapped to Produce UV cells."""
    rx, ry, rz = center_rbx
    if color_kind == "red":
        cell, u_min, u_max = (2, 3), 0.10, 0.40
    elif color_kind == "orange":
        cell, u_min, u_max = (2, 3), 0.60, 0.90
    elif color_kind == "yellow":
        cell, u_min, u_max = (3, 3), 0.10, 0.40
    else:  # green
        cell, u_min, u_max = (3, 3), 0.60, 0.90

    if low_poly:
        # 12-tri hexagonal bipyramid saves 8 tris/fruit on small counter piles while staying plump
        eq_verts = [
            bm.verts.new(rbx_to_blender(
                rx + math.cos(k * math.tau / 6.0) * radius,
                ry,
                rz + math.sin(k * math.tau / 6.0) * radius,
            ))
            for k in range(6)
        ]
        v_top = bm.verts.new(rbx_to_blender(rx, ry + radius * squash_y, rz))
        v_bot = bm.verts.new(rbx_to_blender(rx, ry - radius * squash_y, rz))
        faces = []
        for k in range(6):
            kn = (k + 1) % 6
            faces.append(bm.faces.new([eq_verts[k], eq_verts[kn], v_top]))
            faces.append(bm.faces.new([eq_verts[kn], eq_verts[k], v_bot]))
        for f in faces:
            for idx, loop in enumerate(f.loops):
                lu = u_min + (0.2 if idx == 0 else (0.8 if idx == 1 else 0.5)) * (u_max - u_min)
                lv = 0.25 + 0.5 * (idx / 2.0)
                loop[uv_layer].uv = map_cell_uv(cell, lu, lv)
        return

    res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)
    verts = res["verts"]
    for v in verts:
        v.co = rbx_to_blender(rx + v.co.x, ry + v.co.y * squash_y, rz + v.co.z)

    seen_faces = set()
    for v in verts:
        for f in v.link_faces:
            if f in seen_faces:
                continue
            seen_faces.add(f)
            for idx, loop in enumerate(f.loops):
                lu = u_min + (0.2 if idx == 0 else (0.8 if idx == 1 else 0.5)) * (u_max - u_min)
                lv = 0.25 + 0.5 * (idx / 2.0)
                loop[uv_layer].uv = map_cell_uv(cell, lu, lv)


def add_burlap_sack_rbx(
    bm: bmesh.types.BMesh,
    uv_layer,
    center_rbx: tuple[float, float, float],
    scale: float,
    yaw_deg: float,
    tilt_deg: float = 0.0,
) -> None:
    """Create a plump 8-sided burlap grain sack with pinched rope-tied neck & flared collar (48 tris)."""
    cell = (1, 2)  # Burlap with rope band at lv ~0.73
    profile = [
        (0.00 * scale, 0.48 * scale, 0.08),
        (0.32 * scale, 0.64 * scale, 0.34),
        (0.74 * scale, 0.56 * scale, 0.58),
        (1.02 * scale, 0.24 * scale, 0.73),  # Rope-pinched waist!
        (1.24 * scale, 0.38 * scale, 0.92),  # Flared top ruffle
    ]
    n_seg = 8
    rot = Euler((math.radians(tilt_deg), math.radians(yaw_deg), 0.0), "YXZ").to_matrix()
    base = Vector(center_rbx)

    rings = []
    for y_off, rad, _ in profile:
        ring = []
        for s in range(n_seg):
            a = (2.0 * math.pi * s) / n_seg
            wobble = 1.0 + 0.07 * math.sin(a * 3.0 + y_off * 2.0)
            lp = Vector((math.cos(a) * rad * wobble, y_off, math.sin(a) * rad * wobble * 0.92))
            wp = base + (rot @ lp)
            ring.append(bm.verts.new(rbx_to_blender(wp.x, wp.y, wp.z)))
        rings.append(ring)

    for r_i in range(len(rings) - 1):
        lv0, lv1 = profile[r_i][2], profile[r_i + 1][2]
        for s in range(n_seg):
            sn = (s + 1) % n_seg
            f = bm.faces.new([rings[r_i][s], rings[r_i][sn], rings[r_i + 1][sn], rings[r_i + 1][s]])
            f.loops[0][uv_layer].uv = map_cell_uv(cell, s / n_seg, lv0)
            f.loops[1][uv_layer].uv = map_cell_uv(cell, (s + 1) / n_seg, lv0)
            f.loops[2][uv_layer].uv = map_cell_uv(cell, (s + 1) / n_seg, lv1)
            f.loops[3][uv_layer].uv = map_cell_uv(cell, s / n_seg, lv1)

    # Bottom + pinched mouth recess
    f_bot = bm.faces.new(list(reversed(rings[0])))
    for s, loop in enumerate(f_bot.loops):
        loop[uv_layer].uv = map_cell_uv(cell, 0.2 + 0.6 * (s / n_seg), 0.15)
    f_top = bm.faces.new(rings[-1])
    for s, loop in enumerate(f_top.loops):
        loop[uv_layer].uv = map_cell_uv(cell, 0.2 + 0.6 * (s / n_seg), 0.92)


def finalize_mesh_obj(
    name: str,
    bm: bmesh.types.BMesh,
    mat: bpy.types.Material,
    col: bpy.types.Collection,
    split_angle_deg: float = 38.0,
    double_sided: bool = False,
    location_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> tuple[bpy.types.Object, int]:
    """Recalc normals, split sharp edges cleanly for crisp bevels, apply smooth shading, return (obj, tri_count)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    sharp_edges = [
        e for e in bm.edges
        if e.is_manifold and e.calc_face_angle(0.0) > math.radians(split_angle_deg)
    ]
    if sharp_edges:
        bmesh.ops.split_edges(bm, edges=sharp_edges)

    bmesh.ops.triangulate(bm, faces=bm.faces)
    tri_count = len(bm.faces)

    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.materials.append(mat)
    mesh.update()

    obj = bpy.data.objects.new(name, mesh)
    obj.location = rbx_to_blender(*location_rbx)
    if double_sided and hasattr(mesh, "use_auto_smooth"):
        pass
    col.objects.link(obj)
    return obj, tri_count


# ---------------------------------------------------------------------------
# Bazaar Geometry Layout Constants (Roblox Market-local space)
# ---------------------------------------------------------------------------
STALL_LEFT = {"cx": -10.8, "cz": -3.8, "yaw": 15.0}
STALL_CENTER = {"cx": 0.9, "cz": -7.6, "yaw": -2.0}
STALL_RIGHT = {"cx": 11.4, "cz": -1.6, "yaw": -26.0}

SIGN_PIVOT_RBX = (-16.98, 8.85, -0.02)
LANTERN_PIVOTS_RBX = [
    (-5.85, 7.25, -2.54),   # Lantern_Housing_1: Left stall inner-right front post (courtyard side)
    (0.81, 7.65, -5.05),    # Lantern_Housing_2: Center stall middle front pendant
    (6.53, 7.25, -1.31),    # Lantern_Housing_3: Right stall inner-left front post (courtyard side)
]

TRADER_SPOTS_RBX = [
    (-11.20, 0.06, -5.30),  # TraderSpot_1: Behind Left Red/Yellow counter
    (0.95, 0.06, -9.15),    # TraderSpot_2: Behind Center Tan Canopy counter
    (12.08, 0.06, -2.99),   # TraderSpot_3: Behind Right Green/White counter
]

# Counter collider descriptors exported to manifest for clean Walk-Over / Blocking in Luau
COUNTER_COLLIDERS = [
    {"name": "CounterCollider_Left",   "pos": [-10.50, 1.65, -2.69], "size": [9.8,  3.30, 2.25], "yaw_deg": 15.0},
    {"name": "CounterCollider_Center", "pos": [0.87,   1.65, -6.60], "size": [11.2, 3.30, 2.25], "yaw_deg": -2.0},
    {"name": "CounterCollider_Right",  "pos": [10.94,  1.65, -0.66], "size": [9.2,  3.30, 2.25], "yaw_deg": -26.0},
    {"name": "ClutterCollider_Left",   "pos": [-15.8,  1.35, -1.2],  "size": [3.6,  2.7,  5.6],  "yaw_deg": 15.0},
    {"name": "ClutterCollider_Right",  "pos": [13.5,   1.35, 3.0],   "size": [4.6,  2.7,  4.4],  "yaw_deg": -26.0},
]


# ---------------------------------------------------------------------------
# Sub-Mesh Builders
# ---------------------------------------------------------------------------
def _clip_poly_halfplane(
    poly: list[tuple[float, float]],
    nx: float,
    nz: float,
    d: float,
) -> list[tuple[float, float]]:
    """Sutherland-Hodgman clip of 2D convex poly against nx*x + nz*z <= d."""
    if not poly:
        return []
    out: list[tuple[float, float]] = []
    n = len(poly)
    for i in range(n):
        ax, az = poly[i]
        bx, bz = poly[(i + 1) % n]
        da = nx * ax + nz * az - d
        db = nx * bx + nz * bz - d
        if da <= 0.0:
            out.append((ax, az))
            if db > 0.0:
                t = da / (da - db)
                out.append((ax + t * (bx - ax), az + t * (bz - az)))
        elif db <= 0.0:
            t = da / (da - db)
            out.append((ax + t * (bx - ax), az + t * (bz - az)))
    return out


def _simplify_poly(poly: list[tuple[float, float]], min_edge: float = 0.28, max_verts: int = 6) -> list[tuple[float, float]]:
    """Collapse short edges and cap polygon vertices to max_verts for crisp low-poly flagstones."""
    pts = list(poly)
    i = 0
    while len(pts) > 3 and i < len(pts):
        ax, az = pts[i]
        bx, bz = pts[(i + 1) % len(pts)]
        if math.hypot(bx - ax, bz - az) < min_edge:
            pts[(i + 1) % len(pts)] = ((ax + bx) * 0.5, (az + bz) * 0.5)
            pts.pop(i)
        else:
            i += 1
    while len(pts) > max_verts:
        # Remove vertex forming the shortest triangle deviation / shortest adjacent edge
        best_i = 0
        best_len = 1e9
        for k in range(len(pts)):
            ax, az = pts[k]
            bx, bz = pts[(k + 1) % len(pts)]
            l = math.hypot(bx - ax, bz - az)
            if l < best_len:
                best_len = l
                best_i = k
        pts.pop(best_i)
    return pts


def build_flagstone_path(mat_ground: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int, list[tuple[float, float]]]:
    """
    Build `Bazaar_FlagstonePath`:
    True tightly tessellated Voronoi cobblestone mosaic in the bazaar center (~56 interlocking polygonal stones
    with crisp 0.14-stud grout seams) transitioning to ~14 organic loose stepping stones around the perimeter
    and into `Path_Market_Slab_4`. NO blocky slab and NO mud rectangle.
    """
    rng = random.Random(4207)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    # 1) Priority bridge/stepping stones right at Path_Market mouth (Z_local ~ 7.0..12.2, X_local ~ -4.6..+4.0),
    # trader pads behind all 3 enlarged stalls & flanked perimeter
    sites: list[tuple[float, float, bool]] = []  # (x, z, is_core)
    for wx, _, wz in [
        *TRADER_SPOTS_RBX,
        (-1.25, 0.06, -9.23),
        (3.95, 0.06, -9.04),
        # Continuous cobblestone bridge meeting & wrapping Path_Market_Slab_5 front edge at (X=-0.39, Z=11.62)
        (-4.0, 0.08, 11.4), (-2.1, 0.08, 11.7), (-0.2, 0.08, 11.8), (1.8, 0.08, 11.6), (3.6, 0.08, 11.3),
        (-3.8, 0.08, 9.4),  (-1.8, 0.08, 9.7),  (0.3, 0.08, 9.6),  (2.4, 0.08, 9.4),  (4.2, 0.07, 9.1),
        (-3.5, 0.08, 7.2),  (-1.4, 0.08, 7.5),  (0.8, 0.08, 7.4),  (3.0, 0.08, 7.2),
        (-5.6, 0.07, 10.2), (5.0, 0.07, 10.0),
        (6.4, 0.06, 6.2),   (9.2, 0.06, 6.0),   (12.8, 0.06, 5.1),
    ]:
        sites.append((wx, wz, abs(wx + 0.3) < 4.7 and wz <= 12.1))

    # 2) Generate jittered hex-grid seeds over enlarged courtyard horseshoe & funnel,
    # sorted center/funnel-outward so stone cap NEVER starves the central plaza bridge!
    spacing = 2.68
    row_dy = spacing * 0.866
    cand_sites: list[tuple[float, float, float, bool]] = []
    for r_i, gz in enumerate([z * row_dy - 9.8 for z in range(10)]):
        x_shift = (r_i % 2) * (spacing * 0.5)
        for c_i, gx_base in enumerate([x * spacing - 16.5 for x in range(14)]):
            px = gx_base + x_shift + rng.uniform(-0.48, 0.48)
            pz = gz + rng.uniform(-0.48, 0.48)
            if any(math.hypot(px - sx, pz - sz) < 1.48 for sx, sz, _ in sites):
                continue
            d_core = math.hypot(px / 13.8, (pz - 0.8) / 7.8)
            d_funnel = math.hypot((px + 0.35) / 5.4, (pz - 7.8) / 4.8)
            d_left = math.hypot((px + 13.4) / 4.2, (pz + 0.6) / 4.6)
            d_right = math.hypot((px - 12.6) / 4.8, (pz - 1.2) / 5.0)
            d_trader = math.hypot((px - 0.5) / 12.6, (pz + 7.2) / 4.0)
            d = min(d_core, d_funnel, d_left, d_right, d_trader)
            if d <= 1.00:
                cand_sites.append((d, px, pz, d < 0.82))
            elif d <= 1.22 and rng.random() < 0.42:
                cand_sites.append((d, px, pz, False))
    cand_sites.sort(key=lambda item: item[0])
    for _, px, pz, is_core in cand_sites:
        sites.append((px, pz, is_core))

    grass_anchors: list[tuple[float, float]] = []
    stone_cells = [(0, 0), (1, 0), (2, 0), (3, 0), (0, 1)]
    stone_idx = 0

    for i, (sx, sz, is_core) in enumerate(sites):
        if stone_idx >= 88:
            break
        # Start with regular octagon bounded around (sx, sz)
        max_rad = 2.08 if is_core else rng.uniform(1.18, 1.65)
        poly = [
            (sx + math.cos(k * math.tau / 8.0) * max_rad, sz + math.sin(k * math.tau / 8.0) * max_rad)
            for k in range(8)
        ]
        # Half-plane clip against every neighboring Voronoi seed with tight crack gap
        gap = rng.uniform(0.11, 0.18) if is_core else rng.uniform(0.24, 0.48)
        for j, (ox, oz, _) in enumerate(sites):
            if i == j:
                continue
            dx, dz = ox - sx, oz - sz
            dist = math.hypot(dx, dz)
            if dist < 1e-4 or dist > 5.4:
                continue
            nx, nz = dx / dist, dz / dist
            half_dist = 0.5 * dist - gap * 0.5
            d_val = nx * sx + nz * sz + half_dist
            poly = _clip_poly_halfplane(poly, nx, nz, d_val)
            if len(poly) < 3:
                break

        poly = _simplify_poly(poly, min_edge=0.34, max_verts=5)
        if len(poly) < 3:
            continue

        # Reject sliver triangles (tiny area)
        area = 0.5 * abs(sum(
            poly[k][0] * poly[(k + 1) % len(poly)][1] - poly[(k + 1) % len(poly)][0] * poly[k][1]
            for k in range(len(poly))
        ))
        if area < 0.55:
            continue

        stone_idx += 1
        cx = sum(p[0] for p in poly) / len(poly)
        cz = sum(p[1] for p in poly) / len(poly)
        # Ensure Path_Market threshold stones (cz >= 7.0) cleanly sit 0.008..0.028 studs above Path_Market top (Y=0.06)
        top_y = rng.uniform(0.068, 0.088) if (cz >= 6.8 or is_core) else rng.uniform(0.056, 0.074)
        bot_y = -0.025
        bevel = 0.89

        v_bot = [bm.verts.new(rbx_to_blender(px, bot_y, pz)) for (px, pz) in poly]
        v_top = [bm.verts.new(rbx_to_blender(cx + (px - cx) * bevel, top_y, cz + (pz - cz) * bevel)) for (px, pz) in poly]

        cell = stone_cells[4] if (not is_core and stone_idx % 2 == 0) else stone_cells[stone_idx % 4]
        f_top = bm.faces.new(v_top)
        for k, loop in enumerate(f_top.loops):
            ang = (k / len(poly)) * math.tau
            loop[uv].uv = map_cell_uv(cell, 0.5 + 0.40 * math.cos(ang), 0.5 + 0.40 * math.sin(ang))

        for k in range(len(poly)):
            kn = (k + 1) % len(poly)
            f_side = bm.faces.new([v_bot[k], v_bot[kn], v_top[kn], v_top[k]])
            f_side.loops[0][uv].uv = map_cell_uv(cell, 0.1, 0.08)
            f_side.loops[1][uv].uv = map_cell_uv(cell, 0.9, 0.08)
            f_side.loops[2][uv].uv = map_cell_uv(cell, 0.9, 0.28)
            f_side.loops[3][uv].uv = map_cell_uv(cell, 0.1, 0.28)

        # Collect crack & edge sites for lush grass tufts
        if (not is_core or stone_idx % 4 == 0) and (cz > -3.5 or abs(cx) > 12.0):
            edge_pt = poly[stone_idx % len(poly)]
            gx = edge_pt[0] + rng.uniform(-0.18, 0.18)
            gz = edge_pt[1] + rng.uniform(-0.18, 0.18)
            grass_anchors.append((gx, gz))

    obj, tri_count = finalize_mesh_obj("Bazaar_FlagstonePath", bm, mat_ground, col, split_angle_deg=35.0)
    return obj, tri_count, grass_anchors


def build_grass_tufts(
    anchors: list[tuple[float, float]],
    mat_ground: bpy.types.Material,
    col: bpy.types.Collection,
) -> tuple[bpy.types.Object, int]:
    """Build `Bazaar_GrassTufts`: lush 5-blade flared grass clumps sprouting through flagstone joints & perimeter."""
    rng = random.Random(8812)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    cell = (1, 1)

    tuft_pts = [
        (-14.2, 2.2), (-15.8, 0.6), (-11.6, 3.8), (-6.8, 3.6), (-3.8, 0.2),
        (-1.4, 3.0), (0.8, 5.4), (4.2, 3.4), (5.8, 0.5), (7.6, 4.8),
        (10.5, 6.4), (13.4, 5.4), (14.6, 2.2), (6.0, 7.6),
        (-5.6, 8.2), (4.6, 8.8), (-8.2, 5.2), (0.2, -0.6),
    ]
    for pt in anchors:
        if len(tuft_pts) >= 26:
            break
        if all(math.hypot(pt[0] - qx, pt[1] - qz) > 1.65 for qx, qz in tuft_pts):
            tuft_pts.append(pt)

    for tx, tz in tuft_pts[:26]:
        base_h = rng.uniform(0.70, 1.15)
        n_blades = 5
        yaw0 = rng.uniform(0.0, math.tau)
        for b in range(n_blades):
            ang = yaw0 + (b / n_blades) * math.tau + rng.uniform(-0.22, 0.22)
            ca, sa = math.cos(ang), math.sin(ang)
            nx, nz = -sa, ca
            w_half = rng.uniform(0.11, 0.16)
            lean = rng.uniform(0.24, 0.42)
            bh = base_h * rng.uniform(0.72, 1.20)

            v_l = bm.verts.new(rbx_to_blender(tx - nx * w_half, -0.02, tz - nz * w_half))
            v_r = bm.verts.new(rbx_to_blender(tx + nx * w_half, -0.02, tz + nz * w_half))
            v_tip = bm.verts.new(rbx_to_blender(tx + ca * lean, bh, tz + sa * lean))
            f_a = bm.faces.new([v_l, v_r, v_tip])
            f_a.loops[0][uv].uv = map_cell_uv(cell, 0.2, 0.05)
            f_a.loops[1][uv].uv = map_cell_uv(cell, 0.8, 0.05)
            f_a.loops[2][uv].uv = map_cell_uv(cell, 0.5, 0.96)

            v_l2 = bm.verts.new(rbx_to_blender(tx - nx * w_half, -0.02, tz - nz * w_half))
            v_r2 = bm.verts.new(rbx_to_blender(tx + nx * w_half, -0.02, tz + nz * w_half))
            v_tip2 = bm.verts.new(rbx_to_blender(tx + ca * lean, bh, tz + sa * lean))
            f_b = bm.faces.new([v_r2, v_l2, v_tip2])
            f_b.loops[0][uv].uv = map_cell_uv(cell, 0.8, 0.05)
            f_b.loops[1][uv].uv = map_cell_uv(cell, 0.2, 0.05)
            f_b.loops[2][uv].uv = map_cell_uv(cell, 0.5, 0.96)

    return finalize_mesh_obj("Bazaar_GrassTufts", bm, mat_ground, col, split_angle_deg=15.0)


def build_stall_timber_frame(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """Build `Stall_TimberFrame`: corner posts, sloped roof rafters, beam pegs, braces, extended sign arm & iron hooks."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    timber = (0, 0)
    iron = (0, 3)

    def add_stall_post(stall: dict, sx: float, sz: float, height: float, thick: float = 0.50):
        px, py, pz = stall_to_rbx(stall["cx"], stall["cz"], stall["yaw"], sx, height * 0.5, sz)
        add_box_rbx(bm, uv, (px, py, pz), (thick, height, thick), timber, (0.0, math.radians(stall["yaw"]), 0.0))

    def add_stall_beam(stall: dict, sx: float, sy: float, sz: float, size: tuple[float, float, float], pitch_deg: float = 0.0, roll_deg: float = 0.0, cell_override=None):
        px, py, pz = stall_to_rbx(stall["cx"], stall["cz"], stall["yaw"], sx, sy, sz)
        rot_local = Euler((math.radians(pitch_deg), 0.0, math.radians(roll_deg)), "YXZ").to_matrix()
        rot_world = Euler((0.0, math.radians(stall["yaw"]), 0.0), "YXZ").to_matrix() @ rot_local
        eu = rot_world.to_euler("YXZ")
        add_box_rbx(bm, uv, (px, py, pz), size, cell_override or timber, (eu.x, eu.y, eu.z))

    # 1) LEFT STALL FRAME (Red & Yellow)
    sl = STALL_LEFT
    for sx in (-5.00, 5.00):
        add_stall_post(sl, sx, 2.15, 8.20, 0.54)   # Front posts
        add_stall_post(sl, sx, -2.95, 10.55, 0.54) # Rear posts
        # Sloped side rafters strictly underneath roof (pitch +24.7 deg slopes down along +Z)
        add_stall_beam(sl, sx, 9.25, -0.40, (0.42, 0.42, 5.65), pitch_deg=24.7)
        # Diagonal knee braces on outer posts
        add_stall_beam(sl, sx + (-0.65 if sx > 0 else 0.65), 7.38, 2.15, (0.32, 1.48, 0.32), roll_deg=(40.0 if sx > 0 else -40.0))
    # Front and rear longitudinal headers
    add_stall_beam(sl, 0.0, 8.05, 2.15, (10.55, 0.46, 0.48))
    add_stall_beam(sl, 0.0, 10.40, -2.95, (10.55, 0.46, 0.48))
    # Protruding circular wooden peg heads under the front awning valance
    for px_s in (-3.6, -1.2, 1.2, 3.6):
        add_stall_beam(sl, px_s, 8.05, 2.66, (0.30, 0.30, 0.42))

    # Extended Signboard Arm off Left Stall's outer-left front post (matching SIGN_PIVOT_RBX)
    add_stall_beam(sl, -6.00, 8.90, 2.05, (2.85, 0.38, 0.38))
    add_stall_beam(sl, -5.65, 8.20, 2.05, (0.30, 1.55, 0.30), roll_deg=48.0)

    # 2) CENTER CORNER STALL FRAME (Taller Tan Draped Canopy, beams tucked strictly beneath cloth!)
    sc = STALL_CENTER
    for sx in (-5.80, 5.80):
        add_stall_post(sc, sx, 2.10, 8.70, 0.56)   # Outer corner Front posts (keeps middle counter 100% open!)
        add_stall_post(sc, sx, -3.35, 11.15, 0.56) # 2 tall Rear posts
        add_stall_beam(sc, sx, 9.75, -0.62, (0.42, 0.42, 5.95), pitch_deg=22.5)
    # Short upper pendant drop supporting central dual-bay seam & Lantern_Housing_2 (never touches counter!)
    add_stall_beam(sc, 0.0, 8.20, 2.10, (0.40, 1.25, 0.40))
    add_stall_beam(sc, 0.0, 9.75, -0.62, (0.38, 0.40, 5.95), pitch_deg=22.5)  # Central ridge rafter under cloth
    add_stall_beam(sc, 0.0, 8.70, 2.10, (12.20, 0.46, 0.48))                   # Front header
    add_stall_beam(sc, 0.0, 10.95, -3.35, (12.20, 0.46, 0.48))                 # Ridge beam cleanly below canopy back!
    for px_s in (-4.0, -1.5, 1.5, 4.0):
        add_stall_beam(sc, px_s, 8.70, 2.60, (0.30, 0.30, 0.42))

    # 3) RIGHT STALL FRAME (Green & White)
    sr = STALL_RIGHT
    for sx in (-4.75, 4.75):
        add_stall_post(sr, sx, 2.05, 8.15, 0.54)
        add_stall_post(sr, sx, -2.80, 10.45, 0.54)
        add_stall_beam(sr, sx, 9.20, -0.38, (0.42, 0.42, 5.45), pitch_deg=25.0)
        add_stall_beam(sr, sx + (-0.62 if sx > 0 else 0.62), 7.35, 2.05, (0.32, 1.44, 0.32), roll_deg=(40.0 if sx > 0 else -40.0))
    add_stall_beam(sr, 0.0, 8.00, 2.05, (10.05, 0.46, 0.48))
    add_stall_beam(sr, 0.0, 10.35, -2.80, (10.05, 0.46, 0.48))
    for px_s in (-3.2, -1.0, 1.0, 3.2):
        add_stall_beam(sr, px_s, 8.00, 2.56, (0.30, 0.30, 0.42))

    # 4) WROUGHT IRON LANTERN HOOK BRACKETS at exact lantern pivot positions
    for idx, (lx, ly, lz) in enumerate(LANTERN_PIVOTS_RBX):
        arm_z = 0.25 if idx == 0 else (-0.25 if idx == 1 else 0.25)
        add_box_rbx(bm, uv, (lx, ly + 0.16, lz - arm_z * 0.5), (0.14, 0.14, 0.56), iron)
        add_box_rbx(bm, uv, (lx, ly + 0.04, lz), (0.10, 0.22, 0.10), iron)

    return finalize_mesh_obj("Stall_TimberFrame", bm, mat_props, col, split_angle_deg=35.0)


def build_stall_counters(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """Build `Stall_Counters`: 3 bevelled counters (3.28 studs tall), recessed bin trays & wooden trader stool."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    timber = (0, 0)
    oak = (1, 0)

    def add_counter(stall: dict, width: float, depth: float, sz_offset: float):
        yaw = math.radians(stall["yaw"])
        # Base skirt plinth (ry=0.0..0.34)
        px, py, pz = stall_to_rbx(stall["cx"], stall["cz"], stall["yaw"], 0.0, 0.17, sz_offset)
        add_box_rbx(bm, uv, (px, py, pz), (width + 0.16, 0.34, depth + 0.16), timber, (0.0, yaw, 0.0))

        # Main oak body cabinet (ry=0.34..2.94)
        px, py, pz = stall_to_rbx(stall["cx"], stall["cz"], stall["yaw"], 0.0, 1.64, sz_offset)
        add_box_rbx(bm, uv, (px, py, pz), (width - 0.10, 2.60, depth - 0.10), oak, (0.0, yaw, 0.0))

        # Decorative dark timber vertical pilasters along counter front
        n_pil = 4
        for i in range(n_pil):
            px_s = -width * 0.46 + (i / (n_pil - 1)) * (width * 0.92)
            px, py, pz = stall_to_rbx(stall["cx"], stall["cz"], stall["yaw"], px_s, 1.64, sz_offset + depth * 0.48)
            add_box_rbx(bm, uv, (px, py, pz), (0.34, 2.62, 0.14), timber, (0.0, yaw, 0.0))

        # Overhanging bevelled countertop plank (ry=2.94..3.26)
        px, py, pz = stall_to_rbx(stall["cx"], stall["cz"], stall["yaw"], 0.0, 3.10, sz_offset + 0.06)
        add_box_rbx(bm, uv, (px, py, pz), (width + 0.48, 0.32, depth + 0.50), oak, (0.0, yaw, 0.0))

        # 3 Produce display bin trays (2 long shared longitudinal rails + 4 cross-dividers)
        bin_w = (width - 1.4) / 3.0
        bin_d = depth - 0.16
        total_bins_span = 3.0 * bin_w + 0.52
        for dz in (bin_d * 0.45, -bin_d * 0.45):
            px, py, pz = stall_to_rbx(stall["cx"], stall["cz"], stall["yaw"], 0.0, 3.37, sz_offset + 0.06 + dz)
            add_box_rbx(bm, uv, (px, py, pz), (total_bins_span, 0.22, 0.14), timber, (0.0, yaw, 0.0))
        for d_idx in range(4):
            dx_s = -total_bins_span * 0.5 + 0.07 + d_idx * ((total_bins_span - 0.14) / 3.0)
            px, py, pz = stall_to_rbx(stall["cx"], stall["cz"], stall["yaw"], dx_s, 3.37, sz_offset + 0.06)
            add_box_rbx(bm, uv, (px, py, pz), (0.14, 0.22, bin_d), timber, (0.0, yaw, 0.0))

    add_counter(STALL_LEFT,   width=9.4,  depth=1.80, sz_offset=1.15)
    add_counter(STALL_CENTER, width=10.8, depth=1.85, sz_offset=1.00)
    add_counter(STALL_RIGHT,  width=8.8,  depth=1.80, sz_offset=1.05)

    # Small round wooden trader stool behind Right Stall counter (near right-back end)
    sx_s, sz_s = 3.10, -1.25
    sp_x, _, sp_z = stall_to_rbx(STALL_RIGHT["cx"], STALL_RIGHT["cz"], STALL_RIGHT["yaw"], sx_s, 0.0, sz_s)
    add_cylinder_rbx(bm, uv, (sp_x, 1.38, sp_z), 0.78, 0.24, 8, oak)
    add_cylinder_rbx(bm, uv, (sp_x, 0.65, sp_z), 0.26, 1.30, 6, timber)

    return finalize_mesh_obj("Stall_Counters", bm, mat_props, col, split_angle_deg=35.0)


def build_striped_awning(
    name: str,
    stall: dict,
    width: float,
    cell_a: tuple[int, int],
    cell_b: tuple[int, int],
    mat_props: bpy.types.Material,
    col: bpy.types.Collection,
) -> tuple[bpy.types.Object, int]:
    """Build 5-stripe sloped awning with subtle roof curve, overhang valance & solid thickness."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    n_stripes = 5
    stripe_w = width / n_stripes

    # Roof profile points along stall local Z (z_s, ry_top): strictly above rafters + headers
    prof = [
        (-3.45, 11.05),
        (-0.40, 9.75),
        (2.75, 8.38),
        (2.85, 7.65),  # Crisp front hanging valance lip
    ]
    thick = 0.14

    for s_idx in range(n_stripes):
        cell = cell_a if (s_idx % 2 == 0) else cell_b
        x0 = -width * 0.5 + s_idx * stripe_w
        x1 = x0 + stripe_w

        # Upper + under strip ring vertices for manifold solid roof planks (zero backface invisible holes!)
        top_l, top_r, bot_l, bot_r = [], [], [], []
        for p_idx, (sz, sy) in enumerate(prof):
            ny = sy - thick if p_idx < 3 else sy
            nz = sz - (thick if p_idx == 3 else 0.0)
            top_l.append(bm.verts.new(stall_to_blender(stall["cx"], stall["cz"], stall["yaw"], x0, sy, sz)))
            top_r.append(bm.verts.new(stall_to_blender(stall["cx"], stall["cz"], stall["yaw"], x1, sy, sz)))
            bot_l.append(bm.verts.new(stall_to_blender(stall["cx"], stall["cz"], stall["yaw"], x0, ny, nz)))
            bot_r.append(bm.verts.new(stall_to_blender(stall["cx"], stall["cz"], stall["yaw"], x1, ny, nz)))

        for k in range(len(prof) - 1):
            ft = bm.faces.new([top_l[k], top_r[k], top_r[k + 1], top_l[k + 1]])
            fb = bm.faces.new([bot_r[k], bot_l[k], bot_l[k + 1], bot_r[k + 1]])
            for f in (ft, fb):
                for idx, loop in enumerate(f.loops):
                    u_c, v_c = ((0.15, 0.15), (0.85, 0.15), (0.85, 0.85), (0.15, 0.85))[idx]
                    loop[uv].uv = map_cell_uv(cell, u_c, v_c)

        # Close outer edges + rear/front ends on extreme stripes or valance tip
        f_end = bm.faces.new([top_l[-1], top_r[-1], bot_r[-1], bot_l[-1]])
        f_back = bm.faces.new([bot_l[0], bot_r[0], top_r[0], top_l[0]])
        for f in (f_end, f_back):
            for loop in f.loops:
                loop[uv].uv = map_cell_uv(cell, 0.5, 0.5)

        if s_idx == 0:
            for k in range(len(prof) - 1):
                fl = bm.faces.new([top_l[k], top_l[k + 1], bot_l[k + 1], bot_l[k]])
                for loop in fl.loops:
                    loop[uv].uv = map_cell_uv(cell, 0.5, 0.5)
        if s_idx == n_stripes - 1:
            for k in range(len(prof) - 1):
                fr = bm.faces.new([top_r[k + 1], top_r[k], bot_r[k], bot_r[k + 1]])
                for loop in fr.loops:
                    loop[uv].uv = map_cell_uv(cell, 0.5, 0.5)

    return finalize_mesh_obj(name, bm, mat_props, col, split_angle_deg=35.0)


def build_center_tan_canopy(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """
    Build `Awning_Center_Tan`:
    Smooth draped two-bay sagging warm tan (#D9B382) corner fabric canopy with creases,
    thickened rim so underside renders properly, and folded eave overhang.
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    cell = (0, 2)
    sc = STALL_CENTER

    nx, nz = 11, 5
    width = 13.0
    z_back, z_front = -3.85, 2.85
    thick = 0.14

    top_grid = []
    bot_grid = []

    for j in range(nz):
        tv = j / (nz - 1)  # 0 at ridge back, 1 at hanging front eave
        sz = z_back + tv * (z_front - z_back)
        if tv > 0.85:
            # Front draped overhang folds downward cleanly
            base_y = 9.35 - (tv - 0.85) * 5.2
            sz = z_front - (tv - 0.85) * 0.22
            slope_t = 1.0
        else:
            slope_t = tv / 0.85
            base_y = 11.78 * (1.0 - slope_t) + 9.35 * slope_t

        row_t, row_b = [], []
        for i in range(nx):
            tu = i / (nx - 1)  # 0..1 across width
            sx = -width * 0.5 + tu * width
            # Dual catenary bay sag anchored cleanly above the 3 rafters/ridge (zero beam poke-through!)
            bay_phase = (tu * 2.0) % 1.0
            sag = math.sin(bay_phase * math.pi) * (0.30 * math.sin(slope_t * math.pi))
            ripple = 0.04 * math.sin(tu * math.pi * 6.0 + tv * 2.4) * math.sin(slope_t * math.pi)
            sy = base_y - sag + ripple

            row_t.append(bm.verts.new(stall_to_blender(sc["cx"], sc["cz"], sc["yaw"], sx, sy, sz)))
            row_b.append(bm.verts.new(stall_to_blender(sc["cx"], sc["cz"], sc["yaw"], sx, sy - thick, sz)))
        top_grid.append(row_t)
        bot_grid.append(row_b)

    for j in range(nz - 1):
        for i in range(nx - 1):
            tu0, tu1 = i / (nx - 1), (i + 1) / (nx - 1)
            tv0, tv1 = j / (nz - 1), (j + 1) / (nz - 1)
            ft = bm.faces.new([top_grid[j][i], top_grid[j][i + 1], top_grid[j + 1][i + 1], top_grid[j + 1][i]])
            fb = bm.faces.new([bot_grid[j][i + 1], bot_grid[j][i], bot_grid[j + 1][i], bot_grid[j + 1][i + 1]])
            for f in (ft, fb):
                f.loops[0][uv].uv = map_cell_uv(cell, tu0, tv0)
                f.loops[1][uv].uv = map_cell_uv(cell, tu1, tv0)
                f.loops[2][uv].uv = map_cell_uv(cell, tu1, tv1)
                f.loops[3][uv].uv = map_cell_uv(cell, tu0, tv1)

    # Cap front, back, left, right canopy thickness seams cleanly
    for i in range(nx - 1):
        bm.faces.new([bot_grid[0][i], bot_grid[0][i + 1], top_grid[0][i + 1], top_grid[0][i]])
        bm.faces.new([top_grid[-1][i], top_grid[-1][i + 1], bot_grid[-1][i + 1], bot_grid[-1][i]])
    for j in range(nz - 1):
        bm.faces.new([top_grid[j][0], top_grid[j + 1][0], bot_grid[j + 1][0], bot_grid[j][0]])
        bm.faces.new([top_grid[j + 1][-1], top_grid[j][-1], bot_grid[j][-1], bot_grid[j + 1][-1]])
    for f in bm.faces:
        if f.loops[0][uv].uv.length < 1e-6:
            for loop in f.loops:
                loop[uv].uv = map_cell_uv(cell, 0.5, 0.5)

    return finalize_mesh_obj("Awning_Center_Tan", bm, mat_props, col, split_angle_deg=55.0)


def build_hanging_sign(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """Build `Sign_HangingBoard` pivoted at top iron hinge rings (SIGN_PIVOT_RBX)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    timber = (0, 0)
    iron = (0, 3)
    cream = (3, 2)

    # Vertices built relative to SIGN_PIVOT_RBX (= local origin 0,0,0 -> top iron hinge ring!)
    rot_yaw = math.radians(STALL_LEFT["yaw"])

    # Two hanging iron chains/rings from ry=0 down to -0.55
    for cx_s in (-0.82, 0.82):
        add_box_rbx(bm, uv, (cx_s, -0.28, 0.0), (0.10, 0.56, 0.10), iron, (0.0, rot_yaw, 0.0))

    # Top crossbar + bevelled timber signboard body (ry=-0.55 down to -2.45)
    add_box_rbx(bm, uv, (0.0, -0.60, 0.0), (2.55, 0.24, 0.28), timber, (0.0, rot_yaw, 0.0))
    add_box_rbx(bm, uv, (0.0, -1.55, 0.0), (2.30, 1.85, 0.20), timber, (0.0, rot_yaw, 0.0))

    # Double-sided cream painted placard inset
    add_box_rbx(bm, uv, (0.0, -1.55, 0.0), (1.76, 1.32, 0.26), cream, (0.0, rot_yaw, 0.0))

    return finalize_mesh_obj(
        "Sign_HangingBoard",
        bm,
        mat_props,
        col,
        split_angle_deg=35.0,
        location_rbx=SIGN_PIVOT_RBX,
    )


def build_lantern(idx: int, pivot_rbx: tuple[float, float, float], mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """Build `Lantern_Housing_N` pivoted at its top hook ring (0,0,0 relative to pivot_rbx)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    iron = (0, 3)
    amber = (1, 3)

    # Top iron bail & pyramid roof cap (ry = 0..-0.40)
    add_box_rbx(bm, uv, (0.0, -0.11, 0.0), (0.08, 0.22, 0.08), iron)
    add_cylinder_rbx(bm, uv, (0.0, -0.31, 0.0), 0.34, 0.20, 4, iron, rot_rbx=(0.0, math.radians(45), 0.0))
    # Warm amber lantern chamber core + dark wrought iron base collar
    add_box_rbx(bm, uv, (0.0, -0.68, 0.0), (0.40, 0.54, 0.40), amber)
    add_box_rbx(bm, uv, (0.0, -1.00, 0.0), (0.46, 0.14, 0.46), iron)

    return finalize_mesh_obj(
        f"Lantern_Housing_{idx}",
        bm,
        mat_props,
        col,
        split_angle_deg=35.0,
        location_rbx=pivot_rbx,
    )


def build_props_clutter(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """
    Build `Bazaar_Props_Clutter`:
    - 7 oak barrels with UV-mapped dark iron hoops
    - Tied burlap sacks with pinched rope-bound necks
    - Panelled wooden crates + 2 slanted open fruit display crates + folded grain bags
    - Vibrant red, orange, yellow, green faceted fruits in all 9 counter bins & slanted display crates
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    crate_cell = (2, 0)
    barrel_cell = (3, 0)
    bag_cell = (2, 2)

    # 1) BARRELS (44 tris each -> 7 * 44 = 308 tris)
    barrels = [
        # Left flank 3 barrels beside Left Stall crate/sacks (clear of outer front post at -15.07, -0.43)
        (-16.9, 1.22, -2.9),
        (-16.0, 1.22, -4.6),
        (-17.4, 1.22, -1.1),
        # Center rear barrel tucked right of center counter back
        (6.0,   1.22, -9.8),
        # Right flank 3 clustered barrels matching enlarged Green/White stall
        (14.0,  1.22, 3.2),
        (15.2,  1.22, 1.7),
        (13.5,  1.22, 1.3),
    ]
    for bx, by, bz in barrels:
        add_cylinder_rbx(bm, uv, (bx, by, bz), 0.95, 2.45, 8, barrel_cell, bulge=0.12)

    # 2) WOODEN CRATES + FOLDED GRAIN BAGS
    # Left crate holding 2 cream grain sacks (clear of front-left post)
    add_box_rbx(bm, uv, (-16.1, 0.92, 0.9),  (2.50, 1.84, 2.05), crate_cell, (0.0, math.radians(15), 0.0))
    add_box_rbx(bm, uv, (-16.2, 2.08, 0.65), (1.50, 0.48, 1.20), bag_cell,   (0.0, math.radians(24), 0.0))
    add_box_rbx(bm, uv, (-15.8, 2.02, 1.20), (1.40, 0.40, 1.00), bag_cell,   (0.0, math.radians(-8), 0.0))

    # Center-front closed crate right of Tan counter
    add_box_rbx(bm, uv, (5.2, 0.88, -4.3), (2.25, 1.76, 1.65), crate_cell, (0.0, math.radians(-12), 0.0))

    # Right-front closed crate beside barrel cluster
    add_box_rbx(bm, uv, (11.7, 0.88, 3.8), (2.45, 1.76, 1.85), crate_cell, (0.0, math.radians(-26), 0.0))

    # 3) TIED BURLAP GRAIN SACKS (4 plump sacks: 3 clustered left flank, 1 front-left of Center counter)
    add_burlap_sack_rbx(bm, uv, (-13.8, 0.0, 1.6), scale=1.28, yaw_deg=15.0, tilt_deg=4.0)
    add_burlap_sack_rbx(bm, uv, (-15.0, 0.0, 2.6), scale=0.95, yaw_deg=-25.0, tilt_deg=-6.0)
    add_burlap_sack_rbx(bm, uv, (-13.3, 0.0, 2.7), scale=0.90, yaw_deg=45.0, tilt_deg=7.0)
    add_burlap_sack_rbx(bm, uv, (-3.1, 0.0, -4.2), scale=1.32, yaw_deg=18.0, tilt_deg=3.0)

    # 4) TWO SLANTED OPEN FRUIT DISPLAY CRATES in front of Right Stall (facing plaza at yaw -26 deg)
    oc1_x, _, oc1_z = stall_to_rbx(STALL_RIGHT["cx"], STALL_RIGHT["cz"], STALL_RIGHT["yaw"], -2.5, 0.0, 2.75)
    oc2_x, _, oc2_z = stall_to_rbx(STALL_RIGHT["cx"], STALL_RIGHT["cz"], STALL_RIGHT["yaw"], -0.2, 0.0, 2.95)
    open_crates = [
        (oc1_x, 0.98, oc1_z, -26.0, ["red", "yellow", "orange", "green"]),
        (oc2_x, 0.98, oc2_z, -24.0, ["orange", "green", "red", "yellow"]),
    ]
    for ox, oy, oz, cyaw, kinds in open_crates:
        # Slanted wooden crate tray + kickstand block underneath
        add_box_rbx(bm, uv, (ox, oy - 0.56, oz), (1.50, 0.92, 1.25), crate_cell, (0.0, math.radians(cyaw), 0.0))
        add_box_rbx(bm, uv, (ox, oy + 0.14, oz), (1.88, 0.56, 1.68), crate_cell, (math.radians(-26), math.radians(cyaw), 0.0))
        # Pack produce neatly inside the slanted upper opening
        rot_c = Euler((math.radians(-26), math.radians(cyaw), 0.0), "YXZ").to_matrix()
        for k_i, kind in enumerate(kinds):
            col_i = k_i % 2
            row_i = k_i // 2
            lp = Vector(((col_i - 0.5) * 0.62, 0.46, (row_i - 0.5) * 0.56))
            wp = Vector((ox, oy + 0.14, oz)) + (rot_c @ lp)
            add_fruit_orb_rbx(bm, uv, (wp.x, wp.y, wp.z), 0.31, kind, low_poly=False)

    # 5) PRODUCE MOUNDS IN THE 9 COUNTER BINS (3 stalls x 3 bins = 9 bins; 3 plump fruits per bin = 27 fruits)
    stall_specs = [
        (STALL_LEFT,   9.4,  1.21, ["red", "yellow", "green"]),
        (STALL_CENTER, 10.8, 1.06, ["orange", "yellow", "green"]),
        (STALL_RIGHT,  8.8,  1.11, ["red", "yellow", "green"]),
    ]
    for stall, width, bin_sz, kinds in stall_specs:
        bin_w = (width - 1.4) / 3.0
        for b_i, kind in enumerate(kinds):
            bx_s = (b_i - 1) * (bin_w + 0.26)
            # Triangular 3-fruit cluster perched nicely inside each wooden countertop tray
            for dx, dy, dz, rad in (
                (-0.42, 3.45,  0.18, 0.28),
                ( 0.42, 3.45,  0.15, 0.27),
                ( 0.00, 3.48, -0.22, 0.29),
            ):
                px, py, pz = stall_to_rbx(stall["cx"], stall["cz"], stall["yaw"], bx_s + dx, dy, bin_sz + dz)
                add_fruit_orb_rbx(bm, uv, (px, py, pz), rad, kind, low_poly=True)

    return finalize_mesh_obj("Bazaar_Props_Clutter", bm, mat_props, col, split_angle_deg=42.0)


# ---------------------------------------------------------------------------
# EEVEE Context Scene & Preview Renderer (Excluded from FBX Export!)
# ---------------------------------------------------------------------------
def build_preview_context(col_ctx: bpy.types.Collection) -> None:
    """Create non-exported grass ground, Path_Market stone approach, and background walls for honest renders."""
    # Grass ground
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=36.0)
    mesh_g = bpy.data.meshes.new("PreviewGrass")
    bm.to_mesh(mesh_g)
    bm.free()
    mat_g = bpy.data.materials.new("PreviewGrassMat")
    mat_g.use_nodes = True
    mat_g.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.18, 0.06, 1.0)
    mat_g.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.92
    mesh_g.materials.append(mat_g)
    obj_g = bpy.data.objects.new("Preview_GrassFloor", mesh_g)
    obj_g.location = (0.0, 0.0, -0.02)
    col_ctx.objects.link(obj_g)

    # Path_Market approach indicator slab ending cleanly at (-0.39, 0.03, +11.62)
    bm_p = bmesh.new()
    bmesh.ops.create_cube(bm_p, size=1.0)
    for v in bm_p.verts:
        v.co.x *= 8.4
        v.co.y *= 12.0
        v.co.z *= 0.06
    mesh_p = bpy.data.meshes.new("PreviewPath")
    bm_p.to_mesh(mesh_p)
    bm_p.free()
    mat_p = bpy.data.materials.new("PreviewPathMat")
    mat_p.use_nodes = True
    mat_p.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.20, 0.21, 0.24, 1.0)
    mesh_p.materials.append(mat_p)
    obj_p = bpy.data.objects.new("Preview_PathMarket", mesh_p)
    obj_p.location = rbx_to_blender(-0.39, 0.03, 17.62)
    obj_p.rotation_euler = (0.0, 0.0, 0.0)
    col_ctx.objects.link(obj_p)

    # Lighting
    sun_data = bpy.data.lights.new("PreviewSun", type="SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(12.0)
    sun = bpy.data.objects.new("PreviewSun", sun_data)
    sun.rotation_euler = (math.radians(48.0), math.radians(15.0), math.radians(135.0))
    col_ctx.objects.link(sun)

    if bpy.context.scene.world is None:
        bpy.context.scene.world = bpy.data.worlds.new("World")
    bpy.context.scene.world.use_nodes = True
    bg = bpy.context.scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.48, 0.56, 0.66, 1.0)
        bg.inputs["Strength"].default_value = 0.85

    # Warm point lights matching the 3 lantern positions so preview shows lantern ambiance
    for idx, (lx, ly, lz) in enumerate(LANTERN_PIVOTS_RBX, 1):
        lt_d = bpy.data.lights.new(f"LanternGlow_{idx}", type="POINT")
        lt_d.color = (1.0, 0.66, 0.14)
        lt_d.energy = 35.0
        lt_d.shadow_soft_size = 0.4
        lt = bpy.data.objects.new(f"LanternGlow_{idx}", lt_d)
        lt.location = rbx_to_blender(lx, ly - 0.65, lz)
        col_ctx.objects.link(lt)


def render_previews(render_dir: Path, col_ctx: bpy.types.Collection) -> list[Path]:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE" if hasattr(bpy.types, "Scene") else "BLENDER_EEVEE"
    # Blender 5.x supports BLENDER_EEVEE_NEXT or BLENDER_EEVEE
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x = 1024
    scene.render.resolution_y = 768
    scene.render.image_settings.file_format = "PNG"

    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 35.0
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    col_ctx.objects.link(cam)
    scene.camera = cam

    views = [
        ("hero_courtyard", (-15.0, 18.5, 29.0), (-0.5, 3.6, -1.5)),
        ("top_layout",     (0.0, 38.0, 1.0),   (0.5, 0.0, -0.5)),
        ("rear_walkway",   (15.0, 12.5, -24.0),(0.5, 3.6, -4.0)),
        ("closeup_stalls", (-1.5, 6.8, 12.0),  (0.5, 3.4, -2.5)),
    ]
    out_paths: list[Path] = []
    render_dir.mkdir(parents=True, exist_ok=True)
    for tag, cam_rbx, tgt_rbx in views:
        cam.location = rbx_to_blender(*cam_rbx)
        direction = rbx_to_blender(*tgt_rbx) - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        out_p = render_dir / f"bazaar_{tag}.png"
        scene.render.filepath = str(out_p)
        bpy.ops.render.render(write_still=True)
        out_paths.append(out_p)
    return out_paths


# ---------------------------------------------------------------------------
# Main Pipeline
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Merchant Bazaar assets & FBX")
    parser.add_argument("--no-render", action="store_true", help="Skip EEVEE preview rendering")
    parser.add_argument("--render-dir", type=Path, default=DEFAULT_RENDER_DIR, help="Output folder for PNG previews")
    cli_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args, _ = parser.parse_known_args(cli_args)

    # Clean startup scene
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene

    prefab_col = bpy.data.collections.new("MerchantBazaar_Prefab")
    scene.collection.children.link(prefab_col)

    print("[MerchantBazaar] Generating 1024x1024 PBR texture trios...")
    g_col, g_nrm, g_rgh = generate_bazaar_ground_textures()
    p_col, p_nrm, p_rgh = generate_bazaar_props_textures()

    mat_ground = create_pbr_material("Mat_BazaarGround", g_col, g_nrm, g_rgh)
    mat_props = create_pbr_material("Mat_BazaarProps", p_col, p_nrm, p_rgh)

    print("[MerchantBazaar] Building modular bazaar geometry...")
    tri_breakdown: dict[str, int] = {}

    _, t, grass_anchors = build_flagstone_path(mat_ground, prefab_col)
    tri_breakdown["Bazaar_FlagstonePath"] = t

    _, t = build_grass_tufts(grass_anchors, mat_ground, prefab_col)
    tri_breakdown["Bazaar_GrassTufts"] = t

    _, t = build_stall_timber_frame(mat_props, prefab_col)
    tri_breakdown["Stall_TimberFrame"] = t

    _, t = build_stall_counters(mat_props, prefab_col)
    tri_breakdown["Stall_Counters"] = t

    _, t = build_striped_awning("Awning_Left_RedYellow", STALL_LEFT, 11.4, (0, 1), (1, 1), mat_props, prefab_col)
    tri_breakdown["Awning_Left_RedYellow"] = t

    _, t = build_center_tan_canopy(mat_props, prefab_col)
    tri_breakdown["Awning_Center_Tan"] = t

    _, t = build_striped_awning("Awning_Right_GreenWhite", STALL_RIGHT, 10.8, (2, 1), (3, 1), mat_props, prefab_col)
    tri_breakdown["Awning_Right_GreenWhite"] = t

    _, t = build_hanging_sign(mat_props, prefab_col)
    tri_breakdown["Sign_HangingBoard"] = t

    _, t = build_props_clutter(mat_props, prefab_col)
    tri_breakdown["Bazaar_Props_Clutter"] = t

    for idx, p_rbx in enumerate(LANTERN_PIVOTS_RBX, 1):
        _, t = build_lantern(idx, p_rbx, mat_props, prefab_col)
        tri_breakdown[f"Lantern_Housing_{idx}"] = t

    total_tris = sum(tri_breakdown.values())
    print(f"[MerchantBazaar] Total Triangles: {total_tris} / 4500")
    for k, v in tri_breakdown.items():
        print(f"  - {k}: {v} tris")
    assert total_tris < 4500, f"Triangle budget exceeded: {total_tris} >= 4500!"

    # Select ONLY prefab collection objects and export FBX
    bpy.ops.object.select_all(action="DESELECT")
    for obj in prefab_col.objects:
        obj.select_set(True)

    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=str(FBX_PATH),
        use_selection=True,
        axis_forward="Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=False,
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="OFF",
        use_mesh_modifiers=True,
    )
    print(f"[MerchantBazaar] Exported FBX: {FBX_PATH}")

    # Write manifest JSON
    manifest = {
        "total_tris": total_tris,
        "tri_breakdown": tri_breakdown,
        "floor_top_y": 0.06,
        "stalls": {
            "left": STALL_LEFT,
            "center": STALL_CENTER,
            "right": STALL_RIGHT,
        },
        "sign_pivot_local": list(SIGN_PIVOT_RBX),
        "lantern_pivots_local": [list(p) for p in LANTERN_PIVOTS_RBX],
        "trader_spots_local": [list(p) for p in TRADER_SPOTS_RBX],
        "worker_slots_local": [
            {"slot": 1, "role": "BazaarHawker",       "pos": [-11.20, 0.06, -5.30], "yaw_deg": 15.0},
            {"slot": 2, "role": "CrateStockist",      "pos": [-1.25,  0.06, -9.23], "yaw_deg": -2.0},
            {"slot": 3, "role": "RelicAppraiser",     "pos": [3.95,   0.06, -9.04], "yaw_deg": -2.0},
            {"slot": 4, "role": "QuartermasterLedger","pos": [12.08,  0.06, -2.99], "yaw_deg": -26.0},
        ],
        "counter_colliders": COUNTER_COLLIDERS,
        "prompt_anchor_local": [0.0, 3.6, 6.2],
        "textures": {
            "ground": {
                "color": str(g_col.relative_to(REPO_ROOT).as_posix()),
                "normal": str(g_nrm.relative_to(REPO_ROOT).as_posix()),
                "roughness": str(g_rgh.relative_to(REPO_ROOT).as_posix()),
            },
            "props": {
                "color": str(p_col.relative_to(REPO_ROOT).as_posix()),
                "normal": str(p_nrm.relative_to(REPO_ROOT).as_posix()),
                "roughness": str(p_rgh.relative_to(REPO_ROOT).as_posix()),
            },
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"[MerchantBazaar] Wrote manifest: {MANIFEST_PATH}")

    if not args.no_render:
        ctx_col = bpy.data.collections.new("Preview_Context")
        scene.collection.children.link(ctx_col)
        build_preview_context(ctx_col)
        renders = render_previews(args.render_dir, ctx_col)
        print("[MerchantBazaar] Rendered previews:")
        for r in renders:
            print(f"  - {r}")


if __name__ == "__main__":
    main()
