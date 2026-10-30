import os
import sys

# Read studio-hero-model-viewer.luau
with open("tests/studio-hero-model-viewer.luau", "r", encoding="utf-8") as f:
    viewer_code = f.read()

# Wrap and call for Jenna armed
code = f"""
local fn = (function()
{viewer_code}
end)()

local res = fn({{
    Armed = true,
    HeroId = "hero_jenna",
    Origin = Vector3.new(0, 5, 0),
}})

return res
"""

with open("tests/spawn_jenna.luau", "w", encoding="utf-8") as out:
    out.write(code)

print("Created tests/spawn_jenna.luau")
