"""Run a hair generator in headless Blender, optionally export it, and render four views.

    blender.exe --background --factory-startup --python run_hair_headless.py -- \
        --generator tools/make_nyx_hair_ugc.py --hair NyxHair --out <render folder> \
        [--export] [--textured] [--views front,threequarter,side,back,backright,backlow]

Blender (Steam): D:\\SteamLibrary\\steamapps\\common\\Blender\\blender.exe.
Run it from the repository root (cwd); paths are relative to it. Renders go to <out>/<hair>_<view>.png (Workbench,
orthographic, with grey torso and arm proxies for a Slim body in 1.2-head units, so you can
judge length and clearance). --export runs the hero-remodel skill's blender_export_hair.py
into assets/hair (FBX, JSON, .blend) and prints the centre and size for the costume piece.
--textured shows the image texture (two-colour hair) instead of the material colour.
Stitch the views with PIL afterwards and compare them with the reference art.
"""

import os
import sys

import bpy
from mathutils import Vector

ROOT = os.getcwd()
EXPORTER = os.path.join(ROOT, ".claude", "skills", "hero-remodel", "scripts", "blender_export_hair.py")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return argv[argv.index(name) + 1] if name in argv else default


generator = os.path.join(ROOT, arg("--generator"))
hair_name = arg("--hair")
out_dir = arg("--out", os.path.join(ROOT, "assets", "hair"))
views_arg = arg("--views", "front,threequarter,side,back")
assert generator and hair_name, "--generator and --hair are required"

for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
exec(open(generator, encoding="utf-8").read(), {"__name__": "__main__"})

if "--export" in argv:
    exec(open(EXPORTER, encoding="utf-8").read(), {"HAIR": hair_name, "OUT_DIR": os.path.join(ROOT, "assets", "hair")})


def box(name, centre, size):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(centre[0], -centre[2], centre[1]))
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[2], size[1])
    m = bpy.data.materials.new(name + "M")
    m.diffuse_color = (0.85, 0.83, 0.78, 1)
    o.data.materials.append(m)


# Slim torso and arms in 1.2-head units (Roblox x, y, z).
box("Torso", (0, -1.29, 0), (1.29, 1.37, 0.72))
box("ArmR", (0.94, -1.25, 0), (0.6, 1.9, 0.6))
box("ArmL", (-0.94, -1.25, 0), (0.6, 1.9, 0.6))

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "TEXTURE" if "--textured" in argv else "MATERIAL"
scene.render.resolution_x = scene.render.resolution_y = 520
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 3.4
target = Vector((0, 0, -0.6))
ALL = {
    "front": (0, 1, 0.12),
    "threequarter": (0.8, 0.6, 0.2),
    "side": (1, -0.1, 0.1),
    "back": (0, -1, 0.25),
    "backright": (0.7, -0.7, 0.2),
    "backlow": (0.3, -1, -0.25),
    "top": (0.001, -0.3, 1),
}
os.makedirs(out_dir, exist_ok=True)
stem = hair_name[:-4].lower() if hair_name.endswith("Hair") else hair_name.lower()
for name in views_arg.split(","):
    d = Vector(ALL[name]).normalized()
    cam.location = target + d * 8
    cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(out_dir, f"{stem}_{name}.png")
    bpy.ops.render.render(write_still=True)
print("rendered", views_arg)
