--!strict
-- Raid Bosses (docs/raid-boss-plan.md). One cycle per server, aligned to the wall clock (:00 and :30 UTC):
-- CALM -> WARNING (portal opens, staging pad) -> ACTIVE (5-minute fight) -> RESULTS (payout, auto-return).
-- State is published as ReplicatedStorage attributes so late joiners need no remote:
--   RaidPhase "CALM" | "WARNING" | "ACTIVE" | "RESULTS", RaidBossId, RaidStartsAt, RaidEndsAt (server time),
--   RaidNumber (reward idempotency key).
-- Damage is recorded by CombatSimulation (hero impacts on the raid boss, overkill excluded) and paid at the
-- end by damage share, capped at RaidConfig.MaxGems.
-- Studio: workspace attribute RaidForce = "<BossId>" starts that boss's warning now; RaidFast = true shortens
-- every timer (RaidConfig.Fast).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.RaidConfig)
local Rules = require(Shared.Util.RaidRules)
local HubLayout = require(Shared.Config.HubLayout)
local StatBalance = require(Shared.Config.StatBalance)
local Combat = require(Shared.Config.FirstBiomeCombat)
local Tower = require(script.Parent.Parent.Core.TowerFloorService)
local Arena = require(script.Parent.RaidArenaBuilder)
local PortalKit = require(script.Parent.RaidPortalKit)

local FLOOR = Config.FloorId

