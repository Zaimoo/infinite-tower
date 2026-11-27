--!strict
-- StarterPlayerScripts/UI/Hud/ForgeRollHud.luau
-- Brighter Grimoire Open Forge proximity dock shown when standing near the player's own
-- Building_Blacksmith terrace (< 28 studs from the Master Anvil) with no full-screen modal open.
-- Exposes live Pedestals + uncapped Roll Luck stats, Free Reroll, Auto-Roll GamePass toggle,
-- Auto-Roll filter chips (ONLY shown once the Auto-Roll GamePass is owned), and Upgrades shortcut.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtifactCatalog = require(Shared:WaitForChild("Config"):WaitForChild("ArtifactCatalog"))
local TreeConfig = require(Shared:WaitForChild("Config"):WaitForChild("FortressTreeConfig"))
local ShopConfig = require(Shared:WaitForChild("Config"):WaitForChild("ShopConfig"))
local FortressTree = require(Shared:WaitForChild("Util"):WaitForChild("FortressTree"))
local RollLuck = require(Shared:WaitForChild("Util"):WaitForChild("RollLuck"))
local ForgeRollRules = require(Shared:WaitForChild("Util"):WaitForChild("ForgeRollRules"))

local Theme = require(script.Parent:WaitForChild("Theme"))
local Icons = require(script.Parent:WaitForChild("Icons"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local UIFeel = require(script.Parent.Parent:WaitForChild("UIFeel"))

local e = React.createElement
local LocalPlayer = Players.LocalPlayer
local Tokens = Kit.Tokens
local Ink = Tokens.Ink

local PROXIMITY_RADIUS = 28

local TYPE_CYCLE = {
	"ANY",
	"SWORD_SHIELD",
	"DAGGERS",
	"BOW",
	"AXE",
	"STAFF",
	"TOME",
}

local TYPE_META: { [string]: { Label: string, Icon: string } } = {
	ANY = { Label = "Any Type", Icon = "Forge" },
	SWORD_SHIELD = { Label = "Sword", Icon = "Vanguard" },
	DAGGERS = { Label = "Daggers", Icon = "Striker" },
	BOW = { Label = "Bow", Icon = "Marksman" },
	AXE = { Label = "Axe", Icon = "Berserker" },
	STAFF = { Label = "Staff", Icon = "Scholar" },
	TOME = { Label = "Tome", Icon = "Healer" },
}

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function getArtifactRemote(name: string): RemoteFunction?
	local folder = Remotes:FindFirstChild("ArtifactRemotes")
	local fn = folder and folder:FindFirstChild(name)
	if fn and fn:IsA("RemoteFunction") then
		return fn
	end
	return nil
end

local function isNearOwnedOpenForge(): boolean
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local plots = Workspace:FindFirstChild("WaitingRoomPlots")
	if not plots then
		return false
	end
	for _, plot in plots:GetChildren() do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
			local buildings = plot:FindFirstChild("PlotBuildings")
			local forge = (buildings and buildings:FindFirstChild("Building_Blacksmith"))
				or plot:FindFirstChild("Building_Blacksmith")
			if not forge then
				return false
			end
			local anvil = forge:FindFirstChild("AnvilInteraction", true)
			local center = if anvil and anvil:IsA("BasePart")
				then anvil.Position
				elseif forge:IsA("Model") then forge:GetPivot().Position
				else nil
			if not center then
				return false
			end
			return (root.Position - center).Magnitude <= PROXIMITY_RADIUS
		end
	end
	return false
end

export type Props = {
	Profile: any,
	Compact: boolean?,
	Top: number?,
	Hidden: boolean?,
}

type DockButtonProps = {
	Name: string,
	Order: number,
	Height: number,
	MinWidth: number,
	TopColor: Color3,
	BottomColor: Color3,
	RailColor: Color3,
	Text: string,
	SubText: string?,
	TextColor: Color3?,
	SubColor: Color3?,
	IconName: string?,
	GemColor: Color3?,
	Disabled: boolean?,
	OnActivated: () -> (),
}

local function DockButton(props: DockButtonProps)
	local hovered, setHovered = React.useState(false)
	local scaleRef = React.useRef(nil :: UIScale?)
	local tweenRef = React.useRef(nil :: Tween?)
	local disabled = props.Disabled == true

	local function animateScale(target: number, duration: number)
		if tweenRef.current then
			tweenRef.current:Cancel()
		end
		local scale = scaleRef.current
		if not scale then
			return
		end
		if UIFeel.ReducedMotion() then
			scale.Scale = 1
			return
		end
		local tw = TweenService:Create(
			scale,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = target }
		)
		tweenRef.current = tw
		tw:Play()
	end

	React.useEffect(function()
		animateScale(if not disabled and hovered then 1.04 else 1.0, 0.12)
		return function()
			if tweenRef.current then
				tweenRef.current:Cancel()
			end
		end
	end, { hovered, disabled })

	return e("TextButton", {
		Name = props.Name,
		LayoutOrder = props.Order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(props.MinWidth, props.Height),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if disabled then 0.3 else 0,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 23,
		[React.Event.MouseEnter] = function()
			setHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setHovered(false)
		end,
		[React.Event.InputBegan] = function(_, input)
			if
				not disabled
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				animateScale(0.95, 0.05)
			end
		end,
		[React.Event.InputEnded] = function()
			animateScale(if not disabled and hovered then 1.04 else 1.0, 0.1)
		end,
		[React.Event.Activated] = function()
			if disabled then
				return
			end
			UIFeel.Sfx("Click")
			props.OnActivated()
		end,
	}, {
		Scale = e("UIScale", { ref = scaleRef }),
		MinSize = e("UISizeConstraint", { MinSize = Vector2.new(props.MinWidth, props.Height) }),
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 9) }),
		Fill = e("UIGradient", {
			Color = ColorSequence.new(props.TopColor, props.BottomColor),
			Rotation = 90,
		}),
		InkStroke = e("UIStroke", {
			Color = Ink,
			Thickness = 2.2,
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		InnerRail = e("Frame", {
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			BackgroundTransparency = 1,
			Active = false,
			ZIndex = 24,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 7) }),
			Line = e("UIStroke", {
				Color = props.RailColor,
				Thickness = 1.2,
				Transparency = if disabled then 0.6 else 0.18,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		Row = e("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			ZIndex = 25,
		}, {
			Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Gem = if props.GemColor
				then e("Frame", {
					LayoutOrder = 1,
					Size = UDim2.fromOffset(10, 10),
					Rotation = 45,
					BackgroundColor3 = props.GemColor,
					BorderSizePixel = 0,
					ZIndex = 26,
				}, {
					Corner = e("UICorner", { CornerRadius = UDim.new(0, 2) }),
					Stroke = e("UIStroke", { Color = Ink, Thickness = 1.4 }),
				})
				else nil,
			Icon = if props.IconName
				then e("Frame", {
					LayoutOrder = 2,
					Size = UDim2.fromOffset(18, 18),
					BackgroundTransparency = 1,
					ZIndex = 26,
				}, {
					Art = e(Icons.Icon, { Name = props.IconName, Size = 18 }),
				})
				else nil,
			Labels = e("Frame", {
				LayoutOrder = 3,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				ZIndex = 26,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Title = e("TextLabel", {
					LayoutOrder = 1,
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundTransparency = 1,
					FontFace = Tokens.Fonts.Title,
					Text = props.Text,
					TextSize = if props.SubText then 13 else 14,
					TextColor3 = props.TextColor or Color3.new(1, 1, 1),
					ZIndex = 27,
				}, {
					Ink = e("UIStroke", {
						Color = Ink,
						Thickness = 1.8,
						LineJoinMode = Enum.LineJoinMode.Round,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
					}),
				}),
				Sub = if props.SubText
					then e("TextLabel", {
						LayoutOrder = 2,
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						FontFace = Tokens.Fonts.Number,
						Text = props.SubText,
						TextSize = 10,
						TextColor3 = props.SubColor or Color3.fromRGB(255, 240, 196),
						ZIndex = 27,
					}, {
						Ink = e("UIStroke", {
							Color = Ink,
							Thickness = 1.2,
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						}),
					})
					else nil,
			}),
		}),
	})
