"""
Infinite Tower: Become a Master! - The Gilded Anvil (6 Gildforged Tier-8 Transcendent Weapons).

Sculpts all 6 Gildforged weapons in Blender using high-craft BMesh geometry:
  - Contoured multi-ring lathes (no simple cylinders)
  - Bezier curved silhouettes extruded via beveled inset_poly plates
  - Honed edge_strip cutting edges along curved blade arcs
  - 3D Bezier ribbon_loft sweeps (auroral bow limbs, dragon horns, ribcages, silk bookmarks, living pages)
  - Layered feathered leaf plates & carved relief strokes/veins
  - Faceted bipyramid gems & notched astrolabe rings
  - Split sharp edges (> 34 deg) so every bevel crease catches studio lighting in both Blender & Roblox EditableMesh.

Weapons (one per archetype):
  1. art_gild_dawnwarden_oath  (Vanguard SWORD_SHIELD - Sunlight: cathedral broadsword + cambered seraph kite shield, spinning SunDisc, orbiting HaloRings)
  2. art_gild_eclipse_sisters   (Striker DAGGERS - Eclipse: asymmetrical Umbra obsidian kris + Corona molten-gold talon)
  3. art_gild_aurora_skyhook    (Marksman BOW - Aurora: swan-wing lotus riser + billowing 3D double-ribbon limbs + crystal arrow)
  4. art_gild_wyrmheart_cleaver (Berserker AXE - Dragonfire: dragon-talon haft + horned draconic skull + double-bearded crescent + rib-caged WyrmHeart)
  5. art_gild_ninth_sky_orrery  (Scholar STAFF - Star-orbit: fluted astrologer spire + crescent lyre cradle + 3 notched armillary rings + 14-point star + 3 moons)
  6. art_gild_evergarden_codex  (Healer TOME - Bloom: arched white-bark filigree covers + cambered vellum + lotus JadeGem + S-curved BlossomBookmark + billowing LivingPages)

Authoring convention:
  - Geometry helpers accept Roblox Y-up coordinates (rx, ry, rz) or 2D (u=rx, v=ry) unless noted,
    converted into Blender Z-up via (rx, -rz, ry) for clean preview & FBX/EditableMesh export.

Outputs:
  - assets/artifacts/gilded_anvil/<template_id>.fbx
  - assets/artifacts/gilded_anvil/manifest.json
  - assets/artifacts/gilded_anvil/gilded_anvil_preview.png (Workbench cavity + outline showcase)
  - assets/artifacts/gilded_anvil/gilded_anvil_eevee_preview.png (EEVEE dark studio showcase)
  - src/ReplicatedStorage/Assets/GildedAnvilMeshData.luau
"""

import base64
import json
import math
import os
import random
import re
import struct

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

REPO = (
    os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    if "__file__" in globals()
    else "/Users/pedrosroving/projects/infinite-tower"
)
OUT_DIR = os.path.join(REPO, "assets", "artifacts", "gilded_anvil")
LUAU_DATA_PATH = os.path.join(REPO, "src", "ReplicatedStorage", "Assets", "GildedAnvilMeshData.luau")


# ---------------------------------------------------------------------------
# Coordinate conversion helpers
# ---------------------------------------------------------------------------

def r2b(p):
    """Roblox (rx, ry, rz) -> Blender Z-up (rx, -rz, ry)."""
    return Vector((p[0], -p[2], p[1]))


def b2r(p):
    """Blender Z-up (bx, by, bz) -> Roblox Y-up (bx, bz, -by)."""
    return Vector((p[0], p[2], -p[1]))


def V2(x, y):
    return Vector((x, y))


def V3(x, y, z):
    return Vector((x, y, z))


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)


def get_or_create_collection(name, parent=None):
    col = bpy.data.collections.get(name)
    if not col:
        col = bpy.data.collections.new(name)
        if parent:
            parent.children.link(col)
        else:
            bpy.context.scene.collection.children.link(col)
    return col


def get_material(name, rgb, material_enum="Metal", metallic=0.25, roughness=0.30, emission=0.0, transparency=0.0):
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    mat["rbx_material"] = material_enum
    mat["rbx_color"] = list(rgb)
    mat["rbx_transparency"] = float(transparency)
    col = (rgb[0] / 255.0, rgb[1] / 255.0, rgb[2] / 255.0, 1.0)
    mat.diffuse_color = col
    mat.metallic = metallic
    mat.roughness = roughness
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = col
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = metallic
        if "Roughness" in bsdf.inputs:
            bsdf.inputs["Roughness"].default_value = roughness
        if emission > 0 and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = col
            bsdf.inputs["Emission Strength"].default_value = emission
        if transparency > 0 and "Alpha" in bsdf.inputs:
            bsdf.inputs["Alpha"].default_value = 1.0 - transparency
    return mat


def materials_palette():
    return {
        "gold": get_material("Gild_Gold", (245, 192, 72), "Metal", metallic=0.65, roughness=0.22),
        "antique_gold": get_material("Gild_AntiqueGold", (202, 148, 52), "Metal", metallic=0.62, roughness=0.28),
        "white_gold": get_material("Gild_WhiteGold", (255, 245, 212), "Metal", metallic=0.45, roughness=0.22),
        "ivory": get_material("Gild_Ivory", (248, 242, 228), "SmoothPlastic", metallic=0.06, roughness=0.28),
        "sun_neon": get_material("Gild_SunNeon", (255, 234, 142), "Neon", metallic=0.0, roughness=0.1, emission=4.2),
        "obsidian": get_material("Gild_Obsidian", (26, 22, 42), "Glass", metallic=0.35, roughness=0.10, transparency=0.10),
        "umbra_edge": get_material("Gild_UmbraEdge", (148, 122, 228), "Neon", metallic=0.20, roughness=0.14, emission=1.8),
        "teal": get_material("Gild_AuroraTeal", (110, 240, 232), "Glass", metallic=0.06, roughness=0.14, emission=0.45, transparency=0.08),
        "violet": get_material("Gild_AuroraViolet", (178, 132, 255), "Glass", metallic=0.06, roughness=0.14, emission=0.40, transparency=0.12),
        "pink_silk": get_material("Gild_AuroraPink", (246, 128, 198), "SmoothPlastic", metallic=0.04, roughness=0.22, emission=0.0, transparency=0.0),
        "crimson_fire": get_material("Gild_Dragonfire", (255, 78, 28), "Neon", metallic=0.0, roughness=0.12, emission=4.8),
        "dark_iron": get_material("Gild_DarkIron", (62, 56, 66), "Metal", metallic=0.58, roughness=0.30),
        "bone_horn": get_material("Gild_BoneHorn", (232, 218, 196), "SmoothPlastic", metallic=0.04, roughness=0.36),
        "astral_blue": get_material("Gild_AstralBlue", (38, 76, 168), "Metal", metallic=0.55, roughness=0.22),
        "star_core": get_material("Gild_StarCore", (253, 224, 71), "Neon", metallic=0.0, roughness=0.05, emission=5.2),
        "moon_pearl": get_material("Gild_MoonPearl", (184, 228, 255), "Neon", metallic=0.25, roughness=0.14, emission=1.7),
        "white_bark": get_material("Gild_WhiteBark", (224, 214, 196), "SmoothPlastic", metallic=0.02, roughness=0.35),
        "jade": get_material("Gild_Jade", (46, 218, 152), "Glass", metallic=0.10, roughness=0.10, emission=0.35, transparency=0.06),
        "blossom": get_material("Gild_Blossom", (244, 114, 182), "Fabric", metallic=0.04, roughness=0.28, emission=1.3),
        "leather": get_material("Gild_Leather", (86, 56, 38), "Leather", metallic=0.02, roughness=0.58),
        "vellum": get_material("Gild_Vellum", (242, 228, 188), "SmoothPlastic", metallic=0.02, roughness=0.38),
    }


# ---------------------------------------------------------------------------
# Sculpted BMesh builder class & curve / bevel primitives
# ---------------------------------------------------------------------------

class Sculpt:
    """BMesh accumulator authoring directly in Roblox (rx, ry, rz) space."""

    def __init__(self):
        self.bm = bmesh.new()

    def v(self, p):
        return self.bm.verts.new(r2b(p))

    def f(self, verts):
        if len(set(verts)) < 3:
            return None
        try:
            return self.bm.faces.new(verts)
        except ValueError:
            return None

    @property
    def empty(self):
        return len(self.bm.faces) == 0


def quad_bezier_2d(a, c, b, n):
    return [a * ((1 - s) ** 2) + c * (2 * s * (1 - s)) + b * (s * s) for s in (i / n for i in range(n + 1))]


def cubic_bezier_3d(p0, p1, p2, p3, n):
    out = []
    for i in range(n + 1):
        s = i / n
        u = 1.0 - s
        out.append(p0 * (u ** 3) + p1 * (3 * (u ** 2) * s) + p2 * (3 * u * (s ** 2)) + p3 * (s ** 3))
    return out


def signed_area_2d(pts):
    return 0.5 * sum(pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y for i in range(len(pts)))


def point_in_poly_2d(p, pts):
    hit = False
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        if (a.y > p.y) != (b.y > p.y):
            x = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
            if x > p.x:
                hit = not hit
    return hit


def inset_poly_2d(pts, depths):
    n = len(pts)
    ccw = signed_area_2d(pts) > 0
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        e1, e2 = (p1 - p0), (p2 - p1)
        if e1.length < 1e-6 or e2.length < 1e-6:
            out.append(p1.copy())
            continue
        e1.normalize()
        e2.normalize()
        n1 = Vector((-e1.y, e1.x)) if ccw else Vector((e1.y, -e1.x))
        n2 = Vector((-e2.y, e2.x)) if ccw else Vector((e2.y, -e2.x))
        m = n1 + n2
        if m.length < 1e-6:
            m = n1.copy()
        m.normalize()
        k = 1.0 / max(0.38, m.dot(n1))
        d = depths[i] if isinstance(depths, (list, tuple)) else depths
        s = 1.0
        q = p1 + m * d * k
        while not point_in_poly_2d(q, pts) and s > 0.04:
            s *= 0.5
            q = p1 + m * d * k * s
        if not point_in_poly_2d(q, pts):
            q = p1 + m * 0.002
        out.append(q)
    return out


def plate_xy(sc, pts, thickness, inset, z0=0.0, neck_u=None, camber_z=None, back_scale=1.0):
    """
    Extrude a 2D (x_rbx, y_rbx) closed outline into a sharp beveled plate in Roblox XY space.
    - camber_z(p) optionally shifts Z smoothly (great for curved covers/wings).
    """
    if len(pts) < 3:
        return
    if signed_area_2d(pts) < 0:
        pts = list(reversed(pts))
    if neck_u is not None:
        depths = [inset * max(0.08, min(1.0, abs(p.x) / neck_u)) for p in pts]
    else:
        depths = inset
    inner = inset_poly_2d(pts, depths)

    def zc(p):
        return z0 + (camber_z(p) if camber_z else 0.0)

    rim = [sc.v((p.x, p.y, zc(p))) for p in pts]
    front = [sc.v((p.x, p.y, zc(p) - thickness * 0.5)) for p in inner]
    back = [sc.v((p.x, p.y, zc(p) + thickness * 0.5 * back_scale)) for p in inner]
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        sc.f([rim[i], rim[j], front[j], front[i]])
        sc.f([rim[j], rim[i], back[i], back[j]])
    sc.f(front)
    sc.f(back[::-1])


def plate_zy(sc, pts_zy, thickness, inset, x0=0.0, camber_x=None):
    """
    Extrude a 2D (z_rbx, y_rbx) closed outline facing -X (for OffhandShield!).
    Front face is toward -X, back toward +X. camber_x(p) curves X smoothly!
    """
    if len(pts_zy) < 3:
        return
    if signed_area_2d(pts_zy) < 0:
        pts_zy = list(reversed(pts_zy))
    inner = inset_poly_2d(pts_zy, inset)

    def xc(p):
        return x0 + (camber_x(p) if camber_x else 0.0)

    rim = [sc.v((xc(p), p.y, p.x)) for p in pts_zy]
    front = [sc.v((xc(p) - thickness * 0.5, p.y, p.x)) for p in inner]
    back = [sc.v((xc(p) + thickness * 0.5, p.y, p.x)) for p in inner]
    n = len(pts_zy)
    for i in range(n):
        j = (i + 1) % n
        sc.f([rim[i], rim[j], front[j], front[i]])
        sc.f([rim[j], rim[i], back[i], back[j]])
    sc.f(front)
    sc.f(back[::-1])