-- Remotes ----------------------------------------------------------------------------------------
local remoteRoot = ReplicatedStorage:WaitForChild("Remotes")
local folder = remoteRoot:FindFirstChild("RaidRemotes") or Instance.new("Folder")
folder.Name = "RaidRemotes"
folder.Parent = remoteRoot
local function remote(name: string, unreliable: boolean?): any
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new(if unreliable then "UnreliableRemoteEvent" else "RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r
end
local LeaveRemote = remote("Leave")
local BoardRemote = remote("Board", true)
local RosterRemote = remote("Roster")
local ResultRemote = remote("Result")

-- State ------------------------------------------------------------------------------------------
type Participant = { Player: Player, UserId: number, Name: string, Slot: number, Damage: number, FirstAt: number, Share: number }

local Service = {}
local phase: Rules.Phase = "CALM"
local startAt = 0
local raidNumber = 0
local boss: Config.Boss = Config.Bosses[1]
local timings = Rules.Timings(false)
local participants: { [number]: Participant } = {} -- by UserId
local nextSlot = 1
local bossMob: any = nil
local killed = false
local endedAt = 0
local paid = false
local lastLeave: { [Player]: number } = {}
local portal: PortalKit.Portal? = nil

local function dataManager(): any
	while not _G.DataManager do task.wait(0.05) end
	return _G.DataManager
end
local function combat(): any
	return _G.CombatSimulation
end
local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish()
	ReplicatedStorage:SetAttribute("RaidPhase", phase)
	ReplicatedStorage:SetAttribute("RaidBossId", boss.Id)
	ReplicatedStorage:SetAttribute("RaidStartsAt", startAt)
	ReplicatedStorage:SetAttribute("RaidEndsAt", startAt + timings.Active)
	ReplicatedStorage:SetAttribute("RaidNumber", raidNumber)
end

local function toastAll(text: string, kind: string)
	local dm = dataManager()
	for _, p in Players:GetPlayers() do dm.SendToast(p, text, kind) end
end

local function inArena(player: Player): boolean
	return Tower.GetState(player).FloorId == FLOOR
end

local function arenaPlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if inArena(p) then table.insert(list, p) end
	end
	return list
end

local function sendRoster()
	local roster = {}
	for _, part in participants do roster[part.Slot] = { UserId = part.UserId, Name = part.Name } end
	for _, p in arenaPlayers() do RosterRemote:FireClient(p, raidNumber, roster) end
end

-- Schedule ---------------------------------------------------------------------------------------
local function scheduleNext(t: number)
	timings = Rules.Timings(RunService:IsStudio() and Workspace:GetAttribute("RaidFast") == true)
	startAt = Rules.NextStart(t)
	-- A server that starts mid-warning still gets a full warning: skip to the following slot.
	if startAt - t < timings.Warning then startAt += Config.IntervalSeconds end
	raidNumber = Rules.RaidNumber(startAt)
	boss = Rules.BossFor(raidNumber)
	phase = "CALM"
	participants, nextSlot, bossMob, killed, paid = {}, 1, nil, false, false
	publish()
end

-- Portal -----------------------------------------------------------------------------------------
local function refreshPortal()
	if not portal then return end
	local open = phase == "WARNING" or (phase == "ACTIVE" and Rules.CanEnter(now(), startAt, timings))
	portal.Prompt.Enabled = open
	PortalKit.SetGlow(portal, if phase == "CALM" or phase == "RESULTS" then boss.Accent:Lerp(Color3.fromRGB(60, 40, 80), 0.6) else boss.Accent, open)
	portal.Title.Text = string.upper(Config.FullName(boss))
	portal.Title.TextColor3 = boss.Accent:Lerp(Color3.new(1, 1, 1), 0.35)
	local t = now()
	if phase == "CALM" then
		portal.Status.Text = "Next raid in " .. Rules.Clock(startAt - t)
	elseif phase == "WARNING" then
		portal.Status.Text = "RAID OPEN - rises in " .. Rules.Clock(startAt - t)
	elseif phase == "ACTIVE" then
		portal.Status.Text = if open then "RAID OPEN - " .. Rules.Clock(startAt + timings.Active - t) .. " left" else "Raid sealed - " .. Rules.Clock(startAt + timings.Active - t)
	else
		portal.Status.Text = if killed then "Defeated!" else "The raid is over"
	end
end

-- Boss -------------------------------------------------------------------------------------------
local function arenaRoom(): any
	return Tower.EnsureRoom(FLOOR)
end

-- Boss ATK follows the participants' median best floor, at half a Biome Boss's hit (many squads share it).
local function bossAtk(): number
	local floors = {}
	local dm = dataManager()
	for _, part in participants do
		local profile = dm.GetProfile(part.Player)
		table.insert(floors, math.clamp((profile and profile.HighestClearedFloor) or 1, 1, 50))
	end
	table.sort(floors)
	local floor = if #floors > 0 then floors[math.max(1, math.ceil(#floors / 2))] else 1
	local stats = StatBalance.GetFloorStats(floor, "BOSS") :: any
	return math.max(1, math.round((stats and stats.ATK or 66) * 0.5))
end

local function spawnBoss(room: any)
	local cs = combat()
	if not cs or not cs.SpawnRaidMob then return end
	cs.ClearRaidMobs(FLOOR)
	local home = room.Origin + Arena.BossHome()
	local enemyId = Combat.RaidEnemyId(boss.Id)
	bossMob = cs.SpawnRaidMob(room, enemyId, home, {
		DisplayName = Config.FullName(boss),
		Role = "BOSS",
		RaidBoss = boss.Id,
		RaidNumber = raidNumber,
		Dormant = true,
		Yaw = 0, -- faces +Z, toward the staging pad
		CurrentHP = 1,
		MaxHP = 1,
		ATK = 1,
		CampId = "RAID",
	})
	-- The enrage move stays sealed until Phase 2.
	local enrageId = Combat.RaidEnrageAttackId(boss.Id)
	if bossMob and enrageId then bossMob.Cooldowns[enrageId] = math.huge end
end

local function enrage(mob: any)
	if mob.Enraged then return end
	mob.Enraged = true
	local enrageId = Combat.RaidEnrageAttackId(boss.Id)
	if enrageId then mob.Cooldowns[enrageId] = 0 end
	local dm = dataManager()
	for _, p in arenaPlayers() do dm.SendToast(p, `{boss.DisplayName} is ENRAGED: {boss.Enrage.DisplayName}!`, "WARN") end
	local adds = boss.Adds
	local cs = combat()
	local room = Tower.GetRoom(FLOOR)
	if adds and cs and room then
		for i = 1, adds.Count do
			local a = (i / adds.Count) * math.pi * 2
			local pos = mob.Position + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)
			cs.SpawnRaidMob(room, adds.Template, pos, {
				DisplayName = "Rift Spiderling", Role = "REGULAR", RaidAdd = true,
				CurrentHP = math.max(1, math.round(mob.MaxHP * 0.01)), MaxHP = math.max(1, math.round(mob.MaxHP * 0.01)),
				ATK = math.max(1, math.round(mob.ATK * 0.25)), LeashRadius = 400,
			})
		end
	end
