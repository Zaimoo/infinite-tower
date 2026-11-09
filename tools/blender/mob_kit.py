"""
Tower mob kit (docs/tower-mob-remodel-plan.md): builds on raid_kit's primitives with
  - a per-biome 512x512 atlas (16x16 cells of 32 px). Each palette colour has a GRADIENT cell (dark at the
    bottom, lit at the top) and a FLAT cell. Faces are UV-mapped when painted, so a primitive's height runs
    along its gradient: cheap, stylized ambient occlusion and rim light with no baking (Tier A);
  - family skeletons: the joint names, parents and pivots TowerEnemyClips drives, checked on build;
  - export named for templates: every segment object is named after its joint ("Body", "ArmL", "Leg-1_2"...),
    glow meshes "<Joint>_Glow_<Colour>", Alpha trophies "<Joint>_Trophy_<n>";
  - Tier B (Elites, Alphas, Biome Bosses): bake.py bakes a high-poly copy onto the game mesh.

Coordinates: 1 unit = 1 stud, Z up, enemies FACE +Y in Blender (Roblox -Z). Ground is z = 0.
"""
import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix
import raid_kit as K

ATLAS = 512
GRID = 16
CELL = ATLAS // GRID
INSET = 3  # px kept away from cell edges (mip bleed)

# ------------------------------------------------------------------ family skeletons
BIPED = {
    "Body": None, "Head": "Body",
    "ArmL": "Body", "ArmR": "Body", "ForearmL": "ArmL", "ForearmR": "ArmR",
    "LegL": "Body", "LegR": "Body", "KneeL": "LegL", "KneeR": "LegR",
}
CRAWLER = {"Body": None, "Head": "Body", "JawL": "Head", "JawR": "Head"}
for _s in (-1, 1):
    for _i in (1, 2, 3):
        CRAWLER[f"Leg{_s}_{_i}"] = "Body"
        CRAWLER[f"Knee{_s}_{_i}"] = f"Leg{_s}_{_i}"
SKELETONS = {"BIPED": BIPED, "CRAWLER": CRAWLER, "QUADRUPED": BIPED, "AVIAN": BIPED, "SERPENT": BIPED}


def skeleton_for(family):
    if family in ("CRAWLER", "INSECT", "CRUSTACEAN", "SCORPION", "SIX_LEGGED_CRAWLER"):
        return CRAWLER
    return BIPED  # bipeds, colossi, treant, quadruped/avian/serpent share the 10-joint names


# ------------------------------------------------------------------ atlas
class Atlas:
    """A biome palette. colours: name -> (r, g, b) 0-255. Names ending in '!' are glow-only (no cell)."""

    def __init__(self, biome, colours):
        self.biome = biome
        self.colours = dict(colours)
        self.index = {}
        i = 0
        for name in self.colours:
            self.index[name] = i
            i += 2  # gradient cell, then flat cell
        assert i <= GRID * GRID, "palette too big"
        self.image = None
        self.material = None

    def cell(self, key):
        flat = key.endswith(":flat")
        name = key[:-5] if flat else key
        i = self.index[name] + (1 if flat else 0)
        return i % GRID, i // GRID, flat

    def uv_rect(self, key):
        cx, cy, flat = self.cell(key)
        u0 = (cx * CELL + INSET) / ATLAS
        u1 = ((cx + 1) * CELL - INSET) / ATLAS
        top = 1 - (cy * CELL + INSET) / ATLAS
        bottom = 1 - ((cy + 1) * CELL - INSET) / ATLAS
        return u0, u1, bottom, top, flat

    def build_image(self, path=None):
        img = bpy.data.images.get("atlas_" + self.biome) or bpy.data.images.new("atlas_" + self.biome, ATLAS, ATLAS, alpha=False)
        px = [0.0] * (ATLAS * ATLAS * 4)
        for name, rgb in self.colours.items():
            for flat in (False, True):
                cx, cy, _ = self.cell(name + (":flat" if flat else ""))
                for y in range(CELL):
                    # t = 0 at the cell bottom, 1 at its top
                    t = y / (CELL - 1)
                    if flat:
                        mul, lift = 1.0, 0.0
                    else:
                        # AO at the base, body colour through the middle, a soft lit rim on top
                        mul = 0.52 + 0.48 * min(1.0, t / 0.55) + (0.16 * (t - 0.75) / 0.25 if t > 0.75 else 0)
                        lift = 0.035 * max(0.0, (t - 0.8) / 0.2)
                    r, g, b = (min(1.0, c / 255 * mul + lift) for c in rgb)
                    row = cy * CELL + (CELL - 1 - y)  # image row 0 is the bottom
                    row = ATLAS - 1 - row
                    for x in range(CELL):
                        o = (row * ATLAS + cx * CELL + x) * 4
                        px[o:o + 4] = (r, g, b, 1.0)
        img.pixels[:] = px
        if path:
            img.filepath_raw = path
            img.file_format = "PNG"
            img.save()
        self.image = img
        return img

    def get_material(self):
        if self.material:
            return self.material
        m = bpy.data.materials.new("Atlas_" + self.biome)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = self.image or self.build_image()
        tex.interpolation = "Linear"
        nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.7
        self.material = m
        return m


