"""
Infinite Tower: Become a Master! - Marksman bow artifacts (BOW remodel).

Builds all 14 launch bows as separate semantic parts and exports one FBX per artifact to
assets/artifacts/bow/, plus bows_manifest.json (part centres, socket points, materials,
triangle counts) that tests/studio-bow-import.luau reads.

    Bow:          Handle (riser + arrow shelf), GripWrap, LimbUpper, LimbLower, Fittings,
                  Ornament, RuneInlay, BowString
    HunterArrow:  ArrowShaft, ArrowHead, ArrowFletch

Run headless:
    blender --background --factory-startup --python tools/blender/generate_marksman_bows.py -- [--preview <png>] [--only id,id]

Authoring frame (1 Blender unit = 1 stud). Roblox Handle space = (bx, bz, -by):
    riser centred on the origin along +Z (upper limb up), string behind the riser at y = -S,
    nocked arrow flying towards +Y, resting beside the riser on its +X side.
    Roblox: stave +Y, string at +Z, arrow flies -Z  -> Grip is the identity at the origin,
    Nock at (ax, az, S), TipUpper/TipLower at (0, +/-T, S).
"""

import math
import os
import random
import sys

from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit as K  # noqa: E402
from weapon_kit import I4, RX, RY, RZ, T, V2, V3, Part, bezier, box, cubic, cut_gem, cyl, gem, lathe, leaf, plate, rgb, sphere, star, sweep, torus  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(REPO, "assets", "artifacts", "bow")
BOW_PARTS = ("Handle", "GripWrap", "LimbUpper", "LimbLower", "Fittings", "Ornament", "RuneInlay", "BowString")
ARROW_PARTS = ("ArrowShaft", "ArrowHead", "ArrowFletch")
AX, AZ = 0.16, 0.1  # arrow rest: beside the riser (+X), just above the hand
YZ = RZ(90)  # plate helper (local XZ, thickness Y) -> a plate in the YZ (side-on) plane, thickness X


def M(mat, r, g, b):
    return (mat, (r, g, b))


