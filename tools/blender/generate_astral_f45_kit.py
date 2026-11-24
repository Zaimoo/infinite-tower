"""
Astral Archives Floor 45 (Rift Warden's Observatory) sculpted assets, generated in headless Blender.

Inspired by the Rift Warden's Observatory reference art (reference/Astral Archives 45.jpg) and the
Observatory finale ecosystem (docs/prompts/astral-archives-floor-layouts-prompt.md):
the archive's final watch overlooking a diagonal Rift torn end-to-end across the floor. Behind the
204x152 Observing Floor boss dais rises the colossal Great Telescope — split cleanly into
GreatTelescopeMount (106-stud stone-and-brass equatorial yoke pedestal) and GreatTelescopeTube
(192-stud stepped brass refractor barrel aimed down at the Rift with a dramatically cracked star-glass
objective lens, combining to ~298 studs to clear the ≥285-stud ladder!) — framed by the torn-open
ObservatoryDomeRibs skeleton dome behind it. Flanking the dais stand the twin colossal AzimuthRings
holding the floor's last two golden Index Lamps; MeridianFooting arcs rim the dais edge without
crowding the boss arena. Across the diagonal Rift stretch three SutureShelfSpans (ebony bookcases
lashed with brass chains & stitched with gold light), the cantilevered RiftOverlookDeck with the Grand
Indexer's overturned chair, jagged RiftLipCrystal ledges, and the swirling RiftEyeMesh deep in the chasm.
Supporting vignettes dress every terrace: cylindrical TransitTowers, brass TransitInstruments, Lens
Gallery LensBenches aimed at the Rift, Orrery Crest's toppled FallenOrrery, StarLecternGrand open to the
final page, star-glyph InkPoolDecals, the Fallen Catalogue's ToppledCabinetRange, and the Proof Room's
ProofPress with its one blank sheet.

1 Blender unit = 1 stud, standing on z = 0, front facing -Y in Blender / +Z in Roblox, one mesh object
per colour role named "<Template>__<ROLE>". Every piece stands on its origin.

Roles (AstralFloor45 passes the Rift-eye silver/indigo/brass override; no new colour roles):
    STONE    pale vellum-stone & observatory ashlar   ALT      dark slate/basalt & lapis-indigo void
    TRIM     worn gold leaf & gilded meridian inlay   METAL    aged brass telescope, rings & chains
    WOOD     ebony bookcases, benches & cabinets      SILK     ivory vellum pages & blank proof sheet
    GLOW     silver lens-light & last gold lamps      CRYSTAL  cracked star-glass lenses & rift crystals

Outputs (assets-source/tower/astral_f45_kit/):
    AstralF45Kit.blend, AstralF45Kit.fbx, manifest.json, previews/kit_sheet_1.png, previews/tiles/*.png.

Run:
    blender.exe --background --factory-startup --python tools/blender/generate_astral_f45_kit.py
"""
import bpy, bmesh, math, os, json, runpy, random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets-source", "tower", "astral_f45_kit")

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
balustrade_post, apply_halcyr_preview_materials = f41["balustrade_post"], f41["apply_halcyr_preview_materials"]
spoked_gear, banded_planet = f42["spoked_gear"], f42["banded_planet"]

T = Matrix.Translation
R = Matrix.Rotation

DEFAULT_BUDGET = 3500
F45_TEMPLATES = {}


def template(name, **budget):
    def deco(fn):
        F45_TEMPLATES[name] = (fn, budget)
        return fn
    return deco


# -----------------------------------------------------------------------------------------------------------
# 1. GreatTelescopeMount — Colossal 106-stud equatorial stone-and-brass observatory mount
# -----------------------------------------------------------------------------------------------------------
@template("GreatTelescopeMount", STONE=3600, ALT=1800, METAL=4200, TRIM=3200, GLOW=600)
def great_telescope_mount(t):
    """Lower equatorial pedestal mount of the colossal Great Telescope (106 studs tall, 62 wide; split from
    GreatTelescopeTube for clean clearance behind the Floor 45 boss dais): stepped circular dark-slate &
    vellum-stone azimuth plinth, colossal brass azimuth gear-ring, twin sweeping cast-brass trunnion yoke
    piers rising to a heavy declination drive wheel and cradle saddle."""
    stone, alt, metal, trim, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "GLOW"))

    # Stepped circular observatory azimuth base plinth (R = 30 -> 21, Z = 0..26).
    cone(stone, 30.0, 28.5, 6.0, 24, T((0, 0, 0)))
    cone(alt, 26.8, 25.6, 5.5, 24, T((0, 0, 6.0)))
    cone(stone, 23.2, 20.5, 13.0, 20, T((0, 0, 11.5)))
    # Heavy brass azimuth gear collar encircling the plinth top (Z = 24.5).
    spoked_gear(metal, trim, 24.2, 3.0, 24, T((0, 0, 24.5)), spokes=8, hub_r=12.0)
    ring_mesh(trim, 28.8, 0.9, 32, T((0, 0, 6.2)), tube_segs=5)
    ring_mesh(trim, 21.0, 0.75, 28, T((0, 0, 24.0)), tube_segs=5)

    # Central sculpted brass equatorial pedestal column (Z = 24..54).
    lathe(metal, [(15.2, 24.0), (11.8, 35.0), (13.4, 47.0), (16.8, 54.0)], 18, Matrix.Identity(4))
    ring_mesh(trim, 14.6, 0.85, 24, T((0, 0, 38.0)), tube_segs=5)
    ring_mesh(alt, 12.4, 0.65, 24, T((0, 0, 32.0)), tube_segs=5)

    # Twin sweeping cast-brass trunnion yoke arms rising from Z = 50 up to trunnion bearings at Z = 101!
    for sx in (-1, 1):
        arm_pts = [
            (sx * 12.5, 0.0, 50.0),
            (sx * 22.8, 0.0, 64.0),
            (sx * 25.5, 0.0, 82.0),
            (sx * 24.5, 0.0, 101.0),
        ]
        tube(metal, arm_pts, [4.6, 4.1, 3.6, 3.4], 10, cap=True)
        # Diagonal reinforcement struts down to turntable waist.
        strut(trim, (sx * 13.8, -5.8, 46.0), (sx * 23.2, -3.6, 88.0), 1.45)
        strut(trim, (sx * 13.8, 5.8, 46.0), (sx * 23.2, 3.6, 88.0), 1.45)
        # Heavy trunnion bearing cap & glowing vernier degree dial at Z = 101!
        cyl_x(metal, 5.5, 6.8, (sx * 24.5, 0.0, 101.0), segs=16)
        ring_mesh(trim, 6.1, 0.6, 20, T((sx * 28.0, 0.0, 101.0)) @ R(math.pi / 2, 4, "Y"), tube_segs=5)
        uvsphere(glow, 1.5, T((sx * 28.5, 0.0, 101.0)), 8, 6)

    # Clean outer brass declination altitude gear-wheel on the east yoke cheek (leaves inner cradle open for tube!).
    spoked_gear(metal, trim, 18.0, 1.8, 22, T((26.2, 0, 92.0)) @ R(math.pi / 2, 4, "Y"), spokes=6)


