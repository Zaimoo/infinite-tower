"""
Writes src/ReplicatedStorage/Assets/SwordBowMeshData.luau for the SWORD_SHIELD and BOW remodel.

Inputs:
    assets/artifacts/sword_shield/sword_shield_manifest.json   (tools/blender/generate_vanguard_swords.py)
    assets/artifacts/bow/bows_manifest.json                     (tools/blender/generate_marksman_bows.py)
    assets/artifacts/sword_bow_mesh_ids.txt                     (MeshIds read back from the Studio 3D Importer)

Studio's importer maps a Blender point (x, y, z) to Roblox (-x, z, y) and keeps every MeshPart
unrotated, so a part's Handle-space offset and size, and every socket, follow from the manifest.
The mesh-id file also records where each part landed in the import; this script checks them
against the manifest and refuses to write if any part is more than 0.002 studs off.

    python tools/apply_sword_bow_mesh_ids.py
"""

import json
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
MANIFESTS = [
    os.path.join(REPO, "assets", "artifacts", "sword_shield", "sword_shield_manifest.json"),
    os.path.join(REPO, "assets", "artifacts", "bow", "bows_manifest.json"),
]
MESH_IDS = os.path.join(REPO, "assets", "artifacts", "sword_bow_mesh_ids.txt")
OUT = os.path.join(REPO, "src", "ReplicatedStorage", "Assets", "SwordBowMeshData.luau")
IMPORT_UNITS = 10000.0  # mesh-id file positions: raw import (cm) recorded x 100
PART_ORDER = {
    "SWORD_SHIELD": ["Handle", "Pommel", "Crossguard", "Blade", "BladeEdge", "Fuller", "RuneInlay",
                     "HandleS", "ShieldPlate", "ShieldRim", "ShieldBoss", "ShieldRune"],
    "BOW": ["Handle", "GripWrap", "LimbUpper", "LimbLower", "Fittings", "Ornament", "RuneInlay", "BowString",
            "ArrowShaft", "ArrowHead", "ArrowFletch"],
}


def to_roblox(v):
    """Blender vector -> Roblox Handle space as the Studio importer lays it out."""
    return (-v[0], v[2], v[1])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def vec(v):
    return f"Vector3.new({v[0] + 0.0:.4f}, {v[1] + 0.0:.4f}, {v[2] + 0.0:.4f})"


def rot_y(legacy_deg):
    """The importer's frame is the legacy WeaponModelBuilder frame turned 180 degrees about Y."""
    r = (legacy_deg + 180.0) % 360.0
    return r - 360.0 if r > 180.0 else r


def sockets_for(info):
    t = info["type"]
    if t == "SWORD_SHIELD":
        return [
            ("Grip", "Handle", info["grip"], -90),  # up = blade, look = edge (EDGE_PLUS_X)
            ("Tip", "Handle", info["tip"], 0),
            ("VfxTip", "Handle", info["tip"], 0),
            ("VfxBase", "Handle", info["base"], 0),
            ("VfxCore", "Handle", info["core"], 0),
            ("ShieldMount", "HandleS", info["shield_mount"], 90),  # looks out through the face
            ("VfxShieldCenter", "HandleS", info["shield_centre"], 0),
        ]
    return [
        ("Grip", "Handle", info["grip"], 0),  # up = upper limb, look = arrow flight
        ("Nock", "Handle", info["nock"], 0),
        ("TipUpper", "Handle", info["tip_upper"], 0),
        ("TipLower", "Handle", info["tip_lower"], 0),
        ("VfxTip", "Handle", info["tip_upper"], 0),
        ("VfxBase", "Handle", info["tip_lower"], 0),
        ("VfxCore", "Handle", info["core"], 0),
        ("VfxNock", "Handle", info["nock"], 0),
    ]