WOOD = dict(prof="rect", segs=8)
SPECS = [
    # T1 Common / Standard - PHYSICAL. Short curved yew bow, ash riser, waxed hemp string, horn nocks.
    dict(id="art_hunters_shortbow", tier=1, T=1.62, S=0.48, zr=0.4, r=0.1,
         limb=dict(w0=0.2, w1=0.1, t0=0.1, t1=0.06, reflex=0.05, recurve=0.12, **WOOD), riser="plain",
         wraps=[], tips="horn", orn=None, rune=None, string=0.016, arrow=dict(L=1.9, head="leaf"),
         col=dict(Handle=M("Wood", 178, 138, 92), GripWrap=M("Leather", 95, 62, 38), LimbUpper=M("Wood", 142, 94, 56), LimbLower=M("Wood", 142, 94, 56),
                  Fittings=M("Slate", 48, 42, 40), BowString=M("Fabric", 225, 215, 195),
                  ArrowShaft=M("Wood", 160, 120, 80), ArrowHead=M("Metal", 110, 112, 118), ArrowFletch=M("Fabric", 225, 220, 205))),
    # T1 Common / Enhanced - PHYSICAL. Tall D-profile yew longbow bound with tendon cordage; heavy field arrow.
    dict(id="art_reinforced_longbow", tier=1, T=2.05, S=0.55, zr=0.44, r=0.11,
         limb=dict(w0=0.22, w1=0.1, t0=0.13, t1=0.07, reflex=0.0, recurve=0.0, **WOOD), riser="plain",
         wraps=[0.18, 0.36, 0.55, 0.75], tips="cap", orn=None, rune=None, string=0.019, arrow=dict(L=2.1, head="bodkin"),
         col=dict(Handle=M("Wood", 120, 82, 50), GripWrap=M("Leather", 70, 48, 32), LimbUpper=M("Wood", 118, 78, 46), LimbLower=M("Wood", 118, 78, 46),
                  Fittings=M("Fabric", 205, 188, 150), BowString=M("Fabric", 215, 205, 180),
                  ArrowShaft=M("Wood", 140, 100, 64), ArrowHead=M("Metal", 95, 98, 105), ArrowFletch=M("Fabric", 70, 60, 52))),
    # T2 Uncommon / Standard - PHYSICAL. Slender pale-ash recurve with horn tips and falcon feathers.
    dict(id="art_recurve_composite", tier=2, T=1.85, S=0.5, zr=0.42, r=0.1,
         limb=dict(w0=0.2, w1=0.09, t0=0.1, t1=0.06, reflex=0.08, recurve=0.28, **WOOD), riser="carved",
         wraps=[0.04], tips="horn", orn="feathers", rune="pip", string=0.017, arrow=dict(L=1.95, head="leaf"),
         col=dict(Handle=M("Wood", 205, 182, 142), GripWrap=M("Leather", 105, 72, 45), LimbUpper=M("Wood", 210, 186, 146), LimbLower=M("Wood", 210, 186, 146),
                  Fittings=M("Slate", 52, 44, 40), Ornament=M("Fabric", 150, 110, 75), RuneInlay=M("Neon", 120, 230, 170), BowString=M("Fabric", 230, 222, 200),
                  ArrowShaft=M("Wood", 190, 160, 120), ArrowHead=M("Metal", 120, 122, 128), ArrowFletch=M("Fabric", 140, 100, 70))),
    # T2 Uncommon / Enhanced - PHYSICAL. Deeply reflexed composite bound in emerald silk, carved ivory riser tips.
    dict(id="art_gale_force_composite", tier=2, T=1.9, S=0.44, zr=0.44, r=0.105,
         limb=dict(w0=0.21, w1=0.09, t0=0.1, t1=0.06, reflex=0.26, recurve=0.32, **WOOD), riser="carved",
         wraps=[0.04, 0.2, 0.4, 0.62, 0.82], tips="horn", orn="ivory_tips", rune="limb_lines", string=0.017, arrow=dict(L=1.95, head="leaf"),
         col=dict(Handle=M("Wood", 92, 64, 44), GripWrap=M("Fabric", 40, 150, 92), LimbUpper=M("Wood", 112, 78, 50), LimbLower=M("Wood", 112, 78, 50),
                  Fittings=M("Fabric", 40, 150, 92), Ornament=M("SmoothPlastic", 236, 226, 200), RuneInlay=M("Neon", 60, 230, 140), BowString=M("Fabric", 230, 225, 205),
                  ArrowShaft=M("Wood", 120, 90, 60), ArrowHead=M("Metal", 140, 145, 150), ArrowFletch=M("Fabric", 40, 150, 92))),
    # T3 Rare / Standard - LIGHTNING. Tall elven recurve with storm-silver inlay and eagle-wing riser accents.
    dict(id="art_stormstrider_longbow", tier=3, T=2.2, S=0.55, zr=0.46, r=0.105,
         limb=dict(w0=0.2, w1=0.08, t0=0.11, t1=0.06, reflex=0.07, recurve=0.32, **WOOD), riser="carved",
         wraps=[0.04], tips="blade", orn="eagle_wings", rune="limb_lines", string=0.017, arrow=dict(L=2.05, head="leaf"),
         col=dict(Handle=M("Wood", 225, 220, 205), GripWrap=M("Leather", 60, 72, 92), LimbUpper=M("Wood", 214, 208, 192), LimbLower=M("Wood", 214, 208, 192),
                  Fittings=M("Metal", 192, 202, 218), Ornament=M("Metal", 200, 210, 225), RuneInlay=M("Neon", 160, 205, 255), BowString=M("Fabric", 225, 232, 245),
                  ArrowShaft=M("Wood", 220, 215, 200), ArrowHead=M("Metal", 200, 210, 225), ArrowFletch=M("Fabric", 230, 235, 245))),
    # T3 Rare / Enhanced - LIGHTNING. Dark recurve wrapped in coiled copper lightning wire with spark nodes.
    dict(id="art_thunderhead_recurve", tier=3, T=2.0, S=0.5, zr=0.44, r=0.11,
         limb=dict(w0=0.21, w1=0.09, t0=0.11, t1=0.06, reflex=0.08, recurve=0.3, **WOOD), riser="carved",
         wraps=[0.04], coils=True, tips="cap", orn="bolts", rune="sparks", string=0.017, arrow=dict(L=2.0, head="bodkin"),
         col=dict(Handle=M("Wood", 62, 56, 72), GripWrap=M("Leather", 40, 36, 46), LimbUpper=M("Wood", 70, 62, 80), LimbLower=M("Wood", 70, 62, 80),
                  Fittings=M("Metal", 200, 118, 62), Ornament=M("Metal", 215, 135, 70), RuneInlay=M("Neon", 255, 230, 90), BowString=M("Fabric", 230, 225, 210),
                  ArrowShaft=M("Wood", 70, 62, 80), ArrowHead=M("Metal", 200, 118, 62), ArrowFletch=M("Fabric", 255, 220, 90))),
    # T4 Superior / Standard - CRYSTAL. Towering mana-quartz greatbow with cerulean mana string.
    dict(id="art_crystal_greatbow", tier=4, T=2.35, S=0.6, zr=0.48, r=0.115,
         limb=dict(w0=0.3, w1=0.1, t0=0.17, t1=0.07, reflex=0.1, recurve=0.26, prof="lens", segs=6), riser="crystal",
         wraps=[0.04], tips="crystal", orn="crystal_cluster", rune="core_lines", string=0.022, arrow=dict(L=2.15, head="crystal"),
         col=dict(Handle=M("Glass", 95, 140, 210), GripWrap=M("Leather", 34, 44, 70), LimbUpper=M("Glass", 140, 200, 255), LimbLower=M("Glass", 140, 200, 255),
                  Fittings=M("Metal", 190, 200, 218), Ornament=M("Glass", 170, 220, 255), RuneInlay=M("Neon", 80, 190, 255), BowString=M("Neon", 90, 200, 255),
                  ArrowShaft=M("Metal", 190, 200, 218), ArrowHead=M("Glass", 140, 200, 255), ArrowFletch=M("Glass", 170, 220, 255))),
    # T4 Superior / Enhanced - CRYSTAL. Mechanical crystal-limbed greatbow with cam wheels and floating focus sights.
    dict(id="art_prismatic_arbalest", tier=4, T=2.15, S=0.62, zr=0.5, r=0.12,
         limb=dict(w0=0.22, w1=0.12, t0=0.12, t1=0.08, reflex=0.0, recurve=0.0, straight=True, prof="lens", segs=6), riser="frame",
         wraps=[0.03], tips="cams", orn="sights", rune="core_lines", string=0.02, arrow=dict(L=2.15, head="crystal"),
         col=dict(Handle=M("Metal", 120, 112, 150), GripWrap=M("Leather", 45, 38, 60), LimbUpper=M("Glass", 175, 150, 255), LimbLower=M("Glass", 175, 150, 255),
                  Fittings=M("Metal", 205, 195, 225), Ornament=M("Glass", 210, 170, 255), RuneInlay=M("Neon", 210, 140, 255), BowString=M("Neon", 220, 180, 255),
                  ArrowShaft=M("Metal", 205, 195, 225), ArrowHead=M("Glass", 210, 170, 255), ArrowFletch=M("Glass", 175, 150, 255))),
    # T5 Exalted / Standard - FIRE. Wide crimson-gold flat limbs sculpted as phoenix wings, layered flame feathers.
    dict(id="art_phoenix_flatbow", tier=5, T=2.3, S=0.55, zr=0.48, r=0.115,
         limb=dict(w0=0.32, w1=0.13, t0=0.075, t1=0.045, reflex=0.12, recurve=0.36, prof="rect", segs=8), riser="ornate",
         wraps=[0.04], tips="flame", orn="phoenix", rune="limb_lines", string=0.019, arrow=dict(L=2.15, head="flame"),
         col=dict(Handle=M("Metal", 238, 180, 62), GripWrap=M("Leather", 120, 28, 30), LimbUpper=M("Metal", 192, 42, 36), LimbLower=M("Metal", 192, 42, 36),
                  Fittings=M("Metal", 240, 185, 65), Ornament=M("Metal", 245, 150, 50), RuneInlay=M("Neon", 255, 140, 40), BowString=M("Fabric", 255, 220, 160),
                  ArrowShaft=M("Metal", 240, 185, 65), ArrowHead=M("Metal", 220, 60, 40), ArrowFletch=M("Metal", 245, 150, 50))),
    # T5 Exalted / Enhanced - CELESTIAL. Incandescent gold recurve with floating corona rings and a sun disc riser.
    dict(id="art_solar_flare_recurve", tier=5, T=2.25, S=0.56, zr=0.48, r=0.115,
         limb=dict(w0=0.24, w1=0.1, t0=0.11, t1=0.06, reflex=0.1, recurve=0.34, prof="rect", segs=8), riser="ornate",
         wraps=[0.04, 0.5], tips="flame", orn="corona", rune="limb_lines", string=0.019, arrow=dict(L=2.15, head="flame"),
         col=dict(Handle=M("Metal", 250, 225, 150), GripWrap=M("Leather", 150, 90, 40), LimbUpper=M("Metal", 250, 212, 118), LimbLower=M("Metal", 250, 212, 118),
                  Fittings=M("Metal", 255, 236, 170), Ornament=M("Metal", 255, 200, 90), RuneInlay=M("Neon", 255, 200, 80), BowString=M("Neon", 255, 235, 170),
                  ArrowShaft=M("Metal", 255, 236, 170), ArrowHead=M("Metal", 255, 200, 90), ArrowFletch=M("Metal", 255, 210, 120))),
    # T6 Legendary / Standard - CELESTIAL. White marble and polished gold, orbital ring sights, starlight string.
    dict(id="art_celestial_zenith", tier=6, T=2.4, S=0.6, zr=0.5, r=0.12,
         limb=dict(w0=0.24, w1=0.1, t0=0.12, t1=0.065, reflex=0.1, recurve=0.36, prof="rect", segs=10), riser="ornate",
         wraps=[0.04, 0.33, 0.66], trims=True, tips="blade", orn="orbits", rune="star_pips", string=0.02, arrow=dict(L=2.2, head="crystal"),
         col=dict(Handle=M("Marble", 242, 240, 234), GripWrap=M("Leather", 60, 75, 120), LimbUpper=M("Marble", 240, 238, 232), LimbLower=M("Marble", 240, 238, 232),
                  Fittings=M("Metal", 245, 200, 85), Ornament=M("Metal", 248, 210, 100), RuneInlay=M("Neon", 255, 238, 170), BowString=M("Neon", 232, 240, 255),
                  ArrowShaft=M("Metal", 245, 200, 85), ArrowHead=M("Glass", 225, 235, 255), ArrowFletch=M("Marble", 240, 238, 232))),
    # T6 Legendary / Enhanced - FIRE. Colossal cosmic recurve radiating stellar flares; plasma bolt.
    dict(id="art_supernova_greatbow", tier=6, T=2.55, S=0.66, zr=0.52, r=0.125,
         limb=dict(w0=0.27, w1=0.11, t0=0.13, t1=0.07, reflex=0.14, recurve=0.4, prof="rect", segs=10), riser="ornate",
         wraps=[0.04, 0.5], trims=True, tips="flare", orn="flares", rune="limb_lines", string=0.021, arrow=dict(L=2.25, head="flame"),
         col=dict(Handle=M("Metal", 60, 36, 95), GripWrap=M("Leather", 40, 24, 60), LimbUpper=M("Metal", 72, 42, 112), LimbLower=M("Metal", 72, 42, 112),
                  Fittings=M("Metal", 245, 190, 80), Ornament=M("Metal", 255, 150, 60), RuneInlay=M("Neon", 255, 120, 60), BowString=M("Neon", 255, 190, 120),
                  ArrowShaft=M("Metal", 245, 190, 80), ArrowHead=M("Glass", 255, 140, 70), ArrowFletch=M("Metal", 255, 150, 60))),
    # T7 Mythical / Standard - COSMIC. Astrea's stave of starlight constellation lines and star nodes.
    dict(id="art_astrea_cosmic_bow", tier=7, T=2.62, S=0.7, zr=0.5, r=0.12,
         limb=dict(w0=0.13, w1=0.06, t0=0.12, t1=0.06, reflex=0.12, recurve=0.38, prof="oval", segs=8, constellation=True), riser="star",
         wraps=[], tips="star", orn="stars", rune="star_nodes", string=0.022, arrow=dict(L=2.3, head="lance"),
         col=dict(Handle=M("Metal", 222, 230, 252), GripWrap=M("Leather", 40, 46, 90), LimbUpper=M("Glass", 175, 205, 255), LimbLower=M("Glass", 175, 205, 255),
                  Fittings=M("Metal", 222, 230, 252), Ornament=M("Metal", 235, 240, 255), RuneInlay=M("Neon", 205, 222, 255), BowString=M("Neon", 200, 220, 255),
                  ArrowShaft=M("Glass", 200, 220, 255), ArrowHead=M("Glass", 225, 235, 255), ArrowFletch=M("Glass", 175, 205, 255))),
    # T7 Mythical / Enhanced - COSMIC. Transcendent arc of floating limb segments, creation core, beam string.
    dict(id="art_infinity_genesis_bow", tier=7, T=2.72, S=0.72, zr=0.52, r=0.125,
         limb=dict(w0=0.26, w1=0.1, t0=0.13, t1=0.07, reflex=0.14, recurve=0.4, prof="lens", segs=10, gaps=3), riser="core",
         wraps=[], tips="flare", orn="genesis", rune="limb_lines", string=0.032, arrow=dict(L=2.3, head="lance"),
         col=dict(Handle=M("Metal", 40, 30, 60), GripWrap=M("Leather", 30, 22, 44), LimbUpper=M("Metal", 46, 34, 70), LimbLower=M("Metal", 46, 34, 70),
                  Fittings=M("Metal", 250, 210, 110), Ornament=M("Metal", 250, 215, 130), RuneInlay=M("Neon", 255, 222, 140), BowString=M("Neon", 255, 242, 205),
                  ArrowShaft=M("Metal", 250, 210, 110), ArrowHead=M("Glass", 255, 230, 170), ArrowFletch=M("Glass", 200, 150, 255))),
]


