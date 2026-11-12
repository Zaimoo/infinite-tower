--!strict
-- ReplicatedStorage/Shared/Util/FacilityWorkerRules.luau
-- Pure slot geometry, courtyard run-in paths, prop assignments, and per-slot animation rules
-- for physical hero workers stationed at The Market and Training Grounds.
--
-- Note: Uses explicit math.cos/math.sin transforms so rules run identically in both Roblox
-- and the standalone Luau CLI test shim.

export type WorkerFacilityId = "Market" | "TrainingGrounds"
export type PropKind = "NONE" | "CRATE" | "RELIC_ORB" | "LEDGER"

export type StationPose = {
	Pos: Vector3, -- plot-local standing position (relative to Plot Origin)
	LookAt: Vector3, -- plot-local horizontal target the worker faces
	LocalPos: Vector3, -- facility-local standing position
	LocalLookAt: Vector3, -- facility-local facing target
}

export type FacilitySlotSpec = {
	SlotIndex: number,
	FacilityId: WorkerFacilityId,
	RoleId: string,
	RoleTitle: string,
	PrimaryClip: string,
	SecondaryClip: string,
	PropKind: PropKind,
	EquipHeroWeapon: boolean,
	EntryWaypoint: Vector3, -- plot-local waypoint around counter/gate into station
	Primary: StationPose,
	Secondary: StationPose,
	Tertiary: StationPose?,
	DummyIndices: { number },
	BullseyeTargetPlot: Vector3?,
}

local FacilityWorkerRules = {}

FacilityWorkerRules.Facilities = table.freeze({
	Market = table.freeze({
		Center = Vector3.new(42, 0, 30),
		RotationY = math.rad(-145),
		FloorY = 0.30,
		BuildingName = "Building_Market",
		LevelAttr = "FacilityLevel_Market",
	}),
	TrainingGrounds = table.freeze({
		Center = Vector3.new(-38, 0, 30),
		RotationY = 0,
		FloorY = 0.56,
		BuildingName = "Building_TrainingGrounds",
		LevelAttr = "FacilityLevel_TrainingGrounds",
	}),
})

FacilityWorkerRules.PlazaFountainCenter = Vector3.new(0, 0, 0)
FacilityWorkerRules.PlazaFountainClearRadius = 16.5

FacilityWorkerRules.CourtyardBounds = table.freeze({
	MinX = -75,
	MaxX = 75,
	MinZ = -55,
	MaxZ = 55,
})

FacilityWorkerRules.DefaultArchetypeWeapons = table.freeze({
	Marksman = "BOW",
	Vanguard = "SWORD_SHIELD",
	Striker = "DAGGERS",
	Berserker = "AXE",
	Scholar = "STAFF",
	Healer = "TOME",
})

-- Rotates facility-local (lx, ly, lz) into plot-local coordinates around Center & RotationY.
function FacilityWorkerRules.FacilityToPlot(facilityId: WorkerFacilityId, localPoint: Vector3): Vector3
	local meta = if facilityId == "Market"
		then FacilityWorkerRules.Facilities.Market
		else FacilityWorkerRules.Facilities.TrainingGrounds
	local c = math.cos(meta.RotationY)
	local s = math.sin(meta.RotationY)
	local wx = meta.Center.X + localPoint.X * c + localPoint.Z * s
	local wy = meta.Center.Y + localPoint.Y
	local wz = meta.Center.Z - localPoint.X * s + localPoint.Z * c
	return Vector3.new(wx, wy, wz)
end

local function localRotate(cx: number, cz: number, yaw: number, ox: number, oy: number, oz: number): Vector3
	local c = math.cos(yaw)
	local s = math.sin(yaw)
	return Vector3.new(cx + ox * c + oz * s, oy, cz - ox * s + oz * c)
end

local function makeStation(facilityId: WorkerFacilityId, localPos: Vector3, localLookAt: Vector3): StationPose
	return table.freeze({
		Pos = FacilityWorkerRules.FacilityToPlot(facilityId, localPos),
		LookAt = FacilityWorkerRules.FacilityToPlot(facilityId, localLookAt),
		LocalPos = localPos,
		LocalLookAt = localLookAt,
	})
