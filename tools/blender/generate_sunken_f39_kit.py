"""
Sunken Sanctuary Floor 39 (Pearlguard Vault) sculpted assets, generated in headless Blender.

The Pearlguard's fortified harbour keep (guide image: reference/Sunken Sanctuary 39.jpg):
the monumental verdigris-ribbed Pearl Vault conservatory dome (206 studs tall) with glowing pearl-gold
arched glazing and twin carved seahorse buttresses, the Colossal Open Clam glowing pearl-white inside the
Vault apse, the fortified moss-draped SeaWallSegment curtains, the sealed DrownedGateWall with carved
trident & flanking sea-serpents, the coral-draped CoralGateTower with domed lantern crown, the eastern
TideArmillaryTower crowned by a giant interlocking bronze armillary tide-sphere, the outer Sea Gate
PortcullisGatehouse with scallop-shell pediment & raised bronze portcullis, MuffledBellStack barricades
wrapped in sailcloth, OysterRack cultivation frames, Divers' Wharf DivingBell & davit rig, moored
PearlguardGalley with scallop-emblem sail, armored CoralWardenStatue with hook-glaive & nautilus shield,
Pearl Market ShellAwningStall, HarbourCrane jib winch, and CoralCageReliquary echoing the Coral Abyss Core.

Reuses the mesh helpers and role conventions of `tools/blender/generate_tower_biome_kit.py`
(1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox,
one mesh object per colour role named "<Template>__<ROLE>").

Run:
    PYTHONHASHSEED=0 /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/blender/generate_sunken_f39_kit.py

Outputs (assets-source/tower/sunken_f39_kit/):
    SunkenF39Kit.blend    the generated scene
    SunkenF39Kit.fbx      FBX for File > Import 3D in Studio
    manifest.json         per template: roles, reference size, triangle counts
    previews/             contact-sheet renders
"""
import bpy, bmesh, math, os, json, runpy
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "sunken_f39_kit")

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


def trident_glyph(bm, mat, scale=1.0):
    box(bm, (0.55 * scale, 0.48 * scale, 6.4 * scale), mat @ M((0, 0, 0)))
    box(bm, (3.4 * scale, 0.48 * scale, 0.55 * scale), mat @ M((0, 0, 1.6 * scale)))
    for sx in (-1, 1):
        box(bm, (0.48 * scale, 0.48 * scale, 2.6 * scale), mat @ M((sx * 1.55 * scale, 0, 2.8 * scale)))


def scallop_fan(bm, radius, thick, mat, ribs=9, spread=math.pi * 0.82):
    """Fluted scallop shell fan standing upright in XZ plane, hinge at mat origin."""
    for i in range(ribs):
        t = (i / (ribs - 1)) - 0.5
        ang = t * spread
        r = radius * (1.0 - 0.14 * abs(t * 2.0))
        cx = math.sin(ang) * r * 0.52
        cz = math.cos(ang) * r * 0.52
        w = radius * (0.24 - 0.04 * abs(t * 2.0))
        box(bm, (w, thick, r), mat @ M((cx, 0, cz), rot=(0, ang, 0)))


def seahorse_relief(bm_stone, bm_accent, mat, side=1, scale=1.0):
    """Stylized carved sea-serpent / seahorse buttress relief curving gracefully up along Z."""
    pts = [
        Vector((0.0, 0.0, 0.0)),
        Vector((side * 1.6, -0.4, 4.0)),
        Vector((side * 0.6, -0.7, 9.0)),
        Vector((-side * 1.0, -0.9, 15.0)),
        Vector((-side * 0.2, -1.1, 21.0)),
        Vector((side * 1.4, -1.3, 25.0)),
        Vector((side * 2.2, -1.5, 23.8)),
    ]
    scaled = [p * scale for p in pts]
    rads = [1.5 * scale, 2.0 * scale, 2.3 * scale, 2.1 * scale, 1.7 * scale, 1.4 * scale, 0.7 * scale]
    for i in range(len(scaled) - 1):
        p0, p1 = scaled[i], scaled[i + 1]
        mid = (p0 + p1) / 2
        d = p1 - p0
        cone(bm_stone, rads[i], rads[i + 1], d.length * 1.15, 7,
             mat @ M((mid.x, mid.y, mid.z)) @ Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4())
    # Dorsal fin ridge along back
    for i in range(1, 5):
        p = scaled[i]
        box(bm_accent, (1.6 * scale, 0.6 * scale, 2.2 * scale),
            mat @ M((p.x - side * 1.5 * scale, p.y, p.z), rot=(0, side * 0.35, 0)))
    # Curled tail spiral at base
    ring_mesh(bm_stone, 1.6 * scale, 0.55 * scale, 10,
              mat @ M((-side * 1.2 * scale, -0.3 * scale, 1.6 * scale), rot=(math.pi / 2, 0, 0)), tube_segs=5)


def coral_branch(bm, mat, seed=1, scale=1.0):
    """Compact sculptural branching coral tuft (never red/orange — tinted pink-violet/cream/aqua in Luau)."""
    arms = [
        ((0, 0, 0), (0.0, 0.0, 3.2), 0.75, 0.35),
        ((0, 0, 1.0), (1.8, 0.5, 3.6), 0.55, 0.25),
        ((0, 0, 1.1), (-1.7, -0.4, 3.4), 0.55, 0.25),
        ((0, 0, 1.3), (0.4, -1.6, 3.2), 0.48, 0.22),
        ((0, 0, 1.4), (-0.5, 1.5, 3.0), 0.48, 0.22),
    ]
    for idx, (a, b, r0, r1) in enumerate(arms):
        pa = Vector(a) * scale
        pb = Vector(b) * scale
        d = pb - pa
        mid = (pa + pb) / 2
        q = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        cone(bm, r0 * scale, r1 * scale, d.length, 6, mat @ M((mid.x, mid.y, mid.z)) @ q)
        uvsphere(bm, r1 * 1.35 * scale, mat @ M((pb.x, pb.y, pb.z)), u=5, v=4)