# --------------------------------------------------------------------------------------
# Limb geometry
# --------------------------------------------------------------------------------------
def limb_path(spec, sign, n=24):
    """Centre line of one limb from inside the riser to the tip (upper: sign=+1)."""
    L, zr, Tt, S = spec["limb"], spec["zr"], spec["T"], spec["S"]
    rf, rc = L.get("reflex", 0.0), L.get("recurve", 0.0)
    span = Tt - zr
    if L.get("straight"):
        pts = [V3(0, 0, zr - 0.08), V3(0, -S * 0.25, zr + span * 0.35), V3(0, -S * 0.7, zr + span * 0.75), V3(0, -S, Tt)]
        main = cubic(*pts, 18)
    else:
        main = cubic(V3(0, 0, zr - 0.08), V3(0, rf, zr + span * 0.36), V3(0, -S * 0.55 - rf * 0.3, zr + span * 0.8), V3(0, -S, Tt), 18)
    if rc > 0:
        main += bezier(V3(0, -S, Tt), V3(0, -S - 0.07, Tt + rc * 0.55), V3(0, -S + rc * 0.7, Tt + rc * 0.82), 7)[1:]
    pts = K.resample(main, n)
    return [V3(p.x, p.y, sign * p.z) for p in pts]


def frame_at(path, i, side=Vector((1, 0, 0))):
    n = len(path)
    tan = (path[min(n - 1, i + 1)] - path[max(0, i - 1)]).normalized()
    sd = (side - tan * side.dot(tan)).normalized()
    nm = tan.cross(sd).normalized()
    return tan, sd, nm


