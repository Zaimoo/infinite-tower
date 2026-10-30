import bpy
import math
import os
from mathutils import Vector

# Studio Lighting Setup
world = bpy.context.scene.world
if not world:
    world = bpy.data.worlds.new("World")
    bpy.context.scene.world = world
world.use_nodes = True
if world.node_tree:
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.05, 0.05, 0.06, 1.0)
        bg.inputs["Strength"].default_value = 0.5

# Setup Studio Lights: Key, Fill, Rim, Under
lights = [
    ("KeyLight", (2.0, 2.5, 3.0), 120, (1.0, 0.98, 0.95)),
    ("FillLight", (-2.5, 2.0, 1.5), 60, (0.85, 0.90, 1.0)),
    ("RimLight", (0.0, -3.0, 2.5), 150, (1.0, 0.95, 0.85)),
    ("UnderLight", (0.0, 1.5, -2.0), 30, (0.8, 0.8, 0.8)),
]

for name, loc, energy, col in lights:
    l_obj = bpy.data.objects.get(name)
    if not l_obj:
        l_data = bpy.data.lights.new(name, "POINT")
        l_obj = bpy.data.objects.new(name, l_data)
        bpy.context.collection.objects.link(l_obj)
    l_obj.location = loc
    l_obj.data.energy = energy
    l_obj.data.color = col

# Ensure RefHead is visible
ref = bpy.data.objects.get("RefHead")
if ref:
    ref.hide_set(False)
    ref.hide_render = False

# Ensure fast rendering
if "BLENDER_EEVEE_NEXT" in bpy.types.RenderEngine.__subclasses__():
    bpy.context.scene.render.engine = "BLENDER_EEVEE_NEXT"
elif "BLENDER_EEVEE" in bpy.types.RenderEngine.__subclasses__():
    bpy.context.scene.render.engine = "BLENDER_EEVEE"

# Camera Setup
cam = bpy.data.objects.get("Camera")
if not cam:
    cam_data = bpy.data.cameras.new("Camera")
    cam = bpy.data.objects.new("Camera", cam_data)
    bpy.context.collection.objects.link(cam)

bpy.context.scene.camera = cam
bpy.context.scene.render.resolution_x = 768
bpy.context.scene.render.resolution_y = 768

# Render views
angles = [
    ("front", (0.0, 2.6, 0.10)),
    ("three_quarter", (1.9, 1.9, 0.45)),
    ("side", (2.6, 0.0, 0.10)),
    ("back", (0.0, -2.6, 0.10)),
]

out_dir = r"D:\Programming shi\infinite-tower\assets\hair"
for name, loc in angles:
    cam.location = loc
    direction = Vector((0.0, 0.0, 0.05)) - Vector(loc)
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
    fp = os.path.join(out_dir, f"jenna_render_{name}.png")
    bpy.context.scene.render.filepath = fp
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {fp}")
