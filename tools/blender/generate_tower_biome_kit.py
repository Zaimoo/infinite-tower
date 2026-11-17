"""
Tower Biome Kit: the sculpted environment meshes for the 50 tower floors (TowerBiomeAssets).

Run inside Blender (Blender MCP or the Text editor):
    exec(open("<repo>/tools/blender/generate_tower_biome_kit.py").read(), {"__file__": "<repo>/tools/blender/generate_tower_biome_kit.py"})

Every template is built at its reference size in studs (1 Blender unit = 1 stud), standing on z = 0, centred on
the origin, front facing -Y (Roblox +Z after the FBX axis conversion). A template is split by colour role:
each role is one mesh object named "<Template>__<ROLE>" (for example "BanyanTree__WOOD"), so the game can tint
and texture it per biome (Shared/Config/TowerBiomeKit.luau holds the palettes). All templates sit on the origin,
so one FBX carries the whole kit and the Studio import script regroups the MeshParts by template name.

Outputs (assets-source/tower/biome_kit/):
    TowerBiomeKit.blend   the generated scene
    TowerBiomeKit.fbx     every template, for one File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/*.png        contact-sheet renders of the kit
"""
import bpy, bmesh, math, os, json, random
from mathutils import Vector, Matrix, noise

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "biome_kit")

# Per-mesh triangle budget. Roblox allows far more, but a floor clones many of these.
DEFAULT_BUDGET = 3500

# Roles that read as organic and get smooth shading; everything else stays faceted (stylised stone).
SMOOTH_ROLES = {"FOLIAGE", "CAP", "STEM", "MOSS", "GLOW", "CORAL"}

TEMPLATES = {}


# ---------------------------------------------------------------------------------------------------------
# Template builder: one bmesh per colour role
# ---------------------------------------------------------------------------------------------------------
class Template:
    def __init__(self, name, budget=None):
        self.name = name
        self.meshes = {}
        self.budget = budget or {}
        self.rng = random.Random(hash(name) & 0xFFFF)

    def bm(self, role):
        if role not in self.meshes:
            self.meshes[role] = bmesh.new()
        return self.meshes[role]


def M(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    t = Matrix.Translation(Vector(loc))
    r = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
    s = Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    return t @ r @ s


def _track(bm):
    """Vertex count before an operation; new geometry is always appended after it."""
    return len(bm.verts)


def _since(bm, before):
    bm.verts.ensure_lookup_table()
    return [bm.verts[i] for i in range(before, len(bm.verts))]


def _edges_of(bm, verts, inner=False):
    """Edges touching verts (inner: both ends in verts), de-duplicated by index (BMesh wrappers do not hash stably)."""
    bm.verts.index_update()
    bm.edges.index_update()
    vs = {v.index for v in verts}
    found = {}
    for v in verts:
        for e in v.link_edges:
            if not inner or (e.verts[0].index in vs and e.verts[1].index in vs):
                found[e.index] = e
    return list(found.values())


def box(bm, size, mat, bevel=0.0, segs=1):
    before = _track(bm)
    m = mat @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    verts = _since(bm, before)
    if bevel > 0:
        edges = _edges_of(bm, verts)
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=segs, affect="EDGES", profile=0.5)
        verts = _since(bm, before)
    return verts


def cone(bm, r1, r2, h, segs, mat, cap=True):
    """Truncated cone along +Z with its base on z = 0 (local)."""
    before = _track(bm)
    m = mat @ Matrix.Translation((0, 0, h / 2))
    bmesh.ops.create_cone(bm, cap_ends=cap, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h, matrix=m)
    return _since(bm, before)


def ico(bm, radius, mat, subdiv=2):
    before = _track(bm)
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius, matrix=mat)
    return _since(bm, before)


def uvsphere(bm, radius, mat, u=16, v=10):
    before = _track(bm)
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=radius, matrix=mat)
    return _since(bm, before)


def lathe(bm, profile, segs, mat, cap_bottom=True, cap_top=True):
    """Revolve a (radius, z) profile around Z."""
    before = _track(bm)
    rings = []
    for (r, z) in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new(mat @ Vector((math.cos(a) * r, math.sin(a) * r, z))))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    if cap_bottom and profile[0][0] > 0.01:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 0.01:
        bm.faces.new(rings[-1])
    return _since(bm, before)


