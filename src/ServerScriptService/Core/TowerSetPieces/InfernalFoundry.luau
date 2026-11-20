--!strict
-- Hand-authored set pieces for the Infernal Foundry floors (docs/prompts/infernal-foundry-floor-layouts-prompt.md).
-- TowerBiomeAssets calls Floor21(ctx) for layout.Authored == "infernal:1" with its own builders (ctx), so this
-- module needs nothing from the place at load time and its placement data can be checked by the specs.
--
-- Floor 21, Slagworks Entry: the Sootwrights' outer works. A rail yard round the Great Turntable (a shunting
-- engine and an ore tub parked on it), the Weighbridge and its office, the Ore Crusher on its gantry, coal
-- hoppers over the Coal Bunker, the Slag Tip with its ladle, the Sorting Shed, the water tower, sidings with
-- buffer stops and a derailed tub, and the hammer-ring Furnace Gate under a soot-brick works with smoking
-- flue stacks: three skyline layers (yard props, mid landmarks, the far works and stacks).
local InfernalFoundry = {}

local V = Vector3.new
local rgb = Color3.fromRGB

-- Sootwright palette.
local IRON = rgb(70, 64, 64)
local IRON_DARK = rgb(44, 40, 42)
local BRICK = rgb(92, 56, 46)
local BRICK_DARK = rgb(62, 40, 36)
local BRASS = rgb(150, 112, 58)
local RUST = rgb(112, 62, 40)
local TIMBER = rgb(58, 44, 36)
local COAL = rgb(30, 28, 30)
local ORE = rgb(108, 72, 56)
local SLAG = rgb(42, 36, 38)
local EMBER = rgb(255, 120, 40)
local LAMP = rgb(255, 188, 110)

export type Landmark = {
	Id: string,
	X: number, -- footprint centre (local floor space)
	Z: number,
	Y: number?, -- the surface it stands on; nil: the ground (terrain) under it
	HalfX: number, -- footprint half extents, already turned by the piece's yaw
	HalfZ: number,
	Top: number, -- height above its surface
}

-- Every Floor 21 landmark's footprint, for the specs (no landmark on a walkway or in a camp) and the census.
InfernalFoundry.Floor21Landmarks = table.freeze({
	{ Id = "TurntableEngine", X = 0, Z = -14, Y = 4, HalfX = 3.6, HalfZ = 10.5, Top = 12.5 },
	{ Id = "TurntableTub", X = 0, Z = 1.5, Y = 4, HalfX = 4, HalfZ = 5.1, Top = 7 },
	{ Id = "TurntableCab", X = 36, Z = 24, Y = 4, HalfX = 6.8, HalfZ = 6.8, Top = 11.5 },
	{ Id = "WeighbridgeOffice", X = 50, Z = 54, HalfX = 6, HalfZ = 7, Top = 15 },
	{ Id = "OreCrusher", X = -150, Z = -139.6, Y = 16, HalfX = 16.3, HalfZ = 16.2, Top = 32 },
	{ Id = "CoalHoppers", X = 146, Z = -160.8, Y = 6, HalfX = 20.2, HalfZ = 8.1, Top = 26.6 },
	{ Id = "FurnaceGate", X = 0, Z = -243.9, Y = 20, HalfX = 36, HalfZ = 9, Top = 69.6 },
	{ Id = "SortingShed", X = -158, Z = 60, HalfX = 38, HalfZ = 11, Top = 27 },
	{ Id = "WaterTower", X = -62, Z = 155.4, Y = 0, HalfX = 8.9, HalfZ = 12.3, Top = 42.5 },
	{ Id = "SlagLadle", X = 184, Z = -50, Y = 12, HalfX = 5.5, HalfZ = 6.5, Top = 10 },
	{ Id = "RoastingKiln", X = -184, Z = 148, Y = 0, HalfX = 9.7, HalfZ = 9.7, Top = 41.2 },
	{ Id = "YardEngine", X = 150, Z = 158, Y = 0, HalfX = 10.5, HalfZ = 3.6, Top = 12.5 },
	{ Id = "YardCabin", X = 64, Z = 156, Y = 0, HalfX = 7.6, HalfZ = 7.6, Top = 13.8 },
	{ Id = "DerailedTub", X = 176, Z = 92, Y = 0, HalfX = 6.5, HalfZ = 6.5, Top = 6 },
}) :: { Landmark }

-- The kit's Sootwright tints (every Floor 21 template uses these roles).
local SOOT = table.freeze({
	METAL = { Color = IRON, Material = Enum.Material.Metal },
	TRIM = { Color = IRON_DARK, Material = Enum.Material.Metal },
	STONE = { Color = BRICK, Material = Enum.Material.Brick },
	GOLD = { Color = BRASS, Material = Enum.Material.Metal },
	WOOD = { Color = TIMBER, Material = Enum.Material.Wood },
	ALT = { Color = COAL, Material = Enum.Material.Basalt },
	ACCENT = { Color = RUST, Material = Enum.Material.CorrodedMetal },
	GLOW = { Color = EMBER, Material = Enum.Material.Neon },
	MOSS = { Color = EMBER, Material = Enum.Material.CrackedLava },
	CRYSTAL = { Color = EMBER, Material = Enum.Material.Glass, Transparency = 0.2 },
})
local function tinted(base: any, changes: { [string]: any }): any
	local o = table.clone(base)
	for role, swatch in changes do
		o[role] = swatch
	end
	return o
end
local ORE_TINT = tinted(SOOT, { ALT = { Color = ORE, Material = Enum.Material.Slate } })
local LAMP_TINT = tinted(SOOT, { GLOW = { Color = LAMP, Material = Enum.Material.Neon } })

