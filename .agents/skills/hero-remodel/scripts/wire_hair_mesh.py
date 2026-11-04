"""Swap a hero's placeholder hair ID for the imported MeshId and allow-list it.

    python -I .claude/skills/hero-remodel/scripts/wire_hair_mesh.py SOLARIS_HAIR_ID 116753377442189 \
        "Solaris's hair, our own: tools/make_solaris_hair_ugc.py (assets/hair/solaris_hair_ugc.blend)."

Replaces rbxassetid://<placeholder> in the hero's HairMesh piece and appends the mesh, with the
comment, as the last entry of HeroCostumes.MESHES. Verify the ID against the export first (see
SKILL.md section 6). Keeps UTF-8 and LF endings.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
COSTUMES = ROOT / "src" / "ReplicatedStorage" / "Assets" / "HeroRig" / "HeroCostumes.luau"

placeholder, mesh_id, comment = sys.argv[1], sys.argv[2].removeprefix("rbxassetid://"), sys.argv[3]
text = COSTUMES.read_bytes().decode("utf-8")

old = f"rbxassetid://{placeholder}"
if text.count(old) != 1:
    sys.exit(f"{old} found {text.count(old)} times; expected exactly once.")
if f'["rbxassetid://{mesh_id}"]' in text:
    sys.exit(f"rbxassetid://{mesh_id} is already in MESHES; is this another hero's mesh?")
text = text.replace(old, f"rbxassetid://{mesh_id}")

close = "} :: { [string]: string })"
at = text.index(close, text.index("HeroCostumes.MESHES"))
entry = f'\t-- {comment}\n\t["rbxassetid://{mesh_id}"] = "",\n'
text = text[:at] + entry + text[at:]

COSTUMES.write_bytes(text.encode("utf-8"))
print(f"Wired rbxassetid://{mesh_id} in place of {placeholder} and allow-listed it.")
