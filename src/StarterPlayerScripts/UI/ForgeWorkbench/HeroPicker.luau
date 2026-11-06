--!strict
-- React lifecycle adapter for the same imperative drawer used by Synthesis and legacy Forge.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Drawer = require(script.Parent.Parent.HeroSelectionDrawer)
local Model = require(script.Parent.Model)

local function HeroPicker(props: any)
	local latest = React.useRef(props)
	latest.current = props
	local ref = React.useRef(nil :: any)
	React.useEffect(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "ForgeHeroSelection"
		gui.ResetOnSpawn = false
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.DisplayOrder = 82
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		local alive = true
		local drawer = Drawer.new(gui, 1, function()
			if alive then latest.current.OnClose() end
		end)
		ref.current = drawer
		return function()
			alive = false
			local target = drawer.ReturnFocus
			local selected = GuiService.SelectedObject
			local restore = selected and selected:IsDescendantOf(drawer.Root)
			drawer:Close(true)
			gui:Destroy()
			-- Destroy cancels deferred drawer focus work; React's opener already exists here.
			if restore and target and target:IsDescendantOf(game) and target.Visible and target.Interactable then
				GuiService.SelectedObject = target
			end
			ref.current = nil
		end
	end, {})
	React.useEffect(function()
		local drawer = ref.current
		if not drawer then return end
		local snapshot, target = props.Snapshot, props.Target
		local entries = {}
		for _, hero in Model.pickerHeroes(snapshot, target, "ALL", "LEVEL") do
			local current = hero.EquippedArtifactUUID == target.UUID
			local equipped = hero.EquippedArtifactUUID and snapshot.Artifacts[hero.EquippedArtifactUUID]
			table.insert(entries, {
				UUID = hero.UUID, Hero = hero, Selected = current,
				Status = if current then "Equipped: This" elseif equipped then "Equipped: " .. equipped.DisplayName else "No Artifact",
				Action = if current then "UNEQUIP" elseif equipped then "SWAP" else "EQUIP",
			})
		end
		table.sort(entries, function(a, b)
			if a.Selected ~= b.Selected then return a.Selected end
			if a.Hero.Level ~= b.Hero.Level then return a.Hero.Level > b.Hero.Level end
			if a.Hero.Stars ~= b.Hero.Stars then return a.Hero.Stars > b.Hero.Stars end
			if a.Hero.DisplayName ~= b.Hero.DisplayName then return a.Hero.DisplayName < b.Hero.DisplayName end
			return a.UUID < b.UUID
		end)
		drawer:SetContent("EQUIP ARTIFACT", target.DisplayName, entries, function(uuid)
			local current = latest.current
			if not current.Busy then current.OnSelect(uuid) end
		end, "No compatible heroes in your roster.")
		drawer:Open()
	end, { props.Snapshot, props.Target })
	return nil
end

return HeroPicker
