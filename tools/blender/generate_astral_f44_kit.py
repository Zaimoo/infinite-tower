"""
Astral Archives Floor 44 (Runeguard Athenaeum) sculpted assets, generated in headless Blender.

Inspired by the Runeguard Athenaeum reference art (reference/Astral Archives 44.jpg) and the Runeguard
ward-fortress ecosystem (docs/prompts/astral-archives-floor-layouts-prompt.md):
three ascending stone wards locked behind two shimmering Rune-Ward Walls, each pierced by a single
Waygate ring-portal. Towering over the back-east Sealed Stacks rises the colossal Athenaeum Dome — split
into AthenaeumDomeDrum (open-front arched colonnade rotunda with inner Sealed Stacks & anchor chains)
and AthenaeumDomeCrown (lapis-indigo ribbed dome locked down with diagonal brass rune-chains, reaching
220 studs combined). Two Rune-Ward barriers are built from RunewardPylons and sculpted glowing-glyph
RunewardVeils, pierced by West & East WaygateRings hung with the floor's only unshuttered golden Index
Lamps. Flanking RuneguardTowers watch the walls; inside lie the Hall of Indices (IndexBoard with half
its star-glyphs blacked out), the Seal Forge (StarIronAnvil & furnace hearth, SealPress & oath-stones),
the Forbidden Vault (geared VaultRingDoor swung open), the Reliquary of Lenses (LensRack with one
cracked optical lens), the Sealed Stacks' caged half-written entry (ChainedTomeRack), ShutteredLamps
locked behind rune-plates, Copyists' Yard awnings (CopyistAwning), Binders' Yard sewing & vellum frames
(SewingFrame), Porters' Lodge lift-cage & book cart (BookCartLift), and the Warded Court's inlaid floor
circle (WardedCirclePad).

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands on its origin.

Roles (AstralFloor44 passes the Runeguard indigo-dusk override; no new colour roles):
    STONE    pale vellum-stone & grey ashlar      ALT      lapis-indigo dome, dark slate & sealed plates
    TRIM     worn gold leaf & gilded rune trim    METAL    aged brass chains, gears, vault & forge iron
    WOOD     ebony shelving, crates & frames      SILK     vellum awnings, stretched hides & pages
    GLOW     warm Waygate gold & ward-script      CRYSTAL  ground star-glass lenses & ward sheen

Outputs (assets-source/tower/astral_f44_kit/):
    AstralF44Kit.blend, AstralF44Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_astral_f44_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "astral_f44_kit")

# Reuse shared primitives, Halcyr motifs, chains, gears, and kit pipeline from Floors 41 & 42.
f41 = runpy.run_path(os.path.join(HERE, "generate_astral_f41_kit.py"))
f42 = runpy.run_path(os.path.join(HERE, "generate_astral_f42_kit.py"))

box = f41["box"]
cone = f41["cone"]
uvsphere = f41["uvsphere"]
tube = f41["tube"]
ring_mesh = f41["ring_mesh"]
lathe = f41["lathe"]
cyl_x, cyl_y, cyl_z, strut = f41["cyl_x"], f41["cyl_y"], f41["cyl_z"], f41["strut"]
ground_rock, slab_stone = f41["ground_rock"], f41["slab_stone"]
build_kit, export_kit, render_previews = f41["build_kit"], f41["export_kit"], f41["render_previews"]
open_tome, chain_run, index_lantern_head = f41["open_tome"], f41["chain_run"], f41["index_lantern_head"]
star_quill_sigil, apply_halcyr_preview_materials = f41["star_quill_sigil"], f41["apply_halcyr_preview_materials"]
spoked_gear = f42["spoked_gear"]

T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F44_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F44_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# 1. AthenaeumDomeDrum — Open-front 118-stud arched colonnade rotunda drum (lower half of 220-stud dome)
# -----------------------------------------------------------------------------------------------------------
@template("AthenaeumDomeDrum", STONE=5600, ALT=2400, TRIM=4200, METAL=3400, WOOD=2200, GLOW=1600, SILK=800)
def athenaeum_dome_drum(t):
    """Lower rotunda drum of the Runeguard Athenaeum Dome (118 studs tall, 104 wide, open front portal facing -Y
    so the Sealed Stacks arena stays clear): 12 monumental fluted vellum-stone piers arranged in a circle (front
    3 bays open for the grand portico!), tall arched golden-lit rotunda windows between piers, curved inner
    ebony Sealed Stacks bookcases lining the back apse, gilded entablature cornice, and 4 sweeping exterior
    brass anchor chains pinning the cornice down to flank mooring bollards."""
    stone, alt, trim, metal, wood, glow, silk = (t.bm(r) for r in ("STONE", "ALT", "TRIM", "METAL", "WOOD", "GLOW", "SILK"))
    R_drum = 46.0
    H_drum = 114.0
    bays = 12

    # Stepped circular rotunda floor kerb (horseshoe open at the front -Y arc for wide arena entry!).
    for k in range(bays):
        a = 2 * math.pi * k / bays
        px, py = math.cos(a) * R_drum, math.sin(a) * R_drum
        # Keep front entrance bay (south, -Y: sin(a) < -0.75) completely open!
        is_front_gap = (math.sin(a) < -0.82)
        if not is_front_gap:
            pm = T((px, py, 0.0)) @ R(a, 4, "Z")
            # Massive pier base, fluted shaft & gilded capital rising to H_drum.
            box(stone, (7.6, 8.2, 7.5), pm @ T((0, 0, 3.75)), bevel=0.25)
            box(stone, (5.8, 6.4, H_drum - 12.0), pm @ T((0, 0, 7.5 + (H_drum - 12.0) * 0.5)), bevel=0.18)
            box(trim, (6.8, 7.4, 2.2), pm @ T((0, 0, H_drum - 4.0)))
            box(stone, (7.6, 8.0, 3.2), pm @ T((0, 0, H_drum - 1.2)))
            # Vertical lapis inlay flute on outer pier face.
            box(alt, (0.8, 2.8, H_drum - 24.0), pm @ T((3.1, 0, 56.0)))

        # Curtain wall + tall arched glowing rotunda window spanning to next pier (skip front 3 entrance bays!).
        a_mid = 2 * math.pi * (k + 0.5) / bays
        if math.sin(a_mid) < -0.45:
            continue
        mx, my = math.cos(a_mid) * (R_drum - 0.6), math.sin(a_mid) * (R_drum - 0.6)
        wm = T((mx, my, 0.0)) @ R(a_mid, 4, "Z")
        bay_w = 2 * math.pi * R_drum / bays - 4.6
        # Lower stone dado wall & inner Sealed Stacks ebony bookshelves!
        box(stone, (3.6, bay_w, 34.0), wm @ T((0, 0, 17.0)))
        box(wood, (2.2, bay_w - 1.2, 29.0), wm @ T((-2.4, 0, 15.5)))
        for s_z in (6.5, 14.0, 21.5, 29.0):
            box(trim, (2.4, bay_w - 1.4, 0.55), wm @ T((-2.5, 0, s_z)))
            box(silk if int(s_z) % 2 else alt, (1.5, bay_w - 2.6, 4.8), wm @ T((-2.7, 0, s_z - 3.2)))
        # Upper arched golden-lit cathedral window bay (Z = 34..102).
        box(stone, (3.2, bay_w, 6.0), wm @ T((0, 0, 36.0)))
        box(alt, (2.4, bay_w - 1.0, 58.0), wm @ T((0.2, 0, 68.0)))
        box(glow, (1.4, bay_w - 3.8, 52.0), wm @ T((0.5, 0, 68.0)))
        # Mullion grid over the glowing rotunda window.
        box(trim, (1.8, 0.9, 54.0), wm @ T((0.6, 0, 68.0)))
        for wz in (52.0, 70.0, 86.0):
            box(trim, (1.8, bay_w - 2.4, 0.9), wm @ T((0.6, 0, wz)))
        box(stone, (3.6, bay_w + 1.0, 14.0), wm @ T((0, 0, 104.0)))

    # Grand circular entablature ring crowning the entire drum (Z = 111..118).
    ring_mesh(stone, R_drum, 3.6, 36, T((0, 0, H_drum + 0.5)), tube_segs=6)
    ring_mesh(trim, R_drum + 3.4, 1.15, 36, T((0, 0, H_drum + 3.0)), tube_segs=6)
    ring_mesh(alt, R_drum + 2.8, 0.85, 36, T((0, 0, H_drum - 2.5)), tube_segs=5)

    # Four massive exterior brass anchor chains sweeping down from the east & west cornice flanks to anchor bollards!
    for sx in (-1, 1):
        for sy_off in (-16.0, 16.0):
            top_pt = (sx * (R_drum + 3.2), sy_off, H_drum - 4.0)
            bot_pt = (sx * (R_drum + 22.0), sy_off * 1.15, 3.0)
            box(stone, (6.0, 6.0, 4.5), T((bot_pt[0], bot_pt[1], 2.25)), bevel=0.2)
            ring_mesh(metal, 1.8, 0.45, 12, T((bot_pt[0], bot_pt[1], 4.8)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
            chain_run(metal, trim, top_pt, bot_pt, link_h=4.6, link_w=2.6, thick=0.52)


# -----------------------------------------------------------------------------------------------------------
# 2. AthenaeumDomeCrown — Colossal 102-stud lapis-indigo ribbed dome locked down with brass rune-chains
# -----------------------------------------------------------------------------------------------------------
@template("AthenaeumDomeCrown", ALT=3600, TRIM=4200, METAL=3600, STONE=1800, GLOW=1200, CRYSTAL=600)
def athenaeum_dome_crown(t):
    """Upper ribbed lapis-indigo dome of the Runeguard Athenaeum (104 studs tall, 102 diameter; sits atop
    AthenaeumDomeDrum for a combined 220-stud height clearing Floor 44's ≥210-stud ladder target!): deep
    lapis-indigo shell, 12 bold gold structural ribs, crisscrossing diagonal brass rune-chains bolted over
    the dome (directly from the Floor 44 guide image!), and a golden star-quill lantern cupola at the peak."""
    alt, trim, metal, stone, glow, crystal = (t.bm(r) for r in ("ALT", "TRIM", "METAL", "STONE", "GLOW", "CRYSTAL"))
    R_base = 48.0
    H_dome = 76.0

    # Moulded vellum-and-gold base collar ring standing cleanly on z = 0.
    ring_mesh(stone, R_base, 2.8, 36, T((0, 0, 2.6)), tube_segs=6)
    ring_mesh(trim, R_base + 2.4, 0.95, 36, T((0, 0, 5.2)), tube_segs=5)

    # Smooth ogival/hemispherical lapis-indigo dome shell via lathe (Z = 4..80).
    profile = []
    for k in range(13):
        f = k / 12.0
        ang = f * (math.pi * 0.48)
        rr = max(4.2, math.cos(ang) * R_base * (1.0 - 0.05 * f))
        zz = 4.0 + math.sin(ang) * H_dome
        profile.append((rr, zz))
    lathe(alt, profile, 32, Matrix.Identity(4), cap_bottom=False, cap_top=True)

    # 12 bold gold ribs climbing from collar to cupola lantern + horizontal compression rings.
    for k in range(12):
        a = 2 * math.pi * k / 12
        pts = [(math.cos(a) * (r + 1.0), math.sin(a) * (r + 1.0), z) for (r, z) in profile]
        tube(trim, pts, [1.35 - 0.05 * i for i in range(len(pts))], 6, cap=True)
    ring_mesh(trim, R_base * 0.72, 0.95, 32, T((0, 0, 4.0 + H_dome * 0.68)), tube_segs=5)

    # Crisscrossing diagonal brass rune-chains riding cleanly OVER the convex lapis dome surface (guide image hero motif!).
    for k in range(12):
        a0 = 2 * math.pi * k / 12
        a1 = 2 * math.pi * (k + 1) / 12
        am = 0.5 * (a0 + a1)
        r_low = R_base * 0.99 + 1.8
        r_mid = R_base * 0.91 + 2.4
        r_hi = R_base * 0.74 + 2.0
        z_low, z_mid, z_hi = 14.0, 35.0, 4.0 + H_dome * 0.66
        p_low0 = (math.cos(a0) * r_low, math.sin(a0) * r_low, z_low)
        p_low1 = (math.cos(a1) * r_low, math.sin(a1) * r_low, z_low)
        p_x = (math.cos(am) * r_mid, math.sin(am) * r_mid, z_mid)
        p_hi0 = (math.cos(a0) * r_hi, math.sin(a0) * r_hi, z_hi)
        p_hi1 = (math.cos(a1) * r_hi, math.sin(a1) * r_hi, z_hi)
        chain_run(metal, trim, p_low0, p_x, link_h=3.6, link_w=2.0, thick=0.45)
        chain_run(metal, trim, p_x, p_hi1, link_h=3.6, link_w=2.0, thick=0.45)
        chain_run(metal, trim, p_low1, p_x, link_h=3.6, link_w=2.0, thick=0.45)
        chain_run(metal, trim, p_x, p_hi0, link_h=3.6, link_w=2.0, thick=0.45)
        uvsphere(trim, 1.35, T(p_x), 8, 6)

    # Soaring gilded star-lantern cupola & spire crowning the dome (Z = 79..104).
    cz = 79.0
    cone(stone, 8.6, 8.2, 2.6, 12, T((0, 0, cz)))
    for k in range(8):
        a = 2 * math.pi * k / 8
        strut(trim, (math.cos(a) * 6.8, math.sin(a) * 6.8, cz + 2.4), (math.cos(a) * 6.4, math.sin(a) * 6.4, cz + 12.6), 0.95)
    cone(glow, 4.8, 4.8, 9.6, 12, T((0, 0, cz + 2.6)))
    cone(crystal, 5.6, 5.6, 9.6, 12, T((0, 0, cz + 2.6)))
    lathe(trim, [(7.8, cz + 12.2), (6.4, cz + 15.2), (2.2, cz + 18.2), (0.3, cz + 25.0)], 12, Matrix.Identity(4))
    uvsphere(glow, 1.5, T((0, 0, cz + 23.8)), 10, 8)


# -----------------------------------------------------------------------------------------------------------
# 3. RunewardPylon — Tall faceted lapis-and-brass ward pylon with glowing star-glyphs & crystal tip
# -----------------------------------------------------------------------------------------------------------
@template("RunewardPylon", STONE=1800, ALT=1200, METAL=1400, TRIM=1200, CRYSTAL=900, GLOW=900)
def runeward_pylon(t):
    """Runeguard ward-wall anchor pylon (seen dividing every luminous ward-wall bay in the guide image):
    stepped grey-vellum ashlar plinth, tall square bevelled stone obelisk banded with brass collars, vertical
    glowing lapis glyph-channels down each face, and a sharp faceted star-glass pyramid crystal finial.
    About 26 studs tall."""
    stone, alt, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "CRYSTAL", "GLOW"))

    # Stepped fortress plinth.
    box(stone, (7.6, 7.6, 2.2), T((0, 0, 1.1)), bevel=0.18)
    box(alt, (6.2, 6.2, 1.6), T((0, 0, 3.0)))
    box(stone, (5.4, 5.4, 17.5), T((0, 0, 12.55)), bevel=0.22)
    # Brass binding collars & gilded capital cornice.
    for zc in (6.5, 13.5, 20.5):
        box(metal, (5.9, 5.9, 0.85), T((0, 0, zc)))
    box(trim, (6.4, 6.4, 0.9), T((0, 0, 21.6)))
    # Vertical carved lapis & glowing glyph channels on all 4 faces.
    for k in range(4):
        m = R(k * math.pi / 2, 4, "Z")
        box(alt, (1.8, 0.5, 15.6), m @ T((0, -2.75, 12.6)))
        for row in range(6):
            box(glow, (1.1 if row % 2 == 0 else 0.55, 0.25, 1.1), m @ T((0, -2.98, 6.2 + row * 2.5)))
    # Faceted star-glass pyramid cap caged in gold corner ribs (Z = 22..27).
    cone(crystal, 3.4, 0.12, 4.8, 4, T((0, 0, 22.0)) @ R(math.pi / 4, 4, "Z"))
    cone(glow, 1.7, 0.06, 3.6, 4, T((0, 0, 22.3)) @ R(math.pi / 4, 4, "Z"))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        strut(trim, (math.cos(a) * 3.5, math.sin(a) * 3.5, 22.0), (0, 0, 26.8), 0.26)


# -----------------------------------------------------------------------------------------------------------
# 4. RunewardVeil — Sculpted luminous Runeguard glyph barrier curtain (no flat semi-transparent box!)
# -----------------------------------------------------------------------------------------------------------
@template("RunewardVeil", STONE=1200, METAL=1400, TRIM=1200, CRYSTAL=1400, GLOW=2400)
def runeward_veil(t):
    """A 36-stud-wide Runeguard rune-ward barrier span (matching the luminous vertical glyph-script walls
    stretching across both wards in the guide image): low bevelled stone & brass emitter sill on the ground,
    slender brass top rail, sculpted fluted star-glass energy columns, and dense staggered vertical columns
    of raised glowing star-glyph bars. Pure sculpted geometry (no flat semi-transparent box!)."""
    stone, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "CRYSTAL", "GLOW"))
    W, H = 36.0, 18.5
    rng = random.Random(4404)

    # Grounded emitter sill & upper anchor beam.
    box(stone, (W, 3.2, 1.4), T((0, 0, 0.7)), bevel=0.12)
    box(metal, (W - 0.6, 2.0, 0.65), T((0, 0, 1.72)))
    box(glow, (W - 1.2, 0.8, 0.35), T((0, 0, 2.1)))
    box(trim, (W, 1.2, 0.55), T((0, 0, H)))

    # Sculpted vertical star-glass fluted fins forming the shimmering energy veil.
    for k in range(15):
        fx = -W * 0.46 + k * (W * 0.92 / 14)
        cone(crystal, 0.38, 0.28, H - 2.2, 4, T((fx, 0, 2.1)) @ R(math.pi / 4, 4, "Z"))

    # Vertical columns of raised glowing Runeguard ward-script bars (reads identically to the guide art!).
    for col in range(18):
        cx = -W * 0.47 + col * (W * 0.94 / 17)
        for row in range(7):
            if rng.random() < 0.16:
                continue
            gz = 3.2 + row * 2.1 + rng.uniform(-0.15, 0.15)
            gw = rng.uniform(0.65, 1.25)
            gh = rng.uniform(0.45, 1.15)
            box(glow, (gw, 0.42, gh), T((cx, 0, gz)))
            if (col + row) % 4 == 0:
                box(trim, (gw * 1.15, 0.52, 0.22), T((cx, 0, gz)))


# -----------------------------------------------------------------------------------------------------------
# 5. WaygateRing — Standing circular brass Waygate ring-portal hung with the ONLY 2 lit golden Index Lamps!
# -----------------------------------------------------------------------------------------------------------
@template("WaygateRing", STONE=2400, ALT=1600, METAL=3200, TRIM=2800, CRYSTAL=1200, GLOW=1200)
def waygate_ring(t):
    """The West and East Waygates (the single physical ring-portal crossing through each rune-ward, seen
    gleaming warm gold in the Floor 44 guide image): massive circular brass-and-lapis ring arch on stepped
    fortress piers (wide 24-stud clear bridge opening inside!), crowned with a glowing star-crystal keystone,
    inner turning ring rim, and the floor's TWO unshuttered golden Index Lamps hanging inside the arch!"""
    stone, alt, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "CRYSTAL", "GLOW"))

    # Flanking fortress pier plinths (clear bridge opening from X = -12.5 to +12.5).
    for sx in (-1, 1):
        px = sx * 15.6
        box(stone, (6.2, 7.6, 2.4), T((px, 0, 1.2)), bevel=0.16)
        box(stone, (5.2, 6.4, 7.8), T((px, 0, 6.3)), bevel=0.12)
        box(alt, (3.4, 6.7, 5.0), T((px, 0, 6.3)))
        box(trim, (5.6, 6.8, 0.6), T((px, 0, 10.4)))

    # Massive circular Waygate portal ring (centre Z = 16.5, R = 15.2 -> top at Z = 33.5).
    cz, R_g = 16.5, 15.2
    segs = 32
    for k in range(segs):
        a = -math.radians(30) + math.radians(240) * (k + 0.5) / segs
        x = math.cos(a) * R_g
        z = cz + math.sin(a) * R_g
        if z < 3.5:
            continue
        seg_len = (2 * math.pi * R_g * 240 / 360) / segs + 0.35
        m = T((x, 0, z)) @ R(-a, 4, "Y")
        box(alt, (2.6, 3.6, seg_len), m)
        for sr in (-1, 1):
            box(trim, (0.52, 4.0, seg_len * 0.99), m @ T((sr * 1.45, 0, 0)))
        if k % 2 == 0:
            for sy in (-1, 1):
                box(glow, (0.38, 0.22, 1.15), m @ T((0, sy * 1.9, 0)))

    # Inner turning brass rune-ring + outer structural brass collar.
    for r_r, th, bm in ((R_g + 1.85, 0.42, metal), (R_g - 1.9, 0.36, trim), (R_g - 2.9, 0.24, metal)):
        pts = [(math.cos(math.radians(-26 + 232 * k / 30)) * r_r, 0.0, cz + math.sin(math.radians(-26 + 232 * k / 30)) * r_r) for k in range(31)]
        tube(bm, pts, [th] * len(pts), 6, cap=True)

    # Glowing star-crystal keystone crest at the Waygate apex (Z = 31.8..36.5).
    box(stone, (4.8, 4.4, 4.6), T((0, 0, cz + R_g + 0.8)), bevel=0.2)
    cone(crystal, 1.6, 0.1, 3.2, 4, T((0, 0, cz + R_g + 3.0)) @ R(math.pi / 4, 4, "Z"))
    uvsphere(glow, 0.95, T((0, -2.2, cz + R_g + 0.8)), 8, 6)

    # THE TWO UNSHUTTERED GOLDEN INDEX LAMPS hanging inside the arch (at Z = 22.8, well above 18-stud clearance!).
    for sx in (-1, 1):
        lx = sx * 7.2
        chain_top_z = cz + math.sqrt(max(1.0, (R_g - 1.8) ** 2 - lx ** 2))
        chain_run(metal, trim, (lx, 0, chain_top_z), (lx, 0, 23.6), link_h=1.1, link_w=0.65, thick=0.12)
        index_lantern_head(metal, trim, crystal, glow, T((lx, 0, 22.2)), scale=1.12)


