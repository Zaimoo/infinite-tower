"""
=============================================================================
Infinite Towers: Become a Master! - scenery mesh bake
Merges builder-made Roblox parts into a few meshes per asset.
Target: Blender 4.x / 5.x (headless) -> FBX -> Roblox Studio (MeshParts)
=============================================================================
Some hub scenery is thousands of plain blocks: FortressWalls is ~2,300 parts
per plot, CourtyardGroundTiles ~250. This script rebuilds the same geometry
from an export of those parts and merges it into one mesh per material and
colour, so a plot's walls become about a dozen MeshParts.

Pipeline
  1. In Studio (edit mode), run tools/blender/export_scenery_parts.luau through
     the command bar or Studio MCP and save its output as
     tools/blender/bake_data/scenery_parts.txt. It builds the walls and tiles
     with the real builders and writes every bakeable part
     (ServerScriptService.BaseOverhaul.SceneryBake.IsBakeable).
  2. Run this script headless:
       blender.exe --background --factory-startup \
           --python tools/blender/bake_scenery_meshes.py
     It writes  assets/models/baked_scenery/<Asset>.fbx,
                assets/models/baked_scenery/baked_scenery_manifest.json and
                src/ServerScriptService/BaseOverhaul/BakedSceneryIndex.luau.
  3. Import each FBX into ReplicatedStorage.Assets.BakedScenery as a Model
     named after the asset (docs/performance-plan.md has the import settings).
     SceneryBake.Apply then swaps the parts for the meshes on the next hub
     rebuild.

Data file (all lengths in hundredths of a stud, rotations in thousandths)
  #G <id> <Material>_<hex>           material-and-colour group
  #R <id> r00 r01 r02 r10 ... r22    rotation matrix, row-major
  #A <Asset> <signature>             starts an asset
  #U <id>                            starts a unit (a wall bay, a tower, ...)
  <B|W|C> <group> <rot> sx sy sz px py pz    block / wedge / cylinder, unit space
  #I <unit> <quarterTurns> cx cy cz  places a unit: centre (studs) and yaw

Coordinates
  Everything is computed in Roblox space (X right, Y up, Z back). A Roblox
  point (x, y, z) is written to Blender as (x, -z, y), and the FBX is exported
  with Blender's default axes (forward -Z, up Y), so FBX space is Roblox space.
  Three marker cubes (BakeOrigin, BakeAxisX, BakeAxisY) are exported with the
  meshes; SceneryBake reads the bake's origin and axes from where they land, so
  the import may move or rotate the model as a whole.
=============================================================================
"""

import json
import math
import os
import sys

import bpy

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA_PATH = os.path.join(REPO_ROOT, "tools", "blender", "bake_data", "scenery_parts.txt")
EXPORT_DIR = os.path.join(REPO_ROOT, "assets", "models", "baked_scenery")
INDEX_PATH = os.path.join(REPO_ROOT, "src", "ServerScriptService", "BaseOverhaul", "BakedSceneryIndex.luau")
MANIFEST_PATH = os.path.join(EXPORT_DIR, "baked_scenery_manifest.json")

# A mesh over this many triangles is split by courtyard quadrant (Roblox caps a MeshPart's triangles).
MAX_TRIS_PER_MESH = 18000
CYLINDER_SEGMENTS = 16
MARKER_SIZE = 0.2
MARKER_AXIS_DISTANCE = 10.0  # SceneryBake.MARKER_AXIS_DISTANCE
UV_TILE_STUDS = 8.0
# Short mesh-name prefixes, so MeshPart names stay readable in the Explorer.
PREFIXES = {"FortressWalls": "FW", "CourtyardGroundTiles": "CT"}


# ---------------------------------------------------------------------------
# Data file
# ---------------------------------------------------------------------------
def parse(path):
    groups, rotations, assets = {}, {}, []
    asset, unit = None, None
    with open(path, "r", encoding="ascii") as handle:
        for raw in handle:
            line = raw.strip()
            if not line:
                continue
            fields = line.split()
            tag = fields[0]
            if tag == "#G":
                groups[int(fields[1])] = fields[2]
            elif tag == "#R":
                rotations[int(fields[1])] = [int(v) / 1000.0 for v in fields[2:11]]
            elif tag == "#A":
                asset = {"name": fields[1], "signature": fields[2], "units": {}, "instances": []}
                assets.append(asset)
            elif tag == "#U":
                unit = []
                asset["units"][int(fields[1])] = unit
            elif tag == "#I":
                asset["instances"].append(
                    (int(fields[1]), int(fields[2]), (float(fields[3]), float(fields[4]), float(fields[5])))
                )
            elif tag in ("B", "W", "C"):
                size = [int(v) / 100.0 for v in fields[3:6]]
                position = [int(v) / 100.0 for v in fields[6:9]]
                unit.append((tag, int(fields[1]), int(fields[2]), size, position))
            else:
                raise ValueError("Unknown line: " + line)
    return groups, rotations, assets


