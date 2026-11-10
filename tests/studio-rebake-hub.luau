-- studio-rebake-hub.luau
-- Paste into Studio's command bar in EDIT mode (Rojo synced) to rebake the Central Hub preview:
-- the tower, the Cloister Commons, every plot island and the plot buildings. Then save the place.
-- Studio caches required modules, so this swaps in fresh copies of Shared and BaseOverhaul for the
-- bake and puts the originals (the ones Rojo tracks) back afterwards.

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
	local _, rebuilt = HubOverhaul.Build(true)
	print("[Rebake] Hub rebuilt:", rebuilt, "version", HubOverhaul.Version)
	local plotsOk, plotsErr = pcall(HubOverhaul.RebuildPlotBuildings)
	print("[Rebake] Plot buildings:", if plotsOk then "rebuilt" else ("skipped: " .. tostring(plotsErr)))
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