# ------------------------------------------------------------------ segments
class MobSegment(K.Segment):
    """A rig segment whose palette faces get atlas UVs the moment they are painted."""

    def __init__(self, asset, name, pivot=(0, 0, 0), parent=None):
        super().__init__(asset, name, pivot, parent)
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _paint(self, faces, colour):
        faces = super()._paint(faces, colour)
        if colour.startswith("glow:"):
            return faces
        u0, u1, v0, v1, flat = self.asset.atlas.uv_rect(colour)
        uc = (u0 + u1) / 2
        if flat:
            for f in faces:
                for l in f.loops:
                    l[self.uv].uv = (uc, (v0 + v1) / 2)
            return faces
        zs = [v.co.z for f in faces for v in f.verts]
        lo, hi = min(zs), max(zs)
        span = max(hi - lo, 1e-4)
        for f in faces:
            for l in f.loops:
                t = (l.vert.co.z - lo) / span
                l[self.uv].uv = (uc, v0 + (v1 - v0) * t)
        return faces


class MobAsset:
    def __init__(self, enemy_id, family, atlas, role):
        self.name = enemy_id
        self.family = family
        self.atlas = atlas
        self.role = role
        self.segments = []
        self.objects = []
        self.meta = {"EnemyId": enemy_id, "Family": family, "Role": role, "Biome": atlas.biome, "Segments": []}

    def segment(self, name, pivot=(0, 0, 0), parent=None):
        return MobSegment(self, name, pivot, parent)

    def seg(self, name):
        return next(s for s in self.segments if s.name == name)

    def validate(self):
        skel = skeleton_for(self.family)
        names = {s.name: s for s in self.segments}
        missing = [j for j in skel if j not in names]
        assert not missing, f"{self.name}: missing joints {missing}"
        for s in self.segments:
            if s.name in skel:
                want = skel[s.name]
                got = s.parent.name if s.parent else None
                assert want == got, f"{self.name}: {s.name} parent {got}, clips expect {want}"
            else:
                assert s.name.startswith(("Trophy", "Extra")) and s.parent is not None, f"{self.name}: unknown joint {s.name}"

    # ------------------------------------------------------------ build meshes
    def build(self, collection=None):
        self.validate()
        col = collection or bpy.context.scene.collection
        atlas_mat = self.atlas.get_material()
        for seg in self.segments:
            bm = seg.bm
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            ngons = [f for f in bm.faces if len(f.verts) > 4]
            if ngons:
                bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")
            glow_slots = {i: s.split(":")[1] for i, s in enumerate(seg.slots) if s.startswith("glow:")}
            entry = {"Name": seg.name, "Parent": seg.parent.name if seg.parent else None, "Pivot": K.to_roblox(seg.pivot), "Glow": []}
            body = bm.copy()
            bmesh.ops.delete(body, geom=[f for f in body.faces if f.material_index in glow_slots], context="FACES")
            if len(body.faces):
                obj = self._object(seg.name, body, seg, col, atlas_mat)
                entry.update(K.Asset._bounds(obj))
                entry["Tris"] = sum(len(p.vertices) - 2 for p in obj.data.polygons)
            body.free()
            for gi, colour in glow_slots.items():
                g = bm.copy()
                bmesh.ops.delete(g, geom=[f for f in g.faces if f.material_index != gi], context="FACES")
                if len(g.faces):
                    obj = self._object(f"{seg.name}_Glow_{colour.capitalize()}", g, seg, col, K.glow_material(colour))
                    ge = {"Mesh": obj.name, "Colour": list(K.GLOW[colour]),
                          "Tris": sum(len(p.vertices) - 2 for p in obj.data.polygons)}
                    ge.update(K.Asset._bounds(obj))
                    entry["Glow"].append(ge)
                g.free()
            self.meta["Segments"].append(entry)
        bpy.context.view_layer.update()
        return self.objects

    def _object(self, name, bm, seg, col, mat):
        for f in bm.faces:
            f.material_index = 0
        for v in bm.verts:
            v.co -= seg.pivot
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        me.materials.append(mat)
        for p in me.polygons:
            p.use_smooth = True
        try:
            me.set_sharp_from_angle(angle=math.radians(40))
        except Exception:
            pass
        obj = bpy.data.objects.new(name, me)
        obj.location = seg.pivot
        col.objects.link(obj)
        self.objects.append(obj)
        return obj

    def export(self, out_dir, extra=None):
        os.makedirs(out_dir, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.objects[0]
        fbx = os.path.join(out_dir, f"{self.name}.fbx")
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"}, axis_forward="-Z", axis_up="Y",
                                 apply_unit_scale=True, bake_space_transform=True, mesh_smooth_type="FACE",
                                 path_mode="COPY", embed_textures=True, use_mesh_modifiers=True)
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in self.objects)
        lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
        for o in self.objects:
            for c in o.bound_box:
                w = o.location + Vector(c)
                lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
                hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
        s = hi - lo
        self.meta.update({"TotalTris": tris, "MeshCount": len(self.objects), "Size": [round(s.x, 2), round(s.z, 2), round(s.y, 2)],
                          "FeetY": round(lo.z, 3),
                          "Convention": "Studs, Roblox axes (Y up, faces -Z), origin on the ground under the enemy. Pivot = joint position. "
                                        "Mesh objects are named after their joint."})
        if extra:
            self.meta.update(extra)
        with open(os.path.join(out_dir, f"{self.name}.json"), "w") as fh:
            json.dump(self.meta, fh, indent=1)
        print(f"[mob_kit] {self.name}: {len(self.objects)} meshes, {tris} tris, size {self.meta['Size']}")
        return fbx


