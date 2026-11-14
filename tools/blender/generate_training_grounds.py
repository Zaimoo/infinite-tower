"""
=============================================================================
Infinite Towers: Become a Master! - 3D Environment Pipeline
Asset: Medieval Training Grounds (`TrainingGrounds.fbx` / `TrainingArea`)
Target Engine: Blender 5.x -> Roblox Studio (ReplicatedStorage.Assets.PlotFacilities.TrainingArea)
=============================================================================
Generates the polygonal level-ground Medieval Training Grounds:
  - `Arena_Floor`      : Thin (0.08 stud, non-sunken) polygonal cobble-to-earth pad
  - `Perimeter_Fence`  : Chamfered polygon split-rail wooden fence leaving entrance gap & rear wall clearance
  - `Entrance_Archway` : Doorless stone-and-timber pointed V-gabled entrance archway (~8 studs wide)
  - `Training_Props`   : 2 circular red/white bullseye targets, interior weapon racks, entrance iron rack, barrels & crates
  - `Dummy_1_Base..5_Base` & `Dummy_1_Body..5_Body` : 5 animatable strike dummies with Body origin at the lower hinge (ry=1.15)

Coordinate Convention (1 Blender meter = 1 Roblox stud):
  In Roblox TrainingArea-local space (`Center=(-38, 0, 30)`, `RotationY=-51.71 deg`):
    -rz = Front (-Z toward Plaza Fountain & Path_TrainingArea)
    +rz = Back (+Z toward CornerSpire_SE Bastion)
    +rx = Left when looking inward from Fountain (Wall_EastLeft side)
    -rx = Right when looking inward from Fountain (Wall_South / Building_ThePit side)
    +ry = Up (Y=0 rests on courtyard grass top Y=12.0)

  Using rbx_to_blender(rx, ry, rz) = (rx, -rz, ry) and exporting with
  axis_forward="Z", axis_up="Y" preserves (rx, ry, rz) 1-to-1 in FBX.
=============================================================================
"""

from __future__ import annotations

import json
import math
import os
import random
import struct
import zlib
from pathlib import Path

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

REPO_ROOT = Path(r"C:\WORK\infinite-tower")
ASSET_DIR = REPO_ROOT / "assets" / "models" / "facilities"
TEX_DIR = ASSET_DIR / "textures" / "training_grounds"
FBX_PATH = ASSET_DIR / "TrainingGrounds.fbx"
MANIFEST_PATH = ASSET_DIR / "training_grounds_manifest.json"
COLLECTION_NAME = "TrainingGrounds_Prefab"

# Perfectly left-right symmetrical (rx <-> -rx across X=0 centerline) larger polygonal perimeter!
# ScreenRight = -rx; ScreenLeft = +rx; Front/Entrance = -rz; Back/BastionApex = +rz
FENCE_CHAIN_LEFT = [
    (5.0, -12.0),    # GateL (left stone pier center)
    (16.0, -9.5),    # V1_L front-left shoulder
    (23.8, 2.5),     # V2_L outer-left corner (~3.8 studs clear of Wall_EastLeft plinth)
    (12.0, 18.5),    # V3_L back-left shoulder (~3.1 studs clear of Wall_EastLeft plinth)
    (0.0, 27.5),     # Apex center (~7.2 studs clear in front of CornerSpire_SE steps)
    (-12.0, 18.5),   # V3_R back-right shoulder
    (-23.8, 2.5),    # V2_R outer-right corner
    (-16.0, -9.5),   # V1_R front-right shoulder
    (-5.0, -12.0),   # GateR (right stone pier center)
]

FLOOR_POLYGON_2D = [
    (0.0, -12.8),    # Threshold front cobble apron meeting Path_TrainingArea_Slab_3
    (5.4, -12.4),
    (16.4, -9.85),
    (24.25, 2.55),
    (12.35, 18.85),
    (0.0, 27.95),
    (-12.35, 18.85),
    (-24.25, 2.55),
    (-16.4, -9.85),
    (-5.4, -12.4),
]

# 5 animatable strike dummies in a symmetrical chevron/quincunx formation across the courtyard
DUMMY_SPECS = [
    # Dummy 1: Front-Right flank, faces inward toward courtyard center
    {"id": 1, "rx": -8.5, "rz": -1.5, "facing_xz": (0.85, -0.53)},
    # Dummy 2: Center foreground cobble circle on X=0 symmetry axis, faces Entrance
    {"id": 2, "rx": 0.0, "rz": 2.0, "facing_xz": (0.0, -1.0)},
    # Dummy 3: Front-Left flank (exact mirror of Dummy 1), faces inward toward courtyard center
    {"id": 3, "rx": 8.5, "rz": -1.5, "facing_xz": (-0.85, -0.53)},
    # Dummy 4: Back-Right flank, faces forward-center
    {"id": 4, "rx": -6.2, "rz": 11.2, "facing_xz": (0.45, -0.89)},
    # Dummy 5: Back-Left flank (exact mirror of Dummy 4), faces forward-center
    {"id": 5, "rx": 6.2, "rz": 11.2, "facing_xz": (-0.45, -0.89)},
]


def rbx_to_blender(rx: float, ry: float, rz: float) -> Vector:
    return Vector((rx, -rz, ry))


def facing_xz_to_blender_yaw(fx: float, fz: float) -> float:
    """In local dummy coords, local Front = -Z_rbx = +Y_bl (when rot=0) or -Y_bl.
    We build dummy body facing -Y_bl (`front` toward -Z_rbx when yaw=0? Wait:
    in rbx_to_blender, +rx=+X_bl, -rz=+Y_bl, +rz=-Y_bl).
    So dummy Front in Blender XY is `(fx, -fz)`!
    If unrotated dummy has its chest facing `-Y_bl` (i.e. `(0, -1)`), rotating by Z angle `theta`
    turns `(0, -1)` into `(sin(theta), -cos(theta))`.
    Match `(sin(theta), -cos(theta)) = (fx, -fz)` => `theta = atan2(fx, fz)`?
    Wait: for fx=0, fz=-1 (-Z_rbx = Entrance): `(-fz)=+1`. We want `(sin(theta), -cos(theta)) = (0, +1)`, so `theta = pi` (`atan2(fx, -fz)` for `(0, +1)` -> if unrotated chest faces `+Y_bl` (`-Z_rbx`), `rotZ(theta)` turns `(0, 1)` into `(-sin(theta), cos(theta))`! Match `(-sin, cos) = (fx, -fz)` -> `theta = math.atan2(-fx, -fz)`!)."""
    return math.atan2(-fx, -fz)


# =============================================================================
# 1. PROCEDURAL PNG WRITER & PBR TEXTURE GENERATION
# =============================================================================
def write_png(path: Path, rgba_or_rgb: bytes, width: int, height: int, channels: int = 3) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    color_type = 6 if channels == 4 else 2
    stride = width * channels
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        start = y * stride
        raw.extend(rgba_or_rgb[start : start + stride])

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, color_type, 0, 0, 0)
    idat = zlib.compress(bytes(raw), level=6)
    png_bytes = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    path.write_bytes(png_bytes)


