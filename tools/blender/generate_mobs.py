"""
Tower mob generator (docs/tower-mob-remodel-plan.md §6.1). Builds a biome's enemies headless:
  blender -b -P tools/blender/generate_mobs.py -- verdant_ruins                 (whole biome + lineup)
  blender -b -P tools/blender/generate_mobs.py -- verdant_ruins mob_moss_crawler (one enemy)
Outputs:
  assets/models/enemies/<biome>/<enemyId>.fbx + .json       (joint-named meshes, Roblox-axis metadata)
  assets/models/enemies/<biome>/atlas_<biome>[_alpha].png    (the Tier A gradient atlas)
  assets/models/enemies/<biome>/previews/<enemyId>_<view>.jpg and lineup.jpg
  assets-source/tower/enemies/<enemyId>/model.blend
"""
import sys, os, importlib
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "mobs"))
import bpy
from mathutils import Vector
import raid_kit as K
import mob_kit as M

REPO = os.path.abspath(os.path.join(HERE, "..", ".."))


def build_one(mod, biome, enemy_id, out, prev):
    K.reset_scene()
    K.setup_preview(ground_size=120)
    mod_ = importlib.reload(mod)
    asset = mod_.BUILDERS[enemy_id]()
    asset.atlas.material = None
    asset.atlas.build_image(os.path.join(out, f"atlas_{asset.atlas.biome}.png"))
    objs = asset.build()
    asset.meta["Biome"] = biome
    asset.export(out, {"Atlas": f"atlas_{asset.atlas.biome}.png"})
    src = os.path.join(REPO, "assets-source", "tower", "enemies", enemy_id)
    os.makedirs(src, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(src, "model.blend"), compress=True)
    K.render_views(objs, prev, enemy_id, views=(("front", (0.0, 1.0, 0.22)), ("three_quarter", (0.8, 0.9, 0.4)), ("back", (-0.5, -1.0, 0.35))))


def lineup(mod, biome, ids, out, prev):
    """All the biome's enemies side by side (in-game scale), for the review."""
    K.reset_scene()
    K.setup_preview(ground_size=200)
    mod_ = importlib.reload(mod)
    x = 0.0
    every = []
    for enemy_id in ids:
        asset = mod_.BUILDERS[enemy_id]()
        asset.atlas.material = None
        asset.atlas.build_image()
        objs = asset.build()
        lo = min(o.location.x + min(c[0] for c in o.bound_box) for o in objs)
        hi = max(o.location.x + max(c[0] for c in o.bound_box) for o in objs)
        scale = 1.4 if asset.role == "ALPHA" else 1.0  # Alphas spawn 1.4x
        shift = x - lo * scale
        for o in objs:
            o.location = Vector((o.location.x * scale + shift, o.location.y * scale, o.location.z * scale))
            o.scale = (scale, scale, scale)
        x += (hi - lo) * scale + 2.5
        every += objs
    bpy.context.view_layer.update()
    K.render_views(every, prev, "lineup", views=(("front", (0.0, 1.0, 0.18)), ("three_quarter", (0.5, 0.9, 0.3))), lens=35, pad=1.0)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    biome = argv[0]
    mod = importlib.import_module(biome)
    ids = argv[1:] or list(mod.BUILDERS)
    out = os.path.join(REPO, "assets", "models", "enemies", biome)
    prev = os.path.join(out, "previews")
    os.makedirs(prev, exist_ok=True)
    for enemy_id in ids:
        build_one(mod, biome, enemy_id, out, prev)
    if len(argv) == 1:
        lineup(mod, biome, list(mod.BUILDERS), out, prev)
