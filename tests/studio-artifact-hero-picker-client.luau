-- Client-only controller integration check. Remotes are fakes; no inventory is changed.
local player = game.Players.LocalPlayer
local ui = player.PlayerScripts:FindFirstChild("SelectionTestModules") or player.PlayerScripts.UI
local Forge = require(ui.ForgeController)
local Drawer = require(ui.HeroSelectionDrawer)
local old = player.PlayerGui:FindFirstChild("ArtifactPickerTest")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "ArtifactPickerTest"
gui.DisplayOrder = 1100
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player.PlayerGui
local root = Instance.new("Frame")
root.Parent = gui
local hero = { UUID = "equipment-test", TemplateId = "hero_han", DisplayName = "Han", Archetype = "Striker", Level = 2, Stars = 1 }
local profile = { Heroes = { [hero.UUID] = hero }, Artifacts = {
	new = { DisplayName = "Test Daggers", Type = "DAGGERS" },
	old = { DisplayName = "Old Daggers", Type = "DAGGERS" },
} }
local calls = {}
local forge = setmetatable({ Root = root, Drawer = Instance.new("Frame"), SelectedAssignArtifactUUID = "new", Busy = false }, Forge)
forge.ResolveProfile = function() return profile end
forge.Refresh = function() end
forge.HeroDrawer = Drawer.new(gui, 90, function() forge.PickerMode = "NONE" end)
local original = forge.HeroDrawer.SetContent
local action, entries
forge.HeroDrawer.SetContent = function(self, title, subtitle, items, callback, empty)
	action, entries = callback, items
	original(self, title, subtitle, items, callback, empty)
end
forge.RequestEquip = { InvokeServer = function(_, uuid, artifact)
	table.insert(calls, { "equip", uuid, artifact })
	task.wait(0.05)
	hero.EquippedArtifactUUID = artifact
	return true
end }
forge.RequestUnequip = { InvokeServer = function(_, uuid)
	table.insert(calls, { "unequip", uuid })
	task.wait(0.05)
	hero.EquippedArtifactUUID = nil
	return true
end }
local results = {}
local function check(value, message)
	assert(value, message)
	table.insert(results, message)
end
forge:OpenHeroDrawer("new")
check(entries[1].Action == "EQUIP", "Unequipped hero offers Equip")
action(hero.UUID)
action(hero.UUID)
task.wait(0.1)
check(#calls == 1 and calls[1][1] == "equip" and calls[1][3] == "new", "Equip dispatches once while busy")
check(hero.EquippedArtifactUUID == "new" and not forge.HeroDrawer.Root.Visible, "Equip closes shared drawer")
hero.EquippedArtifactUUID = "old"
forge:OpenHeroDrawer("new")
check(entries[1].Action == "SWAP" and entries[1].Status == "Equipped: Old Daggers", "Equipped hero offers Swap and current artifact status")
action(hero.UUID)
task.wait(0.1)
check(#calls == 2 and calls[2][1] == "equip" and hero.EquippedArtifactUUID == "new", "Swap dispatches Equip with selected artifact")
forge:OpenHeroDrawer("new")
check(entries[1].Selected and entries[1].Action == "UNEQUIP", "Current wearer offers Unequip with selected styling")
action(hero.UUID)
task.wait(0.1)
check(#calls == 3 and calls[3][1] == "unequip" and hero.EquippedArtifactUUID == nil, "Unequip dispatches correct remote")
forge.RequestEquip = { InvokeServer = function() error("simulated network failure") end }
forge:OpenHeroDrawer("new")
action(hero.UUID)
task.wait()
check(not forge.Busy and forge.HeroDrawer.Opened and forge.HeroDrawer.Footer.Text:find("failed"), "Failed equip leaves drawer retryable")
forge:ClosePicker()
forge.Drawer:Destroy()
gui:Destroy()
return results