def _hash_noise_grid(res: int, cells: int, seed: int) -> list[float]:
    import numpy as np

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


def _fbm(res: int, octaves: list[tuple[int, float]], seed: int) -> "np.ndarray":
    import numpy as np

    acc = np.zeros((res, res), dtype=np.float32)
    w_sum = 0.0
    for idx, (c, w) in enumerate(octaves):
        acc += _hash_noise_grid(res, c, seed + idx * 37) * w
        w_sum += w
    return acc / max(w_sum, 1e-6)


def _height_to_normal_u8(height, strength: float) -> "np.ndarray":
    import numpy as np

    dx = 0.5 * (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1))
    dy = 0.5 * (np.roll(height, 1, axis=0) - np.roll(height, -1, axis=0))
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    nrm = np.stack([nx * inv * 0.5 + 0.5, ny * inv * 0.5 + 0.5, nz * inv * 0.5 + 0.5], axis=-1)
    return np.clip(nrm * 255.0, 0, 255).astype(np.uint8)


def _worley_cobble(res: int, cells: int, jitter: float, seed: int):
    import numpy as np

    rng = np.random.default_rng(seed)
    px = (np.arange(cells)[None, :] + 0.5 + rng.uniform(-0.45 * jitter, 0.45 * jitter, (cells, cells))) / cells
    py = (np.arange(cells)[:, None] + 0.5 + rng.uniform(-0.45 * jitter, 0.45 * jitter, (cells, cells))) / cells
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