end

local function StatPill(props: { Order: number, Label: string, Value: string, Accent: Color3 })
	return e("Frame", {
		LayoutOrder = props.Order,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = Color3.fromRGB(11, 16, 24),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ZIndex = 24,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Stroke = e("UIStroke", {
			Color = props.Accent,
			Thickness = 1.2,
			Transparency = 0.25,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Pad = e("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }),
		Row = e("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			ZIndex = 25,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Key = e("TextLabel", {
				LayoutOrder = 1,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = Tokens.Fonts.Body,
				Text = props.Label,
				TextSize = 11,
				TextColor3 = Color3.fromRGB(203, 213, 225),
				ZIndex = 26,
			}),
			Val = e("TextLabel", {
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				FontFace = Tokens.Fonts.Number,
				Text = props.Value,
				TextSize = 12,
				TextColor3 = props.Accent,
				ZIndex = 26,
			}, {
				Ink = e("UIStroke", { Color = Ink, Thickness = 1.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
			}),
		}),
	})
end

local function ForgeRollHud(props: Props)
	local nearForge, setNearForge = React.useState(false)
	local busy, setBusy = React.useState(false)
	local animating, setAnimating = React.useState(LocalPlayer:GetAttribute("ForgeRollAnimating") == true)
	local autoActive, setAutoActive = React.useState(LocalPlayer:GetAttribute("ForgeAutoRollActive") == true)
	local passConfig = ShopConfig.Passes and ShopConfig.Passes.ForgeAutoRoll
	local passAttr = passConfig and passConfig.Attribute or "OwnsForgeAutoRoll"
	local ownsPass, setOwnsPass = React.useState(
		LocalPlayer:GetAttribute(passAttr) == true or LocalPlayer:GetAttribute("StudioGrantAutoRoll") == true
	)
	local dockScaleRef = React.useRef(nil :: UIScale?)

	React.useEffect(function()
		local alive = true
		setNearForge(isNearOwnedOpenForge())
		task.spawn(function()
			while alive do
				task.wait(0.2)
				if not alive then
					break
				end
				local near = isNearOwnedOpenForge()
				setNearForge(function(prev)
					return if prev == near then prev else near
				end)
			end
		end)
		local function syncPass()
			setOwnsPass(
				LocalPlayer:GetAttribute(passAttr) == true or LocalPlayer:GetAttribute("StudioGrantAutoRoll") == true
			)
		end
		local autoConn = LocalPlayer:GetAttributeChangedSignal("ForgeAutoRollActive"):Connect(function()
			setAutoActive(LocalPlayer:GetAttribute("ForgeAutoRollActive") == true)
		end)
		local animConn = LocalPlayer:GetAttributeChangedSignal("ForgeRollAnimating"):Connect(function()
			setAnimating(LocalPlayer:GetAttribute("ForgeRollAnimating") == true)
		end)
		local passConn = LocalPlayer:GetAttributeChangedSignal(passAttr):Connect(syncPass)
		local studioConn = LocalPlayer:GetAttributeChangedSignal("StudioGrantAutoRoll"):Connect(syncPass)
		return function()
			alive = false
			autoConn:Disconnect()
			animConn:Disconnect()
			passConn:Disconnect()
			studioConn:Disconnect()
		end
	end, {})

	local profile = props.Profile
	local forgeUnlocked = profile and profile.Unlocks and profile.Unlocks.Forge == true
	local visible = not props.Hidden and nearForge and profile ~= nil and forgeUnlocked

	React.useEffect(function()
		if not visible or UIFeel.ReducedMotion() then
			return
		end
		local scale = dockScaleRef.current
		if not scale then
			return
		end
		scale.Scale = 0.92
		local tw = TweenService:Create(
			scale,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		tw:Play()
		return function()
			tw:Cancel()
		end
	end, { visible })

	if not visible then
		return nil
	end

	local tree = profile.FortressTree
	local pedestals = FortressTree.ForgePedestals(tree)
	local maxPedestals = TreeConfig.MaxForgePedestals or 6
	local luckPct = math.round(RollLuck.ForProfile(profile) * 100)

	local rollState = profile.ForgeRoll or {}
	local minRarity, weaponType = ForgeRollRules.SanitizeFilter(rollState.MinRarity or 5, rollState.WeaponType or "ANY")
	local safeMinRarity = minRarity or 5
	local safeWeaponType = weaponType or "ANY"
	local rarityInfo = ArtifactCatalog.GetRarityInfo(safeMinRarity)
	local rarityColor = Theme.RarityColor(safeMinRarity)
	local typeInfo = TYPE_META[safeWeaponType] or TYPE_META.ANY

	local compact = props.Compact == true
	local btnH = if compact then 34 else 38

	local function invokeReroll()
		if busy or animating then
			return
		end
		local remote = getArtifactRemote("RerollForge")
		if not remote then
			return
		end
		setBusy(true)
		task.spawn(function()
			pcall(function()
				remote:InvokeServer()
			end)
			setBusy(false)
		end)
	end

	local function invokeConfig(payload: { [string]: any })
		local remote = getArtifactRemote("SetAutoRollConfig")
		if not remote then
			return
		end
		task.spawn(function()
			pcall(function()
				remote:InvokeServer(payload)
			end)
		end)
	end

	local function onToggleAutoRoll()
		if not ownsPass then
			if passConfig and passConfig.GamePassId ~= 0 then
				pcall(function()
					MarketplaceService:PromptGamePassPurchase(LocalPlayer, passConfig.GamePassId)
				end)
			end
			invokeConfig({ Enabled = true })
			return
		end
		invokeConfig({ Enabled = not autoActive })
	end

	local function onCycleRarity()
		local nextTier = if safeMinRarity >= 7 then 3 else math.max(3, safeMinRarity + 1)
		invokeConfig({ MinRarity = nextTier })
	end

	local function onCycleType()
		local idx = table.find(TYPE_CYCLE, safeWeaponType) or 1
		local nextType = TYPE_CYCLE[(idx % #TYPE_CYCLE) + 1]
		invokeConfig({ WeaponType = nextType })
	end

	local function onOpenUpgrades()
		local openBranch = (_G :: any).OpenFortressBranch
		if type(openBranch) == "function" then
			openBranch("ForgePedestals")
			return
		end
		local openFacility = (_G :: any).OpenFacilityHUD
		if type(openFacility) == "function" then
			openFacility("FortressTree")
		end
	end

	local autoTone = if autoActive
		then Tokens.Intent.Confirm
		elseif ownsPass then Tokens.Intent.Secondary
		else { Top = Color3.fromRGB(214, 146, 44), Bottom = Color3.fromRGB(132, 74, 18), Rail = Color3.fromRGB(255, 240, 180) }

	local filterTop = Tokens.Surface.Panel.Top:Lerp(rarityColor, 0.24)
	local filterBottom = Tokens.Surface.Inset.Bottom:Lerp(rarityColor, 0.12)

	return e("Frame", {
		Name = "ForgeRollHudBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, props.Top or 14),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 20,
	}, {
		Scale = e("UIScale", { ref = dockScaleRef }),
		Corner = e("UICorner", { CornerRadius = UDim.new(0, 14) }),
		Fill = e("UIGradient", {
			Color = ColorSequence.new(Tokens.Surface.Window.Top, Tokens.Surface.Window.Bottom),
			Rotation = 90,
		}),
		Ink = e("UIStroke", {
			Color = Ink,
			Thickness = 2.8,
			LineJoinMode = Enum.LineJoinMode.Round,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		GoldRail = e("Frame", {
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundTransparency = 1,
			Active = false,
			ZIndex = 21,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0, 11) }),
			Line = e("UIStroke", {
				Color = if autoActive then Color3.fromRGB(110, 236, 130) else Tokens.Surface.Window.Rail,
				Thickness = 1.4,
				Transparency = 0.2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
		}),
		Body = e("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			ZIndex = 22,
		}, {
			Pad = e("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 8),
			}),
			Stack = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			-- Top Ember Header Bar: OPEN FORGE crest + live Pedestals & Roll Luck badges
			Header = e("Frame", {
				Name = "ForgeDockHeader",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 23,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0, 8) }),
				Fill = e("UIGradient", {
					Color = ColorSequence.new(Tokens.Domain.Forge.Top, Tokens.Domain.Forge.Bottom),
					Rotation = 90,
				}),
				Stroke = e("UIStroke", {
					Color = Ink,
					Thickness = 1.8,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				Left = e("Frame", {
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromScale(0, 1),
					Position = UDim2.fromOffset(8, 0),
					BackgroundTransparency = 1,
					ZIndex = 24,
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Crest = e("Frame", {
						LayoutOrder = 1,
						Size = UDim2.fromOffset(18, 18),
						BackgroundTransparency = 1,
						ZIndex = 25,
					}, {
						Art = e(Icons.Icon, { Name = "Forge", Size = 18 }),
					}),
					Title = e("TextLabel", {
						LayoutOrder = 2,
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						FontFace = Tokens.Fonts.Title,
						Text = "OPEN FORGE",
						TextSize = 14,
						TextColor3 = Color3.new(1, 1, 1),
						ZIndex = 25,
					}, {
						Gradient = e("UIGradient", {
							Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 224, 138)),
							Rotation = 90,
						}),
						Ink = e("UIStroke", { Color = Ink, Thickness = 1.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
					}),
				}),
				Right = e("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -6, 0.5, 0),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 22),
					BackgroundTransparency = 1,
					ZIndex = 24,
				}, {
					Layout = e("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 6),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Pedestals = e(StatPill, {
						Order = 1,
						Label = "PEDESTALS",
						Value = string.format("%d/%d", pedestals, maxPedestals),
						Accent = Color3.fromRGB(253, 224, 71),
					}),
					Luck = e(StatPill, {
						Order = 2,
						Label = "ROLL LUCK",
						Value = string.format("+%d%%", luckPct),
						Accent = if luckPct > 0 then Color3.fromRGB(74, 222, 128) else Color3.fromRGB(203, 213, 225),
					}),
				}),
			}),

			-- Action Row: Reroll (Free) | Auto-Roll | (Target Rarity & Weapon Type only when Auto-Roll owned) | Upgrades
			Actions = e("Frame", {
				Name = "ForgeDockActions",
				LayoutOrder = 2,
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				ZIndex = 23,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 7),
					SortOrder = Enum.SortOrder.LayoutOrder,
					Wraps = compact,
				}),
				Reroll = e(DockButton, {
					Name = "ForgeHudRerollBtn",
					Order = 1,
					Height = btnH,
					MinWidth = if compact then 110 else 128,
					TopColor = if busy or animating then Tokens.Intent.Disabled.Top else Tokens.Intent.Primary.Top,
					BottomColor = if busy or animating then Tokens.Intent.Disabled.Bottom else Tokens.Intent.Primary.Bottom,
					RailColor = if busy or animating then Tokens.Intent.Disabled.Rail else Tokens.Intent.Primary.Rail,
					Text = if busy or animating then "ROLLING…" else "REROLL",
					SubText = if busy or animating then "WAIT FOR REVEAL" else "FREE · ANVIL",
					SubColor = Color3.fromRGB(255, 250, 214),
					IconName = "Hammer",
					Disabled = busy or animating,
					OnActivated = invokeReroll,
				}),
				AutoRoll = e(DockButton, {
					Name = "ForgeHudAutoRollBtn",
					Order = 2,
					Height = btnH,
					MinWidth = if compact then 106 else 122,
					TopColor = autoTone.Top,
					BottomColor = autoTone.Bottom,
					RailColor = autoTone.Rail,
					Text = if autoActive then "AUTO: ON" elseif ownsPass then "AUTO: OFF" else "AUTO-ROLL",
					SubText = if autoActive
						then "ROLLING…"
						elseif ownsPass then "GAMEPASS"
						else string.format("%d ROBUX", passConfig and passConfig.RobuxPrice or 199),
					IconName = if ownsPass then (if autoActive then "Check" else "Forge") else "Robux",
					OnActivated = onToggleAutoRoll,
				}),
				-- Auto-Roll filter settings ONLY appear once the player owns the Auto-Roll GamePass
				TargetRarity = if ownsPass
					then e(DockButton, {
						Name = "ForgeHudRarityChip",
						Order = 3,
						Height = btnH,
						MinWidth = if compact then 112 else 128,
						TopColor = filterTop,
						BottomColor = filterBottom,
						RailColor = rarityColor,
						Text = string.upper(rarityInfo.Name) .. (if safeMinRarity < 7 then "+" else ""),
						SubText = "STOP TARGET",
						TextColor = rarityColor:Lerp(Color3.new(1, 1, 1), 0.35),
						SubColor = Color3.fromRGB(172, 188, 208),
						GemColor = rarityColor,
						OnActivated = onCycleRarity,
					})
					else nil,
				TargetType = if ownsPass
					then e(DockButton, {
						Name = "ForgeHudTypeChip",
						Order = 4,
						Height = btnH,
						MinWidth = if compact then 100 else 114,
						TopColor = Tokens.Surface.Panel.Top,
						BottomColor = Tokens.Surface.Inset.Bottom,
						RailColor = Tokens.Surface.Panel.Rail,
						Text = typeInfo.Label,
						SubText = "FILTER TYPE",
						SubColor = Color3.fromRGB(172, 188, 208),
						IconName = typeInfo.Icon,
						OnActivated = onCycleType,
					})
					else nil,
				Upgrades = e(DockButton, {
					Name = "ForgeHudUpgradesBtn",
					Order = 5,
					Height = btnH,
					MinWidth = if compact then 96 else 112,
					TopColor = Tokens.Intent.Travel.Top,
					BottomColor = Tokens.Intent.Travel.Bottom,
					RailColor = Tokens.Intent.Travel.Rail,
					Text = "UPGRADES",
					SubText = "SLOTS & LUCK",
					IconName = "Fortress",
					OnActivated = onOpenUpgrades,
				}),
			}),
		}),
	})
end

return ForgeRollHud
