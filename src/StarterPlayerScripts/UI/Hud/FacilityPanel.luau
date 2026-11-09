--!strict
-- StarterPlayerScripts/UI/Hud/FacilityPanel.luau
-- Phase 5 §4.5: one Gilded Grimoire panel for every support facility (Guard Post, Market, Training
-- Grounds, God's Blessing).
--   * Header: drawn facility icon, title, level, worker count and the next Fortress Tree node.
--   * Bonus: the live figure in big inked numbers, a hover preview, and a caption/value breakdown.
--   * Workers: large slots with portrait, labor and a +25% badge, plus REMOVE. An empty slot
--     points at the list; the next locked slot opens the Fortress Tree.
--   * Hero list: labor here, rarity and status, with one clear action per row (ASSIGN, MOVE HERE
--     with a confirm step, RESTING or FULL). Filters: All / Bench / Best fit.
-- Assignments go through AssignHeroRole; every reply is shown. No upgrade button: facilities are
-- levelled only in the Fortress Tree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local FacilityConfig = require(Shared:WaitForChild("Config"):WaitForChild("FacilityConfig"))
local HeroCatalog = require(Shared:WaitForChild("Config"):WaitForChild("HeroCatalog"))
local FirstBiomeCombat = require(Shared:WaitForChild("Config"):WaitForChild("FirstBiomeCombat"))
local TreeConfig = require(Shared:WaitForChild("Config"):WaitForChild("FortressTreeConfig"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local OutskirtsRules = require(Shared:WaitForChild("Util"):WaitForChild("OutskirtsRules"))
local FacilityWorkerRules = require(Shared:WaitForChild("Util"):WaitForChild("FacilityWorkerRules"))
local StatFormulas = require(Shared:WaitForChild("Util"):WaitForChild("StatFormulas"))
local InventoryCapacity = require(Shared:WaitForChild("Util"):WaitForChild("InventoryCapacity"))
local SummonLuck = require(Shared:WaitForChild("Util"):WaitForChild("SummonLuck"))
local Grimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local Assets = ReplicatedStorage:WaitForChild("Assets")
local EnemyRigFactory = require(Assets:WaitForChild("EnemyRigFactory")) -- remodelled templates, else the part rig
local TowerEnemyClips = require(Assets:WaitForChild("TowerEnemyClips"))
local EnemyAnimator = require(Assets:WaitForChild("EnemyAnimator"))
local HeroRigFolder = Assets:WaitForChild("HeroRig")
local HeroRegistry = require(HeroRigFolder:WaitForChild("HeroRegistry"))
local HeroAnimator = require(HeroRigFolder:WaitForChild("HeroAnimator"))
local HeroLoadout = require(HeroRigFolder:WaitForChild("HeroLoadout"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Portrait = require(script.Parent:WaitForChild("Portrait"))
local Components = require(script.Parent:WaitForChild("Components"))

local AssignHeroRole = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TycoonGachaRemotes"):WaitForChild("AssignHeroRole") :: RemoteFunction

local e = React.createElement
local Panel = Components.Panel
local Heavy = Components.HeavyLabel
local Body = Components.Body
local IconAt = Components.IconAt
local Tones = Grimoire.Tones
local TEXT = Grimoire.Text
local INK = Grimoire.Ink
local CLOSE_ACTION = "FacilityPanelClose"

local FACILITIES = {
	GuardPost = { Title = "OUTSKIRTS GUARD POST", Tag = "FACILITY_GUARD_POST", Worker = "Adventurer", Icon = "Camp", Tone = "Teal", Branch = "Outskirts",
		Blurb = "Adventurers patrol the outskirts and earn Gold, even while you're offline." },
	Market = { Title = "THE MARKET", Tag = "FACILITY_MARKET", Worker = "Merchant", Icon = "Market", Tone = "Bronze", Branch = "Commerce",
		Blurb = "Merchants raise the Gold you bring back from the tower." },
	TrainingGrounds = { Title = "TRAINING GROUNDS", Tag = "FACILITY_TRAINING", Worker = "Trainer", Icon = "Power", Tone = "Crimson", Branch = "Martial",
		Blurb = "Trainers drill your squad: more ATK and HP for every deployed hero." },
	GodsBlessing = { Title = "GOD'S BLESSING", Tag = "FACILITY_GODS_BLESSING", Worker = "Acolyte", Icon = "Blessing", Tone = "Violet", Branch = "Divine",
		Blurb = "Acolytes pray for luck: better odds on every hero summon." },
}

local ASSIGNMENT_LABELS: { [string]: string } = {
	BENCHED = "Bench",
	FACILITY_GUARD_POST = "Guard Post",
	FACILITY_MARKET = "Market",
	FACILITY_TRAINING = "Training",
	FACILITY_GODS_BLESSING = "Blessing",
}

type Filter = "All" | "Bench" | "Best"

local function assignmentLabel(assignment: string?): string
	local slot = string.match(assignment or "", "^SQUAD_SLOT_(%d+)$")
	if slot then return "Squad · Slot " .. slot end
	return ASSIGNMENT_LABELS[assignment or "BENCHED"] or "Bench"
end

local function hasSynergy(facility: string, hero: any): boolean
	local seed = HeroCatalog.Seeds[hero.TemplateId]
	local pref = seed and seed.PreferredFacility or ""
	local tag = FACILITIES[facility].Tag
	return pref == "ALL" or pref == tag or (tag == "FACILITY_GODS_BLESSING" and (hero.Archetype or (seed and seed.Archetype)) == "Healer")
end

local function restingSeconds(hero: any): number
	return math.max(0, (hero.ComaUntilTimestamp or 0) - os.time())
end

local function awakeLabor(profile: any, uuids: { string }, tag: string): number
	local sum = 0
	for _, uuid in uuids do
		local hero = profile.Heroes[uuid]
		if hero and restingSeconds(hero) == 0 then
			sum += StatFormulas.GetEffectiveLabor(hero, tag)
		end
	end
	return sum
end

-- The facility's big number for a given total worker labor, plus a formatter and breakdown rows
-- ({ caption, value }).
local function bonusFor(facility: string, profile: any, level: number, labor: number): (number, string, { { string } })
	local perks = FortressTree.PerkBonuses(profile.FortressTree)
	if facility == "GuardPost" then
		local tier = profile.HighestClearedBiomeBoss or 0
		local rate = StatFormulas.GetPassiveGoldRate(level, labor, tier, perks)
		local cfg = FacilityConfig.UpgradeTable.GuardPost[level]
		local cap = if cfg then (cfg.MaxOfflineMinutes + perks.OfflineMinutes) / 60 else 0
		return rate, string.format("%s Gold/min", Components.Abbreviate(rate)), {
			{ "Base rate" .. (if perks.GuardPostRate > 0 then " (Long Patrols)" else ""), string.format("%d Gold/min", math.round((cfg and cfg.BaseGoldPerMin or 0) * (1 + perks.GuardPostRate))) },
			{ "Adventurer labor", string.format("%.1f × 0.85", labor) },
			{ "Biome Boss bonus", string.format("+%d%% (tier %d)", tier * 15, tier) },
			{ "Offline earnings", string.format("%dh cap · %d%%", cap, math.round((cfg and cfg.OfflineEfficiency or 0) * 100)) },
		}
	elseif facility == "Market" then
		local mult = StatFormulas.GetMarketLootMultiplier(level, labor, perks)
		local cfg = FacilityConfig.UpgradeTable.Market[level]
		return mult, string.format("+%.1f%% tower loot", (mult - 1) * 100), {
			{ "Level bonus" .. (if perks.MarketBonus > 0 then " (Appraiser's Eye)" else ""), string.format("+%.0f%%", ((cfg and cfg.BaseBonus or 0) + perks.MarketBonus) * 100) },
			{ "Merchant labor", string.format("%.1f × 0.5%%", labor) },
		}
	elseif facility == "TrainingGrounds" then
		local mult = StatFormulas.GetTrainingCombatMultiplier(level, labor, perks)
		local cfg = FacilityConfig.UpgradeTable.TrainingGrounds[level]
		local before = StatFormulas.GetSquadPower(profile, 1)
		local after = StatFormulas.GetSquadPower(profile, mult)
		return mult, string.format("+%.1f%% ATK & HP", (mult - 1) * 100), {
			{ "Level bonus" .. (if perks.TrainingBonus > 0 then " (Veteran Drills)" else ""), string.format("+%.0f%%", ((cfg and cfg.BaseBonus or 0) + perks.TrainingBonus) * 100) },
			{ "Trainer labor", string.format("%.1f × 0.4%%", labor) },
			{ "Squad Power gained", "+" .. Components.Abbreviate(after - before) },
		}
	else
		local luck = SummonLuck.Luck(level, labor, perks.BlessingLuck)
		local cfg = FacilityConfig.UpgradeTable.GodsBlessing[level]
		local rates = HeroCatalog.LimitedBanner.Rates :: { number }
		local top = #rates
		return luck, string.format("+%.1f%% summon luck", luck * 100), {
			{ "Base luck", string.format("+%.0f%%", (cfg and cfg.BaseLuck or 0) * 100) },
			{ "Acolyte labor" .. (if perks.BlessingLuck > 0 then " (Saint's Favor +3%)" else ""), string.format("%.1f × 0.4%%", labor) },
			{ "Luck cap", string.format("+%d%%", math.round(FacilityConfig.Constants.MaxSummonLuck * 100)) },
			{ "Astrea (Mythical) odds", string.format("%.2f%% → %.3f%%", rates[top] * 100, SummonLuck.ApplyLuck(rates, luck)[top] * 100) },
		}
	end
end

local function nextNode(facility: string, tree: any): any
	for _, node in TreeConfig.Nodes do
		if node.Facility == facility and not FortressTree.Owns(tree, node.Id) then
			return node
		end
	end
	return nil
end

-- A themed button: toned panel, label as a child (a fill gradient would tint text on the button).
local function button(props: { [string]: any }, tone: string, text: string, textSize: number?)
	local t = Tones[tone] or Tones.Slate
	local inst: { [string]: any } = { Class = "TextButton", Text = "", AutoButtonColor = false, Radius = 10, Top = t.Top, Bottom = t.Bottom, Rail = t.Rail, Selectable = true }
	for k, v in props do inst[k] = v end
	return Panel(inst, {
		Label = Heavy({ Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 1, -4), MaxSize = textSize or 15, Outline = 2, Gold = false,
			Text = text, ZIndex = (props.ZIndex or 1) + 2 }),
	})
end

-- A small inked caption + value row for the bonus breakdown.
local function breakdownRow(order: number, caption: string, value: string)
	return e("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 }, {
		Caption = Body({ Size = UDim2.new(0.58, 0, 1, 0), TextSize = 14, TextColor3 = TEXT.Muted, Text = caption }),
		Value = Body({ Position = UDim2.fromScale(0.58, 0), Size = UDim2.new(0.42, 0, 1, 0), TextSize = 14, TextColor3 = TEXT.Parchment,
			TextXAlignment = Enum.TextXAlignment.Right, Text = value, FontFace = Grimoire.Fonts.Number }),
	})
end

-- Live looping ViewportFrame diorama for the Outskirts Guard Post showing stationed Adventurers
-- clashing with a biome raider from the player's highest unlocked Tower floor/biome.
local function OutskirtsPreviewStage(props: { Profile: any, AssignedUUIDs: { string }, DeploySerial: number })
	local vpRef = React.useRef(nil :: ViewportFrame?)
	local strokeRef = React.useRef(nil :: UIStroke?)
	local deployRef = React.useRef(props.DeploySerial)
	deployRef.current = props.DeploySerial

	local profile = props.Profile
	local frontier = OutskirtsRules.ResolveFrontierInfo(profile.HighestClearedFloor, profile.MaxFloorReached)

	local shownHeroes: { any } = {}
	for _, uuid in ipairs(props.AssignedUUIDs) do
		local h = profile.Heroes and profile.Heroes[uuid]
		if h then
			table.insert(shownHeroes, h)
			if #shownHeroes >= 2 then
				break
			end
		end
	end
	local heroKeyParts: { string } = {}
	for _, h in ipairs(shownHeroes) do
		table.insert(heroKeyParts, string.format("%s:%s", tostring(h.UUID), tostring(h.EquippedArtifactUUID or "")))
	end
	local heroSignature = table.concat(heroKeyParts, ",")

	React.useEffect(function()
		local vp = vpRef.current
		if not vp then
			return
		end
		for _, child in ipairs(vp:GetChildren()) do
			if not child:IsA("UICorner") and not child:IsA("UIStroke") then
				child:Destroy()
			end
		end

		local heroesFolder = Assets:FindFirstChild("Heroes")
		if not heroesFolder or #heroesFolder:GetChildren() == 0 then
			pcall(HeroRegistry.EnsureHeroes)
			heroesFolder = Assets:FindFirstChild("Heroes")
		end

		local world = Instance.new("Model")
		world.Name = "OutskirtsStageDiorama"

		-- Meadow & dirt trail plinth + Guard Post palisade stakes on the left
		local meadow = Instance.new("Part")
		meadow.Size = Vector3.new(20, 0.4, 7.5)
		meadow.CFrame = CFrame.new(0, -0.2, 0)
		meadow.Anchored = true
		meadow.CanCollide = false
		meadow.Color = Color3.fromRGB(68, 108, 52)
		meadow.Material = Enum.Material.Grass
		meadow.Parent = world

		local trail = Instance.new("Part")
		trail.Size = Vector3.new(17.5, 0.14, 3.6)
		trail.CFrame = CFrame.new(0, 0.04, 0)
		trail.Anchored = true
		trail.CanCollide = false
		trail.Color = Color3.fromRGB(112, 88, 64)
		trail.Material = Enum.Material.Ground
		trail.Parent = world

		for s = 1, 3 do
			local stake = Instance.new("Part")
			stake.Shape = Enum.PartType.Cylinder
			stake.Size = Vector3.new(3.8 + (s % 2) * 0.5, 0.65, 0.65)
			stake.CFrame = CFrame.new(-7.4 + (s - 1) * 0.9, 1.8, -1.6 + (s - 1) * 0.8) * CFrame.Angles(0, 0, math.pi * 0.5)
			stake.Anchored = true
			stake.CanCollide = false
			stake.Color = Color3.fromRGB(94, 62, 36)
			stake.Material = Enum.Material.Wood
			stake.Parent = world
		end

		local spark = Instance.new("Part")
		spark.Name = "ClashSpark"
		spark.Shape = Enum.PartType.Ball
		spark.Size = Vector3.new(0.9, 0.9, 0.9)
		spark.CFrame = CFrame.new(0.2, 2.6, 0)
		spark.Anchored = true
		spark.CanCollide = false
		spark.Color = Color3.fromRGB(255, 218, 98)
		spark.Material = Enum.Material.Neon
		spark.Transparency = 1
		spark.Parent = world

		-- Stationed Adventurer R15 clones
		local heroActors: { { Rig: Model, Animator: HeroAnimator.HeroAnimator, BaseCF: CFrame, NextSwingAt: number } } = {}
		local slotPositions = {
			CFrame.new(-3.2, 3.0, 0.35) * CFrame.Angles(0, -math.pi * 0.5, 0),
			CFrame.new(-5.4, 3.0, -1.15) * CFrame.Angles(0, -math.pi * 0.46, 0),
		}
		for idx, h in ipairs(shownHeroes) do
			local template = heroesFolder and heroesFolder:FindFirstChild(tostring(h.TemplateId or "hero_han"))
			if not template and heroesFolder then
				template = heroesFolder:FindFirstChild("hero_han")
			end
			if template and template:IsA("Model") then
				local rig = template:Clone()
				local seed = HeroCatalog.Seeds[h.TemplateId]
				local archetype = h.Archetype or (seed and seed.Archetype) or "Vanguard"
				local artUUID = h.EquippedArtifactUUID
				local art = if artUUID and profile.Artifacts then profile.Artifacts[artUUID] else nil
				local weaponType = if art and type(art.Type) == "string"
					then art.Type
					else OutskirtsRules.DefaultWeaponForArchetype(archetype)
				local artId = if art and type(art.TemplateId) == "string" then art.TemplateId else nil
				local artRarity = if art and type(art.Rarity) == "number" then art.Rarity else 1

				local hostEntity = Instance.new("Model")
				hostEntity.Name = "StageHero_" .. idx
				rig.Parent = hostEntity
				local resolved = HeroLoadout.Equip(hostEntity, rig, artId, weaponType, artRarity)

				for _, desc in ipairs(hostEntity:GetDescendants()) do
					if desc:IsA("BaseScript") then
						desc:Destroy()
					elseif desc:IsA("BasePart") then
						desc.Anchored = true
						desc.CanCollide = false
					end
				end

				local baseCF = slotPositions[idx] or slotPositions[1]
				local hrp = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					hrp.CFrame = baseCF
				else
					rig:PivotTo(baseCF)
				end

				local animator = HeroAnimator.new(rig, {
					HeroId = h.TemplateId,
					WeaponType = resolved or weaponType,
				})
				animator:SetLocomotion("Move")
				HeroAnimator.ApplyStaticPose(rig, animator:Evaluate())
				hostEntity.Parent = world

				table.insert(heroActors, {
					Rig = rig,
					Animator = animator,
					BaseCF = baseCF,
					NextSwingAt = 0.65 + (idx - 1) * 0.9,
				})
			end
		end

		-- Frontier Biome Preview Enemy Rig
		local enemyId = frontier.PreviewEnemyId
		local combatSpec = FirstBiomeCombat.Get(enemyId)

		local mobModel = Instance.new("Model")
		mobModel.Name = "StageFrontierMob"
		local mobRoot = Instance.new("Part")
		mobRoot.Name = "HumanoidRootPart"
		mobRoot.Size = Vector3.new(1, 1, 1)
		mobRoot.Transparency = 1
		mobRoot.Anchored = true
		mobRoot.CanCollide = false
		mobRoot.CFrame = CFrame.new(0, 8, 0)
		mobRoot.Parent = mobModel
		mobModel.PrimaryPart = mobRoot

		local enemyRig = EnemyRigFactory.Build(mobModel, mobRoot, enemyId)
		local _, rawExtents = mobModel:GetBoundingBox()
		local rigScale = if rawExtents.Y > 5.8 then (5.8 / rawExtents.Y) else 1.0
		if rigScale ~= 1.0 then
			mobModel:ScaleTo(rigScale)
			for _, joint in pairs(enemyRig.Joints) do
				joint.Bind = joint.Motor.C0
			end
		end
		local scaledCF, scaledExtents = mobModel:GetBoundingBox()
		local rawFootOffset = mobRoot.Position.Y - (scaledCF.Position.Y - scaledExtents.Y * 0.5)
		local fallbackRootH = ((combatSpec and combatSpec.RootHeight) or 3.2) * rigScale
		local footOffset = if rawExtents.Y > 0.2 then math.clamp(rawFootOffset, 0.5, 6.2) else fallbackRootH
		local mobBaseCF = CFrame.new(3.5, 0.12 + footOffset, 0.15) * CFrame.Angles(0, math.pi * 0.5, 0)
		mobModel:PivotTo(mobBaseCF)

		type StaticLink = { Kind: string, Motor: Motor6D?, Part0: BasePart, Part1: BasePart, Rel: CFrame? }
		local mobLinks: { StaticLink } = {}
		for _, part in ipairs(enemyRig.Parts) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
				local weld = part:FindFirstChildWhichIsA("WeldConstraint")
				if weld and weld.Part0 and weld.Part1 == part then
					table.insert(mobLinks, {
						Kind = "Weld",
						Motor = nil,
						Part0 = weld.Part0,
						Part1 = part,
						Rel = weld.Part0.CFrame:ToObjectSpace(part.CFrame),
					})
				else
					for _, joint in pairs(enemyRig.Joints) do
						if joint.Motor.Part1 == part and joint.Motor.Part0 then
							table.insert(mobLinks, {
								Kind = "Motor",
								Motor = joint.Motor,
								Part0 = joint.Motor.Part0,
								Part1 = part,
								Rel = nil,
							})
							break
						end
					end
				end
			end
		end
		-- Walks in place at one stride cycle per ~1.2 s, attacking every 2.8 s (EnemyAnimator).
		local mobAnimator = EnemyAnimator.new(enemyRig, enemyId)
		local mobAction = { AnimationKey = "BasicAttack", StartServerTime = 0, WindupSeconds = 0.64, ImpactOffsetSeconds = 0.64, RecoverySeconds = 0.16 }
		local mobInput: any = { Treadmill = 0.85 * EnemyAnimator.Stride(enemyRig), Action = nil, HitAt = nil }
		mobModel.Parent = world
		world.Parent = vp

		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 4.1, 15.8), Vector3.new(0.1, 2.5, 0))
		cam.Parent = vp
		vp.CurrentCamera = cam

		local clock = 0
		local lastDeploySeen = deployRef.current
		local flashTimer = 0
		local mobHitTimer = 0
		local swingCounter = 0

		local conn = RunService.RenderStepped:Connect(function(dt: number)
			local stepDt = math.min(dt, 0.08)
			clock += stepDt

			if deployRef.current ~= lastDeploySeen then
				lastDeploySeen = deployRef.current
				flashTimer = 0.55
				for _, actor in ipairs(heroActors) do
					actor.Animator:PlayAction("AttackSpecial", 0.78)
					actor.NextSwingAt = clock + 1.5
				end
				mobHitTimer = 0.32
			end

			if strokeRef.current then
				if flashTimer > 0 then
					flashTimer = math.max(0, flashTimer - stepDt)
					strokeRef.current.Color = TEXT.Gold
					strokeRef.current.Thickness = 2.6
				else
					strokeRef.current.Color = Tones.Teal.Rail
					strokeRef.current.Thickness = 1.4
				end
			end

			for idx, actor in ipairs(heroActors) do
				if clock >= actor.NextSwingAt then
					swingCounter += 1
					local state = if swingCounter % 3 == 0 then "AttackSpecial" else "AttackBasic"
					actor.Animator:PlayAction(state, 0.76)
					actor.NextSwingAt = clock + 1.95 + (idx - 1) * 0.35
					mobHitTimer = 0.42
				end
				actor.Animator.Clock += stepDt
				actor.Animator.LocomotionTime += stepDt * 1.05
				if actor.Animator.Action and (actor.Animator.Clock - actor.Animator.Action.Started) >= actor.Animator.Action.Duration then
					actor.Animator.Action = nil
				end
				local lunge = if actor.Animator.Action then math.sin(math.clamp((actor.Animator.Clock - actor.Animator.Action.Started) / actor.Animator.Action.Duration, 0, 1) * math.pi) * 0.55 else 0
				local hrp = actor.Rig:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					hrp.CFrame = actor.BaseCF * CFrame.new(0, 0, -lunge)
				end
				HeroAnimator.ApplyStaticPose(actor.Rig, actor.Animator:Evaluate())
			end

			local clips = TowerEnemyClips[enemyId]
			if clips then
				if #heroActors > 0 and mobHitTimer > 0 then
					mobHitTimer = math.max(0, mobHitTimer - stepDt)
					if mobHitTimer < 0.24 and (mobInput.HitAt == nil or clock - mobInput.HitAt > 0.3) then
						mobInput.HitAt = clock
					end
					spark.Transparency = 0.2 + 0.8 * (1 - math.min(1, mobHitTimer * 3))
					spark.Size = Vector3.one * (0.6 + (1 - mobHitTimer) * 1.8)
				else
					spark.Transparency = 1
				end
				-- a basic attack in the last 0.8 s of every 2.8 s, while no hero is landing a hit
				local cycle = clock % 2.8
				if cycle > 2.0 and mobHitTimer <= 0 and clips.BasicAttack then
					mobAction.StartServerTime = clock - (cycle - 2.0)
					mobInput.Action = mobAction
				elseif cycle <= 2.0 then
					mobInput.Action = nil
				end
				local sway = math.sin(clock * 2.2) * 0.28
				mobRoot.CFrame = mobBaseCF * CFrame.new(0, 0, -sway)
				mobAnimator:Step(clock, mobInput)
				for _, link in ipairs(mobLinks) do
					if link.Kind == "Motor" and link.Motor then
						link.Part1.CFrame = link.Part0.CFrame * link.Motor.C0 * link.Motor.Transform * link.Motor.C1:Inverse()
					elseif link.Rel then
						link.Part1.CFrame = link.Part0.CFrame * link.Rel
					end
				end
			end
		end)

		return function()
			conn:Disconnect()
			world:Destroy()
			cam:Destroy()
		end
	end, { heroSignature, frontier.PreviewEnemyId } :: { any })

	return Panel({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 124), Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Teal.Rail }, {
		Caption = Heavy({ Position = UDim2.fromOffset(18, 8), Size = UDim2.new(0.45, 0, 0, 18), MaxSize = 14, Outline = 2,
			TextXAlignment = Enum.TextXAlignment.Left, Text = "LIVE PATROL", ZIndex = 4 }),
		Biome = Body({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 9), Size = UDim2.new(0.55, -18, 0, 16),
			TextSize = 12, TextColor3 = TEXT.Gold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4,
			Text = string.format("FLOOR %d · %s", frontier.FloorId, string.upper(frontier.BiomeDisplayName)) }),
		Stage = e("ViewportFrame", {
			ref = vpRef,
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -24, 1, -38),
			BackgroundColor3 = Color3.fromRGB(14, 20, 18),
			BackgroundTransparency = 0.12,
			Ambient = Color3.fromRGB(168, 178, 162),
			LightColor = Color3.fromRGB(255, 238, 206),
			LightDirection = Vector3.new(-1, -1.2, -1.6),
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Border = e("UIStroke", { ref = strokeRef, Color = Tones.Teal.Rail, Thickness = 1.4 }),
		}),
		EmptyHint = if #shownHeroes == 0 then Body({
			Position = UDim2.fromOffset(22, 58), Size = UDim2.new(0.52, 0, 0, 34), TextSize = 12, TextWrapped = true,
			TextColor3 = TEXT.Parchment, Text = "Station an Adventurer to defend the Outskirts", ZIndex = 5,
		}) else nil,
	})