def tube(bm, points, radii, segs, mat=Matrix.Identity(4), cap=True):
    """A tube through points (local) with a radius per point; parallel-transported frames, so no twisting."""
    before = _track(bm)
    pts = [Vector(p) for p in points]
    rings = []
    prev_n = None
    for k, p in enumerate(pts):
        if k == 0:
            t = (pts[1] - pts[0]).normalized()
        elif k == len(pts) - 1:
            t = (pts[k] - pts[k - 1]).normalized()
        else:
            t = (pts[k + 1] - pts[k - 1]).normalized()
        if prev_n is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            n = t.cross(ref).normalized()
        else:
            n = (prev_n - t * prev_n.dot(t)).normalized()
        prev_n = n
        b = t.cross(n).normalized()
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            off = (n * math.cos(a) + b * math.sin(a)) * radii[k]
            ring.append(bm.verts.new(mat @ (p + off)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        tip = bm.verts.new(mat @ (pts[-1] + (pts[-1] - pts[-2]).normalized() * radii[-1] * 0.6))
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((rings[-1][i], rings[-1][j], tip))
    return _since(bm, before)


def branch_path(start, direction, length, steps, wobble, rng, droop=0.0):
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    for i in range(steps):
        d = (d + Vector((rng.uniform(-wobble, wobble), rng.uniform(-wobble, wobble), rng.uniform(-wobble, wobble) - droop))).normalized()
        pts.append(pts[-1] + d * (length / steps))
    return pts


def subdivide(bm, verts, cuts=1):
    """Subdivide the piece made of verts; returns every vertex of the piece afterwards."""
    edges = _edges_of(bm, verts, inner=True)
    before = _track(bm)
    if edges:
        bmesh.ops.subdivide_edges(bm, edges=edges, cuts=cuts, use_grid_fill=True)
    return [v for v in verts if v.is_valid] + _since(bm, before)


def displace(bm, verts, amp, freq, seed=0, octaves=3, axis_scale=(1, 1, 1), up_bias=0.0):
    """Push verts along their normals by fractal noise (stylised rock/organic lumps)."""
    bm.normal_update()
    off = Vector((seed * 17.31, seed * 5.77, seed * 11.13))
    for v in verts:
        if not v.is_valid:
            continue
        p = Vector((v.co.x * axis_scale[0], v.co.y * axis_scale[1], v.co.z * axis_scale[2])) * freq + off
        n = noise.fractal(p, 0.6, 2.0, octaves, noise_basis="PERLIN_ORIGINAL")
        nv = v.normal.copy()
        if up_bias:
            nv.z += up_bias
            nv.normalize()
        v.co += nv * n * amp


def jitter(verts, amp, rng):
    for v in verts:
        if v.is_valid:
            v.co += Vector((rng.uniform(-amp, amp), rng.uniform(-amp, amp), rng.uniform(-amp, amp)))


def rock(bm, size, mat, seed, roughness=0.22, subdiv=3, flat_bottom=True):
    """An icosphere boulder squashed to size, lumped with noise, with a flattened base."""
    verts = ico(bm, 0.5, Matrix.Identity(4), subdiv)
    displace(bm, verts, roughness, 2.2, seed)
    for v in verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        if flat_bottom and v.co.z < -size[2] * 0.3:
            v.co.z = -size[2] * 0.3
        v.co = mat @ (v.co + Vector((0, 0, size[2] * 0.3)))
    return verts


def metaball(name, elements, resolution=0.6, threshold=0.6):
    """elements: (type, co, radius, size_xyz or None, rot_euler or None). Returns an evaluated mesh datablock."""
    mb = bpy.data.metaballs.new(name + "_mb")
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = threshold
    obj = bpy.data.objects.new(name + "_mbobj", mb)
    bpy.context.scene.collection.objects.link(obj)
    for (kind, co, radius, size, rot) in elements:
        el = mb.elements.new(type=kind)
        el.co = co
        el.radius = radius
        if size and kind in ("ELLIPSOID", "CAPSULE", "CUBE", "PLANE"):
            el.size_x, el.size_y, el.size_z = size
        if rot:
            q = Matrix.Rotation(rot[2], 4, "Z") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[0], 4, "X")
            el.rotation = q.to_quaternion()
    dg = bpy.context.evaluated_depsgraph_get()
    dg.update()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
    bpy.data.objects.remove(obj)
    bpy.data.metaballs.remove(mb)
    return mesh


def append_mesh(bm, mesh, mat=Matrix.Identity(4)):
    before = _track(bm)
    vmap = [bm.verts.new(mat @ v.co) for v in mesh.vertices]
    for p in mesh.polygons:
        try:
            bm.faces.new([vmap[i] for i in p.vertices])
        except ValueError:
            pass
    bpy.data.meshes.remove(mesh)
    return _since(bm, before)


def ring_mesh(bm, radius, thickness, segs, mat, tube_segs=6):
    pts = [(math.cos(2 * math.pi * i / segs) * radius, math.sin(2 * math.pi * i / segs) * radius, 0) for i in range(segs + 1)]
    return tube(bm, pts, [thickness] * len(pts), tube_segs, mat, cap=False)


# ---------------------------------------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------------------------------------
def template(name, **budget):
    def deco(fn):
        TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# ---- Cliffs ---------------------------------------------------------------------------------------------
def _column_cliff(t, width, depth, height, seed, peaked=False, flat_top=None):
    """A bunched cluster of faceted rock columns (stylised basalt/limestone cliff) with cover caps.

    flat_top: if set, every column is cut to that height (a crown props can stand on)."""
    rng = random.Random(seed)
    stone, moss = t.bm("STONE"), t.bm("MOSS")
    cols = []
    # Columns on a jittered grid filling the footprint; tallest towards the back (+Y) and the middle.
    nx, ny = max(2, round(width / 9)), max(2, round(depth / 9))
    for i in range(nx):
        for j in range(ny):
            fx = (i + 0.5) / nx - 0.5
            fy = (j + 0.5) / ny - 0.5
            x = fx * width + rng.uniform(-2.0, 2.0)
            y = fy * depth + rng.uniform(-2.0, 2.0)
            centrality = 1 - min(1, abs(fx) * 1.6)
            back = 0.5 + fy
            h = height * (0.45 + 0.35 * centrality + 0.2 * back) * rng.uniform(0.82, 1.05)
            if flat_top is not None:
                h = flat_top if abs(fx) < 0.42 and abs(fy) < 0.42 else flat_top * rng.uniform(0.55, 0.9)
            r = min(width / nx, depth / ny) * rng.uniform(0.62, 0.78)
            cols.append((x, y, h, r))
    if peaked:
        cols.append((rng.uniform(-2, 2), depth * 0.12, height * 1.12, min(width, depth) * 0.22))
    for k, (x, y, h, r) in enumerate(cols):
        sides = rng.choice((5, 6, 6, 7))
        tilt = (rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05), rng.uniform(0, math.pi))
        top_r = r * (0.78 if flat_top is None else 0.95)
        v = cone(stone, r * 1.08, top_r, h, sides, M((x, y, -0.5), rot=tilt))
        v = subdivide(stone, v, 2)
        # Big, slow noise only: keeps facets crisp.
        displace(stone, v, r * 0.22, 0.05, seed * 13 + k, octaves=2, axis_scale=(1, 1, 0.35))
        for vv in v:
            if vv.is_valid and vv.co.z < 0:
                vv.co.z = -0.5
            if flat_top is not None and vv.is_valid and vv.co.z > flat_top - 0.2:
                vv.co.z = min(vv.co.z, flat_top)
        # Chunky shelf / spall boulders at the foot.
        if rng.random() < 0.45:
            rock(stone, (r * 1.1, r * 0.9, r * 0.7), M((x + rng.uniform(-r, r), y - r * 0.9, 0)), seed * 31 + k, roughness=0.3, subdiv=2)
        # Cover cap (moss / snow / ash) on the column top.
        if flat_top is None or h < flat_top - 0.5:
            cap = cone(moss, top_r * 0.98, top_r * 0.55, min(1.6, h * 0.08), sides, M((x, y, h - 0.9), rot=(0, 0, tilt[2])))
            jitter(cap, 0.25, rng)
    if flat_top is not None:
        cap = subdivide(moss, cone(moss, width * 0.44, width * 0.42, 1.4, 16, M((0, 0, flat_top - 0.4))), 1)
        jitter(cap, 0.3, rng)


@template("CliffRockA", STONE=5000, MOSS=1500)
def cliff_a(t):
    """Perimeter cliff block: 40 wide (X), 30 deep (Y), ~80 tall; the front face looks -Y."""
    _column_cliff(t, 40, 30, 80, 3)


@template("CliffRockB", STONE=5000, MOSS=1500)
def cliff_b(t):
    """Peaked crag variant: 38 x 32, a tall needle rising out of the cluster."""
    _column_cliff(t, 38, 32, 66, 11, peaked=True)


@template("ChasmIsland", STONE=4000, MOSS=1200)
def chasm_island(t):
    """A rock pillar with a flat crown at z = 38 that props stand on: 32 x 34 footprint."""
    _column_cliff(t, 32, 34, 38, 21, flat_top=38)


# ---- Masonry --------------------------------------------------------------------------------------------
@template("ArchPierBase", TRIM=1200)
def arch_pier_base(t):
    """Pier plinth: 8 x 8 footprint (studs), 3.5 tall. Code scales X/Z to the pier depth."""
    trim = t.bm("TRIM")
    box(trim, (8.6, 8.6, 1.6), M((0, 0, 0.8)), bevel=0.25)
    box(trim, (7.6, 7.6, 1.9), M((0, 0, 2.55)), bevel=0.3)


@template("ArchPierSegment", TRIM=900, MOSS=300)
def arch_pier_segment(t):
    """Two courses of dressed stone, 6.4 x 6.4 x 4.4; tiled up the pier."""
    rng = t.rng
    trim = t.bm("TRIM")
    for k in range(2):
        z = k * 2.2 + 1.1
        for s in (-1, 1):
            # Two staggered blocks per course, slightly irregular.
            off = 0.0 if k == 0 else 0.6
            v = box(trim, (3.15, 6.4, 2.12), M((s * 1.6 + off * s * 0.1, rng.uniform(-0.12, 0.12), z), rot=(0, 0, rng.uniform(-0.02, 0.02))), bevel=0.22)
            jitter(v, 0.06, rng)
    rock(t.bm("MOSS"), (2.2, 1.0, 1.0), M((1.8, -3.0, 3.6)), 4, roughness=0.3, subdiv=2)


