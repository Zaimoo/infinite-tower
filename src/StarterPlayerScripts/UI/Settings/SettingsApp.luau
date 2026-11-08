--!strict
-- StarterPlayerScripts/UI/Settings/SettingsApp.luau
-- Clear Glass Declarative React Luau Settings Application for Infinite Towers.
-- Renders translucent frosted dark crystal panels, diagonal specular glass sheens,
-- and connects all Audio, Graphics, and Preset controls directly to the live game engine.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local ModalFit = require(script.Parent.Parent:WaitForChild("ModalFit"))
local GuiService = game:GetService("GuiService")

local SettingsConfig = require(script.Parent:WaitForChild("SettingsConfig"))
local SettingsComponents = require(script.Parent:WaitForChild("SettingsComponents"))
local SettingsAudioEngine = require(script.Parent:WaitForChild("SettingsAudioEngine"))
local SettingsGraphicsEngine = require(script.Parent:WaitForChild("SettingsGraphicsEngine"))

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useCallback = React.useCallback

local Section = SettingsComponents.Section
local Slider = SettingsComponents.Slider
local Toggle = SettingsComponents.Toggle
local TabButton = SettingsComponents.TabButton
local StatCard = SettingsComponents.StatCard
local ActionButton = SettingsComponents.ActionButton
local HeavyLabel = SettingsComponents.HeavyLabel
local Body = SettingsComponents.Body

local Grimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Icons = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Icons"))

local LocalPlayer = Players.LocalPlayer

local setIsOpenGlobal: ((boolean) -> ())? = nil
local isCurrentlyOpen = false

-- True when two settings tables hold the same values (the draft against the applied settings).
local function sameSettings(a: { [string]: any }, b: { [string]: any }): boolean
	for k, v in a do
		if b[k] ~= v then return false end
	end
	for k, v in b do
		if a[k] ~= v then return false end
	end
	return true
end

_G.OpenSettings = function()
	if _G.OpenMasterModal then
		_G.OpenMasterModal("SETTINGS")
	elseif _G.CloseBackpack then
		_G.CloseBackpack()
	end
	if setIsOpenGlobal then setIsOpenGlobal(true) end
end
_G.CloseSettings = function()
	if setIsOpenGlobal then setIsOpenGlobal(false) end
end
_G.ToggleSettings = function()
	if isCurrentlyOpen then
		if setIsOpenGlobal then setIsOpenGlobal(false) end
	else
		if _G.OpenMasterModal then
			_G.OpenMasterModal("SETTINGS")
		elseif _G.CloseBackpack then
			_G.CloseBackpack()
		end
		if setIsOpenGlobal then setIsOpenGlobal(true) end
	end
end
_G.IsSettingsOpen = function()
	return isCurrentlyOpen
end

