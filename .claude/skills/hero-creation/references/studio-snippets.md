# Studio MCP snippets for hero creation

Run with `execute_luau` in the **Edit** DataModel. Get the `studio_id` from
`list_roblox_studios` (it changes when Studio restarts). The look snippets (verify a mesh,
temp rig, cameras) are in the `hero-remodel` skill's `references/studio-snippets.md`.

All snippets require a **clone** of `ReplicatedStorage.Assets.HeroRig` (the command bar caches
modules) and wait for Rojo first: check that a value you just changed is in the clone's
`Source` and stop with "not synced" if not. Weapon parts hang off their assembly's primary with
WeldConstraints, which anchored posing ignores, so the snippets carry them along by hand.

## Line-up: one rig per key frame (or per candidate joint value)

Set `HERO`, `WEAPON`, `BUILD` and `FRAMES` (`{ state, fraction, overrides? }`, where overrides
are `{ JointName = { x, y, z } }` in degrees, for trying candidate angles). Rigs stand along X
at y 603; with the camera at −Z looking at +Z, the **first** frame is on the viewer's **left**.

```lua
local HERO, WEAPON, BUILD = "hero_nyx", "DAGGERS", "BuildDaggers"
local CHECK = "backhand sweep" -- text you just added to HeroClips
local FRAMES = {
	{ "Idle", 0 },
	{ "AttackBasic", 0.38 },
	{ "AttackSpecial", 0.48 },
	{ "AttackSkill", 0.3, { RightWrist = { 110, 0, 0 } } },
}
task.wait(2)
local RS = game:GetService("ReplicatedStorage")
local fresh = RS.Assets.HeroRig:Clone()
if not fresh.HeroClips.Source:find(CHECK, 1, true) then return "not synced" end
local Builder = require(fresh.HeroRigBuilder)
local CostumeBuilder = require(fresh.HeroCostumeBuilder)
local Costumes = require(fresh.HeroCostumes)
local Sockets = require(fresh.HeroSockets)
local Clips = require(fresh.HeroClips)
local Animator = require(fresh.HeroAnimator)
local Weapons = require(RS.Assets.WeaponModelBuilder)
for _, m in workspace:GetChildren() do if m.Name:find("ClaudePose") then m:Destroy() end end
local c = Costumes.ById[HERO]
local spacing = 4
for i, fr in FRAMES do
	local x = ((#FRAMES + 1) / 2 - i) * spacing
	local rig = Builder.Build({ Name = "ClaudePose" .. i, BodyType = c.BodyType, Pivot = CFrame.new(x, 603, 0) })
	CostumeBuilder.Apply(rig, c) -- also sets the HeroId attribute, so per-hero grips apply
	Sockets.Equip(rig, Weapons[BUILD](), WEAPON)
	local weapon = rig:FindFirstChild("EquippedWeapon")
	local followers = {}
	for _, d in weapon:GetDescendants() do
		if d:IsA("BasePart") then
			local node, primary = d.Parent, weapon.PrimaryPart
			while node and node ~= weapon do
				if node:IsA("Model") and node.PrimaryPart then primary = node.PrimaryPart break end
				node = node.Parent
			end
			if d ~= primary then table.insert(followers, { Part = d, Primary = primary, Offset = primary.CFrame:ToObjectSpace(d.CFrame) }) end
		end
	end
	for _, p in rig:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true end end
	local pose = Animator.Sample(Clips.Get(HERO, WEAPON, fr[1]), fr[2])
	for joint, v in fr[3] or {} do pose[joint] = CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3])) end
	Animator.ApplyStaticPose(rig, pose)
	for _, f in followers do f.Part.CFrame = f.Primary.CFrame * f.Offset end
	rig.Parent = workspace
end
task.wait(2) -- faces and hair meshes load
return "built " .. #FRAMES
```

Capture: `screen_capture` with `camera_position` `[0, 605, -4 * #FRAMES]` and
`look_at_position` `[0, 603.5, 0]`; for one rig up close, put the camera 6 studs in front of
its X. A rig rotated about Y (`CFrame.new(x, 603, 0) * CFrame.Angles(0, math.rad(-35), 0)`)
shows a three-quarter view in the same line-up.

## Mirror clones around a point

Builds a hero with its weapon, then five `MirrorClones` in a ring, posed from its clips, to
judge the clone look (tint, outline, grip) without a fight.

```lua
task.wait(2)
local RS = game:GetService("ReplicatedStorage")
local assets = RS.Assets:Clone()
local H = assets.HeroRig
local Builder, CostumeBuilder = require(H.HeroRigBuilder), require(H.HeroCostumeBuilder)
local Costumes, Sockets = require(H.HeroCostumes), require(H.HeroSockets)
local Clips, Animator = require(H.HeroClips), require(H.HeroAnimator)
local Weapons = require(RS.Assets.WeaponModelBuilder)
local MirrorClones = require(assets.CombatVfx.MirrorClones)
for _, m in workspace:GetChildren() do if m.Name == "ClaudePose0" or m.Name == "ClaudeClones" then m:Destroy() end end
local c = Costumes.ById.hero_nyx
local rig = Builder.Build({ Name = "ClaudePose0", BodyType = c.BodyType, Pivot = CFrame.new(0, 603, 10) })
CostumeBuilder.Apply(rig, c)
Sockets.Equip(rig, Weapons.BuildDaggers(), "DAGGERS")
rig.Parent = workspace
local folder = Instance.new("Folder"); folder.Name = "ClaudeClones"; folder.Parent = workspace
local cut = Clips.Get("hero_nyx", "DAGGERS", "AttackBasic")
local center = Vector3.new(0, 603, 0)
for i = 1, 5 do
	local a = (i - 1) / 5 * math.pi * 2
	local spot = center + Vector3.new(math.cos(a) * 4.4, 0, math.sin(a) * 4.4)
	local clone = MirrorClones.Make(rig, folder, Color3.fromRGB(40, 226, 196), Color3.fromRGB(212, 175, 90))
	if not clone then return "clone failed" end
	clone.Pose(CFrame.lookAt(spot, center), Animator.Sample(cut, i / 6))
	clone.Fade(0)
end
task.wait(3)
return "clones " .. #folder:GetChildren()
```

Capture from `[0, 610, -13]` looking at `[0, 603, 0]`.

## Clean up

```lua
local n = 0
for _, m in workspace:GetChildren() do
	if m.Name:find("ClaudePose") or m.Name == "ClaudeClones" or m.Name == "ClaudeHairCheck" then m:Destroy() n += 1 end
end
return n .. " removed"
```