# -----------------------------------------------------------------------------------------------------------
# 6. RuneguardTower — Crenellated Runeguard bastion tower with glaive racks & chained chests
# -----------------------------------------------------------------------------------------------------------
@template("RuneguardTower", STONE=4200, ALT=2400, METAL=2200, TRIM=1800, WOOD=1400, GLOW=700)
def runeguard_tower(t):
    """West and East Tower bastion (seen flanking both wings of the middle ward in the guide image): a stout
    30-stud-wide crenellated dark-slate & grey-stone octagonal watchtower with battered plinth, brass string-
    courses, merlon battlements, arched arrow slits, Runeguard glaives racked along its foot, and chained
    confiscated book chests on its parapet. About 38 studs tall."""
    stone, alt, metal, trim, wood, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "WOOD", "GLOW"))
    R_t, H_t = 13.5, 32.0

    # Battered ashlar base plinth & main octagonal drum.
    cone(stone, R_t + 2.0, R_t + 0.4, 6.0, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(alt, R_t, R_t - 0.8, H_t - 6.0, 8, T((0, 0, 6.0)) @ R(math.pi / 8, 4, "Z"))
    # Stone corner quoins & brass reinforcing belts.
    for z_b in (6.0, 18.0, 29.5):
        ring_mesh(metal, R_t + 0.2 - (z_b / H_t) * 0.6, 0.55, 16, T((0, 0, z_b)), tube_segs=5)
    # Corbelled overhanging battlement crown & 16 stone merlons!
    cone(stone, R_t - 0.4, R_t + 1.6, 2.8, 8, T((0, 0, H_t - 2.0)) @ R(math.pi / 8, 4, "Z"))
    ring_mesh(trim, R_t + 1.6, 0.35, 20, T((0, 0, H_t + 0.8)), tube_segs=5)
    for k in range(16):
        if k % 2 == 1:
            continue
        a = 2 * math.pi * k / 16
        mm = R(a, 4, "Z") @ T((R_t + 0.7, 0, H_t + 2.6))
        box(stone, (2.2, 3.6, 3.4), mm, bevel=0.1)
        box(trim, (2.4, 3.8, 0.32), mm @ T((0, 0, 1.8)))
    # Recessed arrow slits & subtle watch-glow windows.
    for k in range(8):
        a = 2 * math.pi * k / 8
        wm = R(a, 4, "Z") @ T((R_t - 0.4, 0, 21.0))
        box(stone, (1.4, 2.8, 6.2), wm)
        box(glow if k % 2 == 0 else alt, (0.8, 1.1, 4.6), wm @ T((0.5, 0, 0)))

    # Confiscated brass-bound chests chained to the parapet roof (seen on top of both towers in the guide art!).
    for sx, sy, yaw in ((-4.2, -2.8, 0.4), (4.6, 2.2, -0.5)):
        cm = T((sx, sy, H_t + 0.8)) @ R(yaw, 4, "Z")
        box(wood, (4.4, 2.8, 2.4), cm @ T((0, 0, 1.2)), bevel=0.08)
        box(metal, (4.6, 3.0, 0.35), cm @ T((0, 0, 1.2)))
        box(trim, (0.7, 3.05, 2.5), cm @ T((0, 0, 1.25)))

    # Runeguard glaives racked along the front (-Y) tower base wall.
    for k in range(5):
        gx = -4.0 + k * 2.0
        cyl_z(metal, 0.14, 9.2, (gx, -(R_t + 1.4), 0.2), segs=8)
        box(trim, (0.28, 0.75, 2.4), T((gx, -(R_t + 1.55), 10.2)))


# -----------------------------------------------------------------------------------------------------------
# 7. IndexBoard — Hall of Indices monumental Star-Glyph Board with half its plates blacked out!
# -----------------------------------------------------------------------------------------------------------
@template("IndexBoard", WOOD=2200, STONE=1400, TRIM=1800, ALT=1400, GLOW=1200, METAL=900)
def index_board(t):
    """Hall of Indices' great star-glyph index board (seen on the back wall of the middle scriptorium in the
    guide image): a 20-stud-wide ebony-and-brass architectural frame holding a 6x4 grid of star-glyph plates —
    half glowing pale-gold, half ominously shuttered/blacked out with bolted dark slate seal-plates."""
    wood, stone, trim, alt, glow, metal = (t.bm(r) for r in ("WOOD", "STONE", "TRIM", "ALT", "GLOW", "METAL"))
    W, H = 20.0, 13.0

    # Stepped stone plinth & carved ebony frame with brass corner brackets.
    box(stone, (W + 1.6, 3.2, 1.2), T((0, 0, 0.6)), bevel=0.1)
    box(wood, (W, 1.8, H - 1.6), T((0, 0, 1.2 + (H - 1.6) * 0.5)), bevel=0.08)
    box(trim, (W + 0.8, 2.4, 0.65), T((0, 0, H - 0.1)))
    box(wood, (W + 1.2, 2.6, 0.9), T((0, 0, H + 0.6)), bevel=0.1)
    for sx in (-1, 1):
        box(metal, (0.9, 2.2, H - 1.0), T((sx * (W * 0.5), 0, H * 0.5)))

    # 6 columns x 4 rows of star-glyph index tiles — east/right half ominously blacked out!
    for col in range(6):
        cx = -7.5 + col * 3.0
        for row in range(4):
            cz = 2.8 + row * 2.4
            is_blacked = (col >= 3) or (col == 2 and row in (1, 3))
            box(trim if not is_blacked else metal, (2.4, 0.3, 1.9), T((cx, -0.95, cz)))
            if is_blacked:
                # Bolted dark slate blackout plate with cross-bar seal.
                box(alt, (2.05, 0.42, 1.55), T((cx, -1.04, cz)))
                box(metal, (2.2, 0.48, 0.24), T((cx, -1.08, cz)) @ R(0.35, 4, "Y"))
            else:
                # Active glowing star-glyph plate!
                box(alt, (2.0, 0.34, 1.5), T((cx, -0.98, cz)))
                box(glow, (0.32, 0.4, 1.1), T((cx, -1.04, cz)))
                box(glow, (1.1, 0.4, 0.32), T((cx, -1.04, cz)))


# -----------------------------------------------------------------------------------------------------------
# 8. SealPress — Court of Seals heavy Runeguard seal-stamp press & carved Runeguard oath-stones
# -----------------------------------------------------------------------------------------------------------
@template("SealPress", METAL=2400, TRIM=1600, STONE=2200, ALT=1200, WOOD=900, GLOW=600)
def seal_press(t):
    """Court of Seals vignette (seen below the Athenaeum dome in the guide image): a heavy brass-and-iron
    vertical Runeguard rune-seal stamping press with spinning flywheel & star-quill die, flanked by three
    carved standing Runeguard oath-stones inlaid with gold sealing glyphs."""
    metal, trim, stone, alt, wood, glow = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "ALT", "WOOD", "GLOW"))

    # Central heavy brass & iron seal-stamping press.
    box(stone, (5.8, 5.2, 1.0), T((0, 0, 0.5)), bevel=0.1)
    box(metal, (4.8, 4.2, 2.6), T((0, 0, 2.3)), bevel=0.08)
    # Curved C-frame press neck & vertical plunger screw.
    box(metal, (2.0, 1.8, 5.2), T((0, 1.1, 5.8)))
    box(metal, (2.2, 3.6, 1.4), T((0, -0.2, 7.8)))
    cyl_z(trim, 0.48, 4.4, (0, -0.8, 5.2), segs=12)
    # Spinning horizontal brass spoked handwheel atop the press!
    spoked_gear(metal, trim, 2.1, 0.32, 12, T((0, -0.8, 9.6)), spokes=4)
    # Star-quill wax-seal die stamping a glowing gold seal onto a dark slate tablet on the bed.
    box(alt, (3.2, 2.6, 0.35), T((0, -0.6, 3.78)))
    cyl_z(glow, 0.85, 0.22, (0, -0.6, 3.92), segs=12)
    cyl_z(trim, 0.95, 0.45, (0, -0.8, 5.0), segs=12)

    # Three flanking standing Runeguard Oath-Stones (rounded-top monoliths seen in the guide art's Court of Seals!).
    for ox, oy, oh, yaw in ((-5.8, 0.8, 7.2, 0.22), (5.6, 0.6, 8.0, -0.18), (8.2, -1.6, 5.8, -0.4)):
        om = T((ox, oy, 0.0)) @ R(yaw, 4, "Z")
        box(stone, (2.8, 1.3, oh - 1.2), om @ T((0, 0, (oh - 1.2) * 0.5)), bevel=0.15)
        cyl_y(stone, 1.4, 1.25, (om @ Vector((0, 0, oh - 1.2))), segs=12)
        box(alt, (1.8, 1.42, oh * 0.52), om @ T((0, 0, oh * 0.48)))
        box(trim, (0.3, 1.48, oh * 0.38), om @ T((0, 0, oh * 0.5)))