@template("ArchCrown", TRIM=2600, ACCENT=300, MOSS=900)
def arch_crown(t):
    """Capitals, voussoirs and keystone for a 24-stud span (pier centres at x = +-12), depth 6.5, springing at z = 0."""
    rng = t.rng
    trim, accent = t.bm("TRIM"), t.bm("ACCENT")
    span, depth = 24.0, 6.5
    r_in, r_out = span / 2 - 3.0, span / 2 + 3.4
    for s in (-1, 1):
        box(trim, (8.0, depth * 1.3, 1.8), M((s * span / 2, 0, 0.9)), bevel=0.3)
    n = 13
    for i in range(n):
        a0 = math.pi * i / n
        a1 = math.pi * (i + 1) / n
        gap = 0.05
        a0 += gap * 0.5 / n
        a1 -= gap * 0.5 / n
        pts = []
        for (a, r) in ((a0, r_in), (a1, r_in), (a1, r_out), (a0, r_out)):
            pts.append((math.cos(a) * r, math.sin(a) * r + 1.8))
        bmt = accent if i == n // 2 else trim
        before = _track(bmt)
        fv = [bmt.verts.new((x, -depth / 2, z)) for (x, z) in pts]
        bv = [bmt.verts.new((x, depth / 2, z)) for (x, z) in pts]
        bmt.faces.new(fv)
        bmt.faces.new(list(reversed(bv)))
        for k in range(4):
            j = (k + 1) % 4
            bmt.faces.new((fv[k], bv[k], bv[j], fv[j]))
        if i == n // 2:
            # Keystone juts out a little.
            for v in _since(bmt, before):
                v.co.y *= 1.18
                v.co.z += 0.5 if v.co.z > r_out else 0
        else:
            jitter(_since(bmt, before), 0.08, rng)
    # Moss/snow drapes on the extrados.
    moss = t.bm("MOSS")
    for i in range(5):
        a = math.pi * (0.2 + 0.6 * i / 4) + rng.uniform(-0.06, 0.06)
        r = r_out + 0.2
        rock(moss, (3.6, depth * 0.9, 1.4), M((math.cos(a) * r, 0, math.sin(a) * r + 1.4), rot=(0, -(a - math.pi / 2), 0)), 50 + i, roughness=0.3, subdiv=2)


@template("Obelisk", TRIM=1500, GLOW=400, GOLD=300)
def obelisk(t):
    """Carved spire: widthBase 10, shaft height 40 (code spire(height=40, widthBase=10))."""
    trim, glow, gold = t.bm("TRIM"), t.bm("GLOW"), t.bm("GOLD")
    wb, h = 10.0, 40.0
    box(trim, (wb * 1.6, wb * 1.6, 2.2), M((0, 0, 1.1)), bevel=0.3)
    box(trim, (wb * 1.38, wb * 1.38, 3.0), M((0, 0, 3.7)), bevel=0.35)
    # Tapered shaft as a frustum (4 sides).
    shaft = cone(trim, wb * 0.70, wb * 0.52, h, 4, M((0, 0, 5.2), rot=(0, 0, math.pi / 4)))
    box(trim, (wb * 0.92, wb * 0.92, 1.6), M((0, 0, 5.2 + h * 0.62)), bevel=0.2)
    box(trim, (wb * 0.86, wb * 0.86, 1.4), M((0, 0, 5.2 + h + 0.7)), bevel=0.2)
    cone(gold, wb * 0.58, 0.05, h * 0.26, 4, M((0, 0, 5.2 + h + 1.4), rot=(0, 0, math.pi / 4)))
    # Rune channels on each face: stacked glyph bars.
    for face in range(4):
        a = face * math.pi / 2
        for k in range(7):
            z = 9 + k * 4.0
            frac = (z - 5.2) / h
            half = (wb * 0.70 + (wb * 0.52 - wb * 0.70) * frac) * math.cos(math.pi / 4)
            wbar = 1.6 if k % 2 == 0 else 2.6
            box(glow, (wbar, 0.25, 1.1), M((math.cos(a) * 0 - math.sin(a) * 0, 0, 0)) @ M(rot=(0, 0, a)) @ M((0, -half - 0.05, z)))
        box(glow, (0.45, 0.25, h * 0.5), M(rot=(0, 0, a)) @ M((0, -(wb * 0.6) * math.cos(math.pi / 4) - 0.05, 5.2 + h * 0.3)))


@template("CrystalSpire", CRYSTAL=1600, STONE=1500)
def crystal_spire(t):
    """Cluster of hexagonal crystals on a rock base: height ~50, base width ~14."""
    rng = t.rng
    cry, stone = t.bm("CRYSTAL"), t.bm("STONE")
    rock(stone, (16, 14, 6), M(), 8, roughness=0.25)
    specs = [(0, 0, 0, 0, 5.0, 42), (4, 2, 0.32, 0.6, 3.0, 26), (-4, 1.5, -0.3, 2.2, 3.2, 30), (1.5, -4, 0.25, 4.0, 2.4, 20), (-2, -3.5, -0.38, 5.2, 2.0, 16), (3.5, -1.5, 0.45, 1.4, 1.6, 12)]
    for (x, y, tilt, yaw, r, h) in specs:
        mat = M((x, y, 2.5), rot=(tilt, 0, yaw))
        shaft = cone(cry, r, r * 0.88, h * 0.78, 6, mat)
        cone(cry, r * 0.88, 0.05, h * 0.22, 6, mat @ M((0, 0, h * 0.78)))


# ---- Trees ----------------------------------------------------------------------------------------------
def _canopy_blob(bm, centre, size, seed, subdiv=2):
    v = ico(bm, 0.5, Matrix.Identity(4), subdiv)
    displace(bm, v, 0.2, 2.6, seed)
    for x in v:
        x.co = Vector((x.co.x * size[0], x.co.y * size[1], x.co.z * size[2])) + Vector(centre)
    return v


@template("BanyanTree", WOOD=4500, FOLIAGE=4500)
def banyan(t):
    """Ancient ruin tree: trunk 40 tall leaning, buttress roots, five boughs, layered canopy (~64 tall, ~80 wide)."""
    rng = t.rng
    wood, leaf = t.bm("WOOD"), t.bm("FOLIAGE")
    top = Vector((-4.5, 2.0, 40))
    trunk = [Vector((0, 0, -1))]
    for k in range(1, 7):
        f = k / 6
        trunk.append(Vector((top.x * f + rng.uniform(-0.8, 0.8), top.y * f + rng.uniform(-0.8, 0.8), top.z * f)))
    tube(wood, trunk, [5.6, 4.9, 4.5, 4.2, 4.0, 3.8, 3.5], 10)
    for k in range(6):
        a = k * 2 * math.pi / 6 + 0.3
        p0 = Vector((math.cos(a) * 2.5, math.sin(a) * 2.5, 9))
        p1 = Vector((math.cos(a) * 9, math.sin(a) * 9, 3))
        p2 = Vector((math.cos(a) * 17, math.sin(a) * 17, -0.6))
        tube(wood, [p0, (p0 + p1) / 2 + Vector((0, 0, 1.5)), p1, p2], [2.4, 2.0, 1.6, 0.9], 7)
    ends = []
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.3
        d = Vector((math.cos(a), math.sin(a), 0.55))
        path = branch_path(top - Vector((0, 0, 5)), d, 26, 4, 0.18, rng)
        tube(wood, path, [2.3, 1.9, 1.5, 1.1, 0.7], 7)
        ends.append(path[-1])
        # Hanging aerial roots.
        if k % 2 == 0:
            p = path[2]
            tube(wood, [p, p + Vector((0.4, 0.2, -10)), p + Vector((0.6, 0.6, -22))], [0.45, 0.35, 0.25], 5)
    for k, e in enumerate(ends):
        _canopy_blob(leaf, e + Vector((0, 0, 3)), (30, 28, 13), 40 + k)
        _canopy_blob(leaf, e + Vector((rng.uniform(-6, 6), rng.uniform(-6, 6), 8)), (18, 17, 9), 60 + k, subdiv=1)
    _canopy_blob(leaf, top + Vector((0, 0, 15)), (44, 42, 16), 77)
    _canopy_blob(leaf, top + Vector((3, -2, 22)), (26, 24, 10), 78)


