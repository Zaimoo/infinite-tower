--!strict
-- Economy-sensitive Pit operations. Validation and staged commit never yield.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.PitBalanceConfig)
local Math = require(Shared.Util.PitMath)
local Stats = require(Shared.Util.StatFormulas)
local HeroCatalog = require(Shared.Config.HeroCatalog)
local FacilityConfig = require(Shared.Config.FacilityConfig)

local PitService = {}
PitService.__index = PitService

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

-- Canonical encoding is an exact state fingerprint, not a client supplied revision.
local function fingerprint(value: any): string
	if type(value) ~= "table" then return type(value) .. ":" .. tostring(value) end
	local keys = {}
	for key in pairs(value) do table.insert(keys, key) end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local output = { "{" }
	for _, key in ipairs(keys) do
		table.insert(output, fingerprint(key) .. "=" .. fingerprint(value[key]) .. ";")
	end
	table.insert(output, "}")
	return table.concat(output)
end

local function fail(message: string): any
	return { Success = false, Message = message, Reason = message }
end

function PitService.EnsureDefaults(profile: any)
	profile.PitMaterials = profile.PitMaterials or {}
	for _, key in ipairs({ "SoulEssence", "PromotionStone" }) do
		if not finite(profile.PitMaterials[key]) or profile.PitMaterials[key] < 0 then profile.PitMaterials[key] = 0 end
	end
	profile.PitRevision = profile.PitRevision or 0
	profile.UnlockedResearch = profile.UnlockedResearch or {}
	for _, key in ipairs({ "EssenceAttunement", "MemoryStudies", "AdvancedStonecraft", "MasterStonecraft" }) do
		if profile.UnlockedResearch[key] == nil then profile.UnlockedResearch[key] = false end
	end
	for _, hero in pairs(profile.Heroes) do
		if hero.Locked == nil then hero.Locked = false end
		if hero.Favorite == nil then hero.Favorite = false end
		hero.OverflowXP = hero.OverflowXP or 0
		hero.SynthesisHistory = hero.SynthesisHistory or { DonorsConsumed = 0, XPGained = 0, Promotions = 0 }
	end
	profile.SchemaVersion = math.max(profile.SchemaVersion or 1, Config.SchemaVersion)
end

function PitService.new(dependencies: any): any
	return setmetatable({ Dependencies = dependencies, Locks = {}, Previews = {}, LastPreview = {}, LastState = {}, LastLock = {}, PreparedProfiles = {}, CombatGrants = {} }, PitService)
end

function PitService:Prepare(player: any, profile: any)
	if self.PreparedProfiles[player] ~= profile or (profile.SchemaVersion or 1) < Config.SchemaVersion then
		PitService.EnsureDefaults(profile)
		self.PreparedProfiles[player] = profile
	end
end

function PitService:Now(): number
	return self.Dependencies.Clock and self.Dependencies.Clock() or os.clock()
end

-- Mirror heroes copy the Master's best normal hero, so every roster keeps at least one normal hero (gilded-mirror-plan §2.2).
PitService.LastNormalHeroReason = "Your last normal hero can't be used. Mirror heroes copy it."
local function normalHeroCount(profile: any, excluded: { [string]: boolean }?): number
	local count = 0
	for uuid, hero in pairs(profile.Heroes) do
		if not Stats.IsMirror(hero) and not (excluded and excluded[uuid]) then count += 1 end
	end
	return count
end