end

local function makeStallStation(
	stallX: number,
	stallZ: number,
	stallYaw: number,
	ox: number,
	oy: number,
	oz: number,
	lookOx: number,
	lookOz: number
): StationPose
	local lPos = localRotate(stallX, stallZ, stallYaw, ox, oy, oz)
	local lLook = localRotate(stallX, stallZ, stallYaw, lookOx, oy, lookOz)
	return makeStation("Market", lPos, lLook)
end

-- Courtyard run-in paths start clear of PlazaFountain (radius 16.5) and lead to each facility apron.
FacilityWorkerRules.CourtyardRunIn = table.freeze({
	Market = table.freeze({
		Vector3.new(14, 0, 10),
		Vector3.new(26, 0, 18),
		FacilityWorkerRules.FacilityToPlot("Market", Vector3.new(0, 0.30, 6.8)),
	}),
	TrainingGrounds = table.freeze({
		Vector3.new(-14, 0, 10),
		Vector3.new(-26, 0, 18),
		FacilityWorkerRules.FacilityToPlot("TrainingGrounds", Vector3.new(0, 0.56, -15.0)),
		FacilityWorkerRules.FacilityToPlot("TrainingGrounds", Vector3.new(0, 0.56, -10.5)),
	}),
})

-- Quiet sideline rest spots when a stationed worker is recovering from coma.
FacilityWorkerRules.ComaRestSpots = table.freeze({
	Market = table.freeze({
		makeStation("Market", Vector3.new(-14.2, 0.30, 2.6), Vector3.new(0, 0.30, 0)),
		makeStation("Market", Vector3.new(-7.4, 0.30, -10.4), Vector3.new(0, 0.30, -2.0)),
		makeStation("Market", Vector3.new(8.2, 0.30, -10.2), Vector3.new(0, 0.30, -2.0)),
		makeStation("Market", Vector3.new(14.4, 0.30, 2.8), Vector3.new(0, 0.30, 0)),
	}),
	TrainingGrounds = table.freeze({
		makeStation("TrainingGrounds", Vector3.new(8.8, 0.56, -8.2), Vector3.new(0, 0.56, 0)),
		makeStation("TrainingGrounds", Vector3.new(10.2, 0.56, -4.6), Vector3.new(0, 0.56, 0)),
		makeStation("TrainingGrounds", Vector3.new(-8.6, 0.56, -8.4), Vector3.new(0, 0.56, 0)),
		makeStation("TrainingGrounds", Vector3.new(-9.6, 0.56, 6.8), Vector3.new(0, 0.56, 0)),
	}),
})

--============================================================================
-- THE MARKET SLOTS (4 Distinct Bazaar Roles)
--============================================================================
local marketFloorY = FacilityWorkerRules.Facilities.Market.FloorY

