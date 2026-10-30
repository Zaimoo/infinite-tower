import bpy
import math

# Clean existing hair objects if re-running
for obj in list(bpy.data.objects):
    if obj.name.startswith("AaronHair") or obj.name == "RobloxHeadRef":
        bpy.data.objects.remove(obj, do_unlink=True)

# 1. Create Roblox Head Reference (Standard blocky head scale in meters: ~0.36m)
bpy.ops.mesh.primitive_cube_add(size=0.34, location=(0, 0, 1.5))
head_ref = bpy.context.active_object
head_ref.name = "RobloxHeadRef"
bpy.ops.object.modifier_add(type='BEVEL')
head_ref.modifiers["Bevel"].width = 0.05
head_ref.modifiers["Bevel"].segments = 4
head_ref.display_type = 'WIRE'

# 2. Create Stylized Anime Hair Profile Curve (Diamond with sharp outer ridge)
profile_data = bpy.data.curves.new('AaronHair_Profile', type='CURVE')
profile_data.dimensions = '2D'
spline = profile_data.splines.new('POLY')
spline.points.add(3)
# Points: Left edge, Top sharp ridge, Right edge, Flat bottom
coords = [(-0.045, 0.0, 0, 1), (0.0, 0.038, 0, 1), (0.045, 0.0, 0, 1), (0.0, -0.012, 0, 1)]
for i, coord in enumerate(coords):
    spline.points[i].co = coord
spline.use_cyclic_u = True
profile_obj = bpy.data.objects.new('AaronHair_Profile', profile_data)
bpy.context.collection.objects.link(profile_obj)
profile_obj.hide_viewport = True

# 3. Create Sandy Blonde Material (#DEC085)
mat = bpy.data.materials.get("AaronBlonde") or bpy.data.materials.new(name="AaronBlonde")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs["Base Color"].default_value = (0.87, 0.75, 0.52, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85

# Helper function to create tapered hair locks
def create_hair_lock(name, points, radii, tilts):
    curve_data = bpy.data.curves.new(name, type='CURVE')
    curve_data.dimensions = '3D'
    curve_data.bevel_mode = 'OBJECT'
    curve_data.bevel_object = profile_obj
    curve_data.use_fill_caps = True
    
    spline = curve_data.splines.new('BEZIER')
    spline.bezier_points.add(len(points) - 1)
    
    for i, (pt, rad, tilt) in enumerate(zip(points, radii, tilts)):
        bp = spline.bezier_points[i]
        bp.co = pt
        bp.handle_left_type = 'AUTO'
        bp.handle_right_type = 'AUTO'
        bp.radius = rad
        bp.tilt = math.radians(tilt)
        
    obj = bpy.data.objects.new(name, curve_data)
    obj.data.materials.append(mat)
    bpy.context.collection.objects.link(obj)
    return obj

# 4. Base Hair Cap (Covers upper skull)
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.19, location=(0, 0.01, 1.56))
cap = bpy.context.active_object
cap.name = "AaronHair_BaseCap"
cap.scale = (0.98, 1.05, 0.95)
cap.data.materials.append(mat)

# 5. Generate Aaron's Signature Locks (Coordinates relative to head at Z=1.5)
locks_spec = [
    # Main Left Curtain Bang (Sweeps over forehead to the left)
    ("AaronHair_Bang_L1", [(-0.02, -0.14, 1.69), (-0.10, -0.20, 1.66), (-0.16, -0.19, 1.54)], [0.8, 1.3, 0.05], [0, -25, -40]),
    # Main Right Curtain Bang (Heavy sweep to the right)
    ("AaronHair_Bang_R1", [(-0.01, -0.14, 1.69), (0.09, -0.21, 1.67), (0.16, -0.19, 1.53)], [0.9, 1.4, 0.05], [0, 25, 35]),
    # Center Forehead Strands (Dipping between eyebrows)
    ("AaronHair_Bang_Center1", [(-0.01, -0.15, 1.68), (-0.03, -0.20, 1.61), (-0.01, -0.19, 1.54)], [0.6, 0.9, 0.02], [0, -10, 0]),
    ("AaronHair_Bang_Center2", [(0.01, -0.15, 1.68), (0.04, -0.20, 1.62), (0.02, -0.19, 1.55)], [0.5, 0.8, 0.02], [0, 15, 5]),
    # Side Locks & Sideburns (Left & Right)
    ("AaronHair_Sideburn_L", [(-0.15, -0.10, 1.63), (-0.19, -0.11, 1.54), (-0.18, -0.10, 1.44)], [0.9, 1.0, 0.05], [-70, -80, -85]),
    ("AaronHair_Sideburn_R", [(0.15, -0.10, 1.63), (0.19, -0.11, 1.54), (0.18, -0.10, 1.44)], [0.9, 1.0, 0.05], [70, 80, 85]),
    # Outer Fluffy Side Spikes
    ("AaronHair_SideSpike_L1", [(-0.08, -0.05, 1.68), (-0.18, -0.06, 1.64), (-0.23, -0.02, 1.57)], [0.8, 1.2, 0.05], [-45, -60, -70]),
    ("AaronHair_SideSpike_R1", [(0.08, -0.05, 1.68), (0.19, -0.06, 1.65), (0.24, -0.02, 1.58)], [0.8, 1.3, 0.05], [45, 60, 70]),
    # Top Crown Spikes (Upturned tuft at the parting)
    ("AaronHair_CrownSpike_1", [(-0.02, -0.04, 1.70), (0.03, -0.02, 1.75), (0.08, 0.04, 1.77)], [0.7, 1.1, 0.02], [0, 15, 25]),
    ("AaronHair_CrownSpike_2", [(-0.03, -0.02, 1.70), (-0.08, 0.02, 1.74), (-0.13, 0.06, 1.75)], [0.7, 1.0, 0.02], [0, -20, -30]),
]

for name, pts, rads, tilts in locks_spec:
    create_hair_lock(name, pts, rads, tilts)

print("Aaron's Hair Curves Generated! Adjust Bezier handles in Edit Mode, then Convert to Mesh -> Join -> Export FBX (Scale 0.01).")
