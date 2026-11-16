"""
Infinite Tower: Become a Master! - Vanguard sword & shield artifacts (SWORD_SHIELD remodel).

Builds all 14 launch sword-and-shield artifacts as separate semantic parts and exports one FBX
per artifact to assets/artifacts/sword_shield/, plus sword_shield_manifest.json (part centres,
socket points, materials, triangle counts) that tests/studio-sword-shield-import.luau reads.

    Sword:          Handle, Pommel, Crossguard, Blade, BladeEdge, Fuller, RuneInlay
    OffhandShield:  HandleS, ShieldPlate, ShieldRim, ShieldBoss, ShieldRune

Run headless:
    blender --background --factory-startup --python tools/blender/generate_vanguard_swords.py -- [--preview <png>] [--only id,id]

Authoring frame (1 Blender unit = 1 stud). Roblox Handle space = (bx, bz, -by):
    sword grip centred on the origin along +Z, blade up +Z, blade width along X (edge +X),
    blade flats facing +/-Y.  Roblox: blade +Y, edge +X  -> Grip uses EDGE_PLUS_X.
    shield authored around SHIELD_ORIGIN: face towards -X, top +Z, width along Y.
    Roblox (HandleS space): face -X, top +Y, width Z  -> ShieldMount at (-0.18, 0, 0), rot (0, 90, 0).
"""

import math
import os
import random
import sys

from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit as K  # noqa: E402
from weapon_kit import I4, RX, RY, RZ, T, V2, V3, Part, bezier, box, cut_gem, cyl, edge_strip, face_gem, gem, inset_poly, lathe, leaf, mirror_u, ngon, plate, polyline, rgb, sphere, star, stroke, sweep, torus  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_DIR = os.path.join(REPO, "assets", "artifacts", "sword_shield")
SHIELD_ORIGIN = Vector((0.0, 2.4, 0.4))
SWORD_PARTS = ("Handle", "Pommel", "Crossguard", "Blade", "BladeEdge", "Fuller", "RuneInlay")
SHIELD_PARTS = ("HandleS", "ShieldPlate", "ShieldRim", "ShieldBoss", "ShieldRune")


def M(mat, r, g, b):
    return (mat, (r, g, b))


