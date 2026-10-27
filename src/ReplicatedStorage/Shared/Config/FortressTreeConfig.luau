--!strict
-- ReplicatedStorage/Shared/Config/FortressTreeConfig.luau
-- Fortress Development Tree (docs/rework-plan/PHASE_4_ONBOARDING_AND_PROGRESSION.md §5).
-- The only way to unlock and level the support facilities. A facility's level is the number of
-- LEVEL nodes owned in its branch; PERK nodes hang off level 3 and level 5.

export type NodeKind = "ROOT" | "LEVEL" | "PERK"
export type PerkKey =
	"OfflineMinutes"
	| "GuardPostRate"
	| "MarketWorkers"
	| "MarketBonus"
	| "TrainingWorkers"
	| "TrainingBonus"
	| "BlessingWorkers"
	| "BlessingLuck"

export type Node = {
	Id: string,
	Branch: string,
	Facility: string?,
	Kind: NodeKind,
	Level: number?, -- LEVEL nodes only
	Name: string,
	Description: string,
	Gold: number,
	FloorGate: number, -- HighestClearedFloor required
	Requires: { string },
	Perk: { Key: PerkKey, Value: number }?,
	Default: boolean?, -- owned by every profile from the start
	System: string?, -- onboarding unlock this node needs; defaults to "FortressTree"
}

export type Branch = { Id: string, Title: string, Facility: string, Color: Color3 }

local FortressTreeConfig = {}

FortressTreeConfig.RootId = "root"

FortressTreeConfig.Branches = table.freeze({
	{ Id = "Outskirts", Title = "OUTSKIRTS", Facility = "GuardPost", Color = Color3.fromRGB(130, 205, 95) },
	{ Id = "Commerce", Title = "COMMERCE", Facility = "Market", Color = Color3.fromRGB(245, 195, 75) },
	{ Id = "Martial", Title = "MARTIAL", Facility = "TrainingGrounds", Color = Color3.fromRGB(235, 80, 80) },
	{ Id = "Divine", Title = "DIVINE", Facility = "GodsBlessing", Color = Color3.fromRGB(255, 226, 150) },
	{ Id = "Command", Title = "COMMAND", Facility = "Squad", Color = Color3.fromRGB(56, 189, 248) },
} :: { Branch })

local nodes: { Node } = {
	{ Id = "root", Branch = "Root", Kind = "ROOT", Name = "Citadel Charter", Description = "The founding charter of your fortress.", Gold = 0, FloorGate = 0, Requires = {}, Default = true },
}

local function level(prefix: string, branch: string, facility: string, lv: number, name: string, gold: number, gate: number, description: string, system: string?)
	table.insert(nodes, {
		Id = prefix .. "_" .. lv,
		Branch = branch,
		Facility = facility,
		Kind = "LEVEL",
		Level = lv,
		Name = name,
		Description = description,
		Gold = gold,
		FloorGate = gate,
		Requires = { if lv == 1 then "root" else prefix .. "_" .. (lv - 1) },
		Default = if gold == 0 then true else nil,
		System = system,
	})
end

local function perk(id: string, branch: string, facility: string, after: string, name: string, gold: number, gate: number, key: PerkKey, value: number, description: string)
	table.insert(nodes, {
		Id = id,
		Branch = branch,
		Facility = facility,
		Kind = "PERK",
		Name = name,
		Description = description,
		Gold = gold,
		FloorGate = gate,
		Requires = { after },
		Perk = { Key = key, Value = value },
	})
end

-- Command: squad slots. Every Master starts with one slot; each level opens the next one.
-- These need only the Squad system (unlocked by the first summon), not the full Fortress Tree.
level("sq", "Command", "Squad", 1, "Second Banner", 500, 0, "Opens squad slot 2.", "Squad")
level("sq", "Command", "Squad", 2, "Third Banner", 2000, 0, "Opens squad slot 3.", "Squad")
level("sq", "Command", "Squad", 3, "Fourth Banner", 6000, 5, "Opens squad slot 4.", "Squad")
level("sq", "Command", "Squad", 4, "Fifth Banner", 15000, 10, "Opens squad slot 5, a full squad.", "Squad")

-- Outskirts: Guard Post (level 1 is owned from the start so idle Gold works immediately)
level("gp", "Outskirts", "GuardPost", 1, "Frontier Camp", 0, 0, "Guard Post Lv.1: a lean-to and campfire on the southern trail.")
level("gp", "Outskirts", "GuardPost", 2, "Timber Shack", 1500, 0, "Guard Post Lv.2: 2 Adventurers, 75 Gold/min base.")
level("gp", "Outskirts", "GuardPost", 3, "Stone Bastion", 6000, 5, "Guard Post Lv.3: 3 Adventurers, 160 Gold/min base.")
perk("gp_night_watch", "Outskirts", "GuardPost", "gp_3", "Night Watch", 8000, 5, "OfflineMinutes", 120, "+2 hours of offline Gold cap.")
level("gp", "Outskirts", "GuardPost", 4, "Fortified Outpost", 20000, 15, "Guard Post Lv.4: 4 Adventurers, 300 Gold/min base.")
level("gp", "Outskirts", "GuardPost", 5, "Frontier Barbican", 60000, 25, "Guard Post Lv.5: 5 Adventurers, 550 Gold/min base.")
perk("gp_long_patrols", "Outskirts", "GuardPost", "gp_5", "Long Patrols", 75000, 25, "GuardPostRate", 0.10, "+10% Guard Post base Gold rate.")

