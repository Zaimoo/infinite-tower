-- Tower Biome Kit and per-biome floor lighting specs. Bundled by run.ps1 after the module list; `nodes`,
-- `register` and `require` come from the shim.
local Kit = require(nodes["ReplicatedStorage.Shared.Config.TowerBiomeKit"])
local Light = require(nodes["ReplicatedStorage.Shared.Config.HubLighting"])
local Floors = require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end

local ROLES = {
	STONE = true, TRIM = true, ACCENT = true, MOSS = true, GLOW = true, WOOD = true, FOLIAGE = true,
	METAL = true, GOLD = true, CRYSTAL = true, CAP = true, STEM = true, ALT = true, CORAL = true,
	BULB = true, CANDLE = true, SILK = true,
}

test("Every kit template has a size, stands on the ground and uses known colour roles", function()
	local count = 0
	for name, t in Kit.Templates do
		count += 1
		assert(t.Size.X > 0 and t.Size.Y > 0 and t.Size.Z > 0, name .. " has no size")
		-- Feet and roots may dip a little (TowerKitProps caps the sink at placement).
		assert(t.Min.Y > -2.5 and t.Min.Y < 0.5, name .. " does not stand on its origin")
		assert(#t.Roles > 0, name .. " has no roles")
		for _, role in t.Roles do
			assert(ROLES[role], name .. " uses unknown role " .. role)
		end
	end
	assert(count == 30, "expected 30 templates, got " .. count)
end)

test("Every biome on the floor list has a kit whose templates exist", function()
	for id = 1, 50 do
		local floor = Floors.Get(id)
		local biome = Kit.Biomes[floor.BiomeId]
		assert(biome, "no kit for " .. floor.BiomeId)
		for _, name in { biome.Tree, biome.Spire, biome.Pine } do
			if name then
				assert(Kit.Templates[name], floor.BiomeId .. " names missing template " .. name)
			end
		end
		assert(#biome.Clutter > 0, floor.BiomeId .. " has no clutter")
		for _, name in biome.Clutter do
			assert(Kit.Templates[name], floor.BiomeId .. " clutter names missing template " .. name)
		end
		for role, swatch in biome.Palette do
			assert(ROLES[role], floor.BiomeId .. " palette has unknown role " .. role)
			-- (The shim models Color3 as a table and enum items as strings.)
			assert(swatch.Color ~= nil and swatch.Material ~= nil, floor.BiomeId .. " palette " .. role .. " is incomplete")
		end
	end
	for role in Kit.SharedPalette do
		assert(ROLES[role], "shared palette has unknown role " .. role)
	end
	for name in Kit.RefScale do
		assert(Kit.Templates[name], "RefScale names missing template " .. name)
	end
	for name in Kit.CastsShadow do
		assert(Kit.Templates[name] or Kit.ExtraTemplates[name], "CastsShadow names missing template " .. name)
	end
end)

test("Every extra floor-specific template has a size, stands on the ground and uses known colour roles", function()
	local count = 0
	for name, t in Kit.ExtraTemplates do
		count += 1
		assert(not Kit.Templates[name], name .. " is both a core and an extra template")
		assert(t.Size.X > 0 and t.Size.Y > 0 and t.Size.Z > 0, name .. " has no size")
		assert(t.Min.Y > -3 and t.Min.Y < 2, name .. " does not stand on its origin")
		assert(#t.Roles > 0, name .. " has no roles")
		for _, role in t.Roles do
			assert(ROLES[role], name .. " uses unknown role " .. role)
		end
	end
	-- Floor 6 (Sporelit Entry, fungal_f6_kit).
	for _, name in { "ElderCap", "GlowcapTuftA", "GlowcapTuftB", "SporeMoss", "MyceliumVein", "CandleAltar", "VelmariLampPost", "HangingRootFringe", "EggSacCluster", "PadCap" } do
		assert(Kit.ExtraTemplates[name], "fungal_f6_kit is missing " .. name)
	end
	-- Floor 7 (Mycelium Galleries, fungal_f7_kit).
	for _, name in { "LampNiche", "MyceliumNet" } do
		assert(Kit.ExtraTemplates[name], "fungal_f7_kit is missing " .. name)
	end
	-- Floor 8 (Blooming Chasm, fungal_f8_kit: the Lampkeepers' camp kit).
	for _, name in { "CapShelter", "CampSupplies", "CrystalBrazier", "Barricade", "ChalkSign" } do
		assert(Kit.ExtraTemplates[name], "fungal_f8_kit is missing " .. name)
	end
	-- Floor 9 (Rotcap Keep, fungal_f9_kit).
	for _, name in { "BrokenBarricade", "RotVat", "OssuaryBones", "RotcapTower", "VelmariBanner", "RotcapCluster", "RotMyceliumWeb" } do
		assert(Kit.ExtraTemplates[name], "fungal_f9_kit is missing " .. name)
	end
	-- Floor 10 (Matriarch's Hollow, fungal_f10_kit).
	for _, name in { "WebbedArchway", "SilkSpire", "BroodEggClutch", "StolenLampCocoon", "SilkWindlass", "LastLampShrine", "SilkWebCurtain" } do
		assert(Kit.ExtraTemplates[name], "fungal_f10_kit is missing " .. name)
	end
	-- Floor 10's dais and brood pieces (fungal_f10_nest_kit), named apart from fungal_f10_kit's.
	for _, name in { "ShroudSpire", "EggRack", "SilkSpool", "SilkDrape", "CocoonLamp" } do
		local t = Kit.ExtraTemplates[name]
		assert(t, "fungal_f10_nest_kit is missing " .. name)
		assert(t.Min.Y > -2.5 and t.Min.Y < 0.5, name .. " does not stand on its origin")
		for _, role in t.Roles do
			assert(ROLES[role], name .. " uses unknown role " .. role)
		end
	end
	assert(Kit.Biomes.fungal_hollow.Palette.SILK, "fungal palette lacks SILK")
	assert(Kit.Biomes.fungal_hollow.Palette.BULB and Kit.Biomes.fungal_hollow.Palette.CANDLE, "fungal palette lacks BULB or CANDLE")
	assert(count >= 45, "expected Floor 2-5 and Floor 11-15 extra templates")
end)

test("Floor 21 has its own Sootwright kit: at least six new templates for the escalation ladder", function()
	local f21 = { "OreCrusherJaw", "CoalHopper", "OreCart", "TankLocomotive", "SignalCabin", "FurnaceGateDoors",
		"WaterTower", "RailBuffer", "FlueStack", "ScrapHeap", "CoalHeap", "SignalLamp" }
	for _, name in f21 do
		assert(Kit.ExtraTemplates[name], "missing Floor 21 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates), not gate every floor")
	end
	assert(#f21 >= 6)
	-- The tallest Floor 21 landmark (a flue stack) reaches the ladder's 80 studs at its smallest placed scale.
	assert(Kit.ExtraTemplates.FlueStack.Size.Y * 0.85 >= 80)
end)

test("Floor 22 has its own assembly-hall kit: more new templates than Floor 21", function()
	local f22 = { "ConstructShell", "AssemblyScaffold", "ChainHoist", "CraneTrolley", "QuenchTank", "PatternRack",
		"ControlCabin", "FurnaceBox", "WallGear", "ConveyorRollers", "PartsRack", "HydraulicJack" }
	for _, name in f22 do
		assert(Kit.ExtraTemplates[name], "missing Floor 22 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f22 >= 7)
	-- The master jig's scaffold, at its placed height scale (3.1), clears the ladder's 95 studs.
	assert(Kit.ExtraTemplates.AssemblyScaffold.Size.Y * 3.1 >= 95)
end)

test("Floor 23 has its own furnace-line kit: at least eight new templates", function()
	local f23 = { "FurnaceTower", "TiltingCrucible", "MouldBed", "CoolingRack", "BladeDisplay", "FurnaceDoorGiant",
		"SlagLadleCart", "JibCrane", "BellowsDuctRun", "CrustIsland", "SteamVent" }
	for _, name in f23 do
		assert(Kit.ExtraTemplates[name], "missing Floor 23 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f23 >= 8)
	-- The tallest Floor 23 landmarks, the flue stacks flanking the Mouth (scale 1.15), clear the ladder's 110.
	assert(Kit.ExtraTemplates.FlueStack.Size.Y * 1.15 >= 110)
end)

test("Floor 24 has its own Ironflame Bulwark kit: at least nine new templates and a 130+ stud Citadel", function()
	local f24 = { "BulwarkWall", "SluiceTower", "SluiceGateChain", "SlagCannon", "SignalBrazier", "DropHammer",
		"PowderKegStack", "FlameJetPortcullis", "ChainWinch", "SiegeBallista", "ArmourRack", "CitadelDoors" }
	for _, name in f24 do
		assert(Kit.ExtraTemplates[name], "missing Floor 24 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f24 >= 9)
	-- The tallest Floor 24 landmark, Ironflame Citadel keep (scale 1.55), clears the ladder's 130 studs.
	assert(Kit.ExtraTemplates.CitadelDoors.Size.Y * 1.55 >= 130)
end)

test("Floor 25 has its own Titan's Crucible kit: at least ten new templates and a 170+ stud Great Crucible", function()
	local f25 = { "GreatCrucible", "TitanHeartGrate", "GreatBellows", "TitanMouldFist", "TitanMouldHelm",
		"HangingChainRun", "PourSpoutChute", "DuctManifold", "IngotPallet", "PatternLathe", "VaultRibArch",
		"ChainGalleryRail" }
	for _, name in f25 do
		assert(Kit.ExtraTemplates[name], "missing Floor 25 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f25 >= 10)
	-- The colossal Great Crucible centrepiece (scale 1.85) clears the ladder's 170 studs.
	assert(Kit.ExtraTemplates.GreatCrucible.Size.Y * 1.85 >= 170)
end)

test("Floor 26 has its own Kairnfolk kit: at least eight new templates and a 95+ stud tor", function()
	local f26 = { "ForkedBoltTotem", "SplitGraniteTor", "HighlandWindmill", "RuneStandingStone", "ShepherdCroft",
		"DryStoneWall", "RamHurdleFence", "TrailCairnTall", "WindBentPine", "StormgrassTuft", "DolmenBellGate",
		"HighlandSheep", "WaterfallRibbon", "PrayerFlagLine", "StormCrystalSpikes" }
	for _, name in f26 do
		assert(Kit.ExtraTemplates[name], "missing Floor 26 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f26 >= 8)
	-- The split granite tor (scale 0.62) and the forked-bolt totem on its crown (0.95) rise past 95 studs together.
	assert(Kit.ExtraTemplates.SplitGraniteTor.Size.Y * 0.62 + Kit.ExtraTemplates.ForkedBoltTotem.Size.Y * 0.95 >= 95)
	-- The bell-gate's uprights (scale 1.45) stand clear of the 20-stud arrival causeway either side.
	local gate = Kit.ExtraTemplates.DolmenBellGate
	assert(gate.Size.Y * 1.45 > 30, "the bell-gate does not clear the walk")
end)

test("Floor 27 has its own ringfort kit: at least nine new templates and a 115+ stud broch keep", function()
	local f27 = { "BrochKeepTower", "WindHarpTower", "RampartWallSegment", "PalisadeWallSpan", "WatchBellGallows",
		"BeaconBrazier", "CopperWireReel", "CopperForgeHearth", "RamPenChute", "CapacitorCask", "LonghouseRuin",
		"InnerGateArch", "CopperCableMast" }
	for _, name in f27 do
		assert(Kit.ExtraTemplates[name], "missing Floor 27 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f27 >= 9)
	-- The broch keep (placed at scale 2.15) clears the ladder's 115 studs, and stays narrow enough (46 studs at
	-- that scale) to stand between the Lodge's spread portals.
	local keep = Kit.ExtraTemplates.BrochKeepTower
	assert(keep.Size.Y * 2.15 >= 115 and math.max(keep.Size.X, keep.Size.Z) * 2.15 <= 48)
	-- The gate-arch (scale 1.08) clears the walk under it by more than the 14-stud lane.
	assert(Kit.ExtraTemplates.InnerGateArch.Size.Y * 1.08 > 30)
end)

test("Floor 28 has its own skybridge kit: at least ten new templates and 135+ stud crown towers", function()
	local f28 = { "CrownAnchorTower", "SeaStackSpire", "CloudBankLayer", "CableWinchCapstan", "SupplyHoistWindlass",
		"ShedRocFeather", "TalonNestPlatform", "FulguriteSpireTall", "AnemometerMast", "CliffGroundingChain",
		"SnappedBridgeStub", "SkybridgeWaystone", "SquallHornPerch" }
	for _, name in f28 do
		assert(Kit.ExtraTemplates[name], "missing Floor 28 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f28 >= 10)
	-- The crown towers (placed at scale 2) clear the ladder's 135 studs.
	assert(Kit.ExtraTemplates.CrownAnchorTower.Size.Y * 2 >= 135)
	-- The cloud bank is a broad low drift, not a column (the abyss reads as a sea of cloud).
	local cloud = Kit.ExtraTemplates.CloudBankLayer
	assert(cloud.Size.X > 3 * cloud.Size.Y and cloud.Size.Z > 2 * cloud.Size.Y and #cloud.Roles == 1 and cloud.Roles[1] == "ALT")
	-- The hanging chain is long enough to reach from a high span down into the cloud sea.
	assert(Kit.ExtraTemplates.CliffGroundingChain.Size.Y >= 40)
end)

test("Floor 29 has its own redoubt kit: at least eleven new templates and a 160+ stud citadel keep", function()
	local f29 = { "RedoubtCitadelKeep", "CapacitorCoilSpire", "StormBellGatehouse", "StormkeepRoundTower", "BarbicanGatehouse",
		"CurtainWallSegment", "ShatteredWatchtower", "FaultRetainingButtress", "SignalHornCannon", "ThunderRamStable",
		"LightningSpearBallista", "NexusBrazierPedestal", "WarBannerPole" }
	for _, name in f29 do
		assert(Kit.ExtraTemplates[name], "missing Floor 29 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f29 >= 11)
	-- The citadel keep (placed at scale 1.26) clears the ladder's 160 studs.
	assert(Kit.ExtraTemplates.RedoubtCitadelKeep.Size.Y * 1.26 >= 160)
	-- The gates straddle a walkway: wide enough for a 28-stud link and its landing lane between their towers.
	assert(Kit.ExtraTemplates.StormBellGatehouse.Size.X >= 60 and Kit.ExtraTemplates.BarbicanGatehouse.Size.X >= 60)
end)

test("Floor 31 has its own Blighted Verge kit: at least eight new templates and a 105+ stud Heartrot Spring", function()
	local f31 = { "HollinWaterMill", "MillWheel", "FieldstoneWeir", "PaleBandTree", "GraftKnotPost", "WardensLeanTo",
		"SawnStumpCluster", "HeartrotSpringTrunk", "HollinStileArch", "WattleFence", "FieldstoneCairn", "FelledBandLog",
		"HangingLantern", "AutumnGrassTuft", "RotBloomCluster" }
	for _, name in f31 do
		assert(Kit.ExtraTemplates[name], "missing Floor 31 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f31 >= 8)
	-- The Heartrot Spring elder (placed at scale 1.25) clears the ladder's 105 studs.
	assert(Kit.ExtraTemplates.HeartrotSpringTrunk.Size.Y * 1.25 >= 105)
	-- The Pale Bands are linen (SILK) on every banded template.
	for _, name in { "PaleBandTree", "GraftKnotPost", "HollinStileArch", "FieldstoneCairn", "FelledBandLog" } do
		assert(table.find(Kit.ExtraTemplates[name].Roles, "SILK"), name .. " has no Pale Band")
	end
end)

test("Floor 32 has its own Twisted Orchard kit: at least nine new templates and a 125+ stud Great Cider Press", function()
	local f32 = {
		"GreatCiderPress", "PressHouseRoof", "GraftedCrownTree", "GraftedFruitTreeA", "GraftedFruitTreeB",
		"GraftedFruitTreeC", "PleachedArch", "EspalierWall", "BeeSkepBench", "CiderVatSplit",
		"GraftingBench", "FruitBasketPile", "CrutchPoleProp", "ThornBrambleArch", "HollinBench",
	}
	for _, name in f32 do
		assert(Kit.ExtraTemplates[name], "missing Floor 32 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f32 >= 9)
	-- The Great Cider Press (placed at scale 1.2) clears the ladder's 125 studs.
	assert(Kit.ExtraTemplates.GreatCiderPress.Size.Y * 1.2 >= 125)
	-- The Grafted Crown carries five distinct seasonal crown roles plus linen Pale Bands.
	for _, role in { "CORAL", "ALT", "FOLIAGE", "CAP", "ACCENT", "SILK" } do
		assert(table.find(Kit.ExtraTemplates.GraftedCrownTree.Roles, role), "GraftedCrownTree missing role " .. role)
	end
	-- Pale Bands are linen (SILK) on every banded orchard template.
	for _, name in { "GraftedCrownTree", "GraftedFruitTreeA", "GraftedFruitTreeB", "GraftedFruitTreeC", "PleachedArch" } do
		assert(table.find(Kit.ExtraTemplates[name].Roles, "SILK"), name .. " has no Pale Band")
	end
end)

test("Floor 33 has its own Briar Labyrinth kit: at least ten new templates, low hedges and a 150+ stud Thornheart", function()
	local f33 = {
		"ThornheartKnot", "BriarGatehouse", "HedgeWallStraight", "HedgeWallCorner", "HedgeWallBroken",
		"WattleCroft", "ScarecrowProp", "HangingPlanterPergola", "FieldstoneWellhead", "GibbetCage",
		"RotRoseBush", "TopiaryStag", "TopiaryGraftKnot", "ThreeArmSignpost", "ThornKnotCluster",
		"WardenSkeleton",
	}
	for _, name in f33 do
		assert(Kit.ExtraTemplates[name], "missing Floor 33 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f33 >= 10)
	-- The Thornheart centrepiece (placed at scale 1.1) clears the ladder's 150 studs.
	assert(Kit.ExtraTemplates.ThornheartKnot.Size.Y * 1.1 >= 150)
	-- Every labyrinth hedge piece stays at or under 9 studs so the gameplay camera reads the maze from above.
	for _, name in { "HedgeWallStraight", "HedgeWallCorner", "HedgeWallBroken" } do
		assert(Kit.ExtraTemplates[name].Size.Y <= 9, name .. " is taller than the 9-stud hedge limit")
	end
	-- Pale Bands are linen (SILK) on the banded labyrinth templates.
	for _, name in { "BriarGatehouse", "ThreeArmSignpost", "ScarecrowProp", "WardenSkeleton", "GibbetCage" } do
		assert(table.find(Kit.ExtraTemplates[name].Roles, "SILK"), name .. " has no Pale Band")
	end
end)

test("Floor 34 has its own Heartrot Stronghold kit: at least eleven new templates and a 175+ stud Great Rotwood", function()
	local f34 = {
		"GreatRotwoodCavity", "ElderTrunkRootFlare", "ElderTrunkBoleA", "ElderTrunkBoleB", "ElderTrunkFork",
		"TreehouseKeep", "ShelfFungusBracket", "SapTapCistern", "SeedJarStack", "StakePalisadeSegment",
		"StiltHut", "WeepingGallowsTree", "SunkenWardenBoat", "BranchBridgeHanger",
	}
	for _, name in f34 do
		assert(Kit.ExtraTemplates[name], "missing Floor 34 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f34 >= 11)
	-- The Great Rotwood centrepiece (placed at Y scale 1.15) clears the ladder's 175 studs.
	assert(Kit.ExtraTemplates.GreatRotwoodCavity.Size.Y * 1.15 >= 175)
	-- Pale Bands are linen (SILK) on every banded stronghold template.
	for _, name in { "GreatRotwoodCavity", "ElderTrunkBoleA", "TreehouseKeep", "StakePalisadeSegment", "WeepingGallowsTree", "BranchBridgeHanger" } do
		assert(table.find(Kit.ExtraTemplates[name].Roles, "SILK"), name .. " has no Pale Band")
	end
end)

test("Floor 35 has its own Sovereign's Grove kit: at least twelve new templates and a 230+ stud Mother Graft", function()
	local f35 = {
		"MotherGraftTrunk", "MotherGraftLimbOak", "MotherGraftLimbPine", "MotherGraftLimbFruit",
		"RootRidgeSegment", "RootKneeJunction", "LastWardenGraft", "RotbloomGiant", "FallenCrownBranch",
		"SapfallRibbon", "HeartrotGeode", "ThornCagedSeed", "MossMantle", "WardenRootShrine",
	}
	for _, name in f35 do
		assert(Kit.ExtraTemplates[name], "missing Floor 35 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f35 >= 12)
	-- The Mother Graft colossus (placed at Y scale 1.15) clears the ladder's 230 studs.
	assert(Kit.ExtraTemplates.MotherGraftTrunk.Size.Y * 1.15 >= 230)
	-- Pale Bands are linen (SILK) on every banded grove template.
	for _, name in { "MotherGraftTrunk", "LastWardenGraft", "FallenCrownBranch", "ThornCagedSeed", "WardenRootShrine" } do
		assert(table.find(Kit.ExtraTemplates[name].Roles, "SILK"), name .. " has no Pale Band")
	end
end)

test("Floor 39 has its own Pearlguard Vault kit: at least twelve new templates and a 195+ stud Pearl Vault Dome", function()
	local f39 = {
		"PearlVaultDome", "ColossalClam", "SeaWallSegment", "DrownedGateWall", "CoralGateTower",
		"TideArmillaryTower", "PortcullisGatehouse", "MuffledBellStack", "OysterRack", "DivingBell",
		"PearlguardGalley", "CoralWardenStatue", "ShellAwningStall", "HarbourCrane", "CoralCageReliquary",
	}
	for _, name in f39 do
		assert(Kit.ExtraTemplates[name], "missing Floor 39 template " .. name)
		assert(Kit.Templates[name] == nil, name .. " must stay optional (ExtraTemplates)")
	end
	assert(#f39 >= 12)
	assert(Kit.ExtraTemplates.PearlVaultDome.Size.Y >= 195, "PearlVaultDome must clear the ladder's 195 studs")
end)

test("Every biome has an ecosystem built from kit templates", function()
	for biomeId in Kit.Biomes do
		local e = Kit.Ecology[biomeId]
		assert(e, biomeId .. " has no ecology")
		assert(e.Groves > 0 and #e.Trees > 0 and #e.Understory > 0 and #e.Monoliths > 0, biomeId .. " ecology is empty")
		assert(e.TreeScale[1] > 0 and e.TreeScale[1] <= e.TreeScale[2] and e.MonolithScale[1] <= e.MonolithScale[2])
		for _, list in { e.Trees, e.Understory, e.SlopeForest, e.Monoliths } do
			for _, name in list do
				assert(Kit.Templates[name], biomeId .. " ecology names missing template " .. name)
			end
		end
		assert(e.SlopeForestCount == 0 or #e.SlopeForest > 0)
	end
end)

test("The kit has the pieces TowerBiomeAssets builds from", function()
	for _, name in { "ArchPierBase", "ArchPierSegment", "ArchCrown", "CliffRockA", "CliffRockB", "ChasmIsland",
		"CrystalSpire", "GiantMushroom", "LionGuardian", "RobedStatueStaff", "RobedStatueTrident", "PineTree",
		"BanyanTree", "BlightTree", "DeadTree" } do
		assert(Kit.Templates[name], "missing " .. name)
	end
	-- Arch crowns are drawn for a 24-stud span: their capitals sit on pier centres at x = +-12.
	local crown = Kit.Templates.ArchCrown
	assert(math.abs(crown.Min.X + crown.Size.X / 2) < 0.01, "the arch crown is not centred")
end)

test("Each tower floor takes its own biome's lighting grade", function()
	assert(#Light.BiomeGrades == 10)
	local storm = Light.Presets.Storm
	for i, grade in Light.BiomeGrades do
		for key, value in grade do
			assert(storm[key] ~= nil, "grade " .. i .. " sets unknown field " .. key)
			assert(typeof(value) == typeof(storm[key]), "grade " .. i .. " field " .. key .. " has the wrong type")
		end
		local preset = Light.TowerPreset(i)
		for key in storm do
			assert(preset[key] ~= nil, "graded preset " .. i .. " lacks " .. key)
		end
	end
	assert(Light.TowerPreset(nil) == storm)
	assert(Light.TowerPreset(99) == storm)
	for id = 1, 50 do
		local x = 12000 + ((id - 1) % 10) * 2400
		local z = 12000 + math.floor((id - 1) / 10) * 2400
		local floor = Floors.Get(id)
		for _, offset in { Vector3.zero, Vector3.new(250, 0, -300), Vector3.new(-280, 0, 320) } do
			assert(Light.TowerBiomeAt(x + offset.X, z + offset.Z) == floor.BiomeIndex, "floor " .. id .. " reads the wrong biome")
			assert(select(1, Light.Classify(x + offset.X, z + offset.Z)) == "Storm")
		end
	end
	assert(Light.TowerBiomeAt(0, 0) == nil, "the hub is not a tower floor")
	assert(Light.TowerBiomeAt(-14000, -14000) == nil, "the raid arena is not a tower floor")
end)

test("A floor with its own grade layers it over its biome's; the others keep the biome's", function()
	local storm = Light.Presets.Storm
	for id, grade in Light.FloorGrades do
		local biome = math.ceil(id / 5)
		local preset = Light.TowerPreset(biome, id)
		for key, value in grade do
			assert(typeof(value) == typeof(storm[key]), "floor grade " .. id .. " field " .. key .. " has the wrong type")
			assert(preset[key] == value, "floor " .. id .. " does not apply " .. key)
		end
		for key, value in Light.BiomeGrades[biome] do
			if grade[key] == nil then assert(preset[key] == value, "floor " .. id .. " lost its biome's " .. key) end
		end
		assert(Light.TowerPreset(biome, id) == preset, "floor grades are not cached")
	end
	assert(Light.FloorGrades[1] ~= nil, "floor 1 (Overgrown Threshold) has its dawn grade")
	assert(Light.FloorGrades[2] ~= nil, "floor 2 (Broken Aqueduct) has its morning grade")
	assert(Light.FloorGrades[3] ~= nil, "floor 3 (Rootway Crossing) has its noon grade")
	assert(Light.FloorGrades[4] ~= nil, "floor 4 (Vinebound Bastion) has its overcast grade")
	assert(Light.FloorGrades[5] ~= nil, "floor 5 (Mossbound Court) has its golden-hour dusk grade")
	assert(Light.FloorGrades[6] ~= nil, "floor 6 (Sporelit Entry) has its underground-twilight grade")
	assert(Light.FloorGrades[7] ~= nil, "floor 7 (Mycelium Galleries) has its deep-gallery grade")
	assert(Light.FloorGrades[8] ~= nil, "floor 8 (Blooming Chasm) has its full-bloom grade")
	assert(Light.FloorGrades[9] ~= nil, "floor 9 (Rotcap Keep) has its sickly-rot grade")
	assert(Light.FloorGrades[10] ~= nil, "floor 10 (Matriarch's Hollow) has its heart-of-web grade")
	assert(Light.FloorGrades[11] ~= nil, "floor 11 (Cinder Gate) has its searing desert noon grade")
	assert(Light.FloorGrades[12] ~= nil, "floor 12 (Buried Caravan) has its afternoon sandstorm grade")
	assert(Light.FloorGrades[13] ~= nil, "floor 13 (Glasswind Ravine) has its ravine dusk grade")
	assert(Light.FloorGrades[14] ~= nil, "floor 14 (Sunscar Fortress) has its night kiln-glow grade")
	assert(Light.FloorGrades[15] ~= nil, "floor 15 (Colossus Dais) has its volcanic eruption grade")
	assert(Light.FloorGrades[16] ~= nil, "floor 16 (Rimefall Approach) has its overcast winter grade")
	assert(Light.FloorGrades[17] ~= nil, "floor 17 (Frozen Barracks) has its clear cold noon grade")
	assert(Light.FloorGrades[18] ~= nil, "floor 18 (Shattered Iceway) has its blizzard grade")
	assert(Light.FloorGrades[19] ~= nil, "floor 19 (Whiteguard Keep) has its twilight aurora grade")
	assert(Light.FloorGrades[20] ~= nil, "floor 20 (Frostbound Throne) has its frozen night grade")
	assert(Light.FloorGrades[21] ~= nil, "floor 21 (Slagworks Entry) has its smoky red dawn grade")
	assert(Light.FloorGrades[22] ~= nil, "floor 22 (Molten Assembly) has its sodium work-light grade")
	assert(Light.FloorGrades[23] ~= nil, "floor 23 (Furnace Causeway) has its furnace-glare grade")
	assert(Light.FloorGrades[24] ~= nil, "floor 24 (Ironflame Bulwark) has its siege-red night grade")
	assert(Light.FloorGrades[25] ~= nil, "floor 25 (Titan's Crucible) has its molten-heart grade")
	assert(Light.FloorGrades[26] ~= nil, "floor 26 (Stormgrass Rise) has its storm-breaking dawn grade")
	assert(Light.FloorGrades[27] ~= nil, "floor 27 (Thunderhead Outpost) has its gathering thunderhead noon grade")
	assert(Light.FloorGrades[27].AtmosphereHaze > Light.FloorGrades[26].AtmosphereHaze, "floor 27's haze thickens over floor 26's")
	assert(Light.FloorGrades[28] ~= nil, "floor 28 (Skybridge Cliffs) has its cloud-sea squall grade")
	-- The cloud abyss lights the needles from below: the grade's bottom colour shift is brighter than its top's.
	local g28 = Light.FloorGrades[28]
	local function lum(c: Color3): number return c.R + c.G + c.B end
	assert(lum(g28.ColorShift_Bottom) > lum(Light.FloorGrades[27].ColorShift_Bottom), "floor 28's abyss bounce is brighter than floor 27's")
	assert(Light.FloorGrades[31] ~= nil, "floor 31 (Blighted Verge) has its sickly gold afternoon grade")
	assert(Light.FloorGrades[31].AtmosphereHaze < Light.BiomeGrades[7].AtmosphereHaze, "floor 31 is the least murky Corrupted floor")
	assert(Light.FloorGrades[32] ~= nil, "floor 32 (Twisted Orchard) has its overripe rose dusk grade")
	assert(Light.FloorGrades[32].AtmosphereHaze > Light.FloorGrades[31].AtmosphereHaze, "floor 32 is hazier than floor 31")
	assert(Light.FloorGrades[33] ~= nil, "floor 33 (Briar Labyrinth) has its hard-shadow noon grade")
	assert(Light.FloorGrades[33].Contrast >= 0.15, "floor 33 keeps crisp thorn-shadow contrast")
	assert(Light.FloorGrades[33].AtmosphereHaze < Light.FloorGrades[32].AtmosphereHaze, "floor 33 is clearer than floor 32's dusk haze")
	assert(Light.FloorGrades[34] ~= nil, "floor 34 (Heartrot Stronghold) has its canopy gloom grade")
	assert(Light.FloorGrades[34].AtmosphereDensity >= 0.38 and Light.FloorGrades[34].SunRaysIntensity > 0, "floor 34 keeps canopy gloom and sun-ray shafts")
	assert(Light.FloorGrades[35] ~= nil, "floor 35 (Sovereign's Grove) has its blight-eclipse grade")
	assert(Light.FloorGrades[35].BloomIntensity >= 0.58, "floor 35 highlights the Mother Graft cavity with eclipse bloom")
	assert(Light.FloorGrades[29] ~= nil, "floor 29 (Tempest Redoubt) has its electric dusk grade")
	-- Electric dusk: darker than the squall afternoon, hazier, the storm light blooming hardest.
	local g29 = Light.FloorGrades[29]
	assert(lum(g29.OutdoorAmbient) < lum(g28.OutdoorAmbient) and g29.AtmosphereHaze > g28.AtmosphereHaze and g29.BloomIntensity > g28.BloomIntensity,
		"floor 29's dusk is darker, hazier and blooms harder than floor 28's afternoon")
	assert(Light.FloorGrades[39] ~= nil, "floor 39 (Pearlguard Vault) has its deep blue twilight grade")
	assert(Light.FloorGrades[39].AtmosphereHaze >= 0.9 and Light.FloorGrades[39].BloomIntensity >= 0.48, "floor 39 keeps twilight haze and pearl-vault bloom")
	assert(Light.TowerPreset(6, 30) == Light.TowerPreset(6), "a floor without its own grade shares its biome's")
	for id = 1, 50 do
		local x = 12000 + ((id - 1) % 10) * 2400
		local z = 12000 + math.floor((id - 1) / 10) * 2400
		assert(Light.TowerFloorAt(x + 200, z - 250) == id, "floor " .. id .. " reads the wrong floor id")
	end
	assert(Light.TowerFloorAt(0, 0) == nil)
end)

print(string.format("tower-biome-kit: %d passed", passed))