def ring_at(part, path, i, a, b, tube, n=14):
    """Oval band around the limb at path[i] (a = half width along X, b = half depth)."""
    tan, sd, nm = frame_at(path, i)
    Mx = Matrix((
        (sd.x, nm.x, tan.x, path[i].x),
        (sd.y, nm.y, tan.y, path[i].y),
        (sd.z, nm.z, tan.z, path[i].z),
        (0, 0, 0, 1),
    ))
    torus(part, 1.0, tube, n, 6, Mx, sx=a, sy=b)


def build_limbs(spec, parts, rng):
    L = spec["limb"]
    out = {}
    for sign, name in ((1, "LimbUpper"), (-1, "LimbLower")):
        path = limb_path(spec, sign)
        n = len(path)
        widths = [L["w0"] + (L["w1"] - L["w0"]) * (i / (n - 1)) ** 0.8 for i in range(n)]
        thicks = [L["t0"] + (L["t1"] - L["t0"]) * (i / (n - 1)) for i in range(n)]
        P = parts[name]
        if L.get("gaps"):  # floating segments
            k = L["gaps"]
            cuts = [int(round((n - 1) * j / k)) for j in range(k + 1)]
            for j in range(k):
                a, b = cuts[j] + (2 if j else 0), cuts[j + 1] - (1 if j < k - 1 else 0)
                sweep(P, path[a:b + 1], widths[a:b + 1], thicks[a:b + 1], segs=L["segs"], profile=L["prof"])
        else:
            sweep(P, path, widths, thicks, segs=L["segs"], profile=L["prof"])
        if L.get("constellation"):  # second star line zig-zagging in front of the main stave
            nodes = [path[2]] + [path[i] + Vector((0, 0.24 * (1 if i % 2 else -0.3), 0)) for i in range(5, n - 3, 3)] + [path[n - 3]]
            for a, b in zip(nodes, nodes[1:]):
                cyl(P, a, b, 0.032, 0.032, 6)
            out[name + "_nodes"] = nodes
        out[name] = (path, widths, thicks)
    return out


