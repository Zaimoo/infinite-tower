--!strict
-- Economy-sensitive Pit operations. Validation and staged commit never yield.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.PitBalanceConfig)
local Math = require(Shared.Util.PitMath)
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
	for _, key in ipairs({ "SoulEssence", "PromotionStone", "ImprintCatalyst" }) do
		if not finite(profile.PitMaterials[key]) or profile.PitMaterials[key] < 0 then profile.PitMaterials[key] = 0 end
	end
	profile.PitRevision = profile.PitRevision or 0
	profile.UnlockedResearch = profile.UnlockedResearch or {}
	for _, key in ipairs({ "EssenceAttunement", "MemoryStudies", "AdvancedStonecraft", "MasterStonecraft" }) do
		if profile.UnlockedResearch[key] == nil then profile.UnlockedResearch[key] = false end
	end
	-- These fields were missing even on old default social profiles.
	if profile.Social then profile.Social.GarnishedGemDebt = profile.Social.GarnishedGemDebt or 0 end
	for _, hero in pairs(profile.Heroes) do
		if hero.Locked == nil then hero.Locked = false end
		if hero.Favorite == nil then hero.Favorite = false end
		hero.InheritedImprints = hero.InheritedImprints or {}
		hero.OverflowXP = hero.OverflowXP or 0
		hero.SynthesisHistory = hero.SynthesisHistory or { DonorsConsumed = 0, XPGained = 0, ImprintsPerformed = 0, Promotions = 0 }
		hero.ImprintCapacity = Math.GetImprintCapacity(hero)
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

function PitService:DonorStatus(profile: any, hero: any, recipientUUID: string?): any
	local reason, status = "", "Available"
	local seed = HeroCatalog.Seeds[hero.TemplateId]
	if hero.UUID == recipientUUID then reason, status = "A hero cannot be its own donor.", "Recipient"
	elseif not seed or hero.TemplateId == "hero_archon" or seed.BannerOrigin ~= "STANDARD" or hero.Unique or hero.IsUnique or hero.Protected then
		reason, status = "This unique hero is protected from consumption.", "Protected"
	elseif hero.Locked or hero.Favorite or hero.Favorited then reason, status = "This hero is protected. Unlock it deliberately before using it.", "Locked"
	elseif (hero.ComaUntilTimestamp or 0) > os.time() or hero.IsHardAuditComa then reason, status = "This hero must recover from Coma first.", "Recovering"
	elseif hero.ReservedBy ~= nil or hero.Reserved or hero.OperationReserved or hero.ReservedOperationId ~= nil then reason, status = "This hero is reserved by another operation.", "Reserved"
	elseif hero.InCombat or hero.IsInCombat or hero.ActiveCombat then reason, status = "This hero is in active combat.", "Deployed"
	elseif hero.Assignment ~= "BENCHED" then
		if string.sub(hero.Assignment or "", 1, 8) == "FACILITY" then reason, status = "Assign this hero to the Waiting Room before using it as a donor.", "Facility Worker"
		else reason, status = "Bench this deployed hero before using it as a donor.", "Deployed" end
	end
	-- Validate redundant indexes as well as the hero's assignment flag.
	if reason == "" then
		for _, uuid in ipairs(profile.DeployedSquadOrder or {}) do
			if uuid == hero.UUID then reason, status = "This hero is still deployed. Bench it in the roster.", "Deployed" break end
		end
	end
	if reason == "" then
		for _, facility in pairs(profile.Facilities or {}) do
			for _, uuid in ipairs(facility.AssignedHeroUUIDs or {}) do
				if uuid == hero.UUID then reason, status = "Unassign this facility worker before using it as a donor.", "Facility Worker" break end
			end
			if reason ~= "" then break end
		end
	end
	if reason == "" and profile.ReservedHeroUUIDs and profile.ReservedHeroUUIDs[hero.UUID] then reason, status = "This hero is reserved by another operation.", "Reserved" end
	return { EligibleDonor = reason == "", Reason = reason, Status = status }