def load_mesh_ids():
    out = {}
    with open(MESH_IDS, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            wid, rest = line.split("|")
            parts = {}
            for item in rest.split(";"):
                name, val = item.split("=")
                mesh, pos = val.split("@")
                parts[name] = (mesh, tuple(float(p) / IMPORT_UNITS for p in pos.split(",")))
            out[wid] = parts
    return out


def main():
    manifest = {}
    for path in MANIFESTS:
        with open(path, encoding="utf-8") as fh:
            manifest.update(json.load(fh))
    meshes = load_mesh_ids()

    blocks, problems = [], []
    for wid in sorted(manifest):
        info = manifest[wid]
        if wid not in meshes:
            problems.append(f"{wid}: no mesh ids")
            continue
        parts = info["parts"]
        h0 = parts["Handle"]["centre"]
        lines = [f"\t{wid} = {{", f'\t\tType = "{info["type"]}",', f"\t\tRarityTier = {info['tier']},", "\t\tParts = {"]
        for name in PART_ORDER[info["type"]]:
            if name not in parts:
                continue
            p = parts[name]
            if name not in meshes[wid]:
                problems.append(f"{wid}.{name}: no mesh id")
                continue
            mesh, landed = meshes[wid][name]
            offset = to_roblox(sub(p["centre"], h0))
            err = max(abs(offset[i] - landed[i]) for i in range(3))
            if err > 0.002:
                problems.append(f"{wid}.{name}: import landed {err:.4f} studs from the manifest")
            s = p["size"]
            c = p["color"]
            transparency = 0.12 if p["material"] == "Glass" else 0
            lines.append(
                f'\t\t\t{{ Name = "{name}", Assembly = "{p["assembly"]}", MeshId = "rbxassetid://{mesh}", '
                f"Size = {vec((s[0], s[2], s[1]))}, Offset = {vec(offset)}, Material = Enum.Material.{p['material']}, "
                f"Color = Color3.fromRGB({c[0]}, {c[1]}, {c[2]}), Transparency = {transparency} }},"
            )
        lines.append("\t\t},")
        lines.append("\t\tSockets = {")
        for sname, pname, point, legacy in sockets_for(info):
            if pname not in parts:
                continue
            pos = to_roblox(sub(point, parts[pname]["centre"]))
            lines.append(f'\t\t\t{{ Name = "{sname}", Part = "{pname}", Position = {vec(pos)}, RotationY = {rot_y(legacy):g} }},')
        lines.append("\t\t},")
        lines.append("\t},")
        blocks.append("\n".join(lines))

    if problems:
        raise SystemExit("Refusing to write SwordBowMeshData:\n  " + "\n  ".join(problems))

    header = """--!strict
-- ReplicatedStorage/Assets/SwordBowMeshData.luau
-- GENERATED by tools/apply_sword_bow_mesh_ids.py - do not hand-edit. Regenerate after re-running
-- tools/blender/generate_vanguard_swords.py or generate_marksman_bows.py and re-importing the FBX
-- files (docs/prompts/artifact-remodel-prompt.md).
--
-- Uploaded meshes for the 14 Vanguard SWORD_SHIELD and 14 Marksman BOW artifacts. Offsets and
-- sizes are in studs in the Handle's space, which is the Studio importer's frame: the legacy
-- WeaponModelBuilder frame turned 180 degrees about Y (sword blade +Y with its edge towards -X,
-- shield face +X, bow arrow flying +Z). Sockets keep the runtime meaning (sword Grip looks at the
-- edge, ShieldMount looks out through the face, bow Grip looks along the arrow); RotationY is the
-- socket's turn about Y in its part's space. Assembly "" is the main weapon; "OffhandShield" and
-- "HunterArrow" are sub-models whose primaries are HandleS and ArrowShaft.

export type PartData = {
	Name: string,
	Assembly: string,
	MeshId: string,
	Size: Vector3,
	Offset: Vector3,
	Material: Enum.Material,
	Color: Color3,
	Transparency: number,
}

export type SocketData = {
	Name: string,
	Part: string,
	Position: Vector3,
	RotationY: number,
}

export type WeaponData = {
	Type: "SWORD_SHIELD" | "BOW",
	RarityTier: number,
	Parts: { PartData },
	Sockets: { SocketData },
}

local SwordBowMeshData: { [string]: WeaponData } = {
"""
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(header + "\n".join(blocks) + "\n}\n\nreturn table.freeze(SwordBowMeshData)\n")
    print(f"wrote {OUT} ({len(blocks)} weapons)")


main()
