--!strict
-- StarterPlayerScripts/Rendering/FacilityLabelController.client.luau
-- Floating labels above every facility building (UI overhaul plan §5.14): a drawn icon and the
-- facility's name in Grimoire type, plus, on your own plot only, one live status line ("Lv.3 ·
-- 2 workers", "44/100 weapons"). Labels are sized in studs (they shrink with distance), fade out past
-- MAX_DISTANCE, are hidden by buildings (not AlwaysOnTop) and hide while a window is open.
-- Purely visual: reads the replicated profile (_G.CurrentProfile); no remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GrimoireIcons = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GrimoireIcons"))
local InventoryCapacity = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("InventoryCapacity"))
local StatBalance = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("StatBalance"))
local Kit = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local LocalPlayer = Players.LocalPlayer
local Tokens = Kit.Tokens
local New = Tokens.New

local MAX_DISTANCE = 120
local PROMPT_NAMES = { FacilityHUDPrompt = true, BlacksmithPrompt = true }
-- Building "Facility" attribute → icon.
local ICONS = {
	Market = "Market", TrainingGrounds = "Power", GuardPost = "Camp", Blacksmith = "Forge",
	ThePit = "Summon", Summoning = "Summon", GodsBlessing = "Blessing",
}
-- Support facilities whose level and workers live in profile.Facilities[key].
local WORKER_FACILITIES = { Market = true, TrainingGrounds = true, GuardPost = true, GodsBlessing = true }

local folder = New("Folder", { Name = "FacilityLabels" }, LocalPlayer:WaitForChild("PlayerGui"))
type Label = { Billboard: BillboardGui, Status: TextLabel, Facility: string, Owned: boolean, LastText: string }
local labels: { [ProximityPrompt]: Label } = {}

-- The building model's Facility attribute, and whether the prompt is on the local player's plot.
local function describe(prompt: ProximityPrompt): (string?, boolean)
	local facility: string? = nil
	local owned = true
	local current: Instance? = prompt
	while current and current.Parent do
		if not facility then
			local attr = current:GetAttribute("Facility")
			if type(attr) == "string" then facility = attr end
		end
		if current.Parent.Name == "WaitingRoomPlots" then
			local ownerId = current:GetAttribute("OwnerUserId")
			owned = ownerId == nil or ownerId == LocalPlayer.UserId
			break
		end
		current = current.Parent
	end
	return facility, owned
end

local function statusText(facility: string): string
	local profile = (_G :: any).CurrentProfile
	if not profile then return "" end
	if facility == "Blacksmith" then
		return string.format("%d/%d weapons", InventoryCapacity.ArtifactCount(profile), InventoryCapacity.ArtifactCap(profile.FortressTree))
	elseif WORKER_FACILITIES[facility] then
		local data = profile.Facilities and profile.Facilities[facility]
		if not data then return "Not built yet" end
		local workers = #(data.AssignedHeroUUIDs or {})
		return string.format("Lv.%d · %d worker%s", data.Level or 1, workers, if workers == 1 then "" else "s")
	elseif facility == "ThePit" then
		return "Synthesis · Promotion"
	elseif facility == "Summoning" then
		local gems = profile.Currencies and profile.Currencies.Gems or 0
		return string.format("%s Gems", StatBalance.Format(gems))
	end
	return ""
end

local function build(prompt: ProximityPrompt)
	if labels[prompt] then return end
	local adornee = prompt.Parent
	if not adornee or not (adornee:IsA("BasePart") or adornee:IsA("Attachment")) then return end
	local facility, owned = describe(prompt)
	local billboard: BillboardGui = New("BillboardGui", {
		Name = "FacilityLabel_" .. (facility or prompt.ObjectText),
		Adornee = adornee,
		Size = UDim2.fromScale(11, if owned then 3.4 else 2.2), -- studs: shrinks with distance
		StudsOffset = Vector3.new(0, 7.5, 0),
		MaxDistance = MAX_DISTANCE,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
	}, folder)
	local card = New("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), ZIndex = 1 }, billboard)
	Tokens.Paint(card, Tokens.Surface.Hud, 12, 2.5, 0.25)
	card.BackgroundTransparency = 0.08
	local icon = GrimoireIcons.Create(ICONS[facility or ""] or "Spark", 1, card, 3)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0.03, 0, 0.5, 0)
	icon.Size = UDim2.fromScale(0.2, 0.85)
	New("UIAspectRatioConstraint", { AspectRatio = 1 }, icon)
	-- The icon's canvas is 64 px with a UIScale; keep it filling the scaled box.
	local canvas = icon:FindFirstChild("Canvas")
	if canvas then
		local scale = canvas:FindFirstChildOfClass("UIScale")
		local function fit() if scale then scale.Scale = icon.AbsoluteSize.X / 64 end end
		icon:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		fit()
	end
	local title = Tokens.Label(card, prompt.ObjectText ~= "" and prompt.ObjectText or (facility or "Facility"), 20, "Title", {
		Name = "Title", Position = UDim2.fromScale(0.25, if owned then 0.06 else 0.1), Size = UDim2.fromScale(0.72, if owned then 0.5 else 0.8),
		TextScaled = true, TextColor3 = Tokens.Text.White, ZIndex = 3,
	})
	New("UITextSizeConstraint", { MaxTextSize = 34, MinTextSize = 8 }, title)
	local status = Tokens.Label(card, "", 14, "Body", {
		Name = "Status", Position = UDim2.fromScale(0.25, 0.56), Size = UDim2.fromScale(0.72, 0.36),
		TextScaled = true, TextColor3 = Tokens.Text.Gold, Visible = owned, ZIndex = 3,
	})
	New("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 7 }, status)
	labels[prompt] = { Billboard = billboard, Status = status, Facility = facility or "", Owned = owned, LastText = "" }
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
				local text = statusText(label.Facility)
				if text ~= label.LastText then
					label.Status.Text = text
					label.LastText = text
				end
			end
		end
	end
end)
