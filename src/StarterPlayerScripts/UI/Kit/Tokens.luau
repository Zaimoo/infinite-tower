--!strict
-- StarterPlayerScripts/UI/Kit/Tokens.luau
-- "Brighter Grimoire" (UI overhaul plan §3): Gilded Grimoire's ink outlines, gold rails and Cinzel
-- type, with brighter surfaces, saturated domain headers and vivid intent colours. Dark is for
-- backgrounds only; anything you can press or read is bright. Built on Shared/Util/GildedGrimoire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Grimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))

export type Tone = { Top: Color3, Bottom: Color3, Rail: Color3 }

local function tone(top: Color3, bottom: Color3, rail: Color3): Tone
	return table.freeze({ Top = top, Bottom = bottom, Rail = rail })
end

local Tokens = {}

Tokens.Grimoire = Grimoire
Tokens.Ink = Grimoire.Ink
Tokens.Fonts = Grimoire.Fonts
Tokens.Text = Grimoire.Text

-- Surfaces: Neo-Gothic Astral Obsidian glass & deep slate panels.
Tokens.Surface = table.freeze({
	Window = tone(Color3.fromRGB(22, 32, 48), Color3.fromRGB(11, 16, 24), Color3.fromRGB(229, 196, 112)),
	Panel = tone(Color3.fromRGB(20, 30, 46), Color3.fromRGB(10, 15, 24), Color3.fromRGB(56, 189, 248)),
	Inset = tone(Color3.fromRGB(15, 23, 36), Color3.fromRGB(9, 14, 23), Color3.fromRGB(71, 95, 126)),
	Hud = tone(Color3.fromRGB(18, 28, 44), Color3.fromRGB(11, 16, 24), Color3.fromRGB(56, 189, 248)),
})

-- Window header bars, one saturated colour per area of the game.
Tokens.Domain = table.freeze({
	Forge = tone(Color3.fromRGB(240, 120, 44), Color3.fromRGB(150, 50, 20), Color3.fromRGB(253, 230, 138)),
	Pit = tone(Color3.fromRGB(36, 138, 196), Color3.fromRGB(14, 52, 92), Color3.fromRGB(229, 196, 112)),
	Tower = tone(Color3.fromRGB(244, 63, 94), Color3.fromRGB(140, 22, 44), Color3.fromRGB(253, 230, 138)),
	Fortress = tone(Color3.fromRGB(229, 196, 112), Color3.fromRGB(168, 120, 36), Color3.fromRGB(253, 244, 204)),
	Index = tone(Color3.fromRGB(229, 196, 112), Color3.fromRGB(146, 108, 52), Color3.fromRGB(253, 244, 204)),
	Store = tone(Color3.fromRGB(244, 63, 94), Color3.fromRGB(146, 22, 46), Color3.fromRGB(229, 196, 112)),
	Settings = tone(Color3.fromRGB(51, 65, 85), Color3.fromRGB(22, 32, 48), Color3.fromRGB(186, 230, 253)),
	Backpack = tone(Color3.fromRGB(229, 196, 112), Color3.fromRGB(162, 108, 30), Color3.fromRGB(253, 244, 204)),
	Squad = tone(Color3.fromRGB(56, 189, 248), Color3.fromRGB(18, 90, 140), Color3.fromRGB(224, 242, 254)),
})

-- Button intents (plan §3.3). Colour says what a button does.
export type Intent = "Primary" | "Confirm" | "Travel" | "Secondary" | "Danger" | "Disabled"
Tokens.Intent = table.freeze({
	Primary = tone(Color3.fromRGB(245, 216, 138), Color3.fromRGB(198, 146, 48), Color3.fromRGB(253, 244, 204)),
	Confirm = tone(Color3.fromRGB(74, 222, 128), Color3.fromRGB(24, 138, 66), Color3.fromRGB(218, 255, 228)),
	Travel = tone(Color3.fromRGB(56, 189, 248), Color3.fromRGB(18, 92, 160), Color3.fromRGB(224, 242, 254)),
	Secondary = tone(Color3.fromRGB(30, 44, 66), Color3.fromRGB(15, 23, 36), Color3.fromRGB(56, 189, 248)),
	Danger = tone(Color3.fromRGB(244, 63, 94), Color3.fromRGB(156, 24, 48), Color3.fromRGB(255, 216, 224)),
	Disabled = tone(Color3.fromRGB(48, 58, 74), Color3.fromRGB(26, 33, 45), Color3.fromRGB(100, 116, 139)),
})

