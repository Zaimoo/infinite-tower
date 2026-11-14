--!strict
-- Uses the existing server-validated sale endpoint. Never automatically retries a sale.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local C = require(script.Parent.Components)
local Model = require(script.Parent.Model)
local T = require(script.Parent.Tokens)
local e = React.createElement

return function(props: any)
	local selected, setSelected = React.useState({})
	local review, setReview = React.useState(false)
	local busy, setBusy = React.useState(false)
	local message, setMessage = React.useState("Choose spare artifacts. Equipped and locked weapons are protected.")
	local latch, mounted = React.useRef(false), React.useRef(true)
	React.useEffect(function()
		mounted.current = true
		return function() mounted.current = false end
	end, {})
	React.useEffect(function()
		props.OnBusyChanged(busy)
		return function() props.OnBusyChanged(false) end
	end, { busy })
	local snapshot = props.Snapshot
	local ids, items, total = {}, {}, 0
	local function eligible(artifact)
		return not artifact.Locked and not Catalog.IsGildforged(artifact) and #Model.ownerIds(snapshot, artifact.UUID) == 0
	end
	for _, artifact in props.Items do
		if selected[artifact.UUID] and eligible(artifact) then
			table.insert(ids, artifact.UUID)
			table.insert(items, artifact)
			total += Catalog.CalculateSellPrice(artifact.Rarity, artifact.Star, artifact.TemplateId)
		end
	end
	local selectionSignature = {}
	for _, artifact in items do
		table.insert(selectionSignature, artifact.UUID .. ":" .. tostring(artifact.Rarity) .. ":" .. tostring(artifact.Star))
	end
	table.sort(selectionSignature)
	React.useEffect(function() setReview(false) end, { table.concat(selectionSignature, "|" ) })
	local function quickPick(rarity: number?)
		if latch.current then return end
		local nextSelection = {}
		for _, artifact in props.Items do
			if eligible(artifact) and (rarity == nil or artifact.Rarity == rarity) then nextSelection[artifact.UUID] = true end
		end
		setSelected(nextSelection)
		setReview(false)
	end
	local function sell()
		if latch.current or #ids == 0 then return end
		latch.current = true
		setBusy(true)
		setMessage("Waiting for the server…")
		local submitted = table.clone(ids)
		task.spawn(function()
			local ok, success, result = pcall(props.OnSellArtifacts, submitted)
			if not mounted.current then return end
			setSelected({})
			setReview(false)
			setMessage(if ok then result or (if success then "Artifacts sold." else "Sale declined. Review your inventory.") else "Sale status unknown. Reopen the Forge to refresh before trying again.")
			-- An uncertain legacy request cannot be replayed safely from this screen.
			if ok then latch.current = false; setBusy(false) end
		end)
	end
	return e("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		Hint = e(C.Text, { Text = message, Size = UDim2.new(1, 0, 0, 48), TextSize = 14, TextColor3 = T.Gold }),
		Grid = e("Frame", { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -228), BackgroundTransparency = 1 }, {
			Items = e(C.InventoryGrid, { Snapshot = snapshot, Items = if review then items else props.Items, MaterialIds = ids, MaterialMode = false, Width = props.Width, FilterKey = tostring(review), OnSelect = function(id)
				if latch.current or review then return end
				local artifact = snapshot.Artifacts[id]
				if not artifact or not eligible(artifact) then setMessage("That artifact is protected. Unequip or unlock it first."); return end
				setSelected(function(previous) local nextSelection = table.clone(previous); nextSelection[id] = not nextSelection[id]; return nextSelection end)
			end }),
		}),
  Quick = e("Frame", { Position = UDim2.new(0, 0, 1, -172), Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1 }, {
   Common = e(C.Button, { Text = "Select Common", Size = UDim2.new(0.33, -4, 1, 0), Disabled = busy or review, OnActivate = function() quickPick(1) end }),
   Uncommon = e(C.Button, { Text = "Select Uncommon", Position = UDim2.fromScale(0.33, 0), Size = UDim2.new(0.34, -4, 1, 0), Disabled = busy or review, OnActivate = function() quickPick(2) end }),
   All = e(C.Button, { Text = "All Unequipped", Position = UDim2.fromScale(0.67, 0), Size = UDim2.fromScale(0.33, 1), Disabled = busy or review, OnActivate = function() quickPick(nil) end }),
  }),
  Total = e(C.Text, { Text = string.format("%d selected  ·  +%s Gold%s", #ids, tostring(total), if review then "  ·  Permanent sale" else ""), Position = UDim2.new(0, 0, 1, -116), Size = UDim2.new(1, 0, 0, 52), TextSize = 18, FontFace = T.Theme.Fonts.Number, TextColor3 = T.Gold }),
		Pick = e(C.Button, { Name = "SellQuickPickButton", Text = if review then "Back" else "Cancel sell", Position = UDim2.new(0, 0, 1, -56), Size = UDim2.new(0.32, -6, 0, 48), Disabled = busy, OnActivate = if review then function() setReview(false) end else props.OnCancel }),
		Clear = e(C.Button, { Name = "ClearSaleButton", Text = "Clear", Position = UDim2.new(0.32, 0, 1, -56), Size = UDim2.new(0.2, -6, 0, 48), Disabled = busy, OnActivate = function() setSelected({}); setReview(false) end }),
		Confirm = e(C.Button, { Name = "ReviewSaleButton", Text = if busy then "Checking…" elseif review then "Confirm sale" else "Review sale", Position = UDim2.new(0.52, 0, 1, -56), Size = UDim2.new(0.48, 0, 0, 48), Primary = true, Accent = if review then T.Bad else T.Gold, Disabled = busy or #ids == 0 or not props.OnSellArtifacts, OnActivate = if review then sell else function() setReview(true) end }),
	})
end
