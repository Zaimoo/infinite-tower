--!strict
-- ServerScriptService/ExtractionAndSocial/RelicService.server.luau
-- Physical Relic Extraction, Overhead Welding, Fumbles & Private Plot Extraction

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
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
	TierId: RelicTierId,
	Part: BasePart,
	BillboardStatus: TextLabel?,
	Weld: WeldConstraint?,
	Carrier: Player?,
	LockedUserId: number?,
	LockExpiresAt: number,
	DespawnAt: number,
}

local BASE_WALKSPEED = 16.0
local BASE_JUMPPOWER = 50.0
local FUMBLE_STUN_SECONDS = 1.0
local FUMBLE_OWNER_LOCK_SECONDS = 3.0

local ArtPackVisuals = require(ReplicatedStorage.Assets:WaitForChild("ArtPackVisuals"))
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
	local relic: ActiveRelic = {
		RelicId = relicId,
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
	RelicStateRemote:FireAllClients(relicId, tierId, "SPAWN", initialOwnerUserId, relic.LockExpiresAt)
	return relic
end

function RelicService.TryPickupRelic(player: Player, relic: ActiveRelic): boolean
	local now = os.clock()
	if relic.Carrier ~= nil or CarrierToRelic[player] ~= nil then
		return false
	end
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
	if player.Character then
		player.Character:SetAttribute("CarryingRelic", relic.TierId)
	end

	local dm = getDataManager()
	local spec = RelicConfig[relic.TierId]

	updateMasterMovementAttributes(player, now)
	dm.SendToast(player, string.format("Carrying %s (-%d%% Spd)! Bring to your Extraction Pad!", spec.DisplayName, math.round(spec.WalkSpeedPenalty * 100)), "INFO")
	RelicStateRemote:FireAllClients(relic.RelicId, relic.TierId, "PICKUP", player.UserId, 0)
	return true
end

function RelicService.FumbleRelicOnAoEHit(carrier: Player)
	local relic = CarrierToRelic[carrier]
	if not relic then
		return
	end

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
	relic.Part.Position = Vector3.new(dropPos.X, math.max(3.5, dropPos.Y), dropPos.Z)
	relic.LockedUserId = carrier.UserId
	relic.LockExpiresAt = now + FUMBLE_OWNER_LOCK_SECONDS

	PlayerStunnedUntil[carrier] = math.max(PlayerStunnedUntil[carrier] or 0, now + FUMBLE_STUN_SECONDS)
	updateMasterMovementAttributes(carrier, now)

	local dm = getDataManager()
	dm.SendToast(carrier, "💥 AoE Hit! Stunned 1.0s & Fumbled Relic (3.0s Owner-Lock before stealable)!", "WARN")
	RelicStateRemote:FireAllClients(relic.RelicId, relic.TierId, "FUMBLE", carrier.UserId, relic.LockExpiresAt)
end

local function awardRelicPayout(player: Player, spec: any, scalar: number)
	local dm = getDataManager()
	local profile = dm.GetProfile(player)
	if not profile then
		return
	end
	local gems = math.round(spec.Payout.Gems * scalar)
	local gold = math.round(spec.Payout.Gold * scalar)
	local rp = math.round(spec.Payout.ResearchPoints * scalar)

	profile.Currencies.Gems += gems
	profile.Currencies.Gold += gold
	profile.Currencies.ResearchPoints += rp

	-- Check Calamity Heart +25% Boss Hero Roll
	if spec.TierId == "CALAMITY_HEART" and math.random() <= 0.25 then
		local uuid, archon = dm.CreateHeroFromSeed("hero_archon", 1.10)
		profile.Heroes[uuid] = archon
		dm.BroadcastToast(string.format("👑 %s extracted THE CALAMITY HEART and rolled 3★ SOVEREIGN ARCHON!", player.DisplayName), "SUCCESS")
	end

	dm.SendToast(
		player,
		string.format("Extracted %s (%d%%): +%d Gems, +%d Gold, +%d RP!", spec.DisplayName, math.round(scalar * 100), gems, gold, rp),
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

function RelicService.ExtractOnPrivatePad(carrier: Player)
	local relic = CarrierToRelic[carrier]
	if not relic then
		return
	end
	local dm = getDataManager()
	local profile = dm.GetProfile(carrier)
	if not profile then
		return
	end

	local spec = RelicConfig[relic.TierId]
	awardRelicPayout(carrier, spec, 1.00)
	RelicStateRemote:FireAllClients(relic.RelicId, relic.TierId, "EXTRACT_PRIVATE", carrier.UserId, 0)
	destroyRelicInstance(relic)
end

-- Heartbeat for Relic Pickups, Billboard Timers & Extraction Pad Detection
RunService.Heartbeat:Connect(function()
	local now = os.clock()

	for _, relic in pairs(ActiveRelics) do
		local spec = RelicConfig[relic.TierId]
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
			-- Relic is being carried: check Private Extraction Pads on Waiting Room Plots
			local carrier = relic.Carrier
			local _, hrp = getCharacterParts(carrier)
			if hrp then
				if relic.BillboardStatus then
					relic.BillboardStatus.Text = string.format("CARRIED BY %s (-%d%% SPD)", carrier.DisplayName, math.round(spec.WalkSpeedPenalty * 100))
					relic.BillboardStatus.TextColor3 = Color3.fromRGB(255, 235, 115)
				end

				-- Check Private Extraction Pad on Carrier's Plot (or any plot if testing)
				for _, plotModel in ipairs(PlotsFolder:GetChildren()) do
					local ownerId = plotModel:GetAttribute("OwnerUserId")
					if ownerId == carrier.UserId or ownerId == 0 then
						local pad = plotModel:FindFirstChild("PrivateExtractionPad") :: BasePart?
						if pad and (hrp.Position - pad.Position).Magnitude <= 10.5 then
							RelicService.ExtractOnPrivatePad(carrier)
							break
						end
					end
				end
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

_G.RelicService = RelicService
