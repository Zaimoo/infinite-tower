--!strict
-- StarterPlayerScripts/Input/MasterController.client.luau
-- Handles [Click/Tap] targeting, [Q] Overdrive, [E] Recall, [Shift] Sprint, and [F] facility HUD prompts.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CombatRemotes = Remotes:WaitForChild("CombatRemotes")
local TycoonRemotes = Remotes:WaitForChild("TycoonGachaRemotes")

local FocusTargetRemote = CombatRemotes:WaitForChild("FocusTarget") :: RemoteEvent
local WhistleCommandRemote = CombatRemotes:WaitForChild("WhistleCommand") :: RemoteEvent
local DropCarriedItemRemote = CombatRemotes:WaitForChild("DropCarriedItem") :: RemoteEvent
local FacilityInteractEvent = TycoonRemotes:WaitForChild("FacilityInteract") :: RemoteEvent
local AssignHeroRoleFunc = TycoonRemotes:WaitForChild("AssignHeroRole") :: RemoteFunction

local SPRINT_MULTIPLIER = 3.0
local baseWalkSpeed = 16.0
local lastAppliedSprint = false

RunService.RenderStepped:Connect(function()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end

	local shiftDown = not UserInputService:GetFocusedTextBox()
		and (
			UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		)

	local expectedSpeed = if lastAppliedSprint then baseWalkSpeed * SPRINT_MULTIPLIER else baseWalkSpeed
	if math.abs(hum.WalkSpeed - expectedSpeed) > 0.05 then
		baseWalkSpeed = hum.WalkSpeed
	end

	lastAppliedSprint = shiftDown
	local targetSpeed = if shiftDown then baseWalkSpeed * SPRINT_MULTIPLIER else baseWalkSpeed
	if math.abs(hum.WalkSpeed - targetSpeed) > 0.05 then
		hum.WalkSpeed = targetSpeed
	end
end)

-- Facility interactions take priority over Recall while their prompt is visible.
local visibleInteractionPrompts: { [ProximityPrompt]: boolean } = {}
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	visibleInteractionPrompts[prompt] = true
end)
ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	visibleInteractionPrompts[prompt] = nil
end)
_G.IsFacilityPromptVisible = function(): boolean
	return next(visibleInteractionPrompts) ~= nil
end

-- Phase 5 §2.1: whistles share one module with the HUD's Right Rail (cooldowns, Tower-floor and duel gating).
local Whistles = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Hud"):WaitForChild("Whistles"))

-- 1. Keyboard Hotkeys: [Q] Overdrive, [E] Recall (yields to visible ProximityPrompts), [R] Drop Carried Loot
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or (_G.IsAnyMasterModalOpen and _G.IsAnyMasterModalOpen()) or (_G.IsTowerSelectorOpen and _G.IsTowerSelectorOpen()) then
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		Whistles.Fire("Overdrive")
	elseif input.KeyCode == Enum.KeyCode.E then
		-- Yield [E] to visible ProximityPrompts that use it (e.g. the Synthesis Chamber)
		if next(visibleInteractionPrompts) ~= nil then
			return
		end
		Whistles.Fire("Recall")
	elseif input.KeyCode == Enum.KeyCode.R then
		local char = LocalPlayer.Character
		if char and (char:GetAttribute("CarryingLoot") == true or char:GetAttribute("CarryingRelic") ~= nil) then
			DropCarriedItemRemote:FireServer()
		end
	end
end)

-- 2. [Click / Tap] Focus Target Raycast in 3D Viewport
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or (_G.IsAnyMasterModalOpen and _G.IsAnyMasterModalOpen()) or (_G.IsTowerSelectorOpen and _G.IsTowerSelectorOpen()) then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	-- An assigned squad picks its own targets until recalled (the server ignores focus too).
	if Whistles.AssignedFloor() then
		return
	end

	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end

	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	local filterList: { Instance } = {}
	local visualFolder = Workspace:FindFirstChild("ClientVisualEntities")
	if visualFolder then
		table.insert(filterList, visualFolder)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then
			table.insert(filterList, p.Character)
		end
	end

	local lootFolder = Workspace:FindFirstChild("PhysicalLoot")
	if lootFolder then
		table.insert(filterList, lootFolder)
	end

	params.FilterDescendantsInstances = filterList

	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 350, params)
	if result and result.Instance then
		local hitInst = result.Instance

		local netId = hitInst:GetAttribute("NetId")
			or (hitInst.Parent and hitInst.Parent:GetAttribute("NetId"))

		if type(netId) == "number" then
			if _G.ClientCombatState then
				_G.ClientCombatState.FocusedNetId = netId
			end
			FocusTargetRemote:FireServer(netId)
			return
		end

		-- Check if an enemy Master character was clicked
		local hitChar = hitInst:FindFirstAncestorOfClass("Model")
		if hitChar then
			local enemyPlayer = Players:GetPlayerFromCharacter(hitChar)
			if enemyPlayer and enemyPlayer ~= LocalPlayer then
				local foundNetId: number? = nil
				if _G.ClientCombatState and _G.ClientCombatState.Metadata then
					for nId, meta in pairs(_G.ClientCombatState.Metadata) do
						if meta.IsHero and meta.OwnerUserId == enemyPlayer.UserId then
							foundNetId = nId
							break
						end
					end
				end

				if _G.ClientCombatState and foundNetId then
					_G.ClientCombatState.FocusedNetId = foundNetId
				end
				FocusTargetRemote:FireServer(foundNetId or 0, enemyPlayer.UserId)
			end
		end
	end
end)

local function isPromptOnOwnedPlot(prompt: ProximityPrompt): boolean
	local current: Instance? = prompt
	while current and current.Parent do
		if current.Parent.Name == "WaitingRoomPlots" then
			local ownerId = current:GetAttribute("OwnerUserId")
			if ownerId ~= nil and ownerId ~= LocalPlayer.UserId then
				return false
			end
			return true
		end
		current = current.Parent
	end
	return true
end

-- 3. Plot Facility ProximityPrompt Handler
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, playerWhoTriggered: Player)
	if playerWhoTriggered ~= LocalPlayer then
		return
	end
	if not isPromptOnOwnedPlot(prompt) then
		return
	end

	local name = prompt.Name
	if name == "FacilityHUDPrompt" then
		local facility = prompt:GetAttribute("FacilityHUD")
		if type(facility) == "string" and _G.OpenFacilityHUD then
			_G.OpenFacilityHUD(facility)
		end
	elseif name == "SummonAltarPrompt" then
		if _G.OpenMasterModal then
			_G.OpenMasterModal("WAITING_ROOM")
		end

	elseif name == "BlacksmithPrompt" then
		if _G.OpenMasterModal then
			_G.OpenMasterModal("BLACKSMITH")
		end
	end
end)