@template("BlightTree", WOOD=4200, GLOW=900, FOLIAGE=1500)
def blight_tree(t):
    """Twisted corrupted tree with glowing bark fissures and sparse wisp canopy (~60 tall)."""
    rng = t.rng
    wood, glow, leaf = t.bm("WOOD"), t.bm("GLOW"), t.bm("FOLIAGE")
    trunk = []
    for k in range(9):
        f = k / 8
        trunk.append(Vector((math.sin(f * 4.2) * 3.5 - 3 * f, math.cos(f * 3.1) * 2.5, f * 42 - 1)))
    radii = [5.8 - 3.2 * (k / 8) for k in range(9)]
    tube(wood, trunk, radii, 9)
    for k in range(4):
        a = k * math.pi / 2 + 0.6
        off = Vector((math.cos(a), math.sin(a), 0))
        pts = [trunk[k] + off * (radii[k] * 0.98) for k in range(1, 7)]
        tube(glow, pts, [0.42] * len(pts), 4)
    for k in range(5):
        a = k * 2 * math.pi / 5
        p0 = Vector((math.cos(a) * 2.5, math.sin(a) * 2.5, 7))
        tube(wood, [p0, Vector((math.cos(a) * 10, math.sin(a) * 10, 2.5)), Vector((math.cos(a) * 15, math.sin(a) * 15, -0.6))], [2.3, 1.4, 0.7], 6)
    for k in range(7):
        a = k * 2 * math.pi / 7 + rng.uniform(-0.2, 0.2)
        start = trunk[5 + (k % 3)]
        path = branch_path(start, (math.cos(a), math.sin(a), 0.35), 22, 5, 0.32, rng)
        tube(wood, path, [1.8, 1.4, 1.0, 0.7, 0.45, 0.2], 6)
        # Thorny twigs.
        for j in (2, 4):
            twig = branch_path(path[j], (math.cos(a + 0.9), math.sin(a + 0.9), 0.6), 6, 2, 0.3, rng)
            tube(wood, twig, [0.45, 0.3, 0.1], 4)
        if k % 2 == 0:
            _canopy_blob(leaf, path[-1] + Vector((0, 0, 1.5)), (14, 13, 6), 90 + k, subdiv=1)


@template("DeadTree", WOOD=3500)
def dead_tree(t):
    """Bare, sun-bleached tree with splayed branches (~34 tall)."""
    rng = t.rng
    wood = t.bm("WOOD")
    trunk = [Vector((0, 0, -0.8)), Vector((0.6, 0.3, 8)), Vector((-0.5, 0.8, 16)), Vector((0.8, 0.2, 24))]
    tube(wood, trunk, [3.6, 2.8, 2.2, 1.6], 8)
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        tube(wood, [Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, 4)), Vector((math.cos(a) * 6, math.sin(a) * 6, 1.2)), Vector((math.cos(a) * 9, math.sin(a) * 9, -0.6))], [1.5, 0.9, 0.4], 5)
    for k in range(6):
        a = k * 2 * math.pi / 6 + rng.uniform(-0.3, 0.3)
        start = trunk[1 + k % 3]
        path = branch_path(start, (math.cos(a), math.sin(a), 0.8), 14, 4, 0.3, rng)
        tube(wood, path, [1.2, 0.9, 0.6, 0.35, 0.15], 5)
        for j in (2,):
            twig = branch_path(path[j], (math.cos(a - 0.8), math.sin(a - 0.8), 0.9), 5, 2, 0.3, rng)
            tube(wood, twig, [0.35, 0.2, 0.08], 4)


@template("PineTree", WOOD=800, FOLIAGE=3200, MOSS=1600)
def pine_tree(t):
    """Conifer with five jagged tiers and a cover cap on each tier (snow / pale needles), ~46 tall."""
    rng = t.rng
    wood, leaf, moss = t.bm("WOOD"), t.bm("FOLIAGE"), t.bm("MOSS")
    tube(wood, [Vector((0, 0, -0.8)), Vector((0, 0, 20)), Vector((0, 0, 40))], [2.2, 1.6, 0.8], 8)
    tiers = [(9, 13.5, 12), (17, 11.5, 11), (24, 9.2, 10), (31, 6.8, 9), (37, 4.6, 9)]
    for i, (z, r, h) in enumerate(tiers):
        v = subdivide(leaf, cone(leaf, r, 0.4, h, 12, M((0, 0, z - 2), rot=(0, 0, i * 0.5))), 1)
        # Jagged skirt: push the bottom ring in and out.
        for x in v:
            if x.is_valid and x.co.z < z - 1.5:
                ang = math.atan2(x.co.y, x.co.x)
                x.co.x *= 1 + 0.16 * math.sin(ang * 6 + i)
                x.co.y *= 1 + 0.16 * math.sin(ang * 6 + i)
                x.co.z -= 0.9 * (0.5 + 0.5 * math.cos(ang * 6 + i))
        displace(leaf, v, 0.5, 0.4, 200 + i)
        cap = cone(moss, r * 0.62, 0.3, h * 0.55, 10, M((0, 0, z - 2 + h * 0.48), rot=(0, 0, i * 0.5 + 0.3)))
        displace(moss, cap, 0.3, 0.6, 300 + i)