-- The builders every Infernal floor shares: the surface under a spot, parts in local space, plumes, kit pieces
-- with part-built fallbacks, and the work-clutter pass.
local function helpers(ctx: any): any
	local origin: Vector3 = ctx.origin
	local layout = ctx.layout
	local field = ctx.field
	local bottom: number = ctx.bottom
	local d: number = ctx.d
	local P = layout.Platforms

	-- The surface at (x, z): a terrace's or deck's top, else the terrain (or the chasm floor without terrain).
	local function surfaceAt(x: number, z: number): (number, boolean)
		for id, p in P do
			if id ~= "Sanctuary" and math.abs(x - p.X) <= p.Width / 2 and math.abs(z - p.Z) <= p.Depth / 2 then
				return p.Y, true
			end
		end
		if field then
			return field.Height(x, z) + 1.6, false
		end
		return bottom, false
	end

	local function boxAt(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, trans: number?): Part
		local p = ctx.block(name, size, cf.Position, color, mat, nil, trans)
		p.CFrame = CFrame.new(origin) * cf
		return p
	end
	-- A cylinder from a to b (local space).
	local function rod(name: string, a: Vector3, b: Vector3, radius: number, color: Color3, mat: Enum.Material): Part
		local len = math.max(0.1, (b - a).Magnitude)
		local p = ctx.block(name, V(len, radius * 2, radius * 2), (a + b) / 2, color, mat, Enum.PartType.Cylinder)
		p.CFrame = CFrame.lookAt(origin + (a + b) / 2, origin + b) * CFrame.Angles(0, math.pi / 2, 0)
		return p
	end
	local function lump(name: string, at: Vector3, size: Vector3, color: Color3, mat: Enum.Material): Part
		return ctx.orb(name, at, size, color, mat)
	end
	local function light(p: Instance, color: Color3, brightness: number, range: number)
		ctx.pointLight(p, color, brightness, range)
	end
	local function plume(at: Vector3, color: Color3, size: number, rate: number, speed: number, lifetime: number)
		-- A smoke or ember plume (server-built like the earlier floors' vents; counted in the emitter budget).
		local anchor = ctx.block("PlumeAnchorSmoke", V(1, 1, 1), at, color, Enum.Material.SmoothPlastic, nil, 1)
		anchor.CanCollide = false
		anchor.CanQuery = false
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "FoundryPlume"
		pe.Color = ColorSequence.new(color, color:Lerp(Color3.new(0.1, 0.1, 0.1), 0.6))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.4), NumberSequenceKeypoint.new(1, size * 1.6) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		pe.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
		pe.Rate = rate
		pe.Speed = NumberRange.new(speed * 0.6, speed)
		pe.SpreadAngle = Vector2.new(14, 14)
		pe.Acceleration = V(1.5, 0.6, 0)
		pe.RotSpeed = NumberRange.new(-20, 20)
		pe.LightEmission = if color.R > 0.8 then 0.8 else 0
		pe.Parent = anchor
		return anchor
	end

	-- Places a kit template (or its native fallback) as one prop at (x, z) on whatever is under it, and returns
	-- the prop (its PropKind Model). On open terrain it is tagged OnTerrain, so the settle pass leaves it.
	local function piece(kind: string, x: number, z: number, yawDeg: number, kitName: string?, s: number, override: any?, fallback: ((cf: CFrame) -> ())?, y: number?, roll: CFrame?): Instance?
		local gy, onDeck = surfaceAt(x, z)
		local baseY = y or gy
		local prop: Instance? = nil
		ctx.group(kind, function()
			prop = ctx.current()
			if not onDeck and y == nil then
				ctx.tag("OnTerrain", true)
			end
			local cf = CFrame.new(x, baseY, z) * CFrame.Angles(0, math.rad(yawDeg), 0) * (roll or CFrame.identity)
			if kitName and ctx.has(kitName) then
				ctx.kitAt(kitName, cf * CFrame.new(0, if onDeck then 0 else -0.35, 0), s, override)
			elseif fallback then
				fallback(cf)
			end
		end)
		return prop
	end
	local function glowOf(prop: Instance?): Instance?
		return if prop then prop:FindFirstChild("GLOW", true) else nil
	end
	local function noCollide(m: Instance?)
		if not m then return end
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.CanQuery = false
				p.CastShadow = false
			end
		end
	end

	-- Native fallbacks (until the Floor 21 kit is imported). cf: the piece's origin on its surface, front +Z.
	local function fallbackCart(cf: CFrame)
		boxAt("OreTubBody", V(4.6, 3, 8.4), cf * CFrame.new(0, 3.6, 0), IRON, Enum.Material.Metal)
		boxAt("OreTubRim", V(5.2, 0.5, 9), cf * CFrame.new(0, 5.1, 0), RUST, Enum.Material.CorrodedMetal)
		for _, zz in { -2.6, 2.6 } do
			for _, xx in { -2.5, 2.5 } do
				local wcf = cf * CFrame.new(xx, 1.15, zz)
				boxAt("OreTubWheel", V(0.5, 2.3, 2.3), wcf, IRON_DARK, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
			end
		end
		lump("OreTubLoad", (cf * CFrame.new(0, 5.2, 0)).Position, V(4.2, 2.2, 7.6), ORE, Enum.Material.Slate)
	end
	local function fallbackEngine(cf: CFrame)
		boxAt("EngineFrame", V(4.6, 1.2, 17), cf * CFrame.new(0, 2.3, 0), IRON_DARK, Enum.Material.Metal)
		local boiler = boxAt("EngineBoiler", V(10.5, 4.6, 4.6), cf * CFrame.new(0, 5.4, 2.6) * CFrame.Angles(0, math.pi / 2, 0), IRON, Enum.Material.Metal)
		boiler.Shape = Enum.PartType.Cylinder
		boxAt("EngineSaddleTank", V(6, 3.6, 8.4), cf * CFrame.new(0, 6.2, 1.8), IRON, Enum.Material.Metal)
		boxAt("EngineCab", V(6.2, 6.4, 4.6), cf * CFrame.new(0, 6.1, -4.4), IRON, Enum.Material.Metal)
		boxAt("EngineCabRoof", V(7, 0.5, 5.6), cf * CFrame.new(0, 9.5, -4.4), IRON_DARK, Enum.Material.Metal)
		boxAt("EngineChimney", V(1.8, 4.2, 1.8), cf * CFrame.new(0, 9.4, 6.6), IRON_DARK, Enum.Material.Metal)
		boxAt("EngineDome", V(2.2, 1.6, 2.2), cf * CFrame.new(0, 8.4, 3), BRASS, Enum.Material.Metal)
		for _, zz in { -5.2, -0.6, 4 } do
			for _, xx in { -2.5, 2.5 } do
				boxAt("EngineWheel", V(0.6, 3.8, 3.8), cf * CFrame.new(xx, 1.9, -zz), IRON_DARK, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
			end
		end
	end
	local function fallbackCabin(cf: CFrame)
		boxAt("CabinFooting", V(9.4, 1.2, 8.4), cf * CFrame.new(0, 0.3, 0), BRICK_DARK, Enum.Material.Brick)
		boxAt("CabinBody", V(8.6, 7, 7.6), cf * CFrame.new(0, 4.4, 0), IRON, Enum.Material.CorrodedMetal)
		for _, side in { -1, 1 } do
			boxAt("CabinRoof", V(10, 0.4, 5), cf * CFrame.new(0, 9, side * 2) * CFrame.Angles(side * math.rad(24), 0, 0), IRON_DARK, Enum.Material.Metal)
		end
		local win = boxAt("CabinWindow", V(3, 2, 0.2), cf * CFrame.new(1.8, 5.4, 3.9), LAMP, Enum.Material.Neon)
		light(win, LAMP, 0.8, 22)
	end
	local function fallbackSignal(cf: CFrame)
		boxAt("SignalBase", V(1.8, 0.8, 1.8), cf * CFrame.new(0, 0.4, 0), IRON, Enum.Material.Metal)
		boxAt("SignalPost", V(0.6, 9, 0.6), cf * CFrame.new(0, 5.3, 0), IRON_DARK, Enum.Material.Metal)
		boxAt("SignalHousing", V(1.4, 1.6, 1.2), cf * CFrame.new(0, 8.2, 0.4), IRON, Enum.Material.Metal)
		boxAt("SignalLampGlow", V(0.9, 0.9, 0.2), cf * CFrame.new(0, 8.2, 1.05), LAMP, Enum.Material.Neon)
	end
	local function fallbackBuffer(cf: CFrame)
		boxAt("BufferBeam", V(7, 1.6, 1.2), cf * CFrame.new(0, 2.8, 1.2), TIMBER, Enum.Material.Wood)
		for _, xx in { -2.6, 2.6 } do
			local brace = boxAt("BufferBrace", V(0.6, 0.6, 4.6), cf * CFrame.new(xx, 1.7, -0.8) * CFrame.Angles(math.rad(38), 0, 0), IRON_DARK, Enum.Material.Metal)
			brace.CanCollide = false
			boxAt("BufferHead", V(1.4, 1.7, 1.7), cf * CFrame.new(xx * 0.77, 2.8, 2.5) * CFrame.Angles(0, math.pi / 2, 0), IRON, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
		end
		boxAt("BufferLampBoard", V(1.6, 1.6, 0.25), cf * CFrame.new(0, 4.4, 1.9), RUST, Enum.Material.CorrodedMetal)
	end
	local function fallbackHeap(cf: CFrame, color: Color3, mat: Enum.Material)
		lump("CoalHeapMound", (cf * CFrame.new(0, 0.6, 0)).Position, V(9, 3.4, 7), color, mat)
		lump("CoalHeapMound", (cf * CFrame.new(3.6, 0.4, 2)).Position, V(5, 2.4, 4.4), color, mat)
	end
	local function fallbackScrap(cf: CFrame)
		lump("ScrapClinkerBed", (cf * CFrame.new(0, 0.2, 0)).Position, V(14, 2.4, 11), SLAG, Enum.Material.Basalt)
		for k = 1, 5 do
			boxAt("ScrapPlate", V(3.6, 0.3, 2.6), cf * CFrame.new((k - 3) * 2.2, 1.6 + (k % 2) * 0.6, (k % 3 - 1) * 2) * CFrame.Angles(math.rad(20 * (k % 3 - 1)), k * 0.9, math.rad(25 * (k % 2))), if k % 2 == 0 then RUST else IRON, Enum.Material.CorrodedMetal)
		end
	end
	local function fallbackStack(cf: CFrame, s: number)
		boxAt("FlueStackPlinth", V(14, 10, 14) * s, cf * CFrame.new(0, 5 * s, 0), BRICK_DARK, Enum.Material.Brick)
		local shaft = boxAt("FlueStackShaft", V(86 * s, 9.2 * s, 9.2 * s), cf * CFrame.new(0, (10 + 43) * s, 0) * CFrame.Angles(0, 0, math.pi / 2), BRICK, Enum.Material.Brick)
		shaft.Shape = Enum.PartType.Cylinder
		for k = 1, 5 do
			local band = boxAt("FlueStackBand", V(0.8 * s, 9.9 * s, 9.9 * s), cf * CFrame.new(0, (14 + k * 15) * s, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON_DARK, Enum.Material.Metal)
			band.Shape = Enum.PartType.Cylinder
		end
		local crown = boxAt("FlueStackCrown", V(3 * s, 10.4 * s, 10.4 * s), cf * CFrame.new(0, 97.5 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal)
		crown.Shape = Enum.PartType.Cylinder
	end

	-- Work clutter: every terrace a vignette (crates, barrels, tool racks, ingot moulds, coal), dressing both
	-- ends of every link off the lanes, vignettes over the open ground, then cheap ground cover. Spots are
	-- checked against lanes (footprintClear), camps and the landmarks, and skipped when taken. Returns
	-- (props, ground cover) placed.
	local function workClutter(landmarkList: { Landmark }, seed: number, openVignettes: number, groundCount: number): (number, number)
		local props, cover = 0, 0
		local function campFree(x: number, z: number, r: number): boolean
			for _, camp in layout.Camps do
				if (camp.X - x) ^ 2 + (camp.Z - z) ^ 2 < (36 + r) ^ 2 then
					return false
				end
			end
			return true
		end
		local function barrel(cf: CFrame)
			ctx.cyl("FuelDrum", (cf * CFrame.new(0, 1.6, 0)).Position, 1.2, 3.2, if (cf.Position.X + cf.Position.Z) % 2 < 1 then RUST else IRON, Enum.Material.CorrodedMetal)
		end
		local function crate(cf: CFrame)
			boxAt("PartsCrate", V(3.4, 2.6, 3.4), cf * CFrame.new(0, 1.3, 0), TIMBER, Enum.Material.WoodPlanks)
			boxAt("PartsCrateBand", V(3.6, 0.3, 3.6), cf * CFrame.new(0, 2.1, 0), IRON_DARK, Enum.Material.Metal)
		end
		local function toolRack(cf: CFrame)
			boxAt("ToolRackFrame", V(6, 5, 0.6), cf * CFrame.new(0, 2.5, 0), TIMBER, Enum.Material.Wood)
			for k = -2, 2 do
				local tool = boxAt("ToolRackHammer", V(0.4, 3.6, 0.4), cf * CFrame.new(k * 1.1, 2.6, 0.5), IRON_DARK, Enum.Material.Metal)
				tool.CanCollide = false
			end
		end
		local function mould(cf: CFrame)
			boxAt("IngotMould", V(5, 1.2, 3), cf * CFrame.new(0, 0.6, 0), IRON_DARK, Enum.Material.Metal)
			boxAt("IngotMouldSlagGlowSeam", V(4, 0.2, 2), cf * CFrame.new(0, 1.25, 0), rgb(150, 70, 40), Enum.Material.CrackedLava)
		end
		type ClutterKind = { Name: string, Kit: string?, Scale: number, Fallback: ((cf: CFrame) -> ())?, R: number }
		local kinds: { ClutterKind } = {
			{ Name = "FuelDrums", Kit = nil, Scale = 1, Fallback = barrel, R = 2.4 },
			{ Name = "PartsCrates", Kit = nil, Scale = 1, Fallback = crate, R = 3 },
			{ Name = "ToolRack", Kit = nil, Scale = 1, Fallback = toolRack, R = 3.6 },
			{ Name = "IngotMould", Kit = nil, Scale = 1, Fallback = mould, R = 3.2 },
			{ Name = "ForgeScrap", Kit = "ForgeScrap", Scale = 0.6, Fallback = nil, R = 4.5 },
			{ Name = "CoalPile", Kit = "CoalHeap", Scale = 0.55, Fallback = function(cf) fallbackHeap(cf, COAL, Enum.Material.Basalt) end, R = 4 },
			{ Name = "OrePile", Kit = "CoalHeap", Scale = 0.5, Fallback = function(cf) fallbackHeap(cf, ORE, Enum.Material.Slate) end, R = 3.6 },
			{ Name = "Signal", Kit = "SignalLamp", Scale = 0.8, Fallback = fallbackSignal, R = 1.6 },
		}
		local taken: { { number } } = {}
		local function spotFree(x: number, z: number, r: number): boolean
			for _, t in taken do
				if (t[1] - x) ^ 2 + (t[2] - z) ^ 2 < (t[3] + r) ^ 2 then
					return false
				end
			end
			return campFree(x, z, r) and ctx.footprintClear(x, z, r + 1, r + 1)
		end
		for _, lm in landmarkList do
			table.insert(taken, { lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ) + 2 })
		end
		local rng = Random.new(seed * 7907)
		local function vignette(cx: number, cz: number, spread: number, count: number, y: number?)
			local made = 0
			for _ = 1, count * 6 do
				if made >= count then break end
				local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, spread)
				local x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
				local kind = kinds[rng:NextInteger(1, #kinds)]
				local rad = kind.R
				local gy = surfaceAt(x, z)
				local dry = y ~= nil or not field or field.Kind(x, z) ~= "POOL"
				if dry and math.abs(x) < ctx.w / 2 - 8 and math.abs(z) < d / 2 - 8 and spotFree(x, z, rad) and (y == nil or math.abs(gy - y) < 0.5) then
					table.insert(taken, { x, z, rad })
					ctx.reserve(x, z, rad)
					local m = piece(kind.Name, x, z, rng:NextNumber(0, 360), kind.Kit, kind.Scale, if kind.Name == "OrePile" then ORE_TINT else SOOT, kind.Fallback, y)
					if kind.Name ~= "Signal" then noCollide(m) end
					made += 1
				end
			end
			return made
		end
		-- Each terrace's free corners, both ends of every link, the yard edges and the open ground between.
		for id, p in P do
			if id ~= "Sanctuary" then
				for _, sx in { -1, 1 } do
					for _, sz in { -1, 1 } do
						props += vignette(p.X + sx * (p.Width / 2 - 7), p.Z + sz * (p.Depth / 2 - 7), 8, 3, p.Y)
					end
				end
			end
		end
		for _, link in layout.Links do
			local dx, dz = link.BX - link.AX, link.BZ - link.AZ
			local len = math.sqrt(dx * dx + dz * dz)
			local nx, nz = -dz / len, dx / len
			for _, endpoint in { { link.AX, link.AZ, link.AY }, { link.BX, link.BZ, link.BY } } do
				for _, side in { -1, 1 } do
					props += vignette(endpoint[1] + nx * side * 26, endpoint[2] + nz * side * 26, 6, 2)
				end
			end
		end
		for _ = 1, openVignettes do
			props += vignette(rng:NextNumber(-ctx.w / 2 + 30, ctx.w / 2 - 30), rng:NextNumber(-d / 2 + 40, d / 2 - 60), 14, 3)
		end

		-- Ground cover: coal and ore lumps, clinker and scrap strewn over the open yard ground (cheap, never solid).
		for _ = 1, groundCount do
			local x, z = rng:NextNumber(-ctx.w / 2 + 16, ctx.w / 2 - 16), rng:NextNumber(-d / 2 + 16, d / 2 - 16)
			local _, onDeck = surfaceAt(x, z)
			local r = 2.2
			if not onDeck and spotFree(x, z, r) and (not field or (field.Slope(x, z) < 0.8 and field.Kind(x, z) ~= "POOL")) then
				table.insert(taken, { x, z, r })
				ctx.reserve(x, z, r)
				local pick = rng:NextInteger(1, 4)
				local m = piece("GroundCover", x, z, rng:NextNumber(0, 360), if pick <= 2 then "CoalHeap" else "BoulderCluster", rng:NextNumber(0.25, 0.45), if pick == 1 then SOOT elseif pick == 2 then ORE_TINT else tinted(SOOT, { STONE = { Color = SLAG, Material = Enum.Material.Basalt } }), function(cf)
					lump("ClinkerLump", (cf * CFrame.new(0, 0.3, 0)).Position, V(2.4, 1, 2), if pick == 2 then ORE else SLAG, Enum.Material.Basalt)
				end)
				noCollide(m)
				cover += 1
			end
		end

		return props, cover
	end
	return {
		origin = origin,
		layout = layout,
		field = field,
		bottom = bottom,
		d = d,
		P = P,
		surfaceAt = surfaceAt,
		boxAt = boxAt,
		rod = rod,
		lump = lump,
		light = light,
		plume = plume,
		piece = piece,
		glowOf = glowOf,
		noCollide = noCollide,
		fallbackCart = fallbackCart,
		fallbackEngine = fallbackEngine,
		fallbackCabin = fallbackCabin,
		fallbackSignal = fallbackSignal,
		fallbackBuffer = fallbackBuffer,
		fallbackHeap = fallbackHeap,
		fallbackScrap = fallbackScrap,
		fallbackStack = fallbackStack,
		workClutter = workClutter,
	}
end

function InfernalFoundry.Floor21(ctx: any)
	local H = helpers(ctx)
	local origin: Vector3, layout, field, bottom: number, d: number, P = H.origin, H.layout, H.field, H.bottom, H.d, H.P
	local surfaceAt, boxAt, rod, lump, light, plume, piece = H.surfaceAt, H.boxAt, H.rod, H.lump, H.light, H.plume, H.piece
	local glowOf, noCollide = H.glowOf, H.noCollide
	local fallbackCart, fallbackEngine, fallbackCabin, fallbackSignal = H.fallbackCart, H.fallbackEngine, H.fallbackCabin, H.fallbackSignal
	local fallbackBuffer, fallbackHeap, fallbackScrap, fallbackStack = H.fallbackBuffer, H.fallbackHeap, H.fallbackScrap, H.fallbackStack
	local landmarks, props, cover = 0, 0, 0

	for _, lm in InfernalFoundry.Floor21Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- =====================================================================================================
	-- 1. The Great Turntable: a shunting engine and an ore tub parked on the bridge, a cab hut on its rim.
	-- =====================================================================================================
	local cr = P.Crossing
	piece("TurntableEngine", cr.X, cr.Z - 14, 0, "TankLocomotive", 1, LAMP_TINT, fallbackEngine, cr.Y)
	piece("TurntableTub", cr.X, cr.Z + 1.5, 0, "OreCart", 1, ORE_TINT, fallbackCart, cr.Y)
	piece("TurntableCab", cr.X + 36, cr.Z + 24, -40, "SignalCabin", 0.9, LAMP_TINT, fallbackCabin, cr.Y)
	piece("TurntableSignal", cr.X - 36, cr.Z + 34, 30, "SignalLamp", 1.1, LAMP_TINT, fallbackSignal, cr.Y)
	ctx.reserve(cr.X, cr.Z, 46)
	landmarks += 1
	props += 4

	-- =====================================================================================================
	-- 2. The Weighbridge: its office beside the scale, brass lamps at the plate's corners.
	-- =====================================================================================================
	local wb = P.Weighbridge
	piece("WeighbridgeOffice", wb.X + 50, wb.Z, -90, "SignalCabin", 1.2, LAMP_TINT, fallbackCabin)
	ctx.reserve(wb.X + 50, wb.Z, 12)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			piece("WeighbridgeLamp", wb.X + sx * 26, wb.Z + sz * 7.5, if sz > 0 then 0 else 180, "SignalLamp", 0.85, LAMP_TINT, fallbackSignal, wb.Y)
		end
	end
	-- A stack of check weights and a coal scuttle by the office door.
	piece("WeighbridgeWeights", wb.X + 41, wb.Z + 9, 0, "MessCauldron", 0.7, SOOT, function(cf)
		ctx.cyl("CheckWeight", (cf * CFrame.new(0, 1, 0)).Position, 2, 2, IRON_DARK, Enum.Material.Metal)
	end)
	landmarks += 1
	props += 6

	-- =====================================================================================================
	-- 3. The Ore Crusher on its gantry deck, a tub waiting under the chute, ore spilled round it.
	-- =====================================================================================================
	local oc = P.OreCrusher
	local crusher = piece("OreCrusher", oc.X - 10, oc.Z - 12, 0, "OreCrusherJaw", 1.25, ORE_TINT, function(cf)
		boxAt("CrusherBed", V(32, 3, 22), cf * CFrame.new(0, 1.5, 0), BRICK_DARK, Enum.Material.Brick)
		boxAt("CrusherHousing", V(17.5, 15, 16), cf * CFrame.new(0, 11, 1.2), IRON, Enum.Material.Metal)
		for _, sx in { -1, 1 } do
			local wheel = boxAt("CrusherFlywheel", V(2, 21, 21), cf * CFrame.new(sx * 12, 15, 2.5), IRON_DARK, Enum.Material.Metal)
			wheel.Shape = Enum.PartType.Cylinder
		end
		boxAt("CrusherHopper", V(15, 8, 15), cf * CFrame.new(0, 23, 0.6), IRON, Enum.Material.Metal)
		lump("CrusherOreLoad", (cf * CFrame.new(0, 27, 0.6)).Position, V(12, 5, 12), ORE, Enum.Material.Slate)
	end, oc.Y)
	local crusherGlow = glowOf(crusher)
	if crusherGlow then light(crusherGlow, EMBER, 1.2, 30) end
	piece("CrusherTub", oc.X + 20, oc.Z - 22, 12, "OreCart", 1, ORE_TINT, fallbackCart, oc.Y)
	piece("CrusherSpill", oc.X - 30, oc.Z + 2, 40, "CoalHeap", 0.9, ORE_TINT, function(cf) fallbackHeap(cf, ORE, Enum.Material.Slate) end, oc.Y)
	piece("CrusherSignal", oc.X + 30, oc.Z - 26, 200, "SignalLamp", 1, LAMP_TINT, fallbackSignal, oc.Y)
	plume(V(oc.X - 10, oc.Y + 34, oc.Z - 12), rgb(120, 104, 96), 6, 3, 4, 6)
	landmarks += 1
	props += 4

	-- =====================================================================================================
	-- 4. Coal hoppers over the Coal Bunker, tubs on the siding under their chutes, coal heaped below.
	-- =====================================================================================================
	local cb = P.CoalBunker
	piece("CoalHoppers", cb.X + 6, cb.Z - 20, 0, "CoalHopper", 1.1, SOOT, function(cf)
		for _, xx in { -18.7, -6.3, 6.3, 18.7 } do
			for _, zz in { -5.5, 5.5 } do
				boxAt("HopperLeg", V(1.5, 20, 1.5), cf * CFrame.new(xx, 10, zz), IRON_DARK, Enum.Material.Metal)
			end
		end
		for _, xx in { -12.5, 0, 12.5 } do
			boxAt("HopperBin", V(11.5, 9, 11.5), cf * CFrame.new(xx, 20, 0), IRON, Enum.Material.Metal)
			lump("HopperCoal", (cf * CFrame.new(xx, 25, 0)).Position, V(10, 3.6, 10), COAL, Enum.Material.Basalt)
		end
	end, cb.Y)
	for _, xx in { -11.5, 12.5 } do
		piece("BunkerTub", cb.X + 6 + xx, cb.Z - 18, 90, "OreCart", 1, SOOT, fallbackCart, cb.Y)
	end
	for k, spot in { { 28, -4 }, { 24, 18 }, { -30, -22 } } do
		piece("BunkerCoal", cb.X + spot[1], cb.Z + spot[2], k * 47, "CoalHeap", 1.1 + k * 0.1, SOOT, function(cf) fallbackHeap(cf, COAL, Enum.Material.Basalt) end, cb.Y)
	end
	landmarks += 1
	props += 6

	-- =====================================================================================================
	-- 5. The Slag Tip: a slag ladle tipping over the terrace edge, slag pots and scrap, the glowing sump.
	-- =====================================================================================================
	local st = P.EastGallery
	local ladleX, ladleZ = st.X + 34, st.Z - 30
	ctx.reserve(ladleX, ladleZ, 9)
	ctx.group("SlagLadle", function()
		local cf = CFrame.new(ladleX, st.Y, ladleZ) * CFrame.Angles(0, math.rad(34), 0) -- tipping toward the slag heap
		boxAt("LadleBogie", V(6, 1.4, 9), cf * CFrame.new(0, 1.6, 0), IRON_DARK, Enum.Material.Metal)
		for _, zz in { -2.8, 2.8 } do
			for _, xx in { -2.6, 2.6 } do
				boxAt("LadleWheel", V(0.6, 2.2, 2.2), cf * CFrame.new(xx, 1.1, zz), IRON_DARK, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
			end
		end
		for _, xx in { -3.2, 3.2 } do
			boxAt("LadleTrunnion", V(1, 5, 1.6), cf * CFrame.new(xx, 4.6, 0), IRON, Enum.Material.Metal)
		end
		local bowl = boxAt("LadleBowl", V(6.6, 6, 6), cf * CFrame.new(0, 6.4, 0.6) * CFrame.Angles(math.rad(38), 0, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal)
		bowl.Shape = Enum.PartType.Cylinder
		local lip = boxAt("LadleSlagGlowSeam", V(0.6, 4.8, 4.8), cf * CFrame.new(0, 8.6, 2.9) * CFrame.Angles(math.rad(38), 0, 0) * CFrame.Angles(0, 0, math.pi / 2), EMBER, Enum.Material.Neon)
		lip.Shape = Enum.PartType.Cylinder
		light(lip, EMBER, 1.6, 34)
	end)
	plume(V(ladleX + 4, st.Y + 4, ladleZ + 6), EMBER, 1.2, 6, 6, 2.2)
	piece("SlagPot", st.X + 34, st.Z + 30, 20, "MessCauldron", 1.1, SOOT, function(cf)
		ctx.cyl("SlagPotBody", (cf * CFrame.new(0, 2.6, 0)).Position, 3.6, 5.2, IRON, Enum.Material.Metal)
	end)
	piece("SlagPot", st.X + 26, st.Z + 34, -30, "MessCauldron", 0.9, SOOT, function(cf)
		ctx.cyl("SlagPotBody", (cf * CFrame.new(0, 2.2, 0)).Position, 3, 4.4, IRON, Enum.Material.Metal)
	end)
	piece("SlagScrap", st.X - 32, st.Z - 30, 15, "ScrapHeap", 0.9, SOOT, fallbackScrap)
	piece("SlagSignal", st.X - 36, st.Z + 30, 120, "SignalLamp", 1, LAMP_TINT, fallbackSignal)
	-- The runoff sump at the slag fan's foot glows under its crust.
	if field then
		local sumpY = field.LiquidLevel + 0.6
		local glow = ctx.block("SlagSumpGlowSeam", V(30, 0.4, 10), V(172, sumpY, 48), EMBER, Enum.Material.SmoothPlastic, nil, 0.55)
		light(glow, EMBER, 1.4, 40)
		plume(V(172, sumpY + 1, 48), EMBER, 1, 5, 5, 2.5)
	end
	landmarks += 1
	props += 5

	-- =====================================================================================================
	-- 6. The Sorting Shed: an open-fronted iron shed below the gallery, chutes down from its roof bins,
	--    sorting grates and ore bins on the gallery's corners.
	-- =====================================================================================================
	local sh = P.WestGallery
	local shedX, shedZ = sh.X - 8, sh.Z + 60
	ctx.reserve(shedX, shedZ, 30)
	ctx.group("SortingShed", function()
		ctx.tag("OnTerrain", true)
		local gy = bottom
		if field then
			gy = math.huge
			for _, ox in { -36, -12, 12, 36 } do
				for _, oz in { -9, 9 } do
					gy = math.min(gy, field.Height(shedX + ox, shedZ + oz) + 1.2)
				end
			end
		end
		local base = CFrame.new(shedX, gy, shedZ)
		boxAt("ShedFloorSlab", V(76, 1.2, 22), base * CFrame.new(0, 0.2, 0), BRICK_DARK, Enum.Material.Brick)
		local roofY = 26
		for k = 0, 6 do
			local x = -36 + k * 12
			for _, zz in { -10, 10 } do
				boxAt("ShedColumn", V(1.4, roofY, 1.4), base * CFrame.new(x, roofY / 2, zz), IRON_DARK, Enum.Material.Metal)
			end
			-- Roof trusses: a raking pair per bay.
			for _, side in { -1, 1 } do
				local truss = boxAt("ShedTruss", V(0.8, 0.8, 12), base * CFrame.new(x, roofY + 2.2, side * 5.4) * CFrame.Angles(side * math.rad(22), 0, 0), IRON_DARK, Enum.Material.Metal)
				truss.CanCollide = false
			end
		end
		boxAt("ShedBackWall", V(76, roofY - 2, 1), base * CFrame.new(0, (roofY - 2) / 2, 10.6), IRON, Enum.Material.CorrodedMetal)
		for _, side in { -1, 1 } do
			boxAt("ShedRoof", V(78, 0.5, 13), base * CFrame.new(0, roofY + 2.6, side * 5.8) * CFrame.Angles(side * math.rad(22), 0, 0), IRON, Enum.Material.CorrodedMetal)
			boxAt("ShedEndWall", V(1, roofY - 2, 22), base * CFrame.new(side * 38, (roofY - 2) / 2, 0), BRICK, Enum.Material.Brick)
		end
		-- Roof bins with chutes raking down to the sorting bins at the front.
		for k = 0, 4 do
			local x = -28 + k * 14
			boxAt("ShedRoofBin", V(7, 6, 7), base * CFrame.new(x, roofY - 4, 4), IRON, Enum.Material.Metal)
			local chute = boxAt("ShedChute", V(3.4, 0.5, 15), base * CFrame.new(x, roofY - 13, -3) * CFrame.Angles(math.rad(-46), 0, 0), RUST, Enum.Material.CorrodedMetal)
			chute.CanCollide = false
			boxAt("ShedSortingBin", V(8, 4.4, 6), base * CFrame.new(x, 2.8, -6), IRON_DARK, Enum.Material.Metal)
			lump("ShedBinOre", (base * CFrame.new(x, 5, -6)).Position, V(7, 2.4, 5), if k % 2 == 0 then ORE else COAL, if k % 2 == 0 then Enum.Material.Slate else Enum.Material.Basalt)
		end
		local lampA = boxAt("ShedLamp", V(1.6, 1, 1.6), base * CFrame.new(-14, roofY - 3, -2), LAMP, Enum.Material.Neon)
		light(lampA, LAMP, 0.9, 30)
		local lampB = boxAt("ShedLamp", V(1.6, 1, 1.6), base * CFrame.new(18, roofY - 3, -2), LAMP, Enum.Material.Neon)
		light(lampB, LAMP, 0.9, 30)
	end)
	-- Sorting grates and ore bins on the gallery's free corners (outside the Elite camp).
	piece("SortingGrate", sh.X - 34, sh.Z + 30, 0, nil, 1, nil, function(cf)
		boxAt("GrateFrame", V(10, 1.2, 8), cf * CFrame.new(0, 0.6, 0), IRON_DARK, Enum.Material.Metal)
		for k = -2, 2 do
			boxAt("GrateBar", V(0.4, 0.4, 8), cf * CFrame.new(k * 1.8, 1.4, 0), IRON, Enum.Material.Metal)
		end
		lump("GrateOre", (cf * CFrame.new(-3, 1.6, 2)).Position, V(4, 1.6, 3), ORE, Enum.Material.Slate)
	end, sh.Y)
	piece("SortingScrap", sh.X - 34, sh.Z - 30, 70, "ScrapHeap", 0.75, SOOT, fallbackScrap, sh.Y)
	piece("SortingTub", sh.X + 36, sh.Z + 32, 15, "OreCart", 0.95, ORE_TINT, fallbackCart, sh.Y)
	landmarks += 1
	props += 4

	-- =====================================================================================================
	-- 7. The Ore Yard: the water tower, a roasting kiln, a second engine and tubs on the sidings, buffer stops
	--    at the siding ends, a derailed tub spilling ore, scrap heaps and the yard cabin.
	-- =====================================================================================================
	local yard = P.Basin
	piece("WaterTower", -62, 152, 0, "WaterTower", 1.25, SOOT, function(cf)
		for _, xx in { -6, 6 } do
			for _, zz in { -6, 6 } do
				boxAt("WaterTowerLeg", V(1.4, 25, 1.4), cf * CFrame.new(xx, 12.5, zz), IRON_DARK, Enum.Material.Metal)
			end
		end
		local tank = boxAt("WaterTowerTank", V(11.5, 16, 16), cf * CFrame.new(0, 31, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal)
		tank.Shape = Enum.PartType.Cylinder
		boxAt("WaterTowerRoof", V(14, 2, 14), cf * CFrame.new(0, 38, 0), IRON_DARK, Enum.Material.Metal)
	end, yard.Y)
	plume(V(-62, 44, 150), rgb(206, 200, 196), 4, 2, 2.5, 5)
	piece("RoastingKiln", -184, 148, 25, "KilnTower", 0.7, SOOT, function(cf)
		ctx.cyl("RoastingKilnBody", (cf * CFrame.new(0, 14, 0)).Position, 9, 28, BRICK, Enum.Material.Brick)
		ctx.cyl("RoastingKilnNeck", (cf * CFrame.new(0, 33, 0)).Position, 4.5, 10, BRICK_DARK, Enum.Material.Brick)
	end, yard.Y)
	piece("YardEngine", 150, 158, -90, "TankLocomotive", 1, LAMP_TINT, fallbackEngine, yard.Y)
	piece("YardTub", 133, 158, 90, "OreCart", 1, ORE_TINT, fallbackCart, yard.Y)
	piece("YardTub", 122, 158, 90, "OreCart", 1, SOOT, fallbackCart, yard.Y)
	for k, x in { -152, -141, -130 } do
		piece("SidingTub", x, 82, 90, "OreCart", 1, if k % 2 == 0 then SOOT else ORE_TINT, fallbackCart, yard.Y)
	end
	piece("YardCabin", 64, 156, 200, "SignalCabin", 1.1, LAMP_TINT, fallbackCabin, yard.Y)
	for _, spot in { { -197, 82, 90 }, { 197, 82, -90 }, { 197, 158, -90 }, { -197, 158, 90 } } do
		piece("RailBuffer", spot[1], spot[2], spot[3], "RailBuffer", 1, SOOT, fallbackBuffer, yard.Y)
	end
	-- The derailed tub, tipped on its side, its ore spilled beside it.
	piece("DerailedTub", 176, 92, 70, "OreCart", 1, ORE_TINT, fallbackCart, yard.Y + 3.4, CFrame.Angles(0, 0, math.rad(84)))
	piece("DerailedSpill", 170, 99, 10, "CoalHeap", 0.8, ORE_TINT, function(cf) fallbackHeap(cf, ORE, Enum.Material.Slate) end, yard.Y)
	piece("YardScrap", -182, 104, 30, "ScrapHeap", 1, SOOT, fallbackScrap, yard.Y)
	piece("YardScrap", 186, 128, -40, "ScrapHeap", 0.9, SOOT, fallbackScrap, yard.Y)
	for _, spot in { { -40, 158 }, { 40, 84 }, { -40, 84 } } do
		piece("YardSignal", spot[1], spot[2], if spot[2] > 120 then 180 else 0, "SignalLamp", 1.1, LAMP_TINT, fallbackSignal, yard.Y)
	end
	landmarks += 4 -- water tower, kiln, yard engine, derailed tub and buffers
	props += 21

	-- Sidings: rails and sleepers along the yard's front and back edges, broken at the causeway.
	local function siding(z: number, x0: number, x1: number)
		local seg = 12
		local n = math.floor((x1 - x0) / seg)
		for k = 0, n - 1 do
			local xa, xb = x0 + k * seg, x0 + (k + 1) * seg
			ctx.group("YardSiding", function()
				for _, side in { -2.6, 2.6 } do
					local r = ctx.block("SidingRailTrack", V(seg, 0.32, 0.45), V((xa + xb) / 2, yard.Y + 0.3, z + side), rgb(128, 122, 118), Enum.Material.Metal)
					r.CanCollide = false
					r.CanQuery = false
				end
				for j = 0, 3 do
					local sl = ctx.block("SidingSleeperTrack", V(1.4, 0.2, 9), V(xa + 1.5 + j * 3, yard.Y + 0.1, z), TIMBER, Enum.Material.Wood)
					sl.CanCollide = false
					sl.CanQuery = false
				end
			end)
		end
	end
	siding(82, -196, -28)
	siding(82, 28, 196)
	siding(158, -196, -76)
	siding(158, 76, 196)

	-- =====================================================================================================
	-- 8. The Furnace Gate and the works behind it: the hammer-ring doors, soot-brick wings with buttresses,
	--    iron ducts, braziers at the Furnace Steps, and the flue stacks smoking against the red sky.
	-- =====================================================================================================
	local apex = P.Apex
	local gateZ = apex.Z - apex.Depth / 2 - 11
	ctx.reserve(0, gateZ, 40)
	local gate = piece("FurnaceGate", 0, gateZ, 0, "FurnaceGateDoors", 1.5, SOOT, function(cf)
		for _, sx in { -1, 1 } do
			boxAt("GateButtressWall", V(15, 66, 15), cf * CFrame.new(sx * 28.5, 33, 1), BRICK, Enum.Material.Brick)
			local niche = boxAt("GateBrazierGlow", V(5.4, 3.6, 0.8), cf * CFrame.new(sx * 28.5, 14, 9), EMBER, Enum.Material.Neon)
			light(niche, EMBER, 1.4, 40)
		end
		boxAt("GateLintelWall", V(42, 15, 12), cf * CFrame.new(0, 58, 1), BRICK_DARK, Enum.Material.Brick)
		for _, sx in { -1, 1 } do
			boxAt("GateDoorLeaf", V(19.5, 51, 2.4), cf * CFrame.new(sx * 9.9, 25.5, 1.5), IRON, Enum.Material.Metal)
		end
		ctx.ring("GateHammerRing", (cf * CFrame.new(0, 28, 3.2)).Position, 10, 2, BRASS, Enum.Material.Metal)
		boxAt("GateHammerHaft", V(2.4, 13, 1.4), cf * CFrame.new(0, 26, 3.4), BRASS, Enum.Material.Metal)
		boxAt("GateHammerHead", V(10.8, 4.8, 2), cf * CFrame.new(0, 33, 3.4), BRASS, Enum.Material.Metal)
	end, apex.Y)
	local gateGlow = glowOf(gate)
	if gateGlow then light(gateGlow, EMBER, 1.4, 44) end
	landmarks += 1
	-- The works: soot-brick wings either side of the gate, stepped back, with buttresses and window glows.
	ctx.group("FoundryWorks", function()
		local wingDepth = 26
		local backZ = -d / 2 + wingDepth / 2 + 2
		for _, sx in { -1, 1 } do
			-- Each wing: centre X, width, height (stepping down away from the gate).
			for k, wing in { { 57, 40, 52 }, { 103, 52, 40 }, { 155, 48, 30 } } do
				local cx, width, hgt = sx * wing[1], wing[2], wing[3]
				local z = backZ - (k - 1) * 2
				local wallBase = apex.Y - 2
				boxAt("FoundryWorksWall", V(width, hgt, wingDepth), CFrame.new(cx, wallBase + hgt / 2, z), if k == 2 then BRICK_DARK else BRICK, Enum.Material.Brick)
				boxAt("FoundryWorksCornice", V(width + 2, 2.4, wingDepth + 2), CFrame.new(cx, wallBase + hgt + 1.2, z), IRON_DARK, Enum.Material.Metal)
				-- Buttresses and tall arched-window glows facing the room.
				local bays = math.max(2, math.floor(width / 13))
				for b = 0, bays do
					local bx = cx - width / 2 + b * width / bays
					boxAt("FoundryWorksButtressWall", V(3.4, hgt * 0.92, 4), CFrame.new(bx, wallBase + hgt * 0.46, z + wingDepth / 2 + 1.6), BRICK_DARK, Enum.Material.Brick)
					if b < bays and (b + k) % 2 == 0 then
						-- Two small panes per window: large Neon reads as plastic (TowerBiomeAssets' bloom guard).
						local wx = bx + width / bays / 2
						for pane = 0, 1 do
							local win = boxAt("FoundryWorksWindowGlowSeam", V(4, 7.5, 0.6), CFrame.new(wx, wallBase + hgt * 0.42 + pane * 8.2, z + wingDepth / 2 + 0.2), rgb(255, 140, 60), Enum.Material.Neon)
							win.CanCollide = false
						end
					end
				end
				-- Iron ducts running along the wall face.
				local duct = rod("FoundryWorksDuct", V(cx - width / 2, wallBase + hgt * 0.78, z + wingDepth / 2 + 4.2), V(cx + width / 2, wallBase + hgt * 0.78, z + wingDepth / 2 + 4.2), 1.8, IRON, Enum.Material.Metal)
				duct.CanCollide = false
			end
		end
	end)
	landmarks += 1
	-- Flue stacks: two flanking the gate (the tallest pieces on the floor), two farther out, two on the side
	-- mountains; each one smokes.
	local stacks = {
		{ -48, -252, 1.2 }, { 48, -252, 1.2 }, { -122, -250, 1.0 }, { 122, -250, 1.0 },
		{ -212, 18, 0.85 }, { 212, 70, 0.85 },
	}
	for k, sp in stacks do
		local sx, sz, s = sp[1], sp[2], sp[3]
		local sy = if math.abs(sz) > 240 then apex.Y - 1 else nil
		local stack = piece("FlueStack", sx, sz, k * 37, "FlueStack", s, SOOT, function(cf) fallbackStack(cf, s) end, sy)
		local top = (sy or (surfaceAt(sx, sz))) + 100 * s
		if k <= 4 or k == 6 then
			plume(V(sx, top + 2, sz), rgb(54, 46, 46), 11 * s, 3, 7, 9)
		end
		local stackGlow = glowOf(stack)
		if stackGlow and k <= 2 then light(stackGlow, EMBER, 1.2, 40) end
		ctx.reserve(sx, sz, 10 * s)
	end
	landmarks += 1
	-- Braziers at the head of the Furnace Steps and racks of ingots and tools on the Apex flanks.
	for _, sx in { -1, 1 } do
		piece("StepsLamp", sx * 26, apex.Z + apex.Depth / 2 - 4, 0, "SignalLamp", 1.2, LAMP_TINT, fallbackSignal, apex.Y)
		ctx.group("FoundryBrazier", function()
			local at = V(sx * 52, apex.Y, apex.Z + apex.Depth / 2 - 8)
			ctx.cyl("BrazierPedestal", at + V(0, 2.5, 0), 1.6, 5, IRON_DARK, Enum.Material.Metal)
			ctx.cyl("BrazierBowl", at + V(0, 5.6, 0), 3, 1.4, IRON, Enum.Material.Metal)
			local coals = ctx.block("BrazierCoalsGlowSeam", V(4.6, 0.6, 4.6), at + V(0, 6.4, 0), EMBER, Enum.Material.Neon)
			light(coals, EMBER, 1.3, 32)
		end)
		ctx.group("IngotStack", function()
			local at = V(sx * 50, apex.Y, apex.Z - apex.Depth / 2 + 10)
			for layer = 0, 3 do
				for k = -1, 1 do
					local ingot = ctx.block("IngotBar", V(1.4, 1, 4.6), at + V(k * 1.8 + (layer % 2) * 0.6, 0.5 + layer, 0), BRASS, Enum.Material.Metal)
					ingot.CanCollide = layer == 0
				end
			end
		end)
		piece("ApexScrap", sx * 40, apex.Z - 6, sx * 30, "ForgeScrap", 0.9, SOOT, nil, apex.Y)
	end
	props += 8

	-- =====================================================================================================
	-- 9. The bellows duct: an iron main on trestles down the west side, from the Sorting Shed to the crusher.
	-- =====================================================================================================
	ctx.group("BellowsDuct", function()
		ctx.tag("OnTerrain", true)
		local pts = { V(-200, 24, 52), V(-206, 26, 0), V(-206, 28, -60), V(-196, 30, -112) }
		for k = 1, #pts - 1 do
			local a, b = pts[k], pts[k + 1]
			rod("BellowsDuctPipe", a, b, 2.4, IRON, Enum.Material.Metal).CanCollide = false
			ctx.cyl("BellowsDuctFlange", a, 3, 0.8, IRON_DARK, Enum.Material.Metal)
			local legs = math.max(1, math.floor((b - a).Magnitude / 26))
			for j = 1, legs do
				local p = a:Lerp(b, j / (legs + 1))
				local gy = if field then field.Height(p.X, p.Z) + 1 else bottom
				if p.Y - 2.4 > gy then
					local leg = ctx.block("BellowsDuctTrestle", V(1.2, p.Y - 2.4 - gy, 1.2), V(p.X, (p.Y - 2.4 + gy) / 2, p.Z), IRON_DARK, Enum.Material.Metal)
					leg.CanCollide = false
				end
			end
		end
	end)
	props += 1

	-- =====================================================================================================
	-- 10. A lava fall down the north-east mountain into the coal heaps (the far layer's fire).
	-- =====================================================================================================
	ctx.group("LavaFall", function()
		ctx.tag("OnTerrain", true)
		local fx, fz = 186, -250
		local top = 96
		local foot = if field then field.Height(fx, fz + 14) + 1 else bottom
		local fall = ctx.block("NorthLavaFall", V(12, top - foot, 4), V(fx, (top + foot) / 2, fz), EMBER, Enum.Material.SmoothPlastic, nil, 0.2)
		fall.CFrame = CFrame.new(origin + V(fx, (top + foot) / 2, fz)) * CFrame.Angles(math.rad(-8), 0, 0)
		light(fall, EMBER, 1.8, 60)
		plume(V(fx, foot + 2, fz + 10), EMBER, 1.4, 8, 7, 2.4)
	end)
	landmarks += 1

	-- 11. Work clutter and ground cover.
	local clutter, groundCover = H.workClutter(InfernalFoundry.Floor21Landmarks, 21, 26, 260)
	props += clutter
	cover += groundCover

	ctx.setAttribute("Floor21Landmarks", landmarks)
	ctx.setAttribute("Floor21Props", props)
	ctx.setAttribute("Floor21GroundCover", cover)
end

-- Floor 22 landmark footprints (see Floor21Landmarks). The gantry hoists are listed by their legs and hanging
-- loads: their crossbeams pass 60 studs over the girder walk.
InfernalFoundry.Floor22Landmarks = table.freeze({
	{ Id = "MasterJig", X = 0, Z = -290, Y = 24, HalfX = 25.2, HalfZ = 15.3, Top = 96 },
	{ Id = "FurnaceWest", X = -70, Z = -289.6, Y = 24, HalfX = 11.8, HalfZ = 10.6, Top = 34.3 },
	{ Id = "FurnaceEast", X = 70, Z = -289.6, Y = 24, HalfX = 11.8, HalfZ = 10.6, Top = 34.3 },
	{ Id = "GearWest", X = -125, Z = -296, Y = 24, HalfX = 17.5, HalfZ = 2.6, Top = 28.9 },
	{ Id = "GearEast", X = 125, Z = -296, Y = 24, HalfX = 17.5, HalfZ = 2.6, Top = 28.9 },
	{ Id = "IdleGantryWest", X = -170, Z = -294, Y = 24, HalfX = 5, HalfZ = 5, Top = 108 },
	{ Id = "IdleGantryEast", X = 170, Z = -294, Y = 24, HalfX = 5, HalfZ = 5, Top = 108 },
	{ Id = "YardBayWest", X = -58, Z = 42, HalfX = 13.6, HalfZ = 10.7, Top = 43.4 },
	{ Id = "YardBayEast", X = 58, Z = 42, HalfX = 13.6, HalfZ = 10.7, Top = 43.4 },
	{ Id = "NorthBayWest", X = -75, Z = -76, HalfX = 11.6, HalfZ = 9.2, Top = 37.2 },
	{ Id = "NorthBayEast", X = 75, Z = -76, HalfX = 11.6, HalfZ = 9.2, Top = 37.2 },
	{ Id = "WestHoistLegNorth", X = -88, Z = -45.5, HalfX = 1.4, HalfZ = 1.4, Top = 76 },
	{ Id = "WestHoistLegSouth", X = -88, Z = 5.5, HalfX = 1.4, HalfZ = 1.4, Top = 76 },
	{ Id = "WestHoistLoad", X = -88, Z = 9, Y = 20, HalfX = 7.2, HalfZ = 4, Top = 26 },
	{ Id = "EastHoistLegNorth", X = 88, Z = -45.5, HalfX = 1.4, HalfZ = 1.4, Top = 76 },
	{ Id = "EastHoistLegSouth", X = 88, Z = 5.5, HalfX = 1.4, HalfZ = 1.4, Top = 76 },
	{ Id = "EastHoistLoad", X = 88, Z = 9, Y = 20, HalfX = 7.2, HalfZ = 4, Top = 26 },
	{ Id = "FailedJack", X = 150, Z = -20, HalfX = 3.8, HalfZ = 3.4, Top = 12.8 },
	{ Id = "QuenchWest", X = -150, Z = 70, HalfX = 14.1, HalfZ = 9.5, Top = 7.4 },
	{ Id = "QuenchEast", X = 150, Z = 70, HalfX = 14.1, HalfZ = 9.5, Top = 7.4 },
	{ Id = "PatternRacks", X = -180, Z = -172, Y = 16, HalfX = 23, HalfZ = 4, Top = 11.1 },
	{ Id = "ControlCabin", X = 180, Z = -175, Y = 20, HalfX = 10.9, HalfZ = 10.9, Top = 18 },
	{ Id = "OverheadCrane", X = 0, Z = 40, Y = 94, HalfX = 250, HalfZ = 8, Top = 14 },
	{ Id = "ConveyorWest", X = -30, Z = 74, HalfX = 4, HalfZ = 11.5, Top = 6 },
	{ Id = "ConveyorEast", X = 30, Z = 74, HalfX = 4, HalfZ = 11.5, Top = 6 },
	{ Id = "ConveyorNorth", X = -40, Z = -76, HalfX = 4, HalfZ = 11.5, Top = 6 },
}) :: { Landmark }

-- Floor 22, Molten Assembly: the assembly hall under a closed brick vault. The gantry crane's girder is the walk
-- (TowerRoomBuilder: lattice piers, free girder spans, the trolley's winch drums and hook); here, the hoist
-- portals with half-built constructs hanging beside the girder, rows of constructs in scaffolds on the yard
-- floor, the master jig in the Assembly Hall between two furnaces venting steam, steaming quench tanks, the
-- Pattern Loft and the glazed Control Cab, the failed jack under the east pier, an overhead travelling crane
-- with its hook over the yard, lamp strings and vault ribs, great gears and an idle gantry beyond.
function InfernalFoundry.Floor22(ctx: any)
	local H = helpers(ctx)
	local origin: Vector3, field, bottom: number, w: number, P = H.origin, H.field, H.bottom, ctx.w, H.P
	local surfaceAt, boxAt, rod, light, plume, piece = H.surfaceAt, H.boxAt, H.rod, H.light, H.plume, H.piece
	local glowOf, noCollide, fallbackHeap = H.glowOf, H.noCollide, H.fallbackHeap
	local landmarks, props = 0, 0
	local SODIUM = rgb(255, 178, 92)
	local CONSTRUCT = tinted(SOOT, { GLOW = { Color = EMBER, Material = Enum.Material.Neon } })
	local GLASS = tinted(LAMP_TINT, { CRYSTAL = { Color = rgb(255, 196, 132), Material = Enum.Material.Glass, Transparency = 0.45 } })
	local QUENCH = tinted(SOOT, { CRYSTAL = { Color = rgb(22, 26, 30), Material = Enum.Material.Glass, Transparency = 0.15 } })

	for _, lm in InfernalFoundry.Floor22Landmarks do
		if lm.Id ~= "OverheadCrane" then
			ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
		end
	end
	local function groundAt(x: number, z: number): number
		return if field then field.Height(x, z) + 1.4 else bottom
	end

	-- Native fallbacks for the Floor 22 kit.
	local function fallbackConstruct(cf: CFrame)
		for _, sx in { -1, 1 } do
			boxAt("ConstructLeg", V(2.2, 11, 2.4), cf * CFrame.new(sx * 1.8, 5.5, 0), IRON, Enum.Material.Metal)
		end
		boxAt("ConstructChest", V(7, 7, 6), cf * CFrame.new(0, 15.5, 0), IRON, Enum.Material.Metal)
		boxAt("ConstructCore", V(3.4, 2.4, 0.3), cf * CFrame.new(0, 17, 3.1), EMBER, Enum.Material.Neon)
		for _, sx in { -1, 1 } do
			boxAt("ConstructPauldron", V(3.6, 3, 3.6), cf * CFrame.new(sx * 4.4, 20.4, 0), IRON_DARK, Enum.Material.Metal)
			boxAt("ConstructArm", V(2.2, 9, 2.2), cf * CFrame.new(sx * 5.2, 14, 0), IRON_DARK, Enum.Material.Metal)
		end
		boxAt("ConstructHelm", V(3, 3, 3), cf * CFrame.new(0, 23.4, 0), IRON, Enum.Material.Metal)
	end
	local function fallbackScaffold(cf: CFrame)
		for _, sx in { -9, 9 } do
			for _, sz in { -7, 7 } do
				local pole = boxAt("ScaffoldPole", V(0.5, 30, 0.5), cf * CFrame.new(sx, 15, sz), IRON_DARK, Enum.Material.Metal)
				pole.CanCollide = false
			end
		end
		for k = 1, 4 do
			for _, sz in { -7, 7 } do
				local ledger = boxAt("ScaffoldLedger", V(18, 0.4, 0.4), cf * CFrame.new(0, k * 6.8, sz), IRON_DARK, Enum.Material.Metal)
				ledger.CanCollide = false
			end
		end
		for _, y in { 13.6, 27.2 } do
			boxAt("ScaffoldPlank", V(18, 0.3, 2.6), cf * CFrame.new(0, y, 5.7), TIMBER, Enum.Material.WoodPlanks)
		end
	end
	local function fallbackHoist(cf: CFrame)
		local chainPart = boxAt("HoistChain", V(0.4, 18, 0.4), cf * CFrame.new(0, 13, 0), IRON_DARK, Enum.Material.Metal)
		chainPart.CanCollide = false
		boxAt("HoistBlock", V(2, 2.4, 1.6), cf * CFrame.new(0, 4.6, 0), IRON, Enum.Material.Metal)
		boxAt("HoistHook", V(0.8, 2.4, 0.8), cf * CFrame.new(0, 1.6, 0), BRASS, Enum.Material.Metal)
	end
	local function fallbackFurnace(cf: CFrame)
		boxAt("FurnaceBody", V(22, 14, 16), cf * CFrame.new(0, 7, 0), BRICK, Enum.Material.Brick)
		boxAt("FurnaceCrown", V(18, 6, 14), cf * CFrame.new(0, 17, -1), BRICK_DARK, Enum.Material.Brick)
		local mouth = boxAt("FurnaceMouthGlow", V(7, 7, 0.4), cf * CFrame.new(0, 5, 8.1), EMBER, Enum.Material.Neon)
		light(mouth, EMBER, 1.6, 44)
		for _, sx in { -5.5, 5.5 } do
			ctx.cyl("FurnaceChimney", (cf * CFrame.new(sx, 27, -3)).Position, 1.6, 14, IRON, Enum.Material.Metal)
		end
	end
	local function fallbackQuench(cf: CFrame)
		boxAt("QuenchKerb", V(27, 1, 19), cf * CFrame.new(0, 0.3, 0), BRICK_DARK, Enum.Material.Brick)
		boxAt("QuenchRim", V(24, 1.8, 16), cf * CFrame.new(0, 1, 0), IRON, Enum.Material.Metal)
		local water = boxAt("QuenchWater", V(22, 0.2, 14), cf * CFrame.new(0, 1.95, 0), rgb(22, 26, 30), Enum.Material.Glass, 0.15)
		water.CanCollide = false
	end
	local function fallbackRack(cf: CFrame)
		boxAt("RackFrame", V(12, 9, 0.6), cf * CFrame.new(0, 4.5, -1.5), TIMBER, Enum.Material.Wood)
		for k = 0, 2 do
			boxAt("RackShelf", V(12, 0.3, 3.4), cf * CFrame.new(0, 0.6 + k * 2.8, 0), IRON_DARK, Enum.Material.Metal)
			boxAt("RackPart", V(2, 1.6, 2), cf * CFrame.new(-3 + k * 3, 1.6 + k * 2.8, 0), IRON, Enum.Material.Metal)
		end
	end
	local function fallbackCabin(cf: CFrame)
		boxAt("CabBase", V(14, 4, 11), cf * CFrame.new(0, 2, 0), IRON, Enum.Material.Metal)
		local glass = boxAt("CabGlazing", V(13.6, 5, 10.6), cf * CFrame.new(0, 6.5, 0), rgb(255, 196, 132), Enum.Material.Glass, 0.45)
		glass.CanCollide = true
		boxAt("CabRoof", V(15, 1, 12), cf * CFrame.new(0, 9.5, 0), IRON_DARK, Enum.Material.Metal)
	end
	local function fallbackGear(cf: CFrame)
		local wheel = boxAt("GiantGearWheel", V(3, 26, 26), cf * CFrame.new(0, 13.5, 0) * CFrame.Angles(0, math.pi / 2, 0), IRON, Enum.Material.Metal)
		wheel.Shape = Enum.PartType.Cylinder
		boxAt("GiantGearCradle", V(30, 1.6, 5), cf * CFrame.new(2, 0.8, 0), IRON_DARK, Enum.Material.Metal)
	end
	local function fallbackConveyor(cf: CFrame)
		boxAt("ConveyorBed", V(5.2, 0.8, 22), cf * CFrame.new(0, 3.2, 0), IRON_DARK, Enum.Material.Metal)
		for _, zz in { -9, 0, 9 } do
			boxAt("ConveyorLeg", V(4.8, 2.8, 0.5), cf * CFrame.new(0, 1.4, zz), IRON_DARK, Enum.Material.Metal)
		end
	end
	local function fallbackJack(cf: CFrame)
		boxAt("JackBase", V(8, 1.2, 8), cf * CFrame.new(0, 0.6, 0), IRON_DARK, Enum.Material.Metal)
		ctx.cyl("JackCylinder", (cf * CFrame.new(0, 4.7, 0)).Position, 2.6, 7, IRON, Enum.Material.Metal)
		local ram = boxAt("JackRam", V(3.4, 5, 3.4), cf * CFrame.new(0.4, 10.5, 0) * CFrame.Angles(0, 0, math.rad(-9)), IRON_DARK, Enum.Material.Metal)
		ram.Shape = Enum.PartType.Block
	end

	-- A construct standing in its assembly scaffold on the yard floor (or a deck), facing `yawDeg`.
	local function bay(kind: string, x: number, z: number, yawDeg: number, scaffoldScale: number, constructScale: number)
		piece(kind .. "Scaffold", x, z, yawDeg, "AssemblyScaffold", scaffoldScale, SOOT, fallbackScaffold)
		piece(kind, x, z + 0.5, yawDeg, "ConstructShell", constructScale, CONSTRUCT, fallbackConstruct)
	end

	-- =====================================================================================================
	-- 1. The master jig in the Assembly Hall: a nearly finished construct three times a man's height in a
	--    great scaffold, between two brick furnaces venting steam, with great gears in their cradles.
	-- =====================================================================================================
	local apex = P.Apex
	ctx.group("MasterJig", function()
		local cf = CFrame.new(0, apex.Y, -290)
		if ctx.has("AssemblyScaffold") then
			ctx.kitAt("AssemblyScaffold", cf, V(2.6, 3.1, 2.0), SOOT)
		else
			fallbackScaffold(cf)
		end
		if ctx.has("ConstructShell") then
			local mdl = ctx.kitAt("ConstructShell", cf * CFrame.new(0, 0, 0.6), 3.2, CONSTRUCT)
			local core = glowOf(mdl)
			if core then light(core, EMBER, 1.6, 48) end
		else
			fallbackConstruct(cf)
		end
	end)
	plume(V(0, apex.Y + 60, -280), rgb(255, 170, 80), 0.8, 7, 9, 1.6)
	for _, sx in { -1, 1 } do
		local furnace = piece("Furnace", sx * 70, -288, 0, "FurnaceBox", 1, SOOT, fallbackFurnace, apex.Y)
		local mouth = glowOf(furnace)
		if mouth then light(mouth, EMBER, 1.6, 44) end
		plume(V(sx * 70, apex.Y + 36, -285), rgb(196, 188, 182), 6, 3, 6, 6)
		piece("GreatGear", sx * 125, -296, 0, "WallGear", 1, SOOT, fallbackGear, apex.Y)
	end
	landmarks += 3
	props += 5

	-- An idle second gantry beyond the hall's north end, its girder high over the master jig.
	ctx.group("IdleGantry", function()
		ctx.tag("OnTerrain", true)
		local topY = apex.Y + 108
		for _, sx in { -1, 1 } do
			local x = sx * 170
			for _, ox in { -4, 4 } do
				for _, oz in { -4, 4 } do
					boxAt("IdleGantryLeg", V(1.4, topY - apex.Y, 1.4), CFrame.new(x + ox, (apex.Y + topY) / 2, -294 + oz), IRON_DARK, Enum.Material.Metal)
				end
			end
			for k = 0, 9 do
				local y0 = apex.Y + k * (topY - apex.Y) / 10
				local y1 = y0 + (topY - apex.Y) / 10
				local brace = rod("IdleGantryBrace", V(x - 4, y0, -290), V(x + 4, y1, -290), 0.3, IRON_DARK, Enum.Material.Metal)
				brace.CanCollide = false
			end
		end
		for _, oz in { -3, 3 } do
			boxAt("IdleGantryGirder", V(348, 4, 1.4), CFrame.new(0, topY - 2, -294 + oz), IRON, Enum.Material.Metal)
		end
		for k = 0, 28 do
			local x = -168 + k * 12
			local web = rod("IdleGantryWeb", V(x, topY - 4, -294), V(x + 6, topY, -294), 0.3, RUST, Enum.Material.CorrodedMetal)
			web.CanCollide = false
		end
	end)
	landmarks += 1

	-- =====================================================================================================
	-- 2. The hoist portals: an iron portal astride each girder hoist, its jib reaching out over the yard with
	--    a half-built construct hanging on a chain hoist beside the girder walk.
	-- =====================================================================================================
	for _, id in { "WestHoist", "EastHoist" } do
		local node = P[id]
		local beamY = 70
		ctx.group("HoistPortal", function()
			ctx.tag("OnTerrain", true)
			for _, zz in { -45.5, 5.5 } do
				local gy = groundAt(node.X, zz)
				boxAt("HoistPortalLeg", V(2.4, beamY - gy, 2.4), CFrame.new(node.X, (beamY + gy) / 2, zz), IRON_DARK, Enum.Material.Metal)
				boxAt("HoistPortalFoot", V(5, 1.6, 5), CFrame.new(node.X, gy + 0.8, zz), BRICK_DARK, Enum.Material.Brick)
			end
			boxAt("HoistPortalBeam", V(3, 3.6, 64), CFrame.new(node.X, beamY + 1.8, -14), IRON, Enum.Material.Metal)
			for _, zz in { -45.5, 5.5 } do
				local brace = rod("HoistPortalKnee", V(node.X, beamY - 8, zz), V(node.X, beamY, zz + (if zz < 0 then 8 else -8)), 0.5, IRON_DARK, Enum.Material.Metal)
				brace.CanCollide = false
			end
			-- The chain hoist and its load: a construct shell hanging beside the girder walk, its feet 11 studs over
			-- the girder; the hoist's hook takes it by the helm and its top block hangs from the jib.
			local hangCF = CFrame.new(node.X, 20, 9) * CFrame.Angles(0, math.pi, 0)
			if ctx.has("ChainHoist") then
				ctx.kitAt("ChainHoist", CFrame.new(node.X, 45.4, 9), 1, SOOT)
			else
				fallbackHoist(CFrame.new(node.X, 45.4, 9))
			end
			local hanger = boxAt("HoistJibHanger", V(0.6, beamY - 67.6, 0.6), CFrame.new(node.X, (beamY + 67.6) / 2, 9), IRON_DARK, Enum.Material.Metal)
			hanger.CanCollide = false
			if ctx.has("ConstructShell") then
				local mdl = ctx.kitAt("ConstructShell", hangCF, 1, CONSTRUCT)
				noCollide(mdl)
			else
				fallbackConstruct(hangCF)
			end
		end)
	end
	landmarks += 2
	props += 2

	-- =====================================================================================================
	-- 3. Rows of constructs in scaffolds on the yard floor, south and north of the girder.
	-- =====================================================================================================
	bay("YardConstruct", -58, 42, 160, 1.4, 1.5)
	bay("YardConstruct", 58, 42, 200, 1.4, 1.5)
	bay("YardConstruct", -75, -76, 20, 1.2, 1.25)
	bay("YardConstruct", 75, -76, -20, 1.2, 1.25)
	landmarks += 1
	props += 8

	-- The overhead travelling crane: a truss bridge across the hall on runway beams carried by wall piers, its
	-- trolley over the east yard bay and the hook lowered to its construct's shoulders.
	ctx.group("OverheadCrane", function()
		ctx.tag("OnTerrain", true)
		local craneY, craneZ = 96, 40
		local span = w / 2 - 25
		for _, sx in { -1, 1 } do
			local x = sx * span
			boxAt("CraneRunwayBeam", V(3, 3, 360), CFrame.new(x, craneY - 3, -90), IRON, Enum.Material.Metal)
			for z = -250, 70, 64 do
				local gy = groundAt(x, z)
				if gy < craneY - 6 then
					boxAt("CraneRunwayPier", V(3.6, craneY - 4.5 - gy, 3.6), CFrame.new(x, (craneY - 4.5 + gy) / 2, z), BRICK_DARK, Enum.Material.Brick)
				end
			end
		end
		for _, oz in { -4, 4 } do
			boxAt("CraneBridgeChord", V(span * 2, 1.6, 1.2), CFrame.new(0, craneY + 6, craneZ + oz), IRON, Enum.Material.Metal)
			boxAt("CraneBridgeChord", V(span * 2, 1.6, 1.2), CFrame.new(0, craneY, craneZ + oz), IRON_DARK, Enum.Material.Metal)
			local bays = 40
			for k = 0, bays - 1 do
				local x0 = -span + k * span * 2 / bays
				local x1 = x0 + span * 2 / bays
				local web = rod("CraneBridgeWeb", V(x0, if k % 2 == 0 then craneY else craneY + 6, craneZ + oz), V(x1, if k % 2 == 0 then craneY + 6 else craneY, craneZ + oz), 0.3, RUST, Enum.Material.CorrodedMetal)
				web.CanCollide = false
			end
		end
		boxAt("CraneWalkway", V(span * 2, 0.4, 6), CFrame.new(0, craneY + 6.9, craneZ), IRON_DARK, Enum.Material.DiamondPlate)
		local hookX = 58
		local trolleyCF = CFrame.new(hookX, craneY + 7.1, craneZ)
		if ctx.has("CraneTrolley") then
			ctx.kitAt("CraneTrolley", trolleyCF, 1, LAMP_TINT)
		else
			boxAt("CraneTrolleyHouse", V(16, 8, 11), trolleyCF * CFrame.new(0, 4, 0), IRON, Enum.Material.Metal)
		end
		-- The hook: a long chain hoist from the trolley down to the east bay construct's shoulders.
		local hookY = 44
		if ctx.has("ChainHoist") then
			ctx.kitAt("ChainHoist", CFrame.new(hookX, hookY, craneZ), V(1.2, (craneY - hookY) / 22.26, 1.2), SOOT)
		else
			fallbackHoist(CFrame.new(hookX, hookY, craneZ))
			local rope = boxAt("CraneHookRope", V(0.5, craneY - hookY - 18, 0.5), CFrame.new(hookX, (craneY + hookY + 18) / 2, craneZ), IRON_DARK, Enum.Material.Metal)
			rope.CanCollide = false
		end
	end)
	landmarks += 1

	-- =====================================================================================================
	-- 4. The failed jack under the east pier's end, its ram cocked against the deck; shims and scrap round it.
	-- =====================================================================================================
	-- Both stand on the yard floor under the deck (surfaceAt would find the deck above them).
	piece("FailedJack", 150, -20, 15, "HydraulicJack", 0.84, SOOT, fallbackJack, groundAt(150, -20))
	piece("JackScrap", 160, -6, 40, "ScrapHeap", 0.5, SOOT, H.fallbackScrap, groundAt(160, -6))
	landmarks += 1
	props += 2

	-- =====================================================================================================
	-- 5. Quench tanks steaming at the front of the yard; conveyors feeding the bays.
	-- =====================================================================================================
	for _, sx in { -1, 1 } do
		piece("QuenchTank", sx * 150, 70, if sx < 0 then 0 else 180, "QuenchTank", 1, QUENCH, fallbackQuench)
		plume(V(sx * 150, groundAt(sx * 150, 70) + 3, 70), rgb(224, 220, 216), 7, 4, 3, 6)
	end
	piece("Conveyor", -30, 74, 0, "ConveyorRollers", 1, SOOT, fallbackConveyor)
	piece("Conveyor", 30, 74, 0, "ConveyorRollers", 1, SOOT, fallbackConveyor)
	piece("Conveyor", -40, -76, 0, "ConveyorRollers", 1, SOOT, fallbackConveyor)
	landmarks += 2
	props += 5

	-- =====================================================================================================
	-- 6. The Pattern Loft (wooden patterns and the pattern-makers' benches) and the Control Cab.
	-- =====================================================================================================
	local loft = P.PatternLoft
	for k, x in { -200, -180, -160 } do
		piece("PatternRack", x, -172, 0, "PatternRack", 1, tinted(SOOT, { WOOD = { Color = rgb(150, 112, 74), Material = Enum.Material.Wood } }), fallbackRack, loft.Y)
		if k == 2 then
			piece("PatternParts", x, -152, 180, "PartsRack", 0.9, SOOT, fallbackRack, loft.Y)
		end
	end
	local cab = P.ControlCab
	local cabin = piece("ControlCabin", 180, -175, 0, "ControlCabin", 1.4, GLASS, fallbackCabin, cab.Y)
	local cabLamp = glowOf(cabin)
	if cabLamp then light(cabLamp, SODIUM, 1, 30) end
	piece("CabGear", 204, -150, -90, "WallGear", 0.4, SOOT, fallbackGear, cab.Y)
	landmarks += 2
	props += 5

	-- Parts racks on the piers' free corners, facing in.
	for _, sx in { -1, 1 } do
		for _, z in { -47, 7 } do
			piece("PartsRack", sx * 205, z, sx * -90, "PartsRack", 0.9, SOOT, fallbackRack, P[if sx < 0 then "WestGallery" else "EastGallery"].Y)
		end
	end
	props += 4

	-- =====================================================================================================
	-- 7. The vault: brick ribs springing from wall piers to the crown, and sodium lamp strings sagging across
	--    the hall between them; the lava runnels down the side aisles glow under their crust.
	-- =====================================================================================================
	local vaultY = ctx.h
	for _, z in { -240, -170, -40, 30, 100, 170 } do
		ctx.group("VaultRib", function()
			ctx.tag("OnTerrain", true)
			local spring = vaultY - 58
			local halfSpan = w / 2 - 12
			for _, sx in { -1, 1 } do
				local gy = groundAt(sx * halfSpan, z)
				if spring - gy > 1 then
					boxAt("VaultRibPierWall", V(6, spring - gy, 6), CFrame.new(sx * halfSpan, (spring + gy) / 2, z), BRICK_DARK, Enum.Material.Brick)
				end
			end
			local segs = 14
			for k = 0, segs - 1 do
				local a0, a1 = math.pi * k / segs, math.pi * (k + 1) / segs
				local p0 = V(-math.cos(a0) * halfSpan, spring + math.sin(a0) * 56, z)
				local p1 = V(-math.cos(a1) * halfSpan, spring + math.sin(a1) * 56, z)
				local rib = rod("VaultRibArch", p0, p1, 2.4, BRICK, Enum.Material.Brick)
				rib.Shape = Enum.PartType.Block
				rib.Size = V((p1 - p0).Magnitude + 1, 4.6, 4.6)
			end
		end)
	end
	local lampCount = 0
	for _, z in { -200, -130, -70, 100 } do
		ctx.group("LampString", function()
			ctx.tag("OnTerrain", true)
			local halfSpan = w / 2 - 14
			local hiY, loY = vaultY - 70, vaultY - 96
			local n = 22
			local prev: Vector3? = nil
			for k = 0, n do
				local t = k / n
				local at = V(-halfSpan + t * halfSpan * 2, loY + (hiY - loY) * (2 * t - 1) ^ 2, z)
				if prev then
					local wire = rod("LampStringWire", prev, at, 0.12, IRON_DARK, Enum.Material.Metal)
					wire.CanCollide = false
				end
				if k % 2 == 1 then
					local bulb = ctx.orb("LampStringBulb", at - V(0, 1.2, 0), V(1.1, 1.1, 1.1), SODIUM, Enum.Material.Neon)
					bulb.CanCollide = false
					if k % 7 == 3 and lampCount < 8 then
						lampCount += 1
						light(bulb, SODIUM, 1.1, 46)
					end
				end
				prev = at
			end
		end)
	end
	if field then
		for _, sx in { -1, 1 } do
			for _, z in { -160, 20 } do
				local glow = ctx.block("LavaRunnelGlowSeam", V(14, 0.4, 40), V(sx * 212, field.LiquidLevel + 0.6, z), EMBER, Enum.Material.SmoothPlastic, nil, 0.55)
				light(glow, EMBER, 1.4, 44)
			end
			plume(V(sx * 212, field.LiquidLevel + 1, -60), EMBER, 1, 6, 5, 2.4)
		end
	end
	landmarks += 2

	-- 8. Work clutter and ground cover.
	local clutter, groundCover = H.workClutter(InfernalFoundry.Floor22Landmarks, 22, 34, 340)
	props += clutter
	ctx.setAttribute("Floor22Landmarks", landmarks)
	ctx.setAttribute("Floor22Props", props)
	ctx.setAttribute("Floor22GroundCover", groundCover)
end

-- Floor 23 landmark footprints (see Floor21Landmarks). Furnace towers and ducts stand on plinths in the lava
-- (Y = -6), between the rib links.
InfernalFoundry.Floor23Landmarks = table.freeze({
	{ Id = "FurnaceTowerSW", X = -68, Z = 100, Y = -6, HalfX = 10, HalfZ = 10, Top = 59.3 },
	{ Id = "FurnaceTowerSE", X = 68, Z = 100, Y = -6, HalfX = 10, HalfZ = 10, Top = 59.3 },
	{ Id = "FurnaceTowerW", X = -68, Z = -25, Y = -6, HalfX = 10, HalfZ = 10, Top = 59.3 },
	{ Id = "FurnaceTowerE", X = 68, Z = -25, Y = -6, HalfX = 10, HalfZ = 10, Top = 59.3 },
	{ Id = "FurnaceTowerNW", X = -68, Z = -145, Y = -6, HalfX = 10, HalfZ = 10, Top = 59.3 },
	{ Id = "FurnaceTowerNE", X = 68, Z = -145, Y = -6, HalfX = 10, HalfZ = 10, Top = 59.3 },
	{ Id = "DuctW", X = -45.8, Z = -25, Y = -6, HalfX = 13.8, HalfZ = 4.2, Top = 28 },
	{ Id = "DuctE", X = 45.8, Z = -25, Y = -6, HalfX = 13.8, HalfZ = 4.2, Top = 28 },
	{ Id = "DuctNW", X = -45.8, Z = -145, Y = -6, HalfX = 13.8, HalfZ = 4.2, Top = 28 },
	{ Id = "DuctNE", X = 45.8, Z = -145, Y = -6, HalfX = 13.8, HalfZ = 4.2, Top = 28 },
	{ Id = "Crucible", X = -167.7, Z = -215.5, Y = 24, HalfX = 8, HalfZ = 10.5, Top = 17 },
	{ Id = "MouldBeds", X = -157, Z = -193, Y = 24, HalfX = 19.5, HalfZ = 13.5, Top = 1.8 },
	{ Id = "CastingJib", X = -172, Z = -174.7, Y = 24, HalfX = 3, HalfZ = 11.2, Top = 32.4 },
	{ Id = "SlagLadle", X = 173.1, Z = 40, Y = 4, HalfX = 8.5, HalfZ = 5.2, Top = 15.4 },
	{ Id = "QuenchNorth", X = 173, Z = -120, Y = 16, HalfX = 7.8, HalfZ = 5.3, Top = 4.1 },
	{ Id = "QuenchSouth", X = 173, Z = -60, Y = 16, HalfX = 7.8, HalfZ = 5.3, Top = 4.1 },
	{ Id = "CoolingRacks", X = -160, Z = -90, Y = 14, HalfX = 14, HalfZ = 30, Top = 9.2 },
	{ Id = "BladeDisplays", X = 148, Z = -223, Y = 22, HalfX = 24, HalfZ = 2, Top = 8.9 },
	{ Id = "FurnaceMouthDoor", X = 0, Z = -331.6, Y = 28, HalfX = 28, HalfZ = 6.5, Top = 64.8 },
	{ Id = "MouthStackWest", X = -48, Z = -333.3, Y = 28, HalfX = 8.4, HalfZ = 11.1, Top = 115.5 },
	{ Id = "MouthStackEast", X = 48, Z = -333.3, Y = 28, HalfX = 8.4, HalfZ = 11.1, Top = 115.5 },
	{ Id = "ChargingCraneWest", X = -87.7, Z = 226, Y = 0, HalfX = 11.2, HalfZ = 3, Top = 32.4 },
	{ Id = "ChargingCraneEast", X = 87.7, Z = 226, Y = 0, HalfX = 11.2, HalfZ = 3, Top = 32.4 },
}) :: { Landmark }

-- Floor 23, Furnace Causeway: the furnace line over a lava lake. The causeway's stone piers and pipe runs are
-- TowerRoomBuilder's; here, six furnace towers and their bellows ducts flanking the spine, the tilting crucible
-- pouring into the Casting Bay's mould beds under a jib crane, a slag ladle tipping into the lava off the Slag
-- Bay, steaming quench tanks, racks of glowing blades in the Cooling Bay, the Blade Gallery's displays, the
-- giant furnace door at the Mouth between smoking flue stacks, coal tubs and cranes on the Charging Floor, and
-- crust floes adrift on the lake.
function InfernalFoundry.Floor23(ctx: any)
	local H = helpers(ctx)
	local origin: Vector3, field, bottom: number, d: number, P = H.origin, H.field, H.bottom, H.d, H.P
	local surfaceAt, boxAt, rod, lump, light, plume, piece = H.surfaceAt, H.boxAt, H.rod, H.lump, H.light, H.plume, H.piece
	local glowOf, noCollide, fallbackCart, fallbackHeap, fallbackStack = H.glowOf, H.noCollide, H.fallbackCart, H.fallbackHeap, H.fallbackStack
	local landmarks, props = 0, 0
	local MOLTEN = tinted(SOOT, { GLOW = { Color = rgb(255, 196, 96), Material = Enum.Material.Neon } })
	local CRUST = tinted(SOOT, { ALT = { Color = rgb(34, 30, 32), Material = Enum.Material.Basalt }, STONE = { Color = rgb(52, 44, 44), Material = Enum.Material.Basalt } })
	local QUENCH = tinted(SOOT, { CRYSTAL = { Color = rgb(22, 26, 30), Material = Enum.Material.Glass, Transparency = 0.15 } })
	local lavaY = if field then field.LiquidLevel else bottom

	for _, lm in InfernalFoundry.Floor23Landmarks do
		ctx.reserve(lm.X, lm.Z, math.max(lm.HalfX, lm.HalfZ))
	end

	-- A soot-brick plinth from the lava floor up to a piece's base (towers and ducts stand in the lake).
	local function plinth(x: number, z: number, half: number, top: number)
		local b = bottom - 4
		boxAt("LavaPlinthWall", V(half * 2, top - b, half * 2), CFrame.new(x, (top + b) / 2, z), BRICK_DARK, Enum.Material.Brick)
		boxAt("LavaPlinthCap", V(half * 2 + 1, 1, half * 2 + 1), CFrame.new(x, top - 0.5, z), IRON_DARK, Enum.Material.Metal)
	end

	-- Native fallbacks for the Floor 23 kit.
	local function fallbackTower(cf: CFrame)
		boxAt("FurnaceTowerShaft", V(16, 36, 14), cf * CFrame.new(0, 22, 0), BRICK, Enum.Material.Brick)
		boxAt("FurnaceTowerBase", V(20, 4, 18), cf * CFrame.new(0, 2, 0), BRICK_DARK, Enum.Material.Brick)
		boxAt("FurnaceTowerMouthGlow", V(7, 7, 0.4), cf * CFrame.new(0, 7.5, 7.1), EMBER, Enum.Material.Neon)
		ctx.cyl("FurnaceTowerStack", (cf * CFrame.new(0, 49, 1.5)).Position, 2.6, 18, IRON, Enum.Material.Metal)
	end
	local function fallbackDuct(cf: CFrame)
		local rise = boxAt("BellowsDuctRiser", V(5, 22, 5), cf * CFrame.new(0, 11, -4), IRON, Enum.Material.Metal)
		rise.Shape = Enum.PartType.Block
		boxAt("BellowsDuctRun", V(5, 5, 22), cf * CFrame.new(0, 24.6, 7), IRON, Enum.Material.Metal)
	end
	local function fallbackCrucible(cf: CFrame)
		for _, sx in { -6.2, 6.2 } do
			boxAt("CrucibleFrame", V(1.4, 9, 3), cf * CFrame.new(sx, 4.5, -2), IRON_DARK, Enum.Material.Metal)
		end
		boxAt("CruciblePot", V(8, 8, 8), cf * CFrame.new(0, 8.5, -2) * CFrame.Angles(math.rad(55), 0, 0), IRON, Enum.Material.Metal)
		local pour = boxAt("CruciblePourGlowSeam", V(1.2, 8, 1.2), cf * CFrame.new(0, 4.5, 7.5), rgb(255, 196, 96), Enum.Material.Neon)
		pour.CanCollide = false
	end
	local function fallbackMould(cf: CFrame)
		boxAt("MouldBedSand", V(16, 1.4, 10), cf * CFrame.new(0, 0.7, 0), rgb(70, 60, 56), Enum.Material.Sand)
		local glow = boxAt("MouldBedGlowSeam", V(12, 0.15, 6), cf * CFrame.new(0, 1.45, 0), rgb(255, 150, 60), Enum.Material.CrackedLava)
		glow.CanCollide = false
	end
	local function fallbackLadle(cf: CFrame)
		boxAt("LadleCartBogie", V(5.6, 1.2, 11), cf * CFrame.new(0, 2, -1), IRON_DARK, Enum.Material.Metal)
		boxAt("LadleCartBell", V(7, 7, 7), cf * CFrame.new(0, 8, -1) * CFrame.Angles(math.rad(70), 0, 0), IRON, Enum.Material.Metal)
		local pour = boxAt("LadleCartPourGlowSeam", V(1, 9, 1), cf * CFrame.new(0, 3, 8), rgb(255, 196, 96), Enum.Material.Neon)
		pour.CanCollide = false
	end
	local function fallbackRack(cf: CFrame)
		boxAt("CoolingRackFrame", V(12, 9, 0.5), cf * CFrame.new(0, 4.5, 0), IRON_DARK, Enum.Material.Metal)
		local glow = boxAt("CoolingRackBladesGlowSeam", V(10, 1, 0.3), cf * CFrame.new(0, 4.4, 0.4), EMBER, Enum.Material.Neon)
		glow.CanCollide = false
	end
	local function fallbackDisplay(cf: CFrame)
		boxAt("BladeDisplayFrame", V(8, 8.6, 0.6), cf * CFrame.new(0, 4.3, -0.8), TIMBER, Enum.Material.Wood)
		for k = -1, 1 do
			boxAt("BladeDisplaySword", V(0.5, 6.5, 0.15), cf * CFrame.new(k * 2.2, 4, -0.3), rgb(150, 146, 140), Enum.Material.Metal)
		end
	end
	local function fallbackDoor(cf: CFrame)
		for _, sx in { -1, 1 } do
			boxAt("MouthDoorPierWall", V(13, 64, 10), cf * CFrame.new(sx * 21.5, 32, 0), BRICK, Enum.Material.Brick)
		end
		boxAt("MouthDoorLintelWall", V(30, 22, 10), cf * CFrame.new(0, 53, 0), BRICK_DARK, Enum.Material.Brick)
		local fire = boxAt("MouthDoorFireGlow", V(7.5, 7.5, 0.6), cf * CFrame.new(0, 14, 2), rgb(255, 210, 120), Enum.Material.Neon)
		light(fire, rgb(255, 190, 100), 2, 70)
		boxAt("MouthDoorDepth", V(30, 42, 1), cf * CFrame.new(0, 21, -4.5), rgb(255, 150, 60), Enum.Material.SmoothPlastic)
	end
	local function fallbackJib(cf: CFrame)
		boxAt("JibMast", V(3, 26, 3), cf * CFrame.new(0, 13, 0), IRON_DARK, Enum.Material.Metal)
		local boom = boxAt("JibBoom", V(1, 1, 19), cf * CFrame.new(0, 29, 9) * CFrame.Angles(math.rad(-18), 0, 0), IRON_DARK, Enum.Material.Metal)
		boom.CanCollide = false
		local hang = boxAt("JibChain", V(0.4, 14, 0.4), cf * CFrame.new(0, 25, 18), IRON_DARK, Enum.Material.Metal)
		hang.CanCollide = false
	end
	local function fallbackCrust(cf: CFrame)
		lump("CrustFloe", (cf * CFrame.new(0, 0.4, 0)).Position, V(15, 1.6, 11), rgb(34, 30, 32), Enum.Material.Basalt)
	end
	local function fallbackVent(cf: CFrame)
		ctx.cyl("SteamVentStack", (cf * CFrame.new(0, 4.8, 0)).Position, 1.1, 8, IRON, Enum.Material.Metal)
	end

	-- =====================================================================================================
	-- 1. Six furnace towers flanking the spine, their mouths toward the causeway, each fed by a bellows duct.
	-- =====================================================================================================
	local towerLights = 0
	for k, spot in { { -68, 100 }, { 68, 100 }, { -68, -25 }, { 68, -25 }, { -68, -145 }, { 68, -145 } } do
		local x, z = spot[1], spot[2]
		plinth(x, z, 11, -6)
		local facing = if x < 0 then 90 else -90
		local tower = piece("FurnaceTower", x, z, facing, "FurnaceTower", 1, MOLTEN, fallbackTower, -6)
		local mouth = glowOf(tower)
		if mouth and towerLights < 6 then
			towerLights += 1
			light(mouth, EMBER, 1.8, 50)
		end
		if k % 2 == 0 then
			plume(V(x, 56, z + 1.5), rgb(70, 60, 58), 9, 3, 6, 8)
		end
		if z < 0 then
			-- The duct's riser stands 4 studs inboard of its origin (its run reaches out to the tower).
			plinth(if x < 0 then -36 else 36, z, 4.6, -6)
			piece("BellowsDuct", if x < 0 then -40 else 40, z, if x < 0 then -90 else 90, "BellowsDuctRun", 1, SOOT, fallbackDuct, -6)
		end
	end
	landmarks += 2
	props += 10

	-- =====================================================================================================
	-- 2. The Casting Bay: the tilting crucible pouring into a grid of mould beds, a jib crane over them.
	-- =====================================================================================================
	local cast = P.CastingBay
	local crucible = piece("TiltingCrucible", -168, -217, 0, "TiltingCrucible", 1, MOLTEN, fallbackCrucible, cast.Y)
	local pourGlow = glowOf(crucible)
	if pourGlow then light(pourGlow, rgb(255, 196, 96), 2, 50) end
	plume(V(-168, cast.Y + 2, -207), rgb(255, 200, 110), 0.8, 10, 8, 1.4)
	for _, spot in { { -168, -201 }, { -146, -201 }, { -168, -185 }, { -146, -185 } } do
		piece("MouldBed", spot[1], spot[2], 0, "MouldBed", 1, MOLTEN, fallbackMould, cast.Y)
	end
	piece("CastingJib", -172, -167, 180, "JibCrane", 1, SOOT, fallbackJib, cast.Y)
	landmarks += 3
	props += 6

	-- =====================================================================================================
	-- 3. The Slag Bay: a slag ladle on its rails tipping over the bay's edge into the lava; slag pots by it.
	-- =====================================================================================================
	local slag = P.SlagBay
	local ladle = piece("SlagLadleCart", 172, 40, 90, "SlagLadleCart", 1, MOLTEN, fallbackLadle, slag.Y)
	local ladleGlow = glowOf(ladle)
	if ladleGlow then light(ladleGlow, rgb(255, 196, 96), 1.8, 46) end
	plume(V(184, lavaY + 1, 40), EMBER, 1.2, 8, 7, 2)
	ctx.group("SlagBayRails", function()
		for _, side in { -2.6, 2.6 } do
			local r = ctx.block("SlagRailTrack", V(44, 0.32, 0.45), V(156, slag.Y + 0.3, 40 + side), rgb(128, 122, 118), Enum.Material.Metal)
			r.CanCollide = false
			r.CanQuery = false
		end
	end)
	for k, spot in { { 160, 70 }, { 172, 66 } } do
		piece("SlagPot", spot[1], spot[2], k * 40, "MessCauldron", 1, SOOT, function(cf)
			ctx.cyl("SlagPotBody", (cf * CFrame.new(0, 2.4, 0)).Position, 3.2, 4.8, IRON, Enum.Material.Metal)
		end, slag.Y)
	end
	landmarks += 1
	props += 3

	-- =====================================================================================================
	-- 4. The East Quench Bay: quench tanks steaming at its free corners, with steam vents.
	-- =====================================================================================================
	local quench = P.EastGallery
	for _, z in { -60, -120 } do
		piece("QuenchTank", 173, z, 90, "QuenchTank", 0.55, QUENCH, function(cf)
			boxAt("QuenchRim", V(14, 1.6, 9), cf * CFrame.new(0, 0.8, 0), IRON, Enum.Material.Metal)
		end, quench.Y)
		plume(V(173, quench.Y + 3, z), rgb(226, 222, 218), 6, 4, 3, 6)
	end
	for _, spot in { { 112, -60 }, { 178, -90 } } do
		piece("SteamVent", spot[1], spot[2], 0, "SteamVent", 1, SOOT, fallbackVent, quench.Y)
	end
	landmarks += 1
	props += 4

	-- =====================================================================================================
	-- 5. The Cooling Bay's racks of glowing blades, and the Blade Gallery's displays of finished weapons.
	-- =====================================================================================================
	local cool = P.CoolingBay
	local rackGlow = 0
	for _, x in { -170, -150 } do
		for _, z in { -112, -90, -68 } do
			if not (x == -150 and z == -90) then
				local rack = piece("CoolingRack", x, z, 90, "CoolingRack", 1, MOLTEN, fallbackRack, cool.Y)
				local g = glowOf(rack)
				if g and rackGlow < 1 then
					rackGlow += 1
					light(g, EMBER, 1.2, 36)
				end
			end
		end
	end
	local blade = P.BladeGallery
	for _, x in { 130, 142, 154, 166 } do
		piece("BladeDisplay", x, -223, 0, "BladeDisplay", 1, tinted(SOOT, { METAL = { Color = rgb(168, 164, 158), Material = Enum.Material.Metal } }), fallbackDisplay, blade.Y)
	end
	piece("BladeDisplay", 172, -171, -90, "BladeDisplay", 1, SOOT, fallbackDisplay, blade.Y)
	landmarks += 2
	props += 10

	-- =====================================================================================================
	-- 6. The Furnace Mouth: the giant door at the head of the stair between two flue stacks, more stacks
	--    banked along the back wall.
	-- =====================================================================================================
	local apex = P.Apex
	ctx.group("FurnaceMouthDoor", function()
		local cf = CFrame.new(0, apex.Y, -332)
		if ctx.has("FurnaceDoorGiant") then
			local mdl = ctx.kitAt("FurnaceDoorGiant", cf, V(1, 1.2, 0.8), MOLTEN)
			local g = glowOf(mdl)
			if g then light(g, rgb(255, 196, 110), 2.2, 80) end
		else
			fallbackDoor(cf)
		end
	end)
	plume(V(0, apex.Y + 20, -334), rgb(255, 180, 90), 1.4, 12, 10, 1.8)
	-- Square to the wall, each stack's flue duct turned toward the hall.
	for k, spot in { { -48, -336, 1.15 }, { 48, -336, 1.15 }, { -104, -338, 1.0 }, { 104, -338, 1.0 }, { -165, -338, 0.9 }, { 165, -338, 0.9 } } do
		local sx, sz, s = spot[1], spot[2], spot[3]
		local sy = if math.abs(sx) <= 104 then apex.Y - 1 else nil
		piece("FlueStack", sx, sz, 0, "FlueStack", s, SOOT, function(cf) fallbackStack(cf, s) end, sy)
		if k <= 2 then
			plume(V(sx, (sy or apex.Y) + 100 * s + 2, sz), rgb(56, 48, 48), 11 * s, 3, 7, 9)
		end
	end
	landmarks += 2
	props += 6

	-- =====================================================================================================
	-- 7. The Charging Floor: coal tubs on two sidings, coal heaped by them, two jib cranes over the floor.
	-- =====================================================================================================
	local yard = P.Basin
	local function siding(z: number, x0: number, x1: number)
		local seg = 12
		for k = 0, math.floor((x1 - x0) / seg) - 1 do
			local xa = x0 + k * seg
			ctx.group("ChargingSiding", function()
				for _, side in { -2.6, 2.6 } do
					local r = ctx.block("SidingRailTrack", V(seg, 0.32, 0.45), V(xa + seg / 2, yard.Y + 0.3, z + side), rgb(128, 122, 118), Enum.Material.Metal)
					r.CanCollide = false
					r.CanQuery = false
				end
				for j = 0, 3 do
					local sl = ctx.block("SidingSleeperTrack", V(1.4, 0.2, 9), V(xa + 1.5 + j * 3, yard.Y + 0.1, z), TIMBER, Enum.Material.Wood)
					sl.CanCollide = false
					sl.CanQuery = false
				end
			end)
		end
	end
	siding(133, -200, -30)
	siding(133, 30, 200)
	siding(228, -200, -30)
	siding(228, 30, 200)
	for k, x in { -170, -159, -148, 148, 159, 170 } do
		piece("CoalTub", x, 133, 90, "OreCart", 1, if k % 2 == 0 then SOOT else ORE_TINT, fallbackCart, yard.Y)
	end
	for k, spot in { { -130, 228 }, { 130, 228 }, { -60, 135 }, { 60, 135 } } do
		piece("CoalHeap", spot[1], spot[2], k * 53, "CoalHeap", 1.2, SOOT, function(cf) fallbackHeap(cf, COAL, Enum.Material.Basalt) end, yard.Y)
	end
	piece("ChargingCrane", -80, 226, -90, "JibCrane", 1, SOOT, fallbackJib, yard.Y)
	piece("ChargingCrane", 80, 226, 90, "JibCrane", 1, SOOT, fallbackJib, yard.Y)
	landmarks += 2
	props += 12

	-- =====================================================================================================
	-- 8. The lava lake: crust floes adrift, and its glow lighting the causeway from below.
	-- =====================================================================================================
	local rng = Random.new(23 * 4243)
	local floes, glows = 0, 0
	if field then
		for _ = 1, 120 do
			if floes >= 14 then break end
			local x, z = rng:NextNumber(-240, 240), rng:NextNumber(-300, 110)
			if field.Kind(x, z) == "POOL" and ctx.footprintClear(x, z, 10, 10) then
				local clear = true
				for _, lm in InfernalFoundry.Floor23Landmarks do
					if math.abs(lm.X - x) < lm.HalfX + 12 and math.abs(lm.Z - z) < lm.HalfZ + 12 then
						clear = false
						break
					end
				end
				if clear then
					floes += 1
					ctx.reserve(x, z, 10)
					local m = piece("CrustFloe", x, z, rng:NextNumber(0, 360), "CrustIsland", rng:NextNumber(0.7, 1.3), CRUST, fallbackCrust, lavaY - 0.2)
					noCollide(m)
				end
			end
		end
		for _, spot in { { -40, 60 }, { 40, -60 }, { -40, -180 }, { 40, -260 } } do
			if glows < 4 then
				glows += 1
				local g = ctx.block("LavaLakeGlowSeam", V(30, 0.4, 30), V(spot[1], lavaY + 0.5, spot[2]), EMBER, Enum.Material.SmoothPlastic, nil, 0.6)
				light(g, EMBER, 1.6, 60)
			end
		end
		plume(V(-120, lavaY + 1, -20), EMBER, 1, 6, 5, 2.6)
	end
	landmarks += 1
	props += floes

	-- 9. Work clutter and ground cover (dry ground only: the Charging Floor and the bays).
	local clutter, groundCover = H.workClutter(InfernalFoundry.Floor23Landmarks, 23, 30, 320)
	props += clutter
	ctx.setAttribute("Floor23Landmarks", landmarks)
	ctx.setAttribute("Floor23Props", props)
	ctx.setAttribute("Floor23GroundCover", groundCover)
end

InfernalFoundry.Helpers = helpers
InfernalFoundry.SOOT = SOOT
InfernalFoundry.ORE_TINT = ORE_TINT
InfernalFoundry.LAMP_TINT = LAMP_TINT
InfernalFoundry.Tinted = tinted
InfernalFoundry.Colors = table.freeze({
	IRON = IRON,
	IRON_DARK = IRON_DARK,
	BRICK = BRICK,
	BRICK_DARK = BRICK_DARK,
	BRASS = BRASS,
	RUST = RUST,
	TIMBER = TIMBER,
	COAL = COAL,
	ORE = ORE,
	SLAG = SLAG,
	EMBER = EMBER,
	LAMP = LAMP,
})

return table.freeze(InfernalFoundry)
