"""
Shared bmesh kit for the artifact weapon generators (tools/blender/generate_*.py).

Every helper writes into a Part (one bmesh = one Roblox MeshPart). Coordinates are Blender
units (1 unit = 1 stud) in the Blender frame; the generators document how that frame maps to
the weapon's Roblox Handle space. Lifted from generate_berserker_greataxes.py and extended
with swept tubes and a per-part vertex warp (shield camber, limb curl).
"""

import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

I4 = Matrix.Identity(4)


def V2(u, z):
    return Vector((u, z))


def V3(x, y, z):
    return Vector((x, y, z))


def rgb(r, g, b):
    return (r / 255, g / 255, b / 255, 1)


def T(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))


def RX(deg):
    return Matrix.Rotation(math.radians(deg), 4, "X")


def RY(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Y")


def RZ(deg):
    return Matrix.Rotation(math.radians(deg), 4, "Z")


# --------------------------------------------------------------------------------------
# Part: one bmesh that becomes one MeshPart
# --------------------------------------------------------------------------------------
class Part:
    def __init__(self):
        self.bm = bmesh.new()
        self.warp = None  # optional callable(Vector) -> Vector applied after M

    def v(self, co, M=I4):
        p = M @ Vector(co)
        if self.warp:
            p = self.warp(p)
        return self.bm.verts.new(p)

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


def lathe(part, profile, segs, M=I4, sx=1.0, sy=1.0, phase=0.0):
    """Revolve (radius, z) pairs about Z. A radius of 0 closes to a point."""
    rings = []
    for r, z in profile:
        if r < 1e-5:
            rings.append([part.v((0, 0, z), M)])
        else:
            ring = []
            for i in range(segs):
                a = phase + 2 * math.pi * i / segs
                ring.append(part.v((r * sx * math.cos(a), r * sy * math.sin(a), z), M))
            rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                part.f([a[0], b[i], b[j]])
            elif len(b) == 1:
                part.f([a[i], a[j], b[0]])
            else:
                part.f([a[i], a[j], b[j], b[i]])
    if len(rings[0]) > 1:
        part.f(rings[0][::-1])
    if len(rings[-1]) > 1:
        part.f(rings[-1])


def box(part, c, size, M=I4):
    cx, cy, cz = c
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    vs = [part.v((cx + dx * hx, cy + dy * hy, cz + dz * hz), M) for dx in (-1, 1) for dy in (-1, 1) for dz in (-1, 1)]
    for q in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
        part.f([vs[i] for i in q])


def torus(part, R, r, n_major, n_minor, M=I4, sx=1.0, sy=1.0, arc=1.0):
    """Torus in the local XY plane about Z. arc < 1 leaves an open (capped) arc."""
    closed = arc >= 0.999
    n = n_major if closed else n_major + 1
    rings = []
    for i in range(n):
        a = 2 * math.pi * arc * i / n_major
        ring = []
        for j in range(n_minor):
            b = 2 * math.pi * j / n_minor
            rr = R + r * math.cos(b)
            ring.append(part.v((rr * math.cos(a) * sx, rr * math.sin(a) * sy, r * math.sin(b)), M))
        rings.append(ring)
    for i in range(n if closed else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        for j in range(n_minor):
            k = (j + 1) % n_minor
            part.f([a[j], b[j], b[k], a[k]])
    if not closed:
        part.f(rings[0][::-1])
        part.f(rings[-1])


def sphere(part, c, r, segs=10, rings=6, M=I4, sz=1.0):
    prof = [(r * math.sin(math.pi * i / rings), -r * sz * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
    lathe(part, prof, segs, M @ Matrix.Translation(Vector(c)))


def gem(part, c, r, h, segs=6, M=I4, tilt=(0.0, 0.0)):
    """Crystal shard: a lopsided bipyramid standing on its local Z."""
    Mt = M @ Matrix.Translation(Vector(c)) @ Matrix.Rotation(tilt[0], 4, "X") @ Matrix.Rotation(tilt[1], 4, "Y")
    lathe(part, [(0, -h * 0.35), (r, -h * 0.05), (r * 0.8, h * 0.2), (0, h * 0.65)], segs, Mt)


def cut_gem(part, c, r, h, segs=8, M=I4):
    """Faceted cabochon/brilliant: girdle at c, crown along +Z, pavilion along -Z."""
    lathe(part, [(0, -h * 0.55), (r, 0), (r * 0.62, h * 0.32), (0, h * 0.36)], segs, M @ Matrix.Translation(Vector(c)))


def face_gem(part, pos, r, h, segs=8, facing=1, M=I4):
    """Cut gem set into a face, crown pointing along +Y (facing=1) or -Y (facing=-1)."""
    cut_gem(part, (0, 0, 0), r, h, segs, M @ Matrix.Translation(Vector(pos)) @ Matrix.Rotation(math.radians(-90 * facing), 4, "X"))


def cyl(part, a, b, r0, r1=None, segs=8):
    """Tapered rod between two 3D points."""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    if L < 1e-6:
        return
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    M = Matrix.Translation(a) @ q.to_matrix().to_4x4()
    lathe(part, [(r0, 0), (r1 if r1 is not None else r0, L)], segs, M)


# --------------------------------------------------------------------------------------
# 2D outline helpers (u, z) - plates are built in the local XZ plane, thickness along Y
# --------------------------------------------------------------------------------------
def signed_area(pts):
    return 0.5 * sum(pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y for i in range(len(pts)))


def inside(p, pts):
    hit = False
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        if (a.y > p.y) != (b.y > p.y):
            x = a.x + (p.y - a.y) / (b.y - a.y) * (b.x - a.x)
            if x > p.x:
                hit = not hit
    return hit


def inset_poly(pts, depths):
    n = len(pts)
    ccw = signed_area(pts) > 0
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
        k = 1.0 / max(0.4, m.dot(n1))
        s = 1.0
        q = p1 + m * depths[i] * k
        while not inside(q, pts) and s > 0.04:
            s *= 0.5
            q = p1 + m * depths[i] * k * s
        if not inside(q, pts):
            q = p1 + m * 0.002
        out.append(q)
    return out


def plate(part, pts, t, inset, M=I4, rim_t=0.0, depth_fn=None):
    """Bevelled slab in the local XZ plane: full thickness t inside, tapering to a rim of
    thickness rim_t (0 = knife edge). depth_fn(p) can scale the bevel depth per vertex."""
    depths = [inset * (depth_fn(p) if depth_fn else 1.0) for p in pts]
    inner = inset_poly(pts, depths)
    n = len(pts)
    if rim_t > 1e-5:
        rim_f = [part.v((p.x, rim_t / 2, p.y), M) for p in pts]
        rim_b = [part.v((p.x, -rim_t / 2, p.y), M) for p in pts]
    else:
        rim_f = rim_b = [part.v((p.x, 0, p.y), M) for p in pts]
    front = [part.v((p.x, t / 2, p.y), M) for p in inner]
    back = [part.v((p.x, -t / 2, p.y), M) for p in inner]
    for i in range(n):
        j = (i + 1) % n
        part.f([rim_f[i], rim_f[j], front[j], front[i]])
        part.f([rim_b[j], rim_b[i], back[i], back[j]])
        if rim_t > 1e-5:
            part.f([rim_b[i], rim_b[j], rim_f[j], rim_f[i]])
    part.f(front)
    part.f(back[::-1])


def slab(part, pts, t, M=I4):
    """Flat extruded outline (no bevel) in the local XZ plane."""
    n = len(pts)
    front = [part.v((p.x, t / 2, p.y), M) for p in pts]
    back = [part.v((p.x, -t / 2, p.y), M) for p in pts]
    for i in range(n):
        j = (i + 1) % n
        part.f([front[i], back[i], back[j], front[j]])
    part.f(front)
    part.f(back[::-1])


def bezier(a, c, b, n):
    return [(a * (1 - s) ** 2 + c * 2 * s * (1 - s) + b * s * s) for s in (i / n for i in range(n + 1))]


def cubic(p0, p1, p2, p3, n):
    out = []
    for i in range(n + 1):
        s = i / n
        out.append(p0 * (1 - s) ** 3 + p1 * 3 * s * (1 - s) ** 2 + p2 * 3 * s * s * (1 - s) + p3 * s ** 3)
    return out


def edge_strip(part, arc, centre, w, te, M=I4, proud=0.02, taper=True):
    """Honed edge laid over a plate's rim: sharp outside, raised ridge inside."""
    n = len(arc)
    outer, front, back = [], [], []
    for i, p in enumerate(arc):
        tan = arc[min(n - 1, i + 1)] - arc[max(0, i - 1)]
        if tan.length < 1e-6:
            tan = V2(0, 1)
        tan.normalize()
        nrm = V2(-tan.y, tan.x)
        c = centre(p) if callable(centre) else centre
        if nrm.dot(c - p) < 0:
            nrm = -nrm
        s = i / (n - 1)
        wi = w * (0.35 + 0.65 * math.sin(math.pi * s)) if taper else w
        o, q = p - nrm * proud, p + nrm * wi
        outer.append(part.v((o.x, 0, o.y), M))
        front.append(part.v((q.x, te / 2, q.y), M))
        back.append(part.v((q.x, -te / 2, q.y), M))
    for i in range(n - 1):
        part.f([outer[i], outer[i + 1], front[i + 1], front[i]])
        part.f([outer[i + 1], outer[i], back[i], back[i + 1]])
        part.f([front[i], front[i + 1], back[i + 1], back[i]])
    part.f([outer[0], front[0], back[0]])
    part.f([outer[-1], back[-1], front[-1]])


def stroke(part, a, b, width, t, M=I4, depth=0.022, sides=(1, -1)):
    """Inlay line between two plate-face points, sitting proud on both faces of a plate of thickness t."""
    d = b - a
    if d.length < 1e-5:
        return
    d.normalize()
    n = V2(-d.y, d.x) * (width / 2)
    for side in sides:
        y = side * t / 2
        vs = []
        for yy in (y - depth, y + depth):
            for p in (a - n, a + n, b + n, b - n):
                vs.append(part.v((p.x, yy, p.y), M))
        for q in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
            part.f([vs[i] for i in q])


def polyline(part, pts, width, t, M=I4, depth=0.022, sides=(1, -1)):
    for a, b in zip(pts, pts[1:]):
        stroke(part, a, b, width, t, M, depth, sides)


def vein(part, a, b, width, t, rng, kinks, wobble, M=I4):
    prev = a
    d = b - a
    n = V2(-d.y, d.x)
    for i in range(1, kinks + 1):
        s = i / kinks
        p = a.lerp(b, s)
        if i < kinks:
            p += n * rng.uniform(-wobble, wobble)
        stroke(part, prev, p, width * (1.0 - 0.5 * s), t, M)
        prev = p


def leaf(base, angle, length, width, n):
    """Feather outline starting at `base`, pointing along `angle` (radians from +u towards +z)."""
    c, s = math.cos(angle), math.sin(angle)
    pts = []
    for i in range(n + 1):
        k = i / n
        pts.append((length * k, width * math.sin(math.pi * k ** 0.7) * 0.5 + 0.02))
    for i in range(n - 1, 0, -1):
        k = i / n
        pts.append((length * k, -width * math.sin(math.pi * k ** 0.85) * 0.28))
    return [V2(base.x + x * c - y * s, base.y + x * s + y * c) for x, y in pts]


def star(cx, cz, r_out, r_in, points, phase=math.pi / 2):
    pts = []
    for i in range(points * 2):
        a = phase + math.pi * i / points
        r = r_out if i % 2 == 0 else r_in
        pts.append(V2(cx + r * math.cos(a), cz + r * math.sin(a)))
    return pts


def ngon(cx, cz, r, n, phase=math.pi / 2, sx=1.0):
    return [V2(cx + r * sx * math.cos(phase + 2 * math.pi * i / n), cz + r * math.sin(phase + 2 * math.pi * i / n)) for i in range(n)]


def mirror_u(half):
    """Close a right-hand outline (top -> bottom, u >= 0) into a symmetric polygon."""
    left = [V2(-p.x, p.y) for p in reversed(half) if abs(p.x) > 1e-6]
    return half + left


# --------------------------------------------------------------------------------------
# Swept tube / ribbon along a 3D path
# --------------------------------------------------------------------------------------
def sweep(part, path, widths, thicks, side=Vector((1, 0, 0)), segs=8, profile="lens", cap=True, twist=None, closed=False):
    """Sweep a cross-section along `path`. The section is `widths[i]` wide along `side`
    (re-orthogonalised against the tangent) and `thicks[i]` thick along tangent x side.
    profile: 'lens' (pointed ellipse), 'oval', 'rect' (rounded box). closed joins the last
    section back to the first (a loop)."""
    n = len(path)
    if isinstance(widths, (int, float)):
        widths = [widths] * n
    if isinstance(thicks, (int, float)):
        thicks = [thicks] * n
    rings = []
    for i, p in enumerate(path):
        if closed:
            tan = path[(i + 1) % n] - path[(i - 1) % n]
        else:
            tan = path[min(n - 1, i + 1)] - path[max(0, i - 1)]
        tan.normalize()
        sd = side - tan * side.dot(tan)
        if sd.length < 1e-6:
            sd = Vector((0, 1, 0)) - tan * tan.y
        sd.normalize()
        nm = tan.cross(sd).normalized()
        if twist:
            a = twist(i / (n - 1))
            sd, nm = sd * math.cos(a) + nm * math.sin(a), nm * math.cos(a) - sd * math.sin(a)
        w, t = widths[i] / 2, thicks[i] / 2
        ring = []
        for j in range(segs):
            a = 2 * math.pi * j / segs
            ca, sa = math.cos(a), math.sin(a)
            if profile == "lens":
                x, y = w * ca, t * sa * (1 - 0.35 * abs(ca))
            elif profile == "rect":
                k = 0.25
                x = w * math.copysign(abs(ca) ** k, ca)
                y = t * math.copysign(abs(sa) ** k, sa)
            else:
                x, y = w * ca, t * sa
            ring.append(part.v(p + sd * x + nm * y))
        rings.append(ring)
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for a, b in pairs:
        for j in range(segs):
            k = (j + 1) % segs
            part.f([a[j], a[k], b[k], b[j]])
    if cap and not closed:
        part.f(rings[0][::-1])
        part.f(rings[-1])


def resample(pts, n):
    """Evenly resample a polyline to n+1 points."""
    acc = [0.0]
    for a, b in zip(pts, pts[1:]):
        acc.append(acc[-1] + (b - a).length)
    L = acc[-1]
    out, j = [], 0
    for i in range(n + 1):
        d = L * i / n
        while j < len(acc) - 2 and acc[j + 1] < d:
            j += 1
        seg = acc[j + 1] - acc[j]
        s = 0 if seg < 1e-9 else (d - acc[j]) / seg
        out.append(pts[j].lerp(pts[j + 1], s))
    return out


# --------------------------------------------------------------------------------------
# Scene output
# --------------------------------------------------------------------------------------
def material(name, color):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    return mat


def bbox(bm):
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    lo, hi = Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))
    return lo, hi


def realise(wid, parts, colours, sharp_deg=32):
    """Turn Parts into mesh objects. Returns (objects, tris, {name: (centre, size)})."""
    coll = bpy.data.collections.new(wid)
    bpy.context.scene.collection.children.link(coll)
    objs, tris, info = [], 0, {}
    for name, part in parts.items():
        if part.empty:
            part.bm.free()
            continue
        bm = part.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for face in bm.faces:
            face.smooth = True
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(sharp_deg):
                e.smooth = False
        lo, hi = bbox(bm)
        info[name] = ((lo + hi) / 2, hi - lo)
        me = bpy.data.meshes.new(f"{wid}_{name}")
        bm.to_mesh(me)
        tris += len(bm.faces)
        bm.free()
        me.materials.append(material(f"{wid}_{name}", colours.get(name, (0.6, 0.6, 0.6, 1))))
        obj = bpy.data.objects.new(name, me)
        coll.objects.link(obj)
        objs.append(obj)
    return objs, tris, info


def export_fbx(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, mesh_smooth_type="EDGE",
                             add_leaf_bones=False, bake_anim=False, use_mesh_modifiers=True)


def render_sheet(path, cam_loc, cam_rot_deg, ortho, res_x, res_y):
    scene = bpy.context.scene
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = ortho
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    cam.location = cam_loc
    cam.rotation_euler = tuple(math.radians(a) for a in cam_rot_deg)
    scene.camera = cam
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("W")
    scene.world.color = (0.22, 0.23, 0.26)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)


def write_json(path, data):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent="\t")


def r3(v):
    return [round(v[0], 4), round(v[1], 4), round(v[2], 4)]


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    opts = {}
    for key in ("--preview", "--only", "--views"):
        if key in argv:
            opts[key[2:]] = argv[argv.index(key) + 1]
    return opts


def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)