local marketSlots: { FacilitySlotSpec } = {
	-- Slot 1: Stall_RedAmber (-11.5, 0, -3.5), yaw +28 deg — Bazaar Hawker
	table.freeze({
		SlotIndex = 1,
		FacilityId = "Market" :: WorkerFacilityId,
		RoleId = "BazaarHawker",
		RoleTitle = "Bazaar Hawker",
		PrimaryClip = "MarketHawker",
		SecondaryClip = "MarketHawker",
		PropKind = "NONE" :: PropKind,
		EquipHeroWeapon = false,
		EntryWaypoint = FacilityWorkerRules.FacilityToPlot("Market", Vector3.new(-6.6, marketFloorY, -4.8)),
		Primary = makeStallStation(-11.5, -3.5, math.rad(28), -2.0, marketFloorY, -0.75, -2.0, 4.5),
		Secondary = makeStallStation(-11.5, -3.5, math.rad(28), 2.0, marketFloorY, -0.75, 2.0, 4.5),
		Tertiary = makeStallStation(-11.5, -3.5, math.rad(28), 0.0, marketFloorY, -0.18, 0.0, 4.5),
		DummyIndices = table.freeze({}),
		BullseyeTargetPlot = nil,
	}),
	-- Slot 2: Stall_TanLeft (-4.2, 0, -8.5), yaw +8 deg — Crate Hauler & Stockist
	table.freeze({
		SlotIndex = 2,
		FacilityId = "Market" :: WorkerFacilityId,
		RoleId = "CrateStockist",
		RoleTitle = "Crate Stockist",
		PrimaryClip = "MarketStock",
		SecondaryClip = "MarketCarry",
		PropKind = "CRATE" :: PropKind,
		EquipHeroWeapon = false,
		EntryWaypoint = FacilityWorkerRules.FacilityToPlot("Market", Vector3.new(-6.8, marketFloorY, -5.6)),
		Primary = makeStallStation(-4.2, -8.5, math.rad(8), -1.8, marketFloorY, -0.75, -1.8, 4.2),
		Secondary = makeStation(
			"Market",
			Vector3.new(-7.1, marketFloorY, -11.0),
			Vector3.new(-8.5, marketFloorY, -11.5)
		),
		Tertiary = makeStallStation(-4.2, -8.5, math.rad(8), 1.8, marketFloorY, -0.75, 1.8, 4.2),
		DummyIndices = table.freeze({}),
		BullseyeTargetPlot = nil,
	}),
	-- Slot 3: Stall_TanRight (6.2, 0, -8.0), yaw -12 deg — Relic Appraiser
	table.freeze({
		SlotIndex = 3,
		FacilityId = "Market" :: WorkerFacilityId,
		RoleId = "RelicAppraiser",
		RoleTitle = "Relic Appraiser",
		PrimaryClip = "MarketAppraiser",
		SecondaryClip = "MarketStock",
		PropKind = "RELIC_ORB" :: PropKind,
		EquipHeroWeapon = false,
		EntryWaypoint = FacilityWorkerRules.FacilityToPlot("Market", Vector3.new(8.2, marketFloorY, -4.4)),
		Primary = makeStallStation(6.2, -8.0, math.rad(-12), 1.8, marketFloorY, -0.75, 1.8, 4.2),
		Secondary = makeStation(
			"Market",
			Vector3.new(8.9, marketFloorY, -10.3),
			Vector3.new(11.0, marketFloorY, -10.5)
		),
		Tertiary = makeStallStation(6.2, -8.0, math.rad(-12), -1.8, marketFloorY, -0.75, -1.8, 4.2),
		DummyIndices = table.freeze({}),
		BullseyeTargetPlot = nil,
	}),
	-- Slot 4: Stall_GreenWhite (12.5, 0, -1.5), yaw -38 deg — Quartermaster Ledger (Extra Stall perk)
	table.freeze({
		SlotIndex = 4,
		FacilityId = "Market" :: WorkerFacilityId,
		RoleId = "QuartermasterLedger",
		RoleTitle = "Ledger Scribe",
		PrimaryClip = "MarketLedger",
		SecondaryClip = "MarketLedger",
		PropKind = "LEDGER" :: PropKind,
		EquipHeroWeapon = false,
		EntryWaypoint = FacilityWorkerRules.FacilityToPlot("Market", Vector3.new(8.4, marketFloorY, -3.8)),
		Primary = makeStallStation(12.5, -1.5, math.rad(-38), -1.8, marketFloorY, -0.75, -1.8, 4.2),
		Secondary = makeStation(
			"Market",
			Vector3.new(10.8, marketFloorY, 5.4),
			Vector3.new(13.5, marketFloorY, 7.0)
		),
		Tertiary = makeStation(
			"Market",
			Vector3.new(8.6, marketFloorY, 1.8),
			Vector3.new(12.5, marketFloorY, 3.0)
		),
		DummyIndices = table.freeze({}),
		BullseyeTargetPlot = nil,
	}),
}