# --------------------------------------------------------------------------------------
# Specs: one entry per artifact (design brief in the comment above each)
# --------------------------------------------------------------------------------------
SPECS = [
    # T1 Common / Standard - PHYSICAL. Cast-grey iron broadsword, hammered fuller, wooden heater
    # shield with iron corner bands. Silhouette: plain cruciform sword + flat-topped heater.
    dict(id="art_iron_broadsword", tier=1,
         grip=dict(L=0.86, r=0.095, ribs=5), pommel="ball", guard=dict(kind="bar", span=0.6, h=0.13),
         blade=dict(L=2.7, w=0.2, t=0.075, taper=0.16, tf=0.15, tipc=0.9, ric=0.08, fuller=0.62, dents=True),
         rune=None,
         shield=dict(kind="heater", W=1.5, H=2.0, t=0.13, k=0.1, rim="bands", boss="dome", planks=True),
         col=dict(Handle=M("Leather", 75, 52, 38), Pommel=M("Metal", 98, 101, 108), Crossguard=M("Metal", 95, 98, 105),
                  Blade=M("Metal", 150, 154, 162), BladeEdge=M("Metal", 192, 197, 207), Fuller=M("Metal", 108, 111, 119),
                  HandleS=M("Leather", 70, 50, 36), ShieldPlate=M("WoodPlanks", 122, 86, 52), ShieldRim=M("Metal", 85, 88, 95),
                  ShieldBoss=M("Metal", 115, 118, 125))),
    # T1 Common / Enhanced - PHYSICAL. Hand-and-a-half carbon-steel blade, fluted flared guard,
    # fishtail pommel, steel buckler with radial straps and spike boss.
    dict(id="art_tempered_bastard_sword", tier=1,
         grip=dict(L=1.08, r=0.09, ribs=7), pommel="fishtail", guard=dict(kind="fluted", span=0.7, h=0.14),
         blade=dict(L=2.95, w=0.185, t=0.075, taper=0.3, tf=0.18, tipc=0.95, ric=0.1, waist=0.06, fuller=0.7),
         rune=None,
         shield=dict(kind="round", W=1.45, H=1.45, t=0.11, k=0.16, kz=0.16, rim="tube", boss="spike", spokes=6),
         col=dict(Handle=M("Fabric", 55, 42, 35), Pommel=M("Metal", 185, 145, 65), Crossguard=M("Metal", 88, 92, 102),
                  Blade=M("Metal", 88, 93, 104), BladeEdge=M("Metal", 198, 205, 218), Fuller=M("Metal", 62, 66, 76),
                  HandleS=M("Leather", 60, 44, 34), ShieldPlate=M("Metal", 132, 137, 147), ShieldRim=M("Metal", 185, 145, 65),
                  ShieldBoss=M("Metal", 160, 165, 175))),
    # T2 Uncommon / Standard - PHYSICAL. Cobalt knightly longsword, swept quillons, wheel pommel,
    # emerald rune grooves in the fuller; tall runic pavise with a central ridge.
    dict(id="art_runic_longsword", tier=2,
         grip=dict(L=0.92, r=0.09, ribs=6), pommel="wheel", guard=dict(kind="swept", span=0.66, h=0.14),
         blade=dict(L=3.15, w=0.18, t=0.075, taper=0.32, tf=0.17, tipc=0.9, ric=0.08, fuller=0.72),
         rune="glyphs",
         shield=dict(kind="pavise", W=1.3, H=2.4, t=0.14, k=0.14, rim="tube", boss="ridge", runes="pavise"),
         col=dict(Handle=M("Leather", 34, 40, 52), Pommel=M("Metal", 70, 82, 105), Crossguard=M("Metal", 70, 82, 105),
                  Blade=M("Metal", 122, 140, 172), BladeEdge=M("Metal", 205, 215, 232), Fuller=M("Metal", 66, 80, 112),
                  RuneInlay=M("Neon", 60, 230, 140),
                  HandleS=M("Leather", 40, 44, 54), ShieldPlate=M("Metal", 92, 108, 140), ShieldRim=M("Metal", 160, 170, 190),
                  ShieldBoss=M("Metal", 118, 132, 160), ShieldRune=M("Neon", 60, 230, 140))),
    # T2 Uncommon / Enhanced - PHYSICAL. Needle estoc with a triangular (diamond) section and a
    # full basket hilt; convex teardrop kite shield with brass rim.
    dict(id="art_knightly_estoc", tier=2,
         grip=dict(L=0.9, r=0.085, ribs=8), pommel="pear", guard=dict(kind="basket", span=0.42, h=0.12),
         blade=dict(L=3.35, w=0.11, t=0.13, taper=1.0, tf=0.0, tipc=1.0, ric=0.06, diamond=True),
         rune="ridge",
         shield=dict(kind="kite", W=1.3, H=2.35, t=0.13, k=0.2, rim="tube", boss="dome", runes="cross"),
         col=dict(Handle=M("Leather", 60, 30, 32), Pommel=M("Metal", 195, 160, 80), Crossguard=M("Metal", 62, 64, 72),
                  Blade=M("Metal", 210, 214, 224), BladeEdge=M("Metal", 235, 238, 245), RuneInlay=M("Neon", 120, 210, 255),
                  HandleS=M("Leather", 60, 30, 32), ShieldPlate=M("Metal", 150, 40, 48), ShieldRim=M("Metal", 200, 165, 85),
                  ShieldBoss=M("Metal", 200, 165, 85), ShieldRune=M("Neon", 120, 210, 255))),
    # T3 Rare / Standard - CELESTIAL. Chivalric spatha with parallel edges and a rounded point,
    # winged crossguard, sun pommel; white heater shield with a gold sun crest.
    dict(id="art_paladin_spatha", tier=3,
         grip=dict(L=0.9, r=0.092, ribs=6), pommel="sun", guard=dict(kind="winged", span=0.62, h=0.15),
         blade=dict(L=3.35, w=0.2, t=0.08, taper=0.06, tf=0.13, tipc=0.55, ric=0.08, fuller=0.75),
         rune="line",
         shield=dict(kind="heater", W=1.6, H=2.3, t=0.14, k=0.12, rim="tube", boss="sun", runes="sun_ring"),
         col=dict(Handle=M("Leather", 235, 230, 220), Pommel=M("Metal", 230, 185, 75), Crossguard=M("Metal", 225, 230, 240),
                  Blade=M("Metal", 205, 210, 222), BladeEdge=M("Metal", 240, 242, 248), Fuller=M("Metal", 225, 182, 80),
                  RuneInlay=M("Neon", 255, 205, 90),
                  HandleS=M("Leather", 120, 90, 60), ShieldPlate=M("SmoothPlastic", 232, 230, 224), ShieldRim=M("Metal", 230, 185, 75),
                  ShieldBoss=M("Metal", 235, 190, 80), ShieldRune=M("Neon", 255, 205, 90))),
    # T3 Rare / Enhanced - PHYSICAL. Wide tower-blade with a full-length blood channel, riveted
    # block guard; massive scalloped fortress shield with rivet rows.
    dict(id="art_vanguard_warden_bastion", tier=3,
         grip=dict(L=0.95, r=0.1, ribs=6), pommel="hex", guard=dict(kind="block", span=0.62, h=0.2),
         blade=dict(L=3.25, w=0.27, t=0.1, taper=0.05, tf=0.1, tipc=0.75, ric=0.06, fuller=0.92, fuller_w=0.22),
         rune="slots",
         shield=dict(kind="tower", W=1.8, H=2.75, t=0.16, k=0.12, rim="tube", boss="bar", rivets=True, runes="slits"),
         col=dict(Handle=M("Leather", 48, 40, 36), Pommel=M("Metal", 72, 76, 84), Crossguard=M("Metal", 72, 76, 84),
                  Blade=M("Metal", 118, 124, 136), BladeEdge=M("Metal", 205, 210, 222), Fuller=M("Metal", 52, 55, 62),
                  RuneInlay=M("Neon", 90, 170, 255),
                  HandleS=M("Leather", 48, 40, 36), ShieldPlate=M("Metal", 88, 92, 102), ShieldRim=M("Metal", 140, 145, 158),
                  ShieldBoss=M("Metal", 120, 125, 138), ShieldRune=M("Neon", 90, 170, 255))),
    # T4 Superior / Standard - CRYSTAL. Translucent amethyst greatsword with faceted, faintly jagged
    # edges and crystal growths at the guard; interlocking prismatic hex-tile barrier.
    dict(id="art_crystal_claymore", tier=4,
         grip=dict(L=1.0, r=0.095, ribs=7), pommel="crystal", guard=dict(kind="crystal", span=0.72, h=0.16),
         blade=dict(L=3.75, w=0.22, t=0.1, taper=0.25, tf=0.16, tipc=0.95, ric=0.05, jag=0.018, facet=True, fuller=0.6, fuller_w=0.35),
         rune="crystals",
         shield=dict(kind="hexcluster", W=2.0, H=2.3, t=0.14, k=0.1, rim="hexframe", boss="crystal", runes="pips"),
         col=dict(Handle=M("Leather", 48, 36, 62), Pommel=M("Glass", 170, 110, 230), Crossguard=M("Metal", 175, 168, 200),
                  Blade=M("Glass", 150, 92, 210), BladeEdge=M("Glass", 215, 180, 255), Fuller=M("Glass", 105, 58, 170),
                  RuneInlay=M("Neon", 195, 125, 255),
                  HandleS=M("Leather", 48, 36, 62), ShieldPlate=M("Glass", 140, 100, 215), ShieldRim=M("Metal", 185, 178, 210),
                  ShieldBoss=M("Glass", 200, 150, 255), ShieldRune=M("Neon", 195, 125, 255))),
    # T4 Superior / Enhanced - LIGHTNING. Sonic steel broadsword with a rippled resonance edge and
    # tuning-fork guard; hexagonal acoustic aegis with a speaker-cone boss.
    dict(id="art_resonant_bulwark", tier=4,
         grip=dict(L=0.95, r=0.095, ribs=7), pommel="orb", guard=dict(kind="fork", span=0.6, h=0.16),
         blade=dict(L=3.5, w=0.23, t=0.085, taper=0.18, tf=0.14, tipc=0.85, ric=0.07, wave=(0.022, 7), fuller=0.78),
         rune="slots",
         shield=dict(kind="hex", W=2.0, H=2.3, t=0.15, k=0.12, kz=0.08, rim="hexrings", boss="speaker", runes="hexline"),
         col=dict(Handle=M("Leather", 40, 44, 52), Pommel=M("Metal", 150, 160, 178), Crossguard=M("Metal", 150, 160, 178),
                  Blade=M("Metal", 170, 182, 200), BladeEdge=M("Metal", 225, 235, 248), Fuller=M("Metal", 80, 92, 112),
                  RuneInlay=M("Neon", 80, 220, 255),
                  HandleS=M("Leather", 40, 44, 52), ShieldPlate=M("Metal", 82, 92, 110), ShieldRim=M("Metal", 165, 175, 192),
                  ShieldBoss=M("Metal", 120, 132, 150), ShieldRune=M("Neon", 80, 220, 255))),
    # T5 Exalted / Standard - CELESTIAL. White-silver executioner claymore (broad, parallel, blunt
    # rounded point), angelic wing quillons; large kite shield with a gold sunburst.
    dict(id="art_paladin_claymore", tier=5,
         grip=dict(L=1.05, r=0.1, ribs=8), pommel="sun", guard=dict(kind="angel", span=0.8, h=0.18),
         blade=dict(L=3.95, w=0.25, t=0.09, taper=0.04, tf=0.09, tipc=0.4, ric=0.06, fuller=0.8),
         rune="script",
         shield=dict(kind="kite", W=1.75, H=2.75, t=0.15, k=0.16, rim="tube", boss="gem", rays=12, runes="sun_ring"),
         col=dict(Handle=M("Leather", 238, 234, 226), Pommel=M("Metal", 240, 195, 80), Crossguard=M("Metal", 232, 236, 246),
                  Blade=M("Metal", 226, 229, 238), BladeEdge=M("Metal", 250, 250, 255), Fuller=M("Metal", 236, 192, 82),
                  RuneInlay=M("Neon", 255, 225, 120),
                  HandleS=M("Leather", 150, 110, 70), ShieldPlate=M("SmoothPlastic", 238, 236, 230), ShieldRim=M("Metal", 240, 195, 80),
                  ShieldBoss=M("Metal", 245, 200, 85), ShieldRune=M("Neon", 255, 225, 120))),
    # T5 Exalted / Enhanced - CELESTIAL. Gilded royal arming sword with scroll-ended guard;
    # round solar shield with corona rays beyond the rim and a domed sun boss.
    dict(id="art_aegis_of_valor", tier=5,
         grip=dict(L=0.95, r=0.092, ribs=8), pommel="lobed", guard=dict(kind="royal", span=0.7, h=0.16),
         blade=dict(L=3.7, w=0.2, t=0.08, taper=0.36, tf=0.2, tipc=0.9, ric=0.08, fuller=0.72),
         rune="script",
         shield=dict(kind="round", W=2.15, H=2.15, t=0.14, k=0.14, kz=0.14, rim="tube", boss="dome_big", corona=16, runes="rings"),
         col=dict(Handle=M("Leather", 120, 30, 38), Pommel=M("Metal", 245, 200, 80), Crossguard=M("Metal", 245, 200, 80),
                  Blade=M("Metal", 222, 224, 232), BladeEdge=M("Metal", 250, 248, 240), Fuller=M("Metal", 242, 196, 72),
                  RuneInlay=M("Neon", 255, 235, 150),
                  HandleS=M("Leather", 120, 30, 38), ShieldPlate=M("Metal", 238, 190, 72), ShieldRim=M("Metal", 250, 225, 140),
                  ShieldBoss=M("Metal", 255, 215, 100), ShieldRune=M("Neon", 255, 235, 150))),
    # T6 Legendary / Standard - COSMIC. Dimensional glass blade with a nebula core and drifting
    # star pips, fractured tip shards; antique gothic portal shield with rose-window tracery.
    dict(id="art_blade_of_the_rift", tier=6,
         grip=dict(L=1.0, r=0.095, ribs=8), pommel="crystal", guard=dict(kind="cathedral", span=0.76, h=0.2),
         blade=dict(L=4.2, w=0.25, t=0.095, taper=0.2, tf=0.17, tipc=0.9, ric=0.05, jag=0.012, fuller=0.82, fuller_w=0.42, shards=4),
         rune="stars",
         shield=dict(kind="arch", W=1.9, H=2.9, t=0.16, k=0.12, rim="tube", boss="rose", runes="spiral"),
         col=dict(Handle=M("Leather", 30, 26, 46), Pommel=M("Glass", 120, 80, 220), Crossguard=M("Metal", 190, 160, 95),
                  Blade=M("Glass", 58, 46, 120), BladeEdge=M("Glass", 170, 150, 255), Fuller=M("Glass", 140, 80, 220),
                  RuneInlay=M("Neon", 225, 200, 255),
                  HandleS=M("Leather", 30, 26, 46), ShieldPlate=M("Slate", 40, 34, 62), ShieldRim=M("Metal", 190, 160, 95),
                  ShieldBoss=M("Metal", 200, 170, 105), ShieldRune=M("Neon", 170, 110, 255))),
    # T6 Legendary / Enhanced - VOID. Segmented hard-light blade (hex gold plates floating on a
    # glowing core spine), orbit-ring guard; six floating gold plates around a rift power core.
    dict(id="art_aegis_core", tier=6,
         grip=dict(L=1.0, r=0.1, ribs=8), pommel="orb", guard=dict(kind="orbit", span=0.66, h=0.18),
         blade=dict(L=4.15, w=0.26, t=0.09, taper=0.15, tf=0.16, tipc=0.9, ric=0.05, segments=4, satellites=True, fuller=0.95, fuller_w=0.18),
         rune="core",
         shield=dict(kind="hexorbit", W=2.2, H=2.4, t=0.15, k=0.0, rim="none", boss="core", runes="core"),
         col=dict(Handle=M("Leather", 32, 30, 40), Pommel=M("Metal", 238, 188, 72), Crossguard=M("Metal", 238, 188, 72),
                  Blade=M("Metal", 236, 186, 70), BladeEdge=M("Metal", 255, 228, 140), Fuller=M("Glass", 120, 230, 255),
                  RuneInlay=M("Neon", 140, 90, 255),
                  HandleS=M("Leather", 32, 30, 40), ShieldPlate=M("Metal", 236, 186, 70), ShieldRim=M("Metal", 255, 228, 140),
                  ShieldBoss=M("Metal", 70, 60, 90), ShieldRune=M("Neon", 140, 90, 255))),
    # T7 Mythical / Standard - COSMIC. Starlight-alloy executioner with a chisel tip and a night-sky
    # fuller of constellation runes; monolithic starry mirror shield.
    dict(id="art_astral_executioner", tier=7,
         grip=dict(L=1.08, r=0.1, ribs=9), pommel="star", guard=dict(kind="constellation", span=0.85, h=0.2),
         blade=dict(L=4.3, w=0.28, t=0.1, taper=0.08, tf=0.0, chisel=0.55, ric=0.05, fuller=0.86, fuller_w=0.48),
         rune="constellation",
         shield=dict(kind="monolith", W=1.85, H=3.05, t=0.18, k=0.08, rim="tube", boss="star", runes="constellation"),
         col=dict(Handle=M("Leather", 26, 28, 52), Pommel=M("Metal", 215, 222, 245), Crossguard=M("Metal", 215, 222, 245),
                  Blade=M("Metal", 205, 214, 238), BladeEdge=M("Metal", 245, 248, 255), Fuller=M("Glass", 30, 34, 72),
                  RuneInlay=M("Neon", 255, 238, 170),
                  HandleS=M("Leather", 26, 28, 52), ShieldPlate=M("Glass", 34, 40, 80), ShieldRim=M("Metal", 215, 222, 245),
                  ShieldBoss=M("Metal", 230, 236, 252), ShieldRune=M("Neon", 255, 238, 170))),
    # T7 Mythical / Enhanced - VOID. Colossal dark-matter bastion blade with a notched spine and an
    # event-horizon slot; collapsed-star shield with floating gravity rings around a black core.
    dict(id="art_genesis_worldbreaker", tier=7,
         grip=dict(L=1.1, r=0.11, ribs=9), pommel="orb", guard=dict(kind="gravity", span=0.9, h=0.22),
         blade=dict(L=4.45, w=0.32, t=0.11, taper=0.12, tf=0.15, tipc=0.8, ric=0.04, notches=3, fuller=0.84, fuller_w=0.3),
         rune="accretion",
         shield=dict(kind="round", W=2.6, H=2.6, t=0.17, k=0.1, kz=0.1, rim="gravity", boss="blackhole", runes="accretion"),
         col=dict(Handle=M("Leather", 30, 22, 40), Pommel=M("Metal", 60, 45, 85), Crossguard=M("Metal", 60, 45, 85),
                  Blade=M("Metal", 40, 30, 60), BladeEdge=M("Metal", 232, 212, 255), Fuller=M("Glass", 18, 12, 28),
                  RuneInlay=M("Neon", 255, 130, 70),
                  HandleS=M("Leather", 30, 22, 40), ShieldPlate=M("Metal", 30, 24, 46), ShieldRim=M("Metal", 175, 150, 220),
                  ShieldBoss=M("Glass", 10, 8, 16), ShieldRune=M("Neon", 255, 130, 70))),
]


