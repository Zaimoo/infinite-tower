--!strict
-- ServerScriptService/Core/HeroAssetSetup.server.luau
-- Ensures all 12 R15 anime hero models exist in ReplicatedStorage.Assets.Heroes on server start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HeroModelBuilder = require(ReplicatedStorage:WaitForChild("Assets"):WaitForChild("HeroModelBuilder"))

local ok, heroes = pcall(function()
	return HeroModelBuilder.EnsureHeroes()
end)

if ok and heroes then
	local count = 0
	for _ in pairs(heroes) do count += 1 end
	print(string.format("[HeroAssetSetup] Verified and populated %d hero models in ReplicatedStorage.Assets.Heroes", count))
else
	warn("[HeroAssetSetup] Failed to populate hero models:", tostring(heroes))
end