def edge_strip_xy(sc, arc, centre, width, thickness, proud=0.022, z0=0.0):
    """Separate razor-honed cutting edge hugging an open polyline arc in XY (Roblox)."""
    n = len(arc)
    if n < 2:
        return
    outer, front, back = [], [], []
    for i, p in enumerate(arc):
        tan = arc[min(n - 1, i + 1)] - arc[max(0, i - 1)]
        if tan.length < 1e-6:
            tan = V2(0, 1)
        tan.normalize()
        nrm = V2(-tan.y, tan.x)
        if nrm.dot(centre - p) < 0:
            nrm = -nrm
        s = i / (n - 1)
        wi = width * (0.35 + 0.65 * math.sin(math.pi * s))
        o, q = p - nrm * proud, p + nrm * wi
        outer.append(sc.v((o.x, o.y, z0)))
        front.append(sc.v((q.x, q.y, z0 - thickness * 0.5)))
        back.append(sc.v((q.x, q.y, z0 + thickness * 0.5)))
    for i in range(n - 1):
        sc.f([outer[i], outer[i + 1], front[i + 1], front[i]])
        sc.f([outer[i + 1], outer[i], back[i], back[i + 1]])
        sc.f([front[i], front[i + 1], back[i + 1], back[i]])
    sc.f([outer[0], front[0], back[0]])
    sc.f([outer[-1], back[-1], front[-1]])


def lathe_y(sc, profile, segs=22, sx=1.0, sz=1.0, offset=(0.0, 0.0, 0.0), rot_deg=(0.0, 0.0, 0.0), phase=0.0):
    """Revolve (radius, y_rbx) pairs about Roblox +Y axis."""
    rot_m = Euler((math.radians(rot_deg[0]), math.radians(rot_deg[1]), math.radians(rot_deg[2])), "XYZ").to_matrix()
    off_v = Vector(offset)
    rings = []
    for r, y in profile:
        if r < 1e-5:
            p = off_v + rot_m @ Vector((0.0, y, 0.0))
            rings.append([sc.v(p)])
        else:
            ring = []
            for i in range(segs):
                a = phase + 2 * math.pi * i / segs
                p = off_v + rot_m @ Vector((r * sx * math.cos(a), y, r * sz * math.sin(a)))
                ring.append(sc.v(p))
            rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                sc.f([a[0], b[j], b[i]])
            elif len(b) == 1:
                sc.f([a[i], a[j], b[0]])
            else:
                sc.f([a[i], a[j], b[j], b[i]])
    if len(rings[0]) > 1:
        sc.f(rings[0])
    if len(rings[-1]) > 1:
        sc.f(rings[-1][::-1])


def ribbon_loft(sc, pts3d, widths, thicks, up_hint=(0.0, 0.0, 1.0), profile="lens", twist_fn=None):
    """
    Sweep a smooth sculpted 3D tube / airfoil / beveled-band along `pts3d` in Roblox space.
    - profile="lens": 8-point sharp sword/aurora ribbon lens
    - profile="oval": 10-point organic round horn / rib / cord
    - profile="bevel": 8-point chamfered architectural frame / ring
    """
    n = len(pts3d)
    if n < 2:
        return
    hint = Vector(up_hint).normalized()
    if profile == "lens":
        angles = [2 * math.pi * k / 8 for k in range(8)]
        shape = [(math.cos(a), 0.72 * math.sin(a) if abs(math.cos(a)) < 0.99 else 0.0) for a in angles]
        # sharpen leading & trailing edges cleanly
        shape = [
            (1.0, 0.0), (0.55, 0.78), (0.0, 1.0), (-0.55, 0.78),
            (-1.0, 0.0), (-0.55, -0.78), (0.0, -1.0), (0.55, -0.78),
        ]
    elif profile == "bevel":
        shape = [
            (1.0, 0.45), (0.45, 1.0), (-0.45, 1.0), (-1.0, 0.45),
            (-1.0, -0.45), (-0.45, -1.0), (0.45, -1.0), (1.0, -0.45),
        ]
    else:  # oval / organic horn / rib
        shape = [(math.cos(2 * math.pi * k / 10), math.sin(2 * math.pi * k / 10)) for k in range(10)]

    rings = []
    prev_n = None
    for i, p in enumerate(pts3d):
        if i == 0:
            t_vec = pts3d[1] - pts3d[0]
        elif i == n - 1:
            t_vec = pts3d[-1] - pts3d[-2]
        else:
            t_vec = pts3d[i + 1] - pts3d[i - 1]
        t_vec = t_vec.normalized() if t_vec.length > 1e-6 else Vector((0, 1, 0))
        ref = prev_n if prev_n is not None else hint
        s_vec = t_vec.cross(ref)
        if s_vec.length < 1e-4:
            alt = Vector((1, 0, 0)) if abs(t_vec.x) < 0.8 else Vector((0, 1, 0))
            s_vec = t_vec.cross(alt)
        s_vec.normalize()
        n_vec = s_vec.cross(t_vec).normalized()
        prev_n = n_vec

        if twist_fn:
            ang = twist_fn(i / (n - 1))
            ca, sa = math.cos(ang), math.sin(ang)
            s_tw = s_vec * ca + n_vec * sa
            n_tw = -s_vec * sa + n_vec * ca
            s_vec, n_vec = s_tw, n_tw

        w = widths[i] * 0.5
        th = thicks[i] * 0.5
        ring = []
        for sx_f, ny_f in shape:
            q = p + s_vec * (sx_f * w) + n_vec * (ny_f * th)
            ring.append(sc.v(q))
        rings.append(ring)

    m = len(shape)
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(m):
            k = (j + 1) % m
            sc.f([r0[j], r0[k], r1[k], r1[j]])
    sc.f(rings[0][::-1])
    sc.f(rings[-1])


def closed_ring_loft(sc, pts3d, widths, thicks, up_hint=(0.0, 0.0, 1.0), profile="bevel"):
    """Closed seamless beveled/sculpted loop (for halos, astrolabe rings, pommel rings)."""
    n = len(pts3d)
    if profile == "bevel":
        shape = [
            (1.0, 0.42), (0.42, 1.0), (-0.42, 1.0), (-1.0, 0.42),
            (-1.0, -0.42), (-0.42, -1.0), (0.42, -1.0), (1.0, -0.42),
        ]
    else:
        shape = [(math.cos(2 * math.pi * k / 10), math.sin(2 * math.pi * k / 10)) for k in range(10)]

    rings = []
    hint = Vector(up_hint).normalized()
    for i in range(n):
        p = pts3d[i]
        t_vec = (pts3d[(i + 1) % n] - pts3d[(i - 1) % n]).normalized()
        s_vec = t_vec.cross(hint)
        if s_vec.length < 1e-4:
            s_vec = t_vec.cross(Vector((1, 0, 0)))
        s_vec.normalize()
        n_vec = s_vec.cross(t_vec).normalized()
        w = widths[i] * 0.5
        th = thicks[i] * 0.5
        rings.append([sc.v(p + s_vec * (sx_f * w) + n_vec * (ny_f * th)) for sx_f, ny_f in shape])

    m = len(shape)
    for i in range(n):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for j in range(m):
            k = (j + 1) % m
            sc.f([r0[j], r0[k], r1[k], r1[j]])


def leaf_outline(base, angle, length, width, n=8):
    """Curved tapered feather / petal 2D polygon starting at `base` pointing at `angle` (radians)."""
    c, s = math.cos(angle), math.sin(angle)
    pts = []
    for i in range(n + 1):
        k = i / n
        pts.append((length * k, width * math.sin(math.pi * (k ** 0.72)) * 0.55))
    for i in range(n - 1, 0, -1):
        k = i / n
        pts.append((length * k, -width * math.sin(math.pi * (k ** 0.88)) * 0.30))
    return [V2(base.x + x * c - y * s, base.y + x * s + y * c) for x, y in pts]


def gem_crystal(sc, center, rx, ry, rz, segs=8, rot_deg=(0.0, 0.0, 0.0)):
    """Faceted crystal bipyramid in Roblox space."""
    rot_m = Euler((math.radians(rot_deg[0]), math.radians(rot_deg[1]), math.radians(rot_deg[2])), "XYZ").to_matrix()
    off = Vector(center)
    prof = [(0.0, -ry), (1.0, -ry * 0.12), (0.86, ry * 0.24), (0.0, ry)]
    rings = []
    for r, y in prof:
        if r < 1e-5:
            rings.append([sc.v(off + rot_m @ Vector((0.0, y, 0.0)))])
        else:
            ring = []
            for i in range(segs):
                a = 2 * math.pi * i / segs
                p = Vector((r * rx * math.cos(a), y, r * rz * math.sin(a)))
                ring.append(sc.v(off + rot_m @ p))
            rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            if len(a) == 1:
                sc.f([a[0], b[j], b[i]])
            elif len(b) == 1:
                sc.f([a[i], a[j], b[0]])
            else:
                sc.f([a[i], a[j], b[j], b[i]])


def inlay_stroke_xy(sc, a, b, w0, w1, thickness, depth=0.018):
    """Tapered glowing inlay bar on both +/-Z faces of a blade/plate in Roblox XY space."""
    d = b - a
    if d.length < 1e-5:
        return
    dn = d.normalized()
    n = V2(-dn.y, dn.x)
    pts = [a - n * (w0 * 0.5), a + n * (w0 * 0.5), b + n * (w1 * 0.5), b - n * (w1 * 0.5)]
    for side in (-1.0, 1.0):
        zc = side * (thickness * 0.5)
        plate_xy(sc, pts, depth * 2.0, min(w0, w1) * 0.28, z0=zc)


def inlay_vein_xy(sc, a, b, width, thickness, rng, kinks=6, wobble=0.055):
    """Smooth continuous tapered magma/rune vein along both blade faces (no segment seams)."""
    d = b - a
    n = V2(-d.y, d.x).normalized() if d.length > 1e-5 else V2(0, 1)
    spine = [a]
    for i in range(1, kinks):
        s = i / kinks
        p = a.lerp(b, s) + n * rng.uniform(-wobble, wobble)
        spine.append(p)
    spine.append(b)
    widths = [width * (1.0 - 0.58 * (i / kinks)) for i in range(kinks + 1)]
    for side in (-1.0, 1.0):
        zc = side * (thickness * 0.5 + 0.008)
        pts3 = [V3(p.x, p.y, zc) for p in spine]
        ribbon_loft(sc, pts3, widths, [0.022] * (kinks + 1), up_hint=(0, 0, side), profile="bevel")


def _ensure_outward_islands(bm):
    visited = set()
    for seed in bm.faces:
        if seed in visited:
            continue
        comp = []
        stack = [seed]
        visited.add(seed)
        while stack:
            f = stack.pop()
            comp.append(f)
            for e in f.edges:
                for nf in e.link_faces:
                    if nf not in visited:
                        visited.add(nf)
                        stack.append(nf)
        bmesh.ops.recalc_face_normals(bm, faces=comp)
        comp_edges = {e for f in comp for e in f.edges}
        is_closed = all(len(e.link_faces) >= 2 for e in comp_edges)
        if not is_closed:
            continue
        pts = [v.co for v in {v for f in comp for v in f.verts}]
        ctr = sum(pts, Vector((0.0, 0.0, 0.0))) / max(1, len(pts))
        vol = 0.0
        for f in comp:
            if len(f.verts) == 3:
                a, b, c = [v.co - ctr for v in f.verts]
                vol += a.dot(b.cross(c))
        if vol < -1e-7:
            bmesh.ops.reverse_faces(bm, faces=comp)