function PitService:DonorStatus(profile: any, hero: any, recipientUUID: string?): any
	local reason, status = "", "Available"
	local seed = HeroCatalog.Seeds[hero.TemplateId]
	if hero.UUID == recipientUUID then reason, status = "Already the recipient.", "Recipient"
	elseif not Stats.IsMirror(hero) and normalHeroCount(profile) <= 1 then reason, status = PitService.LastNormalHeroReason, "Protected"
	elseif not seed or seed.BannerOrigin == "WORLD_BOSS" or (hero.Stars or 1) > 7 or hero.Unique or hero.IsUnique or hero.Protected then
		reason, status = "Unique heroes can't be used.", "Protected"
	elseif hero.Locked or hero.Favorite or hero.Favorited then reason, status = "Locked. Unlock it first.", "Locked"
	elseif (hero.ComaUntilTimestamp or 0) > os.time() or hero.IsHardAuditComa then reason, status = "Recovering from Coma.", "Recovering"
	elseif hero.ReservedBy ~= nil or hero.Reserved or hero.OperationReserved or hero.ReservedOperationId ~= nil then reason, status = "In use elsewhere.", "Reserved"
	elseif hero.InCombat or hero.IsInCombat or hero.ActiveCombat then reason, status = "In combat.", "Deployed"
	elseif hero.Assignment ~= "BENCHED" then
		if string.sub(hero.Assignment or "", 1, 8) == "FACILITY" then reason, status = "Working at a facility. Unassign it first.", "Stationed"
		else reason, status = "In your squad. Bench it first.", "Deployed" end
	end
	-- Validate redundant indexes as well as the hero's assignment flag.
	if reason == "" then
		for _, uuid in ipairs(profile.DeployedSquadOrder or {}) do
			if uuid == hero.UUID then reason, status = "In your squad. Bench it first.", "Deployed" break end
		end
	end
	if reason == "" then
		for _, facility in pairs(profile.Facilities or {}) do
			for _, uuid in ipairs(facility.AssignedHeroUUIDs or {}) do
				if uuid == hero.UUID then reason, status = "Working at a facility. Unassign it first.", "Facility Worker" break end
			end
			if reason ~= "" then break end
		end
	end
	if reason == "" and profile.ReservedHeroUUIDs and profile.ReservedHeroUUIDs[hero.UUID] then reason, status = "In use elsewhere.", "Reserved" end
	return { EligibleDonor = reason == "", Reason = reason, Status = status }
end

function PitService:RecipientStatus(profile: any, hero: any): any
	if hero.ReservedBy or hero.Reserved or hero.OperationReserved or hero.ReservedOperationId or (profile.ReservedHeroUUIDs or {})[hero.UUID] then
		return { Eligible = false, Reason = "Reserved by another operation" }
	end
	if (hero.ComaUntilTimestamp or 0) > os.time() or hero.IsHardAuditComa then
		return { Eligible = false, Reason = "Recovering from coma" }
	end
	if Stats.IsMirror(hero) then
		return { Eligible = false, Reason = "Mirror heroes don't level." }
	end
	return { Eligible = true, Reason = "Ready to receive EXP" }
end

function PitService:State(profile: any): any
	local heroes = {}
	for uuid, hero in pairs(profile.Heroes) do
		local copy = Math.Copy(hero)
		copy.PitStatus = self:DonorStatus(profile, hero)
		copy.RecipientStatus = self:RecipientStatus(profile, hero)
		copy.Stats = Math.Snapshot(hero, profile)
		copy.SynthesisXPValue = Config.Synthesis.BaseXP * Config.Synthesis.StarMultiplier ^ (hero.Stars - 1) + Config.Synthesis.LevelXP * Stats.GetEffectiveLevel(hero.Stars, hero.Level)
		heroes[uuid] = copy
	end
	local resources = Math.Copy(profile.Currencies)
	for key, amount in pairs(profile.PitMaterials) do resources[key] = amount end
	return { Heroes = heroes, Currencies = Math.Copy(profile.Currencies), Materials = Math.Copy(profile.PitMaterials), Resources = resources,
		UnlockedResearch = Math.Copy(profile.UnlockedResearch), Revision = profile.PitRevision, MaxDonors = Config.MaxDonors,
		Recipes = Math.Copy(Config.Recipes), Research = Math.Copy(FacilityConfig.TechNodes), Facilities = Math.Copy(profile.Facilities),
		SessionOnly = true }
end

