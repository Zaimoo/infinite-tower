--!strict
-- ServerScriptService/Core/ForgeRollService.luau
-- Server-authoritative Open Forge pedestal rolling, relic-scaled Gold purchases, world prompt/click
-- wiring, and the permanent Robux Auto-Roll GamePass loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local StatBalance = require(Shared:WaitForChild("Config"):WaitForChild("StatBalance"))
local ShopConfig = require(Shared:WaitForChild("Config"):WaitForChild("ShopConfig"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local ForgeRollRules = require(Shared:WaitForChild("Util"):WaitForChild("ForgeRollRules"))

export type Dependencies = {
	GetProfile: (Player) -> any,
	SyncProfile: (Player, boolean?) -> (),
	SendToast: (Player, string, string?) -> (),
	CreateArtifact: (string, number?, number?) -> (string, any),
	IsUnlocked: (Player, string) -> boolean,
	StarterWeaponType: (Player) -> string?,
	ReportOnboarding: (Player, string) -> (),
	ProgressBattlePass: (Player, string, number) -> (),
	PostNews: (any) -> (),
	ArtifactRemotes: Folder,
}

local MANUAL_SLOT_ROLL_SECONDS = 0.42
local MANUAL_REVEAL_SETTLE_SECONDS = 0.30
local AUTO_SLOT_ROLL_SECONDS = 0.14
local AUTO_REVEAL_SETTLE_SECONDS = 0.28
local AUTO_ROLL_POLL_SECONDS = 0.15
local MAX_ANVIL_CLICK_DIST = 30
local MAX_AUTOROLL_FORGE_DIST = 55

local ForgeRollService = {}
local deps: Dependencies? = nil
local rollLockedUntil: { [Player]: number } = {}
local nextAutoRollAt: { [Player]: number } = {}
local autoRollActive: { [Player]: boolean } = {}
local boundForgeModels: { [Instance]: { RBXScriptConnection } } = {}

local function computeRollDuration(pedestalCount: number, isAuto: boolean): (number, number)
	local count = math.max(1, pedestalCount)
	local slotDur = if isAuto then AUTO_SLOT_ROLL_SECONDS else MANUAL_SLOT_ROLL_SECONDS
	local settle = if isAuto then AUTO_REVEAL_SETTLE_SECONDS else MANUAL_REVEAL_SETTLE_SECONDS
	return slotDur, count * slotDur + settle
end

local function ensureRemote(folder: Folder, name: string): RemoteFunction
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local rf = Instance.new("RemoteFunction")
	rf.Name = name
	rf.Parent = folder
	return rf
end

local function getOwnedPlot(player: Player): Model?
	local pm = (_G :: any).PlotManager
	if not pm or not pm.GetPlayerPlotModel or not pm.IsPlayerPlotOwner then
		return nil
	end
	if not pm.IsPlayerPlotOwner(player) then
		return nil
	end
	return pm.GetPlayerPlotModel(player)
end

local function getForgeModel(plotModel: Instance?): Model?
	local buildings = plotModel and plotModel:FindFirstChild("PlotBuildings")
	local forge = buildings and buildings:FindFirstChild("Building_Blacksmith")
	return if forge and forge:IsA("Model") then forge else nil
end

local function ownsAutoRollPass(player: Player): boolean
	local attr = ShopConfig.Passes.ForgeAutoRoll.Attribute
	return player:GetAttribute(attr) == true
end

local function setAutoRollState(player: Player, enabled: boolean)
	autoRollActive[player] = if enabled then true else nil
	if player.Parent == Players then
		player:SetAttribute("ForgeAutoRollActive", enabled)
	end
end

function ForgeRollService.ClearPlotPedestals(plotModel: Instance?)
	local forge = getForgeModel(plotModel)
	local pedestals = forge and forge:FindFirstChild("Pedestals")
	if not pedestals then
		return
	end
	for idx = 1, 6 do
		local ped = pedestals:FindFirstChild("Pedestal_" .. idx)
		if ped then
			ped:SetAttribute("Unlocked", idx == 1)
			ped:SetAttribute("TemplateId", "")
			ped:SetAttribute("Cost", 0)
			ped:SetAttribute("TargetMatched", false)
			local prompt = ped:FindFirstChild("BuyArtifactPrompt", true)
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Enabled = false
			end
		end
	end
end

function ForgeRollService.SyncPlotPedestals(
	player: Player,
	plotModelOverride: Instance?,
	bumpRollSeq: boolean?,
	matchedLookup: { [number]: boolean }?,
	isAutoRoll: boolean?
)
	local d = deps
	if not d then
		return
	end
	local profile = d.GetProfile(player)
	local plotModel = plotModelOverride or getOwnedPlot(player)
	if not profile or not plotModel then
		return
	end

	-- Only auto-roll once on a brand-new uninitialized profile; bought pedestals stay empty until rerolled!
	ForgeRollRules.EnsureUnlockedPopulated(profile, nil, d.StarterWeaponType(player))
	local state = ForgeRollRules.EnsureState(profile)
	local pedestalCount = FortressTree.ForgePedestals(profile.FortressTree)

	local forge = getForgeModel(plotModel)
	if not forge then
		return
	end

	local pedestals = forge:FindFirstChild("Pedestals")
	if not pedestals then
		return
	end

	local batchSeq = tonumber(forge:GetAttribute("RollBatchSeq")) or 0
	local slotDur, totalDur = computeRollDuration(pedestalCount, isAutoRoll == true)
	if bumpRollSeq then
		batchSeq += 1
		forge:SetAttribute("AnvilStrikeSeq", (tonumber(forge:GetAttribute("AnvilStrikeSeq")) or 0) + 1)
		forge:SetAttribute("RollSlotDuration", slotDur)
		forge:SetAttribute("RollTotalDuration", totalDur)
		forge:SetAttribute("RollUnlockedCount", pedestalCount)
		forge:SetAttribute("RollAnimUntil", Workspace:GetServerTimeNow() + totalDur)
		-- Lock the Anvil ProximityPrompt until the sequential reveal animation completes
		local anvilPrompt = forge:FindFirstChild("AnvilRollPrompt", true)
		if anvilPrompt and anvilPrompt:IsA("ProximityPrompt") then
			anvilPrompt.Enabled = false
			local thisBatch = batchSeq
			task.delay(totalDur, function()
				if forge.Parent and anvilPrompt.Parent and (tonumber(forge:GetAttribute("RollBatchSeq")) or 0) == thisBatch then
					anvilPrompt.Enabled = true
				end
			end)
		end
	end

	for idx = 1, 6 do
		local ped = pedestals:FindFirstChild("Pedestal_" .. idx)
		if not ped then
			continue
		end
		local unlocked = idx <= pedestalCount
		local templateId = if unlocked then (state.Slots[tostring(idx)] or "") else ""
		local seed = if templateId ~= "" then ArtifactCatalog.Seeds[templateId] else nil
		local cost = if seed then ArtifactCatalog.GetPedestalCost(seed) else 0
		local isMatch = matchedLookup ~= nil and matchedLookup[idx] == true

		if ped:GetAttribute("Unlocked") ~= unlocked then
			ped:SetAttribute("Unlocked", unlocked)
		end
		if ped:GetAttribute("TemplateId") ~= templateId then
			ped:SetAttribute("TemplateId", templateId)
		end
		if ped:GetAttribute("Cost") ~= cost then
			ped:SetAttribute("Cost", cost)
		end
		if matchedLookup ~= nil or ped:GetAttribute("TargetMatched") == nil then
			ped:SetAttribute("TargetMatched", isMatch)
		end
		if bumpRollSeq then
			ped:SetAttribute("RollSeq", (tonumber(ped:GetAttribute("RollSeq")) or 0) + 1)
		end

		local prompt = ped:FindFirstChild("BuyArtifactPrompt", true)
		if prompt and prompt:IsA("ProximityPrompt") then
			if unlocked and seed then
				local rarityInfo = ArtifactCatalog.GetRarityInfo(seed.RarityTier or 1)
				local variantTag = if seed.IsHighStat then " · Enhanced" else ""
				prompt.ObjectText = string.format("%s (%s%s)", seed.DisplayName, rarityInfo.Name, variantTag)
				prompt.ActionText = string.format("Buy · %s Gold", StatBalance.Format(cost))
				prompt.HoldDuration = if (seed.RarityTier or 1) >= 5 then 0.35 else 0
				if bumpRollSeq then
					-- Hide Buy prompt while this pedestal is still queued/rolling; reveal once its turn lands
					prompt.Enabled = false
					local thisBatch = batchSeq
					local expectedId = templateId
					task.delay(idx * slotDur, function()
						if
							forge.Parent
							and prompt.Parent
							and (tonumber(forge:GetAttribute("RollBatchSeq")) or 0) == thisBatch
							and ped:GetAttribute("TemplateId") == expectedId
							and ped:GetAttribute("Unlocked") == true
						then
							prompt.Enabled = true
						end
					end)
				else
					prompt.Enabled = true
				end
			else
				prompt.Enabled = false
			end
		end
	end

	-- Fire RollBatchSeq LAST so all pedestal TemplateId / Unlocked / Cost attributes are already updated
	if bumpRollSeq then
		forge:SetAttribute("RollBatchSeq", batchSeq)
	end
end

function ForgeRollService.OnPedestalUnlocked(player: Player)
	local d = deps
	local profile = d and d.GetProfile(player)
	if profile then
		local newSlot = FortressTree.ForgePedestals(profile.FortressTree)
		ForgeRollRules.PopulateSlot(profile, newSlot, nil)
	end
	local plotModel = getOwnedPlot(player)
	ForgeRollService.SyncPlotPedestals(player, plotModel, false, nil)
end

function ForgeRollService.Reroll(player: Player, fromAutoRoll: boolean?): (boolean, string?, { [number]: string }?)
	local d = deps
	if not d then
		return false, "Service unavailable", nil
	end
	local profile = d.GetProfile(player)
	if not profile then
		return false, "Profile not loaded", nil
	end
	local plotModel = getOwnedPlot(player)
	if not plotModel then
		return false, "Return to your Fortress Plot to use the Forge", nil
	end
	if not d.IsUnlocked(player, "Forge") then
		d.SendToast(player, "Clear Floor 1 first|Unlocks the Open Forge", "WARN")
		return false, "Clear Floor 1 first", nil
	end

	local now = os.clock()
	if now < (rollLockedUntil[player] or 0) then
		return false, "Rolling in progress…", nil
	end
	if not fromAutoRoll and autoRollActive[player] then
		setAutoRollState(player, false)
	end

	local pedestalCount = FortressTree.ForgePedestals(profile.FortressTree)
	local _, animDuration = computeRollDuration(pedestalCount, fromAutoRoll == true)
	rollLockedUntil[player] = now + animDuration
	if fromAutoRoll then
		nextAutoRollAt[player] = now + math.max(0.85, animDuration + 0.12)
	end

	local rolled = ForgeRollRules.RollAll(profile, nil, d.StarterWeaponType(player))
	local clearMatches: { [number]: boolean } = {}
	ForgeRollService.SyncPlotPedestals(player, plotModel, true, clearMatches, fromAutoRoll == true)
	d.SyncProfile(player, true)
	return true, "Rerolled", rolled
end

function ForgeRollService.BuyPedestal(player: Player, slotIndex: any): (boolean, string?, any?)
	local d = deps
	if not d then
		return false, "Service unavailable", nil
	end
	local profile = d.GetProfile(player)
	if not profile then
		return false, "Profile not loaded", nil
	end
	local plotModel = getOwnedPlot(player)
	if not plotModel then
		return false, "Plot ownership validation failed", nil
	end
	if not d.IsUnlocked(player, "Forge") then
		d.SendToast(player, "Clear Floor 1 first|Unlocks the Open Forge", "WARN")
		return false, "Clear Floor 1 first", nil
	end

	local ok, reason, seed, cost = ForgeRollRules.ValidatePurchase(profile, slotIndex)
	if not ok or not seed or not cost then
		d.SendToast(player, tostring(reason or "Cannot buy artifact"), "WARN")
		return false, reason, nil
	end

	if autoRollActive[player] then
		setAutoRollState(player, false)
	end

	-- Atomic deduction, slot clear, and 1★ instantiation
	profile.Currencies.Gold -= cost
	local state = ForgeRollRules.EnsureState(profile)
	state.Slots[tostring(slotIndex)] = nil

	if not profile.Artifacts then
		profile.Artifacts = {}
	end
	local uuid, artifact = d.CreateArtifact(seed.TemplateId, 1, seed.RarityTier)
	profile.Artifacts[uuid] = artifact

	ForgeRollService.SyncPlotPedestals(player, plotModel, false, {})
	d.ProgressBattlePass(player, "Artifacts", 1)
	d.SyncProfile(player, false)
	d.ReportOnboarding(player, "ArtifactSummoned")

	local rarityInfo = ArtifactCatalog.GetRarityInfo(seed.RarityTier or 1)
	d.SendToast(
		player,
		string.format("Forged %s|%s 1★ (-%s Gold)", seed.DisplayName, rarityInfo.Name, StatBalance.Format(cost)),
		"SUCCESS"
	)

	if (seed.RarityTier or 1) >= 5 then
		d.PostNews({
			Kind = "BIG_FORGE",
			ActorUserId = player.UserId,
			ActorName = player.DisplayName,
			ItemName = seed.DisplayName,
			Tier = seed.RarityTier,
		})
	end

	return true, "Purchased " .. seed.DisplayName, artifact
end

function ForgeRollService.ConfigureAutoRoll(player: Player, payload: any): (boolean, string?)
	local d = deps
	if not d then
		return false, "Service unavailable"
	end
	local profile = d.GetProfile(player)
	if not profile then
		return false, "Profile not loaded"
	end
	if type(payload) ~= "table" then
		return false, "Invalid request"
	end

	local state = ForgeRollRules.EnsureState(profile)
	local minR, wType = ForgeRollRules.SanitizeFilter(payload.MinRarity, payload.WeaponType)
	if payload.MinRarity ~= nil and minR == nil then
		return false, "Invalid rarity filter"
	end
	if payload.WeaponType ~= nil and wType == nil then
		return false, "Invalid weapon filter"
	end
	if minR then
		state.MinRarity = minR
	end
	if wType then
		state.WeaponType = wType
	end

	if type(payload.Enabled) == "boolean" then
		if payload.Enabled then
			if not ownsAutoRollPass(player) then
				setAutoRollState(player, false)
				return false, "Requires the Forge Auto-Roll GamePass"
			end
			if not d.IsUnlocked(player, "Forge") then
				setAutoRollState(player, false)
				return false, "Clear Floor 1 first"
			end
			local plotModel = getOwnedPlot(player)
			if not plotModel then
				setAutoRollState(player, false)
				return false, "Stand near your Open Forge to start Auto-Roll"
			end
			-- Guard: if an existing pedestal ALREADY satisfies the filter, highlight it instead of rolling over it!
			local alreadyMatched = ForgeRollRules.MatchingSlots(profile)
			if #alreadyMatched > 0 then
				setAutoRollState(player, false)
				local matchedSet: { [number]: boolean } = {}
				for _, s in ipairs(alreadyMatched) do
					matchedSet[s] = true
				end
				ForgeRollService.SyncPlotPedestals(player, plotModel, false, matchedSet)
				local hitSlot = alreadyMatched[1]
				local hitSeed = ArtifactCatalog.Seeds[state.Slots[tostring(hitSlot)]]
				local hitName = if hitSeed then hitSeed.DisplayName else "Target Artifact"
				d.SendToast(player, string.format("Already on Pedestal #%d!|Walk over to buy %s", hitSlot, hitName), "SUCCESS")
				d.SyncProfile(player, true)
				return true, "Target already on pedestal"
			end
			setAutoRollState(player, true)
		else
			setAutoRollState(player, false)
		end
	end

	d.SyncProfile(player, true)
	return true, "Updated"
end

local function isPlayerNearForge(player: Player, plotModel: Model): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local forge = getForgeModel(plotModel)
	local anvil = forge and forge:FindFirstChild("AnvilInteraction")
	if not (hrp and hrp:IsA("BasePart") and anvil and anvil:IsA("BasePart")) then
		return false
	end
	return (hrp.Position - anvil.Position).Magnitude <= MAX_AUTOROLL_FORGE_DIST
end

local function bindForgeInteractions(forge: Model)
	if boundForgeModels[forge] then
		return
	end
	local conns: { RBXScriptConnection } = {}
	boundForgeModels[forge] = conns

	local function connectDescendant(inst: Instance)
		if inst:IsA("ProximityPrompt") then
			if inst.Name == "AnvilRollPrompt" then
				table.insert(conns, inst.Triggered:Connect(function(who: Player)
					local plot = getOwnedPlot(who)
					if plot and forge:IsDescendantOf(plot) then
						ForgeRollService.Reroll(who, false)
					end
				end))
			elseif inst.Name == "BuyArtifactPrompt" then
				table.insert(conns, inst.Triggered:Connect(function(who: Player)
					local plot = getOwnedPlot(who)
					if plot and forge:IsDescendantOf(plot) then
						local slotIdx = tonumber(inst:GetAttribute("SlotIndex"))
						ForgeRollService.BuyPedestal(who, slotIdx)
					end
				end))
			end
		elseif inst:IsA("ClickDetector") and inst.Name == "AnvilClickDetector" then
			table.insert(conns, inst.MouseClick:Connect(function(who: Player)
				local plot = getOwnedPlot(who)
				if not (plot and forge:IsDescendantOf(plot)) then
					return
				end
				local char = who.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local parentPart = inst.Parent
				if not (hrp and hrp:IsA("BasePart") and parentPart and parentPart:IsA("BasePart")) then
					return
				end
				if (hrp.Position - parentPart.Position).Magnitude > MAX_ANVIL_CLICK_DIST then
					return
				end
				ForgeRollService.Reroll(who, false)
			end))
		end
	end

	for _, desc in ipairs(forge:GetDescendants()) do
		connectDescendant(desc)
	end
	table.insert(conns, forge.DescendantAdded:Connect(connectDescendant))
	table.insert(conns, forge.Destroying:Connect(function()
		local list = boundForgeModels[forge]
		boundForgeModels[forge] = nil
		if list then
			for _, c in ipairs(list) do
				c:Disconnect()
			end
		end
	end))
end

function ForgeRollService.Init(dependencies: Dependencies)
	deps = dependencies

	local rerollRemote = ensureRemote(dependencies.ArtifactRemotes, "RerollForge")
	local buyRemote = ensureRemote(dependencies.ArtifactRemotes, "BuyPedestalArtifact")
	local autoRemote = ensureRemote(dependencies.ArtifactRemotes, "SetAutoRollConfig")

	rerollRemote.OnServerInvoke = function(player: Player)
		return ForgeRollService.Reroll(player, false)
	end
	buyRemote.OnServerInvoke = function(player: Player, slotIndex: any)
		return ForgeRollService.BuyPedestal(player, slotIndex)
	end
	autoRemote.OnServerInvoke = function(player: Player, payload: any)
		return ForgeRollService.ConfigureAutoRoll(player, payload)
	end

	-- Bind world prompts & ClickDetectors across all current and rebuilt plots
	task.spawn(function()
		local plots = Workspace:WaitForChild("WaitingRoomPlots")
		for _, desc in ipairs(plots:GetDescendants()) do
			if desc:IsA("Model") and desc.Name == "Building_Blacksmith" then
				bindForgeInteractions(desc)
			end
		end
		plots.DescendantAdded:Connect(function(desc)
			if desc:IsA("Model") and desc.Name == "Building_Blacksmith" then
				bindForgeInteractions(desc)
			end
		end)
	end)

	-- Server-paced Auto-Roll loop (waits for the sequential roll animation to finish before next roll)
	task.spawn(function()
		while true do
			task.wait(AUTO_ROLL_POLL_SECONDS)
			local d = deps
			if not d then
				continue
			end
			local now = os.clock()
			for player in pairs(autoRollActive) do
				if player.Parent ~= Players or not ownsAutoRollPass(player) then
					setAutoRollState(player, false)
					continue
				end
				if now < (nextAutoRollAt[player] or 0) or now < (rollLockedUntil[player] or 0) then
					continue
				end
				local plotModel = getOwnedPlot(player)
				if not plotModel or not isPlayerNearForge(player, plotModel) then
					setAutoRollState(player, false)
					if player.Parent == Players then
						d.SendToast(player, "Auto-Roll paused|Stepped away from the Open Forge", "INFO")
					end
					continue
				end

				local ok = ForgeRollService.Reroll(player, true)
				if not ok then
					continue
				end

				local profile = d.GetProfile(player)
				local matched = if profile then ForgeRollRules.MatchingSlots(profile) else {}
				if #matched > 0 and profile then
					setAutoRollState(player, false)
					local matchedSet: { [number]: boolean } = {}
					for _, s in ipairs(matched) do
						matchedSet[s] = true
					end
					ForgeRollService.SyncPlotPedestals(player, plotModel, false, matchedSet)
					local hitSlot = matched[1]
					local state = ForgeRollRules.EnsureState(profile)
					local seed = ArtifactCatalog.Seeds[state.Slots[tostring(hitSlot)]]
					if seed then
						local rInfo = ArtifactCatalog.GetRarityInfo(seed.RarityTier or 1)
						d.SendToast(
							player,
							string.format("Target Rolled!|%s (%s) on Pedestal #%d", seed.DisplayName, rInfo.Name, hitSlot),
							"SUCCESS"
						)
					end
				end
			end
		end
	end)
end

function ForgeRollService.Forget(player: Player)
	rollLockedUntil[player] = nil
	nextAutoRollAt[player] = nil
	setAutoRollState(player, false)
end

_G.ForgeRollService = ForgeRollService

return ForgeRollService