--============================================================================
-- TRAINING GROUNDS SLOTS (4 Distinct Combat Drill Roles)
--============================================================================
local ringY = FacilityWorkerRules.Facilities.TrainingGrounds.FloorY
local dummyAngles = { math.rad(35), math.rad(125), math.rad(215), math.rad(305) }

local function makeDummyStrikeStation(dummyIndex: number, standRadius: number): StationPose
	local angle = dummyAngles[dummyIndex]
	local dx = math.cos(angle) * 9.6
	local dz = math.sin(angle) * 9.6
	local sx = math.cos(angle) * standRadius
	local sz = math.sin(angle) * standRadius
	return makeStation(
		"TrainingGrounds",
		Vector3.new(sx, ringY, sz),
		Vector3.new(dx, ringY, dz)
	)
end

local bullseyePlot = FacilityWorkerRules.FacilityToPlot("TrainingGrounds", Vector3.new(0, 4.1, 11.8))

local trainingSlots: { FacilitySlotSpec } = {
	-- Slot 1: Dummy Combo Striker (alternates Dummy_1 NE & Dummy_4 SE with melee/weapon combos)
	table.freeze({
		SlotIndex = 1,
		FacilityId = "TrainingGrounds" :: WorkerFacilityId,
		RoleId = "DummyComboStriker",
		RoleTitle = "Combo Striker",
		PrimaryClip = "AttackBasic",
		SecondaryClip = "AttackSpecial",
		PropKind = "NONE" :: PropKind,
		EquipHeroWeapon = true,
		EntryWaypoint = FacilityWorkerRules.FacilityToPlot("TrainingGrounds", Vector3.new(2.8, ringY, -7.8)),
		Primary = makeDummyStrikeStation(1, 6.2),
		Secondary = makeDummyStrikeStation(4, 6.2),
		Tertiary = makeStation(
			"TrainingGrounds",
			Vector3.new(4.4, ringY, -0.8),
			Vector3.new(7.86, ringY, 5.51)
		),
		DummyIndices = table.freeze({ 1, 4 }),
		BullseyeTargetPlot = nil,
	}),
	-- Slot 2: Bullseye Precision Drill (fires volleys/shockwaves into +Z Bullseye target)
	table.freeze({
		SlotIndex = 2,
		FacilityId = "TrainingGrounds" :: WorkerFacilityId,
		RoleId = "BullseyePrecision",
		RoleTitle = "Target Marksman",
		PrimaryClip = "AttackSpecial",
		SecondaryClip = "TrainingKata",
		PropKind = "NONE" :: PropKind,
		EquipHeroWeapon = true,
		EntryWaypoint = FacilityWorkerRules.FacilityToPlot("TrainingGrounds", Vector3.new(0.0, ringY, -6.5)),
		Primary = makeStation(
			"TrainingGrounds",
			Vector3.new(-1.2, ringY, -1.2),
			Vector3.new(0, ringY, 11.8)
		),
		Secondary = makeStation(
			"TrainingGrounds",
			Vector3.new(2.2, ringY, -1.2),
			Vector3.new(0, ringY, 11.8)
		),
		Tertiary = makeStation(
			"TrainingGrounds",
			Vector3.new(0.0, ringY, 2.4),
			Vector3.new(0, ringY, 11.8)
		),
		DummyIndices = table.freeze({}),
		BullseyeTargetPlot = bullseyePlot,
	}),
	-- Slot 3: Martial Kata & Weapon Rack Inspection (western mat + Dummy_3 lunge + SW rack check)
	table.freeze({
		SlotIndex = 3,
		FacilityId = "TrainingGrounds" :: WorkerFacilityId,
		RoleId = "KataForms",
		RoleTitle = "Kata Specialist",
		PrimaryClip = "TrainingKata",
		SecondaryClip = "AttackBasic",
		PropKind = "NONE" :: PropKind,
		EquipHeroWeapon = true,
		EntryWaypoint = FacilityWorkerRules.FacilityToPlot("TrainingGrounds", Vector3.new(-3.8, ringY, -7.8)),
		Primary = makeStation(
			"TrainingGrounds",
			Vector3.new(-5.8, ringY, 0.8),
			Vector3.new(2.0, ringY, 0.8)
		),
		Secondary = makeDummyStrikeStation(3, 6.2),
		Tertiary = makeStation(
			"TrainingGrounds",
			Vector3.new(-8.6, ringY, -4.6),
			Vector3.new(-11.4, ringY, -4.8)
		),
		DummyIndices = table.freeze({ 3 }),
		BullseyeTargetPlot = nil,
	}),
	-- Slot 4: Drill Sergeant / Arena Coach (Drill Sergeant perk: paces ring + Dummy_2 heavy skill)
	table.freeze({
		SlotIndex = 4,
		FacilityId = "TrainingGrounds" :: WorkerFacilityId,
		RoleId = "DrillSergeant",
		RoleTitle = "Drill Sergeant",
		PrimaryClip = "TrainingCoach",
		SecondaryClip = "AttackSkill",
		PropKind = "NONE" :: PropKind,
		EquipHeroWeapon = true,
		EntryWaypoint = FacilityWorkerRules.FacilityToPlot("TrainingGrounds", Vector3.new(-1.6, ringY, -8.2)),
		Primary = makeStation(
			"TrainingGrounds",
			Vector3.new(0.6, ringY, -5.6),
			Vector3.new(-0.8, ringY, 4.5)
		),
		Secondary = makeStation(
			"TrainingGrounds",
			Vector3.new(-2.6, ringY, 2.0),
			Vector3.new(3.5, ringY, 1.5)
		),
		Tertiary = makeDummyStrikeStation(2, 6.2),
		DummyIndices = table.freeze({ 2 }),
		BullseyeTargetPlot = nil,
	}),
}

