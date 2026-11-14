--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local Model = require(script.Parent.Model)
local Types = require(script.Parent.Types)

type Artifact = Types.Artifact
type Snapshot = Types.Snapshot

export type UseSellProps = {
	Snapshot: Snapshot,
	Items: { Artifact },
	OnSellArtifacts: ((ids: { string }) -> (boolean, string?))?,
	OnBusyChanged: ((busy: boolean) -> ())?,
}

local function useSell(props: UseSellProps)
	local selected, setSelected = React.useState({} :: { [string]: boolean })
	local busy, setBusy = React.useState(false)
	local message, setMessage = React.useState("Select spare artifacts to sell. Equipped and locked weapons are protected.")
	local latch = React.useRef(false)
	local mounted = React.useRef(true)

	React.useEffect(function()
		mounted.current = true
		return function()
			mounted.current = false
		end
	end, {})

	React.useEffect(function()
		if props.OnBusyChanged then
			props.OnBusyChanged(busy)
		end
	end, { busy })

	local snapshot = props.Snapshot

	local function eligible(artifact: Artifact): boolean
		return not artifact.Locked and not Catalog.IsGildforged(artifact) and #Model.ownerIds(snapshot, artifact.UUID) == 0
	end

	local selectedIds: { string } = {}
	local selectedItems: { Artifact } = {}
	local totalGold = 0
	local rarityCounts: { [number]: number } = {}
	local hasRareOrBetter = false
	local rareOrBetterItems: { Artifact } = {}

	for _, artifact in props.Items do
		if selected[artifact.UUID] and eligible(artifact) then
			table.insert(selectedIds, artifact.UUID)
			table.insert(selectedItems, artifact)
			totalGold += Catalog.CalculateSellPrice(artifact.Rarity, artifact.Star, artifact.TemplateId)
			rarityCounts[artifact.Rarity] = (rarityCounts[artifact.Rarity] or 0) + 1
			if artifact.Rarity > 2 then
				hasRareOrBetter = true
				table.insert(rareOrBetterItems, artifact)
			end
		end
	end

	local function toggle(id: string)
		if latch.current or busy then return end
		local artifact = snapshot.Artifacts[id]
		if not artifact or not eligible(artifact) then
			setMessage("That artifact is protected. Unequip or unlock it first.")
			return
		end
		setSelected(function(previous)
			local nextSelection = table.clone(previous)
			nextSelection[id] = not nextSelection[id]
			return nextSelection
		end)
	end

	local function quickPick(rarity: number?)
		if latch.current or busy then return end
		local nextSelection: { [string]: boolean } = {}
		for _, artifact in props.Items do
			if eligible(artifact) and (rarity == nil or artifact.Rarity == rarity) then
				nextSelection[artifact.UUID] = true
			end
		end
		setSelected(nextSelection)
	end

	local function clear()
		if latch.current or busy then return end
		setSelected({})
	end

	local function sell(onDone: (() -> ())?)
		if latch.current or #selectedIds == 0 or not props.OnSellArtifacts then return end
		latch.current = true
		setBusy(true)
		setMessage("Waiting for the server…")
		local submitted = table.clone(selectedIds)

		task.spawn(function()
			local ok, success, result = pcall(props.OnSellArtifacts, submitted)
			if not mounted.current then return end
			setSelected({})
			setMessage(if ok then result or (if success then "Artifacts sold." else "Sale declined. Review your inventory.") else "Sale status unknown. Reopen the Forge to refresh before trying again.")
			if ok then
				latch.current = false
				setBusy(false)
				if onDone then onDone() end
			end
		end)
	end

	return {
		Selected = selected,
		Toggle = toggle,
		QuickPick = quickPick,
		Clear = clear,
		TotalGold = totalGold,
		SelectedIds = selectedIds,
		SelectedItems = selectedItems,
		SelectedCount = #selectedIds,
		RarityCounts = rarityCounts,
		HasRareOrBetter = hasRareOrBetter,
		RareOrBetterItems = rareOrBetterItems,
		Eligible = eligible,
		Sell = sell,
		Busy = busy,
		Message = message,
	}
end

return useSell
