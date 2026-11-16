--!strict
-- ServerScriptService/Core/FacilityPresence.luau
-- Support facilities exist in the world only once unlocked in the Fortress Tree (Phase 4 §5.6).
-- Locked buildings are taken out of the DataModel (so nothing replicates or prompts), a level 1
-- unlock plays a construction reveal, and later levels play an upgrade burst. Levels are mirrored
-- on the plot as attributes so a rebuilt PlotBuildings folder can be re-hidden without the profile.
--
-- A plot nobody owns stands empty: every Building_* model in PlotBuildings (the Guard Post included) and
-- the plaza fountain are taken out of the DataModel until a Master is assigned the plot. The fortress walls
-- and gatehouses, the courtyard (floor, lanterns, benches) and the outskirts scenery (trees, rocks, trail)
-- remain; KEEP_WALLS_WHEN_VACANT = false would also clear the walls and courtyard accents.

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

-- What an unoccupied plot has removed: the buildings, the fountain, the walls and the courtyard accents.
local BUILDING_PREFIX = "Building_"
local FOUNTAIN_NAME = "PlazaFountain"
local ISLAND_NAME = "FloatingFortressIsland"
local WALLS_NAME = "FortressWalls"
local ACCENTS_NAME = "CourtyardAccents"
-- Stays inside the walls model: it stops players walking off the island's edge.
local EDGE_BARRIERS_NAME = "InvisibleEdgeBarriers"
-- Set to true to leave the plaza fountain standing on unoccupied plots.
local KEEP_FOUNTAIN_WHEN_VACANT = false
-- Leaves the fortress walls, gatehouses and courtyard lanterns standing on unoccupied plots.
local KEEP_WALLS_WHEN_VACANT = true

-- Removed pieces, keyed by "<home path>/<name>". Each remembers the container it came from, so a piece
-- whose container was rebuilt in the meantime is dropped instead of being put back into the new one.
type Stashed = { Home: Instance, Insts: { Instance } }
local vacated: { [Instance]: { [string]: Stashed } } = {}

function FacilityPresence.IsOccupied(plot: Instance): boolean
	local owner = plot:GetAttribute("OwnerUserId")
	return type(owner) == "number" and owner > 0
end

local function stashKey(homePath: string, name: string): string
	return homePath .. "/" .. name
end

-- Removes every building, the fountain, the walls and the courtyard accents from a plot with no owner.
-- A piece rebuilt while the plot stood empty replaces the stashed copy of the same name.
local function vacate(plot: Instance)
	local taken: { [string]: Stashed } = {}
	local function take(home: Instance, homePath: string, inst: Instance)
		local key = stashKey(homePath, inst.Name)
		local entry = taken[key]
		if not entry then
			entry = { Home = home, Insts = {} }
			taken[key] = entry
		end
		table.insert(entry.Insts, inst)
		inst.Parent = nil
	end

	local folder = plot:FindFirstChild("PlotBuildings")
	if folder then
		for _, building in folder:GetChildren() do
			-- Everything else in the folder is outskirts scenery, which stays
			if building:IsA("Model") and string.sub(building.Name, 1, #BUILDING_PREFIX) == BUILDING_PREFIX then
				take(folder, "PlotBuildings", building)
			end
		end
	end
	if not KEEP_FOUNTAIN_WHEN_VACANT then
		local fountain = plot:FindFirstChild(FOUNTAIN_NAME)
		if fountain then
			take(plot, "", fountain)
		end
	end
	local island = plot:FindFirstChild(ISLAND_NAME)
	if island and not KEEP_WALLS_WHEN_VACANT then
		local accents = island:FindFirstChild(ACCENTS_NAME)
		if accents then
			take(island, ISLAND_NAME, accents)
		end
		local walls = island:FindFirstChild(WALLS_NAME)
		if walls then
			for _, piece in walls:GetChildren() do
				if piece.Name ~= EDGE_BARRIERS_NAME then
					take(walls, ISLAND_NAME .. "/" .. WALLS_NAME, piece)
				end
			end
		end
	end

	if next(taken) == nil then
		return
	end
	local stash = vacated[plot] or {}
	vacated[plot] = stash
	for key, entry in taken do
		local older = stash[key]
		if older then
			for _, inst in older.Insts do
				if not table.find(entry.Insts, inst) then
					inst:Destroy()
				end
			end
		end
		stash[key] = entry
	end
end

-- Puts back what vacate removed. A copy rebuilt in the meantime wins over the stashed one, and pieces
-- whose container is gone are dropped.
local function occupy(plot: Instance)
	local stash = vacated[plot]
	if not stash then
		return
	end
	vacated[plot] = nil
	for _, entry in stash do
		local home = entry.Home
		local homeAlive = home == plot or home:IsDescendantOf(plot)
		local name = entry.Insts[1] and entry.Insts[1].Name
		-- Checked once per key, before any copy goes back, so same-named wall pieces all return
		local rebuilt = homeAlive and name ~= nil and home:FindFirstChild(name) ~= nil
		for _, inst in entry.Insts do
			if homeAlive and not rebuilt then
				inst.Parent = home
			else
				inst:Destroy()
			end
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

-- Returns the live or off-tree stashed facility model if one is present for this plot.
function FacilityPresence.GetBuilding(plot: Instance, facility: string): Model?
	local name = BUILDINGS[facility]
	if not name then
		return nil
	end
	local folder = plot:FindFirstChild("PlotBuildings")
	local live = folder and folder:FindFirstChild(name)
	if live and live:IsA("Model") then
		return live
	end
	local stash = hidden[plot]
	local stashed = if stash then stash[facility] else nil
	if stashed and stashed:IsA("Model") then
		return stashed
	end
	-- Removed because the plot is unoccupied
	local vacant = vacated[plot]
	local entry = if vacant then vacant[stashKey("PlotBuildings", name)] else nil
	local removed = if entry then entry.Insts[1] else nil
	return if removed and removed:IsA("Model") then removed else nil
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