end

-- Live looping ViewportFrame diorama for The Market (`LIVE BAZAAR`) and Training Grounds (`LIVE DRILLS`),
-- rendering up to 4 stationed workers simultaneously performing their distinct per-slot animations.
local function FacilityWorkersPreviewStage(props: {
	Facility: string,
	Profile: any,
	AssignedUUIDs: { string },
	MaxWorkers: number,
	DeploySerial: number,
})
	local vpRef = React.useRef(nil :: ViewportFrame?)
	local strokeRef = React.useRef(nil :: UIStroke?)
	local deployRef = React.useRef(props.DeploySerial)
	deployRef.current = props.DeploySerial

	local isMarket = props.Facility == "Market"
	local railTone = if isMarket then Tones.Bronze.Rail else Tones.Crimson.Rail
	local profile = props.Profile

	local shownEntries: { { Slot: number, Hero: any } } = {}
	for slotIdx, uuid in ipairs(props.AssignedUUIDs) do
		local h = profile.Heroes and profile.Heroes[uuid]
		if h then
			table.insert(shownEntries, { Slot = math.clamp(slotIdx, 1, 4), Hero = h })
			if #shownEntries >= 4 then
				break
			end
		end
	end

	local sigParts: { string } = { props.Facility }
	for _, entry in ipairs(shownEntries) do
		local h = entry.Hero
		table.insert(sigParts, string.format("%d:%s:%s", entry.Slot, tostring(h.UUID), tostring(h.EquippedArtifactUUID or "")))
	end
	local signature = table.concat(sigParts, "|")

	React.useEffect(function()
		local vp = vpRef.current
		if not vp then
			return
		end
		for _, child in ipairs(vp:GetChildren()) do
			if not child:IsA("UICorner") and not child:IsA("UIStroke") then
				child:Destroy()
			end
		end

		local heroesFolder = Assets:FindFirstChild("Heroes")
		if not heroesFolder or #heroesFolder:GetChildren() == 0 then
			pcall(HeroRegistry.EnsureHeroes)
			heroesFolder = Assets:FindFirstChild("Heroes")
		end

		local world = Instance.new("Model")
		world.Name = props.Facility .. "StageDiorama"

		local function addAnchoredPart(
			name: string,
			size: Vector3,
			cf: CFrame,
			color: Color3,
			material: Enum.Material,
			shape: Enum.PartType?
		): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Shape = shape or Enum.PartType.Block
			p.Size = size
			p.CFrame = cf
			p.Anchored = true
			p.CanCollide = false
			p.Color = color
			p.Material = material
			p.Parent = world
			return p
		end

		local dummyPivot = CFrame.new(5.1, 0.1, 0.25)
		local dummyMovingParts: { { Part: BasePart, Offset: CFrame } } = {}

		if isMarket then
			-- Cobblestone Bazaar Apron + Striped Stall Counter + Goods Trays
			addAnchoredPart("CobbleFloor", Vector3.new(21, 0.4, 8.5), CFrame.new(0, -0.2, 0), Color3.fromRGB(78, 82, 90), Enum.Material.Cobblestone)
			addAnchoredPart("CounterBody", Vector3.new(15.2, 2.0, 1.5), CFrame.new(0, 1.0, 2.1), Color3.fromRGB(96, 64, 38), Enum.Material.WoodPlanks)
			addAnchoredPart("CounterTop", Vector3.new(15.8, 0.28, 1.85), CFrame.new(0, 2.12, 2.1), Color3.fromRGB(132, 92, 56), Enum.Material.Wood)
			local goodColors = {
				Color3.fromRGB(220, 65, 55),
				Color3.fromRGB(245, 195, 55),
				Color3.fromRGB(95, 205, 225),
				Color3.fromRGB(75, 185, 95),
			}
			for g = 1, 4 do
				local gx = -5.1 + (g - 1) * 3.4
				addAnchoredPart("Tray_" .. g, Vector3.new(1.7, 0.36, 1.1), CFrame.new(gx, 2.4, 2.1), Color3.fromRGB(96, 64, 38), Enum.Material.WoodPlanks)
				addAnchoredPart("Good_" .. g, Vector3.new(0.62, 0.62, 0.62), CFrame.new(gx - 0.25, 2.72, 2.1), goodColors[g], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
				addAnchoredPart("GoodB_" .. g, Vector3.new(0.56, 0.56, 0.56), CFrame.new(gx + 0.28, 2.68, 2.18), goodColors[g], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
			addAnchoredPart("SupplyCrate", Vector3.new(2.1, 1.7, 2.0), CFrame.new(-7.4, 0.85, -1.5) * CFrame.Angles(0, math.rad(22), 0), Color3.fromRGB(132, 92, 56), Enum.Material.WoodPlanks)
		else
			-- Bordered Cobblestone Combat Ring + Wobbling Straw Dummy + Bullseye Target
			addAnchoredPart("ArenaFloor", Vector3.new(23, 0.4, 14), CFrame.new(0, -0.2, 0), Color3.fromRGB(84, 82, 78), Enum.Material.Cobblestone)
			addAnchoredPart("InnerRing", Vector3.new(0.18, 12.6, 12.6), CFrame.new(-0.4, 0.04, 0) * CFrame.Angles(0, 0, math.pi * 0.5), Color3.fromRGB(102, 96, 88), Enum.Material.Cobblestone, Enum.PartType.Cylinder)

			addAnchoredPart("DummyBase", Vector3.new(0.32, 1.9, 1.9), dummyPivot * CFrame.new(0, 0.16, 0) * CFrame.Angles(0, 0, math.pi * 0.5), Color3.fromRGB(88, 58, 34), Enum.Material.Wood, Enum.PartType.Cylinder)
			local post = addAnchoredPart("DummyPost", Vector3.new(4.8, 0.55, 0.55), dummyPivot * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.pi * 0.5), Color3.fromRGB(88, 58, 34), Enum.Material.Wood, Enum.PartType.Cylinder)
			local bar = addAnchoredPart("DummyArms", Vector3.new(0.38, 0.38, 3.0), dummyPivot * CFrame.new(0, 3.55, 0), Color3.fromRGB(88, 58, 34), Enum.Material.Wood)
			local torso = addAnchoredPart("DummyTorso", Vector3.new(2.1, 1.55, 1.55), dummyPivot * CFrame.new(0, 3.0, 0) * CFrame.Angles(0, 0, math.pi * 0.5), Color3.fromRGB(214, 182, 102), Enum.Material.Fabric, Enum.PartType.Cylinder)
			local band = addAnchoredPart("DummyBand", Vector3.new(0.38, 1.62, 1.62), dummyPivot * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.pi * 0.5), Color3.fromRGB(190, 42, 42), Enum.Material.Fabric, Enum.PartType.Cylinder)
			local head = addAnchoredPart("DummyHead", Vector3.new(1.18, 1.18, 1.18), dummyPivot * CFrame.new(0, 4.55, 0), Color3.fromRGB(214, 182, 102), Enum.Material.Fabric, Enum.PartType.Ball)
			for _, dp in ipairs({ post, bar, torso, band, head }) do
				table.insert(dummyMovingParts, { Part = dp, Offset = dummyPivot:ToObjectSpace(dp.CFrame) })
			end

			local bullCF = CFrame.new(6.8, 3.0, -1.85) * CFrame.Angles(0, math.rad(25), 0)
			addAnchoredPart("BullOuter", Vector3.new(0.32, 2.7, 2.7), bullCF * CFrame.Angles(0, math.pi * 0.5, 0), Color3.fromRGB(205, 40, 40), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			addAnchoredPart("BullMid", Vector3.new(0.36, 1.75, 1.75), bullCF * CFrame.Angles(0, math.pi * 0.5, 0), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			addAnchoredPart("BullCenter", Vector3.new(0.40, 0.85, 0.85), bullCF * CFrame.Angles(0, math.pi * 0.5, 0), Color3.fromRGB(215, 35, 35), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end

		local spark = addAnchoredPart(
			"StageSpark",
			Vector3.new(0.85, 0.85, 0.85),
			if isMarket then CFrame.new(0, 3.1, 2.1) else CFrame.new(4.5, 3.2, 0.25),
			if isMarket then Color3.fromRGB(255, 214, 92) else Color3.fromRGB(255, 196, 98),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		spark.Transparency = 1

		local marketPoses = {
			CFrame.new(-5.2, 3.0, 0.05) * CFrame.Angles(0, math.pi - 0.18, 0),
			CFrame.new(-1.8, 3.0, -0.15) * CFrame.Angles(0, math.pi - 0.06, 0),
			CFrame.new(1.8, 3.0, -0.15) * CFrame.Angles(0, math.pi + 0.06, 0),
			CFrame.new(5.2, 3.0, 0.05) * CFrame.Angles(0, math.pi + 0.18, 0),
		}
		local trainingPoses = {
			CFrame.new(1.4, 3.0, 0.35) * CFrame.Angles(0, -math.pi * 0.5, 0),
			CFrame.new(-1.5, 3.0, -0.85) * CFrame.Angles(0, -math.pi * 0.44, 0),
			CFrame.new(-4.3, 3.0, 0.45) * CFrame.Angles(0, math.pi * 0.76, 0),
			CFrame.new(-6.7, 3.0, -0.45) * CFrame.Angles(0, math.pi * 0.68, 0),
		}

		type StageActor = {
			Slot: number,
			Rig: Model,
			Animator: HeroAnimator.HeroAnimator,
			BaseCF: CFrame,
			NextActionAt: number,
		}
		local stageActors: { StageActor } = {}

		local function weldStageProp(rig: Model, slotNum: number)
			if not isMarket then
				return
			end
			if slotNum == 2 then
				local ut = rig:FindFirstChild("UpperTorso") :: BasePart?
				if ut then
					local crate = Instance.new("Part")
					crate.Size = Vector3.new(1.45, 0.85, 1.1)
					crate.Color = Color3.fromRGB(138, 96, 56)
					crate.Material = Enum.Material.WoodPlanks
					crate.Anchored = true
					crate.CanCollide = false
					crate.Parent = rig
					local w = Instance.new("Weld")
					w.Part0 = ut
					w.Part1 = crate
					w.C0 = CFrame.new(0, -0.15, -1.15)
					w.Parent = crate
				end
			elseif slotNum == 3 then
				local lh = rig:FindFirstChild("LeftHand") :: BasePart?
				if lh then
					local orb = Instance.new("Part")
					orb.Shape = Enum.PartType.Ball
					orb.Size = Vector3.new(0.62, 0.62, 0.62)
					orb.Color = Color3.fromRGB(115, 232, 255)
					orb.Material = Enum.Material.Neon
					orb.Anchored = true
					orb.CanCollide = false
					orb.Parent = rig
					local grip = lh:FindFirstChild("LeftGripAttachment") :: Attachment?
					local w = Instance.new("Weld")
					w.Part0 = lh
					w.Part1 = orb
					w.C0 = if grip then grip.CFrame * CFrame.new(0, 0.32, 0) else CFrame.new(0, -0.1, -0.25)
					w.Parent = orb
				end
			elseif slotNum == 4 then
				local lh = rig:FindFirstChild("LeftHand") :: BasePart?
				if lh then
					local book = Instance.new("Part")
					book.Size = Vector3.new(1.05, 0.14, 0.82)
					book.Color = Color3.fromRGB(238, 226, 198)
					book.Material = Enum.Material.SmoothPlastic
					book.Anchored = true
					book.CanCollide = false
					book.Parent = rig
					local grip = lh:FindFirstChild("LeftGripAttachment") :: Attachment?
					local w = Instance.new("Weld")
					w.Part0 = lh
					w.Part1 = book
					w.C0 = if grip
						then grip.CFrame * CFrame.new(0, 0.24, 0.06) * CFrame.Angles(math.rad(-75), 0, 0)
						else CFrame.new(0, 0.12, -0.3)
					w.Parent = book
				end
			end
		end

		for _, entry in ipairs(shownEntries) do
			local h = entry.Hero
			local slotNum = entry.Slot
			local slotSpec = FacilityWorkerRules.GetSlotSpec(props.Facility, slotNum)
			local template = heroesFolder and heroesFolder:FindFirstChild(tostring(h.TemplateId or "hero_han"))
			if not template and heroesFolder then
				template = heroesFolder:FindFirstChild("hero_han")
			end
			if template and template:IsA("Model") and slotSpec then
				local rig = template:Clone()
				local seed = HeroCatalog.Seeds[h.TemplateId]
				local archetype = h.Archetype or (seed and seed.Archetype) or "Vanguard"
				local artUUID = h.EquippedArtifactUUID
				local art = if artUUID and profile.Artifacts then profile.Artifacts[artUUID] else nil
				local weaponType = if art and type(art.Type) == "string"
					then art.Type
					else FacilityWorkerRules.ResolveHeroWeaponType(archetype, nil)
				local artId = if art and type(art.TemplateId) == "string" then art.TemplateId else nil
				local artRarity = if art and type(art.Rarity) == "number" then art.Rarity else 1

				local hostEntity = Instance.new("Model")
				hostEntity.Name = "StageWorker_" .. slotNum
				rig.Parent = hostEntity

				local animWeapon = "UNARMED"
				if slotSpec.EquipHeroWeapon then
					local resolved = HeroLoadout.Equip(hostEntity, rig, artId, weaponType, artRarity)
					animWeapon = resolved or weaponType
				else
					HeroLoadout.Unequip(hostEntity, rig)
					weldStageProp(rig, slotNum)
				end

				for _, desc in ipairs(hostEntity:GetDescendants()) do
					if desc:IsA("BaseScript") then
						desc:Destroy()
					elseif desc:IsA("BasePart") then
						desc.Anchored = true
						desc.CanCollide = false
					end
				end

				local poseList = if isMarket then marketPoses else trainingPoses
				local baseCF = poseList[slotNum] or poseList[1]
				local hrp = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					hrp.CFrame = baseCF
				else
					rig:PivotTo(baseCF)
				end

				local animator = HeroAnimator.new(rig, {
					HeroId = h.TemplateId,
					WeaponType = animWeapon,
				})
				local initLoco = if isMarket
					then slotSpec.PrimaryClip
					elseif slotNum == 3 then "TrainingKata"
					elseif slotNum == 4 then "TrainingCoach"
					else "Idle"
				animator:SetLocomotion(initLoco)
				HeroAnimator.ApplyStaticPose(rig, animator:Evaluate())
				hostEntity.Parent = world

				table.insert(stageActors, {
					Slot = slotNum,
					Rig = rig,
					Animator = animator,
					BaseCF = baseCF,
					NextActionAt = 0.55 + (slotNum - 1) * 0.65,
				})
			end
		end

		world.Parent = vp

		local cam = Instance.new("Camera")
		cam.FieldOfView = 30
		cam.CFrame = if isMarket
			then CFrame.lookAt(Vector3.new(0, 4.7, 17.6), Vector3.new(0, 2.75, 0.3))
			else CFrame.lookAt(Vector3.new(0.1, 4.7, 18.2), Vector3.new(0.2, 2.85, 0))
		cam.Parent = vp
		vp.CurrentCamera = cam

		local clock = 0
		local lastDeploySeen = deployRef.current
		local flashTimer = 0
		local sparkTimer = 0
		local dummyHitClock = -10
		local actionCounter = 0

		local conn = RunService.RenderStepped:Connect(function(dt: number)
			local stepDt = math.min(dt, 0.08)
			clock += stepDt

			if deployRef.current ~= lastDeploySeen then
				lastDeploySeen = deployRef.current
				flashTimer = 0.55
				sparkTimer = 0.42
				if not isMarket then
					dummyHitClock = clock
					for _, actor in ipairs(stageActors) do
						actor.Animator:PlayAction("AttackSpecial", 0.78)
						actor.NextActionAt = clock + 1.4
					end
				end
			end

			if strokeRef.current then
				if flashTimer > 0 then
					flashTimer = math.max(0, flashTimer - stepDt)
					strokeRef.current.Color = TEXT.Gold
					strokeRef.current.Thickness = 2.6
				else
					strokeRef.current.Color = railTone
					strokeRef.current.Thickness = 1.4
				end
			end

			for _, actor in ipairs(stageActors) do
				local hrp = actor.Rig:FindFirstChild("HumanoidRootPart") :: BasePart?
				if isMarket then
					if actor.Slot == 1 then
						actor.Animator:SetLocomotion("MarketHawker")
						if hrp then
							hrp.CFrame = actor.BaseCF * CFrame.new(math.sin(clock * 1.4) * 0.45, 0, 0)
						end
					elseif actor.Slot == 2 then
						local haulPhase = (clock % 5.2) > 3.2
						actor.Animator:SetLocomotion(if haulPhase then "MarketCarry" else "MarketStock")
						if hrp then
							local zShift = if haulPhase then -math.sin(((clock % 5.2) - 3.2) / 2.0 * math.pi) * 0.75 else 0
							hrp.CFrame = actor.BaseCF * CFrame.new(0, 0, zShift)
						end
					elseif actor.Slot == 3 then
						actor.Animator:SetLocomotion("MarketAppraiser")
					else
						actor.Animator:SetLocomotion("MarketLedger")
					end
					if clock >= actor.NextActionAt then
						actor.NextActionAt = clock + 2.8
						sparkTimer = 0.30
						spark.CFrame = actor.BaseCF * CFrame.new(0, 0.3, -1.8)
					end
				else
					if actor.Slot == 1 then
						actor.Animator:SetLocomotion("Idle")
						if clock >= actor.NextActionAt then
							actionCounter += 1
							local act = if actionCounter % 3 == 0 then "AttackSkill" elseif actionCounter % 2 == 0 then "AttackSpecial" else "AttackBasic"
							actor.Animator:PlayAction(act, 0.80)
							actor.NextActionAt = clock + 1.55
							dummyHitClock = clock + 0.26
							sparkTimer = 0.36
						end
					elseif actor.Slot == 2 then
						local kataWindow = (clock % 5.6) > 3.4
						actor.Animator:SetLocomotion(if kataWindow then "TrainingKata" else "Idle")
						if not kataWindow and clock >= actor.NextActionAt then
							actor.Animator:PlayAction("AttackSpecial", 0.82)
							actor.NextActionAt = clock + 1.75
						end
					elseif actor.Slot == 3 then
						actor.Animator:SetLocomotion("TrainingKata")
						if clock >= actor.NextActionAt then
							actor.Animator:PlayAction("AttackBasic", 0.75)
							actor.NextActionAt = clock + 3.6
						end
					else
						actor.Animator:SetLocomotion("TrainingCoach")
						if hrp then
							hrp.CFrame = actor.BaseCF * CFrame.new(math.sin(clock * 1.1) * 0.4, 0, 0)
						end
					end

					if actor.Slot == 1 and hrp then
						local lunge = if actor.Animator.Action
							then math.sin(math.clamp((actor.Animator.Clock - actor.Animator.Action.Started) / actor.Animator.Action.Duration, 0, 1) * math.pi) * 0.55
							else 0
						hrp.CFrame = actor.BaseCF * CFrame.new(0, 0, -lunge)
					end
				end

				actor.Animator.Clock += stepDt
				actor.Animator.LocomotionTime += stepDt * (if flashTimer > 0 then 1.35 else 1.0)
				if actor.Animator.Action and (actor.Animator.Clock - actor.Animator.Action.Started) >= actor.Animator.Action.Duration then
					actor.Animator.Action = nil
				end
				HeroAnimator.ApplyStaticPose(actor.Rig, actor.Animator:Evaluate())
			end

			if not isMarket and #dummyMovingParts > 0 then
				local hitElapsed = clock - dummyHitClock
				if hitElapsed >= 0 and hitElapsed < 0.68 then
					local tilt = math.rad(13) * math.exp(-6.0 * hitElapsed) * math.sin(24 * hitElapsed)
					local rotPivot = CFrame.new(dummyPivot.Position) * CFrame.Angles(0, 0, -tilt) * dummyPivot.Rotation
					for _, item in ipairs(dummyMovingParts) do
						item.Part.CFrame = rotPivot * item.Offset
					end
				else
					for _, item in ipairs(dummyMovingParts) do
						item.Part.CFrame = dummyPivot * item.Offset
					end
				end
			end

			if sparkTimer > 0 then
				sparkTimer = math.max(0, sparkTimer - stepDt)
				spark.Transparency = 0.25 + 0.75 * (1 - math.min(1, sparkTimer * 3))
				spark.Size = Vector3.one * (0.55 + (1 - sparkTimer) * 1.5)
			else
				spark.Transparency = 1
			end
		end)

		return function()
			conn:Disconnect()
			world:Destroy()
			cam:Destroy()
		end
	end, { signature } :: { any })

	local activeRoleBadge: string
	if #shownEntries == 0 then
		activeRoleBadge = if isMarket then "NO MERCHANTS STATIONED" else "NO TRAINERS STATIONED"
	else
		local roleNames: { string } = {}
		for _, entry in ipairs(shownEntries) do
			local spec = FacilityWorkerRules.GetSlotSpec(props.Facility, entry.Slot)
			if spec then
				table.insert(roleNames, string.upper(spec.RoleTitle))
			end
		end
		activeRoleBadge = table.concat(roleNames, " · ")
	end

	return Panel({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 124), Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = railTone }, {
		Caption = Heavy({ Position = UDim2.fromOffset(18, 8), Size = UDim2.new(0.38, 0, 0, 18), MaxSize = 14, Outline = 2,
			TextXAlignment = Enum.TextXAlignment.Left, Text = if isMarket then "LIVE BAZAAR" else "LIVE DRILLS", ZIndex = 4 }),
		Roles = Body({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 9), Size = UDim2.new(0.62, -18, 0, 16),
			TextSize = 11, TextColor3 = TEXT.Gold, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4,
			Text = activeRoleBadge }),
		Stage = e("ViewportFrame", {
			ref = vpRef,
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -24, 1, -38),
			BackgroundColor3 = if isMarket then Color3.fromRGB(22, 17, 13) else Color3.fromRGB(22, 14, 15),
			BackgroundTransparency = 0.12,
			Ambient = Color3.fromRGB(174, 168, 158),
			LightColor = Color3.fromRGB(255, 236, 202),
			LightDirection = Vector3.new(-0.8, -1.2, -1.6),
			ZIndex = 3,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
			Border = e("UIStroke", { ref = strokeRef, Color = railTone, Thickness = 1.4 }),
		}),
		EmptyHint = if #shownEntries == 0 then Body({
			Position = UDim2.fromOffset(22, 58), Size = UDim2.new(0.58, 0, 0, 34), TextSize = 12, TextWrapped = true,
			TextColor3 = TEXT.Parchment,
			Text = if isMarket
				then "Station Merchants to open Bazaar stalls & boost Tower Gold"
				else "Station Trainers to run combat drills & boost Squad ATK/HP",
			ZIndex = 5,
		}) else nil,
	})