# --------------------------------------------------------------------------------------
# Riser, grip, shelf
# --------------------------------------------------------------------------------------
def build_riser(spec, parts, rng):
    zr, r, tier = spec["zr"], spec["r"], spec["tier"]
    H = parts["Handle"]
    kind = spec["riser"]
    segs = 10 + tier
    if kind == "plain":
        lathe(H, [(r * 0.75, -zr), (r, -zr + 0.12), (r * 0.92, 0), (r, zr - 0.12), (r * 0.75, zr)], segs, sx=0.82, sy=1.15)
    elif kind in ("carved", "ornate"):
        prof = [(r * 0.7, -zr - 0.03), (r * 1.15, -zr + 0.1), (r * 0.95, -0.3), (r * 0.9, 0), (r * 1.05, 0.18), (r * 1.25, zr - 0.12), (r * 0.7, zr + 0.03)]
        lathe(H, prof, segs, sx=0.82, sy=1.25)
        if kind == "ornate":  # sculpted sight window plates on the riser belly/back
            for s in (1, -1):
                plate(H, [V2(-0.05, s * 0.1), V2(0.14 + 0.01 * tier, s * 0.32), V2(0.02, s * (zr - 0.02))], 0.06, 0.02, YZ @ T(0, 0, 0))
    elif kind == "crystal":
        lathe(H, [(r * 0.7, -zr), (r * 1.1, -zr + 0.12), (r * 0.95, 0), (r * 1.1, zr - 0.12), (r * 0.7, zr)], 6, sx=0.85, sy=1.2)
    elif kind == "frame":  # mechanical riser: core with side frame plates
        lathe(H, [(r * 0.8, -zr), (r, -zr + 0.1), (r, zr - 0.1), (r * 0.8, zr)], 8, sx=0.8, sy=1.3)
        for y in (0.13, -0.13):
            box(H, (0, y, 0), (0.06, 0.05, zr * 1.7))
        box(H, (0, 0.24, 0.12), (0.08, 0.3, 0.08))  # forward stock rail under the arrow line
    elif kind == "star":
        lathe(H, [(r * 0.7, -zr), (r, -zr + 0.12), (r * 0.9, 0), (r, zr - 0.12), (r * 0.7, zr)], segs, sx=0.82, sy=1.15)
        plate(H, star(0.0, 0.32, 0.36, 0.1, 4, math.pi / 2), 0.06, 0.03, YZ @ T(0, 0, 0))
    elif kind == "core":
        lathe(H, [(r * 0.75, -zr), (r, -zr + 0.12), (r * 0.9, -0.1), (r * 0.9, 0.1), (r, zr - 0.12), (r * 0.75, zr)], segs, sx=0.82, sy=1.15)
    # arrow shelf on the +X side, just under the arrow line
    box(H, (AX * 0.6, 0.02, AZ - 0.045), (AX * 0.9, 0.2, 0.04))

    G = parts["GripWrap"]
    prof, ribs = [], 6 + tier
    za, zb = -0.28, 0.04
    prof.append((r * 0.9, za - 0.02))
    for i in range(ribs * 2 + 1):
        prof.append((r * (1.06 if i % 2 else 0.99), za + (zb - za) * i / (ribs * 2)))
    prof.append((r * 0.9, zb + 0.02))
    lathe(G, prof, max(10, segs), sx=0.86, sy=1.18)


# --------------------------------------------------------------------------------------
# Fittings, tips, ornaments, runes
# --------------------------------------------------------------------------------------
def build_fittings(spec, parts, limbs, rng):
    F, R, O = parts["Fittings"], parts["RuneInlay"], parts["Ornament"]
    L, tier = spec["limb"], spec["tier"]
    S, Tt = spec["S"], spec["T"]
    for name in ("LimbUpper", "LimbLower"):
        path, widths, thicks = limbs[name]
        n = len(path)
        for f in spec["wraps"]:
            i = max(1, int(round(f * (n - 1))))
            ring_at(F, path, i, widths[i] / 2 + 0.012, thicks[i] / 2 + 0.012, 0.03, 16)
            if f > 0.1:
                ring_at(F, path, min(n - 1, i + 1), widths[i] / 2 + 0.01, thicks[i] / 2 + 0.01, 0.025, 16)
        if spec.get("coils"):  # copper wire wound round the limb
            coil = []
            for k in range(120):
                s = 0.08 + 0.75 * k / 119
                fi = s * (n - 1)
                i = int(fi)
                p = path[i].lerp(path[min(n - 1, i + 1)], fi - i)
                tan, sd, nm = frame_at(path, i)
                a = k * 0.55
                coil.append(p + sd * (widths[i] / 2 + 0.02) * math.cos(a) + nm * (thicks[i] / 2 + 0.02) * math.sin(a))
            sweep(F, coil, 0.022, 0.022, segs=5, profile="oval")
        if spec.get("trims"):  # gold edge trim along both edges of the limb
            for side in (1, -1):
                trim = []
                for i in range(2, n - 2):
                    tan, sd, nm = frame_at(path, i)
                    trim.append(path[i] + sd * side * widths[i] / 2)
                sweep(F, trim, 0.035, max(thicks) * 0.6, segs=6, profile="oval")

        # Tip: string anchor point and tip ornament
        sign = 1 if name == "LimbUpper" else -1
        anchor = V3(0, -S, sign * Tt)
        tip = path[-1]
        tan, sd, nm = frame_at(path, n - 1)
        kind = spec["tips"]
        if kind == "horn":
            cyl(F, path[-3], tip + tan * 0.12, widths[-3] * 0.4, 0.015, 8)
        elif kind == "cap":
            cyl(F, anchor - tan * 0.12, tip + tan * 0.08, widths[-1] * 0.6, 0.02, 8)
        elif kind == "blade":  # leaf blade tip
            cyl(F, path[-3], tip, widths[-3] * 0.35, 0.03, 8)
            plate(F, leaf(V2(tip.y, tip.z), math.atan2(tan.z, tan.y), 0.32, 0.12, 6), 0.035, 0.015, YZ)
        elif kind == "crystal":
            gem(F, tuple(tip), 0.05, 0.36, 6, I4, (math.atan2(-tan.y, tan.z), 0))
        elif kind == "cams":
            for c in (anchor,):
                Mx = T(*c) @ RY(90)
                torus(F, 0.13, 0.03, 20, 6, Mx)
                lathe(F, [(0, -0.03), (0.12, -0.03), (0.12, 0.03), (0, 0.03)], 16, Mx)
                sphere(R, tuple(c), 0.04, 8, 5)
            cyl(F, tip, anchor, 0.035, 0.035, 6)
        elif kind == "flame":  # flame-licked tip
            for k, (ang, ln) in enumerate(((0, 0.36), (35, 0.24), (-30, 0.22))):
                a = math.atan2(tan.z, tan.y) + math.radians(ang) * sign
                plate(O, leaf(V2(tip.y, tip.z), a, ln, 0.1, 6), 0.03, 0.012, YZ)
        elif kind == "flare":
            plate(O, K.star(tip.y, tip.z, 0.3, 0.07, 6), 0.04, 0.015, YZ)
            sphere(R, tuple(tip), 0.05, 8, 5)
        elif kind == "star":
            plate(O, K.star(tip.y, tip.z, 0.34, 0.08, 4), 0.06, 0.022, YZ)
            gem(R, tuple(tip), 0.04, 0.12, 4, I4, (0, math.pi / 2))
        # nock groove ring where the string ties on
        if kind != "cams":
            sphere(F, tuple(anchor), 0.035 + 0.003 * tier, 8, 5)