# --------------------------------------------------------------------------------------
# Blade
# --------------------------------------------------------------------------------------
def blade_profile(b, z0, res, rng):
    """Right half of the blade, base -> tip, as (u, z) points; u is the half width."""
    L, w = b["L"], b["w"]
    taper, tf, tipc = b.get("taper", 0.2), b.get("tf", 0.15), b.get("tipc", 0.8)
    body = 1.0 - tf
    pts = []
    nb = max(4, int(res * body * 1.6))
    for i in range(nb + 1):
        s = body * i / nb
        k = s / body if body > 0 else 1
        hw = w * (1 - taper * k)
        if b.get("waist"):
            hw -= w * b["waist"] * math.sin(math.pi * min(1, k * 1.4))
        if b.get("wave") and 0.08 < k < 0.97:
            a, f = b["wave"]
            hw += a * math.sin(2 * math.pi * f * k)
        if b.get("jag") and 0.05 < k < 0.98 and i % 2:
            hw += b["jag"] * rng.uniform(-1, 1.5)
        pts.append(V2(hw, z0 + L * s))
    if tf > 0:
        hw_end = pts[-1].x
        nt = max(3, int(res * 0.5))
        for i in range(1, nt + 1):
            k = i / nt
            pts.append(V2(hw_end * (1 - k) ** tipc if k < 1 else 0.0, z0 + L * (body + tf * k)))
    return pts


def build_blade(spec, parts, z0, rng):
    b, tier = spec["blade"], spec["tier"]
    res = 8 + 2 * tier
    half = blade_profile(b, z0, res, rng)
    top = z0 + b["L"]
    t = b["t"]
    w = b["w"]
    inset = w * 0.98 if b.get("diamond") else min(w * 0.5, 0.11)
    if b.get("facet"):
        inset = w * 0.8
    B, E = parts["Blade"], parts["BladeEdge"]
    ric_z = z0 + b["L"] * b.get("ric", 0.06)

    if b.get("chisel"):
        c = b["chisel"] * 2 * half[-1].x
        right = half
        left = [V2(-p.x, p.y) for p in half if p.y < top - c - 1e-4]
        corner = V2(-half[-1].x, top - c)
        pts = right + [corner] + list(reversed(left))
        edge_r = [p for p in right if p.y >= ric_z] + [corner]
        edge_l = [corner] + list(reversed([p for p in left if p.y >= ric_z]))
        centre_r = lambda p: V2(0, min(p.y, top - c) - 0.35)
    else:
        pts = mirror_u(half)
        edge_r = [p for p in half if p.y >= ric_z]
        edge_l = [V2(-p.x, p.y) for p in reversed(edge_r)]
        centre_r = lambda p: V2(0, p.y - 0.05)
    tip = V2(0, top) if not b.get("chisel") else V2(half[-1].x * 0.0, top - c * 0.5)

    if b.get("segments"):
        # Hard-light plates: the outline cut into floating segments along the blade.
        n = b["segments"]
        gap = 0.13
        L = b["L"]
        cuts = [z0 + L * i / n for i in range(n + 1)]
        for i in range(n):
            za, zb = cuts[i] + (gap / 2 if i else 0), cuts[i + 1] - gap / 2 if i < n - 1 else top
            seg = [p for p in half if za <= p.y <= zb]
            if len(seg) < 2:
                continue
            # pointed hex segment: chevron top and bottom
            hw_a, hw_b = seg[0].x, seg[-1].x
            outline = [V2(0, za + 0.06 if i else za)] + seg + ([V2(0, zb + 0.06)] if i < n - 1 else [])
            plate(B, mirror_u(outline), t, inset)
        edge_strip(E, edge_r, centre_r, inset * 0.55, t * 0.6 + 0.03)
        edge_strip(E, edge_l, lambda p: V2(0, p.y - 0.05), inset * 0.55, t * 0.6 + 0.03)
    else:
        plate(B, pts, t, inset)
        te = t * min(1.0, 0.55) + 0.03 if not b.get("diamond") else t * 0.25 + 0.02
        we = inset * 0.55 if not b.get("diamond") else w * 0.35
        edge_strip(E, edge_r, centre_r, we, te)
        edge_strip(E, edge_l, lambda p: V2(0, p.y - 0.05), we, te)

    if b.get("notches"):  # bites out of the spine edge rendered as dark wedges on the blade faces
        for i in range(b["notches"]):
            zc = z0 + b["L"] * (0.45 + 0.13 * i)
            hw = w * (1 - b.get("taper", 0.2) * (0.45 + 0.13 * i))
            tri = [V2(-hw - 0.01, zc + 0.12), V2(-hw * 0.55, zc), V2(-hw - 0.01, zc - 0.12)]
            plate(parts["Fuller"], tri, t + 0.02, 0.01)

    # Fuller (raised a hair above the blade face so it reads as a darker channel)
    fl = b.get("fuller")
    if fl:
        fw = w * b.get("fuller_w", 0.27)
        za, zb = ric_z + 0.06, z0 + b["L"] * fl
        if b.get("segments"):
            sweep(parts["Fuller"], [V3(0, 0, za - 0.1), V3(0, 0, (za + zb) / 2), V3(0, 0, zb)], [fw * 1.2, fw, fw * 0.4], [t + 0.04, t + 0.04, t * 0.6], segs=6, profile="oval")
        else:
            outline = [V2(0, za - 0.04), V2(fw, za + 0.1), V2(fw * 0.85, zb - 0.16), V2(0, zb)]
            plate(parts["Fuller"], mirror_u(outline), t + 0.018, 0.012)
            if b.get("dents"):  # hammer marks: shallow flats pressed into the faces
                for i in range(7):
                    zc = rng.uniform(za + 0.2, top - 0.5)
                    u = rng.choice((-1, 1)) * rng.uniform(fw + 0.03, w * 0.6)
                    side = rng.choice((-1, 1))
                    face_gem(parts["Fuller"], (u, side * (t / 2 - 0.004), zc), 0.04, 0.016, 5, side)
        b["_fuller"] = (za, zb, fw)

    if b.get("satellites"):  # small hex plates orbiting the blade
        for i, (u, zf) in enumerate(((1, 0.3), (-1, 0.5), (1, 0.72))):
            zc = z0 + b["L"] * zf
            plate(parts["Crossguard"], ngon(u * (w + 0.22), zc, 0.12, 6, 0), 0.06, 0.025)
            sphere(parts["RuneInlay"], (u * (w + 0.22), 0, zc), 0.035, 6, 4)

    if b.get("shards"):  # fractured fragments drifting off the tip
        for i in range(b["shards"]):
            gem(B, (rng.uniform(-0.1, 0.1), 0, top + 0.18 + 0.2 * i), 0.05 + 0.012 * (i % 2), 0.16 + 0.03 * i, 4, I4, (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5)))

    return dict(top=top, tip=tip, ric_z=ric_z)


