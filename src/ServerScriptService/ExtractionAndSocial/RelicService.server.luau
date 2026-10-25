--!strict
-- ServerScriptService/ExtractionAndSocial/RelicService.server.luau
-- Physical Relic Extraction, Overhead Welding, Fumbles & Private Plot Extraction

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SanctuaryRules = require(Shared.Util.TowerSanctuaryRules)
local RelicConfig = require(Shared:WaitForChild("Config"):WaitForChild("RelicConfig"))

local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RelicPactRemotes")
local RelicStateRemote = RemotesFolder:WaitForChild("RelicStateChanged") :: RemoteEvent

local PhysicalRelicsFolder = Workspace:WaitForChild("PhysicalRelics")
local PlotsFolder = Workspace:WaitForChild("WaitingRoomPlots")

local function getDataManager(): any
	while not _G.DataManager do
		task.wait(0.05)
	end
	return _G.DataManager
end

export type RelicTierId = "MANA_GEODE" | "CURSED_URN" | "ABYSSAL_CORE" | "CALAMITY_HEART"

export type ActiveRelic = {
	RelicId: number,
	RewardMultiplier: number,
	FloorId: number,
	RoomGeneration: number,
	TierId: RelicTierId,
	Part: BasePart,
	BillboardStatus: TextLabel?,
	Weld: WeldConstraint?,
	Carrier: Player?,
	LockedUserId: number?,
	LockExpiresAt: number,
	DespawnAt: number,
	PickupBlockedUserId: number?,
	PickupBlockedUntil: number?,
}

local BASE_WALKSPEED = 16.0
local BASE_JUMPPOWER = 50.0
local FUMBLE_STUN_SECONDS = 1.0
local FUMBLE_OWNER_LOCK_SECONDS = 3.0

local ArtPackVisuals = require(ReplicatedStorage.Assets:WaitForChild("ArtPackVisuals"))
local Tower=require(script.Parent.Parent.Core.TowerFloorService)
Tower.Init()
local RelicService = {}
local NextRelicId = 1
local ActiveRelics: { [number]: ActiveRelic } = {}
local CarrierToRelic: { [Player]: ActiveRelic } = {}
local PlayerStunnedUntil: { [Player]: number } = {}