def build_object(name, sc, collection, mat=None, anim_role=None, pivot_offset=(0.0, 0.0, 0.0), double_sided=False):
    bm = sc.bm
    if len(bm.faces) == 0:
        bm.free()
        return None
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    _ensure_outward_islands(bm)
    for face in bm.faces:
        face.smooth = True
    sharp_edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(33)]
    for e in sharp_edges:
        e.smooth = False
    # Bake crisp creases directly into topology so Roblox EditableMesh mirrors Blender's bevel edge highlights
    if sharp_edges:
        bmesh.ops.split_edges(bm, edges=sharp_edges)

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    if mat:
        obj.data.materials.append(mat)
    if anim_role:
        obj["gild_anim_role"] = anim_role
        obj["gild_pivot_offset"] = [round(pivot_offset[0], 4), round(pivot_offset[1], 4), round(pivot_offset[2], 4)]
    obj["rbx_double_sided"] = bool(double_sided)
    collection.objects.link(obj)
    return obj


# ===========================================================================
# 1. Dawnwarden's Oath (Vanguard SWORD_SHIELD - Sunlight)
# ===========================================================================

def build_dawnwarden_oath(root_col, pal):
    col = get_or_create_collection("art_gild_dawnwarden_oath", root_col)

    # Contoured ivory grip with cord ridges + gold collar rings (centered y=0)
    sc_h = Sculpt()
    grip_prof = [
        (0.0, -0.48), (0.145, -0.46), (0.155, -0.40), (0.115, -0.34),
        (0.102, -0.25), (0.120, -0.18), (0.104, -0.10), (0.125, 0.0),
        (0.106, 0.10), (0.122, 0.18), (0.106, 0.27), (0.125, 0.36),
        (0.160, 0.42), (0.148, 0.48), (0.0, 0.49),
    ]
    lathe_y(sc_h, grip_prof, segs=22, sx=1.08, sz=0.80)
    build_object("Handle", sc_h, col, mat=pal["ivory"])

    # Sunburst Chalice Pommel + radiant sun rays + gem
    sc_p = Sculpt()
    lathe_y(sc_p, [(0.0, -0.46), (0.17, -0.48), (0.11, -0.55), (0.21, -0.60), (0.0, -0.63)], segs=18, sx=1.08, sz=0.82)
    sun_pts = []
    for i in range(16):
        a = 2 * math.pi * i / 16 - math.pi / 2
        r = 0.34 if i % 2 == 0 else 0.17
        sun_pts.append(V2(r * math.cos(a), -0.74 + r * math.sin(a)))
    plate_xy(sc_p, sun_pts, 0.13, 0.05)
    build_object("Pommel", sc_p, col, mat=pal["gold"])

    sc_pg = Sculpt()
    gem_crystal(sc_pg, (0, -0.74, 0), 0.11, 0.13, 0.10, segs=8)
    build_object("PommelGem", sc_pg, col, mat=pal["sun_neon"])

    # Sweeping Seraph-Wing Crossguard (zero boxes!)
    sc_g = Sculpt()
    # Sculpted gothic arched bolster
    guard_pts = (
        [V2(-0.88, 0.86)]
        + quad_bezier_2d(V2(-0.88, 0.86), V2(-0.42, 0.56), V2(0.0, 0.50), 6)[1:]
        + quad_bezier_2d(V2(0.0, 0.50), V2(0.42, 0.56), V2(0.88, 0.86), 6)[1:]
        + quad_bezier_2d(V2(0.88, 0.86), V2(0.45, 0.72), V2(0.0, 0.80), 6)[1:]
        + quad_bezier_2d(V2(0.0, 0.80), V2(-0.45, 0.72), V2(-0.88, 0.86), 6)[1:-1]
    )
    plate_xy(sc_g, guard_pts, 0.24, 0.07)
    # Central escutcheon diamond
    plate_xy(sc_g, [V2(0, 0.44), V2(0.24, 0.65), V2(0, 0.90), V2(-0.24, 0.65)], 0.30, 0.07)
    build_object("Crossguard", sc_g, col, mat=pal["gold"])

    # Layered Seraph Feathers on Crossguard Wings
    sc_w = Sculpt()
    for side in (1.0, -1.0):
        for k, (bx, by, ang_deg, ln, wd, th) in enumerate([
            (0.42, 0.64, 24, 0.86, 0.21, 0.10),
            (0.38, 0.68, 38, 0.94, 0.22, 0.11),
            (0.32, 0.72, 52, 0.76, 0.18, 0.09),
            (0.26, 0.74, 65, 0.54, 0.14, 0.08),
        ]):
            pts = leaf_outline(V2(side * bx, by), math.radians(ang_deg if side > 0 else 180 - ang_deg), ln, wd, n=7)
            plate_xy(sc_w, pts, th, 0.038, z0=0.02 * ((-1) ** k))
    build_object("CrossguardWings", sc_w, col, mat=pal["white_gold"])

    # Cathedral Broadsword Blade (waisted ricasso + graceful Bezier taper + Gothic spear point)
    sc_b = Sculpt()
    left_edge = (
        [V2(-0.18, 0.74), V2(-0.15, 0.96), V2(-0.29, 1.12)]
        + quad_bezier_2d(V2(-0.29, 1.12), V2(-0.25, 2.70), V2(-0.17, 4.32), 10)[1:]
        + [V2(0.0, 5.20)]
    )
    right_edge = list(reversed([V2(-p.x, p.y) for p in left_edge[:-1]]))
    blade_pts = left_edge + right_edge
    plate_xy(sc_b, blade_pts, 0.15, 0.11, neck_u=0.05)
    build_object("Blade", sc_b, col, mat=pal["white_gold"])

    # Honed Golden Cutting Edge along outer silhouette
    sc_be = Sculpt()
    cut_right = list(reversed([V2(-p.x, p.y) for p in left_edge[2:]]))
    edge_strip_xy(sc_be, left_edge[2:], V2(0, 2.7), 0.068, 0.052, proud=0.022)
    edge_strip_xy(sc_be, cut_right, V2(0, 2.7), 0.068, 0.052, proud=0.022)
    build_object("BladeEdge", sc_be, col, mat=pal["gold"])

    # Radiant Solar Fuller & Engraved Sun Runes
    sc_bf = Sculpt()
    fuller_pts = [
        V2(0.0, 0.88), V2(0.068, 1.15), V2(0.045, 3.85), V2(0.0, 4.45),
        V2(-0.045, 3.85), V2(-0.068, 1.15),
    ]
    plate_xy(sc_bf, fuller_pts, 0.175, 0.024)
    for ry in (1.55, 2.15, 2.75, 3.35):
        inlay_stroke_xy(sc_bf, V2(-0.12, ry - 0.10), V2(0.0, ry + 0.08), 0.032, 0.024, 0.155)
        inlay_stroke_xy(sc_bf, V2(0.12, ry - 0.10), V2(0.0, ry + 0.08), 0.032, 0.024, 0.155)
    gem_crystal(sc_bf, (0, 0.66, 0), 0.10, 0.13, 0.16, segs=6)
    build_object("BladeFullerGlow", sc_bf, col, mat=pal["sun_neon"])

    # --- OffhandShield (face points -X, top +Y, width Z) ---
    sc_col = get_or_create_collection("OffhandShield", col)

    sc_hs = Sculpt()
    lathe_y(sc_hs, [(0.0, -0.32), (0.11, -0.28), (0.09, 0.0), (0.11, 0.28), (0.0, 0.32)], segs=16)
    build_object("HandleS", sc_hs, sc_col, mat=pal["gold"])

    def shield_outline(scale_w, scale_h):
        hw = 1.02 * scale_w
        hh = 1.56 * scale_h
        # Smooth gothic heater/aegis silhouette in (u=z_rbx, v=y_rbx)
        c_r_bot = quad_bezier_2d(V2(0, -hh), V2(hw * 0.72, -hh * 0.56), V2(hw * 0.98, hh * 0.22), 8)
        c_r_top = quad_bezier_2d(V2(hw * 0.98, hh * 0.22), V2(hw * 1.06, hh * 0.82), V2(hw * 0.66, hh * 0.98), 5)[1:]
        c_crest = quad_bezier_2d(V2(hw * 0.66, hh * 0.98), V2(hw * 0.30, hh * 0.88), V2(0, hh * 1.06), 4)[1:]
        right = c_r_bot + c_r_top + c_crest
        left = [V2(-p.x, p.y) for p in reversed(right[:-1])][:-1]
        return right + left

    camber = lambda p: 0.22 * (p.x ** 2)

    sc_sr = Sculpt()
    plate_zy(sc_sr, shield_outline(1.03, 1.03), 0.13, 0.10, x0=-0.34, camber_x=camber)
    build_object("ShieldRim", sc_sr, sc_col, mat=pal["gold"])

    sc_sb = Sculpt()
    plate_zy(sc_sb, shield_outline(0.89, 0.91), 0.17, 0.11, x0=-0.37, camber_x=camber)
    build_object("ShieldBody", sc_sb, sc_col, mat=pal["ivory"])

    # Sculpted Seraph Wing Reliefs framing the Sun Sanctuary
    sc_sw = Sculpt()
    for side in (1.0, -1.0):
        for k, (bu, bv, ang_deg, ln, wd, xo) in enumerate([
            (0.44, 0.18, 12, 0.96, 0.24, -0.45),
            (0.42, 0.34, 28, 1.08, 0.26, -0.46),
            (0.36, 0.52, 44, 0.98, 0.24, -0.45),
            (0.28, 0.68, 60, 0.80, 0.20, -0.44),
            (0.22, -0.05, -18, 0.72, 0.18, -0.44),
        ]):
            ang = math.radians(ang_deg if side > 0 else 180 - ang_deg)
            pts = leaf_outline(V2(side * bu, bv), ang, ln, wd, n=7)
            plate_zy(sc_sw, pts, 0.08, 0.032, x0=xo, camber_x=camber)
    build_object("ShieldWings", sc_sw, sc_col, mat=pal["white_gold"])

    # Rotating 12-Ray SunDisc (flamed & pointed rays around a solar gem)
    sc_sd = Sculpt()
    n_sun = 24
    sd_pts = []
    for i in range(n_sun):
        a = 2 * math.pi * i / n_sun
        if i % 2 == 0:
            r = 0.64 if (i // 2) % 2 == 0 else 0.48
        else:
            r = 0.24
        sd_pts.append(V2(r * math.cos(a), 0.24 + r * math.sin(a)))
    plate_zy(sc_sd, sd_pts, 0.11, 0.05, x0=-0.52)
    gem_crystal(sc_sd, (-0.56, 0.24, 0), 0.14, 0.18, 0.18, segs=10)
    build_object("SunDisc", sc_sd, sc_col, mat=pal["sun_neon"], anim_role="SunDisc", pivot_offset=(-0.54, 0.24, 0))

    # Orbiting Astrolabe Halo Rings with Star Studs
    for idx, (r, w, th, xc, tilt_x, tilt_y, mat_key) in enumerate([
        (0.76, 0.075, 0.055, -0.62, 16, 12, "gold"),
        (0.94, 0.058, 0.044, -0.68, -18, -14, "white_gold"),
    ], start=1):
        sc_hr = Sculpt()
        rot_m = Euler((math.radians(tilt_x), math.radians(tilt_y), 0), "XYZ").to_matrix()
        ctr = Vector((xc, 0.24, 0))
        pts3d = []
        for i in range(28):
            a = 2 * math.pi * i / 28
            p = ctr + rot_m @ Vector((0.0, r * math.sin(a), r * math.cos(a)))
            pts3d.append(p)
        closed_ring_loft(sc_hr, pts3d, [w] * 28, [th] * 28, up_hint=rot_m @ Vector((1, 0, 0)), profile="bevel")
        for k in range(4):
            a = math.pi * 0.5 * k
            p_gem = ctr + rot_m @ Vector((0.0, r * math.sin(a), r * math.cos(a)))
            gem_crystal(sc_hr, p_gem, 0.07, 0.07, 0.07, segs=6)
        build_object(f"HaloRing{idx}", sc_hr, sc_col, mat=pal[mat_key], anim_role=f"HaloRing{idx}", pivot_offset=(xc, 0.24, 0))

    return col


# ===========================================================================
# 2. Eclipse Sisters (Striker DAGGERS - Umbra & Corona)
# ===========================================================================

def _build_sister_dagger(target_col, suffix, flip_x, grip_mat, guard_mat, blade_mat, edge_mat, rune_mat, ring_mat, core_mat):
    s = -1.0 if flip_x else 1.0

    # Contoured spiral-waisted dagger handle
    sc_h = Sculpt()
    prof = [
        (0.0, -0.40), (0.125, -0.37), (0.096, -0.26), (0.112, -0.14),
        (0.095, 0.0), (0.114, 0.14), (0.098, 0.26), (0.132, 0.36), (0.0, 0.40),
    ]
    lathe_y(sc_h, prof, segs=18, sx=1.08, sz=0.78)
    build_object(f"Handle{suffix}", sc_h, target_col, mat=grip_mat)

    # Ring Pommel Cradle with twin crescent horns
    sc_rp = Sculpt()
    pom_ctr = Vector((0, -0.60, 0))
    outer_ring = [pom_ctr + Vector((0.22 * math.cos(2 * math.pi * i / 22), 0.22 * math.sin(2 * math.pi * i / 22), 0)) for i in range(22)]
    closed_ring_loft(sc_rp, outer_ring, [0.055] * 22, [0.065] * 22, up_hint=(0, 0, 1), profile="bevel")
    horn_pts = (
        quad_bezier_2d(V2(-0.18 * s, -0.52), V2(-0.34 * s, -0.64), V2(-0.22 * s, -0.84), 6)
        + quad_bezier_2d(V2(-0.22 * s, -0.84), V2(-0.28 * s, -0.66), V2(-0.12 * s, -0.50), 6)[1:-1]
    )
    plate_xy(sc_rp, horn_pts, 0.07, 0.025)
    build_object(f"RingPommel{suffix}", sc_rp, target_col, mat=guard_mat)

    # Asymmetrical Lunar Crescent Guard
    sc_g = Sculpt()
    guard_arc = (
        quad_bezier_2d(V2(0.46 * s, 0.64), V2(0.24 * s, 0.36), V2(0.0, 0.38), 6)
        + quad_bezier_2d(V2(0.0, 0.38), V2(-0.22 * s, 0.40), V2(-0.38 * s, 0.26), 6)[1:]
        + quad_bezier_2d(V2(-0.38 * s, 0.26), V2(-0.18 * s, 0.50), V2(0.0, 0.56), 6)[1:]
        + quad_bezier_2d(V2(0.0, 0.56), V2(0.22 * s, 0.52), V2(0.46 * s, 0.64), 6)[1:-1]
    )
    plate_xy(sc_g, guard_arc, 0.14, 0.045)
    for ang_d, ln, wd in [(42, 0.42, 0.11), (62, 0.30, 0.09)]:
        a = math.radians(ang_d if s > 0 else 180 - ang_d)
        plate_xy(sc_g, leaf_outline(V2(0.14 * s, 0.44), a, ln, wd, n=6), 0.09, 0.028)
    build_object(f"Guard{suffix}", sc_g, target_col, mat=guard_mat)

    # S-Curved Recurve Blade (Umbra: wave-kris with dorsal hook; Corona: sweeping flame talon)
    sc_b = Sculpt()
    if suffix == "":
        front_edge = (
            [V2(0.10 * s, 0.46)]
            + quad_bezier_2d(V2(0.10 * s, 0.46), V2(0.24 * s, 1.05), V2(0.14 * s, 1.72), 8)[1:]
            + quad_bezier_2d(V2(0.14 * s, 1.72), V2(0.06 * s, 2.15), V2(0.02 * s, 2.58), 6)[1:]
        )
        back_spine = (
            [V2(0.02 * s, 2.58)]
            + quad_bezier_2d(V2(0.02 * s, 2.58), V2(-0.18 * s, 2.02), V2(-0.08 * s, 1.48), 7)[1:]
            + quad_bezier_2d(V2(-0.08 * s, 1.48), V2(0.02 * s, 0.96), V2(-0.10 * s, 0.46), 7)[1:-1]
        )
    else:
        front_edge = (
            [V2(0.11 * s, 0.46)]
            + quad_bezier_2d(V2(0.11 * s, 0.46), V2(0.22 * s, 1.25), V2(0.18 * s, 1.90), 8)[1:]
            + quad_bezier_2d(V2(0.18 * s, 1.90), V2(0.12 * s, 2.25), V2(0.01 * s, 2.52), 6)[1:]
        )
        back_spine = (
            [V2(0.01 * s, 2.52)]
            + quad_bezier_2d(V2(0.01 * s, 2.52), V2(-0.14 * s, 1.95), V2(-0.12 * s, 1.35), 7)[1:]
            + quad_bezier_2d(V2(-0.12 * s, 1.35), V2(-0.08 * s, 0.88), V2(-0.10 * s, 0.46), 7)[1:-1]
        )
    blade_pts = front_edge + back_spine
    plate_xy(sc_b, blade_pts, 0.095, 0.072, neck_u=0.04)
    build_object(f"Blade{suffix}", sc_b, target_col, mat=blade_mat)

    sc_be = Sculpt()
    edge_strip_xy(sc_be, front_edge, V2(-0.05 * s, 1.4), 0.050, 0.036, proud=0.018)
    build_object(f"BladeEdge{suffix}", sc_be, target_col, mat=edge_mat)

    sc_br = Sculpt()
    for p0, p1 in [
        (V2(0.0 * s, 0.72), V2(0.06 * s, 1.15)),
        (V2(0.06 * s, 1.15), V2(0.02 * s, 1.65)),
        (V2(0.02 * s, 1.65), V2(0.04 * s, 2.08)),
    ]:
        inlay_stroke_xy(sc_br, p0, p1, 0.028, 0.022, 0.105)
    gem_crystal(sc_br, (0.0, 0.48, 0), 0.07, 0.09, 0.11, segs=6)
    build_object(f"BladeRunes{suffix}", sc_br, target_col, mat=rune_mat)

    # Orbiting Eclipse Ring & Core inside Ring Pommel
    sc_er = Sculpt()
    pts_er = [pom_ctr + Vector((0.16 * math.cos(2 * math.pi * i / 20), 0.16 * math.sin(2 * math.pi * i / 20), 0.05 * math.sin(2 * math.pi * i / 20))) for i in range(20)]
    closed_ring_loft(sc_er, pts_er, [0.035] * 20, [0.035] * 20, up_hint=(0.3, 0, 1), profile="bevel")
    build_object(f"EclipseRing{suffix}", sc_er, target_col, mat=ring_mat, anim_role="EclipseRing", pivot_offset=(0, -0.60, 0))

    sc_ec = Sculpt()
    gem_crystal(sc_ec, (0, -0.60, 0), 0.095, 0.115, 0.095, segs=8)
    build_object(f"EclipseCore{suffix}", sc_ec, target_col, mat=core_mat, anim_role="EclipseCore", pivot_offset=(0, -0.60, 0))


def build_eclipse_sisters(root_col, pal):
    col = get_or_create_collection("art_gild_eclipse_sisters", root_col)
    _build_sister_dagger(
        col, "", False,
        pal["obsidian"], pal["gold"], pal["obsidian"], pal["gold"], pal["umbra_edge"], pal["gold"], pal["obsidian"],
    )
    left_col = get_or_create_collection("LeftDagger", col)
    _build_sister_dagger(
        left_col, "L", True,
        pal["white_gold"], pal["obsidian"], pal["white_gold"], pal["obsidian"], pal["umbra_edge"], pal["sun_neon"], pal["gold"],
    )
    return col


# ===========================================================================
# 3. Aurora Skyhook (Marksman BOW - Aurora)
# ===========================================================================

def build_aurora_skyhook(root_col, pal):
    col = get_or_create_collection("art_gild_aurora_skyhook", root_col)

    # Ergonomic Contoured Riser + Arrow Shelf Wing Guard
    sc_h = Sculpt()
    lathe_y(sc_h, [
        (0.0, -0.52), (0.14, -0.46), (0.12, -0.34), (0.105, -0.18),
        (0.115, 0.0), (0.105, 0.18), (0.125, 0.36), (0.15, 0.48), (0.0, 0.54),
    ], segs=20, sx=0.88, sz=1.18)
    # Sculpted celestial wing arrow-rest & riser crest
    for side_y in (1.0, -1.0):
        for bx, by, ang_d, ln, wd in [(0.08, side_y * 0.24, side_y * 68, 0.48, 0.13), (0.12, side_y * 0.12, side_y * 42, 0.38, 0.11)]:
            pts = leaf_outline(V2(bx, by), math.radians(ang_d), ln, wd, n=6)
            plate_xy(sc_h, pts, 0.09, 0.025, z0=-0.12)
    build_object("Handle", sc_h, col, mat=pal["gold"])

    # Lotus-Petal Gold Limb Clasps
    for sign, cname in [(1.0, "ClaspUpper"), (-1.0, "ClaspLower")]:
        sc_c = Sculpt()
        prof = [
            (0.0, 0.46 * sign), (0.15, 0.50 * sign), (0.12, 0.56 * sign),
            (0.18, 0.62 * sign), (0.13, 0.68 * sign), (0.0, 0.70 * sign),
        ]
        if sign < 0:
            prof = list(reversed(prof))
        lathe_y(sc_c, prof, segs=16, sx=0.85, sz=1.18, offset=(0.0, 0.0, 0.04))
        for k in range(4):
            a = math.radians(90 * k + 45)
            # 4 lotus prongs clasping the ribbon root
            p0 = V3(0.10 * math.cos(a), 0.56 * sign, 0.04 + 0.10 * math.sin(a))
            p1 = V3(0.16 * math.cos(a), 0.68 * sign, 0.02 + 0.14 * math.sin(a))
            p2 = V3(0.09 * math.cos(a), 0.80 * sign, 0.04 + 0.10 * math.sin(a))
            ribbon_loft(sc_c, [p0, p1, p2], [0.075, 0.06, 0.015], [0.04, 0.03, 0.01], up_hint=(0, 0, 1), profile="lens")
        build_object(cname, sc_c, col, mat=pal["white_gold"])

    # Sculpted 3D Recurve Aurora Ribbon Limbs + Entwined Translucent Violet Streamers
    for sign, rname, sname, rmat, smat in [
        (1.0, "AuroraRibbonUpper", "AuroraVeilUpper", pal["teal"], pal["violet"]),
        (-1.0, "AuroraRibbonLower", "AuroraVeilLower", pal["violet"], pal["pink_silk"]),
    ]:
        pivot = (0.0, 0.56 * sign, 0.04)
        spine = cubic_bezier_3d(
            V3(0.0, 0.54 * sign, 0.04),
            V3(0.05 * sign, 1.02 * sign, -0.22),
            V3(-0.04 * sign, 1.56 * sign, 0.22),
            V3(0.0, 1.96 * sign, 0.50),
            n=22,
        )
        widths = [0.28 * (1.0 - 0.56 * (i / 22)) + 0.05 * math.sin(math.pi * (i / 22)) for i in range(23)]
        thicks = [0.11 * (1.0 - 0.50 * (i / 22)) for i in range(23)]
        sc_r = Sculpt()
        ribbon_loft(sc_r, spine, widths, thicks, up_hint=(0, 0, 1), profile="lens", twist_fn=lambda t: sign * 0.45 * math.sin(t * math.pi))
        build_object(rname, sc_r, col, mat=rmat, anim_role=rname, pivot_offset=pivot, double_sided=True)

        # Flowing trailing Aurora silk veil arcing behind each limb
        veil_spine = cubic_bezier_3d(
            V3(0.0, 0.64 * sign, 0.03),
            V3(0.14 * sign, 1.18 * sign, -0.02),
            V3(0.18 * sign, 1.72 * sign, 0.42),
            V3(0.04 * sign, 2.26 * sign, 0.82),
            n=20,
        )
        vw = [0.14 * math.sin(math.pi * max(0.05, min(0.95, i / 20))) + 0.02 for i in range(21)]
        vth = [0.045 * (1.0 - 0.5 * (i / 20)) for i in range(21)]
        sc_v = Sculpt()
        ribbon_loft(sc_v, veil_spine, vw, vth, up_hint=(1, 0, 0), profile="lens", twist_fn=lambda t: -sign * 0.9 * t)
        build_object(sname, sc_v, col, mat=smat, anim_role=rname, pivot_offset=pivot, double_sided=True)

    # Crescent-Star Bow Tip Nocks
    for sign, tname in [(1.0, "TipHornUpper"), (-1.0, "TipHornLower")]:
        sc_t = Sculpt()
        horn = cubic_bezier_3d(
            V3(0.0, 1.90 * sign, 0.46),
            V3(0.0, 2.02 * sign, 0.58),
            V3(0.0, 2.16 * sign, 0.72),
            V3(0.0, 2.24 * sign, 0.88),
            n=10,
        )
        ribbon_loft(sc_t, horn, [0.13 * (1 - 0.78 * (i / 10)) for i in range(11)], [0.09 * (1 - 0.75 * (i / 10)) for i in range(11)], up_hint=(1, 0, 0), profile="oval")
        gem_crystal(sc_t, (0.0, 1.98 * sign, 0.50), 0.075, 0.095, 0.075, segs=6)
        build_object(tname, sc_t, col, mat=pal["gold"])

    # Tapered Luminous String + Nock Crystal
    sc_bs = Sculpt()
    lathe_y(sc_bs, [(0.0, -1.96), (0.018, -1.80), (0.024, 0.0), (0.018, 1.80), (0.0, 1.96)], segs=8, offset=(0.0, 0.0, 0.50))
    build_object("BowString", sc_bs, col, mat=pal["white_gold"])

    sc_nc = Sculpt()
    gem_crystal(sc_nc, (0.20, 0.10, 0.48), 0.055, 0.055, 0.075, segs=6)
    build_object("NockCrystal", sc_nc, col, mat=pal["teal"])

    # HunterArrow Child Model (shaft along -Z from nock z=0.48 to tip z=-1.52)
    arr_col = get_or_create_collection("HunterArrow", col)
    sc_as = Sculpt()
    lathe_y(sc_as, [(0.0, -1.02), (0.026, -0.96), (0.020, 0.0), (0.028, 0.96), (0.0, 1.02)], segs=10, offset=(0.20, 0.10, -0.52), rot_deg=(90, 0, 0))
    build_object("ArrowShaft", sc_as, arr_col, mat=pal["white_gold"])

    sc_ah = Sculpt()
    ah_pts = [
        V3(0.20, 0.10, -1.44),
        V3(0.20, 0.165, -1.49),
        V3(0.20, 0.10, -1.78),
        V3(0.20, 0.035, -1.49),
    ]
    gem_crystal(sc_ah, (0.20, 0.10, -1.58), 0.085, 0.19, 0.055, segs=6, rot_deg=(90, 0, 0))
    build_object("ArrowHead", sc_ah, arr_col, mat=pal["teal"])

    for idx, ang_d in enumerate([0, 120, 240], start=1):
        sc_af = Sculpt()
        ang_r = math.radians(ang_d)
        f_pts = [
            V3(0.20, 0.10, 0.30),
            V3(0.20 + 0.085 * math.sin(ang_r), 0.10 + 0.085 * math.cos(ang_r), 0.36),
            V3(0.20 + 0.065 * math.sin(ang_r), 0.10 + 0.065 * math.cos(ang_r), 0.44),
            V3(0.20, 0.10, 0.46),
        ]
        ribbon_loft(sc_af, [V3(0.20, 0.10, 0.24), V3(0.20 + 0.055 * math.sin(ang_r), 0.10 + 0.055 * math.cos(ang_r), 0.34), V3(0.20 + 0.025 * math.sin(ang_r), 0.10 + 0.025 * math.cos(ang_r), 0.45)], [0.05, 0.075, 0.02], [0.012, 0.010, 0.008], up_hint=(math.cos(ang_r), -math.sin(ang_r), 0), profile="lens")
        build_object(f"ArrowFletch_{idx}", sc_af, arr_col, mat=pal["pink_silk" if idx == 2 else "teal"])

    return col


# ===========================================================================
# 4. Wyrmheart Cleaver (Berserker AXE - Dragonfire)
# ===========================================================================

def build_wyrmheart_cleaver(root_col, pal):
    col = get_or_create_collection("art_gild_wyrmheart_cleaver", root_col)
    rng = random.Random(42)

    # Contoured 26-ring oval greataxe haft spanning [-2.75, 2.75]
    sc_h = Sculpt()
    haft_prof = [
        (0.0, -2.76), (0.15, -2.72), (0.115, -2.52), (0.145, -2.35), (0.118, -2.20),
        (0.115, -1.75), (0.142, -1.70), (0.115, -1.00), (0.142, -0.94), (0.116, -0.10),
        (0.145, -0.02), (0.118, 0.72), (0.148, 0.80), (0.125, 1.48), (0.165, 1.56),
        (0.150, 2.60), (0.180, 2.72), (0.0, 2.78),
    ]
    lathe_y(sc_h, haft_prof, segs=20, sx=0.86, sz=1.18)
    build_object("Handle", sc_h, col, mat=pal["dark_iron"])

    # Ribbed Leather Grip Wraps at both hands (Grip = 0.35, OffhandGrip = -1.35)
    for gname, gy in [("GripWrapUpper", 0.35), ("GripWrapLower", -1.35)]:
        sc_gw = Sculpt()
        g_prof = []
        for k in range(11):
            t = k / 10
            yy = gy - 0.35 + 0.70 * t
            r = 0.136 + 0.016 * (1.0 if k % 2 == 1 else 0.0)
            g_prof.append((r, yy))
        g_prof = [(0.11, gy - 0.36)] + g_prof + [(0.11, gy + 0.36)]
        lathe_y(sc_gw, g_prof, segs=20, sx=0.88, sz=1.20)
        build_object(gname, sc_gw, col, mat=pal["leather"])

    # Dragon-Talon Clawed Pommel gripping a Crimson Ember Stone
    sc_pm = Sculpt()
    lathe_y(sc_pm, [(0.0, -2.68), (0.18, -2.72), (0.24, -2.84), (0.15, -2.92), (0.0, -2.94)], segs=18, sx=0.92, sz=1.16)
    for k in range(3):
        a = math.radians(120 * k + 30)
        talon = cubic_bezier_3d(
            V3(0.16 * math.cos(a), -2.82, 0.16 * math.sin(a)),
            V3(0.28 * math.cos(a), -3.00, 0.28 * math.sin(a)),
            V3(0.22 * math.cos(a), -3.18, 0.22 * math.sin(a)),
            V3(0.06 * math.cos(a), -3.26, 0.06 * math.sin(a)),
            n=10,
        )
        ribbon_loft(sc_pm, talon, [0.09 * (1 - 0.8 * (i / 10)) for i in range(11)], [0.07 * (1 - 0.75 * (i / 10)) for i in range(11)], up_hint=(0, 1, 0), profile="oval")
    build_object("Pommel", sc_pm, col, mat=pal["gold"])

    sc_pg = Sculpt()
    gem_crystal(sc_pg, (0, -3.06, 0), 0.15, 0.19, 0.15, segs=8)
    build_object("PommelHeart", sc_pg, col, mat=pal["crimson_fire"])

    # Sculpted Armored Draconic Skull Collar (upper/lower snout fangs + brow crest + eyes)
    sc_ds = Sculpt()
    skull_pts = (
        [V2(-0.22, 1.62), V2(0.14, 1.56), V2(0.56, 1.50), V2(0.32, 1.72), V2(0.68, 1.76),
         V2(0.28, 1.94), V2(0.32, 2.26), V2(0.72, 2.40), V2(0.36, 2.48), V2(0.60, 2.66),
         V2(0.12, 2.64), V2(-0.26, 2.52), V2(-0.14, 2.08)]
    )
    plate_xy(sc_ds, skull_pts, 0.42, 0.085)
    # Brow crest plates
    for side in (-1.0, 1.0):
        plate_xy(sc_ds, leaf_outline(V2(-0.08, 2.42), math.radians(18), 0.62, 0.22, n=6), 0.14, 0.045, z0=side * 0.16)
    build_object("DragonSkull", sc_ds, col, mat=pal["gold"])

    # Sweeping 3D Curved Bone-Gold Dragon Horns flaring outward in +/-Z & back in -X
    for hname, sign_y, end_y in [("SkullHornTop", 1.0, 3.38), ("SkullHornBot", -1.0, 1.02)]:
        sc_sh = Sculpt()
        for side_z in (-1.0, 1.0):
            base_y = 2.48 if sign_y > 0 else 1.70
            h_spine = cubic_bezier_3d(
                V3(0.0, base_y, side_z * 0.16),
                V3(-0.34, base_y + sign_y * 0.24, side_z * 0.36),
                V3(-0.76, base_y + sign_y * 0.56, side_z * 0.30),
                V3(-1.02, end_y, side_z * 0.12),
                n=14,
            )
            hw = [0.22 * (1.0 - 0.86 * (i / 14)) + 0.015 * math.sin(i * 2.2) for i in range(15)]
            hth = [0.19 * (1.0 - 0.86 * (i / 14)) for i in range(15)]
            ribbon_loft(sc_sh, h_spine, hw, hth, up_hint=(0, 0, side_z), profile="oval")
        build_object(hname, sc_sh, col, mat=pal["bone_horn"])

    # Double-Bearded Crescent Cleaver Blade with a TRUE OPEN HEART WINDOW around WyrmHeart
    sc_b = Sculpt()
    z0 = 2.08
    T = V2(1.88, z0 + 1.38)
    B = V2(1.76, z0 - 1.32)
    outer_top = quad_bezier_2d(V2(0.18, z0 + 0.44), V2(1.05, z0 + 0.62), T, 10)
    cutting_arc = []
    n_cut = 16
    for i in range(n_cut + 1):
        s = i / n_cut
        p = T.lerp(B, s)
        flare = 0.42 * math.sin(math.pi * s) - 0.22 * math.exp(-((s - 0.52) * 5.2) ** 2)
        p.x += flare
        cutting_arc.append(p)
    outer_bot = quad_bezier_2d(B, V2(1.02, z0 - 0.62), V2(0.18, z0 - 0.46), 10)

    # Split blade into 3 clean convex/shallow-concave plates so the heart socket is completely hollow!
    # 1) Upper Wing
    cut_upper = cutting_arc[:7]  # from T down to y ~ z0 + 0.32
    u_inner = quad_bezier_2d(V2(1.22, z0 + 0.22), V2(0.68, z0 + 0.44), V2(0.18, z0 + 0.44), 6)
    plate_xy(sc_b, outer_top + cut_upper[1:] + u_inner[1:-1], 0.21, 0.16, neck_u=0.25)

    # 2) Front Bridge joining upper & lower wings outside the heart window (x >= 1.18)
    cut_mid = cutting_arc[6:11]  # around the bearded middle notch
    bridge_back = [V2(1.16, cutting_arc[10].y), V2(1.22, z0), V2(1.16, cutting_arc[6].y)]
    plate_xy(sc_b, cut_mid + bridge_back, 0.19, 0.12)

    # 3) Lower Bearded Wing
    cut_lower = cutting_arc[10:]
    b_inner = quad_bezier_2d(V2(0.18, z0 - 0.46), V2(0.68, z0 - 0.42), V2(1.20, z0 - 0.22), 6)
    plate_xy(sc_b, cut_lower + outer_bot[1:] + b_inner[1:-1], 0.21, 0.16, neck_u=0.25)
    build_object("Blade", sc_b, col, mat=pal["dark_iron"])

    sc_be = Sculpt()
    edge_strip_xy(sc_be, cutting_arc, V2(1.10, z0), 0.14, 0.145, proud=0.025)
    build_object("BladeEdge", sc_be, col, mat=pal["gold"])

    # Volcanic Magma Vein Inlays radiating across upper & lower wings and front bridge
    sc_ru = Sculpt()
    for p0, p1 in [
        (V2(1.18, z0 + 0.40), V2(1.78, z0 + 1.10)),
        (V2(1.24, z0 + 0.24), V2(1.88, z0 + 0.56)),
        (V2(1.24, z0 - 0.22), V2(1.86, z0 - 0.52)),
        (V2(1.16, z0 - 0.38), V2(1.70, z0 - 1.05)),
    ]:
        inlay_vein_xy(sc_ru, p0, p1, 0.072, 0.20, rng, kinks=6, wobble=0.055)
    for side in (-1.0, 1.0):
        gem_crystal(sc_ru, (0.28, 2.28, side * 0.21), 0.085, 0.11, 0.06, segs=6)
    build_object("RuneInlay", sc_ru, col, mat=pal["crimson_fire"])

    # Sweeping Dorsal Wyrm-Tail Counterspike (-X)
    sc_bs = Sculpt()
    spike_pts = (
        quad_bezier_2d(V2(-0.16, z0 + 0.18), V2(-0.48, z0 + 0.24), V2(-0.88, z0 + 0.56), 7)
        + quad_bezier_2d(V2(-0.88, z0 + 0.56), V2(-0.62, z0 + 0.08), V2(-0.56, z0 - 0.18), 6)[1:]
        + quad_bezier_2d(V2(-0.56, z0 - 0.18), V2(-0.34, z0 - 0.12), V2(-0.16, z0 - 0.16), 5)[1:-1]
    )
    plate_xy(sc_bs, spike_pts, 0.16, 0.075)
    build_object("BackSpike", sc_bs, col, mat=pal["dark_iron"])

    # Skeletal Dragon Rib-Cage wrapping WyrmHeart at (0.74, z0, 0)
    hc_ctr = V3(0.74, z0, 0.0)
    sc_hc = Sculpt()
    for k in range(3):
        yy = z0 + (k - 1) * 0.20
        r_span = 0.34 - abs(k - 1) * 0.04
        for side_z in (-1.0, 1.0):
            rib = cubic_bezier_3d(
                V3(0.40, yy, side_z * 0.12),
                V3(0.58, yy + 0.03, side_z * (r_span + 0.14)),
                V3(0.92, yy + 0.03, side_z * (r_span + 0.14)),
                V3(1.10, yy, side_z * 0.08),
                n=10,
            )
            ribbon_loft(sc_hc, rib, [0.055] * 11, [0.045] * 11, up_hint=(0, 1, 0), profile="oval")
    build_object("HeartCageRing", sc_hc, col, mat=pal["gold"])

    # Sculpted Multi-Faceted Pulsing WyrmHeart inside cage
    sc_wh = Sculpt()
    gem_crystal(sc_wh, (0.74, z0, 0.0), 0.24, 0.32, 0.23, segs=10)
    gem_crystal(sc_wh, (0.66, z0 + 0.08, 0.04), 0.15, 0.20, 0.15, segs=8, rot_deg=(18, 0, 20))
    build_object("WyrmHeart", sc_wh, col, mat=pal["crimson_fire"], anim_role="WyrmHeart", pivot_offset=(0.74, z0, 0.0))

    return col


# ===========================================================================
# 5. Orrery of the Ninth Sky (Scholar STAFF - Star-Orbit)
# ===========================================================================

def build_ninth_sky_orrery(root_col, pal):
    col = get_or_create_collection("art_gild_ninth_sky_orrery", root_col)

    # Tapered 28-ring Midnight-Blue Astronomer's Spire
    sc_h = Sculpt()
    spire_prof = [
        (0.0, -2.26), (0.04, -2.05), (0.085, -1.75), (0.105, -1.20),
        (0.118, -0.50), (0.115, 0.20), (0.125, 0.90), (0.135, 1.55),
        (0.175, 1.98), (0.140, 2.08), (0.0, 2.10),
    ]
    lathe_y(sc_h, spire_prof, segs=22)
    build_object("Handle", sc_h, col, mat=pal["astral_blue"])

    # Gold Astrolabe Collars + Sculpted Calyx Pommel
    sc_sb = Sculpt()
    for y_band, r_band in [(-1.42, 0.145), (-0.40, 0.148), (0.55, 0.152), (1.35, 0.160), (1.92, 0.205)]:
        lathe_y(sc_sb, [(r_band * 0.78, y_band - 0.10), (r_band, y_band - 0.04), (r_band * 1.12, y_band), (r_band, y_band + 0.04), (r_band * 0.78, y_band + 0.10)], segs=20)
    build_object("ShaftBands", sc_sb, col, mat=pal["gold"])

    sc_pm = Sculpt()
    gem_crystal(sc_pm, (0, -2.38, 0), 0.16, 0.24, 0.16, segs=8)
    build_object("Pommel", sc_pm, col, mat=pal["star_core"])

    # Celestial Twin-Crescent Lyre Cradle around sphere at (0, 2.75, 0)
    sc_cr = Sculpt()
    for side in (-1.0, 1.0):
        arm = cubic_bezier_3d(
            V3(side * 0.10, 1.96, 0.0),
            V3(side * 0.76, 2.06, 0.0),
            V3(side * 0.96, 2.66, 0.0),
            V3(side * 0.66, 3.42, 0.0),
            n=16,
        )
        aw = [0.18 * (1.0 - 0.68 * (i / 16)) + 0.04 * math.sin(math.pi * (i / 16)) for i in range(17)]
        ath = [0.13 * (1.0 - 0.65 * (i / 16)) for i in range(17)]
        ribbon_loft(sc_cr, arm, aw, ath, up_hint=(0, 0, 1), profile="lens")
        # Astral wing feathers below cradle
        for ang_d, ln, wd in [(24, 0.56, 0.14), (42, 0.44, 0.12)]:
            a = math.radians(ang_d if side > 0 else 180 - ang_d)
            plate_xy(sc_cr, leaf_outline(V2(side * 0.26, 2.04), a, ln, wd, n=6), 0.08, 0.025)
    build_object("Cradle", sc_cr, col, mat=pal["gold"])

    center = V3(0, 2.75, 0)
    # 3 Precision-Notched Counter-Tilted Armillary Rings
    for idx, (r, w, th, tilt_deg, mkey) in enumerate([
        (0.76, 0.080, 0.048, (18, 0, 24), "gold"),
        (0.58, 0.068, 0.042, (-26, 34, 0), "white_gold"),
        (0.42, 0.056, 0.036, (34, -22, 16), "gold"),
    ], start=1):
        sc_or = Sculpt()
        rot_m = Euler((math.radians(tilt_deg[0]), math.radians(tilt_deg[1]), math.radians(tilt_deg[2])), "XYZ").to_matrix()
        pts_o = [center + rot_m @ Vector((r * math.cos(2 * math.pi * i / 28), 0.0, r * math.sin(2 * math.pi * i / 28))) for i in range(28)]
        closed_ring_loft(sc_or, pts_o, [w] * 28, [th] * 28, up_hint=rot_m @ Vector((0, 1, 0)), profile="bevel")
        for k in range(4):
            a = math.pi * 0.5 * k
            p_card = center + rot_m @ Vector((r * math.cos(a), 0.0, r * math.sin(a)))
            gem_crystal(sc_or, p_card, 0.055, 0.08, 0.055, segs=6)
        build_object(f"OrreryRing{idx}", sc_or, col, mat=pal[mkey], anim_role=f"OrreryRing{idx}", pivot_offset=(0, 2.75, 0))

    # 3D 14-Point Sunburst Core
    sc_os = Sculpt()
    gem_crystal(sc_os, center, 0.16, 0.22, 0.16, segs=8)
    gem_crystal(sc_os, center, 0.24, 0.09, 0.09, segs=6, rot_deg=(0, 0, 90))
    gem_crystal(sc_os, center, 0.09, 0.09, 0.24, segs=6, rot_deg=(90, 0, 0))
    build_object("OrreryStar", sc_os, col, mat=pal["star_core"], anim_role="OrreryStar", pivot_offset=(0, 2.75, 0))

    # 3 Sculpted Moons (ringed planetoid, crescent-cradled pearl, emerald comet-gem)
    sc_m1 = Sculpt()
    m1_p = V3(0.92, 2.94, 0.14)
    gem_crystal(sc_m1, m1_p, 0.105, 0.105, 0.105, segs=10)
    m1_ring = [m1_p + Euler((0.4, 0, -0.5), "XYZ").to_matrix() @ Vector((0.18 * math.cos(2 * math.pi * i / 18), 0, 0.18 * math.sin(2 * math.pi * i / 18))) for i in range(18)]
    closed_ring_loft(sc_m1, m1_ring, [0.025] * 18, [0.015] * 18, up_hint=(0, 1, 0), profile="bevel")
    build_object("OrreryMoon1", sc_m1, col, mat=pal["moon_pearl"], anim_role="OrreryMoon1", pivot_offset=(0, 2.75, 0))

    sc_m2 = Sculpt()
    gem_crystal(sc_m2, (-0.74, 2.54, -0.44), 0.09, 0.11, 0.09, segs=8, rot_deg=(20, 0, 35))
    build_object("OrreryMoon2", sc_m2, col, mat=pal["moon_pearl"], anim_role="OrreryMoon2", pivot_offset=(0, 2.75, 0))

    sc_m3 = Sculpt()
    gem_crystal(sc_m3, (0.14, 3.46, 0.52), 0.085, 0.13, 0.085, segs=6, rot_deg=(-25, 18, 0))
    build_object("OrreryMoon3", sc_m3, col, mat=pal["jade"], anim_role="OrreryMoon3", pivot_offset=(0, 2.75, 0))

    return col


# ===========================================================================
# 6. Evergarden Codex (Healer TOME - Bloom)
# ===========================================================================

def _open_sheet_mesh(sc, x_start, x_end, y_base, arch_height, z_half, thick, side=1.0, curl_tip=0.0):
    """Build a smoothly curved open book cover or multi-layer page block along X and Z."""
    nu, nv = 10, 4
    top_grid, bot_grid = [], []
    for iu in range(nu + 1):
        t = iu / nu
        x = side * (x_start + (x_end - x_start) * t)
        # Gull-wing book arch + optional soft upward page wave
        y = y_base + arch_height * math.sin(t * math.pi * 0.92) + t * 0.08 + curl_tip * (t ** 2)
        t_row, b_row = [], []
        for iv in range(nv + 1):
            s = (iv / nv) * 2.0 - 1.0  # -1..1 along z
            # Subtle scalloped tapering at top/bottom corners
            edge_pull = 1.0 - 0.05 * ((1.0 - abs(t - 0.5) * 2.0) ** 2)
            z = s * z_half * (1.0 - 0.04 * (t ** 2))
            scallop_y = 0.018 * (1.0 - s * s)
            t_row.append(sc.v((x, y + scallop_y, z)))
            b_row.append(sc.v((x, y + scallop_y - thick, z)))
        top_grid.append(t_row)
        bot_grid.append(b_row)

    for iu in range(nu):
        for iv in range(nv):
            sc.f([top_grid[iu][iv], top_grid[iu + 1][iv], top_grid[iu + 1][iv + 1], top_grid[iu][iv + 1]])
            sc.f([bot_grid[iu][iv + 1], bot_grid[iu + 1][iv + 1], bot_grid[iu + 1][iv], bot_grid[iu][iv]])
    # Perimeter walls
    for iu in range(nu):
        sc.f([top_grid[iu][0], bot_grid[iu][0], bot_grid[iu + 1][0], top_grid[iu + 1][0]])
        sc.f([top_grid[iu + 1][nv], bot_grid[iu + 1][nv], bot_grid[iu][nv], top_grid[iu][nv]])
    for iv in range(nv):
        sc.f([top_grid[0][iv + 1], bot_grid[0][iv + 1], bot_grid[0][iv], top_grid[0][iv]])
        sc.f([top_grid[nu][iv], bot_grid[nu][iv], bot_grid[nu][iv + 1], top_grid[nu][iv + 1]])


def build_evergarden_codex(root_col, pal):
    col = get_or_create_collection("art_gild_evergarden_codex", root_col)

    # Small faceted lotus seed Handle at origin (marked invisible/Handle)
    sc_h = Sculpt()
    gem_crystal(sc_h, (0, 0, 0), 0.06, 0.06, 0.06, segs=6)
    build_object("Handle", sc_h, col, mat=pal["gold"])

    # Sculpted Arched Spine with 5 Raised Vine Binding Ribs along Z=[-0.68, 0.68]
    sc_sp = Sculpt()
    spine_pts = [V3(0, 0.34, -0.68 + 1.36 * (i / 10)) for i in range(11)]
    ribbon_loft(sc_sp, spine_pts, [0.24] * 11, [0.11] * 11, up_hint=(0, 1, 0), profile="bevel")
    for kz in (-0.54, -0.27, 0.0, 0.27, 0.54):
        rib = cubic_bezier_3d(V3(-0.14, 0.38, kz), V3(0, 0.27, kz), V3(0, 0.27, kz), V3(0.14, 0.38, kz), n=6)
        ribbon_loft(sc_sp, rib, [0.055] * 7, [0.045] * 7, up_hint=(0, 0, 1), profile="oval")
    build_object("Spine", sc_sp, col, mat=pal["gold"])

    # Arched White-Bark Botanical Covers (no flat boxes!)
    for side, cname in [(-1.0, "CoverL"), (1.0, "CoverR")]:
        sc_cv = Sculpt()
        _open_sheet_mesh(sc_cv, 0.06, 0.84, 0.36, 0.08, 0.65, 0.065, side=side, curl_tip=-0.04)
        build_object(cname, sc_cv, col, mat=pal["white_bark"])

    # Raised Gold Corner Filigree & Living Vine Trim along covers
    sc_ft = Sculpt()
    for side in (-1.0, 1.0):
        for ez in (-0.64, 0.64):
            vine = cubic_bezier_3d(
                V3(side * 0.12, 0.36, ez),
                V3(side * 0.45, 0.44, ez * 0.96),
                V3(side * 0.72, 0.44, ez * 0.92),
                V3(side * 0.84, 0.40, ez * 0.78),
                n=8,
            )
            ribbon_loft(sc_ft, vine, [0.045 * (1 - 0.5 * (i / 8)) for i in range(9)], [0.04] * 9, up_hint=(0, 1, 0), profile="bevel")
    build_object("FiligreeTrim", sc_ft, col, mat=pal["gold"])

    # Gently Curved Gull-Wing Vellum Pages
    for side, pname in [(-1.0, "PagesL"), (1.0, "PagesR")]:
        sc_pg = Sculpt()
        _open_sheet_mesh(sc_pg, 0.03, 0.76, 0.43, 0.15, 0.59, 0.11, side=side, curl_tip=-0.02)
        build_object(pname, sc_pg, col, mat=pal["vellum"])

    # Blooming Lotus JadeGem floating above spine gutter
    sc_jg = Sculpt()
    gem_crystal(sc_jg, (0, 0.90, 0), 0.17, 0.24, 0.17, segs=8)
    for k in range(6):
        ang = 2 * math.pi * k / 6
        p0 = V3(0.06 * math.cos(ang), 0.76, 0.06 * math.sin(ang))
        p1 = V3(0.18 * math.cos(ang), 0.82, 0.18 * math.sin(ang))
        p2 = V3(0.24 * math.cos(ang), 0.96, 0.24 * math.sin(ang))
        ribbon_loft(sc_jg, [p0, p1, p2], [0.09, 0.11, 0.02], [0.025, 0.025, 0.01], up_hint=(0, 1, 0), profile="lens")
    build_object("JadeGem", sc_jg, col, mat=pal["jade"], anim_role="JadeGem", pivot_offset=(0, 0.90, 0))

    # S-Curved Flowing BlossomBookmark Silk Ribbon + 5-Petal Sakura Rosette
    sc_bm = Sculpt()
    bm_spine = cubic_bezier_3d(
        V3(0.0, 0.36, 0.58),
        V3(0.08, 0.28, 0.76),
        V3(-0.06, 0.14, 0.90),
        V3(0.04, -0.04, 0.98),
        n=14,
    )
    bm_w = [0.13 + 0.04 * math.sin(math.pi * (i / 14)) for i in range(15)]
    ribbon_loft(sc_bm, bm_spine, bm_w, [0.028] * 15, up_hint=(0, 1, 0), profile="lens", twist_fn=lambda t: 0.45 * math.sin(t * math.pi))
    charm_ctr = V3(0.04, -0.04, 0.98)
    for k in range(5):
        a = 2 * math.pi * k / 5
        ribbon_loft(
            sc_bm,
            [charm_ctr, charm_ctr + V3(0.07 * math.cos(a), -0.02, 0.07 * math.sin(a)), charm_ctr + V3(0.12 * math.cos(a), -0.05, 0.12 * math.sin(a))],
            [0.04, 0.075, 0.02],
            [0.018, 0.018, 0.008],
            up_hint=(0, 1, 0),
            profile="lens",
        )
    build_object("BlossomBookmark", sc_bm, col, mat=pal["blossom"], anim_role="BlossomBookmark", pivot_offset=(0, 0.36, 0.60), double_sided=True)

    # Two Doubly-Curved Billowing Living Leaf-Pages hovering mid-turn
    for side, lpname, y0, arch, curl in [
        (1.0, "LivingPage1", 0.54, 0.28, 0.14),
        (-1.0, "LivingPage2", 0.56, 0.32, 0.18),
    ]:
        sc_lp = Sculpt()
        _open_sheet_mesh(sc_lp, 0.04, 0.62, y0, arch, 0.52, 0.020, side=side, curl_tip=curl)
        build_object(lpname, sc_lp, col, mat=pal["vellum"], anim_role=lpname, pivot_offset=(side * 0.04, y0, 0), double_sided=True)

    return col


# ===========================================================================
# Export (FBX + Manifest + Compact Luau EditableMesh Tables + Dual Renders)
# ===========================================================================

def extract_roblox_part_geometry(obj, root_col):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.verts.ensure_lookup_table()
    # Geometry is in Blender Z-up inside object space -> convert back to Roblox Y-up
    pts = [(v.co.x, v.co.z, -v.co.y) for v in bm.verts]
    xs, ys, zs = [p[0] for p in pts], [p[1] for p in pts], [p[2] for p in pts]
    cx, cy, cz = (min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5

    flat_verts = []
    for px, py, pz in pts:
        flat_verts.extend([round(px - cx, 4), round(py - cy, 4), round(pz - cz, 4)])
    flat_tris = []
    for f in bm.faces:
        if len(f.verts) == 3:
            flat_tris.extend([f.verts[0].index + 1, f.verts[1].index + 1, f.verts[2].index + 1])
    bm.free()

    mat = obj.data.materials[0] if obj.data.materials else None
    sub_col = next((c.name for c in obj.users_collection if c != root_col), "")
    loc_rbx = Vector((cx, cy, cz))
    clean_name = re.sub(r"\.\d+$", "", obj.name)
    return {
        "Name": clean_name,
        "SubCollection": sub_col,
        "Offset": [round(loc_rbx.x, 4), round(loc_rbx.y, 4), round(loc_rbx.z, 4)],
        "RotDeg": [0.0, 0.0, 0.0],
        "Size": [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(max(zs) - min(zs), 4)],
        "Material": mat.get("rbx_material", "Metal") if mat else "Metal",
        "Color": list(mat.get("rbx_color", [245, 185, 66])) if mat else [245, 185, 66],
        "Transparency": float(mat.get("rbx_transparency", 0.0)) if mat else 0.0,
        "AnimRole": obj.get("gild_anim_role", ""),
        "PivotOffset": list(obj.get("gild_pivot_offset", [round(loc_rbx.x, 4), round(loc_rbx.y, 4), round(loc_rbx.z, 4)])),
        "DoubleSided": bool(obj.get("rbx_double_sided", False)),
        "MeshId": "",
        "Verts": flat_verts,
        "Tris": flat_tris,
    }


def load_uploaded_mesh_ids():
    """MeshIds of the parts already uploaded through Studio (see tools/apply_gilded_anvil_mesh_ids.py).
    Re-upload a weapon whenever its geometry changes, or its old MeshIds will no longer match."""
    path = os.path.join(OUT_DIR, "mesh_ids.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def export_weapon(name, col):
    os.makedirs(OUT_DIR, exist_ok=True)
    objs = [o for o in col.all_objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objs:
        obj.select_set(True)
    if objs:
        bpy.context.view_layer.objects.active = objs[0]
    fbx_path = os.path.join(OUT_DIR, f"{name}.fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx_path,
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="EDGE",
        add_leaf_bones=False,
        bake_anim=False,
        use_mesh_modifiers=True,
        bake_space_transform=True,
    )
    parts_full, parts_summary, tri_count = [], [], 0
    uploaded = load_uploaded_mesh_ids().get(name, {})
    for obj in objs:
        pinfo = extract_roblox_part_geometry(obj, col)
        pinfo["MeshId"] = uploaded.get(pinfo["Name"], "")
        tri_count += len(pinfo["Tris"]) // 3
        parts_full.append(pinfo)
        parts_summary.append({k: v for k, v in pinfo.items() if k not in ("Verts", "Tris")})
    return (
        {"TemplateId": name, "FBX": os.path.basename(fbx_path), "Triangles": tri_count, "Parts": parts_summary},
        parts_full,
    )


LUAU_SHARDS_DIR = os.path.join(REPO, "src", "ReplicatedStorage", "Assets", "GildedAnvilMeshes")


def _encode_part_buffers(p):
    verts = p["Verts"]
    tris = p["Tris"]
    sx, sy, sz = p["Size"]
    hx = max(1e-5, sx * 0.5)
    hy = max(1e-5, sy * 0.5)
    hz = max(1e-5, sz * 0.5)
    vbuf = bytearray()
    for i in range(0, len(verts), 3):
        qx = max(-32767, min(32767, round((verts[i] / hx) * 32767.0)))
        qy = max(-32767, min(32767, round((verts[i + 1] / hy) * 32767.0)))
        qz = max(-32767, min(32767, round((verts[i + 2] / hz) * 32767.0)))
        vbuf.extend(struct.pack("<hhh", qx, qy, qz))
    tbuf = bytearray()
    for i in range(0, len(tris), 3):
        tbuf.extend(struct.pack("<HHH", tris[i], tris[i + 1], tris[i + 2]))
    return base64.b64encode(bytes(vbuf)).decode("ascii"), base64.b64encode(bytes(tbuf)).decode("ascii")


def write_luau_mesh_module(all_parts_by_id):
    os.makedirs(LUAU_SHARDS_DIR, exist_ok=True)
    for tid, parts in all_parts_by_id.items():
        shard_path = os.path.join(LUAU_SHARDS_DIR, f"{tid}.luau")
        s_lines = [
            "--!nocheck",
            f"-- ReplicatedStorage/Assets/GildedAnvilMeshes/{tid}.luau",
            "-- Generated directly from Blender FBX geometry (tools/blender/generate_gilded_anvil_weapons.py).",
            "",
            "return {",
        ]
        for p in parts:
            c, o, s, pv = p["Color"], p["Offset"], p["Size"], p["PivotOffset"]
            vb, tb = _encode_part_buffers(p)
            role_lit = f'"{p["AnimRole"]}"' if p["AnimRole"] else "nil"
            ds_lit = "true" if p["DoubleSided"] else "false"
            mesh_lit = f'"{p.get("MeshId", "")}"'
            s_lines.extend([
                "\t{",
                f'\t\tName = "{p["Name"]}", SubCollection = "{p["SubCollection"]}",',
                f"\t\tOffset = Vector3.new({o[0]}, {o[1]}, {o[2]}), RotDeg = Vector3.zero, Size = Vector3.new({s[0]}, {s[1]}, {s[2]}),",
                f"\t\tPivotOffset = Vector3.new({pv[0]}, {pv[1]}, {pv[2]}),",
                f'\t\tMaterial = Enum.Material.{p["Material"]}, Color = Color3.fromRGB({c[0]}, {c[1]}, {c[2]}), Transparency = {p["Transparency"]},',
                f"\t\tAnimRole = {role_lit}, DoubleSided = {ds_lit}, MeshId = {mesh_lit},",
                f'\t\tVB = "{vb}",',
                f'\t\tTB = "{tb}",',
                "\t},",
            ])
        s_lines.append("}")
        with open(shard_path, "w", encoding="utf-8") as f:
            f.write("\n".join(s_lines) + "\n")
        print(f"Wrote Gilded Anvil shard: {shard_path} ({os.path.getsize(shard_path)} bytes)")

    weapon_keys = ",\n".join(f'\t{tid} = unpackWeapon(MeshesFolder:WaitForChild("{tid}"))' for tid in all_parts_by_id.keys())
    loader_src = f"""--!strict
-- ReplicatedStorage/Assets/GildedAnvilMeshData.luau
-- Decodes Blender FBX geometry shards from ReplicatedStorage.Assets.GildedAnvilMeshes.

local GildedAnvilMeshData = {{}}

export type PartMeshSpec = {{
\tName: string,
\tSubCollection: string,
\tOffset: Vector3,
\tRotDeg: Vector3,
\tSize: Vector3,
\tPivotOffset: Vector3,
\tMaterial: Enum.Material,
\tColor: Color3,
\tTransparency: number,
\tAnimRole: string?,
\tDoubleSided: boolean,
\tMeshId: string,
\t-- Packed fallback geometry, decoded on demand by GetGeometry (only needed when MeshId is empty or fails to load).
\tVB: string?,
\tTB: string?,
\tVerts: {{ number }}?,
\tTris: {{ number }}?,
}}

local B64_LOOKUP = table.create(256, -1)
do
\tlocal alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
\tfor i = 1, #alphabet do
\t\tB64_LOOKUP[string.byte(alphabet, i)] = i - 1
\tend
end

local function decodeBase64(b64: string): buffer
\tlocal len = #b64
\tif len == 0 then
\t\treturn buffer.create(0)
\tend
\tlocal pad = 0
\tif string.byte(b64, len) == 61 then
\t\tpad += 1
\t\tif len >= 2 and string.byte(b64, len - 1) == 61 then
\t\t\tpad += 1
\t\tend
\tend
\tlocal outLen = (len // 4) * 3 - pad
\tlocal buf = buffer.create(outLen)
\tlocal outPos = 0
\tfor i = 1, len, 4 do
\t\tlocal c0 = B64_LOOKUP[string.byte(b64, i)]
\t\tlocal c1 = B64_LOOKUP[string.byte(b64, i + 1)]
\t\tlocal b2 = string.byte(b64, i + 2)
\t\tlocal b3 = string.byte(b64, i + 3)
\t\tlocal c2 = if b2 == 61 then 0 else B64_LOOKUP[b2]
\t\tlocal c3 = if b3 == 61 then 0 else B64_LOOKUP[b3]
\t\tlocal bits = bit32.bor(
\t\t\tbit32.lshift(c0, 18),
\t\t\tbit32.lshift(c1, 12),
\t\t\tbit32.lshift(c2, 6),
\t\t\tc3
\t\t)
\t\tif outPos < outLen then
\t\t\tbuffer.writeu8(buf, outPos, bit32.rshift(bits, 16))
\t\t\toutPos += 1
\t\tend
\t\tif outPos < outLen then
\t\t\tbuffer.writeu8(buf, outPos, bit32.band(bit32.rshift(bits, 8), 255))
\t\t\toutPos += 1
\t\tend
\t\tif outPos < outLen then
\t\t\tbuffer.writeu8(buf, outPos, bit32.band(bits, 255))
\t\t\toutPos += 1
\t\tend
\tend
\treturn buf
end

local function unpackVerts(vb: string, size: Vector3): {{ number }}
\tlocal buf = decodeBase64(vb)
\tlocal nBytes = buffer.len(buf)
\tlocal verts = table.create(nBytes // 2)
\tlocal hx = math.max(1e-5, size.X * 0.5) / 32767
\tlocal hy = math.max(1e-5, size.Y * 0.5) / 32767
\tlocal hz = math.max(1e-5, size.Z * 0.5) / 32767
\tfor off = 0, nBytes - 6, 6 do
\t\tverts[#verts + 1] = buffer.readi16(buf, off) * hx
\t\tverts[#verts + 1] = buffer.readi16(buf, off + 2) * hy
\t\tverts[#verts + 1] = buffer.readi16(buf, off + 4) * hz
\tend
\treturn verts
end

local function unpackTris(tb: string): {{ number }}
\tlocal buf = decodeBase64(tb)
\tlocal nBytes = buffer.len(buf)
\tlocal tris = table.create(nBytes // 2)
\tfor off = 0, nBytes - 2, 2 do
\t\ttris[#tris + 1] = buffer.readu16(buf, off)
\tend
\treturn tris
end

local function unpackWeapon(shardModule: Instance): {{ PartMeshSpec }}
\tlocal rawList = require(shardModule :: ModuleScript) :: {{ any }}
\tlocal unpacked = table.create(#rawList)
\tfor _, raw in ipairs(rawList) do
\t\tunpacked[#unpacked + 1] = {{
\t\t\tName = raw.Name,
\t\t\tSubCollection = raw.SubCollection,
\t\t\tOffset = raw.Offset,
\t\t\tRotDeg = raw.RotDeg,
\t\t\tSize = raw.Size,
\t\t\tPivotOffset = raw.PivotOffset,
\t\t\tMaterial = raw.Material,
\t\t\tColor = raw.Color,
\t\t\tTransparency = raw.Transparency,
\t\t\tAnimRole = raw.AnimRole,
\t\t\tDoubleSided = raw.DoubleSided,
\t\t\tMeshId = raw.MeshId or "",
\t\t\tVB = raw.VB,
\t\t\tTB = raw.TB,
\t\t\tVerts = raw.Verts,
\t\t\tTris = raw.Tris,
\t\t}}
\tend
\treturn unpacked
end

-- Returns the part's vertex and triangle lists, decoding the packed shard data the first time.
-- Parts with an uploaded MeshId never need this, so the decode cost is only paid on the fallback path.
function GildedAnvilMeshData.GetGeometry(spec: PartMeshSpec): ({{ number }}, {{ number }})
\tif not spec.Verts then
\t\tspec.Verts = if spec.VB then unpackVerts(spec.VB, spec.Size) else {{}}
\tend
\tif not spec.Tris then
\t\tspec.Tris = if spec.TB then unpackTris(spec.TB) else {{}}
\tend
\treturn spec.Verts :: {{ number }}, spec.Tris :: {{ number }}
end

local MeshesFolder = (script.Parent :: Instance):WaitForChild("GildedAnvilMeshes")

GildedAnvilMeshData.Weapons = {{
{weapon_keys}
}} :: {{ [string]: {{ PartMeshSpec }} }}

return GildedAnvilMeshData
"""
    os.makedirs(os.path.dirname(LUAU_DATA_PATH), exist_ok=True)
    with open(LUAU_DATA_PATH, "w", encoding="utf-8") as f:
        f.write(loader_src)
    print(f"Wrote Luau mesh data loader: {LUAU_DATA_PATH}")


def setup_preview_studio(weapon_cols):
    # Separate objects along X cleanly for contact sheet showcase after FBX export
    configs = [
        (-10.2, 0.32, 1.85, 0.68),   # Dawnwarden + Shield side-by-side
        (-5.3, 0.22, 0.92, 0.22),    # Eclipse Sisters
        (-1.6, -0.78, 0.0, 0.0),     # Aurora Skyhook angled so bow sweep shows clearly
        (2.1, -0.18, 0.0, 0.0),      # Wyrmheart Cleaver
        (6.4, 0.22, 0.0, 0.0),       # Ninth Sky Orrery
        (10.3, 0.32, 0.0, 0.0),      # Evergarden Codex
    ]
    for idx, col in enumerate(weapon_cols):
        dx, yaw, sub_dx, sub_yaw = configs[idx]
        for obj in col.all_objects:
            is_sub = any(c.name in ("OffhandShield", "LeftDagger") for c in obj.users_collection)
            x_off = dx + (sub_dx if is_sub else 0.0)
            z_off = 0.0 if idx == 0 else (0.35 if idx != 3 else -0.25)
            if idx == 5:
                z_off = 0.75
            obj.location = (x_off, 0.0, z_off)
            obj.rotation_euler.z = yaw + (sub_yaw if is_sub else 0.0)
            if idx == 5:  # tilt Evergarden Codex clearly toward viewer
                obj.rotation_euler.x = -0.82

    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = 36
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    cam.location = (0.0, -29.2, 2.3)
    cam.rotation_euler = (Vector((0.0, 0, 1.45)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(cam)
    scene.camera = cam

    # 1) Crisp Workbench Cavity + Outline Studio Preview (matching generate_berserker_greataxes.py!)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.cavity_type = "BOTH"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 2400
    scene.render.resolution_y = 1000
    world = bpy.data.worlds.new("GildedPreviewWorld")
    scene.world = world
    world.color = (0.14, 0.15, 0.19)
    wb_png = os.path.join(OUT_DIR, "gilded_anvil_preview.png")
    scene.render.filepath = wb_png
    bpy.ops.render.render(write_still=True)
    print(f"Rendered Workbench cavity showcase: {wb_png}")

    # 2) EEVEE Material + Emission Preview
    scene.render.engine = (
        "BLENDER_EEVEE_NEXT"
        if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
        else "BLENDER_EEVEE"
    )
    scene.render.resolution_x = 2000
    scene.render.resolution_y = 840
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.04, 0.045, 0.075, 1.0)
        bg.inputs[1].default_value = 1.0
    for lname, loc, energy, color in [
        ("KeyLight", (0, -16, 11), 1600, (1.0, 0.95, 0.86)),
        ("FillLight", (-9, -11, 4), 600, (0.74, 0.86, 1.0)),
        ("RimLight", (6, 9, 10), 900, (1.0, 0.86, 0.56)),
    ]:
        ldata = bpy.data.lights.new(lname, type="AREA")
        ldata.energy = energy
        ldata.color = color
        ldata.size = 9.0
        lobj = bpy.data.objects.new(lname, ldata)
        lobj.location = loc
        lobj.rotation_euler = (Vector((0, 0, 1.2)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(lobj)
    eevee_png = os.path.join(OUT_DIR, "gilded_anvil_eevee_preview.png")
    scene.render.filepath = eevee_png
    bpy.ops.render.render(write_still=True)
    print(f"Rendered EEVEE emission showcase: {eevee_png}")


def main():
    clear_scene()
    root_col = get_or_create_collection("GildedAnvil")
    pal = materials_palette()

    builders = [
        ("art_gild_dawnwarden_oath", build_dawnwarden_oath),
        ("art_gild_eclipse_sisters", build_eclipse_sisters),
        ("art_gild_aurora_skyhook", build_aurora_skyhook),
        ("art_gild_wyrmheart_cleaver", build_wyrmheart_cleaver),
        ("art_gild_ninth_sky_orrery", build_ninth_sky_orrery),
        ("art_gild_evergarden_codex", build_evergarden_codex),
    ]

    weapon_cols, manifest, all_parts = [], {}, {}
    for name, fn in builders:
        col = fn(root_col, pal)
        weapon_cols.append(col)
        summary, full_parts = export_weapon(name, col)
        manifest[name] = summary
        all_parts[name] = full_parts
        print(f"[gilded_anvil] {name:28s} tris={summary['Triangles']:5d} parts={len(summary['Parts'])}")

    manifest_path = os.path.join(OUT_DIR, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    write_luau_mesh_module(all_parts)
    setup_preview_studio(weapon_cols)
    return manifest


if __name__ == "__main__":
    main()