def build_runes(spec, parts, z0, info, rng):
    kind = spec.get("rune")
    if not kind:
        return
    b = spec["blade"]
    R, t = parts["RuneInlay"], b["t"]
    w = b["w"]
    za, zb, fw = b.get("_fuller", (info["ric_z"] + 0.1, z0 + b["L"] * 0.7, w * 0.25))
    ft = t + 0.018
    if kind == "glyphs":  # emerald knot-glyphs down the fuller
        n = 6
        for i in range(n):
            zc = za + 0.2 + (zb - za - 0.4) * i / (n - 1)
            s = fw * 0.7
            if i % 2:
                polyline(R, [V2(-s, zc - 0.07), V2(0, zc + 0.07), V2(s, zc - 0.07)], 0.028, ft, depth=0.014)
            else:
                polyline(R, [V2(0, zc - 0.08), V2(0, zc + 0.08)], 0.028, ft, depth=0.014)
                polyline(R, [V2(-s, zc), V2(s, zc)], 0.024, ft, depth=0.014)
    elif kind == "ridge":  # thin glowing line up the diamond ridge + pommel pip
        polyline(R, [V2(0, info["ric_z"] + 0.1), V2(0, z0 + b["L"] * 0.6)], 0.022, t + 0.004, depth=0.012)
    elif kind == "line":
        polyline(R, [V2(0, za + 0.1), V2(0, zb - 0.12)], 0.03, ft, depth=0.014)
        for zc in (za + 0.1, zb - 0.12):
            for side in (1, -1):
                face_gem(R, (0, side * ft / 2, zc), 0.05, 0.03, 6, side)
    elif kind == "slots":
        n = 7
        for i in range(n):
            zc = za + 0.15 + (zb - za - 0.3) * i / (n - 1)
            polyline(R, [V2(-fw * 0.6, zc), V2(fw * 0.6, zc)], 0.04, ft, depth=0.014)
    elif kind == "crystals":  # crystal growths bursting from the blade root
        for i in range(7):
            side = -1 if i % 2 else 1
            gem(R, (side * rng.uniform(0.02, w * 0.6), 0, z0 + 0.12 + 0.07 * i), 0.045 + 0.01 * (i % 3), 0.28 + 0.04 * (i % 2), 5, I4,
                (rng.uniform(-0.7, 0.7), side * rng.uniform(0.1, 0.5)))
    elif kind == "script":  # holy script: short alternating glyph strokes
        n = 9
        for i in range(n):
            zc = za + 0.15 + (zb - za - 0.3) * i / (n - 1)
            s = fw * 0.65
            if i % 3 == 0:
                polyline(R, [V2(-s, zc - 0.06), V2(s, zc + 0.06)], 0.026, ft, depth=0.014)
            elif i % 3 == 1:
                polyline(R, [V2(-s, zc + 0.05), V2(0, zc - 0.06), V2(s, zc + 0.05)], 0.026, ft, depth=0.014)
            else:
                polyline(R, [V2(0, zc - 0.07), V2(0, zc + 0.07)], 0.026, ft, depth=0.014)
                polyline(R, [V2(-s * 0.6, zc + 0.02), V2(s * 0.6, zc + 0.02)], 0.022, ft, depth=0.014)
    elif kind == "stars":  # star pips suspended in the nebula core
        for i in range(14):
            zc = rng.uniform(za + 0.1, zb - 0.1)
            u = rng.uniform(-fw * 0.8, fw * 0.8)
            for side in (1, -1):
                gem(R, (u, side * (ft / 2), zc), 0.022 + 0.012 * (i % 3), 0.07, 4, I4, (side * math.pi / 2, 0))
    elif kind == "core":  # power core seen through the gaps + hilt pip
        sphere(R, (0, 0, z0 + 0.05), 0.09, 10, 6)
    elif kind == "constellation":
        prev = None
        for i in range(9):
            zc = za + 0.15 + (zb - za - 0.3) * i / 8
            p = V2(rng.uniform(-fw * 0.7, fw * 0.7), zc)
            for side in (1, -1):
                gem(R, (p.x, side * ft / 2, p.y), 0.03 + (0.02 if i % 3 == 0 else 0), 0.08, 4, I4, (side * math.pi / 2, 0))
            if prev:
                stroke(R, prev, p, 0.012, ft, depth=0.008)
            prev = p
    elif kind == "accretion":  # molten lines streaming into the event-horizon slot
        for i in range(8):
            zc = za + 0.2 + (zb - za - 0.4) * i / 7
            side = 1 if i % 2 else -1
            K.vein(R, V2(side * w * 0.7, zc + 0.15), V2(side * fw * 0.9, zc), 0.035, t, rng, 3, 0.04)


# --------------------------------------------------------------------------------------
# Hilt
# --------------------------------------------------------------------------------------
def rrect(cx, cz, hw, hh, r, n=3):
    pts = []
    for (sx, sz, a0) in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        ccx, ccz = cx + sx * (hw - r), cz + sz * (hh - r)
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append(V2(ccx + r * math.cos(a), ccz + r * math.sin(a)))
    return pts


def build_grip(spec, parts):
    g = spec["grip"]
    L, r, ribs = g["L"], g["r"], g["ribs"]
    prof = [(r * 0.92, -L / 2)]
    for i in range(ribs * 2 + 1):
        prof.append((r * (1.08 if i % 2 else 0.98), -L / 2 + 0.03 + (L - 0.06) * i / (ribs * 2)))
    prof.append((r * 0.92, L / 2))
    lathe(parts["Handle"], prof, 10 + spec["tier"], sy=0.86)