# -----------------------------------------------------------------------------------------------------------
# 2. GreatTelescopeTube — Colossal 188-stud brass refractor barrel with cracked star-glass objective lens!
# -----------------------------------------------------------------------------------------------------------
@template("GreatTelescopeTube", METAL=5200, TRIM=4200, CRYSTAL=2200, ALT=1800, GLOW=1600)
def great_telescope_tube(t):
    """Colossal stepped brass refractor barrel of the Great Telescope (188 studs tall, 146 long; mounts onto
    GreatTelescopeMount for a combined ~294-stud landmark clearing Floor 45's >=285-stud ladder!): stout
    stepped brass optical tube pitched cleanly at 32 deg toward -Y (so the huge dramatically CRACKED
    star-glass objective lens gleams directly over the Observing Floor toward the Rift!), complete with a
    parallel brass finder scope, gilded collars, focus handwheels, and a tall equatorial brass sighting spire."""
    metal, trim, crystal, alt, glow = (t.bm(r) for r in ("METAL", "TRIM", "CRYSTAL", "ALT", "GLOW"))

    # Cradle pivot centred at Z = 62 with a sturdy equatorial saddle block standing cleanly on z = 0..62!
    # Local +Z of the tube points forward (-Y) and UPWARD at +30 deg so the giant cracked lens faces the player
    # and the Rift proudly (matching reference/Astral Archives 45.jpg!).
    pivot = Vector((0.0, 0.0, 62.0))
    pitch = math.radians(60)  # local +Z -> (0, -sin(60)=-0.866, cos(60)=+0.500) forward (-Y) & up!
    tm = T(pivot) @ R(pitch, 4, "X")

    # Heavy bronze trunnion cradle ring, cross-axle, and grounded counterweight saddle standing on z = 0.
    box(alt, (24.0, 18.0, 14.0), T((0, 0, 7.0)), bevel=0.4)
    cone(metal, 14.0, 10.5, 48.0, 16, T((0, 0, 14.0)))
    ring_mesh(trim, 19.5, 1.6, 28, tm @ T((0, 0, 0)), tube_segs=6)
    cyl_x(metal, 4.6, 50.0, (0, 0, 62.0), segs=16)

    # Stout stepped brass refractor barrel (rear eyepiece at local Z = -76 -> huge front objective hood at +88!).
    cone(trim, 6.2, 8.8, 22.0, 18, tm @ T((0, 0, -76.0)))
    cone(metal, 9.6, 13.8, 34.0, 22, tm @ T((0, 0, -54.0)))
    # Main wide optical barrel.
    cone(metal, 14.6, 19.4, 72.0, 26, tm @ T((0, 0, -20.0)))
    # Wide flared front objective lens dew-shield hood (UN-CAPPED so the giant cracked lens shines boldly!).
    cone(trim, 19.6, 22.8, 36.0, 26, tm @ T((0, 0, 52.0)), cap=False)
    ring_mesh(trim, 23.0, 1.75, 30, tm @ T((0, 0, 88.0)), tube_segs=6)

    # Bold gilded strengthening collars & recessed dark-lapis optical bands along the barrel.
    for z_c, r_c in ((-52.0, 10.2), (-18.0, 15.2), (16.0, 17.6), (52.0, 20.2), (72.0, 21.8)):
        ring_mesh(trim, r_c + 1.0, 1.15, 26, tm @ T((0, 0, z_c)), tube_segs=6)
        ring_mesh(alt, r_c + 0.45, 0.85, 26, tm @ T((0, 0, z_c - 3.2)), tube_segs=5)

    # THE CRACKED OBJECTIVE STAR-GLASS LENS seated right inside the open front dew-shield hood!
    cone(alt, 21.2, 21.2, 1.6, 26, tm @ T((0, 0, 81.5)))
    cone(crystal, 21.6, 21.6, 2.4, 26, tm @ T((0, 0, 83.2)))
    # Bold jagged glowing star-fracture cracks radiating across the exposed objective lens!
    crack_rays = (
        [(0, 0, 86.2), (6.5, 4.8, 86.5), (13.2, 11.4, 86.3), (20.2, 15.6, 86.0)],
        [(0, 0, 86.2), (-7.2, 6.4, 86.5), (-15.0, 9.6, 86.3), (-20.4, 12.2, 86.0)],
        [(0, 0, 86.2), (-4.6, -8.4, 86.5), (-11.0, -16.2, 86.3)],
        [(0, 0, 86.2), (8.2, -6.8, 86.5), (17.2, -12.6, 86.3)],
    )
    for ray in crack_rays:
        tube(glow, [tm @ Vector(p) for p in ray], [1.25, 0.92, 0.65, 0.40][:len(ray)], 5, cap=True)
    uvsphere(glow, 3.6, tm @ T((0, 0, 86.2)), 10, 8)

    # Secondary side finder-telescope mounted cleanly along top-east of the barrel (just like the reference art!).
    cone(metal, 3.2, 4.8, 56.0, 16, tm @ T((19.5, 13.0, -10.0)))
    ring_mesh(trim, 5.1, 0.65, 18, tm @ T((19.5, 13.0, 46.0)), tube_segs=5)
    for z_st in (-2.0, 32.0):
        strut(trim, tm @ Vector((12.0, 7.5, z_st)), tm @ Vector((19.5, 13.0, z_st)), 1.5)

    # Tall brass zenith meridian arc & equatorial sighting finial rising cleanly above the barrel to Z = 188!
    fin_base = tm @ Vector((0, 0, 52.0))
    cone(trim, 2.4, 0.35, 84.0, 10, T((fin_base.x, fin_base.y, fin_base.z + 14.0)))
    ring_mesh(trim, 8.5, 0.85, 22, T((fin_base.x, fin_base.y, fin_base.z + 72.0)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    uvsphere(glow, 2.4, T((fin_base.x, fin_base.y, fin_base.z + 96.5)), 10, 8)


# -----------------------------------------------------------------------------------------------------------
# 3. ObservatoryDomeRibs — Torn-open skeleton observatory half-dome framing the Great Telescope behind the dais
# -----------------------------------------------------------------------------------------------------------
@template("ObservatoryDomeRibs", STONE=2600, ALT=2400, METAL=4200, TRIM=3600)
def observatory_dome_ribs(t):
    """Far-layer backdrop skeleton dome behind the Observing Floor dais (seen framing the Great Telescope in
    the Floor 45 guide image!): a monumental 160-stud-wide open ribbed hemisphere with low ashlar drum base,
    9 soaring brass meridian ribs curving up to an open-shutter zenith ring, horizontal purlin arcs, and two
    torn-open curved dark-lapis dome shutter wings flanking the gaping open sky slit."""
    stone, alt, metal, trim = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM"))
    R_d = 76.0
    H_sill = 16.0
    H_dome = 128.0

    # Low semicircular dark-stone sill wall around the back arc (open completely on the front -Y side!).
    segs = 16
    for k in range(segs):
        a = math.radians(-10 + 200 * (k + 0.5) / segs)
        cx, cy = math.cos(a) * R_d, math.sin(a) * R_d
        seg_w = (2 * math.pi * R_d * 200 / 360) / segs + 0.8
        m = T((cx, cy, 0.0)) @ R(a, 4, "Z")
        box(stone, (5.2, seg_w, H_sill), m @ T((0, 0, H_sill * 0.5)), bevel=0.25)
        box(trim, (5.8, seg_w + 0.4, 1.4), m @ T((0, 0, H_sill + 0.6)))

    # 9 soaring curved brass structural ribs climbing from the sill arc up to the open zenith oculus ring!
    for k in range(9):
        a = math.radians(-5 + 190 * k / 8)
        pts = []
        for i in range(13):
            f = i / 12.0
            phi = f * math.radians(76)
            rr = math.cos(phi) * R_d
            zz = H_sill + math.sin(phi) * H_dome
            pts.append((math.cos(a) * rr, math.sin(a) * rr, zz))
        tube(metal, pts, [2.1 - 0.06 * i for i in range(13)], 6, cap=True)
        # Inner gold trim flange along each rib.
        pts_in = [(p[0] * 0.985, p[1] * 0.985, p[2] - 0.8) for p in pts]
        tube(trim, pts_in, [0.7] * len(pts_in), 4, cap=True)

    # Three horizontal curved purlin rings tying the ribs together + torn zenith oculus ring!
    for phi_deg, th, bm in ((24, 1.4, metal), (50, 1.3, trim), (76, 1.9, trim)):
        phi = math.radians(phi_deg)
        rr = math.cos(phi) * R_d
        zz = H_sill + math.sin(phi) * H_dome
        pts = [(math.cos(math.radians(-5 + 190 * i / 24)) * rr,
                math.sin(math.radians(-5 + 190 * i / 24)) * rr, zz) for i in range(25)]
        tube(bm, pts, [th] * len(pts), 6, cap=True)

    # Torn-open curved dark-lapis shutter panels hugging the outer west & east flanks of the dome tangent to the ribs!
    for side_a0, side_a1 in ((math.radians(-4), math.radians(38)), (math.radians(142), math.radians(184))):
        for k in range(3):
            a = side_a0 + (side_a1 - side_a0) * (k + 0.5) / 3
            for band in range(3):
                phi = math.radians(14 + band * 21)
                rr = math.cos(phi) * (R_d - 0.8)
                zz = H_sill + math.sin(phi) * H_dome
                pm = T((math.cos(a) * rr, math.sin(a) * rr, zz)) @ R(a, 4, "Z") @ R(-phi, 4, "Y")
                box(alt, (1.4, 21.0 * math.cos(phi), 26.0), pm)


# -----------------------------------------------------------------------------------------------------------
# 4. AzimuthRing — Twin colossal brass rings flanking the dais holding the LAST TWO golden Index Lamps!
# -----------------------------------------------------------------------------------------------------------
@template("AzimuthRing", STONE=2200, ALT=1400, METAL=3400, TRIM=2800, CRYSTAL=900, GLOW=900)
def azimuth_ring(t):
    """The Observatory's colossal West & East Azimuth Rings (seen gleaming dramatically either side of the
    dais above the glowing star-glass Ring Stairs in the Floor 45 guide image!): twin tall arched stone piers
    supporting a massive 34-stud-wide circular brass azimuth ring (clear 24-stud stair opening underneath!)
    with degree ticks and ONE of the floor's last two steady golden Index Lamps hanging inside its crown."""
    stone, alt, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "CRYSTAL", "GLOW"))

    # Tall arched stone-and-lapis flanking piers (clear passage X = -12 to +12).
    for sx in (-1, 1):
        px = sx * 15.2
        box(stone, (6.0, 8.0, 2.4), T((px, 0, 1.2)), bevel=0.16)
        box(stone, (4.8, 6.8, 12.0), T((px, 0, 8.4)), bevel=0.12)
        box(alt, (3.2, 7.1, 8.0), T((px, 0, 8.4)))
        box(trim, (5.4, 7.4, 0.75), T((px, 0, 14.6)))

    # Colossal open-bottom brass azimuth ring arch centred at Z = 23.0, R = 15.5 (clear stair passage below!).
    cz, R_az = 23.0, 15.5
    for r_r, th, bm in ((R_az, 1.35, metal), (R_az + 1.45, 0.55, trim), (R_az - 1.45, 0.45, trim)):
        pts = [(math.cos(math.radians(-30 + 240 * i / 30)) * r_r, 0.0,
                cz + math.sin(math.radians(-30 + 240 * i / 30)) * r_r) for i in range(31)]
        tube(bm, pts, [th] * len(pts), 6, cap=True)
    # 13 raised brass azimuth degree ticks around the upper arch.
    for k in range(13):
        a = math.radians(-22 + 224 * k / 12)
        tm = T((math.cos(a) * (R_az + 1.8), 0, cz + math.sin(a) * (R_az + 1.8))) @ R(-a, 4, "Y")
        box(trim, (1.1, 2.4, 0.55), tm)

    # THE LAST STEADY GOLDEN INDEX LAMP hanging cleanly from the ring's crown (at Z = 31.2, far above walk lane!).
    chain_run(metal, trim, (0, 0, cz + R_az - 1.5), (0, 0, 33.0), link_h=1.2, link_w=0.68, thick=0.14)
    index_lantern_head(metal, trim, crystal, glow, T((0, 0, 31.0)), scale=1.35)