def build_ornaments(spec, parts, limbs, rng):
    O, R, F = parts["Ornament"], parts["RuneInlay"], parts["Fittings"]
    kind, tier, zr, S, Tt = spec.get("orn"), spec["tier"], spec["zr"], spec["S"], spec["T"]
    up, lo = limbs["LimbUpper"][0], limbs["LimbLower"][0]
    if kind == "feathers":  # falcon feathers hung from the lower limb collar
        base = lo[1]
        for k in range(3):
            a = math.radians(-100 + 14 * k)
            plate(O, leaf(V2(base.y + 0.06, base.z), a, 0.42 - 0.06 * k, 0.12, 6), 0.025, 0.01, YZ @ T(0.05 + 0.025 * k, 0, 0))
        cyl(O, V3(0.05, base.y, base.z + 0.04), V3(0.05, base.y + 0.06, base.z - 0.04), 0.012, 0.012, 5)
    elif kind == "ivory_tips":  # carved ivory caps at both riser ends, curling forward
        for s in (1, -1):
            path = [V3(0, 0.02, s * (zr - 0.06)), V3(0, 0.16, s * (zr + 0.04)), V3(0, 0.24, s * (zr - 0.06)), V3(0, 0.2, s * (zr - 0.16))]
            sweep(O, K.resample(cubic(*path, 10), 10), [0.14 - 0.01 * i for i in range(11)], [0.1 - 0.006 * i for i in range(11)], segs=8, profile="oval")
    elif kind == "eagle_wings":  # wing plates fanning up and back from the riser's front
        for s in (1, -1):
            for k, (ang, ln, wd) in enumerate(((70, 0.62, 0.17), (50, 0.52, 0.15), (30, 0.4, 0.12))):
                a = math.radians(ang) if s > 0 else -math.radians(ang)
                base = V2(0.06, s * (zr - 0.14))
                plate(O, leaf(base, math.pi / 2 - a if s > 0 else -math.pi / 2 - a, ln, wd, 7), 0.035, 0.014, YZ @ T(0, 0.03 * (k - 1), 0))
    elif kind == "bolts":  # zig-zag lightning prongs off the riser ends
        for s in (1, -1):
            z0 = s * (zr - 0.05)
            pts = [V2(0.05, z0), V2(0.28, z0 + s * 0.16), V2(0.2, z0 + s * 0.2), V2(0.42, z0 + s * 0.42), V2(0.16, z0 + s * 0.14), V2(0.24, z0 + s * 0.1)]
            plate(O, pts, 0.04, 0.015, YZ)
            sphere(R, (0, 0.42, z0 + s * 0.42), 0.04, 8, 5)
    elif kind == "crystal_cluster":
        for k in range(7):
            a = 2 * math.pi * k / 7
            gem(O, (0.06 * math.cos(a), 0.08 + 0.03 * math.sin(a), 0.32 + 0.05 * (k % 3)), 0.05, 0.36 - 0.04 * (k % 3), 6, I4,
                (-math.radians(55) + 0.3 * math.sin(a), 0.4 * math.cos(a)))
        for k in range(5):
            a = 2 * math.pi * k / 5
            gem(O, (0.05 * math.cos(a), 0.06, -0.38 - 0.03 * (k % 2)), 0.045, 0.28, 6, I4, (math.pi + math.radians(50) + 0.3 * math.sin(a), 0.4 * math.cos(a)))
        for path in (up, lo):
            for i in range(4, len(path) - 5, 3):
                tan, sd, nm = frame_at(path, i)
                d = nm if nm.y > 0 else -nm
                gem(O, tuple(path[i] + d * 0.04), 0.045, 0.3 - 0.01 * i, 5, I4, (math.atan2(-d.y, d.z) + 0.25, 0))
    elif kind == "sights":  # floating focus ring on the arrow line + crystal lens
        c = V3(AX, 0.55, AZ)
        torus(O, 0.16, 0.025, 24, 6, T(*c) @ RX(90))
        torus(O, 0.1, 0.015, 20, 5, T(*c) @ RX(90))
        gem(R, (AX, 0.55, AZ + 0.32), 0.04, 0.14, 5)
        for s in (1, -1):
            gem(O, (AX, 0.55, AZ + s * 0.24), 0.04, 0.16, 4, I4, (0 if s > 0 else math.pi, 0))
    elif kind == "phoenix":  # flame feathers trailing back off both limbs
        for path in (up, lo):
            sign = 1 if path[-1].z > 0 else -1
            for k, i in enumerate(range(3, len(path) - 4, 3)):
                p = path[i]
                tan, sd, nm = frame_at(path, i)
                a = math.atan2(tan.z, tan.y) + sign * math.radians(70 + 6 * k)
                ln = 0.55 - 0.04 * k
                plate(O, leaf(V2(p.y, p.z), a, ln, 0.16, 7), 0.03, 0.012, YZ @ T(0, 0, 0))
        plate(O, leaf(V2(0.05, 0.3), math.radians(70), 0.4, 0.2, 7), 0.05, 0.02, YZ)  # crest
        gem(R, (0, 0.12, 0.36), 0.05, 0.16, 6, I4, (-math.pi / 2, 0))
    elif kind == "corona":  # sun disc on the riser + floating corona rings
        plate(O, K.star(0.18, 0.0, 0.42, 0.24, 12, 0), 0.04, 0.015, YZ @ T(0, 0, 0))
        for k, (rr, tilt) in enumerate(((0.55, 18), (0.68, -24))):
            torus(O, rr, 0.025, 36, 6, T(0, 0.1, 0) @ RY(90) @ RX(tilt))
        for path in (up, lo):
            ring_at(F, path, len(path) - 6, 0.13, 0.1, 0.02, 18)
    elif kind == "orbits":
        for k, (rr, tx, ty) in enumerate(((0.5, 24, 0), (0.6, -20, 30))):
            torus(O, rr, 0.022, 36, 6, T(0, 0.05, 0.05) @ RY(90) @ RX(tx) @ RZ(ty))
        torus(O, 0.12, 0.018, 20, 5, T(AX, 0.62, AZ) @ RX(90))
    elif kind == "flares":
        for path in (up, lo):
            for i in range(4, len(path) - 4, 4):
                p = path[i]
                tan, sd, nm = frame_at(path, i)
                d = nm * (1 if nm.y > 0 else -1)
                plate(O, [V2(p.y - 0.06 * tan.y, p.z - 0.06 * tan.z), V2(p.y + d.y * 0.42, p.z + d.z * 0.42), V2(p.y + 0.06 * tan.y, p.z + 0.06 * tan.z)], 0.035, 0.012, YZ)
        plate(O, K.star(0.16, 0.0, 0.5, 0.14, 8, 0), 0.05, 0.02, YZ)
        sphere(R, (0, 0.16, 0), 0.09, 10, 6)
    elif kind == "stars":
        for name in ("LimbUpper_nodes", "LimbLower_nodes"):
            for i, p in enumerate(limbs.get(name, [])):
                plate(O, K.star(p.y, p.z, 0.14 + 0.05 * (i % 2), 0.045, 4), 0.05, 0.018, YZ)
        plate(O, K.star(0.2, 0.0, 0.62, 0.14, 8, 0), 0.06, 0.022, YZ)
        torus(O, 0.42, 0.025, 36, 6, T(0, 0.2, 0) @ RY(90))
    elif kind == "genesis":  # creation core + rings around the limb gaps
        sphere(R, (-0.07, 0.3, 0), 0.17, 16, 10)  # kept off the arrow line (x = AX)
        for tilt in (0, 60, -60):
            torus(O, 0.34, 0.024, 36, 6, T(-0.07, 0.3, 0) @ RX(tilt) @ RY(90))
        torus(O, 0.62, 0.03, 44, 6, T(0, 0.12, 0) @ RY(90))
        for path in (up, lo):
            n = len(path)
            for j in (1, 2):
                i = int(round((n - 1) * j / 3)) + 1
                ring_at(O, path, i, 0.24, 0.2, 0.026, 22)
                ring_at(R, path, i, 0.3, 0.26, 0.012, 22)
            for i in range(4, n - 4, 5):
                tan, sd, nm = frame_at(path, i)
                d = nm if nm.y > 0 else -nm
                gem(O, tuple(path[i] + d * 0.3), 0.04, 0.2, 4, I4, (math.atan2(-d.y, d.z), 0.3))