# ---- Mushrooms ------------------------------------------------------------------------------------------
def _mushroom(t, at, s, seed, tendrils=True, spots=True):
    stem, cap, glow = t.bm("STEM"), t.bm("CAP"), t.bm("GLOW")
    rng = random.Random(seed)
    stem_h, cap_r = 30 * s, 24 * s
    bend = Vector((4 * s, 0, 0))
    base = Vector(at)
    pts = [base + Vector((0, 0, -0.5 * s)), base + Vector((0.4, 0, stem_h * 0.33)) + bend * 0.25, base + Vector((0, 0, stem_h * 0.66)) + bend * 0.6, base + Vector((0, 0, stem_h)) + bend]
    tube(stem, pts, [6.2 * s, 4.4 * s, 3.8 * s, 3.4 * s], 10)
    top = pts[-1]
    # Skirt ring partway up the stem.
    lathe(glow, [(3.7 * s, 0), (5.0 * s, -1.0 * s), (4.6 * s, -1.6 * s), (3.6 * s, -0.8 * s)], 14, M(top - Vector((0, 0, stem_h * 0.32)) + Vector((-bend.x * 0.35, 0, 0))), cap_bottom=False, cap_top=False)
    # Cap: lathe dome with a curled lip.
    prof = [(0.01, cap_r * 0.62), (cap_r * 0.35, cap_r * 0.58), (cap_r * 0.65, cap_r * 0.46), (cap_r * 0.88, cap_r * 0.28), (cap_r * 1.0, cap_r * 0.10), (cap_r * 0.98, 0.0), (cap_r * 0.90, -0.6 * s)]
    v = lathe(cap, prof, 24, M(top), cap_bottom=False, cap_top=False)
    displace(cap, v, 0.9 * s, 0.12 / max(s, 0.3), seed)
    # Glowing gill disc underneath.
    lathe(glow, [(cap_r * 0.9, -0.5 * s), (cap_r * 0.55, -0.1 * s), (cap_r * 0.2, 0.3 * s), (0.01, 0.4 * s)], 24, M(top), cap_bottom=False, cap_top=False)
    if spots:
        for k in range(9):
            a = k * 2 * math.pi / 9 + rng.uniform(-0.2, 0.2)
            rr = cap_r * rng.uniform(0.35, 0.75)
            prof_z = cap_r * (0.58 - 0.5 * (rr / cap_r) ** 2)
            ico(glow, 1.0, M(top + Vector((math.cos(a) * rr, math.sin(a) * rr, prof_z + 0.1 * s)), scale=(1.7 * s, 1.7 * s, 0.45 * s)), 1)
    if tendrils:
        for k in range(8):
            a = k * math.pi / 4
            p0 = top + Vector((math.cos(a) * cap_r * 0.74, math.sin(a) * cap_r * 0.74, -0.6 * s))
            ln = (7 + (k % 3) * 4) * s
            tube(glow, [p0, p0 + Vector((0.2, 0, -ln * 0.5)), p0 + Vector((0.3, 0.2, -ln))], [0.35 * s, 0.3 * s, 0.25 * s], 4, cap=False)
            ico(glow, 0.9 * s, M(p0 + Vector((0.3, 0.2, -ln - 0.4 * s))), 1)


@template("GiantMushroom", STEM=2500, CAP=3000, GLOW=2500)
def giant_mushroom(t):
    _mushroom(t, (0, 0, 0), 1.0, 5)


@template("MushroomCluster", STEM=900, CAP=1200, GLOW=800, MOSS=500)
def mushroom_cluster(t):
    """Three small mushrooms on a mound (~6 studs across)."""
    for (x, y, s, seed) in ((0, 0, 0.17, 1), (2.4, 1.5, 0.12, 2), (-2.0, -1.3, 0.085, 3)):
        _mushroom(t, (x, y, 0), s, seed, tendrils=False, spots=s > 0.1)
    rock(t.bm("MOSS"), (5.4, 4.6, 1.6), M((0, 0, -0.4)), 9, roughness=0.2, subdiv=2)


# ---- Statues --------------------------------------------------------------------------------------------
def _plinth(t, w, accent=True):
    trim = t.bm("TRIM")
    box(trim, (w, w, 4), M((0, 0, 2)), bevel=0.4)
    box(t.bm("ACCENT") if accent else trim, (w * 0.82, w * 0.82, 4), M((0, 0, 6)), bevel=0.35)


def _bounds(verts):
    xs = [v.co.x for v in verts]
    ys = [v.co.y for v in verts]
    zs = [v.co.z for v in verts]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


@template("LionGuardian", TRIM=4500, ACCENT=2500, GLOW=200)
def lion(t):
    """Seated stone lion on a two-tier plinth, facing -Y (Roblox +Z); ~34 tall."""
    _plinth(t, 22)
    trim = t.bm("TRIM")
    els = [
        ("ELLIPSOID", (0, 3.5, 15.5), 8.5, (1.0, 1.2, 0.95), None),  # haunch
        ("ELLIPSOID", (0, -2.0, 19.5), 7.5, (0.95, 0.95, 1.3), (0.3, 0, 0)),  # chest
        ("CAPSULE", (4.2, -6.2, 13.5), 3.2, (2.6, 1, 1), (0, math.pi / 2, 0)),  # forelegs
        ("CAPSULE", (-4.2, -6.2, 13.5), 3.2, (2.6, 1, 1), (0, math.pi / 2, 0)),
        ("ELLIPSOID", (4.4, -8.2, 9.6), 3.4, (1.0, 1.4, 0.6), None),  # paws
        ("ELLIPSOID", (-4.4, -8.2, 9.6), 3.4, (1.0, 1.4, 0.6), None),
        ("ELLIPSOID", (6.4, 4.5, 11.5), 5.2, (0.75, 1.3, 0.85), None),  # hind legs
        ("ELLIPSOID", (-6.4, 4.5, 11.5), 5.2, (0.75, 1.3, 0.85), None),
        ("CAPSULE", (0, 11, 10.5), 1.8, (3.5, 1, 1), (0, 0.3, math.pi / 2)),  # tail
    ]
    append_mesh(trim, metaball("lion", els, resolution=0.5, threshold=0.4))
    head = append_mesh(trim, metaball("lionhead", [
        ("ELLIPSOID", (0, -6.0, 27.5), 5.6, (1.0, 1.05, 0.95), None),
        ("ELLIPSOID", (0, -10.0, 26.2), 3.2, (1.0, 1.0, 0.8), None),  # snout
    ], resolution=0.4, threshold=0.4))
    lo, hi = _bounds(head)
    mane = metaball("mane", [
        ("ELLIPSOID", (0, -3.8, 27.0), 8.2, (1.05, 0.8, 1.1), None),
        ("ELLIPSOID", (0, -3.0, 21.5), 6.8, (1.0, 0.7, 1.0), None),
    ], resolution=0.55, threshold=0.4)
    v = append_mesh(t.bm("ACCENT"), mane)
    displace(t.bm("ACCENT"), v, 0.7, 0.18, 7, octaves=2)
    # Eyes sit on the face: two thirds of the way up the head, just inside its front.
    eye_z = lo.z + (hi.z - lo.z) * 0.68
    for sgn in (-1, 1):
        ico(t.bm("GLOW"), 0.8, M((sgn * 2.3, lo.y + 5.0, eye_z)), 1)