end

local function FacilityPanel(props: { Facility: string, Profile: any, Width: number, OnClose: () -> () })
	local info = FACILITIES[props.Facility]
	local hovered, setHovered = React.useState(nil :: string?)
	local confirming, setConfirming = React.useState(nil :: string?)
	local message, setMessage = React.useState("")
	local isError, setIsError = React.useState(false)
	local busy, setBusy = React.useState(false)
	local filter, setFilter = React.useState("All" :: Filter)
	local deploySerial, setDeploySerial = React.useState(0)

	React.useEffect(function()
		ContextActionService:BindAction(CLOSE_ACTION, function(_, state)
			if state == Enum.UserInputState.Begin then props.OnClose() end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.ButtonB)
		return function() ContextActionService:UnbindAction(CLOSE_ACTION) end
	end, {})

	local profile = props.Profile
	if not info or not profile then return nil end
	local data = profile.Facilities and profile.Facilities[props.Facility] or { Level = 0, AssignedHeroUUIDs = {} }
	local level = data.Level or 0
	local perks = FortressTree.PerkBonuses(profile.FortressTree)
	local maxWorkers = StatFormulas.GetFacilityMaxWorkers(props.Facility, level, perks)
	local assigned = data.AssignedHeroUUIDs or {}
	local labor = awakeLabor(profile, assigned, info.Tag)
	local value, figure, breakdown = bonusFor(props.Facility, profile, level, labor)
	local levelCfg = (FacilityConfig.UpgradeTable :: any)[props.Facility][level]
	-- Always two columns. Below MIN_WIDTH the window is laid out at MIN_WIDTH and scaled down to fit,
	-- instead of restacking into one scrolling column.
	local MIN_WIDTH = 820
	local fit = math.clamp(props.Width / MIN_WIDTH, 0.4, 1)
	local full = #assigned >= maxWorkers
	local tone = Tones[info.Tone] or Tones.Violet

	local function say(text: string, bad: boolean?)
		setMessage(text)
		setIsError(bad == true)
	end

	local function request(uuid: string, target: string)
		if busy then return end
		setBusy(true)
		say("Saving…")
		task.spawn(function()
			local ok, success, msg = pcall(function() return AssignHeroRole:InvokeServer(uuid, target) end)
			setBusy(false)
			setConfirming(nil)
			if not ok then
				say("Couldn't reach the server. Try again.", true)
			elseif success then
				local hero = profile.Heroes[uuid]
				if target ~= "BENCHED" and (props.Facility == "GuardPost" or props.Facility == "Market" or props.Facility == "TrainingGrounds") then
					setDeploySerial(function(prev: number)
						return prev + 1
					end)
				end
				say(if target == "BENCHED" then string.format("%s returned to the bench.", hero and hero.DisplayName or "Hero")
					else string.format("%s now works here.", hero and hero.DisplayName or "Hero"))
			else
				say(tostring(msg or "Unable to assign that hero."), true)
			end
		end)
	end

	-- What the big figure becomes if a hero joined (while a slot is free).
	local function gainText(hero: any): string
		local after = bonusFor(props.Facility, profile, level, labor + StatFormulas.GetEffectiveLabor(hero, info.Tag))
		if props.Facility == "GuardPost" then
			return string.format("+%s Gold/min", Components.Abbreviate(after - value))
		end
		return string.format("+%.1f%%", (after - value) * 100)
	end
	local hoverHero = hovered and profile.Heroes[hovered]
	local preview = if hoverHero and hoverHero.Assignment ~= info.Tag and not full and restingSeconds(hoverHero) == 0 then gainText(hoverHero) else ""

	-- Header ----------------------------------------------------------------
	local synergy = table.concat(FacilityConfig.FacilityArchetypeSynergies[props.Facility] or {}, ", ")
	local nxt = nextNode(props.Facility, profile.FortressTree)
	local nextText = if nxt
		then string.format("NEXT: %s · %s Gold%s", string.upper(nxt.Name), Components.Abbreviate(nxt.Gold), if nxt.FloorGate > (profile.HighestClearedFloor or 0) then string.format(" · Floor %d", nxt.FloorGate) else "")
		else "ALL NODES BUILT"
	local header = e("Frame", { Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -96, 0, 84), BackgroundTransparency = 1, ZIndex = 24 }, {
		Icon = IconAt(info.Icon, 76, { Position = UDim2.fromOffset(0, 2), ZIndex = 25 }),
		Title = Heavy({ Position = UDim2.fromOffset(90, 2), Size = UDim2.new(1, -90, 0, 34), MaxSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Text = info.Title, ZIndex = 25 }),
		Level = Panel({ Position = UDim2.fromOffset(90, 42), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, Radius = 14,
			Top = tone.Top, Bottom = tone.Bottom, Rail = tone.Rail, ZIndex = 25 }, {
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
			Text = Heavy({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), TextScaled = false, TextSize = 15, Outline = 2, Gold = false, ZIndex = 27,
				Text = string.format("LV.%d · %s", level, string.upper(levelCfg and levelCfg.VisualTitle or "Unbuilt")) }),
		}),
		Blurb = Body({ Position = UDim2.fromOffset(90, 72), Size = UDim2.new(1, -90, 0, 16), TextSize = 13, TextColor3 = TEXT.Muted, Text = info.Blurb, ZIndex = 25 }),
	})

	-- Bonus panel -------------------------------------------------------------
	local rows: { [string]: any } = { Layout = e("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for i, row in breakdown do
		rows["R" .. i] = breakdownRow(i, row[1], row[2])
	end
	local bonusHeight = 118 + #breakdown * 24
	local bonus = Panel({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, bonusHeight), Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = tone.Rail }, {
		Caption = Heavy({ Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 18), MaxSize = 15, Outline = 2, TextXAlignment = Enum.TextXAlignment.Left,
			Text = "CURRENT BONUS", ZIndex = 3 }),
		Figure = e("TextLabel", { Position = UDim2.fromOffset(18, 34), Size = UDim2.new(1, -36, 0, 44), BackgroundTransparency = 1, FontFace = Grimoire.Fonts.Number,
			TextScaled = true, TextColor3 = TEXT.Gold, TextXAlignment = Enum.TextXAlignment.Left, Text = figure, ZIndex = 3 }, {
			Limit = e("UITextSizeConstraint", { MaxTextSize = 36 }),
			Ink = e("UIStroke", { Color = INK, Thickness = 2.6, LineJoinMode = Enum.LineJoinMode.Round }),
		}),
		Preview = if preview ~= "" then Panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 12), Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X, Radius = 13, Top = Color3.fromRGB(40, 120, 70), Bottom = Color3.fromRGB(16, 60, 34), Rail = TEXT.Good, ZIndex = 4 }, {
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
			Text = Heavy({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextScaled = false, TextSize = 14, Outline = 2, Gold = false, Text = preview, ZIndex = 6 }),
		}) else nil,
		Note = Body({ Position = UDim2.fromOffset(18, 80), Size = UDim2.new(1, -36, 0, 16), TextSize = 12, TextColor3 = TEXT.Muted, ZIndex = 3,
			Text = string.format("%d / %d %ss working · labor %.1f%s", #assigned, maxWorkers, info.Worker, labor, if synergy ~= "" then " · +25% for " .. synergy else "") }),
		Lines = e("Frame", { Position = UDim2.fromOffset(18, 104), Size = UDim2.new(1, -36, 1, -112), BackgroundTransparency = 1, ZIndex = 3 }, rows),
	})

	-- Worker slots ----------------------------------------------------------
	local slots: { [string]: any } = { Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for i = 1, math.min(math.max(maxWorkers, 1) + 1, 5) do
		local uuid = assigned[i]
		local hero = uuid and profile.Heroes[uuid]
		local size = UDim2.fromOffset(104, 160)
		if i <= maxWorkers and hero then
			local rarity = StatFormulas.GetHeroRarity(hero)
			local resting = restingSeconds(hero)
			slots["S" .. i] = Panel({ LayoutOrder = i, Size = size, Radius = 10, Top = Tones.Violet.Top, Bottom = Tones.Violet.Bottom, Rail = Theme.RarityColor(rarity) }, {
				Art = e("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(72, 72),
					BackgroundColor3 = Color3.fromRGB(14, 10, 22), ClipsDescendants = true, ZIndex = 3 }, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Ring = e("UIStroke", { Color = Theme.RarityColor(rarity), Thickness = 2.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					Portrait = e(Portrait, { TemplateId = hero.TemplateId, Archetype = hero.Archetype, Stars = hero.Stars }),
				}),
				Bonus = if hasSynergy(props.Facility, hero) then IconAt("Spark", 22, { Position = UDim2.fromOffset(4, 2), ZIndex = 6 }) else nil,
				Name = Heavy({ Position = UDim2.fromOffset(4, 82), Size = UDim2.new(1, -8, 0, 18), MaxSize = 13, Outline = 1.8, Gold = false, Text = hero.DisplayName, ZIndex = 4 }),
				Labor = Body({ Position = UDim2.fromOffset(4, 100), Size = UDim2.new(1, -8, 0, 16), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4,
					TextColor3 = if resting > 0 then TEXT.Bad else TEXT.Gold,
					Text = if resting > 0 then string.format("Resting %ds", resting) else string.format("%.1f labor", StatFormulas.GetEffectiveLabor(hero, info.Tag)) }),
				Remove = button({ Position = UDim2.fromOffset(8, 122), Size = UDim2.new(1, -16, 0, 30), ZIndex = 4,
					[React.Event.Activated] = function() request(uuid, "BENCHED") end }, "Slate", "REMOVE", 13),
			})
		elseif i <= maxWorkers then
			slots["S" .. i] = Panel({ Class = "TextButton", Text = "", AutoButtonColor = false, LayoutOrder = i, Size = size, Radius = 10,
				Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = TEXT.Gold,
				[React.Event.Activated] = function() say("Pick a hero from the list on the right to fill this slot.") end }, {
				Plus = Heavy({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 50), MaxSize = 48, Text = "+", ZIndex = 4 }),
				Hint = Body({ Position = UDim2.fromOffset(6, 92), Size = UDim2.new(1, -12, 0, 40), TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TEXT.Muted, Text = "Assign hero", ZIndex = 4 }),
			})
		else
			-- The next slot this facility can open, through a level or perk node.
			slots["S" .. i] = Panel({ Class = "TextButton", Text = "", AutoButtonColor = false, LayoutOrder = i, Size = size, Radius = 10,
				Top = Tones.Slate.Top, Bottom = Tones.Slate.Bottom, Rail = Tones.Slate.Rail,
				[React.Event.Activated] = function()
					props.OnClose()
					if _G.OpenFacilityHUD then _G.OpenFacilityHUD("FortressTree") end
				end }, {
				Padlock = IconAt("Lock", 40, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), ZIndex = 4 }),
				Lock = Body({ Position = UDim2.fromOffset(6, 74), Size = UDim2.new(1, -12, 0, 56), TextSize = 12, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TEXT.Muted, Text = "More slots in\nUpgrades", ZIndex = 4 }),
			})
		end
	end
	local stagePanel = if props.Facility == "GuardPost"
		then e(OutskirtsPreviewStage, {
			Profile = profile,
			AssignedUUIDs = assigned,
			DeploySerial = deploySerial,
		})
		elseif props.Facility == "Market" or props.Facility == "TrainingGrounds" then e(FacilityWorkersPreviewStage, {
			Facility = props.Facility,
			Profile = profile,
			AssignedUUIDs = assigned,
			MaxWorkers = maxWorkers,
			DeploySerial = deploySerial,
		})
		else nil
	local slotPanel = Panel({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 214), Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Deep.Rail }, {
		Caption = Heavy({ Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 18), MaxSize = 15, Outline = 2, TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("WORKERS  %d/%d", #assigned, maxWorkers), ZIndex = 3 }),
		Row = e("ScrollingFrame", { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 168), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ZIndex = 3 }, slots),
	})

	-- Hero list -------------------------------------------------------------
	local heroes = {}
	for _, hero in pairs(profile.Heroes or {}) do
		-- Workers of any facility are out of the backpack; they come back only when unassigned.
		if not InventoryCapacity.IsInFacility(hero) then
			if filter == "All" or (filter == "Bench" and hero.Assignment == "BENCHED") or (filter == "Best" and hasSynergy(props.Facility, hero)) then
				table.insert(heroes, hero)
			end
		end
	end
	table.sort(heroes, function(a, b)
		local ra, rb = restingSeconds(a) > 0, restingSeconds(b) > 0
		if ra ~= rb then return rb end
		local la, lb = StatFormulas.GetEffectiveLabor(a, info.Tag), StatFormulas.GetEffectiveLabor(b, info.Tag)
		if la ~= lb then return la > lb end
		return tostring(a.UUID) < tostring(b.UUID)
	end)
	local cards: { [string]: any } = { Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Pad = e("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8) }) }
	for i, hero in heroes do
		local good = hasSynergy(props.Facility, hero)
		local rarity = StatFormulas.GetHeroRarity(hero)
		local resting = restingSeconds(hero)
		local away = hero.Assignment ~= "BENCHED"
		local isConfirming = confirming == hero.UUID
		local heroLabor = StatFormulas.GetEffectiveLabor(hero, info.Tag)
		local actionTone, actionText = "Action", "ASSIGN"
		if resting > 0 then
			actionTone, actionText = "Slate", "RESTING"
		elseif full then
			actionTone, actionText = "Slate", "FULL"
		elseif isConfirming then
			actionTone, actionText = "Gold", "CONFIRM"
		elseif away then
			actionTone, actionText = "Bronze", "MOVE HERE"
		end
		local function act()
			if resting > 0 then
				say(string.format("%s is resting for %ds.", hero.DisplayName, resting), true)
			elseif full then
				say(string.format("All %d %s slots are full. Remove a worker first.", maxWorkers, info.Worker), true)
			elseif away and not isConfirming then
				-- Moving a hero off another job asks first (plan §6, Soft) instead of "press CONFIRM".
				local heroId = hero.UUID
				Kit.Confirm.Ask({
					Tier = Kit.Rules.ConfirmTier("UNASSIGN_FACILITY"),
					Title = string.format("Move %s here?", hero.DisplayName),
					Body = string.format("%s will leave %s and work here instead.", hero.DisplayName, assignmentLabel(hero.Assignment)),
					ConfirmText = "Move here",
					SessionKey = "UNASSIGN_FACILITY",
					OnConfirm = function() request(heroId, info.Tag) end,
				})
			else
				request(hero.UUID, info.Tag)
			end
		end
		cards["H" .. i] = Panel({
			Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 78), Radius = 10,
			Top = if hovered == hero.UUID then Tones.Violet.Top else Tones.Deep.Top, Bottom = Tones.Deep.Bottom,
			Rail = if good then TEXT.Gold else Color3.fromRGB(110, 96, 140),
			[React.Event.MouseEnter] = function() setHovered(hero.UUID) end,
			[React.Event.MouseLeave] = function() if hovered == hero.UUID then setHovered(nil) end end,
			[React.Event.Activated] = act,
		}, {
			Art = e("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(62, 62), BackgroundColor3 = Color3.fromRGB(14, 10, 22), ClipsDescendants = true, ZIndex = 3 }, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
				Ring = e("UIStroke", { Color = Theme.RarityColor(rarity), Thickness = 2.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
				Portrait = e(Portrait, { TemplateId = hero.TemplateId, Archetype = hero.Archetype, Stars = hero.Stars }),
			}),
			Arch = IconAt(hero.Archetype or "Striker", 24, { Position = UDim2.fromOffset(54, 50), ZIndex = 6 }),
			Name = Heavy({ Position = UDim2.fromOffset(84, 8), Size = UDim2.new(1, -250, 0, 20), MaxSize = 16, Outline = 2, Gold = false,
				TextXAlignment = Enum.TextXAlignment.Left, Text = hero.DisplayName, ZIndex = 4 }),
			Info = Body({ Position = UDim2.fromOffset(84, 30), Size = UDim2.new(1, -250, 0, 16), TextSize = 12, ZIndex = 4, TextColor3 = Theme.RarityColor(rarity),
				Text = string.format("%s · %s %d★ · Lv.%d", hero.Archetype or "?", HeroCatalog.RarityName(rarity), hero.Stars or 1, hero.Level or 1) }),
			Where = Body({ Position = UDim2.fromOffset(84, 50), Size = UDim2.new(1, -250, 0, 16), TextSize = 12, ZIndex = 4,
				TextColor3 = if resting > 0 then TEXT.Bad elseif away then Color3.fromRGB(150, 236, 255) else TEXT.Muted,
				Text = if resting > 0 then string.format("Resting %ds", resting) else "Now: " .. assignmentLabel(hero.Assignment) }),
			Labor = e("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -140, 0.5, 0), Size = UDim2.fromOffset(92, 56), BackgroundTransparency = 1, ZIndex = 4 }, {
				Value = e("TextLabel", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, FontFace = Grimoire.Fonts.Number, TextSize = 24, ZIndex = 4,
					TextColor3 = if good then TEXT.Gold else TEXT.Parchment, Text = string.format("%.1f", heroLabor) }, {
					Ink = e("UIStroke", { Color = INK, Thickness = 2 }),
				}),
				Caption = Body({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 14), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = if good then TEXT.Gold else TEXT.Muted, Text = if good then "LABOR · +25%" else "LABOR", ZIndex = 4 }),
				Gain = if not full and resting == 0 then Body({ Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 14), TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = TEXT.Good, Text = gainText(hero), ZIndex = 4 }) else nil,
			}),
			Action = button({ Name = if actionText == "ASSIGN" then "GuideAssignWorker" else "WorkerAction", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(118, 40), ZIndex = 4,
				[React.Event.Activated] = act }, actionTone, actionText, 14),
		})
	end
	if #heroes == 0 then
		cards.Empty = Body({ Size = UDim2.new(1, 0, 0, 60), TextSize = 14, TextColor3 = TEXT.Muted, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true,
			Text = if filter == "All" then "No other heroes. Summon more at the Summoning Altar." else "No heroes match this filter." })
	end
	local chips: { [string]: any } = { Layout = e("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }
	for order, key in { "All", "Bench", "Best" } do
		chips[key] = button({ LayoutOrder = order, Size = UDim2.fromOffset(if key == "Best" then 96 else 72, 28), ZIndex = 4,
			[React.Event.Activated] = function() setFilter(key :: Filter) end },
			if filter == key then "Gold" else "Slate", if key == "Best" then "BEST FIT" else string.upper(key), 12)
	end
	local picker = Panel({ LayoutOrder = 4, Size = UDim2.fromScale(1, 1),
		Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Deep.Rail }, {
		Caption = Heavy({ Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -300, 0, 20), MaxSize = 16, Outline = 2, TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("ASSIGN %sS", string.upper(info.Worker)), ZIndex = 3 }),
		Chips = e("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.fromOffset(280, 28), BackgroundTransparency = 1, ZIndex = 3 }, chips),
		List = e("ScrollingFrame", {
			Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 1, -54), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 5, ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 3,
		}, cards),
	})

	-- Layout: always two columns (bonus, stage and workers left; the hero picker right).
	local body = e("Frame", { Position = UDim2.fromOffset(20, 108), Size = UDim2.new(1, -40, 1, -156), BackgroundTransparency = 1, ZIndex = 23 }, {
		Left = e("ScrollingFrame", { Size = UDim2.new(0.44, -8, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(240, 196, 110),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 23 }, {
			Layout = e("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
			Bonus = bonus, Stage = stagePanel, Slots = slotPanel,
		}),
		Right = e("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.56, -8, 1, 0), BackgroundTransparency = 1, ZIndex = 23 }, {
			Picker = picker,
		}),
	})

	-- Footer: the Fortress Tree link and the status line.
	local footer = e("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -12), Size = UDim2.new(1, -40, 0, 36), BackgroundTransparency = 1, ZIndex = 24 }, {
		Status = Body({ Size = UDim2.new(1, -340, 1, 0), TextSize = 14, TextColor3 = if isError then TEXT.Bad else TEXT.Muted, Text = message, ZIndex = 25 }),
		Next = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(330, 36), ZIndex = 25,
			[React.Event.Activated] = function()
				props.OnClose()
				if _G.OpenFacilityHUD then _G.OpenFacilityHUD("FortressTree") end
			end }, "Bronze", nextText .. "  ›", 13),
	})

	return e("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(6, 5, 10), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 20,
		[React.Event.Activated] = function() props.OnClose() end,
	}, {
		Window = Panel({
			Name = `GuideFacility_{props.Facility}`,
			Class = "TextButton", Text = "", AutoButtonColor = false, -- swallows clicks so they don't reach the scrim
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			-- Sized at 1/fit and scaled by fit, so on narrow screens it still fills the screen minus
			-- 24 px but lays out as if MIN_WIDTH wide.
			Size = UDim2.new(1 / fit, -24 / fit, 1 / fit, -24 / fit),
			Radius = 16,
			Rail = tone.Rail,
			ZIndex = 21,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(1120, 720) }),
			Fit = e("UIScale", { Scale = fit }),
			Header = header,
			Close = Panel({
				Class = "TextButton", Text = "", AutoButtonColor = false, Selectable = true, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18),
				Size = UDim2.fromOffset(44, 40), Radius = 10, Top = Tones.Crimson.Top, Bottom = Tones.Crimson.Bottom, Rail = Tones.Crimson.Rail, ZIndex = 25,
				[React.Event.Activated] = function() props.OnClose() end,
			}, {
				X = IconAt("Close", 18, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 27 }),
			}),
			Body = body,
			Footer = footer,
		}),
	})
end

return FacilityPanel
