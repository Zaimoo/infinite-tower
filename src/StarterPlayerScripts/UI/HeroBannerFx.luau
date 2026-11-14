--!strict
-- StarterPlayerScripts/UI/HeroBannerFx.luau
-- Animated VFX and motion for the Summoning Altar's hero banners:
--   * CALL_OF_THE_RIFT: swirling dimensional rift tear, counter-rotating arcane vortex rings,
--     indigo/violet nebula washes, drifting rift motes, and arcane sparkle pops.
--   * A_STARS_ARRIVAL: twinkling 4-point starfield, diagonal shooting-star meteors, rotating
--     golden starburst rays, orbiting celestial astrolabe ring, and starlight motes.
-- Both banners also get a breathing FeaturedPortrait float, rail glow pulse, periodic light
-- shimmer sweeps across the card and 10X button, pity-near-full glow, entrance pop, and
-- charge-up / trigger-burst animations when summoning. Respects UIFeel.ReducedMotion().

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Theme = require(script.Parent:WaitForChild("Hud"):WaitForChild("Theme"))
local UIFeel = require(script.Parent:WaitForChild("UIFeel"))
local GildedGrimoire = require(Shared:WaitForChild("Util"):WaitForChild("GildedGrimoire"))

export type BannerKey = "CALL_OF_THE_RIFT" | "A_STARS_ARRIVAL"

export type BannerFxOptions = {
	Key: BannerKey,
	Card: Frame,
	Halo: Frame,
	PortraitHost: Frame,
	Plate: Frame,
	TitleLabel: TextLabel,
	TagLabel: TextLabel,
	PityFill: Frame,
	Button10X: GuiButton,
	AccentColor: Color3,
	KeyArtId: string?,
	IsVisible: () -> boolean,
}

export type BannerFxHandle = {
	SetActive: (self: BannerFxHandle, active: boolean) -> (),
	SetCharging: (self: BannerFxHandle, charging: boolean) -> (),
	SetPityRatio: (self: BannerFxHandle, ratio: number, guaranteed: boolean) -> (),
	PlayEntrance: (self: BannerFxHandle) -> (),
	PlayTriggerBurst: (self: BannerFxHandle, topRarity: number?) -> (),
	Destroy: (self: BannerFxHandle) -> (),
}

local HeroBannerFx = {}

local WHITE = Color3.new(1, 1, 1)
local CENTERED = Vector2.new(0.5, 0.5)
local PORTAL_POS = UDim2.new(1, -118, 0, 110)

local THEMES = {
	CALL_OF_THE_RIFT = {
		Primary = Color3.fromRGB(192, 132, 252), -- arcane violet
		Secondary = Color3.fromRGB(115, 130, 255), -- dimensional indigo
		Highlight = Color3.fromRGB(238, 224, 255),
		Rail = Color3.fromRGB(210, 155, 255),
		RailBase = Color3.fromRGB(240, 196, 110),
	},
	A_STARS_ARRIVAL = {
		Primary = Color3.fromRGB(255, 218, 102), -- starlight gold
		Secondary = Color3.fromRGB(216, 110, 245), -- celestial magenta-violet
		Highlight = Color3.fromRGB(255, 248, 220),
		Rail = Color3.fromRGB(255, 228, 128),
		RailBase = Color3.fromRGB(240, 196, 110),
	},
}

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

local function findRailStroke(container: Instance): UIStroke?
	local rail = container:FindFirstChild("GrimoireRail")
	if rail then
		local stroke = rail:FindFirstChildWhichIsA("UIStroke")
		if stroke then return stroke end
	end
	return nil
end

