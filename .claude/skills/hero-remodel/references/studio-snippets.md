# Studio MCP snippets for hero remodels

Run with `execute_luau` in the **Edit** DataModel (EditableMesh reads are blocked on the client,
and Edit isn't available during a playtest). Get the `studio_id` from `list_roblox_studios`;
it changes when Studio restarts.

## Verify an uploaded hair mesh

Compare with `scripts/export_signature.py <hero>`: same vertex count, and this min-X vertex
equals the export's max-X vertex with X and Z negated.

```lua
local AssetService = game:GetService("AssetService")
local em = AssetService:CreateEditableMeshAsync(Content.fromUri("rbxassetid://MESH_ID"))
local minX, n = nil, 0
for _, id in em:GetVertices() do
	local p = em:GetPosition(id); n += 1
	if not minX or p.X < minX.X then minX = p end
end
return string.format("n=%d minX=%s", n, tostring(minX))
```

## Temp rig: costume, weapon and idle pose

Set `HERO`, `WEAPON` (the archetype weapon type), `BUILD` (the `WeaponModelBuilder` function)
and `CHECK` (a piece name and value you just changed, so the snippet stops if Rojo hasn't
synced yet). The rig is built high up at y 603 so it doesn't collide with the map; the head is
at about y 605.4.

```lua
local HERO, WEAPON, BUILD = "hero_solaris", "STAFF", "BuildStaff"
local CHECK_PIECE, CHECK_X = "BannerL", -3.25
task.wait(2) -- give Rojo a moment after an edit
local RS = game:GetService("ReplicatedStorage")
local fresh = RS.Assets.HeroRig:Clone() -- a clone: the command bar caches required modules
local Builder = require(fresh.HeroRigBuilder)
local CostumeBuilder = require(fresh.HeroCostumeBuilder)
local Costumes = require(fresh.HeroCostumes)
local Sockets = require(fresh.HeroSockets)
local Clips = require(fresh.HeroClips)
local Animator = require(fresh.HeroAnimator)
local Weapons = require(RS.Assets.WeaponModelBuilder)
local c = Costumes.ById[HERO]
local x
for _, p in c.Pieces do if p.Name == CHECK_PIECE then x = p.Position[1] end end
if x ~= CHECK_X then return "not synced yet: " .. tostring(x) end
local old = workspace:FindFirstChild("ClaudeHairCheck") if old then old:Destroy() end
local rig = Builder.Build({ Name = "ClaudeHairCheck", BodyType = c.BodyType, Pivot = CFrame.new(0, 603, 0) })
CostumeBuilder.Apply(rig, c)
Sockets.Equip(rig, Weapons[BUILD](), WEAPON)
-- Weapon parts hang off their handle with WeldConstraints, which anchored posing ignores:
-- record each part's offset from its own handle (the shield and off-hand dagger have their own).
local weapon = rig:FindFirstChild("EquippedWeapon")
local subs = {}
for _, name in { "OffhandShield", "LeftDagger" } do
	local sub = weapon:FindFirstChild(name)
	if sub and sub:IsA("Model") and sub.PrimaryPart then table.insert(subs, sub) end
end
local followers = {}
for _, d in weapon:GetDescendants() do
	if d:IsA("BasePart") then
		local primary = weapon.PrimaryPart
		for _, s in subs do if d:IsDescendantOf(s) then primary = s.PrimaryPart end end
		if d ~= primary then table.insert(followers, { Part = d, Primary = primary, Offset = primary.CFrame:ToObjectSpace(d.CFrame) }) end
	end
end
for _, p in rig:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true end end
Animator.ApplyStaticPose(rig, Animator.Sample(Clips.Get(HERO, WEAPON, "Idle"), 0))
for _, f in followers do f.Part.CFrame = f.Primary.CFrame * f.Offset end
rig.Parent = workspace
task.wait(2) -- let the face decal and hair mesh load before capturing
return "built " .. c.BodyType
```

Weapon builders: `BuildBow`, `BuildSwordShield`, `BuildDaggers`, `BuildAxe`, `BuildStaff`,
`BuildTome`.

## Camera positions for `screen_capture`

The hero faces -Z. Front is at negative Z, back at positive Z.

| View | camera_position | look_at_position |
| --- | --- | --- |
| Full front (wide items behind) | `[1.2, 605.5, -11]` | `[0, 604.4, 0]` |
| Full front | `[2, 604.8, -6.5]` | `[0, 603.6, 0]` |
| Face close-up | `[-1, 605.5, -3.4]` | `[0, 605.3, 0]` |
| Back | `[1.4, 605.5, 5]` | `[0, 604.5, 0]` |

## Where a piece ended up (in root space)

Useful when something is hidden or out of place.

```lua
local rig = workspace.ClaudeHairCheck
local root = rig.HumanoidRootPart.CFrame
local out = {}
for _, n in { "BannerL", "BannerR" } do
	local p = rig:FindFirstChild(n, true)
	table.insert(out, n .. " " .. tostring(root:PointToObjectSpace(p.Position)))
end
return table.concat(out, "\n")
```

## Clean up

```lua
local n = 0
for _, m in workspace:GetChildren() do if m.Name == "ClaudeHairCheck" then m:Destroy() n += 1 end end
return n .. " removed"
```