def _robed(t, weapon):
    _plinth(t, 20)
    trim, gold, glow = t.bm("TRIM"), t.bm("GOLD"), t.bm("GLOW")
    lathe(trim, [(7.6, 8), (7.0, 12), (6.0, 18), (5.2, 24), (5.4, 30), (6.8, 36), (7.6, 38.5), (3.0, 39.5), (2.3, 41)], 18, M())
    v = [x for x in trim.verts if x.co.z > 8.5 and x.co.z < 38]
    displace(trim, v, 0.5, 0.35, 12)
    append_mesh(trim, metaball("robe", [
        ("CAPSULE", (8.5, -2.2, 32), 2.4, (3.4, 1, 1), (0, math.pi / 2 - 0.25, 0)),  # right arm (holds weapon)
        ("CAPSULE", (-7.6, -1.2, 31), 2.4, (3.2, 1, 1), (0, math.pi / 2 + 0.35, 0)),  # left arm
        ("ELLIPSOID", (0, 0.6, 37.5), 8.0, (1.15, 0.75, 0.5), None),  # shoulders
        ("ELLIPSOID", (0, 0, 33), 6.0, (1.0, 0.75, 1.0), None),  # chest
        ("CAPSULE", (0, 0, 40.5), 2.4, (1.2, 1, 1), (0, math.pi / 2, 0)),  # neck
    ], resolution=0.45, threshold=0.4))
    head = append_mesh(trim, metaball("head", [("ELLIPSOID", (0, 0, 44.5), 5.0, (0.95, 1.0, 1.15), None)], resolution=0.35, threshold=0.4))
    lo, hi = _bounds(head)
    top = hi.z
    lathe(gold, [(3.4, top - 2.0), (3.8, top - 0.8), (3.3, top + 1.2), (2.8, top + 0.2), (2.3, top + 2.0), (1.8, top + 0.4), (0.01, top + 0.4)], 16, M(), cap_bottom=False)
    eye_z = lo.z + (hi.z - lo.z) * 0.58
    for sgn in (-1, 1):
        ico(glow, 0.5, M((sgn * 1.5, lo.y + 0.55, eye_z)), 1)
    tube(gold, [Vector((11, -3.5, 6)), Vector((11, -3.5, 30)), Vector((11, -3.5, 56))], [0.9, 0.9, 0.8], 8)
    if weapon == "trident":
        for dx in (-3.2, 0, 3.2):
            tube(glow, [Vector((11 + dx * 0.8, -3.5, 55)), Vector((11 + dx, -3.5, 59)), Vector((11 + dx, -3.5, 64))], [0.6, 0.55, 0.3], 6)
        tube(gold, [Vector((7.6, -3.5, 55)), Vector((14.4, -3.5, 55))], [0.7, 0.7], 6, cap=False)
        append_mesh(trim, metaball("beard", [("ELLIPSOID", (0, lo.y + 1.2, lo.z + 1.0), 3.4, (1.0, 0.6, 1.3), None)], resolution=0.4, threshold=0.4))
    else:
        ico(glow, 3.0, M((11, -3.5, 59)), 2)
        ring_mesh(gold, 3.7, 0.35, 18, M((11, -3.5, 59), rot=(math.pi / 2, 0, 0)))


@template("RobedStatueStaff", TRIM=5000, GOLD=1500, GLOW=600)
def robed_staff(t):
    _robed(t, "staff")


@template("RobedStatueTrident", TRIM=5000, GOLD=1500, GLOW=700)
def robed_trident(t):
    _robed(t, "trident")


# ---- Biome landmarks ------------------------------------------------------------------------------------
@template("FurnaceStack", STONE=1800, METAL=2200, GLOW=800)
def furnace_stack(t):
    """Foundry chimney: brick base, iron-banded stack, glowing vents and ember lip; widthBase 13, height ~60."""
    stone, metal, glow = t.bm("STONE"), t.bm("METAL"), t.bm("GLOW")
    box(stone, (20, 20, 6), M((0, 0, 3)), bevel=0.6)
    box(stone, (17, 17, 6), M((0, 0, 9)), bevel=0.5)
    lathe(metal, [(7.4, 12), (6.8, 22), (6.0, 34), (5.6, 46), (6.6, 50), (7.6, 53), (7.0, 54), (5.0, 53)], 16, M(), cap_bottom=True, cap_top=True)
    for z in (16, 26, 36, 46):
        r = 7.4 - (z - 12) * 0.05
        lathe(metal, [(r + 0.6, z - 0.9), (r + 0.75, z), (r + 0.6, z + 0.9)], 16, M(), cap_bottom=False, cap_top=False)
    for k in range(4):
        a = k * math.pi / 2
        box(glow, (3.0, 1.0, 4.5), M((math.cos(a) * 8.6, math.sin(a) * 8.6, 9), rot=(0, 0, a + math.pi / 2)))
        for z in (20, 30, 40):
            box(glow, (1.2, 0.8, 3.0), M((math.cos(a + 0.78) * (6.9 - (z - 12) * 0.05), math.sin(a + 0.78) * (6.9 - (z - 12) * 0.05), z), rot=(0, 0, a + 0.78 + math.pi / 2)))
    lathe(glow, [(5.0, 53.2), (4.0, 54.2), (2.0, 54.6), (0.01, 54.7)], 16, M(), cap_bottom=False)


@template("ObsidianSpire", STONE=3000, GLOW=900)
def obsidian_spire(t):
    """Jagged obsidian shard cluster with violet veins: ~60 tall, base ~14."""
    rng = t.rng
    stone, glow = t.bm("STONE"), t.bm("GLOW")
    rock(stone, (18, 16, 5), M(), 13, roughness=0.3)
    specs = [(0, 0, 0, 0, 6.5, 58), (4.5, 2.5, 0.28, 1.0, 3.6, 30), (-4.8, 1.0, -0.3, 2.5, 3.8, 34), (1.0, -4.6, 0.3, 4.1, 3.0, 22), (-2.4, -3.8, -0.35, 5.4, 2.4, 16)]
    for i, (x, y, tilt, yaw, r, h) in enumerate(specs):
        mat = M((x, y, 2), rot=(tilt, 0, yaw))
        v = subdivide(stone, cone(stone, r, 0.05, h, 5, mat), 2)
        displace(stone, v, r * 0.18, 0.35, 70 + i)
        if i < 3:
            pts = [mat @ Vector((r * 0.62, 0, h * f)) for f in (0.05, 0.3, 0.55, 0.78)]
            tube(glow, pts, [0.5, 0.42, 0.3, 0.12], 4)


# ---- Clutter --------------------------------------------------------------------------------------------
@template("BoulderCluster", STONE=1500)
def boulders(t):
    stone = t.bm("STONE")
    rock(stone, (5.4, 4.8, 3.8), M(), 1)
    rock(stone, (3.8, 3.2, 2.6), M((3.2, 1.8, 0)), 2)
    rock(stone, (2.8, 2.6, 2.0), M((-2.8, -2.0, 0)), 3)


@template("RuinRubble", TRIM=1200, MOSS=500)
def ruin_rubble(t):
    rng = t.rng
    trim = t.bm("TRIM")
    v = box(trim, (4.5, 3.8, 2.8), M((0, 0, 1.4), rot=(0.05, 0.08, 0.2)), bevel=0.3)
    jitter(v, 0.15, rng)
    v = box(trim, (3.2, 2.8, 2.2), M((2.8, 1.6, 1.0), rot=(0.25, 0, 0.6)), bevel=0.25)
    jitter(v, 0.12, rng)
    # Fallen fluted column drum.
    cone(trim, 2.2, 2.2, 3.6, 16, M((-2.6, -1.4, 2.2), rot=(math.pi / 2, 0, 0.5)))
    rock(t.bm("MOSS"), (3.4, 3.0, 1.0), M((0.2, 0.1, 2.6)), 5, roughness=0.3, subdiv=2)


@template("FoliageBush", FOLIAGE=1800, STONE=400, ALT=300)
def foliage_bush(t):
    rng = t.rng
    leaf = t.bm("FOLIAGE")
    _canopy_blob(leaf, (0, 0, 2.2), (7.2, 6.8, 4.6), 1)
    _canopy_blob(leaf, (2.3, 1.2, 1.8), (5.0, 5.0, 3.8), 2)
    _canopy_blob(leaf, (-1.9, -1.8, 1.5), (4.6, 4.4, 3.2), 3)
    rock(t.bm("STONE"), (3.0, 2.6, 1.4), M((0.6, -2.8, 0)), 4, subdiv=2)
    for k in range(7):
        a = k * 2 * math.pi / 7 + rng.uniform(-0.3, 0.3)
        r = rng.uniform(1.5, 3.2)
        ico(t.bm("ALT"), 0.42, M((math.cos(a) * r, math.sin(a) * r, 3.6 + rng.uniform(-0.6, 1.1))), 1)


