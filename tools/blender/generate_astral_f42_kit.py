"""
Astral Archives Floor 42 (Orbiting Stacks) sculpted assets, generated in headless Blender.

Inspired by the Orbiting Stacks reference art (reference/Astral Archives 42.jpg) and the Halcyr
orrery-index ecosystem (docs/prompts/astral-archives-floor-layouts-prompt.md):
a working brass orrery built around the central Sun-Lectern. High overhead, concentric toothed brass
orbit rails sweep around the room; below, the Orrery Gate frames the arrival with miniature planets on
brass wires flanked by half-sunk drive ring-gears in the Orrery Plinth; Perihelion Court's engraved
brass sundial looks across open void at the Sun-Lectern; brass moon-phase medallions mark Folio Moon
and Codex Moon; orrery-arm conjunction bridges with hanging brass counterweights swing inward to
Lexicon and Concordance's curved lectern rows; Folio and Codex carry sweeping semicircular ring
bookcases and banded department planet masts; Atlas holds a grand meridian globe stand and map-chests;
Almanac displays brass-framed star-table slates; Glossary and Marginalia stack wooden annotation slips
and folios; the frosted Aphelion aims a lone brass refractor telescope out into the Starfield; and
interlocking clockwork gears sheath the floating slate undersides beneath the planets.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands on its origin.

Roles (AstralFloor42 passes the Halcyr override; no new colour roles):
    STONE    pale vellum-white stone         ALT      deep lapis-indigo marble / dark slate
    TRIM     worn gold leaf & inlay          METAL    warm aged brass
    WOOD     ebony shelving & chests         SILK     vellum pages & star-scrolls
    GLOW     pale starlight / sun gold       CRYSTAL  star-glass & Aphelion frost
    MOSS     star-moss / patina accents

Outputs (assets-source/tower/astral_f42_kit/):
    AstralF42Kit.blend, AstralF42Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_astral_f42_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "astral_f42_kit")

# Reuse shared primitives, Halcyr motifs, and pipeline from Floor 41 / Floor 21 / Floor 26.
f41 = runpy.run_path(os.path.join(HERE, "generate_astral_f41_kit.py"))
box = f41["box"]
cone = f41["cone"]
uvsphere = f41["uvsphere"]
tube = f41["tube"]
ring_mesh = f41["ring_mesh"]
lathe = f41["lathe"]
cyl_x, cyl_y, cyl_z, strut = f41["cyl_x"], f41["cyl_y"], f41["cyl_z"], f41["strut"]
ground_rock, slab_stone = f41["ground_rock"], f41["slab_stone"]
build_kit, export_kit, render_previews = f41["build_kit"], f41["export_kit"], f41["render_previews"]
open_tome, star_quill_sigil = f41["open_tome"], f41["star_quill_sigil"]
crystal_spike_cluster, balustrade_post = f41["crystal_spike_cluster"], f41["balustrade_post"]
apply_halcyr_preview_materials = f41["apply_halcyr_preview_materials"]

T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F42_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F42_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# Shared Floor 42 Orrery helpers: spoked gears, banded planets, arched ribs
# -----------------------------------------------------------------------------------------------------------
def spoked_gear(metal, trim, r, thick, teeth, mat, spokes=6, hub_r=None):
    """A toothed brass cogwheel in the local XY plane centred on mat."""
    hr = hub_r if hub_r is not None else r * 0.24
    ring_mesh(metal, r * 0.86, max(0.18, r * 0.11), max(18, teeth), mat, tube_segs=6)
    ring_mesh(trim, r * 0.72, max(0.10, r * 0.04), max(16, teeth), mat, tube_segs=4)
    # Central hub.
    cone(metal, hr, hr, thick * 1.35, 12, mat @ T((0, 0, -thick * 0.675)))
    cone(trim, hr * 0.55, hr * 0.55, thick * 1.65, 10, mat @ T((0, 0, -thick * 0.825)))
    # Spokes.
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        strut(metal, mat @ Vector((math.cos(a) * hr * 0.8, math.sin(a) * hr * 0.8, 0)),
              mat @ Vector((math.cos(a) * r * 0.82, math.sin(a) * r * 0.82, 0)), max(0.22, r * 0.08))
    # Gear teeth around the rim.
    tooth_w = (2 * math.pi * r / teeth) * 0.46
    tooth_len = max(0.35, r * 0.14)
    for k in range(teeth):
        a = 2 * math.pi * k / teeth
        bm_t = trim if k % 2 == 0 else metal
        box(bm_t, (tooth_len, tooth_w, thick), mat @ R(a, 4, "Z") @ T((r * 0.96 + tooth_len * 0.35, 0, 0)))


def banded_planet(body_bm, band_bm, ring_bm, centre, radius, has_ring=True, ring_tilt=0.35, moons=0):
    """A Halcyr department planet globe with equatorial latitude bands and optional tilted brass ring."""
    c = Vector(centre)
    uvsphere(body_bm, radius, T(c), 16, 12)
    # Sculpted raised equatorial & tropic bands so each planet reads clearly from afar.
    ring_mesh(band_bm, radius * 1.01, radius * 0.08, 22, T(c), tube_segs=5)
    ring_mesh(band_bm, radius * 0.88, radius * 0.05, 18, T((c.x, c.y, c.z + radius * 0.46)), tube_segs=4)
    ring_mesh(band_bm, radius * 0.88, radius * 0.05, 18, T((c.x, c.y, c.z - radius * 0.46)), tube_segs=4)
    if has_ring:
        rm = T(c) @ R(ring_tilt, 4, "X") @ R(0.25, 4, "Y")
        ring_mesh(ring_bm, radius * 1.55, radius * 0.08, 28, rm, tube_segs=5)
        ring_mesh(band_bm, radius * 1.82, radius * 0.045, 28, rm, tube_segs=4)
    for k in range(moons):
        a = k * math.pi + 0.6
        mx = c.x + math.cos(a) * radius * 2.15
        my = c.y + math.sin(a) * radius * 2.15
        mz = c.z + (0.35 if k % 2 == 0 else -0.35) * radius
        strut(ring_bm, c, (mx, my, mz), max(0.08, radius * 0.04))
        uvsphere(band_bm, radius * 0.24, T((mx, my, mz)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 1. SunLecternGlobe — The central Sun-Lectern pedestal & radiant golden sun globe on the Apex dais
# -----------------------------------------------------------------------------------------------------------
@template("SunLecternGlobe", STONE=2400, ALT=1400, METAL=3200, TRIM=2800, GLOW=2200, CRYSTAL=1200, SILK=600)
def sun_lectern_globe(t):
    """The Sun-Lectern at the heart of the Apex: a stepped circular vellum-and-lapis lectern dais rimmed with
    brass compass-degree rings, four curved brass solar cradle struts, a master-index lectern desk facing -Y,
    and a blazing 16-stud-diameter pale-gold Sun Globe encircled by nested brass solar corona rings.
    About 38 studs tall, compact 24x24 footprint."""
    stone, alt, metal, trim, glow, crystal, silk = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "GLOW", "CRYSTAL", "SILK"))

    # Stepped circular dais plinth with lapis-indigo compass disc & brass degree collar.
    cone(stone, 12.2, 11.6, 1.4, 24, T((0, 0, 0)))
    cone(alt, 10.6, 10.2, 1.2, 24, T((0, 0, 1.4)))
    ring_mesh(trim, 10.6, 0.28, 28, T((0, 0, 2.6)), tube_segs=5)
    cone(stone, 8.2, 7.2, 2.4, 20, T((0, 0, 2.6)))
    ring_mesh(metal, 7.6, 0.32, 24, T((0, 0, 5.0)), tube_segs=6)

    # Turned brass central solar pedestal & 4 sweeping curved cradle arms rising to cup the Sun Globe.
    lathe(metal, [(4.2, 5.0), (2.4, 7.2), (1.9, 11.0), (3.4, 13.4), (5.2, 14.8)], 16, Matrix.Identity(4))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        pts = [
            (math.cos(a) * 6.8, math.sin(a) * 6.8, 5.0),
            (math.cos(a) * 8.2, math.sin(a) * 8.2, 11.5),
            (math.cos(a) * 9.8, math.sin(a) * 9.8, 18.5),
            (math.cos(a) * 10.6, math.sin(a) * 10.6, 25.0),
        ]
        tube(metal, pts, [0.55, 0.48, 0.42, 0.34], 6, cap=True)
        uvsphere(trim, 0.62, T(pts[-1]), 8, 6)

    # The radiant Sun Globe (centred at Z = 25.5, radius 7.4) — exposed pale-gold GLOW orb framed by star-glass halo ring!
    cz = 25.5
    uvsphere(glow, 7.2, T((0, 0, cz)), 20, 14)
    ring_mesh(crystal, 8.3, 0.32, 28, T((0, 0, cz)) @ R(math.radians(-14), 4, "Y"), tube_segs=5)
    # Three tilted solar corona armillary rings hugging the Sun Globe.
    ring_mesh(trim, 9.4, 0.35, 32, T((0, 0, cz)) @ R(math.radians(18), 4, "X"), tube_segs=6)
    ring_mesh(metal, 10.8, 0.38, 32, T((0, 0, cz)) @ R(math.radians(78), 4, "X") @ R(0.4, 4, "Z"), tube_segs=6)
    ring_mesh(trim, 11.8, 0.28, 32, T((0, 0, cz)) @ R(math.radians(-68), 4, "Y"), tube_segs=5)
    # 12 pointed gold solar flare finials around the outer equatorial corona.
    for k in range(12):
        a = 2 * math.pi * k / 12
        fm = T((0, 0, cz)) @ R(a, 4, "Z") @ R(math.pi / 2, 4, "Y") @ T((0, 0, 9.4))
        cone(trim, 0.52, 0.05, 2.4 if k % 2 == 0 else 1.5, 4, fm)

    # Master-Index lectern desk mounted at the front (-Y) of the dais, holding the open master catalogue.
    lx, ly = 0.0, -9.2
    lathe(metal, [(1.1, 2.6), (0.55, 5.0), (0.75, 6.8)], 10, T((lx, ly, 0)))
    lm = T((lx, ly, 7.1)) @ R(math.radians(-26), 4, "X")
    box(trim, (4.2, 2.8, 0.28), lm)
    open_tome(alt, silk, trim, lm @ T((0, 0, 0.24)), w=3.6, d=2.4, page_h=0.55, spread=0.25)


# -----------------------------------------------------------------------------------------------------------
# 2. ArmillarySphereTall — Monumental 156-stud Sun-Lectern armillary canopy (Floor 42's ≥150 stud landmark)
# -----------------------------------------------------------------------------------------------------------
@template("ArmillarySphereTall", STONE=3600, ALT=1800, METAL=6200, TRIM=4800, GLOW=1800, CRYSTAL=1200)
def armillary_sphere_tall(t):
    """The Sun-Lectern's colossal soaring armillary sphere (156 studs tall at scale 1, clearing the 150-stud
    escalation target): four tall perimeter vellum-and-brass colonnade piers standing on a 66-stud ring
    (leaving the central arena completely unobstructed below Z = 26!), supporting an equatorial brass gallery
    ring and four monumental tilted interlocking armillary rings crowning a high zenith sun-beacon."""
    stone, alt, metal, trim, glow, crystal = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "GLOW", "CRYSTAL"))
    pier_r = 32.0
    gallery_z = 30.0
    sphere_cz = 88.0
    sphere_r = 54.0

    # Four monumental corner/cardinal piers standing outside the arena footprint (at r = 32, clear walk inside!).
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        px, py = math.cos(a) * pier_r, math.sin(a) * pier_r
        pm = T((px, py, 0.0)) @ R(a, 4, "Z")
        # Stepped vellum-and-lapis pier footing.
        cone(stone, 5.2, 4.6, 3.2, 8, pm)
        cone(alt, 4.2, 3.8, 2.4, 8, pm @ T((0, 0, 3.2)))
        # Tall fluted stone & brass shaft rising to gallery_z (30 studs, well above 18-stud clearance!).
        cone(stone, 3.4, 2.8, gallery_z - 5.6, 8, pm @ T((0, 0, 5.6)))
        ring_mesh(trim, 3.6, 0.38, 12, pm @ T((0, 0, 16.0)), tube_segs=5)
        cone(metal, 3.8, 4.4, 2.4, 8, pm @ T((0, 0, gallery_z - 1.2)))
        # Curved brass cradle buttress sweeping upward from pier top into the great equatorial ring.
        pts = [
            (px, py, gallery_z + 1.0),
            (math.cos(a) * 42.0, math.sin(a) * 42.0, 52.0),
            (math.cos(a) * (sphere_r + 1.5), math.sin(a) * (sphere_r + 1.5), sphere_cz),
        ]
        tube(metal, pts, [1.5, 1.35, 1.2], 6, cap=True)
        # Gold trim spine along each buttress.
        pts_o = [(p[0] * 1.03, p[1] * 1.03, p[2]) for p in pts]
        tube(trim, pts_o, [0.45, 0.42, 0.38], 4, cap=True)

    # Lower brass collar ring tying the 4 piers together at Z = 31 (well clear of the 18-stud overhead rule).
    ring_mesh(metal, pier_r, 1.1, 36, T((0, 0, gallery_z + 1.0)), tube_segs=6)
    ring_mesh(trim, pier_r + 1.1, 0.42, 36, T((0, 0, gallery_z + 1.0)), tube_segs=4)

    # Colossal interlocking armillary rings centred at Z = 88 (top crest reaches Z = 144 + zenith finial = 156!).
    ring_specs = (
        # Horizontal grand equatorial belt (wide double rail with gold degree ticks).
        (sphere_r, 1.85, (0.0, 0.0, 0.0), metal),
        (sphere_r + 2.0, 0.65, (0.0, 0.0, 0.0), trim),
        # Twin towering vertical meridian rings (N-S and E-W).
        (sphere_r, 1.75, (math.pi / 2, 0.0, 0.0), metal),
        (sphere_r - 1.4, 0.6, (math.pi / 2, 0.0, 0.0), trim),
        (sphere_r * 0.96, 1.65, (math.pi / 2, 0.0, math.pi / 2), metal),
        # Sweeping tilted ecliptic band (23.5 deg) with raised star-glyph tablets.
        (sphere_r * 0.88, 1.55, (math.radians(24), math.radians(16), 0.35), trim),
        # Counter-tilted inner colure ring.
        (sphere_r * 0.72, 1.25, (math.radians(-38), math.radians(42), 1.1), metal),
    )
    for r, th, rot, bm in ring_specs:
        m = T((0, 0, sphere_cz)) @ R(rot[2], 4, "Z") @ R(rot[1], 4, "Y") @ R(rot[0], 4, "X")
        ring_mesh(bm, r, th, 44, m, tube_segs=6)

    # Raised zodiac/star-glyph medallions along the tilted ecliptic band.
    ec_m = T((0, 0, sphere_cz)) @ R(0.35, 4, "Z") @ R(math.radians(16), 4, "Y") @ R(math.radians(24), 4, "X")
    for k in range(12):
        a = 2 * math.pi * k / 12
        gm = ec_m @ R(a, 4, "Z") @ T((sphere_r * 0.88, 0, 0))
        box(alt, (1.2, 4.8, 3.6), gm)
        box(glow, (1.5, 1.6, 1.6), gm @ R(math.pi / 4, 4, "X"))

    # High radiant Sun-Core suspended at the very heart of the colossal armillary (Z = 88) — exposed GLOW orb + crystal corona!
    uvsphere(glow, 12.4, T((0, 0, sphere_cz)), 20, 14)
    ring_mesh(crystal, 14.8, 0.55, 32, T((0, 0, sphere_cz)) @ R(math.radians(18), 4, "X"), tube_segs=5)
    ring_mesh(crystal, 14.8, 0.55, 32, T((0, 0, sphere_cz)) @ R(math.radians(-72), 4, "Y"), tube_segs=5)
    # Zenith star-quill spire rising from top of the outer meridian ring (Z = 142..156).
    cone(metal, 2.2, 0.25, 13.5, 8, T((0, 0, sphere_cz + sphere_r + 0.5)))
    uvsphere(glow, 2.0, T((0, 0, sphere_cz + sphere_r + 12.5)), 10, 8)
    ring_mesh(trim, 4.4, 0.45, 20, T((0, 0, sphere_cz + sphere_r + 6.5)) @ R(math.pi / 2, 4, "X"), tube_segs=5)


# -----------------------------------------------------------------------------------------------------------
# 3. OrbitRailSegment — Curved toothed brass orbit rail arc with meshed spur gear (skyline/perimeter rings)
# -----------------------------------------------------------------------------------------------------------
@template("OrbitRailSegment", METAL=2400, TRIM=2200, ALT=400, GLOW=400)
def orbit_rail_segment(t):
    """A 48-stud-long curved toothed brass orbit rail arc (curving along a ~160-stud radius) with twin
    flanged brass rails, continuous inner gear-track teeth, cross-ties, and a horizontal brass spur gear
    meshed onto its outer edge (seen sweeping around the Floor 42 skyline in the guide image)."""
    metal, trim, alt, glow = (t.bm(r) for r in ("METAL", "TRIM", "ALT", "GLOW"))
    R_arc = 150.0
    span_deg = 18.4
    segs = 24
    # Arc centred so the chord midpoint rests at X = 0, Y = 0, standing on Z = 0..4.2.
    r_inner, r_outer = R_arc - 2.2, R_arc + 2.2

    for r_r, th, z_off, bm in (
        (r_inner, 0.55, 2.2, metal), (r_outer, 0.55, 2.2, metal),
        (r_inner, 0.35, 3.6, trim), (r_outer, 0.35, 3.6, trim),
        (r_inner, 0.35, 0.7, metal), (r_outer, 0.35, 0.7, metal),
    ):
        pts = []
        for k in range(segs + 1):
            a = math.radians(-span_deg / 2 + span_deg * k / segs)
            pts.append((math.sin(a) * r_r, (math.cos(a) - 1.0) * r_r, z_off))
        tube(bm, pts, [th] * len(pts), 6, cap=True)

    # Cross-ties & continuous toothed gear-rack along the inner & bottom rails.
    for k in range(segs):
        a = math.radians(-span_deg / 2 + span_deg * (k + 0.5) / segs)
        cx = math.sin(a) * R_arc
        cy = (math.cos(a) - 1.0) * R_arc
        m = T((cx, cy, 2.2)) @ R(-a, 4, "Z")
        if k % 2 == 0:
            box(alt, (0.9, 4.2, 2.4), m)
            box(trim, (1.1, 4.4, 0.35), m @ T((0, 0, 1.35)))
        # Crisp downward & inward gear teeth so the rail reads as a mechanical track from below!
        box(trim, (0.85, 1.0, 1.1), m @ T((0, -2.55, 0.0)))
        box(metal, (0.85, 1.2, 0.9), m @ T((0, 0.0, -1.75)))

    # Horizontal brass spur gear meshed into the back (+Y) outer track off-centre.
    ga = math.radians(3.5)
    gx = math.sin(ga) * (R_arc + 6.4)
    gy = (math.cos(ga) - 1.0) * (R_arc + 6.4) + 6.4
    spoked_gear(metal, trim, 4.8, 1.1, 14, T((gx, gy, 2.2)), spokes=5)
    uvsphere(glow, 0.75, T((gx, gy, 3.4)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 4. OrreryArmBridge — Conjunction brass orrery-arm bridge with star-glass deck & counterweight pendulum
# -----------------------------------------------------------------------------------------------------------
@template("OrreryArmBridge", METAL=2800, TRIM=2200, CRYSTAL=900, STONE=900, GLOW=900, ALT=600)
def orrery_arm_bridge(t):
    """Floor 42's new traversal feature: a 26-stud-long brass orrery-arm conjunction bridge with a recessed
    translucent star-glass walkway, side gear-guard rails outside usable width, pivot collar at the near end,
    and a sculpted brass counterweight pendulum orb slung underneath its outer end."""
    metal, trim, crystal, stone, glow, alt = (t.bm(r) for r in ("METAL", "TRIM", "CRYSTAL", "STONE", "GLOW", "ALT"))
    L, W, deck_z = 26.0, 13.0, 4.8

    # Lower brass counterweight pendulum & pivot cradle (bottom orb sits cleanly at z = 0.0!).
    cw_y = -L * 0.36
    uvsphere(metal, 1.85, T((0, cw_y, 1.85)), 14, 10)
    ring_mesh(trim, 2.15, 0.22, 18, T((0, cw_y, 1.85)), tube_segs=5)
    ring_mesh(trim, 2.15, 0.18, 18, T((0, cw_y, 1.85)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    # Twin diagonal brass pendulum struts up to the bridge spine.
    for sx in (-1, 1):
        strut(metal, (sx * 1.4, cw_y, 2.8), (sx * 4.4, cw_y + 2.8, deck_z - 0.5), 0.42)
        strut(metal, (sx * 1.4, cw_y, 2.8), (sx * 4.4, cw_y - 2.8, deck_z - 0.5), 0.42)

    # Main heavy brass girder side-beams & arched underside truss.
    for sx in (-1, 1):
        rx = sx * (W * 0.45)
        box(metal, (0.95, L, 0.95), T((rx, 0, deck_z - 0.35)))
        box(trim, (1.1, L, 0.25), T((rx, 0, deck_z + 0.22)))
        # Mechanical gear-pivots mounted at both ends of each rail.
        for sy in (-1, 1):
            spoked_gear(metal, trim, 1.45, 0.45, 10, T((rx + sx * 0.55, sy * (L * 0.42), deck_z + 0.2)) @ R(math.pi / 2, 4, "Y"), spokes=4)
        # Sleek open brass handrails (outside clear 10.5-stud lane).
        strut(trim, (rx, -L * 0.46, deck_z + 3.1), (rx, L * 0.46, deck_z + 3.1), 0.28)
        strut(metal, (rx, -L * 0.46, deck_z + 1.65), (rx, L * 0.46, deck_z + 1.65), 0.18)
        for k in range(6):
            py = -L * 0.44 + k * (L * 0.88 / 5)
            strut(metal, (rx, py, deck_z + 0.2), (rx, py, deck_z + 3.2), 0.26)
            if k in (0, 5):
                uvsphere(glow, 0.42, T((rx, py, deck_z + 3.65)), 8, 6)

    # Transverse cross-beams, translucent star-glass deck & glowing brass alignment rail down centre.
    for k in range(7):
        py = -L * 0.45 + k * (L * 0.9 / 6)
        box(metal, (W * 0.9, 0.55, 0.5), T((0, py, deck_z - 0.45)))
    box(crystal, (W - 2.0, L - 0.6, 0.36), T((0, 0, deck_z + 0.08)))
    box(glow, (0.35, L - 1.6, 0.14), T((0, 0, deck_z + 0.24)))
    # Lapis & gold end thresholds.
    for sy in (-1, 1):
        box(alt, (W - 1.6, 1.6, 0.48), T((0, sy * (L * 0.46), deck_z + 0.1)))
        box(stone, (W * 0.96, 0.9, 0.55), T((0, sy * (L * 0.49), deck_z + 0.14)))


# -----------------------------------------------------------------------------------------------------------
# 5. PlanetGlobe — Tall brass department mast crowned by a banded/ringed planet globe
# -----------------------------------------------------------------------------------------------------------
@template("PlanetGlobe", STONE=1000, ALT=1600, METAL=1800, TRIM=1600, CRYSTAL=800, GLOW=600)
def planet_globe(t):
    """A Halcyr department planet globe on a tall turned brass mast (seen crowning Folio, Codex, Atlas,
    Almanac and Aphelion in the guide image): stepped lapis-and-vellum pedestal, fluted brass mast with
    meridian gimbal cradle, banded ringed planet globe, and twin orbiting mini-moons. About 24 studs tall."""
    stone, alt, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "CRYSTAL", "GLOW"))
    # Stepped octagonal pedestal.
    cone(stone, 3.6, 3.3, 1.0, 12, T((0, 0, 0)))
    cone(alt, 2.9, 2.6, 0.9, 12, T((0, 0, 1.0)))
    ring_mesh(trim, 2.8, 0.18, 16, T((0, 0, 1.9)), tube_segs=5)
    # Tall slender turned brass department mast rising to Z = 15.2.
    lathe(metal, [(1.6, 1.9), (0.85, 3.4), (0.62, 10.0), (0.95, 10.6), (0.55, 11.2), (0.52, 14.8), (1.15, 15.6)], 12, Matrix.Identity(4))
    # Crescent brass meridian cradle around the planet (centred at Z = 19.6, R = 3.2).
    cz, pr = 19.6, 3.2
    pts = []
    for k in range(15):
        a = math.radians(-160) + math.radians(140) * k / 14
        pts.append((math.cos(a) * (pr + 0.95), 0.0, cz + math.sin(a) * (pr + 0.95)))
    tube(metal, pts, [0.24] * len(pts), 6, cap=True)
    # Banded ringed planet globe + 2 tiny orbiting moons + polar star finial.
    banded_planet(alt, trim, metal, (0, 0, cz), pr, has_ring=True, ring_tilt=0.38, moons=2)
    cone(trim, 0.36, 0.03, 1.8, 4, T((0, 0, cz + pr + 0.2)))
    uvsphere(glow, 0.45, T((0, 0, cz + pr + 1.8)), 8, 6)
    ring_mesh(crystal, pr * 1.68, 0.09, 24, T((0, 0, cz)) @ R(0.38, 4, "X") @ R(0.25, 4, "Y"), tube_segs=4)


# -----------------------------------------------------------------------------------------------------------
# 6. RingBookcase — Sweeping 4-bay semicircular ebony ring bookcase (Folio & Codex galleries)
# -----------------------------------------------------------------------------------------------------------
@template("RingBookcase", WOOD=3800, STONE=1100, TRIM=2400, METAL=1400, ALT=1400, SILK=1400)
def ring_bookcase(t):
    """Folio and Codex's semicircular outer-edge ring bookcase (seen curving cleanly around the outer arc
    of both side galleries in the guide image): 4 curved ebony bays forming an ~88-degree arc, packed with
    varied tomes, vellum-stone base, brass gearwork side finials, and gold cornice."""
    wood, stone, trim, metal, alt, silk = (t.bm(r) for r in ("WOOD", "STONE", "TRIM", "METAL", "ALT", "SILK"))
    rng = random.Random(4206)
    arc_r = 18.0
    bay_angles = (-math.radians(33), -math.radians(11), math.radians(11), math.radians(33))
    bay_w, bay_d, bay_h = 6.4, 2.8, 11.4

    for b_idx, ang in enumerate(bay_angles):
        cx = math.sin(ang) * arc_r
        cy = (math.cos(ang) - 1.0) * arc_r
        bm_mat = T((cx, cy, 0.0)) @ R(-ang, 4, "Z")

        box(stone, (bay_w + 0.35, bay_d + 0.45, 0.95), bm_mat @ T((0, 0, 0.475)), bevel=0.06)
        box(wood, (bay_w, 0.48, bay_h), bm_mat @ T((0, bay_d * 0.42, 0.95 + bay_h * 0.5)))
        box(wood, (bay_w + 0.4, bay_d + 0.5, 0.72), bm_mat @ T((0, 0, bay_h + 1.0)), bevel=0.06)
        box(trim, (bay_w + 0.55, bay_d + 0.6, 0.24), bm_mat @ T((0, 0, bay_h + 1.45)))
        for sx in (-1, 1):
            box(wood, (0.62, bay_d + 0.14, bay_h), bm_mat @ T((sx * (bay_w * 0.48), 0, 0.95 + bay_h * 0.5)))
            box(trim, (0.76, bay_d + 0.26, 0.48), bm_mat @ T((sx * (bay_w * 0.48), 0, bay_h + 0.5)))

        for s_i in range(4):
            sz = 1.25 + s_i * 2.65
            box(wood, (bay_w - 0.55, bay_d - 0.2, 0.28), bm_mat @ T((0, -0.1, sz)))
            x_cur = -bay_w * 0.41
            while x_cur < bay_w * 0.36:
                bw = rng.uniform(0.55, 1.05)
                bh = rng.uniform(1.45, 2.1)
                bd = rng.uniform(1.4, 1.9)
                tilt = rng.uniform(-0.14, 0.14) if rng.random() < 0.22 else 0.0
                role_bm = (alt, trim, silk, wood)[(b_idx + s_i + int((x_cur + 5) * 3)) % 4]
                box(role_bm, (bw, bd, bh), bm_mat @ T((x_cur + bw * 0.5, -0.15, sz + 0.14 + bh * 0.5)) @ R(tilt, 4, "Y"))
                x_cur += bw + 0.12

    # Sweeping brass cornice rail & end clockwork scroll caps.
    rail_pts = []
    for k in range(17):
        a = -math.radians(44) + math.radians(88) * k / 16
        rail_pts.append((math.sin(a) * (arc_r - 1.5), (math.cos(a) - 1.0) * (arc_r - 1.5) - 1.5, bay_h + 1.55))
    tube(metal, rail_pts, [0.22] * len(rail_pts), 6, cap=True)
    for end_ang in (-math.radians(44), math.radians(44)):
        ex = math.sin(end_ang) * arc_r
        ey = (math.cos(end_ang) - 1.0) * arc_r
        em = T((ex, ey, 0)) @ R(-end_ang, 4, "Z")
        box(stone, (1.4, 3.4, 12.2), em @ T((0, 0, 6.1)), bevel=0.1)
        uvsphere(trim, 0.72, em @ T((0, 0, 12.85)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 7. MoonPhaseDisc — Engraved brass lunar-phase medallion (Folio Moon & Codex Moon)
# -----------------------------------------------------------------------------------------------------------
@template("MoonPhaseDisc", METAL=2400, TRIM=2200, ALT=1200, GLOW=900, STONE=700)
def moon_phase_disc(t):
    """Folio Moon and Codex Moon's engraved brass moon-phase medallion (seen flanking Perihelion Court in
    the guide image): a 12-stud-diameter geared brass ring on a stepped cradle foot, framing a lapis-indigo
    lunar dial with sculpted waxing/waning crescent relief and 8 orbital phase moons around the rim."""
    metal, trim, alt, glow, stone = (t.bm(r) for r in ("METAL", "TRIM", "ALT", "GLOW", "STONE"))
    cz, R_disc = 7.2, 5.4

    # Low stepped vellum-and-brass cradle base so it stands cleanly on z = 0.
    box(stone, (6.4, 3.4, 1.0), T((0, 0, 0.5)), bevel=0.1)
    box(metal, (5.2, 2.4, 0.9), T((0, 0, 1.45)))
    # Vertical brass medallion rim & lapis backing plate (faces -Y front & +Y back).
    m_face = T((0, 0, cz)) @ R(math.pi / 2, 4, "X")
    ring_mesh(metal, R_disc, 0.55, 32, m_face, tube_segs=6)
    ring_mesh(trim, R_disc + 0.58, 0.24, 32, m_face, tube_segs=5)
    cyl_y(alt, R_disc - 0.35, 0.65, (0, 0, cz), segs=28)

    # Sculpted raised glowing lunar crescent on both faces (offset overlapping discs!).
    for sy in (-1, 1):
        # Bright waxing crescent arc built from thick curved tube.
        c_pts = []
        for k in range(15):
            a = math.radians(-115) + math.radians(230) * k / 14
            rr = 3.2
            th = 0.95 * math.sin(math.pi * k / 14) + 0.14
            c_pts.append((math.cos(a) * rr - 0.5, sy * 0.42, cz + math.sin(a) * rr))
        tube(glow, c_pts, [0.85 * math.sin(math.pi * k / 14) + 0.12 for k in range(15)], 6, cap=True)
        # 8 small lunar phase beads inlaid in a ring around the dial edge.
        for k in range(8):
            a = 2 * math.pi * k / 8
            bx = math.cos(a) * 4.45
            bz = cz + math.sin(a) * 4.45
            bm_p = glow if k in (0, 1, 7) else (trim if k in (2, 6) else metal)
            uvsphere(bm_p, 0.42, T((bx, sy * 0.42, bz)), 8, 6)

    # Crown star finial atop the medallion.
    cone(trim, 0.45, 0.04, 1.8, 4, T((0, 0, cz + R_disc + 0.6)))


# -----------------------------------------------------------------------------------------------------------
# 8. GlobeStand — Atlas's grand meridian cartographic globe stand flanked by brass-bound map-chests
# -----------------------------------------------------------------------------------------------------------
@template("GlobeStand", METAL=2400, TRIM=1800, WOOD=1800, ALT=1200, STONE=900, SILK=600, MOSS=600)
def globe_stand(t):
    """Atlas's cartographic vignette (seen on the north-west isle in the guide image): a grand celestial-
    terrestrial globe suspended in a brass horizon-and-meridian cradle on a carved tripod stand, flanked by
    two heavy brass-bound ebony map-chests with rolled vellum star-charts."""
    metal, trim, wood, alt, stone, silk, moss = (t.bm(r) for r in ("METAL", "TRIM", "WOOD", "ALT", "STONE", "SILK", "MOSS"))

    # Central globe stand: turned pedestal, 4 curved legs, horizontal zodiac table ring & meridian cradle.
    cone(stone, 4.0, 3.6, 0.7, 12, T((0, 0, 0)))
    lathe(wood, [(1.6, 0.7), (0.8, 2.2), (1.1, 4.4), (0.75, 5.4)], 12, Matrix.Identity(4))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        strut(wood, (math.cos(a) * 3.4, math.sin(a) * 3.4, 0.7), (math.cos(a) * 4.4, math.sin(a) * 4.4, 8.8), 0.42)
    # Brass horizon ring table & vertical meridian ring.
    cz, gr = 9.2, 3.8
    ring_mesh(trim, gr + 1.0, 0.42, 28, T((0, 0, cz)), tube_segs=6)
    ring_mesh(metal, gr + 0.55, 0.28, 28, T((0, 0, cz)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    # The great cartographic globe (lapis oceans, star-moss continents, gold latitude/longitude lines).
    uvsphere(alt, gr, T((0, 0, cz)), 18, 12)
    for k in range(5):
        a = 2 * math.pi * k / 5
        z_c = cz + (-1.2 if k % 2 else 1.1)
        uvsphere(moss, 1.35, T((math.cos(a) * (gr - 0.7), math.sin(a) * (gr - 0.7), z_c)), 8, 6)
    ring_mesh(trim, gr + 0.06, 0.08, 24, T((0, 0, cz)), tube_segs=4)
    ring_mesh(trim, gr + 0.06, 0.08, 24, T((0, 0, cz)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)
    # Polar axis finial.
    axis_m = T((0, 0, cz)) @ R(math.radians(23.5), 4, "X")
    strut(trim, axis_m @ Vector((0, 0, -gr - 0.8)), axis_m @ Vector((0, 0, gr + 1.4)), 0.16)
    cone(trim, 0.35, 0.03, 1.1, 4, axis_m @ T((0, 0, gr + 1.4)))

    # Two brass-strapped ebony map-chests flanking left and right, one topped with rolled vellum scrolls.
    for sx, yaw in ((-1, 0.25), (1, -0.3)):
        cm = T((sx * 6.8, -0.8, 0.0)) @ R(yaw, 4, "Z")
        box(wood, (4.8, 3.0, 2.4), cm @ T((0, 0, 1.2)), bevel=0.08)
        # Bevelled domed chest lid.
        box(wood, (4.85, 2.9, 0.75), cm @ T((0, 0, 2.65)), bevel=0.22, segs=2)
        for bx in (-1.7, 0.0, 1.7):
            box(metal, (0.34, 3.12, 3.05), cm @ T((bx, 0, 1.55)))
        box(trim, (0.75, 0.28, 0.75), cm @ T((0, -1.55, 2.2)))
        if sx == 1:
            # Rolled vellum map scrolls resting on top of the right chest.
            for k in range(3):
                sm = cm @ T((-0.9 + k * 0.9, 0.0, 3.35)) @ R(0.2 * (k - 1), 4, "Z") @ R(math.pi / 2, 4, "X")
                cone(silk, 0.28, 0.28, 2.6, 8, sm @ T((0, 0, -1.3)))
                ring_mesh(trim, 0.30, 0.05, 10, sm, tube_segs=4)


# -----------------------------------------------------------------------------------------------------------
# 9. StarTableSlate — Almanac's trio of brass-framed carved star-table slates & tabletop astrolabe
# -----------------------------------------------------------------------------------------------------------
@template("StarTableSlate", ALT=1600, METAL=2200, TRIM=2200, STONE=1200, GLOW=1200, CRYSTAL=400)
def star_table_slate(t):
    """Almanac's standing star-table slates (seen on the north-east isle in the guide image): three arched
    brass-framed lapis-indigo slate stelae standing in a gentle fan, engraved with raised gold orbital charts
    and glowing star-tables, accompanied by a freestanding brass astrolabe on a slender plinth."""
    alt, metal, trim, stone, glow, crystal = (t.bm(r) for r in ("ALT", "METAL", "TRIM", "STONE", "GLOW", "CRYSTAL"))
    specs = ((-5.2, 0.6, 0.22, 9.6), (0.0, 0.0, 0.0, 11.4), (5.2, 0.6, -0.22, 9.6))

    for idx, (sx, sy, yaw, h) in enumerate(specs):
        m = T((sx, sy, 0.0)) @ R(yaw, 4, "Z")
        w = 4.2 if idx == 1 else 3.6
        # Vellum-stone stele base plinth.
        box(stone, (w + 0.9, 2.0, 1.1), m @ T((0, 0, 0.55)), bevel=0.08)
        # Main lapis-indigo slate tablet.
        box(alt, (w - 0.3, 0.65, h - 1.4), m @ T((0, 0, 1.1 + (h - 1.4) * 0.5)))
        # Brass outer frame piers & arched pediment cap.
        for side in (-1, 1):
            box(metal, (0.45, 0.95, h - 1.0), m @ T((side * (w * 0.5), 0, 1.1 + (h - 1.0) * 0.5)))
            uvsphere(trim, 0.34, m @ T((side * (w * 0.5), 0, h + 0.3)), 8, 6)
        box(trim, (w + 0.4, 1.0, 0.45), m @ T((0, 0, h)))
        cone(trim, w * 0.42, 0.1, 1.5, 4, m @ T((0, 0, h + 0.2)) @ R(math.pi / 4, 4, "Z"))
        # Engraved gold & glowing star-table lines + orbital diagram circles on front (-Y) face!
        ring_mesh(glow, w * 0.28, 0.07, 16, m @ T((0, -0.38, h * 0.68)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
        ring_mesh(trim, w * 0.16, 0.06, 14, m @ T((0, -0.38, h * 0.68)) @ R(math.pi / 2, 4, "X"), tube_segs=4)
        for row in range(4):
            rz = 2.4 + row * 1.15
            box(trim if row % 2 == 0 else glow, (w * 0.68, 0.12, 0.18), m @ T((0, -0.36, rz)))

    # Freestanding brass astrolabe on the west side (-X).
    ax, ay = -8.6, -1.6
    cone(stone, 1.2, 0.95, 0.6, 8, T((ax, ay, 0)))
    lathe(metal, [(0.45, 0.6), (0.24, 3.6), (0.42, 4.2)], 10, T((ax, ay, 0)))
    ring_mesh(trim, 1.55, 0.12, 20, T((ax, ay, 5.8)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    ring_mesh(metal, 1.15, 0.09, 16, T((ax, ay, 5.8)) @ R(math.pi / 2, 4, "X") @ R(0.5, 4, "Z"), tube_segs=4)
    uvsphere(crystal, 0.42, T((ax, ay, 5.8)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 10. LecternRow — Lexicon & Concordance's curved row of 3 tall brass-and-stone lecterns facing the Sun
# -----------------------------------------------------------------------------------------------------------
@template("LecternRow", STONE=1600, METAL=1600, TRIM=1600, ALT=900, SILK=1200, WOOD=700, GLOW=400)
def lectern_row(t):
    """Lexicon and Concordance's curved gallery row of three tall reading lecterns (seen lining the inner
    rim of both middle-orbit isles facing the Sun in the guide image): stepped curved stone curb, three
    fluted vellum-and-brass lecterns holding open illuminated vellum tomes."""
    stone, metal, trim, alt, silk, wood, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ALT", "SILK", "WOOD", "GLOW"))
    arc_r = 16.0
    for idx, ang in enumerate((-math.radians(18), 0.0, math.radians(18))):
        lx = math.sin(ang) * arc_r
        ly = (math.cos(ang) - 1.0) * arc_r
        m = T((lx, ly, 0.0)) @ R(-ang, 4, "Z")
        # Stepped stone base & fluted column pedestal.
        box(stone, (3.2, 2.4, 0.75), m @ T((0, 0, 0.375)), bevel=0.06)
        cone(stone, 0.95, 0.72, 3.8, 8, m @ T((0, 0, 0.75)))
        ring_mesh(metal, 0.88, 0.14, 12, m @ T((0, 0, 4.55)), tube_segs=5)
        box(wood, (3.6, 2.4, 0.32), m @ T((0, 0, 5.0)) @ R(math.radians(-24), 4, "X"))
        box(trim, (3.75, 2.55, 0.14), m @ T((0, 0, 5.12)) @ R(math.radians(-24), 4, "X"))
        # Open glowing tome resting on each lectern.
        open_tome(alt if idx == 1 else wood, silk, trim, m @ T((0, 0, 5.25)) @ R(math.radians(-24), 4, "X"),
                  w=3.1, d=2.1, page_h=0.48, spread=0.25)
        uvsphere(glow, 0.24, m @ T((0, 0, 6.25)), 6, 5)

    # Low curved brass linking rail tying the 3 lectern plinths together.
    pts = []
    for k in range(13):
        a = -math.radians(22) + math.radians(44) * k / 12
        pts.append((math.sin(a) * arc_r, (math.cos(a) - 1.0) * arc_r, 0.75))
    tube(metal, pts, [0.22] * len(pts), 6, cap=True)


# -----------------------------------------------------------------------------------------------------------
# 11. RingGearHalf — Massive half-sunk toothed brass drive ring-gear (The Orrery Plinth)
# -----------------------------------------------------------------------------------------------------------
@template("RingGearHalf", METAL=2600, TRIM=2200, STONE=1400, ALT=900)
def ring_gear_half(t):
    """The Orrery Plinth's half-sunk drive gear (seen left and right on the foreground Plinth in the guide
    image): a massive 19-stud-wide vertical toothed brass cogwheel arch rising out of a bevelled lapis-and-
    vellum stone gear-slot housing, paired with a smaller offset idler gear behind it."""
    metal, trim, stone, alt = (t.bm(r) for r in ("METAL", "TRIM", "STONE", "ALT"))

    # Stepped lapis & vellum stone housing slot standing on z = 0.
    box(stone, (20.4, 6.8, 1.3), T((0, 0, 0.65)), bevel=0.14)
    box(alt, (18.8, 4.6, 1.0), T((0, 0, 1.45)))
    box(trim, (19.2, 5.0, 0.24), T((0, 0, 2.0)))

    # Main half-sunk vertical brass gear arch (radius 8.0, centred at Z = 1.4, emerging 0..180 degrees).
    R_g, cz = 8.0, 1.4
    segs = 20
    # Solid curved rim band & inner flange.
    for r_ring, th, bm in ((R_g - 0.8, 0.75, metal), (R_g - 1.9, 0.35, trim)):
        pts = []
        for k in range(segs + 1):
            a = math.pi * k / segs
            pts.append((math.cos(a) * r_ring, -0.5, cz + math.sin(a) * r_ring))
        tube(bm, pts, [th] * len(pts), 6, cap=True)
    # 5 radial brass spokes emerging from the slot.
    for k in range(1, 6):
        a = math.pi * k / 6
        strut(metal, (0, -0.5, cz + 0.4), (math.cos(a) * (R_g - 1.0), -0.5, cz + math.sin(a) * (R_g - 1.0)), 0.72)
    # 13 chunky gear teeth marching around the upper arc!
    for k in range(13):
        a = math.radians(8) + math.radians(164) * k / 12
        tm = T((math.cos(a) * (R_g + 0.45), -0.5, cz + math.sin(a) * (R_g + 0.45))) @ R(-a, 4, "Y")
        box(trim if k % 2 == 0 else metal, (1.55, 1.45, 1.25), tm)

    # Secondary smaller offset idler half-gear behind (+Y) for rich mechanical depth.
    R2 = 5.2
    for k in range(9):
        a = math.radians(12) + math.radians(156) * k / 8
        tm = T((3.2 + math.cos(a) * (R2 + 0.35), 1.4, cz + math.sin(a) * (R2 + 0.35))) @ R(-a, 4, "Y")
        box(metal, (1.1, 1.0, 0.9), tm)
    pts2 = [(3.2 + math.cos(math.pi * k / 14) * (R2 - 0.5), 1.4, cz + math.sin(math.pi * k / 14) * (R2 - 0.5)) for k in range(15)]
    tube(trim, pts2, [0.55] * len(pts2), 6, cap=True)


# -----------------------------------------------------------------------------------------------------------
# 12. SundialBrass — Perihelion Court's grand engraved circular brass sundial
# -----------------------------------------------------------------------------------------------------------
@template("SundialBrass", STONE=1800, METAL=2400, TRIM=2200, ALT=1000, GLOW=600)
def sundial_brass(t):
    """Perihelion Court's great brass sundial (seen front-and-centre in the guide image facing the Sun-Lectern):
    an 18-stud-diameter stepped circular vellum-stone dial rim, engraved concentric brass compass rings, 12
    raised gold hour markers, lapis inner star-rose, and a bold pierced-brass triangular gnomon pointing north."""
    stone, metal, trim, alt, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "ALT", "GLOW"))
    R_out = 9.0

    # Stepped circular dial platform (walkable low profile around rim, gnomon centred).
    cone(stone, R_out, R_out - 0.3, 0.75, 28, T((0, 0, 0)))
    cyl_z(metal, R_out - 0.65, 0.35, (0, 0, 0.75), segs=28)
    cyl_z(alt, R_out * 0.52, 0.18, (0, 0, 1.05), segs=24)
    # Concentric brass & gold degree rings.
    ring_mesh(trim, R_out - 0.65, 0.24, 32, T((0, 0, 1.15)), tube_segs=5)
    ring_mesh(metal, R_out * 0.74, 0.18, 28, T((0, 0, 1.16)), tube_segs=5)
    ring_mesh(trim, R_out * 0.52, 0.16, 24, T((0, 0, 1.24)), tube_segs=5)

    # 12 raised gold hour-line ticks & cardinal star-points.
    for k in range(12):
        a = 2 * math.pi * k / 12
        is_card = (k % 3 == 0)
        box(trim if not is_card else glow, (1.8 if is_card else 1.2, 0.32 if is_card else 0.22, 0.2),
            R(a, 4, "Z") @ T((R_out * 0.68, 0, 1.22)))
        if is_card:
            cone(trim, 0.42, 0.04, 1.1, 4, R(a, 4, "Z") @ T((R_out * 0.88, 0, 1.15)))

    # Bold pierced-brass triangular gnomon blade rising from centre toward +Y (north / Sun-Lectern).
    strut(metal, (0, -3.2, 1.1), (0, 3.4, 6.2), 0.55)
    strut(metal, (0, 3.4, 1.1), (0, 3.4, 6.2), 0.58)
    strut(trim, (0, -3.2, 1.1), (0, 3.4, 1.1), 0.52)
    # Interior scrolled brass brace inside the gnomon triangle.
    ring_mesh(trim, 1.15, 0.16, 16, T((0, 1.35, 2.75)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)
    uvsphere(glow, 0.48, T((0, 3.4, 6.45)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 13. OrreryGateArch — Arrival brass orrery arch with miniature planets on wires (guide image foreground)
# -----------------------------------------------------------------------------------------------------------
@template("OrreryGateArch", STONE=2400, ALT=1400, METAL=3200, TRIM=2600, CRYSTAL=900, GLOW=900)
def orrery_gate_arch(t):
    """The Orrery Gate over the Floor 42 Sanctuary arrival (seen at the bottom of the guide image): twin
    stepped lapis-and-vellum piers supporting a wide twin-ribbed brass semicircular arch (clear 28 studs wide
    x 18+ studs high inside!) strung with brass orbital wires suspending 5 miniature planets (including a
    ringed planet) and crowned with a solar finial."""
    stone, alt, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "CRYSTAL", "GLOW"))

    # Flanking stepped piers (clear walkway from X = -14.5 to +14.5).
    for sx in (-1, 1):
        px = sx * 17.2
        box(stone, (6.2, 6.6, 2.0), T((px, 0, 1.0)), bevel=0.14)
        box(stone, (5.0, 5.4, 7.2), T((px, 0, 5.6)), bevel=0.1)
        box(alt, (3.4, 5.7, 4.6), T((px, 0, 5.6)))
        box(trim, (5.5, 5.9, 0.55), T((px, 0, 9.4)))
        # Small brass drive-gear finial on outer shoulder.
        spoked_gear(metal, trim, 1.65, 0.45, 10, T((sx * 19.8, 0, 10.6)) @ R(math.pi / 2, 4, "X"), spokes=4)

    # Wide twin-ribbed semicircular brass arch (centre Z = 10.0, outer R = 17.8, inner R = 15.6).
    cz = 10.0
    for r_arch, th, bm in ((17.8, 0.72, metal), (15.6, 0.58, trim)):
        pts = [(math.cos(math.pi * k / 28) * r_arch, 0.0, cz + math.sin(math.pi * k / 28) * r_arch) for k in range(29)]
        tube(bm, pts, [th] * len(pts), 6, cap=True)
    # Radial brass ladder struts linking inner & outer arch ribs.
    for k in range(1, 12):
        a = math.pi * k / 12
        strut(metal, (math.cos(a) * 15.6, 0, cz + math.sin(a) * 15.6),
              (math.cos(a) * 17.8, 0, cz + math.sin(a) * 17.8), 0.34)

    # Twin curved brass orbital wire tracks slung high under the crown (Z >= 20.5, clearing walk lanes!)
    # carrying 5 distinct miniature planets (including a ringed Saturn-like planet!).
    for r_wire in (13.4, 11.4):
        wpts = [(math.cos(math.radians(32 + 116 * k / 20)) * r_wire, 0.0, cz + math.sin(math.radians(32 + 116 * k / 20)) * r_wire) for k in range(21)]
        tube(metal, wpts, [0.14] * len(wpts), 5, cap=True)

    planet_specs = (
        (math.radians(44), 13.4, 0.95, alt, False),
        (math.radians(66), 11.4, 1.35, trim, True),
        (math.radians(90), 13.4, 1.45, glow, False),
        (math.radians(114), 11.4, 1.05, crystal, False),
        (math.radians(136), 13.4, 1.20, metal, True),
    )
    for ang, r_w, p_rad, bm_p, has_r in planet_specs:
        px = math.cos(ang) * r_w
        pz = cz + math.sin(ang) * r_w
        # Vertical brass suspension rod from the inner arch rib.
        strut(trim, (math.cos(ang) * 15.6, 0, cz + math.sin(ang) * 15.6), (px, 0, pz), 0.12)
        uvsphere(bm_p, p_rad, T((px, 0, pz)), 12, 8)
        if has_r:
            ring_mesh(trim, p_rad * 1.75, 0.14, 18, T((px, 0, pz)) @ R(0.35, 4, "X"), tube_segs=4)

    # Crown solar star-quill crest at Z = 28..33.
    cone(trim, 0.8, 0.06, 3.6, 4, T((0, 0, cz + 18.2)))
    ring_mesh(trim, 1.85, 0.18, 18, T((0, 0, cz + 19.6)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    uvsphere(glow, 0.72, T((0, 0, cz + 19.6)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 14. AphelionTelescope — Frosted far-planet brass refractor telescope on star-glass ice plinth (The Aphelion)
# -----------------------------------------------------------------------------------------------------------
@template("AphelionTelescope", CRYSTAL=1800, STONE=1000, METAL=2400, TRIM=1600, WOOD=900, SILK=600, GLOW=400)
def aphelion_telescope(t):
    """The Aphelion's lone refractor telescope (seen on the frosted icy north isle in the guide image): a
    gleaming stepped brass refracting telescope with declination arc, finder scope and tripod, standing on a
    frosted star-glass crystal shelf beside stacked star-charts and a frosted lantern."""
    crystal, stone, metal, trim, wood, silk, glow = (t.bm(r) for r in ("CRYSTAL", "STONE", "METAL", "TRIM", "WOOD", "SILK", "GLOW"))

    # Faceted frosted star-glass & pale-stone plinth with jagged frost shards at edges.
    cone(stone, 5.4, 5.0, 0.85, 10, T((0, 0, 0)))
    cone(crystal, 4.9, 4.6, 0.45, 10, T((0, 0, 0.85)))
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        cone(crystal, 0.65, 0.04, 1.9 + (k % 2) * 0.7, 5, T((math.cos(a) * 4.5, math.sin(a) * 4.5, 0.4)) @ R(a, 4, "Z") @ R(0.25, 4, "Y"))

    # Heavy mahogany-and-brass tripod legs meeting at pivot head (Z = 6.2).
    pivot = Vector((0, 0, 6.2))
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 6
        foot = Vector((math.cos(a) * 3.1, math.sin(a) * 3.1, 1.1))
        strut(wood, foot, pivot, 0.38)
        box(metal, (0.58, 0.58, 0.55), T(foot))
        # Mid spreader bar to centre column.
        strut(metal, (math.cos(a) * 1.8, math.sin(a) * 1.8, 3.2), (0, 0, 3.2), 0.16)
    cyl_z(metal, 0.52, 2.2, (0, 0, 5.4), segs=12)
    ring_mesh(trim, 1.4, 0.12, 16, T((0, 0, 6.5)) @ R(math.pi / 2, 4, "Y"), tube_segs=4)

    # Stepped brass refractor tube aimed upward & outward (-Y / +Z at 28 deg elevation).
    tm = T((0, 0, 7.6)) @ R(math.radians(90 - 28), 4, "X")
    # Eyepiece back (+Z local = down-back), main barrel, wide objective hood (-Z local = up-forward).
    cone(trim, 0.36, 0.52, 2.4, 12, tm @ T((0, 0, -4.8)))
    cone(metal, 0.62, 1.02, 7.6, 16, tm @ T((0, 0, -2.6)))
    cone(trim, 1.05, 1.24, 2.4, 16, tm @ T((0, 0, 5.0)))
    # Objective star-glass lens & subtle glint.
    cone(crystal, 1.12, 1.12, 0.25, 16, tm @ T((0, 0, 7.1)))
    uvsphere(glow, 0.45, tm @ T((0, 0, 7.15)), 8, 6)
    # Brass strengthening collars & side finder scope.
    for z_c in (-1.2, 2.2, 5.1):
        ring_mesh(trim, 0.88 + (z_c + 2.0) * 0.04, 0.14, 16, tm @ T((0, 0, z_c)), tube_segs=5)
    cone(metal, 0.22, 0.28, 3.8, 10, tm @ T((0.95, 0.75, 0.6)))
    strut(trim, tm @ Vector((0, 0, 1.2)), tm @ Vector((0.95, 0.75, 1.2)), 0.12)
    strut(trim, tm @ Vector((0, 0, 3.4)), tm @ Vector((0.95, 0.75, 3.4)), 0.12)

    # Stacked observation logs on the side of the plinth.
    for k in range(4):
        bm_r = R(0.32 * k, 4, "Z")
        box(wood if k % 2 == 0 else trim, (2.0, 1.5, 0.38), T((-2.8, -1.6, 1.5 + k * 0.4)) @ bm_r)
        box(silk, (1.82, 1.32, 0.24), T((-2.75, -1.6, 1.5 + k * 0.4)) @ bm_r)


# -----------------------------------------------------------------------------------------------------------
# 15. MarginaliaStack — Glossary & Marginalia's clustered slip-boxes & teetering annotation towers
# -----------------------------------------------------------------------------------------------------------
@template("MarginaliaStack", WOOD=1800, SILK=1600, ALT=1200, TRIM=1200, METAL=700, STONE=600)
def marginalia_stack(t):
    """Glossary and Marginalia's annotation clutter cluster (seen on the far-east & far-west minor moons in
    the guide image): wooden annotation slip-boxes brimming with ivory index slips, three staggered teetering
    stacks of thick tomes, and an open reference codex."""
    wood, silk, alt, trim, metal, stone = (t.bm(r) for r in ("WOOD", "SILK", "ALT", "TRIM", "METAL", "STONE"))
    rng = random.Random(4215)

    # Low stone footing pad.
    box(stone, (10.2, 7.6, 0.45), T((0, 0, 0.225)), bevel=0.06)

    # Two open wooden annotation slip-boxes filled with upright vellum slips.
    for bx, by, yaw in ((-2.6, -1.2, 0.18), (2.8, 1.0, -0.25)):
        bm = T((bx, by, 0.45)) @ R(yaw, 4, "Z")
        box(wood, (3.4, 2.2, 1.4), bm @ T((0, 0, 0.7)), bevel=0.05)
        box(metal, (3.5, 2.3, 0.18), bm @ T((0, 0, 0.25)))
        box(trim, (3.5, 2.3, 0.16), bm @ T((0, 0, 1.35)))
        for s_i in range(6):
            sx = -1.25 + s_i * 0.5
            box(silk, (0.14, 1.8, rng.uniform(1.45, 1.95)), bm @ T((sx, 0, 1.45)) @ R(rng.uniform(-0.14, 0.14), 4, "Y"))

    # Three staggered tall stacks of thick annotation tomes (up to 7.8 studs tall!).
    stacks = ((0.2, 1.2, 9), (-3.1, 1.6, 6), (2.4, -1.5, 7))
    for sx, sy, n_books in stacks:
        z_cur = 0.45
        for k in range(n_books):
            bw = rng.uniform(1.9, 2.8) * (1.0 - 0.03 * k)
            bd = rng.uniform(1.5, 2.2) * (1.0 - 0.03 * k)
            bh = rng.uniform(0.55, 0.85)
            ox = rng.uniform(-0.22, 0.22)
            oy = rng.uniform(-0.22, 0.22)
            bm = T((sx + ox, sy + oy, z_cur + bh * 0.5)) @ R(rng.uniform(-0.45, 0.45), 4, "Z")
            cover = (alt, wood, trim)[k % 3]
            box(cover, (bw, bd, bh), bm)
            box(silk, (bw * 0.9, bd * 0.88, bh * 0.7), bm @ T((bw * 0.04, 0, 0)))
            box(trim, (0.16, bd * 0.96, bh * 1.02), bm @ T((-bw * 0.48, 0, 0)))
            z_cur += bh

    # Open reference book perched atop the central stack.
    open_tome(alt, silk, trim, T((0.2, 1.2, 6.8)) @ R(0.3, 4, "Z"), w=2.8, d=1.9, page_h=0.45, spread=0.28)


# -----------------------------------------------------------------------------------------------------------
# 16. OrreryGearUnderside — Faceted floating slate underside fitted with massive brass clockwork gears
# -----------------------------------------------------------------------------------------------------------
@template("OrreryGearUnderside", ALT=2600, STONE=1100, METAL=3400, TRIM=2200, GLOW=600)
def orrery_gear_underside(t):
    """Floor 42's clockwork floating-isle underside (seen beneath the Sun-Lectern and every planet isle in
    the guide image): a tapering faceted indigo-slate rock crag crowned by a vellum-and-brass rim collar,
    sheathed in massive interlocking toothed brass drive-gears and a vertical brass drive-spindle tip."""
    alt, stone, metal, trim, glow = (t.bm(r) for r in ("ALT", "STONE", "METAL", "TRIM", "GLOW"))
    top_r, height = 24.0, 34.0
    rng = random.Random(4216)

    # Vertical central brass drive spindle & glowing bearing tip sitting cleanly on z = 0.
    cone(trim, 0.55, 2.2, 6.5, 8, T((0, 0, 0.0)))
    uvsphere(glow, 1.2, T((0, 0, 5.2)), 10, 8)
    cone(metal, 2.2, 3.6, 5.0, 12, T((0, 0, 6.5)))

    # Tapering faceted indigo-slate crag body rising from z = 7 to collar_z = 32.
    collar_z = height - 2.0
    cone(alt, 4.2, top_r * 0.92, collar_z - 7.0, 12, T((0, 0, 7.0)))
    for k in range(10):
        a = 2 * math.pi * k / 10
        sub_h = rng.uniform(13.0, 21.0)
        z_bot = collar_z - sub_h
        r_m = top_r * rng.uniform(0.45, 0.72)
        cone(alt, 1.2, top_r * 0.18, sub_h, 5, T((math.cos(a) * r_m, math.sin(a) * r_m, z_bot)) @ R(a, 4, "Z"))

    # Upper vellum-stone & brass rim collar.
    cone(stone, top_r * 0.94, top_r, 2.0, 24, T((0, 0, collar_z)))
    ring_mesh(metal, top_r * 0.99, 0.48, 28, T((0, 0, collar_z + 1.0)), tube_segs=6)
    ring_mesh(trim, top_r * 0.96, 0.25, 28, T((0, 0, collar_z + 1.85)), tube_segs=4)

    # Four massive vertical interlocking toothed brass clockwork gears projecting boldly from the underside rock!
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        gr = 9.2 if k % 2 == 0 else 7.4
        gz = 23.0 if k % 2 == 0 else 18.2
        dist = top_r * 0.72 if k % 2 == 0 else top_r * 0.62
        gm = R(a, 4, "Z") @ T((dist, 0, gz)) @ R(math.pi / 2, 4, "Y")
        spoked_gear(metal, trim, gr, 1.35, 14 if k % 2 == 0 else 12, gm, spokes=5)

    # Large horizontal brass ring-gear encircling the lower spindle waist (Z = 12.0).
    spoked_gear(metal, trim, 13.6, 1.35, 20, T((0, 0, 12.0)), spokes=6)


if __name__ == "__main__":
    kit, manifest = build_kit("AstralF42Kit", F42_TEMPLATES, DEFAULT_BUDGET)
    apply_halcyr_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AstralF42Kit")
    render_previews(kit, F42_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