def build_guard(spec, parts, rng):
    g, tier = spec["guard"], spec["tier"]
    gl = spec["grip"]["L"]
    z, span, h = gl / 2, g["span"], g["h"]
    C, R = parts["Crossguard"], parts["RuneInlay"]
    r = spec["grip"]["r"]
    segs = 10 + tier
    th = 0.16 + 0.015 * tier  # guard thickness along Y
    kind = g["kind"]
    # Ferrule ring where the grip meets the guard
    lathe(C, [(r * 1.0, z - 0.06), (r * 1.3, z - 0.03), (r * 1.3, z + 0.01)], segs, sy=0.86)
    zc = z + h / 2
    if kind == "bar":
        plate(C, rrect(0, zc, span, h / 2, h * 0.45), th, 0.04)
        for s in (1, -1):
            sphere(C, (s * span, 0, zc), h * 0.62, 8, 5)
        plate(C, [V2(0, z - 0.05), V2(0.13, zc), V2(0, z + h + 0.12), V2(-0.13, zc)], th * 1.15, 0.04)
    elif kind == "fluted":
        half = [V2(0.0, z + h), V2(span * 0.55, z + h * 0.85), V2(span, z + h * 1.55), V2(span + 0.04, z + h * 0.6),
                V2(span, z - h * 0.4), V2(span * 0.55, z + 0.02), V2(0.0, z - 0.03)]
        plate(C, mirror_u(half), th, 0.045)
        for s in (1, -1):
            for k in (-1, 0, 1):
                stroke(C, V2(s * span * 0.3, zc + k * 0.035), V2(s * span * 0.85, zc + k * 0.06 + 0.03), 0.018, th, depth=0.01)
    elif kind == "swept":
        plate(C, rrect(0, zc, 0.17, h / 2 + 0.02, 0.05), th * 1.1, 0.04)
        for s in (1, -1):
            path = [V3(s * 0.1, 0, zc), V3(s * span * 0.6, 0, zc + 0.02), V3(s * span * 0.95, 0, zc + 0.16), V3(s * span * 1.02, 0, zc + 0.34)]
            path = K.resample(K.cubic(*path, 10), 10)
            sweep(C, path, [0.11 - 0.05 * i / 10 for i in range(11)], [th * 0.9 - 0.04 * i / 10 for i in range(11)], side=V3(0, 1, 0), segs=8, profile="oval")
            sphere(C, tuple(path[-1]), 0.045, 6, 4)
        for side in (1, -1):
            face_gem(R, (0, side * th * 0.55, zc), 0.065, 0.05, 6, side)
    elif kind == "basket":
        plate(C, rrect(0, zc, span, h / 2, h * 0.45), th, 0.035)
        # knuckle bow from the guard's +X end down to the pommel, two side rings
        zp = -gl / 2 - 0.06
        path = K.cubic(V3(span, 0, zc), V3(span + 0.22, 0, z - 0.2), V3(0.34, 0, zp + 0.1), V3(0.06, 0, zp), 14)
        sweep(C, path, 0.05, 0.05, side=V3(0, 1, 0), segs=6, profile="oval")
        for s in (1, -1):
            torus(C, 0.24, 0.026, 18, 6, T(0.05, s * 0.0, z - 0.02) @ RX(s * 90) @ RZ(0), sx=1.1, sy=0.75, arc=0.5)
        for s in (1, -1):
            path = K.cubic(V3(span * 0.6, 0, zc), V3(span * 0.7, s * 0.25, z - 0.2), V3(0.3, s * 0.22, zp + 0.3), V3(0.2, 0, zp + 0.04), 12)
            sweep(C, path, 0.035, 0.035, side=V3(0, 1, 0), segs=6, profile="oval")
    elif kind == "winged":
        plate(C, rrect(0, zc, 0.2, h / 2, 0.05), th * 1.1, 0.04)
        for s in (1, -1):
            for k, (ang, ln, wd) in enumerate(((14, span, 0.2), (32, span * 0.8, 0.16), (52, span * 0.55, 0.12))):
                pts = leaf(V2(s * 0.12, zc + 0.02 * k), math.radians(ang if s > 0 else 180 - ang), ln, wd, 6 + tier)
                plate(C, pts, th * (0.8 - 0.12 * k), 0.03)
        for side in (1, -1):
            face_gem(R, (0, side * th * 0.6, zc), 0.06, 0.05, 6, side)
    elif kind == "block":
        half = [V2(0, z + h + 0.06), V2(span, z + h), V2(span + 0.05, z + h * 0.3)]
        for i in range(4):  # scalloped underside
            u0 = span - span * i / 4
            half += bezier(V2(u0, z), V2(u0 - span / 8, z + h * 0.45), V2(u0 - span / 4, z), 3)[1:]
        plate(C, [half[0]] + half[1:-1] + [V2(0, z)] + [V2(-p.x, p.y) for p in reversed(half[1:-1])], th * 1.4, 0.05)
        for s in (1, -1):
            for u in (0.18, 0.4):
                for side in (1, -1):
                    sphere(C, (s * u, side * th * 0.7, zc + 0.02), 0.035, 6, 4)
        for side in (1, -1):
            box(R, (0, side * th * 0.7, zc), (0.22, 0.03, 0.04))
    elif kind == "crystal":
        plate(C, rrect(0, zc, span * 0.55, h / 2, 0.05), th, 0.04)
        for s in (1, -1):
            for k in range(4):
                gem(R if k == 0 else C, (s * (span * 0.55 + 0.04 * k), 0, zc + 0.02 * k), 0.06 - 0.008 * k, 0.4 - 0.05 * k, 5, I4,
                    (rng.uniform(-0.3, 0.3), s * math.radians(-62 + 18 * k)))
    elif kind == "fork":  # tuning-fork prongs either side of a hex hub
        plate(C, ngon(0, zc, 0.2, 6, 0), th * 1.2, 0.05)
        for s in (1, -1):
            plate(C, rrect(s * span * 0.55, zc, span * 0.45, h * 0.3, 0.03), th * 0.8, 0.03)
            for k in (-1, 1):
                plate(C, rrect(s * span, zc + 0.22 + k * 0.0, 0.035, 0.24, 0.02), th * 0.7, 0.02, M=T(0, k * th * 0.32, 0))
        for side in (1, -1):
            face_gem(R, (0, side * th * 0.62, zc), 0.08, 0.05, 6, side)
    elif kind == "angel":
        plate(C, rrect(0, zc, 0.24, h / 2, 0.06), th * 1.2, 0.05)
        for s in (1, -1):
            for k, (ang, ln, wd) in enumerate(((6, span, 0.24), (24, span * 0.92, 0.22), (42, span * 0.75, 0.18), (60, span * 0.55, 0.14), (-14, span * 0.6, 0.14))):
                pts = leaf(V2(s * 0.14, zc + 0.03 * k), math.radians(ang if s > 0 else 180 - ang), ln, wd, 6 + tier)
                plate(C, pts, th * (0.85 - 0.08 * k), 0.035, M=T(0, (0.02 if k % 2 else -0.02), 0))
        sphere(R, (0, 0, zc + 0.02), 0.075, 10, 6)
        torus(C, 0.11, 0.02, 16, 6, T(0, 0, zc + 0.02) @ RX(90))
    elif kind == "royal":
        half = [V2(0, z + h + 0.05), V2(span * 0.8, z + h * 0.7), V2(span, z + h * 0.2), V2(span * 0.8, z - 0.02), V2(0, z - 0.04)]
        plate(C, mirror_u(half), th, 0.045)
        for s in (1, -1):  # scroll curls
            torus(C, 0.11, 0.035, 14, 6, T(s * (span + 0.06), 0, zc + 0.08) @ RX(90) @ RZ(-90 if s > 0 else 90), arc=0.8)
            sphere(C, (s * (span + 0.06), 0, zc + 0.08), 0.04, 6, 4)
        lathe(C, [(0, -0.02), (0.13, 0), (0.15, 0.04), (0.11, 0.07)], 14, T(0, th * 0.45, zc) @ RX(-90))
        lathe(C, [(0, -0.02), (0.13, 0), (0.15, 0.04), (0.11, 0.07)], 14, T(0, -th * 0.45, zc) @ RX(90))
        for side in (1, -1):
            face_gem(R, (0, side * (th * 0.45 + 0.07), zc), 0.085, 0.06, 8, side)
    elif kind == "cathedral":  # gothic arch guard with twin spires
        half = [V2(0, z + h + 0.18), V2(0.12, z + h), V2(span * 0.75, z + h * 0.9), V2(span, z + h + 0.4), V2(span + 0.08, z + h * 0.5),
                V2(span * 0.9, z - 0.02), V2(span * 0.3, z + 0.03), V2(0, z - 0.05)]
        plate(C, mirror_u(half), th, 0.05)
        for s in (1, -1):
            plate(C, [V2(s * span, z + h + 0.38), V2(s * (span + 0.06), z + h + 0.75), V2(s * (span - 0.06), z + h + 0.5)], th * 0.6, 0.02)
            torus(C, 0.09, 0.022, 14, 5, T(s * span * 0.55, 0, zc + 0.02) @ RX(90))
            sphere(R, (s * span * 0.55, 0, zc + 0.02), 0.05, 8, 5)
        for side in (1, -1):
            face_gem(R, (0, side * th * 0.55, z + h * 0.5), 0.08, 0.06, 6, side)
    elif kind == "orbit":
        plate(C, ngon(0, zc, span * 0.42, 6, 0, sx=1.4), th * 1.1, 0.05)
        for s in (1, -1):
            plate(C, ngon(s * span * 0.8, zc + 0.05, 0.13, 6, 0), th * 0.8, 0.03)
        torus(C, span * 0.7, 0.03, 28, 6, T(0, 0, zc + 0.12) @ RX(0), sy=0.55)
        sphere(R, (0, 0, zc), 0.1, 10, 6)
        for s in (1, -1):
            sphere(R, (s * span * 0.8, 0, zc + 0.05), 0.05, 8, 5)
    elif kind == "constellation":
        plate(C, star(0, zc, span, 0.13, 4, 0.0), th, 0.05)
        plate(C, star(0, zc + 0.05, 0.36, 0.1, 4, math.pi / 4), th * 0.8, 0.03, M=T(0, 0, 0))
        for s in (1, -1):
            plate(C, star(s * span, zc, 0.14, 0.05, 4, 0.0), th * 0.6, 0.02)
            gem(R, (s * span, 0, zc), 0.035, 0.1, 4, I4, (math.pi / 2, 0))
        for side in (1, -1):
            face_gem(R, (0, side * th * 0.5, zc), 0.08, 0.06, 8, side)
    elif kind == "gravity":
        half = [V2(0, z + h + 0.1), V2(span * 0.6, z + h * 1.1), V2(span, z + h * 1.9), V2(span * 0.95, z + h * 0.6),
                V2(span * 0.55, z - 0.05), V2(0, z - 0.08)]
        plate(C, mirror_u(half), th * 1.3, 0.06)
        torus(C, span * 0.62, 0.045, 32, 6, T(0, 0, zc + 0.22) @ RX(78))
        torus(R, span * 0.62, 0.016, 32, 5, T(0, 0, zc + 0.22) @ RX(78), sx=1.0)
        for s in (1, -1):
            gem(C, (s * span * 0.98, 0, z + h * 1.9), 0.05, 0.3, 5, I4, (0, s * math.radians(-30)))
        sphere(R, (0, 0, zc + 0.06), 0.09, 10, 6)