end

function PitService:State(profile: any): any
	local heroes = {}
	for uuid, hero in pairs(profile.Heroes) do
		local copy = Math.Copy(hero)
		copy.PitStatus = self:DonorStatus(profile, hero)
		copy.Stats = Math.Snapshot(hero, profile)
		copy.SynthesisXPValue = Config.Synthesis.BaseXP * Config.Synthesis.StarMultiplier ^ (hero.Stars - 1) + Config.Synthesis.LevelXP * hero.Level
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
		copy.Stats = Math.Snapshot(hero, profile)
		copy.SynthesisXPValue = Config.Synthesis.BaseXP * Config.Synthesis.StarMultiplier ^ (hero.Stars - 1) + Config.Synthesis.LevelXP * hero.Level
		heroes[uuid] = copy
	end
	local resources = Math.Copy(profile.Currencies)
	for key, amount in pairs(profile.PitMaterials) do resources[key] = amount end
	return { Heroes = heroes, Removed = Math.Copy(removed), Currencies = Math.Copy(profile.Currencies),
		Materials = Math.Copy(profile.PitMaterials), Resources = resources, UnlockedResearch = Math.Copy(profile.UnlockedResearch), Revision = profile.PitRevision }
end

function PitService:Fingerprint(profile: any, request: any): string
	local heroes = {}
	local ids = Math.Copy(request.Donors or {})
	if request.Recipient then table.insert(ids, request.Recipient) end
	for _, uuid in ipairs(ids) do
		local copy = Math.Copy(profile.Heroes[uuid])
		if copy then
			-- Stamina only affects this operation at exhaustion. Ordinary regeneration
			-- must not invalidate a confirmation every second.
			copy.IsExhausted = (copy.CurrentStamina or 100) <= 0
			copy.CurrentStamina = nil
		end
		heroes[uuid] = copy or false
	end
	local assignments = {}
	for key, facility in pairs(profile.Facilities or {}) do assignments[key] = facility.AssignedHeroUUIDs end
	return fingerprint({ Request = request, Heroes = heroes, Currencies = profile.Currencies, Materials = profile.PitMaterials,
		Research = profile.UnlockedResearch, Deployed = profile.DeployedSquadOrder, Facilities = assignments,
		Reserved = profile.ReservedHeroUUIDs or {} })
end

