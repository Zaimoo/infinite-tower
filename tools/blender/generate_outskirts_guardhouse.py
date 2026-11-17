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
FBX_GROUND_PATH = ASSET_DIR / "OutskirtsGround.fbx"
FBX_ENVKIT_PATH = ASSET_DIR / "OutskirtsEnvironmentKit.fbx"
MANIFEST_PATH = ASSET_DIR / "outskirts_guardhouse_manifest.json"
DEFAULT_PREVIEW_PATH = (
    Path(r"C:\Users\enter\.gemini\antigravity\brain\1f0596d8-a4d0-45c0-9724-9721c02d88c0\scratch")
    / "outskirts_guardhouse_preview.png"
)

TEX_SIZE = 1024
CELL_PX = 256
CELL_PAD_PX = 14

# 6 seamless regional dirt-splat chunks covering the entire trail, campfire yard, and tower plaza
# (21-38 px/stud effective sharpness with 4px world-continuous extrapolated gutter per tile)
PATH_CHUNKS: list[tuple[str, float, float, float, float]] = [
    ("Ground_Path_NW", -28.0, -3.0, -36.5, 1.5),
    ("Ground_Path_NE", -3.0, 25.0, -36.5, 1.5),
    ("Ground_Path_SW", -28.0, -3.0, 1.5, 29.5),
    ("Ground_Path_SE", -3.0, 25.0, 1.5, 29.5),
    ("Ground_Path_WestWing", -74.0, -28.0, -6.0, 28.0),
    ("Ground_Path_EastWing", 25.0, 62.0, -6.0, 28.0),
]

# Guardpost-local origin corresponds to Plot-local (12, 0, 96)
GP_PLOT_ORIGIN = (12.0, 0.0, 96.0)

# Guard Tower center in Guardpost-local coordinates -> Plot-local (28.5, 0, 81.5)
TOWER_POS_RBX = (16.5, 0.0, -14.5)
TOWER_YAW_DEG = -82.0  # +Z_tower faces Front-Left (pathway/campfire), +X_tower faces Front-Right (ladder/roof)

# Campfire center in Guardpost-local coordinates -> Plot-local (-2.0, 0, 89.5)
CAMPFIRE_POS_RBX = (-14.0, 0.0, -6.5)

