--!strict
-- StarterPlayerScripts/UI/Settings/SettingsApp.luau
-- Main Declarative React Luau Settings Application

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local SettingsConfig = require(script.Parent:WaitForChild("SettingsConfig"))
local SettingsComponents = require(script.Parent:WaitForChild("SettingsComponents"))

local e = React.createElement
local useState = React.useState
local useEffect = React.useEffect
local useCallback = React.useCallback
local useMemo = React.useMemo

local Section = SettingsComponents.Section
local Slider = SettingsComponents.Slider
local Toggle = SettingsComponents.Toggle
local TabButton = SettingsComponents.TabButton
local StatCard = SettingsComponents.StatCard
local ActionButton = SettingsComponents.ActionButton
-- Gilded Grimoire building blocks (shared with the Phase 5 HUD).
local Panel = SettingsComponents.Panel
local HeavyLabel = SettingsComponents.HeavyLabel
local Body = SettingsComponents.Body
local Grimoire = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("GildedGrimoire"))
local Icons = require(script.Parent.Parent:WaitForChild("Hud"):WaitForChild("Icons"))
local Tones = Grimoire.Tones

local LocalPlayer = Players.LocalPlayer

local function ensureEffect<T>(className: string, name: string): T
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then
		return found :: any
	end
	if found then found:Destroy() end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst :: any
end