local function getCharacterParts(player: Player): (Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hum, hrp
end

function RelicService.StunPlayer(player: Player, durationSec: number)
	local now = os.clock()
	PlayerStunnedUntil[player] = math.max(PlayerStunnedUntil[player] or 0, now + durationSec)
end

local function updateMasterMovementAttributes(player: Player, now: number)
	local hum, hrp = getCharacterParts(player)
	if not hum or not hrp then
		return
	end

	local stunnedUntil = PlayerStunnedUntil[player] or 0
	if now < stunnedUntil then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		return
	end

	local relic = CarrierToRelic[player]
	if not relic then
		hum.WalkSpeed = BASE_WALKSPEED
		hum.JumpPower = BASE_JUMPPOWER
		return
	end

	local spec = RelicConfig[relic.TierId]
	local penalty = spec.WalkSpeedPenalty

	local dm = getDataManager()
	local rogueBonus = (dm and dm.IsPlayerRogue and dm.IsPlayerRogue(player)) and 0.10 or 0.0

	local multiplier = math.clamp(1.0 - penalty + rogueBonus, 0.35, 1.25)
	hum.WalkSpeed = BASE_WALKSPEED * multiplier
	hum.JumpPower = spec.DisableJump and 0 or BASE_JUMPPOWER
end

function RelicService.SpawnRelic(tierId: RelicTierId, worldPos: Vector3, initialOwnerUserId: number?): ActiveRelic
	local spec = RelicConfig[tierId] or RelicConfig.MANA_GEODE
	local relicId = NextRelicId
	NextRelicId += 1

	local part = ArtPackVisuals.Mesh(tierId) or Instance.new("Part")
	part.Name = string.format("Relic_%s_%d", tierId, relicId)
	if part:IsA("Part") then part.Shape = (tierId == "CALAMITY_HEART" or tierId == "ABYSSAL_CORE") and Enum.PartType.Ball or Enum.PartType.Block end
	if part:IsA("MeshPart") then part.Size *= ((tierId=="CALAMITY_HEART") and 4.2 or 3.8)/math.max(part.Size.Y,.01)
	else part.Size = (tierId == "CALAMITY_HEART") and Vector3.new(4.2, 4.2, 4.2) or Vector3.new(3.2, 3.8, 3.2) end
	part.Position = Vector3.new(worldPos.X, math.max(3.5, worldPos.Y + 2.2), worldPos.Z)
	part.Color = part:IsA("MeshPart") and Color3.new(1,1,1) or spec.Color
	part.Material = part:IsA("MeshPart") and Enum.Material.SmoothPlastic or Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.Parent = PhysicalRelicsFolder

	local highlight = Instance.new("Highlight")
	highlight.FillColor = spec.Color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 1
	highlight.Parent = part

	-- World-Space Relic Billboard (Doc 4 Section 5.1)
	local bb = Instance.new("BillboardGui")
	bb.Name = "RelicBillboard"
	bb.Size = UDim2.new(0, 210, 0, 68)
	bb.StudsOffset = Vector3.new(0, 4.2, 0)
	bb.MaxDistance = 240
	bb.AlwaysOnTop = (tierId == "CALAMITY_HEART" or tierId == "ABYSSAL_CORE")
	bb.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(14, 14, 22)
	frame.BackgroundTransparency = 0.15
	frame.Parent = bb

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = spec.Color
	stroke.Thickness = 2
	stroke.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -8, 0.42, 0)
	title.Position = UDim2.new(0, 4, 0, 2)
	title.BackgroundTransparency = 1
	title.Text = string.format("💎 %s (%s)", string.upper(spec.DisplayName), spec.Rarity)
	title.TextColor3 = spec.Color
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = frame

	local statusLbl = Instance.new("TextLabel")
	statusLbl.Name = "StatusLabel"
	statusLbl.Size = UDim2.new(1, -8, 0.54, 0)
	statusLbl.Position = UDim2.new(0, 4, 0.44, 0)
	statusLbl.BackgroundTransparency = 1
	statusLbl.Text = string.format("WalkSpeed: -%d%% | Touch to Carry!", math.round(spec.WalkSpeedPenalty * 100))
	statusLbl.TextColor3 = Color3.fromRGB(235, 235, 245)
	statusLbl.Font = Enum.Font.GothamMedium
	statusLbl.TextScaled = true
	statusLbl.Parent = frame

	local now = os.clock()
	local context=assert(Tower.ContextAt(worldPos),"Relic spawn outside room")
	local relic: ActiveRelic = {
		FloorId=context.FloorId,RoomGeneration=context.RoomGeneration,
		RelicId = relicId,
		RewardMultiplier = if context.FloorId > 0 then 1 + 0.05 * (context.FloorId - 1) else 1,
		TierId = tierId,
		Part = part,
		BillboardStatus = statusLbl,
		Weld = nil,
		Carrier = nil,
		LockedUserId = initialOwnerUserId,
		LockExpiresAt = initialOwnerUserId and (now + spec.InitialLockSeconds) or 0,
		DespawnAt = now + spec.DespawnSeconds,
	}

	ActiveRelics[relicId] = relic
	Tower.BroadcastAt(RelicStateRemote,relic,relicId, tierId, "SPAWN", initialOwnerUserId, relic.LockExpiresAt)
	return relic
end