function PitService:Build(profile: any, request: any): (any, any)
	local action = request.Action
	local preview = { Action = action, CanCommit = true, Reason = "", Donors = {}, Costs = {}, Rewards = {}, Warnings = {}, Errors = {},
		Requirements = {}, Imprints = {}, RequiresRareConfirmation = false, SuccessChance = 1 }
	local staged = { Heroes = {}, Remove = {}, Currencies = Math.Copy(profile.Currencies), Materials = Math.Copy(profile.PitMaterials) }
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
			if recipient.ReservedBy or recipient.Reserved or recipient.OperationReserved or recipient.ReservedOperationId or (profile.ReservedHeroUUIDs or {})[recipient.UUID] then reject("The recipient is reserved by another operation.") end
			if (recipient.ComaUntilTimestamp or 0) > os.time() or recipient.IsHardAuditComa then reject("The recipient must recover from Coma first.") end
		end
	end
	local donorIds = request.Donors or {}
	local needsDonors = action == "SYNTHESIS" or action == "IMPRINT" or action == "CONVERSION"
	if needsDonors then
		if #donorIds == 0 or #donorIds > Config.MaxDonors then reject("Select between 1 and " .. Config.MaxDonors .. " donors.") end
		if action == "IMPRINT" and #donorIds ~= 1 then reject("Focused Imprint requires exactly one donor.") end
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
				if donor.Stars >= Config.RareConfirmationStars then preview.RequiresRareConfirmation = true end
			end
			seen[uuid] = true
		end
	elseif action == "PROMOTION" and #donorIds > 0 then
		local seen = {}
		for _, uuid in ipairs(donorIds) do
			local donor = profile.Heroes[uuid]
			if seen[uuid] then reject("Each sacrifice material must be a different hero instance.")
			elseif not donor then reject("A selected sacrifice material is no longer in your roster.")
			elseif recipient and donor.Stars ~= recipient.Stars then reject("Sacrifice materials must be the same rank (" .. recipient.Stars .. "★).")
			else
				local eligibility = self:DonorStatus(profile, donor, request.Recipient)
				if not eligibility.EligibleDonor then reject(donor.DisplayName .. ": " .. eligibility.Reason) end
				table.insert(preview.Donors, Math.Copy(donor))
				table.insert(staged.Remove, uuid)
				if donor.Stars >= Config.RareConfirmationStars then preview.RequiresRareConfirmation = true end
			end
			seen[uuid] = true
		end
	elseif #donorIds > 0 then reject("This operation does not consume heroes. Clear the donor selection.") end

	if action == "SYNTHESIS" or action == "IMPRINT" then
		if recipient then
			local xp = { Base = 0, Final = 0, Efficiency = 1, ResearchBonus = 0, Breakdown = {} }
			for _, donor in ipairs(preview.Donors) do
				local breakdown = Math.GetSynthesisXP(donor, recipient, profile.UnlockedResearch)
				breakdown.UUID, breakdown.Name = donor.UUID, donor.DisplayName
				xp.Base += breakdown.Base
				xp.Final += breakdown.Final
				xp.ResearchBonus = breakdown.ResearchBonus
				table.insert(xp.Breakdown, breakdown)
				if action == "SYNTHESIS" then
					for _, option in ipairs(Math.GetImprintOptions(donor, recipient, profile.UnlockedResearch)) do
						option.DonorUUID, option.DonorName = donor.UUID, donor.DisplayName
						option.OpportunityOnly = true
						table.insert(preview.Imprints, option)
					end
				end
			end
			preview.Mode = action == "IMPRINT" and "Focused Imprint" or "Essence Synthesis"
			if xp.Base > 0 then
				local weighted = 0
				for _, part in ipairs(xp.Breakdown) do weighted += part.Base * part.Efficiency end
				xp.Efficiency = weighted / xp.Base
			end
			if xp.Efficiency < 1 then table.insert(preview.Warnings, "The recipient outlevels these donors. The displayed EXP includes reduced efficiency.") end
			if action == "IMPRINT" then
				xp.Final = math.floor(xp.Final * Config.Synthesis.FocusedXPScale)
				if recipient.Stars == Config.MaxStars and recipient.Level >= Config.MaxStars * 10 then
					xp.MemoryOnly = true
					xp.Final = 0
					table.insert(preview.Warnings, "At maximum level, Focused Imprint grants the selected memory only. This donor grants 0 EXP.")
				end
				preview.Costs = { Gold = Config.Imprints.GoldCost, ImprintCatalyst = Config.Imprints.CatalystCost }
				if preview.Donors[1] then
					preview.Imprints = Math.GetImprintOptions(preview.Donors[1], recipient, profile.UnlockedResearch)
					local option
					for _, candidate in ipairs(preview.Imprints) do if candidate.Id == request.Imprint then option = candidate break end end
					if not option then reject("Choose a memory carried by this donor.")
					elseif not option.Compatible then reject(option.Reason)
					else preview.SelectedImprint = option end
				end
				preview.FailureResult = "Guaranteed inheritance. The donor is consumed once; there is no failure roll."
			end
			local after, overflow = Math.AdvanceXP(recipient, xp.Final)
			if overflow.Rejected > 0 then reject("This EXP would exceed the reserve. Use fewer donors or promote the recipient first.") end
			if after.OverflowXP > 0 then table.insert(preview.Warnings, "Excess EXP is stored in the bounded reserve and released on promotion.") end
			if action == "IMPRINT" and preview.SelectedImprint then
				local option = preview.SelectedImprint
				after.InheritedImprints[option.Id] = option.CurrentRank + 1
				after.SynthesisHistory.ImprintsPerformed = (after.SynthesisHistory.ImprintsPerformed or 0) + 1
			end
			after.SynthesisHistory.DonorsConsumed = (after.SynthesisHistory.DonorsConsumed or 0) + #preview.Donors
			after.SynthesisHistory.XPGained = (after.SynthesisHistory.XPGained or 0) + xp.Final
			preview.XP, preview.Overflow, preview.After = xp, overflow, Math.Snapshot(after, profile)
			staged.Heroes[recipient.UUID] = after
		end
	elseif action == "CONVERSION" then
		local essence = 0
		for _, donor in ipairs(preview.Donors) do essence += Math.GetConversionYield(donor) end
		preview.Rewards = { SoulEssence = essence }
	elseif action == "PROMOTION" then
		if recipient then
			local rule = Config.Promotion[recipient.Stars]
			if recipient.Stars >= Config.MaxStars or not rule then reject("This hero has reached the maximum 5★ rank.")
			else
				preview.Costs = { Gold = rule.Gold, PromotionStone = rule.PromotionStone }
				preview.Requirements = { { Label = "Reach the current level cap", Current = recipient.Level, Required = recipient.Stars * 10, Met = recipient.Level >= recipient.Stars * 10 } }
				if rule.Research then
					table.insert(preview.Requirements, { Label = rule.Research == "MasterStonecraft" and "Master Stonecraft" or "Advanced Stonecraft",
						Current = profile.UnlockedResearch[rule.Research] and 1 or 0, Required = 1, Met = profile.UnlockedResearch[rule.Research] == true })
				end
				if recipient.Level < recipient.Stars * 10 then reject("Reach Level " .. recipient.Stars * 10 .. " to unlock promotion.") end
				if rule.Research and not profile.UnlockedResearch[rule.Research] then reject("Unlock " .. (rule.Research == "MasterStonecraft" and "Master Stonecraft" or "Advanced Stonecraft") .. " in the Dimensional Lab.") end
				local after, overflow = Math.Promote(recipient)
				after.ImprintCapacity = Math.GetImprintCapacity(after)
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
	if preview.RequiresRareConfirmation then table.insert(preview.Warnings, "Rare heroes are selected. Confirm each donor's identity before proceeding.") end
	return preview, staged