function PitService:Delta(profile: any, changed: any, removed: any): any
	local heroes = {}
	for uuid, hero in pairs(changed) do
		local copy = Math.Copy(hero)
		copy.PitStatus = self:DonorStatus(profile, hero)
		copy.RecipientStatus = self:RecipientStatus(profile, hero)
		copy.Stats = Math.Snapshot(hero, profile)
		copy.SynthesisXPValue = Config.Synthesis.BaseXP * Config.Synthesis.StarMultiplier ^ (hero.Stars - 1) + Config.Synthesis.LevelXP * Stats.GetEffectiveLevel(hero.Stars, hero.Level)
		heroes[uuid] = copy
	end
	local resources = Math.Copy(profile.Currencies)
	for key, amount in pairs(profile.PitMaterials) do resources[key] = amount end
	return { Heroes = heroes, Removed = Math.Copy(removed), Currencies = Math.Copy(profile.Currencies),
		Materials = Math.Copy(profile.PitMaterials), Resources = resources, UnlockedResearch = Math.Copy(profile.UnlockedResearch), Revision = profile.PitRevision }
end

-- What the player confirmed, as an exact fingerprint: who is consumed, what is paid and what the
-- recipient gains. A commit goes through while a fresh Build still produces this outcome, so income
-- ticking in (Guard Post Gold, combat EXP short of a level-up, stamina) no longer voids a preview.
function PitService:Outcome(request: any, preview: any): string
	local donors, unequips = {}, {}
	for _, donor in ipairs(preview.Donors or {}) do table.insert(donors, donor.UUID) end
	for _, entry in ipairs(preview.Unequips or {}) do table.insert(unequips, entry.ArtifactUUID) end
	local xp, after = preview.XP, preview.After
	return fingerprint({ Action = request.Action, Recipient = request.Recipient or false, Recipe = request.Recipe or false,
		Donors = donors, Unequips = unequips, Costs = preview.Costs or {}, Rewards = preview.Rewards or {},
		XP = if xp then { Final = xp.Final, Applied = xp.Applied or false } else false,
		Level = after and after.Level or false, Stars = after and after.Stars or false,
		Rare = preview.RequiresRareConfirmation == true, Overflow = preview.RequiresOverflowConfirmation == true })
end

