--!strict
-- ServerScriptService/Core/ShopService.server.luau
-- Robux Store purchases (Developer Products, ShopConfig). MarketplaceService.ProcessReceipt is the
-- only place a purchase is granted, and it is idempotent:
--   1. The player must be in this server with a loaded profile, or we answer NotProcessedYet and
--      Roblox retries later (the player is charged only once a receipt is granted).
--   2. The receipt's PurchaseId is claimed in a DataStore with UpdateAsync. If it was already
--      claimed, the purchase was granted before: answer PurchaseGranted without granting again.
--   3. The grant runs; if it fails, the claim is released and we answer NotProcessedYet.
-- Summon packs are paid random items: restricted players get Gems instead (ShopConfig.SafeGrant).
--
-- NOTE: player profiles are not yet saved to a DataStore (DataManager builds a fresh profile on
-- join), so granted items are lost when the player leaves. Keep every ProductId at 0 until
-- profile persistence exists.

local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("ShopConfig"))

local Receipts = DataStoreService:GetDataStore("ShopReceipts_V1")

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

local function withRetries<T>(fn: () -> T): (boolean, T?)
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then return true, result end
		warn(string.format("[ShopService] DataStore call failed (attempt %d): %s", attempt, tostring(result)))
		task.wait(attempt)
	end
	return false, nil
end

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
		profile.Currencies.Gold += g.Amount
		dm.SyncProfile(player)
		return string.format("Purchase complete: +%d Gold!", g.Amount)
	else
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

	-- Claim this PurchaseId exactly once.
	local key = tostring(receipt.PurchaseId)
	local alreadyGranted = false
	local claimed = withRetries(function()
		return Receipts:UpdateAsync(key, function(existing)
			if existing then
				alreadyGranted = true
				return nil -- keep the existing record
			end
			return { UserId = receipt.PlayerId, ProductId = receipt.ProductId, Offer = offer.Id, Time = os.time() }
		end)
	end)
	if not claimed then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if alreadyGranted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, result = pcall(grant, player, offer)
	if not ok then
		warn("[ShopService] Grant failed, releasing the claim: " .. tostring(result))
		withRetries(function()
			return Receipts:RemoveAsync(key)
		end)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	dm.SendToast(player, result :: string, "SUCCESS")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
