--!strict
-- The only async boundary. Receipts replace snapshots; this never mutates profile tables.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Model = require(script.Parent.Model)
local Types = require(script.Parent.Types)
type Snapshot = Types.Snapshot
type Command = Types.Command
type Result = Types.Result

local function useForge(props: Types.Props)
	local snapshot, setSnapshot = React.useState(props.Snapshot)
	local initialHeroes = Model.sortedHeroes(props.Snapshot)
	local heroId, setHeroId = React.useState(props.InitialHeroId or (initialHeroes[1] and initialHeroes[1].UUID))
	local targetId, setTargetId = React.useState(props.InitialArtifactId)
	local mode, setMode = React.useState(props.InitialMode or "EQUIP")
	local materials, setMaterials = React.useState({} :: { string })
	local phase, setPhase = React.useState("idle")
	local message, setMessage = React.useState("Choose a hero and an artifact to compare.")
	local success, setSuccess = React.useState(false)
	local sequence, setSequence = React.useState(0)
	local undo, setUndo = React.useState(nil :: { Token: string, ExpiresAt: number }?)
	local mounted = React.useRef(true)
	local snapshotRef = React.useRef(snapshot)
	local pending = React.useRef(nil :: Command?)
	local reconciling = React.useRef(false)
	local timeout = React.useRef(nil :: thread?)
	snapshotRef.current = snapshot

	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
			if timeout.current then task.cancel(timeout.current); timeout.current = nil end
		end
	end, {})
	React.useEffect(function()
		if props.Snapshot.Revision >= snapshotRef.current.Revision then
			snapshotRef.current = props.Snapshot
			setSnapshot(props.Snapshot)
		end
	end, { props.Snapshot })
	React.useEffect(function()
		setMaterials(function(previous) return Model.materials(snapshot, targetId, previous) end)
		if heroId and not snapshot.Heroes[heroId] then setHeroId(nil) end
		if targetId and not snapshot.Artifacts[targetId] then setTargetId(nil) end
	end, { snapshot, targetId, heroId })

	local function applyResult(result: Result, requestId: string)
		if not mounted.current or not pending.current or pending.current.RequestId ~= requestId then return end
		if result.RequestId ~= requestId then error("Mismatched Forge receipt") end
		local command = pending.current
		pending.current = nil
		reconciling.current = false
		if timeout.current then task.cancel(timeout.current); timeout.current = nil end
		if result.Snapshot.Revision >= snapshotRef.current.Revision then
			snapshotRef.current = result.Snapshot
			setSnapshot(result.Snapshot)
			if props.OnSnapshot then props.OnSnapshot(result.Snapshot) end
		end
		setPhase("idle")
		setMessage(result.Message)
		setSuccess(result.Ok)
		setSequence(function(n) return n + 1 end)
		if result.Ok and command.Kind == "UPGRADE" then setMaterials({}) end
		if result.Ok and result.UndoToken and result.UndoExpiresAt then
			setUndo({ Token = result.UndoToken, ExpiresAt = result.UndoExpiresAt })
		end
	end

	local function uncertain()
		if not mounted.current or not pending.current then return end
		setPhase("uncertain")
		setSuccess(false)
		setMessage("Still checking the server. Your action may have completed. Check status before making another change.")
	end

	local function execute(command: Command): boolean
		if pending.current then return false end -- synchronous latch rejects same-frame double taps
		pending.current = command
		setUndo(nil)
		setPhase("sending")
		setSuccess(false)
		setMessage("Waiting for the server…")
		timeout.current = task.delay(12, function() timeout.current = nil; uncertain() end)
		task.spawn(function()
			local ok = pcall(function() applyResult(props.Transport.Execute(command), command.RequestId) end)
			if not ok then uncertain() end -- do not replay an uncertain economy action
		end)
		return true
	end

	local function command(kind: string): Command
		return { RequestId = HttpService:GenerateGUID(false), ExpectedRevision = snapshotRef.current.Revision, Kind = kind }
	end

	local function equip(): boolean
		local current = snapshotRef.current
		local reason = Model.equipReason(current, heroId, targetId)
		if reason then setMessage(reason); setSuccess(false); return false end
		local request = command("EQUIP")
		request.HeroId, request.ArtifactId = heroId, targetId
		return execute(request)
	end
	local function unequip(): boolean
		local hero = heroId and snapshotRef.current.Heroes[heroId]
		if not hero or not hero.EquippedArtifactUUID then return false end
		local request = command("UNEQUIP")
		request.HeroId = heroId
		return execute(request)
	end
	local function upgrade(expectedRevision: number): boolean
		local current = snapshotRef.current
		if current.Revision ~= expectedRevision then setMessage("Inventory changed. Review the new preview before upgrading."); return false end
		local reason = Model.upgradeReason(current, targetId, materials)
		if reason then setMessage(reason); setSuccess(false); return false end
		local request = command("UPGRADE")
		request.ArtifactId, request.MaterialIds = targetId, table.clone(materials)
		return execute(request)
	end
	local function toggleMaterial(id: string)
		if pending.current then return end
		local reason = Model.materialReason(snapshotRef.current, targetId, id)
		if reason then setMessage(reason); setSuccess(false); return end
		setMaterials(function(previous)
			local nextIds = table.clone(previous)
			local index = table.find(nextIds, id)
			if index then table.remove(nextIds, index) else table.insert(nextIds, id) end
			return Model.materials(snapshotRef.current, targetId, nextIds)
		end)
	end
	local function autoFill()
		if pending.current or not targetId then return end
		local nextIds = Model.autoFill(snapshotRef.current, targetId, materials)
		setMaterials(nextIds)
		local target = snapshotRef.current.Artifacts[targetId]
		local required = if target then Catalog.GetFodderRequirement(target.Star) else 0
		setMessage(if #nextIds < required then "Not enough unprotected materials. Equipped and locked artifacts remain visible in the inventory." else "Safe materials selected. Review the consumed items and cost.")
		setSuccess(false)
	end
	local function toggleLock()
		local artifact = targetId and snapshotRef.current.Artifacts[targetId]
		if not artifact then return end
		local request = command("LOCK")
		request.ArtifactId, request.Locked = targetId, not artifact.Locked
		execute(request)
	end
	local function undoLast()
		if not undo then return end
		if Workspace:GetServerTimeNow() >= undo.ExpiresAt then setUndo(nil); setMessage("Undo expired. Select the previous artifact to equip it again."); return end
		local request = command("UNDO")
		request.UndoToken = undo.Token
		execute(request)
	end
	local function reconcile()
		local request = pending.current
		if not request or reconciling.current then return end
		reconciling.current = true
		task.spawn(function()
			local ok = pcall(function() applyResult(props.Transport.Reconcile(request.RequestId), request.RequestId) end)
			reconciling.current = false
			if not ok then uncertain() end
		end)
	end
	local function selectTarget(id: string)
		if pending.current then return end
		setTargetId(id)
		setMaterials({})
	end

	return {
		Snapshot = snapshot, HeroId = heroId, TargetId = targetId, Mode = mode,
		Materials = Model.materials(snapshot, targetId, materials), Phase = phase,
		Message = message, Success = success, Sequence = sequence, Undo = undo,
		SetHero = setHeroId, SetMode = setMode, SelectTarget = selectTarget,
		ToggleMaterial = toggleMaterial, AutoFill = autoFill, ToggleLock = toggleLock,
		Equip = equip, Unequip = unequip, Upgrade = upgrade, UndoLast = undoLast, Reconcile = reconcile,
		Explain = function(text: string) setMessage(text); setSuccess(false) end,
	}
end

return useForge