def cast_bell_muffled(bm_accent, bm_silk, bm_wood, mat, scale=1.0):
    """Verdigris Tidebell wrapped in sailcloth and rope bindings (muffled so Leviathan cannot hear)."""
    prof = [(2.2 * scale, 0.0), (2.35 * scale, 0.35 * scale), (1.9 * scale, 1.1 * scale),
            (1.45 * scale, 2.3 * scale), (1.15 * scale, 3.4 * scale), (0.0, 3.8 * scale)]
    lathe(bm_accent, prof, 12, mat)
    # Sailcloth muffler wrap bands around waist & lip
    lathe(bm_silk, [(2.48 * scale, 0.1 * scale), (2.55 * scale, 0.9 * scale), (2.15 * scale, 1.8 * scale), (1.65 * scale, 2.6 * scale)], 12, mat)
    for zf in (0.45, 1.3, 2.2):
        ring_mesh(bm_wood, (2.4 - zf * 0.28) * scale, 0.18 * scale, 12, mat @ M((0, 0, zf * scale)), tube_segs=5)


# =============================================================================
# 1. PearlVaultDome (~136 x 206 x 40) — monumental verdigris-ribbed apse dome
# =============================================================================
def make_pearl_vault_dome(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    crystal = t.bm("CRYSTAL")
    candle = t.bm("CANDLE")
    coral = t.bm("CORAL")

    # Curved apse plinth & stepped masonry drum (open front so Apex & portals sit clear in front!)
    half_w = 64.0
    drum_h = 88.0
    # 7 monumental drum piers arranged in a shallow crescent/apse (z=0..88, y in [-16, +18])
    pier_angles = [-0.46 * math.pi, -0.32 * math.pi, -0.17 * math.pi, 0.0, 0.17 * math.pi, 0.32 * math.pi, 0.46 * math.pi]
    pier_pts = []
    for ang in pier_angles:
        px = math.sin(ang) * half_w
        py = math.cos(ang) * 18.0  # curves backward into +Y (north = -Z in Roblox)
        pier_pts.append((px, py, ang))
        # Stepped limestone pier + plinth
        box(stone, (10.5, 12.0, drum_h), M((px, py, drum_h * 0.5), rot=(0, 0, -ang * 0.5)))
        box(trim, (12.4, 13.6, 8.0), M((px, py, 4.0), rot=(0, 0, -ang * 0.5)))
        box(trim, (12.2, 13.4, 5.0), M((px, py, drum_h - 2.5), rot=(0, 0, -ang * 0.5)))
        # Verdigris vertical rib column on front face
        cone(accent, 2.2, 1.9, drum_h - 8.0, 8, M((px, py - 5.8, drum_h * 0.5)))
        # Gold capital ring
        box(gold, (5.4, 5.4, 2.4), M((px, py - 5.8, drum_h - 5.0)))

    # Glowing arched pearl-gold conservatory windows between adjacent drum piers
    for i in range(len(pier_pts) - 1):
        x0, y0, _ = pier_pts[i]
        x1, y1, _ = pier_pts[i + 1]
        mx, my = (x0 + x1) * 0.5, (y0 + y1) * 0.5
        span = math.hypot(x1 - x0, y1 - y0)
        yaw = math.atan2(y1 - y0, x1 - x0)
        # Lower stone dado + upper cornice arch
        box(stone, (span, 7.5, 18.0), M((mx, my + 1.5, 9.0), rot=(0, 0, yaw)))
        box(trim, (span + 2.0, 9.2, 6.0), M((mx, my + 1.0, drum_h - 3.0), rot=(0, 0, yaw)))
        # Tall illuminated glass glazing bay
        box(crystal, (span - 6.0, 2.0, drum_h - 24.0), M((mx, my + 2.0, 18.0 + (drum_h - 24.0) * 0.5), rot=(0, 0, yaw)))
        # Warm golden pearl window light strips (interior mullions)
        for m in (-0.25, 0.0, 0.25):
            box(candle, (1.4, 1.8, drum_h - 28.0), M((mx + math.cos(yaw) * span * m, my + 1.4 + math.sin(yaw) * span * m, 52.0), rot=(0, 0, yaw)))
        round_arch(accent, span * 0.44, 14.0, 3.2, 5.0, M((mx, my - 2.0, drum_h - 22.0), rot=(0, 0, yaw)), segs=8)

    # Grand central triumphal arch framing the Pearl Vault opening (spanning between inner-front piers)
    round_arch(trim, 44.0, 38.0, 6.5, 10.0, M((0, -8.0, drum_h - 22.0)), segs=14)
    round_arch(accent, 42.0, 36.0, 3.4, 11.5, M((0, -8.8, drum_h - 22.0)), segs=14)
    # Twin sculpted stone seahorse buttresses flanking the central arch (iconic guide-image motif!)
    seahorse_relief(trim, accent, M((-44.0, -9.5, 22.0)), side=-1, scale=2.1)
    seahorse_relief(trim, accent, M((44.0, -9.5, 22.0)), side=1, scale=2.1)

    # Sweeping verdigris-ribbed conservatory dome rising from z=88 to z=182 (semi-dome shell + 11 ribs)
    dome_base_z = drum_h
    dome_rx = 65.0
    dome_ry = 19.5
    dome_h = 94.0
    ring_levels = 7
    rib_count = 11
    # Horizontal purlin rings + translucent dome panels
    for r in range(ring_levels):
        t0 = r / ring_levels
        t1 = (r + 1) / ring_levels
        a0 = t0 * (math.pi * 0.48)
        a1 = t1 * (math.pi * 0.48)
        z0 = dome_base_z + math.sin(a0) * dome_h
        z1 = dome_base_z + math.sin(a1) * dome_h
        c0, c1 = math.cos(a0), math.cos(a1)
        for k in range(rib_count - 1):
            u0 = -0.5 * math.pi + math.pi * k / (rib_count - 1)
            u1 = -0.5 * math.pi + math.pi * (k + 1) / (rib_count - 1)
            um = (u0 + u1) * 0.5
            # Glass dome facet
            px = math.sin(um) * dome_rx * (c0 + c1) * 0.5
            py = math.cos(um) * dome_ry * (c0 + c1) * 0.5
            pz = (z0 + z1) * 0.5
            seg_w = math.hypot(
                (math.sin(u1) - math.sin(u0)) * dome_rx * c0,
                (math.cos(u1) - math.cos(u0)) * dome_ry * c0,
            ) + 1.2
            seg_h = math.hypot((c0 - c1) * dome_rx * 0.5, z1 - z0) + 1.0
            yaw = math.atan2(-math.sin(um) * dome_ry, math.cos(um) * dome_rx)
            tilt = math.atan2(c0 - c1, (z1 - z0) / dome_rx) * 0.55
            box(crystal, (seg_w, 1.8, seg_h), M((px, py, pz), rot=(tilt, 0, yaw)))
            # Warm golden-pearl vault ribs glowing softly on inner underside
            if r in (1, 3, 5):
                box(candle, (seg_w * 0.85, 1.2, 1.8), M((px, py - 1.0, pz), rot=(0, 0, yaw)))

    # Heavy external verdigris bronze dome ribs arching to the lantern crown
    for k in range(rib_count):
        u = -0.5 * math.pi + math.pi * k / (rib_count - 1)
        for r in range(ring_levels):
            a0 = (r / ring_levels) * (math.pi * 0.49)
            a1 = ((r + 1) / ring_levels) * (math.pi * 0.49)
            p0 = Vector((math.sin(u) * dome_rx * math.cos(a0), math.cos(u) * dome_ry * math.cos(a0), dome_base_z + math.sin(a0) * dome_h))
            p1 = Vector((math.sin(u) * dome_rx * math.cos(a1), math.cos(u) * dome_ry * math.cos(a1), dome_base_z + math.sin(a1) * dome_h))
            d = p1 - p0
            mid = (p0 + p1) * 0.5
            q = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
            box(accent, (3.2, 3.8, d.length + 1.4), M((mid.x, mid.y, mid.z)) @ q)
            if k % 2 == 0 and r == 0:
                coral_branch(coral, M((p0.x, p0.y - 3.5, p0.z + 2.0)), seed=k + 1, scale=2.6)

    # Crown cupola lantern + golden spire finial reaching Z = 206 studs!
    crown_z = dome_base_z + dome_h
    cone(accent, 13.0, 9.5, 10.0, 12, M((0, 2.0, crown_z + 2.0)))
    cone(candle, 8.2, 7.6, 8.0, 10, M((0, 2.0, crown_z + 9.0)))
    cone(accent, 11.5, 2.0, 10.0, 12, M((0, 2.0, crown_z + 16.0)))
    cone(gold, 2.0, 0.3, 12.0, 8, M((0, 2.0, crown_z + 24.0)))  # tip at 88+94+30 = 212? Let's cap ~206
    uvsphere(gold, 3.2, M((0, 2.0, crown_z + 19.0)), u=8, v=6)


# =============================================================================
# 2. ColossalClam (~46 x 32 x 26) — giant open pearl-white scalloped clam
# =============================================================================
def make_colossal_clam(t: Template):
    trim = t.bm("TRIM")
    alt = t.bm("ALT")
    glow = t.bm("GLOW")
    gold = t.bm("GOLD")
    accent = t.bm("ACCENT")

    # Stepped octagonal limestone pearl-dais pedestal
    cone(trim, 20.5, 17.8, 4.2, 12, M((0, 0, 0.0)))
    cone(accent, 18.2, 16.4, 2.0, 12, M((0, 0, 4.2)))
    ring_mesh(gold, 17.2, 0.7, 16, M((0, 0, 6.2)), tube_segs=6)

    # Lower open clam bowl (curving forward toward -Y)
    for i in range(11):
        u = (i / 10.0) - 0.5
        ang = u * math.pi * 0.88
        r = 18.5 * (1.0 - 0.12 * abs(u * 2.0))
        cx = math.sin(ang) * r * 0.55
        cy = -math.cos(ang) * r * 0.55 + 3.5
        box(alt, (4.4, r, 2.8), M((cx, cy, 8.6 + abs(u) * 2.4), rot=(0.24, 0, -ang)))

    # Towering upper open scalloped valve fanning upward (z = 8..32)
    scallop_fan(alt, 25.5, 3.4, M((0, 6.5, 8.5), rot=(-0.38, 0, 0)), ribs=11, spread=math.pi * 0.86)
    # Golden gilded shell lip & hinge cradle
    box(gold, (14.0, 5.0, 4.5), M((0, 7.8, 8.8)))
    for sx in (-1, 1):
        uvsphere(gold, 2.4, M((sx * 7.2, 7.6, 8.8)), u=7, v=5)

    # Luminous empty pearl-white cradle inside the open clam (where the Pearl of Stillwater lay)
    uvsphere(glow, 8.8, M((0, -0.5, 11.5), scale=(1.35, 1.0, 0.55)), u=12, v=8)
    ring_mesh(gold, 9.6, 0.65, 14, M((0, -0.5, 10.2)), tube_segs=5)


# =============================================================================
# 3. SeaWallSegment (~44 x 38 x 11) — fortified moss-draped curtain wall
# =============================================================================
def make_sea_wall_segment(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    silk = t.bm("SILK")
    moss = t.bm("MOSS")
    glow = t.bm("GLOW")

    # Main battered curtain wall
    box(stone, (44.0, 9.2, 32.0), M((0, 0, 16.0)))
    # Heavy battered base plinth
    box(stone, (44.4, 11.0, 7.0), M((0, -0.4, 3.5)))
    # Twin projecting fortress buttresses
    for sx in (-16.0, 16.0):
        box(trim, (5.2, 11.4, 33.0), M((sx, -0.5, 16.5)))
        box(trim, (6.0, 12.2, 2.6), M((sx, -0.6, 33.2)))
    # Machicolated cornice & crenellated battlements (z = 32..38)
    box(trim, (44.4, 11.2, 2.4), M((0, -0.4, 32.8)))
    for i in range(-3, 4):
        box(stone, (4.0, 2.2, 4.2), M((i * 6.4, -4.8, 36.1)))
        box(trim, (4.4, 2.6, 0.8), M((i * 6.4, -4.8, 38.4)))
    # Tall teal trident banner hanging down front face
    box(silk, (5.4, 0.6, 15.0), M((0, -5.0, 19.5)))
    box(gold, (6.2, 0.9, 0.8), M((0, -5.0, 27.2)))
    trident_glyph(gold, M((0, -5.4, 20.0)), scale=0.95)
    # Hooded aqua sconce braziers flanking the banner
    for sx in (-8.5, 8.5):
        box(accent, (2.2, 2.4, 3.0), M((sx, -5.4, 25.5)))
        uvsphere(glow, 0.95, M((sx, -5.5, 27.2)), u=6, v=5)
    # Waterline moss & barnacle drapery
    for idx, mx in enumerate((-19.0, -8.0, 7.0, 18.0)):
        rock_clean(moss, (7.5, 3.0, 6.2), M((mx, -4.8, 2.2 + (idx % 2) * 1.4)), 301 + idx, subdiv=1)


# =============================================================================
# 4. DrownedGateWall (~64 x 48 x 14) — sealed inner Drowned Gate centerpiece
# =============================================================================
def make_drowned_gate_wall(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    silk = t.bm("SILK")
    moss = t.bm("MOSS")
    glow = t.bm("GLOW")

    # Massive flanking curtain bastions
    box(stone, (64.0, 11.5, 40.0), M((0, 0, 20.0)))
    for sx in (-26.0, 26.0):
        box(trim, (10.5, 13.8, 42.0), M((sx, -0.6, 21.0)))
    # Deeply recessed bricked-up arched Drowned Gate (sealed solid!)
    round_arch(trim, 14.5, 14.5, 4.4, 13.8, M((0, -0.8, 17.5)), segs=12)
    box(accent, (26.0, 2.4, 29.0), M((0, -5.6, 14.5)))
    # Giant carved glowing aqua trident relief on the sealed gate face
    trident_glyph(glow, M((0, -6.9, 15.0)), scale=2.6)
    ring_mesh(gold, 6.8, 0.55, 14, M((0, -6.8, 15.0), rot=(math.pi / 2, 0, 0)), tube_segs=5)
    # Twin carved stone sea-serpent reliefs flanking the sealed arch (straight from guide image!)
    seahorse_relief(trim, accent, M((-18.5, -5.8, 4.0)), side=-1, scale=1.15)
    seahorse_relief(trim, accent, M((18.5, -5.8, 4.0)), side=1, scale=1.15)
    # Pediment nameplate plaque & crenellated Wall-Walk parapet above (z = 40..48)
    box(trim, (26.0, 13.2, 5.2), M((0, -0.8, 40.5)))
    scallop_fan(trim, 7.5, 2.0, M((0, -7.2, 40.5)), ribs=7)
    for i in range(-4, 5):
        box(stone, (4.4, 2.4, 4.8), M((i * 7.2, -5.2, 44.5)))
        box(trim, (4.8, 2.8, 0.9), M((i * 7.2, -5.2, 47.2)))
    # Teal trident banners on flanking piers
    for sx in (-26.0, 26.0):
        box(silk, (5.2, 0.6, 15.0), M((sx, -7.6, 24.0)))
        trident_glyph(gold, M((sx, -8.0, 24.5)), scale=0.85)
    # Flooded moss & barnacle skirt at base
    for idx, mx in enumerate((-22.0, -10.0, 0.0, 10.0, 22.0)):
        rock_clean(moss, (10.0, 3.6, 5.4), M((mx, -6.2, 1.8)), 320 + idx, subdiv=1)


# =============================================================================
# 5. CoralGateTower (~28 x 82 x 28) — western coral-grown fortress tower
# =============================================================================
def make_coral_gate_tower(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    coral = t.bm("CORAL")
    silk = t.bm("SILK")
    glow = t.bm("GLOW")

    # Battered octagonal coastal keep shaft
    cone(stone, 14.2, 12.4, 16.0, 8, M((0, 0, 0.0)))
    cone(stone, 12.4, 11.4, 42.0, 8, M((0, 0, 16.0)))
    # Stone string-courses & machicolated watch gallery (z = 56..63)
    cone(trim, 13.6, 13.6, 3.2, 8, M((0, 0, 56.0)))
    for i in range(8):
        ang = i * math.pi / 4
        cx, cy = math.cos(ang) * 12.2, math.sin(ang) * 12.2
        box(stone, (4.8, 2.4, 4.8), M((cx, cy, 61.5), rot=(0, 0, ang + math.pi / 2)))
        # Hung nautilus shield on alternating merlons
        if i % 2 == 0:
            uvsphere(accent, 2.2, M((cx * 1.12, cy * 1.12, 57.5), scale=(1.0, 0.35, 1.0), rot=(0, 0, ang + math.pi / 2)), u=8, v=6)
            ring_mesh(gold, 1.6, 0.25, 10, M((cx * 1.15, cy * 1.15, 57.5), rot=(math.pi / 2, 0, ang + math.pi / 2)), tube_segs=5)
    # Lantern belfry + verdigris dome crown + coral crest + flagpole (z = 60..84)
    cone(trim, 7.6, 7.2, 7.5, 8, M((0, 0, 59.5)))
    cone(glow, 5.4, 5.4, 5.5, 8, M((0, 0, 60.5)))
    uvsphere(accent, 8.4, M((0, 0, 68.5), scale=(1.0, 1.0, 0.72)), u=10, v=6)
    cone(gold, 0.65, 0.22, 11.5, 6, M((0, 0, 72.5)))
    box(silk, (9.5, 0.5, 3.6), M((4.8, 0, 81.2)))
    # Dramatic branching coral climbing the tower flank & crowning the parapet!
    coral_branch(coral, M((-10.5, -6.5, 22.0), rot=(0.2, -0.3, 0.4)), seed=11, scale=3.2)
    coral_branch(coral, M((10.0, -7.2, 34.0), rot=(0.15, 0.35, -0.3)), seed=12, scale=2.9)
    coral_branch(coral, M((-6.5, -7.5, 62.5)), seed=13, scale=2.4)
    coral_branch(coral, M((6.8, -6.8, 62.5)), seed=14, scale=2.2)
    # Teal banner down front face
    box(silk, (5.8, 0.7, 17.0), M((0, -12.4, 34.0)))
    trident_glyph(gold, M((0, -12.9, 34.5)), scale=1.05)


# =============================================================================
# 6. TideArmillaryTower (~28 x 88 x 28) — eastern Tide Tower with giant armillary sphere
# =============================================================================
def make_tide_armillary_tower(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    metal = t.bm("METAL")
    silk = t.bm("SILK")
    glow = t.bm("GLOW")

    # Square battered coastal watchtower (z = 0..60)
    box(stone, (24.0, 24.0, 14.0), M((0, 0, 7.0)))
    box(stone, (20.4, 20.4, 46.0), M((0, 0, 37.0)))
    for sx in (-10.4, 10.4):
        for sy in (-10.4, 10.4):
            box(trim, (3.4, 3.4, 58.0), M((sx, sy, 29.0)))
    # Parapet gallery + muffled bell niche
    box(trim, (23.6, 23.6, 3.4), M((0, 0, 60.5)))
    for sx in (-9.0, 0.0, 9.0):
        for sy in (-10.8, 10.8):
            box(stone, (4.4, 2.2, 4.4), M((sx, sy, 64.2)))
    for sy in (-9.0, 0.0, 9.0):
        for sx in (-10.8, 10.8):
            box(stone, (2.2, 4.4, 4.4), M((sx, sy, 64.2)))
    # Teal trident banner on front
    box(silk, (6.0, 0.7, 18.0), M((0, -10.8, 36.0)))
    trident_glyph(gold, M((0, -11.3, 36.5)), scale=1.1)
    # Colossal interlocking bronze Armillary / Astrolabe Tide-Sphere crowning the tower (z = 63..90)!
    cone(trim, 6.2, 4.4, 5.0, 8, M((0, 0, 62.0)))
    sphere_z = 76.5
    ring_mesh(gold, 10.6, 0.85, 18, M((0, 0, sphere_z), rot=(math.pi / 2, 0, 0)), tube_segs=6)
    ring_mesh(accent, 9.8, 0.75, 18, M((0, 0, sphere_z), rot=(math.pi / 2, 0, math.pi / 2)), tube_segs=6)
    ring_mesh(gold, 9.2, 0.7, 18, M((0, 0, sphere_z), rot=(0.48, 0.35, 0)), tube_segs=6)
    ring_mesh(metal, 8.6, 0.65, 18, M((0, 0, sphere_z)), tube_segs=6)
    # Axis spear + glowing pearl/aqua core orb
    cone(metal, 0.6, 0.25, 25.0, 6, M((0, 0, sphere_z - 10.5)))
    uvsphere(glow, 3.2, M((0, 0, sphere_z)), u=10, v=7)


# =============================================================================
# 7. PortcullisGatehouse (~56 x 46 x 16) — outer Sea Gate with raised portcullis & scallop pediment
# =============================================================================
def make_portcullis_gatehouse(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    metal = t.bm("METAL")
    silk = t.bm("SILK")
    candle = t.bm("CANDLE")

    # Twin flanking fortified gatehouse piers leaving a WIDE 28-stud clear central passage!
    for sx in (-1, 1):
        px = sx * 20.5
        box(stone, (14.5, 14.5, 36.0), M((px, 0, 18.0)))
        box(trim, (15.8, 15.8, 4.0), M((px, 0, 2.0)))
        box(trim, (15.8, 15.8, 2.8), M((px, 0, 36.4)))
        # Corner merlons & glowing brazier atop each pier
        for mx in (-4.8, 4.8):
            box(stone, (3.6, 2.4, 3.8), M((px + mx, -6.2, 39.6)))
        cone(metal, 2.0, 2.8, 2.6, 8, M((px, -4.0, 39.0)))
        uvsphere(candle, 1.6, M((px, -4.0, 41.0)), u=6, v=5)
        # Teal trident banner on pier front
        box(silk, (4.8, 0.6, 14.0), M((px, -7.8, 20.0)))
        trident_glyph(gold, M((px, -8.2, 20.5)), scale=0.85)

    # High arch header (clear opening Y = 0..24.5, X = -13.2..+13.2)
    round_arch(trim, 14.5, 10.5, 3.8, 14.0, M((0, 0, 17.5)), segs=12)
    box(stone, (28.0, 13.5, 10.0), M((0, 0, 32.0)))
    box(trim, (30.0, 14.8, 2.8), M((0, 0, 37.5)))
    # Giant carved scallop-shell pediment crowning the Sea Gate (iconic guide-image centerpiece!)
    scallop_fan(trim, 10.5, 2.6, M((0, -7.5, 35.5)), ribs=9, spread=math.pi * 0.85)
    uvsphere(gold, 2.2, M((0, -8.2, 36.8)), u=8, v=6)
    # Raised bronze portcullis grate & teeth hanging at top of arch (bottom teeth at Z = 22.0, plenty of clearance!)
    box(metal, (26.0, 1.2, 1.4), M((0, -3.5, 26.8)))
    box(metal, (26.0, 1.2, 1.2), M((0, -3.5, 24.4)))
    for i in range(-5, 6):
        box(metal, (0.9, 1.1, 6.2), M((i * 2.3, -3.5, 25.4)))
        cone(gold, 0.55, 0.1, 1.8, 5, M((i * 2.3, -3.5, 21.6), rot=(math.pi, 0, 0)))


# =============================================================================
# 8. MuffledBellStack (~14 x 11 x 10) — sailcloth-wrapped Tidebell barricade
# =============================================================================
def make_muffled_bell_stack(t: Template):
    accent = t.bm("ACCENT")
    silk = t.bm("SILK")
    wood = t.bm("WOOD")
    stone = t.bm("STONE")
    metal = t.bm("METAL")

    # Timber cribbing & stone chocks
    box(wood, (13.4, 8.8, 1.6), M((0, 0, 0.8)))
    rock_clean(stone, (3.2, 2.8, 2.4), M((-5.4, -2.8, 0.0)), 401, subdiv=1)
    rock_clean(stone, (3.0, 2.8, 2.2), M((5.4, 2.6, 0.0)), 402, subdiv=1)
    # 3 heavy muffled bells stacked in a barricade pyramid
    cast_bell_muffled(accent, silk, wood, M((-3.2, -0.5, 1.5), rot=(0.18, 0.12, 0.3)), scale=1.25)
    cast_bell_muffled(accent, silk, wood, M((3.3, 0.4, 1.5), rot=(-0.15, -0.22, -0.4)), scale=1.2)
    cast_bell_muffled(accent, silk, wood, M((0.0, 0.2, 5.4), rot=(0.35, -0.1, 0.15)), scale=1.18)
    # Chain & timber barricade stakes bracing the stack
    for sx in (-5.2, 5.2):
        cone(wood, 0.65, 0.45, 7.6, 6, M((sx, -2.5, 3.6), rot=(-0.28, sx * 0.15, 0)))
    box(metal, (11.5, 0.6, 0.6), M((0, -2.2, 4.2)))


# =============================================================================
# 9. OysterRack (~18 x 7 x 10) — Pearl Beds cultivation rack with glowing pearls
# =============================================================================
def make_oyster_rack(t: Template):
    wood = t.bm("WOOD")
    moss = t.bm("MOSS")
    alt = t.bm("ALT")
    glow = t.bm("GLOW")
    trim = t.bm("TRIM")

    # Wet pilings & twin timber trestle rails
    for sx in (-7.2, 0.0, 7.2):
        for sy in (-3.6, 3.6):
            cone(wood, 0.65, 0.55, 6.2, 6, M((sx, sy, 0.0)))
            if sy < 0:
                rock_clean(moss, (1.6, 1.6, 1.8), M((sx, sy, 0.0)), 420 + int(sx + 10), subdiv=1)
    for sy in (-3.6, 0.0, 3.6):
        box(wood, (17.2, 0.9, 0.85), M((0, sy, 4.6)))
    # Slatted cultivation trays loaded with open oyster shells & glowing pearls
    for ix in (-5.4, -1.8, 1.8, 5.4):
        for iy in (-1.8, 1.8):
            box(wood, (3.1, 3.0, 0.5), M((ix, iy, 5.15)))
            uvsphere(alt, 1.25, M((ix, iy, 5.65), scale=(1.1, 0.85, 0.35)), u=7, v=5)
            uvsphere(trim, 1.15, M((ix, iy + 0.6, 6.35), scale=(1.0, 0.75, 0.28), rot=(0.65, 0, 0)), u=7, v=5)
            uvsphere(glow, 0.52, M((ix, iy, 5.95)), u=6, v=5)


# =============================================================================
# 10. DivingBell (~11 x 15 x 11) — Divers' Wharf bronze diving bell & timber davit
# =============================================================================
def make_diving_bell(t: Template):
    wood = t.bm("WOOD")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    metal = t.bm("METAL")
    alt = t.bm("ALT")
    candle = t.bm("CANDLE")

    # Timber wharf plinth & A-frame davit hoist
    box(wood, (10.5, 9.6, 1.2), M((0, 0, 0.6)))
    for sx in (-3.8, 3.8):
        box(wood, (1.1, 1.1, 13.5), M((sx, 2.2, 7.2), rot=(-0.18, sx * 0.06, 0)))
    box(wood, (9.4, 1.2, 1.3), M((0, 0.2, 13.8)))
    cone(metal, 0.28, 0.28, 4.8, 6, M((0, -0.4, 9.0)))
    # Heavy riveted verdigris-and-brass diving bell/helmet
    prof = [(3.2, 0.0), (3.4, 0.5), (3.1, 2.2), (2.7, 4.8), (2.2, 6.2), (0.0, 7.1)]
    lathe(accent, prof, 14, M((0, -0.4, 2.4)))
    ring_mesh(gold, 3.25, 0.32, 14, M((0, -0.4, 2.8)), tube_segs=5)
    ring_mesh(gold, 2.95, 0.24, 14, M((0, -0.4, 6.0)), tube_segs=5)
    # Front brass viewport porthole (iconic guide-image diving helmet detail!)
    ring_mesh(gold, 1.25, 0.28, 10, M((0, -3.5, 5.4), rot=(math.pi / 2, 0, 0)), tube_segs=5)
    uvsphere(candle, 0.92, M((0, -3.3, 5.4)), u=7, v=5)
    # Coiled hemp diving ropes & leaded diving weights on deck
    for r in range(3):
        ring_mesh(alt, 1.5 - r * 0.22, 0.26, 10, M((-3.4, -2.6, 1.45 + r * 0.45)), tube_segs=5)
    box(metal, (2.2, 2.2, 1.8), M((3.4, -2.6, 2.1)))


# =============================================================================
# 11. PearlguardGalley (~46 x 34 x 16) — moored fortified galley with scallop sail
# =============================================================================
def make_pearlguard_galley(t: Template):
    wood = t.bm("WOOD")
    metal = t.bm("METAL")
    gold = t.bm("GOLD")
    accent = t.bm("ACCENT")
    silk = t.bm("SILK")
    alt = t.bm("ALT")
    moss = t.bm("MOSS")

    # Curved ribbed galley hull (length along X, facing -X/+X, front broadside -Y)
    hull_pts = [(-21.0, 1.2, 4.5), (-15.0, 5.2, 6.2), (-6.0, 7.2, 6.8), (6.0, 7.2, 6.8), (15.0, 5.2, 6.2), (21.0, 1.4, 7.8)]
    for i in range(len(hull_pts) - 1):
        x0, w0, h0 = hull_pts[i]
        x1, w1, h1 = hull_pts[i + 1]
        mx = (x0 + x1) * 0.5
        mw = (w0 + w1) * 0.5
        mh = (h0 + h1) * 0.5
        box(wood, (x1 - x0 + 0.8, mw * 2.0, mh), M((mx, 0, mh * 0.5 + 0.5)))
    # Swept stern & prow bronze ram + scallop figurehead
    cone(gold, 1.8, 0.2, 7.5, 6, M((-22.5, 0, 2.8), rot=(0, -math.pi / 2, 0)))
    scallop_fan(accent, 4.2, 1.2, M((-19.5, 0, 7.2), rot=(0, 0, math.pi / 2)), ribs=7)
    box(wood, (8.5, 11.5, 3.8), M((15.5, 0, 9.2)))  # raised stern castle
    # Shield rack along both gunwales
    for sx in (-10.0, -5.0, 0.0, 5.0, 10.0):
        for sy in (-7.4, 7.4):
            uvsphere(accent, 1.65, M((sx, sy, 7.8), scale=(1.0, 0.35, 1.0)), u=7, v=5)
            ring_mesh(gold, 1.35, 0.2, 10, M((sx, sy * 1.03, 7.8), rot=(math.pi / 2, 0, 0)), tube_segs=5)
    # Tall mast, yardarm & billowing teal scallop-emblem sail (z = 6..34)
    cone(wood, 0.95, 0.55, 28.0, 8, M((-1.0, 0, 5.5)))
    cone(wood, 0.55, 0.42, 22.0, 6, M((-12.0, -1.2, 27.0), rot=(0, math.pi / 2, 0)))
    # Billowing sail panels
    for row in range(4):
        rz = 14.0 + row * 3.8
        belly = -1.6 - math.sin((row + 0.5) / 4.0 * math.pi) * 2.2
        box(silk, (18.5 - row * 0.8, 0.7, 4.0), M((-1.0, belly, rz)))
    scallop_fan(alt, 5.2, 0.9, M((-1.0, -4.2, 18.0)), ribs=7)
    # Barnacle/moss waterline
    for idx, mx in enumerate((-12.0, 0.0, 12.0)):
        rock_clean(moss, (9.0, 3.2, 2.4), M((mx, -6.8, 0.0)), 440 + idx, subdiv=1)


# =============================================================================
# 12. CoralWardenStatue (~14 x 30 x 12) — armored guardian with glaive & nautilus shield
# =============================================================================
def make_coral_warden_statue(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    accent = t.bm("ACCENT")
    gold = t.bm("GOLD")
    metal = t.bm("METAL")
    coral = t.bm("CORAL")
    glow = t.bm("GLOW")

    # Carved octagonal pedestal
    cone(stone, 6.2, 5.4, 5.2, 8, M((0, 0, 0.0)))
    cone(trim, 5.8, 5.2, 1.4, 8, M((0, 0, 5.2)))
    # Armored legs, greaves, cuirass & crested helm
    for sx in (-1.9, 1.9):
        cone(stone, 1.6, 1.35, 9.0, 7, M((sx, 0, 6.5)))
    box(stone, (7.4, 4.6, 9.2), M((0, 0, 19.5)))
    box(trim, (6.2, 5.2, 6.8), M((0, -0.3, 20.0)))
    uvsphere(stone, 2.2, M((0, 0, 26.2)), u=8, v=6)
    scallop_fan(gold, 3.2, 0.8, M((0, 0.5, 27.6)), ribs=7)  # pearl-crown crest
    uvsphere(glow, 0.7, M((0, -2.0, 26.2)), u=6, v=4)
    # Branching coral pauldrons
    coral_branch(coral, M((-4.6, 0, 23.0), rot=(0, -0.45, 0)), seed=21, scale=1.45)
    coral_branch(coral, M((4.6, 0, 23.0), rot=(0, 0.45, 0)), seed=22, scale=1.45)
    # Tall bronze hook-glaive in right hand
    cone(metal, 0.42, 0.35, 24.5, 6, M((-5.4, -2.2, 5.2)))
    box(gold, (1.4, 3.8, 6.4), M((-5.4, -2.6, 27.6), rot=(0.25, 0, 0)))
    # Sculpted nautilus shield held forward on left arm
    uvsphere(accent, 4.2, M((4.6, -2.8, 17.5), scale=(1.0, 0.42, 1.25)), u=9, v=6)
    ring_mesh(gold, 3.2, 0.4, 12, M((4.6, -4.4, 17.5), rot=(math.pi / 2, 0, 0)), tube_segs=5)


# =============================================================================
# 13. ShellAwningStall (~16 x 13 x 11) — Pearl Market stall with striped shell awning
# =============================================================================
def make_shell_awning_stall(t: Template):
    wood = t.bm("WOOD")
    silk = t.bm("SILK")
    alt = t.bm("ALT")
    gold = t.bm("GOLD")
    glow = t.bm("GLOW")
    candle = t.bm("CANDLE")

    # 4 corner timber posts & market counter
    for sx in (-6.8, 6.8):
        for sy in (-4.0, 4.0):
            h = 10.6 if sy > 0 else 9.0
            box(wood, (0.95, 0.95, h), M((sx, sy, h * 0.5)))
    box(wood, (14.4, 4.4, 3.8), M((0, -2.0, 1.9)))
    box(wood, (15.0, 5.2, 0.6), M((0, -2.0, 4.0)))
    # Striped scalloped canvas awning pitched forward
    for i in range(7):
        sx = -6.6 + i * 2.2
        bm_strip = silk if i % 2 == 0 else alt
        box(bm_strip, (2.25, 10.4, 0.55), M((sx, 0, 10.6), rot=(0.22, 0, 0)))
        # Scalloped front valance drop
        uvsphere(bm_strip, 1.15, M((sx, -5.0, 9.2), scale=(1.0, 0.35, 1.0)), u=6, v=4)
    # Wicker oyster baskets, pearl scale & glowing pearl bowls on counter
    for bx in (-4.4, 0.0, 4.4):
        cone(alt, 1.6, 1.9, 1.8, 8, M((bx, -2.0, 5.1)))
        uvsphere(glow, 1.1, M((bx, -2.0, 6.0), scale=(1.0, 1.0, 0.45)), u=6, v=4)
    # Brass pearl balance scale
    cone(gold, 0.5, 0.25, 2.4, 6, M((2.2, -2.2, 5.4)))
    box(gold, (2.8, 0.25, 0.25), M((2.2, -2.2, 6.4)))
    # Warm hanging market lantern
    uvsphere(candle, 0.9, M((-5.2, -4.2, 8.2)), u=6, v=5)


# =============================================================================
# 14. HarbourCrane (~18 x 26 x 14) — Harbour Ward timber & bronze jib crane
# =============================================================================
def make_harbour_crane(t: Template):
    stone = t.bm("STONE")
    wood = t.bm("WOOD")
    metal = t.bm("METAL")
    gold = t.bm("GOLD")
    accent = t.bm("ACCENT")
    alt = t.bm("ALT")

    # Stone quay plinth & heavy braced mast
    box(stone, (10.0, 10.0, 4.5), M((0, 0, 2.25)))
    box(wood, (2.2, 2.2, 21.0), M((0, 1.5, 14.5)))
    for sx in (-3.2, 3.2):
        box(wood, (1.1, 1.1, 10.0), M((sx, 1.5, 8.2), rot=(0, sx * 0.14, 0)))
    # Angled jib boom projecting forward over the water (-Y)
    box(wood, (1.8, 19.5, 1.8), M((0, -4.5, 21.5), rot=(-0.42, 0, 0)))
    box(metal, (2.2, 1.6, 2.2), M((0, -12.6, 25.0)))
    # Winch drum & bronze crank gears
    cone(wood, 1.4, 1.4, 5.2, 10, M((0, 3.4, 8.8), rot=(0, math.pi / 2, 0)))
    ring_mesh(gold, 2.0, 0.35, 10, M((2.8, 3.4, 8.8), rot=(0, math.pi / 2, 0)), tube_segs=5)
    # Dangling chain + suspended muffled cargo crate / pearl cask
    cone(metal, 0.24, 0.24, 12.5, 6, M((0, -12.6, 12.5)))
    box(accent, (4.8, 4.8, 4.4), M((0, -12.6, 10.5)))
    box(alt, (5.2, 0.7, 4.6), M((0, -12.6, 10.5)))


# =============================================================================
# 15. CoralCageReliquary (~10 x 17 x 10) — Coral Abyss Core relic monument
# =============================================================================
def make_coral_cage_reliquary(t: Template):
    stone = t.bm("STONE")
    trim = t.bm("TRIM")
    coral = t.bm("CORAL")
    gold = t.bm("GOLD")
    accent = t.bm("ACCENT")
    glow = t.bm("GLOW")
    crystal = t.bm("CRYSTAL")

    # Stepped carved reliquary plinth
    cone(stone, 5.2, 4.4, 4.5, 8, M((0, 0, 0.0)))
    cone(trim, 4.8, 4.0, 2.0, 8, M((0, 0, 4.5)))
    ring_mesh(gold, 4.0, 0.35, 12, M((0, 0, 6.6)), tube_segs=5)
    # Swirling coral & bronze filigree ribs caging a blazing aqua-pearl Abyss Core
    core_z = 11.4
    for i in range(6):
        ang = i * math.pi / 3
        cx, cy = math.cos(ang) * 3.4, math.sin(ang) * 3.4
        coral_branch(coral, M((cx * 0.85, cy * 0.85, 6.4), rot=(0.25 * math.sin(ang), -0.25 * math.cos(ang), ang)), seed=50 + i, scale=1.55)
        cone(accent, 0.35, 0.28, 8.8, 6, M((cx, cy, 6.6), rot=(0.15 * math.sin(ang), -0.15 * math.cos(ang), 0)))
    ring_mesh(gold, 3.6, 0.32, 12, M((0, 0, 15.2)), tube_segs=5)
    cone(gold, 1.2, 0.2, 2.8, 6, M((0, 0, 15.2)))
    uvsphere(glow, 2.2, M((0, 0, core_z)), u=10, v=7)
    uvsphere(crystal, 2.9, M((0, 0, core_z)), u=8, v=6)


DEFAULT_BUDGET = 900
F39_TEMPLATES = {
    "PearlVaultDome": (make_pearl_vault_dome, {"STONE": 1400, "TRIM": 1200, "ACCENT": 1400, "CRYSTAL": 1200, "CANDLE": 700, "CORAL": 900, "GOLD": 500}),
    "ColossalClam": (make_colossal_clam, {"ALT": 1200, "TRIM": 600, "GLOW": 600, "GOLD": 600, "ACCENT": 400}),
    "SeaWallSegment": (make_sea_wall_segment, {"STONE": 800, "TRIM": 600, "MOSS": 600, "SILK": 300, "GOLD": 400, "ACCENT": 300, "GLOW": 300}),
    "DrownedGateWall": (make_drowned_gate_wall, {"STONE": 900, "TRIM": 1200, "ACCENT": 600, "MOSS": 600, "SILK": 300, "GOLD": 500, "GLOW": 400}),
    "CoralGateTower": (make_coral_gate_tower, {"STONE": 900, "TRIM": 600, "ACCENT": 700, "CORAL": 1100, "GOLD": 600, "SILK": 300, "GLOW": 300}),
    "TideArmillaryTower": (make_tide_armillary_tower, {"STONE": 800, "TRIM": 600, "GOLD": 900, "ACCENT": 700, "METAL": 600, "SILK": 300, "GLOW": 400}),
    "PortcullisGatehouse": (make_portcullis_gatehouse, {"STONE": 900, "TRIM": 900, "METAL": 800, "GOLD": 600, "SILK": 400, "CANDLE": 400}),
    "MuffledBellStack": (make_muffled_bell_stack, {"ACCENT": 900, "SILK": 800, "WOOD": 700, "STONE": 400, "METAL": 300}),
    "OysterRack": (make_oyster_rack, {"WOOD": 500, "ALT": 700, "TRIM": 600, "GLOW": 500, "MOSS": 400}),
    "DivingBell": (make_diving_bell, {"ACCENT": 800, "GOLD": 600, "WOOD": 500, "ALT": 600, "METAL": 400, "CANDLE": 300}),
    "PearlguardGalley": (make_pearlguard_galley, {"WOOD": 900, "SILK": 600, "ALT": 600, "ACCENT": 700, "GOLD": 600, "MOSS": 500}),
    "CoralWardenStatue": (make_coral_warden_statue, {"STONE": 800, "TRIM": 500, "ACCENT": 600, "GOLD": 600, "CORAL": 700, "METAL": 400, "GLOW": 300}),
    "ShellAwningStall": (make_shell_awning_stall, {"WOOD": 500, "SILK": 600, "ALT": 700, "GOLD": 400, "GLOW": 400, "CANDLE": 300}),
    "HarbourCrane": (make_harbour_crane, {"WOOD": 600, "STONE": 400, "METAL": 500, "GOLD": 400, "ACCENT": 400, "ALT": 300}),
    "CoralCageReliquary": (make_coral_cage_reliquary, {"CORAL": 900, "STONE": 500, "TRIM": 400, "ACCENT": 500, "GOLD": 600, "GLOW": 500, "CRYSTAL": 400}),
}


def build_kit():
    reset_scene()
    kit = bpy.data.collections.new("SunkenF39Kit")
    bpy.context.scene.collection.children.link(kit)
    manifest = {}
    for name, (fn, budget) in F39_TEMPLATES.items():
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
        filepath=os.path.join(OUT_DIR, "SunkenF39Kit.fbx"),
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
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, "SunkenF39Kit.blend"))


if __name__ == "__main__":
    kit, manifest = build_kit()
    export_kit(kit, manifest)
    preview_dir = os.path.join(OUT_DIR, "previews")
    render_previews(kit, preview_dir, list(F39_TEMPLATES.keys()), tile=520, cols=5)
    print(json.dumps(manifest, indent=2))