-- Commerce: The Market
level("mk", "Commerce", "Market", 1, "Open the Market", 1000, 0, "Builds the Market: +5% tower loot Gold.")
level("mk", "Commerce", "Market", 2, "Twin Stalls", 3500, 0, "Market Lv.2: +10% tower loot Gold.")
level("mk", "Commerce", "Market", 3, "Bazaar Pavilion", 12000, 5, "Market Lv.3: 2 Merchants, +18% tower loot Gold.")
perk("mk_extra_stall", "Commerce", "Market", "mk_3", "Extra Stall", 15000, 5, "MarketWorkers", 1, "+1 Market worker slot.")
level("mk", "Commerce", "Market", 4, "Exchange Depot", 35000, 15, "Market Lv.4: +28% tower loot Gold.")
level("mk", "Commerce", "Market", 5, "Merchant Exchange", 90000, 25, "Market Lv.5: 3 Merchants, +40% tower loot Gold.")
perk("mk_appraiser", "Commerce", "Market", "mk_5", "Appraiser's Eye", 110000, 25, "MarketBonus", 0.05, "+5% Market base bonus.")

-- Martial: Training Grounds
level("tg", "Martial", "TrainingGrounds", 1, "Raise the Grounds", 1200, 0, "Builds the Training Grounds: +4% squad ATK and HP.")
level("tg", "Martial", "TrainingGrounds", 2, "Training Yard", 4000, 0, "Training Grounds Lv.2: +8% squad ATK and HP.")
level("tg", "Martial", "TrainingGrounds", 3, "Cobblestone Arena", 14000, 5, "Training Grounds Lv.3: 2 Trainers, +14%.")
perk("tg_drill_sergeant", "Martial", "TrainingGrounds", "tg_3", "Drill Sergeant", 18000, 5, "TrainingWorkers", 1, "+1 Training Grounds worker slot.")
level("tg", "Martial", "TrainingGrounds", 4, "War Pavilion", 40000, 15, "Training Grounds Lv.4: +22% squad ATK and HP.")
level("tg", "Martial", "TrainingGrounds", 5, "Martial Amphitheater", 100000, 25, "Training Grounds Lv.5: 3 Trainers, +32%.")
perk("tg_veteran_drills", "Martial", "TrainingGrounds", "tg_5", "Veteran Drills", 125000, 25, "TrainingBonus", 0.03, "+3% Training Grounds base bonus.")

-- Divine: God's Blessing (the whole branch needs the first Biome Boss)
level("gb", "Divine", "GodsBlessing", 1, "Consecrate the Angel", 2500, 5, "Raises the angel on the Plaza Fountain: +4% summon luck.")
level("gb", "Divine", "GodsBlessing", 2, "Gilded Wings", 8000, 5, "God's Blessing Lv.2: +8% summon luck.")
level("gb", "Divine", "GodsBlessing", 3, "Choir of Light", 25000, 5, "God's Blessing Lv.3: 2 Acolytes, +14% summon luck.")
perk("gb_votive_candles", "Divine", "GodsBlessing", "gb_3", "Votive Candles", 30000, 5, "BlessingWorkers", 1, "+1 God's Blessing worker slot.")
level("gb", "Divine", "GodsBlessing", 4, "Radiant Halo", 70000, 15, "God's Blessing Lv.4: +22% summon luck.")
level("gb", "Divine", "GodsBlessing", 5, "Seraph Ascendant", 180000, 25, "God's Blessing Lv.5: 3 Acolytes, +32% summon luck.")
perk("gb_saints_favor", "Divine", "GodsBlessing", "gb_5", "Saint's Favor", 200000, 25, "BlessingLuck", 0.03, "+3% summon luck (still capped at +50%).")

local byId: { [string]: Node } = {}
for _, node in nodes do
	table.freeze(node.Requires)
	table.freeze(node)
	byId[node.Id] = node
end

FortressTreeConfig.Nodes = table.freeze(nodes)
FortressTreeConfig.ById = table.freeze(byId)

-- One squad slot is always open; the Command branch adds the rest.
FortressTreeConfig.BaseSquadSlots = 1
FortressTreeConfig.MaxSquadSlots = 5

-- Facilities gated by the tree; anything else on the plot is a Core Main Building.
FortressTreeConfig.GatedFacilities = table.freeze({ "GuardPost", "Market", "TrainingGrounds", "GodsBlessing" })

return table.freeze(FortressTreeConfig)
