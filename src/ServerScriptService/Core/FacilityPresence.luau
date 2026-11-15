--!strict
-- ServerScriptService/Core/FacilityPresence.luau
-- Support facilities exist in the world only once unlocked in the Fortress Tree (Phase 4 §5.6).
-- Locked buildings are taken out of the DataModel (so nothing replicates or prompts), a level 1
-- unlock plays a construction reveal, and later levels play an upgrade burst. Levels are mirrored
-- on the plot as attributes so a rebuilt PlotBuildings folder can be re-hidden without the profile.
--
-- A plot nobody owns stands empty: every Building_* model in PlotBuildings (the Guard Post included)
-- and the plaza fountain are taken out of the DataModel until a Master is assigned the plot. The walls,
-- the courtyard and the outskirts scenery (trees, rocks, trail) remain.

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

-- What an unoccupied plot has had removed: building models by name, and the fountain.
local BUILDING_PREFIX = "Building_"
local FOUNTAIN_NAME = "PlazaFountain"
-- Set to true to leave the plaza fountain standing on unoccupied plots.
local KEEP_FOUNTAIN_WHEN_VACANT = false
local vacated: { [Instance]: { [string]: Instance } } = {}

function FacilityPresence.IsOccupied(plot: Instance): boolean
	local owner = plot:GetAttribute("OwnerUserId")
	return type(owner) == "number" and owner > 0
end

-- Takes `inst` out of the DataModel and remembers it under `key`. A newer copy replaces an older one.
local function stashVacant(plot: Instance, key: string, inst: Instance)
	local stash = vacated[plot] or {}
	vacated[plot] = stash
	local older = stash[key]
	if older and older ~= inst then
		older:Destroy()
	end
	inst.Parent = nil
	stash[key] = inst
end

-- Removes every building (and the fountain) from a plot with no owner.
local function vacate(plot: Instance)
	local folder = plot:FindFirstChild("PlotBuildings")
	if folder then
		for _, building in folder:GetChildren() do
			-- Everything else in the folder is outskirts scenery, which stays
			if building:IsA("Model") and string.sub(building.Name, 1, #BUILDING_PREFIX) == BUILDING_PREFIX then
				stashVacant(plot, building.Name, building)
			end
		end
	end
	if not KEEP_FOUNTAIN_WHEN_VACANT then
		local fountain = plot:FindFirstChild(FOUNTAIN_NAME)
		if fountain then
			stashVacant(plot, FOUNTAIN_NAME, fountain)
		end
	end
end

-- Whether a building that is not in the plot's folder is only put away (the plot is unoccupied, or the
-- facility is still locked), as opposed to missing. PlotBuildings uses it to keep its cached folder.
function FacilityPresence.Holds(plot: Instance, buildingName: string): boolean
	local vacant = vacated[plot]
	if vacant and vacant[buildingName] then
		return true
	end
	local stash = hidden[plot]
	if stash then
		for _, model in stash do
			if model.Name == buildingName then
				return true
			end
		end
	end
	return false
end

-- Puts back what vacate removed. A copy rebuilt in the meantime wins over the stashed one.
local function occupy(plot: Instance)
	local stash = vacated[plot]
	if not stash then
		return
	end
	vacated[plot] = nil
	local folder = plot:FindFirstChild("PlotBuildings")
	for key, inst in stash do
		local home: Instance? = if key == FOUNTAIN_NAME then plot else folder
		if home and not home:FindFirstChild(key) then
			inst.Parent = home
		else
			inst:Destroy()
		end
	end
end

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
	-- A freshly rebuilt folder supersedes an older hidden copy.
	if live and stashed then
		stashed:Destroy()
		stash[facility] = nil
		stashed = nil
	end
	-- Phase 4 §5.6: a support facility exists in the world only once its first tree node is built.
	if level > 0 then
		if not live and stashed and folder then
			stashed.Parent = folder
			stash[facility] = nil
			if previous ~= nil and previous <= 0 then
				reveal(stashed)
			end
		elseif not live and not stashed and folder then
			-- Self-healing: if facility was wiped from folder and not stashed, rebuild PlotBuildings
			local ok, PlotBuildings = pcall(function()
				return require(script.Parent:WaitForChild("PlotBuildings"))
			end)
			if ok and PlotBuildings then
				PlotBuildings.Build(plot)
			end
		elseif live and live:IsA("Model") and previous ~= nil and level > previous then
			upgradeBurst(live)
		end
	elseif live and live:IsA("Model") then
		live.Parent = nil
		stash[facility] = live
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
	if FacilityPresence.IsOccupied(plot) then
		occupy(plot)
	end
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
	-- RunService:IsEdit() requires plugin capability and throws in game scripts, which used to
	-- abort PlotManager before any plot was assigned. IsStudio + not IsRunning is the safe equivalent.
	if RunService:IsStudio() and not RunService:IsRunning() then
		return
	end
	local occupied = FacilityPresence.IsOccupied(plot)
	if occupied then
		occupy(plot)
	end
	for _, facility in GATED do
		local attr = plot:GetAttribute(attributeName(facility))
		local level = if type(attr) == "number" then attr else 0
		if facility == "GodsBlessing" then
			AngelStatue.Apply(plot, level)
		else
			applyBuilding(plot, facility, level, nil)
		end
	end
	if not occupied then
		-- After the gated pass, so the statue is gone before its fountain is removed
		vacate(plot)
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
