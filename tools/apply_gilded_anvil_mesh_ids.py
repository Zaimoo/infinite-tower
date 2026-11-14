"""Write uploaded Gilded Anvil MeshIds into the generated Luau shards and the manifest.

Pipeline (docs/gilded-anvil-plan.md, "Mesh upload"):
  1. Import the six assets/artifacts/gilded_anvil/art_gild_*.fbx files in Studio (File > Import 3D).
  2. Run tests/studio-gilded-anvil-import.luau through Studio MCP. Its last line is a JSON map
     { templateId: { PartName: "rbxassetid://..." } }.
  3. Save that JSON as assets/artifacts/gilded_anvil/mesh_ids.json and run:
       python3 tools/apply_gilded_anvil_mesh_ids.py

The script only rewrites the `MeshId = "..."` field of each part, so it needs no Blender.
tools/blender/generate_gilded_anvil_weapons.py reads the same mesh_ids.json, so a full
re-export keeps the IDs as long as the part geometry did not change (re-upload if it did).
"""

import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART_DIR = os.path.join(REPO, "assets", "artifacts", "gilded_anvil")
IDS_PATH = os.path.join(ART_DIR, "mesh_ids.json")
MANIFEST_PATH = os.path.join(ART_DIR, "manifest.json")
SHARDS_DIR = os.path.join(REPO, "src", "ReplicatedStorage", "Assets", "GildedAnvilMeshes")

ID_RE = re.compile(r"^rbxassetid://\d+$")
NAME_RE = re.compile(r'Name = "([^"]+)", SubCollection')
MESHID_RE = re.compile(r'MeshId = "[^"]*"')


def load_ids(path):
    with open(path, encoding="utf-8") as f:
        raw = json.load(f)
    ids = {}
    for tid, parts in raw.items():
        ids[tid] = {}
        for name, mid in parts.items():
            mid = str(mid).strip()
            if mid.isdigit():
                mid = f"rbxassetid://{mid}"
            if mid and not ID_RE.match(mid):
                sys.exit(f"{tid}.{name}: '{mid}' is not an rbxassetid:// MeshId")
            ids[tid][name] = mid
    return ids


def patch_shard(tid, part_ids):
    path = os.path.join(SHARDS_DIR, f"{tid}.luau")
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    current, seen, written = None, set(), 0
    for i, line in enumerate(lines):
        m = NAME_RE.search(line)
        if m:
            current = m.group(1)
            seen.add(current)
            continue
        if current and "MeshId = " in line:
            mid = part_ids.get(current, "")
            lines[i] = MESHID_RE.sub(f'MeshId = "{mid}"', line)
            written += 1 if mid else 0
            current = None
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    return seen, written


def main():
    if not os.path.exists(IDS_PATH):
        sys.exit(f"Missing {IDS_PATH}")
    ids = load_ids(IDS_PATH)
    with open(MANIFEST_PATH, encoding="utf-8") as f:
        manifest = json.load(f)

    problems = []
    for tid, entry in manifest.items():
        part_ids = ids.get(tid, {})
        seen, written = patch_shard(tid, part_ids)
        for part in entry["Parts"]:
            part["MeshId"] = part_ids.get(part["Name"], "")
        missing = sorted(seen - {n for n, v in part_ids.items() if v})
        unknown = sorted(set(part_ids) - seen)
        if missing:
            problems.append(f"{tid}: no MeshId for {', '.join(missing)} (falls back to EditableMesh)")
        if unknown:
            problems.append(f"{tid}: ids for unknown parts {', '.join(unknown)}")
        print(f"{tid:28s} {written}/{len(seen)} parts wired")

    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    for p in problems:
        print("WARN", p)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
