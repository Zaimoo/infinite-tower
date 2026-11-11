--!strict
-- StarterPlayerScripts/Rendering/FacilityLabelController.client.luau
-- Floating labels above every facility building (UI overhaul plan §5.14): a drawn icon and the
-- facility's name in Grimoire type. On your own plot each label adds what the building is doing for
-- you right now ("+29.2% ATK & HP") and a detail line ("Lv.1 · 1/2 Trainers").
-- Labels sit above the building's roof, are sized in pixels (the same size at any camera zoom), have
-- no plate, disappear past MAX_DISTANCE, are hidden by buildings (not AlwaysOnTop) and hide while a
-- window is open. Purely visual: reads the replicated profile (_G.CurrentProfile); no remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GrimoireIcons = require(Shared:WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local InventoryCapacity = require(Shared:WaitForChild("Util"):WaitForChild("InventoryCapacity"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local SummonLuck = require(Shared:WaitForChild("Util"):WaitForChild("SummonLuck"))
local StatBalance = require(Shared:WaitForChild("Config"):WaitForChild("StatBalance"))
local BillboardThemes = require(Shared:WaitForChild("Config"):WaitForChild("BillboardThemes"))
local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local LocalPlayer = Players.LocalPlayer
local Tokens = Kit.Tokens
local New = Tokens.New

local MAX_DISTANCE = 120
local LABEL_WIDTH = 300
local NAME_SIZE, BONUS_SIZE, DETAIL_SIZE, ICON_SIZE = 18, 17, 13, 24
local ROOF_CLEARANCE = 1.5 -- studs between the roof and the bottom of the label
local PROMPT_NAMES = { FacilityHUDPrompt = true, BlacksmithPrompt = true }
-- Building "Facility" attribute → icon.
local ICONS = {
	Market = "Market", TrainingGrounds = "Power", GuardPost = "Camp", Blacksmith = "Forge",
	ThePit = "Summon", Summoning = "Summon", GodsBlessing = "Blessing",
}
-- Support facilities whose level and workers live in profile.Facilities[key].
local WORKERS: { [string]: { Tag: string, Name: string } } = {
	GuardPost = { Tag = "FACILITY_GUARD_POST", Name = "Adventurer" },
	Market = { Tag = "FACILITY_MARKET", Name = "Merchant" },
	TrainingGrounds = { Tag = "FACILITY_TRAINING", Name = "Trainer" },
	GodsBlessing = { Tag = "FACILITY_GODS_BLESSING", Name = "Acolyte" },
}
-- Height above the prompt's part when the building model can't be measured.
local FALLBACK_LIFT = 7.5
local FALLBACK_LIFTS: { [string]: number } = { GodsBlessing = 24 }

local folder = New("Folder", { Name = "FacilityLabels" }, LocalPlayer:WaitForChild("PlayerGui"))
type Label = { Billboard: BillboardGui, Bonus: TextLabel, Detail: TextLabel, Facility: string, Owned: boolean, LastBonus: string, LastDetail: string }
local labels: { [ProximityPrompt]: Label } = {}

-- The building model (the ancestor carrying the Facility attribute), its facility key, and whether
-- the prompt is on the local player's plot.
local function describe(prompt: ProximityPrompt): (string?, boolean, Instance?)
	local facility: string? = nil
	local building: Instance? = nil
	local owned = true
	local current: Instance? = prompt
	while current and current.Parent do
		if not facility then
			local attr = current:GetAttribute("Facility")
			if type(attr) == "string" then
				facility = attr
				building = current
			end
		end
		if current.Parent.Name == "WaitingRoomPlots" then
			local ownerId = current:GetAttribute("OwnerUserId")
			owned = ownerId == nil or ownerId == LocalPlayer.UserId
			break
		end
		current = current.Parent
	end
	return facility, owned, building
end

-- World-space offset from the adornee to a point just above the middle of the building's roof.
local function roofOffset(adornee: Instance, facility: string?, building: Instance?): Vector3
	local from = if adornee:IsA("Attachment") then adornee.WorldPosition else (adornee :: BasePart).Position
	if building and building:IsA("Model") then
		local cf, size = building:GetBoundingBox()
		if size.Y > 0.5 then
			local top = cf.Position + Vector3.new(0, size.Y / 2 + ROOF_CLEARANCE, 0)
			return top - from
		end
	end
	return Vector3.new(0, FALLBACK_LIFTS[facility or ""] or FALLBACK_LIFT, 0)
end

local function percent(fraction: number): string
	return string.format("+%.1f%%", fraction * 100)
end

-- The two lines under the name on your own plot: (what it gives you now, level and workers).
local function statusText(facility: string): (string, string)
	local profile = (_G :: any).CurrentProfile
	if not profile then return "", "" end
	local worker = WORKERS[facility]
	if worker then
		local data = profile.Facilities and profile.Facilities[facility]
		local level = data and data.Level or 0
		if level <= 0 then return "Not built yet", "Unlock it in the Fortress Tree" end
		local perks = FortressTree.PerkBonuses(profile.FortressTree)
		local assigned = data.AssignedHeroUUIDs or {}
		local labor, resting, now = 0, 0, os.time()
		for _, uuid in assigned do
			local hero = profile.Heroes and profile.Heroes[uuid]
			if hero then
				if (hero.ComaUntilTimestamp or 0) > now then
					resting += 1
				else
					labor += StatFormulas.GetEffectiveLabor(hero, worker.Tag)
				end
			end
		end
		local bonus: string
		if facility == "GuardPost" then
			local rate = StatFormulas.GetPassiveGoldRate(level, labor, profile.HighestClearedBiomeBoss or 0, perks)
			bonus = string.format("+%s Gold/min", StatBalance.Format(math.round(rate)))
		elseif facility == "Market" then
			bonus = percent(StatFormulas.GetMarketLootMultiplier(level, labor, perks) - 1) .. " tower loot"
		elseif facility == "TrainingGrounds" then
			bonus = percent(StatFormulas.GetTrainingCombatMultiplier(level, labor, perks) - 1) .. " ATK & HP"
		else
			bonus = percent(SummonLuck.Luck(level, labor, perks.BlessingLuck)) .. " summon luck"
		end
		local max = StatFormulas.GetFacilityMaxWorkers(facility, level, perks)
		local detail = string.format("Lv.%d · %d/%d %s%s", level, #assigned, max, worker.Name, if max == 1 then "" else "s")
		if resting > 0 then
			detail ..= string.format(" · %d resting", resting)
		elseif #assigned < max then
			detail ..= " · slot free"
		end
		return bonus, detail
	elseif facility == "Blacksmith" then
		local count, cap = InventoryCapacity.ArtifactCount(profile), InventoryCapacity.ArtifactCap(profile.FortressTree)
		return string.format("%d/%d weapons", count, cap), if count >= cap then "Full · sell or promote to make room" else "Forge · Promote · Sell"
	elseif facility == "ThePit" then
		local count, cap = InventoryCapacity.HeroCount(profile), InventoryCapacity.HeroCap(profile.FortressTree)
		return "Synthesis · Promotion", string.format("%d/%d heroes", count, cap)
	elseif facility == "Summoning" then
		local gems = profile.Currencies and profile.Currencies.Gems or 0
		local luck = SummonLuck.ForProfile(profile)
		return string.format("%s Gems", StatBalance.Format(gems)), if luck > 0 then percent(luck) .. " summon luck" else ""
	end
	return "", ""
end

local function build(prompt: ProximityPrompt)
	if labels[prompt] then return end
	local adornee = prompt.Parent
	if not adornee or not (adornee:IsA("BasePart") or adornee:IsA("Attachment")) then return end
	local facility, owned, building = describe(prompt)
	local offsetAttr = prompt:GetAttribute("BillboardStudsOffset")
		or prompt:GetAttribute("BillboardOffset")
		or adornee:GetAttribute("BillboardStudsOffset")
		or adornee:GetAttribute("BillboardOffset")
	local offset = if typeof(offsetAttr) == "Vector3" then offsetAttr else roofOffset(adornee, facility, building)
	local nameRow = math.max(NAME_SIZE + 4, ICON_SIZE)
	local height = nameRow + (if owned then BONUS_SIZE + DETAIL_SIZE + 8 else 0)
	local billboard: BillboardGui = New("BillboardGui", {
		Name = "FacilityLabel_" .. (facility or prompt.ObjectText),
		Adornee = adornee,
		Size = UDim2.fromOffset(LABEL_WIDTH, height), -- pixels: the same size at any zoom
		SizeOffset = Vector2.new(0, 0.5), -- the label's bottom edge sits on the anchor point
		StudsOffsetWorldSpace = offset,
		MaxDistance = MAX_DISTANCE,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ClipsDescendants = false,
		ResetOnSpawn = false,
	}, folder)
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, billboard)

	-- Icon and name, centred as one group.
	local head = New("Frame", { Name = "Head", LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, nameRow) }, billboard)
	New("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
	}, head)
	local icon = GrimoireIcons.Create(ICONS[facility or ""] or "Spark", ICON_SIZE, head, 3)
	icon.LayoutOrder = 1
	local name = BillboardThemes.Text(head, Tokens.Fonts.Title, prompt.ObjectText ~= "" and prompt.ObjectText or (facility or "Facility"), NAME_SIZE, Tokens.Text.White)
	name.Name = "Title"
	name.LayoutOrder = 2
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Size = UDim2.fromOffset(0, nameRow)

	local bonus = BillboardThemes.Text(billboard, Tokens.Fonts.Number, "", BONUS_SIZE, Tokens.Text.Gold)
	bonus.Name = "Bonus"
	bonus.LayoutOrder = 2
	bonus.Visible = false
	local detail = BillboardThemes.Text(billboard, Tokens.Fonts.Body, "", DETAIL_SIZE, Tokens.Text.Parchment)
	detail.Name = "Detail"
	detail.LayoutOrder = 3
	detail.Visible = false

	labels[prompt] = { Billboard = billboard, Bonus = bonus, Detail = detail, Facility = facility or "", Owned = owned, LastBonus = "", LastDetail = "" }
	prompt.Destroying:Connect(function()
		local label = labels[prompt]
		if label then label.Billboard:Destroy() end
		labels[prompt] = nil
	end)
end

local function consider(inst: Instance)
	if inst:IsA("ProximityPrompt") and PROMPT_NAMES[inst.Name] then
		task.defer(build, inst)
	end
end

task.spawn(function()
	local plots = Workspace:WaitForChild("WaitingRoomPlots")
	for _, d in plots:GetDescendants() do consider(d) end
	plots.DescendantAdded:Connect(consider)
end)

-- Status lines and modal hiding, a few times a second; text is written only when it changes.
-- Hero and mob nameplates (tagged "UnitNameplate" by EntityRenderer) hide with the labels while a
-- window is open, so they never clutter it (plan §5.13).
local CollectionService = game:GetService("CollectionService")
local lastModal = false
task.spawn(function()
	while true do
		task.wait(0.5)
		local modalOpen = (_G :: any).IsAnyMasterModalOpen ~= nil and (_G :: any).IsAnyMasterModalOpen()
		if modalOpen ~= lastModal then
			lastModal = modalOpen
			for _, plate in CollectionService:GetTagged("UnitNameplate") do
				if plate:IsA("BillboardGui") then plate.Enabled = not modalOpen end
			end
		end
		for _, label in labels do
			label.Billboard.Enabled = not modalOpen
			if label.Owned and not modalOpen then
				local bonus, detail = statusText(label.Facility)
				if bonus ~= label.LastBonus then
					label.Bonus.Text = bonus
					label.Bonus.Visible = bonus ~= ""
					label.LastBonus = bonus
				end
				if detail ~= label.LastDetail then
					label.Detail.Text = detail
					label.Detail.Visible = detail ~= ""
					label.LastDetail = detail
				end
			end
		end
	end
end)
