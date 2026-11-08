"""
Raid asset kit: tiny procedural modelling helpers for the raid portal and raid bosses.

Conventions (match the hair pipeline, docs/hero-art-pipeline.md 4.4):
  - 1 Blender unit = 1 stud. Z up. Assets FACE +Y in Blender, which exports to Roblox -Z (LookVector)
    with axis_forward='-Z', axis_up='Y'. Roblox point = (x, z, -y).
  - Every asset is a set of Segments. A Segment is one rigid piece (a limb, or a portal role).
    Its non-glow faces are UV-collapsed onto a shared palette texture (raid_palette.png, 8x8 swatches)
    so each Segment becomes ONE textured MeshPart. Glow faces become separate "<Seg>_Glow_<Colour>"
    meshes, one per glow colour, for Neon MeshParts tinted in code.
"""
import bpy, bmesh, math, json, os, random
from mathutils import Vector, Matrix, Euler

# ---------------------------------------------------------------- palette
PALETTE = [
    # name, (r, g, b) 0-255. Order is the swatch index: never reorder, only append.
    ("obsidian", (22, 20, 28)), ("stone_dark", (40, 38, 48)), ("stone_mid", (64, 60, 74)), ("stone_light", (96, 92, 106)),
    ("bone", (214, 200, 170)), ("bone_dark", (150, 134, 108)), ("gold", (222, 180, 86)), ("gold_dark", (150, 108, 48)),
    ("iron_dark", (34, 34, 40)), ("iron", (70, 70, 80)), ("iron_light", (124, 124, 136)), ("crimson", (140, 22, 32)),
    ("crimson_dark", (78, 10, 18)), ("cloth_red", (112, 16, 26)), ("leather", (66, 42, 30)), ("black", (12, 12, 14)),
    ("flesh_purple", (96, 52, 108)), ("flesh_dark", (52, 26, 64)), ("flesh_pink", (176, 96, 128)), ("eye_white", (232, 226, 214)),
    ("chitin_black", (26, 26, 24)), ("chitin_green", (38, 58, 36)), ("chitin_mid", (66, 84, 54)), ("bone_green", (184, 192, 152)),
    ("rock_blue", (58, 66, 80)), ("rock_dark", (34, 40, 52)), ("rock_light", (92, 102, 116)), ("crystal_deep", (36, 104, 136)),
    ("teal_dark", (24, 84, 88)), ("purple_dark", (42, 22, 62)), ("white", (236, 236, 236)), ("rust", (110, 56, 34)),
    ("moss", (58, 80, 40)), ("stone_warm", (84, 70, 64)), ("violet", (88, 50, 140)), ("tooth", (240, 232, 200)),
]
PAL_INDEX = {n: i for i, (n, _) in enumerate(PALETTE)}
GRID = 8  # 8 x 8 swatches
TEX = 256

GLOW = {
    "crimson": (255, 46, 58), "violet": (186, 96, 255), "teal": (60, 255, 214), "green": (126, 255, 74),
    "cyan": (84, 226, 255), "gold": (255, 202, 96), "orange": (255, 118, 36), "white": (255, 244, 230),
}


def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def swatch_uv(name):
    i = PAL_INDEX[name]
    cx, cy = i % GRID, i // GRID
    return ((cx + 0.5) / GRID, 1.0 - (cy + 0.5) / GRID)


def make_palette_image(path=None):
    img = bpy.data.images.get("raid_palette") or bpy.data.images.new("raid_palette", TEX, TEX, alpha=False)
    px = [0.0] * (TEX * TEX * 4)
    cell = TEX // GRID
    for i, (_, rgb) in enumerate(PALETTE):
        cx, cy = i % GRID, i // GRID
        for y in range(cell):
            row = TEX - 1 - (cy * cell + y)  # image rows start at the bottom
            for x in range(cell):
                o = (row * TEX + cx * cell + x) * 4
                px[o:o + 4] = [rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1.0]
    img.pixels[:] = px
    if path:
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
    return img


_mats = {}


def palette_material():
    if "pal" in _mats:
        return _mats["pal"]
    m = bpy.data.materials.new("RaidPalette")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = make_palette_image()
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.62
    _mats["pal"] = m
    return m