def build_pommel(spec, parts, rng):
    kind, tier = spec["pommel"], spec["tier"]
    gl, r = spec["grip"]["L"], spec["grip"]["r"]
    z = -gl / 2
    P, R = parts["Pommel"], parts["RuneInlay"]
    segs = 10 + tier
    lathe(P, [(r * 1.0, z + 0.05), (r * 1.3, z + 0.02), (r * 1.25, z - 0.05), (r * 0.9, z - 0.08)], segs, sy=0.86)
    if kind == "ball":
        sphere(P, (0, 0, z - 0.2), 0.15, segs, 7)
        sphere(P, (0, 0, z - 0.37), 0.05, 8, 4)
    elif kind == "fishtail":
        plate(P, [V2(0, z - 0.04), V2(0.1, z - 0.06), V2(0.2, z - 0.32), V2(0.1, z - 0.27), V2(0, z - 0.31), V2(-0.1, z - 0.27), V2(-0.2, z - 0.32), V2(-0.1, z - 0.06)], 0.15, 0.04)
    elif kind == "wheel":
        lathe(P, [(0, -0.07), (0.15, -0.07), (0.19, -0.03), (0.19, 0.03), (0.15, 0.07), (0, 0.07)], 16, T(0, 0, z - 0.25) @ RX(90))
        for side in (1, -1):
            face_gem(R, (0, side * 0.075, z - 0.25), 0.06, 0.04, 6, side)
    elif kind == "pear":
        lathe(P, [(0.06, z - 0.06), (0.13, z - 0.14), (0.14, z - 0.24), (0.09, z - 0.33), (0, z - 0.38)], segs)
        cut_gem(R, (0, 0, z - 0.42), 0.04, 0.08, 6, RX(180))
    elif kind == "sun":
        plate(P, star(0, z - 0.24, 0.2, 0.11, 8), 0.12, 0.04)
        for side in (1, -1):
            face_gem(R, (0, side * 0.06, z - 0.24), 0.07, 0.05, 6, side)
    elif kind == "hex":
        lathe(P, [(0.08, z - 0.04), (0.17, z - 0.1), (0.17, z - 0.26), (0.1, z - 0.33), (0, z - 0.35)], 6, phase=math.pi / 6)
    elif kind == "crystal":
        gem(P, (0, 0, z - 0.12), 0.12, 0.6, 6, I4, (math.pi, 0))
        for k in range(3):
            gem(R, (0.06 * math.cos(2.1 * k), 0.06 * math.sin(2.1 * k), z - 0.15), 0.035, 0.24, 5, I4, (math.pi - 0.5 * math.cos(2.1 * k), 0.5 * math.sin(2.1 * k)))
    elif kind == "orb":
        lathe(P, [(0.07, z - 0.05), (0.15, z - 0.12), (0.1, z - 0.18)], segs)
        sphere(R, (0, 0, z - 0.3), 0.12, 12, 8)
        torus(P, 0.17, 0.025, 20, 6, T(0, 0, z - 0.3) @ RX(70))
        lathe(P, [(0.06, z - 0.42), (0.03, z - 0.5), (0, z - 0.56)], segs)
    elif kind == "lobed":
        for k, (u, dz) in enumerate(((0, -0.34), (0.12, -0.22), (-0.12, -0.22))):
            sphere(P, (u, 0, z + dz), 0.1, 10, 6, sz=1.1)
        for side in (1, -1):
            face_gem(R, (0, side * 0.09, z - 0.24), 0.06, 0.04, 6, side)
    elif kind == "star":
        plate(P, star(0, z - 0.26, 0.24, 0.07, 4), 0.12, 0.04)
        plate(P, star(0, z - 0.26, 0.14, 0.05, 4, math.pi / 4), 0.16, 0.03)
        for side in (1, -1):
            face_gem(R, (0, side * 0.08, z - 0.26), 0.05, 0.04, 6, side)


# --------------------------------------------------------------------------------------
# Shield
# --------------------------------------------------------------------------------------
def shield_outline(kind, W, H):
    hw, hh = W / 2, H / 2
    if kind == "heater":
        half = [V2(0, hh + 0.05), V2(hw * 0.5, hh + 0.03), V2(hw, hh), V2(hw, hh * 0.15)]
        half += bezier(V2(hw, hh * 0.15), V2(hw * 0.98, -hh * 0.55), V2(0, -hh), 10)[1:]
        return mirror_u(half)
    if kind == "round":
        return ngon(0, 0, hw, 36)
    if kind == "kite":
        half = bezier(V2(0, hh), V2(hw * 1.02, hh * 1.0), V2(hw, hh * 0.35), 8)
        half += bezier(V2(hw, hh * 0.35), V2(hw * 0.86, -hh * 0.5), V2(0, -hh), 10)[1:]
        return mirror_u(half)
    if kind == "pavise":
        half = bezier(V2(0, hh), V2(hw * 0.75, hh), V2(hw, hh * 0.82), 6) + [V2(hw, -hh * 0.9), V2(hw * 0.85, -hh), V2(0, -hh)]
        return mirror_u(half)
    if kind == "tower":
        half = [V2(0, hh * 0.92)]
        for i in range(3):  # scalloped crown
            u0, u1 = hw * i / 3, hw * (i + 1) / 3
            half += bezier(V2(u0, hh * 0.92), V2((u0 + u1) / 2, hh * 1.06), V2(u1, hh * 0.92), 4)[1:]
        half += [V2(hw, hh * 0.92), V2(hw, -hh * 0.75)] + bezier(V2(hw, -hh * 0.75), V2(hw * 0.7, -hh * 1.0), V2(0, -hh), 5)[1:]
        return mirror_u(half)
    if kind == "hexorbit":
        return ngon(0, 0, hh, 6, 0)
    if kind in ("hex", "hexcluster"):
        return ngon(0, 0, hh, 6, math.pi / 2, sx=hw / hh / 0.866)
    if kind == "arch":
        half = bezier(V2(0, hh), V2(hw * 0.35, hh * 0.9), V2(hw, hh * 0.35), 8) + [V2(hw, -hh * 0.82), V2(hw * 0.8, -hh), V2(0, -hh)]
        return mirror_u(half)
    if kind == "monolith":
        c = 0.22
        return [V2(-hw + c, hh), V2(hw - c, hh), V2(hw, hh - c), V2(hw, -hh + c * 1.6), V2(hw - c * 1.6, -hh), V2(-hw + c * 1.6, -hh), V2(-hw, -hh + c * 1.6), V2(-hw, hh - c)]
    raise ValueError(kind)


