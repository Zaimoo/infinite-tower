--!strict
-- StarterPlayerScripts/Input/MasterController.client.luau
-- Handles [Click/Tap] Focus Target Raycasting, [Q] Overdrive, [E] Recall & Plot Prompts

local Players = game:GetService("Players")
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

-- Facility interactions take priority over Recall while their prompt is visible.
local visibleInteractionPrompts: { [ProximityPrompt]: boolean } = {}
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	visibleInteractionPrompts[prompt] = true
end)
ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
	visibleInteractionPrompts[prompt] = nil
end)

-- 1. Keyboard Hotkeys: [Q] Overdrive Whistle, [E] Emergency Recall Whistle
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Q then
		WhistleCommandRemote:FireServer(1) -- 1 = Q_OVERDRIVE
		if _G.TriggerHUDWhistleCooldown then
			_G.TriggerHUDWhistleCooldown("Q")
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		local char = LocalPlayer.Character
		if char and (char:GetAttribute("CarryingLoot") == true or char:GetAttribute("CarryingRelic") ~= nil) then
			DropCarriedItemRemote:FireServer()
		end
	elseif input.KeyCode == Enum.KeyCode.E then
		for prompt in pairs(visibleInteractionPrompts) do
			if prompt.Parent and prompt.Enabled and prompt.KeyboardKeyCode == Enum.KeyCode.E then
				return
			end
		end
		WhistleCommandRemote:FireServer(2) -- 2 = E_RECALL
		if _G.TriggerHUDWhistleCooldown then
			_G.TriggerHUDWhistleCooldown("E")
		end
	end
end)

-- 2. [Click / Tap] Focus Target Raycast in 3D Viewport
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
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

-- 3. Plot Facility ProximityPrompt Handler
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, playerWhoTriggered: Player)
	if playerWhoTriggered ~= LocalPlayer then
		return
	end

	local name = prompt.Name
	if name == "SummonAltarPrompt" then
		if _G.OpenMasterModal then
			_G.OpenMasterModal("WAITING_ROOM")
		end
	elseif name == "ThePitPrompt" then
		if _G.OpenMasterModal then
			_G.OpenMasterModal("THE_PIT")
		end
	elseif name == "ConduitInteractPrompt" then
		FacilityInteractEvent:FireServer("COLLECT_CONDUIT")
	elseif name == "LabInteractPrompt" then
		FacilityInteractEvent:FireServer("COLLECT_LAB")
		if _G.OpenMasterModal then
			_G.OpenMasterModal("WAITING_ROOM")
		end
	elseif name == "InfirmaryInteractPrompt" then
		task.spawn(function()
			AssignHeroRoleFunc:InvokeServer("AUTO_SWAP_EXHAUSTED", "")
		end)
	end
end)
