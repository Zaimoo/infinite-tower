--!strict
-- ServerScriptService/Core/HeroAssetSetup.server.luau
-- Builds all 12 hero templates into ReplicatedStorage.Assets.Heroes (HeroRegistry: code-built
-- HeroRig + HeroCostumes) and modular 3D weapon models into ReplicatedStorage.Assets.Weapons
-- on server start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Assets = ReplicatedStorage:WaitForChild("Assets")
local HeroRegistry = require(Assets:WaitForChild("HeroRig"):WaitForChild("HeroRegistry"))
local WeaponModelBuilder = require(Assets:WaitForChild("WeaponModelBuilder"))

local okHeroes, heroes = pcall(function()
	return HeroRegistry.EnsureHeroes()
end)

if okHeroes and heroes then
	local count = 0
	for _ in pairs(heroes) do count += 1 end
	print(string.format("[HeroAssetSetup] Verified and populated %d hero models in ReplicatedStorage.Assets.Heroes", count))
else
	warn("[HeroAssetSetup] Failed to populate hero models:", tostring(heroes))
end

local okWeapons, weapons = pcall(function()
	return WeaponModelBuilder.EnsureWeapons()
end)

if okWeapons and weapons then
	local count = 0
	if typeof(weapons) == "Instance" then
		count = #weapons:GetChildren()
	elseif type(weapons) == "table" then
		for _ in pairs(weapons) do count += 1 end
	end
	print(string.format("[HeroAssetSetup] Verified and populated %d weapon models in ReplicatedStorage.Assets.Weapons", count))
else
	warn("[HeroAssetSetup] Failed to populate weapon models:", tostring(weapons))
end