def build_runes(spec, parts, limbs, rng):
    R, kind = parts["RuneInlay"], spec.get("rune")
    if not kind:
        return
    for name in ("LimbUpper", "LimbLower"):
        path, widths, thicks = limbs[name]
        n = len(path)
        if kind in ("limb_lines", "core_lines"):
            for face in ((1, -1) if kind == "limb_lines" else (0,)):
                line = []
                for i in range(3, n - 5):
                    tan, sd, nm = frame_at(path, i)
                    line.append(path[i] + nm * face * (thicks[i] / 2 + 0.004))
                if kind == "core_lines":
                    sweep(R, line, [widths[i] * 0.3 for i in range(3, n - 5)], [thicks[i] * 0.55 for i in range(3, n - 5)], segs=6, profile="lens")
                else:
                    sweep(R, line, [widths[i] * 0.28 for i in range(3, n - 5)], 0.016, segs=4, profile="oval")
        elif kind == "sparks":
            for i in (5, 11, 17):
                sphere(R, tuple(path[i]), max(widths[i], thicks[i]) * 0.5 + 0.035, 8, 5)
        elif kind == "star_pips":
            for i in range(4, n - 4, 4):
                tan, sd, nm = frame_at(path, i)
                for face in (1, -1):
                    gem(R, tuple(path[i] + nm * face * thicks[i] / 2), 0.03, 0.08, 4, I4, (0, 0))
        elif kind == "star_nodes":
            for p in limbs.get(name + "_nodes", []):
                sphere(R, tuple(p), 0.04, 8, 5)
    if kind == "pip":
        cut_gem(R, (0, 0, 0), 0.04, 0.03, 6, T(0, 0.135, 0.12) @ RX(-90))