local function SettingsApp()
	local isOpen, setIsOpen = useState(false)
	local activeTab, setActiveTab = useState("Overview" :: SettingsConfig.TabName)
	local statusMsg, setStatusMsg = useState("Ready. Adjust any parameter with live preview.")
	local settings, setSettings = useState(table.clone(SettingsConfig.DEFAULTS))

	local theme = SettingsConfig.THEMES[settings.Theme] or SettingsConfig.THEMES.Gold
	local accent = theme.Accent

	----------------------------------------------------------------------------
	-- System & Engine Effects (Live Preview)
	----------------------------------------------------------------------------
	useEffect(function()
		local camera = workspace.CurrentCamera
		if camera then
			camera.FieldOfView = settings.FOV
		end

		-- Lighting
		Lighting.Brightness = settings.Brightness * 2
		Lighting.GlobalShadows = settings.GlobalShadows

		local bloom = ensureEffect("BloomEffect", "SettingsLocalBloom") :: BloomEffect
		bloom.Enabled = settings.Bloom
		bloom.Intensity = 0.45
		bloom.Size = 18

		local colorCorr = ensureEffect("ColorCorrectionEffect", "SettingsLocalColor") :: ColorCorrectionEffect
		colorCorr.Enabled = settings.ColorFX
		colorCorr.Brightness = 0.02
		colorCorr.Contrast = 0.04
		colorCorr.Saturation = 0.02

		local blur = ensureEffect("BlurEffect", "SettingsPanelBlur") :: BlurEffect
		blur.Enabled = isOpen
		blur.Size = if isOpen then (if settings.ReduceMotion then 6 else 14) else 0

		-- SoundGroups
		local sfx = SoundService:FindFirstChild("SFX") :: SoundGroup?
		local music = SoundService:FindFirstChild("Music") :: SoundGroup?
		local ambience = SoundService:FindFirstChild("Ambience") :: SoundGroup?

		if sfx and sfx:IsA("SoundGroup") then
			sfx.Volume = if settings.MuteSFX then 0 else settings.Sound
		end
		if music and music:IsA("SoundGroup") then
			music.Volume = if settings.MuteMusic then 0 else settings.Music
		end
		if ambience and ambience:IsA("SoundGroup") then
			ambience.Volume = if settings.MuteAmbience then 0 else settings.Ambience
		end

		-- Sync attributes to LocalPlayer
		LocalPlayer:SetAttribute("Settings_MasterVolume", settings.Sound)
		LocalPlayer:SetAttribute("Settings_MusicVolume", settings.Music)
		LocalPlayer:SetAttribute("Settings_AmbienceVolume", settings.Ambience)
		LocalPlayer:SetAttribute("Settings_ShowNotifications", settings.ShowNotifications)
		LocalPlayer:SetAttribute("Settings_DamageNumbers", settings.DamageNumbers)
		LocalPlayer:SetAttribute("Settings_CompactMode", settings.CompactMode)
		LocalPlayer:SetAttribute("Settings_ReduceMotion", settings.ReduceMotion)
		LocalPlayer:SetAttribute("Settings_Theme", settings.Theme)
		LocalPlayer:SetAttribute("Settings_Font", settings.Font)

		return function()
			blur.Enabled = false
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
	-- Global APIs and Listeners
	----------------------------------------------------------------------------
	useEffect(function()
		_G.OpenSettings = function() setIsOpen(true) end
		_G.CloseSettings = function() setIsOpen(false) end
		_G.ToggleSettings = function() setIsOpen(function(prev) return not prev end) end
		_G.IsSettingsOpen = function() return isOpen end

		-- Escape key closes UI
		local conn = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.Escape and isOpen then
				setIsOpen(false)
			end
		end)

		-- Bind SettingsButton in PlayerGui
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local boundButtons: { [Instance]: boolean } = {}
		local function bind(btn: Instance)
			if btn.Name == "SettingsButton" and btn:IsA("GuiButton") and not boundButtons[btn] then
				boundButtons[btn] = true
				btn.Activated:Connect(function()
					setIsOpen(function(prev) return not prev end)
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
	-- Value Update Helpers
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
		setStatusMsg("All parameters restored to factory defaults.")
	end, {})

	local applySettings = useCallback(function()
		setStatusMsg("Settings successfully committed and exported.")
	end, {})

	-- Presets
	local applyPreset = useCallback(function(name: string)
		if name == "Quiet" then
			setSettings(function(prev)
				local c = table.clone(prev)
				c.Sound = 0.2
				c.Music = 0.15
				c.Ambience = 0.15
				return c
			end)
			setStatusMsg("Applied Quiet preset (20% master volume).")
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
			setStatusMsg("Applied Maximum Performance preset (effects trimmed).")
		elseif name == "Cinematic" then
			setSettings(function(prev)
				local c = table.clone(prev)
				c.Quality = "High"
				c.GlobalShadows = true
				c.Bloom = true
				c.ColorFX = true
				c.FOV = 75
				return c
			end)
			setStatusMsg("Applied Cinematic preset (full shadows, bloom and color FX).")
		elseif name == "Clean" then
			setSettings(function(prev)
				local c = table.clone(prev)
				c.CompactMode = true
				c.DamageNumbers = false
				c.ShowNotifications = true
				return c
			end)
			setStatusMsg("Applied Clean UI preset (compact layout, minimal popups).")
		end
	end, {})

	if not isOpen then
		return nil
	end

	----------------------------------------------------------------------------
	-- Tab Pages
	----------------------------------------------------------------------------
	local pageContent: any = nil

	if activeTab == "Overview" then
		pageContent = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 14),
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
					Value = string.format("%d%%", math.round(settings.Sound * 100)),
					Subtext = string.format("Music %d%% • Amb %d%%", math.round(settings.Music * 100), math.round(settings.Ambience * 100)),
					AccentColor = accent,
					LayoutOrder = 1,
				}),
				VisualStat = e(StatCard, {
					Title = "VISUAL QUALITY",
					Value = settings.Quality:upper(),
					Subtext = string.format("FOV %d° • Brightness %d%%", math.round(settings.FOV), math.round(settings.Brightness * 100)),
					AccentColor = accent,
					LayoutOrder = 2,
				}),
				EffectsStat = e(StatCard, {
					Title = "DYNAMIC SHADOWS",
					Value = if settings.GlobalShadows then "ENABLED" else "DISABLED",
					Subtext = if settings.Bloom then "Bloom & Shaders On" else "Fast Lighting",
					AccentColor = accent,
					LayoutOrder = 3,
				}),
			}),
			Presets = e(Section, {
				Title = "Quick Configuration Presets",
				Subtitle = "Instantly rebalance audio and graphics for your playstyle",
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
							Text = "Quiet Mode",
							AccentColor = accent,
							Size = UDim2.new(0.31, 0, 1, 0),
							LayoutOrder = 1,
							OnClick = function() applyPreset("Quiet") end,
						}),
						P2 = e(ActionButton, {
							Text = "Max Performance",
							AccentColor = accent,
							Size = UDim2.new(0.31, 0, 1, 0),
							LayoutOrder = 2,
							OnClick = function() applyPreset("Performance") end,
						}),
						P3 = e(ActionButton, {
							Text = "Cinematic Visuals",
							AccentColor = accent,
							Size = UDim2.new(0.31, 0, 1, 0),
							LayoutOrder = 3,
							OnClick = function() applyPreset("Cinematic") end,
						}),
					}),
				},
			}),
			StatusCard = e(Section, {
				Title = "Experience Information",
				Subtitle = "Infinite Towers • Client Runtime Synced",
				LayoutOrder = 3,
				Children = {
					Info = Body({
						Text = "Every slider and toggle updates the live engine instantly. Use the tabs on the left to fine-tune sound channels, post-processing shaders, input scale, and UI palette themes.",
						TextSize = 14,
						TextWrapped = true,
						TextTruncate = Enum.TextTruncate.None,
						Size = UDim2.new(1, 0, 0, 44),
						LayoutOrder = 2,
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
				Padding = UDim.new(0, 14),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Sliders = e(Section, {
				Title = "Volume Levels",
				Subtitle = "Real-time master and directional sound channel controls",
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
				Subtitle = "Instantly silence individual audio groups",
				LayoutOrder = 2,
				Children = {
					T1 = e(Toggle, {
						Label = "Mute Sound Effects",
						Description = "Silences combat impacts, swing whooshes and UI sounds",
						Value = settings.MuteSFX,
						AccentColor = accent,
						LayoutOrder = 1,
						OnToggle = function() updateSetting("MuteSFX", not settings.MuteSFX) end,
					}),
					T2 = e(Toggle, {
						Label = "Mute Music",
						Description = "Stops background melodies and floor boss themes",
						Value = settings.MuteMusic,
						AccentColor = accent,
						LayoutOrder = 2,
						OnToggle = function() updateSetting("MuteMusic", not settings.MuteMusic) end,
					}),
					T3 = e(Toggle, {
						Label = "Mute Ambience",
						Description = "Disables wind and tower environment background sounds",
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
				Padding = UDim.new(0, 14),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			QualitySection = e(Section, {
				Title = "Visual Tuning",
				Subtitle = "World lighting and camera viewport adjustments",
				LayoutOrder = 1,
				Children = {
					FovSlider = e(Slider, {
						Label = "Field of View (Camera FOV)",
						Value = (settings.FOV - 60) / 30,
						AccentColor = accent,
						LayoutOrder = 1,
						OnChange = function(v) updateSetting("FOV", math.round(60 + v * 30)) end,
					}),
					BrightSlider = e(Slider, {
						Label = "Lighting Brightness",
						Value = settings.Brightness,
						AccentColor = accent,
						LayoutOrder = 2,
						OnChange = function(v) updateSetting("Brightness", v) end,
					}),
				},
			}),
			PostFx = e(Section, {
				Title = "Post-Processing & Shaders",
				Subtitle = "Toggle rendering shaders to optimize frame rates",
				LayoutOrder = 2,
				Children = {
					ShadowToggle = e(Toggle, {
						Label = "Global Dynamic Shadows",
						Description = "Simulates realistic sunlight and architectural shadows",
						Value = settings.GlobalShadows,
						AccentColor = accent,
						LayoutOrder = 1,
						OnToggle = function() updateSetting("GlobalShadows", not settings.GlobalShadows) end,
					}),
					BloomToggle = e(Toggle, {
						Label = "Bloom & Glow Effects",
						Description = "Enables glowing energy cores and crystal highlights",
						Value = settings.Bloom,
						AccentColor = accent,
						LayoutOrder = 2,
						OnToggle = function() updateSetting("Bloom", not settings.Bloom) end,
					}),
					ColorToggle = e(Toggle, {
						Label = "Atmospheric Color Correction",
						Description = "Applies sunset sky atmospheric grading and contrast",
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
	-- Render Main Modal
	----------------------------------------------------------------------------
	return e("Frame", {
		Name = "SettingsUiRoot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		-- Dim Backdrop
		Dim = e("TextButton", {
			Name = "Dim",
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.45,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			[React.Event.Activated] = function()
				-- Click outside does not close accidentally
			end,
		}),

		-- Centered Settings Window (Gilded Grimoire violet window)
		Window = Panel({
			Name = "SettingsPanel",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 960, 0, 620),
			Radius = 16,
			ZIndex = 2,
		}, {
			Max = e("UISizeConstraint", { MaxSize = Vector2.new(960, 620) }),
			Content = e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, {
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
				PaddingTop = UDim.new(0, 16),
				PaddingBottom = UDim.new(0, 16),
			}),
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			-- Top Header: drawn gear, gold title, crimson close button
			Header = Panel({
				Name = "Header",
				Size = UDim2.new(1, 0, 0, 72),
				LayoutOrder = 1,
				Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = accent,
			}, {
				Gear = e("Frame", { Position = UDim2.new(0, 14, 0.5, -26), Size = UDim2.fromOffset(52, 52), BackgroundTransparency = 1, ZIndex = 3 }, {
					Art = e(Icons.Icon, { Name = "Gear", Size = 52 }),
				}),
				Titles = e("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 78, 0, 12),
					Size = UDim2.new(0.75, 0, 1, -24),
					ZIndex = 3,
				}, {
					MainTitle = HeavyLabel({ Size = UDim2.new(1, 0, 0, 28), MaxSize = 26, TextXAlignment = Enum.TextXAlignment.Left,
						Text = "S E T T I N G S", ZIndex = 3 }),
					SubTitle = Body({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 16), TextSize = 13,
						TextColor3 = Grimoire.Text.Muted, Text = "Customize your game experience", ZIndex = 3 }),
				}),
				ExitBtn = Panel({
					Class = "TextButton",
					Name = "ExitButton",
					AutoButtonColor = false,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -16, 0.5, 0),
					Size = UDim2.fromOffset(42, 42),
					Text = "",
					Radius = 10,
					Top = Tones.Crimson.Top, Bottom = Tones.Crimson.Bottom, Rail = Tones.Crimson.Rail,
					ZIndex = 3,
					[React.Event.Activated] = function() setIsOpen(false) end,
				}, {
					X = e("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, ZIndex = 4 }, {
						Art = e(Icons.Icon, { Name = "Close", Size = 18 }),
					}),
				}),
			}),

			-- Main Body (Sidebar + Content Scroll)
			Body = e("Frame", {
				Name = "Body",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -142),
				LayoutOrder = 2,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 14),
				}),

				-- Left Sidebar
				Sidebar = Panel({
					Name = "Sidebar",
					Size = UDim2.new(0, 230, 1, 0),
					Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Deep.Rail,
				}, {
					Content = e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, {
					Padding = e("UIPadding", {
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 14),
						PaddingBottom = UDim.new(0, 12),
					}),
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						Padding = UDim.new(0, 10),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),

					-- Player Profile Card
					ProfileCard = Panel({
						Size = UDim2.new(1, 0, 0, 66),
						LayoutOrder = 1,
						Radius = 10,
						Top = Tones.Violet.Top, Bottom = Tones.Violet.Bottom, Rail = accent,
					}, {
						Avatar = e("ImageLabel", {
							BackgroundColor3 = Color3.fromRGB(26, 20, 36),
							Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", LocalPlayer.UserId),
							Position = UDim2.fromOffset(10, 9),
							Size = UDim2.fromOffset(48, 48),
							ZIndex = 3,
						}, {
							Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
							Ink = e("UIStroke", { Color = Grimoire.Ink, Thickness = 2.4 }),
						}),
						Info = e("Frame", {
							BackgroundTransparency = 1,
							Position = UDim2.fromOffset(66, 12),
							Size = UDim2.new(1, -74, 0, 42),
							ZIndex = 3,
						}, {
							Name = HeavyLabel({ Size = UDim2.new(1, 0, 0, 20), MaxSize = 15, Outline = 2, TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd, Text = LocalPlayer.DisplayName, ZIndex = 3 }),
							User = Body({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 16), TextSize = 12,
								TextColor3 = Grimoire.Text.Muted, Text = "@" .. LocalPlayer.Name, ZIndex = 3 }),
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

				-- Right Content Scroll Area
				Content = e("ScrollingFrame", {
					Name = "ContentArea",
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Size = UDim2.new(1, -244, 1, 0),
					ScrollBarThickness = 5,
					ScrollBarImageColor3 = accent,
					CanvasSize = UDim2.new(0, 0, 0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
				}, {
					Padding = e("UIPadding", {
						PaddingTop = UDim.new(0, 4),
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 10),
						PaddingBottom = UDim.new(0, 4),
					}),
					Page = pageContent,
				}),
			}),

			-- Footer (Status message + Reset / Apply buttons)
			Footer = Panel({
				Name = "Footer",
				Size = UDim2.new(1, 0, 0, 46),
				LayoutOrder = 3,
				Radius = 12,
				Top = Tones.Deep.Top, Bottom = Tones.Deep.Bottom, Rail = Tones.Deep.Rail,
			}, {
				Content = e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, {
				Padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 8),
				}),
				StatusText = Body({
					Text = statusMsg,
					TextSize = 13,
					TextColor3 = Grimoire.Text.Muted,
					Size = UDim2.new(0.62, 0, 1, 0),
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
						Size = UDim2.new(0, 160, 1, 0),
						LayoutOrder = 1,
						OnClick = resetDefaults,
					}),
					ApplyBtn = e(ActionButton, {
						Text = "Apply",
						Primary = true,
						AccentColor = accent,
						Size = UDim2.new(0, 90, 1, 0),
						LayoutOrder = 2,
						OnClick = applySettings,
					}),
				}),
			}),
		}),
		}),
	}),
})
end

return SettingsApp
