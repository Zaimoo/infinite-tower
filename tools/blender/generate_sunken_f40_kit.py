"""
Sunken Sanctuary Floor 40 (Leviathan's Basin) sculpted assets, generated in headless Blender.

The drowned abyssal basin under the Sea-Dome (guide image: reference/Sunken Sanctuary 40.jpg):
- GreatTidebellTower (~136 x 272 x 48): monumental torn twin-buttress limestone bell-tower stump
  framing a giant central belfry arch with twisted bronze yoke, shattered bell remnant, flanking
  lancet wing-arches, navy-teal trident banners, and stepped stone plinth (>= 265 studs tall).
- SeaDomeArchRib (~68 x 112 x 18): sweeping dark-bronze & limestone geodesic Sea-Dome rib arch
  with riveted cross-bracing and translucent sea-glass pane strips.
- MaelstromSwirlRing (~140 x 16 x 140): sculpted 6-arm logarithmic spiral wave funnel with frothy
  curling crest ribbons for the client-animated whirlpool layers.
- ChainAnchorBollard (~20 x 26 x 20): stone anchor pier with bronze twin-fluke chain bollard,
  coiled heavy anchor chain links, and aqua flame brazier cap.
- ChainTowerRound (~32 x 74 x 32): round coral-encrusted Chain Tower with fluted limestone drum,
  bronze chain-winding capstan drum, trident banner, and ruined open lantern crown.
- DrownedAltar (~22 x 14 x 18): High Cantor's drowned circular stone altar with carved tide-spiral
  plinth, dropped bronze bell-hammer, glowing aqua tide-sigil, and votive urns.
- CantorPulpit (~20 x 24 x 18): carved reef pulpit with lancet canopy arch, stone lectern,
  coral-fossilized cantor robe silhouette, and glowing pearl lantern.
- AbyssReliquaryShrine (~22 x 28 x 20): vaulted deep-reef Pearl Reliquary shrine with open empty
  pearl cradle, carved scaled Leviathan-heart relief arch, and glowing aqua crystal vents.
- BellBargeWreck (~44 x 24 x 16): split timber-and-bronze wreck of the Great Tidebell transport
  barge with empty iron bell-cradle ribs, shattered mast, and trailing anchor chain.
- BrokenTideStatue (~26 x 48 x 20): waist-broken colossal limestone Nereth tide-monarch statue
  on a carved plinth with barnacle crown and snapped bronze trident.
- CrackedTidebell (~12 x 14 x 12): cracked verdigris bronze Tidebell resting canted on a stone
  cradle, bound in chain with glowing aqua fissure seams.
- ReefCoralTable (~18 x 16 x 16): multi-tiered glowing bioluminescent table-coral and branching
  reef cluster matching the Reef Horns in the guide image.
- KelpForestTall (~14 x 48 x 14): towering sinuous kelp stipes and sweeping translucent-tipped
  fronds with glowing aqua gas bladders.
- BubbleVentCluster (~14 x 8 x 14): abyssal stone hydrothermal vent chimneys with glowing aqua
  inner cores.
- DaisBrazierPedestal (~8 x 14 x 8): octagonal limestone dais-rim pedestal with bronze trident
  relief, chain-ring collar, wide bronze bowl, and cyan-aqua flame spire.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Run:
    PYTHONHASHSEED=0 /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_sunken_f40_kit.py

Outputs (assets-source/tower/sunken_f40_kit/):
    SunkenF40Kit.blend    the generated scene
    SunkenF40Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             contact-sheet renders
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "sunken_f40_kit")

kit_mod = runpy.run_path(os.path.join(HERE, "generate_tower_biome_kit.py"), init_globals={"RUN_KIT": False})

Template = kit_mod["Template"]
M = kit_mod["M"]
box = kit_mod["box"]
cone = kit_mod["cone"]
uvsphere = kit_mod["uvsphere"]
tube = kit_mod["tube"]
lathe = kit_mod["lathe"]
rock = kit_mod["rock"]
ring_mesh = kit_mod["ring_mesh"]
reset_scene = kit_mod["reset_scene"]
finalize = kit_mod["finalize"]
render_previews = kit_mod["render_previews"]


def rock_clean(bm, size, mat, seed, roughness=0.22, subdiv=2, flat_bottom=True):
    tmp = bmesh.new()
    rock(tmp, size, mat, seed, roughness=roughness, subdiv=subdiv, flat_bottom=flat_bottom)
    vmap = [bm.verts.new(v.co) for v in tmp.verts]
    for f in tmp.faces:
        bm.faces.new([vmap[v.index] for v in f.verts])
    tmp.free()


def round_arch(bm, half_span, rise, thick, depth, mat, segs=12):
    pts = []
    for k in range(segs + 1):
        a = math.pi * k / segs
        pts.append(Vector((math.cos(a) * half_span, 0.0, math.sin(a) * rise)))
    for k in range(segs):
        p0, p1 = pts[k], pts[k + 1]
        mid = (p0 + p1) / 2
        d = p1 - p0
        ang = math.atan2(d.z, d.x)
        box(bm, (d.length + thick * 0.35, depth, thick), mat @ M((mid.x, 0, mid.z), rot=(0, -ang, 0)))


def pointed_arch(bm, half_span, rise, thick, depth, mat, segs=10):
    half = max(3, segs // 2)
    for side in (-1, 1):
        pts = []
        for k in range(half + 1):
            t = k / half
            x = side * half_span * (1.0 - t) ** 1.18
            z = rise * math.sin(t * math.pi * 0.5)
            pts.append(Vector((x, 0.0, z)))
        for k in range(half):
            p0, p1 = pts[k], pts[k + 1]
            mid = (p0 + p1) / 2
            d = p1 - p0
            ang = math.atan2(d.z, d.x)
            box(bm, (d.length + thick * 0.32, depth, thick), mat @ M((mid.x, 0, mid.z), rot=(0, -ang, 0)))


def trident_glyph(bm, mat, scale=1.0):
    box(bm, (0.55 * scale, 0.45 * scale, 6.4 * scale), mat @ M((0, 0, 0)))
    box(bm, (3.4 * scale, 0.45 * scale, 0.55 * scale), mat @ M((0, 0, 1.55 * scale)))
    for sx in (-1, 1):
        box(bm, (0.48 * scale, 0.45 * scale, 2.6 * scale), mat @ M((sx * 1.55 * scale, 0, 2.75 * scale)))


def chain_link(bm, mat, radius=1.2, wire=0.32):
    ring_mesh(bm, radius, wire, 10, mat, tube_segs=5)


def banner_drape(bm_silk, bm_gold, mat, w=5.6, h=18.0):
    """Hanging navy-teal Nereth banner with notched swallowtail hem & golden trident."""
    box(bm_gold, (w * 1.15, 0.75, 0.75), mat @ M((0, 0, h * 0.5)))
    box(bm_silk, (w, 0.35, h * 0.84), mat @ M((0, 0, h * 0.08)))
    for sx in (-1, 1):
        box(bm_silk, (w * 0.44, 0.35, h * 0.22), mat @ M((sx * w * 0.28, 0, -h * 0.39)))
    trident_glyph(bm_gold, mat @ M((0, -0.25, h * 0.05)), scale=w * 0.14)


def coral_tuft(bm, mat, scale=1.0):
    """Branching reef coral cluster (recolored to violet/lavender/aqua in Luau)."""
    arms = [
        ((0, 0, 0), (0.0, 0.0, 3.4), 0.72, 0.32),
        ((0, 0, 0.9), (1.9, 0.4, 3.6), 0.54, 0.24),
        ((0, 0, 1.0), (-1.8, -0.5, 3.4), 0.54, 0.24),
        ((0, 0, 1.2), (0.4, -1.7, 3.1), 0.46, 0.20),
        ((0, 0, 1.3), (-0.5, 1.6, 3.0), 0.46, 0.20),
    ]
    for a, b, r0, r1 in arms:
        pa = Vector(a) * scale
        pb = Vector(b) * scale
        d = pb - pa
        q = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        cone(bm, r0 * scale, r1 * scale, d.length, 6, mat @ M((pa.x, pa.y, pa.z)) @ q)
        uvsphere(bm, r1 * 1.35 * scale, mat @ M((pb.x, pb.y, pb.z)), u=5, v=4)


# =============================================================================
# 1. GreatTidebellTower (~136 x 272 x 48) — torn monumental bell-tower stump
#    (matches guide image: twin ribbed limestone buttresses, giant central
#     belfry arch with suspended bronze bell yoke & cracked bell remnant,
#     flanking wing arches, hanging trident banners, >= 265 studs tall!)
# =============================================================================
def make_great_tidebell_tower(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    metal = t.bm("METAL")
    gold = t.bm("GOLD")
    silk = t.bm("SILK")
    moss = t.bm("MOSS")
    glow = t.bm("GLOW")

    # Broad stepped monument plinth grounded cleanly at z = 0
    box(stone, (132.0, 44.0, 14.0), M((0, 0, 7.0)))
    box(trim, (124.0, 40.0, 6.0), M((0, 0, 17.0)))
    box(stone, (108.0, 34.0, 20.0), M((0, 0, 30.0)))

    # Massive lower curtain base behind central arch (framed spillway + niche)
    box(stone, (56.0, 26.0, 48.0), M((0, 4.0, 64.0)))
    box(trim, (62.0, 4.0, 4.5), M((0, -8.5, 88.0)))

    # Twin colossal vertical tower buttress piers rising to ragged torn crowns (West 248, East 272)
    pier_specs = [(-36.0, 248.0, -1), (36.0, 272.0, 1)]
    for px, top_z, side in pier_specs:
        # Lower massive pier shaft (z = 20 .. 148)
        box(stone, (26.0, 32.0, 128.0), M((px, 0, 84.0)))
        # Outer stepped flying buttress fin
        box(stone, (14.0, 22.0, 110.0), M((px + side * 16.0, 2.0, 75.0)))
        box(trim, (16.0, 24.0, 4.5), M((px + side * 16.0, 2.0, 130.0)))
        # Upper narrower belfry pier shaft (z = 148 .. top_z - 16)
        upper_h = top_z - 164.0
        box(stone, (20.0, 26.0, upper_h), M((px, 0, 148.0 + upper_h * 0.5)))
        # Horizontal moulded cornice bands
        for cz in (52.0, 96.0, 148.0, 198.0):
            if cz < top_z - 18.0:
                w = 30.0 if cz <= 148.0 else 24.0
                d = 36.0 if cz <= 148.0 else 30.0
                box(trim, (w, d, 4.5), M((px, 0, cz)))
        # Fluted front & side vertical ribs
        for rx in (-8.0, 0.0, 8.0):
            rib_h = top_z - 34.0
            box(trim, (2.6, 3.2, rib_h), M((px + rx, -14.5 if rib_h < 150 else -13.0, 20.0 + rib_h * 0.5)))
        # Torn jagged ruin crown spires at the top (so East reaches exactly 272.0 studs!)
        jag_heights = [(-6.5, 16.0), (0.0, 10.0), (6.5, 13.5)] if side == 1 else [(-6.5, 12.0), (0.0, 16.0), (6.5, 8.5)]
        for ox, jh in jag_heights:
            base_z = top_z - 16.0
            box(stone, (6.2, 18.0, jh), M((px + ox, 0, base_z + jh * 0.5)))
            box(trim, (4.0, 12.0, 3.0), M((px + ox, -1.5, base_z + jh - 1.5)))
        # Lancet blind windows carved on pier face
        for wz in (112.0, 166.0):
            if wz < top_z - 34.0:
                box(accent, (6.0, 2.0, 22.0), M((px, -13.5, wz)))
                pointed_arch(trim, 4.2, 7.0, 2.0, 3.2, M((px, -13.8, wz + 11.0)), segs=8)
        # Moss & algae streaks draping down pier flanks
        box(moss, (5.5, 12.0, 38.0), M((px + side * 12.5, -6.0, 44.0)))
        box(moss, (4.8, 10.0, 30.0), M((px - side * 11.5, -10.0, 96.0)))

    # Giant central belfry arch spanning between the twin piers (z = 165..205)
    round_arch(stone, 28.0, 34.0, 11.0, 24.0, M((0, 0, 174.0)), segs=14)
    round_arch(trim, 25.0, 31.0, 4.5, 26.5, M((0, 0, 174.0)), segs=14)
    # Torn upper spandrel & heavy bridge cross-beam above the central arch
    box(stone, (58.0, 22.0, 16.0), M((0, 0, 214.0)))
    box(trim, (62.0, 25.0, 4.5), M((0, 0, 222.0)))
    # Torn masonry teeth along the broken central crest
    for tx, th in ((-18.0, 12.0), (-9.0, 7.0), (10.0, 9.5), (19.0, 15.0)):
        box(stone, (7.0, 16.0, th), M((tx, 0, 224.0 + th * 0.5)))

    # Secondary lower central arch framing the cascade opening (z = 88..126)
    round_arch(stone, 24.0, 24.0, 8.5, 20.0, M((0, 0, 102.0)), segs=12)
    round_arch(trim, 22.0, 22.0, 3.6, 22.0, M((0, 0, 102.0)), segs=12)

    # Flanking wing-arches extending left & right (like the guide image's side ruins)
    for side in (-1, 1):
        wx = side * 56.0
        box(stone, (14.0, 22.0, 116.0), M((wx + side * 6.0, 2.0, 72.0)))
        box(trim, (16.0, 24.0, 4.0), M((wx + side * 6.0, 2.0, 130.0)))
        round_arch(stone, 14.0, 18.0, 6.5, 18.0, M((wx - side * 5.0, 2.0, 100.0)), segs=10)
        box(stone, (10.0, 14.0, 16.0), M((wx + side * 6.0, 2.0, 138.0)))

    # Twisted bronze bell yoke + cracked remnant of the Great Tidebell suspended in the belfry arch
    box(metal, (54.0, 5.5, 6.0), M((0, 0, 190.0), rot=(0, 0.06, 0)))
    box(gold, (18.0, 7.5, 7.5), M((0, 0, 190.0), rot=(0, 0.06, 0)))
    # Vertical bronze yoke suspension rods & chains
    for rx in (-10.0, 10.0):
        cone(metal, 1.4, 1.4, 34.0, 8, M((rx, 0, 156.0)))
    # Massive shattered Tidebell body hanging slightly canted inside the arch
    bell_mat = M((0.0, 0.0, 134.0), rot=(0.08, -0.14, 0.0))
    bell_prof = [
        (16.5, 0.0), (17.2, 2.5), (14.2, 8.5), (11.5, 18.0),
        (9.6, 28.0), (7.5, 34.0), (0.0, 37.0),
    ]
    lathe(accent, bell_prof, 16, bell_mat)
    # Decorative bronze rim & golden tide-band on bell
    ring_mesh(gold, 16.4, 1.1, 16, bell_mat @ M((0, 0, 2.8)), tube_segs=6)
    ring_mesh(gold, 12.2, 0.85, 16, bell_mat @ M((0, 0, 15.0)), tube_segs=6)
    # Clapper hanging beneath the bell
    cone(metal, 1.2, 1.0, 16.0, 8, bell_mat @ M((0, 0, -10.0)))
    uvsphere(metal, 3.2, bell_mat @ M((0, 0, -10.0)), u=8, v=6)

    # Twin giant hanging navy-teal Nereth trident banners on lower front pier faces
    for side in (-1, 1):
        banner_drape(silk, gold, M((side * 34.0, -17.5, 72.0)), w=12.0, h=42.0)
        # Glowing aqua flame braziers atop the outer wing pedestals
        box(trim, (8.0, 8.0, 5.0), M((side * 56.0, -10.0, 42.0)))
        cone(glow, 3.2, 0.6, 7.5, 8, M((side * 56.0, -10.0, 44.5)))


# =============================================================================
# 2. SeaDomeArchRib (~68 x 112 x 18) — geodesic Sea-Dome overhead arch rib
# =============================================================================
def make_sea_dome_arch_rib(t: Template):
    metal = t.bm("METAL")
    stone = t.bm("STONE")
    accent = t.bm("ACCENT")
    crystal = t.bm("CRYSTAL")

    # Sweeping convex quarter-arch dome rib rising vertically from rim (x=-32, z=0)
    # and curving gracefully overhead toward the Eye of Daylight (x=+32, z=112)
    segs = 12
    pts = []
    max_ang = math.pi * 0.48
    for k in range(segs + 1):
        u = k / segs
        ang = u * max_ang
        x = -32.0 + (1.0 - math.cos(ang)) * 64.0 / (1.0 - math.cos(max_ang))
        z = 4.0 + math.sin(ang) * 108.0 / math.sin(max_ang)
        pts.append(Vector((x, 0.0, z)))

    # Stone base shoe grounded cleanly at z = 0
    box(stone, (12.0, 16.0, 14.0), M((-32.0, 0, 7.0)))
    box(metal, (10.0, 14.0, 4.0), M((-32.0, 0, 15.0)))

    for k in range(segs):
        p0, p1 = pts[k], pts[k + 1]
        mid = (p0 + p1) / 2
        d = p1 - p0
        pitch = math.atan2(d.z, d.x)
        # Twin heavy dark-bronze main chords
        for sy in (-5.5, 5.5):
            box(metal, (d.length + 1.8, 3.4, 5.2), M((mid.x, sy, mid.z), rot=(0, -pitch, 0)))
        # Cross purlin tie-bar
        box(accent, (2.6, 15.0, 3.0), M((mid.x, 0, mid.z), rot=(0, -pitch, 0)))
        # Translucent sea-glass dome panel strip nestled between the chords
        box(crystal, (d.length + 0.6, 10.2, 1.0), M((mid.x, 0, mid.z + 1.5), rot=(0, -pitch, 0)))


# =============================================================================
# 3. MaelstromSwirlRing (~140 x 16 x 140) — sculpted 6-arm whirlpool spiral
#    (rotated smoothly around Y on the client for the animated whirlpool!)
# =============================================================================
def make_maelstrom_swirl_ring(t: Template):
    alt = t.bm("ALT")          # deep turquoise water ridge
    crystal = t.bm("CRYSTAL")  # translucent aqua wave crest
    silk = t.bm("SILK")        # frothy white-cyan foam ribbon
    glow = t.bm("GLOW")        # bright bioluminescent inner-eye foam shimmer

    arms = 6
    steps = 14
    r_inner = 26.0
    r_outer = 68.0
    for arm in range(arms):
        base_ang = (2.0 * math.pi * arm) / arms
        prev = None
        for k in range(steps + 1):
            u = k / steps
            # Logarithmic-feel inward-tightening spiral (outer rim higher z=14, inner eye lower z=0.8)
            r = r_outer * (1.0 - u) + r_inner * u
            ang = base_ang + u * 2.35
            z = 1.2 + (1.0 - u) ** 1.35 * 13.0 + math.sin(u * math.pi * 3.0 + arm) * 0.9
            p = Vector((math.cos(ang) * r, math.sin(ang) * r, z))
            if prev is not None:
                mid = (prev + p) / 2
                d = p - prev
                yaw = math.atan2(d.y, d.x)
                pitch = -math.atan2(d.z, math.hypot(d.x, d.y))
                seg_len = d.length * 1.18
                width = 9.5 * (1.0 - u * 0.42)
                thick = 3.2 * (1.0 - u * 0.35)
                # Sweeping turquoise water-wall ridge
                box(alt, (seg_len, width, thick), M((mid.x, mid.y, mid.z), rot=(0.24, pitch, yaw)))
                # Translucent crest lip curling slightly inward
                box(crystal, (seg_len * 0.96, width * 0.58, thick * 0.62),
                    M((mid.x, mid.y, mid.z + thick * 0.55), rot=(0.35, pitch, yaw)))
                # Frothy sea-foam ribbon riding the wave crest
                if k % 2 == 0 or u > 0.55:
                    foam_bm = glow if u > 0.72 else silk
                    box(foam_bm, (seg_len * 0.9, width * 0.28, 1.15),
                        M((mid.x, mid.y, mid.z + thick * 0.95), rot=(0.18, pitch, yaw)))
            prev = p

    # Outer broken spray arcs & inner eye whitewater collar
    ring_mesh(silk, r_inner + 1.5, 1.3, 24, M((0, 0, 1.3)), tube_segs=5)
    ring_mesh(glow, r_inner - 1.0, 0.95, 20, M((0, 0, 0.95)), tube_segs=5)


# =============================================================================
# 4. ChainAnchorBollard (~20 x 26 x 20) — heavy bronze chain-bridge anchor pier
# =============================================================================
def make_chain_anchor_bollard(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    metal = t.bm("METAL")
    gold = t.bm("GOLD")
    glow = t.bm("GLOW")

    # Stepped octagonal-feel stone pier base grounded at z = 0
    cone(stone, 9.8, 8.6, 5.0, 8, M((0, 0, 0)))
    cone(trim, 8.2, 7.2, 8.0, 8, M((0, 0, 5.0)))
    cone(stone, 7.6, 6.2, 3.0, 8, M((0, 0, 13.0)))

    # Massive bronze twin-fluke anchor bollard drum rising from the stone pier
    cone(metal, 4.4, 3.6, 7.0, 10, M((0, 0, 15.5)))
    ring_mesh(gold, 4.2, 0.65, 12, M((0, 0, 17.5)), tube_segs=5)
    ring_mesh(metal, 4.8, 0.85, 12, M((0, 0, 21.5)), tube_segs=6)
    # Cross mooring horns
    box(metal, (14.0, 2.2, 2.2), M((0, 0, 19.5)))
    for sx in (-1, 1):
        uvsphere(gold, 1.55, M((sx * 7.2, 0, 19.5)), u=7, v=5)

    # Coiled giant bronze anchor chain links wrapped around waist + trailing lug
    for k in range(6):
        a = k * math.pi / 3.0
        chain_link(metal, M((math.cos(a) * 5.2, math.sin(a) * 5.2, 16.8), rot=(0.4, 0, a + 0.5)), radius=1.55, wire=0.45)
    # Heavy chain eye-ring facing front (-Y)
    chain_link(gold, M((0, -6.4, 17.0), rot=(math.pi / 2, 0, 0)), radius=2.2, wire=0.55)

    # Aqua flame brazier crown atop the bollard
    cone(metal, 2.4, 3.4, 1.8, 8, M((0, 0, 22.2)))
    cone(glow, 1.9, 0.25, 3.2, 8, M((0, 0, 23.2)))


# =============================================================================
# 5. ChainTowerRound (~32 x 74 x 32) — round coral-encrusted Chain Tower
# =============================================================================
def make_chain_tower_round(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    metal = t.bm("METAL")
    gold = t.bm("GOLD")
    coral = t.bm("CORAL")
    silk = t.bm("SILK")
    glow = t.bm("GLOW")

    # Stepped circular drum foundation grounded at z = 0
    cone(stone, 15.5, 14.2, 10.0, 14, M((0, 0, 0)))
    cone(trim, 14.8, 13.8, 3.5, 14, M((0, 0, 10.0)))
    # Tall fluted limestone tower shaft (z = 13.5..58)
    cone(stone, 13.2, 11.4, 44.5, 14, M((0, 0, 13.5)))
    for cz in (26.0, 42.0, 56.5):
        ring_mesh(trim, 12.8 - (cz - 26.0) * 0.04, 1.05, 14, M((0, 0, cz)), tube_segs=6)
    # Vertical stone pilasters around drum
    for k in range(8):
        a = k * math.pi / 4.0
        box(trim, (2.2, 2.4, 42.0), M((math.cos(a) * 12.2, math.sin(a) * 12.2, 34.5), rot=(0, 0, a)))

    # Giant bronze chain-winding capstan wheel protruding on the front-side (-Y)
    ring_mesh(metal, 6.2, 1.1, 14, M((0, -13.2, 34.0), rot=(math.pi / 2, 0, 0)), tube_segs=6)
    cone(gold, 2.4, 2.4, 5.0, 10, M((0, -10.8, 34.0), rot=(math.pi / 2, 0, 0)))
    for k in range(6):
        a = k * math.pi / 3.0
        box(metal, (1.1, 1.1, 12.0), M((math.cos(a) * 0.1, -13.2, 34.0), rot=(0, a, 0)))
    # Hanging chain links dropping from capstan
    for kz in range(5):
        chain_link(metal, M((0, -14.2, 27.5 - kz * 2.8), rot=(0, math.pi / 2 if kz % 2 else 0, 0)), radius=1.5, wire=0.4)

    # Open ruined lantern crown at top (z = 58..74)
    for k in range(6):
        a = k * math.pi / 3.0
        col_h = 12.0 if k % 2 == 0 else 9.0
        cone(trim, 1.35, 1.15, col_h, 8, M((math.cos(a) * 9.5, math.sin(a) * 9.5, 58.0)))
    ring_mesh(trim, 9.6, 1.15, 12, M((0, 0, 69.5)), tube_segs=6)
    # Glowing aqua beacon core inside crown
    cone(glow, 3.0, 0.5, 6.5, 8, M((0, 0, 59.5)))
    # Hanging trident banner on opposite side
    banner_drape(silk, gold, M((0, 13.6, 42.0), rot=(0, 0, math.pi)), w=5.6, h=18.0)
    # Encrusting reef coral clusters around base & ledge
    coral_tuft(coral, M((-11.5, -8.0, 9.5), rot=(0.2, 0, 0.5)), scale=1.35)
    coral_tuft(coral, M((11.0, -7.5, 25.5), rot=(-0.2, 0.2, -0.6)), scale=1.15)


# =============================================================================
# 6. DrownedAltar (~22 x 14 x 18) — High Cantor's drowned altar & bell-hammer
# =============================================================================
def make_drowned_altar(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    glow = t.bm("GLOW")
    coral = t.bm("CORAL")

    # Stepped circular/oval altar dais grounded at z = 0
    cone(stone, 10.8, 10.2, 2.2, 14, M((0, 0, 0)))
    cone(trim, 8.8, 8.2, 2.0, 14, M((0, 0, 2.2)))

    # Carved altar table block with fluted legs
    box(stone, (11.5, 6.4, 5.2), M((0, -0.5, 6.8)))
    box(trim, (13.0, 7.6, 1.4), M((0, -0.5, 9.9)))
    trident_glyph(gold, M((0, -3.9, 6.8)), scale=0.68)

    # Glowing tide-spiral disc resting on altar top
    ring_mesh(glow, 2.4, 0.28, 14, M((0, -0.5, 10.8)), tube_segs=5)
    ring_mesh(gold, 1.4, 0.22, 12, M((0, -0.5, 10.9)), tube_segs=5)

    # Dropped verdigris bronze bell-hammer lying askew across the altar slab
    cone(accent, 0.42, 0.36, 7.2, 8, M((-2.8, -1.2, 11.2), rot=(0.08, math.pi / 2, 0.35)))
    box(accent, (2.6, 1.7, 1.7), M((3.2, 0.8, 11.4), rot=(0, 0, 0.35)))
    ring_mesh(gold, 0.95, 0.2, 10, M((3.2, 0.8, 11.4), rot=(0, math.pi / 2, 0.35)), tube_segs=5)

    # Flanking carved votive pillars behind the altar
    for sx in (-1, 1):
        cone(trim, 1.45, 1.15, 8.5, 8, M((sx * 6.8, 3.8, 4.2)))
        uvsphere(glow, 1.1, M((sx * 6.8, 3.8, 13.2)), u=7, v=5)
    coral_tuft(coral, M((-7.4, -3.2, 2.2)), scale=0.85)
    coral_tuft(coral, M((7.2, 2.6, 2.2)), scale=0.75)


# =============================================================================
# 7. CantorPulpit (~20 x 24 x 18) — reef pulpit with coral-fossilized robes
# =============================================================================
def make_cantor_pulpit(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    coral = t.bm("CORAL")
    gold = t.bm("GOLD")
    glow = t.bm("GLOW")

    # Stepped pulpit base grounded at z = 0
    cone(stone, 9.4, 8.4, 4.2, 10, M((0, 0, 0)))
    # Curved low parapet wall around front (-Y)
    for k in range(7):
        a = -math.pi * 0.85 + (math.pi * 0.70) * (k / 6.0)
        box(trim, (2.8, 1.6, 5.2), M((math.cos(a) * 6.8, math.sin(a) * 6.8, 6.8), rot=(0, 0, a + math.pi / 2)))
    # Rear lancet canopy arch framing the pulpit
    for sx in (-1, 1):
        cone(stone, 1.5, 1.3, 14.0, 8, M((sx * 5.6, 4.2, 4.0)))
    pointed_arch(trim, 6.0, 6.2, 1.8, 2.8, M((0, 4.2, 17.5)), segs=10)
    # Stone lectern + open scroll slab
    cone(trim, 1.3, 0.95, 5.4, 8, M((0, -3.6, 4.2)))
    box(gold, (3.4, 2.4, 0.55), M((0, -3.6, 9.8), rot=(0.35, 0, 0)))
    # Coral-fossilized cantor robe silhouette standing behind the lectern
    cone(coral, 2.2, 1.15, 7.2, 8, M((0, 0.5, 4.2)))
    uvsphere(coral, 1.2, M((0, 0.5, 12.2)), u=7, v=5)
    coral_tuft(coral, M((1.6, 0.4, 8.5), rot=(0.2, 0.3, 0)), scale=0.85)
    # Hanging pearl lantern under canopy crown
    cone(gold, 0.25, 0.25, 3.0, 6, M((0, 3.0, 19.0)))
    uvsphere(glow, 1.15, M((0, 3.0, 18.2)), u=7, v=5)


# =============================================================================
# 8. AbyssReliquaryShrine (~22 x 28 x 20) — empty Pearl Reliquary & heart door
# =============================================================================
def make_abyss_reliquary_shrine(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    crystal = t.bm("CRYSTAL")
    glow = t.bm("GLOW")

    # Stepped sanctuary plinth grounded at z = 0
    box(stone, (21.0, 19.0, 3.6), M((0, 0, 1.8)))
    box(trim, (17.5, 16.0, 2.2), M((0, 0, 4.7)))

    # Vaulted rear apse wall with carved Leviathan-heart scaled door relief
    box(stone, (16.0, 4.2, 17.0), M((0, 5.2, 14.2)))
    round_arch(trim, 8.2, 7.2, 2.4, 5.0, M((0, 5.2, 20.5)), segs=10)
    # Scaled Leviathan-heart medallion on the door
    ring_mesh(gold, 4.0, 0.55, 14, M((0, 2.9, 14.5), rot=(math.pi / 2, 0, 0)), tube_segs=6)
    uvsphere(accent, 2.8, M((0, 3.1, 14.5)), u=8, v=6)

    # Four corner columns supporting the reliquary canopy
    for sx in (-1, 1):
        for sy in (-1, 1):
            cone(trim, 1.35, 1.1, 16.5, 8, M((sx * 6.8, sy * 5.2, 5.8)))
    box(stone, (16.5, 13.5, 2.4), M((0, 0, 23.0)))
    cone(accent, 6.2, 1.0, 4.2, 10, M((0, 0, 24.0)))

    # Open empty pearl cradle pedestal at center
    cone(trim, 2.4, 1.6, 4.2, 10, M((0, -1.6, 5.8)))
    for k in range(6):
        a = k * math.pi / 3.0
        box(gold, (0.65, 1.8, 2.6), M((math.cos(a) * 2.1, -1.6 + math.sin(a) * 2.1, 10.6), rot=(0.45, 0, a + math.pi / 2)))
    # Subtle residual aqua shimmer inside empty cradle
    uvsphere(glow, 0.95, M((0, -1.6, 10.8)), u=7, v=5)
    # Flanking translucent crystal shards
    for sx in (-1, 1):
        cone(crystal, 1.2, 0.15, 6.2, 6, M((sx * 8.6, -4.0, 3.6), rot=(0.2, sx * 0.25, 0)))


# =============================================================================
# 9. BellBargeWreck (~44 x 24 x 16) — split Great Tidebell barge with empty cradle
# =============================================================================
def make_bell_barge_wreck(t: Template):
    wood = t.bm("WOOD")
    metal = t.bm("METAL")
    accent = t.bm("ACCENT")
    moss = t.bm("MOSS")
    gold = t.bm("GOLD")

    # Broad heeled wooden hull broken into fore and aft sections grounded at z = 0
    box(wood, (24.0, 13.0, 4.4), M((-8.0, 0.0, 2.4), rot=(0.14, 0.04, 0.05)))
    box(wood, (18.0, 12.2, 4.0), M((12.0, 0.8, 2.1), rot=(-0.10, -0.06, -0.14)))
    # Raised bow & stern sheer bulwarks
    box(wood, (6.5, 11.5, 5.6), M((-18.5, 0.0, 4.8), rot=(0.12, -0.25, 0.05)))
    box(wood, (5.5, 10.8, 5.0), M((19.5, 1.4, 4.2), rot=(-0.10, 0.22, -0.14)))
    # Exposed curved hull ribs along sides
    for rx in (-14.0, -9.0, -4.0, 1.0, 7.0, 13.0):
        for sy in (-1, 1):
            box(wood, (1.1, 1.2, 6.8), M((rx, sy * 6.0, 4.8), rot=(sy * 0.22, 0, 0)))

    # Empty heavy iron-and-bronze Great Tidebell cradle frame amidships
    for sx in (-1, 1):
        box(metal, (1.8, 10.6, 2.0), M((sx * 6.2 - 3.0, 0.0, 5.4)))
        cone(metal, 1.0, 0.85, 11.5, 8, M((sx * 6.2 - 3.0, -4.6, 5.2), rot=(0.18, 0, 0)))
        cone(metal, 1.0, 0.85, 11.5, 8, M((sx * 6.2 - 3.0, 4.6, 5.2), rot=(-0.18, 0, 0)))
    box(metal, (14.5, 2.2, 2.2), M((-3.0, 0.0, 16.0)))
    ring_mesh(gold, 2.2, 0.45, 10, M((-3.0, 0.0, 14.0), rot=(math.pi / 2, 0, 0)), tube_segs=5)

    # Shattered leaning mast & yardarm
    cone(wood, 1.35, 0.85, 22.0, 8, M((8.5, 0.4, 3.0), rot=(0.12, -0.28, 0)))
    box(wood, (12.0, 1.1, 1.1), M((5.0, -0.6, 15.5), rot=(0.2, 0.4, 0.2)))
    # Verdigris prow emblem & kelp moss drape
    trident_glyph(accent, M((-21.5, 0.0, 5.2), rot=(0, 0, math.pi / 2)), scale=0.6)
    box(moss, (9.0, 4.2, 2.2), M((-10.0, -5.8, 3.2)))
    box(moss, (7.5, 3.6, 2.0), M((10.0, 5.2, 2.8)))


# =============================================================================
# 10. BrokenTideStatue (~26 x 48 x 20) — waist-broken Nereth tide-monarch
# =============================================================================
def make_broken_tide_statue(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    moss = t.bm("MOSS")
    glow = t.bm("GLOW")

    # Stepped carved plinth grounded at z = 0
    box(stone, (24.0, 18.0, 5.5), M((0, 0, 2.75)))
    box(trim, (20.0, 15.0, 7.5), M((0, 0, 9.25)))
    box(stone, (21.5, 16.2, 2.2), M((0, 0, 14.1)))
    trident_glyph(glow, M((0, -7.8, 9.2)), scale=0.72)

    # Lower draped robe & armored torso rising to jagged waist/shoulder break (z = 15..44)
    cone(stone, 7.4, 5.8, 14.0, 10, M((0, 0, 15.0)))
    box(stone, (13.5, 8.8, 12.0), M((0, 0, 34.0), rot=(0.06, -0.05, 0)))
    # Broad carved pauldrons & cloak folds
    for sx in (-1, 1):
        uvsphere(trim, 3.6, M((sx * 7.4, 0.0, 38.0)), u=8, v=6)
    # Tilted noble head & barnacle-rimmed crown (slightly leaning, eroded)
    uvsphere(stone, 3.4, M((-0.6, -0.4, 43.2)), u=8, v=6)
    ring_mesh(gold, 3.3, 0.55, 10, M((-0.6, -0.4, 46.2), rot=(0.12, -0.14, 0)), tube_segs=5)
    for k in range(5):
        a = -math.pi * 0.7 + k * (math.pi * 0.35)
        cone(gold, 0.55, 0.12, 2.4, 5, M((-0.6 + math.cos(a) * 3.1, -0.4 + math.sin(a) * 3.1, 46.2)))

    # Snapped bronze trident shaft gripped on right & fallen broken fork at plinth foot
    cone(accent, 0.75, 0.65, 22.0, 8, M((7.8, -2.5, 16.0), rot=(-0.12, 0.18, 0)))
    trident_glyph(accent, M((-7.0, -8.2, 2.0), rot=(math.pi / 2, 0, 0.5)), scale=1.05)
    box(moss, (5.0, 3.5, 8.0), M((-6.5, -2.0, 22.0)))


# =============================================================================
# 11. CrackedTidebell (~12 x 14 x 12) — cracked chain-bound bronze Tidebell
# =============================================================================
def make_cracked_tidebell(t: Template):
    stone = t.bm("STONE")
    accent = t.bm("ACCENT")
    metal = t.bm("METAL")
    gold = t.bm("GOLD")
    glow = t.bm("GLOW")

    # Low stone cradle grounded at z = 0
    box(stone, (11.2, 10.6, 2.4), M((0, 0, 1.2)))
    # Canted verdigris Tidebell body
    bm = M((0.0, 0.0, 2.2), rot=(0.18, -0.22, 0.1))
    prof = [(4.8, 0.0), (5.0, 0.9), (4.1, 2.8), (3.3, 5.8), (2.6, 8.8), (1.6, 10.4), (0.0, 11.2)]
    lathe(accent, prof, 14, bm)
    ring_mesh(gold, 4.75, 0.38, 14, bm @ M((0, 0, 0.9)), tube_segs=5)
    # Glowing aqua fissure seam along the bell's crack
    box(glow, (0.45, 1.2, 6.2), bm @ M((0.4, -3.7, 4.6), rot=(0.16, 0, 0.12)))
    # Heavy binding iron chains wrapped around the bell
    for cz in (2.8, 6.0):
        ring_mesh(metal, 4.35 - cz * 0.18, 0.42, 12, bm @ M((0, 0, cz)), tube_segs=5)


# =============================================================================
# 12. ReefCoralTable (~18 x 16 x 16) — multi-tiered glowing table-coral cluster
#     (matching the lush glowing lavender/violet/aqua reef tiers in the guide!)
# =============================================================================
def make_reef_coral_table(t: Template):
    stone = t.bm("STONE")
    coral = t.bm("CORAL")
    glow = t.bm("GLOW")
    crystal = t.bm("CRYSTAL")

    # Reef rock anchor base grounded cleanly at z = 0
    rock_clean(stone, (12.0, 10.0, 4.4), M((0, 0, 0.0)), seed=401, roughness=0.25)
    cone(stone, 5.2, 4.6, 1.4, 8, M((0, 0, 0.0)))

    # Three overlapping flat-topped scalloped table-coral shelves (like guide image!)
    tiers = [
        (0.0, 0.0, 9.5, 6.8, 0.10, -0.06),
        (-4.8, -2.6, 6.2, 4.8, -0.14, 0.12),
        (5.0, 2.4, 7.6, 5.2, 0.08, 0.15),
        (-3.2, 4.0, 12.8, 4.2, -0.08, -0.10),
    ]
    for cx, cy, cz, rad, rx, ry in tiers:
        # Curved coral stem from rock base up to shelf
        cone(coral, rad * 0.28, rad * 0.16, cz - 1.5, 8, M((cx * 0.55, cy * 0.55, 1.8)))
        # Wide scalloped table-coral cap
        cap_m = M((cx, cy, cz), rot=(rx, ry, 0))
        cone(coral, rad * 0.42, rad, 1.4, 12, cap_m @ M((0, 0, -1.2)))
        cone(coral, rad, rad * 0.85, 0.9, 12, cap_m @ M((0, 0, 0.2)))
        # Bioluminescent underside & glowing rim edge
        ring_mesh(glow, rad * 0.92, 0.36, 12, cap_m @ M((0, 0, 0.35)), tube_segs=5)

    # Branching staghorn coral fingers sprouting around the shelves
    coral_tuft(coral, M((-5.5, 1.2, 3.0), rot=(0.2, -0.2, 0.4)), scale=1.3)
    coral_tuft(crystal, M((4.6, -3.5, 3.2), rot=(-0.15, 0.25, -0.5)), scale=1.2)


# =============================================================================
# 13. KelpForestTall (~14 x 48 x 14) — towering bioluminescent kelp fronds
# =============================================================================
def make_kelp_forest_tall(t: Template):
    stone = t.bm("STONE")
    foliage = t.bm("FOLIAGE")
    glow = t.bm("GLOW")

    # Rooted reef holdfast rock grounded cleanly at z = 0
    rock_clean(stone, (8.6, 8.2, 3.4), M((0, 0, 0.0)), seed=402, roughness=0.28)
    cone(stone, 4.0, 3.4, 1.2, 8, M((0, 0, 0.0)))

    # 5 sinuous tall kelp stalks sweeping up to 48 studs
    stalks = [
        (0.0, 0.0, 46.0, 0.0),
        (-3.2, -2.0, 38.0, 1.1),
        (3.4, -1.6, 41.0, 2.2),
        (-2.2, 3.2, 33.0, 3.5),
        (2.6, 2.8, 36.0, 4.8),
    ]
    for sx, sy, height, phase in stalks:
        segs = 9
        prev = Vector((sx * 0.6, sy * 0.6, 1.8))
        for k in range(1, segs + 1):
            u = k / segs
            p = Vector((
                sx + math.sin(u * 4.2 + phase) * (1.8 + u * 2.2),
                sy + math.cos(u * 3.8 + phase) * (1.8 + u * 2.0),
                1.8 + u * height,
            ))
            d = p - prev
            q = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
            cone(foliage, 0.52 * (1.0 - u * 0.45), 0.42 * (1.0 - u * 0.45), d.length * 1.06, 5,
                 M((prev.x, prev.y, prev.z)) @ q)
            # Sweeping broad leaf blades & glowing gas bladders along stalk
            if k >= 2:
                ang = phase + k * 1.45
                box(foliage, (4.8 * (1.0 - u * 0.35), 0.25, 1.6),
                    M((p.x + math.cos(ang) * 1.8, p.y + math.sin(ang) * 1.8, p.z), rot=(0.35, -0.45, ang)))
                if k % 2 == 1:
                    uvsphere(glow, 0.58, M((p.x, p.y, p.z)), u=5, v=4)
            prev = p


# =============================================================================
# 14. BubbleVentCluster (~14 x 8 x 14) — abyssal hydrothermal bubble vents
# =============================================================================
def make_bubble_vent_cluster(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    glow = t.bm("GLOW")

    rock_clean(stone, (13.0, 12.2, 3.4), M((0, 0, 0.0)), seed=403, roughness=0.28)
    cone(stone, 5.8, 5.2, 1.2, 8, M((0, 0, 0.0)))
    vents = [
        (0.0, 0.0, 7.6, 2.4, 1.45),
        (-3.6, -2.4, 5.4, 1.8, 1.05),
        (3.8, -1.8, 5.8, 1.9, 1.15),
        (-2.2, 3.4, 4.6, 1.6, 0.95),
        (2.8, 3.0, 4.9, 1.7, 1.0),
    ]
    for vx, vy, vh, r0, r1 in vents:
        cone(stone, r0, r1, vh, 8, M((vx, vy, 0.0)))
        ring_mesh(trim, r1 * 0.92, 0.32, 8, M((vx, vy, vh)), tube_segs=5)
        cone(glow, r1 * 0.72, r1 * 0.45, 0.7, 8, M((vx, vy, vh - 0.5)))


# =============================================================================
# 15. DaisBrazierPedestal (~8 x 14 x 8) — Leviathan Dais rim aqua flame brazier
# =============================================================================
def make_dais_brazier_pedestal(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    metal = t.bm("METAL")
    gold = t.bm("GOLD")
    glow = t.bm("GLOW")

    # Stepped octagonal limestone pedestal grounded at z = 0
    cone(stone, 3.8, 3.3, 2.0, 8, M((0, 0, 0)))
    cone(trim, 2.8, 2.3, 6.2, 8, M((0, 0, 2.0)))
    cone(stone, 3.2, 3.6, 1.6, 8, M((0, 0, 8.2)))
    # Bronze chain-ring collar & trident emblem
    ring_mesh(gold, 2.85, 0.32, 10, M((0, 0, 8.2)), tube_segs=5)
    trident_glyph(gold, M((0, -2.65, 5.0)), scale=0.45)
    # Wide bronze brazier bowl
    cone(metal, 2.2, 3.5, 1.8, 10, M((0, 0, 9.6)))
    ring_mesh(gold, 3.45, 0.28, 10, M((0, 0, 11.4)), tube_segs=5)
    # Bright cyan-aqua flame spire
    cone(glow, 1.85, 0.25, 3.4, 8, M((0, 0, 10.6)))


DEFAULT_BUDGET = 900
F40_TEMPLATES = {
    "GreatTidebellTower": (make_great_tidebell_tower, {"STONE": 1400, "TRIM": 1200, "ACCENT": 1100, "METAL": 800, "GOLD": 700, "SILK": 400, "MOSS": 400, "GLOW": 300}),
    "SeaDomeArchRib": (make_sea_dome_arch_rib, {"METAL": 700, "STONE": 400, "ACCENT": 400, "CRYSTAL": 500}),
    "MaelstromSwirlRing": (make_maelstrom_swirl_ring, {"ALT": 1200, "CRYSTAL": 1000, "SILK": 900, "GLOW": 700}),
    "ChainAnchorBollard": (make_chain_anchor_bollard, {"STONE": 600, "TRIM": 500, "METAL": 900, "GOLD": 600, "GLOW": 300}),
    "ChainTowerRound": (make_chain_tower_round, {"STONE": 800, "TRIM": 700, "METAL": 900, "GOLD": 500, "CORAL": 700, "SILK": 300, "GLOW": 300}),
    "DrownedAltar": (make_drowned_altar, {"STONE": 600, "TRIM": 600, "ACCENT": 500, "GOLD": 500, "GLOW": 400, "CORAL": 600}),
    "CantorPulpit": (make_cantor_pulpit, {"STONE": 600, "TRIM": 700, "CORAL": 800, "GOLD": 400, "GLOW": 300}),
    "AbyssReliquaryShrine": (make_abyss_reliquary_shrine, {"STONE": 700, "TRIM": 700, "ACCENT": 500, "GOLD": 600, "CRYSTAL": 400, "GLOW": 300}),
    "BellBargeWreck": (make_bell_barge_wreck, {"WOOD": 900, "METAL": 700, "ACCENT": 400, "MOSS": 400, "GOLD": 300}),
    "BrokenTideStatue": (make_broken_tide_statue, {"STONE": 900, "TRIM": 600, "ACCENT": 600, "GOLD": 500, "MOSS": 300, "GLOW": 300}),
    "CrackedTidebell": (make_cracked_tidebell, {"STONE": 300, "ACCENT": 800, "METAL": 600, "GOLD": 400, "GLOW": 300}),
    "ReefCoralTable": (make_reef_coral_table, {"STONE": 500, "CORAL": 1100, "GLOW": 600, "CRYSTAL": 600}),
    "KelpForestTall": (make_kelp_forest_tall, {"STONE": 400, "FOLIAGE": 1100, "GLOW": 500}),
    "BubbleVentCluster": (make_bubble_vent_cluster, {"STONE": 700, "TRIM": 500, "GLOW": 400}),
    "DaisBrazierPedestal": (make_dais_brazier_pedestal, {"STONE": 400, "TRIM": 400, "METAL": 500, "GOLD": 400, "GLOW": 300}),
}


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("SunkenF40Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F40_TEMPLATES.items():
        coll = bpy.data.collections.new(name)
        kit.children.link(coll)
        t = Template(name)
        fn(t)
        roles = {}
        lo = Vector((1e9, 1e9, 1e9))
        hi = Vector((-1e9, -1e9, -1e9))
        for role, bm in t.meshes.items():
            if len(bm.verts) == 0:
                bm.free()
                continue
            obj, tris = finalize(name, role, bm, budget.get(role, DEFAULT_BUDGET), coll)
            for v in obj.data.vertices:
                lo = Vector((min(lo.x, v.co.x), min(lo.y, v.co.y), min(lo.z, v.co.z)))
                hi = Vector((max(hi.x, v.co.x), max(hi.y, v.co.y), max(hi.z, v.co.z)))
            roles[role] = tris
        manifest[name] = {
            "Roles": roles,
            "Triangles": sum(roles.values()),
            "Size": [round(hi.x - lo.x, 3), round(hi.z - lo.z, 3), round(hi.y - lo.y, 3)],
            "Min": [round(lo.x, 3), round(lo.z, 3), round(-hi.y, 3)],
        }
    return kit, manifest


def export_kit(kit, manifest):
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    objs = [o for o in kit.all_objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(OUT_DIR, "SunkenF40Kit.fbx"),
        use_selection=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        add_leaf_bones=False,
        bake_anim=False,
        use_mesh_modifiers=True,
        bake_space_transform=True,
        object_types={"MESH"},
    )
    with open(os.path.join(OUT_DIR, "manifest.json"), "w") as f:
        json.dump({"Templates": manifest, "Unit": "studs", "Front": "-Y in Blender, +Z in Roblox"}, f, indent=2, sort_keys=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "SunkenF40Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F40_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