# -----------------------------------------------------------------------------------------------------------
# 5. RiftEyeMesh — Swirling concentric vortex eye deep in the Rift bed (client-side Rift centrepiece!)
# -----------------------------------------------------------------------------------------------------------
@template("RiftEyeMesh", ALT=2600, CRYSTAL=2600, GLOW=2600, SILK=1000)
def rift_eye_mesh(t):
    """The Rift-Eye deep in the chasm (seen swirling violently at the heart of the Floor 45 guide image!):
    a 68-stud-diameter sculpted multi-layered cosmic whirlpool with a deep abyssal pupil, luminous inner
    accretion bowl, eight thick sweeping spiral vortex arms, and 24 loose vellum pages spiralling inward
    into the eye. Stands cleanly on z >= 0."""
    alt, crystal, glow, silk = (t.bm(r) for r in ("ALT", "CRYSTAL", "GLOW", "SILK"))
    rng = random.Random(4505)

    # Deep abyssal pupil & terraced luminous swirling whirlpool funnel standing cleanly on z >= 0!
    cyl_z(alt, 11.0, 0.8, (0, 0, 0.4), segs=28)
    cone(alt, 33.5, 12.0, 1.2, 32, T((0, 0, 0.0)))
    cone(crystal, 29.0, 11.5, 1.0, 32, T((0, 0, 1.0)))
    cone(glow, 19.5, 10.5, 0.9, 28, T((0, 0, 1.7)))
    ring_mesh(glow, 12.0, 1.05, 30, T((0, 0, 2.2)), tube_segs=6)
    ring_mesh(crystal, 20.5, 1.25, 34, T((0, 0, 2.5)), tube_segs=6)
    ring_mesh(alt, 29.5, 1.35, 36, T((0, 0, 2.6)), tube_segs=6)

    # 8 thick sweeping logarithmic spiral vortex arms churning around the pupil!
    for arm in range(8):
        pts = []
        rads = []
        a0 = 2 * math.pi * arm / 8
        for k in range(18):
            f = k / 17.0
            a = a0 + f * 3.1
            rr = 9.8 + f * 24.0
            zz = 1.6 + f * 3.0 + math.sin(f * math.pi) * 0.85
            pts.append((math.cos(a) * rr, math.sin(a) * rr, zz))
            rads.append(1.65 * (1.0 - 0.52 * f))
        tube(glow if arm % 2 == 0 else crystal, pts, rads, 5, cap=True)

    # 24 loose vellum pages spiralling inward & tilting down into the Rift Eye!
    for k in range(24):
        a = 2 * math.pi * k / 24 + rng.uniform(-0.18, 0.18)
        rr = rng.uniform(12.0, 31.5)
        zz = rng.uniform(2.6, 5.6)
        pm = T((math.cos(a) * rr, math.sin(a) * rr, zz)) @ R(a + math.pi / 2, 4, "Z") @ R(math.radians(-26), 4, "X")
        box(silk, (2.6, 1.9, 0.14), pm)


