--!strict
-- Non-yielding forge authority. Receipts are recorded BEFORE callers synchronize or toast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Promotion = require(ReplicatedStorage.Shared.Util.WeaponPromotion)
local Balance = require(ReplicatedStorage.Shared.Config.StatBalance)
local InventoryCapacity = require(ReplicatedStorage.Shared.Util.InventoryCapacity)
local EquipBest = require(ReplicatedStorage.Shared.Util.EquipBest)

local ForgeTransactions = {}
local ARTIFACT_FIELDS = { "UUID", "TemplateId", "DisplayName", "Type", "Rarity", "Star", "Locked", "EquippedHeroUUID" }
local HERO_FIELDS = { "Assignment", "UUID", "TemplateId", "DisplayName", "Archetype", "Stars", "Level", "Rarity", "QualityScalar", "AttackInterval", "ComaUntilTimestamp", "EquippedArtifactUUID" }
local MAX_RECEIPTS = 128
local RECEIPT_SECONDS = 600

local function validId(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= 64 and string.match(value, "^[%w_%-]+$") ~= nil
end

local function project(source: any, fields: { string }, id: string): any
	local result = { UUID = id }
	for _, key in fields do
		local value = source[key]
		if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then result[key] = value end
	end
	result.UUID = id
	return result
end

local function copySnapshot(snapshot: any): any
	local result = table.clone(snapshot)
	result.Artifacts, result.Heroes = {}, {}
	for id, artifact in snapshot.Artifacts do result.Artifacts[id] = table.clone(artifact) end
	for id, hero in snapshot.Heroes do result.Heroes[id] = table.clone(hero) end
	return result
end

local function copyReceipt(receipt: any): any
	local result = table.clone(receipt)
	result.Snapshot = copySnapshot(receipt.Snapshot)
	return result
end

local function signature(snapshot: any): string
	local parts = {}
	for _, group in { "Artifacts", "Heroes" } do
		local ids = {}
		for id in snapshot[group] do table.insert(ids, id) end
		table.sort(ids)
		table.insert(parts, group)
		for _, id in ids do
			local fields = if group == "Artifacts" then ARTIFACT_FIELDS else HERO_FIELDS
			for _, key in fields do
				local atom = typeof(snapshot[group][id][key]) .. ":" .. tostring(snapshot[group][id][key])
				table.insert(parts, tostring(#atom) .. ":" .. atom)
			end
		end
	end
	return table.concat(parts, "|")
end

function ForgeTransactions.new(options: { Clock: () -> number, GenerateToken: () -> string })
	local sessions: { [any]: any } = {}
	local service = {}
	local function session(profile: any): any
		local state = sessions[profile]
		if not state then
			state = { Revision = 0, Signature = "", Receipts = {}, ReceiptOrder = {}, Undo = nil, Tokens = 16, LastRefill = options.Clock() }
			sessions[profile] = state
		end
		return state
	end

	function service.Snapshot(profile: any): any
		local state = session(profile)
		local snapshot = { Revision = state.Revision, Heroes = {}, Artifacts = {}, Gold = profile.Currencies.Gold, Gems = profile.Currencies.Gems }
		for id, artifact in profile.Artifacts or {} do snapshot.Artifacts[id] = project(artifact, ARTIFACT_FIELDS, id) end
		for id, hero in profile.Heroes or {} do snapshot.Heroes[id] = project(hero, HERO_FIELDS, id) end
		local nextSignature = signature(snapshot)
		if nextSignature ~= state.Signature then
			state.Revision += 1
			state.Signature = nextSignature
		end
		snapshot.Revision = state.Revision
		snapshot.ArtifactCap = InventoryCapacity.ArtifactCap(profile.FortressTree)
		-- Currency ticks do not invalidate equipment undo or a material selection. Every mutation
		-- still checks the CURRENT server balance immediately before committing.
		profile.ForgeRevision = state.Revision
		return snapshot
	end

	function service.Forget(profile: any)
		sessions[profile] = nil
	end

	local function allow(state: any): boolean
		local now = options.Clock()
		state.Tokens = math.min(16, state.Tokens + math.max(0, now - state.LastRefill) * 4)
		state.LastRefill = now
		if state.Tokens < 1 then return false end
		state.Tokens -= 1
		return true
	end

	local function prune(state: any)
		local now = options.Clock()
		while #state.ReceiptOrder > 0 do
			local first = state.ReceiptOrder[1]
			if #state.ReceiptOrder < MAX_RECEIPTS and now - first.Time < RECEIPT_SECONDS then break end
			state.Receipts[first.Id] = nil
			table.remove(state.ReceiptOrder, 1)
		end
	end

	function service.Read(profile: any): any
		if not allow(session(profile)) then error("Please wait before refreshing the Forge again.") end
		return service.Snapshot(profile)
	end

	local function response(profile: any, id: any, ok: boolean, message: string): any
		return { RequestId = if validId(id) then id else "invalid", Ok = ok, Message = message, Snapshot = service.Snapshot(profile) }
	end

	function service.Reconcile(profile: any, id: any): any
		local state = session(profile)
		if not allow(state) then error("Please wait before checking Forge status again.") end
		if not validId(id) then error("Invalid Forge request ID") end
		prune(state)
		local receipt = state.Receipts[id]
		if not receipt then error("No terminal Forge receipt. Refresh your inventory before retrying.") end
		return copyReceipt(receipt)
	end

	function service.Execute(profile: any, command: any, upgradeAllowed: boolean): any
		local state = session(profile)
		if type(command) ~= "table" or not validId(command.RequestId) then return response(profile, nil, false, "Invalid Forge request") end
		prune(state)
		if state.Receipts[command.RequestId] then return copyReceipt(state.Receipts[command.RequestId]), false end
		if not allow(state) then return response(profile, command.RequestId, false, "Please wait before changing equipment again.") end
		local before = service.Snapshot(profile)
		local function finish(ok: boolean, message: string, undo: any?): any
			local result = response(profile, command.RequestId, ok, message)
			if ok then
				state.Undo = nil
				if undo then
					undo.Token = options.GenerateToken()
					undo.ExpiresAt = options.Clock() + 10
					undo.Revision = result.Snapshot.Revision
					state.Undo = undo
					result.UndoToken, result.UndoExpiresAt = undo.Token, undo.ExpiresAt
				end
			end
			state.Receipts[command.RequestId] = result
			table.insert(state.ReceiptOrder, { Id = command.RequestId, Time = options.Clock() })
			return copyReceipt(result), ok
		end
		if not Balance.Integer(command.ExpectedRevision, 0, 2 ^ 53 - 1) or command.ExpectedRevision ~= before.Revision then
			return finish(false, "Inventory changed. Review the refreshed selection.", nil)
		end
		local kind = command.Kind
		if kind ~= "EQUIP" and kind ~= "UNEQUIP" and kind ~= "LOCK" and kind ~= "UPGRADE" and kind ~= "UNDO" and kind ~= "EQUIP_BEST" then
			return finish(false, "Unsupported Forge action", nil)
		end
		local hero = validId(command.HeroId) and profile.Heroes[command.HeroId] or nil
		local artifact = validId(command.ArtifactId) and profile.Artifacts[command.ArtifactId] or nil
		if kind == "LOCK" then
			if not artifact or type(command.Locked) ~= "boolean" then return finish(false, "Invalid artifact lock request", nil) end
			artifact.Locked = command.Locked
			return finish(true, if artifact.Locked then "Artifact protected from consumption." else "Artifact unlocked.", nil)
		elseif kind == "UPGRADE" then
			if not upgradeAllowed then return finish(false, "Unlock the Blacksmith Forge to promote artifacts.", nil) end
			if not artifact then return finish(false, "Artifact no longer owned", nil) end
			local ok, message = Promotion.Promote(profile, command.ArtifactId, command.MaterialIds)
			return finish(ok, message, nil)
		elseif kind == "UNDO" then
			local undo = state.Undo
			if not undo or not validId(command.UndoToken) or command.UndoToken ~= undo.Token or options.Clock() >= undo.ExpiresAt or before.Revision ~= undo.Revision then
				return finish(false, "Undo expired or equipment has changed.", nil)
			end
			-- Validate the WHOLE inverse before restoring any link. Never resurrect missing items.
			for id in undo.Heroes do if not profile.Heroes[id] then return finish(false, "A hero is no longer owned.", nil) end end
			for id in undo.Artifacts do if not profile.Artifacts[id] then return finish(false, "An artifact is no longer owned.", nil) end end
			for id, link in undo.Heroes do profile.Heroes[id].EquippedArtifactUUID = if link == false then nil else link end
			for id, link in undo.Artifacts do profile.Artifacts[id].EquippedHeroUUID = if link == false then nil else link end
			return finish(true, "Equipment change undone.", nil)
		elseif kind == "EQUIP_BEST" then
			local plan = EquipBest.Plan(profile.Heroes or {}, profile.Artifacts or {})
			if not plan.HasChanges or plan.ChangeCount == 0 then
				return finish(false, "Squad already equipped with optimal gear.", nil)
			end
			local undo = { Heroes = {}, Artifacts = {} }
			local function rememberHero(id: string)
				if undo.Heroes[id] == nil and profile.Heroes[id] then
					undo.Heroes[id] = profile.Heroes[id].EquippedArtifactUUID or false
				end
			end
			local function rememberArtifact(id: string)
				if undo.Artifacts[id] == nil and profile.Artifacts[id] then
					undo.Artifacts[id] = profile.Artifacts[id].EquippedHeroUUID or false
				end
			end
			for heroId, newArtId in plan.Changes do
				rememberHero(heroId)
				local oldArtId = profile.Heroes[heroId] and profile.Heroes[heroId].EquippedArtifactUUID
				if oldArtId then rememberArtifact(oldArtId) end
				rememberArtifact(newArtId)
				local prevOwner = profile.Artifacts[newArtId] and profile.Artifacts[newArtId].EquippedHeroUUID
				if prevOwner and profile.Heroes[prevOwner] then rememberHero(prevOwner) end
			end
			for heroId, newArtId in plan.Changes do
				local heroEntry = profile.Heroes[heroId]
				local newArtEntry = profile.Artifacts[newArtId]
				if heroEntry and newArtEntry then
					local oldArtId = heroEntry.EquippedArtifactUUID
					if oldArtId and profile.Artifacts[oldArtId] then
						profile.Artifacts[oldArtId].EquippedHeroUUID = nil
					end
					local prevOwner = newArtEntry.EquippedHeroUUID
					if prevOwner and profile.Heroes[prevOwner] and prevOwner ~= heroId then
						profile.Heroes[prevOwner].EquippedArtifactUUID = nil
					end
					heroEntry.EquippedArtifactUUID = newArtId
					newArtEntry.EquippedHeroUUID = heroId
				end
			end
			return finish(true, string.format("Optimal gear equipped on %d squad member%s.", plan.ChangeCount, if plan.ChangeCount == 1 then "" else "s"), undo)
		end
		if not hero then return finish(false, "Hero no longer owned", nil) end
		local undo = { Heroes = {}, Artifacts = {} }
		local function rememberHero(id: string)
			undo.Heroes[id] = profile.Heroes[id].EquippedArtifactUUID or false
		end
		local function rememberArtifact(id: string)
			undo.Artifacts[id] = profile.Artifacts[id].EquippedHeroUUID or false
		end
		local oldId = hero.EquippedArtifactUUID
		if oldId then
			local old = profile.Artifacts[oldId]
			if not old or old.EquippedHeroUUID ~= command.HeroId then return finish(false, "Equipment is out of sync. Refresh and select again.", nil) end
			for id, other in profile.Heroes do
				if id ~= command.HeroId and other.EquippedArtifactUUID == oldId then return finish(false, "Equipment is out of sync.", nil) end
			end
		end
		if kind == "UNEQUIP" then
			if not oldId then return finish(false, "This hero has an empty weapon slot.", nil) end
			for id, other in profile.Heroes do
				if id ~= command.HeroId and other.EquippedArtifactUUID == oldId then return finish(false, "Equipment is out of sync.", nil) end
			end
			rememberHero(command.HeroId); rememberArtifact(oldId)
			hero.EquippedArtifactUUID = nil; profile.Artifacts[oldId].EquippedHeroUUID = nil
			return finish(true, "Weapon returned to inventory.", undo)
		end
		if not artifact or not Catalog.CanHeroEquip(hero.Archetype, artifact.Type) then return finish(false, "This hero cannot equip that artifact.", nil) end
		if oldId == command.ArtifactId then return finish(false, "Already equipped on this hero.", nil) end
		local previousId = artifact.EquippedHeroUUID
		if previousId and (not profile.Heroes[previousId] or profile.Heroes[previousId].EquippedArtifactUUID ~= command.ArtifactId) then
			return finish(false, "The artifact's owner is out of sync. Refresh first.", nil)
		end
		for id, other in profile.Heroes do
			if other.EquippedArtifactUUID == command.ArtifactId and id ~= previousId then return finish(false, "Conflicting artifact ownership. Refresh first.", nil) end
		end
		rememberHero(command.HeroId); rememberArtifact(command.ArtifactId)
		if oldId then rememberArtifact(oldId) end
		if previousId then rememberHero(previousId) end
		-- No calls/yields between these mutations and the receipt recorded by finish().
		if previousId then profile.Heroes[previousId].EquippedArtifactUUID = nil end
		if oldId then profile.Artifacts[oldId].EquippedHeroUUID = nil end
		hero.EquippedArtifactUUID = command.ArtifactId
		artifact.EquippedHeroUUID = command.HeroId
		return finish(true, string.format("%s equipped to %s.", artifact.DisplayName, hero.DisplayName), undo)
	end

	return service
end

return ForgeTransactions
