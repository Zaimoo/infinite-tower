--!strict
-- ReplicatedStorage/Assets/HeroRig/HeroRegistry.luau
-- Builds every hero template from code (hero-rig-rebuild-plan.md, Phase 3): a bare
-- HeroRig dressed with its HeroCostumes entry. The only source of
-- ReplicatedStorage.Assets.Heroes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeroRigBuilder = require(script.Parent:WaitForChild("HeroRigBuilder"))
local HeroCostumes = require(script.Parent:WaitForChild("HeroCostumes"))
local HeroCostumeBuilder = require(script.Parent:WaitForChild("HeroCostumeBuilder"))

local HeroRegistry = {}

-- Builds one hero (unparented). Errors for an unknown hero id.
function HeroRegistry.Build(heroId: string, pivot: CFrame?): Model
	local costume = HeroCostumes.ById[heroId]
	assert(costume, `HeroRegistry: no costume for {heroId}`)
	local rig = HeroRigBuilder.Build({
		Name = heroId,
		BodyType = costume.BodyType,
		SkinColor = Color3.fromRGB(costume.Colors.Skin[1], costume.Colors.Skin[2], costume.Colors.Skin[3]),
		Pivot = pivot,
	})
	HeroCostumeBuilder.Apply(rig, costume)
	return rig
end

-- Rebuilds every hero template into ReplicatedStorage.Assets.Heroes, replacing whatever
-- is there (including templates saved in the place), and returns them by hero id.
function HeroRegistry.EnsureHeroes(): { [string]: Model }
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end
	local heroesFolder = assets:FindFirstChild("Heroes")
	if not heroesFolder then
		heroesFolder = Instance.new("Folder")
		heroesFolder.Name = "Heroes"
		heroesFolder.Parent = assets
	end

	local result: { [string]: Model } = {}
	for _, costume in HeroCostumes.List do
		local ok, built = pcall(HeroRegistry.Build, costume.HeroId)
		if ok then
			local existing = heroesFolder:FindFirstChild(costume.HeroId)
			if existing then
				existing:Destroy()
			end
			built.Parent = heroesFolder
			result[costume.HeroId] = built
		else
			warn(`[HeroRegistry] Failed to build {costume.HeroId}: {built}`)
		end
	end
	return result
end

return table.freeze(HeroRegistry)
