-- Real React adapter + shared drawer integration, with a controller callback spy.
local player = game.Players.LocalPlayer
local ui = player.PlayerScripts:FindFirstChild("SelectionTestModules") or player.PlayerScripts.UI
local React = require(game.ReplicatedStorage.Packages.React)
local ReactRoblox = require(game.ReplicatedStorage.Packages.ReactRoblox)
local Picker = require(ui.ForgeWorkbench.HeroPicker)
local Drawer = require(ui.HeroSelectionDrawer)
local snapshot = { Revision = 1, Gold = 10000, Gems = 1000, Heroes = {
	a = { UUID = "a", TemplateId = "hero_jenna", DisplayName = "Jenna", Archetype = "Marksman", Level = 2, Stars = 1 },
	b = { UUID = "b", TemplateId = "hero_jenna", DisplayName = "Jenna", Archetype = "Marksman", Level = 1, Stars = 1, EquippedArtifactUUID = "old" },
	c = { UUID = "c", TemplateId = "hero_jenna", DisplayName = "Jenna", Archetype = "Marksman", Level = 1, Stars = 1, EquippedArtifactUUID = "new" },
} , Artifacts = {
	new = { UUID = "new", TemplateId = "art_crystal_greatbow", DisplayName = "Crystal Greatbow", Type = "BOW", Star = 1, Rarity = 4 },
	old = { UUID = "old", TemplateId = "art_crystal_greatbow", DisplayName = "Old Bow", Type = "BOW", Star = 1, Rarity = 4 },
} }
local oldNew = Drawer.new
local drawer, action, items
Drawer.new = function(...)
	drawer = oldNew(...)
	local set = drawer.SetContent
	drawer.SetContent = function(self, title, subtitle, entries, callback, empty)
		action, items = callback, entries
		set(self, title, subtitle, entries, callback, empty)
	end
	return drawer
end
local host = Instance.new("Folder")
host.Name = "ReactPickerTest"
host.Parent = player.PlayerGui
local root = ReactRoblox.createRoot(host)
local chosen, closed = nil, false
local ok, err = pcall(function()
	root:render(React.createElement(Picker, {
		Snapshot = snapshot, Target = snapshot.Artifacts.new, Busy = false,
		OnSelect = function(uuid) chosen = uuid end, OnClose = function() closed = true end,
	}))
	task.wait(0.5)
	assert(drawer and drawer.Root.Visible, "React workbench mounts the shared drawer")
	assert(items[1].UUID == "c" and items[1].Action == "UNEQUIP", "Current wearer sorts first with Unequip")
	assert(items[2].UUID == "a" and items[2].Action == "EQUIP", "Compatible unarmed hero offers Equip")
	assert(items[3].UUID == "b" and items[3].Action == "SWAP", "Compatible armed hero offers Swap")
	action("b")
	assert(chosen == "b", "Shared drawer forwards selection to React controller")
	drawer:Close(true)
	assert(closed, "Drawer cancel returns to React workbench")
end)
Drawer.new = oldNew
root:unmount()
host:Destroy()
assert(ok, err)
assert(not player.PlayerGui:FindFirstChild("ForgeHeroSelection"), "Unmount removes overlay and input bindings")
return "7 React picker integration assertions passed"
