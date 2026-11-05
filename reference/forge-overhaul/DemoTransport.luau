--!strict
-- LOCAL DEMONSTRATION ONLY. This is not a server implementation or a profile adapter.
-- The fake authority demonstrates the required receipt/idempotency/undo contract.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Model = require(script.Parent.ForgeWorkbench.Model)
local Types = require(script.Parent.ForgeWorkbench.Types)
type Snapshot = Types.Snapshot
type Command = Types.Command
type Result = Types.Result

local function clone(snapshot: Snapshot): Snapshot
	local result = table.clone(snapshot)
	result.Heroes, result.Artifacts = {}, {}
	for id, value in snapshot.Heroes do result.Heroes[id] = table.clone(value) end
	for id, value in snapshot.Artifacts do result.Artifacts[id] = table.clone(value) end
	return result
end

local function new(initial: Snapshot): Types.Transport
	local current = clone(initial)
	local receipts: { [string]: Result } = {}
	local undo: { Token: string, Before: Snapshot, AfterRevision: number, ExpiresAt: number }? = nil
	local function execute(command: Command): Result
		if receipts[command.RequestId] then return receipts[command.RequestId] end
		local before = clone(current)
		local reason: string? = nil
		local ok = false
		local message = "Unsupported command"
		local token, expiresAt = nil, nil
		if command.ExpectedRevision ~= current.Revision then
			reason = "Inventory changed. Review the refreshed snapshot."
		elseif command.Kind == "EQUIP" then
			reason = Model.equipReason(current, command.HeroId, command.ArtifactId)
			if not reason and command.HeroId and command.ArtifactId then
				local hero, artifact = current.Heroes[command.HeroId], current.Artifacts[command.ArtifactId]
				for _, ownerId in Model.ownerIds(current, artifact.UUID) do current.Heroes[ownerId].EquippedArtifactUUID = nil end
				local oldId = hero.EquippedArtifactUUID
				if oldId then current.Artifacts[oldId].EquippedHeroUUID = nil end
				hero.EquippedArtifactUUID, artifact.EquippedHeroUUID = artifact.UUID, hero.UUID
				ok, message = true, artifact.DisplayName .. " equipped to " .. Model.heroLabel(hero)
			end
		elseif command.Kind == "UNEQUIP" then
			local hero = command.HeroId and current.Heroes[command.HeroId]
			if hero and hero.EquippedArtifactUUID then
				current.Artifacts[hero.EquippedArtifactUUID].EquippedHeroUUID = nil
				hero.EquippedArtifactUUID = nil
				ok, message = true, "Weapon returned to inventory."
			else reason = "No weapon equipped" end
		elseif command.Kind == "LOCK" then
			local artifact = command.ArtifactId and current.Artifacts[command.ArtifactId]
			if artifact and type(command.Locked) == "boolean" then
				artifact.Locked = command.Locked
				ok, message = true, if command.Locked then "Protected from consumption." else "Protection unlocked."
			else reason = "Artifact no longer owned" end
		elseif command.Kind == "UPGRADE" then
			reason = Model.upgradeReason(current, command.ArtifactId, command.MaterialIds or {})
			if not reason and command.ArtifactId and command.MaterialIds then
				local target = current.Artifacts[command.ArtifactId]
				local rule = Catalog.GetStarPromotionCost(target.Star)
				current.Gold -= rule.Gold; current.Gems -= rule.Gems
				for _, id in command.MaterialIds do current.Artifacts[id] = nil end
				target.Star += 1
				ok, message = true, string.format("%s upgraded to %d★. Materials consumed.", target.DisplayName, target.Star)
			end
		elseif command.Kind == "UNDO" then
			local record = undo
			if record and command.UndoToken == record.Token and current.Revision == record.AfterRevision and Workspace:GetServerTimeNow() < record.ExpiresAt then
				local revision = current.Revision
				current = clone(record.Before); current.Revision = revision
				ok, message = true, "Equipment change undone."
			else reason = "Undo expired or your equipment has changed." end
		end
		if ok then
			current.Revision += 1
			undo = nil
			if command.Kind == "EQUIP" or command.Kind == "UNEQUIP" then
				token, expiresAt = "demo-undo-" .. command.RequestId, Workspace:GetServerTimeNow() + 10
				undo = { Token = token, Before = before, AfterRevision = current.Revision, ExpiresAt = expiresAt }
			end
		end
		local result: Result = { RequestId = command.RequestId, Ok = ok, Message = reason or message, Snapshot = clone(current), UndoToken = token, UndoExpiresAt = expiresAt }
		receipts[command.RequestId] = result
		return result
	end
	return {
		Execute = execute,
		Reconcile = function(id: string): Result
			assert(receipts[id], "No terminal receipt yet")
			return receipts[id]
		end,
	}
end

return new