# -----------------------------------------------------------------------------------------------------------
# 6. RiftLipCrystal — Jagged crystallised starlight crags fringing both edges of the diagonal Rift
# -----------------------------------------------------------------------------------------------------------
@template("RiftLipCrystal", ALT=2000, CRYSTAL=2600, GLOW=1200, STONE=900)
def rift_lip_crystal(t):
    """Crystallised starlight rift-lip cluster (seen glowing along every torn chasm edge in the guide image):
    fractured dark basalt/slate overhang blocks bristling with a dramatic jagged row of translucent star-glass
    crystal blades and glowing inner cores leaning out over the Rift void. About 26 wide, 15 tall."""
    alt, crystal, glow, stone = (t.bm(r) for r in ("ALT", "CRYSTAL", "GLOW", "STONE"))
    rng = random.Random(4506)

    # Fractured basalt & flagstone cliff lip base.
    for k in range(5):
        bx = -9.6 + k * 4.8
        ground_rock(alt, (rng.uniform(5.5, 7.5), rng.uniform(6.0, 8.2), rng.uniform(4.2, 6.8)), (bx, 1.2, 0.0), seed=4510 + k, roughness=0.3, subdiv=1)
        box(stone, (4.4, 4.6, 0.9), T((bx, 2.8, 5.2 + (k % 2) * 0.4)) @ R(rng.uniform(-0.08, 0.08), 4, "Z"), bevel=0.1)

    # Jagged crystalline starlight blades jutting forward (-Y) & upward from the fractured lip!
    for k in range(11):
        cx = -11.0 + k * 2.2 + rng.uniform(-0.4, 0.4)
        cy = rng.uniform(-2.6, 0.4)
        ch = rng.uniform(6.5, 13.8)
        cr = rng.uniform(0.95, 1.85)
        tilt_x = math.radians(rng.uniform(14, 34))  # leans out over the Rift (-Y)!
        tilt_y = math.radians(rng.uniform(-16, 16))
        cm = T((cx, cy, 1.2)) @ R(tilt_x, 4, "X") @ R(tilt_y, 4, "Y") @ R(rng.uniform(0, math.pi), 4, "Z")
        cone(crystal, cr, cr * 0.82, ch * 0.42, 6, cm)
        cone(crystal, cr * 0.82, 0.04, ch * 0.58, 6, cm @ T((0, 0, ch * 0.42)))
        cone(glow, cr * 0.4, 0.02, ch * 0.78, 5, cm @ T((0, 0, ch * 0.06)))


# -----------------------------------------------------------------------------------------------------------
# 7. SutureShelfSpan — Shelving bridge lashed with brass chains & stitched with golden light (The 3 Sutures!)
# -----------------------------------------------------------------------------------------------------------
@template("SutureShelfSpan", WOOD=2800, METAL=2400, TRIM=1800, ALT=1200, SILK=1200, GLOW=1400)
def suture_shelf_span(t):
    """Floor 45's signature traversal feature (seen spanning the diagonal Rift in three places in the guide
    image!): a 28-stud-long improvised bridge of lashed archive shelving timbers flanked by upright ebony
    bookcase parapets at both ends, bound tightly with crisscrossed brass anchor chains and stitched along
    the side edges with glowing pale-gold light-threads (clear 11-stud walkway down the middle!)."""
    wood, metal, trim, alt, silk, glow = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "ALT", "SILK", "GLOW"))
    L, W, deck_z = 28.0, 14.5, 2.2
    rng = random.Random(4507)

    # Heavy lashed timber deck planks & twin brass underside chain-stringers.
    for sx in (-1, 1):
        box(metal, (0.8, L, 0.7), T((sx * (W * 0.42), 0, deck_z - 0.55)))
        # Hanging underside anchor chains dipping cleanly to z = 0.2!
        chain_run(metal, trim, (sx * (W * 0.44), -L * 0.42, deck_z - 0.3), (sx * (W * 0.44), -L * 0.2, 0.4), link_h=1.1, link_w=0.65, thick=0.14)
        chain_run(metal, trim, (sx * (W * 0.44), L * 0.42, deck_z - 0.3), (sx * (W * 0.44), L * 0.2, 0.4), link_h=1.1, link_w=0.65, thick=0.14)
    for k in range(14):
        py = -L * 0.46 + k * (L * 0.92 / 13)
        box(wood, (W - 1.2, 1.65, 0.45), T((0, py, deck_z + rng.uniform(-0.04, 0.04))), bevel=0.04)

    # Upright ebony bookcases lashed as parapet walls at the 4 corners (outside clear 11-stud walk width!).
    for sx in (-1, 1):
        for sy in (-1, 1):
            bx, by = sx * (W * 0.45), sy * (L * 0.34)
            box(wood, (1.6, 6.8, 7.6), T((bx, by, deck_z + 4.0)))
            box(trim, (1.8, 7.0, 0.35), T((bx, by, deck_z + 7.9)))
            # Packed shelf books facing inward!
            for s_z in (deck_z + 1.8, deck_z + 4.2, deck_z + 6.2):
                box(alt if int(s_z) % 2 else silk, (1.1, 5.8, 1.5), T((bx - sx * 0.3, by, s_z)))
        # Crisscrossing glowing golden "suture stitches" lacing the mid-span gap between the bookcases!
        rx = sx * (W * 0.44)
        for k in range(5):
            y0 = -6.0 + k * 3.0
            y1 = y0 + 2.6
            strut(glow, (rx, y0, deck_z + 0.4), (rx, y1, deck_z + 4.2), 0.16)
            strut(glow, (rx, y1, deck_z + 0.4), (rx, y0, deck_z + 4.2), 0.16)
        strut(trim, (rx, -L * 0.46, deck_z + 4.3), (rx, L * 0.46, deck_z + 4.3), 0.24)