function RelicService.TryPickupRelic(player: Player, relic: ActiveRelic): boolean
	local now = os.clock()
	if Tower.IsTransitioning(player) or not Tower.Same(Tower.GetState(player),relic) or ActiveRelics[relic.RelicId]~=relic or now>=relic.DespawnAt then return false end
	if relic.Carrier ~= nil or CarrierToRelic[player] ~= nil then
		return false
	end
	if player.Character and player.Character:GetAttribute("CarryingLoot") == true then return false end
	if relic.PickupBlockedUserId == player.UserId and now < (relic.PickupBlockedUntil or 0) then return false end
	if now < (PlayerStunnedUntil[player] or 0) then
		return false
	end
	if relic.LockedUserId and relic.LockedUserId ~= player.UserId and now < relic.LockExpiresAt then
		return false
	end
	if player.Character and player.Character:GetAttribute("SquadWiped") == true then
		local dm = getDataManager()
		dm.SendToast(player, "🚫 SQUAD DOWN! You cannot carry relics until you recover your squad at your Waiting Room!", "WARN")
		return false
	end

	local hum, hrp = getCharacterParts(player)
	if not hum or not hrp or hum.Health <= 0 then
		return false
	end
	if (hrp.Position - relic.Part.Position).Magnitude > 9.5 then
		return false
	end

	relic.Part.Anchored = false
	relic.Part.CFrame = hrp.CFrame * CFrame.new(0, 5.2, 0)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = relic.Part
	weld.Parent = relic.Part

	relic.Weld = weld
	relic.Carrier = player
	CarrierToRelic[player] = relic
	Tower.GetState(player).BankArmed = true
	if player.Character then
		player.Character:SetAttribute("CarryingRelic", relic.TierId)
	end

	local dm = getDataManager()
	local spec = RelicConfig[relic.TierId]

	updateMasterMovementAttributes(player, now)
	dm.SendToast(player, string.format("Carrying %s (-%d%% Spd)! Bring to a Floor Safe Sanctuary or your Extraction Pad!", spec.DisplayName, math.round(spec.WalkSpeedPenalty * 100)), "INFO")
	Tower.BroadcastAt(RelicStateRemote,relic,relic.RelicId, relic.TierId, "PICKUP", player.UserId, 0)
	return true
end

function RelicService.DropCarriedRelic(carrier: Player): boolean
	local relic = CarrierToRelic[carrier]
	if not relic then return false end
	Tower.CancelPending(carrier,"CARGO_CHANGED")
	if relic.Weld then
		relic.Weld:Destroy()
		relic.Weld = nil
	end
	local _, root = getCharacterParts(carrier)
	local position = root and (root.Position + root.CFrame.LookVector * 8) or relic.Part.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {carrier.Character or relic.Part, PhysicalRelicsFolder, Workspace.PhysicalLoot}
	local ground = Workspace:Raycast(position + Vector3.new(0, 8, 0), Vector3.new(0, -64, 0), params)
	relic.Part.Anchored = true
	relic.Part.Position = Tower.GroundDrop(relic,position,relic.Part.Size.Y/2)
	relic.Carrier = nil
	CarrierToRelic[carrier] = nil
	relic.LockedUserId = nil
	relic.LockExpiresAt = 0
	relic.PickupBlockedUserId = carrier.UserId
	relic.PickupBlockedUntil = os.clock() + 1.5
	if carrier.Character then carrier.Character:SetAttribute("CarryingRelic", nil) end
	updateMasterMovementAttributes(carrier, os.clock())
	Tower.BroadcastAt(RelicStateRemote,relic,relic.RelicId, relic.TierId, "DROP", carrier.UserId, 0)
	return true
end

function RelicService.FumbleRelicOnAoEHit(carrier: Player)
	local relic = CarrierToRelic[carrier]
	if not relic then
		return
	end

	Tower.CancelPending(carrier,"CARGO_CHANGED")
	local now = os.clock()
	if relic.Weld then
		relic.Weld:Destroy()
		relic.Weld = nil
	end

	local _, hrp = getCharacterParts(carrier)
	local dropPos = hrp and (hrp.Position + Vector3.new(2, 0, 2)) or relic.Part.Position

	relic.Carrier = nil
	CarrierToRelic[carrier] = nil
	if carrier.Character then
		carrier.Character:SetAttribute("CarryingRelic", nil)
	end

	relic.Part.Anchored = true
	relic.Part.Position = Tower.GroundDrop(relic,dropPos,relic.Part.Size.Y/2)
	relic.LockedUserId = carrier.UserId
	relic.LockExpiresAt = now + FUMBLE_OWNER_LOCK_SECONDS

	PlayerStunnedUntil[carrier] = math.max(PlayerStunnedUntil[carrier] or 0, now + FUMBLE_STUN_SECONDS)
	updateMasterMovementAttributes(carrier, now)

	local dm = getDataManager()
	dm.SendToast(carrier, "💥 AoE Hit! Stunned 1.0s & Fumbled Relic (3.0s Owner-Lock before stealable)!", "WARN")
	Tower.BroadcastAt(RelicStateRemote,relic,relic.RelicId, relic.TierId, "FUMBLE", carrier.UserId, relic.LockExpiresAt)