FacilityWorkerRules.Slots = table.freeze({
	Market = table.freeze(marketSlots),
	TrainingGrounds = table.freeze(trainingSlots),
})

function FacilityWorkerRules.GetSlotSpec(facilityId: string, slotIndex: number): FacilitySlotSpec?
	local list = if facilityId == "Market"
		then FacilityWorkerRules.Slots.Market
		elseif facilityId == "TrainingGrounds" then FacilityWorkerRules.Slots.TrainingGrounds
		else nil
	if not list then
		return nil
	end
	local clamped = math.clamp(math.floor(slotIndex), 1, #list)
	return list[clamped]
end

function FacilityWorkerRules.GetComaStation(facilityId: string, slotIndex: number): StationPose?
	local list = if facilityId == "Market"
		then FacilityWorkerRules.ComaRestSpots.Market
		elseif facilityId == "TrainingGrounds" then FacilityWorkerRules.ComaRestSpots.TrainingGrounds
		else nil
	if not list then
		return nil
	end
	local clamped = math.clamp(math.floor(slotIndex), 1, #list)
	return list[clamped]
end

function FacilityWorkerRules.GetDummyPlotPosition(dummyIndex: number): Vector3
	local idx = math.clamp(math.floor(dummyIndex), 1, #dummyAngles)
	local angle = dummyAngles[idx]
	return FacilityWorkerRules.FacilityToPlot(
		"TrainingGrounds",
		Vector3.new(math.cos(angle) * 9.6, 0.5, math.sin(angle) * 9.6)
	)
end

function FacilityWorkerRules.ResolveHeroWeaponType(archetype: string?, equippedWeaponType: string?): string
	if type(equippedWeaponType) == "string" and equippedWeaponType ~= "" then
		return equippedWeaponType
	end
	if type(archetype) == "string" then
		local mapped = FacilityWorkerRules.DefaultArchetypeWeapons[archetype]
		if mapped then
			return mapped
		end
	end
	return "SWORD_SHIELD"
end

function FacilityWorkerRules.IsSupportedFacility(facilityId: string?): boolean
	return facilityId == "Market" or facilityId == "TrainingGrounds"
end

return FacilityWorkerRules