# -----------------------------------------------------------------------------------------------------------
# 8. RiftOverlookDeck — Cantilevered balcony facing the dais with the Grand Indexer's overturned chair!
# -----------------------------------------------------------------------------------------------------------
@template("RiftOverlookDeck", STONE=1600, WOOD=1800, METAL=2200, TRIM=1600, SILK=600)
def rift_overlook_deck(t):
    """The Rift Overlook cantilever (seen projecting right over the Rift Eye from the Middle Suture in the
    Floor 45 guide image!): a semicircular cantilevered vellum-and-brass observation balcony braced by curved
    underside brass struts and anchor chains, with the Grand Indexer's ornate high-backed chair overturned
    across the floor amid loose pages."""
    stone, wood, metal, trim, silk = (t.bm(r) for r in ("STONE", "WOOD", "METAL", "TRIM", "SILK"))
    deck_z = 8.4

    # Grounded brass anchor wall bracket & underside cantilevered diagonal struts standing on z = 0.
    box(stone, (14.0, 2.6, deck_z + 0.8), T((0, 5.2, (deck_z + 0.8) * 0.5)), bevel=0.14)
    for sx in (-4.5, 0.0, 4.5):
        strut(metal, (sx, 4.4, 0.6), (sx * 0.85, -4.6, deck_z - 0.4), 0.55)
    # Semicircular cantilevered balcony deck floor.
    box(wood, (13.2, 6.8, 0.85), T((0, 1.4, deck_z)), bevel=0.08)
    cyl_z(wood, 6.6, 0.85, (0, -2.0, deck_z - 0.42), segs=20)
    ring_mesh(trim, 6.75, 0.28, 24, T((0, -2.0, deck_z + 0.35)), tube_segs=5)
    # Curved front brass railing posts around the cantilevered semicircle (-Y side).
    rail_pts = [(math.cos(math.radians(180 + 180 * k / 14)) * 6.45,
                 -2.0 + math.sin(math.radians(180 + 180 * k / 14)) * 6.45, deck_z + 3.2) for k in range(15)]
    tube(trim, rail_pts, [0.24] * len(rail_pts), 6, cap=True)
    for k in range(0, 15, 2):
        p = rail_pts[k]
        strut(metal, (p[0], p[1], deck_z + 0.4), p, 0.22)

    # THE GRAND INDEXER'S ORNATE HIGH-BACKED CHAIR OVERTURNED ON ITS SIDE!
    cm = T((0.6, -2.2, deck_z + 1.45)) @ R(math.radians(78), 4, "Y") @ R(math.radians(28), 4, "Z")
    box(wood, (2.6, 2.6, 0.38), cm)
    box(wood, (2.6, 0.38, 4.2), cm @ T((0, 1.15, 2.2)))
    box(trim, (2.8, 0.44, 0.35), cm @ T((0, 1.15, 4.35)))
    for sx in (-1.05, 1.05):
        for sy in (-1.05, 1.05):
            box(wood, (0.34, 0.34, 2.2), cm @ T((sx, sy, -1.1)))
    # Scattered loose pages sliding off the deck edge.
    for k in range(5):
        box(silk, (1.2, 0.9, 0.08), T((-3.2 + k * 1.6, -3.5 + (k % 2) * 1.4, deck_z + 0.48)) @ R(k * 0.6, 4, "Z"))


# -----------------------------------------------------------------------------------------------------------
# 9. TransitTower — Cylindrical dark-slate observatory transit watchtower (West & East Transit Towers)
# -----------------------------------------------------------------------------------------------------------
@template("TransitTower", STONE=2600, ALT=1800, METAL=1600, TRIM=1400, WOOD=600, GLOW=400)
def transit_tower(t):
    """West and East Transit Tower (seen flanking the far banks in the Floor 45 guide image!): a cylindrical
    24-stud-wide dark-slate & ashlar observatory tower with stepped stone base, brass cornice rings, arched
    oak-and-brass entrance door, meridian slit windows, and a flat observation parapet roof ready to hold a
    TransitInstrument. About 34 studs tall."""
    stone, alt, metal, trim, wood, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "WOOD", "GLOW"))
    R_t, H_t = 11.2, 31.0

    # Stepped circular base plinth & smooth faceted slate cylindrical drum.
    cone(stone, R_t + 1.6, R_t + 0.4, 3.6, 18, T((0, 0, 0)))
    cone(alt, R_t, R_t - 0.5, H_t - 5.6, 18, T((0, 0, 3.6)))
    # Brass meridian string-courses & overhanging stone parapet crown.
    for zb in (3.6, 16.0, H_t - 2.4):
        ring_mesh(metal, R_t + 0.25, 0.42, 24, T((0, 0, zb)), tube_segs=5)
    cone(stone, R_t - 0.3, R_t + 1.2, 2.4, 18, T((0, 0, H_t - 2.4)))
    ring_mesh(trim, R_t + 1.2, 0.38, 24, T((0, 0, H_t + 0.2)), tube_segs=5)
    # Continuous low roof parapet wall around the flat observation deck!
    for k in range(18):
        a = 2 * math.pi * k / 18
        m = R(a, 4, "Z") @ T((R_t + 0.5, 0, H_t + 1.6))
        box(stone, (1.4, 3.8, 2.6), m)
        box(trim, (1.6, 4.0, 0.28), m @ T((0, 0, 1.4)))

    # Arched oak-and-brass front doorway (-Y).
    box(stone, (5.8, 2.4, 8.8), T((0, -(R_t + 0.2), 4.4)), bevel=0.14)
    box(wood, (3.8, 2.7, 7.2), T((0, -(R_t + 0.25), 3.6)))
    ring_mesh(trim, 2.1, 0.26, 16, T((0, -(R_t + 1.4), 7.0)) @ R(math.pi / 2, 4, "X"), tube_segs=5)
    # 4 narrow meridian slit windows around the upper drum.
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        wm = R(a, 4, "Z") @ T((R_t - 0.2, 0, 21.0))
        box(stone, (1.2, 2.2, 5.4), wm)
        box(glow if k < 2 else alt, (0.7, 0.9, 4.2), wm @ T((0.4, 0, 0)))