def glow_material(colour):
    key = "glow_" + colour
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new("Glow_" + colour)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    rgb = GLOW[colour]
    lin = (srgb_to_lin(rgb[0]), srgb_to_lin(rgb[1]), srgb_to_lin(rgb[2]), 1.0)
    bsdf.inputs["Base Color"].default_value = lin
    bsdf.inputs["Emission Color"].default_value = lin
    bsdf.inputs["Emission Strength"].default_value = 6.0
    _mats[key] = m
    return m


# ---------------------------------------------------------------- transforms
def V(x, y=None, z=None):
    if y is None:
        return Vector(x)
    return Vector((x, y, z))


def M(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    """Matrix from location, Euler XYZ degrees, and scale."""
    r = Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
    s = Matrix.Diagonal(Vector((*scale, 1.0)))
    return Matrix.Translation(Vector(loc)) @ r @ s


def look_matrix(origin, target, up=(0, 0, 1)):
    """Matrix whose local +Z points from origin to target."""
    z = (Vector(target) - Vector(origin)).normalized()
    upv = Vector(up)
    if abs(z.dot(upv)) > 0.98:
        upv = Vector((0, 1, 0)) if abs(z.y) < 0.9 else Vector((1, 0, 0))
    x = upv.cross(z).normalized()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


# ---------------------------------------------------------------- segments
class Segment:
    def __init__(self, asset, name, pivot=(0, 0, 0), parent=None):
        self.asset = asset
        self.name = name
        self.pivot = Vector(pivot)
        self.parent = parent
        self.bm = bmesh.new()
        self.slots = []  # material keys: palette names or "glow:<colour>"
        asset.segments.append(self)

    def _slot(self, colour):
        if colour not in self.slots:
            self.slots.append(colour)
        return self.slots.index(colour)

    def _paint(self, faces, colour):
        idx = self._slot(colour)
        for f in faces:
            f.material_index = idx
        return faces

    @staticmethod
    def _faces_of(verts):
        out = set()
        for v in verts:
            out.update(v.link_faces)
        return list(out)

    # -- primitives -------------------------------------------------------
    def box(self, size, colour, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0, mat=None):
        m = (mat if mat is not None else M(loc, rot)) @ Matrix.Diagonal(Vector((*size, 1.0)))
        verts = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)["verts"]
        faces = self._faces_of(verts)
        if bevel > 0:
            edges = list({e for f in faces for e in f.edges})
            res = bmesh.ops.bevel(self.bm, geom=edges + list(verts), offset=bevel, segments=1, affect="EDGES", profile=0.5, clamp_overlap=True)
            faces = list(set(faces) | set(res.get("faces", [])))
            faces = [f for f in faces if f.is_valid]
            faces = self._faces_of(list({v for f in faces for v in f.verts}))
        return self._paint(faces, colour)

    def sphere(self, radius, colour, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), segs=16, rings=10, mat=None):
        m = (mat if mat is not None else M(loc, rot, scale))
        verts = bmesh.ops.create_uvsphere(self.bm, u_segments=segs, v_segments=rings, radius=radius, matrix=m)["verts"]
        return self._paint(self._faces_of(verts), colour)

    def ico(self, radius, colour, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), subdiv=1, jitter=0.0, seed=0, mat=None):
        m = (mat if mat is not None else M(loc, rot, scale))
        verts = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=radius, matrix=Matrix())["verts"]
        rnd = random.Random(seed)
        for v in verts:
            if jitter:
                v.co *= 1.0 + rnd.uniform(-jitter, jitter)
            v.co = m @ v.co
        return self._paint(self._faces_of(verts), colour)

    def cyl(self, r1, r2, depth, colour, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), segs=12, mat=None):
        """Cone/cylinder along local Z, centred on loc."""
        m = (mat if mat is not None else M(loc, rot, scale))
        verts = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r1, radius2=max(r2, 0.0), depth=depth, matrix=m)["verts"]
        return self._paint(self._faces_of(verts), colour)

    def spike(self, base, tip, radius, colour, segs=6):
        """Cone from base point to tip point."""
        base, tip = Vector(base), Vector(tip)
        length = (tip - base).length
        m = look_matrix(base, tip) @ Matrix.Translation(Vector((0, 0, length / 2)))
        return self.cyl(radius, 0.0, length, colour, mat=m, segs=segs)

    def rod(self, a, b, radius, colour, segs=8, r2=None):
        a, b = Vector(a), Vector(b)
        length = (b - a).length
        m = look_matrix(a, b) @ Matrix.Translation(Vector((0, 0, length / 2)))
        return self.cyl(radius, radius if r2 is None else r2, length, colour, mat=m, segs=segs)

    def crystal(self, base, tip, radius, colour, sides=6, shaft=0.72):
        """Hexagonal crystal: prism shaft then pointed cap."""
        base, tip = Vector(base), Vector(tip)
        mid = base.lerp(tip, shaft)
        f = self.rod(base, mid, radius, colour, segs=sides, r2=radius * 1.06)
        f += self.spike(mid, tip, radius * 1.06, colour, segs=sides)
        return f

    def torus(self, R, r, colour, mat=None, loc=(0, 0, 0), rot=(0, 0, 0), major=32, minor=8, scale_minor=(1, 1)):
        m = mat if mat is not None else M(loc, rot)
        bm = self.bm
        rings = []
        for i in range(major):
            a = 2 * math.pi * i / major
            c, s = math.cos(a), math.sin(a)
            ring = []
            for j in range(minor):
                b = 2 * math.pi * j / minor
                rr = R + r * scale_minor[0] * math.cos(b)
                p = Vector((rr * c, rr * s, r * scale_minor[1] * math.sin(b)))
                ring.append(bm.verts.new(m @ p))
            rings.append(ring)
        faces = []
        for i in range(major):
            for j in range(minor):
                a, b2 = rings[i][j], rings[i][(j + 1) % minor]
                c2, d = rings[(i + 1) % major][(j + 1) % minor], rings[(i + 1) % major][j]
                faces.append(bm.faces.new((a, b2, c2, d)))
        return self._paint(faces, colour)

    def tube(self, pts, radii, colour, sides=8, rect=False, roll=0.0, up=(0, 0, 1)):
        """Sweep a ring along pts. radii: number, or (rx, ry) per point. rect=True -> rectangular section.
        A radius of 0 at an end becomes a point (tapered tip)."""
        bm = self.bm
        pts = [Vector(p) for p in pts]
        n = len(pts)
        if not isinstance(radii, (list, tuple)) or (len(radii) == 2 and n != 2 and not isinstance(radii[0], (list, tuple))):
            radii = [radii] * n
        rings = []
        prev = None
        for i, p in enumerate(pts):
            if i == 0:
                t = pts[1] - pts[0]
            elif i == n - 1:
                t = pts[-1] - pts[-2]
            else:
                t = (pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()
            t.normalize()
            if prev is None:
                u = Vector(up)
                if abs(t.dot(u)) > 0.95:
                    u = Vector((1, 0, 0)) if abs(t.x) < 0.9 else Vector((0, 1, 0))
                nrm = t.cross(u).normalized()
            else:
                nrm = (prev - t * prev.dot(t))
                nrm = nrm.normalized() if nrm.length > 1e-6 else prev
            prev = nrm
            bnm = t.cross(nrm).normalized()
            r = radii[i]
            rx, ry = (r, r) if not isinstance(r, (list, tuple)) else r
            if rx <= 1e-6 and ry <= 1e-6:
                rings.append([bm.verts.new(p)])
                continue
            ring = []
            if rect:
                corners = [(1, 1), (-1, 1), (-1, -1), (1, -1)]
                for cx, cy in corners:
                    ring.append(bm.verts.new(p + nrm * cx * rx + bnm * cy * ry))
            else:
                for k in range(sides):
                    a = 2 * math.pi * k / sides + roll
                    ring.append(bm.verts.new(p + nrm * math.cos(a) * rx + bnm * math.sin(a) * ry))
            rings.append(ring)
        faces = []
        for i in range(n - 1):
            A, B = rings[i], rings[i + 1]
            if len(A) == 1 and len(B) == 1:
                continue
            if len(A) == 1:
                for k in range(len(B)):
                    faces.append(bm.faces.new((A[0], B[(k + 1) % len(B)], B[k])))
            elif len(B) == 1:
                for k in range(len(A)):
                    faces.append(bm.faces.new((A[k], A[(k + 1) % len(A)], B[0])))
            else:
                m = len(A)
                for k in range(m):
                    faces.append(bm.faces.new((A[k], A[(k + 1) % m], B[(k + 1) % m], B[k])))
        if len(rings[0]) > 2:
            faces.append(bm.faces.new(list(reversed(rings[0]))))
        if len(rings[-1]) > 2:
            faces.append(bm.faces.new(rings[-1]))
        return self._paint(faces, colour)

    def prism(self, poly, depth, colour, mat=None, loc=(0, 0, 0), rot=(0, 0, 0)):
        """Extrude a 2D polygon given in local (x, z) along local Y, centred. Concave is fine."""
        m = mat if mat is not None else M(loc, rot)
        bm = self.bm
        front = [bm.verts.new(m @ Vector((x, depth / 2, z))) for x, z in poly]
        back = [bm.verts.new(m @ Vector((x, -depth / 2, z))) for x, z in poly]
        faces = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
        n = len(poly)
        for i in range(n):
            j = (i + 1) % n
            faces.append(bm.faces.new((front[j], front[i], back[i], back[j])))
        return self._paint(faces, colour)

    def mirror_x(self, fn):
        """Run fn(sign) for sign in (+1, -1)."""
        for s in (1, -1):
            fn(s)


class Asset:
    def __init__(self, name):
        self.name = name
        self.segments = []
        self.objects = []
        self.meta = {"Asset": name, "Segments": []}

    def segment(self, name, pivot=(0, 0, 0), parent=None):
        return Segment(self, name, pivot, parent)

    # ------------------------------------------------------------ build meshes
    def build(self, collection=None):
        col = collection or bpy.context.scene.collection
        pal = palette_material()
        for seg in self.segments:
            bm = seg.bm
            bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            ngons = [f for f in bm.faces if len(f.verts) > 4]
            if ngons:
                bmesh.ops.triangulate(bm, faces=ngons, quad_method="BEAUTY", ngon_method="BEAUTY")
            glow_slots = {i: s.split(":")[1] for i, s in enumerate(seg.slots) if s.startswith("glow:")}
            entry = {"Name": seg.name, "Parent": seg.parent.name if seg.parent else None,
                     "Pivot": to_roblox(seg.pivot), "Glow": []}
            # textured body
            body = bm.copy()
            bmesh.ops.delete(body, geom=[f for f in body.faces if f.material_index in glow_slots], context="FACES")
            if len(body.faces):
                obj = self._make_object(f"{self.name}_{seg.name}", body, seg, col, pal, palette=True)
                entry.update(self._bounds(obj))
                entry["Mesh"] = obj.name
                entry["Tris"] = sum(len(p.vertices) - 2 for p in obj.data.polygons)
            has_body = len(body.faces) > 0
            body.free()
            for gi, colour in glow_slots.items():
                g = bm.copy()
                bmesh.ops.delete(g, geom=[f for f in g.faces if f.material_index != gi], context="FACES")
                if len(g.faces):
                    gname = f"{self.name}_{seg.name}" if (not has_body and len(glow_slots) == 1) else f"{self.name}_{seg.name}_Glow_{colour.capitalize()}"
                    obj = self._make_object(gname, g, seg, col, glow_material(colour), palette=False)
                    ge = {"Mesh": obj.name, "Colour": list(GLOW[colour])}
                    ge.update(self._bounds(obj))
                    entry["Glow"].append(ge)
                g.free()
            self.meta["Segments"].append(entry)
        bpy.context.view_layer.update()
        return self.objects

    def _make_object(self, name, bm, seg, col, mat, palette):
        if palette:
            uv = bm.loops.layers.uv.new("UVMap")
            for f in bm.faces:
                key = seg.slots[f.material_index]
                u = swatch_uv(key)
                for l in f.loops:
                    l[uv].uv = u
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
            me.set_sharp_from_angle(angle=math.radians(38))
        except Exception:
            pass
        obj = bpy.data.objects.new(name, me)
        obj.location = seg.pivot
        col.objects.link(obj)
        self.objects.append(obj)
        return obj

    @staticmethod
    def _bounds(obj):
        # Objects are only translated (never rotated or scaled), and matrix_world is stale until the
        # depsgraph updates, so offset the local box by the location directly.
        ws = [obj.location + Vector(c) for c in obj.bound_box]
        lo = Vector((min(v.x for v in ws), min(v.y for v in ws), min(v.z for v in ws)))
        hi = Vector((max(v.x for v in ws), max(v.y for v in ws), max(v.z for v in ws)))
        c = (lo + hi) / 2
        s = hi - lo
        return {"Centre": to_roblox(c), "Size": [round(s.x, 3), round(s.z, 3), round(s.y, 3)]}

    # ------------------------------------------------------------ export
    def export(self, out_dir, extra_meta=None):
        os.makedirs(out_dir, exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        for o in self.objects:
            o.select_set(True)
        bpy.context.view_layer.objects.active = self.objects[0]
        fbx = os.path.join(out_dir, f"{self.name}.fbx")
        bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={"MESH"},
                                 axis_forward="-Z", axis_up="Y", apply_unit_scale=True, bake_space_transform=True,
                                 mesh_smooth_type="FACE", path_mode="COPY", embed_textures=True, use_mesh_modifiers=True)
        tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in self.objects)
        self.meta["TotalTris"] = tris
        self.meta["MeshCount"] = len(self.objects)
        lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
        for o in self.objects:
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
                hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
        s = hi - lo
        self.meta["Size"] = [round(s.x, 2), round(s.z, 2), round(s.y, 2)]
        self.meta["Convention"] = "Studs. Roblox axes (Y up, model faces -Z). Pivot = joint in model space, origin at ground centre. Centre/Size = mesh bounding box (Roblox importer recentres meshes on it)."
        if extra_meta:
            self.meta.update(extra_meta)
        with open(os.path.join(out_dir, f"{self.name}.json"), "w") as fh:
            json.dump(self.meta, fh, indent=1)
        print(f"[raid_kit] exported {fbx}: {len(self.objects)} meshes, {tris} tris, size {self.meta['Size']}")
        return fbx