end

local function awardRelicPayout(player: Player, spec: any, scalar: number, rewardMultiplier: number?)
	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	if not profile then
		return
	end
	local marketMult = dm.GetMarketMultiplier and dm.GetMarketMultiplier(player) or 1.0
	local gems = math.round(spec.Payout.Gems * scalar * (rewardMultiplier or 1))
	local gold = math.round(spec.Payout.Gold * scalar * marketMult * (rewardMultiplier or 1))

	profile.Currencies.Gems += gems
	profile.Currencies.Gold += gold

	-- Check Calamity Heart +25% Boss Hero Roll
	if spec.TierId == "CALAMITY_HEART" and math.random() <= 0.25 then
		local uuid, archon = dm.CreateHeroFromSeed("hero_archon", 1.10)
		profile.Heroes[uuid] = archon
		dm.BroadcastToast(string.format("👑 %s extracted THE CALAMITY HEART and rolled 3★ SOVEREIGN ARCHON!", player.DisplayName), "SUCCESS")
	end

	dm.SendToast(
		player,
		string.format("Extracted %s (%d%%): +%d Gems, +%d Gold!", spec.DisplayName, math.round(scalar * 100), gems, gold),
		"SUCCESS"
	)
	dm.SyncProfile(player)
end

local function destroyRelicInstance(relic: ActiveRelic)
	if relic.Carrier then
		local carrier = relic.Carrier
		CarrierToRelic[carrier] = nil
		if carrier.Character then
			carrier.Character:SetAttribute("CarryingRelic", nil)
		end
		relic.Carrier = nil
		updateMasterMovementAttributes(carrier, os.clock())
	end
	if relic.Weld then
		relic.Weld:Destroy()
	end
	if relic.Part then
		relic.Part:Destroy()
	end
	ActiveRelics[relic.RelicId] = nil
end

local function extractAtSanctuary(carrier: Player, floorOnly: boolean?)
	local location = Tower.GetState(carrier)
	if not location.BankArmed or Tower.IsTransitioning(carrier) then return end
	if floorOnly and location.FloorId == 0 then return end
	local relic = CarrierToRelic[carrier]
	if not relic then return end
	local hum, root = getCharacterParts(carrier)
	if not hum or hum.Health <= 0 or not root or relic.Carrier ~= carrier
		or not Tower.Same(location,relic) or os.clock() >= relic.DespawnAt then return end
	local validPad = false
	local event = "EXTRACT_PRIVATE"
	if location.FloorId > 0 then
		validPad = SanctuaryRules.CanExtractFloor(location,relic,Tower.GetSafety(location,root.Position),Tower.IsTransitioning(carrier),os.clock())
		event = "EXTRACT_SAFE_ZONE"
	else
		for _, plot in PlotsFolder:GetChildren() do
			local pad = plot:FindFirstChild("PrivateExtractionPad")
			if plot:GetAttribute("OwnerUserId") == carrier.UserId and pad and pad:IsA("BasePart") then
				local at = pad.CFrame:PointToObjectSpace(root.Position)
				if math.abs(at.X)<=pad.Size.X/2+2 and math.abs(at.Z)<=pad.Size.Z/2+2 and at.Y>=-2 and at.Y<=12 then
					validPad=true
					break
				end
			end
		end
	end
	if not validPad then return end
	local dm = getDataManager()
	if not dm.GetProfile(carrier) then return end
	local spec = RelicConfig[relic.TierId]
	-- Reentrant calls cannot award the same authoritative relic twice.
	CarrierToRelic[carrier]=nil
	ActiveRelics[relic.RelicId]=nil
	awardRelicPayout(carrier,spec,1,relic.RewardMultiplier)
	Tower.BroadcastAt(RelicStateRemote,relic,relic.RelicId,relic.TierId,event,carrier.UserId,0)
	destroyRelicInstance(relic)
