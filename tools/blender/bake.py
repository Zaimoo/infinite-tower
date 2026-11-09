"""
Tier B surface bake for Elites, Alphas and Biome Bosses (docs/tower-mob-remodel-plan.md §3.2).

For a built MobAsset:
  1. every non-glow game mesh gets a high-poly twin: Subdivision (2) + a light Displace noise, so edges round off
     and surfaces get stylized chips and lumps;
  2. the game meshes get one shared, packed UV layout (Smart UV Project over all of them at once);
  3. Cycles bakes, high -> low, into one texture per enemy: tangent NORMAL, DIFFUSE colour (from the atlas the
     high-poly still carries) and AO (with every other twin in the scene, so contact shadows land);
  4. colour x AO -> <enemyId>_color.png, plus <enemyId>_normal.png; the game meshes get a Principled material
     with both, so the FBX carries a PBR surface (Studio's importer turns it into a SurfaceAppearance);
  5. the twins are deleted.
Glow meshes are untouched (they stay Neon in Roblox).
"""
import bpy, os, math
import numpy as np


def _new_image(name, size, non_color=False):
    img = bpy.data.images.get(name)
    if img:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def _bake_material(img):
    m = bpy.data.materials.new("BakeTarget")
    m.use_nodes = True
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.nodes.active = tex
    return m, tex


def _select(objs, active):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active


def bake_asset(asset, objs, size, out_dir, samples=24):
    scene = bpy.context.scene
    try:
        scene.render.engine = "CYCLES"
    except TypeError:
        pass
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    bake = scene.render.bake
    bake.use_clear = False
    bake.margin = 6
    bake.use_selected_to_active = True

    lows = [o for o in objs if "_Glow_" not in o.name]
    # 1. high-poly twins (keep the atlas UVs for the diffuse source)
    highs = {}
    noise = bpy.data.textures.new("ChipNoise", type="CLOUDS")
    noise.noise_scale = 0.35
    noise.noise_depth = 2
    for lo in lows:
        hi = lo.copy()
        hi.data = lo.data.copy()
        hi.name = lo.name + "__hi"
        scene.collection.objects.link(hi)
        sub = hi.modifiers.new("Sub", "SUBSURF")
        sub.levels = sub.render_levels = 2
        d = hi.modifiers.new("Chip", "DISPLACE")
        d.texture = noise
        d.strength = 0.05
        d.mid_level = 0.5
        highs[lo.name] = hi
    bpy.context.view_layer.update()

    # 2. one packed UV layout over all game meshes
    for lo in lows:
        uv = lo.data.uv_layers.new(name="BakeUV")
        lo.data.uv_layers.active = uv
    _select(lows, lows[0])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.012, scale_to_bounds=False)
    bpy.ops.uv.select_all(action="SELECT")
    try:  # pack tighter than Smart UV does on its own: more texels per stud
        bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
    except Exception as err:
        print("[bake] pack_islands skipped:", err)
    bpy.ops.object.mode_set(mode="OBJECT")

    # bake targets: the game meshes temporarily wear a material whose active node is the target image
    keep = {lo.name: list(lo.data.materials) for lo in lows}
    imgs = {"NORMAL": _new_image(asset.name + "_normal", size, True),
            "DIFFUSE": _new_image(asset.name + "_diffuse", size),
            "AO": _new_image(asset.name + "_ao", size, True)}
    for kind, img in imgs.items():
        mat, _ = _bake_material(img)
        if kind == "NORMAL":  # neutral background
            img.pixels[:] = np.tile(np.array([0.5, 0.5, 1.0, 1.0], dtype=np.float32), size * size)
        for lo in lows:
            lo.data.materials.clear()
            lo.data.materials.append(mat)
        for lo in lows:
            _select([highs[lo.name], lo], lo)
            ext = max(0.02, min(lo.dimensions) * 0.06)
            kwargs = dict(type=kind, use_selected_to_active=True, cage_extrusion=ext, margin=6, use_clear=False)
            if kind == "DIFFUSE":
                kwargs["pass_filter"] = {"COLOR"}
            bpy.ops.object.bake(**kwargs)
        print(f"[bake] {asset.name}: {kind} done")

    # 4. colour x AO, save, and give the game meshes a PBR material
    os.makedirs(out_dir, exist_ok=True)
    diff = np.array(imgs["DIFFUSE"].pixels[:], dtype=np.float32).reshape(-1, 4)
    ao = np.array(imgs["AO"].pixels[:], dtype=np.float32).reshape(-1, 4)[:, :1]
    col = diff.copy()
    col[:, :3] = np.clip(diff[:, :3] * (0.38 + 0.62 * ao), 0, 1)
    color = _new_image(asset.name + "_color", size)
    color.pixels[:] = col.ravel()
    paths = {}
    for key, img in (("color", color), ("normal", imgs["NORMAL"])):
        p = os.path.join(out_dir, f"{asset.name}_{key}.png")
        img.filepath_raw = p
        img.file_format = "PNG"
        img.save()
        paths[key] = p
    pbr = bpy.data.materials.new(asset.name + "_PBR")
    pbr.use_nodes = True
    nt = pbr.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexImage"); tc.image = color
    tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = imgs["NORMAL"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Roughness"].default_value = 0.72
    for lo in lows:
        lo.data.materials.clear()
        lo.data.materials.append(pbr)
        atlas_uv = lo.data.uv_layers.get("UVMap")
        if atlas_uv:
            lo.data.uv_layers.remove(atlas_uv)
        lo.data.uv_layers["BakeUV"].name = "UVMap"

    # 5. remove the twins
    for hi in highs.values():
        bpy.data.objects.remove(hi, do_unlink=True)
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE"
    asset.meta["Surface"] = {"Tier": "B", "Size": size, "Color": os.path.basename(paths["color"]), "Normal": os.path.basename(paths["normal"])}
    print(f"[bake] {asset.name}: saved {paths}")
    return paths