def generate_textures() -> dict[str, dict[str, Path]]:
    import numpy as np

    TEX_DIR.mkdir(parents=True, exist_ok=True)
    registry: dict[str, dict[str, Path]] = {}

    def save_trio(name: str, col_u8, h_f32, r_f32, nrm_strength: float) -> None:
        r_res = col_u8.shape[0]
        c_p = TEX_DIR / f"{name}_Color.png"
        n_p = TEX_DIR / f"{name}_Normal.png"
        r_p = TEX_DIR / f"{name}_Roughness.png"
        write_png(c_p, np.clip(col_u8, 0, 255).astype(np.uint8).tobytes(), r_res, r_res, 3)
        write_png(n_p, _height_to_normal_u8(h_f32, nrm_strength).tobytes(), r_res, r_res, 3)
        ru = np.repeat(np.clip(r_f32 * 255.0, 12, 248).astype(np.uint8)[..., None], 3, axis=-1)
        write_png(r_p, ru.tobytes(), r_res, r_res, 3)
        registry[name] = {"Color": c_p, "Normal": n_p, "Roughness": r_p}

    # 1. Tex_ArenaGround (1024x1024): World-mapped polygon UV rx=[-26..+26], rz=[-16..+32] -> [0..1]
    R = 1024
    u = np.linspace(-26.0, 26.0, R, dtype=np.float32)[None, :]
    v = np.linspace(32.0, -16.0, R, dtype=np.float32)[:, None]
    # Center cobble zone centered symmetrically at (rx=0, rz=4.5) extending forward into entrance threshold!
    dist_center = np.sqrt((u * 0.94) ** 2 + ((v - 4.5) * 0.92) ** 2)
    dist_path = np.sqrt((u * 1.15) ** 2 + (np.maximum(0.0, -v - 2.0) * 0.35) ** 2)
    f_big = _fbm(R, [(5, 1.0), (14, 0.65), (36, 0.35)], seed=701)
    f_fine = _fbm(R, [(42, 0.7), (96, 0.5), (180, 0.3)], seed=707)
    edge_cob, cid_cob = _worley_cobble(R, cells=30, jitter=0.82, seed=713)

    cobble_mask = np.clip((13.6 + (f_big - 0.5) * 4.2 - dist_center) / 2.2, 0.0, 1.0)
    # Also extend cobbles along the entrance walkway (|rx| < 4.7, rz < 0)
    walkway_mask = np.clip((4.7 + (f_big - 0.5) * 2.0 - np.abs(u)) / 1.4, 0.0, 1.0) * np.clip((-v) / 4.0, 0.0, 1.0)
    cobble_weight = np.maximum(cobble_mask, walkway_mask)

    # Cobble color (warm weathered granite #62605C + dark mortar + subtle moss)
    stone_shade = 0.80 + 0.28 * cid_cob + 0.14 * (f_fine - 0.5)
    cob_col = np.stack([
        104.0 * stone_shade,
        99.0 * stone_shade + 4.0 * (f_big - 0.5),
        92.0 * stone_shade,
    ], axis=-1)
    mortar_col = np.array([58.0, 54.0, 48.0], dtype=np.float32)
    cob_final = mortar_col + (cob_col - mortar_col) * edge_cob[..., None]

    # Earthy perimeter dirt (#6E6254 warm brown earth + pebbles + scattered grass moss hint near fence)
    earth_base = np.array([112.0, 96.0, 78.0], dtype=np.float32)
    earth_dark = np.array([86.0, 72.0, 58.0], dtype=np.float32)
    earth_var = np.clip(0.3 + 0.55 * f_big + 0.25 * f_fine, 0.0, 1.0)[..., None]
    earth_final = earth_dark * (1.0 - earth_var) + earth_base * earth_var
    moss_speck = np.clip((f_big * f_fine - 0.36) * 6.0, 0.0, 1.0) * (1.0 - 0.5 * cobble_weight)
    moss_col = np.array([76.0, 92.0, 54.0], dtype=np.float32)
    ground_col = earth_final * (1.0 - cobble_weight[..., None]) + cob_final * cobble_weight[..., None]
    ground_col = ground_col * (1.0 - moss_speck[..., None] * 0.45) + moss_col * (moss_speck[..., None] * 0.45)

    ground_h = (0.3 + 0.4 * edge_cob + 0.2 * cid_cob + 0.1 * f_fine) * cobble_weight + (0.25 + 0.35 * f_fine) * (1.0 - cobble_weight)
    ground_r = 0.72 * cobble_weight + 0.88 * (1.0 - cobble_weight) + (1.0 - edge_cob) * cobble_weight * 0.18
    save_trio("Tex_ArenaGround", ground_col, ground_h, ground_r, nrm_strength=4.5)

    # 2. Tex_TrainingProps (1024x1024 4x4 padded tile atlas -> crisp per-material UV islands)
    A = 1024
    T = A // 4  # 256 px per tile
    col_a = np.zeros((A, A, 3), dtype=np.float32)
    h_a = np.full((A, A), 0.5, dtype=np.float32)
    r_a = np.full((A, A), 0.72, dtype=np.float32)

    noise_g = _fbm(T, [(8, 0.9), (22, 0.6), (54, 0.35)], seed=801)
    # Woodgrain streaks (elongated vertically along tile)
    wood_streak = _hash_noise_grid(T, 32, seed=811) * 0.55 + _fbm(T, [(6, 0.7), (28, 0.4)], seed=815) * 0.45
    row_f = np.linspace(0.0, 1.0, T, dtype=np.float32)[:, None]
    col_f = np.linspace(0.0, 1.0, T, dtype=np.float32)[None, :]
    grain_v = np.sin(col_f * math.pi * 24.0 + noise_g * 5.0) * 0.5 + 0.5

    def put_tile(gx: int, gy: int, tc, th, tr):
        y0, y1 = gy * T, (gy + 1) * T
        x0, x1 = gx * T, (gx + 1) * T
        col_a[y0:y1, x0:x1] = tc
        h_a[y0:y1, x0:x1] = th
        r_a[y0:y1, x0:x1] = tr

    # Row 0 (top V=0.75..1.0 in Blender -> row 0..256 in image):
    # (0,0) Cedar fence wood (#5C4033)
    put_tile(0, 0, np.stack([78 + 26 * grain_v, 54 + 18 * grain_v, 42 + 14 * grain_v], -1), 0.45 + 0.25 * grain_v, 0.78)
    # (1,0) Lighter pine crate planks (#7A5638) with plank groove lines
    plank_sep = np.clip(np.abs(((row_f * 4.0) % 1.0) - 0.5) * 14.0 - 5.8, 0.0, 1.0)
    put_tile(1, 0, np.stack([112 + 24 * wood_streak - 28 * plank_sep, 79 + 18 * wood_streak - 22 * plank_sep, 52 + 14 * wood_streak - 16 * plank_sep], -1),
             0.55 - 0.35 * plank_sep + 0.1 * grain_v, 0.75)
    # (2,0) Dark barrel oak (#64432C)
    stave_sep = np.clip(np.abs(((col_f * 8.0) % 1.0) - 0.5) * 16.0 - 6.8, 0.0, 1.0)
    put_tile(2, 0, np.stack([92 + 20 * grain_v - 30 * stave_sep, 62 + 14 * grain_v - 22 * stave_sep, 40 + 10 * grain_v - 15 * stave_sep], -1),
             0.55 - 0.35 * stave_sep + 0.12 * grain_v, 0.74)
    # (3,0) Shingle roof (#4B3629) overlapping rows
    sh_row = ((row_f * 6.0) % 1.0)
    sh_seam = np.clip(1.0 - sh_row * 6.0, 0.0, 1.0)
    put_tile(3, 0, np.stack([72 + 18 * noise_g - 20 * sh_seam, 52 + 14 * noise_g - 15 * sh_seam, 40 + 10 * noise_g - 12 * sh_seam], -1),
             0.4 + 0.35 * sh_row - 0.2 * sh_seam, 0.80)

    # Row 1:
    # (0,1) Fieldstone archway pier (#8A847A chunky medieval masonry)
    ed_st, cid_st = _worley_cobble(T, cells=4, jitter=0.72, seed=821)
    st_s = 0.84 + 0.24 * cid_st + 0.08 * (noise_g - 0.5)
    put_tile(0, 1, np.stack([138 * st_s * (0.64 + 0.36 * ed_st), 130 * st_s * (0.64 + 0.36 * ed_st), 118 * st_s * (0.64 + 0.36 * ed_st)], -1),
             0.3 + 0.5 * ed_st + 0.15 * noise_g, 0.82)
    # (1,1) Dark wrought iron (#202328)
    put_tile(1, 1, np.stack([32 + 12 * noise_g, 35 + 12 * noise_g, 40 + 14 * noise_g], -1), 0.5 + 0.15 * noise_g, 0.36)
    # (2,1) Polished weapon steel (#9DA5B0)
    put_tile(2, 1, np.stack([152 + 24 * wood_streak, 160 + 24 * wood_streak, 172 + 24 * wood_streak], -1), 0.55 + 0.1 * noise_g, 0.26)
    # (3,1) Warm leather strapping (#4A2E1E)
    put_tile(3, 1, np.stack([72 + 16 * noise_g, 44 + 12 * noise_g, 28 + 10 * noise_g], -1), 0.48 + 0.15 * noise_g, 0.62)

    # Row 2:
    # (0,2) Padded yellow straw burlap (#EAB308)
    weave = (np.sin(row_f * math.pi * 48.0) * np.sin(col_f * math.pi * 48.0)) * 0.5 + 0.5
    put_tile(0, 2, np.stack([224 + 22 * weave + 12 * (noise_g - 0.5), 174 + 18 * weave, 22 + 12 * noise_g], -1),
             0.45 + 0.2 * weave, 0.86)
    # (1,2) Crimson target / dummy sash (#DC2626)
    put_tile(1, 2, np.stack([208 + 20 * weave, 36 + 10 * noise_g, 36 + 10 * noise_g], -1), 0.48 + 0.15 * weave, 0.72)
    # (2,2) Cream-white bullseye paint (#F2EDE2)
    put_tile(2, 2, np.stack([236 + 10 * noise_g, 232 + 10 * noise_g, 220 + 10 * noise_g], -1), 0.48 + 0.1 * noise_g, 0.74)
    # (3,2) Dark stained beam wood (#4B3224)
    put_tile(3, 2, np.stack([66 + 22 * grain_v, 44 + 15 * grain_v, 31 + 11 * grain_v], -1), 0.45 + 0.22 * grain_v, 0.76)

    # Row 3: solid accents + radial painted bullseye disc in (0,3)!
    # (0,3) Concentric Bullseye Face (3 rings + outer wood rim!)
    cx_t = (col_f - 0.5) * 2.0
    cy_t = (row_f - 0.5) * 2.0
    rr = np.sqrt(cx_t * cx_t + cy_t * cy_t)
    bull_rgb = np.zeros((T, T, 3), dtype=np.float32)
    bull_rgb[:] = np.array([105.0, 72.0, 44.0], dtype=np.float32)  # outer wood bezel
    bull_rgb = np.where((rr <= 0.92)[..., None], np.array([212.0, 38.0, 38.0], dtype=np.float32), bull_rgb)
    bull_rgb = np.where((rr <= 0.64)[..., None], np.array([242.0, 238.0, 228.0], dtype=np.float32), bull_rgb)
    bull_rgb = np.where((rr <= 0.34)[..., None], np.array([212.0, 38.0, 38.0], dtype=np.float32), bull_rgb)
    bull_rgb = np.where((rr <= 0.14)[..., None], np.array([242.0, 238.0, 228.0], dtype=np.float32), bull_rgb)
    bull_rgb = bull_rgb * (0.90 + 0.14 * grain_v[..., None])
    put_tile(0, 3, bull_rgb, 0.5 + 0.08 * grain_v, 0.70)
    put_tile(1, 3, np.broadcast_to(np.array([92, 66, 44], dtype=np.float32), (T, T, 3)), 0.5, 0.78)
    put_tile(2, 3, np.broadcast_to(np.array([44, 46, 52], dtype=np.float32), (T, T, 3)), 0.5, 0.36)
    put_tile(3, 3, np.broadcast_to(np.array([218, 178, 32], dtype=np.float32), (T, T, 3)), 0.5, 0.84)

    save_trio("Tex_TrainingProps", col_a, h_a, r_a, nrm_strength=3.0)
    return registry