# -----------------------------------------------------------------------------------------------------------
# 10. TransitInstrument — Precision brass meridian transit telescope on twin stone piers
# -----------------------------------------------------------------------------------------------------------
@template("TransitInstrument", STONE=1400, METAL=2400, TRIM=1800, CRYSTAL=600, GLOW=400)
def transit_instrument(t):
    """A Halcyr meridian transit circle telescope: twin fluted vellum-stone bearing piers carrying a horizontal
    brass trunnion axle, dual graduated brass altitude circles, and a slender meridian transit barrel aimed
    high across the sky meridian. About 14 studs tall."""
    stone, metal, trim, crystal, glow = (t.bm(r) for r in ("STONE", "METAL", "TRIM", "CRYSTAL", "GLOW"))

    # Base slab & twin meridian stone bearing piers.
    box(stone, (10.8, 6.2, 0.9), T((0, 0, 0.45)), bevel=0.1)
    for sx in (-3.6, 3.6):
        box(stone, (2.2, 2.6, 7.2), T((sx, 0, 4.5)), bevel=0.12)
        box(trim, (2.5, 2.9, 0.45), T((sx, 0, 8.2)))
        cyl_x(metal, 0.95, 1.6, (sx, 0, 8.9), segs=12)

    # Horizontal trunnion axle & twin graduated altitude setting circles.
    cyl_x(metal, 0.52, 8.4, (0, 0, 8.9), segs=12)
    for sx in (-2.0, 2.0):
        spoked_gear(trim, metal, 3.1, 0.26, 16, T((sx, 0, 8.9)) @ R(math.pi / 2, 4, "Y"), spokes=6)

    # Slender stepped brass meridian transit tube pitched at 35 deg elevation!
    tm = T((0, 0, 8.9)) @ R(math.radians(55), 4, "X")
    cone(trim, 0.42, 0.58, 3.2, 12, tm @ T((0, 0, -5.8)))
    cone(metal, 0.65, 1.05, 9.4, 14, tm @ T((0, 0, -2.8)))
    cone(trim, 1.08, 1.24, 2.0, 14, tm @ T((0, 0, 6.6)))
    cone(crystal, 1.12, 1.12, 0.22, 14, tm @ T((0, 0, 8.4)))
    uvsphere(glow, 0.38, tm @ T((0, 0, 8.45)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 11. LensBench — Lens Gallery optical grinding workbench with rows of lenses turned toward the Rift!
# -----------------------------------------------------------------------------------------------------------
@template("LensBench", WOOD=1600, METAL=1800, TRIM=1400, CRYSTAL=1600, STONE=700, GLOW=400)
def lens_bench(t):
    """Lens Gallery's optical grinding bench (seen arranged in rows on the middle-right terrace of the Floor
    45 guide image!): a heavy ebony workbench fitted with three brass gimbal-mounted star-glass lenses all
    turned to face the Rift (-Y), polishing stone bowls, and a low brass alignment rail."""
    wood, metal, trim, crystal, stone, glow = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "CRYSTAL", "STONE", "GLOW"))

    # Heavy timber workbench frame.
    for sx in (-4.8, 4.8):
        for sy in (-1.5, 1.5):
            box(wood, (0.55, 0.55, 3.4), T((sx, sy, 1.7)))
        strut(wood, (sx, -1.5, 1.0), (sx, 1.5, 1.0), 0.28)
    strut(wood, (-4.8, 0, 1.0), (4.8, 0, 1.0), 0.32)
    box(wood, (11.2, 3.8, 0.48), T((0, 0, 3.55)), bevel=0.06)
    box(metal, (11.4, 4.0, 0.16), T((0, 0, 3.82)))

    # Three brass gimbal-mounted optical lenses mounted along the bench, all aimed toward -Y (the Rift)!
    for idx, (lx, lr) in enumerate(((-3.4, 1.45), (0.0, 1.85), (3.4, 1.45))):
        cyl_z(metal, 0.65, 0.45, (lx, 0.2, 3.85), segs=10)
        strut(metal, (lx, 0.2, 4.2), (lx, 0.2, 5.4), 0.26)
        lz = 5.4 + lr
        lm = T((lx, 0.2, lz)) @ R(math.pi / 2, 4, "X")
        ring_mesh(metal, lr, 0.20, 22, lm, tube_segs=5)
        ring_mesh(trim, lr + 0.18, 0.09, 22, lm, tube_segs=4)
        uvsphere(crystal, lr * 0.92, T((lx, 0.2, lz)) @ Matrix.Diagonal((1.0, 0.24, 1.0, 1.0)), 14, 10)
        if idx == 1:
            uvsphere(glow, 0.35, T((lx, -0.05, lz)), 8, 6)

    # Grinding stone lap bowl & brass calipers on the front work edge.
    cone(stone, 0.85, 1.1, 0.55, 12, T((-1.8, -1.1, 3.85)))
    cone(stone, 0.72, 0.92, 0.48, 12, T((1.9, -1.0, 3.85)))


# -----------------------------------------------------------------------------------------------------------
# 12. FallenOrrery — Orrery Crest's great observatory orrery toppled on its side with scattered planets!
# -----------------------------------------------------------------------------------------------------------
@template("FallenOrrery", STONE=1800, ALT=1800, METAL=3400, TRIM=2600, GLOW=700)
def fallen_orrery(t):
    """Orrery Crest's shattered centrepiece (seen on the far-right platform of the Floor 45 guide image!):
    the Observatory's grand brass armillary-orrery toppled violently at a 38-degree crash angle onto a cracked
    stepped plinth, its outer rings buckled, and three banded planet globes snapped loose and rolled across
    the flagstones."""
    stone, alt, metal, trim, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "GLOW"))

    # Cracked stepped stone pedestal base.
    cone(stone, 10.5, 9.8, 1.4, 20, T((0, 0, 0)))
    cone(alt, 8.8, 8.4, 1.0, 20, T((0, 0, 1.4)))
    ring_mesh(trim, 9.0, 0.26, 24, T((0, 0, 2.4)), tube_segs=5)

    # Toppled & buckled great brass orrery crashed sideways at 38 degrees!
    om = T((-1.4, 0.8, 11.4)) @ R(math.radians(38), 4, "Y") @ R(math.radians(16), 4, "X")
    # Broken brass pedestal stem.
    cone(metal, 2.2, 1.4, 9.5, 12, T((0, 0, 2.2)) @ R(math.radians(32), 4, "Y"))
    # Buckled interlocking brass orrery rings (one snapped open!).
    ring_mesh(metal, 9.4, 0.58, 32, om, tube_segs=6)
    ring_mesh(trim, 8.4, 0.48, 30, om @ R(math.pi / 2, 4, "X"), tube_segs=6)
    ring_mesh(metal, 7.6, 0.44, 28, om @ R(math.pi / 2, 4, "Y") @ R(0.45, 4, "Z"), tube_segs=5)
    # Snapped partial outer ecliptic arc jutting brokenly upward!
    pts = [(math.cos(math.radians(-20 + 215 * k / 18)) * 10.4, math.sin(math.radians(-20 + 215 * k / 18)) * 10.4, 0) for k in range(19)]
    tube(trim, pts, [0.46] * len(pts), 6, mat=om @ R(0.6, 4, "X"), cap=True)
    # Dimmed central brass sun globe & broken axle spear.
    uvsphere(trim, 2.6, om, 14, 10)
    uvsphere(glow, 1.2, om @ T((0, -2.1, 0)), 8, 6)
    strut(metal, om @ Vector((0, 0, -11.0)), om @ Vector((0, 0, 11.5)), 0.36)

    # Three banded planet globes rolled loose onto the flagstones around the crashed base!
    banded_planet(alt, trim, metal, (10.2, -4.5, 2.2), 2.1, has_ring=True, ring_tilt=0.45)
    banded_planet(metal, trim, metal, (-9.8, -5.2, 1.5), 1.45, has_ring=False)
    banded_planet(alt, trim, metal, (6.4, 7.8, 1.7), 1.65, has_ring=True, ring_tilt=-0.3)


