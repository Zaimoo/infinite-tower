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

-- Surfaces: lifted from near-black so contents don't sit in a void.
Tokens.Surface = table.freeze({
	Window = tone(Color3.fromRGB(86, 58, 128), Color3.fromRGB(40, 26, 64), Color3.fromRGB(246, 204, 116)),
	Panel = tone(Color3.fromRGB(66, 46, 98), Color3.fromRGB(32, 22, 52), Color3.fromRGB(222, 178, 104)),
	Inset = tone(Color3.fromRGB(44, 30, 68), Color3.fromRGB(24, 16, 38), Color3.fromRGB(176, 140, 90)),
	Hud = tone(Color3.fromRGB(70, 48, 104), Color3.fromRGB(30, 20, 48), Color3.fromRGB(246, 204, 116)),
})

-- Window header bars, one saturated colour per area of the game.
Tokens.Domain = table.freeze({
	Forge = tone(Color3.fromRGB(240, 120, 44), Color3.fromRGB(150, 50, 20), Color3.fromRGB(255, 226, 150)),
	Pit = tone(Color3.fromRGB(178, 100, 246), Color3.fromRGB(96, 44, 172), Color3.fromRGB(255, 226, 150)),
	Tower = tone(Color3.fromRGB(70, 156, 246), Color3.fromRGB(28, 72, 156), Color3.fromRGB(220, 244, 255)),
	Fortress = tone(Color3.fromRGB(252, 200, 70), Color3.fromRGB(196, 122, 22), Color3.fromRGB(255, 248, 210)),
	Index = tone(Color3.fromRGB(230, 192, 130), Color3.fromRGB(152, 108, 58), Color3.fromRGB(255, 244, 214)),
	Store = tone(Color3.fromRGB(236, 70, 92), Color3.fromRGB(150, 24, 46), Color3.fromRGB(255, 226, 150)),
	Settings = tone(Color3.fromRGB(128, 116, 160), Color3.fromRGB(62, 54, 88), Color3.fromRGB(236, 228, 246)),
	Backpack = tone(Color3.fromRGB(246, 186, 46), Color3.fromRGB(184, 104, 16), Color3.fromRGB(255, 248, 210)),
	Squad = tone(Color3.fromRGB(70, 200, 150), Color3.fromRGB(24, 110, 80), Color3.fromRGB(226, 255, 240)),
})

-- Button intents (plan §3.3). Colour says what a button does.
export type Intent = "Primary" | "Confirm" | "Travel" | "Secondary" | "Danger" | "Disabled"
Tokens.Intent = table.freeze({
	Primary = tone(Color3.fromRGB(255, 216, 92), Color3.fromRGB(222, 136, 28), Color3.fromRGB(255, 250, 214)),
	Confirm = tone(Color3.fromRGB(96, 224, 116), Color3.fromRGB(28, 140, 62), Color3.fromRGB(226, 255, 230)),
	Travel = tone(Color3.fromRGB(80, 176, 252), Color3.fromRGB(30, 90, 192), Color3.fromRGB(226, 244, 255)),
	Secondary = tone(Color3.fromRGB(120, 86, 180), Color3.fromRGB(58, 38, 100), Color3.fromRGB(236, 206, 140)),
	Danger = tone(Color3.fromRGB(244, 84, 96), Color3.fromRGB(162, 28, 46), Color3.fromRGB(255, 220, 220)),
	Disabled = tone(Color3.fromRGB(92, 86, 108), Color3.fromRGB(52, 48, 64), Color3.fromRGB(140, 132, 158)),
})

-- Meaning colours for toasts, callouts and bars.
export type Severity = "info" | "success" | "warn" | "error" | "reward" | "block"
Tokens.Severity = table.freeze({
	info = Color3.fromRGB(110, 196, 255),
	success = Color3.fromRGB(110, 236, 130),
	warn = Color3.fromRGB(255, 194, 72),
	error = Color3.fromRGB(255, 96, 104),
	block = Color3.fromRGB(255, 96, 104),
	reward = Color3.fromRGB(255, 214, 92),
})
Tokens.SeverityIcon = table.freeze({
	info = "Eye", success = "Check", warn = "Warning", error = "Warning", block = "Lock", reward = "Spark",
})

Tokens.BarTone = table.freeze({
	Gold = tone(Color3.fromRGB(255, 226, 110), Color3.fromRGB(226, 146, 30), Color3.fromRGB(255, 250, 214)),
	Jade = tone(Color3.fromRGB(120, 240, 140), Color3.fromRGB(34, 156, 70), Color3.fromRGB(226, 255, 230)),
	Azure = tone(Color3.fromRGB(110, 196, 255), Color3.fromRGB(34, 104, 210), Color3.fromRGB(226, 244, 255)),
	Crimson = tone(Color3.fromRGB(255, 110, 120), Color3.fromRGB(176, 30, 50), Color3.fromRGB(255, 220, 220)),
	Arcane = tone(Color3.fromRGB(206, 150, 255), Color3.fromRGB(120, 58, 210), Color3.fromRGB(240, 226, 255)),
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