def build_shield(spec, parts, rng):
    sh, tier = spec["shield"], spec["tier"]
    kind, W, H, t = sh["kind"], sh["W"], sh["H"], sh["t"]
    O = SHIELD_ORIGIN
    xc = 0.27 + t / 2  # plate centre in front of the forearm mount
    base = T(O.x - xc, O.y, O.z) @ RZ(90)  # local X -> width (+Y), local Y -> front (-X)
    ky, kz = sh.get("k", 0.12), sh.get("kz", 0.0)

    def warp(p):
        dy, dz = p.y - O.y, p.z - O.z
        return Vector((p.x + ky * dy * dy + kz * dz * dz, p.y, p.z))

    face = [parts[n] for n in ("ShieldPlate", "ShieldRim", "ShieldBoss", "ShieldRune")]
    for p in face:
        p.warp = warp
    Pl, Rim, Boss, Rn = face
    front = t / 2
    outline = shield_outline(kind, W, H)

    def at(u, z, f=0.0):  # local-frame point -> Blender point (no warp)
        return base @ Vector((u, f, z))

    def ring_path(pts, f):
        path = K.resample([at(p.x, p.y, f) for p in pts + [pts[0]]], max(24, len(pts) * 2))[:-1]
        return path

    # Plate ---------------------------------------------------------------------------
    if kind == "hexcluster":  # seven interlocking hex tiles
        r = H / 2 / 2.6
        cells = [(0, 0)] + [(1.75 * r * math.cos(math.radians(30 + 60 * i)), 1.75 * r * math.sin(math.radians(30 + 60 * i))) for i in range(6)]
        for i, (u, z) in enumerate(cells):
            hexo = ngon(u, z, r * 0.97, 6, 0)
            plate(Pl, hexo, t * (1.25 if i == 0 else 1.0), 0.06, base, rim_t=0.03)
            sweep(Rim, ring_path(hexo, 0.0), 0.06, t * 1.2 + 0.02, side=Vector((1, 0, 0)), segs=6, profile="oval", closed=True)
            if i:
                a = math.radians(60 * (i - 1))
                gem(Rn, tuple(at(r * math.cos(a), r * math.sin(a), t * 0.62)), 0.035, 0.1, 4, I4, (0, -math.pi / 2))
    elif kind == "hexorbit":  # six floating gold plates around the core
        r_in, r_out = 0.42, H / 2
        for i in range(6):
            a0, a1 = math.radians(60 * i + 4), math.radians(60 * (i + 1) - 4)
            pts = [V2(r_in * math.cos(a0), r_in * math.sin(a0)), V2(r_out * math.cos(a0), r_out * math.sin(a0)),
                   V2(r_out * 1.04 * math.cos((a0 + a1) / 2), r_out * 1.04 * math.sin((a0 + a1) / 2)),
                   V2(r_out * math.cos(a1), r_out * math.sin(a1)), V2(r_in * math.cos(a1), r_in * math.sin(a1))]
            plate(Pl, pts, t, 0.07, base @ K.T(0, 0.04 * (i % 2), 0))
            mid = V2((r_in + r_out) / 2 * math.cos((a0 + a1) / 2), (r_in + r_out) / 2 * math.sin((a0 + a1) / 2))
            plate(Rim, ngon(mid.x, mid.y, 0.12, 6, 0), 0.05, 0.02, base @ K.T(0, front + 0.03, 0))
            stroke(Rn, V2(r_in * 1.15 * math.cos((a0 + a1) / 2), r_in * 1.15 * math.sin((a0 + a1) / 2)), mid * 0.85, 0.03, 2 * front + 0.02, base, depth=0.012, sides=(1,))
    else:
        plate(Pl, outline, t, min(0.09, t * 0.7), base, rim_t=t * 0.35)

    # Rim -----------------------------------------------------------------------------
    rim = sh.get("rim")
    if rim in ("tube", "bands", "gravity"):
        sweep(Rim, ring_path(outline, 0.0), t * 1.25 + 0.03, 0.09 + 0.008 * tier, side=Vector((1, 0, 0)), segs=8, profile="oval", closed=True)
    if rim == "bands":  # iron corner brackets + plank bands
        for z in (H * 0.32, -H * 0.18):
            stroke(Rim, V2(-W / 2, z), V2(W / 2, z), 0.09, 2 * front, base, depth=0.025, sides=(1,))
        for s in (1, -1):
            stroke(Rim, V2(s * W * 0.5, H * 0.5), V2(s * W * 0.28, H * 0.5), 0.12, 2 * front, base, depth=0.03, sides=(1,))
            stroke(Rim, V2(s * W * 0.5, H * 0.5), V2(s * W * 0.5, H * 0.28), 0.12, 2 * front, base, depth=0.03, sides=(1,))
        for z in (H * 0.32, -H * 0.18):
            for u in (-W * 0.35, 0, W * 0.35):
                K.sphere(Rim, (u, front + 0.03, z), 0.035, 6, 4, base)
    if sh.get("planks"):
        for u in (-W * 0.25, 0.0, W * 0.25):
            stroke(Pl, V2(u, H * 0.48), V2(u, -H * 0.4 if abs(u) > 0 else -H * 0.48), 0.018, 2 * front, base, depth=0.006, sides=(1,))
    if rim == "hexrings":
        for k in (0.78, 0.55):
            sweep(Rim, ring_path(shield_outline("hex", W * k, H * k), front), 0.05, 0.07, side=Vector((1, 0, 0)), segs=6, profile="oval", closed=True)
        sweep(Rim, ring_path(outline, 0.0), t * 1.2 + 0.03, 0.1, side=Vector((1, 0, 0)), segs=6, profile="oval", closed=True)
    if rim == "gravity":  # floating gravity rings in front of the face
        for k, (rr, off) in enumerate(((W * 0.42, 0.12), (W * 0.31, 0.2), (W * 0.2, 0.28))):
            torus(Rim, rr, 0.03 - 0.004 * k, 40, 6, base @ T(0, front + off, 0) @ RX(-90) @ RX(8 * (k - 1)))
    if sh.get("rivets"):
        for s in (1, -1):
            for i in range(7):
                z = H * 0.38 - H * 0.72 * i / 6
                K.sphere(Rim, (s * W * 0.4, front + 0.02, z), 0.04, 6, 4, base)
    if sh.get("spokes"):
        for i in range(sh["spokes"]):
            a = 2 * math.pi * i / sh["spokes"]
            stroke(Rim, V2(0.2 * math.cos(a), 0.2 * math.sin(a)), V2(W * 0.47 * math.cos(a), W * 0.47 * math.sin(a)), 0.08, 2 * front, base, depth=0.02, sides=(1,))
    if sh.get("rays"):  # sunburst rays across the face
        n = sh["rays"]
        for i in range(n):
            a = math.pi / 2 + 2 * math.pi * i / n
            ln = (0.95 if i % 2 == 0 else 0.6) * min(W, H) * 0.48
            d, nrm = V2(math.cos(a), math.sin(a)), V2(-math.sin(a), math.cos(a))
            c = V2(0, H * 0.08)
            plate(Rim, [c + d * 0.22 + nrm * 0.06, c + d * ln, c + d * 0.22 - nrm * 0.06], 0.05, 0.02, base @ T(0, front + 0.02, 0))
    if sh.get("corona"):  # flame rays beyond the rim
        n = sh["corona"]
        for i in range(n):
            a = 2 * math.pi * (i + 0.5) / n
            d, nrm = V2(math.cos(a), math.sin(a)), V2(-math.sin(a), math.cos(a))
            r0 = W / 2 - 0.05
            ln = 0.32 if i % 2 == 0 else 0.2
            plate(Rim, [d * r0 + nrm * 0.1, d * (r0 + ln) + nrm * 0.03, d * (r0 + ln * 1.15), d * r0 - nrm * 0.1], t * 0.6, 0.03, base)
    if kind == "arch":  # rose-window tracery + side columns
        cz = H * 0.12
        torus(Rim, 0.55, 0.035, 36, 6, base @ T(0, front + 0.02, cz) @ RX(-90))
        torus(Rim, 0.3, 0.03, 30, 6, base @ T(0, front + 0.02, cz) @ RX(-90))
        for i in range(8):
            a = 2 * math.pi * i / 8
            stroke(Rim, V2(0.3 * math.cos(a), cz + 0.3 * math.sin(a)), V2(0.55 * math.cos(a), cz + 0.55 * math.sin(a)), 0.05, 2 * front, base, depth=0.025, sides=(1,))
        for s in (1, -1):
            stroke(Rim, V2(s * W * 0.36, -H * 0.42), V2(s * W * 0.36, H * 0.1), 0.08, 2 * front, base, depth=0.03, sides=(1,))
            stroke(Rim, V2(s * W * 0.36, H * 0.1), V2(0, H * 0.46), 0.07, 2 * front, base, depth=0.03, sides=(1,))
    if kind == "monolith":
        sweep(Rim, ring_path(shield_outline("monolith", W - 0.3, H - 0.3), front), 0.05, 0.04, side=Vector((1, 0, 0)), segs=6, profile="oval", closed=True)

    # Boss ----------------------------------------------------------------------------
    boss = sh.get("boss")
    bz = H * 0.08 if kind in ("heater", "kite", "arch") else 0.0
    Mb = base @ T(0, front - 0.01, bz) @ RX(-90)
    if boss == "dome":
        lathe(Boss, [(0.24, 0), (0.24, 0.03), (0.2, 0.1), (0.1, 0.17), (0, 0.19)], 14, Mb)
    elif boss == "spike":
        lathe(Boss, [(0.26, 0), (0.25, 0.04), (0.17, 0.12), (0.07, 0.18), (0.035, 0.3), (0, 0.42)], 14, Mb)
    elif boss == "ridge":
        plate(Boss, [V2(0, H * 0.45), V2(0.09, 0), V2(0, -H * 0.45), V2(-0.09, 0)], 0.1, 0.05, base @ T(0, front, 0))
        lathe(Boss, [(0.17, 0), (0.15, 0.06), (0.08, 0.12), (0, 0.13)], 6, Mb, phase=math.pi / 4)
    elif boss == "sun":
        plate(Boss, star(0, bz, 0.42, 0.2, 8), 0.06, 0.025, base @ T(0, front + 0.02, 0))
        lathe(Boss, [(0.17, 0), (0.15, 0.08), (0.06, 0.14), (0, 0.15)], 14, Mb)
    elif boss == "bar":
        plate(Boss, rrect(0, 0, 0.1, H * 0.4, 0.05), 0.09, 0.04, base @ T(0, front + 0.03, 0))
        plate(Boss, rrect(0, H * 0.05, W * 0.38, 0.09, 0.05), 0.09, 0.04, base @ T(0, front + 0.03, 0))
    elif boss == "crystal":
        for k in range(5):
            a = 2 * math.pi * k / 5
            gem(Boss, tuple(at(0.06 * math.cos(a), 0.06 * math.sin(a), front)), 0.08, 0.42 - 0.05 * (k % 2), 6, I4, (0.4 * math.sin(a), -math.pi / 2 + 0.4 * math.cos(a)))
        gem(Boss, tuple(at(0, 0, front)), 0.12, 0.6, 6, I4, (0, -math.pi / 2))
    elif boss == "speaker":
        prof = [(0.42, 0)]
        for i in range(6):
            prof += [(0.42 - 0.06 * i, 0.02 + 0.03 * (i % 2)), (0.39 - 0.06 * i, 0.025 + 0.012 * i)]
        prof += [(0.06, 0.09), (0, 0.11)]
        lathe(Boss, prof, 6, Mb, phase=math.pi / 6)
    elif boss == "gem":
        lathe(Boss, [(0.26, 0), (0.25, 0.05), (0.18, 0.09), (0.12, 0.1)], 16, Mb)
        cut_gem(Rn, (0, 0, 0.12), 0.13, 0.1, 10, Mb)
    elif boss == "dome_big":
        lathe(Boss, [(0.45, 0), (0.44, 0.06), (0.36, 0.17), (0.2, 0.25), (0, 0.28)], 20, Mb)
        torus(Boss, 0.47, 0.035, 30, 6, Mb @ T(0, 0, 0.02))
    elif boss == "rose":
        cut_gem(Rn, (0, 0, 0.03), 0.17, 0.14, 10, base @ T(0, front, H * 0.12) @ RX(-90))
        lathe(Boss, [(0.21, 0), (0.2, 0.05), (0.17, 0.06)], 14, base @ T(0, front - 0.01, H * 0.12) @ RX(-90))
    elif boss == "core":
        torus(Boss, 0.36, 0.06, 28, 8, base @ T(0, front, 0) @ RX(-90))
        sphere(Rn, (0, front + 0.1, 0), 0.26, 16, 10, base)
        torus(Boss, 0.52, 0.025, 32, 6, base @ T(0, front + 0.12, 0) @ RX(-90) @ RX(28) @ RY(18))
    elif boss == "star":
        plate(Boss, star(0, 0.2, 0.36, 0.1, 4), 0.06, 0.03, base @ T(0, front + 0.02, 0))
        cut_gem(Rn, (0, 0, 0.06), 0.1, 0.08, 8, base @ T(0, front, 0.2) @ RX(-90))
    elif boss == "blackhole":
        sphere(Boss, (0, front + 0.18, 0), 0.34, 18, 12, base)
        torus(Rn, 0.52, 0.05, 40, 6, base @ T(0, front + 0.18, 0) @ RX(-90) @ RX(18), sy=0.95)

    # Runes ---------------------------------------------------------------------------
    rn = sh.get("runes")
    f2 = 2 * front + 0.01
    if rn == "pavise":
        for i in range(5):
            z = H * 0.32 - i * H * 0.16
            for s in (1, -1):
                polyline(Rn, [V2(s * 0.2, z), V2(s * 0.38, z + 0.08), V2(s * 0.5, z)], 0.035, f2, base, depth=0.014, sides=(1,))
    elif rn == "cross":
        polyline(Rn, [V2(0, H * 0.4), V2(0, -H * 0.42)], 0.03, f2, base, depth=0.014, sides=(1,))
        polyline(Rn, [V2(-W * 0.38, H * 0.12), V2(W * 0.38, H * 0.12)], 0.03, f2, base, depth=0.014, sides=(1,))
    elif rn == "sun_ring":
        torus(Rn, 0.5 if tier < 5 else 0.6, 0.022, 36, 5, base @ T(0, front + 0.03, bz) @ RX(-90))
    elif rn == "slits":
        for s in (1, -1):
            for i in range(3):
                z = H * 0.25 - i * 0.24
                polyline(Rn, [V2(s * 0.22, z), V2(s * 0.62, z)], 0.04, f2, base, depth=0.014, sides=(1,))
    elif rn == "pips":
        pass  # placed with the hex tiles
    elif rn == "hexline":
        sweep(Rn, ring_path(shield_outline("hex", W * 0.66, H * 0.66), front + 0.01), 0.025, 0.04, side=Vector((1, 0, 0)), segs=4, profile="oval", closed=True)
    elif rn == "rings":
        for rr in (0.62, 0.78):
            torus(Rn, rr, 0.018, 40, 5, base @ T(0, front + 0.02, 0) @ RX(-90))
        sphere(Rn, (0, front + 0.3, 0), 0.06, 8, 5, base)
    elif rn == "spiral":
        pts = []
        for i in range(40):
            a = i * 0.45
            r = 0.04 + 0.006 * i
            pts.append(V2(r * math.cos(a), H * 0.12 + r * math.sin(a)))
        polyline(Rn, pts, 0.03, f2 + 0.04, base, depth=0.012, sides=(1,))
    elif rn == "constellation":
        stars = [V2(rng.uniform(-W * 0.38, W * 0.38), rng.uniform(-H * 0.4, H * 0.4)) for _ in range(9)]
        stars.sort(key=lambda p: p.y)
        for i, p in enumerate(stars):
            gem(Rn, tuple(at(p.x, p.y, front)), 0.03 + (0.018 if i % 3 == 0 else 0), 0.1, 4, I4, (0, -math.pi / 2))
        polyline(Rn, stars[:5], 0.014, f2, base, depth=0.008, sides=(1,))
        polyline(Rn, stars[4:], 0.014, f2, base, depth=0.008, sides=(1,))
    elif rn == "accretion":
        for k in range(3):
            a0 = 2 * math.pi * k / 3
            pts = []
            for i in range(16):
                a = a0 + i * 0.22
                r = W * 0.46 - i * 0.045
                pts.append(V2(r * math.cos(a), r * math.sin(a)))
            polyline(Rn, pts, 0.035, f2, base, depth=0.012, sides=(1,))

    # HandleS: forearm strap bracket behind the plate (not warped) --------------------
    Hs = parts["HandleS"]
    back = O.x - xc + t / 2 - 0.02  # back face of the plate (x grows towards the arm)
    lathe(Hs, [(0.07, -0.3), (0.075, -0.26), (0.07, 0.26), (0.07, 0.3)], 8, T(O.x + 0.04, O.y, O.z))
    for z in (0.26, -0.26):
        box(Hs, ((back + O.x + 0.04) / 2, O.y, O.z + z), (O.x + 0.04 - back + 0.04, 0.42, 0.07))
    box(Hs, (back + 0.02, O.y, O.z), (0.05, 0.5, 0.8))

    mount = O + Vector((-0.18, 0, 0))
    centre = at(0, bz, front + 0.12)
    return dict(mount=mount, centre=centre)


