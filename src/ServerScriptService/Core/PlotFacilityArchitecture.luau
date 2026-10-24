--!strict
-- Reference-inspired round sanctuaries, courtyard standard, and freestanding rift gate.
local Architecture = {}
local V = Vector3.new
local stone = Color3.fromRGB(156, 160, 164)
local pale = Color3.fromRGB(194, 192, 178)
local shadow = Color3.fromRGB(85, 95, 104)
local bronze = Color3.fromRGB(145, 129, 92)
local doorColor = Color3.fromRGB(39, 62, 69)

function Architecture.Build(model: Model, frame: CFrame, id: string, accent: Color3)
	local function block(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, frame * cf
		p.Anchored, p.Color, p.Material = true, color, material or Enum.Material.Limestone
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local function part(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?): Part
		return block(name, size, CFrame.new(pos), color, material)
	end
	local function cylinder(name: string, radius: number, height: number, pos: Vector3, color: Color3, material: Enum.Material?): Part
		local p = block(name, V(height, radius * 2, radius * 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function line(name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material?): Part
		local p = block(name, V(thickness, thickness, (b - a).Magnitude + .04), CFrame.lookAt((a + b) / 2, b), color, material)
		p.CanCollide = false
		return p
	end
	local function glow(name: string, size: Vector3, pos: Vector3): Part
		local p = part(name, size, pos, accent, Enum.Material.Neon)
		p.CanCollide = false
		return p
	end
	local function sign(anchor: Part, title: string, subtitle: string)
		for _, face in {Enum.NormalId.Front, Enum.NormalId.Back} do
			local gui = Instance.new("SurfaceGui")
			gui.Face, gui.CanvasSize, gui.Parent = face, Vector2.new(800, 200), anchor
			local label = Instance.new("TextLabel")
			label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
			label.Text, label.Font, label.TextSize = title .. "\n" .. subtitle, Enum.Font.GothamBold, 44
			label.TextColor3, label.Parent = pale, gui
		end
	end
	local function arch(name: string, radius: number, centerY: number, z: number, thickness: number, color: Color3, material: Enum.Material?)
		for i = 0, 23 do
			local a, b = math.pi * i / 24, math.pi * (i + 1) / 24
			line(name, V(math.cos(a) * radius, centerY + math.sin(a) * radius, z), V(math.cos(b) * radius, centerY + math.sin(b) * radius, z), thickness, color, material)
		end
	end
	if id == "Infirmary" then
		local teal = Color3.fromRGB(38, 101, 100)
		local lightStone = Color3.fromRGB(183, 185, 168)
		local linen = Color3.fromRGB(225, 222, 197)
		part("WardFoundation", V(31, .7, 25), V(0, .35, 0), shadow)
		part("InlaidWardFloor", V(29.8, .5, 23.8), V(0, .95, 0), lightStone, Enum.Material.Marble)
		for i = 1, 3 do part("EntranceStep_" .. i, V(12 + i * 2, .35, 1.6), V(0, 1.05 - (i - 1) * .35, 12.1 + (i - 1) * 1.35), pale) end
		part("RearMasonry", V(29, 15, 1), V(0, 8.7, -11.3), stone, Enum.Material.Brick)
		for _, x in {-14, 14} do
			part("WindowSillWall", V(1, 4.2, 22), V(x, 3.3, 0), stone, Enum.Material.Brick)
			part("WindowHeaderWall", V(1, 3.7, 22), V(x, 14.35, 0), stone, Enum.Material.Brick)
			for _, z in {-10.3, -2.8, 5, 10.5} do
				part("StoneWindowPier", V(1.4, 11.5, 1.1), V(x, 9, z), lightStone)
			end
			for _, z in {-6.6, 1.1, 7.8} do
				local pane = part("TealWardGlass", V(.14, 7, 5.5), V(x, 9, z), Color3.fromRGB(112, 182, 167), Enum.Material.Glass)
				pane.Transparency, pane.CanCollide = .45, false
				for _, y in {5.5, 9, 12.5} do part("WindowTransom", V(1.2, .18, 5.7), V(x, y, z), bronze, Enum.Material.Metal) end
				part("WindowMullion", V(1.2, 7, .18), V(x, 9, z), bronze, Enum.Material.Metal)
			end
			part("SideCornice", V(1.8, .5, 24), V(x, 16.25, 0), pale)
		end
		-- Three open arches form a sheltered stone arcade across the front.
		for _, x in {-14, -5, 5, 14} do
			part("ArcadePlinth", V(1.7, .7, 2), V(x, 1.6, 10.7), shadow)
			cylinder("ArcadeColumn", .52, 10.3, V(x, 7.1, 10.7), pale)
			cylinder("ArcadeCapital", .8, .6, V(x, 12.5, 10.7), bronze)
		end
		for _, center in {-9.5, 0, 9.5} do
			local radius = center == 0 and 4.5 or 4
			for i = 0, 19 do
				local a, b = math.pi * i / 20, math.pi * (i + 1) / 20
				line("CarvedArcadeArch", V(center + math.cos(a) * radius, 10 + math.sin(a) * radius, 10.7), V(center + math.cos(b) * radius, 10 + math.sin(b) * radius, 10.7), .65, pale)
			end
		end
		part("ArcadeEntablature", V(30, 1.4, 2.5), V(0, 15.9, 10.7), lightStone)
		local title = part("InfirmaryInscription", V(15, 1.9, .22), V(0, 16, 12.1), teal, Enum.Material.Metal)
		sign(title, "INFIRMARY", "HOUSE OF RECOVERY")
		-- Copper-green pitched roofing, gold seams, and a small healing lantern tower.
		for _, side in {-1, 1} do
			local pitch = math.rad(-side * 19)
			block("PitchedTealRoof", V(17.5, .6, 26), CFrame.new(side * 8.15, 19.15, 0) * CFrame.Angles(0, 0, pitch), teal, Enum.Material.Metal)
			for _, z in {-12.7, -6.4, 0, 6.4, 12.7} do
				block("CopperRoofSeam", V(17.6, .1, .12), CFrame.new(side * 8.15, 19.48, z) * CFrame.Angles(0, 0, pitch), bronze, Enum.Material.Metal)
			end
		end
		part("RidgeCap", V(.7, .5, 26.4), V(0, 22.1, 0), bronze, Enum.Material.Metal)
		-- Narrow stacked masonry strips close the gable beneath the roof slopes.
		for _, z in {-11.5, 11.4} do
			for i = 0, 29 do
				local x = -14.5 + (i + .5) * 29 / 30
				local h = 5.2 - math.abs(x) * .342
				part("StoneGable", V(29 / 30 + .01, math.max(.1, h), .7), V(x, 16.6 + h / 2, z), lightStone)
			end
		end
		cylinder("LanternTowerBase", 3, .6, V(0, 23, -3), pale)
		local lantern = cylinder("HealingLantern", 2.2, 4, V(0, 25.2, -3), accent, Enum.Material.Glass)
		lantern.Transparency, lantern.CanCollide = .3, false
		for i = 0, 7 do
			local a = i * math.pi / 4
			cylinder("LanternPillar", .2, 4.5, V(math.cos(a) * 2.45, 25.2, -3 + math.sin(a) * 2.45), pale)
		end
		cylinder("LanternCornice", 3, .5, V(0, 27.6, -3), bronze)
		local dome = part("TealCupola", V(6.4, 3, 6.4), V(0, 28.3, -3), teal, Enum.Material.Metal)
		dome.Shape = Enum.PartType.Ball
		glow("MedicalFinialVertical", V(.5, 3, .5), V(0, 31, -3))
		glow("MedicalFinialHorizontal", V(2, .5, .5), V(0, 31.3, -3))
		local function medicalCross(x: number, y: number, z: number, scale: number)
			part("MedicalCrossVertical", V(.65 * scale, 2.6 * scale, .2), V(x, y, z), linen, Enum.Material.SmoothPlastic)
			part("MedicalCrossHorizontal", V(2.1 * scale, .65 * scale, .2), V(x, y + .2 * scale, z + .02), linen, Enum.Material.SmoothPlastic)
		end
		for _, x in {-11, 11} do
			part("MedicalBannerPole", V(3.5, .18, .25), V(x, 12.4, 12.2), bronze, Enum.Material.Metal)
			part("MedicalBanner", V(2.8, 5, .12), V(x, 9.8, 12.2), teal, Enum.Material.Fabric)
			medicalCross(x, 10, 12.35, .85)
			-- Apothecary planters frame the entrance with silvery medicinal foliage.
			part("HerbPlanter", V(4, 1.6, 2.4), V(x, .85, 14), shadow)
			part("PlanterRim", V(4.3, .25, 2.7), V(x, 1.65, 14), pale)
			for i = -1, 1 do
				local leaf = part("MedicinalShrub", V(1.8, 1.8, 1.8), V(x + i * 1.1, 2.4 + (i == 0 and .4 or 0), 14), Color3.fromRGB(102, 142, 111), Enum.Material.Grass)
				leaf.Shape, leaf.CanCollide = Enum.PartType.Ball, false
			end
		end
		for i = 1, 5 do
			local x = (i - 3) * 4.7
			part("BedFrame_" .. i, V(3.7, .5, 6.4), V(x, 2.1, -5.8), bronze, Enum.Material.Wood)
			for _, z in {-8.2, -3.4} do
				for _, dx in {-1.4, 1.4} do part("BedLeg", V(.25, 1.1, .25), V(x + dx, 1.7, z), bronze, Enum.Material.Wood) end
			end
			part("Mattress_" .. i, V(3.5, .65, 6), V(x, 2.65, -5.8), linen, Enum.Material.Fabric)
			part("TealQuilt_" .. i, V(3.55, .2, 3.7), V(x, 3.05, -4.9), teal, Enum.Material.Fabric)
			part("Pillow_" .. i, V(2.4, .4, 1.3), V(x, 3.1, -8), Color3.fromRGB(240, 236, 220), Enum.Material.Fabric)
			part("CarvedHeadboard", V(3.8, 2.4, .3), V(x, 3, -9), lightStone)
		end
		for _, x in {-7.05, -2.35, 2.35, 7.05} do
			part("PrivacyCurtainRail", V(.12, .12, 7), V(x, 7, -5.9), bronze, Enum.Material.Metal)
			part("GatheredPrivacyCurtain", V(.15, 4.6, 1.8), V(x, 4.6, -8.2), Color3.fromRGB(152, 184, 169), Enum.Material.Fabric)
		end
		part("ApothecaryCabinet", V(5, 4, 1.5), V(-10, 3.2, 3), doorColor, Enum.Material.Wood)
		part("CabinetCounter", V(5.3, .25, 1.8), V(-10, 5.3, 3), pale, Enum.Material.Marble)
		for i = 1, 4 do
			cylinder("MedicineBottle", .22, .7, V(-12 + i * .8, 5.8, 3), i % 2 == 0 and accent or Color3.fromRGB(180, 146, 90), Enum.Material.Glass)
		end
		for _, x in {-5, 5} do
			part("LanternBracket", V(.15, 1, .8), V(x, 10, 12), bronze, Enum.Material.Metal)
			local lamp = part("WarmWardLantern", V(.65, 1.2, .65), V(x, 9.2, 12.4), Color3.fromRGB(255, 218, 151), Enum.Material.Neon)
			lamp.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Parent = lamp.Color, 10, .7, lamp
		end
		return
	end
	if id == "SquadManagement" then
		cylinder("StandardBase", 3.2, .55, V(0, .7, 0), shadow)
		cylinder("BaseMoulding", 2.2, .45, V(0, 1.2, 0), pale)
		cylinder("BaseCap", 1.4, .3, V(0, 1.55, 0), bronze)
		cylinder("BannerPole", .22, 16, V(0, 9.2, 0), bronze, Enum.Material.Metal)
		part("Crossbar", V(7.8, .26, .26), V(0, 15.2, 0), bronze, Enum.Material.Metal)
		for _, x in {-3.9, 3.9} do
			local finial = part("CrossbarFinial", V(.5, .5, .5), V(x, 15.2, 0), pale, Enum.Material.Metal)
			finial.CFrame *= CFrame.Angles(0, 0, math.rad(45))
		end
		-- Crossed halberds behind the banner standard
		local s1 = cylinder("SpearShaft1", .14, 17, V(0, 9.2, -.18), bronze, Enum.Material.Metal)
		s1.CFrame *= CFrame.Angles(0, 0, math.rad(28))
		local s2 = cylinder("SpearShaft2", .14, 17, V(0, 9.2, -.18), bronze, Enum.Material.Metal)
		s2.CFrame *= CFrame.Angles(0, 0, math.rad(-28))

		-- Lantern bracket lighting the war standard
		part("LanternArm", V(.15, .8, 1.4), V(0, 14.6, .8), bronze, Enum.Material.Metal)
		local lamp = part("StandardLantern", V(.7, 1.2, .7), V(0, 13.9, 1.5), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
		lamp.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Parent = lamp.Color, 14, 1.0, lamp

		local cloth = part("SquadBanner", V(7.0, 8.4, .12), V(0, 10.8, 0), Color3.fromRGB(135, 30, 44), Enum.Material.Fabric)
		-- Gold embroidered border and double split tails
		for _, x in {-3.36, 3.36} do part("EmbroideredBorder", V(.16, 8.2, .16), V(x, 10.8, .02), bronze, Enum.Material.Fabric) end
		for _, x in {-1.8, 1.8} do part("BannerTail", V(3.3, 1.3, .12), V(x, 6.0, 0), Color3.fromRGB(135, 30, 44), Enum.Material.Fabric) end
		local crest = part("SpearFinial", V(.9, 1.8, .9), V(0, 17.5, 0), pale, Enum.Material.Metal)
		crest.CFrame *= CFrame.Angles(0, 0, math.rad(45))

		for _, face in {Enum.NormalId.Front, Enum.NormalId.Back} do
			local gui = Instance.new("SurfaceGui")
			gui.Face, gui.CanvasSize, gui.Parent = face, Vector2.new(500, 700), cloth
			local container = Instance.new("Frame")
			container.Size = UDim2.fromScale(1, 1)
			container.BackgroundTransparency = 1
			container.Parent = gui

			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(1, -20, 0, 130)
			title.Position = UDim2.new(0, 10, 0, 40)
			title.BackgroundTransparency = 1
			title.Text = "⚔️\nSQUAD DEPLOY"
			title.TextColor3, title.Font, title.TextSize = Color3.fromRGB(255, 235, 180), Enum.Font.GothamBold, 44
			title.Parent = container

			local divider = Instance.new("TextLabel")
			divider.Size = UDim2.new(1, -20, 0, 40)
			divider.Position = UDim2.new(0, 10, 0, 190)
			divider.BackgroundTransparency = 1
			divider.Text = "◆   ◆   ◆   ◆   ◆"
			divider.TextColor3, divider.Font, divider.TextSize = Color3.fromRGB(245, 195, 90), Enum.Font.GothamBold, 26
			divider.Parent = container

			local sub = Instance.new("TextLabel")
			sub.Size = UDim2.new(1, -20, 0, 80)
			sub.Position = UDim2.new(0, 10, 0, 240)
			sub.BackgroundTransparency = 1
			sub.Text = "ACTIVE SQUAD\n5 COMBAT SLOTS"
			sub.TextColor3, sub.Font, sub.TextSize = Color3.fromRGB(220, 215, 235), Enum.Font.GothamMedium, 28
			sub.Parent = container
		end
		return
	end
	if id == "Summoning" then
		cylinder("PortalPlatform", 12, .5, V(0, .25, 0), shadow)
		cylinder("PortalInlay", 10.8, .16, V(0, .58, 0), pale)
		for _, x in {-7.8, 7.8} do
			part("PillarFoot", V(5, .8, 5), V(x, 1.05, 0), shadow)
			part("PillarPlinth", V(4.2, 1, 4.2), V(x, 1.95, 0), pale)
			cylinder("PillarBase", 2, .8, V(x, 2.85, 0), bronze)
			cylinder("PortalColumn", 1.45, 15.5, V(x, 11, 0), stone)
			for _, y in {3.5, 7.7, 12, 17.8} do cylinder("ColumnBand", 1.6, .24, V(x, y, 0), pale) end
			glow("ColumnRunelight", V(.23, 11, .18), V(x, 10.5, 1.47))
			cylinder("Capital", 2.1, .9, V(x, 19, 0), pale)
			part("CapitalAbacus", V(4.5, .65, 4.5), V(x, 19.75, 0), shadow)
		end
		part("GateEntablature", V(21, 1.3, 5), V(0, 20.7, 0), stone)
		part("GateCornice", V(22, .55, 5.5), V(0, 21.65, 0), pale)
		arch("PortalArchStone", 6.2, 12.1, 0, 1.05, pale)
		arch("PortalRunicArch", 5.55, 12.1, .1, .18, accent, Enum.Material.Neon)
		for _, x in {-5.55, 5.55} do glow("PortalEdge", V(.18, 9.4, .18), V(x, 7.4, .1)) end
		local membrane = glow("RiftMembrane", V(10.7, 10, .15), V(0, 7.3, 0))
		membrane.Transparency = .62
		for i = 0, 17 do
			local x = -5.35 + (i + .5) * 10.7 / 18
			local h = math.sqrt(math.max(0, 5.35 ^ 2 - x ^ 2))
			local p = glow("ArchedRiftMembrane", V(10.7 / 18 + .01, math.max(.05, h), .15), V(x, 12.3 + h / 2, 0))
			p.Transparency = .62
		end
		for _, x in {-3.6, 0, 3.6} do
			local rune = glow("FloatingRiftRune", V(.7, .7, .2), V(x, 8 + math.abs(x) * .3, .35))
			rune.CFrame *= CFrame.Angles(0, 0, math.pi / 4)
		end
		local title = part("GateInscription", V(13, 1.8, .2), V(0, 20.65, 2.62), shadow)
		sign(title, "SUMMONING", "GATE OF THE RIFT")
		return
	end

	if id == "Market" then
		local woodPlank = Color3.fromRGB(115, 85, 55)
		local darkWood = Color3.fromRGB(75, 50, 35)
		local crimson = Color3.fromRGB(160, 35, 45)
		local goldTone = Color3.fromRGB(225, 175, 60)

		-- Wooden bazaar deck foundation
		part("MarketDeck", V(26, .7, 20), V(0, .35, 0), darkWood, Enum.Material.WoodPlanks)
		part("MarketInlaidFloor", V(24.5, .4, 18.5), V(0, .8, 0), woodPlank, Enum.Material.WoodPlanks)

		-- Main Bazaar Stall Frame
		for _, x in {-9.5, 9.5} do
			for _, z in {-7, 7} do
				cylinder("StallPillar", .55, 10, V(x, 5.8, z), darkWood, Enum.Material.Wood)
			end
		end

		-- Twin Striped Canopy Awning
		for i = 0, 9 do
			local z = -7.5 + (i + 0.5) * 1.5
			local color = (i % 2 == 0) and crimson or goldTone
			block("AwningStripeLeft", V(10, .35, 1.5), CFrame.new(-4.8, 11, z) * CFrame.Angles(0, 0, math.rad(-12)), color, Enum.Material.Fabric)
			block("AwningStripeRight", V(10, .35, 1.5), CFrame.new(4.8, 11, z) * CFrame.Angles(0, 0, math.rad(12)), color, Enum.Material.Fabric)
		end
		part("CanopyRidge", V(1.2, .6, 16.5), V(0, 12.1, 0), bronze, Enum.Material.Metal)

		-- Merchant Counters & Display Tables
		part("FrontCounter", V(18, 3.2, 2.2), V(0, 2.4, 6), darkWood, Enum.Material.Wood)
		part("CounterTop", V(19, .4, 2.6), V(0, 4.1, 6), pale, Enum.Material.Marble)

		-- Scales, Ledgers & Coin Bags on Counter
		part("CoinScaleStand", V(.35, 2.2, .35), V(-4, 5.3, 6), bronze, Enum.Material.Metal)
		part("CoinScaleBeam", V(2.2, .18, .18), V(-4, 6.3, 6), bronze, Enum.Material.Metal)
		part("CoinScalePanLeft", V(1, .15, 1), V(-5, 5.7, 6), goldTone, Enum.Material.Metal)
		part("CoinScalePanRight", V(1, .15, 1), V(-3, 5.7, 6), goldTone, Enum.Material.Metal)

		local ledger = part("TradeLedger", V(1.8, .22, 1.4), V(3, 4.4, 6), Color3.fromRGB(240, 235, 215), Enum.Material.Fabric)
		ledger.CFrame *= CFrame.Angles(0, math.rad(15), 0)

		-- Cargo Crates & Sacks Stacked at the Rear
		for _, x in {-6, -2, 4} do
			part("CargoCrate_" .. x, V(3.2, 3.2, 3.2), V(x, 2.4, -4.5), darkWood, Enum.Material.Wood)
			part("CrateIronBand", V(3.3, .3, 3.3), V(x, 2.4, -4.5), shadow, Enum.Material.Metal)
		end
		part("CargoCrateStacked", V(2.8, 2.8, 2.8), V(-4, 5.2, -4.5), darkWood, Enum.Material.Wood)

		-- Hanging Brass Market Lanterns
		for _, x in {-8, 8} do
			part("MarketLanternArm", V(.18, .6, 1.2), V(x, 10, 7), bronze, Enum.Material.Metal)
			local lamp = part("MarketLantern", V(.65, 1.1, .65), V(x, 9.3, 7.5), Color3.fromRGB(255, 215, 140), Enum.Material.Neon)
			lamp.CanCollide = false
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Parent = lamp.Color, 12, 1.0, lamp
		end

		local title = part("MarketSign", V(14, 1.8, .25), V(0, 13.2, 7.8), shadow)
		sign(title, "THE MARKET", "BAZAAR OF COMMERCE")
		return
	end

	if id == "TrainingGrounds" then
		local woodTrim = Color3.fromRGB(90, 65, 45)
		local ropeColor = Color3.fromRGB(195, 175, 135)
		local strawColor = Color3.fromRGB(220, 195, 120)
		local ironMetal = Color3.fromRGB(80, 85, 95)

		-- Cobblestone & Sand Sparring Arena Floor
		cylinder("ArenaFoundation", 12.5, .6, V(0, .3, 0), shadow)
		cylinder("SandSparringRing", 11.8, .4, V(0, .6, 0), Color3.fromRGB(180, 160, 130), Enum.Material.Sand)
		cylinder("ArenaStoneBorder", 12.2, .25, V(0, .85, 0), pale)

		-- Heavy Timber Ring Posts and Boundary Ropes
		for i = 0, 7 do
			local angle = i * math.pi / 4
			local x, z = math.cos(angle) * 11.2, math.sin(angle) * 11.2
			cylinder("RingPost_" .. i, .45, 4.2, V(x, 2.7, z), woodTrim, Enum.Material.Wood)
			for _, ry in {2.2, 3.6} do
				local nextA = (i + 1) * math.pi / 4
				local nx, nz = math.cos(nextA) * 11.2, math.sin(nextA) * 11.2
				line("BoundaryRope", V(x, ry, z), V(nx, ry, nz), .14, ropeColor, Enum.Material.Fabric)
			end
		end

		-- Straw Training Dummies with Bullseye Chestplates
		for _, dx in {-4.5, 4.5} do
			cylinder("DummyStand", .25, 4.2, V(dx, 2.7, -3.5), woodTrim, Enum.Material.Wood)
			part("DummyCrossbar", V(3.2, .25, .25), V(dx, 3.6, -3.5), woodTrim, Enum.Material.Wood)
			local body = part("DummyStrawBody", V(1.8, 2.8, 1.4), V(dx, 3.5, -3.5), strawColor, Enum.Material.Grass)
			body.Shape = Enum.PartType.Ball
			local head = part("DummyHead", V(1.1, 1.2, 1.1), V(dx, 5.2, -3.5), strawColor, Enum.Material.Grass)
			head.Shape = Enum.PartType.Ball
			-- Target plate
			part("DummyBullseye", V(.9, .9, .15), V(dx, 3.5, -2.75), Color3.fromRGB(220, 50, 50), Enum.Material.SmoothPlastic)
		end

		-- Iron Weapon Rack with Practice Swords
		part("WeaponRackBase", V(6, .35, 1.8), V(0, .9, -7.5), woodTrim, Enum.Material.Wood)
		for _, x in {-2.6, 2.6} do
			part("WeaponRackUpright", V(.35, 4.2, 1.6), V(x, 3, -7.5), woodTrim, Enum.Material.Wood)
		end
		part("WeaponRackBeam", V(5.5, .3, .25), V(0, 4.6, -7.5), woodTrim, Enum.Material.Wood)
		for i = -2, 2 do
			local sword = part("PracticeSword_" .. i, V(.2, 3.4, .45), V(i * 1.1, 3.2, -7.5), ironMetal, Enum.Material.Metal)
			sword.CFrame *= CFrame.Angles(0, 0, math.rad(10))
		end

		-- Iron Brazier with Warm Combat Flame
		cylinder("BrazierBase", 1.2, .5, V(0, .9, 6.5), shadow)
		cylinder("BrazierBowl", 1.6, .9, V(0, 2.0, 6.5), ironMetal, Enum.Material.Metal)
		local coal = part("BrazierCoal", V(2.2, .4, 2.2), V(0, 2.4, 6.5), Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
		coal.Shape = Enum.PartType.Ball
		coal.CanCollide = false
		local fire = Instance.new("PointLight")
		fire.Color, fire.Range, fire.Brightness, fire.Parent = Color3.fromRGB(255, 160, 60), 16, 1.2, coal

		local title = part("TrainingSign", V(14, 1.8, .25), V(0, 8.5, 9.5), shadow)
		sign(title, "TRAINING GROUNDS", "MARTIAL DRILL ARENA")
		return
	end

	if id == "GuardPost" then
		local logColor = Color3.fromRGB(92, 68, 44)
		local timberColor = Color3.fromRGB(120, 90, 58)
		local ironColor = Color3.fromRGB(60, 65, 75)
		local emberColor = Color3.fromRGB(255, 105, 30)

		-- Heavy Timber Bastion Base & Watchtower
		part("BastionPlatform", V(24, .9, 18), V(0, .45, 0), timberColor, Enum.Material.WoodPlanks)

		-- Sturdy Log Corner Posts
		for _, x in {-10, 10} do
			for _, z in {-7.5, 7.5} do
				cylinder("BastionLogColumn", .75, 12, V(x, 6.5, z), logColor, Enum.Material.Wood)
			end
		end

		-- Raised Watchtower Parapet & Roof
		part("WatchPlatform", V(22, .6, 16), V(0, 12.3, 0), timberColor, Enum.Material.WoodPlanks)
		for _, side in {-1, 1} do
			block("WatchRoofSlab", V(13, .55, 18), CFrame.new(side * 5.6, 15.6, 0) * CFrame.Angles(0, 0, math.rad(-side * 18)), logColor, Enum.Material.Wood)
		end
		part("WatchRoofPeak", V(1.4, .5, 18.2), V(0, 17.5, 0), ironColor, Enum.Material.Metal)

		-- Defensive Log Palisade Barricade with Sharpened Tips
		for i = 0, 11 do
			local x = -8.8 + (i + 0.5) * 1.6
			local stake = cylinder("PalisadeStake_" .. i, .38, 5.2, V(x, 3.1, 7.8), logColor, Enum.Material.Wood)
			stake.CFrame *= CFrame.Angles(math.rad(12), 0, 0)
		end
		part("PalisadeCrossBeam", V(18.5, .35, .35), V(0, 2.8, 7.6), ironColor, Enum.Material.Metal)

		-- Central Campfire with Stone Ring & Glowing Embers
		for i = 0, 7 do
			local angle = i * math.pi / 4
			part("CampfireStone_" .. i, V(1.1, .75, 1.1), V(math.cos(angle) * 2.2, 1.0, -1.5 + math.sin(angle) * 2.2), stone, Enum.Material.Slate)
		end
		-- Crossed Campfire Logs
		local log1 = cylinder("CampfireLog1", .22, 3.6, V(0, 1.2, -1.5), logColor, Enum.Material.Wood)
		log1.CFrame *= CFrame.Angles(0, math.rad(45), 0)
		local log2 = cylinder("CampfireLog2", .22, 3.6, V(0, 1.2, -1.5), logColor, Enum.Material.Wood)
		log2.CFrame *= CFrame.Angles(0, math.rad(-45), 0)

		local embers = part("GlowingEmbers", V(2.4, .5, 2.4), V(0, 1.4, -1.5), emberColor, Enum.Material.Neon)
		embers.Shape = Enum.PartType.Ball
		embers.CanCollide = false
		local fireLight = Instance.new("PointLight")
		fireLight.Color, fireLight.Range, fireLight.Brightness, fireLight.Parent = Color3.fromRGB(255, 140, 50), 18, 1.4, embers

		-- Signal Beacon Lantern on Front Parapet
		local lanternPost = cylinder("BeaconPole", .25, 4.5, V(0, 14.5, 7.8), ironColor, Enum.Material.Metal)
		local signalLamp = part("SignalBeacon", V(.9, 1.4, .9), V(0, 16.5, 7.8), Color3.fromRGB(255, 210, 120), Enum.Material.Neon)
		signalLamp.CanCollide = false
		local beaconLight = Instance.new("PointLight")
		beaconLight.Color, beaconLight.Range, beaconLight.Brightness, beaconLight.Parent = signalLamp.Color, 20, 1.5, signalLamp

		local title = part("BastionSign", V(16, 2.0, .3), V(0, 11.2, 8.4), shadow)
		sign(title, "OUTSKIRTS GUARD POST", "FRONTIER BASTION")
		return
	end

	-- A round classical sanctuary, with layered cornices, pilasters, and open arched doors.
	local promotion = id == "Promotion"
	local title = promotion and "PROMOTION" or "SYNTHESIS"
	local stoneTone = promotion and Color3.fromRGB(177, 172, 153) or stone
	cylinder("CircularFoundation", 14.7, .6, V(0, .3, 0), shadow)
	cylinder("SanctuaryFloor", 14.2, 2, V(0, 1.6, 0), pale)
	for i = 1, 5 do
		part("BroadEntranceStep_" .. i, V(17.5, .5, 2.4), V(0, .25 + (i - 1) * .5, 21.1 - (i - 1) * 1.65), stoneTone)
	end
	for i = 0, 47 do
		local angle = math.rad(38 + (i + .5) * 284 / 48)
		block("CurvedMasonry", V(1.58, 22.2, 1.15), CFrame.new(math.sin(angle) * 13.5, 13.7, math.cos(angle) * 13.5) * CFrame.Angles(0, angle, 0), stoneTone, Enum.Material.Brick)
	end
	for _, y in {3.4, 12.8, 23.8, 25, 26.4, 27.3} do
		-- The lower two mouldings stop at the entrance instead of crossing it.
		local full = y > 22
		local start, sweep = full and 0 or 38, full and 360 or 284
		for i = 0, 47 do
			local angle = math.rad(start + (i + .5) * sweep / 48)
			local radius = y > 24 and 14.3 or 13.95
			block("RoundCornice", V(full and 1.96 or 1.6, y > 24 and .65 or .28, .65), CFrame.new(math.sin(angle) * radius, y, math.cos(angle) * radius) * CFrame.Angles(0, angle, 0), pale)
		end
	end
	cylinder("RoofSlab", 14.8, .65, V(0, 26, 0), shadow)
	cylinder("RoofCoping", 15, .5, V(0, 27, 0), pale)
	cylinder("RecessedRoof", 13.2, .35, V(0, 27.45, 0), shadow)
	for _, degrees in {38, 90, 142, 194, 246, 298, 322} do
		local a = math.rad(degrees)
		local x, z = math.sin(a) * 14.05, math.cos(a) * 14.05
		cylinder("ColumnFoot", 1, .55, V(x, 3, z), shadow)
		cylinder("ColumnBase", .85, .55, V(x, 3.5, z), pale)
		cylinder("TallStoneColumn", .59, 19, V(x, 13.25, z), pale)
		for _, y in {4, 21.8, 22.45} do cylinder("ColumnCollar", .75, .3, V(x, y, z), bronze) end
		cylinder("ColumnCapital", .95, .7, V(x, 23.1, z), pale)
	end
	local doorZ = 11
	for _, x in {-7.2, 7.2} do
		part("DoorJamb", V(1.1, 12, 2.2), V(x, 8.6, doorZ), pale)
		part("ArchUprightTrim", V(.25, 12, .4), V(x * .925, 8.6, doorZ + 1.2), bronze)
	end
	for i = 0, 25 do
		local x = -7.7 + (i + .5) * 15.4 / 26
		local archY = 14.6 + math.sqrt(math.max(0, 7.7 ^ 2 - x ^ 2))
		part("ArchSpandrel", V(15.4 / 26 + .02, 24.75 - archY, 2), V(x, (24.75 + archY) / 2, doorZ), stoneTone)
	end
	arch("ArchedEntranceOuter", 7.6, 14.6, doorZ + 1, 1.2, pale)
	arch("ArchedEntranceInner", 6.7, 14.6, doorZ + 1.45, .24, bronze)
	-- Sculpted double doors swing outward from the jambs.
	for _, side in {-1, 1} do
		local hinge = CFrame.new(side * 6.6, 2.6, doorZ) * CFrame.Angles(0, math.rad(side * 62), 0)
		local leaf = block("OpenSculptedDoor", V(6.4, 12, .45), hinge * CFrame.new(-side * 3.2, 6, 0), doorColor, Enum.Material.Metal)
		leaf.CanCollide = false
		for _, dx in {0, -side * 6.3} do
			block("DoorEdgeInlay", V(.16, 12, .13), hinge * CFrame.new(dx, 6, .3), bronze, Enum.Material.Metal).CanCollide = false
		end
		for i = 0, 11 do
			local dx = (i + .5) * 6.4 / 12
			local h = math.sqrt(math.max(0, 6.4 ^ 2 - (6.4 - dx) ^ 2))
			block("DoorArchedCrown", V(6.4 / 12 + .01, math.max(h, .05), .45), hinge * CFrame.new(-side * dx, 12 + h / 2, 0), doorColor, Enum.Material.Metal).CanCollide = false
		end
		for _, y in {1, 5, 10} do
			block("DoorCrossInlay", V(6.4, .16, .13), hinge * CFrame.new(-side * 3.2, y, .3), bronze, Enum.Material.Metal).CanCollide = false
		end
		local handle = block("DoorHandle", V(.22, 1.1, .32), hinge * CFrame.new(-side * 5.6, 5.6, .6), accent, Enum.Material.Neon)
		handle.CanCollide = false
	end
	-- Stand the plaque in front of the outermost curved cornice, including its ends.
	for _, x in {-6.4, 6.4} do
		part("NameplateBracket", V(.32, .55, 3.6), V(x, 24.1, 14.3), bronze, Enum.Material.Metal)
	end
	local nameplate = part("CarvedFacilityName", V(17, 3.2, .35), V(0, 24.1, 16.35), shadow)
	nameplate.CanCollide = false
	local plaqueGui = Instance.new("SurfaceGui")
	plaqueGui.Face, plaqueGui.CanvasSize = Enum.NormalId.Back, Vector2.new(1062, 200)
	plaqueGui.AlwaysOnTop, plaqueGui.Parent = false, nameplate
	local function plaqueLine(text: string, y: number, h: number, textSize: number)
		local label = Instance.new("TextLabel")
		label.Size, label.Position = UDim2.new(1, -40, 0, h), UDim2.fromOffset(20, y)
		label.BackgroundTransparency, label.Text, label.Font = 1, text, Enum.Font.GothamBold
		label.TextColor3, label.TextSize, label.Parent = pale, textSize, plaqueGui
	end
	plaqueLine(title, 14, 98, 66)
	plaqueLine(promotion and "HALL OF ASCENSION" or "ESSENCE SANCTUM", 118, 58, 32)
	-- A restrained interior accent identifies each sanctuary without changing its architecture.
	cylinder("RitualDais", 4.5, .7, V(0, 3, -2), shadow)
	cylinder("RitualDaisTrim", 4.1, .18, V(0, 3.45, -2), bronze)
	if promotion then
		for i = 1, 3 do cylinder("AscensionTier", 3.6 - i * .65, .55, V(0, 3.5 + i * .55, -2), pale) end
		local crystal = glow("PromotionCrystal", V(1.4, 3, 1.4), V(0, 7, -2))
		crystal.CFrame *= CFrame.Angles(0, 0, math.rad(35))
	else
		cylinder("EssenceBasin", 2.8, 1.8, V(0, 4.4, -2), doorColor, Enum.Material.Metal)
		cylinder("EssenceRim", 3, .3, V(0, 5.3, -2), bronze, Enum.Material.Metal)
		cylinder("EssencePool", 2.6, .15, V(0, 5.48, -2), accent, Enum.Material.Neon).CanCollide = false
	end
end

return Architecture
