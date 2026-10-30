import json
import os

with open("assets/hair/jenna_hair.json", "r", encoding="utf-8") as f:
    data = json.load(f)

verts = data["verts"]
tris = data["tris"]

lines = []
lines.append("local M = {}")
lines.append("M.verts = {")
for v in verts:
    lines.append(f"{v[0]},{v[1]},{v[2]},")
lines.append("}")
lines.append("M.tris = {")
for t in tris:
    lines.append(f"{t[0]+1},{t[1]+1},{t[2]+1},")
lines.append("}")
lines.append("return M")

out_path = "src/ReplicatedStorage/TempJennaHairData.luau"
with open(out_path, "w", encoding="utf-8") as out:
    out.write("\n".join(lines))

print(f"Generated {out_path} with {len(verts)} verts and {len(tris)} tris")
