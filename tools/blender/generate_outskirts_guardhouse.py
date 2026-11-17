"""
=============================================================================
Infinite Tower: Become a Master! - 3D Environment Pipeline
Assets:
  1. `assets/models/facilities/OutskirtsGuardhouse.fbx` (`GuardpostOutskirts`)
     - `GuardTower_CobblePad`
     - `GuardTower_Structure`
     - `GuardTower_Roof`
     - `GuardTower_Props`
     - `Campfire_Area`
     - `Outskirts_Fence`
  2. `assets/models/facilities/OutskirtsEnvironmentKit.fbx` (`OutskirtsEnvironment`)
     - `Outskirts_Pathway` (Gatehouse Flagstone Apron + Organic Dirt Trail + Chiseled Stepping Stones)
     - `Outskirts_LushBush` (Reusable plump multi-lobed leafy shrub)
     - `Outskirts_WoodlandFern` (Reusable radial arching woodland fern)
     - `Outskirts_MossyBoulder` (Reusable faceted slate boulder with moss patch)
     - `Outskirts_GrassTuft` (Reusable 7-blade forest grass clump)
  3. PBR Texture Sets under `assets/models/facilities/textures/outskirts_guardhouse/`:
     - `Tex_GuardpostGround_{Color,Normal,Roughness}.png` (1024x1024, 4x4 atlas)
     - `Tex_GuardpostProps_{Color,Normal,Roughness}.png`  (1024x1024, 4x4 atlas)
     - `Tex_OutskirtsMeadow_{Color,Normal,Roughness}.png` (512x512 seamless forest grass)
  4. Metadata Manifest:
     - `assets/models/facilities/outskirts_guardhouse_manifest.json`

Coordinate Convention (1 Blender meter = 1 Roblox stud):
  Guardpost-local origin is Plot-local (12.0, 0.0, 96.0).
  rbx_to_blender(rx, ry, rz) = (rx, -rz, ry)
  Exported with axis_forward="Z", axis_up="Y" matching TrainingGrounds & MerchantBazaar.

Run:
  "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b -P tools/blender/generate_outskirts_guardhouse.py
=============================================================================
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
# Paths & Constants
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = REPO_ROOT / "assets" / "models" / "facilities"
TEX_DIR = ASSET_DIR / "textures" / "outskirts_guardhouse"
FBX_GUARDPOST_PATH = ASSET_DIR / "OutskirtsGuardhouse.fbx"
FBX_ENVKIT_PATH = ASSET_DIR / "OutskirtsEnvironmentKit.fbx"
MANIFEST_PATH = ASSET_DIR / "outskirts_guardhouse_manifest.json"
DEFAULT_PREVIEW_PATH = (
    Path(r"C:\Users\enter\.gemini\antigravity\brain\1f0596d8-a4d0-45c0-9724-9721c02d88c0\scratch")
    / "outskirts_guardhouse_preview.png"
)

TEX_SIZE = 1024
CELL_PX = 256
CELL_PAD_PX = 14

# Guardpost-local origin corresponds to Plot-local (12, 0, 96)
GP_PLOT_ORIGIN = (12.0, 0.0, 96.0)

# Guard Tower center in Guardpost-local coordinates -> Plot-local (28.5, 0, 81.5)
TOWER_POS_RBX = (16.5, 0.0, -14.5)
TOWER_YAW_DEG = -82.0  # +Z_tower faces Front-Left (pathway/campfire), +X_tower faces Front-Right (ladder/roof)

# Campfire center in Guardpost-local coordinates -> Plot-local (-2.0, 0, 89.5)
CAMPFIRE_POS_RBX = (-14.0, 0.0, -6.5)

# Fence polyline in Guardpost-local coordinates
PALISADE_POINTS = [
    (-29.0, -14.0),  # Plot (-17.0, 82.0) near left pine
    (-23.0, -3.0),   # Plot (-11.0, 93.0)
    (-17.0, 5.5),    # Plot (-5.0, 101.5) corner post connecting palisade -> split-rail
]
SPLIT_RAIL_POINTS = [
    (-17.0, 5.5),    # Shared corner post
    (-11.5, 6.5),    # Plot (0.5, 102.5) front corner
    (-6.2, 0.5),     # Plot (5.8, 96.5) path-side terminal post
]


def rbx_to_blender(rx: float, ry: float, rz: float) -> Vector:
    return Vector((rx, -rz, ry))


def plot_to_gp(px: float, py: float, pz: float) -> tuple[float, float, float]:
    return (px - GP_PLOT_ORIGIN[0], py - GP_PLOT_ORIGIN[1], pz - GP_PLOT_ORIGIN[2])


def tower_local_to_gp(lx: float, ly: float, lz: float) -> tuple[float, float, float]:
    """Transform tower-local Roblox coordinates into Guardpost-local Roblox coordinates."""
    a = math.radians(TOWER_YAW_DEG)
    ca, sa = math.cos(a), math.sin(a)
    # Matches Roblox CFrame.Angles(0, rad(yaw), 0):
    # X' = X*cos + Z*sin, Z' = -X*sin + Z*cos
    gx = TOWER_POS_RBX[0] + lx * ca + lz * sa
    gy = TOWER_POS_RBX[1] + ly
    gz = TOWER_POS_RBX[2] - lx * sa + lz * ca
    return (gx, gy, gz)


# ---------------------------------------------------------------------------
# Procedural PNG Writer & Noise Helpers
# ---------------------------------------------------------------------------
def write_png_rgba(path: Path, rgba: np.ndarray) -> None:
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


def _tileable_noise(res: int, cells: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    grid = rng.random((cells, cells), dtype=np.float32)
    coords = np.linspace(0.0, cells, res, endpoint=False, dtype=np.float32)
    i0 = np.floor(coords).astype(np.int32) % cells
    i1 = (i0 + 1) % cells
    f = coords - np.floor(coords)
    u = f * f * (3.0 - 2.0 * f)
    g00 = grid[np.ix_(i0, i0)]
    g10 = grid[np.ix_(i0, i1)]
    g01 = grid[np.ix_(i1, i0)]
    g11 = grid[np.ix_(i1, i1)]
    nx0 = g00 * (1.0 - u[None, :]) + g10 * u[None, :]
    nx1 = g01 * (1.0 - u[None, :]) + g11 * u[None, :]
    return nx0 * (1.0 - u[:, None]) + nx1 * u[:, None]


def fbm_grid(h: int, w: int, seed: int, octaves: tuple[int, ...] = (64, 32, 16, 8)) -> np.ndarray:
    acc = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for idx, sc in enumerate(octaves):
        acc += amp * _hash_noise_2d(h, w, sc, seed + idx * 97)
        norm += amp
        amp *= 0.5
    return acc / max(norm, 1e-6)


def worley_cobble(res: int, cells: int, jitter: float, seed: int) -> tuple[np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed)
    px = (np.arange(cells)[None, :] + 0.5 + rng.uniform(-0.42 * jitter, 0.42 * jitter, (cells, cells))) / cells
    py = (np.arange(cells)[:, None] + 0.5 + rng.uniform(-0.42 * jitter, 0.42 * jitter, (cells, cells))) / cells
    cval = rng.random((cells, cells), dtype=np.float32)
    us = np.linspace(0.0, 1.0, res, endpoint=False, dtype=np.float32)[None, :]
    vs = np.linspace(0.0, 1.0, res, endpoint=False, dtype=np.float32)[:, None]
    ci = np.floor(us * cells).astype(np.int32)
    cj = np.floor(vs * cells).astype(np.int32)
    d1 = np.full((res, res), 1e6, dtype=np.float32)
    d2 = np.full((res, res), 1e6, dtype=np.float32)
    cid = np.zeros((res, res), dtype=np.float32)
    for dj in (-1, 0, 1):
        ny = (cj + dj) % cells
        for di in (-1, 0, 1):
            nx = (ci + di) % cells
            ddx = us - px[ny, nx]
            ddx -= np.round(ddx)
            ddy = vs - py[ny, nx]
            ddy -= np.round(ddy)
            dist = np.sqrt(ddx * ddx + ddy * ddy) * cells
            s1 = dist < d1
            d2 = np.where(s1, d1, np.minimum(d2, dist))
            d1 = np.where(s1, dist, d1)
            cid = np.where(s1, cval[ny, nx], cid)
    edge = np.clip((d2 - d1) / 0.16, 0.0, 1.0)
    return edge, cid


def height_to_normal_rgb(height: np.ndarray, strength: float = 2.2) -> np.ndarray:
    gx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    gy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    nx = -gx * strength
    ny = gy * strength
    nz = np.ones_like(height)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    return np.stack([
        np.clip((nx * inv * 0.5 + 0.5) * 255.0, 0, 255),
        np.clip((ny * inv * 0.5 + 0.5) * 255.0, 0, 255),
        np.clip((nz * inv * 0.5 + 0.5) * 255.0, 0, 255),
    ], axis=-1).astype(np.uint8)


# ---------------------------------------------------------------------------
# UV Atlas Mapping
# ---------------------------------------------------------------------------
def cell_uv_bounds(col: int, row_from_top: int, pad_px: int = CELL_PAD_PX) -> tuple[float, float, float, float]:
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


def _cell_coords() -> tuple[np.ndarray, np.ndarray]:
    lin = np.linspace(0.0, 1.0, CELL_PX, dtype=np.float32)
    uu, vv = np.meshgrid(lin, 1.0 - lin)
    return uu, vv


def _make_atlas_buffers() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    col = np.zeros((TEX_SIZE, TEX_SIZE, 4), dtype=np.uint8)
    col[..., 3] = 255
    height = np.full((TEX_SIZE, TEX_SIZE), 0.5, dtype=np.float32)
    rough = np.full((TEX_SIZE, TEX_SIZE), 205, dtype=np.uint8)
    return col, height, rough


def _put_cell(atlas_col, atlas_h, atlas_r, cell: tuple[int, int], rgb, h, r) -> None:
    cx, cy = cell
    x0, x1 = cx * CELL_PX, (cx + 1) * CELL_PX
    y0, y1 = cy * CELL_PX, (cy + 1) * CELL_PX
    atlas_col[y0:y1, x0:x1, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    atlas_h[y0:y1, x0:x1] = h.astype(np.float32)
    atlas_r[y0:y1, x0:x1] = np.clip(r * 255.0, 14, 248).astype(np.uint8)


# ---------------------------------------------------------------------------
# 1. PBR Texture Generation
# ---------------------------------------------------------------------------
def generate_guardpost_ground_textures() -> tuple[Path, Path, Path]:
    """Generate Tex_GuardpostGround_{Color,Normal,Roughness}.png (4x4 atlas)."""
    col, height, rough = _make_atlas_buffers()
    uu, vv = _cell_coords()

    # (0,0) Mossy Cobblestone Pad (warm grey-taupe rounded cobbles + dark moss mortar)
    edge_c, cid_c = worley_cobble(CELL_PX, cells=5, jitter=0.78, seed=101)
    grain_c = fbm_grid(CELL_PX, CELL_PX, 102, (32, 16, 8))
    stone_rgb = (
        np.array([112.0, 108.0, 102.0]) * (0.78 + 0.30 * cid_c[..., None] + 0.14 * grain_c[..., None])
    )
    mortar_moss = np.array([58.0, 78.0, 44.0]) + grain_c[..., None] * np.array([16.0, 22.0, 12.0])
    rgb_00 = mortar_moss + (stone_rgb - mortar_moss) * edge_c[..., None]
    _put_cell(col, height, rough, (0, 0), rgb_00, 0.25 + 0.58 * edge_c + 0.14 * grain_c, 0.80 + 0.12 * (1.0 - edge_c))

    # (1,0) Chiseled Grey Stepping Stone (cool layered slate #6B7480 with soft bevel rim)
    n_st = fbm_grid(CELL_PX, CELL_PX, 111, (48, 24, 12, 6))
    flk = fbm_grid(CELL_PX, CELL_PX, 112, (16, 8))
    edge_dist = np.maximum(np.abs(uu - 0.5), np.abs(vv - 0.5)) * 2.0
    bevel = np.clip(1.0 - (edge_dist ** 3.2) * 0.38, 0.62, 1.0)
    rgb_10 = (np.array([96.0, 104.0, 114.0]) + n_st[..., None] * np.array([34.0, 36.0, 38.0])) * bevel[..., None]
    _put_cell(col, height, rough, (1, 0), rgb_10, 0.45 + 0.35 * n_st * bevel + 0.1 * flk, 0.76 - 0.08 * n_st)

    # (2,0) Gatehouse Threshold Stone Slab (slightly warmer ashlar stone #74706B)
    n_gt = fbm_grid(CELL_PX, CELL_PX, 121, (48, 24, 12))
    rgb_20 = (np.array([104.0, 101.0, 96.0]) + n_gt[..., None] * np.array([30.0, 28.0, 26.0])) * bevel[..., None]
    _put_cell(col, height, rough, (2, 0), rgb_20, 0.45 + 0.32 * n_gt * bevel, 0.80)

    # (3,0) Trodden Dirt Pathway (rich damp brown earth #5B4332 -> #473426 with fine grit)
    n_dt1 = fbm_grid(CELL_PX, CELL_PX, 131, (48, 24, 12, 6))
    n_dt2 = fbm_grid(CELL_PX, CELL_PX, 132, (8, 4))
    rgb_30 = np.array([66.0, 49.0, 36.0]) + n_dt1[..., None] * np.array([34.0, 26.0, 18.0]) + n_dt2[..., None] * 10.0
    _put_cell(col, height, rough, (3, 0), rgb_30, 0.38 + 0.36 * n_dt1 + 0.15 * n_dt2, 0.90 + 0.06 * (1.0 - n_dt1))

    # (0,1) Campfire Scorched Ash & Earth Ring (dark ash core -> warm earth rim)
    rad = np.sqrt((uu - 0.5) ** 2 + (vv - 0.5) ** 2) * 2.0
    ash_t = np.clip((rad - 0.25) / 0.55, 0.0, 1.0)
    ash_c = np.array([34.0, 30.0, 28.0]) + n_dt2[..., None] * 14.0
    rgb_01 = ash_c * (1.0 - ash_t[..., None]) + rgb_30 * ash_t[..., None]
    _put_cell(col, height, rough, (0, 1), rgb_01, 0.35 + 0.25 * n_dt2, 0.94)

    # (1,1) Campfire River Stones (warm fire-kissed grey-ochre cobble)
    n_rs = fbm_grid(CELL_PX, CELL_PX, 141, (32, 16, 8))
    rgb_11 = np.array([102.0, 96.0, 88.0]) + n_rs[..., None] * np.array([38.0, 34.0, 28.0])
    _put_cell(col, height, rough, (1, 1), rgb_11, 0.45 + 0.35 * n_rs, 0.82)

    # (2,1) Lush Forest Moss & Deep Grass (emerald-moss green #437032 -> #639644)
    n_ms = fbm_grid(CELL_PX, CELL_PX, 151, (32, 16, 8, 4))
    streak = _hash_noise_2d(CELL_PX, CELL_PX, 6, 152)
    grad_v = np.clip(vv * 0.78 + 0.22 * streak, 0.0, 1.0)
    rgb_21 = (
        np.array([52.0, 88.0, 38.0]) * (1.0 - grad_v[..., None])
        + np.array([92.0, 142.0, 62.0]) * grad_v[..., None]
    ) * (0.88 + 0.22 * n_ms[..., None])
    _put_cell(col, height, rough, (2, 1), rgb_21, 0.42 + 0.32 * n_ms + 0.15 * streak, 0.84)

    # (3,1) Woodland Fern & Shrub Leaf (layered stylized leaf green with central midrib)
    n_lf = fbm_grid(CELL_PX, CELL_PX, 161, (24, 12, 6))
    midrib = np.exp(-((uu - 0.5) * 14.0) ** 2) * 0.18
    vein = (np.sin((vv * 10.0 - np.abs(uu - 0.5) * 8.0) * math.pi) * 0.5 + 0.5) * 0.12
    leaf_base = np.array([62.0, 104.0, 44.0]) * (1.0 - vv[..., None]) + np.array([108.0, 156.0, 68.0]) * vv[..., None]
    rgb_31 = leaf_base * (0.90 + 0.18 * n_lf[..., None] + midrib[..., None] + vein[..., None] * 0.5)
    _put_cell(col, height, rough, (3, 1), rgb_31, 0.45 + 0.28 * midrib + 0.16 * vein + 0.12 * n_lf, 0.72)

    # (0,2) Faceted Boulder Slate Rock (#5E6670 with cool crevices & subtle moss tint)
    n_rk = fbm_grid(CELL_PX, CELL_PX, 171, (48, 24, 12, 6))
    moss_flt = np.clip((fbm_grid(CELL_PX, CELL_PX, 172, (32, 16)) - 0.55) * 2.5, 0.0, 0.55)
    rk_c = np.array([86.0, 92.0, 100.0]) + n_rk[..., None] * np.array([34.0, 36.0, 38.0])
    rgb_02 = rk_c * (1.0 - moss_flt[..., None]) + np.array([72.0, 106.0, 52.0]) * moss_flt[..., None]
    _put_cell(col, height, rough, (0, 2), rgb_02, 0.42 + 0.40 * n_rk, 0.84)

    # (1,2) Dark Wet Soil / Trail Fringe Blend (deep warm soil-moss blend)
    rgb_12 = np.array([56.0, 58.0, 40.0]) + n_dt1[..., None] * np.array([26.0, 28.0, 18.0])
    _put_cell(col, height, rough, (1, 2), rgb_12, 0.40 + 0.30 * n_dt1, 0.90)

    # (2,2) Lighter Bush Sunlit Crown Foliage
    rgb_22 = (
        np.array([72.0, 118.0, 48.0]) * (1.0 - grad_v[..., None])
        + np.array([124.0, 172.0, 78.0]) * grad_v[..., None]
    ) * (0.90 + 0.16 * n_lf[..., None])
    _put_cell(col, height, rough, (2, 2), rgb_22, 0.45 + 0.25 * n_lf, 0.76)

    # (3,2) Deep Meadow Shadow Grass
    rgb_32 = np.array([44.0, 74.0, 36.0]) + n_ms[..., None] * np.array([24.0, 38.0, 20.0])
    _put_cell(col, height, rough, (3, 2), rgb_32, 0.40 + 0.25 * n_ms, 0.88)

    # Row 3 fallbacks
    for cx, src_rgb in enumerate((rgb_00, rgb_10, rgb_30, rgb_21)):
        _put_cell(col, height, rough, (cx, 3), src_rgb, 0.45 + 0.2 * n_st, 0.84)

    norm_rgb = height_to_normal_rgb(height, strength=2.4)
    norm_rgba = np.dstack([norm_rgb, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])
    rough_rgba = np.dstack([rough, rough, rough, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])

    p_col = TEX_DIR / "Tex_GuardpostGround_Color.png"
    p_nrm = TEX_DIR / "Tex_GuardpostGround_Normal.png"
    p_rgh = TEX_DIR / "Tex_GuardpostGround_Roughness.png"
    write_png_rgba(p_col, col)
    write_png_rgba(p_nrm, norm_rgba)
    write_png_rgba(p_rgh, rough_rgba)
    return p_col, p_nrm, p_rgh


def generate_guardpost_props_textures() -> tuple[Path, Path, Path]:
    """Generate Tex_GuardpostProps_{Color,Normal,Roughness}.png (4x4 atlas)."""
    col, height, rough = _make_atlas_buffers()
    uu, vv = _cell_coords()

    def make_wood(seed: int, base_rgb, seam_rgb, n_planks: int, rough_val: float, vertical: bool = False):
        g_fine = _hash_noise_2d(CELL_PX, CELL_PX, 4, seed)
        g_str = _hash_noise_2d(CELL_PX, CELL_PX, 28, seed + 17)
        grain = 0.58 * g_str + 0.42 * g_fine
        rgb = np.array(base_rgb) * (0.84 + 0.28 * grain[..., None])
        h_map = 0.52 + 0.20 * grain
        r_map = np.full((CELL_PX, CELL_PX), rough_val, dtype=np.float32)
        if not vertical and n_planks > 1:
            p_pos = (vv * n_planks) % 1.0
            seam = (p_pos < 0.05) | (p_pos > 0.95)
            rgb[seam] = np.array(seam_rgb) * 0.85
            h_map[seam] = 0.22
            r_map[seam] = min(0.95, rough_val + 0.12)
        return rgb, h_map, r_map

    # (0,0) Heavy Structural Timber (rich chestnut oak #6E472B, vertical grain)
    _put_cell(col, height, rough, (0, 0), *make_wood(301, (112.0, 72.0, 42.0), (58.0, 36.0, 20.0), 1, 0.82, vertical=True))
    # (1,0) Cabin & Deck Horizontal Planks (#7D5234 with 5 plank seams)
    _put_cell(col, height, rough, (1, 0), *make_wood(302, (124.0, 82.0, 50.0), (66.0, 42.0, 24.0), 5, 0.80, vertical=False))
    # (2,0) Weathered Shingle Roof (#564840 with crisp shingle edge highlight)
    n_sh = fbm_grid(CELL_PX, CELL_PX, 303, (32, 16, 8))
    sh_grain = _hash_noise_2d(CELL_PX, CELL_PX, 6, 304)
    sh_rgb = np.array([86.0, 72.0, 63.0]) * (0.86 + 0.24 * (0.6 * n_sh + 0.4 * sh_grain)[..., None])
    sh_row = (vv * 2.0) % 1.0
    sh_seam = sh_row < 0.08
    sh_rgb[sh_seam] *= 0.62
    sh_h = 0.45 + 0.30 * sh_row + 0.14 * sh_grain
    sh_h[sh_seam] = 0.20
    _put_cell(col, height, rough, (2, 0), sh_rgb, sh_h, np.full((CELL_PX, CELL_PX), 0.85))

    # (3,0) Velvety Roof & Log Moss Overlay (#55823A -> #72A24E)
    n_ms = fbm_grid(CELL_PX, CELL_PX, 305, (24, 12, 6))
    ms_rgb = np.array([74.0, 114.0, 48.0]) + n_ms[..., None] * np.array([42.0, 56.0, 24.0])
    _put_cell(col, height, rough, (3, 0), ms_rgb, 0.48 + 0.34 * n_ms, np.full((CELL_PX, CELL_PX), 0.92))

    # (0,1) Deep Furrowed Tree Bark (felled logs & palisade stakes #4C3322)
    b_furrow = np.sin(uu * math.pi * 16.0 + fbm_grid(CELL_PX, CELL_PX, 311, (24, 12)) * 4.5) * 0.5 + 0.5
    b_noise = fbm_grid(CELL_PX, CELL_PX, 312, (32, 16, 8))
    bark_rgb = np.array([58.0, 40.0, 26.0]) + b_furrow[..., None] * np.array([34.0, 22.0, 14.0]) + b_noise[..., None] * 10.0
    _put_cell(col, height, rough, (0, 1), bark_rgb, 0.32 + 0.48 * b_furrow + 0.12 * b_noise, np.full((CELL_PX, CELL_PX), 0.90))

    # (1,1) Cut Sapwood / Sharpened Stake Tips (#B88B58 with concentric rings)
    rad = np.sqrt((uu - 0.5) ** 2 + (vv - 0.5) ** 2) * 2.0
    rings = np.sin(rad * math.pi * 10.0 + fbm_grid(CELL_PX, CELL_PX, 313, (24, 12)) * 1.4) * 0.5 + 0.5
    tip_rgb = np.array([164.0, 122.0, 76.0]) + rings[..., None] * np.array([28.0, 22.0, 14.0])
    _put_cell(col, height, rough, (1, 1), tip_rgb, 0.52 + 0.14 * rings, np.full((CELL_PX, CELL_PX), 0.78))

    # (2,1) Framed Pine Crate (#845834 with dark frame border & diagonal brace)
    cr_rgb, cr_h, cr_r = make_wood(314, (132.0, 88.0, 52.0), (80.0, 52.0, 30.0), 4, 0.80)
    border = (uu < 0.15) | (uu > 0.85) | (vv < 0.15) | (vv > 0.85)
    diag = np.abs((uu - 0.5) - (vv - 0.5)) < 0.09
    frame = border | diag
    cr_rgb[frame] = np.array([96.0, 62.0, 34.0])
    cr_h[frame] = 0.78
    _put_cell(col, height, rough, (2, 1), cr_rgb, cr_h, cr_r)

    # (3,1) Burlap Grain Sack + Rope Tie (#B29268)
    wx = np.sin(uu * math.pi * 46.0) * 0.5 + 0.5
    wy = np.sin(vv * math.pi * 46.0) * 0.5 + 0.5
    weave = 0.5 * wx + 0.5 * wy
    n_bur = fbm_grid(CELL_PX, CELL_PX, 315, (48, 24, 12))
    bur_rgb = np.array([174.0, 142.0, 98.0]) * (0.88 + 0.16 * n_bur[..., None] + 0.04 * (weave[..., None] - 0.5))
    rope = (vv > 0.68) & (vv < 0.78)
    bur_rgb[rope] = np.array([104.0, 76.0, 44.0])
    bur_h = 0.48 + 0.10 * weave + 0.12 * n_bur
    bur_h[rope] = 0.78
    _put_cell(col, height, rough, (3, 1), bur_rgb, bur_h, np.full((CELL_PX, CELL_PX), 0.92))

    # (0,2) Hammered Wrought Iron (#282C33)
    n_ir = fbm_grid(CELL_PX, CELL_PX, 321, (24, 12, 6))
    ir_rgb = np.array([38.0, 42.0, 48.0]) * (0.84 + 0.30 * n_ir[..., None])
    _put_cell(col, height, rough, (0, 2), ir_rgb, 0.48 + 0.24 * n_ir, np.full((CELL_PX, CELL_PX), 0.42))

    # (1,2) Weathered Ochre-Tan Swallowtail Banner Cloth (#AC8E68)
    n_bn = fbm_grid(CELL_PX, CELL_PX, 322, (48, 24, 12))
    bn_rgb = np.array([164.0, 134.0, 98.0]) * (0.88 + 0.18 * n_bn[..., None])
    b_trim = (uu < 0.09) | (uu > 0.91)
    bn_rgb[b_trim] = np.array([124.0, 96.0, 68.0])
    _put_cell(col, height, rough, (1, 2), bn_rgb, 0.5 + 0.08 * weave + 0.1 * n_bn, np.full((CELL_PX, CELL_PX), 0.88))

    # (2,2) Glowing Lantern Glass (#FFBA42 -> #FFF0A8)
    glow = np.clip(1.0 - rad * 0.72, 0.0, 1.0)
    gl_rgb = np.array([255.0, 162.0, 24.0]) * (1.0 - glow[..., None]) + np.array([255.0, 238.0, 168.0]) * glow[..., None]
    mullion = (uu < 0.09) | (uu > 0.91) | (vv < 0.09) | (vv > 0.91)
    gl_rgb[mullion] = np.array([38.0, 40.0, 46.0])
    _put_cell(col, height, rough, (2, 2), gl_rgb, np.where(mullion, 0.75, 0.45), np.where(mullion, 0.42, 0.16))

    # (3,2) Charred Firewood & Glowing Embers
    n_ch = fbm_grid(CELL_PX, CELL_PX, 323, (32, 16, 8))
    ember_crack = np.clip((n_ch - 0.62) * 5.0, 0.0, 1.0)
    ch_rgb = np.array([30.0, 24.0, 22.0]) * (1.0 - ember_crack[..., None]) + np.array([255.0, 118.0, 22.0]) * ember_crack[..., None]
    _put_cell(col, height, rough, (3, 2), ch_rgb, 0.42 + 0.32 * n_ch, np.full((CELL_PX, CELL_PX), 0.88))

    # (0,3) Banded Barrel Staves + Iron Hoops
    st_pos = (uu * 8.0) % 1.0
    st_seam = (st_pos < 0.05) | (st_pos > 0.95)
    bar_rgb = np.array([112.0, 74.0, 44.0]) * (0.86 + 0.22 * n_sh[..., None])
    bar_rgb[st_seam] = np.array([56.0, 34.0, 20.0])
    bar_h = 0.52 + 0.16 * n_sh
    bar_h[st_seam] = 0.25
    bar_r = np.full((CELL_PX, CELL_PX), 0.80, dtype=np.float32)
    hoop = ((vv > 0.16) & (vv < 0.26)) | ((vv > 0.74) & (vv < 0.84))
    bar_rgb[hoop] = np.array([38.0, 42.0, 48.0])
    bar_h[hoop] = 0.84
    bar_r[hoop] = 0.38
    _put_cell(col, height, rough, (0, 3), bar_rgb, bar_h, bar_r)

    # (1,3) Dark Window Backing / Interior Shadow
    _put_cell(col, height, rough, (1, 3), np.broadcast_to(np.array([24.0, 20.0, 18.0]), (CELL_PX, CELL_PX, 3)), np.full((CELL_PX, CELL_PX), 0.3), np.full((CELL_PX, CELL_PX), 0.95))
    # (2,3) Polished Spearhead Steel
    _put_cell(col, height, rough, (2, 3), np.array([152.0, 160.0, 170.0]) * (0.88 + 0.22 * n_ir[..., None]), 0.55 + 0.15 * n_ir, np.full((CELL_PX, CELL_PX), 0.28))
    # (3,3) Dark Saddle Leather / Strap
    _put_cell(col, height, rough, (3, 3), np.array([76.0, 46.0, 28.0]) * (0.86 + 0.22 * n_bn[..., None]), 0.48 + 0.15 * n_bn, np.full((CELL_PX, CELL_PX), 0.65))

    norm_rgb = height_to_normal_rgb(height, strength=2.3)
    norm_rgba = np.dstack([norm_rgb, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])
    rough_rgba = np.dstack([rough, rough, rough, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])

    p_col = TEX_DIR / "Tex_GuardpostProps_Color.png"
    p_nrm = TEX_DIR / "Tex_GuardpostProps_Normal.png"
    p_rgh = TEX_DIR / "Tex_GuardpostProps_Roughness.png"
    write_png_rgba(p_col, col)
    write_png_rgba(p_nrm, norm_rgba)
    write_png_rgba(p_rgh, rough_rgba)
    return p_col, p_nrm, p_rgh


def generate_outskirts_meadow_textures() -> tuple[Path, Path, Path]:
    """Generate 512x512 seamless deep forest grass textures for OutskirtsGrounds MaterialVariant."""
    R = 512
    n_big = _tileable_noise(R, 8, 501) * 0.6 + _tileable_noise(R, 18, 502) * 0.4
    n_fine = _tileable_noise(R, 42, 503) * 0.6 + _tileable_noise(R, 96, 504) * 0.4
    blade_mix = n_big * 0.58 + n_fine * 0.42

    # Cool deep forest green matching the reference image (dark emerald shadow -> rich moss green)
    c_dark = np.array([34.0, 62.0, 32.0], dtype=np.float32)
    c_mid = np.array([48.0, 84.0, 42.0], dtype=np.float32)
    c_hi = np.array([68.0, 108.0, 50.0], dtype=np.float32)
    t1 = np.clip(blade_mix * 1.8, 0.0, 1.0)[..., None]
    t2 = np.clip((blade_mix - 0.52) * 2.1, 0.0, 1.0)[..., None]
    rgb = np.where(blade_mix[..., None] < 0.52, c_dark * (1.0 - t1) + c_mid * t1, c_mid * (1.0 - t2) + c_hi * t2)

    h_map = 0.35 + 0.45 * blade_mix
    r_u8 = np.clip((0.88 - 0.12 * n_fine) * 255.0, 120, 245).astype(np.uint8)
    norm_rgb = height_to_normal_rgb(h_map, strength=2.6)

    col_rgba = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), np.full((R, R), 255, dtype=np.uint8)])
    norm_rgba = np.dstack([norm_rgb, np.full((R, R), 255, dtype=np.uint8)])
    rough_rgba = np.dstack([r_u8, r_u8, r_u8, np.full((R, R), 255, dtype=np.uint8)])

    p_col = TEX_DIR / "Tex_OutskirtsMeadow_Color.png"
    p_nrm = TEX_DIR / "Tex_OutskirtsMeadow_Normal.png"
    p_rgh = TEX_DIR / "Tex_OutskirtsMeadow_Roughness.png"
    write_png_rgba(p_col, col_rgba)
    write_png_rgba(p_nrm, norm_rgba)
    write_png_rgba(p_rgh, rough_rgba)
    return p_col, p_nrm, p_rgh


def create_pbr_material(name: str, p_col: Path, p_nrm: Path, p_rgh: Path) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Specular IOR Level"].default_value = 0.32
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def load_img(path: Path, colorspace: str):
        img = bpy.data.images.load(str(path), check_existing=True)
        img.colorspace_settings.name = colorspace
        return img

    tex_col = nt.nodes.new("ShaderNodeTexImage")
    tex_col.image = load_img(p_col, "sRGB")
    nt.links.new(tex_col.outputs["Color"], bsdf.inputs["Base Color"])

    tex_rgh = nt.nodes.new("ShaderNodeTexImage")
    tex_rgh.image = load_img(p_rgh, "Non-Color")
    nt.links.new(tex_rgh.outputs["Color"], bsdf.inputs["Roughness"])

    tex_nrm = nt.nodes.new("ShaderNodeTexImage")
    tex_nrm.image = load_img(p_nrm, "Non-Color")
    nrm_node = nt.nodes.new("ShaderNodeNormalMap")
    nrm_node.inputs["Strength"].default_value = 0.85
    nt.links.new(tex_nrm.outputs["Color"], nrm_node.inputs["Color"])
    nt.links.new(nrm_node.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


# ---------------------------------------------------------------------------
# 2. BMesh Geometry Primitives (Roblox Coordinates -> Blender)
# ---------------------------------------------------------------------------
def set_face_tile_uv(face: bmesh.types.BMFace, uv_layer, cell: tuple[int, int]) -> None:
    u0, u1, v0, v1 = cell_uv_bounds(cell[0], cell[1])
    n = len(face.loops)
    if n == 4:
        pts = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        for i, loop in enumerate(face.loops):
            loop[uv_layer].uv = pts[i]
    else:
        for i, loop in enumerate(face.loops):
            ang = 2.0 * math.pi * (i / max(1, n))
            loop[uv_layer].uv = (
                (u0 + u1) * 0.5 + (u1 - u0) * 0.45 * math.cos(ang),
                (v0 + v1) * 0.5 + (v1 - v0) * 0.45 * math.sin(ang),
            )


def rbx_rot_matrix(euler_rbx: tuple[float, float, float]) -> Matrix:
    """Roblox CFrame.fromEulerAnglesYXZ(pitch, yaw, roll) = Ry(yaw) @ Rx(pitch) @ Rz(roll)."""
    px, yy, rz = euler_rbx
    return Matrix.Rotation(yy, 3, "Y") @ Matrix.Rotation(px, 3, "X") @ Matrix.Rotation(rz, 3, "Z")


def add_box_rbx(
    bm: bmesh.types.BMesh,
    uv,
    center_rbx: tuple[float, float, float],
    size_rbx: tuple[float, float, float],
    cell: tuple[int, int],
    euler_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    sx, sy, sz = size_rbx
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    corners = [
        (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
        (-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz),
    ]
    rot = rbx_rot_matrix(euler_rbx)
    c_vec = Vector(center_rbx)
    verts = [bm.verts.new(rbx_to_blender(*(c_vec + rot @ Vector(lc)))) for lc in corners]
    quads = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)]
    for q in quads:
        f = bm.faces.new([verts[i] for i in q])
        set_face_tile_uv(f, uv, cell)


def add_beam_between_rbx(
    bm: bmesh.types.BMesh,
    uv,
    p0_rbx: tuple[float, float, float],
    p1_rbx: tuple[float, float, float],
    thickness: float,
    depth: float,
    cell: tuple[int, int],
) -> None:
    v0 = Vector(p0_rbx)
    v1 = Vector(p1_rbx)
    delta = v1 - v0
    length = delta.Length if hasattr(delta, "Length") else delta.length
    if length < 1e-4:
        return
    mid = (v0 + v1) * 0.5
    # Build orthonormal frame in Roblox space with local Y along delta
    y_axis = delta.normalized()
    ref = Vector((0.0, 0.0, 1.0)) if abs(y_axis.z) < 0.92 else Vector((1.0, 0.0, 0.0))
    x_axis = y_axis.cross(ref).normalized()
    z_axis = x_axis.cross(y_axis).normalized()
    ht, hl, hd = thickness * 0.5, length * 0.5, depth * 0.5
    corners = [
        (-ht, -hl, -hd), (ht, -hl, -hd), (ht, -hl, hd), (-ht, -hl, hd),
        (-ht, hl, -hd), (ht, hl, -hd), (ht, hl, hd), (-ht, hl, hd),
    ]
    verts = []
    for lx, ly, lz in corners:
        p = mid + x_axis * lx + y_axis * ly + z_axis * lz
        verts.append(bm.verts.new(rbx_to_blender(p.x, p.y, p.z)))
    for q in [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)]:
        f = bm.faces.new([verts[i] for i in q])
        set_face_tile_uv(f, uv, cell)


def add_prism_y_rbx(
    bm: bmesh.types.BMesh,
    uv,
    center_rbx: tuple[float, float, float],
    radius_bot: float,
    radius_top: float,
    height: float,
    sides: int,
    cell_side: tuple[int, int],
    cell_cap: tuple[int, int] | None = None,
    euler_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel_top: float = 0.0,
    cap_top: bool = True,
) -> None:
    if cell_cap is None:
        cell_cap = cell_side
    rot = rbx_rot_matrix(euler_rbx)
    c_vec = Vector(center_rbx)
    hy = height * 0.5
    u0, u1, v0, v1 = cell_uv_bounds(cell_side[0], cell_side[1])

    ring_b, ring_t = [], []
    for k in range(sides):
        a = 2.0 * math.pi * k / sides
        ca, sa = math.cos(a), math.sin(a)
        pb = c_vec + rot @ Vector((radius_bot * ca, -hy, radius_bot * sa))
        pt = c_vec + rot @ Vector((radius_top * ca, hy - bevel_top, radius_top * sa))
        ring_b.append(bm.verts.new(rbx_to_blender(pb.x, pb.y, pb.z)))
        ring_t.append(bm.verts.new(rbx_to_blender(pt.x, pt.y, pt.z)))

    for k in range(sides):
        kn = (k + 1) % sides
        f = bm.faces.new([ring_b[k], ring_b[kn], ring_t[kn], ring_t[k]])
        t0, t1 = k / sides, (k + 1) / sides
        f.loops[0][uv].uv = (u0 + (u1 - u0) * t0, v0)
        f.loops[1][uv].uv = (u0 + (u1 - u0) * t1, v0)
        f.loops[2][uv].uv = (u0 + (u1 - u0) * t1, v1)
        f.loops[3][uv].uv = (u0 + (u1 - u0) * t0, v1)

    if bevel_top > 1e-4 and cap_top:
        ring_bevel = []
        for k in range(sides):
            a = 2.0 * math.pi * k / sides
            ca, sa = math.cos(a), math.sin(a)
            p_in = c_vec + rot @ Vector((radius_top * 0.78 * ca, hy, radius_top * 0.78 * sa))
            ring_bevel.append(bm.verts.new(rbx_to_blender(p_in.x, p_in.y, p_in.z)))
        for k in range(sides):
            kn = (k + 1) % sides
            fb = bm.faces.new([ring_t[k], ring_t[kn], ring_bevel[kn], ring_bevel[k]])
            set_face_tile_uv(fb, uv, cell_cap)
        top_ring = ring_bevel
    else:
        top_ring = ring_t

    fb = bm.faces.new(list(reversed(ring_b)))
    set_face_tile_uv(fb, uv, cell_cap)
    if cap_top:
        ft = bm.faces.new(top_ring)
        set_face_tile_uv(ft, uv, cell_cap)


def add_lathe_rbx(
    bm: bmesh.types.BMesh,
    uv,
    center_rbx: tuple[float, float, float],
    rings: list[tuple[float, float]],
    sides: int,
    cell: tuple[int, int],
    euler_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
    smooth: bool = True,
) -> None:
    rot = rbx_rot_matrix(euler_rbx)
    c_vec = Vector(center_rbx)
    u0, u1, v0, v1 = cell_uv_bounds(cell[0], cell[1])
    v_rings = []
    for dy, rad in rings:
        row = []
        for k in range(sides):
            a = 2.0 * math.pi * k / sides
            p = c_vec + rot @ Vector((rad * math.cos(a), dy, rad * math.sin(a)))
            row.append(bm.verts.new(rbx_to_blender(p.x, p.y, p.z)))
        v_rings.append(row)

    for r_i in range(len(v_rings) - 1):
        r0, r1 = v_rings[r_i], v_rings[r_i + 1]
        tv0 = r_i / (len(v_rings) - 1)
        tv1 = (r_i + 1) / (len(v_rings) - 1)
        for k in range(sides):
            kn = (k + 1) % sides
            f = bm.faces.new([r0[k], r0[kn], r1[kn], r1[k]])
            f.smooth = smooth
            t0, t1 = k / sides, (k + 1) / sides
            f.loops[0][uv].uv = (u0 + (u1 - u0) * t0, v0 + (v1 - v0) * tv0)
            f.loops[1][uv].uv = (u0 + (u1 - u0) * t1, v0 + (v1 - v0) * tv0)
            f.loops[2][uv].uv = (u0 + (u1 - u0) * t1, v0 + (v1 - v0) * tv1)
            f.loops[3][uv].uv = (u0 + (u1 - u0) * t0, v0 + (v1 - v0) * tv1)

    for row, rev in ((v_rings[0], True), (v_rings[-1], False)):
        seq = list(reversed(row)) if rev else row
        fc = bm.faces.new(seq)
        set_face_tile_uv(fc, uv, cell)


def add_poly_slab_rbx(
    bm: bmesh.types.BMesh,
    uv,
    pts_xz: list[tuple[float, float]],
    y_bot: float,
    y_top: float,
    cell: tuple[int, int],
    bevel_inset: float = 0.14,
) -> None:
    cx = sum(p[0] for p in pts_xz) / len(pts_xz)
    cz = sum(p[1] for p in pts_xz) / len(pts_xz)
    inner = [
        (cx + (px - cx) * (1.0 - bevel_inset), cz + (pz - cz) * (1.0 - bevel_inset))
        for px, pz in pts_xz
    ]
    v_bot = [bm.verts.new(rbx_to_blender(px, y_bot, pz)) for px, pz in pts_xz]
    v_top = [bm.verts.new(rbx_to_blender(px, y_top, pz)) for px, pz in inner]
    v_ctr = bm.verts.new(rbx_to_blender(cx, y_top, cz))

    n = len(pts_xz)
    u0, u1, v0, v1 = cell_uv_bounds(cell[0], cell[1])
    min_x = min(p[0] for p in pts_xz)
    max_x = max(p[0] for p in pts_xz)
    min_z = min(p[1] for p in pts_xz)
    max_z = max(p[1] for p in pts_xz)
    span_x = max(0.01, max_x - min_x)
    span_z = max(0.01, max_z - min_z)

    def planar_uv(px: float, pz: float) -> tuple[float, float]:
        lu = (px - min_x) / span_x
        lv = (pz - min_z) / span_z
        return (u0 + lu * (u1 - u0), v0 + lv * (v1 - v0))

    for k in range(n):
        kn = (k + 1) % n
        ft = bm.faces.new([v_ctr, v_top[k], v_top[kn]])
        ft.loops[0][uv].uv = planar_uv(cx, cz)
        ft.loops[1][uv].uv = planar_uv(inner[k][0], inner[k][1])
        ft.loops[2][uv].uv = planar_uv(inner[kn][0], inner[kn][1])

        fs = bm.faces.new([v_bot[k], v_bot[kn], v_top[kn], v_top[k]])
        fs.loops[0][uv].uv = planar_uv(pts_xz[k][0], pts_xz[k][1])
        fs.loops[1][uv].uv = planar_uv(pts_xz[kn][0], pts_xz[kn][1])
        fs.loops[2][uv].uv = planar_uv(inner[kn][0], inner[kn][1])
        fs.loops[3][uv].uv = planar_uv(inner[k][0], inner[k][1])

    fb = bm.faces.new(list(reversed(v_bot)))
    for k, loop in enumerate(fb.loops):
        idx = n - 1 - k
        loop[uv].uv = planar_uv(pts_xz[idx][0], pts_xz[idx][1])


def add_faceted_rock_rbx(
    bm: bmesh.types.BMesh,
    uv,
    center_rbx: tuple[float, float, float],
    scale_xyz: tuple[float, float, float],
    cell: tuple[int, int],
    seed: int,
    subdiv: int = 1,
    yaw_deg: float = 0.0,
) -> None:
    rng = random.Random(seed)
    tmp = bmesh.new()
    bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=1.0)
    rot = rbx_rot_matrix((0.0, math.radians(yaw_deg), 0.0))
    c_vec = Vector(center_rbx)

    vmap = {}
    for v in tmp.verts:
        co = v.co.copy()
        co.x *= scale_xyz[0] * rng.uniform(0.84, 1.16)
        co.y *= scale_xyz[1] * rng.uniform(0.84, 1.14)
        co.z *= scale_xyz[2] * rng.uniform(0.84, 1.16)
        if co.y < -scale_xyz[1] * 0.35:
            co.y = -scale_xyz[1] * 0.35
        p_rbx = c_vec + rot @ Vector((co.x, co.y, co.z))
        vmap[v.index] = bm.verts.new(rbx_to_blender(p_rbx.x, p_rbx.y, p_rbx.z))

    for f in tmp.faces:
        nf = bm.faces.new([vmap[v.index] for v in f.verts])
        set_face_tile_uv(nf, uv, cell)
    tmp.free()


def add_grass_tuft_rbx(
    bm: bmesh.types.BMesh,
    uv,
    base_rbx: tuple[float, float, float],
    scale: float,
    cell: tuple[int, int],
    seed: int,
    blades: int = 6,
) -> None:
    rng = random.Random(seed)
    bx, by, bz = base_rbx
    u0, u1, v0, v1 = cell_uv_bounds(cell[0], cell[1])
    for i in range(blades):
        ang = (i / blades) * 2.0 * math.pi + rng.uniform(-0.35, 0.35)
        h = rng.uniform(0.75, 1.25) * scale
        w = rng.uniform(0.14, 0.22) * scale
        lean = rng.uniform(0.32, 0.62) * scale
        ox = rng.uniform(-0.22, 0.22) * scale
        oz = rng.uniform(-0.22, 0.22) * scale
        ca, sa = math.cos(ang), math.sin(ang)
        px, pz = -sa, ca
        p_l = (bx + ox + px * w * 0.5, by, bz + oz + pz * w * 0.5)
        p_r = (bx + ox - px * w * 0.5, by, bz + oz - pz * w * 0.5)
        p_m = (bx + ox + ca * lean * 0.45, by + h * 0.55, bz + oz + sa * lean * 0.45)
        p_t = (bx + ox + ca * lean, by + h, bz + oz + sa * lean)
        vl = bm.verts.new(rbx_to_blender(*p_l))
        vr = bm.verts.new(rbx_to_blender(*p_r))
        vm_l = bm.verts.new(rbx_to_blender(p_m[0] + px * w * 0.25, p_m[1], p_m[2] + pz * w * 0.25))
        vm_r = bm.verts.new(rbx_to_blender(p_m[0] - px * w * 0.25, p_m[1], p_m[2] - pz * w * 0.25))
        vt = bm.verts.new(rbx_to_blender(*p_t))
        f1 = bm.faces.new([vl, vr, vm_r, vm_l])
        f1.loops[0][uv].uv = (u0, v0)
        f1.loops[1][uv].uv = (u1, v0)
        f1.loops[2][uv].uv = (u1, (v0 + v1) * 0.5)
        f1.loops[3][uv].uv = (u0, (v0 + v1) * 0.5)
        f2 = bm.faces.new([vm_l, vm_r, vt])
        f2.loops[0][uv].uv = (u0, (v0 + v1) * 0.5)
        f2.loops[1][uv].uv = (u1, (v0 + v1) * 0.5)
        f2.loops[2][uv].uv = ((u0 + u1) * 0.5, v1)


def finalize_mesh_obj(
    name: str,
    bm: bmesh.types.BMesh,
    mat: bpy.types.Material,
    col: bpy.types.Collection,
) -> tuple[bpy.types.Object, int]:
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    tris = sum(max(1, len(f.verts) - 2) for f in bm.faces)
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    col.objects.link(obj)
    mesh.materials.append(mat)
    return obj, tris


# ---------------------------------------------------------------------------
# 3. Guardhouse Sub-Meshes (`OutskirtsGuardhouse.fbx`)
# ---------------------------------------------------------------------------
def build_guardtower_cobblepad(mat_ground: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(2001)
    cell_cobble = (0, 0)
    cell_moss = (2, 1)
    cell_soil = (1, 2)
    cell_slate = (1, 0)

    # Rounded-square dark earth mortar base pad (ry=0.0..0.04)
    n_base = 16
    pts = []
    for k in range(n_base):
        a = 2.0 * math.pi * k / n_base
        ca, sa = math.cos(a), math.sin(a)
        # Superellipse for rounded square cobble yard (~13.4 x 13.4 studs)
        r = 6.7 / ((abs(ca) ** 3.2 + abs(sa) ** 3.2) ** (1.0 / 3.2))
        pts.append(tower_local_to_gp(ca * r, 0.0, sa * r))
    pts_xz = [(p[0], p[2]) for p in pts]
    add_poly_slab_rbx(bm, uv, pts_xz, 0.0, 0.04, cell_soil, bevel_inset=0.05)

    # Individual bevelled cobblestones across the pad in concentric organic rings
    rings = [(0.0, 1), (1.75, 6), (3.45, 11), (5.05, 15)]
    for r_dist, count in rings:
        for i in range(count):
            ang = (2.0 * math.pi * i / count) + rng.uniform(-0.18, 0.18)
            dist = r_dist + rng.uniform(-0.32, 0.32) if r_dist > 0.1 else 0.0
            lx = math.cos(ang) * dist
            lz = math.sin(ang) * dist
            # Keep stones inside rounded square
            if abs(lx) > 5.75 or abs(lz) > 5.75:
                continue
            rad_stone = rng.uniform(0.72, 1.00)
            sides = 5
            stone_pts = []
            for s in range(sides):
                sa_a = 2.0 * math.pi * s / sides + rng.uniform(-0.15, 0.15)
                sr = rad_stone * rng.uniform(0.84, 1.12)
                px, _, pz = tower_local_to_gp(lx + math.cos(sa_a) * sr, 0.0, lz + math.sin(sa_a) * sr)
                stone_pts.append((px, pz))
            add_poly_slab_rbx(
                bm, uv, stone_pts, 0.02, rng.uniform(0.08, 0.13),
                cell_cobble if (i % 3 != 0) else cell_slate, bevel_inset=0.18
            )

    # 4 corner stone pier footings under the 4 timber stilts
    for sx in (-4.1, 4.1):
        for sz in (-4.1, 4.1):
            px, _, pz = tower_local_to_gp(sx, 0.0, sz)
            add_box_rbx(
                bm, uv, (px, 0.22, pz), (1.45, 0.44, 1.45), cell_slate,
                (0.0, math.radians(TOWER_YAW_DEG), 0.0)
            )

    # Outer moss/grass tufts hugging cobble edge
    for k in range(10):
        a = (k / 10.0) * 2.0 * math.pi + 0.2
        ca, sa = math.cos(a), math.sin(a)
        r = 6.5 / ((abs(ca) ** 3.2 + abs(sa) ** 3.2) ** (1.0 / 3.2))
        gx, gy, gz = tower_local_to_gp(ca * r, 0.03, sa * r)
        add_grass_tuft_rbx(bm, uv, (gx, gy, gz), rng.uniform(0.75, 1.05), cell_moss, seed=2100 + k, blades=5)

    return finalize_mesh_obj("GuardTower_CobblePad", bm, mat_ground, col)


def build_guardtower_structure(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    c_timber = (0, 0)
    c_plank = (1, 0)
    c_iron = (0, 2)
    c_lantern = (2, 2)
    c_shadow = (1, 3)

    yaw_rad = math.radians(TOWER_YAW_DEG)

    def add_tbox(lx: float, ly: float, lz: float, size: tuple[float, float, float], cell: tuple[int, int], pitch=0.0, roll=0.0, dyaw=0.0):
        gx, gy, gz = tower_local_to_gp(lx, ly, lz)
        add_box_rbx(bm, uv, (gx, gy, gz), size, cell, (pitch, yaw_rad + dyaw, roll))

    def add_tbeam(p0: tuple[float, float, float], p1: tuple[float, float, float], thick: float, depth: float, cell: tuple[int, int]):
        g0 = tower_local_to_gp(*p0)
        g1 = tower_local_to_gp(*p1)
        add_beam_between_rbx(bm, uv, g0, g1, thick, depth, cell)

    # 1. 4 Heavy Battered Corner Stilts (ry = 0.35 .. 8.35)
    for sx in (-1.0, 1.0):
        for sz in (-1.0, 1.0):
            add_tbeam((sx * 4.1, 0.35, sz * 4.1), (sx * 3.85, 8.35, sz * 3.85), 0.78, 0.78, c_timber)

    # 2. Horizontal Frame Beams + Prominent Diagonal X-Bracing on all 4 bays
    for sz in (-3.9, 3.9):
        add_tbeam((-3.9, 7.85, sz), (3.9, 7.85, sz), 0.56, 0.56, c_timber)
        add_tbeam((-3.95, 1.4, sz), (3.95, 7.6, sz), 0.38, 0.38, c_timber)
        add_tbeam((3.95, 1.4, sz), (-3.95, 7.6, sz), 0.38, 0.38, c_timber)
    for sx in (-3.9, 3.9):
        add_tbeam((sx, 7.85, -3.9), (sx, 7.85, 3.9), 0.56, 0.56, c_timber)
        add_tbeam((sx, 1.4, -3.95), (sx, 7.6, 3.95), 0.38, 0.38, c_timber)
        add_tbeam((sx, 1.4, 3.95), (sx, 7.6, -3.95), 0.38, 0.38, c_timber)

    # 3. Exposed Sub-deck Floor Joists & Bevelled Deck Planks (ry = 8.20 .. 8.78)
    for jz in (-4.4, -2.2, 0.0, 2.2, 4.4):
        add_tbox(0.0, 8.35, jz, (11.2, 0.42, 0.44), c_timber)
    for jx in (-4.4, 4.4):
        add_tbox(jx, 8.35, 0.0, (0.44, 0.42, 11.2), c_timber)
    for p_idx in range(-4, 5):
        add_tbox(0.0, 8.68, p_idx * 1.18, (10.8, 0.26, 1.10), c_plank)

    # 4. Wraparound Balcony Balustrade (ry = 8.80 .. 11.35)
    # Leave ladder opening on +X wall (front-right) at lz in [-3.4, -1.0]
    post_positions = [
        (-5.1, -5.1), (0.0, -5.1), (5.1, -5.1),
        (-5.1, 0.0), (5.1, 0.0),
        (-5.1, 5.1), (0.0, 5.1), (5.1, 5.1),
        (5.1, -0.9), (5.1, -3.5),
    ]
    for px, pz in post_positions:
        add_tbox(px, 10.05, pz, (0.46, 2.50, 0.46), c_timber)
        add_tbox(px, 11.42, pz, (0.56, 0.22, 0.56), c_timber)

    # Balcony top & bottom rails + balusters
    rail_spans = [
        ((-5.1, -5.1), (5.1, -5.1), 7),   # -Z rail
        ((-5.1, 5.1), (5.1, 5.1), 7),     # +Z rail (window side)
        ((-5.1, -5.1), (-5.1, 5.1), 7),   # -X rail (back-left)
        ((5.1, 0.0), (5.1, 5.1), 4),      # +X rail front half (ladder opening at lz in [-3.5, -0.9])
        ((5.1, -5.1), (5.1, -3.5), 1),    # +X rail far-right end
    ]
    for (x0, z0), (x1, z1), nb in rail_spans:
        add_tbeam((x0, 11.0, z0), (x1, 11.0, z1), 0.28, 0.34, c_timber)
        add_tbeam((x0, 9.25, z0), (x1, 9.25, z1), 0.24, 0.28, c_timber)
        for b in range(1, nb + 1):
            t = b / (nb + 1)
            bx = x0 + (x1 - x0) * t
            bz = z0 + (z1 - z0) * t
            add_tbox(bx, 10.12, bz, (0.20, 1.55, 0.20), c_timber)

    # 5. Elevated Wooden Guard Cabin (7.0 x 7.0 footprint, ry = 8.81 .. 15.6 + Gable peak 18.4)
    # 4 corner cabin studs + wall panels
    for sx in (-3.35, 3.35):
        for sz in (-3.35, 3.35):
            add_tbox(sx, 12.1, sz, (0.52, 6.6, 0.52), c_timber)

    # Main wall plank enclosure (slightly recessed inside corner posts)
    add_tbox(0.0, 11.8, -3.3, (6.5, 6.0, 0.38), c_plank)   # Back (-Z_tower)
    add_tbox(-3.3, 11.8, 0.0, (0.38, 6.0, 6.5), c_plank)   # Back-Left (-X_tower)
    add_tbox(3.3, 11.8, 0.0, (0.38, 6.0, 6.5), c_plank)    # Ladder-side (+X_tower)
    # Front-Left Gable Window Wall (+Z_tower): lower wall + side jambs + top header around window
    add_tbox(0.0, 9.85, 3.3, (6.5, 2.1, 0.38), c_plank)
    add_tbox(-2.3, 12.15, 3.3, (1.9, 2.6, 0.38), c_plank)
    add_tbox(2.3, 12.15, 3.3, (1.9, 2.6, 0.38), c_plank)
    add_tbox(0.0, 14.1, 3.3, (6.5, 1.4, 0.38), c_plank)

    # Recessed dark window box + chunky timber frame + 3 horizontal/vertical window bars
    add_tbox(0.0, 12.15, 3.12, (2.7, 2.4, 0.22), c_shadow)
    add_tbox(0.0, 10.92, 3.45, (3.1, 0.30, 0.44), c_timber)  # sill
    add_tbox(0.0, 13.38, 3.45, (3.1, 0.30, 0.44), c_timber)  # header
    for wx in (-1.40, 1.40):
        add_tbox(wx, 12.15, 3.42, (0.28, 2.45, 0.38), c_timber)
    for bar_y in (11.55, 12.15, 12.75):
        add_tbox(0.0, bar_y, 3.30, (2.55, 0.16, 0.16), c_timber)
    add_tbox(0.0, 12.15, 3.32, (0.18, 2.25, 0.18), c_timber)

    # Cabin Doorway Accent on +X wall (above ladder)
    add_tbox(3.48, 11.1, -1.2, (0.20, 4.4, 2.1), c_shadow)
    add_tbox(3.52, 11.1, -2.3, (0.26, 4.5, 0.26), c_timber)
    add_tbox(3.52, 11.1, -0.1, (0.26, 4.5, 0.26), c_timber)
    add_tbox(3.52, 13.4, -1.2, (0.26, 0.30, 2.45), c_timber)

    # Triangular Gable Walls (+Z and -Z_tower, 38 deg pitch matching roof sheathing)
    pitch_g = math.radians(38.0)
    hx_g = 3.45
    hy_g = hx_g * math.tan(pitch_g)
    for gz in (-3.3, 3.3):
        hz_g = 0.20
        for s_face in (-1.0, 1.0):
            v_l = bm.verts.new(rbx_to_blender(*tower_local_to_gp(-hx_g, 14.8, gz + s_face * hz_g)))
            v_r = bm.verts.new(rbx_to_blender(*tower_local_to_gp(hx_g, 14.8, gz + s_face * hz_g)))
            v_t = bm.verts.new(rbx_to_blender(*tower_local_to_gp(0.0, 14.8 + hy_g, gz + s_face * hz_g)))
            verts_tri = [v_l, v_r, v_t] if s_face > 0 else [v_r, v_l, v_t]
            ft = bm.faces.new(verts_tri)
            set_face_tile_uv(ft, uv, c_plank)
        add_tbox(0.0, 14.82, gz, (6.8, 0.30, 0.40), c_plank)

    # 6. Warm Glowing Corner Lantern Hanging at Front Corner (+X_tower=+3.8, +Z_tower=+3.8)
    add_tbeam((3.45, 13.4, 3.45), (4.45, 13.6, 4.45), 0.18, 0.18, c_iron)
    add_tbox(4.35, 13.15, 4.35, (0.12, 0.75, 0.12), c_iron)
    add_tbox(4.35, 12.65, 4.35, (0.72, 0.16, 0.72), c_iron)   # lantern cap
    add_tbox(4.35, 12.15, 4.35, (0.56, 0.82, 0.56), c_lantern) # glowing amber glass
    add_tbox(4.35, 11.68, 4.35, (0.64, 0.14, 0.64), c_iron)   # lantern bottom

    # 7. Steep Wooden Access Ladder on +X_tower face (leaning from ground lx=7.2 to deck lx=5.1 at lz=-2.2)
    for rz_off in (-3.1, -1.3):
        add_tbeam((7.15, 0.05, rz_off), (5.05, 9.55, rz_off), 0.28, 0.38, c_timber)
    for r_i in range(8):
        t = (r_i + 0.7) / 8.5
        rx_rung = 7.15 + (5.05 - 7.15) * t
        ry_rung = 0.05 + (9.55 - 0.05) * t
        add_tbox(rx_rung, ry_rung, -2.2, (0.28, 0.18, 2.05), c_plank)

    return finalize_mesh_obj("GuardTower_Structure", bm, mat_props, col)


def build_guardtower_roof(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(2044)

    c_timber = (0, 0)
    c_shingle = (2, 0)
    c_moss = (3, 0)

    yaw_rad = math.radians(TOWER_YAW_DEG)
    pitch = math.radians(38.0)
    slope_len = 5.45
    roof_len_z = 9.2
    ridge_y = 17.65

    # Solid sheathing panels starting cleanly at apex (no crossing horns) + bargeboards
    for s in (-1.0, 1.0):
        mid_d = slope_len * 0.50 + 0.12
        cx = s * math.cos(pitch) * mid_d
        cy = ridge_y - math.sin(pitch) * mid_d
        gx, gy, gz = tower_local_to_gp(cx, cy, 0.0)
        add_box_rbx(bm, uv, (gx, gy, gz), (slope_len, 0.26, roof_len_z), c_timber, (0.0, yaw_rad, -s * pitch))

        # Front & back angled bargeboards framing gable
        for fz in (-roof_len_z * 0.49, roof_len_z * 0.49):
            bx, by, bz = tower_local_to_gp(cx, cy - 0.06, fz)
            add_box_rbx(bm, uv, (bx, by, bz), (slope_len, 0.46, 0.34), c_timber, (0.0, yaw_rad, -s * pitch))

        # 5 overlapping rows x 7 columns of chunky 3D shingles lying flat on the roof slope
        n_rows = 5
        n_cols = 7
        row_step = (slope_len * 0.88) / n_rows
        col_step = (roof_len_z * 0.92) / n_cols
        for r in range(n_rows):
            dist_down = 0.58 + r * row_step
            n_x = s * math.sin(pitch)
            n_y = math.cos(pitch)
            lift = 0.20 + (n_rows - r) * 0.025
            sx = s * math.cos(pitch) * dist_down + n_x * lift
            sy = ridge_y - math.sin(pitch) * dist_down + n_y * lift
            stag = 0.24 if (r % 2 == 1) else -0.24
            for c_i in range(n_cols):
                tz = -roof_len_z * 0.44 + (c_i + 0.5) * col_step + stag * 0.4
                tz = max(-roof_len_z * 0.43, min(roof_len_z * 0.43, tz))
                gx_s, gy_s, gz_s = tower_local_to_gp(sx, sy, tz)
                is_moss = (s > 0 and r >= n_rows - 2 and c_i in (1, 2, 4, 5))
                sh_cell = c_moss if (is_moss and rng.random() < 0.55) else c_shingle
                add_box_rbx(
                    bm, uv, (gx_s, gy_s, gz_s),
                    (row_step * 1.24, 0.15, col_step * 1.04),
                    sh_cell,
                    (0.0, yaw_rad, -s * (pitch - 0.07)),
                )

    # Heavy ridge cap beam sealing the apex cleanly
    rx, ry, rz = tower_local_to_gp(0.0, ridge_y + 0.18, 0.0)
    add_box_rbx(bm, uv, (rx, ry, rz), (0.68, 0.48, roof_len_z + 0.36), c_timber, (0.0, yaw_rad, 0.0))

    # Sculpted green moss patches sitting flush on the lower shingles of the right roof slope
    for idx, (dist_d, tz, sc) in enumerate([(4.0, 2.2, 0.85), (4.3, 0.3, 0.95), (4.1, -1.9, 0.80), (3.0, 2.8, 0.70)]):
        mx = math.cos(pitch) * dist_d + math.sin(pitch) * 0.30
        my = ridge_y - math.sin(pitch) * dist_d + math.cos(pitch) * 0.30
        gx, gy, gz = tower_local_to_gp(mx, my, tz)
        add_box_rbx(bm, uv, (gx, gy, gz), (1.05 * sc, 0.16 * sc, 1.30 * sc), c_moss, (0.0, yaw_rad + 0.12 * idx, -pitch))

    return finalize_mesh_obj("GuardTower_Roof", bm, mat_props, col)


def build_guardtower_props(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    c_timber = (0, 0)
    c_crate = (2, 1)
    c_sack = (3, 1)
    c_barrel = (0, 3)
    c_iron = (0, 2)
    c_steel = (2, 3)
    c_banner = (1, 2)

    yaw_rad = math.radians(TOWER_YAW_DEG)

    # 1. Stacked Framed Wooden Crates under the Left Stilt Bay (-X_tower, +Z_tower)
    for (lx, ly, lz, sz, dyaw) in [
        (-1.65, 1.05, 1.85, (2.1, 2.0, 2.1), 0.14),
        (-1.75, 2.85, 1.75, (1.65, 1.6, 1.65), -0.22),
    ]:
        gx, gy, gz = tower_local_to_gp(lx, ly, lz)
        add_box_rbx(bm, uv, (gx, gy, gz), sz, c_crate, (0.0, yaw_rad + dyaw, 0.0))

    # 2. Banded Wooden Barrel under the Right Stilt Bay (+X_tower, -Z_tower)
    bx, by, bz = tower_local_to_gp(2.15, 0.05, -0.45)
    add_lathe_rbx(
        bm, uv, (bx, by, bz),
        [(0.0, 0.86), (0.7, 1.08), (1.35, 1.14), (2.0, 1.08), (2.65, 0.88)],
        10, c_barrel, (0.0, yaw_rad, 0.0), smooth=True
    )

    # 3. 4 Plump Tied Burlap Grain Sacks clustered at front corner leg (+X_tower=4.3, +Z_tower=4.3)
    sack_specs = [
        (3.8, 0.05, 5.1, 1.0, 0.0, 0.1),
        (5.0, 0.05, 4.1, 0.92, 0.08, -0.12),
        (2.8, 0.05, 5.4, 0.84, -0.10, 0.08),
        (4.5, 0.05, 5.3, 0.78, 0.12, 0.10),
    ]
    for sx, sy, sz, sc, tilt_x, tilt_z in sack_specs:
        gx, gy, gz = tower_local_to_gp(sx, sy, sz)
        add_lathe_rbx(
            bm, uv, (gx, gy, gz),
            [
                (0.0, 0.56 * sc),
                (0.42 * sc, 0.78 * sc),
                (0.95 * sc, 0.64 * sc),
                (1.22 * sc, 0.24 * sc),
                (1.48 * sc, 0.42 * sc),
            ],
            8, c_sack, (tilt_x, yaw_rad, tilt_z), smooth=True
        )

    # 4. Rustic Spear & Halberd Rack on Left Flank (-Z_tower, outside front-left post)
    rx0, ry0, rz0 = tower_local_to_gp(-5.8, 0.0, 1.2)
    rx1, ry1, rz1 = tower_local_to_gp(-5.8, 0.0, 4.4)
    add_beam_between_rbx(bm, uv, (rx0, 0.0, rz0), (rx0, 3.1, rz0), 0.24, 0.24, c_timber)
    add_beam_between_rbx(bm, uv, (rx1, 0.0, rz1), (rx1, 3.1, rz1), 0.24, 0.24, c_timber)
    add_beam_between_rbx(bm, uv, (rx0, 2.55, rz0), (rx1, 2.55, rz1), 0.22, 0.22, c_timber)
    add_beam_between_rbx(bm, uv, (rx0, 0.75, rz0), (rx1, 0.75, rz1), 0.22, 0.22, c_timber)
    for i in range(4):
        lz_sp = 1.6 + i * 0.78
        sp_x, _, sp_z = tower_local_to_gp(-5.65, 0.0, lz_sp)
        add_box_rbx(bm, uv, (sp_x, 2.35, sp_z), (0.14, 4.6, 0.14), c_timber, (0.0, yaw_rad, 0.08))
        tip_x, _, tip_z = tower_local_to_gp(-5.45, 0.0, lz_sp)
        add_prism_y_rbx(bm, uv, (tip_x, 4.85, tip_z), 0.18, 0.02, 0.82, 4, c_steel, c_steel, (0.0, yaw_rad, 0.08))

    # 5. Hanging Swallowtail Cloth Banner projecting from Front-Left Balcony Post (-X_tower, +Z_tower)
    pole_p0 = tower_local_to_gp(-5.0, 11.2, 5.1)
    pole_p1 = tower_local_to_gp(-7.6, 11.2, 5.1)
    add_beam_between_rbx(bm, uv, pole_p0, pole_p1, 0.20, 0.20, c_timber)
    bx_c, by_c, bz_c = tower_local_to_gp(-6.8, 11.05, 5.1)
    add_box_rbx(bm, uv, (bx_c, by_c, bz_c), (1.85, 0.16, 0.16), c_timber, (0.0, yaw_rad, 0.0))
    # Clean tailored swallowtail banner cloth (two vertical halved panels sloping inward at bottom V-notch)
    add_box_rbx(bm, uv, (bx_c, by_c - 1.45, bz_c), (1.55, 2.75, 0.10), c_banner, (0.0, yaw_rad, 0.0))
    for dx in (-0.42, 0.42):
        tx, ty, tz = tower_local_to_gp(-6.8 + dx, 7.95, 5.1)
        add_box_rbx(bm, uv, (tx, ty, tz), (0.70, 0.72, 0.10), c_banner, (0.0, yaw_rad, 0.0))

    return finalize_mesh_obj("GuardTower_Props", bm, mat_props, col)


def build_campfire_area(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(3011)

    c_bark = (0, 1)
    c_cut = (1, 1)
    c_moss = (3, 0)
    c_char = (3, 2)
    c_crate = (2, 1)
    c_iron = (0, 2)
    c_timber = (0, 0)
    c_sack = (3, 1)

    fcx, _, fcz = CAMPFIRE_POS_RBX

    # 1. Charred Embers Mound + 6 Crossed Split Firewood Logs
    add_prism_y_rbx(bm, uv, (fcx, 0.22, fcz), 1.75, 0.95, 0.44, 10, c_char, c_char)
    for i in range(6):
        ang = (i / 6.0) * 2.0 * math.pi + rng.uniform(-0.18, 0.18)
        lx = fcx + math.cos(ang) * 0.72
        lz = fcz + math.sin(ang) * 0.72
        add_prism_y_rbx(
            bm, uv, (lx, 0.52, lz), 0.24, 0.19, 2.8, 6, c_char, c_cut,
            (math.radians(66), ang, 0.0)
        )

    # 2. 11 Irregular River Stones in the Campfire Ring (radius ~ 2.45 studs)
    # Use c_iron / warm river rock via crate/stone? Wait: Mat_GuardpostProps has c_iron / c_char,
    # OR let's assign Mat_GuardpostGround ONLY? No! Every MeshPart has 1 Material in Roblox!
    # So let's keep stones in a separate ground-atlas mesh OR put river-stone cell in Mat_GuardpostProps?
    # Wait: let's check Mat_GuardpostProps cells! Look at (1,3) - we can dedicate (1,3) or build a dedicated `Campfire_StoneHearth`?
    # Better yet: let's replace (1,3) in `Tex_GuardpostProps`? No, (1,3) is dark shadow backing! Let's replace (3,3) or put fire stones + hearth pad inside `Outskirts_SteppingStones` OR add river-stone color on `Campfire_Area`?
    # WAIT: Look at `Campfire_Area`: if `Campfire_Area` holds ONLY the logs, moss, spit, crate, stump, and fire embers (`Mat_GuardpostProps`), and the **dirt hearth pad + 11 river stones** sit in `Campfire_StoneRing` (`Mat_GuardpostGround`, OR inside `GuardTower_CobblePad`? No, `GuardTower_CobblePad` is inside `Building_GuardPost`!).
    # Wait: `Campfire_Area` MUST disappear with `Building_GuardPost` when a plot is unoccupied!
    # So let's keep `Campfire_StoneHearth` as its own small MeshPart using `Mat_GuardpostGround` (`Cell (0,1)` scorched ash & earth + `Cell (1,1)` campfire river stones)! That gives us crisp high-res rock & ash normals on the fire ring AND keeps `Campfire_Area` crisp on the wood, bark, moss, and crate!

    # 3. 3 Mossy Felled Log Benches around the campfire (tangent U-formation)
    log_benches = [
        # (dx, dz, length, radius) -> yaw computed tangent to circle around fire
        (-2.6, -3.7, 6.2, 0.86),   # Top-left log
        (-3.2, 3.2, 6.0, 0.85),    # Bottom-left log
        (3.4, 3.0, 5.8, 0.84),     # Bottom-right log
    ]
    for idx, (dx, dz, length, rad) in enumerate(log_benches):
        lx, lz = fcx + dx, fcz + dz
        yaw_r = math.atan2(-dz, dx)
        # Main felled log cylinder (lying horizontally along local Z -> pitch=90 deg)
        add_prism_y_rbx(
            bm, uv, (lx, rad * 0.78, lz), rad, rad * 0.94, length, 10,
            c_bark, c_cut, (math.pi * 0.5, yaw_r, 0.0)
        )
        # Tapered organic moss cap hugging the upper arch of the felled log
        hl_m = length * 0.36
        add_lathe_rbx(
            bm, uv, (lx, rad * 1.15, lz),
            [(-hl_m, rad * 0.15), (-hl_m * 0.55, rad * 0.62), (0.0, rad * 0.68), (hl_m * 0.55, rad * 0.58), (hl_m, rad * 0.15)],
            8, c_moss, (math.pi * 0.5, yaw_r, 0.0), smooth=True
        )

    # 4. Chopped Tree Stump left of campfire
    add_prism_y_rbx(bm, uv, (fcx - 5.6, 0.58, fcz - 0.5), 0.92, 0.68, 1.18, 8, c_bark, c_cut)

    # 5. Cooking Spit Frame + Hanging Iron Kettle + Supply Crate on right edge of campfire
    sx0, sz0 = fcx + 2.6, fcz - 3.6
    sx1, sz1 = fcx + 4.4, fcz - 1.6
    add_beam_between_rbx(bm, uv, (sx0, 0.0, sz0), (sx0, 2.55, sz0), 0.18, 0.18, c_timber)
    add_beam_between_rbx(bm, uv, (sx1, 0.0, sz1), (sx1, 2.55, sz1), 0.18, 0.18, c_timber)
    add_beam_between_rbx(bm, uv, (sx0 - 0.1, 2.35, sz0 - 0.1), (sx1 + 0.1, 2.35, sz1 + 0.1), 0.16, 0.16, c_timber)
    mx, mz = (sx0 + sx1) * 0.5, (sz0 + sz1) * 0.5
    add_beam_between_rbx(bm, uv, (mx, 2.35, mz), (mx, 1.55, mz), 0.08, 0.08, c_iron)
    add_lathe_rbx(bm, uv, (mx, 0.95, mz), [(0.0, 0.22), (0.28, 0.44), (0.55, 0.36), (0.65, 0.24)], 8, c_iron)
    # Small cloth pouch hanging beside kettle + framed supply crate
    add_lathe_rbx(bm, uv, (fcx + 4.6, 0.05, fcz - 2.3), [(0.0, 0.42), (0.45, 0.52), (0.9, 0.26), (1.1, 0.36)], 8, c_sack)
    add_box_rbx(bm, uv, (fcx + 5.7, 0.88, fcz - 1.2), (1.85, 1.75, 1.85), c_crate, (0.0, 0.28, 0.0))

    return finalize_mesh_obj("Campfire_Area", bm, mat_props, col)


def build_campfire_stone_hearth(mat_ground: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(3055)

    c_ash = (0, 1)
    c_stone = (1, 1)

    fcx, _, fcz = CAMPFIRE_POS_RBX

    # Compacted circular ash & warm dirt hearth pad (ry = 0.0..0.06, radius ~ 6.6)
    n_pad = 16
    pad_pts = [
        (fcx + math.cos(2.0 * math.pi * k / n_pad) * rng.uniform(6.0, 6.8),
         fcz + math.sin(2.0 * math.pi * k / n_pad) * rng.uniform(6.0, 6.8))
        for k in range(n_pad)
    ]
    add_poly_slab_rbx(bm, uv, pad_pts, 0.0, 0.05, c_ash, bevel_inset=0.06)

    # 11 Chunky River Stones around fire ring (radius ~ 2.40 studs)
    n_stones = 11
    for i in range(n_stones):
        ang = (2.0 * math.pi * i / n_stones) + rng.uniform(-0.08, 0.08)
        r = 2.40 + rng.uniform(-0.14, 0.14)
        sx = fcx + math.cos(ang) * r
        sz = fcz + math.sin(ang) * r
        add_faceted_rock_rbx(
            bm, uv, (sx, 0.36, sz),
            (rng.uniform(0.58, 0.78), rng.uniform(0.38, 0.52), rng.uniform(0.52, 0.68)),
            c_stone, seed=3200 + i, subdiv=1, yaw_deg=math.degrees(ang)
        )

    return finalize_mesh_obj("Campfire_StoneHearth", bm, mat_ground, col)


def build_outskirts_fence(mat_props: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(4011)

    c_bark = (0, 1)
    c_tip = (1, 1)
    c_timber = (0, 0)

    def add_sharpened_stake(gx: float, gz: float, rad: float, height: float, yaw: float):
        shaft_h = height * 0.78
        tip_h = height * 0.22
        add_prism_y_rbx(bm, uv, (gx, shaft_h * 0.5, gz), rad, rad * 0.96, shaft_h, 6, c_bark, c_tip, (0.0, yaw, rng.uniform(-0.03, 0.03)), cap_top=False)
        add_prism_y_rbx(bm, uv, (gx, shaft_h + tip_h * 0.5, gz), rad * 0.96, 0.04, tip_h, 6, c_tip, c_tip, (0.0, yaw, rng.uniform(-0.03, 0.03)), cap_top=True)

    # Section A: Tightly spaced sharpened timber palisade stakes
    for seg_idx in range(len(PALISADE_POINTS) - 1):
        ax, az = PALISADE_POINTS[seg_idx]
        bx, bz = PALISADE_POINTS[seg_idx + 1]
        seg_len = math.hypot(bx - ax, bz - az)
        n_stakes = max(6, int(round(seg_len / 1.02)))
        yaw = math.atan2(bx - ax, bz - az)
        nx, nz = -(bz - az) / seg_len, (bx - ax) / seg_len
        for k in range(n_stakes):
            t = k / n_stakes
            sx = ax + (bx - ax) * t
            sz = az + (bz - az) * t
            add_sharpened_stake(sx, sz, rng.uniform(0.50, 0.58), rng.uniform(4.0, 4.65), yaw + rng.uniform(-0.25, 0.25))
        for ry in (1.25, 2.75):
            add_beam_between_rbx(bm, uv, (ax + nx * 0.46, ry, az + nz * 0.46), (bx + nx * 0.46, ry, bz + nz * 0.46), 0.30, 0.26, c_timber)

    # Section B: Heavy Pointed-Post Split-Rail Corner Fence
    for seg_idx in range(len(SPLIT_RAIL_POINTS) - 1):
        ax, az = SPLIT_RAIL_POINTS[seg_idx]
        bx, bz = SPLIT_RAIL_POINTS[seg_idx + 1]
        seg_len = math.hypot(bx - ax, bz - az)
        yaw = math.atan2(bx - ax, bz - az)
        n_bays = 2
        for k in range(n_bays + 1):
            if seg_idx > 0 and k == 0:
                continue
            t = k / n_bays
            px = ax + (bx - ax) * t
            pz = az + (bz - az) * t
            add_sharpened_stake(px, pz, 0.56, 4.45 if (k % n_bays == 0) else 4.15, yaw)
        for ry in (1.35, 2.75):
            add_beam_between_rbx(bm, uv, (ax, ry, az), (bx, ry, bz), 0.34, 0.44, c_timber)

    return finalize_mesh_obj("Outskirts_Fence", bm, mat_props, col)


# ---------------------------------------------------------------------------
# 4. Outskirts Environment Kit (`OutskirtsEnvironmentKit.fbx`)
# ---------------------------------------------------------------------------
def build_outskirts_pathway(mat_ground: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """
    Build the Gatehouse Flagstone Apron + Organic Trodden Dirt Trail + Chiseled Grey Stepping Stones
    in Guardpost-local coordinates (centered at Plot (12, 0, 96)).
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(5011)

    c_apron = (2, 0)
    c_step = (1, 0)
    c_dirt = (3, 0)
    c_fringe = (1, 2)

    # 1. Gatehouse Flagstone Apron (Plot X=3.5..24.5, Z=60.3..68.7 -> GP X=-8.5..+12.5, Z=-35.7..-27.3)
    apron_x0, apron_x1 = -8.2, 12.2
    apron_z0, apron_z1 = -35.6, -27.2
    # Dark mortar bed + beveled outer curb rim
    add_box_rbx(bm, uv, (2.0, 0.04, -31.4), (20.8, 0.08, 8.6), c_fringe)
    # 5 x 2 grid of irregular bevelled gatehouse flagstones
    nx_a, nz_a = 5, 2
    dx_a = (apron_x1 - apron_x0) / nx_a
    dz_a = (apron_z1 - apron_z0) / nz_a
    for ix in range(nx_a):
        for iz in range(nz_a):
            cx = apron_x0 + (ix + 0.5) * dx_a
            cz = apron_z0 + (iz + 0.5) * dz_a
            w = dx_a * 0.45
            d = dz_a * 0.44
            pts = [
                (cx - w + rng.uniform(-0.18, 0.18), cz - d + rng.uniform(-0.18, 0.18)),
                (cx + w + rng.uniform(-0.18, 0.18), cz - d + rng.uniform(-0.18, 0.18)),
                (cx + w + rng.uniform(-0.18, 0.18), cz + d + rng.uniform(-0.18, 0.18)),
                (cx - w + rng.uniform(-0.18, 0.18), cz + d + rng.uniform(-0.18, 0.18)),
            ]
            add_poly_slab_rbx(bm, uv, pts, 0.02, rng.uniform(0.11, 0.14), c_apron, bevel_inset=0.10)

    # 2. Organic Trodden Dirt Trail Mesh (Connector + Main E-W Frontier Trail)
    # Build smooth organic ribbon polygons so there are zero jagged rectangular box edges!
    def build_trail_ribbon(centerline: list[tuple[float, float, float]], y_top: float, cell: tuple[int, int]):
        left_verts, right_verts, ctr_verts = [], [], []
        u0, u1, v0, v1 = cell_uv_bounds(cell[0], cell[1])
        for idx, (cx, cz, half_w) in enumerate(centerline):
            if idx == 0:
                tx, tz = centerline[1][0] - cx, centerline[1][1] - cz
            elif idx == len(centerline) - 1:
                tx, tz = cx - centerline[-2][0], cz - centerline[-2][1]
            else:
                tx, tz = centerline[idx + 1][0] - centerline[idx - 1][0], centerline[idx + 1][1] - centerline[idx - 1][1]
            tlen = max(1e-4, math.hypot(tx, tz))
            nx, nz = -tz / tlen, tx / tlen
            vl = bm.verts.new(rbx_to_blender(cx - nx * half_w, 0.0, cz - nz * half_w))
            vc = bm.verts.new(rbx_to_blender(cx, y_top, cz))
            vr = bm.verts.new(rbx_to_blender(cx + nx * half_w, 0.0, cz + nz * half_w))
            left_verts.append(vl)
            ctr_verts.append(vc)
            right_verts.append(vr)
        for idx in range(len(centerline) - 1):
            t_v0 = (idx % 2) * 0.5
            t_v1 = t_v0 + 0.5
            for a0, b0, b1, a1 in (
                (left_verts[idx], ctr_verts[idx], ctr_verts[idx + 1], left_verts[idx + 1]),
                (ctr_verts[idx], right_verts[idx], right_verts[idx + 1], ctr_verts[idx + 1]),
            ):
                f = bm.faces.new([a0, b0, b1, a1])
                f.loops[0][uv].uv = (u0, v0 + (v1 - v0) * t_v0)
                f.loops[1][uv].uv = (u1, v0 + (v1 - v0) * t_v0)
                f.loops[2][uv].uv = (u1, v0 + (v1 - v0) * t_v1)
                f.loops[3][uv].uv = (u0, v0 + (v1 - v0) * t_v1)

    connector_pts = [
        (2.0, -27.2, 5.2),
        (2.4, -22.0, 4.9),
        (2.2, -16.5, 4.6),
        (1.0, -10.5, 4.8),
        (0.2, -4.5, 5.1),
        (-0.4, 2.0, 5.4),
        (-1.2, 8.5, 5.6),
        (-1.5, 14.5, 6.2),
    ]
    ew_trail_pts = []
    for k in range(25):
        px = -68.0 + k * (136.0 / 24.0)  # Plot X
        pz = 110.0 + math.sin(px * 0.055) * 6.0 + math.cos(px * 0.11) * 2.5
        gp_x, _, gp_z = plot_to_gp(px, 0.0, pz)
        hw = 5.4 + math.sin(k * 0.8) * 0.85
        ew_trail_pts.append((gp_x, gp_z, hw))

    build_trail_ribbon(connector_pts, 0.035, c_dirt)
    build_trail_ribbon(ew_trail_pts, 0.035, c_dirt)

    # Soft dirt-clearing extension around campfire
    add_poly_slab_rbx(
        bm, uv,
        [(-21.0, -10.5), (-8.5, -13.5), (-1.5, -6.5), (-5.5, 3.0), (-17.5, 3.5), (-23.0, -3.5)],
        0.0, 0.03, c_fringe, bevel_inset=0.14
    )

    # 3. 16 Chiseled Grey Polygonal Stepping Stones along Connector & Main Trail
    stepping_stones = [
        (2.2, -23.5, 2.0, 1.4, 12),
        (3.4, -18.5, 2.2, 1.5, -18),
        (1.0, -13.2, 1.9, 1.4, 24),
        (-0.2, -7.8, 2.1, 1.5, -8),
        (-0.8, -1.8, 2.2, 1.6, 15),
        (1.6, 4.5, 2.1, 1.5, -22),
        (-2.2, 10.2, 2.3, 1.6, 8),
        (-4.5, 15.8, 2.4, 1.7, -14),
        (-11.2, 14.2, 2.2, 1.5, 20),
        (-17.8, 13.8, 2.1, 1.4, -12),
        (-25.0, 13.2, 2.3, 1.5, 10),
        (5.8, 12.8, 2.2, 1.5, -18),
        (13.0, 14.5, 2.1, 1.4, 14),
        (21.5, 16.0, 2.3, 1.5, -10),
        (32.0, 18.2, 2.1, 1.4, 22),
        (-36.0, 10.5, 2.2, 1.5, -15),
    ]
    for idx, (sx, sz, rx_s, rz_s, yaw_deg) in enumerate(stepping_stones):
        n_sides = 6
        yaw = math.radians(yaw_deg)
        ca, sa = math.cos(yaw), math.sin(yaw)
        pts = []
        for s in range(n_sides):
            a = 2.0 * math.pi * s / n_sides + rng.uniform(-0.18, 0.18)
            lx = math.cos(a) * rx_s * rng.uniform(0.82, 1.12)
            lz = math.sin(a) * rz_s * rng.uniform(0.82, 1.12)
            pts.append((sx + lx * ca - lz * sa, sz + lx * sa + lz * ca))
        add_poly_slab_rbx(bm, uv, pts, 0.02, rng.uniform(0.09, 0.12), c_step, bevel_inset=0.14)

    return finalize_mesh_obj("Outskirts_Pathway", bm, mat_ground, col)