end

local function normalizeRequest(payload: any): (any?, string?)
	if type(payload) ~= "table" or type(payload.Action) ~= "string" then return nil, "Choose a Pit operation." end
	local allowed = { SYNTHESIS = true, IMPRINT = true, PROMOTION = true, CONVERSION = true, CRAFT = true }
	if not allowed[payload.Action] then return nil, "Unknown Pit operation." end
	if payload.Recipient ~= nil and (type(payload.Recipient) ~= "string" or #payload.Recipient > 80) then return nil, "Invalid recipient." end
	if payload.Imprint ~= nil and (type(payload.Imprint) ~= "string" or #payload.Imprint > 80) then return nil, "Invalid memory." end
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
	return { Action = payload.Action, Recipient = payload.Recipient, Donors = donors, Imprint = payload.Imprint, Recipe = payload.Recipe }, nil
end

function PitService:Request(player: any, command: any, payload: any): any
	if self.Locks[player] then return fail("The previous Pit operation is still processing.") end
	self.Locks[player] = true
	local ok, response = pcall(function()
		local profile = self.Dependencies.GetProfile(player)
		if not profile then return fail("Your roster is still loading. Try again shortly.") end
		if command == "STATE" then
			local now = self:Now()
			if self.LastState[player] and now - self.LastState[player] < Config.StateCooldown then return fail("Please wait a moment before refreshing your roster.") end
			self.LastState[player] = now
			self:Prepare(player, profile)
			return { Success = true, State = self:State(profile) }
		end
		if command == "LOCK" then
			local now = self:Now()
			if self.LastLock[player] and now - self.LastLock[player] < Config.LockCooldown then return fail("Please wait a moment before changing protection again.") end
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
			if self.LastPreview[player] and now - self.LastPreview[player] < Config.PreviewCooldown then return fail("Please wait a moment before refreshing the preview.") end
			self.LastPreview[player] = now
			self:Prepare(player, profile)
			self.Previews[player] = nil
			local request, reason = normalizeRequest(payload)
			if not request then return fail(reason or "Invalid operation.") end
			local preview = self:Build(profile, request)
			if preview.CanCommit then
				local token = self.Dependencies.GenerateToken()
				local expires = now + Config.PreviewLifetime
				self.Previews[player] = { Token = token, ExpiresAt = expires, Request = request, Fingerprint = self:Fingerprint(profile, request) }
				preview.Token, preview.ExpiresAt = token, expires
			end
			return { Success = true, Preview = preview }
		end
		if command == "COMMIT" then
			self:Prepare(player, profile)
			local stored = self.Previews[player]
			-- Remove before validation: a confirmation token is always single-use.
			self.Previews[player] = nil
			if type(payload) ~= "table" or type(payload.Token) ~= "string" or not stored or stored.Token ~= payload.Token then return fail("This confirmation is no longer valid. Refresh the preview.") end
			if self:Now() > stored.ExpiresAt then return fail("This preview expired. Review the operation again.") end
			if stored.Fingerprint ~= self:Fingerprint(profile, stored.Request) then return fail("Your roster or resources changed. Review the updated preview.") end
			local preview, staged = self:Build(profile, stored.Request)
			if not preview.CanCommit then return fail(preview.Reason) end
			if preview.RequiresRareConfirmation and payload.ConfirmRare ~= true then return fail("Confirm the rare donor warning before consuming these heroes.") end
			-- All possible failures precede these assignments. Preserve unrelated
			-- profile fields and do not yield between deductions and roster updates.
			for _, uuid in ipairs(staged.Remove) do profile.Heroes[uuid] = nil end
			for uuid, hero in pairs(staged.Heroes) do profile.Heroes[uuid] = hero end
			profile.Currencies = staged.Currencies
			profile.PitMaterials = staged.Materials
			profile.PitRevision += 1
			local messages = { SYNTHESIS = "Synthesis complete.", IMPRINT = "Memory inherited.", PROMOTION = "Star promotion complete!", CONVERSION = "Heroes converted into Soul Essence.", CRAFT = "Crafting complete." }
			-- Replication failure cannot turn a committed transaction into a false
			-- failure; STATE can always recover the authoritative result.
			pcall(self.Dependencies.SyncProfile, player, staged.Heroes, staged.Remove)
			local deltaOK, delta = pcall(function() return self:Delta(profile, staged.Heroes, staged.Remove) end)
			return { Success = true, Message = messages[stored.Request.Action], Result = preview, Delta = deltaOK and delta or nil }
		end
		return fail("Unknown Pit request.")
	end)
	self.Locks[player] = nil
	if not ok then
		warn("[The Pit] Request failed: " .. tostring(response))
		return fail("The Pit could not process this request. Refresh your roster and try again.")
	end
	return response
end

function PitService:GrantCombatXP(player: any, uuid: string, amount: number): (boolean, any)
	if self.Locks[player] or not finite(amount) or amount <= 0 then return false, "Invalid combat EXP grant." end
	local profile = self.Dependencies.GetProfile(player)
	if not profile then return false, "Profile not loaded." end
	self:Prepare(player, profile)
	local hero = profile.Heroes[uuid]
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