def to_roblox(v):
    return [round(v.x, 3), round(v.z, 3), round(-v.y, 3)]


# ---------------------------------------------------------------- scene / preview
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def setup_preview(world_rgb=(0.035, 0.035, 0.05), ground=True, ground_size=200):
    scene = bpy.context.scene
    for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    w = bpy.data.worlds.new("PreviewWorld")
    scene.world = w
    w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*world_rgb, 1)
    bg.inputs["Strength"].default_value = 1.0
    for name, rot, energy, col in (("Key", (52, 0, 35), 3.2, (1.0, 0.96, 0.9)), ("Rim", (60, 0, 200), 2.2, (0.7, 0.8, 1.0)), ("Fill", (75, 0, -70), 0.8, (0.9, 0.9, 1.0))):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        ld.color = col
        lo = bpy.data.objects.new(name, ld)
        lo.rotation_euler = Euler([math.radians(a) for a in rot])
        scene.collection.objects.link(lo)
    if ground:
        bm = bmesh.new()
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=ground_size / 2)
        me = bpy.data.meshes.new("PreviewGround")
        bm.to_mesh(me)
        gm = bpy.data.materials.new("PreviewGroundMat")
        gm.use_nodes = True
        b = next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        b.inputs["Base Color"].default_value = (0.05, 0.05, 0.06, 1)
        b.inputs["Roughness"].default_value = 0.9
        me.materials.append(gm)
        g = bpy.data.objects.new("PreviewGround", me)
        scene.collection.objects.link(g)
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.image_settings.file_format = "JPEG"  # previews live in git: keep them small
    scene.render.image_settings.quality = 88
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Punchy"
    except Exception:
        pass
    try:
        scene.eevee.use_shadows = True
    except Exception:
        pass


def render_views(objects, out_dir, base, views=(("front", (0.0, 1.0, 0.25)), ("three_quarter", (0.75, 0.85, 0.42)), ("side", (1.0, 0.0, 0.2)), ("back", (-0.4, -1.0, 0.35))), lens=50, pad=1.18):
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
    for o in objects:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    centre = (lo + hi) / 2
    radius = (hi - lo).length / 2
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.lens = lens
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    fov = 2 * math.atan(18 / lens)
    dist = radius * pad / math.sin(fov / 2)
    paths = []
    for name, d in views:
        d = Vector(d).normalized()
        cam.location = centre + d * dist
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(out_dir, f"{base}_{name}.jpg")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    bpy.data.objects.remove(cam)
    print("[raid_kit] previews:", paths)
    return paths
