--!strict
-- ServerScriptService/Core/HeroAssetSetup.server.luau
-- Ensures all 12 R15 anime hero models exist in ReplicatedStorage.Assets.Heroes
-- and modular 3D weapon models exist in ReplicatedStorage.Assets.Weapons on server start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroModelBuilder = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HeroModelBuilder"))
local WeaponModelBuilder = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("WeaponModelBuilder"))

local okHeroes, heroes = pcall(function()
	return HeroModelBuilder.EnsureHeroes()
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
	for _ in pairs(weapons) do count += 1 end
	print(string.format("[HeroAssetSetup] Verified and populated %d weapon models in ReplicatedStorage.Assets.Weapons", count))
else
	warn("[HeroAssetSetup] Failed to populate weapon models:", tostring(weapons))
end
