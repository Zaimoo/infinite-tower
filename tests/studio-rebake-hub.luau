-- studio-rebake-hub.luau
-- Paste into Studio's command bar in EDIT mode (Rojo synced) to rebake the Central Hub preview:
-- the tower, the Cloister Commons, every plot island and the plot buildings, plus the pieces the
-- server otherwise only builds when the game runs: the island bridges and Pilgrim's Causeway, the
-- tower gate's arrival terrace, the Raid Portal and the Runesmith's Anvil (ReforgeStation). Then save
-- the place. The server still rebuilds those runtime pieces on start (each builder replaces its copy).
-- Studio caches required modules, so this swaps in fresh copies of Shared and BaseOverhaul for the
-- bake and puts the originals (the ones Rojo tracks) back afterwards.

-- true: rebuild the whole hub. false: keep a hub that is already current (HubOverhaul.Build decides).
local FORCE_REBUILD = true

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
assert(not game:GetService("RunService"):IsRunning(), "Run this in Edit mode, not during a playtest")

local sharedOriginal = RS:FindFirstChild("Shared") :: Instance
local overhaulOriginal = SSS:FindFirstChild("BaseOverhaul") :: Instance
assert(sharedOriginal and overhaulOriginal, "Shared or BaseOverhaul is missing; is Rojo synced?")

local sharedFresh = sharedOriginal:Clone()
local overhaulFresh = overhaulOriginal:Clone()
sharedOriginal.Parent = nil
sharedFresh.Parent = RS
overhaulOriginal.Parent = nil
overhaulFresh.Parent = SSS

local ok, err = pcall(function()
	local HubOverhaul = require(overhaulFresh:FindFirstChild("HubOverhaul") :: ModuleScript)
	local container, rebuilt = HubOverhaul.Build(FORCE_REBUILD)
	print("[Rebake] Hub rebuilt:", rebuilt, "version", HubOverhaul.Version)
	if rebuilt then
		local plotsOk, plotsErr = pcall(HubOverhaul.RebuildPlotBuildings)
		print("[Rebake] Plot buildings:", if plotsOk then "rebuilt" else ("skipped: " .. tostring(plotsErr)))
	end

	-- Runtime-only pieces, from fresh copies of their modules
	local function fresh(module: Instance): any
		local copy = module:Clone()
		copy.Parent = module.Parent
		local result = require(copy :: ModuleScript)
		copy:Destroy()
		return result
	end
	local BridgeBuilder = require(overhaulFresh:FindFirstChild("BridgeBuilder") :: ModuleScript)
	BridgeBuilder.Build()
	local Traversal = fresh(SSS.Core.TowerTraversal)
	Traversal.EnsureHubArrival(container)
	local RaidPortalKit = fresh(SSS.Raid.RaidPortalKit)
	RaidPortalKit.Build(workspace)
	local ReforgeService = fresh(SSS.Core.ReforgeService)
	ReforgeService.BuildStation(workspace)
	print("[Rebake] Bridges, causeway, arrival terrace, Raid Portal and Reforge Station baked")
end)

sharedFresh:Destroy()
overhaulFresh:Destroy()
sharedOriginal.Parent = RS
overhaulOriginal.Parent = SSS

if ok then
	local plots = workspace:FindFirstChild("WaitingRoomPlots")
	print("[Rebake] Done. Plots:", plots and #plots:GetChildren(), "- save the place (Ctrl+S) to keep it.")
else
	warn("[Rebake] Failed: " .. tostring(err))
end