# ---------------------------------------------------------------------------
# Primitives in part space (Roblox axes). Faces wind counter-clockwise seen from outside.
# ---------------------------------------------------------------------------
def block(size):
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    verts = [
        (-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
        (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz),
    ]
    faces = [
        (0, 3, 2, 1),  # -Z
        (4, 5, 6, 7),  # +Z
        (0, 4, 7, 3),  # -X
        (1, 2, 6, 5),  # +X
        (3, 7, 6, 2),  # +Y
        (0, 1, 5, 4),  # -Y
    ]
    return verts, faces


def wedge(size):
    # Roblox WedgePart: full bottom face, full back (+Z) face, slope rising from the front-bottom
    # edge (-Z) to the back-top edge (+Z).
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    verts = [
        (-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz),  # bottom
        (-hx, hy, hz), (hx, hy, hz),  # back-top edge
    ]
    faces = [
        (0, 1, 2, 3),  # -Y bottom
        (3, 2, 5, 4),  # +Z back
        (0, 4, 5, 1),  # slope
        (0, 3, 4),  # -X side
        (1, 5, 2),  # +X side
    ]
    return verts, faces


def cylinder(size):
    # Roblox cylinder: axis along X, round in the YZ plane, diameter = the smaller of Y and Z.
    hx = size[0] / 2
    radius = min(size[1], size[2]) / 2
    n = CYLINDER_SEGMENTS
    verts, faces = [], []
    for i in range(n):
        a = 2 * math.pi * i / n
        y, z = radius * math.cos(a), radius * math.sin(a)
        verts.append((-hx, y, z))
        verts.append((hx, y, z))
    for i in range(n):
        j = (i + 1) % n
        faces.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    faces.append(tuple(2 * i for i in range(n)))  # -X cap
    faces.append(tuple(2 * i + 1 for i in reversed(range(n))))  # +X cap
    return verts, faces


PRIMITIVES = {"B": block, "W": wedge, "C": cylinder}


def signed_volume(verts, faces):
    total = 0.0
    for face in faces:
        a = verts[face[0]]
        for i in range(1, len(face) - 1):
            b, c = verts[face[i]], verts[face[i + 1]]
            total += (
                a[0] * (b[1] * c[2] - b[2] * c[1])
                - a[1] * (b[0] * c[2] - b[2] * c[0])
                + a[2] * (b[0] * c[1] - b[1] * c[0])
            )
    return total / 6.0


for _name, _make in PRIMITIVES.items():
    # Outward-facing winding gives a positive volume; a flipped face would show up here.
    assert signed_volume(*_make([2.0, 3.0, 4.0])) > 0, _name + " primitive winds inward"


# ---------------------------------------------------------------------------
# Transforms
# ---------------------------------------------------------------------------
def rotate(matrix, v):
    return (
        matrix[0] * v[0] + matrix[1] * v[1] + matrix[2] * v[2],
        matrix[3] * v[0] + matrix[4] * v[1] + matrix[5] * v[2],
        matrix[6] * v[0] + matrix[7] * v[1] + matrix[8] * v[2],
    )


def yaw(quarter_turns, v):
    # CFrame.Angles(0, k * pi / 2, 0) applied to v
    k = quarter_turns % 4
    x, y, z = v
    if k == 0:
        return (x, y, z)
    if k == 1:
        return (z, y, -x)
    if k == 2:
        return (-x, y, -z)
    return (-z, y, x)


def to_blender(v):
    return (v[0], -v[2], v[1])


# ---------------------------------------------------------------------------
# Mesh building
# ---------------------------------------------------------------------------
class Bucket:
    def __init__(self):
        self.verts = []
        self.faces = []
        self.tris = 0
        self.parts = 0

    def add(self, verts, faces):
        base = len(self.verts)
        self.verts.extend(verts)
        for face in faces:
            self.faces.append(tuple(base + i for i in face))
            self.tris += len(face) - 2
        self.parts += 1


def quadrant(centre):
    return ("E" if centre[0] >= 0 else "W") + ("S" if centre[2] >= 0 else "N")


def collect(asset, groups, rotations):
    """Returns {group key: [(world verts, faces, part centre)]} in Roblox space."""
    by_group = {}
    part_count = 0
    for unit_id, quarter_turns, centre in asset["instances"]:
        for shape, group_id, rotation_id, size, position in asset["units"][unit_id]:
            local_verts, faces = PRIMITIVES[shape](size)
            matrix = rotations[rotation_id]
            world = []
            for v in local_verts:
                r = rotate(matrix, v)
                p = yaw(quarter_turns, (r[0] + position[0], r[1] + position[1], r[2] + position[2]))
                world.append((p[0] + centre[0], p[1] + centre[1], p[2] + centre[2]))
            c = yaw(quarter_turns, position)
            part_centre = (c[0] + centre[0], c[1] + centre[1], c[2] + centre[2])
            by_group.setdefault(groups[group_id], []).append((world, faces, part_centre))
            part_count += 1
    return by_group, part_count


def bucket_parts(parts):
    """One bucket, or one per quadrant when the group has too many triangles for a single mesh."""
    total = sum(sum(len(f) - 2 for f in faces) for _, faces, _ in parts)
    buckets = {}
    for verts, faces, centre in parts:
        key = quadrant(centre) if total > MAX_TRIS_PER_MESH else ""
        buckets.setdefault(key, Bucket()).add(verts, faces)
    return buckets


def box_uv(mesh):
    """World-scale box projection, so a custom texture would tile evenly across the merged mesh."""
    layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        n = poly.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        for loop_index in poly.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            if axis == 0:
                uv = (co[1], co[2])
            elif axis == 1:
                uv = (co[0], co[2])
            else:
                uv = (co[0], co[1])
            layer.data[loop_index].uv = (uv[0] / UV_TILE_STUDS, uv[1] / UV_TILE_STUDS)


def make_object(name, verts_roblox, faces):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_blender(v) for v in verts_roblox], [], faces)
    mesh.update(calc_edges=True)
    box_uv(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def make_marker(name, position_roblox):
    verts, faces = block([MARKER_SIZE, MARKER_SIZE, MARKER_SIZE])
    moved = [(v[0] + position_roblox[0], v[1] + position_roblox[1], v[2] + position_roblox[2]) for v in verts]
    return make_object(name, moved, faces)


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)


