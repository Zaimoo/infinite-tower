"""
=============================================================================
Infinite Tower: Become a Master! - Castle Courtyard Single-Asset Ground
Generates:
  1. `assets/models/facilities/CastleCourtyardGround.fbx` (`CastleCourtyard_Ground`)
     - `Courtyard_FlagstoneFloor` (continuous 160x120 weathered grey flagstone floor
       with natural stone cracks, chipped corners & mortar/corner moss)
     - `Courtyard_DirtAndWeathering` (Merchant Bazaar packed-dirt bed + alpha-feathered
       macro courtyard crack faults & damp moss colonies; NO radial paths or plaza rings)
     *(Optional `--single-mesh` merges both into one single MeshPart.)*
  2. Seamless 1024x1024 PBR Texture Sets under
     `assets/models/facilities/textures/castle_courtyard/`:
     - `Tex_CastleCourtyardStone_{Color,Normal,Roughness}.png` (toroidal 16-stud tile)
     - `Tex_CastleWalkwaySlate_{Color,Normal,Roughness}.png` (RGBA packed dirt + moss/crack splat atlas)
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
from mathutils import Vector
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
TILE_STUDS = 16.0  # 16x16 stud seamless repeat (12x12 base grid = 1.33 studs/stone)

TEX_SIZE = 1024

# Merchant Bazaar world transform (matches FacilityConfig.FacilityLayout.Market)
MARKET_POS = (50.0, 36.0)
MARKET_YAW = math.atan2(-50.0, -36.0)
# Merchant Dirt Apron local bounds: lx in [-20.5, +20.5] (41 studs), lz in [-13.5, +17.0] (30.5 studs)
DIRT_LX_MIN, DIRT_LX_MAX = -20.5, 20.5
DIRT_LZ_MIN, DIRT_LZ_MAX = -13.5, 17.0

# Non-overlapping RGBA splat atlas pixel boxes (x0, y0, x1, y1) inside 1024x1024
SPLAT_RECTS = {
    "merchant_dirt": (16, 16, 656, 560),   # 640x544 (~15.6 px/stud packed dirt & gravel rim)
    "moss_colony":   (672, 16, 1008, 352), # 336x336 organic multi-lobe moss cluster
    "moss_drift":    (672, 368, 1008, 704),# 336x336 directional wall/plinth moss drift
    "crack_star":    (16, 576, 480, 1008), # 464x432 branching stone fault cracks
    "crack_split":   (500, 720, 1008, 1008)# 508x288 linear fractured stone seam
}


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
        # Tight, crisp mortar joints scaled for smaller 1.33-stud player-scale castle bricks
        pad = rng.uniform(0.0022, 0.0032)
        cx = ((gx + gw * 0.5 + row_shift) / grid_n) % 1.0
        cy = ((gy + gh * 0.5) / grid_n) % 1.0
        hx = max(0.012, (gw / grid_n) * 0.5 - pad)
        hy = max(0.012, (gh / grid_n) * 0.5 - pad)
        cx = (cx + rng.uniform(-0.0009, 0.0009)) % 1.0
        cy = (cy + rng.uniform(-0.0009, 0.0009)) % 1.0
        meta = {
            "tone": rng.uniform(-1.0, 1.0),
            "warmth": rng.uniform(-0.35, 0.35),
            "moss_hint": rng.uniform(0.35, 1.0) if rng.random() < 0.38 else 0.0,
            "height_off": rng.uniform(-0.032, 0.038),
            "corner_r": rng.uniform(0.0038, 0.0062) if not is_small else rng.uniform(0.0030, 0.0050),
            "tilt_u": rng.uniform(-0.024, 0.024),
            "tilt_v": rng.uniform(-0.024, 0.024),
            "has_crack": (not is_small) and (rng.random() < 0.30),
            "crack_ang": rng.uniform(0.0, math.pi),
            "crack_off": rng.uniform(-0.28, 0.28) * min(hx, hy),
            "has_fork": rng.random() < 0.45,
            "fork_ang_off": rng.uniform(0.38, 0.92) * rng.choice((-1.0, 1.0)),
            "fork_t": rng.uniform(-0.18, 0.18) * min(hx, hy),
            "has_chip": rng.random() < 0.22,
            "chip_sx": rng.choice((-1.0, 1.0)),
            "chip_sy": rng.choice((-1.0, 1.0)),
            "chip_r": rng.uniform(0.0095, 0.0155),
            "rough_off": rng.uniform(-0.035, 0.035),
        }
        stones.append((cx, cy, hx, hy, meta))

    # Non-periodic row staggers across the 12 rows prevent repeating vertical bands when tiled 10x
    base_shifts = [0.0, 0.42, 0.18, 0.65, 0.30, 0.78, 0.08, 0.52, 0.25, 0.70, 0.12, 0.48]
    row_shifts = [base_shifts[y % len(base_shifts)] for y in range(grid_n)]

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
    Generate 1024x1024 toroidally seamless weathered grey castle flagstone PBR maps
    with natural forked stone cracks, chipped brick corners, and patchy mortar moss.
    """
    R = TEX_SIZE
    u_lin = np.linspace(0.0, 1.0, R, endpoint=False, dtype=np.float32)
    uu, vv = np.meshgrid(u_lin, u_lin)

    # Subtle toroidal domain warp so edges feel hand-hewn & natural without distorting straight coursing
    warp_u = (_tileable_fbm(R, 811, (36, 72, 144)) - 0.5) * 0.0038
    warp_v = (_tileable_fbm(R, 823, (36, 72, 144)) - 0.5) * 0.0038
    u_w = (uu + warp_u) % 1.0
    v_w = (vv + warp_v) % 1.0

    # Stone face, damp moss envelope, & mortar grain noise (100% toroidal)
    n_macro = _tileable_fbm(R, 831, (16, 32))
    n_stone = _tileable_fbm(R, 841, (64, 128, 256))
    n_grain = _tileable_fbm(R, 853, (192, 384))
    n_grit = _tileable_noise(R, 384, 863)
    n_damp = _tileable_fbm(R, 877, (12, 24, 48))
    n_moss_tex = _tileable_fbm(R, 887, (128, 256))

    stones = _build_toroidal_stone_layout(grid_n=12, seed=4042026)

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

        if meta["has_chip"]:
            ch_x = meta["chip_sx"] * (hx - 0.002)
            ch_y = meta["chip_sy"] * (hy - 0.002)
            ch_d = np.hypot(dx - ch_x, dy - ch_y) - meta["chip_r"] + (n_grain - 0.5) * 0.004
            sd = np.maximum(sd, -ch_d)

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
            c_dist = np.abs(dx * ca + dy * sa - meta["crack_off"] + (n_stone - 0.5) * 0.014)
            in_stone = sd < -0.0028
            c_hit = np.where(in_stone, np.clip(1.0 - c_dist / 0.0025, 0.0, 1.0), 0.0)
            if meta["has_fork"]:
                fa = meta["crack_ang"] + meta["fork_ang_off"]
                fca, fsa = math.cos(fa), math.sin(fa)
                along = -dx * sa + dy * ca - meta["fork_t"]
                f_dist = np.abs(dx * fca + dy * fsa - meta["crack_off"] * 0.5 + (n_grain - 0.5) * 0.011)
                f_hit = np.where(in_stone & (along > 0.0), np.clip(1.0 - f_dist / 0.0019, 0.0, 1.0), 0.0)
                c_hit = np.maximum(c_hit, f_hit * 0.90)
            crack_mask = np.maximum(crack_mask, c_hit)

    # Tight stone plateau mask & crisp bevel shoulder
    bevel_w = 0.0032
    stone_mask = np.clip((-best_sd) / bevel_w, 0.0, 1.0)
    stone_mask = stone_mask * stone_mask * (3.0 - 2.0 * stone_mask)

    edge_ao = np.clip((-best_sd) / 0.0068, 0.0, 1.0)
    edge_ao = 0.79 + 0.21 * (edge_ao * edge_ao * (3.0 - 2.0 * edge_ao))

    # Neutral weathered castle grey palette
    base_grey = np.array([99.0, 101.0, 104.0], dtype=np.float32)
    tone_shift = stone_tone[..., None] * np.array([9.5, 9.5, 9.5], dtype=np.float32)
    warm_shift = stone_warmth[..., None] * np.array([3.0, 2.0, 0.0], dtype=np.float32)
    weather_var = (n_stone[..., None] - 0.5) * np.array([23.0, 23.0, 22.5], dtype=np.float32)
    grain_var = (n_grain[..., None] - 0.5) * np.array([10.5, 10.5, 10.5], dtype=np.float32)
    macro_var = (n_macro[..., None] - 0.5) * 2.5

    pitting = np.clip((0.35 - n_stone) * 2.1, 0.0, 1.0)[..., None]
    stone_rgb = (base_grey + tone_shift + warm_shift + weather_var + grain_var + macro_var) * edge_ao[..., None]
    stone_rgb = stone_rgb * (1.0 - pitting * 0.14)
    # Darken primary stone cracks so they read crisply across gameplay camera distances
    stone_rgb = stone_rgb * (1.0 - crack_mask[..., None] * 0.42)

    # Tight dark weathered mortar crevices with fine granite grit
    gravel_dark = np.array([46.0, 48.0, 52.0], dtype=np.float32)
    gravel_speck = np.clip((n_grit - 0.56) * 2.5, 0.0, 1.0)[..., None] * np.array([18.0, 18.0, 19.0], dtype=np.float32)
    mortar_rgb = gravel_dark + n_grain[..., None] * 12.0 + gravel_speck

    rgb = mortar_rgb * (1.0 - stone_mask[..., None]) + stone_rgb * stone_mask[..., None]

    # Subtle patchy moss hugging mortar crevices & damp bevel edges (breaks into small organic clusters)
    joint_prox = np.clip((best_sd + 0.0085) / 0.0110, 0.0, 1.0)
    damp_pocket = np.clip((n_damp - 0.56) * 4.2, 0.0, 1.0)
    seam_moss = np.clip(joint_prox * damp_pocket * (0.40 + 0.60 * n_moss_tex) + crack_mask * damp_pocket * 0.42, 0.0, 0.72)
    moss_base = np.array([54.0, 76.0, 44.0], dtype=np.float32) + n_moss_tex[..., None] * np.array([20.0, 24.0, 12.0], dtype=np.float32)
    rgb = rgb * (1.0 - seam_moss[..., None]) + moss_base * seam_moss[..., None]

    # Height map for crisp bevel, fractures & recessed/mossy relief
    h_stone = (
        0.58
        + stone_hoff
        + stone_tilt * 2.0
        + 0.14 * (n_stone - 0.5)
        + 0.06 * (n_grain - 0.5)
        - 0.09 * pitting[..., 0]
        - 0.26 * crack_mask
    ) * (0.70 + 0.30 * edge_ao)
    h_mortar = 0.20 + 0.12 * n_grit + 0.06 * n_grain
    h_map = h_mortar * (1.0 - stone_mask) + h_stone * stone_mask + 0.08 * seam_moss

    # Roughness: 0.74-0.84 on worn flagstones, 0.90-0.95 inside joints & moss
    r_stone = np.clip(0.79 + stone_roff - 0.05 * (n_stone - 0.5) + 0.08 * crack_mask, 0.70, 0.90)
    r_mortar = np.clip(0.92 + 0.04 * (1.0 - n_grit), 0.86, 0.96)
    r_map = np.clip(r_mortar * (1.0 - stone_mask) + r_stone * stone_mask + 0.06 * seam_moss, 0.70, 0.97)

    norm_rgb = height_to_normal_rgb(h_map, strength=3.2)
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
    print(f"[CastleGround] Baked seamless cracked+mossy courtyard stone PBR maps -> {TEX_DIR}")
    return p_col, p_nrm, p_rgh


