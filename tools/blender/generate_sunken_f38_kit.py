"""
Sunken Sanctuary Floor 38 (Tidal Channels) sculpted assets, generated in headless Blender.

The Nereth waterworks under a grey-teal storm tide (guide image: reference/Sunken Sanctuary 38.jpg):
the colossal arched Sea-Gate (168 studs tall) with glowing aqua trident keystone and swung-open bronze
relief doors, the slender gothic Tidebell Tower with open belfry bell and storm pennant, the wet stone
Tide Mill with its colossal undershot waterwheel, the arched Sluice House with foaming discharge portals,
coursed Lock Chamber Walls with glowing tide runes, Mitre Gate Pairs with balance beams and overflow sheets,
cantilevered timber Bell Gallows Brackets hanging bronze Tidebells, curved Eel Trap Racks with wicker
baskets and draped nets, battered Moored Barges, Tide Gauge Columns with glowing aqua level marks,
bronze Sluice Gear winches, harbour Bollard & Rope stations with iron storm lanterns, and sculpted
Overflow Waterfall Ribbons.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>"). Roles used here: STONE (wet dark basalt/slate
masonry), TRIM (weathered pale limestone quoins & plaques), METAL (dark iron & weathered bronze),
ACCENT (verdigris bronze roofs, doors & bells), GOLD (worn bell lips & gears), GLOW (aqua-cyan rune light,
the floor's signature saturated hue), CANDLE (small warm amber storm lanterns & mill windows), WOOD
(dark rain-slick timber), SILK (storm banners & fishing nets), MOSS (wet canal moss & weed),
ALT (frothy white foam crests & rope) and CRYSTAL (foaming storm water & overflow cascades).

Run:
    PYTHONHASHSEED=0 /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_sunken_f38_kit.py

Outputs (assets-source/tower/sunken_f38_kit/):
    SunkenF38Kit.blend    the generated scene
    SunkenF38Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             contact-sheet renders
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "sunken_f38_kit")

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
    """A semicircular/segmental stone arch over x in [-half_span, half_span], springing at z = 0."""
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


def pointed_arch(bm, half_span, rise, thick, depth, mat, segs=8):
    for s in (-1, 1):
        pts = []
        for k in range(segs + 1):
            a = k / segs * (math.pi / 3)
            x = s * half_span - s * 2 * half_span * (1 - math.cos(a))
            z = 2 * half_span * math.sin(a) * (rise / (2 * half_span * math.sin(math.pi / 3)))
            pts.append(Vector((x, 0, z)))
        for k in range(segs):
            p0, p1 = pts[k], pts[k + 1]
            mid = (p0 + p1) / 2
            d = p1 - p0
            ang = math.atan2(d.z, d.x)
            box(bm, (d.length + thick * 0.35, depth, thick), mat @ M((mid.x, 0, mid.z), rot=(0, -ang, 0)))


def cast_bell(bm_body, bm_trim, bm_wood, mat, scale=1.0):
    """Heavy cast bronze Tidebell with yoke and clapper, lip at z = 0 of mat."""
    prof = [(2.2 * scale, 0.0), (2.35 * scale, 0.3 * scale), (1.95 * scale, 0.85 * scale),
            (1.5 * scale, 1.8 * scale), (1.32 * scale, 3.0 * scale), (1.0 * scale, 3.8 * scale),
            (0.0, 4.1 * scale)]
    lathe(bm_body, prof, 14, mat)
    ring_mesh(bm_trim, 2.25 * scale, 0.18 * scale, 14, mat @ M((0, 0, 0.22 * scale)), tube_segs=5)
    uvsphere(bm_trim, 0.48 * scale, mat @ M((0, 0, 0.15 * scale)), u=6, v=4)
    box(bm_wood, (4.0 * scale, 0.8 * scale, 0.85 * scale), mat @ M((0, 0, 4.4 * scale)))


def trident_glyph(bm, mat, scale=1.0):
    """Glowing aqua Nereth trident sigil facing -Y in XZ plane, centred at mat origin."""
    box(bm, (0.55 * scale, 0.45 * scale, 6.4 * scale), mat @ M((0, 0, 0)))
    box(bm, (3.4 * scale, 0.45 * scale, 0.55 * scale), mat @ M((0, 0, 1.6 * scale)))
    for sx in (-1, 1):
        box(bm, (0.48 * scale, 0.45 * scale, 2.6 * scale), mat @ M((sx * 1.55 * scale, 0, 2.8 * scale)))
    cone(bm, 0.52 * scale, 0.05 * scale, 1.4 * scale, 4, mat @ M((0, 0, 3.2 * scale)))


def wave_glyph(bm, mat, width=4.6, scale=1.0):
    """Triple glowing aqua wave sigil (from the lock gates in the guide image)."""
    for row in (-1, 0, 1):
        pts = []
        for k in range(9):
            f = k / 8.0
            x = (f - 0.5) * width * scale
            z = row * 0.72 * scale + math.sin(f * math.pi * 3.0) * 0.24 * scale
            pts.append(Vector((x, 0.0, z)))
        tube(bm, pts, [0.16 * scale] * len(pts), 4, mat=mat)


DEFAULT_BUDGET = 3800
F38_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F38_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -------------------------------------------------------------------------------------------------
# 1. SeaGateArch: colossal 168-stud arched Sea-Gate with glowing trident keystone & swung-open doors
# -------------------------------------------------------------------------------------------------
@template("SeaGateArch", STONE=3800, TRIM=1600, ACCENT=2800, METAL=1600, GOLD=800, GLOW=1400, MOSS=600)
def sea_gate_arch(t):
    stone, trim, verd, metal, gold, glow, moss = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("METAL"),
        t.bm("GOLD"), t.bm("GLOW"), t.bm("MOSS"),
    )
    half_span = 34.0
    pier_h = 104.0
    # Two monumental buttressed stone gate piers (wide open 56-stud clear opening!)
    for sx in (-1, 1):
        px = sx * half_span
        box(stone, (18.0, 22.0, 14.0), M((px, 0, 7.0)), bevel=0.35)
        box(stone, (14.8, 18.0, pier_h - 14.0), M((px, 0, 14.0 + (pier_h - 14.0) / 2)), bevel=0.3)
        box(trim, (16.4, 19.6, 3.2), M((px, 0, 44.0)), bevel=0.2)
        box(trim, (16.4, 19.6, 3.2), M((px, 0, 82.0)), bevel=0.2)
        box(trim, (17.2, 20.4, 4.4), M((px, 0, pier_h + 1.5)), bevel=0.25)
        # Outer tiered storm buttress
        box(stone, (7.5, 13.0, 72.0), M((px + sx * 9.5, 1.5, 36.0)), bevel=0.25)
        # Gothic crown pinnacle turret above each pier
        box(stone, (10.5, 10.5, 22.0), M((px, 0, pier_h + 14.5)), bevel=0.2)
        cone(verd, 7.8, 0.5, 22.0, 4, M((px, 0, pier_h + 25.5), rot=(0, 0, math.pi / 4)))
        # Vertical glowing aqua rune column on front (-Y) pier face
        for rz in (26.0, 36.0, 56.0, 68.0, 92.0):
            box(glow, (2.2, 0.8, 5.2), M((px, -9.2, rz)))
        trident_glyph(glow, M((px, -9.3, 114.0)), scale=1.35)
        rock_clean(moss, (18.0, 22.0, 5.0), M((px, 0, 0)), 11 + sx, subdiv=1)

    # Soaring monumental arch spanning x in [-34, +34], rising from z = 104 to z = 148
    round_arch(stone, half_span, 40.0, 10.5, 14.0, M((0, 0, pier_h + 2.0)), segs=16)
    round_arch(trim, half_span + 4.8, 44.5, 3.4, 15.2, M((0, 0, pier_h + 2.0)), segs=16)
    round_arch(verd, half_span - 4.8, 35.4, 2.8, 12.6, M((0, 0, pier_h + 2.0)), segs=16)
    # Glowing aqua rune medallions spaced along the arch face
    for k in range(1, 10):
        a = math.pi * k / 10.0
        rx, rz = math.cos(a) * half_span, pier_h + 2.0 + math.sin(a) * 40.0
        box(glow, (2.4, 1.0, 2.4), M((rx, -7.2, rz), rot=(0, a, 0)))

    # Massive keystone crown + glowing aqua Trident Crest reaching z = 168
    box(stone, (12.0, 16.0, 14.0), M((0, 0, pier_h + 44.0)), bevel=0.25)
    box(trim, (13.4, 17.0, 3.0), M((0, 0, pier_h + 52.0)), bevel=0.2)
    trident_glyph(glow, M((0, -8.4, pier_h + 46.5)), scale=2.2)
    # Towering finial spire above keystone
    box(verd, (2.2, 2.2, 14.0), M((0, 0, pier_h + 57.5)))
    for sx in (-1, 1):
        box(verd, (1.4, 1.4, 8.5), M((sx * 4.4, 0, pier_h + 59.0)))
    box(gold, (10.2, 1.6, 1.6), M((0, 0, pier_h + 55.0)))

    # Two enormous swung-open verdigris-bronze relief doors flanking the inner piers (angled open into the threshold)
    for sx in (-1, 1):
        hinge = M((sx * (half_span - 7.5), -3.5, 2.0), rot=(0, 0, sx * -0.92))
        # Door leaf (width 22, thickness 3.2, height 88)
        box(verd, (21.0, 3.2, 86.0), hinge @ M((-sx * 10.5, 0, 43.0)), bevel=0.2)
        box(metal, (21.6, 3.8, 3.2), hinge @ M((-sx * 10.5, 0, 6.0)))
        box(metal, (21.6, 3.8, 3.2), hinge @ M((-sx * 10.5, 0, 44.0)))
        box(metal, (21.6, 3.8, 3.2), hinge @ M((-sx * 10.5, 0, 82.0)))
        # Embossed sea-god medallion & glowing trident relief on each open gate leaf
        ring_mesh(gold, 6.2, 0.75, 14, hinge @ M((-sx * 10.5, -1.8, 52.0), rot=(math.pi / 2, 0, 0)), tube_segs=5)
        uvsphere(metal, 4.4, hinge @ M((-sx * 10.5, -1.2, 52.0)), u=8, v=6)
        trident_glyph(glow, hinge @ M((-sx * 10.5, -2.0, 28.0)), scale=1.7)


# -------------------------------------------------------------------------------------------------
# 2. TidebellTowerSlim: slender 148-stud gothic watchtower with belfry bell & storm pennant
# -------------------------------------------------------------------------------------------------
@template("TidebellTowerSlim", STONE=3200, TRIM=1200, ACCENT=2200, METAL=1200, GOLD=600, GLOW=1100, SILK=600, WOOD=400)
def tidebell_tower_slim(t):
    stone, trim, verd, metal, gold, glow, silk, wood = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("METAL"),
        t.bm("GOLD"), t.bm("GLOW"), t.bm("SILK"), t.bm("WOOD"),
    )
    # Heavy battered storm-plinth (z = 0..20)
    box(stone, (24.0, 24.0, 8.0), M((0, 0, 4.0)), bevel=0.3)
    box(trim, (21.6, 21.6, 2.4), M((0, 0, 9.0)), bevel=0.2)
    box(stone, (19.0, 19.0, 11.0), M((0, 0, 15.5)), bevel=0.25)

    # Slender buttressed gothic shaft (z = 20..88)
    box(stone, (15.4, 15.4, 68.0), M((0, 0, 54.0)), bevel=0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(trim, (3.2, 3.2, 74.0), M((sx * 7.8, sy * 7.8, 52.0)), bevel=0.16)
    for zb in (36.0, 62.0, 86.0):
        box(trim, (18.4, 18.4, 2.0), M((0, 0, zb)), bevel=0.15)
    # Glowing aqua trident & narrow rune lancets on all four faces
    for rot_z in (0, math.pi / 2, math.pi, -math.pi / 2):
        rm = M((0, 0, 0), rot=(0, 0, rot_z))
        trident_glyph(glow, rm @ M((0, -8.0, 48.0)), scale=1.45)
        box(glow, (1.6, 0.7, 13.0), rm @ M((0, -8.0, 74.0)))

    # Open gothic belfry lantern (z = 88..114) housing one great bronze Tidebell
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(stone, (3.4, 3.4, 26.0), M((sx * 6.2, sy * 6.2, 101.0)), bevel=0.14)
    for rot_z in (0, math.pi / 2, math.pi, -math.pi / 2):
        rm = M((0, 0, 0), rot=(0, 0, rot_z))
        pointed_arch(stone, 5.2, 7.6, 1.5, 2.4, rm @ M((0, -6.4, 106.0)), segs=6)
    box(trim, (19.0, 19.0, 2.6), M((0, 0, 115.0)), bevel=0.2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cone(verd, 1.8, 0.25, 8.2, 4, M((sx * 8.0, sy * 8.0, 116.2), rot=(0, 0, math.pi / 4)))
    cast_bell(metal, gold, wood, M((0, 0, 94.0)), scale=2.45)
    ring_mesh(glow, 5.2, 0.25, 16, M((0, 0, 95.0)), tube_segs=4)

    # Steep octagonal verdigris spire (z = 116..148)
    cone(verd, 8.8, 0.35, 30.0, 8, M((0, 0, 116.2)))
    cone(gold, 0.55, 0.1, 4.2, 6, M((0, 0, 145.0)))

    # Cantilevered storm pennant arm (like the guide image's Tidebell Tower flag!)
    box(metal, (14.0, 0.65, 0.65), M((12.5, 0, 84.0)))
    box(silk, (10.5, 0.4, 7.8), M((14.2, 0, 79.8)))
    wave_glyph(glow, M((14.2, -0.35, 79.8)), width=6.2, scale=0.9)


# -------------------------------------------------------------------------------------------------
# 3. TideMillHouse: wet gable-roofed millhouse with colossal spoked undershot waterwheel
# -------------------------------------------------------------------------------------------------
@template("TideMillHouse", STONE=2400, TRIM=900, WOOD=2600, ACCENT=1200, METAL=900, CANDLE=500, GLOW=400, CRYSTAL=1200, ALT=800)
def tide_mill_house(t):
    stone, trim, wood, verd, metal, candle, glow, water, foam = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("WOOD"), t.bm("ACCENT"),
        t.bm("METAL"), t.bm("CANDLE"), t.bm("GLOW"), t.bm("CRYSTAL"), t.bm("ALT"),
    )
    # Arched stone race undercroft (z = 0..10) + upper millhouse (z = 10..24)
    box(stone, (22.0, 28.0, 10.0), M((-4.5, 0, 5.0)), bevel=0.2)
    box(stone, (21.0, 26.0, 13.5), M((-4.5, 0, 16.8)), bevel=0.18)
    # Steep dark slate/verdigris gable roof (z = 23.5..33.5)
    for sx in (-1, 1):
        box(verd, (14.2, 28.4, 1.3), M((-4.5 + sx * 5.6, 0, 28.2), rot=(0, sx * 0.68, 0)), bevel=0.08)
    box(trim, (2.0, 28.8, 1.6), M((-4.5, 0, 33.0)), bevel=0.1)
    # Stone chimney stack
    box(stone, (3.8, 3.8, 9.5), M((-11.0, 8.5, 31.0)), bevel=0.12)
    # Warm glowing mullioned mill windows & aqua tide-rune lintel
    for wy in (-7.0, 3.0):
        box(candle, (0.8, 3.8, 4.8), M((6.1, wy, 17.5)))
        box(trim, (1.2, 4.4, 0.8), M((6.1, wy, 20.2)))
    box(candle, (4.8, 0.8, 4.8), M((-4.5, -13.1, 17.5)))
    trident_glyph(glow, M((-14.0, -13.2, 13.0)), scale=0.85)

    # Colossal spoked drowned-timber undershot waterwheel on +X face (R = 12.2, centre z = 12.5)
    wx, wz = 9.8, 12.5
    wheel_r = 12.0
    # Axle + timber support pier
    tube(metal, [(5.0, 0, wz), (wx + 3.2, 0, wz)], [1.1, 1.0], 10)
    box(stone, (3.2, 4.2, 13.5), M((wx + 3.4, 0, 6.75)), bevel=0.12)
    # Twin heavy wooden rims + 12 spokes + 16 paddles
    for dx in (-1.6, 1.6):
        ring_mesh(wood, wheel_r, 0.72, 20, M((wx + dx, 0, wz), rot=(0, math.pi / 2, 0)), tube_segs=5)
        ring_mesh(metal, wheel_r - 2.6, 0.35, 16, M((wx + dx, 0, wz), rot=(0, math.pi / 2, 0)), tube_segs=4)
    for k in range(12):
        a = k * math.pi / 6
        tube(wood, [(wx, 0, wz), (wx, math.cos(a) * wheel_r, wz + math.sin(a) * wheel_r)], [0.48, 0.36], 5)
    for k in range(16):
        a = k * math.pi / 8
        box(wood, (4.2, 0.45, 2.2), M((wx, math.cos(a) * wheel_r, wz + math.sin(a) * wheel_r), rot=(-a, 0, 0)))
    # Foaming race cascade splashing off the wheel's bottom paddles
    for k in range(-2, 3):
        tube(water, [(wx, k * 2.4 - 4.0, 3.2), (wx + 2.0, k * 2.4 - 8.5, 1.4), (wx + 3.2, k * 2.4 - 12.0, 0.2)], [0.85, 0.65, 0.95], 6)
    rock_clean(foam, (9.0, 14.0, 3.6), M((wx, -5.0, 0.0)), 31, subdiv=2)


# -------------------------------------------------------------------------------------------------
# 4. SluiceHouseKeep: arched stone waterworks house with triple foaming discharge races & wall runes
# -------------------------------------------------------------------------------------------------
@template("SluiceHouseKeep", STONE=2600, TRIM=1000, ACCENT=1200, WOOD=900, CANDLE=500, GLOW=800, CRYSTAL=1400, ALT=900, SILK=500)
def sluice_house_keep(t):
    stone, trim, verd, wood, candle, glow, water, foam, silk = (
        t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("WOOD"),
        t.bm("CANDLE"), t.bm("GLOW"), t.bm("CRYSTAL"), t.bm("ALT"), t.bm("SILK"),
    )
    # Lower arched sluice foundation (z = 0..10.5) with 3 foaming water discharge arches facing -Y
    for sx in (-12.5, -4.2, 4.2, 12.5):
        box(stone, (3.4, 18.0, 11.0), M((sx, 0, 5.5)), bevel=0.18)
    box(stone, (29.0, 10.0, 11.0), M((0, 4.0, 5.5)), bevel=0.2)
    for ax in (-8.35, 0.0, 8.35):
        round_arch(trim, 3.2, 2.8, 1.1, 3.2, M((ax, -8.2, 7.2)), segs=8)
        # Sculpted foaming water pouring out of each sluice arch!
        tube(water, [(ax, -4.0, 5.5), (ax, -9.2, 4.0), (ax, -13.0, 0.8)], [2.1, 1.9, 2.4], 8)
        rock_clean(foam, (5.2, 5.2, 2.4), M((ax, -11.8, 0.0)), 40 + int(ax), subdiv=1)

    # Upper sluice-keeper's gable hall (z = 11..23) + steep pitched verdigris-slate roof (to z = 30.5)
    box(stone, (28.0, 17.5, 11.5), M((0, 0.5, 16.75)), bevel=0.18)
    box(trim, (29.6, 19.0, 1.4), M((0, 0.5, 11.2)), bevel=0.12)
    for sy in (-1, 1):
        box(verd, (30.4, 12.4, 1.2), M((0, 0.5 + sy * 4.8, 26.2), rot=(sy * -0.62, 0, 0)), bevel=0.08)
    box(trim, (30.8, 1.8, 1.5), M((0, 0.5, 30.0)), bevel=0.1)
    # Warm glowing windows + aqua wall runes + fluttering storm banner
    for wx in (-8.0, 0.0, 8.0):
        box(candle, (3.2, 0.7, 4.0), M((wx, -8.35, 16.5)))
    for rx in (-12.5, 12.5):
        trident_glyph(glow, M((rx, -8.5, 16.5)), scale=0.8)
    box(wood, (1.0, 1.0, 10.0), M((11.0, -7.5, 30.5)))
    box(silk, (7.5, 0.35, 3.8), M((15.0, -7.5, 33.2)))


# -------------------------------------------------------------------------------------------------
# 5. LockChamberWall: heavy coursed dark stone lock-pier bastion with glowing tide runes
# -------------------------------------------------------------------------------------------------
@template("LockChamberWall", STONE=1800, TRIM=800, METAL=600, GLOW=700, MOSS=600)
def lock_chamber_wall(t):
    stone, trim, metal, glow, moss = t.bm("STONE"), t.bm("TRIM"), t.bm("METAL"), t.bm("GLOW"), t.bm("MOSS")
    box(stone, (24.0, 10.0, 18.0), M((0, 0, 9.0)), bevel=0.25)
    box(trim, (25.2, 11.0, 1.6), M((0, 0, 18.6)), bevel=0.14)
    # Buttress pilaster & mooring rings
    for sx in (-8.5, 8.5):
        box(stone, (3.6, 11.4, 18.8), M((sx, 0, 9.4)), bevel=0.16)
        ring_mesh(metal, 1.0, 0.22, 10, M((sx, -5.8, 13.5), rot=(math.pi / 2, 0, 0)), tube_segs=4)
    # Carved limestone plaque & glowing aqua trident + wave sigil
    box(trim, (5.6, 1.0, 6.2), M((0, -5.1, 13.0)), bevel=0.1)
    wave_glyph(glow, M((0, -5.7, 13.2)), width=4.0, scale=0.95)
    trident_glyph(glow, M((-8.5, -5.8, 8.0)), scale=0.75)
    rock_clean(moss, (24.6, 10.8, 3.2), M((0, 0, 0)), 52, subdiv=1)


# -------------------------------------------------------------------------------------------------
# 6. MitreGatePair: heavy V-angled timber-and-bronze lock gates with balance beams & overflow sheet
# -------------------------------------------------------------------------------------------------
@template("MitreGatePair", WOOD=1800, METAL=1000, ACCENT=600, GLOW=700, CRYSTAL=1200, ALT=700)
def mitre_gate_pair(t):
    wood, metal, verd, glow, water, foam = (
        t.bm("WOOD"), t.bm("METAL"), t.bm("ACCENT"), t.bm("GLOW"), t.bm("CRYSTAL"), t.bm("ALT"),
    )
    # Two angled timber gate leaves meeting at x = 0 in a gentle mitre V
    for sx in (-1, 1):
        gm = M((sx * 7.6, 0.8, 0.0), rot=(0, 0, sx * -0.18))
        box(wood, (15.6, 2.2, 14.5), gm @ M((0, 0, 7.25)), bevel=0.12)
        for zb in (2.4, 7.2, 12.2):
            box(metal, (15.8, 2.6, 0.9), gm @ M((0, 0, zb)))
        box(metal, (1.2, 2.8, 15.0), gm @ M((sx * 7.2, 0, 7.5)))
        # Long cantilevered timber balance beam extending outward over the bank
        box(wood, (14.5, 1.4, 1.5), gm @ M((sx * 6.5, 0, 16.0)), bevel=0.08)
        box(verd, (2.8, 1.8, 2.0), gm @ M((sx * 13.2, 0, 16.2)), bevel=0.1)
    # Glowing aqua triple-wave glyph across the center seam + foaming overflow cascade
    wave_glyph(glow, M((0, -0.6, 10.5)), width=6.4, scale=1.15)
    for dx in (-2.4, 0.0, 2.4):
        tube(water, [(dx, 0.8, 14.2), (dx, -1.6, 12.0), (dx, -3.4, 6.0), (dx, -4.4, 0.4)], [1.1, 0.95, 1.15, 1.4], 6)
    rock_clean(foam, (9.5, 5.2, 2.8), M((0, -4.0, 0.0)), 63, subdiv=2)


# -------------------------------------------------------------------------------------------------
# 7. BellGallowsBracket: timber & iron cantilevered lock-bell gallows hanging a bronze Tidebell
# -------------------------------------------------------------------------------------------------
@template("BellGallowsBracket", WOOD=1200, METAL=1000, ACCENT=1200, GOLD=600, GLOW=400, STONE=600)
def bell_gallows_bracket(t):
    wood, metal, verd, gold, glow, stone = (
        t.bm("WOOD"), t.bm("METAL"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("GLOW"), t.bm("STONE"),
    )
    # Heavy masonry socket + upright timber mast + diagonal strut + cantilevered bell arm
    box(stone, (4.8, 4.8, 3.2), M((-4.2, 0, 1.6)), bevel=0.14)
    box(wood, (2.2, 2.2, 20.5), M((-4.2, 0, 11.8)), bevel=0.08)
    box(metal, (2.6, 2.6, 1.2), M((-4.2, 0, 21.4)))
    box(wood, (14.2, 1.6, 1.8), M((1.6, 0, 20.6)), bevel=0.08)
    tube(wood, [(-4.0, 0, 13.5), (3.8, 0, 20.2)], [0.65, 0.6], 6)
    box(metal, (1.4, 2.0, 2.4), M((6.2, 0, 20.6)))
    # Large cast-bronze Tidebell hanging clear at x = +4.8, z = 11.2..19.6
    cast_bell(verd, gold, wood, M((4.8, 0, 12.2)), scale=1.75)
    ring_mesh(glow, 3.8, 0.18, 14, M((4.8, 0, 12.8)), tube_segs=4)


# -------------------------------------------------------------------------------------------------
# 8. EelTrapRack: curved wet piling weir with woven wicker traps, draped nets & storm lantern
# -------------------------------------------------------------------------------------------------
@template("EelTrapRack", WOOD=1600, ALT=1200, SILK=900, METAL=500, CANDLE=300, MOSS=500)
def eel_trap_rack(t):
    wood, wicker, net, metal, candle, moss = (
        t.bm("WOOD"), t.bm("ALT"), t.bm("SILK"), t.bm("METAL"), t.bm("CANDLE"), t.bm("MOSS"),
    )
    # Curved row of 11 dark timber pilings + crossrails
    pts = []
    for k in range(11):
        u = (k / 10.0) * 2 - 1
        x = u * 9.5
        y = (1 - u * u) * 3.8 - 1.5
        h = 6.8 + (k % 3) * 0.8
        cone(wood, 0.52, 0.42, h, 8, M((x, y, 0.0)))
        pts.append(Vector((x, y, 5.2)))
    tube(wood, pts, [0.35] * len(pts), 6)
    tube(wood, [p - Vector((0, 0, 2.4)) for p in pts], [0.32] * len(pts), 6)
    # 4 conical wicker eel-trap baskets lashed into the weir
    for k in (2, 4, 6, 8):
        p = pts[k]
        cone(wicker, 1.35, 0.42, 4.2, 10, M((p.x, p.y - 1.4, 2.4), rot=(math.pi / 2 + 0.15, 0, 0)))
    # Draped damp fishing nets & warm post storm lantern
    for k in (1, 5, 9):
        p = pts[k]
        box(net, (3.4, 0.35, 3.6), M((p.x, p.y - 0.5, 4.2), rot=(0.15, 0, 0)))
    cone(wood, 0.45, 0.38, 9.6, 8, M((8.5, -0.8, 0.0)))
    box(metal, (1.2, 1.2, 1.8), M((8.5, -1.8, 8.2)))
    uvsphere(candle, 0.5, M((8.5, -1.8, 8.2)), u=6, v=4)
    rock_clean(moss, (18.0, 5.0, 1.6), M((0, 1.2, 0.0)), 77, subdiv=1)


# -------------------------------------------------------------------------------------------------
# 9. MooredBarge: battered drowned timber cargo barge with crates, barrels & mossy waterline
# -------------------------------------------------------------------------------------------------
@template("MooredBarge", WOOD=2200, METAL=800, MOSS=700, ALT=600)
def moored_barge(t):
    wood, metal, moss, rope = t.bm("WOOD"), t.bm("METAL"), t.bm("MOSS"), t.bm("ALT")
    # Flat-bottomed canal barge hull (26 long along X, 10.5 wide along Y, 5.2 tall)
    box(wood, (22.0, 9.6, 1.2), M((0, 0, 0.6)), bevel=0.1)
    for sy in (-1, 1):
        box(wood, (23.0, 1.0, 4.8), M((0, sy * 4.8, 2.8), rot=(sy * -0.14, 0, 0)), bevel=0.08)
        for rx in (-9.0, -4.5, 0.0, 4.5, 9.0):
            box(wood, (0.7, 1.3, 4.4), M((rx, sy * 4.4, 2.7)))
    # Tapered bow & stern transoms
    for sx in (-1, 1):
        box(wood, (3.2, 7.6, 4.8), M((sx * 12.2, 0, 3.0), rot=(0, sx * 0.25, 0)), bevel=0.12)
        box(metal, (1.2, 8.2, 0.8), M((sx * 13.0, 0, 5.2)))
    # Deck planks, wooden cargo crates, barrels & coiled hawser rope
    box(wood, (7.0, 8.2, 0.6), M((-8.0, 0, 4.8)))
    box(wood, (3.2, 3.2, 2.8), M((-6.5, -1.4, 6.4)), bevel=0.08)
    cone(wood, 1.15, 1.15, 2.6, 10, M((-1.5, 1.6, 1.2)))
    cone(wood, 1.15, 1.15, 2.6, 10, M((1.6, 1.2, 1.2)))
    ring_mesh(rope, 1.3, 0.35, 12, M((8.5, -1.2, 1.6)), tube_segs=5)
    # Broken stub mast
    cone(wood, 0.65, 0.45, 9.5, 8, M((3.5, 0, 1.0), rot=(0.08, 0.12, 0)))
    rock_clean(moss, (24.0, 10.6, 1.8), M((0, 0, 0.0)), 88, subdiv=1)


# -------------------------------------------------------------------------------------------------
# 10. TideGaugeColumn: carved stone water-level obelisk with glowing aqua depth graduations
# -------------------------------------------------------------------------------------------------
@template("TideGaugeColumn", STONE=1100, TRIM=600, ACCENT=600, GLOW=700, MOSS=400)
def tide_gauge_column(t):
    stone, trim, verd, glow, moss = t.bm("STONE"), t.bm("TRIM"), t.bm("ACCENT"), t.bm("GLOW"), t.bm("MOSS")
    box(stone, (4.8, 4.8, 2.4), M((0, 0, 1.2)), bevel=0.14)
    cone(stone, 1.85, 1.25, 13.8, 4, M((0, 0, 2.4), rot=(0, 0, math.pi / 4)))
    box(trim, (3.2, 3.2, 1.1), M((0, 0, 16.0)), bevel=0.1)
    # Glowing aqua graduation bars up the front face
    for k in range(6):
        z = 4.0 + k * 1.85
        w_bar = 2.0 if k % 2 == 0 else 1.2
        box(glow, (w_bar, 0.35, 0.32), M((0, -1.55 + k * 0.08, z)))
    # Verdigris trident finial on top (to z = 19.2)
    trident_glyph(verd, M((0, 0, 18.0)), scale=0.65)
    rock_clean(moss, (5.2, 5.2, 1.4), M((0, 0, 0.0)), 91, subdiv=1)


# -------------------------------------------------------------------------------------------------
# 11. SluiceGear: bronze & iron lock-keeper's winding wheel and rack-and-pinion sluice winch
# -------------------------------------------------------------------------------------------------
@template("SluiceGear", STONE=900, METAL=1200, ACCENT=800, GOLD=600, WOOD=500)
def sluice_gear(t):
    stone, metal, verd, gold, wood = t.bm("STONE"), t.bm("METAL"), t.bm("ACCENT"), t.bm("GOLD"), t.bm("WOOD")
    box(stone, (7.6, 5.4, 2.2), M((0, 0, 1.1)), bevel=0.12)
    for sx in (-2.4, 2.4):
        box(stone, (1.4, 3.8, 5.6), M((sx, 0, 4.6)), bevel=0.1)
    # Horizontal iron winding drum + rack screw rod
    tube(metal, [(-3.4, 0, 6.2), (3.4, 0, 6.2)], [0.85, 0.85], 10)
    box(metal, (0.9, 0.9, 9.6), M((0, 0, 5.4)))
    # Large spoked bronze handwheel on +X end
    ring_mesh(verd, 2.8, 0.32, 16, M((3.8, 0, 6.2), rot=(0, math.pi / 2, 0)), tube_segs=5)
    for k in range(6):
        a = k * math.pi / 3
        tube(gold, [(3.8, 0, 6.2), (3.8, math.cos(a) * 2.8, 6.2 + math.sin(a) * 2.8)], [0.2, 0.16], 5)
    box(wood, (1.4, 0.45, 0.45), M((4.6, 2.5, 6.2)))


# -------------------------------------------------------------------------------------------------
# 12. BollardRope: harbour mooring bollard, wet rope coils, cask & warm iron storm lantern
# -------------------------------------------------------------------------------------------------
@template("BollardRope", STONE=700, METAL=800, WOOD=700, ALT=600, CANDLE=300)
def bollard_rope(t):
    stone, metal, wood, rope, candle = t.bm("STONE"), t.bm("METAL"), t.bm("WOOD"), t.bm("ALT"), t.bm("CANDLE")
    # Heavy stone/iron bollard wrapped in hemp hawser
    cone(stone, 1.35, 1.1, 2.8, 10, M((-0.6, 0, 0.0)))
    uvsphere(metal, 1.25, M((-0.6, 0, 2.9)), u=10, v=6)
    for k in range(3):
        ring_mesh(rope, 1.45, 0.24, 12, M((-0.6, 0, 0.65 + k * 0.48)), tube_segs=5)
    # Wooden harbour barrel beside bollard
    cone(wood, 0.95, 0.95, 2.4, 10, M((1.6, 0.8, 0.0)))
    ring_mesh(metal, 0.98, 0.08, 10, M((1.6, 0.8, 0.6)), tube_segs=4)
    ring_mesh(metal, 0.98, 0.08, 10, M((1.6, 0.8, 1.8)), tube_segs=4)
    # Iron stanchion carrying a warm amber storm lantern (z = 0..5.8)
    tube(metal, [(-1.8, -1.2, 0.0), (-1.8, -1.2, 5.6), (-0.8, -1.2, 5.6)], [0.16, 0.14, 0.12], 6)
    box(metal, (1.1, 1.1, 0.3), M((-0.8, -1.2, 5.1)))
    box(metal, (1.1, 1.1, 0.3), M((-0.8, -1.2, 3.8)))
    uvsphere(candle, 0.48, M((-0.8, -1.2, 4.45)), u=7, v=5)


# -------------------------------------------------------------------------------------------------
# 13. OverflowRibbon: sculpted multi-strand arching waterfall ribbon with frothy mist splash
# -------------------------------------------------------------------------------------------------
@template("OverflowRibbon", CRYSTAL=1800, ALT=1200)
def overflow_ribbon(t):
    water, foam = t.bm("CRYSTAL"), t.bm("ALT")
    # 5 arched crystal water strands cascading smoothly from z = 15 down to z = 0
    for k in range(-2, 3):
        x = k * 3.2
        r0 = 1.35 if k % 2 == 0 else 1.05
        pts = [
            Vector((x, 2.4, 15.2)),
            Vector((x, 0.2, 13.8)),
            Vector((x, -1.8, 9.6)),
            Vector((x, -2.8, 4.2)),
            Vector((x, -3.4, 0.4)),
        ]
        tube(water, pts, [r0, r0 * 0.9, r0 * 1.05, r0 * 1.2, r0 * 1.35], 7)
    rock_clean(foam, (17.0, 4.8, 2.8), M((0, 1.8, 14.2)), 101, subdiv=2)
    rock_clean(foam, (18.5, 6.2, 3.4), M((0, -3.4, 0.0)), 102, subdiv=2)


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("SunkenF38Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F38_TEMPLATES.items():
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
        filepath=os.path.join(OUT_DIR, "SunkenF38Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "SunkenF38Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F38_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