def build_outskirts_lush_bush(mat_ground: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """Plump multi-lobed stylized leafy bush matching the reference image (~360 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    c_dark = (2, 1)
    c_mid = (3, 1)
    c_hi = (2, 2)

    lobes = [
        (0.0, 1.30, 0.0, 1.75, 1.38, 1.75, c_mid, 6001),
        (1.08, 0.90, 0.70, 1.24, 1.06, 1.24, c_dark, 6002),
        (-1.12, 0.95, 0.58, 1.28, 1.08, 1.24, c_dark, 6003),
        (0.58, 0.92, -1.12, 1.22, 1.06, 1.22, c_dark, 6004),
        (-0.70, 0.88, -1.04, 1.20, 1.04, 1.20, c_dark, 6005),
        (0.70, 1.72, 0.44, 1.10, 0.98, 1.10, c_hi, 6006),
        (-0.66, 1.76, -0.32, 1.08, 0.96, 1.08, c_hi, 6007),
        (0.0, 2.15, 0.10, 1.02, 0.88, 1.02, c_hi, 6008),
    ]
    for lx, ly, lz, sx, sy, sz, cell, seed in lobes:
        add_faceted_rock_rbx(bm, uv, (lx, ly, lz), (sx, sy, sz), cell, seed=seed, subdiv=1, yaw_deg=seed * 19.0)

    for f in bm.faces:
        f.smooth = True

    return finalize_mesh_obj("Outskirts_LushBush", bm, mat_ground, col)


def build_outskirts_woodland_fern(mat_ground: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """Radial star rosette of 9 arched woodland fern fronds (~90 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(6101)
    c_fern = (3, 1)
    u0, u1, v0, v1 = cell_uv_bounds(c_fern[0], c_fern[1])

    n_fronds = 9
    for i in range(n_fronds):
        ang = (i / n_fronds) * 2.0 * math.pi + rng.uniform(-0.18, 0.18)
        length = rng.uniform(1.55, 2.05)
        arch_h = rng.uniform(0.75, 1.15)
        w = rng.uniform(0.32, 0.44)
        ca, sa = math.cos(ang), math.sin(ang)
        px, pz = -sa, ca

        # 3-segment arched blade: root -> mid-rise -> arch-peak -> tip-drop
        pts = [
            (0.0, 0.04, 0.0, w * 0.25, 0.0),
            (ca * length * 0.35, arch_h * 0.82, sa * length * 0.35, w, 0.38),
            (ca * length * 0.72, arch_h, sa * length * 0.72, w * 0.78, 0.74),
            (ca * length, arch_h * 0.36, sa * length, 0.03, 1.0),
        ]
        rings = []
        for cx, cy, cz, hw, tv in pts:
            if hw <= 0.04:
                v_tip = bm.verts.new(rbx_to_blender(cx, cy, cz))
                rings.append((v_tip,))
            else:
                vl = bm.verts.new(rbx_to_blender(cx + px * hw, cy - 0.06, cz + pz * hw))
                vc = bm.verts.new(rbx_to_blender(cx, cy + 0.05, cz))
                vr = bm.verts.new(rbx_to_blender(cx - px * hw, cy - 0.06, cz - pz * hw))
                rings.append((vl, vc, vr, tv))

        # Root to segment 1, segment 1 to 2, segment 2 to tip
        for s_i in range(2):
            r0 = rings[s_i]
            r1 = rings[s_i + 1]
            tv0, tv1 = r0[3], r1[3]
            f_l = bm.faces.new([r0[0], r0[1], r1[1], r1[0]])
            f_l.loops[0][uv].uv = (u0, v0 + (v1 - v0) * tv0)
            f_l.loops[1][uv].uv = ((u0 + u1) * 0.5, v0 + (v1 - v0) * tv0)
            f_l.loops[2][uv].uv = ((u0 + u1) * 0.5, v0 + (v1 - v0) * tv1)
            f_l.loops[3][uv].uv = (u0, v0 + (v1 - v0) * tv1)
            f_r = bm.faces.new([r0[1], r0[2], r1[2], r1[1]])
            f_r.loops[0][uv].uv = ((u0 + u1) * 0.5, v0 + (v1 - v0) * tv0)
            f_r.loops[1][uv].uv = (u1, v0 + (v1 - v0) * tv0)
            f_r.loops[2][uv].uv = (u1, v0 + (v1 - v0) * tv1)
            f_r.loops[3][uv].uv = ((u0 + u1) * 0.5, v0 + (v1 - v0) * tv1)
        r_last = rings[2]
        v_tip = rings[3][0]
        ft_l = bm.faces.new([r_last[0], r_last[1], v_tip])
        ft_l.loops[0][uv].uv = (u0, v0 + (v1 - v0) * 0.74)
        ft_l.loops[1][uv].uv = ((u0 + u1) * 0.5, v0 + (v1 - v0) * 0.74)
        ft_l.loops[2][uv].uv = ((u0 + u1) * 0.5, v1)
        ft_r = bm.faces.new([r_last[1], r_last[2], v_tip])
        ft_r.loops[0][uv].uv = ((u0 + u1) * 0.5, v0 + (v1 - v0) * 0.74)
        ft_r.loops[1][uv].uv = (u1, v0 + (v1 - v0) * 0.74)
        ft_r.loops[2][uv].uv = ((u0 + u1) * 0.5, v1)

    return finalize_mesh_obj("Outskirts_WoodlandFern", bm, mat_ground, col)


def build_outskirts_mossy_boulder(mat_ground: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """Chiseled faceted slate boulder with sculpted green moss cap (~140 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    add_faceted_rock_rbx(bm, uv, (0.0, 0.95, 0.0), (2.25, 1.48, 1.95), (0, 2), seed=6201, subdiv=1, yaw_deg=15.0)
    add_faceted_rock_rbx(bm, uv, (0.85, 0.55, 0.65), (1.15, 0.82, 1.05), (0, 2), seed=6202, subdiv=1, yaw_deg=60.0)
    add_faceted_rock_rbx(bm, uv, (-0.25, 1.82, 0.15), (1.10, 0.36, 0.95), (2, 1), seed=6203, subdiv=1, yaw_deg=25.0)
    return finalize_mesh_obj("Outskirts_MossyBoulder", bm, mat_ground, col)


def build_outskirts_grass_tuft(mat_ground: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """Low-poly 7-blade forest grass clump (~21 tris)."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    add_grass_tuft_rbx(bm, uv, (0.0, 0.0, 0.0), 1.0, (2, 1), seed=6301, blades=7)
    return finalize_mesh_obj("Outskirts_GrassTuft", bm, mat_ground, col)


# ---------------------------------------------------------------------------
# 5. Preview Scene Context & EEVEE Render (Matches Reference Camera)
# ---------------------------------------------------------------------------
def build_preview_context(ctx_col: bpy.types.Collection, mat_ground: bpy.types.Material, mat_props: bpy.types.Material) -> None:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    # Meadow grass plane covering outskirts (GP X=-72..+72, Z=-36..+64)
    add_box_rbx(bm, uv, (0.0, -0.15, 14.0), (144.0, 0.30, 100.0), (3, 2))
    # Rear dividing castle wall + gatehouse proxy at GP Z = -36 (Plot Z = 60)
    add_box_rbx(bm, uv, (-28.0, 10.0, -39.0), (54.0, 20.0, 6.0), (0, 2))
    add_box_rbx(bm, uv, (28.0, 10.0, -39.0), (36.0, 20.0, 6.0), (0, 2))
    add_box_rbx(bm, uv, (2.0, 16.5, -39.0), (16.0, 7.0, 6.0), (0, 2))
    # Merlons
    for mx in range(-50, 48, 7):
        add_box_rbx(bm, uv, (float(mx), 21.2, -37.2), (3.4, 2.4, 1.6), (1, 0))
    # Flanking gate doors
    add_box_rbx(bm, uv, (-3.6, 6.0, -35.8), (1.0, 12.0, 4.2), (0, 0))
    add_box_rbx(bm, uv, (7.6, 6.0, -35.8), (1.0, 12.0, 4.2), (0, 0))

    # Proxy dark pines matching OutskirtsEnvironmentBuilder framing
    pine_spots = [
        (-23.0, -24.0, 1.0), (-36.0, -16.0, 1.2), (-34.0, 22.0, 1.15), (-26.0, 34.0, 1.05),
        (28.0, -27.0, 1.1), (36.0, -20.0, 1.2), (27.0, -7.0, 1.02), (38.0, -10.0, 1.18),
        (25.0, 10.0, 1.08), (36.0, 20.0, 1.18), (28.0, 32.0, 1.15),
    ]
    for px, pz, sc in pine_spots:
        add_prism_y_rbx(bm, uv, (px, 4.0 * sc, pz), 1.0 * sc, 0.7 * sc, 8.0 * sc, 6, (0, 1), (1, 1))
        for tier, (ty, tr, th) in enumerate([(4.5, 5.4, 5.0), (7.8, 4.5, 4.8), (11.2, 3.4, 4.6), (14.4, 2.2, 4.4)]):
            add_prism_y_rbx(bm, uv, (px, ty * sc, pz), tr * sc, 0.35 * sc, th * sc, 7, (3, 2), (2, 1))

    # Scatter preview instances of bushes, ferns, boulders at exact Plot-relative positions
    finalize_mesh_obj("Preview_Backdrop", bm, mat_ground, ctx_col)

    bush_src = bpy.data.objects.get("Outskirts_LushBush")
    fern_src = bpy.data.objects.get("Outskirts_WoodlandFern")
    boulder_src = bpy.data.objects.get("Outskirts_MossyBoulder")

    def inst(src, p_plot: tuple[float, float, float], sc: float, yaw_deg: float):
        if not src:
            return
        dup = bpy.data.objects.new(f"Prev_{src.name}", src.data)
        gx, gy, gz = plot_to_gp(*p_plot)
        dup.location = rbx_to_blender(gx, gy, gz)
        dup.scale = (sc, sc, sc)
        dup.rotation_euler = (0.0, 0.0, math.radians(yaw_deg))
        ctx_col.objects.link(dup)

    for b_p, sc in [
        ((23.5, 0.0, 65.5), 1.0), ((25.5, 0.0, 69.5), 0.85), ((1.5, 0.0, 66.5), 0.95),
        ((-3.5, 0.0, 103.5), 0.92), ((4.0, 0.0, 104.5), 0.85),
        ((-1.0, 0.0, 121.0), 1.0), ((-6.0, 0.0, 126.5), 1.05), ((23.5, 0.0, 106.5), 1.05),
    ]:
        inst(bush_src, b_p, sc, b_p[0] * 17.0)

    for f_p, sc in [
        ((-2.5, 0.0, 67.5), 1.0), ((1.5, 0.0, 103.5), 1.05),
        ((34.0, 0.0, 99.5), 1.0), ((38.0, 0.0, 79.0), 0.95), ((-15.0, 0.0, 118.0), 1.0),
    ]:
        inst(fern_src, f_p, sc, f_p[2] * 13.0)

    for r_p, sc, yw in [
        ((30.5, 0.0, 110.0), 1.35, 30.0), ((44.5, 0.0, 81.0), 1.25, 115.0),
    ]:
        inst(boulder_src, r_p, sc, yw)


def render_preview(out_png: Path, ctx_col: bpy.types.Collection) -> None:
    scene = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 900
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(out_png)

    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg:
        bg.inputs[0].default_value = (0.16, 0.24, 0.32, 1.0)
        bg.inputs[1].default_value = 0.75

    # Cool forest twilight moonlight fill
    sun_d = bpy.data.lights.new("MoonKey", type="SUN")
    sun_d.energy = 1.4
    sun_d.color = (0.72, 0.84, 1.0)
    sun = bpy.data.objects.new("MoonKey", sun_d)
    sun.rotation_euler = Euler((math.radians(48.0), math.radians(15.0), math.radians(140.0)), "XYZ")
    ctx_col.objects.link(sun)

    # Warm point lights: Campfire, Tower Lantern, Gate Torches
    lt_specs = [
        ("CampfireLight", CAMPFIRE_POS_RBX[0], 1.8, CAMPFIRE_POS_RBX[2], 320.0, (1.0, 0.56, 0.14)),
        ("TowerLantern", *tower_local_to_gp(4.5, 12.2, 4.5), 140.0, (1.0, 0.68, 0.22)),
        ("GateTorchL", -8.6, 10.5, -35.0, 120.0, (1.0, 0.58, 0.16)),
        ("GateTorchR", 12.6, 10.5, -35.0, 120.0, (1.0, 0.58, 0.16)),
    ]
    for name, gx, gy, gz, energy, col_rgb in lt_specs:
        ld = bpy.data.lights.new(name, type="POINT")
        ld.energy = energy
        ld.color = col_rgb
        ld.shadow_soft_size = 0.6
        lo = bpy.data.objects.new(name, ld)
        lo.location = rbx_to_blender(gx, gy, gz)
        ctx_col.objects.link(lo)

    cam_d = bpy.data.cameras.new("PreviewCam")
    cam_d.lens = 28.0
    cam = bpy.data.objects.new("PreviewCam", cam_d)
    ctx_col.objects.link(cam)
    scene.camera = cam

    # Camera in Plot space (-16, 42, 136) -> GP (-28, 42, 40) looking at Plot (14, 4, 82) -> GP (2, 4, -14)
    cam_pos = rbx_to_blender(*plot_to_gp(-16.0, 40.0, 136.0))
    tgt_pos = rbx_to_blender(*plot_to_gp(14.0, 3.5, 82.0))
    cam.location = cam_pos
    cam.rotation_euler = (tgt_pos - cam_pos).normalized().to_track_quat("-Z", "Y").to_euler()

    out_png.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"[OutskirtsGuardhouse] Rendered preview -> {out_png}")


# ---------------------------------------------------------------------------
# 6. Main Pipeline
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Outskirts Guardhouse FBX & PBR textures")
    parser.add_argument("--no-render", action="store_true")
    parser.add_argument("--preview-out", type=Path, default=DEFAULT_PREVIEW_PATH)
    cli_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args, _ = parser.parse_known_args(cli_args)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    col_gp = bpy.data.collections.new("OutskirtsGuardhouse_Prefab")
    col_env = bpy.data.collections.new("OutskirtsEnvironment_Prefab")
    scene.collection.children.link(col_gp)
    scene.collection.children.link(col_env)

    print("[OutskirtsGuardhouse] Generating PBR textures...")
    g_col, g_nrm, g_rgh = generate_guardpost_ground_textures()
    p_col, p_nrm, p_rgh = generate_guardpost_props_textures()
    m_col, m_nrm, m_rgh = generate_outskirts_meadow_textures()

    mat_ground = create_pbr_material("Mat_GuardpostGround", g_col, g_nrm, g_rgh)
    mat_props = create_pbr_material("Mat_GuardpostProps", p_col, p_nrm, p_rgh)

    print("[OutskirtsGuardhouse] Building Guardhouse facility meshes...")
    tri_gp: dict[str, int] = {}
    gp_objs: list[bpy.types.Object] = []
    for builder, mat in (
        (build_guardtower_cobblepad, mat_ground),
        (build_guardtower_structure, mat_props),
        (build_guardtower_roof, mat_props),
        (build_guardtower_props, mat_props),
        (build_campfire_area, mat_props),
        (build_campfire_stone_hearth, mat_ground),
        (build_outskirts_fence, mat_props),
    ):
        obj, tris = builder(mat, col_gp)
        tri_gp[obj.name] = tris
        gp_objs.append(obj)

    total_gp_tris = sum(tri_gp.values())
    print(f"[OutskirtsGuardhouse] Guardhouse Facility Tris: {total_gp_tris}")
    for k, v in tri_gp.items():
        print(f"  - {k}: {v} tris")
    assert total_gp_tris < 6500, f"Guardhouse triangle budget exceeded: {total_gp_tris} >= 6500"

    print("[OutskirtsGuardhouse] Building Outskirts Environment Kit meshes...")
    tri_env: dict[str, int] = {}
    env_objs: list[bpy.types.Object] = []
    for builder in (
        build_outskirts_pathway,
        build_outskirts_lush_bush,
        build_outskirts_woodland_fern,
        build_outskirts_mossy_boulder,
        build_outskirts_grass_tuft,
    ):
        obj, tris = builder(mat_ground, col_env)
        tri_env[obj.name] = tris
        env_objs.append(obj)

    total_env_tris = sum(tri_env.values())
    print(f"[OutskirtsGuardhouse] Environment Kit Tris: {total_env_tris}")
    for k, v in tri_env.items():
        print(f"  - {k}: {v} tris")

    def export_fbx(objs: list[bpy.types.Object], out_path: Path):
        out_path.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.fbx(
            filepath=str(out_path),
            use_selection=True,
            object_types={"MESH"},
            use_mesh_modifiers=True,
            mesh_smooth_type="FACE",
            axis_forward="Z",
            axis_up="Y",
            apply_unit_scale=True,
            apply_scale_options="FBX_SCALE_UNITS",
            bake_space_transform=False,
            path_mode="COPY",
            embed_textures=True,
        )
        print(f"[OutskirtsGuardhouse] Exported {out_path} ({out_path.stat().st_size} bytes)")

    export_fbx(gp_objs, FBX_GUARDPOST_PATH)
    export_fbx(env_objs, FBX_ENVKIT_PATH)

    # Compute exact bounding box sizes & centers in Guardpost-local Roblox space for manifest verification
    def bbox_rbx(obj: bpy.types.Object) -> dict:
        pts = [Vector(c) for c in obj.bound_box]
        # Blender (bx, by, bz) -> Roblox (bx, bz, -by)
        r_pts = [(p.x, p.z, -p.y) for p in pts]
        xs, ys, zs = [p[0] for p in r_pts], [p[1] for p in r_pts], [p[2] for p in r_pts]
        pos = [round((min(xs) + max(xs)) * 0.5, 4), round((min(ys) + max(ys)) * 0.5, 4), round((min(zs) + max(zs)) * 0.5, 4)]
        sz = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)]
        return {"pos": pos, "size": sz, "pivot_offset": [-pos[0], -pos[1], -pos[2]]}

    manifest = {
        "gp_plot_origin": list(GP_PLOT_ORIGIN),
        "guardpost_tris": total_gp_tris,
        "guardpost_tri_breakdown": tri_gp,
        "env_kit_tris": total_env_tris,
        "env_kit_tri_breakdown": tri_env,
        "tower_pos_local": list(TOWER_POS_RBX),
        "tower_yaw_deg": TOWER_YAW_DEG,
        "lantern_pos_local": [round(v, 4) for v in tower_local_to_gp(4.35, 12.15, 4.35)],
        "campfire_pos_local": list(CAMPFIRE_POS_RBX),
        "palisade_points_local": [list(p) for p in PALISADE_POINTS],
        "split_rail_points_local": [list(p) for p in SPLIT_RAIL_POINTS],
        "guardpost_meshes": {o.name: bbox_rbx(o) for o in gp_objs},
        "env_kit_meshes": {o.name: bbox_rbx(o) for o in env_objs},
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
            "meadow": {
                "color": str(m_col.relative_to(REPO_ROOT).as_posix()),
                "normal": str(m_nrm.relative_to(REPO_ROOT).as_posix()),
                "roughness": str(m_rgh.relative_to(REPO_ROOT).as_posix()),
            },
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"[OutskirtsGuardhouse] Wrote manifest -> {MANIFEST_PATH}")

    if not args.no_render:
        ctx_col = bpy.data.collections.new("Preview_Context")
        scene.collection.children.link(ctx_col)
        # Hide standalone reusable template meshes at origin so only Pathway + Guardhouse show in hero shot
        for tname in ("Outskirts_LushBush", "Outskirts_WoodlandFern", "Outskirts_MossyBoulder", "Outskirts_GrassTuft"):
            to = bpy.data.objects.get(tname)
            if to:
                to.hide_render = True
        build_preview_context(ctx_col, mat_ground, mat_props)
        render_preview(args.preview_out, ctx_col)


if __name__ == "__main__":
    main()