# ------------------------------------------------------------------ organic / motif helpers
import random as _random


def leaf(seg, base, tip, width, colour, thickness=0.06, up=(0, 0, 1)):
    """A pointed leaf blade from base to tip (a thin prism, lens-shaped)."""
    base, tip = Vector(base), Vector(tip)
    L = (tip - base).length
    m = K.look_matrix(base, tip, up=up)
    w = width / 2
    poly = [(0, 0), (w * 0.8, L * 0.25), (w, L * 0.5), (w * 0.6, L * 0.8), (0, L), (-w * 0.6, L * 0.8), (-w, L * 0.5), (-w * 0.8, L * 0.25)]
    return seg.prism(poly, thickness, colour, mat=m)


def vine_spiral(seg, centre, radius, z0, z1, turns, colour, thick=0.12, leaves=None, leaf_colour=None, seed=0, phase=0.0, rx=None):
    """A vine winding around a vertical axis at `centre` (x, y), from z0 to z1, with optional leaves."""
    rnd = _random.Random(seed)
    n = max(8, int(turns * 14))
    pts = []
    for i in range(n + 1):
        t = i / n
        a = phase + t * turns * 2 * math.pi
        r = radius * (1 + 0.05 * math.sin(t * 9))
        pts.append(Vector((centre[0] + math.cos(a) * (rx or r), centre[1] + math.sin(a) * r, z0 + (z1 - z0) * t)))
    seg.tube(pts, [thick] * len(pts), colour, sides=6)
    if leaves:
        for k in range(leaves):
            i = rnd.randint(1, n - 1)
            p = pts[i]
            out = (p - Vector((centre[0], centre[1], p.z))).normalized()
            tip = p + out * rnd.uniform(0.35, 0.55) + Vector((0, 0, rnd.uniform(0.05, 0.3)))
            leaf(seg, p, tip, rnd.uniform(0.18, 0.28), leaf_colour or colour)
    return pts