def build_pbr_material(name: str, tex_set: dict[str, Path]) -> bpy.types.Material:
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    def load_img(path: Path, colorspace: str):
        img = bpy.data.images.load(str(path), check_existing=True)
        img.colorspace_settings.name = colorspace
        return img

    tex_col = nodes.new("ShaderNodeTexImage")
    tex_col.image = load_img(tex_set["Color"], "sRGB")
    links.new(tex_col.outputs["Color"], bsdf.inputs["Base Color"])

    tex_rgh = nodes.new("ShaderNodeTexImage")
    tex_rgh.image = load_img(tex_set["Roughness"], "Non-Color")
    links.new(tex_rgh.outputs["Color"], bsdf.inputs["Roughness"])

    tex_nrm = nodes.new("ShaderNodeTexImage")
    tex_nrm.image = load_img(tex_set["Normal"], "Non-Color")
    nrm_node = nodes.new("ShaderNodeNormalMap")
    nrm_node.inputs["Strength"].default_value = 0.85
    links.new(tex_nrm.outputs["Color"], nrm_node.inputs["Color"])
    links.new(nrm_node.outputs["Normal"], bsdf.inputs["Normal"])

    return mat


# =============================================================================
# 2. BMESH HELPERS (Atlas UV mapping + clean manifold prisms)
# =============================================================================
def tile_uv_bounds(gx: int, gy: int, inset: float = 0.032) -> tuple[float, float, float, float]:
    """Return (u0, v0, u1, v1) for atlas grid (gx=0..3, gy=0..3 where gy=0 is top row)."""
    u0 = gx * 0.25 + inset * 0.25
    u1 = (gx + 1) * 0.25 - inset * 0.25
    # Blender V=1 is image top row (gy=0), V=0 is image bottom row (gy=3)
    v1 = 1.0 - gy * 0.25 - inset * 0.25
    v0 = 1.0 - (gy + 1) * 0.25 + inset * 0.25
    return u0, v0, u1, v1