# -----------------------------------------------------------------------------------------------------------
# 13. StarLecternGrand — Star-Lectern circular podium with the catalogue open at its very last page!
# -----------------------------------------------------------------------------------------------------------
@template("StarLecternGrand", STONE=1800, ALT=1200, METAL=1800, TRIM=1800, SILK=900, GLOW=800)
def star_lectern_grand(t):
    """The Star-Lectern on the near-west bank (seen directly on the mid-left terrace of the Floor 45 guide
    image!): a wide circular lapis-and-gold inlaid meridian podium cradling a grand turned brass lectern
    pedestal holding the oversized Halcyr Star-Catalogue open at its very last page."""
    stone, alt, metal, trim, silk, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "SILK", "GLOW"))

    # Wide circular meridian floor podium (R = 8.4).
    cone(stone, 8.4, 8.1, 0.65, 24, T((0, 0, 0)))
    cyl_z(alt, 7.4, 0.25, (0, 0, 0.65), segs=24)
    ring_mesh(trim, 7.5, 0.20, 28, T((0, 0, 0.92)), tube_segs=5)
    ring_mesh(trim, 4.6, 0.16, 24, T((0, 0, 0.92)), tube_segs=4)
    for k in range(4):
        a = k * math.pi / 2
        strut(trim, (math.cos(a) * 4.6, math.sin(a) * 4.6, 0.9), (math.cos(a) * 7.4, math.sin(a) * 7.4, 0.9), 0.18)

    # Grand turned brass lectern column & flared winged cradle.
    cone(stone, 2.8, 2.3, 1.2, 12, T((0, 0, 0.9)))
    lathe(metal, [(1.6, 2.1), (0.85, 4.2), (1.25, 5.4), (0.8, 6.2), (2.2, 7.4)], 14, Matrix.Identity(4))
    lm = T((0, 0, 7.8)) @ R(math.radians(-22), 4, "X")
    box(trim, (6.2, 4.4, 0.35), lm)
    # The Star-Catalogue open at its very last page (left thick block of finished pages, right single last sheet!).
    open_tome(alt, silk, trim, lm @ T((0, 0, 0.28)), w=5.4, d=3.6, page_h=0.85, spread=0.26)
    uvsphere(glow, 0.72, lm @ T((0, 0, 1.55)), 10, 8)