# Fence polyline in Guardpost-local coordinates
PALISADE_POINTS: list[tuple[float, float]] = []
SPLIT_RAIL_POINTS = [
    (-34.2, 1.8),   # Western shoulder along left half of E-W dirt path
    (-29.5, 3.8),   # Hugging dirt edge of E-W trail
    (-24.0, 6.2),   # Hugging dirt edge of E-W trail
    (-18.5, 7.6),   # Hugging dirt edge below campfire
    (-13.2, 8.6),   # Hugging dirt bend right beside fork stepping stones
    (-8.0, 8.2),    # Fork corner shoulder right next to connector stones
    (-5.4, 3.8),    # Connector dirt edge running north toward campfire entry
    (-5.2, -0.6),   # Connector path terminal post leaving campfire entryway open
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

    # (0,0) Sculpted Single Cool Mossy River Cobble (for individual 3D stones on GuardTower_CobblePad — crisp, no sub-grid noise)
    n_cb = fbm_grid(CELL_PX, CELL_PX, 102, (32, 16))
    edge_dist = np.maximum(np.abs(uu - 0.5), np.abs(vv - 0.5)) * 2.0
    rim_cb = np.exp(-((edge_dist - 0.84) * 10.0) ** 2) * 18.0
    bev_cb = np.clip(1.0 - (edge_dist ** 3.2) * 0.46, 0.54, 1.0)
    moss_cb = np.clip((n_cb - 0.62) * 2.2, 0.0, 0.35)[..., None]
    stone_base_00 = (np.array([76.0, 82.0, 88.0]) + n_cb[..., None] * np.array([22.0, 22.0, 24.0]) + rim_cb[..., None]) * bev_cb[..., None]
    rgb_00 = stone_base_00 * (1.0 - moss_cb) + np.array([42.0, 64.0, 36.0]) * moss_cb
    _put_cell(col, height, rough, (0, 0), rgb_00, 0.44 + 0.34 * bev_cb + 0.14 * n_cb, 0.84 - 0.04 * n_cb)

    # (1,0) Stylized Smooth Cool Slate Stepping Stone (borderless matte blue-slate; 3D bevels handle edge rim lighting)
    n_st = fbm_grid(CELL_PX, CELL_PX, 111, (64, 32, 16))
    n_st2 = fbm_grid(CELL_PX, CELL_PX, 113, (12, 6))
    grad_st = (uu * 0.25 + vv * 0.65) * 0.14 + n_st * 0.16
    crack_line = np.exp(-(((uu - 0.42) * 1.4 + (vv - 0.55) * 0.9 - (n_st - 0.5) * 0.22) * 26.0) ** 2) * 0.12
    rgb_10 = (np.array([72.0, 83.0, 96.0]) + grad_st[..., None] * np.array([22.0, 24.0, 28.0]) + n_st2[..., None] * 6.0) * (1.0 - crack_line[..., None])
    _put_cell(col, height, rough, (1, 0), rgb_10, 0.52 + 0.26 * n_st + 0.12 * n_st2 - crack_line * 0.35, 0.80 - 0.04 * n_st)

    # (2,0) Gatehouse Flagstone A — Borderless Warm-Cool Weathered Limestone-Slate (no repeating square frame)
    n_gt = fbm_grid(CELL_PX, CELL_PX, 121, (64, 32, 16))
    n_gt2 = fbm_grid(CELL_PX, CELL_PX, 125, (14, 7))
    pit_gt = np.clip((0.36 - n_gt2) * 2.5, 0.0, 1.0)
    rgb_20 = (
        np.array([76.0, 74.0, 74.0])
        + n_gt[..., None] * np.array([18.0, 17.0, 16.0])
        + n_gt2[..., None] * np.array([8.0, 8.0, 7.0])
    ) * (1.0 - pit_gt[..., None] * 0.14)
    _put_cell(col, height, rough, (2, 0), rgb_20, 0.48 + 0.28 * n_gt + 0.14 * n_gt2 - pit_gt * 0.18, 0.86 - 0.04 * n_gt)

    # (3,0) Trodden Dirt Pathway & Tower Pad Bed (cool smoky charcoal-umber matching Outskirts_Path)
    n_dt1 = fbm_grid(CELL_PX, CELL_PX, 131, (48, 24, 12, 6))
    n_dt2 = fbm_grid(CELL_PX, CELL_PX, 132, (8, 4))
    rgb_30 = np.array([42.0, 40.0, 39.0]) + n_dt1[..., None] * np.array([22.0, 21.0, 20.0]) + n_dt2[..., None] * 7.0
    _put_cell(col, height, rough, (3, 0), rgb_30, 0.36 + 0.36 * n_dt1 + 0.16 * n_dt2, 0.94 + 0.04 * (1.0 - n_dt1))

    # (0,1) Campfire Scorched Ash & Earth Ring (dark charcoal core -> cool smoky taupe rim)
    rad = np.sqrt((uu - 0.5) ** 2 + (vv - 0.5) ** 2) * 2.0
    ash_t = np.clip((rad - 0.25) / 0.55, 0.0, 1.0)
    ash_c = np.array([34.0, 32.0, 31.0]) + n_dt2[..., None] * 11.0
    rgb_01 = ash_c * (1.0 - ash_t[..., None]) + rgb_30 * ash_t[..., None]
    _put_cell(col, height, rough, (0, 1), rgb_01, 0.35 + 0.25 * n_dt2, 0.94)

    # (1,1) Campfire River Stones (warm fire-kissed grey-ochre cobble)
    n_rs = fbm_grid(CELL_PX, CELL_PX, 141, (32, 16, 8))
    rgb_11 = np.array([102.0, 96.0, 88.0]) + n_rs[..., None] * np.array([38.0, 34.0, 28.0])
    _put_cell(col, height, rough, (1, 1), rgb_11, 0.45 + 0.35 * n_rs, 0.82)

    # (2,1) Lush Forest Moss & Shaded Shrub Green (rich cool pine-forest emerald matching reference bushes)
    n_ms = fbm_grid(CELL_PX, CELL_PX, 151, (32, 16, 8, 4))
    streak = _hash_noise_2d(CELL_PX, CELL_PX, 6, 152)
    grad_v = np.clip(vv * 0.78 + 0.22 * streak, 0.0, 1.0)
    rgb_21 = (
        np.array([32.0, 58.0, 30.0]) * (1.0 - grad_v[..., None])
        + np.array([56.0, 94.0, 42.0]) * grad_v[..., None]
    ) * (0.88 + 0.22 * n_ms[..., None])
    _put_cell(col, height, rough, (2, 1), rgb_21, 0.42 + 0.32 * n_ms + 0.15 * streak, 0.88)

    # (3,1) Woodland Fern & Shrub Leaf (layered shaded emerald leaf with midrib)
    n_lf = fbm_grid(CELL_PX, CELL_PX, 161, (24, 12, 6))
    midrib = np.exp(-((uu - 0.5) * 14.0) ** 2) * 0.18
    vein = (np.sin((vv * 10.0 - np.abs(uu - 0.5) * 8.0) * math.pi) * 0.5 + 0.5) * 0.12
    leaf_base = np.array([36.0, 66.0, 32.0]) * (1.0 - vv[..., None]) + np.array([66.0, 106.0, 46.0]) * vv[..., None]
    rgb_31 = leaf_base * (0.90 + 0.18 * n_lf[..., None] + midrib[..., None] + vein[..., None] * 0.5)
    _put_cell(col, height, rough, (3, 1), rgb_31, 0.45 + 0.28 * midrib + 0.16 * vein + 0.12 * n_lf, 0.78)

    # (0,2) Faceted Boulder Slate Rock (cool grey stone + deep moss crevices)
    n_rk = fbm_grid(CELL_PX, CELL_PX, 171, (48, 24, 12))
    moss_flt = np.clip((fbm_grid(CELL_PX, CELL_PX, 172, (32, 16)) - 0.55) * 2.5, 0.0, 0.55)
    rk_c = np.array([72.0, 78.0, 86.0]) + n_rk[..., None] * np.array([28.0, 30.0, 32.0])
    rgb_02 = rk_c * (1.0 - moss_flt[..., None]) + np.array([38.0, 64.0, 34.0]) * moss_flt[..., None]
    _put_cell(col, height, rough, (0, 2), rgb_02, 0.42 + 0.36 * n_rk, 0.84)

    # (1,2) Dark Recessed Mortar & Earth Shadow Grout (for thin dark crevices between flagstones — NEVER bright tan!)
    rgb_12 = np.array([26.0, 25.0, 25.0]) + n_dt1[..., None] * np.array([12.0, 11.0, 10.0])
    _put_cell(col, height, rough, (1, 2), rgb_12, 0.22 + 0.20 * n_dt1, 0.96)

    # (2,2) Bush Sunlit Crown Foliage (cool mossy emerald, NOT neon cabbage lime)
    rgb_22 = (
        np.array([42.0, 74.0, 34.0]) * (1.0 - grad_v[..., None])
        + np.array([72.0, 112.0, 48.0]) * grad_v[..., None]
    ) * (0.90 + 0.16 * n_lf[..., None])
    _put_cell(col, height, rough, (2, 2), rgb_22, 0.45 + 0.25 * n_lf, 0.82)

    # (3,2) Deep Meadow Shadow Grass
    rgb_32 = np.array([26.0, 48.0, 26.0]) + n_ms[..., None] * np.array([18.0, 28.0, 16.0])
    _put_cell(col, height, rough, (3, 2), rgb_32, 0.40 + 0.25 * n_ms, 0.92)

    # Row 3: (0,3) Cool Dusk Slate Patio Variant, (2,3) Moss-Dusted Weathered Patio Variant, (1,3) Mid-grey Stone, (3,3) Foliage
    rgb_03 = np.array([66.0, 70.0, 77.0]) + n_gt[..., None] * np.array([16.0, 17.0, 19.0]) + n_gt2[..., None] * 7.0
    moss_patina = np.clip((fbm_grid(CELL_PX, CELL_PX, 189, (32, 16)) - 0.58) * 2.8, 0.0, 0.40)[..., None]
    rgb_23 = (np.array([72.0, 73.0, 70.0]) + n_gt[..., None] * np.array([16.0, 16.0, 14.0])) * (1.0 - moss_patina) + np.array([42.0, 62.0, 35.0]) * moss_patina
    for cx, (src_rgb, s_rgh) in enumerate(((rgb_03, 0.85), (rgb_10, 0.82), (rgb_23, 0.87), (rgb_21, 0.86))):
        _put_cell(col, height, rough, (cx, 3), src_rgb, 0.48 + 0.24 * n_gt + 0.12 * n_gt2, s_rgh)

    norm_rgb = height_to_normal_rgb(height, strength=3.0)
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


def _tileable_noise_aniso(res: int, cells_y: int, cells_x: int, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    grid = rng.random((cells_y, cells_x), dtype=np.float32)
    cy = np.linspace(0.0, cells_y, res, endpoint=False, dtype=np.float32)
    cx = np.linspace(0.0, cells_x, res, endpoint=False, dtype=np.float32)
    iy0 = np.floor(cy).astype(np.int32) % cells_y
    iy1 = (iy0 + 1) % cells_y
    ix0 = np.floor(cx).astype(np.int32) % cells_x
    ix1 = (ix0 + 1) % cells_x
    fy = cy - np.floor(cy)
    fx = cx - np.floor(cx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    ux = fx * fx * (3.0 - 2.0 * fx)
    g00 = grid[np.ix_(iy0, ix0)]
    g10 = grid[np.ix_(iy0, ix1)]
    g01 = grid[np.ix_(iy1, ix0)]
    g11 = grid[np.ix_(iy1, ix1)]
    nx0 = g00 * (1.0 - ux[None, :]) + g10 * ux[None, :]
    nx1 = g01 * (1.0 - ux[None, :]) + g11 * ux[None, :]
    return nx0 * (1.0 - uy[:, None]) + nx1 * uy[:, None]


def generate_outskirts_meadow_textures() -> tuple[Path, Path, Path]:
    """Generate 1024x1024 seamless stylized woodland moss & grass textures."""
    R = 1024
    n_macro = _tileable_noise(R, 4, 501) * 0.55 + _tileable_noise(R, 8, 502) * 0.45
    n_clump = _tileable_noise(R, 16, 503) * 0.55 + _tileable_noise(R, 32, 504) * 0.45
    n_blades = _tileable_noise_aniso(R, 56, 128, 505) * 0.55 + _tileable_noise_aniso(R, 112, 240, 506) * 0.45
    blade_mix = n_macro * 0.42 + n_clump * 0.30 + n_blades * 0.28

    # Deep cool pine-forest emerald meadow matching reference grass & pine needles
    c_dark = np.array([24.0, 45.0, 24.0], dtype=np.float32)
    c_mid = np.array([36.0, 67.0, 33.0], dtype=np.float32)
    c_hi = np.array([53.0, 90.0, 42.0], dtype=np.float32)
    t1 = np.clip((blade_mix - 0.18) * 2.6, 0.0, 1.0)[..., None]
    t2 = np.clip((blade_mix - 0.52) * 2.4, 0.0, 1.0)[..., None]
    rgb = np.where(blade_mix[..., None] < 0.52, c_dark * (1.0 - t1) + c_mid * t1, c_mid * (1.0 - t2) + c_hi * t2)

    # Organic dark emerald moss hollows & subtle grass blade highlights
    moss_hollow = np.clip((0.44 - n_macro) * 3.0, 0.0, 1.0)[..., None]
    rgb = rgb * (1.0 - 0.34 * moss_hollow) + np.array([20.0, 38.0, 22.0]) * (0.34 * moss_hollow)
    blade_fleck = np.clip((n_blades - 0.68) * 3.2, 0.0, 1.0)[..., None]
    rgb = rgb + blade_fleck * np.array([15.0, 24.0, 9.0])

    h_map = 0.26 + 0.46 * n_blades + 0.28 * n_clump
    r_u8 = np.clip((0.95 - 0.10 * n_blades) * 255.0, 175, 250).astype(np.uint8)
    norm_rgb = height_to_normal_rgb(h_map, strength=3.1)

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


def _hash2_int(ix: np.ndarray, iz: np.ndarray, seed: int) -> np.ndarray:
    n = (ix * 374761393 + iz * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    n = (n ^ (n >> 16)) & 0xFFFFFFFF
    return (n & 0xFFFFFF).astype(np.float32) / 16777216.0


def _world_value_noise(gx: np.ndarray, gz: np.ndarray, freq: float, seed: int) -> np.ndarray:
    sx = gx * freq
    sz = gz * freq
    ix0 = np.floor(sx).astype(np.int64)
    iz0 = np.floor(sz).astype(np.int64)
    fx = (sx - ix0).astype(np.float32)
    fz = (sz - iz0).astype(np.float32)
    ux = fx * fx * (3.0 - 2.0 * fx)
    uz = fz * fz * (3.0 - 2.0 * fz)
    v00 = _hash2_int(ix0, iz0, seed)
    v10 = _hash2_int(ix0 + 1, iz0, seed)
    v01 = _hash2_int(ix0, iz0 + 1, seed)
    v11 = _hash2_int(ix0 + 1, iz0 + 1, seed)
    return (v00 * (1.0 - ux) + v10 * ux) * (1.0 - uz) + (v01 * (1.0 - ux) + v11 * ux) * uz


def _world_fbm(gx: np.ndarray, gz: np.ndarray, freqs: tuple[float, ...], seed: int) -> np.ndarray:
    acc = np.zeros(gx.shape, dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for idx, f in enumerate(freqs):
        acc += amp * _world_value_noise(gx, gz, f, seed + idx * 97)
        norm += amp
        amp *= 0.5
    return acc / max(norm, 1e-6)


def _world_trail_stones(gx: np.ndarray, gz: np.ndarray, freq: float, seed: int) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Return (stone_height [0..1], stone_shade [0..1], rim_ao [0..1]) for organic irregular trail grit/pebbles."""
    w1 = _world_fbm(gx, gz, (freq * 1.4, freq * 2.8), seed + 17)
    w2 = _world_fbm(gx, gz, (freq * 1.5, freq * 2.9), seed + 31)
    sx = gx * freq + (w1 - 0.5) * 0.48
    sz = gz * freq + (w2 - 0.5) * 0.48
    ix = np.floor(sx).astype(np.int64)
    iz = np.floor(sz).astype(np.int64)
    best_h = np.zeros(gx.shape, dtype=np.float32)
    best_c = np.full(gx.shape, 0.5, dtype=np.float32)
    best_ao = np.zeros(gx.shape, dtype=np.float32)
    for dz in (-1, 0, 1):
        cz = iz + dz
        for dx in (-1, 0, 1):
            cx = ix + dx
            present = _hash2_int(cx, cz, seed) > 0.52
            px = cx + 0.18 + 0.64 * _hash2_int(cx, cz, seed + 1)
            pz = cz + 0.18 + 0.64 * _hash2_int(cx, cz, seed + 2)
            ang = _hash2_int(cx, cz, seed + 5) * math.pi
            ca, sa = np.cos(ang), np.sin(ang)
            aspect = 0.55 + 0.35 * _hash2_int(cx, cz, seed + 6)
            rad = 0.14 + 0.18 * _hash2_int(cx, cz, seed + 3)
            shade = _hash2_int(cx, cz, seed + 4)
            rx = sx - px
            rz = sz - pz
            ux = rx * ca + rz * sa
            uz = (-rx * sa + rz * ca) / aspect
            dist = np.sqrt(ux * ux + uz * uz) / np.maximum(rad, 1e-4)
            # Soft painterly embedded stone nodule (smooth gradient fade, zero cartoon outline ring)
            stone = np.clip((1.12 - dist) / 0.48, 0.0, 1.0)
            stone = stone * stone * (3.0 - 2.0 * stone)
            ao = np.clip(1.0 - dist / 1.35, 0.0, 1.0)
            stone = np.where(present, stone, 0.0)
            ao = np.where(present, ao, 0.0)
            best_ao = np.maximum(best_ao, ao)
            take = stone > best_h
            best_h = np.where(take, stone, best_h)
            best_c = np.where(take, shade, best_c)
    return best_h, best_c, best_ao


def _path_splat_curves():
    connector = [
        (2.0, -31.5, 5.4),
        (2.4, -22.5, 5.0),
        (2.2, -16.0, 5.1),
        (0.9, -9.8, 5.0),
        (0.1, -3.5, 5.1),
        (-0.4, 2.5, 5.4),
        (-1.1, 9.0, 5.8),
        (-1.4, 15.2, 6.2),
    ]
    ew_trail = []
    for k in range(25):
        px = -72.0 + k * (144.0 / 24.0)
        pz = 110.0 + math.sin(px * 0.055) * 6.0 + math.cos(px * 0.11) * 2.5
        gx, _, gz = plot_to_gp(px, 0.0, pz)
        hw = 5.0 + math.sin(k * 0.8) * 0.7
        ew_trail.append((gx, gz, hw))
    fire_spur = [
        (-14.2, -6.2, 4.4),
        (-9.6, -5.2, 3.3),
        (-4.5, -3.5, 3.2),
        (-0.2, -2.0, 4.4),
    ]
    # Bridge linking Guard Tower cobble yard cleanly into the main connector path
    tower_spur = [
        (16.5, -14.5, 6.4),
        (10.5, -13.8, 5.2),
        (2.2, -14.5, 4.8),
    ]
    return connector, ew_trail, fire_spur, tower_spur


def _sd_polygon_approx(gx: np.ndarray, gz: np.ndarray, poly: list[tuple[float, float]]) -> np.ndarray:
    """Exact signed distance to a convex/simple 2D polygon (negative inside, positive outside)."""
    n = len(poly)
    d_sq = np.full(gx.shape, 1e12, dtype=np.float32)
    inside = np.ones(gx.shape, dtype=bool)
    # Use ray casting parity for inside test + segment distance for magnitude
    inside.fill(False)
    j = n - 1
    for i in range(n):
        xi, zi = poly[i]
        xj, zj = poly[j]
        # Segment distance
        dx, dz = xj - xi, zj - zi
        l2 = max(1e-6, dx * dx + dz * dz)
        t = np.clip(((gx - xi) * dx + (gz - zi) * dz) / l2, 0.0, 1.0)
        ex = gx - (xi + t * dx)
        ez = gz - (zi + t * dz)
        d_sq = np.minimum(d_sq, ex * ex + ez * ez)
        # Ray-cast toggle
        cond = ((zi > gz) != (zj > gz)) & (gx < (xj - xi) * (gz - zi) / ((zj - zi) if abs(zj - zi) > 1e-6 else 1e-6) + xi)
        inside = inside ^ cond
        j = i
    dist = np.sqrt(d_sq)
    return np.where(inside, -dist, dist)


def eval_path_splat_sdf(gx: np.ndarray, gz: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Return signed trail distance (negative inside dirt), fire distance, and tower distance."""
    connector, ew_trail, fire_spur, tower_spur = _path_splat_curves()
    best_sd = np.full(gx.shape, 1e6, dtype=np.float32)

    def apply_polyline(pts):
        nonlocal best_sd
        for i in range(len(pts) - 1):
            ax, az, wa = pts[i]
            bx, bz, wb = pts[i + 1]
            dx, dz = bx - ax, bz - az
            len2 = max(1e-6, dx * dx + dz * dz)
            t = np.clip(((gx - ax) * dx + (gz - az) * dz) / len2, 0.0, 1.0)
            cx = ax + t * dx
            cz = az + t * dz
            w = wa + t * (wb - wa)
            d = np.sqrt((gx - cx) ** 2 + (gz - cz) ** 2) - w
            best_sd = np.minimum(best_sd, d)

    apply_polyline(connector)
    apply_polyline(ew_trail)
    apply_polyline(fire_spur)
    apply_polyline(tower_spur)

    # Gatehouse stone apron soil collar wrapping evenly around left & right corners of flagstones before grass
    dx_a = np.maximum(np.maximum(-6.0 - gx, gx - 8.6), 0.0)
    dz_a = np.maximum(np.maximum(-35.6 - gz, gz - (-27.8)), 0.0)
    sd_apron = np.sqrt(dx_a ** 2 + dz_a ** 2) - 1.35
    best_sd = np.minimum(best_sd, sd_apron)

    # Snug rounded Campfire dirt clearing around hearth, inner log ring & crate (leaving moss strip inside fence corners like reference)
    d_fire = np.sqrt((gx - CAMPFIRE_POS_RBX[0]) ** 2 + (gz - CAMPFIRE_POS_RBX[2]) ** 2)
    sd_fire_ring = d_fire - 5.1
    sd_crate_pad = np.sqrt((gx - (-9.6)) ** 2 + (gz - (-6.6)) ** 2) - 2.6
    best_sd = np.minimum(best_sd, np.minimum(sd_fire_ring, sd_crate_pad))

    d_tower = np.sqrt((gx - TOWER_POS_RBX[0]) ** 2 + (gz - TOWER_POS_RBX[2]) ** 2)
    return best_sd, d_fire, d_tower


def meadow_ground_height(gx: float, gz: float) -> float:
    """
    Shared deterministic ground relief sampled by BOTH Ground_GrassMeadow and all 6
    conformed Ground_Path_* overlays so path chunks never sink under meadow hills
    or create sharp mesh-intersection cuts across soft alpha feather skirts.
    """
    base_y = 0.020
    # Flatten across the entire navigable wing trail band (z = -6..30) and central clearing
    edge_x = max(0.0, (abs(gx + 4.0) - 42.0) / 34.0)
    edge_z = max(0.0, (gz - 27.0) / 26.0)
    if -4.0 <= gz <= 26.0:
        # Wing trails extend out to gx=-74 and gx=+62; suppress hills along the trail corridor
        trail_corridor = min(1.0, max(0.0, (abs(gz - 14.0) - 8.5) / 5.5))
        edge_x *= trail_corridor
    wall_fade = min(1.0, max(0.0, (gz - (-32.0)) / 6.0))
    mask = min(1.0, math.hypot(edge_x, edge_z)) * wall_fade
    if mask <= 0.01:
        return base_y
    undul = 0.5 + 0.5 * math.sin(gx * 0.14 + 0.5) * math.cos(gz * 0.16 - 0.3)
    return base_y + (mask * mask) * (0.14 + 0.52 * undul)


def generate_path_chunk_textures() -> dict[str, tuple[Path, Path, Path]]:
    """
    Generate 6 seamless 1024x1024 RGBA textured dirt chunks with 4px extrapolated border gutter
    using world-continuous smoky cool-taupe soil, mossy airbrush fringes, and charred campfire earth.
    """
    R = 1024
    gutter = 4.0
    t_vals = (np.arange(R, dtype=np.float32) + 0.5 - gutter) / (R - 2.0 * gutter)
    us = t_vals[None, :]
    vs = t_vals[:, None]

    # Dark cool charcoal-taupe earth palette matching reference dirt trail
    soil_shadow = np.array([35.0, 34.0, 33.0], dtype=np.float32)
    soil_mid = np.array([51.0, 49.0, 46.0], dtype=np.float32)
    soil_worn = np.array([68.0, 64.0, 60.0], dtype=np.float32)
    fringe_moss = np.array([26.0, 44.0, 24.0], dtype=np.float32)
    ash_col = np.array([26.0, 25.0, 25.0], dtype=np.float32)

    results: dict[str, tuple[Path, Path, Path]] = {}
    for name, x0, x1, z0, z1 in PATH_CHUNKS:
        gx, gz = np.meshgrid(
            (x0 + t_vals * (x1 - x0)).astype(np.float32),
            (z0 + t_vals * (z1 - z0)).astype(np.float32),
        )

        sd_base, d_fire, d_tower = eval_path_splat_sdf(gx, gz)

        n_macro = _world_fbm(gx, gz, (0.11, 0.24), 701)
        n_med = _world_fbm(gx, gz, (0.42, 0.85), 702)
        n_fine = _world_fbm(gx, gz, (1.6, 3.2, 6.4), 703)
        # Domain-warped painterly soil clods + crisp directional footpath ruts
        warp_x = gx + (n_med - 0.5) * 2.2 + (n_fine - 0.5) * 0.65
        warp_z = gz + (n_fine - 0.5) * 1.8
        n_soil = _world_fbm(warp_x, warp_z, (0.32, 0.78, 1.85), 740)

        # Tactile irregular embedded pebbles & fine gravel grit (NO bright round dots)
        st_med, st_med_c, st_med_ao = _world_trail_stones(gx, gz, 1.55, 761)
        st_fin, st_fin_c, st_fin_ao = _world_trail_stones(gx, gz, 3.85, 779)

        # Gentle organic border undulation so alpha feathers softly into deep green grass
        wobble = (n_macro - 0.5) * 2.3 + (n_med - 0.5) * 1.05
        sd = sd_base - wobble

        wall_fade = np.clip((gz - (-36.3)) / 0.8, 0.0, 1.0)
        t_edge = np.clip((1.25 - sd) / 2.55, 0.0, 1.0)
        alpha_raw = (t_edge * t_edge * (3.0 - 2.0 * t_edge)) ** 1.15
        alpha_final = np.clip(alpha_raw * wall_fade, 0.0, 1.0)

        core_t = np.clip((-sd) / 2.6, 0.0, 1.0)[..., None]
        loam_var = np.clip(0.38 * n_macro + 0.42 * n_soil + 0.20 * n_fine, 0.0, 1.0)[..., None]
        base_soil = soil_shadow * (1.0 - loam_var) + soil_mid * loam_var
        worn_patch = np.clip(core_t * (0.28 + 0.72 * n_soil[..., None]), 0.0, 1.0)
        soil_rgb = base_soil * (1.0 - worn_patch * 0.80) + soil_worn * (worn_patch * 0.80)

        # Softly darken recessed soil & blend subtle natural gravel nodules without harsh contour lines
        peb_mask = np.clip(core_t[..., 0] * 1.10, 0.0, 1.0)
        ao_dim = np.clip(st_med_ao * 0.14 * peb_mask, 0.0, 0.22)[..., None]
        soil_rgb = soil_rgb * (1.0 - ao_dim)

        med_col = np.array([50.0, 48.0, 47.0], dtype=np.float32) + st_med_c[..., None] * np.array([22.0, 20.0, 18.0], dtype=np.float32)
        fin_col = np.array([48.0, 46.0, 44.0], dtype=np.float32) + st_fin_c[..., None] * np.array([16.0, 15.0, 14.0], dtype=np.float32)
        soil_rgb = soil_rgb * (1.0 - st_fin[..., None] * peb_mask[..., None] * 0.30) + fin_col * (st_fin[..., None] * peb_mask[..., None] * 0.30)
        soil_rgb = soil_rgb * (1.0 - st_med[..., None] * peb_mask[..., None] * 0.38) + med_col * (st_med[..., None] * peb_mask[..., None] * 0.38)

        # Cool deep forest moss blend along outer edge
        rim_mix = np.clip((0.68 - alpha_final) / 0.62, 0.0, 1.0)[..., None]
        rgb = soil_rgb * (1.0 - rim_mix * 0.68) + fringe_moss * (rim_mix * 0.68)

        # Charred charcoal earth cleanly localized inside fire pit (radius ~ 2.2..4.2)
        ash_t = np.clip((4.0 - d_fire) / 2.2, 0.0, 1.0)[..., None]
        rgb = rgb * (1.0 - ash_t * 0.78) + (ash_col + n_fine[..., None] * 10.0) * (ash_t * 0.78)

        h_map = (
            0.28
            + 0.28 * n_soil
            + 0.16 * n_fine
            + 0.10 * n_macro
            + 0.18 * st_med * peb_mask
            + 0.10 * st_fin * peb_mask
            - 0.12 * st_med_ao * peb_mask
        )
        # World-metric normal gradients with stronger sculpted pebble/soil relief
        px_stud_x = (x1 - x0) / (R - 2.0 * gutter)
        px_stud_z = (z1 - z0) / (R - 2.0 * gutter)
        grad_x = (np.roll(h_map, -1, axis=1) - np.roll(h_map, 1, axis=1)) / (2.0 * px_stud_x)
        grad_z = (np.roll(h_map, -1, axis=0) - np.roll(h_map, 1, axis=0)) / (2.0 * px_stud_z)
        nrm_str = 0.48
        nx_a = -grad_x * nrm_str
        ny_a = grad_z * nrm_str
        nz_a = np.ones_like(h_map)
        inv_a = 1.0 / np.sqrt(nx_a * nx_a + ny_a * ny_a + nz_a * nz_a + 1e-8)
        norm_rgb = np.stack([
            np.clip((nx_a * inv_a * 0.5 + 0.5) * 255.0, 0, 255),
            np.clip((ny_a * inv_a * 0.5 + 0.5) * 255.0, 0, 255),
            np.clip((nz_a * inv_a * 0.5 + 0.5) * 255.0, 0, 255),
        ], axis=-1).astype(np.uint8)
        rough_val = np.clip((0.92 - 0.14 * core_t[..., 0] * n_soil) * 255.0, 155, 246).astype(np.uint8)

        tag = name.replace("Ground_Path_", "")
        p_col = TEX_DIR / f"Tex_OutskirtsPath_{tag}_Color.png"
        p_nrm = TEX_DIR / f"Tex_OutskirtsPath_{tag}_Normal.png"
        p_rgh = TEX_DIR / f"Tex_OutskirtsPath_{tag}_Roughness.png"
        write_png_rgba(p_col, np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), np.clip(alpha_final * 255.0, 0, 255).astype(np.uint8)]))
        write_png_rgba(p_nrm, np.dstack([norm_rgb, np.full((R, R), 255, dtype=np.uint8)]))
        write_png_rgba(p_rgh, np.dstack([rough_val, rough_val, rough_val, np.full((R, R), 255, dtype=np.uint8)]))
        results[name] = (p_col, p_nrm, p_rgh)
    return results


def create_pbr_material(name: str, p_col: Path, p_nrm: Path, p_rgh: Path, blend_alpha: bool = False) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Specular IOR Level"].default_value = 0.26
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def load_img(path: Path, colorspace: str):
        img = bpy.data.images.load(str(path), check_existing=True)
        img.colorspace_settings.name = colorspace
        return img

    tex_col = nt.nodes.new("ShaderNodeTexImage")
    tex_col.image = load_img(p_col, "sRGB")
    nt.links.new(tex_col.outputs["Color"], bsdf.inputs["Base Color"])
    if blend_alpha:
        nt.links.new(tex_col.outputs["Alpha"], bsdf.inputs["Alpha"])
        if hasattr(mat, "blend_method"):
            try:
                mat.blend_method = "BLEND"
            except Exception:
                pass

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
    cell_slate = (1, 0)
    cell_flag = (2, 0)

    # Dense organic rings of individual bevelled cobblestones directly over the dirt/meadow
    # (no flat polygonal base slab so edges feather naturally into the grass)
    rings = [
        (0.0, 1, 1.0),
        (1.65, 6, 1.0),
        (3.15, 11, 0.96),
        (4.55, 15, 0.88),
        (5.75, 19, 0.72),
    ]
    for r_idx, (r_dist, count, scale_f) in enumerate(rings):
        for i in range(count):
            ang = (2.0 * math.pi * i / count) + r_idx * 0.25 + rng.uniform(-0.18, 0.18)
            dist = r_dist + rng.uniform(-0.34, 0.34) if r_dist > 0.1 else 0.0
            lx = math.cos(ang) * dist
            lz = math.sin(ang) * dist
            # Keep perimeter feathered like a rounded organic cluster
            if abs(lx) > 6.2 or abs(lz) > 6.2:
                continue
            if r_idx == len(rings) - 1 and rng.random() < 0.15:
                continue
            rad_stone = rng.uniform(0.68, 1.02) * scale_f
            sides = 5
            stone_pts = []
            for s in range(sides):
                sa_a = 2.0 * math.pi * s / sides + rng.uniform(-0.22, 0.22)
                sr = rad_stone * rng.uniform(0.80, 1.18)
                px, _, pz = tower_local_to_gp(lx + math.cos(sa_a) * sr, 0.0, lz + math.sin(sa_a) * sr)
                stone_pts.append((px, pz))
            c_pick = cell_cobble if (i % 3 == 0) else (cell_slate if (i % 3 == 1) else cell_flag)
            add_poly_slab_rbx(
                bm, uv, stone_pts, 0.01, rng.uniform(0.08, 0.15),
                c_pick, bevel_inset=0.18
            )

    # 4 corner stone pier footings under the 4 timber stilts
    for sx in (-4.1, 4.1):
        for sz in (-4.1, 4.1):
            px, _, pz = tower_local_to_gp(sx, 0.0, sz)
            add_box_rbx(
                bm, uv, (px, 0.22, pz), (1.45, 0.44, 1.45), cell_slate,
                (0.0, math.radians(TOWER_YAW_DEG), 0.0)
            )

    # Outer moss & grass tufts hugging the cobblestone perimeter
    for k in range(12):
        a = (k / 12.0) * 2.0 * math.pi + rng.uniform(-0.15, 0.15)
        r = rng.uniform(5.2, 6.4)
        gx, gy, gz = tower_local_to_gp(math.cos(a) * r, 0.02, math.sin(a) * r)
        add_grass_tuft_rbx(bm, uv, (gx, gy, gz), rng.uniform(0.75, 1.08), cell_moss, seed=2100 + k, blades=5)

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

    c_timber = (0, 0)
    c_shingle = (2, 0)

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
                add_box_rbx(
                    bm, uv, (gx_s, gy_s, gz_s),
                    (row_step * 1.24, 0.15, col_step * 1.04),
                    c_shingle,
                    (0.0, yaw_rad, -s * (pitch - 0.07)),
                )

    # Heavy ridge cap beam sealing the apex cleanly
    rx, ry, rz = tower_local_to_gp(0.0, ridge_y + 0.18, 0.0)
    add_box_rbx(bm, uv, (rx, ry, rz), (0.68, 0.48, roof_len_z + 0.36), c_timber, (0.0, yaw_rad, 0.0))

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

    # Compact scorched ember/ash disc strictly inside the fire ring (radius ~ 2.25)
    # so there is no large hard-edged polygon under the log benches
    n_ash = 12
    ash_pts = [
        (fcx + math.cos(2.0 * math.pi * k / n_ash) * rng.uniform(2.05, 2.30),
         fcz + math.sin(2.0 * math.pi * k / n_ash) * rng.uniform(2.05, 2.30))
        for k in range(n_ash)
    ]
    add_poly_slab_rbx(bm, uv, ash_pts, 0.01, 0.07, c_ash, bevel_inset=0.10)

    # 12 Chunky River Stones around fire ring (radius ~ 2.36 studs) + 5 smaller wedge stones
    n_stones = 12
    for i in range(n_stones):
        ang = (2.0 * math.pi * i / n_stones) + rng.uniform(-0.08, 0.08)
        r = 2.36 + rng.uniform(-0.14, 0.14)
        sx = fcx + math.cos(ang) * r
        sz = fcz + math.sin(ang) * r
        add_faceted_rock_rbx(
            bm, uv, (sx, 0.34, sz),
            (rng.uniform(0.62, 0.88), rng.uniform(0.38, 0.56), rng.uniform(0.54, 0.76)),
            c_stone, seed=3200 + i, subdiv=1, yaw_deg=math.degrees(ang)
        )
    for j in range(5):
        ang = (2.0 * math.pi * (j + 0.5) / 5.0) + rng.uniform(-0.18, 0.18)
        r = 2.68 + rng.uniform(-0.15, 0.22)
        sx = fcx + math.cos(ang) * r
        sz = fcz + math.sin(ang) * r
        add_faceted_rock_rbx(
            bm, uv, (sx, 0.22, sz),
            (rng.uniform(0.34, 0.48), rng.uniform(0.24, 0.34), rng.uniform(0.32, 0.46)),
            c_stone, seed=3300 + j, subdiv=1, yaw_deg=rng.uniform(0, 360)
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

    # Open Heavy Pointed-Post Split-Rail Fence lining the left trail curve (no compact palisade stakes)
    for seg_idx in range(len(SPLIT_RAIL_POINTS) - 1):
        ax, az = SPLIT_RAIL_POINTS[seg_idx]
        bx, bz = SPLIT_RAIL_POINTS[seg_idx + 1]
        seg_len = math.hypot(bx - ax, bz - az)
        yaw = math.atan2(bx - ax, bz - az)
        n_bays = max(1, int(round(seg_len / 3.5)))
        for k in range(n_bays + 1):
            if seg_idx > 0 and k == 0:
                continue
            t = k / n_bays
            px = ax + (bx - ax) * t
            pz = az + (bz - az) * t
            is_corner = (k == 0 or k == n_bays)
            add_sharpened_stake(px, pz, 0.56, 4.45 if is_corner else 4.15, yaw)
        for ry in (1.35, 2.75):
            add_beam_between_rbx(bm, uv, (ax, ry, az), (bx, ry, bz), 0.34, 0.44, c_timber)

    return finalize_mesh_obj("Outskirts_Fence", bm, mat_props, col)


# ---------------------------------------------------------------------------
# 4. Unified Outskirts Ground (`OutskirtsGround.fbx` — Grass + 6 Splat Chunks + Stonework)
# ---------------------------------------------------------------------------
def build_ground_grass_meadow(mat_meadow: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """
    Build the continuous 160x100 forest meadow floor (`Ground_GrassMeadow`) in Guardpost-local
    coordinates (`Plot X=-80..+80, Z=60..160` -> `GP X=-92..+68, Z=-36..+64`) with tiled
    world-space UVs (`18` studs per tile) and gentle woodland perimeter undulations.
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    gx0, gx1 = -92.0, 68.0
    gz0, gz1 = -36.0, 64.0
    nx, nz = 80, 50
    tile_studs = 18.0

    grid: list[list[bmesh.types.BMVert]] = []
    for iz in range(nz + 1):
        gz = gz0 + (gz1 - gz0) * (iz / nz)
        row = []
        for ix in range(nx + 1):
            gx = gx0 + (gx1 - gx0) * (ix / nx)
            gy = meadow_ground_height(gx, gz)
            row.append(bm.verts.new(rbx_to_blender(gx, gy, gz)))
        grid.append(row)

    for iz in range(nz):
        for ix in range(nx):
            v00 = grid[iz][ix]
            v10 = grid[iz][ix + 1]
            v11 = grid[iz + 1][ix + 1]
            v01 = grid[iz + 1][ix]
            f = bm.faces.new([v00, v01, v11, v10])
            f.smooth = True
            for vert, loop in zip((v00, v01, v11, v10), f.loops):
                # In Blender coords: x = gx, y = -gz
                vx, vy = vert.co.x, vert.co.y
                loop[uv].uv = ((vx - gx0) / tile_studs, (vy + gz1) / tile_studs)

    return finalize_mesh_obj("Ground_GrassMeadow", bm, mat_meadow, col)


def build_ground_path_chunks(chunk_mats: dict[str, bpy.types.Material], col: bpy.types.Collection) -> list[tuple[bpy.types.Object, int]]:
    """Build 6 height-conformed rectangular dirt-splat grids (`+0.025` over meadow) with 4px world-continuous UV gutters."""
    gutter_uv = 4.0 / 1024.0
    u0, u1 = gutter_uv, 1.0 - gutter_uv
    v0, v1 = gutter_uv, 1.0 - gutter_uv
    y_offset = 0.025
    built = []
    for name, x0, x1, z0, z1 in PATH_CHUNKS:
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new("UVMap")
        nx_q, nz_q = 16, 16
        dx = (x1 - x0) / nx_q
        dz = (z1 - z0) / nz_q
        verts = []
        for iz in range(nz_q + 1):
            gz = z0 + iz * dz
            row = []
            for ix in range(nx_q + 1):
                gx = x0 + ix * dx
                row.append(bm.verts.new(rbx_to_blender(gx, meadow_ground_height(gx, gz) + y_offset, gz)))
            verts.append(row)
        for iz in range(nz_q):
            tv_top = v1 - (iz / nz_q) * (v1 - v0)
            tv_bot = v1 - ((iz + 1) / nz_q) * (v1 - v0)
            for ix in range(nx_q):
                tu_l = u0 + (ix / nx_q) * (u1 - u0)
                tu_r = u0 + ((ix + 1) / nx_q) * (u1 - u0)
                f = bm.faces.new([verts[iz][ix], verts[iz + 1][ix], verts[iz + 1][ix + 1], verts[iz][ix + 1]])
                f.smooth = True
                f.loops[0][uv].uv = (tu_l, tv_top)
                f.loops[1][uv].uv = (tu_l, tv_bot)
                f.loops[2][uv].uv = (tu_r, tv_bot)
                f.loops[3][uv].uv = (tu_r, tv_top)
        obj, tris = finalize_mesh_obj(name, bm, chunk_mats[name], col)
        built.append((obj, tris))
    return built


def build_ground_stonework(mat_ground: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """
    Build snugly fitted stylized Gatehouse Flagstone Patio (with dark mortar bed),
    15 clean beveled slate Stepping Stones + companion chips, and Guard Tower cobble bridge.
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rng = random.Random(5011)

    c_apron_warm = (2, 0)
    c_apron_cool = (0, 3)
    c_apron_moss = (2, 3)
    c_step = (1, 0)
    c_cobble = (0, 0)
    c_mortar = (3, 0)  # Natural smoky trail earth matching surrounding soil (no black Sharpie lines)

    # 1. Organic Broken-Course Gatehouse Flagstone Patio (extending through gate archway to cover Hub grass seam)
    # Recessed trail-earth bed kept strictly INSIDE the outer stones so zero box edge sticks out
    add_box_rbx(bm, uv, (2.0, 0.036, -37.4), (11.6, 0.032, 4.6), c_mortar)
    add_box_rbx(bm, uv, (1.2, 0.044, -32.2), (10.6, 0.048, 5.2), c_mortar)

    def clip_poly_halfplane(poly: list[tuple[float, float]], px: float, pz: float, nx: float, nz: float) -> list[tuple[float, float]]:
        """Clip 2D convex polygon against half-plane (q - p) . n <= 0."""
        if not poly:
            return []
        res: list[tuple[float, float]] = []
        n_pts = len(poly)
        for idx_p in range(n_pts):
            ax, az = poly[idx_p]
            bx, bz = poly[(idx_p + 1) % n_pts]
            da = (ax - px) * nx + (az - pz) * nz
            db = (bx - px) * nx + (bz - pz) * nz
            if da <= 0.0:
                res.append((ax, az))
                if db > 0.0:
                    t = da / (da - db)
                    res.append((ax + t * (bx - ax), az + t * (bz - az)))
            elif db <= 0.0:
                t = da / (da - db)
                res.append((ax + t * (bx - ax), az + t * (bz - az)))
        return res

    def clip_convex_hull(poly: list[tuple[float, float]], hull_ccw: list[tuple[float, float]]) -> list[tuple[float, float]]:
        """Clip convex polygon inside a closed CCW boundary polygon."""
        nh = len(hull_ccw)
        out = poly
        for ih in range(nh):
            ax, az = hull_ccw[ih]
            bx, bz = hull_ccw[(ih + 1) % nh]
            ex, ez = bx - ax, bz - az
            elen = max(1e-6, math.hypot(ex, ez))
            # Outward normal for CCW polygon in (x, z) is (ez, -ex) / elen; check interior centroid
            nx, nz = ez / elen, -ex / elen
            out = clip_poly_halfplane(out, ax, az, nx, nz)
            if len(out) < 3:
                return []
        return out

    def voronoi_stones_in_hull(seeds_list: list[tuple[float, float]], hull_pts: list[tuple[float, float]], half_gap: float) -> list[list[tuple[float, float]]]:
        # Ensure hull orientation matches inward half-planes around centroid
        hcx = sum(p[0] for p in hull_pts) / len(hull_pts)
        hcz = sum(p[1] for p in hull_pts) / len(hull_pts)
        fixed_planes: list[tuple[float, float, float, float]] = []
        for ih in range(len(hull_pts)):
            ax, az = hull_pts[ih]
            bx, bz = hull_pts[(ih + 1) % len(hull_pts)]
            ex, ez = bx - ax, bz - az
            elen = max(1e-6, math.hypot(ex, ez))
            nx, nz = ez / elen, -ex / elen
            if (hcx - ax) * nx + (hcz - az) * nz > 0.0:
                nx, nz = -nx, -nz
            fixed_planes.append((ax, az, nx, nz))

        cells_out: list[list[tuple[float, float]]] = []
        for idx_s, (sx, sz) in enumerate(seeds_list):
            poly = [(-18.0, -45.0), (22.0, -45.0), (22.0, -20.0), (-18.0, -20.0)]
            for ax, az, nx, nz in fixed_planes:
                poly = clip_poly_halfplane(poly, ax, az, nx, nz)
                if len(poly) < 3:
                    break
            for idx_n, (nx_p, nz_p) in enumerate(seeds_list):
                if idx_n == idx_s or len(poly) < 3:
                    continue
                vx = nx_p - sx
                vz = nz_p - sz
                dist_n = math.hypot(vx, vz)
                if dist_n < 1e-4 or dist_n > 7.5:
                    continue
                ux, uz = vx / dist_n, vz / dist_n
                mx = (sx + nx_p) * 0.5 - ux * half_gap
                mz = (sz + nz_p) * 0.5 - uz * half_gap
                poly = clip_poly_halfplane(poly, mx, mz, ux, uz)
            if len(poly) >= 3:
                cells_out.append(poly)
        return cells_out

    def chamfer_outer_poly(poly: list[tuple[float, float]], rand_gen: random.Random) -> list[tuple[float, float]]:
        """Break straight perimeter chords gently & round sharp corners on outer stones."""
        cx_p = sum(p[0] for p in poly) / len(poly)
        cz_p = sum(p[1] for p in poly) / len(poly)
        out: list[tuple[float, float]] = []
        np_len = len(poly)
        for k_p in range(np_len):
            ax, az = poly[k_p]
            bx, bz = poly[(k_p + 1) % np_len]
            # Slight organic tuck-in if vertex reaches patio outer perimeter (prevents ruler-straight edges)
            is_outer_a = (az > -34.7) and (ax < -4.4 or ax > 7.2 or az > -29.2)
            if is_outer_a:
                pull = rand_gen.uniform(0.84, 1.03)
                ax = cx_p + (ax - cx_p) * pull
                az = cz_p + (az - cz_p) * pull
            out.append((ax, az))
            seg_len = math.hypot(bx - ax, bz - az)
            if seg_len > 1.55 and is_outer_a:
                mx = (ax + bx) * 0.5 + rand_gen.uniform(-0.18, 0.22)
                mz = (az + bz) * 0.5 + rand_gen.uniform(-0.18, 0.22)
                # Keep polygon convex-friendly by bulging outward subtly toward stone normal
                dx_c, dz_c = mx - cx_p, mz - cz_p
                d_c = max(1e-4, math.hypot(dx_c, dz_c))
                out.append((mx + dx_c / d_c * rand_gen.uniform(0.06, 0.22), mz + dz_c / d_c * rand_gen.uniform(0.06, 0.22)))
        return out

    # Archway threshold slabs bridging smoothly through open wooden gate doors onto indoor bridge path
    arch_hull = [(-4.35, -39.9), (8.35, -39.9), (8.35, -35.05), (-4.35, -35.05)]
    arch_seeds = [
        (-2.6, -38.6), (0.6, -38.8), (3.8, -38.5), (6.9, -38.7),
        (-2.1, -36.3), (1.3, -36.1), (4.6, -36.4), (7.2, -36.1),
    ]
    arch_seeds = [(x + rng.uniform(-0.45, 0.45), z + rng.uniform(-0.32, 0.32)) for x, z in arch_seeds]
    for i_a, apoly in enumerate(voronoi_stones_in_hull(arch_seeds, arch_hull, 0.065)):
        c_pick = (c_apron_warm, c_apron_cool, c_apron_moss)[i_a % 3]
        add_poly_slab_rbx(bm, uv, apoly, 0.020, rng.uniform(0.082, 0.104), c_pick, bevel_inset=rng.uniform(0.12, 0.18))

    # Main Gatehouse Patio broken-course slabs inside organic non-rectangular 10-point perimeter
    patio_hull = [
        (-6.2, -34.9),
        (9.0, -34.9),
        (9.5, -32.4),
        (8.4, -29.6),
        (5.6, -27.8),
        (2.0, -27.3),
        (-2.0, -27.6),
        (-5.2, -29.0),
        (-6.8, -31.8),
    ]
    patio_seeds: list[tuple[float, float]] = []
    # Course 1 (wall plinth apron): uneven wide slabs
    for cx_s in (-4.8, -2.0, 0.8, 3.8, 6.9):
        patio_seeds.append((cx_s + rng.uniform(-0.45, 0.45), -34.0 + rng.uniform(-0.35, 0.35)))
    # Course 2 (mid apron): offset staggered slabs + smaller wedge
    for cx_s in (-5.5, -2.9, -0.3, 2.3, 5.1, 7.9):
        patio_seeds.append((cx_s + rng.uniform(-0.40, 0.40), -31.6 + rng.uniform(-0.45, 0.45)))
    # Course 3 (front organic apron curving onto trail)
    for cx_s in (-4.1, -1.3, 1.5, 4.3, 7.1):
        patio_seeds.append((cx_s + rng.uniform(-0.45, 0.45), -29.1 + rng.uniform(-0.42, 0.38)))

    for i_p, ppoly in enumerate(voronoi_stones_in_hull(patio_seeds, patio_hull, 0.070)):
        cpoly = chamfer_outer_poly(ppoly, rng)
        c_pick = (c_apron_warm, c_apron_cool, c_apron_warm, c_apron_moss)[(i_p * 7 + 3) % 4]
        add_poly_slab_rbx(bm, uv, cpoly, 0.025, rng.uniform(0.118, 0.165), c_pick, bevel_inset=rng.uniform(0.16, 0.22))

    # 10 irregular transition curb stones & pebble chips stepping organically around patio edges
    for idx, (bx, bz, brx, brz) in enumerate([
        (-7.1, -33.0, 0.72, 0.55), (-6.3, -30.2, 0.68, 0.52), (-3.8, -27.9, 0.88, 0.56),
        (-1.0, -26.8, 0.96, 0.62), (1.9, -26.5, 1.02, 0.64), (4.8, -27.1, 0.90, 0.56),
        (7.4, -28.4, 0.78, 0.52), (9.2, -30.6, 0.66, 0.50), (0.6, -28.1, 0.48, 0.38),
        (3.8, -26.4, 0.52, 0.40),
    ]):
        pts = [
            (bx + math.cos(2.0 * math.pi * k / 5 + idx * 0.4) * brx * rng.uniform(0.80, 1.15),
             bz + math.sin(2.0 * math.pi * k / 5 + idx * 0.4) * brz * rng.uniform(0.80, 1.15))
            for k in range(5)
        ]
        c_edge = c_step if (idx % 3 == 0) else (c_apron_cool if idx % 2 == 0 else c_apron_warm)
        add_poly_slab_rbx(bm, uv, pts, 0.025, rng.uniform(0.098, 0.138), c_edge, bevel_inset=0.19)

    # 2. Chunky Sculpted Slate Stepping Stones + Foreground/Pair Clusters Matching Reference
    def add_irregular_slab(sx: float, sz: float, rx_s: float, rz_s: float, yaw_deg: float, sides: int, y_t: float, seed_off: int, cell=c_step):
        r_loc = random.Random(5500 + seed_off)
        yaw = math.radians(yaw_deg)
        ca, sa = math.cos(yaw), math.sin(yaw)
        pts = []
        for s in range(sides):
            a = 2.0 * math.pi * s / sides + r_loc.uniform(-0.28, 0.28)
            rad_mul = r_loc.uniform(0.75, 1.18)
            lx = math.cos(a) * rx_s * rad_mul
            lz = math.sin(a) * rz_s * rad_mul
            pts.append((sx + lx * ca - lz * sa, sz + lx * sa + lz * ca))
        add_poly_slab_rbx(bm, uv, pts, 0.025, y_t, cell, bevel_inset=0.22)

    stepping_clusters = [
        (2.4, -23.6, 1.95, 1.28, 18, 5, [(-1.8, 0.9, 0.58), (1.7, -0.7, 0.46)]),
        (3.4, -18.4, 2.30, 1.45, -24, 6, [(2.0, 0.8, 0.60)]),
        (0.9, -13.0, 1.95, 1.40, 32, 5, [(-1.5, -0.8, 0.52), (1.4, 1.0, 0.44)]),
        (-0.3, -7.8, 2.30, 1.52, -14, 6, [(2.1, -0.5, 0.64), (-1.9, 0.7, 0.48)]),
        (-1.1, -1.8, 2.35, 1.55, 20, 5, [(-2.0, -0.9, 0.54)]),
        (1.6, 4.4, 2.20, 1.44, -28, 6, [(-1.6, 1.1, 0.52), (1.8, -0.8, 0.46)]),
        (-2.4, 10.4, 2.48, 1.66, 12, 5, [(2.2, 0.9, 0.66), (-2.1, -0.4, 0.50)]),
        (-5.2, 16.0, 2.55, 1.72, -16, 6, [(2.3, -0.7, 0.60), (0.6, 1.9, 0.52)]),
        (-11.8, 14.4, 2.35, 1.50, 26, 5, [(-2.1, 0.8, 0.56), (1.9, 1.2, 0.46)]),
        (-18.6, 14.0, 2.18, 1.44, -20, 6, [(1.9, -1.0, 0.54)]),
        (-26.2, 13.4, 2.45, 1.55, 14, 5, [(-1.8, 1.1, 0.58), (2.2, 0.5, 0.44)]),
        (6.0, 12.6, 2.28, 1.50, -22, 6, [(-1.7, -0.9, 0.56), (1.9, 1.0, 0.48)]),
        (13.2, 16.0, 2.18, 1.40, 18, 5, [(-1.8, 0.8, 0.52)]),
        (23.0, 19.0, 2.32, 1.50, -14, 6, [(2.1, 0.5, 0.58)]),
        (32.5, 18.4, 2.20, 1.44, 24, 5, [(-1.7, 1.0, 0.50)]),
    ]
    for idx, (sx, sz, rx_s, rz_s, yaw_deg, sides, chips) in enumerate(stepping_clusters):
        add_irregular_slab(sx, sz, rx_s, rz_s, yaw_deg, sides, rng.uniform(0.135, 0.178), idx * 10)
        for c_i, (cdx, cdz, cr) in enumerate(chips):
            add_irregular_slab(
                sx + cdx, sz + cdz, cr * 1.15, cr * 0.88, yaw_deg + c_i * 47.0,
                5, rng.uniform(0.105, 0.138), idx * 10 + c_i + 1
            )

    # 3. Low Embedded Cobble Cluster Bridging Guard Tower Yard onto Main Connector Path
    bridge_cobbles = [
        (7.5, -15.5, 0.52), (8.8, -14.2, 0.62), (9.6, -15.8, 0.48), (10.4, -13.0, 0.58),
        (8.2, -12.4, 0.46), (11.2, -14.8, 0.55), (9.8, -11.6, 0.44), (6.4, -13.8, 0.42),
        (11.6, -12.0, 0.48), (7.2, -17.2, 0.45), (10.6, -16.8, 0.52), (5.8, -16.2, 0.38),
        # Subtle path-fork cobble pebbles matching reference image
        (2.8, 8.4, 0.48), (3.8, 9.5, 0.40), (1.4, 7.6, 0.44), (-4.2, 6.2, 0.46),
        (-3.2, 5.0, 0.38), (5.2, -20.5, 0.45), (6.1, -19.2, 0.36), (1.0, -21.0, 0.42),
    ]
    for idx, (bx, bz, brad) in enumerate(bridge_cobbles):
        add_irregular_slab(
            bx, bz, brad, brad * rng.uniform(0.8, 1.15), idx * 37.0,
            5, rng.uniform(0.068, 0.090), 8000 + idx, cell=c_cobble if idx % 2 == 0 else c_apron_cool
        )

    return finalize_mesh_obj("Ground_Stonework", bm, mat_ground, col)


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

    # Remove duplicate backdrop meadow plane since Ground_GrassMeadow is built by OutskirtsGround
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
    col_ground = bpy.data.collections.new("OutskirtsGround_Prefab")
    col_env = bpy.data.collections.new("OutskirtsEnvironment_Prefab")
    scene.collection.children.link(col_gp)
    scene.collection.children.link(col_ground)
    scene.collection.children.link(col_env)

    print("[OutskirtsGuardhouse] Generating PBR textures...")
    g_col, g_nrm, g_rgh = generate_guardpost_ground_textures()
    p_col, p_nrm, p_rgh = generate_guardpost_props_textures()
    m_col, m_nrm, m_rgh = generate_outskirts_meadow_textures()
    chunk_texs = generate_path_chunk_textures()

    mat_ground = create_pbr_material("Mat_GuardpostGround", g_col, g_nrm, g_rgh)
    mat_props = create_pbr_material("Mat_GuardpostProps", p_col, p_nrm, p_rgh)
    mat_meadow = create_pbr_material("Mat_OutskirtsMeadow", m_col, m_nrm, m_rgh)
    chunk_mats = {
        cname: create_pbr_material(f"Mat_{cname}", sc, sn, sr, blend_alpha=True)
        for cname, (sc, sn, sr) in chunk_texs.items()
    }

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
    assert total_gp_tris < 7500, f"Guardhouse triangle budget exceeded: {total_gp_tris} >= 7500"

    print("[OutskirtsGuardhouse] Building unified Outskirts Ground (`OutskirtsGround.fbx`)...")
    tri_ground: dict[str, int] = {}
    ground_objs: list[bpy.types.Object] = []
    meadow_obj, meadow_tris = build_ground_grass_meadow(mat_meadow, col_ground)
    tri_ground[meadow_obj.name] = meadow_tris
    ground_objs.append(meadow_obj)
    for c_obj, c_tris in build_ground_path_chunks(chunk_mats, col_ground):
        tri_ground[c_obj.name] = c_tris
        ground_objs.append(c_obj)
    stone_obj, stone_tris = build_ground_stonework(mat_ground, col_ground)
    tri_ground[stone_obj.name] = stone_tris
    ground_objs.append(stone_obj)
    total_ground_tris = sum(tri_ground.values())
    print(f"[OutskirtsGuardhouse] Unified Ground Tris: {total_ground_tris}")
    for k, v in tri_ground.items():
        print(f"  - {k}: {v} tris")

    print("[OutskirtsGuardhouse] Building Outskirts Reusable Foliage/Rock Kit meshes...")
    tri_env: dict[str, int] = {}
    env_objs: list[bpy.types.Object] = []
    for builder, mat in (
        (build_outskirts_lush_bush, mat_ground),
        (build_outskirts_woodland_fern, mat_ground),
        (build_outskirts_mossy_boulder, mat_ground),
        (build_outskirts_grass_tuft, mat_ground),
    ):
        obj, tris = builder(mat, col_env)
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
    export_fbx(ground_objs, FBX_GROUND_PATH)
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
        "ground_tris": total_ground_tris,
        "ground_tri_breakdown": tri_ground,
        "env_kit_tris": total_env_tris,
        "env_kit_tri_breakdown": tri_env,
        "tower_pos_local": list(TOWER_POS_RBX),
        "tower_yaw_deg": TOWER_YAW_DEG,
        "lantern_pos_local": [round(v, 4) for v in tower_local_to_gp(4.35, 12.15, 4.35)],
        "campfire_pos_local": list(CAMPFIRE_POS_RBX),
        "palisade_points_local": [list(p) for p in PALISADE_POINTS],
        "split_rail_points_local": [list(p) for p in SPLIT_RAIL_POINTS],
        "guardpost_meshes": {o.name: bbox_rbx(o) for o in gp_objs},
        "ground_meshes": {o.name: bbox_rbx(o) for o in ground_objs},
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
            "path_chunks": {
                cname: {
                    "color": str(sc.relative_to(REPO_ROOT).as_posix()),
                    "normal": str(sn.relative_to(REPO_ROOT).as_posix()),
                    "roughness": str(sr.relative_to(REPO_ROOT).as_posix()),
                }
                for cname, (sc, sn, sr) in chunk_texs.items()
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