def set_face_tile_uv(bm: bmesh.types.BMesh, face: bmesh.types.BMFace, uv_layer, tile: tuple[int, int]) -> None:
    u0, v0, u1, v1 = tile_uv_bounds(tile[0], tile[1])
    n = len(face.loops)
    for idx, loop in enumerate(face.loops):
        t_x = idx % 2 if n == 4 else (0.5 if idx == 0 else (0.0 if idx == 1 else 1.0))
        t_y = (idx // 2) % 2 if n == 4 else (1.0 if idx == 0 else 0.0)
        if n == 4:
            pts = [(u0, v0), (u1, v0), (u1, v1), (u0, v1)]
            loop[uv_layer].uv = pts[idx]
        else:
            loop[uv_layer].uv = (u0 + (u1 - u0) * t_x, v0 + (v1 - v0) * t_y)


def add_box_rbx(
    bm: bmesh.types.BMesh,
    uv_layer,
    center_rbx: tuple[float, float, float],
    size_rbx: tuple[float, float, float],
    tile: tuple[int, int],
    euler_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    """Add an oriented box centered at center_rbx with dimensions size_rbx=(sx, sy, sz)."""
    sx, sy, sz = size_rbx
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    local_corners = [
        (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),
        (-hx, hy, -hz), (hx, hy, -hz), (hx, hy, hz), (-hx, hy, hz),
    ]
    rot = Euler((euler_rbx[0], -euler_rbx[2], euler_rbx[1]), "XYZ").to_matrix()
    # Build directly in Roblox frame first, then transform each vertex to Blender!
    rot_rbx = Euler(euler_rbx, "YXZ").to_matrix()
    c_vec = Vector(center_rbx)
    verts = []
    for lc in local_corners:
        p_rbx = c_vec + rot_rbx @ Vector(lc)
        verts.append(bm.verts.new(rbx_to_blender(p_rbx.x, p_rbx.y, p_rbx.z)))

    quad_idxs = [
        (3, 2, 1, 0),  # bottom
        (4, 5, 6, 7),  # top
        (0, 1, 5, 4),  # -Z face
        (2, 3, 7, 6),  # +Z face
        (1, 2, 6, 5),  # +X face
        (3, 0, 4, 7),  # -X face
    ]
    for q in quad_idxs:
        f = bm.faces.new([verts[i] for i in q])
        set_face_tile_uv(bm, f, uv_layer, tile)


def add_cyl_y_rbx(
    bm: bmesh.types.BMesh,
    uv_layer,
    center_rbx: tuple[float, float, float],
    radius_bot: float,
    radius_top: float,
    height: float,
    sides: int,
    tile: tuple[int, int],
    euler_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
    cap: bool = True,
) -> None:
    rot_rbx = Euler(euler_rbx, "YXZ").to_matrix()
    c_vec = Vector(center_rbx)
    hy = height * 0.5
    u0, v0, u1, v1 = tile_uv_bounds(tile[0], tile[1])

    ring_b, ring_t = [], []
    for k in range(sides):
        a = 2.0 * math.pi * k / sides
        ca, sa = math.cos(a), math.sin(a)
        pb = c_vec + rot_rbx @ Vector((radius_bot * ca, -hy, radius_bot * sa))
        pt = c_vec + rot_rbx @ Vector((radius_top * ca, hy, radius_top * sa))
        ring_b.append(bm.verts.new(rbx_to_blender(pb.x, pb.y, pb.z)))
        ring_t.append(bm.verts.new(rbx_to_blender(pt.x, pt.y, pt.z)))

    for k in range(sides):
        kn = (k + 1) % sides
        f = bm.faces.new([ring_b[k], ring_b[kn], ring_t[kn], ring_t[k]])
        t0, t1 = k / sides, (k + 1) / sides
        f.loops[0][uv_layer].uv = (u0 + (u1 - u0) * t0, v0)
        f.loops[1][uv_layer].uv = (u0 + (u1 - u0) * t1, v0)
        f.loops[2][uv_layer].uv = (u0 + (u1 - u0) * t1, v1)
        f.loops[3][uv_layer].uv = (u0 + (u1 - u0) * t0, v1)

    if cap:
        for ring, v_c, rev in ((ring_b, v0, True), (ring_t, v1, False)):
            seq = list(reversed(ring)) if rev else ring
            fc = bm.faces.new(seq)
            for idx, loop in enumerate(fc.loops):
                ang = 2.0 * math.pi * (idx / len(seq))
                loop[uv_layer].uv = (
                    (u0 + u1) * 0.5 + (u1 - u0) * 0.42 * math.cos(ang),
                    (v0 + v1) * 0.5 + (v1 - v0) * 0.42 * math.sin(ang),
                )


def add_disc_face_rbx(
    bm: bmesh.types.BMesh,
    uv_layer,
    center_rbx: tuple[float, float, float],
    radius: float,
    thickness: float,
    sides: int,
    face_tile: tuple[int, int],
    rim_tile: tuple[int, int],
    euler_rbx: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> None:
    """Bullseye target disc whose +/-Z face maps radially across `face_tile`."""
    rot_rbx = Euler(euler_rbx, "YXZ").to_matrix()
    c_vec = Vector(center_rbx)
    hz = thickness * 0.5
    front_v, back_v = [], []
    for k in range(sides):
        a = 2.0 * math.pi * k / sides
        ca, sa = math.cos(a), math.sin(a)
        pf = c_vec + rot_rbx @ Vector((radius * ca, radius * sa, -hz))
        pb = c_vec + rot_rbx @ Vector((radius * ca, radius * sa, hz))
        front_v.append(bm.verts.new(rbx_to_blender(pf.x, pf.y, pf.z)))
        back_v.append(bm.verts.new(rbx_to_blender(pb.x, pb.y, pb.z)))

    u0, v0, u1, v1 = tile_uv_bounds(face_tile[0], face_tile[1], inset=0.02)
    for ring, rev in ((front_v, False), (back_v, True)):
        seq = list(reversed(ring)) if rev else ring
        fc = bm.faces.new(seq)
        for idx, loop in enumerate(fc.loops):
            k = (sides - 1 - idx) if rev else idx
            a = 2.0 * math.pi * k / sides
            loop[uv_layer].uv = (
                (u0 + u1) * 0.5 + (u1 - u0) * 0.49 * math.cos(a),
                (v0 + v1) * 0.5 + (v1 - v0) * 0.49 * math.sin(a),
            )

    for k in range(sides):
        kn = (k + 1) % sides
        fs = bm.faces.new([back_v[k], back_v[kn], front_v[kn], front_v[k]])
        set_face_tile_uv(bm, fs, uv_layer, rim_tile)


def add_rounded_torso_rbx(
    bm: bmesh.types.BMesh,
    uv_layer,
    center_rbx: tuple[float, float, float],
    rings: list[tuple[float, float]],
    sides: int,
    tile: tuple[int, int],
) -> None:
    """Stacked lathe profile centered at center_rbx; rings = [(dy, radius), ...]."""
    cx, cy, cz = center_rbx
    u0, v0, u1, v1 = tile_uv_bounds(tile[0], tile[1])
    v_rings = []
    for dy, rad in rings:
        row = []
        for k in range(sides):
            a = 2.0 * math.pi * k / sides
            p = rbx_to_blender(cx + rad * math.cos(a), cy + dy, cz + rad * math.sin(a))
            row.append(bm.verts.new(p))
        v_rings.append(row)

    for r_i in range(len(v_rings) - 1):
        r0 = v_rings[r_i]
        r1 = v_rings[r_i + 1]
        t_v0 = r_i / (len(v_rings) - 1)
        t_v1 = (r_i + 1) / (len(v_rings) - 1)
        for k in range(sides):
            kn = (k + 1) % sides
            f = bm.faces.new([r0[k], r0[kn], r1[kn], r1[k]])
            f.smooth = True
            t0, t1 = k / sides, (k + 1) / sides
            f.loops[0][uv_layer].uv = (u0 + (u1 - u0) * t0, v0 + (v1 - v0) * t_v0)
            f.loops[1][uv_layer].uv = (u0 + (u1 - u0) * t1, v0 + (v1 - v0) * t_v0)
            f.loops[2][uv_layer].uv = (u0 + (u1 - u0) * t1, v0 + (v1 - v0) * t_v1)
            f.loops[3][uv_layer].uv = (u0 + (u1 - u0) * t0, v0 + (v1 - v0) * t_v1)

    for row, rev in ((v_rings[0], True), (v_rings[-1], False)):
        seq = list(reversed(row)) if rev else row
        fc = bm.faces.new(seq)
        for loop in fc.loops:
            loop[uv_layer].uv = ((u0 + u1) * 0.5, (v0 + v1) * 0.5)


def finalize_mesh_obj(
    name: str,
    bm: bmesh.types.BMesh,
    mat: bpy.types.Material,
    col: bpy.types.Collection,
    location_bl: Vector = Vector((0, 0, 0)),
    rotation_bl: Euler = Euler((0, 0, 0), "XYZ"),
) -> bpy.types.Object:
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(f"{name}_Mesh")
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    obj.location = location_bl
    obj.rotation_euler = rotation_bl
    col.objects.link(obj)
    mesh.materials.append(mat)
    return obj


# =============================================================================
# 3. BUILD EACH STRUCTURAL SUB-MESH
# =============================================================================
def build_arena_floor(mat: bpy.types.Material, col: bpy.types.Collection) -> bpy.types.Object:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    # Non-sunken 0.08 stud flat beveled octagonal/polygonal slab from ry=0.00 to ry=0.08
    outer = FLOOR_POLYGON_2D
    inner = [(rx * 0.985, rz * 0.985) for (rx, rz) in outer]

    v_bot = [bm.verts.new(rbx_to_blender(rx, 0.0, rz)) for (rx, rz) in outer]
    v_top = [bm.verts.new(rbx_to_blender(rx, 0.08, rz)) for (rx, rz) in inner]
    v_ctr = bm.verts.new(rbx_to_blender(0.0, 0.08, 4.5))

    def map_uv(rx: float, rz: float) -> tuple[float, float]:
        # Matches Tex_ArenaGround domain rx=[-26..+26], rz=[-16..+32]
        return ((rx + 26.0) / 52.0, (rz + 16.0) / 48.0)

    n = len(outer)
    for k in range(n):
        kn = (k + 1) % n
        # Top pie wedge triangle/fan for clean planar non-self-intersecting concavity around threshold
        ft = bm.faces.new([v_ctr, v_top[k], v_top[kn]])
        ft.loops[0][uv].uv = map_uv(0.0, 4.5)
        ft.loops[1][uv].uv = map_uv(inner[k][0], inner[k][1])
        ft.loops[2][uv].uv = map_uv(inner[kn][0], inner[kn][1])

        # Beveled perimeter skirt
        fs = bm.faces.new([v_bot[k], v_bot[kn], v_top[kn], v_top[k]])
        fs.loops[0][uv].uv = map_uv(outer[k][0], outer[k][1])
        fs.loops[1][uv].uv = map_uv(outer[kn][0], outer[kn][1])
        fs.loops[2][uv].uv = map_uv(inner[kn][0], inner[kn][1])
        fs.loops[3][uv].uv = map_uv(inner[k][0], inner[k][1])

    fb = bm.faces.new(list(reversed(v_bot)))
    for k, loop in enumerate(fb.loops):
        idx = n - 1 - k
        loop[uv].uv = map_uv(outer[idx][0], outer[idx][1])

    return finalize_mesh_obj("Arena_Floor", bm, mat, col)


def build_perimeter_fence(mat: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, list[dict]]:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    wood = (0, 0)
    dark = (3, 2)

    collider_segments: list[dict] = []
    placed_posts: set[tuple[int, int]] = set()

    def add_post(rx: float, rz: float):
        key = (round(rx * 10), round(rz * 10))
        if key in placed_posts:
            return
        placed_posts.add(key)
        add_box_rbx(bm, uv, (rx, 1.52, rz), (0.48, 3.04, 0.48), wood)
        add_box_rbx(bm, uv, (rx, 3.12, rz), (0.36, 0.16, 0.36), dark)

    for s_idx in range(len(FENCE_CHAIN_LEFT) - 1):
        ax, az = FENCE_CHAIN_LEFT[s_idx]
        bx, bz = FENCE_CHAIN_LEFT[s_idx + 1]
        dx, dz = bx - ax, bz - az
        seg_len = math.hypot(dx, dz)
        n_spans = max(1, round(seg_len / 4.6))
        yaw = math.atan2(dx, dz)  # box +Z points along seg direction (sin(yaw), cos(yaw))

        collider_segments.append({
            "a": [round(ax, 3), round(az, 3)],
            "b": [round(bx, 3), round(bz, 3)],
            "mid": [round((ax + bx) * 0.5, 3), round((az + bz) * 0.5, 3)],
            "length": round(seg_len, 3),
            "yaw": round(yaw, 5),
        })

        for i in range(n_spans + 1):
            t = i / n_spans
            add_post(ax + dx * t, az + dz * t)

        # Two split horizontal timber rails
        mx, mz = (ax + bx) * 0.5, (az + bz) * 0.5
        for rail_y in (1.08, 2.24):
            add_box_rbx(bm, uv, (mx, rail_y, mz), (0.22, 0.28, seg_len - 0.1), wood, (0.0, yaw, 0.0))

    return finalize_mesh_obj("Perimeter_Fence", bm, mat, col), collider_segments


def build_entrance_archway(mat: bpy.types.Material, col: bpy.types.Collection) -> bpy.types.Object:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    stone = (0, 1)
    timber = (0, 0)
    beam = (3, 2)
    shingle = (3, 0)
    iron = (1, 1)

    arch_z = -12.0
    pier_x = 5.00  # 10.0 center-to-center; piers size 1.75 -> clear opening = 8.25 studs!

    # Twin stepped fieldstone pier bases & heavy vertical timber posts
    for sign in (-1.0, 1.0):
        px = sign * pier_x
        add_box_rbx(bm, uv, (px, 0.22, arch_z), (2.20, 0.44, 2.40), stone)
        add_box_rbx(bm, uv, (px, 1.80, arch_z), (1.75, 2.75, 1.95), stone)
        add_box_rbx(bm, uv, (px, 3.26, arch_z), (1.95, 0.30, 2.15), stone)
        # Main vertical timber post rising cleanly to gable eave
        add_box_rbx(bm, uv, (px, 5.02, arch_z), (0.94, 3.45, 0.94), timber)
        # Iron corner strap collar
        add_box_rbx(bm, uv, (px, 3.68, arch_z), (1.02, 0.24, 1.02), iron)
        # Short diagonal knee brace inward under lintel beam
        add_box_rbx(bm, uv, (px - sign * 0.86, 5.72, arch_z), (0.38, 1.75, 0.38), beam, (0.0, 0.0, sign * 0.72))

    # Horizontal tie header beam across open 8.25-stud passageway (bottom at ry=6.2)
    add_box_rbx(bm, uv, (0.0, 6.62, arch_z), (12.2, 0.82, 1.04), beam)
    # Central king-post inside V-gable truss + two angled collar struts
    add_box_rbx(bm, uv, (0.0, 8.75, arch_z), (0.62, 3.65, 0.62), beam)
    for sign in (-1.0, 1.0):
        add_box_rbx(bm, uv, (sign * 1.60, 8.10, arch_z), (0.44, 2.90, 0.44), beam, (0.0, 0.0, -sign * 0.62))

    # Pointed "Upside-Down V" Gabled Roof Slopes (front-facing gable ridge along Z!)
    ridge_y = 11.15
    eave_x = 6.55
    eave_y = 6.20
    roof_depth = 4.15
    slope_len = math.hypot(eave_x, ridge_y - eave_y)
    slope_ang = math.atan2(ridge_y - eave_y, eave_x)

    for sign in (-1.0, 1.0):
        cx = sign * eave_x * 0.5
        cy = (ridge_y + eave_y) * 0.5
        # Roof shingled slab
        add_box_rbx(bm, uv, (cx, cy + 0.12, arch_z), (slope_len, 0.42, roof_depth), shingle, (0.0, 0.0, -sign * slope_ang))
        # Prominent front/back bargeboard timber rafters framing the V silhouette
        for fz_off in (-roof_depth * 0.47, roof_depth * 0.47):
            add_box_rbx(bm, uv, (cx, cy - 0.16, arch_z + fz_off), (slope_len + 0.25, 0.52, 0.34), beam, (0.0, 0.0, -sign * slope_ang))

    # Peak ridge cap timber & iron crest bracket
    add_box_rbx(bm, uv, (0.0, ridge_y + 0.28, arch_z), (0.72, 0.52, roof_depth + 0.25), beam)
    add_box_rbx(bm, uv, (0.0, ridge_y + 0.25, arch_z - roof_depth * 0.52), (0.55, 0.48, 0.20), iron)

    return finalize_mesh_obj("Entrance_Archway", bm, mat, col)


def build_dummy_pair(spec: dict, mat: bpy.types.Material, col: bpy.types.Collection) -> tuple[bpy.types.Object, bpy.types.Object]:
    """Create `Dummy_N_Base` and `Dummy_N_Body` (origin at lower post hinge ry=1.15)."""
    idx = spec["id"]
    rx, rz = spec["rx"], spec["rz"]
    fx, fz = spec["facing_xz"]
    hinge_y = 1.15
    yaw_bl = facing_xz_to_blender_yaw(fx, fz)

    # 1. Stationary Base (`Dummy_N_Base`, centered on ground at ry=0)
    bm_base = bmesh.new()
    uv_b = bm_base.loops.layers.uv.new("UVMap")
    wood = (0, 0)
    iron = (1, 1)

    add_cyl_y_rbx(bm_base, uv_b, (0.0, 0.14, 0.0), 1.18, 1.06, 0.28, 8, wood)
    add_cyl_y_rbx(bm_base, uv_b, (0.0, 0.72, 0.0), 0.28, 0.25, 0.90, 6, wood, cap=False)
    add_box_rbx(bm_base, uv_b, (0.0, 1.10, 0.0), (0.58, 0.18, 0.58), iron)

    obj_base = finalize_mesh_obj(
        f"Dummy_{idx}_Base",
        bm_base,
        mat,
        col,
        location_bl=rbx_to_blender(rx, 0.08, rz),
        rotation_bl=Euler((0.0, 0.0, yaw_bl), "XYZ"),
    )

    # 2. Pivoting Body (`Dummy_N_Body`, local origin (0,0,0) = hinge at ry = 1.23)
    bm_body = bmesh.new()
    uv_p = bm_body.loops.layers.uv.new("UVMap")
    yellow = (0, 2)
    crimson = (1, 2)

    add_cyl_y_rbx(bm_body, uv_p, (0.0, 1.92, 0.0), 0.23, 0.21, 3.85, 6, wood, cap=False)
    add_box_rbx(bm_body, uv_p, (0.0, 2.55, 0.0), (3.15, 0.34, 0.34), wood)
    torso_rings = [
        (1.40, 0.58),
        (1.75, 0.84),
        (2.85, 0.82),
        (3.42, 0.48),
    ]
    add_rounded_torso_rbx(bm_body, uv_p, (0.0, 0.0, 0.0), torso_rings, 10, yellow)
    add_cyl_y_rbx(bm_body, uv_p, (0.0, 2.26, 0.0), 0.88, 0.88, 0.46, 10, crimson, cap=False)
    head_rings = [
        (3.52, 0.34),
        (3.84, 0.62),
        (4.18, 0.60),
        (4.46, 0.32),
    ]
    add_rounded_torso_rbx(bm_body, uv_p, (0.0, 0.0, 0.0), head_rings, 8, yellow)

    obj_body = finalize_mesh_obj(
        f"Dummy_{idx}_Body",
        bm_body,
        mat,
        col,
        location_bl=rbx_to_blender(rx, hinge_y + 0.08, rz),
        rotation_bl=Euler((0.0, 0.0, yaw_bl), "XYZ"),
    )
    return obj_base, obj_body


def add_barrel(bm, uv, rx: float, rz: float, scale: float = 1.0, tilt_x: float = 0.0):
    wood = (2, 0)
    iron = (1, 1)
    y0 = 0.08 + 1.05 * scale
    barrel_rings = [
        (-1.05 * scale, 0.68 * scale),
        (0.0, 0.88 * scale),
        (1.05 * scale, 0.68 * scale),
    ]
    if abs(tilt_x) < 1e-4:
        add_rounded_torso_rbx(bm, uv, (rx, y0, rz), barrel_rings, 8, wood)
        add_cyl_y_rbx(bm, uv, (rx, y0 - 0.50 * scale, rz), 0.83 * scale, 0.83 * scale, 0.14 * scale, 8, iron, cap=False)
        add_cyl_y_rbx(bm, uv, (rx, y0 + 0.50 * scale, rz), 0.83 * scale, 0.83 * scale, 0.14 * scale, 8, iron, cap=False)
    else:
        add_cyl_y_rbx(bm, uv, (rx, y0, rz), 0.78 * scale, 0.78 * scale, 2.0 * scale, 8, wood, (tilt_x, 0.0, 0.0))


def add_crate(bm, uv, rx: float, rz: float, sx: float, sy: float, sz: float, ry_off: float = 0.08, yaw: float = 0.0):
    crate_tile = (1, 0)
    trim = (3, 2)
    cy = ry_off + sy * 0.5
    add_box_rbx(bm, uv, (rx, cy, rz), (sx, sy, sz), crate_tile, (0.0, yaw, 0.0))
    add_box_rbx(bm, uv, (rx, ry_off + sy - 0.10, rz), (sx + 0.08, 0.18, sz + 0.08), trim, (0.0, yaw, 0.0))


def add_weapon_rack(bm, uv, rx: float, rz: float, width: float, yaw: float, n_weapons: int, has_spears: bool = False):
    wood = (0, 0)
    dark = (3, 2)
    steel = (2, 1)
    iron = (1, 1)

    rot = Euler((0.0, yaw, 0.0), "YXZ").to_matrix()
    def pt(lx: float, ly: float, lz: float) -> tuple[float, float, float]:
        v = Vector((rx, 0.08, rz)) + rot @ Vector((lx, ly, lz))
        return (v.x, v.y, v.z)

    # A-frame or upright timber uprights + footed bases + crossbars
    for sign in (-1.0, 1.0):
        ux = sign * width * 0.46
        add_box_rbx(bm, uv, pt(ux, 0.14, 0.0), (0.36, 0.28, 1.45), dark, (0.0, yaw, 0.0))
        add_box_rbx(bm, uv, pt(ux, 1.95, 0.0), (0.32, 3.65, 0.34), wood, (0.0, yaw, 0.0))
    add_box_rbx(bm, uv, pt(0.0, 0.88, 0.0), (width, 0.28, 0.32), wood, (0.0, yaw, 0.0))
    add_box_rbx(bm, uv, pt(0.0, 3.15, 0.0), (width, 0.28, 0.32), wood, (0.0, yaw, 0.0))

    # Populate rack with resting metallic swords / spears
    span = width * 0.74
    for i in range(n_weapons):
        t = (i / max(1, n_weapons - 1)) - 0.5
        lx = t * span
        # Weapon handle/shaft tilted slightly against upper bar
        add_box_rbx(bm, uv, pt(lx, 2.35, 0.16), (0.14, 3.5 if has_spears else 2.6, 0.10), wood, (-0.12, yaw, 0.0))
        add_box_rbx(bm, uv, pt(lx, 1.55 if has_spears else 2.15, 0.16), (0.22, 1.65, 0.10), steel, (-0.12, yaw, 0.0))
        if not has_spears:
            add_box_rbx(bm, uv, pt(lx, 1.32, 0.16), (0.62, 0.16, 0.18), iron, (-0.12, yaw, 0.0))


def build_training_props(mat: bpy.types.Material, col: bpy.types.Collection) -> bpy.types.Object:
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")

    wood = (0, 0)
    dark = (3, 2)
    iron = (1, 1)
    bull_face = (0, 3)

    # Symmetrical Left (+X) & Right (-X) Wing Props across X=0!

    # 1. Twin Bullseye Targets on outer-middle flanks (facing inward toward X=0 center!)
    # Fence V2 -> V3 runs from (+/-23.8, 2.5) to (+/-12.0, 18.5). Center of span at rx=+/-17.9, rz=10.5.
    # Place twin raised tripod/post bullseyes just inside at rx=+/-16.2, rz=9.8 facing inward!
    for sign in (-1.0, 1.0):
        bx, bz = sign * 16.2, 9.8
        # +Z face points inward & slightly toward entrance: (-sign*0.78, -0.62)
        b_yaw = math.atan2(-sign * 0.78, -0.62)
        b_rot = Euler((0.0, b_yaw, 0.0), "YXZ").to_matrix()
        b_c = Vector((bx, 0.08, bz))
        for lx, lz, pitch, roll in ((-0.70, 0.50, 0.25, 0.16), (0.70, 0.50, 0.25, -0.16), (0.0, -0.68, -0.22, 0.0)):
            lp = b_c + b_rot @ Vector((lx, 1.35, lz))
            add_box_rbx(bm, uv, (lp.x, lp.y, lp.z), (0.26, 2.9, 0.26), wood, (pitch, b_yaw, roll))
        add_disc_face_rbx(bm, uv, (bx, 2.65, bz), 1.65, 0.30, 12, bull_face, wood, (-0.32, b_yaw, 0.0))

    # 2. Symmetrical Weapon & Spear Racks lining front-side and back-shoulder fence spans
    # Front-side span V1(±16.0, -9.5) -> V2(±23.8, 2.5): vector = (±7.8, +12.0)
    for sign in (-1.0, 1.0):
        # Rack along V1 -> V2 midpoint shifted inward
        yaw_fs = math.atan2(-sign * 12.0, 7.8)  # local +Z faces inward perpendicular to span
        add_weapon_rack(bm, uv, sign * 18.8, -4.0, 4.6, yaw_fs, n_weapons=4, has_spears=False)

        # Heavy halberd/spear rack along V3(±12.0, 18.5) -> Apex(0, 27.5): midpoint (±6.0, 23.0)
        yaw_bk = math.atan2(-sign * 9.0, -12.0)  # faces inward (-sign, -Z)
        add_weapon_rack(bm, uv, sign * 6.2, 21.4, 5.4, yaw_bk, n_weapons=4, has_spears=True)

    # 3. Twin Wrought-Iron Armor/Halberd Stands flanking outside the V-gable entrance piers
    for sign in (-1.0, 1.0):
        ix, iz = sign * 7.2, -12.2
        ir_yaw = -sign * 0.22
        add_box_rbx(bm, uv, (ix, 0.20, iz), (1.85, 0.28, 1.65), wood, (0.0, ir_yaw, 0.0))
        add_box_rbx(bm, uv, (ix, 0.42, iz), (1.25, 0.20, 1.15), dark, (0.0, ir_yaw, 0.0))
        add_box_rbx(bm, uv, (ix, 2.55, iz), (0.36, 4.35, 0.36), iron, (0.0, ir_yaw, 0.0))
        add_box_rbx(bm, uv, (ix, 4.30, iz), (1.35, 0.34, 0.34), iron, (0.0, ir_yaw, 0.0))
        add_box_rbx(bm, uv, (ix - sign * 0.28, 5.00, iz + 0.08), (0.52, 1.35, 0.24), iron, (0.0, ir_yaw, sign * 0.14))

    # 4. Symmetrical Barrel & Crate Clusters in Left & Right front/outer corners (zero overlaps!)
    for sign in (-1.0, 1.0):
        # Front-wing crates along V0(±5.0, -12.0) -> V1(±16.0, -9.5)
        add_crate(bm, uv, sign * 9.8, -10.2, 2.2, 1.65, 1.85, ry_off=0.08, yaw=sign * 0.22)
        add_crate(bm, uv, sign * 12.6, -9.5, 2.0, 1.65, 1.80, ry_off=0.08, yaw=sign * 0.22)
        # Front corner barrels inside V1(±16.0, -9.5)
        add_barrel(bm, uv, sign * 15.2, -8.3, scale=1.02)
        add_barrel(bm, uv, sign * 16.6, -7.2, scale=0.98)
        # Outer-corner barrels + crate inside V2(±23.8, 2.5)
        add_barrel(bm, uv, sign * 21.6, 2.2, scale=1.02)
        add_barrel(bm, uv, sign * 20.6, 3.8, scale=0.96)
        add_crate(bm, uv, sign * 20.6, 0.3, 1.85, 1.60, 1.85, ry_off=0.08, yaw=-sign * 0.35)

    return finalize_mesh_obj("Training_Props", bm, mat, col)


# =============================================================================
# 4. ASSEMBLY, MANIFEST, FBX EXPORT & VERIFICATION RENDER
# =============================================================================
def build_training_grounds() -> dict:
    # Remove default startup Cube if present
    cube = bpy.data.objects.get("Cube")
    if cube and len(cube.data.polygons) == 6:
        bpy.data.objects.remove(cube, do_unlink=True)

    if COLLECTION_NAME in bpy.data.collections:
        old = bpy.data.collections[COLLECTION_NAME]
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)

    col = bpy.data.collections.new(COLLECTION_NAME)
    bpy.context.scene.collection.children.link(col)

    tex_reg = generate_textures()
    mat_ground = build_pbr_material("Mat_ArenaGround", tex_reg["Tex_ArenaGround"])
    mat_props = build_pbr_material("Mat_TrainingProps", tex_reg["Tex_TrainingProps"])

    obj_floor = build_arena_floor(mat_ground, col)
    obj_fence, colliders = build_perimeter_fence(mat_props, col)
    obj_arch = build_entrance_archway(mat_props, col)
    obj_props = build_training_props(mat_props, col)

    objs = [obj_floor, obj_fence, obj_arch, obj_props]
    for spec in DUMMY_SPECS:
        d_base, d_body = build_dummy_pair(spec, mat_props, col)
        objs.extend([d_base, d_body])

    # Apply scale/rotation cleanly ONLY on static non-hinged meshes, and apply SCALE ONLY on dummy parts
    # Wait: Dummy_N_Body MUST keep its location & rotation_euler (hinge pivot!) so Roblox knows its hinge!
    # Apply scale=(1,1,1) cleanly already since all geometry was created at exact 1.0 scale.

    tri_breakdown = {}
    total_tris = 0
    for o in objs:
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        tri_breakdown[o.name] = tris
        total_tris += tris

    print(f"[TrainingGrounds] Generated {len(objs)} meshes, total triangles = {total_tris}")
    for k, v in tri_breakdown.items():
        print(f"  - {k}: {v} tris")
    assert total_tris < 4500, f"Triangle budget exceeded: {total_tris} >= 4500!"

    # Export FBX with packed/copied textures
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obj_floor

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
    print(f"[TrainingGrounds] Exported FBX -> {FBX_PATH} ({FBX_PATH.stat().st_size} bytes)")

    manifest = {
        "total_tris": total_tris,
        "tri_breakdown": tri_breakdown,
        "floor_top_y": 0.08,
        "entry_waypoint": [0.0, 0.08, -8.5],
        "arch_approach_waypoint": [0.0, 0.08, -14.8],
        "bullseye_1_local": [16.2, 2.65, 9.8],
        "bullseye_2_local": [-16.2, 2.65, 9.8],
        "dummies": [
            {
                "id": s["id"],
                "base_local": [s["rx"], 0.08, s["rz"]],
                "hinge_local": [s["rx"], 1.23, s["rz"]],
                "facing_xz": list(s["facing_xz"]),
                "spot_local": [
                    round(s["rx"] + s["facing_xz"][0] * 3.2, 3),
                    0.08,
                    round(s["rz"] + s["facing_xz"][1] * 3.2, 3),
                ],
            }
            for s in DUMMY_SPECS
        ],
        "fence_colliders": colliders,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


def render_preview(out_png: Path) -> None:
    scene = bpy.context.scene
    for candidate in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "CYCLES"):
        try:
            scene.render.engine = candidate
            break
        except Exception:
            continue

    scene.render.resolution_x = 1280
    scene.render.resolution_y = 900
    scene.render.filepath = str(out_png)

    # Bright daylight sun + sky fill
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.38, 0.44, 0.34, 1.0)
        bg.inputs[1].default_value = 1.2

    sun_data = bpy.data.lights.new("SunKey", type="SUN")
    sun_data.energy = 3.2
    sun_obj = bpy.data.objects.new("SunKey", sun_data)
    sun_obj.rotation_euler = Euler((math.radians(48), math.radians(18), math.radians(-35)), "XYZ")
    bpy.context.scene.collection.objects.link(sun_obj)

    # Match reference angle: camera in -rz (+Y_bl), elevated looking slightly downward toward center (+Z_rbx / -Y_bl)
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 28.0
    cam_obj = bpy.data.objects.new("PreviewCam", cam_data)
    bpy.context.scene.collection.objects.link(cam_obj)
    scene.camera = cam_obj

    cam_pos = rbx_to_blender(0.0, 26.5, -31.0)
    target = rbx_to_blender(0.0, 1.5, 3.0)
    cam_obj.location = cam_pos
    direction = (target - cam_pos).normalized()
    cam_obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    out_png.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print(f"[TrainingGrounds] Rendered preview -> {out_png}")


if __name__ == "__main__":
    build_training_grounds()
    preview_out = Path(r"C:\Users\enter\.gemini\antigravity\brain\82103f1e-d9e0-4535-bdf0-150efaadd707\scratch\training_grounds_preview.png")
    render_preview(preview_out)