@template("StoneUrn", TRIM=1200, ACCENT=400, FOLIAGE=900)
def stone_urn(t):
    lathe(t.bm("TRIM"), [(2.2, 0), (2.2, 0.9), (1.4, 1.2), (1.6, 1.8), (2.2, 2.6), (2.25, 3.6), (1.9, 4.5), (1.5, 4.8)], 16, M())
    lathe(t.bm("ACCENT"), [(1.5, 4.7), (2.6, 4.9), (2.7, 5.5), (1.6, 5.4)], 16, M(), cap_bottom=False, cap_top=False)
    _canopy_blob(t.bm("FOLIAGE"), (0, 0, 5.8), (4.2, 4.0, 2.4), 6, subdiv=2)
    for k in range(3):
        a = k * 2.2 + 0.5
        _canopy_blob(t.bm("FOLIAGE"), (math.cos(a) * 1.9, math.sin(a) * 1.9, 5.0), (1.8, 1.8, 1.6), 30 + k, subdiv=1)


@template("IceCluster", CRYSTAL=900, MOSS=600)
def ice_cluster(t):
    cry = t.bm("CRYSTAL")
    for (x, y, tilt, yaw, r, h) in ((0, 0, 0.05, 0, 1.2, 7.5), (2.0, 1.2, 0.35, 1.0, 0.9, 5.6), (-1.6, -1.0, -0.3, 2.4, 0.7, 4.2), (0.8, -1.8, 0.4, 4.0, 0.55, 3.0)):
        mat = M((x, y, 0.2), rot=(tilt, 0, yaw))
        cone(cry, r, r * 0.9, h * 0.75, 6, mat)
        cone(cry, r * 0.9, 0.05, h * 0.25, 6, mat @ M((0, 0, h * 0.75)))
    rock(t.bm("MOSS"), (6.6, 5.6, 1.8), M((0, 0, -0.5)), 3, roughness=0.15, subdiv=2)


@template("ForgeScrap", METAL=1200, GOLD=200, STONE=500)
def forge_scrap(t):
    metal = t.bm("METAL")
    box(metal, (4.2, 2.2, 1.6), M((0, 0, 0.8), rot=(0, 0, 0.2)), bevel=0.2)
    box(t.bm("GOLD"), (3.6, 2.0, 1.4), M((0.8, 0.4, 2.3), rot=(0, 0, -0.3)), bevel=0.2)
    rock(t.bm("STONE"), (5.5, 4.8, 2.4), M((-2.6, 1.2, 0)), 4, roughness=0.3, subdiv=2)
    gear = M((2.4, -1.8, 1.4), rot=(1.2, 0.3, 0.4))
    ring_mesh(metal, 2.2, 0.45, 16, gear)
    for k in range(8):
        a = k * math.pi / 4
        box(metal, (0.8, 0.9, 0.9), gear @ M((math.cos(a) * 2.75, math.sin(a) * 2.75, 0), rot=(0, 0, a)))


@template("Cairn", TRIM=900, FOLIAGE=900)
def cairn(t):
    rng = t.rng
    trim = t.bm("TRIM")
    z = 0
    for k, (rx, rz) in enumerate(((2.9, 1.5), (2.2, 1.3), (1.5, 1.1), (0.9, 0.9))):
        rock(trim, (rx * 2, rx * 1.8, rz), M((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), z - rz * 0.3), rot=(0, 0, rng.uniform(0, 3))), 10 + k, roughness=0.15, subdiv=2)
        z += rz * 0.92
    for k in range(3):
        a = k * 2.1 + 0.4
        _canopy_blob(t.bm("FOLIAGE"), (math.cos(a) * 3.0, math.sin(a) * 3.0, 0.7), (3.6, 3.4, 1.9), 20 + k, subdiv=1)


@template("BlightPod", CAP=900, GLOW=400, WOOD=900, STONE=400)
def blight_pod(t):
    rng = t.rng
    v = ico(t.bm("CAP"), 1.0, M((0, 0, 1.8), scale=(1.8, 1.8, 1.4)), 2)
    displace(t.bm("CAP"), v, 0.18, 1.6, 3)
    ico(t.bm("GLOW"), 0.95, M((0, -0.85, 2.0)), 2)
    for k in range(5):
        a = k * 2 * math.pi / 5
        path = branch_path((math.cos(a) * 1.4, math.sin(a) * 1.4, 0.3), (math.cos(a), math.sin(a), 0.9), 5, 3, 0.35, rng)
        tube(t.bm("WOOD"), path, [0.38, 0.3, 0.2, 0.06], 4)
    rock(t.bm("STONE"), (4.8, 4.2, 1.6), M((1.4, -1.2, -0.3)), 8, roughness=0.3, subdiv=2)


@template("CoralCluster", CORAL=1800, GLOW=500, STONE=600)
def coral_cluster(t):
    rng = t.rng
    coral = t.bm("CORAL")
    for k in range(5):
        a = k * 2 * math.pi / 5 + 0.2
        path = branch_path((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.4), (math.cos(a) * 0.5, math.sin(a) * 0.5, 1.0), 6.0, 4, 0.25, rng)
        tube(coral, path, [0.75, 0.6, 0.5, 0.42, 0.3], 6)
        ico(t.bm("GLOW"), 0.6, M(path[-1]), 1)
        side = branch_path(path[2], (math.cos(a + 1), math.sin(a + 1), 0.8), 2.6, 2, 0.3, rng)
        tube(coral, side, [0.4, 0.3, 0.2], 5)
        ico(t.bm("GLOW"), 0.4, M(side[-1]), 1)
    rock(t.bm("STONE"), (6.0, 5.2, 2.4), M((0, 0, -0.5)), 6, roughness=0.25, subdiv=2)


@template("TomeStack", ALT=600, ACCENT=300, GOLD=300, TRIM=300)
def tome_stack(t):
    for (role, size, z, rot) in (("ALT", (3.6, 2.8, 1.1), 0.55, 0.1), ("ACCENT", (3.2, 2.5, 1.0), 1.6, -0.15), ("GOLD", (2.8, 2.2, 0.9), 2.55, 0.3), ("ALT", (2.6, 2.0, 0.8), 3.4, -0.4)):
        box(t.bm(role), size, M((0, 0, z), rot=(0, 0, rot)), bevel=0.12)
    v = cone(t.bm("TRIM"), 0.8, 0.8, 3.2, 12, M((2.6, 1.3, 0.8), rot=(math.pi / 2, 0, 0.6)))


@template("VoidShards", STONE=1100, GLOW=300, TRIM=300)
def void_shards(t):
    box(t.bm("TRIM"), (4.6, 4.6, 1.2), M((0, 0, 0.6)), bevel=0.2)
    for i, (x, y, tilt, yaw, r, h) in enumerate(((0, 0, 0.08, 0, 1.1, 7.0), (1.8, 1.2, 0.35, 1.2, 0.8, 5.0), (-1.5, 0.9, -0.3, 2.6, 0.7, 4.0), (0.4, -1.6, 0.3, 4.4, 0.6, 3.2))):
        v = cone(t.bm("STONE"), r, 0.04, h, 5, M((x, y, 1.1), rot=(tilt, 0, yaw)))
        displace(t.bm("STONE"), v, r * 0.15, 1.2, i)
    ico(t.bm("GLOW"), 0.85, M((0, 0, 4.4)), 2)


