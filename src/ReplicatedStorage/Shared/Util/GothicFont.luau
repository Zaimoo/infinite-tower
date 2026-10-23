--!strict
-- ReplicatedStorage/Shared/Util/GothicFont.luau
-- Authoritative typography system for Infinite Towers.
-- Implements the Classical Roman / Inscriptional fantasy serif aesthetic (Cinzel / Trajan)
-- with gold/bronze metallic styling matching the official design specification.

local TweenService = game:GetService("TweenService")

local GothicFont = {}

-- Authoritative Custom Font Asset ID uploaded by user (e.g. "rbxassetid://123456789")
-- When set, all text components dynamically load this custom font asset.
GothicFont.CustomFontAssetId = nil :: string?

export type FontWeightType = "Bold" | "SemiBold" | "Regular" | "Medium" | "Black"
export type FontRole = "Title" | "Header" | "SubHeader" | "Body" | "Button" | "Nav"

local WEIGHT_MAP: { [FontWeightType]: any } = {}
local hasFontWeight, _ = pcall(function()
	WEIGHT_MAP = {
		Regular = Enum.FontWeight.Regular,
		Medium = Enum.FontWeight.Medium,
		SemiBold = Enum.FontWeight.SemiBold,
		Bold = Enum.FontWeight.Bold,
		Black = Enum.FontWeight.Heavy,
	}
	return true
end)

-- Built-in Classical Roman fantasy families available natively in Roblox Studio:
local PRIMARY_FAMILY = "CinzelDecorative"
local SECONDARY_FAMILY = "Cinzel"
local DECORATIVE_FAMILY = "CinzelDecorative"

-- Colors sampled directly from the inscriptional navigation specification
local C = {
	-- Signature Roman Inscriptional Gold
	Gold = Color3.fromRGB(228, 186, 115),
	GoldBright = Color3.fromRGB(252, 222, 156),
	GoldMuted = Color3.fromRGB(180, 142, 85),
	GoldDark = Color3.fromRGB(132, 102, 58),

	-- Metallic Silver / Obsidian Accents
	Silver = Color3.fromRGB(246, 244, 255),
	SilverDim = Color3.fromRGB(185, 175, 205),
	TextWhite = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(165, 155, 185),

	-- Dark Inscriptional Stroke / Shadow
	StrokeDark = Color3.fromRGB(20, 15, 26),
	ShadowDark = Color3.fromRGB(10, 8, 14),
}

GothicFont.Palette = C

-- Fallback Enum.Font for legacy methods that require Enum.Font
GothicFont.LegacyFont = (pcall(function() return Enum.Font.Garamond end) and Enum.Font.Garamond) or nil
GothicFont.LegacyBold = (pcall(function() return Enum.Font.Garamond end) and Enum.Font.Garamond) or nil

-- Resolves the Font object for a given weight
function GothicFont.GetFont(weight: FontWeightType?): any
	local w = WEIGHT_MAP[weight or "Bold"]

	if GothicFont.CustomFontAssetId and GothicFont.CustomFontAssetId ~= "" then
		local s, custom = pcall(function()
			return Font.fromId(GothicFont.CustomFontAssetId :: string, w)
		end)
		if s and custom then
			return custom
		end
	end

	-- Use native Cinzel Roman Inscriptional serif
	local success, font = pcall(function()
		return Font.fromName(PRIMARY_FAMILY, w)
	end)

	if success and font then
		return font
	end

	-- Fallback to Trajan
	local s2, font2 = pcall(function()
		return Font.fromName(SECONDARY_FAMILY, w)
	end)
	if s2 and font2 then
		return font2
	end

	local s3, fallback = pcall(function()
		return Font.fromEnum(Enum.Font.Garamond)
	end)
	if s3 and fallback then
		return fallback
	end

	return nil
end

-- Sets a custom uploaded Creator Store font asset ID
function GothicFont.SetCustomFont(assetId: string?)
	GothicFont.CustomFontAssetId = assetId
end

-- Formats text with classical Roman wide tracking / letter-spacing
function GothicFont.FormatSpaced(text: string): string
	local chars = {}
	for i = 1, #text do
		local c = text:sub(i, i)
		table.insert(chars, c)
		if i < #text and c ~= " " and text:sub(i + 1, i + 1) ~= " " then
			table.insert(chars, " ")
		end
	end
	return table.concat(chars, "")
end

export type ApplyOptions = {
	Role: FontRole?,
	Color: Color3?,
	Size: number?,
	Stroke: boolean?,
	StrokeColor: Color3?,
	StrokeThickness: number?,
	StrokeTransparency: number?,
	Spaced: boolean?,
	Uppercase: boolean?,
	HoverColor: Color3?,
}