def _splat_uv_bounds(key: str) -> tuple[float, float, float, float]:
    """Return exact (u0, u1, v0_bot, v1_top) UV rectangle for a named splat atlas region."""
    x0, y0, x1, y1 = SPLAT_RECTS[key]
    u0 = x0 / TEX_SIZE
    u1 = x1 / TEX_SIZE
    v1 = 1.0 - (y0 / TEX_SIZE)
    v0 = 1.0 - (y1 / TEX_SIZE)
    return (u0, u1, v0, v1)


def _smin(a: np.ndarray, b: np.ndarray, k: float) -> np.ndarray:
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1.0 - h) + a * h - k * h * (1.0 - h)


def _pebble_field(h: int, w: int, seed: int, freq_scale: int) -> tuple[np.ndarray, np.ndarray]:
    """Generate irregular organic pebble masks and per-pebble value tones without circular polka-dots."""
    n_a = _fbm_local(h, w, seed, (freq_scale * 2, freq_scale, max(2, freq_scale // 2)))
    n_b = _fbm_local(h, w, seed + 31, (freq_scale, max(2, freq_scale // 2)))
    mask = np.clip((n_a - 0.62) * 5.2, 0.0, 1.0)
    mask = mask * np.clip((n_b - 0.36) * 2.4, 0.0, 1.0)
    return mask, n_b


def _market_local_to_rbx(lx: float, lz: float) -> tuple[float, float]:
    cx, cz = MARKET_POS
    ca, sa = math.cos(MARKET_YAW), math.sin(MARKET_YAW)
    return (cx + lx * ca + lz * sa, cz - lx * sa + lz * ca)


def generate_walkway_slate_textures() -> tuple[Path, Path, Path]:
    """
    Generate Tex_CastleWalkwaySlate_{Color,Normal,Roughness}.png as a 1024x1024 RGBA splat atlas:
      - merchant_dirt: bespoke 41x30.5-stud packed warm dirt + gravel/moss apron for Building_Market
      - moss_colony & moss_drift: organic wall-base, fountain-rim & bench moss clusters
      - crack_star & crack_split: branching macro fault fractures breaking up tiled bricks
    """
    col = np.zeros((TEX_SIZE, TEX_SIZE, 4), dtype=np.uint8)
    height = np.full((TEX_SIZE, TEX_SIZE), 0.5, dtype=np.float32)
    rough = np.full((TEX_SIZE, TEX_SIZE), 220, dtype=np.uint8)

    def put_region(key: str, rgb: np.ndarray, alpha: np.ndarray, h_local: np.ndarray, r_local: np.ndarray) -> None:
        x0, y0, x1, y1 = SPLAT_RECTS[key]
        a_u8 = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
        col[y0:y1, x0:x1, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
        col[y0:y1, x0:x1, 3] = a_u8
        # Blend height gently toward neutral 0.5 where transparent so normal seams stay 0
        height[y0:y1, x0:x1] = 0.5 * (1.0 - alpha) + h_local * alpha
        rough[y0:y1, x0:x1] = np.clip(r_local * 255.0, 14, 250).astype(np.uint8)

    # 1. Merchant Bazaar Packed-Dirt Apron (640x544 px covering lx in [-20.5, 20.5], lz in [-13.5, 17.0])
    x0, y0, x1, y1 = SPLAT_RECTS["merchant_dirt"]
    w_m, h_m = x1 - x0, y1 - y0
    tx = np.linspace(0.0, 1.0, w_m, dtype=np.float32)[None, :]
    tz = np.linspace(0.0, 1.0, h_m, dtype=np.float32)[:, None]
    lx = DIRT_LX_MIN + tx * (DIRT_LX_MAX - DIRT_LX_MIN)
    lz = DIRT_LZ_MIN + tz * (DIRT_LZ_MAX - DIRT_LZ_MIN)

    lobe_stalls = (np.hypot(lx / 14.2, (lz + 2.4) / 7.2) - 1.0) * 7.2
    lobe_front = (np.hypot((lx + 0.4) / 11.2, (lz - 5.4) / 7.6) - 1.0) * 7.6
    lobe_left = np.hypot(lx + 11.8, lz + 0.2) - 5.0
    lobe_right = np.hypot(lx - 11.4, lz - 1.6) - 5.2
    sd_base = _smin(_smin(lobe_stalls, lobe_front, 3.0), _smin(lobe_left, lobe_right, 2.6), 2.8)

    n_mac = _fbm_local(h_m, w_m, 901, (64, 32, 16))
    n_med = _fbm_local(h_m, w_m, 902, (20, 10, 5))
    n_fine = _fbm_local(h_m, w_m, 903, (6, 3, 2))
    n_moss_m = _fbm_local(h_m, w_m, 904, (24, 12, 6))

    # World coordinates to gracefully fade before touching the South (+Z=60) or East (+X=80) fortress walls
    ca_m, sa_m = math.cos(MARKET_YAW), math.sin(MARKET_YAW)
    rx_w = MARKET_POS[0] + lx * ca_m + lz * sa_m
    rz_w = MARKET_POS[1] - lx * sa_m + lz * ca_m
    wall_fade = np.clip((57.0 - rz_w) / 2.2, 0.0, 1.0) * np.clip((77.0 - rx_w) / 2.2, 0.0, 1.0)
    box_fade = np.clip(np.minimum(np.minimum(tx, 1.0 - tx), np.minimum(tz, 1.0 - tz)) / 0.11, 0.0, 1.0)

    wobble = (n_mac - 0.5) * 4.4 + (n_med - 0.5) * 1.8
    sd_m = sd_base - wobble
    t_edge = np.clip((1.05 - sd_m) / 2.75, 0.0, 1.0)
    alpha_m = np.clip((t_edge * t_edge * (3.0 - 2.0 * t_edge)) ** 1.15 * wall_fade * box_fade, 0.0, 1.0)

    # Rich warm packed bazaar soil palette with crisp tonal mottling matching TrainingGrounds & previews
    soil_dark = np.array([64.0, 50.0, 38.0], dtype=np.float32)
    soil_mid = np.array([104.0, 84.0, 64.0], dtype=np.float32)
    soil_worn = np.array([128.0, 106.0, 84.0], dtype=np.float32)
    loam_var = np.clip(0.42 * n_mac + 0.38 * n_med + 0.20 * n_fine, 0.0, 1.0)[..., None]
    dirt_rgb = soil_dark * (1.0 - loam_var) + soil_mid * loam_var

    # Lighter worn footpath center under Bazaar_FlagstonePath & darker damp soil under counters (lz < -2)
    core_t = np.clip((-sd_m) / 2.8, 0.0, 1.0)
    counter_shadow = np.clip((-lz - 1.0) / 6.5, 0.0, 1.0) * np.clip((14.0 - np.abs(lx)) / 4.0, 0.0, 1.0)
    traffic_t = np.clip(core_t * (1.0 - 0.78 * counter_shadow) * (0.28 + 0.72 * n_med), 0.0, 1.0)[..., None]
    dirt_rgb = dirt_rgb * (1.0 - traffic_t * 0.72) + soil_worn * (traffic_t * 0.72)
    dirt_rgb = dirt_rgb * (1.0 - counter_shadow[..., None] * 0.32)

    # Embedded gravel grit + border pebbles + subtle edge moss near transition into grey courtyard bricks
    peb_med, peb_c = _pebble_field(h_m, w_m, 911, 7)
    peb_fin, _ = _pebble_field(h_m, w_m, 913, 3)
    rim_band = np.clip((0.80 - alpha_m) * (alpha_m * 2.4), 0.0, 1.0)
    peb_strength = np.clip(peb_med * (0.32 + 0.68 * rim_band) + peb_fin * 0.38, 0.0, 0.80)
    peb_col = np.array([96.0, 94.0, 90.0], dtype=np.float32) + peb_c[..., None] * np.array([26.0, 24.0, 22.0], dtype=np.float32)
    dirt_rgb = dirt_rgb * (1.0 - peb_strength[..., None]) + peb_col * peb_strength[..., None]

    moss_rim = np.clip(rim_band * (n_moss_m - 0.35) * 2.8, 0.0, 0.75)[..., None]
    moss_col = np.array([58.0, 82.0, 44.0], dtype=np.float32) + n_fine[..., None] * np.array([20.0, 24.0, 12.0], dtype=np.float32)
    dirt_rgb = dirt_rgb * (1.0 - moss_rim) + moss_col * moss_rim

    # Keep small scattered stone flecks visible at edge rim even where dirt feathers thin
    alpha_m = np.clip(alpha_m + peb_med * rim_band * 0.42, 0.0, 1.0) * wall_fade * box_fade

    h_dirt = 0.36 + 0.28 * n_med + 0.16 * n_fine + 0.20 * peb_strength - 0.08 * counter_shadow
    r_dirt = np.clip(0.90 - 0.08 * traffic_t[..., 0] + 0.04 * moss_rim[..., 0], 0.78, 0.96)
    put_region("merchant_dirt", dirt_rgb, alpha_m, h_dirt, r_dirt)

    # 2. Fragmented Organic Moss Colonies ("moss_colony", "moss_drift")
    # Carved with lacy stone openings so bricks peek cleanly through natural damp moss patches
    for m_key, rx_s, rz_s, seed_m in [
        ("moss_colony", 0.33, 0.31, 920),
        ("moss_drift",  0.38, 0.22, 930),
    ]:
        mx0, my0, mx1, my1 = SPLAT_RECTS[m_key]
        mw, mh = mx1 - mx0, my1 - my0
        ux = np.linspace(-0.5, 0.5, mw, dtype=np.float32)[None, :]
        vy = np.linspace(-0.5, 0.5, mh, dtype=np.float32)[:, None]
        nm1 = _fbm_local(mh, mw, seed_m, (48, 24, 12))
        nm2 = _fbm_local(mh, mw, seed_m + 5, (10, 5, 3))

        d_lobe1 = np.hypot((ux - 0.05) / rx_s, (vy - 0.02) / rz_s) - 1.0
        d_lobe2 = np.hypot((ux + 0.10) / (rx_s * 0.72), (vy + 0.05) / (rz_s * 0.72)) - 1.0
        d_m = np.minimum(d_lobe1, d_lobe2) - (nm1 - 0.5) * 0.75 - (nm2 - 0.5) * 0.30
        edge_b = np.clip(1.0 - np.maximum(np.abs(ux), np.abs(vy)) * 2.0, 0.0, 1.0)
        b_fade = np.clip(edge_b / 0.16, 0.0, 1.0)
        env = np.clip((-d_m) / 0.32, 0.0, 1.0)
        env = env * env * (3.0 - 2.0 * env)
        # Perforate moss body with fine organic gaps so bricks show inside the moss edges
        tufts = np.clip((nm1 * 0.45 + nm2 * 0.55 - 0.38) * 3.1, 0.0, 1.0)
        a_moss = np.clip(env * tufts * b_fade * 0.86, 0.0, 0.86)

        c_deep = np.array([44.0, 64.0, 35.0], dtype=np.float32)
        c_mid = np.array([62.0, 88.0, 46.0], dtype=np.float32)
        c_tip = np.array([78.0, 106.0, 56.0], dtype=np.float32)
        grad_m = np.clip(nm1 * 0.55 + nm2 * 0.45, 0.0, 1.0)[..., None]
        rgb_moss = np.where(
            grad_m < 0.55,
            c_deep * (1.0 - grad_m / 0.55) + c_mid * (grad_m / 0.55),
            c_mid * (1.0 - (grad_m - 0.55) / 0.45) + c_tip * ((grad_m - 0.55) / 0.45),
        )
        put_region(m_key, rgb_moss, a_moss, 0.52 + 0.22 * nm2 + 0.14 * a_moss, np.full((mh, mw), 0.93, dtype=np.float32))

    # 3. Crisp Macro Stone Crack Faults ("crack_star", "crack_split")
    # Uses 1D perpendicular displacement only so cracks stay razor-sharp with zero bubbly loops
    crack_defs = [
        ("crack_star", 940, [
            (0.0, 0.0, 0.37, 0.20, 0.0075),
            (0.0, 0.0, -0.34, 0.24, 0.0072),
            (0.0, 0.0, -0.05, -0.35, 0.0075),
            (0.12, 0.07, 0.32, -0.20, 0.0055),
        ]),
        ("crack_split", 950, [
            (-0.38, -0.05, 0.38, 0.07, 0.0075),
            (-0.07, 0.01, 0.16, -0.30, 0.0058),
            (0.04, 0.02, -0.16, 0.30, 0.0056),
        ]),
    ]
    for c_key, seed_c, segs in crack_defs:
        cx0, cy0, cx1, cy1 = SPLAT_RECTS[c_key]
        cw, ch = cx1 - cx0, cy1 - cy0
        ux = np.linspace(-0.5, 0.5, cw, dtype=np.float32)[None, :]
        vy = np.linspace(-0.5, 0.5, ch, dtype=np.float32)[:, None]
        nc1 = _fbm_local(ch, cw, seed_c, (40, 20, 10))
        nc2 = _fbm_local(ch, cw, seed_c + 7, (8, 4))

        crack_hit = np.zeros((ch, cw), dtype=np.float32)
        for ax, ay, bx, by, width_c in segs:
            abx, aby = bx - ax, by - ay
            ab_len = math.hypot(abx, aby) + 1e-8
            tx_dir, ty_dir = abx / ab_len, aby / ab_len
            nx_dir, ny_dir = -ty_dir, tx_dir
            along = (ux - ax) * tx_dir + (vy - ay) * ty_dir
            in_seg = (along >= 0.0) & (along <= ab_len)
            perp = (ux - ax) * nx_dir + (vy - ay) * ny_dir
            # Pure 1D normal displacement preserves clean fissure silhouette with zero self-folding
            jitter = (nc1 - 0.5) * 0.036 + (nc2 - 0.5) * 0.008
            d_seg = np.abs(perp + jitter)
            taper = np.clip(np.sin(np.clip(along / ab_len, 0.0, 1.0) * math.pi) * 1.6, 0.25, 1.0)
            hit = np.where(in_seg, np.clip(1.0 - d_seg / (width_c * taper), 0.0, 1.0), 0.0)
            crack_hit = np.maximum(crack_hit, hit)

        radial = np.hypot(ux / 0.43, vy / 0.43)
        outer_fade = np.clip((1.0 - radial) / 0.25, 0.0, 1.0)
        box_f = np.clip(np.minimum(0.5 - np.abs(ux), 0.5 - np.abs(vy)) / 0.08, 0.0, 1.0)

        bruise = np.clip(crack_hit * 0.3 + np.clip(0.35 - radial, 0.0, 0.35) * 0.55 * nc1, 0.0, 0.35)
        alpha_c = np.clip(np.maximum(crack_hit * 0.90, bruise * 0.50) * outer_fade * box_f, 0.0, 0.90)

        col_bruise = np.array([74.0, 76.0, 80.0], dtype=np.float32) + nc2[..., None] * 12.0
        col_crevice = np.array([22.0, 24.0, 28.0], dtype=np.float32) + nc2[..., None] * 6.0
        crev_mix = np.clip(crack_hit * 1.4, 0.0, 1.0)[..., None]
        rgb_c = col_bruise * (1.0 - crev_mix) + col_crevice * crev_mix
        h_c = 0.52 - 0.38 * crack_hit + 0.04 * (nc2 - 0.5)
        r_c = np.clip(0.84 + 0.12 * crack_hit, 0.78, 0.96)
        put_region(c_key, rgb_c, alpha_c, h_c, r_c)

    norm_rgb = height_to_normal_rgb(height, strength=2.6)
    norm_rgba = np.dstack([norm_rgb, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])
    rough_rgba = np.dstack([rough, rough, rough, np.full((TEX_SIZE, TEX_SIZE), 255, dtype=np.uint8)])

    p_col = TEX_DIR / "Tex_CastleWalkwaySlate_Color.png"
    p_nrm = TEX_DIR / "Tex_CastleWalkwaySlate_Normal.png"
    p_rgh = TEX_DIR / "Tex_CastleWalkwaySlate_Roughness.png"
    write_png_rgba(p_col, col)
    write_png_rgba(p_nrm, norm_rgba)
    write_png_rgba(p_rgh, rough_rgba)
    print(f"[CastleGround] Baked RGBA dirt & natural weathering splat atlas -> {TEX_DIR}")
    return p_col, p_nrm, p_rgh


# ---------------------------------------------------------------------------
# 2. Blender Material & Mesh Construction
# ---------------------------------------------------------------------------
def create_pbr_material(name: str, p_col: Path, p_nrm: Path, p_rgh: Path, blend_alpha: bool = False) -> bpy.types.Material:
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
    if blend_alpha:
        nt.links.new(tex_col.outputs["Alpha"], bsdf.inputs["Alpha"])

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
    if math.hypot(rx, rz) < 16.5:
        return 0.0
    if math.hypot(rx - 49.5, rz - 35.5) < 23.0:
        return 0.0
    if -74.0 <= rx <= -18.0 and 10.0 <= rz <= 56.0:
        return 0.0
    return 1.0


def _courtyard_floor_y(rx: float, rz: float) -> float:
    w_rel = _flat_zone_weight(rx, rz)
    return FLOOR_Y + 0.005 * math.sin(rx * 0.21 + 0.7) * math.cos(rz * 0.19 - 0.4) * w_rel


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
            ry = _courtyard_floor_y(rx, rz)
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


def _add_splat_grid(
    bm: bmesh.types.BMesh,
    uv,
    splat_key: str,
    nx_q: int,
    nz_q: int,
    pt_fn,
    overlay_lift: float,
) -> None:
    """Append a floor-conformed rectangular UV splat patch from SPLAT_RECTS[splat_key]."""
    u0, u1, v0, v1 = _splat_uv_bounds(splat_key)
    grid: list[list[bmesh.types.BMVert]] = []
    for iz in range(nz_q + 1):
        tz = iz / nz_q
        row = []
        for ix in range(nx_q + 1):
            tx = ix / nx_q
            rx, rz = pt_fn(tx, tz)
            ry = _courtyard_floor_y(rx, rz) + overlay_lift
            row.append(bm.verts.new(rbx_to_blender(rx, ry, rz)))
        grid.append(row)

    for iz in range(nz_q):
        tv_top = v1 - (iz / nz_q) * (v1 - v0)
        tv_bot = v1 - ((iz + 1) / nz_q) * (v1 - v0)
        for ix in range(nx_q):
            tu_l = u0 + (ix / nx_q) * (u1 - u0)
            tu_r = u0 + ((ix + 1) / nx_q) * (u1 - u0)
            f = bm.faces.new([grid[iz][ix], grid[iz + 1][ix], grid[iz + 1][ix + 1], grid[iz][ix + 1]])
            f.smooth = True
            f.loops[0][uv].uv = (tu_l, tv_top)
            f.loops[1][uv].uv = (tu_l, tv_bot)
            f.loops[2][uv].uv = (tu_r, tv_bot)
            f.loops[3][uv].uv = (tu_r, tv_top)


def build_courtyard_dirt_and_weathering(
    mat_splats: bpy.types.Material, col: bpy.types.Collection
) -> tuple[bpy.types.Object, int]:
    """
    Build `Courtyard_DirtAndWeathering`:
      1. Merchant Bazaar packed-dirt bed at (50, 36) rotated to Market yaw (+0.012 above brick floor).
      2. Non-overlapping alpha-feathered moss colonies (fountain plinth rim, wall bases, shaded corners).
      3. Non-overlapping alpha-feathered macro fault crack patches breaking up tile repetition.
      No radial walkways and no fountain plaza rings remain.
    """
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    # 1. Merchant Bazaar Dirt Apron (12x10 conformed grid in Market-local coordinates)
    ca_m, sa_m = math.cos(MARKET_YAW), math.sin(MARKET_YAW)

    def market_pt(tx: float, tz: float) -> tuple[float, float]:
        lx = DIRT_LX_MIN + tx * (DIRT_LX_MAX - DIRT_LX_MIN)
        lz = DIRT_LZ_MIN + tz * (DIRT_LZ_MAX - DIRT_LZ_MIN)
        return (MARKET_POS[0] + lx * ca_m + lz * sa_m, MARKET_POS[1] - lx * sa_m + lz * ca_m)

    _add_splat_grid(bm, uv, "merchant_dirt", 12, 10, market_pt, overlay_lift=0.012)

    # Track placed decals (cx, cz, radius) so transparent quads never overlap and Z-sort cleanly
    placed: list[tuple[float, float, float]] = [(49.5, 35.5, 22.0)]

    def can_place(cx: float, cz: float, w: float, l: float) -> bool:
        r = 0.48 * max(w, l)
        # Keep inside inner courtyard walls and out of Fountain core / Training arena interior / Market dirt
        if abs(cx) > 77.5 or abs(cz) > 57.5:
            return False
        if math.hypot(cx, cz) < 12.2:
            return False
        if math.hypot(cx + 45.7, cz - 32.0) < 20.5:
            return False
        if math.hypot(cx + 41.5, cz + 26.4) < 18.0:
            return False
        for px, pz, pr in placed:
            if math.hypot(cx - px, cz - pz) < (r + pr + 0.3):
                return False
        placed.append((cx, cz, r))
        return True

    def add_decal(splat_key: str, cx: float, cz: float, w: float, l: float, yaw_deg: float, lift: float) -> None:
        if not can_place(cx, cz, w, l):
            return
        yaw = math.radians(yaw_deg)
        ca, sa = math.cos(yaw), math.sin(yaw)

        def decal_pt(tx: float, tz: float) -> tuple[float, float]:
            lx = (tx - 0.5) * w
            lz = (tz - 0.5) * l
            return (cx + lx * ca + lz * sa, cz - lx * sa + lz * ca)

        _add_splat_grid(bm, uv, splat_key, 2, 2, decal_pt, overlay_lift=lift)

    # 2. Fountain plinth rim moss drifts (R = 14.5 hugging plinth outside 12.7 radius)
    for ang_deg, w_m, l_m in [(22, 4.0, 9.0), (96, 4.0, 8.5), (168, 4.0, 8.5), (242, 4.0, 9.0), (312, 4.0, 8.5)]:
        rad = math.radians(ang_deg)
        mx, mz = math.sin(rad) * 14.8, math.cos(rad) * 14.8
        add_decal("moss_drift", mx, mz, l_m, w_m, ang_deg, lift=0.007)

    # 3. Shaded perimeter wall plinth moss colonies & drifts
    wall_moss = [
        ("moss_drift",  -74.0, -18.0, 9.5, 4.8,  90.0),
        ("moss_colony", -73.0,   6.0, 7.2, 6.2,  12.0),
        ("moss_drift",  -14.0, -54.5, 9.5, 4.5,   4.0),
        ("moss_colony",  16.0, -53.8, 7.0, 5.8, -18.0),
        ("moss_drift",   -8.0,  54.2, 9.8, 4.6, 178.0),
        ("moss_colony",  22.0,  53.8, 6.8, 5.6, 165.0),
        ("moss_colony", -66.0, -49.5, 8.0, 6.8,  38.0),
        ("moss_colony",  68.5, -49.5, 7.8, 6.6, -42.0),
        ("moss_drift",   73.8, -28.0, 9.2, 4.6, -90.0),
        ("moss_drift",   73.8,  14.0, 8.8, 4.6, -88.0),
        ("moss_colony", -22.0, -51.0, 6.5, 5.5,  20.0),
        ("moss_colony",  22.0,  14.0, 6.4, 5.4, -35.0),
    ]
    for skey, mx, mz, mw, ml, myaw in wall_moss:
        add_decal(skey, mx, mz, mw, ml, myaw, lift=0.007)

    # 4. Macro stone fault cracks near facility approaches & open bays
    macro_cracks = [
        ("crack_star",   31.0,   0.0, 8.2, 7.6,  14.0),  # Blacksmith hearth approach
        ("crack_split",  35.5, -24.5, 8.8, 5.2, -36.0),  # Summoning Portal steps
        ("crack_star",  -23.5, -14.5, 8.4, 7.4,  34.0),  # The Pit steps
        ("crack_split", -20.0,  15.0, 8.6, 5.2,  42.0),  # Training Grounds gate
        ("crack_star",  -16.0, -34.0, 8.0, 7.0, -22.0),  # NW open bay
        ("crack_split",  14.0, -37.0, 8.5, 5.0,  28.0),  # NE open bay
        ("crack_star",    8.0, -45.0, 7.4, 6.6,  65.0),  # Bridge gate bay
        ("crack_split",  10.0,  32.0, 8.6, 5.0, -18.0),  # SE open bay
        ("crack_star",   -8.0,  39.0, 7.8, 7.0,  48.0),  # South bay
        ("crack_split", -19.0,   2.5, 8.2, 4.8,  76.0),  # West fountain bay
        ("crack_star",   25.5, -14.5, 7.4, 6.8, -52.0),  # East fountain bay
        ("crack_split",  -4.0, -22.5, 7.8, 4.8,   9.0),  # North fountain approach
    ]
    for ckey, cx, cz, cw, cl, cyaw in macro_cracks:
        add_decal(ckey, cx, cz, cw, cl, cyaw, lift=0.008)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    tris = sum(max(1, len(f.verts) - 2) for f in bm.faces)
    mesh = bpy.data.meshes.new("Courtyard_DirtAndWeathering_Mesh")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Courtyard_DirtAndWeathering", mesh)
    col.objects.link(obj)
    mesh.materials.append(mat_splats)
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

    mat_stone = create_pbr_material("Mat_CastleCourtyardStone", s_col, s_nrm, s_rgh, blend_alpha=False)
    mat_splats = create_pbr_material("Mat_CastleWalkwaySlate", w_col, w_nrm, w_rgh, blend_alpha=True)

    print("[CastleGround] Building courtyard ground meshes...")
    floor_obj, floor_tris = build_courtyard_flagstone_floor(mat_stone, col)
    overlay_obj, overlay_tris = build_courtyard_dirt_and_weathering(mat_splats, col)

    export_objs = [floor_obj, overlay_obj]
    tri_breakdown = {
        floor_obj.name: floor_tris,
        overlay_obj.name: overlay_tris,
    }

    if args.single_mesh:
        bpy.ops.object.select_all(action="DESELECT")
        floor_obj.select_set(True)
        overlay_obj.select_set(True)
        bpy.context.view_layer.objects.active = floor_obj
        bpy.ops.object.join()
        floor_obj.name = "CastleCourtyard_Ground"
        export_objs = [floor_obj]
        tri_breakdown = {floor_obj.name: floor_tris + overlay_tris}

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