function PitService:Build(profile: any, request: any): (any, any)
	local action = request.Action
	local preview = { Action = action, CanCommit = true, Reason = "", Donors = {}, Costs = {}, Rewards = {}, Warnings = {}, Errors = {},
		Requirements = {}, Unequips = {}, RequiresRareConfirmation = false, SuccessChance = 1 }
	local staged = { Heroes = {}, Remove = {}, Unequip = {}, Currencies = Math.Copy(profile.Currencies), Materials = Math.Copy(profile.PitMaterials) }
	local function reject(reason: string)
		preview.CanCommit = false
		if preview.Reason == "" then preview.Reason = reason end
		table.insert(preview.Errors, reason)
	end
	local recipient = request.Recipient and profile.Heroes[request.Recipient]
	if action ~= "CONVERSION" and action ~= "CRAFT" then
		if not recipient then reject("Choose an owned recipient hero.")
		else
			preview.Recipient = Math.Copy(recipient)
			preview.Before = Math.Snapshot(recipient, profile)
			preview.After = Math.Copy(preview.Before)
			if recipient.ReservedBy or recipient.Reserved or recipient.OperationReserved or recipient.ReservedOperationId or (profile.ReservedHeroUUIDs or {})[recipient.UUID] then reject("This hero is in use elsewhere.") end
			if (recipient.ComaUntilTimestamp or 0) > os.time() or recipient.IsHardAuditComa then reject("This hero is recovering from Coma.") end
		end
	end
	local donorIds = request.Donors or {}
	local needsDonors = action == "SYNTHESIS" or action == "CONVERSION"
	if needsDonors then
		if #donorIds == 0 or #donorIds > Config.MaxDonors then reject("Select between 1 and " .. Config.MaxDonors .. " donors.") end
		local seen = {}
		for _, uuid in ipairs(donorIds) do
			local donor = profile.Heroes[uuid]
			if seen[uuid] then reject("Each donor must be a different hero instance.")
			elseif not donor then reject("A selected donor is no longer in your roster.")
			else
				local eligibility = self:DonorStatus(profile, donor, request.Recipient)
				if not eligibility.EligibleDonor then reject(donor.DisplayName .. ": " .. eligibility.Reason) end
				table.insert(preview.Donors, Math.Copy(donor))
				table.insert(staged.Remove, uuid)
				-- A consumed hero hands its weapon back to the backpack.
				local artifactUUID = donor.EquippedArtifactUUID
				if artifactUUID ~= nil and artifactUUID ~= "" then
					local artifact = profile.Artifacts and profile.Artifacts[artifactUUID]
					table.insert(staged.Unequip, artifactUUID)
					table.insert(preview.Unequips, { ArtifactUUID = artifactUUID, Hero = donor.DisplayName,
						Artifact = artifact and artifact.DisplayName or "Weapon" })
				end
				if Math.EffectiveStars(donor) >= Config.RareConfirmationStars then preview.RequiresRareConfirmation = true end
			end
			seen[uuid] = true
		end
		-- Several donors together must not use up the last normal hero either.
		local removing = {}
		for _, uuid in ipairs(staged.Remove) do removing[uuid] = true end
		if #staged.Remove > 0 and normalHeroCount(profile, removing) == 0 then reject(PitService.LastNormalHeroReason) end
	elseif #donorIds > 0 then reject("This doesn't use heroes. Clear the selection.") end

	if action == "SYNTHESIS" then
		if recipient and Stats.IsMirror(recipient) then
			reject("Mirror heroes don't level. Promote them instead.")
		elseif recipient then
			local maxLevel = Stats.GetMaxLevel(recipient.Stars)
			if (recipient.Level or 1) >= maxLevel then
				reject("Max level. Promote to raise the cap.")
			end

			local xp = { Base = 0, Final = 0, Efficiency = 1, ResearchBonus = 0, Breakdown = {} }
			local reachedCapIndex: number? = nil

			for index, donor in ipairs(preview.Donors) do
				if reachedCapIndex ~= nil then
					reject("Too many materials: the level cap is reached early. Remove some.")
					break
				end

				local breakdown = Math.GetSynthesisXP(donor, recipient, profile.UnlockedResearch)
				breakdown.UUID, breakdown.Name = donor.UUID, donor.DisplayName
				xp.Base += breakdown.Base
				xp.Final += breakdown.Final
				xp.ResearchBonus = breakdown.ResearchBonus
				table.insert(xp.Breakdown, breakdown)

				local simAfter, _ = Math.AdvanceXP(recipient, xp.Final)
				if (simAfter.Level or 1) >= maxLevel then
					reachedCapIndex = index
				end
			end
			preview.Mode = "Essence Synthesis"
			if xp.Base > 0 then
				local weighted = 0
				for _, part in ipairs(xp.Breakdown) do weighted += part.Base * part.Efficiency end
				xp.Efficiency = weighted / xp.Base
			end
			if xp.Efficiency < 1 then table.insert(preview.Warnings, "Low-level materials give reduced EXP.") end
			local after, overflow = Math.AdvanceXP(recipient, xp.Final)
			if (after.Level or 1) >= maxLevel then
				after.Level = maxLevel
				after.XP = 0
			end
			xp.Applied = xp.Final
			if overflow.Rejected > 0 then
				preview.RequiresOverflowConfirmation = true
				-- Legacy heroes may already have excess EXP. Count only this award's loss.
				local discarded = math.min(xp.Final, overflow.Rejected)
				xp.Applied -= discarded
				table.insert(preview.Warnings, string.format("%d EXP is over the cap and will be lost.", discarded))
			end
			if after.OverflowXP > (recipient.OverflowXP or 0) then table.insert(preview.Warnings, "Extra EXP is kept for after promotion.") end
			after.SynthesisHistory.DonorsConsumed = (after.SynthesisHistory.DonorsConsumed or 0) + #preview.Donors
			after.SynthesisHistory.XPGained = (after.SynthesisHistory.XPGained or 0) + xp.Applied
			preview.XP, preview.Overflow, preview.After = xp, overflow, Math.Snapshot(after, profile)
			-- Synthesis costs Gold for the EXP it applies (EXP lost over the cap is not charged).
			local gold = Math.GetSynthesisGoldCost(xp.Applied)
			if gold > 0 then preview.Costs = { Gold = gold } end
			staged.Heroes[recipient.UUID] = after
		end
	elseif action == "CONVERSION" then
		local essence = 0
		for _, donor in ipairs(preview.Donors) do essence += Math.GetConversionYield(donor) end
		preview.Rewards = { SoulEssence = essence }
	elseif action == "PROMOTION" then
		if recipient then
			local rule = Config.Promotion[recipient.Stars]
			if recipient.Stars >= Config.MaxStars or not rule then reject("This hero has reached the maximum " .. Config.MaxStars .. "★ rank.")
			else
				preview.Costs = { Gold = rule.Gold, PromotionStone = rule.PromotionStone }
				-- Mirror heroes don't level, so they promote without a level requirement (+2% mirror per star).
				local mirror = Stats.IsMirror(recipient)
				preview.Requirements = if mirror then {} else { { Label = "Reach the current level cap", Current = recipient.Level, Required = Stats.GetMaxLevel(recipient.Stars), Met = recipient.Level >= Stats.GetMaxLevel(recipient.Stars) } }
				if rule.Research then
					table.insert(preview.Requirements, { Label = rule.Research == "MasterStonecraft" and "Master Stonecraft" or "Advanced Stonecraft",
						Current = profile.UnlockedResearch[rule.Research] and 1 or 0, Required = 1, Met = profile.UnlockedResearch[rule.Research] == true })
				end
				if not mirror and recipient.Level < Stats.GetMaxLevel(recipient.Stars) then reject("Reach Level " .. Stats.GetMaxLevel(recipient.Stars) .. " to unlock promotion.") end
				if rule.Research and not profile.UnlockedResearch[rule.Research] then reject("Unlock " .. (rule.Research == "MasterStonecraft" and "Master Stonecraft" or "Advanced Stonecraft") .. " in the Dimensional Lab.") end
				local after, overflow = Math.Promote(recipient)
				after.SynthesisHistory.Promotions = (after.SynthesisHistory.Promotions or 0) + 1
				preview.After, preview.Overflow = Math.Snapshot(after, profile), overflow
				staged.Heroes[recipient.UUID] = after
			end
		end
	elseif action == "CRAFT" then
		local recipe = Config.Recipes[request.Recipe]
		if not recipe then reject("Choose a valid crafting recipe.")
		else
			preview.Recipe = request.Recipe
			preview.Costs = { Gold = recipe.Gold, Gems = recipe.Gems, SoulEssence = recipe.SoulEssence }
			preview.Rewards = { [request.Recipe] = recipe.Output }
		end
	else reject("Choose a valid Pit operation.") end

	for currency, amount in pairs(preview.Costs) do
		local bucket = if staged.Currencies[currency] ~= nil then staged.Currencies else staged.Materials
		if not finite(bucket[currency]) or bucket[currency] < amount then reject("Not enough " .. currency:gsub("(%l)(%u)", "%1 %2") .. ".")
		else bucket[currency] -= amount end
	end
	for currency, amount in pairs(preview.Rewards) do
		local bucket = if staged.Currencies[currency] ~= nil then staged.Currencies else staged.Materials
		bucket[currency] = (bucket[currency] or 0) + amount
	end
	if #preview.Unequips > 0 then
		table.insert(preview.Warnings, if #preview.Unequips == 1
			then string.format("%s's %s returns to your backpack.", preview.Unequips[1].Hero, preview.Unequips[1].Artifact)
			else string.format("%d weapons return to your backpack.", #preview.Unequips))
	end
	if preview.RequiresRareConfirmation then table.insert(preview.Warnings, "Rare heroes will be consumed for good.") end
	return preview, staged
end

local function normalizeRequest(payload: any): (any?, string?)
	if type(payload) ~= "table" or type(payload.Action) ~= "string" then return nil, "Choose a Pit operation." end
	local allowed = { SYNTHESIS = true, PROMOTION = true, CONVERSION = true, CRAFT = true }
	if not allowed[payload.Action] then return nil, "Unknown Pit operation." end
	if payload.Recipient ~= nil and (type(payload.Recipient) ~= "string" or #payload.Recipient > 80) then return nil, "Invalid recipient." end
	if payload.Recipe ~= nil and (type(payload.Recipe) ~= "string" or #payload.Recipe > 80) then return nil, "Invalid recipe." end
	if payload.Donors ~= nil and type(payload.Donors) ~= "table" then return nil, "Choose valid donor heroes." end
	local donors = {}
	local count = 0
	for key, value in pairs(payload.Donors or {}) do
		count += 1
		if count > Config.MaxDonors or type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > Config.MaxDonors or type(value) ~= "string" or #value > 80 then return nil, "Choose up to " .. Config.MaxDonors .. " valid donors." end
	end
	for index = 1, count do
		if type(payload.Donors[index]) ~= "string" then return nil, "Choose valid donor heroes." end
		table.insert(donors, payload.Donors[index])
	end
	return { Action = payload.Action, Recipient = payload.Recipient, Donors = donors, Recipe = payload.Recipe }, nil
end

function PitService:Request(player: any, command: any, payload: any): any
	if self.Locks[player] then return fail("Still working. Please wait a moment.") end
	self.Locks[player] = true
	local ok, response = pcall(function()
		local profile = self.Dependencies.GetProfile(player)
		if not profile then return fail("Your roster is still loading. Try again shortly.") end
		if command == "STATE" then
			local now = self:Now()
			if self.LastState[player] and now - self.LastState[player] < Config.StateCooldown then return fail("Please wait a moment.") end
			self.LastState[player] = now
			self:Prepare(player, profile)
			return { Success = true, State = self:State(profile) }
		end
		if command == "LOCK" then
			local now = self:Now()
			if self.LastLock[player] and now - self.LastLock[player] < Config.LockCooldown then return fail("Please wait a moment.") end
			self.LastLock[player] = now
			self:Prepare(player, profile)
			if type(payload) ~= "table" or type(payload.Hero) ~= "string" or type(payload.Locked) ~= "boolean" then return fail("Choose an owned hero and a valid protection setting.") end
			local hero = profile.Heroes[payload.Hero]
			if not hero then return fail("This hero is no longer in your roster.") end
			if hero.TemplateId == "hero_archon" or hero.Unique or hero.IsUnique or hero.Protected then return fail("Unique heroes remain protected.") end
			hero.Locked = payload.Locked
			if not payload.Locked then
				-- The unified protection control is a deliberate unlock action.
				hero.Favorite = false
				if hero.Favorited ~= nil then hero.Favorited = false end
			end
			profile.PitRevision += 1
			self.Previews[player] = nil
			pcall(self.Dependencies.SyncProfile, player, { [hero.UUID] = hero }, {})
			local deltaOK, delta = pcall(function() return self:Delta(profile, { [hero.UUID] = hero }, {}) end)
			return { Success = true, Message = payload.Locked and "Hero protected." or "Hero unlocked.", Delta = deltaOK and delta or nil }
		end
		if command == "PREVIEW" then
			local now = self:Now()
			if self.LastPreview[player] and now - self.LastPreview[player] < Config.PreviewCooldown then return fail("Please wait a moment.") end
			self.LastPreview[player] = now
			self:Prepare(player, profile)
			self.Previews[player] = nil
			local request, reason = normalizeRequest(payload)
			if not request then return fail(reason or "Invalid operation.") end
			local preview = self:Build(profile, request)
			if preview.CanCommit then
				local token = self.Dependencies.GenerateToken()
				local expires = now + Config.PreviewLifetime
				self.Previews[player] = { Token = token, ExpiresAt = expires, Request = request, Outcome = self:Outcome(request, preview) }
				preview.Token, preview.ExpiresAt = token, expires
			end
			return { Success = true, Preview = preview }
		end
		if command == "COMMIT" then
			self:Prepare(player, profile)
			local stored = self.Previews[player]
			-- Remove before validation: a confirmation token is always single-use.
			self.Previews[player] = nil
			local function stale(message: string): any
				local response = fail(message)
				response.Stale = true -- the client refreshes its preview instead of showing an error
				return response
			end
			if type(payload) ~= "table" or type(payload.Token) ~= "string" or not stored or stored.Token ~= payload.Token then return stale("Preview out of date.") end
			if self:Now() > stored.ExpiresAt then return stale("Preview expired.") end
			local preview, staged = self:Build(profile, stored.Request)
			if not preview.CanCommit then return fail(preview.Reason) end
			if stored.Outcome ~= self:Outcome(stored.Request, preview) then return stale("The result changed. Check it and confirm again.") end
			if preview.RequiresRareConfirmation and payload.ConfirmRare ~= true then return fail("Confirm the rare hero warning first.") end
			if preview.RequiresOverflowConfirmation and payload.ConfirmOverflow ~= true then return fail("Confirm the EXP cap warning first.") end
			-- All possible failures precede these assignments. Preserve unrelated
			-- profile fields and do not yield between deductions and roster updates.
			for _, artifactUUID in ipairs(staged.Unequip) do
				local artifact = profile.Artifacts and profile.Artifacts[artifactUUID]
				if artifact then artifact.EquippedHeroUUID = nil end
			end
			for _, uuid in ipairs(staged.Remove) do profile.Heroes[uuid] = nil end
			for uuid, hero in pairs(staged.Heroes) do profile.Heroes[uuid] = hero end
			profile.Currencies = staged.Currencies
			profile.PitMaterials = staged.Materials
			profile.PitRevision += 1
			local messages = { SYNTHESIS = "Synthesis complete.", PROMOTION = "Promotion complete!", CONVERSION = "Converted to Soul Essence.", CRAFT = "Crafting complete." }
			-- Replication failure cannot turn a committed transaction into a false
			-- failure; STATE can always recover the authoritative result.
			pcall(self.Dependencies.SyncProfile, player, staged.Heroes, staged.Remove)
			-- Returned weapons live outside the hero delta: push the whole profile so the Forge sees them.
			if #staged.Unequip > 0 and self.Dependencies.SyncArtifacts then pcall(self.Dependencies.SyncArtifacts, player) end
			local deltaOK, delta = pcall(function() return self:Delta(profile, staged.Heroes, staged.Remove) end)
			return { Success = true, Message = messages[stored.Request.Action], Result = preview, Delta = deltaOK and delta or nil }
		end
		return fail("Unknown Pit request.")
	end)
	self.Locks[player] = nil
	if not ok then
		warn("[The Pit] Request failed: " .. tostring(response))
		return fail("That didn't go through. Try again.")
	end
	return response
end

function PitService:GrantCombatXP(player: any, uuid: string, amount: number): (boolean, any)
	if self.Locks[player] or not finite(amount) or amount <= 0 then return false, "Invalid combat EXP grant." end
	local profile = self.Dependencies.GetProfile(player)
	if not profile then return false, "Profile not loaded." end
	self:Prepare(player, profile)
	local hero = profile.Heroes[uuid]
	if hero and Stats.IsMirror(hero) then return false, "Mirror heroes don't level." end
	if not hero or not string.find(hero.Assignment, "^SQUAD_SLOT_") or (hero.CurrentStamina or 0) <= 0 or (hero.ComaUntilTimestamp or 0) > os.time() then return false, "Hero is not an active combat participant." end
	local key = tostring(player) .. ":" .. uuid
	local now = self:Now()
	if self.CombatGrants[key] and now - self.CombatGrants[key] < Config.CombatXP.Cooldown then return false, "Combat EXP cooldown." end
	local awarded = math.min(Config.CombatXP.MaxGrant, math.floor(amount))
	if awarded <= 0 then return false, "Invalid combat EXP grant." end
	local after, overflow = Math.AdvanceXP(hero, awarded)
	-- Cap combat awards to the available reserve. No donor investment is lost.
	if overflow.Rejected >= awarded then return false, "The hero's EXP reserve is full." end
	local result = { Before = Math.Snapshot(hero, profile), After = Math.Snapshot(after, profile), Overflow = overflow }
	self.Locks[player] = true
	self.CombatGrants[key] = now
	profile.Heroes[uuid] = after
	profile.PitRevision += 1
	if self.Dependencies.SyncCombatXP then pcall(self.Dependencies.SyncCombatXP, player, uuid, after) end
	self.Locks[player] = nil
	return true, result
end

function PitService:Forget(player: any)
	self.Locks[player], self.Previews[player], self.LastPreview[player] = nil, nil, nil
	self.LastState[player], self.LastLock[player], self.PreparedProfiles[player] = nil, nil, nil
	local prefix = tostring(player) .. ":"
	for key in pairs(self.CombatGrants) do if string.sub(key, 1, #prefix) == prefix then self.CombatGrants[key] = nil end end
end

return PitService