def export_fbx(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"MESH"},
        use_mesh_modifiers=False,
        mesh_smooth_type="FACE",
        axis_forward="-Z",
        axis_up="Y",
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        bake_space_transform=True,
        add_leaf_bones=False,
    )


def bake_asset(asset, groups, rotations):
    name = asset["name"]
    prefix = PREFIXES.get(name, name[:2].upper())
    by_group, part_count = collect(asset, groups, rotations)
    expected = int(asset["signature"].split("-")[0])
    assert part_count == expected, "%s: rebuilt %d parts, the export has %d" % (name, part_count, expected)

    clear_scene()
    objects = [
        make_marker("BakeOrigin", (0.0, 0.0, 0.0)),
        make_marker("BakeAxisX", (MARKER_AXIS_DISTANCE, 0.0, 0.0)),
        make_marker("BakeAxisY", (0.0, MARKER_AXIS_DISTANCE, 0.0)),
    ]
    meshes = {}
    index = 0
    for group_key in sorted(by_group):
        material, colour = group_key.rsplit("_", 1)
        for quadrant_key, bucket in sorted(bucket_parts(by_group[group_key]).items()):
            index += 1
            mesh_name = "%s%02d_%s_%s%s" % (prefix, index, material, colour, quadrant_key)
            objects.append(make_object(mesh_name, bucket.verts, bucket.faces))
            meshes[mesh_name] = {
                "Material": material,
                "Color": colour,
                "Triangles": bucket.tris,
                "Parts": bucket.parts,
            }
            assert bucket.tris <= MAX_TRIS_PER_MESH + 4000, mesh_name + " is still too large after the split"

    path = os.path.join(EXPORT_DIR, name + ".fbx")
    export_fbx(path, objects)
    triangles = sum(m["Triangles"] for m in meshes.values())
    print("[SceneryBake] %s: %d parts -> %d meshes, %d triangles -> %s" % (name, part_count, len(meshes), triangles, path))
    return {"Signature": asset["signature"], "Parts": part_count, "Triangles": triangles, "Meshes": meshes}


def write_index(results):
    lines = [
        "--!strict",
        "-- ServerScriptService/BaseOverhaul/BakedSceneryIndex.luau",
        "-- GENERATED by tools/blender/bake_scenery_meshes.py. Do not edit by hand.",
        "-- One entry per baked asset: the Signature of the parts the mesh replaces (SceneryBake.Signature) and",
        "-- the material and colour of each MeshPart in ReplicatedStorage.Assets.BakedScenery.<AssetName>.",
        "",
        "export type MeshLook = { Material: string, Color: string }",
        "export type Entry = { Signature: string, Meshes: { [string]: MeshLook } }",
        "",
        "local Index: { [string]: Entry } = {",
    ]
    for name in sorted(results):
        entry = results[name]
        lines.append("\t%s = {" % name)
        lines.append('\t\tSignature = "%s", -- %d parts, %d triangles' % (entry["Signature"], entry["Parts"], entry["Triangles"]))
        lines.append("\t\tMeshes = {")
        for mesh_name in sorted(entry["Meshes"]):
            mesh = entry["Meshes"][mesh_name]
            lines.append('\t\t\t%s = { Material = "%s", Color = "%s" },' % (mesh_name, mesh["Material"], mesh["Color"]))
        lines.append("\t\t},")
        lines.append("\t},")
    lines += ["}", "", "return Index", ""]
    with open(INDEX_PATH, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))


def main():
    os.makedirs(EXPORT_DIR, exist_ok=True)
    groups, rotations, assets = parse(DATA_PATH)
    results = {asset["name"]: bake_asset(asset, groups, rotations) for asset in assets}
    write_index(results)
    with open(MANIFEST_PATH, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(results, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print("[SceneryBake] wrote %s and %s" % (INDEX_PATH, MANIFEST_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback

        traceback.print_exc()
        sys.exit(1)