# --------------------------------------------------------------------------------------
# Assembly
# --------------------------------------------------------------------------------------
def build_weapon(spec):
    rng = random.Random(sum(ord(c) * (i + 1) for i, c in enumerate(spec["id"])))
    parts = {n: Part() for n in SWORD_PARTS + SHIELD_PARTS}
    gl, gh = spec["grip"]["L"], spec["guard"]["h"]
    z0 = gl / 2 + gh - 0.02
    build_grip(spec, parts)
    build_guard(spec, parts, rng)
    build_pommel(spec, parts, rng)
    bi = build_blade(spec, parts, z0, rng)
    build_runes(spec, parts, z0, bi, rng)
    si = build_shield(spec, parts, rng)
    top = bi["top"]
    info = dict(
        id=spec["id"], tier=spec["tier"], type="SWORD_SHIELD",
        grip=[0, 0, 0], tip=[0, 0, top], base=[0, 0, z0 + 0.05], core=[0, 0, z0 + spec["blade"]["L"] * 0.45],
        trail_bottom=[0, 0, z0 + 0.15], trail_top=[0, 0, top - 0.05],
        shield_mount=K.r3(si["mount"]), shield_centre=K.r3(si["centre"]), shield_origin=K.r3(SHIELD_ORIGIN),
    )
    return parts, info


def main():
    opts = K.parse_args(sys.argv)
    only = set(opts["only"].split(",")) if "only" in opts else None
    K.clear_scene()
    K.ensure_dir(OUT_DIR)
    manifest, built = {}, 0
    spacing = 4.4
    for spec in SPECS:
        if only and spec["id"] not in only:
            continue
        parts, info = build_weapon(spec)
        colours = {name: rgb(*c[1]) for name, c in spec["col"].items()}
        objs, tris, pinfo = K.realise(spec["id"], parts, colours)
        K.export_fbx(os.path.join(OUT_DIR, spec["id"] + ".fbx"), objs)
        for o in objs:  # contact sheet: sword flat-on, shield turned face-on beside it
            x = built * spacing
            if o.name in SHIELD_PARTS:
                o.matrix_world = T(x + 1.75, 0, 1.9) @ RZ(90) @ T(-SHIELD_ORIGIN.x, -SHIELD_ORIGIN.y, -SHIELD_ORIGIN.z)
            else:
                o.matrix_world = T(x, 0, 0)
            o.name = f"{spec['id']}_{o.name}"
        info["parts"] = {n: dict(centre=K.r3(c), size=K.r3(s), assembly="OffhandShield" if n in SHIELD_PARTS else "",
                                 material=spec["col"].get(n, ("Metal", (150, 150, 150)))[0], color=list(spec["col"].get(n, ("Metal", (150, 150, 150)))[1]))
                         for n, (c, s) in pinfo.items()}
        info["tris"] = tris
        manifest[spec["id"]] = info
        print(f"[sword] {spec['id']:32s} tier {spec['tier']} tris {tris:6d} parts {len(pinfo)}")
        built += 1
    if not only:
        K.write_json(os.path.join(OUT_DIR, "sword_shield_manifest.json"), manifest)
    if "preview" in opts:
        width = built * spacing + 0.6
        K.render_sheet(opts["preview"], (width / 2 - 0.9, -30, 2.2), (90, 0, 0), width, 3600, int(3600 * 7.0 / width))


main()
