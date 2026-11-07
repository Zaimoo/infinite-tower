-- Run in Studio Client. Uses an isolated module folder when supplied, otherwise the synced UI.
local player = game.Players.LocalPlayer
local ui = player.PlayerScripts:FindFirstChild("SelectionTestModules") or player.PlayerScripts.UI
local Synth = require(ui.SynthesisController)
local catalog = require(game.ReplicatedStorage.Shared.Config.HeroCatalog)
local old = player.PlayerGui:FindFirstChild("SelectionFlowTest")
if old then old:Destroy() end
local heroes = {}
for i = 1, 20 do
	local seed = catalog.Seeds[({ "hero_han", "hero_jenna", "hero_catio", "hero_aaron" })[(i - 1) % 4 + 1]]
	heroes["test" .. i] = {
		UUID = "test" .. i, TemplateId = seed.HeroId,
		DisplayName = if i == 2 then "Sovereign Archon of the Northern Tower" elseif i % 3 == 0 then "Duplicate" else seed.DisplayName,
		Archetype = seed.Archetype, Stars = seed.BaseStar, Level = i % 9 + 1,
		XP = 0, OverflowXP = 0, QualityScalar = 1, BaseHP = seed.NativeHP,
		BaseATK = seed.NativeATK, BaseLabor = seed.NativeLabor, AttackInterval = seed.AttackInterval,
		AttackRange = seed.AttackRange, Assignment = "BENCHED", CurrentStamina = 100, MaxStamina = 100,
	}
end
heroes.test3.IsHardAuditComa = true
heroes.test4.Reserved = true
local gui = Instance.new("ScreenGui")
gui.Name = "SelectionFlowTest"
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player.PlayerGui
local synth = Synth.new(gui, {} :: any)
synth.Request = function(_, command)
	if command == "STATE" then return { Success = true, State = { Heroes = heroes } } end
	task.wait(0.4)
	return { Success = true, Preview = { CanCommit = true, Token = "stale", Warnings = {}, Donors = { "test5" } } }
end
synth.State = { Heroes = heroes }
synth.Root.Visible, synth.Scrim.Visible = true, true
synth:Render()
local t = { Synth = synth, Heroes = heroes, Gui = gui, Results = {} }
_G.SelectionFlowTest = t
local s = t.Synth
local function check(value, message)
	assert(value, message)
	table.insert(t.Results, message)
end
local function close()
	s.HeroDrawer:Close(true)
end

check(s.ScreenState == "NoRecipient", "Initial state has no recipient")
s:PressRosterHero("test1")
check(s.Recipient == nil and #s.Donors == 0, "Material cards never assign a recipient")
s:OpenPicker("RECIPIENT")
check(s.ScreenState == "PickerOpen", "Drawer blocks background controls")
s:Pick("test3")
check(s.Recipient == nil, "Coma recipient cannot be selected")
s:Pick("test4")
check(s.Recipient == nil, "Reserved recipient cannot be selected")
close()
check(s.Recipient == nil, "First-selection cancellation preserves empty state")
s:OpenPicker("RECIPIENT")
s:Pick("test1")
close()
check(s.Recipient == "test1" and s.ScreenState == "RecipientSelected", "First selection enables materials")
s:PressRosterHero("test5")
check(#s.Donors == 1, "Right roster selects materials after recipient selection")
local serial = s.PreviewSerial
local marker = { CanCommit = false, Marker = true }
s.Preview = marker
s:OpenPicker("RECIPIENT")
s:PressRosterHero("test6")
s:Confirm()
check(#s.Donors == 1 and not s.Popup.Visible, "Roster and Confirm handlers reject input behind drawer")
close()
check(s.Preview == marker and #s.Donors == 1 and s.PreviewSerial == serial, "Cancellation preserves materials and preview")
s:OpenPicker("RECIPIENT")
s:Pick("test1")
close()
check(s.Preview == marker and #s.Donors == 1 and s.PreviewSerial == serial, "Same hero preserves materials and preview")
-- Let the pending request enter InvokeServer, then change recipient before it returns.
s.Preview = nil
s:QueuePreview()
task.wait(0.25)
s:OpenPicker("RECIPIENT")
s:Pick("test2")
close()
check(s.Recipient == "test2" and #s.Donors == 0 and s.Preview == nil, "Different recipient clears dependent selections")
task.wait(0.5)
check(s.Preview == nil and not s.Loading, "Delayed preview from old recipient is discarded")
s:OpenPicker("RECIPIENT")
task.wait(0.3)
game:GetService("GuiService").SelectedObject = s.HeroDrawer.Buttons[1]
close()
task.wait()
check(game:GetService("GuiService").SelectedObject == s.RecipientSlot.Button, "Closing restores recipient-button focus")
for _ = 1, 8 do
	s.Root.Visible = true
	s:OpenPicker("RECIPIENT")
	s.HeroDrawer:Close()
	s:Close()
end
task.wait(0.3)
check(not s.Picker.Visible and not s.HeroDrawer.Opened, "Rapid close cancels animation and removes input blocker")
s.Root.Visible = true
s.Scrim.Visible = true
s.State = { Heroes = {} }
s:RenderPicker()
check(s.HeroDrawer.Empty.Visible, "Empty authoritative roster shows empty message")
s.State = { Heroes = t.Heroes }
s.Recipient = "test2"
s.Donors = { "test5" }
s.Preview = marker
local request = s.Request
s.Request = function() return { Success = true, State = { Heroes = {} } } end
s:Refresh()
task.wait()
check(s.Recipient == nil and #s.Donors == 0 and s.Preview == nil, "Refresh removing recipient clears dependent state")
s.Request = request
s.State = { Heroes = t.Heroes }
s:OpenPicker("RECIPIENT")
task.wait(0.3)
check(#s.HeroDrawer.Buttons == 20 and not s.HeroDrawer.Empty.Visible, "Long and duplicate names render in multi-row roster")
local buttons = s.HeroDrawer.Buttons
check(buttons[1].NextSelectionUp == s.HeroDrawer.CloseButton, "Gamepad navigation returns to close control")
check(buttons[1].AbsoluteSize.Y >= 44 and s.HeroDrawer.CloseButton.AbsoluteSize.Y >= 44, "Drawer action and close targets are at least 44 pixels")
s.Recipient = "test2"
s:RenderPicker()
check(s.HeroDrawer.Buttons[1]:GetAttribute("HeroUUID") == "test2", "Current recipient always sorts first")
local duplicateOrder = {}
for i, button in s.HeroDrawer.Buttons do duplicateOrder[button:GetAttribute("HeroUUID")] = i end
check(duplicateOrder.test18 < duplicateOrder.test9, "Equal-name equal-level heroes have stable UUID ordering")
close()
s:Close()
s:OpenPicker("RECIPIENT")
check(not s.Picker.Visible, "Closed Synthesis rejects stale picker-open handlers")
return t.Results