-- Applies the Gothic Roman typography style to any TextLabel or TextButton
function GothicFont.Apply(textObj: TextLabel | TextButton | TextBox, opts: ApplyOptions?)
	local options = opts or {}
	local role = options.Role or "Title"

	local weight: FontWeightType = "Bold"
	local defaultSize = 14
	local defaultColor = C.Gold

	if role == "Title" then
		weight = "Bold"
		defaultSize = 22
		defaultColor = C.Gold
	elseif role == "Header" then
		weight = "Bold"
		defaultSize = 16
		defaultColor = C.Gold
	elseif role == "SubHeader" then
		weight = "SemiBold"
		defaultSize = 14
		defaultColor = C.Silver
	elseif role == "Nav" then
		weight = "Bold"
		defaultSize = 14
		defaultColor = C.Gold
	elseif role == "Button" then
		weight = "Bold"
		defaultSize = 14
		defaultColor = C.TextWhite
	elseif role == "Body" then
		weight = "Regular"
		defaultSize = 13
		defaultColor = C.SilverDim
	end

	local fontObj = GothicFont.GetFont(weight)
	if fontObj then
		pcall(function()
			(textObj :: any).FontFace = fontObj
		end)
	elseif GothicFont.LegacyFont then
		pcall(function()
			(textObj :: any).Font = GothicFont.LegacyFont
		end)
	end
	textObj.TextSize = options.Size or defaultSize
	textObj.TextColor3 = options.Color or defaultColor

	if options.Uppercase and textObj.Text ~= "" then
		textObj.Text = string.upper(textObj.Text)
	end

	if options.Spaced and textObj.Text ~= "" then
		textObj.Text = GothicFont.FormatSpaced(textObj.Text)
	end

	-- Apply subtle contextual text stroke for crisp contrast against any background
	local strokeEnabled = if options.Stroke ~= nil then options.Stroke else (role == "Title" or role == "Nav" or role == "Header" or role == "Button")
	if strokeEnabled then
		local existing = textObj:FindFirstChild("GothicTextStroke")
		if not existing then
			local stroke = Instance.new("UIStroke")
			stroke.Name = "GothicTextStroke"
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			stroke.Color = options.StrokeColor or C.StrokeDark
			stroke.Thickness = options.StrokeThickness or 0.8
			stroke.Transparency = options.StrokeTransparency or 0.25
			stroke.Parent = textObj
		end
	end

	-- Interactive hover transition for buttons
	if textObj:IsA("GuiButton") and (role == "Nav" or role == "Button") then
		local btn = textObj :: GuiButton
		local baseCol = options.Color or defaultColor
		local hoverCol = options.HoverColor or (if baseCol == C.Gold then C.GoldBright else C.Gold)
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.12), { TextColor3 = hoverCol }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.15), { TextColor3 = baseCol }):Play()
		end)
	end
end

-- Factory helper to create a styled TextLabel
function GothicFont.CreateLabel(props: {
	Name: string?,
	Text: string,
	Role: FontRole?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	TextSize: number?,
	Parent: Instance?,
	ZIndex: number?,
	Spaced: boolean?,
}): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = props.Name or "GothicLabel"
	lbl.BackgroundTransparency = 1
	lbl.Text = props.Text
	lbl.Size = props.Size or UDim2.fromScale(1, 1)
	lbl.Position = props.Position or UDim2.fromScale(0, 0)
	lbl.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	lbl.ZIndex = props.ZIndex or 1

	GothicFont.Apply(lbl, {
		Role = props.Role or "Title",
		Color = props.Color,
		Size = props.TextSize,
		Spaced = props.Spaced,
		Uppercase = true,
	})

	if props.Parent then
		lbl.Parent = props.Parent
	end

	return lbl
end

-- Factory helper to create a styled navigation button (as seen in the menu specification)
function GothicFont.CreateNavButton(props: {
	Name: string?,
	Text: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Parent: Instance?,
	ZIndex: number?,
	OnClick: (() -> ())?,
}): TextButton
	local btn = Instance.new("TextButton")
	btn.Name = props.Name or props.Text
	btn.Text = props.Text
	btn.BackgroundTransparency = 1
	btn.AutoButtonColor = false
	btn.Size = props.Size or UDim2.fromOffset(110, 32)
	btn.Position = props.Position or UDim2.fromScale(0, 0)
	btn.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	btn.ZIndex = props.ZIndex or 1

	GothicFont.Apply(btn, {
		Role = "Nav",
		Color = C.Gold,
		HoverColor = C.GoldBright,
		Size = 14,
		Stroke = true,
		StrokeThickness = 0.8,
		Uppercase = true,
	})

	if props.OnClick then
		btn.Activated:Connect(props.OnClick)
	end

	if props.Parent then
		btn.Parent = props.Parent
	end

	return btn
end

return GothicFont
