--!strict
-- ServerScriptService/Core/ShopService.server.luau
-- Robux Store purchases (Developer Products, ShopConfig). MarketplaceService.ProcessReceipt is the
-- only place a purchase is granted, and it is idempotent:
--   1. The player must be in this server with a loaded profile, or we answer NotProcessedYet and
--      Roblox retries later (the player is charged only once a receipt is granted).
--   2. The receipt's PurchaseId is recorded in the profile itself (profile.PurchaseIds) in the same
--      step as the grant. A PurchaseId already there was granted before and is not granted again.
--   3. The profile is saved, and only a successful save answers PurchaseGranted. The grant and its
--      PurchaseId are written together, so they are saved together or lost together: if the save
--      fails or the server dies first, Roblox retries the receipt and it is granted exactly once.
-- Summon packs are paid random items: restricted players get Gems instead (ShopConfig.SafeGrant).

local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ShopConfig"))
local AnvilBanner = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("AnvilBanner"))
local InventoryCapacity = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("InventoryCapacity"))

--============================================================================
-- PERMANENT GAMEPASSES (e.g. Forge Auto-Roll)
--============================================================================
local function verifyPlayerPasses(player: Player)
	for _, pass in pairs(ShopConfig.Passes) do
		local owns = false
		if pass.GamePassId ~= 0 then
			local ok, res = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
			end)
			owns = ok and res == true
		elseif RunService:IsStudio() then
			owns = workspace:GetAttribute("StudioGrantAutoRoll") == true
				or player:GetAttribute("StudioGrantAutoRoll") == true
				or player:GetAttribute(pass.Attribute) == true
		end
		if owns and player.Parent == Players then
			player:SetAttribute(pass.Attribute, true)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(verifyPlayerPasses, player)
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("StudioGrantAutoRoll"):Connect(function()
			verifyPlayerPasses(player)
		end)
	end
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(verifyPlayerPasses, p)
end
if RunService:IsStudio() then
	workspace:GetAttributeChangedSignal("StudioGrantAutoRoll"):Connect(function()
		for _, p in ipairs(Players:GetPlayers()) do
			verifyPlayerPasses(p)
		end
	end)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
	if not wasPurchased or not player or player.Parent ~= Players then
		return
	end
	for _, pass in pairs(ShopConfig.Passes) do
		if pass.GamePassId ~= 0 and pass.GamePassId == gamePassId then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
			end)
			if (ok and owns) or RunService:IsStudio() then
				player:SetAttribute(pass.Attribute, true)
				local dm = _G.DataManager
				if dm and dm.SendToast then
					dm.SendToast(player, pass.Label .. " unlocked!", "SUCCESS")
				end
			end
		end
	end
end)

-- Roblox only retries a receipt that is still pending, so the last few PurchaseIds are enough.
local MAX_PURCHASE_IDS = 100
-- PurchaseIds whose grant is running right now.
local inFlight: { [string]: boolean } = {}

local function dataManager(): any
	return _G.DataManager
end

-- Cached per player; a failed lookup counts as restricted (the safe answer).
local restrictedCache: { [Player]: boolean } = {}
local function paidRandomRestricted(player: Player): boolean
	local cached = restrictedCache[player]
	if cached ~= nil then return cached end
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local restricted = not ok or (info :: any).ArePaidRandomItemsRestricted == true
	restrictedCache[player] = restricted
	return restricted
end
Players.PlayerRemoving:Connect(function(player)
	restrictedCache[player] = nil
end)

-- Applies one grant to the loaded profile. Returns a toast line.
local function grant(player: Player, offer: ShopConfig.Offer): string
	local dm = dataManager()
	local profile = dm.GetProfile(player)
	assert(profile, "profile not loaded")
	local g = ShopConfig.SafeGrant(offer.Grant, paidRandomRestricted(player))
	if g.Kind == "Gems" then
		profile.Currencies.Gems += g.Amount
		dm.SyncProfile(player)
		return string.format("Purchase complete: +%d Gems!", g.Amount)
	elseif g.Kind == "Gold" then
		-- Gold packs scale with the buyer's frontier floor at the moment the receipt is granted.
		local amount = ShopConfig.GrantAmount(offer, profile.HighestClearedFloor)
		profile.Currencies.Gold += amount
		dm.SyncProfile(player)
		return string.format("Purchase complete: +%d Gold!", amount)
	elseif g.Kind == "BattlePass" then
		local message = dm.UnlockPremiumPass(player)
		dm.SyncProfile(player)
		return message
	else
		if AnvilBanner.IsBanner(g.Banner) then
			local cap = InventoryCapacity.ArtifactCap(profile.FortressTree)
			assert(InventoryCapacity.ArtifactCount(profile) + g.Amount <= cap, "Artifact inventory full")
			local summoned, ok, err = dm.RollAnvilSummons(player, g.Amount)
			assert(ok, err or "Gilded Anvil roll failed")
			dm.SyncProfile(player)
			local names = {}
			for _, art in summoned do
				table.insert(names, art.DisplayName)
			end
			return "Pack opened: " .. table.concat(names, ", ")
		end
		local summoned = dm.RollSummons(player, g.Banner or "A_STARS_ARRIVAL", g.Amount)
		dm.SyncProfile(player)
		local names = {}
		for _, hero in summoned do
			table.insert(names, string.format("%s %d★", hero.DisplayName, hero.Stars or 1))
		end
		return "Pack opened: " .. table.concat(names, ", ")
	end
end

MarketplaceService.ProcessReceipt = function(receipt: any): Enum.ProductPurchaseDecision
	local offer = ShopConfig.ByProductId(receipt.ProductId)
	if not offer then
		warn("[ShopService] Unknown ProductId " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local dm = dataManager()
	if not player or not dm or not dm.GetProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retried when they're back
	end

	local profile = dm.GetProfile(player)
	if type(profile.PurchaseIds) ~= "table" then profile.PurchaseIds = {} end
	local purchaseIds: { string } = profile.PurchaseIds
	local purchaseId = tostring(receipt.PurchaseId)

	-- grant can yield (the PolicyService lookup), so a retry of the same receipt arriving meanwhile
	-- is turned away rather than granted a second time.
	if inFlight[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not table.find(purchaseIds, purchaseId) then
		inFlight[purchaseId] = true
		local ok, result = pcall(grant, player, offer)
		inFlight[purchaseId] = nil
		if not ok then
			warn("[ShopService] Grant failed: " .. tostring(result))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(purchaseIds, purchaseId)
		while #purchaseIds > MAX_PURCHASE_IDS do
			table.remove(purchaseIds, 1)
		end
		local robuxSpent = if type(receipt.CurrencySpent) == "number" and receipt.CurrencySpent > 0
			then receipt.CurrencySpent
			else (offer.RobuxPrice or 0)
		if robuxSpent > 0 then
			profile.TotalRobuxDonated = (if type(profile.TotalRobuxDonated) == "number" then profile.TotalRobuxDonated else 0) + robuxSpent
			if (_G :: any).DonatedLeaderboard and (_G :: any).DonatedLeaderboard.AddDonated then
				(_G :: any).DonatedLeaderboard.AddDonated(player.UserId, robuxSpent)
			end
		end
		dm.SendToast(player, result :: string, "SUCCESS")
	end

	-- Studio without API access saves nothing, so there is nothing to wait for.
	if not dm.IsPersistent(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- Confirm only once the grant is saved. On failure the grant stays in this session and Roblox
	-- retries the receipt; the PurchaseId above stops it being granted twice.
	if dm.SaveProfile(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end
