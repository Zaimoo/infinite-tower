--!strict
-- StarterPlayerScripts/Rendering/SkillCutIn.luau
-- Skill cut-in banners (GDD §4.7). When several of the local Master's heroes fire their Skills
-- together, the skill cutscene gives the camera to one of them (SkillCutscene); every other Skill
-- that fires with it or while it plays gets a cut-in here instead: a strip in the hero's Skill
-- colours with a live close-up of the hero (HeroCard.Portrait), its name and the skill's name. It
-- slides in from the right edge under the top letterbox bar, holds, and slides back out; several
-- stack downwards. Under Reduce Motion they appear and disappear without sliding.
-- Cosmetic and client-only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local SkillVfxCatalog = require(Shared:WaitForChild("Config"):WaitForChild("SkillVfxCatalog"))
local UI = script.Parent.Parent:WaitForChild("UI")
local UIFeel = require(UI:WaitForChild("UIFeel"))
local HeroCard = require(UI:WaitForChild("HeroCard"))

local SkillCutIn = {}

local MAX_SHOWN = 4
local SLIDE_IN = 0.24
local HOLD = 1.25
local SLIDE_OUT = 0.22
local ROW_HEIGHT = 64 -- px
local TOP = 0.14 -- share of the screen height: just under the cutscene's top bar (12%)

export type Entry = {
	HeroId: string,
	WeaponType: string?,
	HeroName: string,
	SkillName: string,
}

local GOLD = Color3.fromRGB(255, 214, 120)
local INK = Color3.fromRGB(6, 10, 16)

local gui = Instance.new("ScreenGui")
gui.Name = "SkillCutIns"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 39 -- with the cutscene's bars: over the HUD, under the Ultimate banner and windows
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local column = Instance.new("Frame")
column.Name = "Column"
column.BackgroundTransparency = 1
column.AnchorPoint = Vector2.new(1, 0)
column.Position = UDim2.new(1, 0, TOP, 0)
column.Size = UDim2.new(0.44, 0, 0.7, 0)
column.Parent = gui
local columnSize = Instance.new("UISizeConstraint")
columnSize.MaxSize = Vector2.new(480, math.huge)
columnSize.Parent = column
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Right
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 8)
list.Parent = column

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local order = 0
local shown: { Frame } = {}

local FALLBACK: SkillVfxCatalog.Palette = {
	Primary = Color3.fromRGB(255, 214, 120),
	Secondary = Color3.fromRGB(240, 186, 82),
	Core = Color3.fromRGB(255, 250, 230),
}

local function label(parent: Instance, font: Font, maxSize: number, color: Color3, centreY: number, heightShare: number): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.FontFace = font
	text.TextScaled = true
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.AnchorPoint = Vector2.new(0, 0.5)
	text.Position = UDim2.new(0, ROW_HEIGHT + 12, centreY, 0)
	text.Size = UDim2.new(1, -(ROW_HEIGHT + 24), heightShare, 0)
	text.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 1.5
	stroke.Parent = text
	return text
end

local function retire(row: Frame)
	local index = table.find(shown, row)
	if index then table.remove(shown, index) end
	local strip = row:FindFirstChild("Strip") :: Frame?
	if not strip or UIFeel.ReducedMotion() then
		row:Destroy()
		return
	end
	local tween = TweenService:Create(strip, TweenInfo.new(SLIDE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(1.15, 0) })
	tween.Completed:Once(function()
		row:Destroy()
	end)
	tween:Play()
end

-- Shows a cut-in for a hero's Skill.
function SkillCutIn.Show(entry: Entry)
	-- Too many at once: the oldest makes way.
	while #shown >= MAX_SHOWN do
		retire(shown[1])
	end
	local _, found = SkillVfxCatalog.Get(entry.HeroId, entry.WeaponType, "SKILL")
	local palette: SkillVfxCatalog.Palette = found or FALLBACK
	local deep = palette.Accent or palette.Secondary

	order += 1
	local row = Instance.new("Frame")
	row.Name = "CutIn"
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.Parent = column

	-- Slides on and off the right edge of the screen (the column is flush with it).
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundColor3 = Color3.new(1, 1, 1)
	strip.BorderSizePixel = 0
	strip.Size = UDim2.fromScale(1, 1)
	strip.Parent = row
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, deep:Lerp(Color3.new(0, 0, 0), 0.35)),
		ColorSequenceKeypoint.new(0.55, palette.Primary:Lerp(Color3.new(0, 0, 0), 0.55)),
		ColorSequenceKeypoint.new(1, palette.Primary:Lerp(Color3.new(0, 0, 0), 0.75)),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.15),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	gradient.Parent = strip
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = strip

	-- A bright edge on the leading side, in the hero's glow.
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BackgroundColor3 = palette.Core
	edge.BorderSizePixel = 0
	edge.Size = UDim2.new(0, 4, 1, 0)
	edge.Parent = strip

	local portraitHost = Instance.new("Frame")
	portraitHost.Name = "Portrait"
	portraitHost.BackgroundColor3 = palette.Primary:Lerp(Color3.new(0, 0, 0), 0.7)
	portraitHost.BorderSizePixel = 0
	portraitHost.Position = UDim2.fromOffset(6, 0)
	portraitHost.Size = UDim2.fromOffset(ROW_HEIGHT, ROW_HEIGHT)
	portraitHost.ClipsDescendants = true
	portraitHost.Parent = strip
	pcall(HeroCard.Portrait, portraitHost, { TemplateId = entry.HeroId }, "CloseUp")

	local heroText = label(strip, GildedGrimoire.Fonts.Body, 15, Color3.new(1, 1, 1), 0.3, 0.28)
	heroText.Text = string.upper(entry.HeroName)
	local skillText = label(strip, GildedGrimoire.Fonts.Title, 26, GOLD, 0.66, 0.42)
	skillText.Text = entry.SkillName

	table.insert(shown, row)
	if not UIFeel.ReducedMotion() then
		strip.Position = UDim2.fromScale(1.15, 0)
		TweenService:Create(strip, TweenInfo.new(SLIDE_IN, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, 0) }):Play()
	end
	task.delay(SLIDE_IN + HOLD, function()
		if row.Parent then
			retire(row)
		end
	end)
end

return SkillCutIn