# -----------------------------------------------------------------------------------------------------------
# 14. InkPoolDecal — Ink Pools sculpted recessed star-ink basin with glowing star-glyphs
# -----------------------------------------------------------------------------------------------------------
@template("InkPoolDecal", STONE=1400, ALT=1200, CRYSTAL=1200, TRIM=900, GLOW=900)
def ink_pool_decal(t):
    """The Ink Pools' recessed archive star-ink basin (seen as three glowing dark pools beside the Star-
    Lectern in the Floor 45 guide image!): a low bevelled stone basin rim filled with glossy deep indigo
    star-ink etched with glowing star-glyph rings and rising pinpoint starlight flecks."""
    stone, alt, crystal, trim, glow = (t.bm(r) for r in ("STONE", "ALT", "CRYSTAL", "TRIM", "GLOW"))
    R_p = 6.2

    # Low bevelled stone basin rim (stands cleanly on z = 0..0.95).
    for k in range(20):
        a = 2 * math.pi * k / 20
        m = R(a, 4, "Z") @ T((R_p, 0, 0.45))
        box(stone, (1.4, 2.15, 0.9), m, bevel=0.08)
    ring_mesh(trim, R_p - 0.65, 0.16, 24, T((0, 0, 0.92)), tube_segs=5)
    # Glossy indigo ink surface & star-glass sheen (stands cleanly on z >= 0).
    cyl_z(alt, R_p - 0.6, 0.40, (0, 0, 0.20), segs=20)
    cyl_z(crystal, R_p - 0.7, 0.16, (0, 0, 0.48), segs=20)
    # Glowing star-glyphs written inside the pooled ink!
    ring_mesh(glow, 3.2, 0.12, 20, T((0, 0, 0.64)), tube_segs=4)
    for k in range(4):
        a = k * math.pi / 2
        strut(glow, (math.cos(a) * 0.6, math.sin(a) * 0.6, 0.64), (math.cos(a) * 4.4, math.sin(a) * 4.4, 0.64), 0.16)
    uvsphere(glow, 0.45, T((0, 0, 0.70)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 15. ToppledCabinetRange — Fallen Catalogue toppled card-catalogue cabinets spilling toward the Rift!
# -----------------------------------------------------------------------------------------------------------
@template("ToppledCabinetRange", WOOD=2600, TRIM=1600, METAL=1200, SILK=1800, STONE=600)
def toppled_cabinet_range(t):
    """The Fallen Catalogue (seen sliding toward the east Rift tip in the foreground-right of the Floor 45
    guide image!): a whole range of three tall ebony-and-brass card-catalogue cabinets — one listing sharply,
    two crashed down at jagged angles — with drawers burst open pouring ivory cards and pages toward the Rift."""
    wood, trim, metal, silk, stone = (t.bm(r) for r in ("WOOD", "TRIM", "METAL", "SILK", "STONE"))
    rng = random.Random(4515)

    def _mini_cabinet(mat, open_mask):
        box(wood, (6.2, 3.4, 8.6), mat @ T((0, 0, 4.3)), bevel=0.06)
        box(trim, (6.5, 3.7, 0.42), mat @ T((0, 0, 8.7)))
        for sx in (-3.05, 3.05):
            box(metal, (0.35, 3.5, 8.6), mat @ T((sx, 0, 4.3)))
        for col in range(3):
            cx = -1.9 + col * 1.9
            for row in range(4):
                cz = 1.4 + row * 1.9
                pull = 1.6 if (col, row) in open_mask else 0.0
                box(wood, (1.6, 0.3 + pull, 1.5), mat @ T((cx, -1.7 - pull * 0.5, cz)))
                box(trim, (0.68, 0.16, 0.26), mat @ T((cx, -1.88 - pull, cz)))
                if pull > 0.5:
                    box(silk, (1.3, 0.85, 1.1), mat @ T((cx, -1.75 - pull * 0.55, cz + 0.2)))

    # Cabinet 1 (back-left): still standing but canted 16 deg toward the Rift!
    _mini_cabinet(T((-5.2, 1.8, 0.95)) @ R(0.25, 4, "Z") @ R(math.radians(-16), 4, "X"), {(0, 2), (2, 3), (1, 1)})
    # Cabinet 2 (centre): fallen 62 deg forward onto rubble & crates!
    _mini_cabinet(T((1.2, 0.4, 3.1)) @ R(-0.18, 4, "Z") @ R(math.radians(-62), 4, "X"), {(1, 2), (2, 1), (0, 3)})
    # Cabinet 3 (east): crashed completely flat on its back/side!
    _mini_cabinet(T((7.4, -1.8, 3.2)) @ R(-0.65, 4, "Z") @ R(math.radians(82), 4, "Y"), {(0, 1), (1, 3)})

    # Spilled cascade of index cards & loose pages sliding downhill toward -Y.
    for k in range(28):
        box(silk, (rng.uniform(0.65, 1.25), rng.uniform(0.8, 1.4), 0.07),
            T((rng.uniform(-9.5, 10.5), rng.uniform(-7.2, 2.2), 0.05 + (k % 3) * 0.04)) @ R(rng.uniform(0, math.pi), 4, "Z"))
    slab_stone(stone, (6.0, 4.0, 0.6), (0.8, 1.5, 0.25), seed=4516, roughness=0.2)


# -----------------------------------------------------------------------------------------------------------
# 16. ProofPress — Proof Room galley press & table with the catalogue's last proofs (one glaring blank sheet!)
# -----------------------------------------------------------------------------------------------------------
@template("ProofPress", WOOD=1800, METAL=2200, TRIM=1400, SILK=1400, ALT=900, GLOW=400)
def proof_press(t):
    """The Proof Room's final press vignette (seen on the near-south terrace of the Floor 45 guide image!):
    a heavy brass-and-ebony flat-bed galley proof press beside a proof inspection table stacked with freshly
    printed dark-inked catalogue sheets — and ONE glaring, untouched blank ivory vellum sheet lying alone
    front-and-centre (the unwritten Rift entry!)."""
    wood, metal, trim, silk, alt, glow = (t.bm(r) for r in ("WOOD", "METAL", "TRIM", "SILK", "ALT", "GLOW"))

    # Flat-bed brass galley proof press on the left (-X).
    px = -3.4
    box(wood, (6.4, 4.4, 3.0), T((px, 0, 1.5)), bevel=0.06)
    box(metal, (6.8, 4.6, 0.45), T((px, 0, 3.2)))
    for sy in (-2.0, 2.0):
        box(metal, (1.2, 0.48, 3.2), T((px - 0.6, sy, 4.8)))
    cyl_y(trim, 0.8, 4.4, (px - 0.6, 0, 4.8), segs=14)
    spoked_gear(metal, trim, 1.75, 0.32, 12, T((px - 0.6, -2.55, 4.8)) @ R(math.pi / 2, 4, "X"), spokes=5)
    box(alt, (4.2, 3.0, 0.2), T((px, 0, 3.52)))
    box(silk, (2.2, 2.6, 0.08), T((px + 1.4, 0, 3.66)))

    # Proof inspection table on the right (+X) holding inked proof stacks + THE ONE BLANK SHEET!
    tx = 3.8
    for sx in (-2.6, 2.6):
        for sy in (-1.5, 1.5):
            box(wood, (0.45, 0.45, 3.1), T((tx + sx, sy, 1.55)))
    box(wood, (6.2, 3.8, 0.36), T((tx, 0, 3.25)), bevel=0.05)
    # Stack of heavily inked proofs on back-left of the table.
    for k in range(5):
        box(silk, (2.2, 1.6, 0.14), T((tx - 1.4, 0.6, 3.5 + k * 0.15)) @ R(0.1 * k, 4, "Z"))
        box(alt, (1.7, 1.15, 0.06), T((tx - 1.4, 0.6, 3.58 + k * 0.15)) @ R(0.1 * k, 4, "Z"))
    # THE ONE BLANK SHEET lying pristine & faintly lit front-right on the table!
    box(silk, (2.4, 1.85, 0.12), T((tx + 1.2, -0.4, 3.50)) @ R(-0.12, 4, "Z"))
    box(trim, (2.55, 2.0, 0.06), T((tx + 1.2, -0.4, 3.45)) @ R(-0.12, 4, "Z"))
    uvsphere(glow, 0.26, T((tx + 1.2, -0.4, 3.85)), 8, 6)


# -----------------------------------------------------------------------------------------------------------
# 17. MeridianFooting — Observing Floor curved boss-dais rim balustrade & azimuth-ring anchor footing
# -----------------------------------------------------------------------------------------------------------
@template("MeridianFooting", STONE=2200, ALT=1200, METAL=1800, TRIM=1800, GLOW=800)
def meridian_footing(t):
    """Curved outer-edge rim segment for the 204x152 Observing Floor boss dais (seen ringing the circular
    boss arena cleanly in the Floor 45 guide image without encroaching on the combat space!): a 34-stud-long
    curved stone-and-lapis dais parapet with classical turned balusters, gilded handrail, two brass azimuth-
    ring footing piers, and a glowing pale-gold rune-ring medallion inlaid on the inner meridian edge."""
    stone, alt, metal, trim, glow = (t.bm(r) for r in ("STONE", "ALT", "METAL", "TRIM", "GLOW"))
    R_arc = 76.0
    span_deg = 26.0
    segs = 10

    # Curved vellum-stone & lapis curb rim with classical balusters.
    for k in range(segs):
        a = math.radians(-span_deg / 2 + span_deg * (k + 0.5) / segs)
        cx = math.sin(a) * R_arc
        cy = (math.cos(a) - 1.0) * R_arc
        seg_w = (2 * math.pi * R_arc * span_deg / 360) / segs + 0.4
        m = T((cx, cy, 0.0)) @ R(-a, 4, "Z")
        box(stone, (seg_w, 3.2, 1.2), m @ T((0, 0, 0.6)), bevel=0.08)
        box(alt, (seg_w, 2.0, 0.35), m @ T((0, -1.8, 0.18)))
        box(trim, (seg_w, 0.35, 0.25), m @ T((0, -1.8, 0.4)))
        balustrade_post(stone, trim, cx, cy, 1.2, h=2.8)
        box(trim, (seg_w + 0.1, 0.7, 0.32), m @ T((0, 0, 4.1)))

    # Twin heavier brass-and-stone azimuth anchor footing piers at both ends (+/- 13 deg).
    for sx in (-1, 1):
        a = math.radians(sx * span_deg * 0.5)
        px = math.sin(a) * R_arc
        py = (math.cos(a) - 1.0) * R_arc
        pm = T((px, py, 0.0)) @ R(-a, 4, "Z")
        box(stone, (3.6, 4.2, 4.8), pm @ T((0, 0, 2.4)), bevel=0.14)
        box(metal, (3.9, 4.5, 0.75), pm @ T((0, 0, 4.9)))
        ring_mesh(trim, 1.35, 0.22, 16, pm @ T((0, 0, 5.5)), tube_segs=5)
        uvsphere(glow, 0.55, pm @ T((0, 0, 6.2)), 8, 6)

    # Central glowing boss-summon rune-ring node inlaid on the inner rim face!
    ring_mesh(glow, 2.2, 0.16, 20, T((0, -3.2, 0.35)), tube_segs=4)
    ring_mesh(trim, 2.8, 0.12, 20, T((0, -3.2, 0.35)), tube_segs=4)


if __name__ == "__main__":
    kit, manifest = build_kit("AstralF45Kit", F45_TEMPLATES, DEFAULT_BUDGET)
    apply_halcyr_preview_materials(kit)
    export_kit(kit, manifest, OUT_DIR, "AstralF45Kit")
    render_previews(kit, F45_TEMPLATES, OUT_DIR)
    print(json.dumps(manifest, indent=2))
