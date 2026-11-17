"""
=============================================================================
Infinite Tower: Become a Master! - Castle Courtyard Single-Asset Ground
Generates:
  1. `assets/models/facilities/CastleCourtyardGround.fbx` (`CastleCourtyard_Ground`)
     - `Courtyard_FlagstoneFloor` (continuous 160x120 weathered grey flagstone & cobble floor)
     - `Courtyard_PlazaAndWalkways` (concentric fountain plaza rings + 7 radial walkways)
     *(Optional `--single-mesh` merges both into one single MeshPart.)*
  2. Seamless 1024x1024 PBR Texture Sets under
     `assets/models/facilities/textures/castle_courtyard/`:
     - `Tex_CastleCourtyardStone_{Color,Normal,Roughness}.png` (toroidal seamless 18-stud tile)
     - `Tex_CastleWalkwaySlate_{Color,Normal,Roughness}.png` (2x2 padded slate/cobble atlas)
  3. Metadata Manifest:
     - `assets/models/facilities/castle_courtyard_ground_manifest.json`

Coordinate Convention (1 Blender meter = 1 Roblox stud):
  Courtyard-local origin is the top center of IslandTopSurface (Y = 0.0).
  rbx_to_blender(rx, ry, rz) = (rx, -rz, ry)
  Exported with axis_forward="Z", axis_up="Y" matching OutskirtsGround.fbx.

Run:
  "C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b -P tools/blender/generate_castle_courtyard_ground.py
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
from mathutils import Matrix, Vector
import numpy as np


# ---------------------------------------------------------------------------
# Paths & Constants
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parents[2]
ASSET_DIR = REPO_ROOT / "assets" / "models" / "facilities"
TEX_DIR = ASSET_DIR / "textures" / "castle_courtyard"
FBX_PATH = ASSET_DIR / "CastleCourtyardGround.fbx"
MANIFEST_PATH = ASSET_DIR / "castle_courtyard_ground_manifest.json"
DEFAULT_PREVIEW_PATH = (
    Path(r"C:\Users\enter\.gemini\antigravity\brain\05ae6b20-23ac-40d3-8dc0-cb4a57c46b44\scratch")
    / "castle_courtyard_ground_preview.png"
)

COURTYARD_W = 160.0  # X in [-80, +80]
COURTYARD_L = 120.0  # Z in [-60, +60]
FLOOR_Y = 0.020
SKIRT_BOTTOM_Y = -0.220
TILE_STUDS = 24.0  # 24x24 stud seamless repeat (8x8 base grid = 3.0 studs/stone -> ~53 stones across 160 studs)

TEX_SIZE = 1024
ATLAS_CELL_PX = 512
ATLAS_PAD_PX = 16


def rbx_to_blender(rx: float, ry: float, rz: float) -> Vector:
    return Vector((rx, -rz, ry))


# ---------------------------------------------------------------------------
# PNG Writer & Toroidal Noise Utilities
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


def _tileable_fbm(res: int, seed: int, octaves: tuple[int, ...]) -> np.ndarray:
    acc = np.zeros((res, res), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for idx, c in enumerate(octaves):
        acc += amp * _tileable_noise(res, c, seed + idx * 97)
        norm += amp
        amp *= 0.5
    return acc / max(norm, 1e-6)


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


def _fbm_local(h: int, w: int, seed: int, octaves: tuple[int, ...] = (64, 32, 16, 8)) -> np.ndarray:
    acc = np.zeros((h, w), dtype=np.float32)
    amp = 1.0
    norm = 0.0
    for idx, sc in enumerate(octaves):
        acc += amp * _hash_noise_2d(h, w, sc, seed + idx * 97)
        norm += amp
        amp *= 0.5
    return acc / max(norm, 1e-6)


def height_to_normal_rgb(height: np.ndarray, strength: float = 2.6) -> np.ndarray:
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
# 1. Procedural Seamless Courtyard & Walkway PBR Texture Bakers
# ---------------------------------------------------------------------------
def _build_toroidal_stone_layout(grid_n: int, seed: int) -> list[tuple[float, float, float, float, dict]]:
    """
    Build a tightly fitted toroidal running-bond / broken-course mosaic of primary
    square flagstones (1x1), subtle paired rectangles (1.5x1 / 1x1.5 / 2x1),
    and occasional split half-pavers inside a `grid_n x grid_n` normalized tile.
    Row offsets break rigid vertical grid alignment so the courtyard looks hand-laid.
    """
    rng = random.Random(seed)
    used = [[False] * grid_n for _ in range(grid_n)]
    stones: list[tuple[float, float, float, float, dict]] = []

    def add_stone(gx: float, gy: float, gw: float, gh: float, row_shift: float, is_small: bool) -> None:
        # Tight, crisp mortar joints matching real castle courtyard pavers
        pad = rng.uniform(0.0036, 0.0054)
        cx = ((gx + gw * 0.5 + row_shift) / grid_n) % 1.0
        cy = ((gy + gh * 0.5) / grid_n) % 1.0
        hx = max(0.015, (gw / grid_n) * 0.5 - pad)
        hy = max(0.015, (gh / grid_n) * 0.5 - pad)
        cx = (cx + rng.uniform(-0.0014, 0.0014)) % 1.0
        cy = (cy + rng.uniform(-0.0014, 0.0014)) % 1.0
        meta = {
            "tone": rng.uniform(-1.0, 1.0),
            "warmth": rng.uniform(-0.35, 0.35),
            "moss_hint": rng.uniform(0.0, 1.0) if rng.random() < 0.22 else 0.0,
            "height_off": rng.uniform(-0.03, 0.035),
            "corner_r": rng.uniform(0.0055, 0.0095) if not is_small else rng.uniform(0.0045, 0.0075),
            "tilt_u": rng.uniform(-0.025, 0.025),
            "tilt_v": rng.uniform(-0.025, 0.025),
            "has_crack": (not is_small) and (rng.random() < 0.16),
            "crack_ang": rng.uniform(0.0, math.pi),
            "crack_off": rng.uniform(-0.32, 0.32) * min(hx, hy),
            "rough_off": rng.uniform(-0.035, 0.035),
        }
        stones.append((cx, cy, hx, hy, meta))

    # Row-level half-stone staggers break up long continuous straight lines naturally
    row_shifts = [0.0 if (y % 2 == 0) else 0.38 for y in range(grid_n)]

    coords = [(gx, gy) for gy in range(grid_n) for gx in range(grid_n)]
    rng.shuffle(coords)

    for gx, gy in coords:
        if used[gy][gx]:
            continue
        r_shift = row_shifts[gy]
        roll = rng.random()
        nx = (gx + 1) % grid_n

        # ~18% paired horizontal rectangular flagstone (2x1), rest 1x1 square courtyard flagstones
        if roll < 0.18 and not used[gy][nx]:
            used[gy][gx] = True
            used[gy][nx] = True
            add_stone(gx, gy, 2.0, 1.0, r_shift, is_small=False)
        else:
            # Classic square/near-square courtyard flagstone matching single-tile reference
            used[gy][gx] = True
            add_stone(gx, gy, 1.0, 1.0, r_shift, is_small=False)

    return stones


def generate_courtyard_stone_textures() -> tuple[Path, Path, Path]:
    """
    Generate 1024x1024 toroidally seamless weathered grey castle flagstone PBR maps.
    Designed to tile cleanly across 160x120 studs at 24 studs/repeat (~53 stones wide).
    """
    R = TEX_SIZE
    u_lin = np.linspace(0.0, 1.0, R, endpoint=False, dtype=np.float32)
    uu, vv = np.meshgrid(u_lin, u_lin)

    # Subtle toroidal domain warp so edges feel hand-hewn & natural without distorting straight coursing
    warp_u = (_tileable_fbm(R, 811, (24, 48, 96)) - 0.5) * 0.0055
    warp_v = (_tileable_fbm(R, 823, (24, 48, 96)) - 0.5) * 0.0055
    u_w = (uu + warp_u) % 1.0
    v_w = (vv + warp_v) % 1.0

    # Stone face & mortar grain noise (100% toroidal)
    n_macro = _tileable_fbm(R, 831, (16, 32))
    n_stone = _tileable_fbm(R, 841, (48, 96, 192))
    n_grain = _tileable_fbm(R, 853, (192, 384))
    n_grit = _tileable_noise(R, 384, 863)

    stones = _build_toroidal_stone_layout(grid_n=8, seed=4042026)

    best_sd = np.full((R, R), 1.0, dtype=np.float32)
    stone_tone = np.zeros((R, R), dtype=np.float32)
    stone_warmth = np.zeros((R, R), dtype=np.float32)
    stone_moss = np.zeros((R, R), dtype=np.float32)
    stone_hoff = np.zeros((R, R), dtype=np.float32)
    stone_tilt = np.zeros((R, R), dtype=np.float32)
    stone_roff = np.zeros((R, R), dtype=np.float32)
    crack_mask = np.zeros((R, R), dtype=np.float32)

    for cx, cy, hx, hy, meta in stones:
        dx = ((u_w - cx + 0.5) % 1.0) - 0.5
        dy = ((v_w - cy + 0.5) % 1.0) - 0.5
        rad = meta["corner_r"]
        qx = np.abs(dx) - (hx - rad)
        qy = np.abs(dy) - (hy - rad)
        outside_x = np.maximum(qx, 0.0)
        outside_y = np.maximum(qy, 0.0)
        inside_d = np.minimum(np.maximum(qx, qy), 0.0)
        sd = np.sqrt(outside_x * outside_x + outside_y * outside_y) + inside_d - rad

        take = sd < best_sd
        best_sd = np.where(take, sd, best_sd)
        stone_tone = np.where(take, meta["tone"], stone_tone)
        stone_warmth = np.where(take, meta["warmth"], stone_warmth)
        stone_moss = np.where(take, meta["moss_hint"], stone_moss)
        stone_hoff = np.where(take, meta["height_off"], stone_hoff)
        tilt_val = dx * meta["tilt_u"] + dy * meta["tilt_v"]
        stone_tilt = np.where(take, tilt_val, stone_tilt)
        stone_roff = np.where(take, meta["rough_off"], stone_roff)

        if meta["has_crack"]:
            ca = math.cos(meta["crack_ang"])
            sa = math.sin(meta["crack_ang"])
            c_dist = np.abs(dx * ca + dy * sa - meta["crack_off"] + (n_stone - 0.5) * 0.015)
            in_stone = sd < -0.005
            c_hit = np.where(in_stone, np.clip(1.0 - c_dist / 0.0024, 0.0, 1.0), 0.0)
            crack_mask = np.maximum(crack_mask, c_hit)

    # Tight stone plateau mask & crisp bevel shoulder
    bevel_w = 0.0045
    stone_mask = np.clip((-best_sd) / bevel_w, 0.0, 1.0)
    stone_mask = stone_mask * stone_mask * (3.0 - 2.0 * stone_mask)

    edge_ao = np.clip((-best_sd) / 0.009, 0.0, 1.0)
    edge_ao = 0.78 + 0.22 * (edge_ao * edge_ao * (3.0 - 2.0 * edge_ao))

    # Neutral weathered castle grey palette (R ~= G ~= B, slightly cool-neutral slate/ash matching approved preview)
    base_grey = np.array([99.0, 101.0, 104.0], dtype=np.float32)
    tone_shift = stone_tone[..., None] * np.array([13.0, 13.0, 13.0], dtype=np.float32)
    warm_shift = stone_warmth[..., None] * np.array([3.5, 2.5, 0.0], dtype=np.float32)
    weather_var = (n_stone[..., None] - 0.5) * np.array([22.0, 22.0, 21.5], dtype=np.float32)
    grain_var = (n_grain[..., None] - 0.5) * np.array([10.0, 10.0, 10.0], dtype=np.float32)
    macro_var = (n_macro[..., None] - 0.5) * 7.0

    # Subtle pitted wear & faint muted lichen/mineral patina inside stone texture
    pitting = np.clip((0.35 - n_stone) * 2.1, 0.0, 1.0)[..., None]
    moss_patina = np.clip((n_stone - 0.55) * stone_moss * 1.4, 0.0, 0.16)[..., None]
    stone_rgb = (base_grey + tone_shift + warm_shift + weather_var + grain_var + macro_var) * edge_ao[..., None]
    stone_rgb = stone_rgb * (1.0 - pitting * 0.13)
    stone_rgb = stone_rgb * (1.0 - moss_patina) + np.array([78.0, 84.0, 74.0]) * moss_patina
    stone_rgb = stone_rgb * (1.0 - crack_mask[..., None] * 0.20)

    # Tight dark weathered mortar crevices with fine granite grit
    gravel_dark = np.array([43.0, 45.0, 48.0], dtype=np.float32)
    gravel_speck = np.clip((n_grit - 0.56) * 2.5, 0.0, 1.0)[..., None] * np.array([18.0, 18.0, 19.0], dtype=np.float32)
    mortar_rgb = gravel_dark + n_grain[..., None] * 12.0 + gravel_speck

    rgb = mortar_rgb * (1.0 - stone_mask[..., None]) + stone_rgb * stone_mask[..., None]

    # Height map for crisp bevel + stone surface normals
    h_stone = (
        0.58
        + stone_hoff
        + stone_tilt * 2.0
        + 0.14 * (n_stone - 0.5)
        + 0.06 * (n_grain - 0.5)
        - 0.08 * pitting[..., 0]
        - 0.16 * crack_mask
    ) * (0.70 + 0.30 * edge_ao)
    h_mortar = 0.20 + 0.12 * n_grit + 0.06 * n_grain
    h_map = h_mortar * (1.0 - stone_mask) + h_stone * stone_mask

    # Roughness: 0.74-0.84 on worn flagstones, 0.90-0.95 inside joints
    r_stone = np.clip(0.79 + stone_roff - 0.05 * (n_stone - 0.5) + 0.06 * crack_mask, 0.70, 0.89)
    r_mortar = np.clip(0.92 + 0.04 * (1.0 - n_grit), 0.86, 0.96)
    r_map = r_mortar * (1.0 - stone_mask) + r_stone * stone_mask

    norm_rgb = height_to_normal_rgb(h_map, strength=2.9)
    col_rgba = np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), np.full((R, R), 255, dtype=np.uint8)])
    norm_rgba = np.dstack([norm_rgb, np.full((R, R), 255, dtype=np.uint8)])
    r_u8 = np.clip(r_map * 255.0, 14, 250).astype(np.uint8)
    rough_rgba = np.dstack([r_u8, r_u8, r_u8, np.full((R, R), 255, dtype=np.uint8)])

    p_col = TEX_DIR / "Tex_CastleCourtyardStone_Color.png"
    p_nrm = TEX_DIR / "Tex_CastleCourtyardStone_Normal.png"
    p_rgh = TEX_DIR / "Tex_CastleCourtyardStone_Roughness.png"
    write_png_rgba(p_col, col_rgba)
    write_png_rgba(p_nrm, norm_rgba)
    write_png_rgba(p_rgh, rough_rgba)
    print(f"[CastleGround] Baked seamless courtyard stone PBR maps -> {TEX_DIR}")
    return p_col, p_nrm, p_rgh


def _walkway_cell_bounds(col_idx: int, row_from_top: int) -> tuple[float, float, float, float]:
    px0 = col_idx * ATLAS_CELL_PX + ATLAS_PAD_PX
    px1 = (col_idx + 1) * ATLAS_CELL_PX - ATLAS_PAD_PX
    py0_top = row_from_top * ATLAS_CELL_PX + ATLAS_PAD_PX
    py1_bot = (row_from_top + 1) * ATLAS_CELL_PX - ATLAS_PAD_PX
    u0 = px0 / TEX_SIZE
    u1 = px1 / TEX_SIZE
    v1 = 1.0 - (py0_top / TEX_SIZE)
    v0 = 1.0 - (py1_bot / TEX_SIZE)
    return (u0, u1, v0, v1)


def generate_walkway_slate_textures() -> tuple[Path, Path, Path]:
    """
    Generate Tex_CastleWalkwaySlate_{Color,Normal,Roughness}.png (2x2 borderless atlas):
      (0,0): Darker neutral-grey weathered walkway slate slab (#494D53)
      (1,0): Refined fine cobblestone inlay mosaic (8x8 rounded river cobbles)
      (0,1): Ashlar border curb stone (#5B6068)
      (1,1): Dark mortar & bevel skirt (#2C2F35)
    """
    col = np.zeros((TEX_SIZE, TEX_SIZE, 4), dtype=np.uint8)
    col[..., 3] = 255
    height = np.full((TEX_SIZE, TEX_SIZE), 0.5, dtype=np.float32)
    rough = np.full((TEX_SIZE, TEX_SIZE), 205, dtype=np.uint8)

    C = ATLAS_CELL_PX
    lin = np.linspace(0.0, 1.0, C, dtype=np.float32)
    uu, vv = np.meshgrid(lin, 1.0 - lin)

    def put_cell(cx: int, cy: int, rgb: np.ndarray, h: np.ndarray, r: np.ndarray) -> None:
        x0, x1 = cx * C, (cx + 1) * C
        y0, y1 = cy * C, (cy + 1) * C
        col[y0:y1, x0:x1, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        height[y0:y1, x0:x1] = h.astype(np.float32)
        rough[y0:y1, x0:x1] = np.clip(r * 255.0, 14, 248).astype(np.uint8)

    # (0,0) Borderless neutral weathered castle slate slab (3D geometry bevels handle edges)
    n_s1 = _fbm_local(C, C, 901, (64, 32, 16))
    n_s2 = _fbm_local(C, C, 902, (12, 6))
    rgb_00 = np.array([72.0, 75.0, 80.0]) + n_s1[..., None] * 16.0 + n_s2[..., None] * 7.0
    put_cell(0, 0, rgb_00, 0.48 + 0.18 * n_s1 + 0.08 * n_s2, 0.80 - 0.05 * n_s1)

    # (1,0) Tightly fitted chiseled angular cobblestone mosaic (matching courtyard stone style, zero polka-dots)
    cells_c = 6
    w_u = (_tileable_fbm(C, 911, (18, 36)) - 0.5) * 0.016
    w_v = (_tileable_fbm(C, 912, (18, 36)) - 0.5) * 0.016
    u_cob = (uu + w_u) % 1.0
    v_cob = (vv + w_v) % 1.0
    cob_sd = np.full((C, C), 1.0, dtype=np.float32)
    cob_shade = np.zeros((C, C), dtype=np.float32)
    rng_c = random.Random(913)
    for ry in range(cells_c):
        shift = 0.45 if (ry % 2 == 1) else 0.0
        for rx in range(cells_c):
            ccx = ((rx + 0.5 + shift + rng_c.uniform(-0.04, 0.04)) / cells_c) % 1.0
            ccy = ((ry + 0.5 + rng_c.uniform(-0.04, 0.04)) / cells_c) % 1.0
            hx = (0.5 / cells_c) - rng_c.uniform(0.008, 0.012)
            hy = (0.5 / cells_c) - rng_c.uniform(0.008, 0.012)
            rad_c = rng_c.uniform(0.012, 0.020)
            dx = ((u_cob - ccx + 0.5) % 1.0) - 0.5
            dy = ((v_cob - ccy + 0.5) % 1.0) - 0.5
            qx = np.abs(dx) - (hx - rad_c)
            qy = np.abs(dy) - (hy - rad_c)
            sd = np.sqrt(np.maximum(qx, 0.0) ** 2 + np.maximum(qy, 0.0) ** 2) + np.minimum(np.maximum(qx, qy), 0.0) - rad_c
            take = sd < cob_sd
            cob_sd = np.where(take, sd, cob_sd)
            cob_shade = np.where(take, rng_c.uniform(-1.0, 1.0), cob_shade)

    cob_mask = np.clip((-cob_sd) / 0.009, 0.0, 1.0)
    cob_mask = cob_mask * cob_mask * (3.0 - 2.0 * cob_mask)
    cob_ao = np.clip((-cob_sd) / 0.018, 0.0, 1.0)
    cob_ao = 0.78 + 0.22 * (cob_ao * cob_ao * (3.0 - 2.0 * cob_ao))
    cob_rgb = (np.array([76.0, 79.0, 84.0]) + n_s1[..., None] * 18.0 + cob_shade[..., None] * 11.0) * cob_ao[..., None]
    gap_rgb = np.array([39.0, 41.0, 45.0]) + n_s2[..., None] * 9.0
    rgb_10 = gap_rgb * (1.0 - cob_mask[..., None]) + cob_rgb * cob_mask[..., None]
    h_10 = 0.26 + (0.36 + 0.14 * n_s1) * cob_mask * cob_ao
    put_cell(1, 0, rgb_10, h_10, 0.85 - 0.06 * cob_mask)

    # (0,1) Borderless ashlar border curb stone (#5A5F66)
    n_c1 = _fbm_local(C, C, 921, (48, 24, 12))
    rgb_01 = np.array([88.0, 91.0, 96.0]) + n_c1[..., None] * 16.0 + n_s2[..., None] * 7.0
    put_cell(0, 1, rgb_01, 0.52 + 0.16 * n_c1 + 0.06 * n_s2, 0.78 - 0.04 * n_c1)

    # (1,1) Subtle bevel trim (#3A3D43)
    rgb_11 = np.array([56.0, 59.0, 65.0]) + n_s2[..., None] * 12.0
    put_cell(1, 1, rgb_11, 0.34 + 0.16 * n_s2, np.full((C, C), 0.88))

    norm_rgb = height_to_normal_rgb(height, strength=2.6)
    norm_rgba = np.dstack([norm_rgb, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])
    rough_rgba = np.dstack([rough, rough, rough, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])

    p_col = TEX_DIR / "Tex_CastleWalkwaySlate_Color.png"
    p_nrm = TEX_DIR / "Tex_CastleWalkwaySlate_Normal.png"
    p_rgh = TEX_DIR / "Tex_CastleWalkwaySlate_Roughness.png"
    write_png_rgba(p_col, col)
    write_png_rgba(p_nrm, norm_rgba)
    write_png_rgba(p_rgh, rough_rgba)
    print(f"[CastleGround] Baked walkway slate atlas PBR maps -> {TEX_DIR}")
    return p_col, p_nrm, p_rgh


# ---------------------------------------------------------------------------
# 2. Blender Material & Mesh Construction
# ---------------------------------------------------------------------------
def create_pbr_material(name: str, p_col: Path, p_nrm: Path, p_rgh: Path) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    if mat.node_tree is None:
        mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()

    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Specular IOR Level"].default_value = 0.28
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
    nrm_node.inputs["Strength"].default_value = 0.90
    nt.links.new(tex_nrm.outputs["Color"], nrm_node.inputs["Color"])
    nt.links.new(nrm_node.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


def _flat_zone_weight(rx: float, rz: float) -> float:
    """
    Returns [0..1] micro-relief weight: 0 near walls, fountain plinth, TrainingArea,
    and MarketCluster so nothing clips or Z-fights; 1 in open courtyard bays.
    """
    if abs(rx) > 71.0 or abs(rz) > 51.0:
        return 0.0
    if math.hypot(rx, rz) < 22.5:
        return 0.0
    if math.hypot(rx - 49.5, rz - 35.5) < 22.0:
        return 0.0
    if -74.0 <= rx <= -18.0 and 10.0 <= rz <= 56.0:
        return 0.0
    return 1.0


def build_courtyard_flagstone_floor(mat_stone: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, int]:
    """
    Build the continuous 160x120 weathered grey stone courtyard floor (`Courtyard_FlagstoneFloor`)
    at courtyard-local Y = +0.020 with a perimeter skirt down to Y = -0.220.
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    half_w = COURTYARD_W * 0.5
    half_l = COURTYARD_L * 0.5
    nx, nz = 32, 24

    grid: list[list[bmesh.types.BMVert]] = []
    for iz in range(nz + 1):
        rz = -half_l + COURTYARD_L * (iz / nz)
        row = []
        for ix in range(nx + 1):
            rx = -half_w + COURTYARD_W * (ix / nx)
            w_rel = _flat_zone_weight(rx, rz)
            undul = 0.005 * math.sin(rx * 0.21 + 0.7) * math.cos(rz * 0.19 - 0.4) * w_rel
            ry = FLOOR_Y + undul
            row.append(bm.verts.new(rbx_to_blender(rx, ry, rz)))
        grid.append(row)

    for iz in range(nz):
        for ix in range(nx):
            v00 = grid[iz][ix]
            v10 = grid[iz][ix + 1]
            v11 = grid[iz + 1][ix + 1]
            v01 = grid[iz + 1][ix]
            # Top face normal points +Y in Roblox (+Z in Blender)
            f = bm.faces.new([v00, v01, v11, v10])
            f.smooth = True
            for vert, loop in zip((v00, v01, v11, v10), f.loops):
                # Blender: vx = rx, vy = -rz -> seamless 18-stud world tiling
                u = (vert.co.x + half_w) / TILE_STUDS
                v = (vert.co.y + half_l) / TILE_STUDS
                loop[uv].uv = (u, v)

    # Downward perimeter skirt around all 4 courtyard boundaries so zero gap shows at wall plinths
    perim_top: list[bmesh.types.BMVert] = []
    perim_bot: list[bmesh.types.BMVert] = []
    # Trace clockwise around perimeter in Roblox XZ: North (-Z) -> East (+X) -> South (+Z) -> West (-X)
    for ix in range(nx):
        perim_top.append(grid[0][ix])
    for iz in range(nz):
        perim_top.append(grid[iz][nx])
    for ix in range(nx, 0, -1):
        perim_top.append(grid[nz][ix])
    for iz in range(nz, 0, -1):
        perim_top.append(grid[iz][0])

    for vt in perim_top:
        perim_bot.append(bm.verts.new(Vector((vt.co.x, vt.co.y, SKIRT_BOTTOM_Y))))

    n_p = len(perim_top)
    for k in range(n_p):
        kn = (k + 1) % n_p
        fs = bm.faces.new([perim_top[k], perim_top[kn], perim_bot[kn], perim_bot[k]])
        fs.smooth = False
        for loop in fs.loops:
            co = loop.vert.co
            loop[uv].uv = ((co.x + co.y) / TILE_STUDS, co.z / TILE_STUDS)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    tris = sum(max(1, len(f.verts) - 2) for f in bm.faces)
    mesh = bpy.data.meshes.new("Courtyard_FlagstoneFloor_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Courtyard_FlagstoneFloor", mesh)
    col.objects.link(obj)
    mesh.materials.append(mat_stone)
    return obj, tris


def _add_walkway_bevelled_quad(
    bm: bmesh.types.BMesh,
    uv,
    pts_xz: list[tuple[float, float]],
    y_bot: float,
    y_top: float,
    cell_top: tuple[int, int],
    cell_side: tuple[int, int] = (1, 1),
    bevel_inset: float = 0.08,
    uv_dirs: tuple[Vector, Vector] | None = None,
) -> None:
    """Add a 4-corner bevelled stone slab in Roblox XZ with clean atlas UV mapping."""
    cx = sum(p[0] for p in pts_xz) / len(pts_xz)
    cz = sum(p[1] for p in pts_xz) / len(pts_xz)
    inner = [
        (cx + (px - cx) * (1.0 - bevel_inset), cz + (pz - cz) * (1.0 - bevel_inset))
        for px, pz in pts_xz
    ]
    v_bot = [bm.verts.new(rbx_to_blender(px, y_bot, pz)) for px, pz in pts_xz]
    v_top = [bm.verts.new(rbx_to_blender(px, y_top, pz)) for px, pz in inner]

    u0, u1, v0, v1 = _walkway_cell_bounds(cell_top[0], cell_top[1])
    su0, su1, sv0, sv1 = _walkway_cell_bounds(cell_side[0], cell_side[1])

    # Top face UV mapping
    f_top = bm.faces.new(v_top)
    f_top.smooth = False
    if len(pts_xz) == 4 and uv_dirs is None:
        coords = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
        for loop, uv_c in zip(f_top.loops, coords):
            loop[uv].uv = uv_c
    else:
        for loop, (px, pz) in zip(f_top.loops, inner):
            dx, dz = px - cx, pz - cz
            if uv_dirs is not None:
                lu = 0.5 + 0.45 * (dx * uv_dirs[0].x + dz * uv_dirs[0].y)
                lv = 0.5 + 0.45 * (dx * uv_dirs[1].x + dz * uv_dirs[1].y)
            else:
                lu = 0.5 + dx * 0.1
                lv = 0.5 + dz * 0.1
            loop[uv].uv = (
                u0 + max(0.0, min(1.0, lu)) * (u1 - u0),
                v0 + max(0.0, min(1.0, lv)) * (v1 - v0),
            )

    n = len(pts_xz)
    for k in range(n):
        kn = (k + 1) % n
        fs = bm.faces.new([v_bot[k], v_bot[kn], v_top[kn], v_top[k]])
        fs.smooth = False
        for loop, uv_c in zip(fs.loops, [(su0, sv0), (su1, sv0), (su1, sv1), (su0, sv1)]):
            loop[uv].uv = uv_c


def build_courtyard_plaza_and_walkways(
    mat_walkway: bpy.types.Material, col: bpy.types.Collection
) -> tuple[bpy.types.Object, int]:
    """
    Build the concentric fountain plaza rings and 7 radial stone walkways matching
    IslandBuilder.luau coordinates and the approved courtyard preview.
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    c_slab = (0, 0)
    c_cobble = (1, 0)
    c_curb = (0, 1)
    c_skirt = (1, 1)

    def add_oriented_box_slab(
        cx: float,
        cz: float,
        width: float,
        length: float,
        yaw_rad: float,
        y_bot: float,
        y_top: float,
        cell: tuple[int, int],
        bevel: float = 0.08,
    ) -> None:
        ca, sa = math.cos(yaw_rad), math.sin(yaw_rad)
        hw, hl = width * 0.5, length * 0.5
        # Local X = right, local Z = forward; rotated around Y by yaw_rad
        corners_local = [(-hw, -hl), (hw, -hl), (hw, hl), (-hw, hl)]
        pts_xz = [(cx + lx * ca + lz * sa, cz - lx * sa + lz * ca) for lx, lz in corners_local]
        _add_walkway_bevelled_quad(bm, uv, pts_xz, y_bot, y_top, cell, c_skirt, bevel_inset=bevel)

    # Radial walkways matching IslandBuilder.luau, with BridgeGate & OutskirtsGate extended cleanly to the gate arches
    radial_walkways = [
        ("Path_BridgeGate", (0.0, -19.6), (0.0, -59.2), 9.2, 6),
        ("Path_SummoningPortal", (16.0, -11.4), (41.5, -29.5), 8.4, 4),
        ("Path_BlacksmithForge", (19.6, -0.8), (44.5, -1.8), 8.4, 4),
        ("Path_Market", (16.2, 11.2), (40.8, 28.9), 8.4, 5),
        ("Path_OutskirtsGate", (4.8, 19.0), (14.0, 57.2), 9.0, 5),
        ("Path_SynthesisChamber", (-16.6, -10.6), (-32.0, -20.4), 8.4, 3),
    ]
    tr_len = math.hypot(66.8, 46.8)
    tr_dx, tr_dz = -66.8 / tr_len, 46.8 / tr_len
    radial_walkways.append(
        ("Path_TrainingArea", (tr_dx * 19.65, tr_dz * 19.65), (tr_dx * 36.4, tr_dz * 36.4), 8.4, 3)
    )

    branch_angles = [math.atan2(p0[0], p0[1]) for _, p0, _, _, _ in radial_walkways]

    def near_branch(theta: float) -> bool:
        for ba in branch_angles:
            diff = math.atan2(math.sin(theta - ba), math.cos(theta - ba))
            if abs(diff) < 0.24:
                return True
        return False

    # 1. Concentric Fountain Plaza Rings
    # Inner ring (R = 14.0, W = 3.2, 16 slabs) + inner curb (R = 12.02, W = 0.60)
    inner_r, inner_w, inner_n, inner_gap = 14.0, 3.2, 16, 0.16
    for i in range(inner_n):
        a0 = (i / inner_n) * math.tau
        a1 = ((i + 1) / inner_n) * math.tau
        amid = (a0 + a1) * 0.5
        chord = 2.0 * inner_r * math.sin((a1 - a0) * 0.5) - inner_gap
        cx, cz = math.sin(amid) * inner_r, math.cos(amid) * inner_r
        # Tangent direction has yaw such that local X points radially outward and local Z tangentially
        yaw = amid + math.pi * 0.5
        add_oriented_box_slab(
            cx, cz, inner_w, chord, yaw, 0.015, 0.052,
            c_cobble if i % 2 == 0 else c_slab, bevel=0.07
        )

        curb_in_r = inner_r - inner_w * 0.5 - 0.38
        curb_in_chord = 2.0 * curb_in_r * math.sin((a1 - a0) * 0.5) - 0.14
        ix, iz = math.sin(amid) * curb_in_r, math.cos(amid) * curb_in_r
        add_oriented_box_slab(ix, iz, 0.60, curb_in_chord, yaw, 0.015, 0.078, c_curb, bevel=0.10)

    # Outer ring (R = 17.8, W = 3.8, 20 slabs) + outer curb (R = 20.23, W = 0.78, open at branches)
    outer_r, outer_w, outer_n, outer_gap, curb_w = 17.8, 3.8, 20, 0.18, 0.78
    for i in range(outer_n):
        a0 = (i / outer_n) * math.tau
        a1 = ((i + 1) / outer_n) * math.tau
        amid = (a0 + a1) * 0.5
        chord = 2.0 * outer_r * math.sin((a1 - a0) * 0.5) - outer_gap
        cx, cz = math.sin(amid) * outer_r, math.cos(amid) * outer_r
        yaw = amid + math.pi * 0.5
        add_oriented_box_slab(
            cx, cz, outer_w, chord, yaw, 0.015, 0.052,
            c_cobble if i % 3 == 0 else c_slab, bevel=0.07
        )

        if not near_branch(amid):
            curb_out_r = outer_r + outer_w * 0.5 + curb_w * 0.5 + 0.14
            curb_out_chord = 2.0 * curb_out_r * math.sin((a1 - a0) * 0.5) - 0.18
            ox, oz = math.sin(amid) * curb_out_r, math.cos(amid) * curb_out_r
            add_oriented_box_slab(ox, oz, curb_w, curb_out_chord, yaw, 0.015, 0.078, c_curb, bevel=0.10)

    # 2. Radial Walkways (7 branches with alternating slate/cobble slabs + raised stone curb borders)
    for _, p0, p1, width, segs in radial_walkways:
        dx, dz = p1[0] - p0[0], p1[1] - p0[1]
        total_len = math.hypot(dx, dz)
        if total_len < 1.0:
            continue
        ux, uz = dx / total_len, dz / total_len
        # Right vector perpendicular to forward (ux, uz) in Roblox XZ: (uz, -ux) -> wait: lookAt(0, (ux,0,uz)) RightVector is (-uz, 0, ux)
        rx_dir, rz_dir = -uz, ux
        yaw = math.atan2(-ux, -uz)
        seg_len = total_len / segs
        inner_w_path = width - curb_w * 2.0 - 0.26

        for s in range(segs):
            t = (s + 0.5) / segs
            px = p0[0] + dx * t
            pz = p0[1] + dz * t
            add_oriented_box_slab(
                px, pz, inner_w_path, seg_len - 0.20, yaw, 0.015, 0.052,
                c_cobble if s % 2 == 0 else c_slab, bevel=0.06
            )
            for side in (-1.0, 1.0):
                off = side * (width * 0.5 - curb_w * 0.5)
                add_oriented_box_slab(
                    px + rx_dir * off, pz + rz_dir * off,
                    curb_w, seg_len - 0.24, yaw, 0.015, 0.076, c_curb, bevel=0.09
                )

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    tris = sum(max(1, len(f.verts) - 2) for f in bm.faces)
    mesh = bpy.data.meshes.new("Courtyard_PlazaAndWalkways_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Courtyard_PlazaAndWalkways", mesh)
    col.objects.link(obj)
    mesh.materials.append(mat_walkway)
    return obj, tris


# ---------------------------------------------------------------------------
# 3. Preview Render Context (Top-Down Courtyard Verification)
# ---------------------------------------------------------------------------
def build_preview_context(ctx_col: bpy.types.Collection) -> None:
    bm = bmesh.new()

    def add_box(center, size, mat_idx):
        cx, cy, cz = center
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        cs = [
            (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
            (-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz),
        ]
        vs = [bm.verts.new(rbx_to_blender(cx + x, cy + y, cz + z)) for x, y, z in cs]
        for q in [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (2, 3, 7, 6), (1, 2, 6, 5), (3, 0, 4, 7)]:
            f = bm.faces.new([vs[i] for i in q])
            f.material_index = mat_idx

    # Dark perimeter castle walls matching WallsBuilder (#3B4048) + blue fountain proxy
    add_box((-80.0, 11.0, 0.0), (6.0, 22.0, 120.0), 0)
    add_box((80.0, 11.0, 0.0), (6.0, 22.0, 120.0), 0)
    add_box((-43.5, 11.0, -60.0), (73.0, 22.0, 6.0), 0)
    add_box((43.5, 11.0, -60.0), (73.0, 22.0, 6.0), 0)
    add_box((-36.5, 11.0, 60.0), (87.0, 22.0, 6.0), 0)
    add_box((50.5, 11.0, 60.0), (59.0, 22.0, 6.0), 0)
    add_box((0.0, 3.0, 0.0), (22.0, 6.0, 22.0), 1)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("PreviewContext_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    mat_wall = bpy.data.materials.new("PreviewWallMat")
    if mat_wall.node_tree is None:
        mat_wall.use_nodes = True
    mat_wall.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.055, 0.062, 0.075, 1.0)
    mat_fountain = bpy.data.materials.new("PreviewFountainMat")
    if mat_fountain.node_tree is None:
        mat_fountain.use_nodes = True
    mat_fountain.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.45, 0.85, 1.0)
    mesh.materials.append(mat_wall)
    mesh.materials.append(mat_fountain)

    obj = bpy.data.objects.new("PreviewContext", mesh)
    ctx_col.objects.link(obj)


def render_preview(out_png: Path, ctx_col: bpy.types.Collection) -> None:
    scene = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "CYCLES"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 960
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(out_png)
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.exposure = 0.0

    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    scene.world = world
    if world.node_tree is None:
        world.use_nodes = True
    bg = next((n for n in world.node_tree.nodes if n.type == "BACKGROUND"), None)
    if bg:
        bg.inputs[0].default_value = (0.28, 0.31, 0.36, 1.0)
        bg.inputs[1].default_value = 1.0

    sun_d = bpy.data.lights.new("CourtyardSun", type="SUN")
    sun_d.energy = 2.4
    sun_d.color = (1.0, 0.98, 0.95)
    sun = bpy.data.objects.new("CourtyardSun", sun_d)
    sun.rotation_euler = (math.radians(38.0), math.radians(16.0), math.radians(-35.0))
    ctx_col.objects.link(sun)

    cam_d = bpy.data.cameras.new("TopDownCam")
    cam_d.lens = 24.0
    cam = bpy.data.objects.new("TopDownCam", cam_d)
    ctx_col.objects.link(cam)
    scene.camera = cam

    cam_pos = rbx_to_blender(0.0, 130.0, 34.0)
    tgt_pos = rbx_to_blender(0.0, 0.0, 0.0)
    cam.location = cam_pos
    cam.rotation_euler = (tgt_pos - cam_pos).normalized().to_track_quat("-Z", "Y").to_euler()

    out_png.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"[CastleGround] Rendered preview -> {out_png}")


# ---------------------------------------------------------------------------
# 4. Main Entrypoint
# ---------------------------------------------------------------------------
def main() -> None:
    parser = argparse.ArgumentParser(description="Generate Castle Courtyard Single-Asset Ground FBX & PBR textures")
    parser.add_argument("--no-render", action="store_true")
    parser.add_argument("--single-mesh", action="store_true", help="Merge floor and plaza/walkways into 1 MeshPart")
    parser.add_argument("--preview-out", type=Path, default=DEFAULT_PREVIEW_PATH)
    cli_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    args, _ = parser.parse_known_args(cli_args)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0

    col = bpy.data.collections.new("CastleCourtyardGround_Prefab")
    scene.collection.children.link(col)

    print("[CastleGround] Generating seamless weathered grey PBR textures...")
    s_col, s_nrm, s_rgh = generate_courtyard_stone_textures()
    w_col, w_nrm, w_rgh = generate_walkway_slate_textures()

    mat_stone = create_pbr_material("Mat_CastleCourtyardStone", s_col, s_nrm, s_rgh)
    mat_walkway = create_pbr_material("Mat_CastleWalkwaySlate", w_col, w_nrm, w_rgh)

    print("[CastleGround] Building courtyard ground meshes...")
    floor_obj, floor_tris = build_courtyard_flagstone_floor(mat_stone, col)
    walkway_obj, walkway_tris = build_courtyard_plaza_and_walkways(mat_walkway, col)

    export_objs = [floor_obj, walkway_obj]
    tri_breakdown = {
        floor_obj.name: floor_tris,
        walkway_obj.name: walkway_tris,
    }

    if args.single_mesh:
        bpy.ops.object.select_all(action="DESELECT")
        floor_obj.select_set(True)
        walkway_obj.select_set(True)
        bpy.context.view_layer.objects.active = floor_obj
        bpy.ops.object.join()
        floor_obj.name = "CastleCourtyard_Ground"
        export_objs = [floor_obj]
        tri_breakdown = {floor_obj.name: floor_tris + walkway_tris}

    total_tris = sum(tri_breakdown.values())
    print(f"[CastleGround] Total Tris: {total_tris} ({tri_breakdown})")
    assert total_tris < 6000, f"Triangle budget exceeded: {total_tris}"

    FBX_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in export_objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = export_objs[0]
    bpy.ops.export_scene.fbx(
        filepath=str(FBX_PATH),
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
    print(f"[CastleGround] Exported FBX -> {FBX_PATH} ({FBX_PATH.stat().st_size} bytes)")

    def bbox_rbx(obj: bpy.types.Object) -> dict:
        pts = [Vector(c) for c in obj.bound_box]
        r_pts = [(p.x, p.z, -p.y) for p in pts]
        xs, ys, zs = [p[0] for p in r_pts], [p[1] for p in r_pts], [p[2] for p in r_pts]
        pos = [round((min(xs) + max(xs)) * 0.5, 4), round((min(ys) + max(ys)) * 0.5, 4), round((min(zs) + max(zs)) * 0.5, 4)]
        sz = [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)]
        return {"pos": pos, "size": sz, "pivot_offset": [-pos[0], -pos[1], -pos[2]]}

    manifest = {
        "courtyard_width": COURTYARD_W,
        "courtyard_length": COURTYARD_L,
        "floor_y": FLOOR_Y,
        "tile_studs": TILE_STUDS,
        "total_tris": total_tris,
        "tri_breakdown": tri_breakdown,
        "meshes": {o.name: bbox_rbx(o) for o in export_objs},
        "textures": {
            "courtyard_stone": {
                "color": str(s_col.relative_to(REPO_ROOT).as_posix()),
                "normal": str(s_nrm.relative_to(REPO_ROOT).as_posix()),
                "roughness": str(s_rgh.relative_to(REPO_ROOT).as_posix()),
            },
            "walkway_slate": {
                "color": str(w_col.relative_to(REPO_ROOT).as_posix()),
                "normal": str(w_nrm.relative_to(REPO_ROOT).as_posix()),
                "roughness": str(w_rgh.relative_to(REPO_ROOT).as_posix()),
            },
        },
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"[CastleGround] Wrote manifest -> {MANIFEST_PATH}")

    if not args.no_render:
        ctx_col = bpy.data.collections.new("Preview_Context")
        scene.collection.children.link(ctx_col)
        build_preview_context(ctx_col)
        render_preview(args.preview_out, ctx_col)


if __name__ == "__main__":
    main()