# -----------------------------------------------------------------------------------------------------------
# 9. StarIronAnvil — Seal Forge hooded stone furnace hearth, star-iron anvil & quench trough
# -----------------------------------------------------------------------------------------------------------
@template("StarIronAnvil", STONE=2400, METAL=2400, ALT=1400, TRIM=1200, WOOD=900, GLOW=1200)
def star_iron_anvil(t):
    """Seal Forge smithy vignette (seen directly in the middle-right ward of the guide image!): a domed stone-
    and-chimney rune-seal furnace glowing warm gold inside its arch, paired with a massive horned star-iron
    anvil mounted on a banded oak block, blacksmith tongs, and a stone quench trough."""
    stone, metal, alt, trim, wood, glow = (t.bm(r) for r in ("STONE", "METAL", "ALT", "TRIM", "WOOD", "GLOW"))

    # Domed stone rune-forge hearth & chimney stack on the back-left (-X, +Y).
    fx, fy = -3.8, 1.4
    box(stone, (6.8, 5.6, 3.6), T((fx, fy, 1.8)), bevel=0.16)
    cone(stone, 3.4, 2.1, 4.4, 10, T((fx, fy, 3.6)))
    cone(alt, 1.8, 1.5, 5.6, 10, T((fx, fy, 7.6)))
    ring_mesh(metal, 1.85, 0.25, 14, T((fx, fy, 13.0)), tube_segs=5)
    # Glowing arched firebox mouth facing -Y!
    box(glow, (3.4, 0.8, 2.4), T((fx, fy - 2.65, 2.8)))
    ring_mesh(trim, 1.85, 0.26, 16, T((fx, fy - 2.75, 3.6)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    box(metal, (4.2, 1.4, 0.35), T((fx, fy - 3.1, 1.5)))

    # Horned Star-Iron Anvil mounted on a brass-banded ebony stump in front-right (+X, -Y).
    ax, ay = 3.2, -1.6
    cyl_z(wood, 1.9, 2.6, (ax, ay, 0.0), segs=12)
    ring_mesh(metal, 1.96, 0.16, 14, T((ax, ay, 0.7)), tube_segs=4)
    ring_mesh(metal, 1.96, 0.16, 14, T((ax, ay, 2.1)), tube_segs=4)
    # Heavy sculpted anvil waist, broad flat face & tapered horn.
    box(alt, (3.6, 1.8, 0.7), T((ax, ay, 2.95)))
    box(alt, (2.2, 1.2, 1.2), T((ax, ay, 3.85)))
    box(alt, (4.4, 1.9, 0.95), T((ax, ay, 4.85)), bevel=0.1)
    cone(metal, 0.82, 0.12, 2.4, 8, T((ax + 2.1, ay, 4.95)) @ R(math.pi / 2, 4, "Y"))
    box(trim, (1.4, 1.1, 0.24), T((ax - 0.5, ay, 5.42)))  # Glowing hot rune-seal blank on anvil!
    box(glow, (0.9, 0.7, 0.28), T((ax - 0.5, ay, 5.44)))

    # Stone quench trough beside the forge (+X, +Y).
    box(stone, (4.0, 2.4, 2.2), T((4.2, 2.6, 1.1)), bevel=0.1)
    box(alt, (3.2, 1.6, 0.3), T((4.2, 2.6, 2.05)))


# -----------------------------------------------------------------------------------------------------------
# 10. ShutteredLamp — Floor 44's signature Index Lamp locked tightly behind Runeguard rune-shutter plates
# -----------------------------------------------------------------------------------------------------------
@template("ShutteredLamp", STONE=700, METAL=1600, ALT=1200, TRIM=1200, GLOW=300)
def shuttered_lamp(t):
    """Floor 44's signature Shuttered Index Lamp (Runeguard motif): an Index Lamp standard whose glowing
    lantern head has been boxed tightly inside bolted lapis-and-brass rune-shutter plates so the Rift cannot
    read by it, letting only thin hairline slits of pale gold light leak out. About 13 studs tall."""
    stone, metal, alt, trim, glow = (t.bm(r) for r in ("STONE", "METAL", "ALT", "TRIM", "GLOW"))
    # Stepped fortress stone base & fluted brass post.
    cone(stone, 1.65, 1.4, 0.7, 8, T((0, 0, 0)) @ R(math.pi / 8, 4, "Z"))
    cone(stone, 1.2, 0.9, 1.2, 8, T((0, 0, 0.7)) @ R(math.pi / 8, 4, "Z"))
    lathe(metal, [(0.55, 1.9), (0.32, 3.0), (0.26, 10.6)], 10, Matrix.Identity(4))
    arm_pts = [(0, 0, 10.4), (0, -0.4, 11.6), (0, -1.4, 12.3), (0, -2.2, 11.9), (0, -2.35, 11.3)]
    tube(metal, arm_pts, [0.18, 0.16, 0.15, 0.14, 0.12], 6, cap=True)

    # Shuttered rune-box enclosing the lantern head!
    lm = T((0, -2.35, 9.6))
    ring_mesh(metal, 1.42, 0.14, 18, lm @ R(math.pi / 2, 4, "X"), tube_segs=5)
    # 4 heavy bolted lapis shutter plates boxed tightly round the lantern with thin glowing cracks between them!
    box(glow, (1.1, 1.1, 1.5), lm)
    for k in range(4):
        sm = lm @ R(k * math.pi / 2, 4, "Z")
        box(alt, (1.12, 0.24, 1.62), sm @ T((0, -0.68, 0)))
        box(trim, (1.22, 0.30, 0.18), sm @ T((0, -0.70, 0.62)))
        box(trim, (1.22, 0.30, 0.18), sm @ T((0, -0.70, -0.62)))
    cone(metal, 0.95, 0.2, 0.65, 4, lm @ T((0, 0, 0.85)) @ R(math.pi / 4, 4, "Z"))
    cone(metal, 0.2, 0.9, 0.55, 4, lm @ T((0, 0, -1.4)) @ R(math.pi / 4, 4, "Z"))


# -----------------------------------------------------------------------------------------------------------
# 11. ChainedTomeRack — The Sealed Stacks' caged half-written entry & confiscated books in chains!
# -----------------------------------------------------------------------------------------------------------
@template("ChainedTomeRack", STONE=1400, METAL=2400, TRIM=2000, ALT=1200, SILK=1000, WOOD=900, GLOW=900)
def chained_tome_rack(t):
    """The Sealed Stacks' focal relic (seen standing right inside the Athenaeum dome portico in the guide
    image!): a tall circular brass-barred rune-ring cage resting on a stepped vellum-and-lapis dais, locking
    away the Half-Written Entry (a single glowing open tome on a sealed lectern bound in heavy brass chains
    and flanked by chained confiscated books)."""
    stone, metal, trim, alt, silk, wood, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ALT", "SILK", "WOOD", "GLOW"))

    # Stepped circular relic plinth.
    cone(stone, 5.4, 5.0, 0.8, 16, T((0, 0, 0)))
    cone(alt, 4.4, 4.2, 0.7, 16, T((0, 0, 0.8)))
    ring_mesh(trim, 4.3, 0.18, 20, T((0, 0, 1.5)), tube_segs=5)

    # Central lectern holding the glowing Half-Written Entry!
    lathe(metal, [(1.2, 1.5), (0.55, 3.6), (0.85, 5.0)], 10, Matrix.Identity(4))
    bm = T((0, 0, 5.35)) @ R(math.radians(-18), 4, "X")
    open_tome(alt, silk, trim, bm, w=3.4, d=2.3, page_h=0.55, spread=0.28)
    uvsphere(glow, 0.72, bm @ T((0, 0, 1.25)), 10, 8)

    # Tall circular Runeguard brass-bar containment cage surrounding the lectern (R = 3.8, Z = 1.5..12.8)!
    for rz in (1.7, 6.8, 11.6):
        ring_mesh(metal, 3.8, 0.22, 24, T((0, 0, rz)), tube_segs=5)
    for k in range(12):
        a = 2 * math.pi * k / 12
        strut(metal, (math.cos(a) * 3.8, math.sin(a) * 3.8, 1.5), (math.cos(a) * 3.8, math.sin(a) * 3.8, 11.8), 0.18)
    # Domed brass rune-ring crown over the cage.
    for k in range(4):
        a = k * math.pi / 4
        pts = [(math.cos(a) * math.cos(math.pi * i / 12) * 3.8,
                math.sin(a) * math.cos(math.pi * i / 12) * 3.8,
                11.6 + math.sin(math.pi * i / 12) * 3.4) for i in range(13)]
        tube(trim, pts, [0.18] * len(pts), 5, cap=True)
    cone(trim, 0.45, 0.04, 1.8, 4, T((0, 0, 15.0)))

    # Confiscated chained tomes bound outside the base rim.
    for sx in (-1, 1):
        box(wood, (2.2, 1.7, 1.4), T((sx * 4.8, -1.8, 0.7)) @ R(sx * 0.35, 4, "Z"))
        box(metal, (2.35, 0.28, 1.52), T((sx * 4.8, -1.8, 0.7)) @ R(sx * 0.35, 4, "Z"))


# -----------------------------------------------------------------------------------------------------------
# 12. VaultRingDoor — Forbidden Vault colossal circular geared brass vault door swung half-open!
# -----------------------------------------------------------------------------------------------------------
@template("VaultRingDoor", STONE=3200, ALT=1800, METAL=3400, TRIM=2800, WOOD=1200, GLOW=800)
def vault_ring_door(t):
    """The Forbidden Vault's monumental circular brass vault door (seen swung wide open into the cliffside
    left of the dome in the Floor 44 guide image!): heavy bevelled stone vault surround, recessed dark vaulted
    archway revealing chained book-stacks inside, gilded circular door frame, and a massive 17-stud-diameter
    geared brass vault door swung 75 degrees open on heavy hinges."""
    stone, alt, metal, trim, wood, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "WOOD", "GLOW"))
    cz, R_v = 11.2, 8.8

    # Heavy bevelled stone fortress vault surround & circular recessed dark vault mouth.
    box(stone, (26.0, 6.2, 23.0), T((0, 3.0, 11.5)), bevel=0.35)
    cyl_y(alt, R_v - 0.55, 2.2, (0, -0.4, cz), segs=28)
    # Heavy circular brass & gold portal collar framing the vault mouth.
    m_ring = T((0, -1.6, cz)) @ R(math.pi / 2, 4, "X")
    ring_mesh(metal, R_v, 1.15, 32, m_ring, tube_segs=6)
    ring_mesh(trim, R_v + 1.1, 0.45, 32, m_ring, tube_segs=5)
    # Recessed chained book-crates & glowing ward rune sitting inside the circular vault threshold!
    for bx in (-3.2, 2.6):
        box(wood, (3.2, 2.4, 3.4), T((bx, -1.5, 4.4)) @ R(0.25, 4, "Z"))
        box(metal, (3.4, 0.3, 3.5), T((bx, -1.5, 4.4)) @ R(0.25, 4, "Z"))
    box(glow, (0.55, 0.3, 6.8), T((0, -1.55, cz)))

    # Massive heavy iron hinge pillar on the west (-X) rim!
    hinge_x, hinge_y = -R_v - 0.6, -2.0
    cyl_z(metal, 1.1, 14.0, (hinge_x, hinge_y, cz - 7.0), segs=10)
    for hz in (cz - 4.5, cz + 4.5):
        box(trim, (2.8, 1.8, 1.4), T((hinge_x + 0.8, hinge_y, hz)))

    # THE COLOSSAL CIRCULAR GEARED BRASS VAULT DOOR swung 78 degrees open toward -Y/-X!
    door_pivot = T((hinge_x, hinge_y, cz)) @ R(math.radians(-78), 4, "Z") @ T((R_v + 0.6, 0, 0))
    dm = door_pivot @ R(math.pi / 2, 4, "X")
    # Thick solid brass circular door leaf + locking bolts around rim + central spoked wheel lock!
    cone(metal, R_v - 0.5, R_v - 0.5, 2.0, 28, dm @ T((0, 0, -1.0)))
    ring_mesh(trim, R_v - 0.3, 0.55, 28, dm @ T((0, 0, -1.0)), tube_segs=6)
    ring_mesh(trim, R_v - 0.3, 0.55, 28, dm @ T((0, 0, 1.0)), tube_segs=6)
    # 8 heavy projecting locking pins round the door edge.
    for k in range(8):
        a = 2 * math.pi * k / 8
        box(trim, (1.8, 0.65, 0.65), door_pivot @ R(a, 4, "Y") @ T((R_v, 0, 0)))
    # Central spoked vault combination wheel on both faces.
    spoked_gear(trim, metal, 4.2, 0.65, 16, dm @ T((0, 0, -1.45)), spokes=6)
    spoked_gear(trim, metal, 3.6, 0.55, 14, dm @ T((0, 0, 1.45)), spokes=6)