end

function RelicService.ExtractInFloorSafeZone(carrier: Player)
	extractAtSanctuary(carrier,true)
end

function RelicService.ExtractOnPrivatePad(carrier: Player)
	extractAtSanctuary(carrier)
end
-- Heartbeat for Relic Pickups, Billboard Timers & Extraction Pad Detection
RunService.Heartbeat:Connect(function()
	local now = os.clock()

	for _, relic in pairs(ActiveRelics) do
		local spec = RelicConfig[relic.TierId]
		if now>=relic.DespawnAt then destroyRelicInstance(relic);continue end
		if relic.Carrier == nil then
			if now >= relic.DespawnAt then
				destroyRelicInstance(relic)
			else
				if relic.BillboardStatus then
					local remDespawn = math.max(0, math.ceil(relic.DespawnAt - now))
					if relic.LockedUserId and now < relic.LockExpiresAt then
						relic.BillboardStatus.Text = string.format("🔒 LOCKED: %.1fs | Despawn: %ds", relic.LockExpiresAt - now, remDespawn)
						relic.BillboardStatus.TextColor3 = Color3.fromRGB(255, 175, 45)
					else
						relic.BillboardStatus.Text = string.format("🔓 STEALABLE NOW! (-%d%% Spd) | %ds", math.round(spec.WalkSpeedPenalty * 100), remDespawn)
						relic.BillboardStatus.TextColor3 = Color3.fromRGB(95, 255, 135)
					end
				end

				for _, player in ipairs(Players:GetPlayers()) do
					local _, hrp = getCharacterParts(player)
					if hrp and (hrp.Position - relic.Part.Position).Magnitude <= 6.8 then
						if RelicService.TryPickupRelic(player, relic) then
							break
						end
					end
				end
			end
		else
			-- Carried relics extract at floor sanctuaries or the owner's Hub pad.
			local carrier = relic.Carrier
			local _, hrp = getCharacterParts(carrier)
			if hrp then
				if relic.BillboardStatus then
					relic.BillboardStatus.Text = string.format("CARRIED BY %s (-%d%% SPD)", carrier.DisplayName, math.round(spec.WalkSpeedPenalty * 100))
					relic.BillboardStatus.TextColor3 = Color3.fromRGB(255, 235, 115)
				end

				RelicService.ExtractOnPrivatePad(carrier)
			end
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if CarrierToRelic[player] or (PlayerStunnedUntil[player] and now <= PlayerStunnedUntil[player] + 0.5) then
			updateMasterMovementAttributes(player, now)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local relic = CarrierToRelic[player]
	if relic then
		RelicService.FumbleRelicOnAoEHit(player)
		relic.LockedUserId = nil
		relic.LockExpiresAt = 0
	end
	PlayerStunnedUntil[player] = nil
end)

Tower.RegisterAdapter("Relic",{
 CaptureCargo=function(player) return CarrierToRelic[player] end,
 DropCargo=function(player)
  local relic=CarrierToRelic[player]
  if relic then RelicService.DropCarriedRelic(player);relic.LockedUserId=nil;relic.LockExpiresAt=0 end
 end,
 Pins=function(id,gen) for _,relic in pairs(ActiveRelics) do if relic.FloorId==id and relic.RoomGeneration==gen then return true end end;return false end,
})
if RunService:IsStudio() then RelicService.DebugRelics=function() return ActiveRelics,CarrierToRelic end end
_G.RelicService = RelicService