end

-- Participants -----------------------------------------------------------------------------------
-- A Master who reaches the arena adds their squad's share to the boss's HP budget (once per raid).
local function admit(player: Player)
	if participants[player.UserId] then
		participants[player.UserId].Player = player
		return
	end
	local cs = combat()
	local dps = if cs and cs.SquadDPS then cs.SquadDPS(player) else 0
	local share = Rules.HpShare(dps, timings.Active)
	participants[player.UserId] = { Player = player, UserId = player.UserId, Name = player.DisplayName, Slot = nextSlot, Damage = 0, FirstAt = math.huge, Share = share }
	nextSlot += 1
	if bossMob and bossMob.IsAlive and not bossMob.Dormant then
		bossMob.CurrentHP, bossMob.MaxHP = Rules.AddShare(bossMob.CurrentHP, bossMob.MaxHP, share)
	end
	sendRoster()
end

function Service.RecordDamage(player: Player, amount: number)
	if phase ~= "ACTIVE" or amount ~= amount or amount <= 0 then return end
	local part = participants[player.UserId]
	if not part then
		admit(player)
		part = participants[player.UserId]
	end
	if part.FirstAt == math.huge then part.FirstAt = now() end
	part.Damage += amount
end

-- Punish Window after a signature, and Aurelith's exposed core while enraged.
function Service.ModifyDamage(mob: any, damage: number, _clock: number?): number
	local t = now()
	local mult = 1
	if mob.PunishUntil and t < mob.PunishUntil then mult *= Config.PunishDamageTaken end
	if mob.Enraged and mob.RaidBoss == "SHARDBOUND" then mult *= 1.5 end
	return math.round(damage * mult)
end

function Service.OnSignature(mob: any, t: number)
	mob.PunishUntil = t + Config.PunishSeconds
end

function Service.OnBossDeath(mob: any, _killer: Player?)
	if mob ~= bossMob or phase ~= "ACTIVE" then return end
	killed = true
end

-- Travel -----------------------------------------------------------------------------------------
local function returnToHub(player: Player)
	if not inArena(player) then return end
	local landing = HubLayout.RaidPortalLanding()
	local char = player.Character
	if char then
		local away = HubLayout.RaidPortalCFrame().LookVector -- face away from the portal, toward the dais
		char:PivotTo(CFrame.lookAt(landing, landing + Vector3.new(away.X, 0, away.Z)))
	end
	Tower.ExitToOverworld(player, landing, false)
end

local function entryError(player: Player): string?
	local t = now()
	if not Rules.CanEnter(t, startAt, timings) or (phase ~= "WARNING" and phase ~= "ACTIVE") then return "The Raid Portal is closed." end
	local dm = dataManager()
	if dm.IsUnlocked and not dm.IsUnlocked(player, "Tower") then return dm.LockedMessage and dm.LockedMessage("Tower") or "Unlock the Tower first." end
	if Tower.IsTransitioning(player) then return "You are already travelling." end
	local char = player.Character
	if not char then return "Your Master is not ready." end
	if char:GetAttribute("CarryingRelic") ~= nil then return "Bank your relic before entering a raid." end
	if char:GetAttribute("IsLootThief") == true then return "Thieves can't enter a raid while their bounty runs." end
	local cs = combat()
	if cs and cs.IsInDuel and cs.IsInDuel(player) then return "Finish your duel first." end
	if cs and cs.StandingHeroes and cs.StandingHeroes(player) == 0 then return "Deploy a hero who can fight to enter the raid." end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or not portal or (root.Position - portal.Trigger.Position).Magnitude > Config.PortalPromptDistance + 12 then return "Step up to the portal." end
	return nil
end

function Service.TryEnter(player: Player)
	local err = entryError(player)
	if err then
		dataManager().SendToast(player, err, "WARN")
		return
	end
	local ok = pcall(arenaRoom)
	if not ok or not Tower.EnterRaidFloor(player, FLOOR) then
		dataManager().SendToast(player, "The Raid Portal flickers. Try again.", "WARN")
	end
end