# --------------------------------------------------------------------------------------
# String and arrow
# --------------------------------------------------------------------------------------
def build_string(spec, parts):
    S, Tt = spec["S"], spec["T"]
    cyl(parts["BowString"], V3(0, -S, -Tt), V3(0, -S, Tt), spec["string"], spec["string"], 6)


def build_arrow(spec, parts):
    a, S, tier = spec["arrow"], spec["S"], spec["tier"]
    La = a["L"]
    y0, y1 = -S, -S + La
    sh = parts["ArrowShaft"]
    r = 0.022 + 0.002 * tier
    cyl(sh, V3(AX, y0 - 0.02, AZ), V3(AX, y1, AZ), r, r, 8)
    lathe(sh, [(0, -0.04), (r * 1.4, 0), (r * 1.3, 0.06), (r, 0.08)], 8, T(AX, y0, AZ) @ RX(-90))  # nock
    Hd = parts["ArrowHead"]
    Mh = T(AX, y1, AZ) @ RX(-90)  # local +Z = flight direction (+Y)
    kind = a["head"]
    if kind == "leaf":
        lathe(Hd, [(r * 1.2, -0.05), (0.07, 0.08), (0.05, 0.18), (0, 0.28)], 4, Mh, sy=0.35)
    elif kind == "bodkin":
        lathe(Hd, [(r * 1.4, -0.06), (0.06, 0.04), (0.045, 0.2), (0, 0.34)], 4, Mh, phase=math.pi / 4)
    elif kind == "crystal":
        gem(Hd, (0, 0, 0.12), 0.07, 0.5, 6, Mh)
    elif kind == "flame":
        lathe(Hd, [(r * 1.4, -0.06), (0.1, 0.1), (0.06, 0.24), (0, 0.4)], 6, Mh, sy=0.4)
        for s in (1, -1):
            plate(Hd, leaf(V2(0.02 * s, 0.06), math.radians(90 - 50 * s), 0.18, 0.06, 5), 0.02, 0.008, Mh @ RX(90))
    elif kind == "lance":
        lathe(Hd, [(r * 1.4, -0.06), (0.06, 0.02), (0.035, 0.36), (0, 0.55)], 6, Mh)
        torus(Hd, 0.1, 0.014, 18, 5, Mh @ T(0, 0, 0.08))
    Fl = parts["ArrowFletch"]
    for k in range(3):
        ang = 90 + 120 * k  # radial direction about the shaft, in the XZ plane
        Mv = T(AX, y0 + 0.08, AZ) @ RY(-ang + 90) @ RZ(90)
        pts = [V2(0, r), V2(0.06, r + 0.08 + 0.005 * tier), V2(0.34, r + 0.05), V2(0.4, r)]
        plate(Fl, pts, 0.012, 0.004, Mv)


# --------------------------------------------------------------------------------------
# Assembly
# --------------------------------------------------------------------------------------
def build_weapon(spec):
    rng = random.Random(sum(ord(c) * (i + 1) for i, c in enumerate(spec["id"])))
    parts = {n: Part() for n in BOW_PARTS + ARROW_PARTS}
    build_riser(spec, parts, rng)
    limbs = build_limbs(spec, parts, rng)
    build_fittings(spec, parts, limbs, rng)
    build_ornaments(spec, parts, limbs, rng)
    build_runes(spec, parts, limbs, rng)
    build_string(spec, parts)
    build_arrow(spec, parts)
    S, Tt = spec["S"], spec["T"]
    info = dict(
        id=spec["id"], tier=spec["tier"], type="BOW",
        grip=[0, 0, 0], nock=[AX, -S, AZ], tip_upper=[0, -S, Tt], tip_lower=[0, -S, -Tt], core=[0, 0.05, 0],
        arrow_tip=[AX, -S + spec["arrow"]["L"], AZ],
    )
    return parts, info


def main():
    opts = K.parse_args(sys.argv)
    only = set(opts["only"].split(",")) if "only" in opts else None
    K.clear_scene()
    K.ensure_dir(OUT_DIR)
    manifest, built = {}, 0
    spacing = 2.6
    for spec in SPECS:
        if only and spec["id"] not in only:
            continue
        parts, info = build_weapon(spec)
        colours = {name: rgb(*c[1]) for name, c in spec["col"].items()}
        objs, tris, pinfo = K.realise(spec["id"], parts, colours)
        K.export_fbx(os.path.join(OUT_DIR, spec["id"] + ".fbx"), objs)
        for o in objs:  # contact sheet: side-on (looking along -X), bows in a row along Y
            o.matrix_world = T(0, built * spacing, 0)
            o.name = f"{spec['id']}_{o.name}"
        info["parts"] = {n: dict(centre=K.r3(c), size=K.r3(s), assembly="HunterArrow" if n in ARROW_PARTS else "",
                                 material=spec["col"].get(n, ("Metal", (150, 150, 150)))[0], color=list(spec["col"].get(n, ("Metal", (150, 150, 150)))[1]))
                         for n, (c, s) in pinfo.items()}
        info["tris"] = tris
        manifest[spec["id"]] = info
        print(f"[bow] {spec['id']:32s} tier {spec['tier']} tris {tris:6d} parts {len(pinfo)}")
        built += 1
    if not only:
        K.write_json(os.path.join(OUT_DIR, "bows_manifest.json"), manifest)
    if "preview" in opts:
        width = built * spacing + 0.6
        K.render_sheet(opts["preview"], (30, width / 2 - 1.0, 0.0), (90, 0, 90), width, 3600, int(3600 * 6.4 / width))


main()