def moss(seg, centre, radius, count, colour, seed=0, flat=0.45, spread=None):
    """A clump of lumpy moss cushions around `centre`."""
    rnd = _random.Random(seed)
    c = Vector(centre)
    sp = spread if spread is not None else radius * 1.4
    for i in range(count):
        off = Vector((rnd.uniform(-sp, sp), rnd.uniform(-sp, sp), rnd.uniform(-0.1, 0.1) * radius))
        r = radius * rnd.uniform(0.55, 1.0)
        seg.ico(r, colour, loc=c + off, scale=(1, 1, flat), subdiv=1, jitter=0.18, seed=seed * 31 + i)


def sun_glyph(seg, centre, normal, radius, ring, glow, rays=8, ring_thick=None):
    """The Verdant motif: a carved sun disc (ring + rays) with a glowing core, facing `normal`."""
    c, n = Vector(centre), Vector(normal).normalized()
    m = K.look_matrix(c, c + n)
    seg.torus(radius, ring_thick or radius * 0.16, ring, mat=m, major=20, minor=6)
    seg.cyl(radius * 0.55, radius * 0.55, radius * 0.2, glow, mat=m, segs=14)
    for k in range(rays):
        a = 2 * math.pi * k / rays
        d = (m.to_3x3() @ Vector((math.cos(a), math.sin(a), 0)))
        seg.spike(c + d * radius * 1.12, c + d * radius * 1.55, radius * 0.13, ring, segs=4)


def column(seg, base, top, radius, colour, flutes=10, capital=None, broken=False, seed=0):
    """A fluted stone column drum from base to top, optional capital block and a broken, jagged top."""
    base, top = Vector(base), Vector(top)
    seg.rod(base, top, radius, colour, segs=flutes * 2)
    m = K.look_matrix(base, top)
    for k in range(flutes):  # flute ridges
        a = 2 * math.pi * k / flutes
        d = m.to_3x3() @ Vector((math.cos(a), math.sin(a), 0))
        seg.rod(base + d * radius * 0.98, top + d * radius * 0.98, radius * 0.09, colour, segs=4)
    if capital:
        seg.box((radius * 2.6, radius * 2.6, radius * 0.6), capital, mat=K.look_matrix(top, top + (top - base)) @ Matrix.Translation((0, 0, radius * 0.3)), bevel=radius * 0.08)
    if broken:
        rnd = _random.Random(seed)
        for k in range(5):
            a = 2 * math.pi * k / 5 + rnd.uniform(-0.3, 0.3)
            d = m.to_3x3() @ Vector((math.cos(a), math.sin(a), 0))
            seg.spike(top + d * radius * 0.5, top + d * radius * 0.55 + (top - base).normalized() * rnd.uniform(0.2, 0.6) * radius, radius * 0.35, colour, segs=4)