# -----------------------------------------------------------------------------------------------------------
# 13. LensRack — Reliquary of Lenses display rack of huge ground star-glass lenses (one cracked!)
# -----------------------------------------------------------------------------------------------------------
@template("LensRack", WOOD=1800, METAL=2200, TRIM=1800, CRYSTAL=1800, GLOW=700, STONE=900)
def lens_rack(t):
    """Reliquary of Lenses display vignette (seen in the back-left chamber of the Floor 44 guide image!):
    a tall brass-and-ebony optical rack holding five huge ground star-glass reading lenses (the largest
    central lens dramatically cracked down the middle, echoing the Rift Warden's eye!), flanked by a brass
    calibration astrolabe and lens stool."""
    wood, metal, trim, crystal, glow, stone = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "CRYSTAL", "GLOW", "STONE"))

    # Stepped cabinet base & tall timber-and-brass optical display frame.
    box(stone, (13.6, 4.2, 0.8), T((0, 0, 0.4)), bevel=0.08)
    box(wood, (12.8, 3.4, 2.4), T((0, 0, 2.0)), bevel=0.06)
    for x in (-6.0, 6.0):
        box(wood, (0.8, 1.0, 9.6), T((x, 0, 8.0)))
    box(wood, (13.2, 1.4, 0.8), T((0, 0, 12.8)), bevel=0.06)
    box(trim, (13.5, 1.6, 0.24), T((0, 0, 13.3)))

    # 5 huge ground star-glass lenses mounted in brass gimbal rings (top row 2 large, bottom row 3 medium)!
    lenses = ((-3.2, 9.4, 2.4, False), (3.0, 9.2, 2.7, True), (-4.0, 5.1, 1.5, False), (0.0, 5.1, 1.65, False), (4.0, 5.1, 1.5, False))
    for lx, lz, lr, cracked in lenses:
        lm = T((lx, -0.2, lz)) @ R(math.pi / 2, 4, "X")
        ring_mesh(metal, lr, 0.24, 24, lm, tube_segs=5)
        ring_mesh(trim, lr + 0.22, 0.10, 24, lm, tube_segs=4)
        # Biconvex lens disc (squashed sphere in crystal!).
        uvsphere(crystal, lr * 0.94, T((lx, -0.2, lz)) @ Matrix.Diagonal((1.0, 0.24, 1.0, 1.0)), 16, 10)
        if cracked:
            # Jagged glowing fracture crack bisecting the great lens (echoing the Rift Warden's cracked eye!).
            c_pts = [(lx - 0.5, -0.58, lz + lr * 0.88), (lx + 0.35, -0.62, lz + 0.4),
                     (lx - 0.25, -0.62, lz - 0.6), (lx + 0.65, -0.58, lz - lr * 0.85)]
            tube(glow, c_pts, [0.14, 0.18, 0.16, 0.12], 5, cap=True)
            strut(trim, (lx, -0.2, lz + lr), (lx, -0.2, 12.5), 0.18)

    # Side brass calibration stand & eyepiece on the east (+X).
    ax, ay = 8.4, -1.2
    cone(stone, 1.2, 0.9, 0.6, 8, T((ax, ay, 0)))
    lathe(metal, [(0.42, 0.6), (0.24, 4.2), (0.45, 4.8)], 10, T((ax, ay, 0)))
    ring_mesh(trim, 1.6, 0.12, 18, T((ax, ay, 6.5)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    uvsphere(crystal, 0.8, T((ax, ay, 6.5)) @ Matrix.Diagonal((1.0, 0.25, 1.0, 1.0)), 10, 8)


# -----------------------------------------------------------------------------------------------------------
# 14. SewingFrame — Binders' Yard cord sewing frame & stretched vellum-hide drying frame
# -----------------------------------------------------------------------------------------------------------
@template("SewingFrame", WOOD=1800, SILK=1600, METAL=1200, TRIM=900, ALT=600)
def sewing_frame(t):
    """Binders' Yard craft vignette (seen on the front-right outer ward of the guide image): a standing
    wooden vellum-stretching rack laced with a taut cream vellum hide, paired with a bookbinder's threaded
    cord sewing table clamping fresh signatures."""
    wood, silk, metal, trim, alt = (t.bm(r) for r in ("WOOD", "SILK", "METAL", "TRIM", "ALT"))

    # Standing timber hide-stretching frame on the left (-X).
    fx = -3.4
    for sx in (-2.4, 2.4):
        box(wood, (0.48, 0.48, 7.6), T((fx + sx, 0, 3.8)))
        box(wood, (0.55, 2.4, 0.42), T((fx + sx, 0, 0.21)))
    box(wood, (5.4, 0.48, 0.48), T((fx, 0, 1.4)))
    box(wood, (5.4, 0.48, 0.48), T((fx, 0, 7.2)))
    # Stretched vellum sheet laced to all 4 bars with brass cords!
    box(silk, (3.6, 0.14, 4.4), T((fx, 0, 4.3)))
    for k in range(5):
        z_l = 2.4 + k * 0.95
        strut(trim, (fx - 2.3, 0, z_l), (fx - 1.75, 0, z_l), 0.08)
        strut(trim, (fx + 1.75, 0, z_l), (fx + 2.3, 0, z_l), 0.08)
    for k in range(4):
        x_l = fx - 1.35 + k * 0.9
        strut(trim, (x_l, 0, 1.5), (x_l, 0, 2.15), 0.08)
        strut(trim, (x_l, 0, 6.45), (x_l, 0, 7.1), 0.08)

    # Bookbinder's cord sewing frame on a low worktable on the right (+X).
    tx = 3.2
    for sx in (-2.2, 2.2):
        for sy in (-1.3, 1.3):
            box(wood, (0.42, 0.42, 2.8), T((tx + sx, sy, 1.4)))
    box(wood, (5.2, 3.2, 0.36), T((tx, 0, 2.95)), bevel=0.05)
    # Twin vertical threaded wooden posts & crossbar holding 5 taut sewing cords!
    for sx in (-1.8, 1.8):
        cyl_z(wood, 0.22, 3.2, (tx + sx, -0.8, 3.1), segs=10)
    box(wood, (4.2, 0.45, 0.32), T((tx, -0.8, 6.2)))
    for k in range(5):
        cx = tx - 1.2 + k * 0.6
        strut(trim, (cx, -0.8, 3.2), (cx, -0.8, 6.1), 0.07)
    # Freshly sewn book signature stack resting against the cords.
    box(alt, (3.2, 1.6, 0.55), T((tx, 0.2, 3.4)))
    box(silk, (3.0, 1.45, 0.72), T((tx, 0.2, 4.02)))
    box(metal, (0.35, 1.6, 0.14), T((tx + 2.0, 0.4, 3.2)))


# -----------------------------------------------------------------------------------------------------------
# 15. BookCartLift — Porters' Lodge barred lift-cage with pulley winch, book cart & stacked crates
# -----------------------------------------------------------------------------------------------------------
@template("BookCartLift", METAL=2400, WOOD=2200, TRIM=1200, STONE=900, ALT=800, SILK=700)
def book_cart_lift(t):
    """Porters' Lodge logistics vignette (seen prominently on the front-right yard of the Floor 44 guide
    image!): a tall barred brass-and-iron archive hoist-cage topped with an overhead pulley mast & cable,
    flanked by a four-wheeled wooden book cart loaded with tomes and a neat stack of banded shipping crates."""
    metal, wood, trim, stone, alt, silk = (t.bm(r) for r in ("METAL", "WOOD", "TRIM", "STONE", "ALT", "SILK"))

    # Barred iron-and-brass archive lift-cage (centred at X = -1.5).
    cx = -1.5
    box(stone, (7.6, 7.6, 0.65), T((cx, 0, 0.325)), bevel=0.08)
    box(wood, (6.4, 6.4, 0.45), T((cx, 0, 0.85)))
    box(metal, (6.6, 6.6, 0.55), T((cx, 0, 8.8)))
    # Corner stanchions & vertical cage bars on 3 sides (front -Y half-open!).
    for sx in (-3.1, 3.1):
        for sy in (-3.1, 3.1):
            box(metal, (0.45, 0.45, 8.2), T((cx + sx, sy, 4.8)))
    for k in range(5):
        off = -2.2 + k * 1.1
        strut(metal, (cx + off, 3.1, 1.0), (cx + off, 3.1, 8.7), 0.16)
        strut(metal, (cx - 3.1, off, 1.0), (cx - 3.1, off, 8.7), 0.16)
        strut(metal, (cx + 3.1, off, 1.0), (cx + 3.1, off, 8.7), 0.16)
    # Overhead pulley mast, spoked hoist wheel & vertical lift cable rising to Z = 15.5!
    strut(metal, (cx - 3.1, 0, 8.8), (cx, 0, 12.6), 0.32)
    strut(metal, (cx + 3.1, 0, 8.8), (cx, 0, 12.6), 0.32)
    cyl_z(metal, 0.24, 6.8, (cx, 0, 8.8), segs=10)
    spoked_gear(trim, metal, 1.35, 0.35, 10, T((cx, 0, 12.6)) @ R(math.pi / 2, 4, "X"), spokes=4)
    # Stacked crate inside the lift cage.
    box(wood, (2.6, 2.6, 2.4), T((cx - 0.8, 0.6, 2.25)), bevel=0.06)
    box(metal, (2.7, 2.7, 0.25), T((cx - 0.8, 0.6, 2.25)))

    # Stacked brass-banded archive shipping crates on the east (+X).
    for bx, by, bz, sz, yaw in ((4.8, 1.2, 1.35, 2.7, 0.15), (7.6, 0.6, 1.2, 2.4, -0.25), (5.6, 0.9, 3.8, 2.2, 0.4)):
        cm = T((bx, by, bz)) @ R(yaw, 4, "Z")
        box(wood, (sz, sz, sz), cm, bevel=0.06)
        box(metal, (sz + 0.12, sz + 0.12, 0.24), cm @ T((0, 0, sz * 0.36)))
        box(metal, (sz + 0.12, sz + 0.12, 0.24), cm @ T((0, 0, -sz * 0.36)))

    # Four-wheeled wooden book cart loaded with upright folios in front-right (+X, -Y).
    kx, ky = 4.6, -3.2
    km = T((kx, ky, 0.0)) @ R(-0.32, 4, "Z")
    for sx in (-1.6, 1.6):
        for sy in (-1.0, 1.0):
            cone(metal, 0.62, 0.62, 0.28, 12, km @ T((sx, sy, 0.62)) @ R(math.pi / 2, 4, "X"))
    box(wood, (4.2, 2.2, 0.35), km @ T((0, 0, 1.25)))
    box(wood, (4.2, 0.24, 1.8), km @ T((0, 1.0, 2.15)))
    box(wood, (0.24, 2.2, 1.8), km @ T((-2.0, 0, 2.15)))
    box(wood, (0.24, 2.2, 1.8), km @ T((2.0, 0, 2.15)))
    for b_i in range(4):
        box(alt if b_i % 2 == 0 else trim, (0.75, 1.5, 1.6), km @ T((-1.2 + b_i * 0.82, 0.0, 2.2)))
        box(silk, (0.6, 1.35, 1.4), km @ T((-1.2 + b_i * 0.82, -0.1, 2.2)))


# -----------------------------------------------------------------------------------------------------------
# 16. CopyistAwning — Copyists' Yard sloped vellum canopy awning over a long copying desk & stools
# -----------------------------------------------------------------------------------------------------------
@template("CopyistAwning", WOOD=1800, SILK=2000, TRIM=900, METAL=700, ALT=600)
def copyist_awning(t):
    """Copyists' Yard vignette (seen on the front-left yard of the Floor 44 guide image!): a timber-framed
    sloped vellum-cloth sun awning shading a long ebony copying table stacked with fair copies, open
    manuscripts, brass ink-pots, and three round wooden stools."""
    wood, silk, trim, metal, alt = (t.bm(r) for r in ("WOOD", "SILK", "TRIM", "METAL", "ALT"))

    # Four timber awning posts (taller at back +Y = 8.4, shorter at front -Y = 6.6).
    for sx in (-5.2, 5.2):
        box(wood, (0.52, 0.52, 6.8), T((sx, -3.2, 3.4)))
        box(wood, (0.52, 0.52, 8.6), T((sx, 3.2, 4.3)))
        strut(wood, (sx, -3.4, 6.8), (sx, 3.4, 8.6), 0.36)
    strut(wood, (-5.4, -3.2, 6.8), (5.4, -3.2, 6.8), 0.34)
    strut(wood, (-5.4, 3.2, 8.6), (5.4, 3.2, 8.6), 0.34)

    # Gently draped sloped vellum-cloth canopy with scalloped front valance!
    slope = math.atan2(1.8, 6.4)
    can_m = T((0, 0, 7.85)) @ R(slope, 4, "X")
    box(silk, (11.4, 7.2, 0.22), can_m)
    for k in range(5):
        box(trim, (0.18, 7.25, 0.26), can_m @ T((-4.4 + k * 2.2, 0, 0.04)))
    box(silk, (11.4, 0.16, 1.1), T((0, -3.45, 6.25)))

    # Long copying table underneath with open fair-copy sheets, ink-pots & 3 stools.
    box(wood, (9.2, 3.0, 0.38), T((0, 0.4, 3.0)), bevel=0.05)
    for sx in (-4.0, 4.0):
        for sy in (-1.1, 1.1):
            box(wood, (0.42, 0.42, 2.9), T((sx, 0.4 + sy, 1.45)))
    for tx in (-2.6, 0.2, 2.8):
        box(silk, (1.9, 1.4, 0.12), T((tx, 0.4, 3.25)) @ R(0.08 * tx, 4, "Z"))
        cyl_z(metal, 0.24, 0.42, (tx + 1.1, 1.1, 3.18), segs=8)
    box(alt, (1.6, 1.2, 0.75), T((-3.8, 0.9, 3.55)))
    for sx in (-2.8, 0.0, 2.8):
        cyl_z(wood, 0.85, 0.26, (sx, -1.9, 1.85), segs=10)
        cyl_z(wood, 0.24, 1.85, (sx, -1.9, 0.0), segs=8)


# -----------------------------------------------------------------------------------------------------------
# 17. WardedCirclePad — Warded Court inlaid concentric Runeguard warding circle (flush ground decal mesh)
# -----------------------------------------------------------------------------------------------------------
@template("WardedCirclePad", ALT=1400, TRIM=1800, GLOW=1600, STONE=900)
def warded_circle_pad(t):
    """Warded Court's inlaid concentric Runeguard warding circle (seen glowing softly in front of the West
    Waygate in the Floor 44 guide image): low nearly-flush dark slate floor medallion (24 diameter, 0.35 tall
    so combat telegraphs stay clean!) inlaid with nested brass & pale-gold starlight warding rings and four
    cardinal satellite rune-circles."""
    alt, trim, glow, stone = (t.bm(r) for r in ("ALT", "TRIM", "GLOW", "STONE"))
    R_main = 11.4

    # Nearly flush bevelled stone & dark slate disc standing cleanly on z = 0..0.28.
    cyl_z(stone, R_main + 0.6, 0.18, (0, 0, 0.0), segs=32)
    cyl_z(alt, R_main, 0.22, (0, 0, 0.04), segs=32)
    # Concentric gilded & glowing warding rings.
    for r_r, th, bm in ((R_main - 0.4, 0.16, trim), (R_main * 0.76, 0.14, glow), (R_main * 0.44, 0.15, trim), (R_main * 0.24, 0.12, glow)):
        ring_mesh(bm, r_r, th, 32, T((0, 0, 0.28)), tube_segs=4)
    # Four intercardinal satellite rune-circles tangent to the outer ring (exact pattern from the guide art!).
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        sx, sy = math.cos(a) * (R_main * 0.86), math.sin(a) * (R_main * 0.86)
        cyl_z(alt, 2.3, 0.24, (sx, sy, 0.04), segs=18)
        ring_mesh(glow, 2.1, 0.14, 20, T((sx, sy, 0.30)), tube_segs=4)
        ring_mesh(trim, 1.4, 0.09, 16, T((sx, sy, 0.30)), tube_segs=4)
    # Radial star-spokes connecting the rings.
    for k in range(8):
        a = 2 * math.pi * k / 8
        strut(trim, (math.cos(a) * R_main * 0.26, math.sin(a) * R_main * 0.26, 0.27),
              (math.cos(a) * R_main * 0.74, math.sin(a) * R_main * 0.74, 0.27), 0.14)


if __name__ == "__main__":
    kit, manifest = build_kit("AstralF44Kit", F44_TEMPLATES, DEFAULT_BUDGET)
    apply_halcyr_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AstralF44Kit")
    render_previews(kit, F44_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