local function makeOrbGlow(parent: Instance, name: string, pos: UDim2, size: number, color: Color3, z: number, transparency: number): Frame
	local f = new("Frame", {
		Name = name,
		AnchorPoint = CENTERED,
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = z,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	new("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.55, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, f)
	return f
end

local function makeStarCross(parent: Instance, pos: UDim2, size: number, color: Color3, z: number): Frame
	local holder = new("Frame", {
		Name = "StarCross",
		AnchorPoint = CENTERED,
		Position = pos,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = z,
	}, parent)
	local barH = new("Frame", {
		Name = "H",
		AnchorPoint = CENTERED,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, math.max(1, math.round(size * 0.16))),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = z,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, barH)
	local barV = new("Frame", {
		Name = "V",
		AnchorPoint = CENTERED,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, math.max(1, math.round(size * 0.16)), 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = z,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, barV)
	return holder
end

local function makeRing(parent: Instance, name: string, size: number, color: Color3, thickness: number, transparency: number, z: number): (Frame, UIStroke)
	local f = new("Frame", {
		Name = name,
		AnchorPoint = CENTERED,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = z,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	local st = new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, f)
	return f, st
end

local function makeShockwave(parent: Instance, at: UDim2, color: Color3, z: number, fromSize: number, toSize: number, duration: number)
	if UIFeel.ReducedMotion() then return end
	local ring = new("Frame", {
		Name = "BannerShockwave",
		AnchorPoint = CENTERED,
		Position = at,
		Size = UDim2.fromOffset(fromSize, fromSize),
		BackgroundTransparency = 1,
		Active = false,
		ZIndex = z,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
	local st = new("UIStroke", {
		Color = color:Lerp(WHITE, 0.35),
		Thickness = 5,
		Transparency = 0.05,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, ring)
	UIFeel.Tween(ring, duration, { Size = UDim2.fromOffset(toSize, toSize) }, Enum.EasingStyle.Quart)
	UIFeel.Tween(st, duration, { Transparency = 1, Thickness = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(duration + 0.05, function()
		if ring.Parent then ring:Destroy() end
	end)
end

-- Diagonal light sweep managed per-banner so it stops cleanly when the banner is hidden.
local function createShimmerRunner(host: GuiObject, z: number, cornerRadius: number, period: number, gentle: boolean)
	local clip = new("Frame", {
		Name = "ShimmerClip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Active = false,
		ZIndex = z,
	}, host)
	new("UICorner", { CornerRadius = UDim.new(0, cornerRadius) }, clip)

	local band = new("Frame", {
		Name = "ShimmerBand",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = z,
		Visible = false,
	}, clip)
	new("UICorner", { CornerRadius = UDim.new(0, cornerRadius) }, band)
	local grad = new("UIGradient", {
		Rotation = 24,
		Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.41, 1),
			NumberSequenceKeypoint.new(0.5, 0.62),
			NumberSequenceKeypoint.new(0.59, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, band)

	local running = false
	local token = 0
	local activeTween: Tween? = nil

	local function sweepOnce()
		if not band.Parent then return end
		if not gentle and UIFeel.ReducedMotion() then return end
		if activeTween then activeTween:Cancel() end
		band.Visible = true
		grad.Offset = Vector2.new(-1, 0)
		local tw = TweenService:Create(grad, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Offset = Vector2.new(1, 0),
		})
		activeTween = tw
		tw:Play()
		tw.Completed:Once(function()
			if activeTween == tw then
				activeTween = nil
				band.Visible = false
			end
		end)
	end

	local function setRunning(on: boolean)
		if running == on then return end
		running = on
		token += 1
		local myToken = token
		if not on then
			if activeTween then activeTween:Cancel(); activeTween = nil end
			band.Visible = false
			return
		end
		task.spawn(function()
			task.wait(0.35)
			while running and token == myToken and band.Parent do
				sweepOnce()
				task.wait(period)
			end
		end)
	end

	return {
		SweepOnce = sweepOnce,
		SetRunning = setRunning,
		Destroy = function()
			running = false
			token += 1
			if activeTween then activeTween:Cancel() end
			clip:Destroy()
		end,
	}
end

function HeroBannerFx.Attach(opts: BannerFxOptions): BannerFxHandle
	local key = opts.Key
	local theme = THEMES[key]
	local card = opts.Card
	local baseZ = card.ZIndex

	-- Optional uploaded key art layer (kept calm on the left so banner typography stays readable).
	if type(opts.KeyArtId) == "string" and opts.KeyArtId ~= "" then
		local art = new("ImageLabel", {
			Name = "BannerKeyArt",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = opts.KeyArtId,
			ImageTransparency = 0.28,
			ScaleType = Enum.ScaleType.Crop,
			Active = false,
			ZIndex = baseZ,
		}, card)
		new("UICorner", { CornerRadius = UDim.new(0, GildedGrimoire.Radius.Card) }, art)
		new("UIGradient", {
			Rotation = 0,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.7),
				NumberSequenceKeypoint.new(0.45, 0.25),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}, art)
	end

	-- Root container for all backdrop FX behind the hero portrait & text.
	local fxLayer = new("Frame", {
		Name = "BannerFxLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Active = false,
		ZIndex = baseZ + 1,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, GildedGrimoire.Radius.Card) }, fxLayer)

	local flash = new("Frame", {
		Name = "BannerFlash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = baseZ + 7,
	}, card)
	new("UICorner", { CornerRadius = UDim.new(0, GildedGrimoire.Radius.Card) }, flash)

	-- Center the FeaturedPortrait on the portal anchor so UIScale and bobbing stay symmetrical.
	local portraitHost = opts.PortraitHost
	portraitHost.AnchorPoint = CENTERED
	local portraitBasePos = UDim2.new(1, -118, 0, 108)
	portraitHost.Position = portraitBasePos
	local portraitScale = new("UIScale", { Name = "BannerBreathScale", Scale = 1 }, portraitHost)
	local haloScale = new("UIScale", { Name = "HaloPulseScale", Scale = 1 }, opts.Halo)

	local cardRail = findRailStroke(card)
	local plateStroke = opts.Plate:FindFirstChildWhichIsA("UIStroke")
	local cardShimmer = createShimmerRunner(card, baseZ + 6, GildedGrimoire.Radius.Card, 3.6, true)
	local plateShimmer = createShimmerRunner(opts.Plate, opts.Plate.ZIndex + 2, 16, 4.2, true)
	local btn10Shimmer = createShimmerRunner(opts.Button10X, opts.Button10X.ZIndex + 1, GildedGrimoire.Radius.Button, 2.8, true)

	-- Shared animation state
	local active = false
	local charging = false
	local spinMult = 1
	local pityGlow = false
	local burstToken = 0
	local elapsed = 0

	-- Per-banner ambient elements
	local nebulaA: Frame
	local nebulaB: Frame
	local motes: { { Frame: Frame, X: number, Y0: number, Phase: number, Speed: number, Sway: number, Spin: number, BaseAlpha: number } } = {}

	-- Rift-specific references
	local riftSlit: Frame? = nil
	local riftOuter: Frame? = nil
	local riftMid: Frame? = nil
	local riftInner: Frame? = nil

	-- Starfall-specific references
	local starRays: Frame? = nil
	local starOrbit: Frame? = nil
	local starDiamond: Frame? = nil
	local twinkles: { { Obj: Frame, Scale: UIScale, Phase: number, Speed: number, BaseAlpha: number } } = {}
	local meteors: { { Root: Frame, Head: Frame, Progress: number, Duration: number, Wait: number, StartX: number, StartY: number, EndX: number, EndY: number } } = {}

	local function buildMotes(count: number, palette: { Color3 })
		for i = 1, count do
			local size = math.random(4, 9)
			local c = palette[(i % #palette) + 1]
			local m = new("Frame", {
				Name = "FxMote",
				AnchorPoint = CENTERED,
				Size = UDim2.fromOffset(size, size),
				Rotation = 45,
				BackgroundColor3 = c:Lerp(WHITE, math.random() * 0.35),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Active = false,
				ZIndex = baseZ + 1,
			}, fxLayer)
			table.insert(motes, {
				Frame = m,
				X = 0.06 + math.random() * 0.90,
				Y0 = math.random(),
				Phase = math.random() * math.pi * 2,
				Speed = 0.06 + math.random() * 0.07,
				Sway = 0.012 + math.random() * 0.022,
				Spin = (math.random() - 0.5) * 140,
				BaseAlpha = 0.25 + math.random() * 0.45,
			})
		end
	end

	if key == "CALL_OF_THE_RIFT" then
		nebulaA = makeOrbGlow(fxLayer, "RiftNebulaLeft", UDim2.fromScale(0.24, 0.55), 320, theme.Secondary, baseZ + 1, 0.82)
		nebulaB = makeOrbGlow(fxLayer, "RiftNebulaPortal", PORTAL_POS, 300, theme.Primary, baseZ + 1, 0.70)

		-- Luminous dimensional rift seam behind the featured hero.
		local slit = new("Frame", {
			Name = "RiftSlit",
			AnchorPoint = CENTERED,
			Position = PORTAL_POS,
			Size = UDim2.fromOffset(34, 210),
			Rotation = 12,
			BackgroundColor3 = theme.Highlight,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			Active = false,
			ZIndex = baseZ + 1,
		}, fxLayer)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, slit)
		new("UIGradient", {
			Rotation = 0,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, theme.Primary),
				ColorSequenceKeypoint.new(0.5, WHITE),
				ColorSequenceKeypoint.new(1, theme.Primary),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, slit)
		riftSlit = slit

		-- Counter-rotating summoning vortex behind FeaturedPortrait.
		local vortex = new("Frame", {
			Name = "RiftVortex",
			AnchorPoint = CENTERED,
			Position = PORTAL_POS,
			Size = UDim2.fromOffset(230, 230),
			BackgroundTransparency = 1,
			Active = false,
			ZIndex = baseZ + 1,
		}, fxLayer)

		local outer = makeRing(vortex, "Outer", 224, theme.Primary, 1.8, 0.35, baseZ + 1)
		for i = 0, 15 do
			local a = (i / 16) * math.pi * 2
			new("Frame", {
				AnchorPoint = CENTERED,
				Position = UDim2.fromScale(0.5 + math.cos(a) * 0.46, 0.5 + math.sin(a) * 0.46),
				Size = UDim2.fromOffset(2, if i % 4 == 0 then 12 else 6),
				Rotation = math.deg(a) + 90,
				BackgroundColor3 = theme.Highlight,
				BackgroundTransparency = 0.25,
				BorderSizePixel = 0,
				Active = false,
				ZIndex = baseZ + 1,
			}, outer)
		end
		riftOuter = outer

		local mid = makeRing(vortex, "Mid", 174, theme.Secondary, 1.4, 0.4, baseZ + 1)
		for i = 0, 7 do
			local a = (i / 8) * math.pi * 2
			new("Frame", {
				AnchorPoint = CENTERED,
				Position = UDim2.fromScale(0.5 + math.cos(a) * 0.5, 0.5 + math.sin(a) * 0.5),
				Size = UDim2.fromOffset(8, 8),
				Rotation = math.deg(a) + 45,
				BackgroundColor3 = if i % 2 == 0 then theme.Highlight else opts.AccentColor,
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				Active = false,
				ZIndex = baseZ + 1,
			}, mid)
		end
		riftMid = mid

		local inner = new("Frame", {
			Name = "InnerOctagram",
			AnchorPoint = CENTERED,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(124, 124),
			BackgroundTransparency = 1,
			Active = false,
			ZIndex = baseZ + 1,
		}, vortex)
		for i = 0, 1 do
			local sq = new("Frame", {
				AnchorPoint = CENTERED,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.707, 0.707),
				Rotation = i * 45,
				BackgroundTransparency = 1,
				Active = false,
				ZIndex = baseZ + 1,
			}, inner)
			new("UIStroke", {
				Color = theme.Primary,
				Thickness = 1.4,
				Transparency = 0.45,
				LineJoinMode = Enum.LineJoinMode.Miter,
			}, sq)
		end
		riftInner = inner

		buildMotes(18, { theme.Primary, theme.Secondary, opts.AccentColor, theme.Highlight })
	else
		-- A_STARS_ARRIVAL: Celestial Starfall & Astrolabe
		nebulaA = makeOrbGlow(fxLayer, "StarNebulaSky", UDim2.fromScale(0.32, 0.35), 340, theme.Secondary, baseZ + 1, 0.80)
		nebulaB = makeOrbGlow(fxLayer, "StarNebulaPortal", PORTAL_POS, 310, theme.Primary, baseZ + 1, 0.68)

		-- Twinkling starfield across the sky (avoiding over-cluttering the text area by keeping stars soft).
		for i = 1, 20 do
			local isCross = (i % 3 == 0)
			local sx = 0.04 + ((i * 0.173) % 0.92)
			local sy = 0.08 + ((i * 0.291) % 0.84)
			local starSize = if isCross then math.random(9, 15) else math.random(4, 7)
			local starColor = if i % 4 == 0 then theme.Highlight elseif i % 2 == 0 then theme.Primary else Color3.fromRGB(224, 242, 254)
			local star: Frame
			if isCross then
				star = makeStarCross(fxLayer, UDim2.fromScale(sx, sy), starSize, starColor, baseZ + 1)
			else
				star = new("Frame", {
					Name = "TwinkleDot",
					AnchorPoint = CENTERED,
					Position = UDim2.fromScale(sx, sy),
					Size = UDim2.fromOffset(starSize, starSize),
					Rotation = 45,
					BackgroundColor3 = starColor,
					BorderSizePixel = 0,
					Active = false,
					ZIndex = baseZ + 1,
				}, fxLayer)
			end
			local sc = new("UIScale", { Scale = 1 }, star)
			table.insert(twinkles, {
				Obj = star,
				Scale = sc,
				Phase = math.random() * math.pi * 2,
				Speed = 1.6 + math.random() * 2.2,
				BaseAlpha = if sx < 0.55 then 0.35 else 0.15,
			})
		end

		-- Pool of 3 diagonal shooting-star meteors.
		for i = 1, 3 do
			local meteor = new("Frame", {
				Name = "Meteor" .. i,
				AnchorPoint = CENTERED,
				Position = UDim2.fromScale(1.1, -0.1),
				Size = UDim2.fromOffset(115, 3),
				Rotation = -26,
				BackgroundColor3 = WHITE,
				BackgroundTransparency = 0.1,
				BorderSizePixel = 0,
				Active = false,
				Visible = false,
				ZIndex = baseZ + 1,
			}, fxLayer)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, meteor)
			new("UIGradient", {
				Rotation = 0,
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, WHITE),
					ColorSequenceKeypoint.new(0.35, theme.Primary),
					ColorSequenceKeypoint.new(1, theme.Secondary),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(0.45, 0.35),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}, meteor)
			local head = makeStarCross(meteor, UDim2.fromScale(0.02, 0.5), 14, theme.Highlight, baseZ + 2)
			table.insert(meteors, {
				Root = meteor,
				Head = head,
				Progress = 0,
				Duration = 0.65 + math.random() * 0.3,
				Wait = 0.4 + (i - 1) * 0.9 + math.random() * 0.6,
				StartX = 0.65 + math.random() * 0.45,
				StartY = -0.05 + math.random() * 0.25,
				EndX = 0.05 + math.random() * 0.35,
				EndY = 0.75 + math.random() * 0.35,
			})
		end

		-- Celestial astrolabe & golden starburst rays behind Astrea.
		local astrolabe = new("Frame", {
			Name = "StarAstrolabe",
			AnchorPoint = CENTERED,
			Position = PORTAL_POS,
			Size = UDim2.fromOffset(260, 260),
			BackgroundTransparency = 1,
			Active = false,
			ZIndex = baseZ + 1,
		}, fxLayer)

		local rays = new("Frame", {
			Name = "StarRays",
			AnchorPoint = CENTERED,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(250, 250),
			BackgroundTransparency = 1,
			Active = false,
			ZIndex = baseZ + 1,
		}, astrolabe)
		for i = 0, 9 do
			local ray = new("Frame", {
				AnchorPoint = CENTERED,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(10, 240),
				Rotation = i * 18,
				BackgroundColor3 = theme.Primary,
				BackgroundTransparency = 0.55,
				BorderSizePixel = 0,
				Active = false,
				ZIndex = baseZ + 1,
			}, rays)
			new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.38, 0.45),
					NumberSequenceKeypoint.new(0.5, 0.2),
					NumberSequenceKeypoint.new(0.62, 0.45),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}, ray)
		end
		starRays = rays

		local orbit = makeRing(astrolabe, "CelestialOrbit", 210, theme.Primary, 1.6, 0.35, baseZ + 1)
		for i = 0, 5 do
			local a = (i / 6) * math.pi * 2
			local gem = makeStarCross(orbit, UDim2.fromScale(0.5 + math.cos(a) * 0.5, 0.5 + math.sin(a) * 0.5), if i % 2 == 0 then 14 else 10, theme.Highlight, baseZ + 1)
			gem.Rotation = math.deg(a)
		end
		starOrbit = orbit

		local diamond = new("Frame", {
			Name = "InnerDiamond",
			AnchorPoint = CENTERED,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(146, 146),
			Rotation = 45,
			BackgroundTransparency = 1,
			Active = false,
			ZIndex = baseZ + 1,
		}, astrolabe)
		new("UIStroke", {
			Color = theme.Highlight,
			Thickness = 1.4,
			Transparency = 0.45,
			LineJoinMode = Enum.LineJoinMode.Miter,
		}, diamond)
		starDiamond = diamond

		buildMotes(18, { theme.Primary, theme.Highlight, theme.Secondary, opts.AccentColor })
	end

	-- Periodic sparkle burst loop (active only while visible).
	local function startBurstLoop()
		burstToken += 1
		local myToken = burstToken
		task.spawn(function()
			task.wait(0.45)
			while active and burstToken == myToken and fxLayer.Parent do
				if opts.IsVisible() and not UIFeel.ReducedMotion() then
					local ox = math.random(-70, 70)
					local oy = math.random(-65, 65)
					local burstColor = if key == "A_STARS_ARRIVAL" then theme.Primary else theme.Primary:Lerp(opts.AccentColor, 0.25)
					UIFeel.Burst(fxLayer, PORTAL_POS + UDim2.fromOffset(ox, oy), burstColor, 8, baseZ + 2, 75)
				end
				task.wait(2.1 + math.random() * 1.4)
			end
		end)
	end

	local function setObjectAlpha(obj: GuiObject, alpha: number)
		if obj.BackgroundTransparency < 1 then
			obj.BackgroundTransparency = alpha
		end
		for _, child in obj:GetChildren() do
			if child:IsA("Frame") then
				child.BackgroundTransparency = alpha
			end
		end
	end

	local renderConn = RunService.RenderStepped:Connect(function(dt: number)
		if not active or not fxLayer.Parent or not opts.IsVisible() then
			return
		end
		elapsed += dt
		local reduced = UIFeel.ReducedMotion()
		local targetMult = if charging then 4.5 else 1
		spinMult += (targetMult - spinMult) * math.min(1, dt * 6)

		-- Rail glow breathing (gentle light cue kept even under Reduce Motion).
		if cardRail then
			local wave = 0.5 + 0.5 * math.sin(elapsed * 2.2)
			cardRail.Color = theme.RailBase:Lerp(theme.Rail, wave)
			cardRail.Transparency = 0.1 + 0.35 * (1 - wave)
		end
		if plateStroke then
			local wave = 0.5 + 0.5 * math.sin(elapsed * 2.8)
			plateStroke.Color = opts.AccentColor:Lerp(theme.Highlight, wave * 0.45)
		end
		if pityGlow and opts.PityFill.Parent then
			local wave = 0.5 + 0.5 * math.sin(elapsed * 4.0)
			opts.PityFill.BackgroundColor3 = opts.AccentColor:Lerp(WHITE, wave * 0.35)
		end

		if reduced then
			portraitHost.Position = portraitBasePos
			portraitScale.Scale = 1
			haloScale.Scale = 1
			return
		end

		-- Featured hero gentle float & breathing scale.
		local floatY = math.sin(elapsed * 2.0) * 4
		local breath = 1 + 0.024 * (0.5 + 0.5 * math.sin(elapsed * 2.0 - 0.5))
		portraitHost.Position = portraitBasePos + UDim2.fromOffset(0, math.round(floatY))
		portraitScale.Scale = if charging then breath * 1.04 else breath

		-- Halo & nebula breathing.
		local haloWave = 0.5 + 0.5 * math.sin(elapsed * 2.5)
		haloScale.Scale = (if charging then 1.12 else 1) + 0.06 * haloWave
		opts.Halo.BackgroundTransparency = (if charging then 0.62 else 0.76) + 0.1 * (1 - haloWave)
		nebulaA.BackgroundTransparency = 0.78 + 0.08 * math.sin(elapsed * 1.3)
		nebulaB.BackgroundTransparency = (if charging then 0.52 else 0.66) + 0.09 * math.cos(elapsed * 1.9)

		-- Drifting motes.
		for _, mote in motes do
			local prog = ((mote.Y0 + elapsed * mote.Speed * (if charging then 2.2 else 1)) % 1)
			local x = mote.X + math.sin(elapsed * 1.4 + mote.Phase) * mote.Sway
			local y = 1.04 - prog * 1.08
			mote.Frame.Position = UDim2.fromScale(x, y)
			mote.Frame.Rotation = 45 + elapsed * mote.Spin
			mote.Frame.BackgroundTransparency = 1 - math.sin(prog * math.pi) * (1 - mote.BaseAlpha)
		end

		if key == "CALL_OF_THE_RIFT" then
			if riftOuter then riftOuter.Rotation = (riftOuter.Rotation + 26 * spinMult * dt) % 360 end
			if riftMid then riftMid.Rotation = (riftMid.Rotation - 36 * spinMult * dt) % 360 end
			if riftInner then riftInner.Rotation = (riftInner.Rotation + 48 * spinMult * dt) % 360 end
			if riftSlit then
				local pulse = 0.5 + 0.5 * math.sin(elapsed * 3.4)
				local w = (if charging then 46 else 30) + 12 * pulse
				riftSlit.Size = UDim2.fromOffset(w, 210)
				riftSlit.BackgroundTransparency = (if charging then 0.25 else 0.48) + 0.16 * (1 - pulse)
			end
		else
			if starRays then starRays.Rotation = (starRays.Rotation + 14 * spinMult * dt) % 360 end
			if starOrbit then starOrbit.Rotation = (starOrbit.Rotation - 28 * spinMult * dt) % 360 end
			if starDiamond then starDiamond.Rotation = (starDiamond.Rotation + 32 * spinMult * dt) % 360 end

			-- Twinkling stars.
			for _, tw in twinkles do
				local wave = 0.5 + 0.5 * math.sin(elapsed * tw.Speed + tw.Phase)
				tw.Scale.Scale = 0.65 + 0.55 * wave
				setObjectAlpha(tw.Obj, tw.BaseAlpha + 0.65 * (1 - wave))
			end

			-- Shooting-star meteors.
			for _, m in meteors do
				if m.Wait > 0 then
					m.Wait -= dt
					if m.Wait <= 0 then
						m.Progress = 0
						m.Root.Visible = true
						m.StartX = 0.65 + math.random() * 0.45
						m.StartY = -0.06 + math.random() * 0.26
						m.EndX = m.StartX - (0.45 + math.random() * 0.3)
						m.EndY = m.StartY + (0.65 + math.random() * 0.35)
					end
				else
					m.Progress += dt / m.Duration
					if m.Progress >= 1 then
						m.Root.Visible = false
						m.Wait = 1.0 + math.random() * 1.4
					else
						local t = m.Progress
						local eased = 1 - (1 - t) ^ 2
						local x = m.StartX + (m.EndX - m.StartX) * eased
						local y = m.StartY + (m.EndY - m.StartY) * eased
						m.Root.Position = UDim2.fromScale(x, y)
						local fade = math.sin(t * math.pi)
						local alpha = 1 - fade * 0.9
						m.Root.BackgroundTransparency = alpha
						setObjectAlpha(m.Head, alpha)
					end
				end
			end
		end
	end)

	local handle: BannerFxHandle = {} :: any

	function handle:SetActive(on: boolean)
		if active == on then return end
		active = on
		cardShimmer.SetRunning(on)
		plateShimmer.SetRunning(on)
		btn10Shimmer.SetRunning(on)
		if on then
			startBurstLoop()
		else
			burstToken += 1
			charging = false
			spinMult = 1
		end
	end

	function handle:SetCharging(on: boolean)
		charging = on
		if on and active and not UIFeel.ReducedMotion() then
			cardShimmer.SweepOnce()
			makeShockwave(fxLayer, PORTAL_POS, theme.Primary, baseZ + 2, 70, 260, 0.45)
			UIFeel.Burst(fxLayer, PORTAL_POS, theme.Highlight, 12, baseZ + 2, 110)
		end
	end

	function handle:SetPityRatio(ratio: number, guaranteed: boolean)
		pityGlow = guaranteed or ratio >= 0.8
		if not pityGlow then
			opts.PityFill.BackgroundColor3 = opts.AccentColor
		end
	end

	function handle:PlayEntrance()
		if UIFeel.ReducedMotion() then return end
		portraitScale.Scale = 0.88
		UIFeel.Tween(portraitScale, 0.34, { Scale = 1 }, Enum.EasingStyle.Back)
		haloScale.Scale = 0.72
		UIFeel.Tween(haloScale, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
		cardShimmer.SweepOnce()
		UIFeel.Burst(fxLayer, PORTAL_POS, theme.Primary, 10, baseZ + 2, 95)
	end

	function handle:PlayTriggerBurst(topRarity: number?)
		charging = false
		if UIFeel.ReducedMotion() then return end
		local burstColor = if topRarity then Theme.RarityColor(topRarity) else theme.Primary
		flash.BackgroundColor3 = burstColor:Lerp(WHITE, 0.4)
		flash.BackgroundTransparency = 0.45
		UIFeel.Tween(flash, 0.32, { BackgroundTransparency = 1 })
		makeShockwave(fxLayer, PORTAL_POS, burstColor, baseZ + 2, 80, 380, 0.4)
		UIFeel.Burst(fxLayer, PORTAL_POS, burstColor, 18, baseZ + 2, 160)
	end

	function handle:Destroy()
		handle:SetActive(false)
		renderConn:Disconnect()
		cardShimmer.Destroy()
		plateShimmer.Destroy()
		btn10Shimmer.Destroy()
		fxLayer:Destroy()
		flash:Destroy()
	end

	return handle
end

return HeroBannerFx