local function SettingsApp()
	local panelRef = React.useRef(nil)
	local scaleRef = React.useRef(nil)
	useEffect(function()
		local panel, scale = panelRef.current, scaleRef.current
		if not panel or not scale then return end
		local gui = panel:FindFirstAncestorOfClass("ScreenGui")
		if not gui then return end
		local function fit()
			local position, fitted, design = ModalFit.Calculate(gui.AbsoluteSize, GuiService:GetGuiInset().Y, 960, 620, { MaxScale = 1.2, FillWidth = true })
			panel.Position = position
			panel.Size = UDim2.fromOffset(design.X, design.Y)
			scale.Scale = fitted
		end
		fit()
		local connection = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		return function() connection:Disconnect() end
	end, {})
	local isOpen, setIsOpen = useState(false)
	isCurrentlyOpen = isOpen
	setIsOpenGlobal = setIsOpen
	local activeTab, setActiveTab = useState("Overview" :: SettingsConfig.TabName)
	local statusMsg, setStatusMsg = useState("Ready.")
	-- `settings` is the draft: it previews live while the window is open. `applied` is what the
	-- player kept with Apply. Closing with a different draft asks before throwing it away.
	local settings, setSettings = useState(table.clone(SettingsConfig.DEFAULTS))
	local applied, setApplied = useState(table.clone(SettingsConfig.DEFAULTS))
	local confirmDiscard, setConfirmDiscard = useState(false)
	local dirty = not sameSettings(settings, applied)
	local dirtyRef = React.useRef(false)
	dirtyRef.current = dirty
	local appliedRef = React.useRef(applied)
	appliedRef.current = applied
	local confirmRef = React.useRef(false)
	confirmRef.current = confirmDiscard

	-- Close if nothing is unapplied; otherwise ask first.
	local function requestClose()
		if dirtyRef.current then
			setConfirmDiscard(true)
		else
			setIsOpen(false)
		end
	end
	-- Throw the draft away and close (the Discard button, or another window taking over).
	local function discardAndClose()
		setSettings(table.clone(appliedRef.current))
		setConfirmDiscard(false)
		setIsOpen(false)
	end

	local theme = SettingsConfig.THEMES[settings.Theme] or SettingsConfig.THEMES.Gold
	local accent = theme.Accent

	----------------------------------------------------------------------------
	-- 1. Initialize Engines & Live Sync
	----------------------------------------------------------------------------
	useEffect(function()
		SettingsAudioEngine.init()
		SettingsGraphicsEngine.init()
	end, {})

	useEffect(function()
		SettingsAudioEngine.updateVolumes(
			settings.Sound,
			settings.Music,
			settings.Ambience,
			settings.MuteSFX,
			settings.MuteMusic,
			settings.MuteAmbience
		)

		SettingsGraphicsEngine.updateFOV(settings.FOV)
		SettingsGraphicsEngine.updateBrightness(settings.Brightness)
		SettingsGraphicsEngine.updateDynamicShadows(settings.GlobalShadows)
		SettingsGraphicsEngine.updateBloom(settings.Bloom)
		SettingsGraphicsEngine.updateColorCorrection(settings.ColorFX)
		SettingsGraphicsEngine.setGlassBlur(isOpen)

		-- Sync attributes to LocalPlayer
		LocalPlayer:SetAttribute("Settings_MasterVolume", settings.Sound)
		LocalPlayer:SetAttribute("Settings_MusicVolume", settings.Music)
		LocalPlayer:SetAttribute("Settings_AmbienceVolume", settings.Ambience)
		LocalPlayer:SetAttribute("Settings_MuteSFX", settings.MuteSFX)
		LocalPlayer:SetAttribute("Settings_MuteMusic", settings.MuteMusic)
		LocalPlayer:SetAttribute("Settings_MuteAmbience", settings.MuteAmbience)
		LocalPlayer:SetAttribute("Settings_FOV", settings.FOV)
		LocalPlayer:SetAttribute("Settings_Brightness", settings.Brightness)
		LocalPlayer:SetAttribute("Settings_GlobalShadows", settings.GlobalShadows)
		LocalPlayer:SetAttribute("Settings_Bloom", settings.Bloom)
		LocalPlayer:SetAttribute("Settings_ColorFX", settings.ColorFX)
		LocalPlayer:SetAttribute("Settings_ShowNotifications", settings.ShowNotifications)
		LocalPlayer:SetAttribute("Settings_DamageNumbers", settings.DamageNumbers)
		LocalPlayer:SetAttribute("Settings_CompactMode", settings.CompactMode)
		LocalPlayer:SetAttribute("Settings_ReduceMotion", settings.ReduceMotion)
		LocalPlayer:SetAttribute("Settings_Theme", settings.Theme)
		LocalPlayer:SetAttribute("Settings_Font", settings.Font)

		return function()
			if not isOpen then
				SettingsGraphicsEngine.setGlassBlur(false)
			end
		end
	end, {
		isOpen :: any,
		settings.Sound,
		settings.Music,
		settings.Ambience,
		settings.MuteSFX,
		settings.MuteMusic,
		settings.MuteAmbience,
		settings.FOV,
		settings.Brightness,
		settings.GlobalShadows,
		settings.Bloom,
		settings.ColorFX,
		settings.ShowNotifications,
		settings.DamageNumbers,
		settings.CompactMode,
		settings.ReduceMotion,
		settings.Theme,
		settings.Font,
	})

	----------------------------------------------------------------------------
	-- 2. Modal Focus Dimmer & Surrounding HUD Icons Suppression
	----------------------------------------------------------------------------
	useEffect(function()
		if isOpen then
			if _G.OpenMasterModal then
				_G.OpenMasterModal("SETTINGS")
			end
			if _G.SetModalFocusMode then
				_G.SetModalFocusMode(true)
			end
		else
			if _G.SetModalFocusMode then
				_G.SetModalFocusMode(false)
			end
		end

		return function()
			if isOpen and _G.SetModalFocusMode then
				_G.SetModalFocusMode(false)
			end
		end
	end, { isOpen })

	----------------------------------------------------------------------------
	-- 3. Global Open / Close / Toggle APIS & Keybinds
	----------------------------------------------------------------------------
	useEffect(function()
		local function openSettings()
			if _G.OpenMasterModal then
				_G.OpenMasterModal("SETTINGS")
			elseif _G.CloseBackpack then
				_G.CloseBackpack()
			end
			setIsOpen(true)
		end
		local function toggleSettings()
			if isOpen then requestClose() else openSettings() end
		end

		_G.OpenSettings = openSettings
		-- Another window is taking over: unapplied changes can't be kept, so they are discarded.
		_G.CloseSettings = function()
			if isOpen then discardAndClose() end
		end
		_G.ToggleSettings = toggleSettings
		_G.IsSettingsOpen = function() return isOpen end

		-- Escape (or gamepad B) closes the discard prompt first, then the window.
		local conn = UserInputService.InputBegan:Connect(function(input)
			if (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) and isOpen then
				if confirmRef.current then
					setConfirmDiscard(false)
				else
					requestClose()
				end
			end
		end)

		-- Bind SettingsButton in PlayerGui
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local boundButtons: { [Instance]: boolean } = {}
		local function bind(btn: Instance)
			if btn.Name == "SettingsButton" and btn:IsA("GuiButton") and not boundButtons[btn] then
				boundButtons[btn] = true
				btn.Activated:Connect(function()
					if _G.ToggleSettings then _G.ToggleSettings() end
				end)
			end
		end

		local addConn: RBXScriptConnection? = nil
		if playerGui then
			for _, d in ipairs(playerGui:GetDescendants()) do
				bind(d)
			end
			addConn = playerGui.DescendantAdded:Connect(bind)
		end

		return function()
			conn:Disconnect()
			if addConn then addConn:Disconnect() end
		end
	end, { isOpen })

	----------------------------------------------------------------------------
	-- 3. State Update Handlers
	----------------------------------------------------------------------------
	local updateSetting = useCallback(function(key: string, val: any)
		setSettings(function(prev)
			local nextCopy: any = table.clone(prev)
			nextCopy[key] = val
			return nextCopy
		end)
	end, {})

	local resetDefaults = useCallback(function()
		setSettings(table.clone(SettingsConfig.DEFAULTS))
		setStatusMsg("Defaults loaded. Press Apply to keep them.")
	end, {})

	local applySettings = useCallback(function()
		setApplied(table.clone(settings))
		setStatusMsg("Settings applied.")
	end, { settings })

	local applyPreset = useCallback(function(name: string)
		if name == "Quiet" then
			setSettings(function(prev)
				local c = table.clone(prev)
				c.Sound = 0.0
				c.Music = 0.0
				c.Ambience = 0.0
				c.MuteSFX = true
				c.MuteMusic = true
				c.MuteAmbience = true
				return c
			end)
			setStatusMsg("Quiet Mode loaded (all audio silenced). Press Apply to keep it.")
		elseif name == "Performance" then
			setSettings(function(prev)
				local c = table.clone(prev)
				c.Quality = "Low"
				c.GlobalShadows = false
				c.Bloom = false
				c.ColorFX = false
				c.ReduceMotion = true
				return c
			end)
			setStatusMsg("Max Performance loaded (effects trimmed). Press Apply to keep it.")
		elseif name == "Cinematic" then
			setSettings(function(prev)
				local c = table.clone(prev)
				c.Quality = "High"
				c.GlobalShadows = true
				c.Bloom = true
				c.ColorFX = true
				c.FOV = 75
				c.Brightness = 0.25
				return c
			end)
			setStatusMsg("Cinematic loaded (shadows, bloom and color FX). Press Apply to keep it.")
		end
	end, {})

	----------------------------------------------------------------------------
	-- 4. Tab Content Pages
	----------------------------------------------------------------------------
	local pageContent: any = nil

	if activeTab == "Overview" then
		-- Dynamic Overview stats calculations
		local audioMixPct = if (settings.MuteSFX and settings.MuteMusic and settings.MuteAmbience)
			or (settings.Sound == 0 and settings.Music == 0 and settings.Ambience == 0)
			then 0
			else math.round((((if settings.MuteSFX then 0 else settings.Sound)
				+ (if settings.MuteMusic then 0 else settings.Music)
				+ (if settings.MuteAmbience then 0 else settings.Ambience)) / 3) * 100)

		local dynamicQuality = if settings.GlobalShadows and settings.Bloom and settings.ColorFX
			then "HIGH"
			elseif settings.GlobalShadows or settings.Bloom or settings.ColorFX
			then "MEDIUM"
			else "LOW"

		pageContent = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			StatsRow = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 84),
				LayoutOrder = 1,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 12),
				}),
				AudioStat = e(StatCard, {
					Title = "AUDIO MIX",
					Value = string.format("%d%%", audioMixPct),
					Subtext = string.format(
						"Music %d%% • Amb %d%%",
						if settings.MuteMusic then 0 else math.round(settings.Music * 100),
						if settings.MuteAmbience then 0 else math.round(settings.Ambience * 100)
					),
					AccentColor = accent,
					LayoutOrder = 1,
				}),
				EffectsStat = e(StatCard, {
					Title = "DYNAMIC SHADOWS",
					Value = if settings.GlobalShadows then "ENABLED" else "DISABLED",
					Subtext = if settings.Bloom then "Bloom & Shaders On" else "Fast Lighting",
					AccentColor = accent,
					LayoutOrder = 2,
				}),
				VisualStat = e(StatCard, {
					Title = "VISUAL QUALITY",
					Value = dynamicQuality,
					Subtext = string.format("FOV %d° • Brightness %d%%", math.round(settings.FOV), math.round(settings.Brightness * 100)),
					AccentColor = accent,
					LayoutOrder = 3,
				}),
			}),
			Presets = e(Section, {
				Title = "Presets",
				Subtitle = "Choose a preset",
				LayoutOrder = 2,
				Children = {
					PresetButtons = e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.new(1, 0, 0, 42),
						LayoutOrder = 2,
					}, {
						Layout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 12),
						}),
						P1 = e(ActionButton, {
							Text = "Cinematic Visuals",
							AccentColor = accent,
							Size = UDim2.new(0.31, 0, 1, 0),
							LayoutOrder = 1,
							OnClick = function() applyPreset("Cinematic") end,
						}),
						P2 = e(ActionButton, {
							Text = "Max Performance",
							AccentColor = accent,
							Size = UDim2.new(0.31, 0, 1, 0),
							LayoutOrder = 2,
							OnClick = function() applyPreset("Performance") end,
						}),
						P3 = e(ActionButton, {
							Text = "Quiet Mode",
							AccentColor = accent,
							Size = UDim2.new(0.31, 0, 1, 0),
							LayoutOrder = 3,
							OnClick = function() applyPreset("Quiet") end,
						}),
					}),
				},
			}),
		})
	elseif activeTab == "Audio" then
		pageContent = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Sliders = e(Section, {
				Title = "Volume Levels",
				Subtitle = "Adjust volume",
				LayoutOrder = 1,
				Children = {
					S1 = e(Slider, {
						Label = "Sound Effects (SFX)",
						Value = settings.Sound,
						AccentColor = accent,
						LayoutOrder = 1,
						OnChange = function(v) updateSetting("Sound", v) end,
					}),
					S2 = e(Slider, {
						Label = "Music Track",
						Value = settings.Music,
						AccentColor = accent,
						LayoutOrder = 2,
						OnChange = function(v) updateSetting("Music", v) end,
					}),
					S3 = e(Slider, {
						Label = "Atmosphere & Ambience",
						Value = settings.Ambience,
						AccentColor = accent,
						LayoutOrder = 3,
						OnChange = function(v) updateSetting("Ambience", v) end,
					}),
				},
			}),
			Mutes = e(Section, {
				Title = "Channel Mutes",
				Subtitle = "Mute sound groups",
				LayoutOrder = 2,
				Children = {
					T1 = e(Toggle, {
						Label = "Mute Sound Effects",
						Description = "Combat and UI sounds",
						Value = settings.MuteSFX,
						AccentColor = accent,
						LayoutOrder = 1,
						OnToggle = function() updateSetting("MuteSFX", not settings.MuteSFX) end,
					}),
					T2 = e(Toggle, {
						Label = "Mute Music",
						Description = "Background and boss music",
						Value = settings.MuteMusic,
						AccentColor = accent,
						LayoutOrder = 2,
						OnToggle = function() updateSetting("MuteMusic", not settings.MuteMusic) end,
					}),
					T3 = e(Toggle, {
						Label = "Mute Atmosphere & Ambience",
						Description = "Water, wind and ambience",
						Value = settings.MuteAmbience,
						AccentColor = accent,
						LayoutOrder = 3,
						OnToggle = function() updateSetting("MuteAmbience", not settings.MuteAmbience) end,
					}),
				},
			}),
		})
	elseif activeTab == "Graphics" then
		pageContent = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			QualitySection = e(Section, {
				Title = "Visual Tuning",
				Subtitle = "Camera and lighting",
				LayoutOrder = 1,
				Children = {
					FovSlider = e(Slider, {
						Label = "Field of View (Camera FOV)",
						Value = math.clamp((settings.FOV - 50) / 50, 0, 1),
						DisplayValue = string.format("%d%%", math.round(((settings.FOV - 50) / 50) * 100)),
						AccentColor = accent,
						LayoutOrder = 1,
						OnChange = function(v) updateSetting("FOV", math.round(50 + v * 50)) end,
					}),
					BrightSlider = e(Slider, {
						Label = "Lighting Brightness",
						Value = settings.Brightness,
						DisplayValue = string.format("%d%%", math.round(settings.Brightness * 100)),
						AccentColor = accent,
						LayoutOrder = 2,
						OnChange = function(v) updateSetting("Brightness", v) end,
					}),
				},
			}),
			PostFx = e(Section, {
				Title = "Post-Processing & Shaders",
				Subtitle = "Balance visuals and performance",
				LayoutOrder = 2,
				Children = {
					ShadowToggle = e(Toggle, {
						Label = "Global Dynamic Shadows",
						Description = "Sunlight and shadows",
						Value = settings.GlobalShadows,
						AccentColor = accent,
						LayoutOrder = 1,
						OnToggle = function() updateSetting("GlobalShadows", not settings.GlobalShadows) end,
					}),
					BloomToggle = e(Toggle, {
						Label = "Bloom & Glow Effects",
						Description = "Glowing effects",
						Value = settings.Bloom,
						AccentColor = accent,
						LayoutOrder = 2,
						OnToggle = function() updateSetting("Bloom", not settings.Bloom) end,
					}),
					ColorToggle = e(Toggle, {
						Label = "Atmospheric Color Correction",
						Description = "Color and contrast",
						Value = settings.ColorFX,
						AccentColor = accent,
						LayoutOrder = 3,
						OnToggle = function() updateSetting("ColorFX", not settings.ColorFX) end,
					}),
				},
			}),
		})
	end

	----------------------------------------------------------------------------
	-- 5. Main Clear Glass Modal Window
	----------------------------------------------------------------------------
	return e("Frame", {
		Name = "SettingsUiRoot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = isOpen,
	}, {
		-- Focus Modal Backdrop Dimmer (dismisses on click outside)
		Dim = e("TextButton", {
			Name = "Dim",
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.55,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			[React.Event.Activated] = function()
				requestClose()
			end,
		}),

		-- Centered Settings Window (Clear Glass Crystal Frame)
		Window = e("Frame", {
			Name = "SettingsPanel",
			ref = panelRef,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 960, 0, 620),
			BackgroundColor3 = Color3.fromRGB(12, 10, 18),
			BackgroundTransparency = 0.35,
			Active = true,
			ZIndex = 2,
		}, {
			Scale = e("UIScale", { ref = scaleRef }),
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
			GlassRimStroke = e("UIStroke", {
				Thickness = 1.2,
				Color = Color3.fromRGB(240, 235, 255),
				Transparency = 0.55,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			GlassSheen = e("UIGradient", {
				Rotation = 135,
				Color = ColorSequence.new(Color3.fromRGB(38, 30, 54), Color3.fromRGB(14, 11, 22)),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.30),
					NumberSequenceKeypoint.new(0.5, 0.45),
					NumberSequenceKeypoint.new(1, 0.35),
				}),
			}),

			Content = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, {
				Padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 16),
					PaddingTop = UDim.new(0, 14),
					PaddingBottom = UDim.new(0, 14),
				}),
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				-- Top Header Bar (Clear Glass Container)
				Header = e("Frame", {
					Name = "Header",
					Size = UDim2.new(1, 0, 0, 68),
					BackgroundColor3 = Color3.fromRGB(16, 13, 24),
					BackgroundTransparency = 0.50,
					LayoutOrder = 1,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
					Stroke = e("UIStroke", {
						Thickness = 1,
						Color = Color3.fromRGB(228, 186, 115),
						Transparency = 0.62,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					Gear = e("Frame", {
						Position = UDim2.new(0, 14, 0.5, -24),
						Size = UDim2.fromOffset(48, 48),
						BackgroundTransparency = 1,
						ZIndex = 3,
					}, {
						Art = e(Icons.Icon, { Name = "Gear", Size = 48 }),
					}),
					Titles = e("Frame", {
						BackgroundTransparency = 1,
						Position = UDim2.new(0, 72, 0, 11),
						Size = UDim2.new(0.75, 0, 1, -22),
						ZIndex = 3,
					}, {
						MainTitle = HeavyLabel({
							Size = UDim2.new(1, 0, 0, 26),
							MaxSize = 24,
							TextXAlignment = Enum.TextXAlignment.Left,
							Text = "S E T T I N G S",
							ZIndex = 3,
						}),
						SubTitle = Body({
							Position = UDim2.fromOffset(0, 28),
							Size = UDim2.new(1, 0, 0, 16),
							TextSize = 13,
							TextColor3 = if dirty then Grimoire.Text.Gold else Grimoire.Text.Muted,
							Text = if dirty then "Unsaved changes: press Apply to keep them" else "All changes applied",
							ZIndex = 3,
						}),
					}),
					ExitBtn = e("TextButton", {
						Name = "ExitButton",
						AutoButtonColor = false,
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -14, 0.5, 0),
						Size = UDim2.fromOffset(40, 40),
						Text = "",
						BackgroundColor3 = Color3.fromRGB(120, 24, 40),
						BackgroundTransparency = 0.35,
						ZIndex = 3,
						[React.Event.Activated] = function() requestClose() end,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
						Stroke = e("UIStroke", {
							Thickness = 1.2,
							Color = Color3.fromRGB(240, 140, 160),
							Transparency = 0.40,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
						X = e("Frame", {
							AnchorPoint = Vector2.new(0.5, 0.5),
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(18, 18),
							BackgroundTransparency = 1,
							ZIndex = 4,
						}, {
							Art = e(Icons.Icon, { Name = "Close", Size = 18 }),
						}),
					}),
				}),

				-- Main Body (Left: Content Scroll, Right: Sidebar Container)
				Body = e("Frame", {
					Name = "Body",
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 1, -136),
					LayoutOrder = 2,
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						Padding = UDim.new(0, 12),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					-- Left Content Scroll Area
					ContentArea = e("ScrollingFrame", {
						Name = "ContentArea",
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Size = UDim2.new(1, -242, 1, 0),
						ScrollBarThickness = 5,
						ScrollBarImageColor3 = Color3.fromRGB(228, 186, 115),
						CanvasSize = UDim2.new(0, 0, 0, 0),
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						LayoutOrder = 1,
					}, {
						Padding = e("UIPadding", {
							PaddingTop = UDim.new(0, 2),
							PaddingLeft = UDim.new(0, 2),
							PaddingRight = UDim.new(0, 8),
							PaddingBottom = UDim.new(0, 2),
						}),
						Page = pageContent,
					}),

					-- Right Sidebar Container (Clear Glass Container)
					Sidebar = e("Frame", {
						Name = "Sidebar",
						Size = UDim2.new(0, 230, 1, 0),
						BackgroundColor3 = Color3.fromRGB(16, 13, 24),
						BackgroundTransparency = 0.50,
						LayoutOrder = 2,
					}, {
						Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
						Stroke = e("UIStroke", {
							Thickness = 1,
							Color = Color3.fromRGB(228, 186, 115),
							Transparency = 0.62,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						}),
						Padding = e("UIPadding", {
							PaddingLeft = UDim.new(0, 10),
							PaddingRight = UDim.new(0, 10),
							PaddingTop = UDim.new(0, 12),
							PaddingBottom = UDim.new(0, 12),
						}),
						Layout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Vertical,
							Padding = UDim.new(0, 10),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),

						-- Player Profile Card
						ProfileCard = e("Frame", {
							Name = "ProfileCard",
							Size = UDim2.new(1, 0, 0, 66),
							BackgroundColor3 = Color3.fromRGB(22, 18, 34),
							BackgroundTransparency = 0.50,
							LayoutOrder = 1,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(0, 10) }),
							Stroke = e("UIStroke", {
								Thickness = 1,
								Color = Color3.fromRGB(228, 186, 115),
								Transparency = 0.65,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							}),
							Avatar = e("ImageLabel", {
								BackgroundColor3 = Color3.fromRGB(26, 20, 36),
								Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId),
								Position = UDim2.fromOffset(10, 9),
								Size = UDim2.fromOffset(48, 48),
								ZIndex = 3,
							}, {
								Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
								Stroke = e("UIStroke", {
									Color = Color3.fromRGB(228, 186, 115),
									Thickness = 1,
									Transparency = 0.50,
								}),
							}),
							Info = e("Frame", {
								BackgroundTransparency = 1,
								Position = UDim2.fromOffset(66, 12),
								Size = UDim2.new(1, -74, 0, 42),
								ZIndex = 3,
							}, {
								Name = HeavyLabel({
									Size = UDim2.new(1, 0, 0, 20),
									MaxSize = 15,
									Outline = 2,
									TextXAlignment = Enum.TextXAlignment.Left,
									TextTruncate = Enum.TextTruncate.AtEnd,
									Text = LocalPlayer.DisplayName,
									ZIndex = 3,
								}),
								User = Body({
									Position = UDim2.fromOffset(0, 22),
									Size = UDim2.new(1, 0, 0, 16),
									TextSize = 12,
									TextColor3 = Grimoire.Text.Muted,
									Text = "@" .. LocalPlayer.Name,
									ZIndex = 3,
								}),
							}),
						}),

						-- Tabs
						T1 = e(TabButton, {
							Name = "Overview",
							Subtitle = "Quick status & presets",
							IsActive = activeTab == "Overview",
							AccentColor = accent,
							LayoutOrder = 2,
							OnClick = function() setActiveTab("Overview") end,
						}),
						T2 = e(TabButton, {
							Name = "Audio",
							Subtitle = "Volume mix & mutes",
							IsActive = activeTab == "Audio",
							AccentColor = accent,
							LayoutOrder = 3,
							OnClick = function() setActiveTab("Audio") end,
						}),
						T3 = e(TabButton, {
							Name = "Graphics",
							Subtitle = "Lighting & shaders",
							IsActive = activeTab == "Graphics",
							AccentColor = accent,
							LayoutOrder = 4,
							OnClick = function() setActiveTab("Graphics") end,
						}),
					}),
				}),

				-- Bottom Footer Bar (Clear Glass Container)
				Footer = e("Frame", {
					Name = "Footer",
					Size = UDim2.new(1, 0, 0, 46),
					BackgroundColor3 = Color3.fromRGB(16, 13, 24),
					BackgroundTransparency = 0.50,
					LayoutOrder = 3,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
					Stroke = e("UIStroke", {
						Thickness = 1,
						Color = Color3.fromRGB(228, 186, 115),
						Transparency = 0.62,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					Content = e("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 2,
					}, {
						Padding = e("UIPadding", {
							PaddingLeft = UDim.new(0, 16),
							PaddingRight = UDim.new(0, 8),
						}),
						StatusText = Body({
							Text = statusMsg,
							TextSize = 13,
							TextColor3 = Grimoire.Text.Muted,
							Size = UDim2.new(0.60, 0, 1, 0),
						}),
						Actions = e("Frame", {
							BackgroundTransparency = 1,
							AnchorPoint = Vector2.new(1, 0.5),
							Position = UDim2.new(1, 0, 0.5, 0),
							Size = UDim2.new(0, 280, 0, 34),
						}, {
							Layout = e("UIListLayout", {
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								Padding = UDim.new(0, 10),
							}),
							ResetBtn = e(ActionButton, {
								Text = "Reset Defaults",
								Primary = false,
								AccentColor = accent,
								Size = UDim2.new(0, 150, 1, 0),
								LayoutOrder = 1,
								OnClick = resetDefaults,
							}),
							ApplyBtn = e(ActionButton, {
								Text = if dirty then "Apply" else "Applied",
								Primary = dirty,
								AccentColor = accent,
								Size = UDim2.new(0, 90, 1, 0),
								LayoutOrder = 2,
								OnClick = applySettings,
							}),
						}),
					}),
				}),
			}),

			-- "Discard unsaved changes?" prompt, over the window, when closing with an unapplied draft.
			DiscardPrompt = if confirmDiscard then e("TextButton", {
				Name = "DiscardPrompt",
				AutoButtonColor = false,
				Text = "",
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.4,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 40,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
				Dialog = e("Frame", {
					Name = "Dialog",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(420, 190),
					BackgroundColor3 = Grimoire.Tones.Deep.Top,
					ZIndex = 41,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 12) }),
					Ink = e("UIStroke", { Color = Grimoire.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
					Pad = e("UIPadding", {
						PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20),
						PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 18),
					}),
					Title = HeavyLabel({
						Size = UDim2.new(1, 0, 0, 28),
						MaxSize = 22,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = "Discard unsaved changes?",
						ZIndex = 42,
					}),
					Message = Body({
						Position = UDim2.fromOffset(0, 36),
						Size = UDim2.new(1, 0, 0, 44),
						TextSize = 15,
						TextWrapped = true,
						TextTruncate = Enum.TextTruncate.None,
						TextColor3 = Grimoire.Text.Parchment,
						Text = "You're previewing changes you haven't applied. Discarding goes back to your applied settings.",
						ZIndex = 42,
					}),
					Actions = e("Frame", {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, 40),
						ZIndex = 42,
					}, {
						Layout = e("UIListLayout", {
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Right,
							Padding = UDim.new(0, 10),
						}),
						Keep = e(ActionButton, {
							Text = "Keep editing",
							Primary = true,
							AccentColor = accent,
							Size = UDim2.new(0, 150, 1, 0),
							LayoutOrder = 1,
							OnClick = function() setConfirmDiscard(false) end,
						}),
						Discard = e(ActionButton, {
							Text = "Discard",
							Primary = false,
							AccentColor = Grimoire.Text.Bad,
							Size = UDim2.new(0, 110, 1, 0),
							LayoutOrder = 2,
							OnClick = discardAndClose,
						}),
					}),
				}),
			}) else nil,
		}),
	})
end

return SettingsApp
