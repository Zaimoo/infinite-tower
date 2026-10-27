--!strict
-- ServerScriptService/Core/FacilityPresence.luau
-- Support facilities exist in the world only once unlocked in the Fortress Tree (Phase 4 §5.6).
-- Locked buildings are taken out of the DataModel (so nothing replicates or prompts), a level 1
-- unlock plays a construction reveal, and later levels play an upgrade burst. Levels are mirrored
-- on the plot as attributes so a rebuilt PlotBuildings folder can be re-hidden without the profile.

local RunService = game:GetService("RunService")
local AngelStatue = require(script.Parent:WaitForChild("AngelStatue"))

local FacilityPresence = {}

-- Facility -> building model name inside Plot_N.PlotBuildings. God's Blessing is the angel statue.
local BUILDINGS: { [string]: string } = {
	Market = "Building_Market",
	TrainingGrounds = "Building_TrainingGrounds",
}
local GATED = { "Market", "TrainingGrounds", "GodsBlessing" }

local REVEAL_SECONDS = 1.6
local DUST_TEXTURE = "rbxassetid://243660364"

local hidden: { [Instance]: { [string]: Model } } = {}

local function attributeName(facility: string): string
	return "FacilityLevel_" .. facility
end

local function setPromptsEnabled(model: Instance, enabled: boolean)
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d.Enabled = enabled
		end
	end
end

local function dustBurst(at: CFrame, size: Vector3, parent: Instance, amount: number)
	local emitterPart = Instance.new("Part")
	emitterPart.Name = "ConstructionDust"
	emitterPart.Anchored, emitterPart.CanCollide, emitterPart.CanTouch, emitterPart.CanQuery = true, false, false, false
	emitterPart.Transparency = 1
	emitterPart.Size = Vector3.new(math.max(size.X, 4), 1, math.max(size.Z, 4))
	emitterPart.CFrame = at
	emitterPart.Parent = parent
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(196, 176, 140))
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	dust.Size = NumberSequence.new(3, 9)
	dust.Lifetime = NumberRange.new(1.2, 2.2)
	dust.Speed = NumberRange.new(4, 9)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.Rate = 0
	dust.Parent = emitterPart
	dust:Emit(amount)
	task.delay(3, function() emitterPart:Destroy() end)
end

-- Wooden scaffold poles around the footprint that sink away as the building rises.
local function scaffold(cf: CFrame, size: Vector3, parent: Instance): { BasePart }
	local poles = {}
	local hx, hz = size.X / 2 + 1, size.Z / 2 + 1
	for _, corner in { Vector2.new(-hx, -hz), Vector2.new(hx, -hz), Vector2.new(-hx, hz), Vector2.new(hx, hz), Vector2.new(0, -hz), Vector2.new(0, hz) } do
		local pole = Instance.new("Part")
		pole.Name = "Scaffold"
		pole.Anchored, pole.CanCollide, pole.CanTouch, pole.CanQuery = true, false, false, false
		pole.Material = Enum.Material.WoodPlanks
		pole.Color = Color3.fromRGB(150, 112, 70)
		pole.Size = Vector3.new(0.6, size.Y, 0.6)
		pole.CFrame = cf * CFrame.new(corner.X, 0, corner.Y)
		pole.Parent = parent
		table.insert(poles, pole)
	end
	return poles
end

-- Construction reveal: dust, scaffolding, the building rising out of the ground.
local function reveal(model: Model)
	local cf, size = model:GetBoundingBox()
	local finalPivot = model:GetPivot()
	local groundCF = cf * CFrame.new(0, -size.Y / 2, 0)
	setPromptsEnabled(model, false)
	local poles = scaffold(cf, size, model.Parent or workspace)
	dustBurst(groundCF, size, model.Parent or workspace, 60)
	local depth = size.Y + 1
	model:PivotTo(finalPivot * CFrame.new(0, -depth, 0))
	task.spawn(function()
		local started = os.clock()
		while true do
			local t = math.clamp((os.clock() - started) / REVEAL_SECONDS, 0, 1)
			local eased = 1 - (1 - t) ^ 3
			if model.Parent == nil then break end
			model:PivotTo(finalPivot * CFrame.new(0, -depth * (1 - eased), 0))
			for _, pole in poles do
				pole.Transparency = eased
			end
			if t >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		for _, pole in poles do pole:Destroy() end
		if model.Parent then
			model:PivotTo(finalPivot)
			setPromptsEnabled(model, true)
			dustBurst(groundCF, size, model.Parent, 25)
		end
	end)
end

-- Level-up burst for a building that is already standing.
local function upgradeBurst(model: Model)
	local cf, size = model:GetBoundingBox()
	dustBurst(cf * CFrame.new(0, -size.Y / 2, 0), size, model.Parent or workspace, 35)
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = Color3.fromRGB(255, 226, 150)
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if anchor then
		sparkle.Parent = anchor
		task.delay(2, function() sparkle:Destroy() end)
	end
end

local function applyBuilding(plot: Instance, facility: string, level: number, previous: number?)
	local folder = plot:FindFirstChild("PlotBuildings")
	local name = BUILDINGS[facility]
	local live = folder and folder:FindFirstChild(name)
	local stash = hidden[plot] or {}
	hidden[plot] = stash
	local stashed = stash[facility]
	-- Keep courtyard architecture permanently visible in the redesigned island layout;
	-- restore any previously stashed model back into PlotBuildings.
	if not live and stashed and folder then
		stashed.Parent = folder
		stash[facility] = nil
		live = stashed
	elseif live and stashed then
		stashed:Destroy()
		stash[facility] = nil
	end
	if live and live:IsA("Model") and level > 0 and previous ~= nil and level > previous then
		if previous <= 0 then
			reveal(live)
		else
			upgradeBurst(live)
		end
	end
end

local function applyAngel(plot: Instance, level: number, previous: number?)
	local statue = AngelStatue.Apply(plot, level)
	if statue and previous ~= nil and level > previous then
		if previous <= 0 then
			reveal(statue)
		else
			upgradeBurst(statue)
		end
	end
end

-- `levels` maps facility -> level (missing = 0). Animations play only for increases since the last
-- Apply on this plot; the first Apply after Reset (a join) builds silently.
function FacilityPresence.Apply(plot: Instance, levels: { [string]: number })
	for _, facility in GATED do
		local level = levels[facility] or 0
		local previousAttr = plot:GetAttribute(attributeName(facility))
		local previous = if type(previousAttr) == "number" then previousAttr else nil
		plot:SetAttribute(attributeName(facility), level)
		if facility == "GodsBlessing" then
			applyAngel(plot, level, previous)
		else
			applyBuilding(plot, facility, level, previous)
		end
	end
end

-- Re-applies the mirrored levels without animation (after PlotBuildings is rebuilt or the fountain
-- appears). Plots with no owner have every gated facility hidden.
function FacilityPresence.Reapply(plot: Instance)
	for _, facility in GATED do
		local attr = plot:GetAttribute(attributeName(facility))
		local level = if type(attr) == "number" then attr else 0
		if facility == "GodsBlessing" then
			AngelStatue.Apply(plot, level)
		else
			applyBuilding(plot, facility, level, nil)
		end
	end
end

-- The owner left: hide everything and forget the levels so the next owner's join builds silently.
function FacilityPresence.Reset(plot: Instance)
	for _, facility in GATED do
		plot:SetAttribute(attributeName(facility), nil)
	end
	FacilityPresence.Reapply(plot)
end

function FacilityPresence.Pulse(plot: Instance)
	AngelStatue.Pulse(plot)
end

return FacilityPresence