LeaveRemote.OnServerEvent:Connect(function(player: Player)
	local t = os.clock()
	if t - (lastLeave[player] or -math.huge) < Config.LeaveCooldown then return end
	lastLeave[player] = t
	returnToHub(player)
end)

-- Payout -----------------------------------------------------------------------------------------
local function payout()
	if paid then return end
	paid = true
	local entries = {}
	for _, part in participants do
		if part.Damage > 0 then table.insert(entries, { UserId = part.UserId, Damage = part.Damage, FirstAt = part.FirstAt }) end
	end
	local ranked = Rules.Rank(entries)
	local maxDamage = if ranked[1] then ranked[1].Damage else 0
	local maxHP = if bossMob then bossMob.MaxHP else 1
	local removed = if killed then 1 elseif bossMob then 1 - math.clamp(bossMob.CurrentHP / math.max(1, bossMob.MaxHP), 0, 1) else 0
	local dm = dataManager()
	local rankOf = {}
	for i, e in ranked do rankOf[e.UserId] = i end
	for _, part in participants do
		local player = part.Player
		if player.Parent ~= Players then continue end
		local rank = rankOf[part.UserId] or (#ranked + 1)
		local profile = dm.GetProfile(player)
		if not profile then continue end
		local raid = dm.EnsureRaidData(profile)
		if raid.LastRewardedRaid >= raidNumber then continue end -- idempotent
		local reward = Rules.Reward(part.Damage, maxDamage, rank, maxHP, removed, Rules.FloorScale(profile.HighestClearedFloor or 1))
		local gems = math.clamp(reward.Gems, 0, Config.MaxGems) -- the cap, enforced again at the credit
		raid.LastRewardedRaid = raidNumber
		raid.Participations += 1
		raid.BestDamage = math.max(raid.BestDamage, part.Damage)
		if killed and reward.Qualified then raid.Kills += 1 end
		profile.Currencies.Gems += gems
		profile.Currencies.Gold += reward.Gold
		dm.SyncProfile(player)
		if dm.SaveProfile then task.spawn(dm.SaveProfile, player) end
		ResultRemote:FireClient(player, {
			RaidNumber = raidNumber, BossId = boss.Id, Killed = killed, Rank = if reward.Qualified then rank else 0,
			Participants = #ranked, Damage = part.Damage, Share = if maxDamage > 0 then part.Damage / maxDamage else 0,
			Gems = gems, Gold = reward.Gold, Qualified = reward.Qualified, ReturnAt = now() + timings.Results,
		})
		if reward.Qualified then
			dm.SendToast(player, `Raid {if killed then "victory" else "over"}: #{rank}, +{gems} Gems, +{reward.Gold} Gold`, "SUCCESS")
		end
	end
end

-- Board ------------------------------------------------------------------------------------------
local boardElapsed = 0
local function broadcastBoard()
	local list = {}
	local total = 0
	for _, part in participants do
		table.insert(list, { UserId = part.UserId, Damage = part.Damage, FirstAt = part.FirstAt })
		total += part.Damage
	end
	local ranked = Rules.Rank(list)
	local rows = {}
	local rankOf = {}
	for i, e in ranked do
		rankOf[e.UserId] = i
		if i <= Config.BoardRows then table.insert(rows, { Slot = participants[e.UserId].Slot, Damage = e.Damage }) end
	end
	local maxHP = if bossMob then bossMob.MaxHP else 0
	local hp = if bossMob and bossMob.IsAlive then bossMob.CurrentHP else 0
	for _, p in arenaPlayers() do
		local me = participants[p.UserId]
		BoardRemote:FireClient(p, Rules.EncodeBoard(rows, rankOf[p.UserId] or 0, me and me.Damage or 0, total, maxHP, hp))
	end
end

-- Phases -----------------------------------------------------------------------------------------
local function enterWarning()
	phase = "WARNING"
	local ok, room = pcall(arenaRoom)
	if ok and room then
		Arena.Retheme(room, boss)
		Arena.SetGateOpen(room, false)
		spawnBoss(room)
	else
		warn("Raid arena build failed: " .. tostring(room))
	end
	toastAll(`{Config.FullName(boss)} rises in {Rules.Clock(startAt - now())}. The Raid Portal in the Commons is open!`, "WARN")
	publish()
end

local function enterActive()
	phase = "ACTIVE"
	local room = Tower.GetRoom(FLOOR)
	if room then Arena.SetGateOpen(room, true) end
	for _, p in arenaPlayers() do admit(p) end
	if bossMob then
		local hp = 0
		for _, part in participants do hp += part.Share end
		hp = math.max(hp, Rules.HpShare(0, timings.Active))
		bossMob.MaxHP, bossMob.CurrentHP = hp, hp
		bossMob.ATK = bossAtk()
		bossMob.Dormant = false
		bossMob.BornAt = now()
	end
	local dm = dataManager()
	for _, p in arenaPlayers() do dm.SendToast(p, `{Config.FullName(boss)} awakens! Deal the most damage in {Rules.Clock(timings.Active)}.`, "WARN") end
	publish()
end

local function enterResults()
	phase = "RESULTS"
	endedAt = now()
	payout()
	local cs = combat()
	if bossMob and bossMob.IsAlive and cs then cs.ClearRaidMobs(FLOOR) end
	local room = Tower.GetRoom(FLOOR)
	if room then Arena.SetGateOpen(room, false) end
	broadcastBoard()
	publish()
end

local function finish()
	for _, p in arenaPlayers() do returnToHub(p) end
	local cs = combat()
	if cs then cs.ClearRaidMobs(FLOOR) end
	scheduleNext(now())
end

local function step(dt: number)
	local t = now()
	local force = if RunService:IsStudio() then Workspace:GetAttribute("RaidForce") else nil
	if type(force) == "string" and force ~= "" then
		Workspace:SetAttribute("RaidForce", nil)
		local forced = Config.Get(force)
		if forced and (phase == "CALM" or phase == "RESULTS") then
			if phase == "RESULTS" then finish() end
			timings = Rules.Timings(Workspace:GetAttribute("RaidFast") == true)
			startAt = t + timings.Warning
			raidNumber = Rules.RaidNumber(startAt) + 1000000 -- never collides with a real raid's reward key
			boss = forced
			participants, nextSlot, bossMob, killed, paid = {}, 1, nil, false, false
		end
	end

	local want = Rules.PhaseAt(t, startAt, timings)
	if phase == "CALM" and want == "WARNING" then enterWarning()
	elseif phase == "CALM" and want == "ACTIVE" then enterWarning(); enterActive()
	elseif phase == "WARNING" and want ~= "WARNING" then enterActive()
	elseif phase == "ACTIVE" then
		for _, p in arenaPlayers() do if not participants[p.UserId] then admit(p) end end
		if bossMob and bossMob.IsAlive and not bossMob.Enraged
			and (bossMob.CurrentHP <= bossMob.MaxHP * Config.EnrageHPFraction or t >= startAt + Config.EnrageAtSeconds * (timings.Active / Config.ActiveSeconds)) then
			enrage(bossMob)
		end
		if killed or want ~= "ACTIVE" or (bossMob and not bossMob.IsAlive) then
			if bossMob and not bossMob.IsAlive then killed = true end
			enterResults()
		end
	elseif phase == "RESULTS" and t >= endedAt + timings.Results then
		finish()
	elseif phase == "CALM" and want == "CALM" and t > startAt then
		scheduleNext(t) -- the slot passed (e.g. the clock jumped); pick the next one
	end

	boardElapsed += dt
	if boardElapsed >= 1 / Config.BoardHz then
		boardElapsed = 0
		if phase == "ACTIVE" or phase == "WARNING" then broadcastBoard() end
		refreshPortal()
	end
end

-- Boot -------------------------------------------------------------------------------------------
Tower.RegisterRoomBuilder(FLOOR, Arena.Build)
Tower.RegisterAdapter("Raid", {
	-- Keep the arena alive from the warning until everyone is back in the hub.
	Pins = function(id: number, _generation: number): boolean
		return id == FLOOR and phase ~= "CALM"
	end,
})

task.spawn(function()
	portal = PortalKit.Build(Workspace)
	local p = portal :: PortalKit.Portal
	p.Prompt.Triggered:Connect(function(player: Player) Service.TryEnter(player) end)
	refreshPortal()
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastLeave[player] = nil
end)

scheduleNext(now())
RunService.Heartbeat:Connect(step)

_G.RaidService = Service
