"""Print the signature of an exported hair mesh, to compare with the uploaded asset.

    python -I .claude/skills/hero-remodel/scripts/export_signature.py <hero>

Reads assets/hair/<hero>_hair.json and prints the vertex count and the max-X vertex relative
to the bounding-box centre, times 100 (the importer stores meshes in centimetres).

The "verify mesh" snippet in references/studio-snippets.md prints the uploaded mesh's vertex
count and its min-X vertex. They match when the counts are equal and the min-X vertex equals
this max-X vertex with X and Z negated (the importer turns meshes 180 degrees about Y).
"""

import json
import sys
from pathlib import Path

hero = sys.argv[1].lower()
path = Path(__file__).resolve().parents[4] / "assets" / "hair" / f"{hero}_hair.json"
verts = json.loads(path.read_text(encoding="utf-8"))["verts"]
centre = [(min(v[i] for v in verts) + max(v[i] for v in verts)) / 2 for i in range(3)]
top = max(verts, key=lambda v: v[0])
rel = [round((top[i] - centre[i]) * 100, 2) for i in range(3)]
print(f"{path.name}: {len(verts)} vertices")
print(f"max-X vertex (x100, centred): {rel}")
print(f"expect uploaded min-X vertex: {[-rel[0], rel[1], -rel[2]]}")