-- Meaning colours for toasts, callouts and bars.
export type Severity = "info" | "success" | "warn" | "error" | "reward" | "block"
Tokens.Severity = table.freeze({
	info = Color3.fromRGB(56, 189, 248),
	success = Color3.fromRGB(74, 222, 128),
	warn = Color3.fromRGB(245, 196, 82),
	error = Color3.fromRGB(244, 63, 94),
	block = Color3.fromRGB(244, 63, 94),
	reward = Color3.fromRGB(229, 196, 112),
})
Tokens.SeverityIcon = table.freeze({
	info = "Eye", success = "Check", warn = "Warning", error = "Warning", block = "Lock", reward = "Spark",
})

Tokens.BarTone = table.freeze({
	Gold = tone(Color3.fromRGB(245, 216, 138), Color3.fromRGB(198, 146, 48), Color3.fromRGB(253, 244, 204)),
	Jade = tone(Color3.fromRGB(74, 222, 128), Color3.fromRGB(24, 144, 68), Color3.fromRGB(218, 255, 228)),
	Azure = tone(Color3.fromRGB(56, 189, 248), Color3.fromRGB(18, 96, 168), Color3.fromRGB(224, 242, 254)),
	Crimson = tone(Color3.fromRGB(244, 63, 94), Color3.fromRGB(162, 24, 48), Color3.fromRGB(255, 216, 224)),
	Arcane = tone(Color3.fromRGB(125, 211, 252), Color3.fromRGB(14, 116, 176), Color3.fromRGB(224, 242, 254)),
})

-- Type scale (px at 1080p). Nothing below Caption.
Tokens.Type = table.freeze({ Title = 28, Section = 18, Number = 26, Body = 15, Caption = 13 })
Tokens.Space = table.freeze({ XS = 4, S = 8, M = 12, L = 16, XL = 24, XXL = 32 })
Tokens.Radius = table.freeze({ Window = 16, Panel = 12, Tile = 10, Button = 10, Pill = 999 })
Tokens.ButtonHeight = table.freeze({ L = 56, M = 44, S = 36 })

--============================================================================
-- DRAWING HELPERS (shared by every kit piece)
--============================================================================

-- Creates an Instance with properties; `parent` last, so it is set after the properties.
function Tokens.New(className: string, props: { [string]: any }?, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props or {} do (inst :: any)[k] = v end
	if parent then inst.Parent = parent end
	return inst
end

-- Gradient fill, ink outline, inset rail and corners on `frame`, in `t`. Safe to call again
-- (replaces the previous decoration), so updates can restyle a piece.
function Tokens.Paint(frame: GuiObject, t: Tone, radius: number?, ink: number?, railTransparency: number?)
	local r = radius or Tokens.Radius.Panel
	for _, name in { "KitCorner", "KitFill", "KitInk", "KitRail" } do
		local old = frame:FindFirstChild(name)
		if old then old:Destroy() end
	end
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	Tokens.New("UICorner", { Name = "KitCorner", CornerRadius = UDim.new(0, r) }, frame)
	Tokens.New("UIGradient", { Name = "KitFill", Rotation = 90, Color = ColorSequence.new(t.Top, t.Bottom) }, frame)
	Tokens.New("UIStroke", {
		Name = "KitInk", Color = Tokens.Ink, Thickness = ink or 2.5,
		LineJoinMode = Enum.LineJoinMode.Round, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, frame)
	local rail = Tokens.New("Frame", {
		Name = "KitRail", BackgroundTransparency = 1, Active = false,
		Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), ZIndex = frame.ZIndex,
	}, frame)
	Tokens.New("UICorner", { CornerRadius = UDim.new(0, math.max(2, math.min(r, 999) - 3)) }, rail)
	Tokens.New("UIStroke", {
		Color = t.Rail, Thickness = 1.4, Transparency = railTransparency or 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, rail)
end

-- A TextLabel in the theme. role: "Title" | "Number" | "Body" (default Body).
function Tokens.Label(parent: Instance?, text: string, size: number, role: string?, props: { [string]: any }?): TextLabel
	local label = Tokens.New("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = if role == "Title" then Tokens.Fonts.Title elseif role == "Number" then Tokens.Fonts.Number else Tokens.Fonts.Body,
		Text = text,
		TextSize = math.max(size, Tokens.Type.Caption),
		TextColor3 = Tokens.Text.Parchment,
		TextStrokeColor3 = Tokens.Ink,
		TextStrokeTransparency = if role == "Body" or role == nil then 0.5 else 0.1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		RichText = true,
	})
	for k, v in props or {} do (label :: any)[k] = v end
	if parent then label.Parent = parent end
	return label
end

-- Readable instance names for tests, Studio MCP and focus maps: "Kit_SellAll".
function Tokens.Name(prefix: string, text: string?): string
	return prefix .. "_" .. (string.gsub(text or "", "[^%w]", ""))
end

return table.freeze(Tokens)