# ---------------------------------------------------------------------------------------------------------
# Build, decimate, export
# ---------------------------------------------------------------------------------------------------------
def reset_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


ROLE_PREVIEW = {
    "STONE": (0.32, 0.33, 0.30), "TRIM": (0.52, 0.53, 0.46), "ACCENT": (0.34, 0.56, 0.28), "MOSS": (0.30, 0.48, 0.20),
    "GLOW": (1.0, 0.85, 0.45), "WOOD": (0.32, 0.24, 0.16), "FOLIAGE": (0.18, 0.42, 0.20), "METAL": (0.24, 0.22, 0.24),
    "GOLD": (0.85, 0.68, 0.30), "CRYSTAL": (0.55, 0.82, 0.98), "CAP": (0.30, 0.20, 0.66), "STEM": (0.66, 0.64, 0.74),
    "ALT": (0.85, 0.40, 0.45), "CORAL": (0.92, 0.55, 0.45),
}


def role_material(role):
    name = "Kit_" + role
    mat = bpy.data.materials.get(name)
    if mat:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    c = ROLE_PREVIEW.get(role, (0.6, 0.6, 0.6))
    bsdf.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1)
    bsdf.inputs["Roughness"].default_value = 0.8
    if role == "GLOW":
        bsdf.inputs["Emission Color"].default_value = (c[0], c[1], c[2], 1)
        bsdf.inputs["Emission Strength"].default_value = 3.0
    mat.diffuse_color = (c[0], c[1], c[2], 1)
    return mat


def finalize(name, role, bm, budget, coll):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(f"{name}__{role}")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(f"{name}__{role}", mesh)
    coll.objects.link(obj)
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    if tris > budget:
        mod = obj.modifiers.new("Decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = budget / tris
        mod.use_collapse_triangulate = True
        dg = bpy.context.evaluated_depsgraph_get()
        dg.update()
        new = bpy.data.meshes.new_from_object(obj.evaluated_get(dg))
        obj.modifiers.remove(mod)
        old = obj.data
        obj.data = new
        bpy.data.meshes.remove(old)
        new.name = f"{name}__{role}"
    smooth = role in SMOOTH_ROLES
    for p in obj.data.polygons:
        p.use_smooth = smooth
    obj.data.materials.append(role_material(role))
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return obj, tris


def build_all(only=None):
    reset_scene()
    kit = bpy.data.collections.new("TowerBiomeKit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in TEMPLATES.items():
        if only and name not in only:
            continue
        coll = bpy.data.collections.new(name)
        kit.children.link(coll)
        t = Template(name)
        fn(t)
        roles = {}
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for role, bm in t.meshes.items():
            if len(bm.verts) == 0:
                bm.free()
                continue
            obj, tris = finalize(name, role, bm, budget.get(role, DEFAULT_BUDGET), coll)
            for v in obj.data.vertices:
                lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
                hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
            roles[role] = tris
        manifest[name] = {
            "Roles": roles,
            "Triangles": sum(roles.values()),
            # Roblox axes (X, Y up, Z): Blender (x, z, y).
            "Size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
            "Min": [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)],
        }
    return kit, manifest


def export(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "TowerBiomeKit.fbx"),
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        use_mesh_modifiers=True,
        bake_space_transform=True,
        object_types={"MESH"},
    )
    with open(os.path.join(OUT_DIR, "manifest.json"), "w") as f:
        json.dump({"Templates": manifest, "Unit": "studs", "Front": "-Y in Blender, +Z in Roblox"}, f, indent=2, sort_keys=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "TowerBiomeKit.blend"))


def render_previews(kit, out_dir, names=None, tile=520, cols=5):
    """One turntable-angle render per template, tiled into contact sheets (previews/kit_sheet_N.png)."""
    import numpy as np
    scene = bpy.context.scene
    tiles = os.path.join(out_dir, "tiles")
    os.makedirs(tiles, exist_ok=True)
    stage = bpy.data.collections.new("PreviewStage")
    scene.collection.children.link(stage)
    lc = next(c for c in bpy.context.view_layer.layer_collection.children if c.collection == kit)
    lc.exclude = True
    sd = bpy.data.lights.new("PreviewSun", "SUN")
    sd.energy = 3.5
    sun = bpy.data.objects.new("PreviewSun", sd)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    stage.objects.link(sun)
    bpy.ops.mesh.primitive_plane_add(size=2000)
    ground = bpy.context.active_object
    for c in ground.users_collection:
        c.objects.unlink(ground)
    stage.objects.link(ground)
    gm = bpy.data.materials.new("PreviewGround")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.18, 0.18, 0.2, 1)
    ground.data.materials.append(gm)
    if not scene.world:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.5, 0.55, 0.62, 1)
    bg.inputs[1].default_value = 0.8
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    stage.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = tile
    names = names or [c.name for c in kit.children]
    for n in names:
        c = bpy.data.collections[n]
        lo = Vector((1e9,) * 3)
        hi = Vector((-1e9,) * 3)
        for o in c.objects:
            for v in o.data.vertices:
                lo = Vector(map(min, lo, v.co))
                hi = Vector(map(max, hi, v.co))
        e = bpy.data.objects.new("PreviewInstance", None)
        e.instance_type = "COLLECTION"
        e.instance_collection = c
        stage.objects.link(e)
        size = max(hi - lo)
        ctr = (lo + hi) / 2
        cam.location = ctr + Vector((0.55, -1.0, 0.45)).normalized() * size * 1.9
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(tiles, n + ".png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(e)
    # Contact sheets of 15.
    for sheet_i in range(0, len(names), 15):
        sel = names[sheet_i:sheet_i + 15]
        rows = (len(sel) + cols - 1) // cols
        canvas = np.ones((rows * tile, cols * tile, 4), dtype=np.float32)
        for i, n in enumerate(sel):
            img = bpy.data.images.load(os.path.join(tiles, n + ".png"), check_existing=False)
            px = np.array(img.pixels[:], dtype=np.float32).reshape(tile, tile, 4)
            r, cidx = i // cols, i % cols
            canvas[(rows - 1 - r) * tile:(rows - r) * tile, cidx * tile:(cidx + 1) * tile] = px
            bpy.data.images.remove(img)
        im = bpy.data.images.new("KitSheet", cols * tile, rows * tile, alpha=True)
        im.pixels = canvas.ravel()
        im.filepath_raw = os.path.join(out_dir, f"kit_sheet_{sheet_i // 15 + 1}.png")
        im.file_format = "PNG"
        im.save()
        bpy.data.images.remove(im)
    for o in list(stage.objects):
        bpy.data.objects.remove(o)
    bpy.data.collections.remove(stage)
    lc.exclude = False


if __name__ == "__main__" or globals().get("RUN_KIT", True):
    _kit, _manifest = build_all(globals().get("ONLY"))
    if globals().get("EXPORT", True):
        export(_kit, _manifest)
    if globals().get("PREVIEWS", False):
        render_previews(_kit, globals().get("PREVIEW_DIR", os.path.join(OUT_DIR, "previews")), globals().get("PREVIEW_NAMES"))
    result = {"templates": len(_manifest), "manifest": _manifest}
