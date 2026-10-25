--!strict
-- Cosmetic server-hit feedback. Never computes damage or changes combat state.
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local RunService=game:GetService("RunService")
local Format=require(game:GetService("ReplicatedStorage").Shared.Config.StatBalance).Format
local Feedback={}
Feedback.MaxNumbers=32
Feedback.Lifetime=.8
function Feedback.new(parent: Instance): any
	local self: any = {
		Parent = parent,
		Active = {},
		Expires = {},
		ActiveFlights = {},
		Serial = 0,
		ScreenShakeMag = 0,
		ScreenShakeDuration = 0.20,
		ScreenShakeStart = 0,
	}

	function self:ScreenShake(magnitude: number?, duration: number?)
		local mag = math.clamp(magnitude or 0.25, 0.15, 0.40)
		local dur = duration or 0.20
		self.ScreenShakeMag = mag
		self.ScreenShakeDuration = dur
		self.ScreenShakeStart = os.clock()
	end

	function self:Step(now: number)
		if self.ScreenShakeMag > 0 then
			local elapsed = now - self.ScreenShakeStart
			if elapsed < self.ScreenShakeDuration then
				local decay = 1.0 - (elapsed / self.ScreenShakeDuration)
				local currentMag = self.ScreenShakeMag * decay
				local cam = Workspace.CurrentCamera
				if cam then
					local rx = (math.random() - 0.5) * 2 * currentMag
					local ry = (math.random() - 0.5) * 2 * currentMag
					cam.CFrame = cam.CFrame * CFrame.new(rx, ry, 0)
				end
			else
				self.ScreenShakeMag = 0
			end
		end

		for i = #self.Active, 1, -1 do
			local part = self.Active[i]
			if not part.Parent or now >= (self.Expires[part] or 0) then
				part:Destroy()
				self.Expires[part] = nil
				table.remove(self.Active, i)
			end
		end
		for i = #self.ActiveFlights, 1, -1 do
			local flight = self.ActiveFlights[i]
			if flight(now) then
				table.remove(self.ActiveFlights, i)
			end
		end
	end

	function self:Clear()
		for _, part in self.Active do
			part:Destroy()
		end
		table.clear(self.Active)
		table.clear(self.Expires)
		table.clear(self.ActiveFlights)
		self.ScreenShakeMag = 0
	end

	function self:Hit(position: Vector3, amount: any, hitType: any, incoming: boolean?, archetype: string?): BasePart?
		if typeof(position) ~= "Vector3" or type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
			return nil
		end
		self:Step(os.clock())
		if #self.Active >= Feedback.MaxNumbers then
			local oldest = table.remove(self.Active, 1)
			self.Expires[oldest] = nil
			oldest:Destroy()
		end
		self.Serial += 1

		local isCritOrSpecial = hitType == "CRITICAL" or hitType == "SPECIAL" or hitType == true
		local isWeak = hitType == "WEAK" or hitType == "RESISTED"
		local isIncoming = incoming == true

		local anchor = Instance.new("Part")
		anchor.Name = "DamageNumber"
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Position = position
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanTouch = false
		anchor.CanQuery = false
		anchor:SetAttribute("Damage", amount)
		anchor.Parent = self.Parent

		local gui = Instance.new("BillboardGui")
		gui.Name = "DamageLabel"
		gui.Adornee = anchor
		gui.Size = if isCritOrSpecial then UDim2.fromOffset(130, 36) else UDim2.fromOffset(140, 42)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 160
		gui.LightInfluence = 0
		local sideways = ((self.Serial % 5) - 2) * 0.35
		gui.StudsOffsetWorldSpace = Vector3.new(sideways, 3.6, 0)
		gui.Parent = anchor

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold

		if isIncoming then
			-- 1. Player Hero Damage (incoming): Crimson font with warning flash
			label.TextSize = 25
			label.Text = "-" .. Format(math.max(1, math.round(amount)))
			label.TextColor3 = Color3.fromRGB(245, 45, 55)
			label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
			label.TextStrokeTransparency = 0.05
			TweenService:Create(label, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {
				TextStrokeColor3 = Color3.fromRGB(100, 10, 10),
				TextStrokeTransparency = 0.2,
			}):Play()
			TweenService:Create(gui, TweenInfo.new(Feedback.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffsetWorldSpace = Vector3.new(sideways * 1.5, 5.5, 0),
			}):Play()
			TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.4), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()

		elseif isCritOrSpecial then
			-- 2. Critical Hit / Special: Yellow/Orange bold font, 1.25x scale with elastic pop
			label.TextSize = 18
			label.Text = "-" .. Format(math.max(1, math.round(amount))) .. "!"
			label.TextColor3 = Color3.fromRGB(255, 175, 30)
			label.TextStrokeColor3 = Color3.fromRGB(55, 18, 5)
			label.TextStrokeTransparency = 0.15
			TweenService:Create(gui, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(175, 52),
				StudsOffsetWorldSpace = Vector3.new(sideways * 1.8, 6.2, 0),
			}):Play()
			TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				TextSize = 30,
			}):Play()
			TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.45), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
			self:ScreenShake(0.20, 0.20)

		elseif isWeak then
			-- 3. Weak / Resisted: Gray font
			label.TextSize = 19
			label.Font = Enum.Font.GothamMedium
			label.Text = "-" .. Format(math.max(1, math.round(amount)))
			label.TextColor3 = Color3.fromRGB(160, 160, 165)
			label.TextStrokeColor3 = Color3.fromRGB(35, 35, 40)
			label.TextStrokeTransparency = 0.3
			TweenService:Create(gui, TweenInfo.new(Feedback.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffsetWorldSpace = Vector3.new(sideways * 1.2, 4.8, 0),
			}):Play()
			TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.35), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()

		else
			-- 4. Standard Hit: White font with slight float-up and fade
			label.TextSize = 23
			label.Text = "-" .. Format(math.max(1, math.round(amount)))
			label.TextColor3 = Color3.fromRGB(250, 250, 250)
			label.TextStrokeColor3 = Color3.fromRGB(25, 28, 22)
			label.TextStrokeTransparency = 0.25
			TweenService:Create(gui, TweenInfo.new(Feedback.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffsetWorldSpace = Vector3.new(sideways * 1.4, 5.2, 0),
			}):Play()
			TweenService:Create(label, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.4), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		end
		label.Parent = gui

		-- Distinct elemental bursts for Scholar and Miner archetypes + Directional slash
		local sparkPos = position + Vector3.new(0, 1.8, 0)
		if archetype == "Scholar" then
			-- Arcane / Lightning burst (Cyan & Violet)
			local arcaneSpark = Instance.new("Part")
			arcaneSpark.Name = "ArcaneBurst"
			arcaneSpark.Shape = Enum.PartType.Ball
			arcaneSpark.Size = Vector3.new(0.6, 0.6, 0.6)
			arcaneSpark.Position = sparkPos
			arcaneSpark.Anchored = true
			arcaneSpark.CanCollide = false
			arcaneSpark.Material = Enum.Material.Neon
			arcaneSpark.Color = Color3.fromRGB(90, 240, 255)
			arcaneSpark.Parent = anchor
			TweenService:Create(arcaneSpark, TweenInfo.new(0.20), { Size = Vector3.new(2.4, 2.4, 2.4), Transparency = 1 }):Play()
			Debris:AddItem(arcaneSpark, 0.22)

			local shockRing = Instance.new("Part")
			shockRing.Name = "ArcaneRing"
			shockRing.Shape = Enum.PartType.Cylinder
			shockRing.Size = Vector3.new(0.12, 1.2, 1.2)
			shockRing.CFrame = CFrame.new(sparkPos) * CFrame.Angles(0, 0, math.rad(90))
			shockRing.Color = Color3.fromRGB(195, 75, 255)
			shockRing.Material = Enum.Material.Neon
			shockRing.Anchored = true
			shockRing.CanCollide = false
			shockRing.Parent = anchor
			TweenService:Create(shockRing, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.12, 3.8, 3.8), Transparency = 1 }):Play()
			Debris:AddItem(shockRing, 0.26)

		elseif archetype == "Miner" then
			-- Seismic / Earth burst (Amber & Slate fragments)
			local seismicSpark = Instance.new("Part")
			seismicSpark.Name = "SeismicBurst"
			seismicSpark.Shape = Enum.PartType.Ball
			seismicSpark.Size = Vector3.new(0.7, 0.7, 0.7)
			seismicSpark.Position = sparkPos
			seismicSpark.Anchored = true
			seismicSpark.CanCollide = false
			seismicSpark.Material = Enum.Material.Neon
			seismicSpark.Color = Color3.fromRGB(255, 145, 35)
			seismicSpark.Parent = anchor
			TweenService:Create(seismicSpark, TweenInfo.new(0.22), { Size = Vector3.new(2.6, 2.6, 2.6), Transparency = 1 }):Play()
			Debris:AddItem(seismicSpark, 0.24)

			local dustShock = Instance.new("Part")
			dustShock.Name = "SeismicShock"
			dustShock.Shape = Enum.PartType.Cylinder
			dustShock.Size = Vector3.new(0.15, 1.4, 1.4)
			dustShock.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			dustShock.Color = Color3.fromRGB(140, 110, 85)
			dustShock.Material = Enum.Material.Slate
			dustShock.Anchored = true
			dustShock.CanCollide = false
			dustShock.Parent = anchor
			TweenService:Create(dustShock, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, 4.2, 4.2), Transparency = 1 }):Play()
			Debris:AddItem(dustShock, 0.30)

		else
			-- Standard hit spark & directional slash
			local spark = Instance.new("Part")
			spark.Name = "HitSpark"
			spark.Shape = Enum.PartType.Ball
			spark.Size = Vector3.new(0.5, 0.5, 0.5)
			spark.Position = sparkPos
			spark.Anchored = true
			spark.CanCollide = false
			spark.Material = Enum.Material.Neon
			spark.Color = label.TextColor3
			spark.Parent = anchor
			TweenService:Create(spark, TweenInfo.new(0.18), { Size = Vector3.new(1.6, 1.6, 1.6), Transparency = 1 }):Play()
			Debris:AddItem(spark, 0.20)

			-- Directional slash along swing plane
			local slash = Instance.new("Part")
			slash.Name = "DirectionalSlash"
			slash.Size = Vector3.new(0.08, 0.35, 1.8)
			local slashYaw = (self.Serial % 8) * (math.pi / 4)
			slash.CFrame = CFrame.new(sparkPos) * CFrame.Angles(math.rad(25), slashYaw, math.rad(35))
			slash.Color = if isCritOrSpecial then Color3.fromRGB(255, 205, 80) else Color3.fromRGB(255, 255, 255)
			slash.Material = Enum.Material.Neon
			slash.Anchored = true
			slash.CanCollide = false
			slash.Parent = anchor
			TweenService:Create(slash, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.08, 0.7, 3.2),
				Transparency = 1,
			}):Play()
			Debris:AddItem(slash, 0.18)
		end

		self.Expires[anchor] = os.clock() + Feedback.Lifetime + 0.05
		Debris:AddItem(anchor, 2.0)
		table.insert(self.Active, anchor)
		return anchor
	end

	function self:Special(position: Vector3, amount: any, hitType: any, incoming: boolean?, archetype: string?): BasePart?
		return self:Hit(position, amount, "SPECIAL", incoming, archetype)
	end
	function self:Skill(position: Vector3,amount: any,skillName: string?): BasePart?
		if typeof(position)~="Vector3" or type(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge then return nil end
		self:Step(os.clock())
		if #self.Active>=Feedback.MaxNumbers then local oldest=table.remove(self.Active,1);self.Expires[oldest]=nil;oldest:Destroy() end
		self.Serial+=1
		local anchor=Instance.new("Part");anchor.Name="DamageNumber_Skill";anchor.Size=Vector3.new(.1,.1,.1)
		anchor.Position=position;anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
		anchor:SetAttribute("Damage",amount);anchor.Parent=self.Parent
		local gui=Instance.new("BillboardGui");gui.Name="DamageLabel";gui.Adornee=anchor;gui.Size=UDim2.fromOffset(170,50)
		gui.AlwaysOnTop=true;gui.MaxDistance=180;gui.LightInfluence=0
		local sideways=((self.Serial%5)-2)*.45;gui.StudsOffsetWorldSpace=Vector3.new(sideways,4.2,0);gui.Parent=anchor
		local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
		label.Font=Enum.Font.GothamBold;label.TextSize=32
		label.Text="-"..Format(math.max(1,math.round(amount))).."!"
		label.TextColor3=Color3.fromRGB(255,215,60) -- Radiant Skill Gold
		label.TextStrokeColor3=Color3.fromRGB(80,20,10);label.TextStrokeTransparency=.1;label.Parent=gui
		TweenService:Create(gui,TweenInfo.new(Feedback.Lifetime+.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
			{StudsOffsetWorldSpace=Vector3.new(sideways*2.0,7.2,0)}):Play()
		TweenService:Create(label,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,.45),
			{TextTransparency=1,TextStrokeTransparency=1}):Play()
		local spark=Instance.new("Part");spark.Name="HitSpark_Skill";spark.Shape=Enum.PartType.Ball;spark.Size=Vector3.new(1.2,1.2,1.2)
		spark.Position=position+Vector3.new(0,2,0);spark.Anchored=true;spark.CanCollide=false;spark.CanTouch=false;spark.CanQuery=false
		spark.Material=Enum.Material.Neon;spark.Color=label.TextColor3;spark.Parent=anchor
		TweenService:Create(spark,TweenInfo.new(.3),{Size=Vector3.new(3.2,3.2,3.2),Transparency=1}):Play()
		Debris:AddItem(spark,.35)
		self.Expires[anchor]=os.clock()+Feedback.Lifetime+.15
		Debris:AddItem(anchor,2)
		table.insert(self.Active,anchor);return anchor
	end
	function self:Heal(position: Vector3,amount: any): BasePart?
		if typeof(position)~="Vector3" or type(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge then return nil end
		self:Step(os.clock())
		if #self.Active>=Feedback.MaxNumbers then local oldest=table.remove(self.Active,1);self.Expires[oldest]=nil;oldest:Destroy() end
		self.Serial+=1
		local anchor=Instance.new("Part");anchor.Name="HealNumber";anchor.Size=Vector3.new(.1,.1,.1)
		anchor.Position=position;anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
		anchor:SetAttribute("Heal",amount);anchor.Parent=self.Parent
		local gui=Instance.new("BillboardGui");gui.Name="HealLabel";gui.Adornee=anchor;gui.Size=UDim2.fromOffset(140,42)
		gui.AlwaysOnTop=true;gui.MaxDistance=150;gui.LightInfluence=0
		local sideways=((self.Serial%5)-2)*.35;gui.StudsOffsetWorldSpace=Vector3.new(sideways,3.6,0);gui.Parent=anchor
		local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
		label.Font=Enum.Font.GothamBold;label.TextSize=25
		label.Text="+"..Format(math.max(1,math.round(amount)))
		label.TextColor3=Color3.fromRGB(80,255,120) -- Restorative Green
		label.TextStrokeColor3=Color3.fromRGB(15,40,20);label.TextStrokeTransparency=.2;label.Parent=gui
		TweenService:Create(gui,TweenInfo.new(Feedback.Lifetime,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
			{StudsOffsetWorldSpace=Vector3.new(sideways*1.4,5.8,0)}):Play()
		TweenService:Create(label,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,.4),
			{TextTransparency=1,TextStrokeTransparency=1}):Play()
		local spark=Instance.new("Part");spark.Name="HealSpark";spark.Shape=Enum.PartType.Ball;spark.Size=Vector3.new(.6,.6,.6)
		spark.Position=position+Vector3.new(0,2,0);spark.Anchored=true;spark.CanCollide=false;spark.CanTouch=false;spark.CanQuery=false
		spark.Material=Enum.Material.Neon;spark.Color=label.TextColor3;spark.Parent=anchor
		TweenService:Create(spark,TweenInfo.new(.22),{Size=Vector3.new(1.8,1.8,1.8),Transparency=1}):Play()
		Debris:AddItem(spark,.25)
		self.Expires[anchor]=os.clock()+Feedback.Lifetime+.05
		Debris:AddItem(anchor,2)
		table.insert(self.Active,anchor);return anchor
	end

	-- ========================================================================
	-- PROJECTILE ARROW VISUALS (Cosmetic-only; damage is server-authoritative)
	-- Tiers: BASIC (Wind-Step Shot), SPECIAL (Piercing Gale Volley), SKILL (Sylphid Arrow Storm)
	-- ========================================================================
	local WIND_CYAN = Color3.fromRGB(120, 235, 255)
	local GALE_EMERALD = Color3.fromRGB(90, 255, 170)
	local SHAFT_WOOD = Color3.fromRGB(150, 105, 65)
	local HEAD_SLATE = Color3.fromRGB(95, 92, 100)
	local FLETCH_WHITE = Color3.fromRGB(235, 240, 235)

	local function makeProjPart(name: string, size: Vector3, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		return p
	end

	local function attachProjPart(arrowModel: Model, root: BasePart, part: BasePart, offset: CFrame)
		part.CFrame = root.CFrame * offset
		part.Parent = arrowModel
	end

	-- Builds a 3D projectile arrow Model oriented along local -Z (tip at -Z).
	local function buildProjectileArrow(parent: Instance, scale: number, glow: Color3, trailWidth: number): Model
		local arrowModel = Instance.new("Model")
		arrowModel.Name = "ProjectileArrowModel"

		local shaft = makeProjPart("ProjectileArrow", Vector3.new(0.11 * scale, 0.11 * scale, 2.7 * scale), SHAFT_WOOD, Enum.Material.Wood)
		shaft.CFrame = CFrame.identity
		shaft.Parent = arrowModel
		arrowModel.PrimaryPart = shaft

		for _, dirY in ipairs({ 1, -1 }) do
			local blade = Instance.new("WedgePart")
			blade.Name = if dirY == 1 then "ArrowHeadTop" else "ArrowHeadBot"
			blade.Size = Vector3.new(0.10 * scale, 0.15 * scale, 0.68 * scale)
			blade.Color = HEAD_SLATE
			blade.Material = Enum.Material.Metal
			blade.Anchored = true
			blade.CanCollide = false
			blade.CanTouch = false
			blade.CanQuery = false
			blade.Massless = true
			blade.CastShadow = false
			local roll = if dirY == 1 then 0 else math.pi
			attachProjPart(arrowModel, shaft, blade, CFrame.new(0, dirY * 0.075 * scale, -1.52 * scale) * CFrame.Angles(0, 0, roll))
		end

		for i = 0, 2 do
			local fletch = makeProjPart("ArrowFletch_" .. i, Vector3.new(0.035 * scale, 0.38 * scale, 0.68 * scale), FLETCH_WHITE)
			attachProjPart(arrowModel, shaft, fletch, CFrame.new(0, 0, 1.02 * scale) * CFrame.Angles(0, 0, math.rad(i * 120)))
		end

		local aura = makeProjPart("WindAura", Vector3.new(2.3 * scale, 0.22 * scale, 0.22 * scale), glow, Enum.Material.Neon, Enum.PartType.Cylinder)
		aura.Transparency = 0.68
		attachProjPart(arrowModel, shaft, aura, CFrame.Angles(0, math.rad(90), 0))

		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, trailWidth * 0.5, 1.2 * scale)
		a0.Parent = shaft
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -trailWidth * 0.5, 1.2 * scale)
		a1.Parent = shaft

		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Lifetime = 0.28
		trail.Color = ColorSequence.new(glow)
		trail.LightEmission = 1
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1.0),
		})
		trail.Parent = shaft

		arrowModel.Parent = parent
		Debris:AddItem(arrowModel, 3.0)
		return arrowModel
	end

	local function spawnRingBurst(parent: Instance, pos: Vector3, color: Color3, startDia: number, endDia: number, duration: number, flat: boolean?)
		local ring = Instance.new("Part")
		ring.Name = "WindRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.18, startDia, startDia)
		ring.CFrame = CFrame.new(pos) * (if flat then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
		ring.Color = color
		ring.Material = Enum.Material.Neon
		ring.Transparency = 0.25
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanTouch = false
		ring.CanQuery = false
		ring.CastShadow = false
		ring.Parent = parent
		TweenService:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.18, endDia, endDia),
			Transparency = 1,
		}):Play()
		Debris:AddItem(ring, duration + 0.1)
	end

	local function spawnImpactBurst(parent: Instance, pos: Vector3, color: Color3, size: number)
		local spark = Instance.new("Part")
		spark.Name = "ArrowImpact"
		spark.Shape = Enum.PartType.Ball
		spark.Size = Vector3.one * (size * 0.4)
		spark.Position = pos
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.Material = Enum.Material.Neon
		spark.Color = color
		spark.Parent = parent
		TweenService:Create(spark, TweenInfo.new(0.25), {
			Size = Vector3.one * size,
			Transparency = 1,
		}):Play()
		Debris:AddItem(spark, 0.3)
		spawnRingBurst(parent, pos, color, size * 0.6, size * 2.2, 0.3, false)
	end

	local function destroyArrowParts(arrowModel: Model)
		if arrowModel and arrowModel.Parent then
			arrowModel:Destroy()
		end
	end

	local function flyArrow(arrowModel: Model, p0: Vector3, p1: Vector3, speed: number, arc: number, onTick: ((Vector3) -> ())?, onDone: (() -> ())?)
		local total = (p1 - p0).Magnitude
		local duration = math.max(0.08, total / speed)
		local started = os.clock()
		local finished = false
		local function pointAt(t: number): Vector3
			return p0:Lerp(p1, t) + Vector3.new(0, math.sin(t * math.pi) * arc, 0)
		end
		local function stepFlight(now: number): boolean
			if finished or not arrowModel.Parent then
				finished = true
				return true
			end
			local t = math.clamp((now - started) / duration, 0, 1)
			local pos = pointAt(t)
			local nextPos = pointAt(math.min(1, t + 0.02))
			if (nextPos - pos).Magnitude > 0.001 then
				arrowModel:PivotTo(CFrame.lookAt(pos, nextPos))
			else
				arrowModel:PivotTo(CFrame.new(pos))
			end
			if onTick then
				onTick(pos)
			end
			if t >= 1 then
				finished = true
				if onDone then
					onDone()
				end
				return true
			end
			return false
		end
		table.insert(self.ActiveFlights, stepFlight)
	end

	function self:SpawnArrowProjectile(originPos: Vector3, targetPos: Vector3, attackTier: string, attackerModel: Model?)
		if typeof(originPos) ~= "Vector3" or typeof(targetPos) ~= "Vector3" then
			return
		end
		local parent = self.Parent
		local startPos = originPos + Vector3.new(0, 3.2, 0)
		if attackerModel then
			local eq = attackerModel:FindFirstChild("EquippedWeapon", true)
			local handle = eq and eq:FindFirstChild("Handle", true) :: BasePart?
			if handle then
				startPos = handle.Position
			end
		end
		local aim = targetPos + Vector3.new(0, 2.8, 0)
		local flatDelta = Vector3.new(aim.X - startPos.X, 0, aim.Z - startPos.Z)
		local dir = if (aim - startPos).Magnitude > 0.01 then (aim - startPos).Unit else Vector3.new(0, 0, -1)

		local container = Instance.new("Model")
		container.Name = "ArrowProjectileVFX_" .. tostring(attackTier)
		container.Parent = parent
		Debris:AddItem(container, 4.0)

		if attackTier == "SKILL" then
			-- Sky-flare arrow streaks upward, opens a wind sigil above target, and rains 14 gale arrows
			local apex = startPos + Vector3.new(flatDelta.X * 0.25, 22, flatDelta.Z * 0.25)
			local flare = buildProjectileArrow(container, 1.35, GALE_EMERALD, 0.9)
			flare:PivotTo(CFrame.lookAt(startPos, apex))
			local sigilPos = targetPos + Vector3.new(0, 14, 0)
			spawnRingBurst(container, sigilPos, GALE_EMERALD, 5, 20, 0.65, true)
			spawnRingBurst(container, sigilPos, WIND_CYAN, 2.5, 13, 0.65, true)
			local rng = Random.new(math.floor(os.clock() * 1000))
			for i = 1, 8 do
				local angle = (i / 8) * math.pi * 2
				local radius = 3.5 + (i % 3) * 1.8
				local land = targetPos + Vector3.new(math.cos(angle) * radius, 0.3, math.sin(angle) * radius)
				local rainStart = land + Vector3.new(rng:NextNumber(-1.5, 1.5), 14, rng:NextNumber(-1.5, 1.5))
				local rainArrow = buildProjectileArrow(container, 0.95, if i % 2 == 0 then GALE_EMERALD else WIND_CYAN, 0.5)
				rainArrow:PivotTo(CFrame.lookAt(rainStart, land))
				flyArrow(rainArrow, rainStart, land, 55, 0, nil, function()
					destroyArrowParts(rainArrow)
					spawnRingBurst(container, land + Vector3.new(0, 0.1, 0), WIND_CYAN, 1, 5, 0.35, true)
				end)
			end
			flyArrow(flare, startPos, apex, 65, 0, nil, function()
				spawnImpactBurst(container, apex, GALE_EMERALD, 5)
				destroyArrowParts(flare)
			end)
		elseif attackTier == "SPECIAL" then
			-- Piercing Gale Volley: 3-arrow emerald gale fan + spiraling wind rings
			local through = aim + dir * 10
			local rightVec = dir:Cross(Vector3.yAxis)
			if rightVec.Magnitude < 0.01 then
				rightVec = Vector3.xAxis
			else
				rightVec = rightVec.Unit
			end
			for idx = -1, 1 do
				local isCenter = (idx == 0)
				local arrowScale = if isCenter then 1.40 else 1.05
				local arrowColor = if isCenter then GALE_EMERALD else WIND_CYAN
				local sideOffset = rightVec * (idx * 1.35)
				local pStart = startPos + sideOffset * 0.35
				local pEnd = through + sideOffset * 1.8
				local bolt = buildProjectileArrow(container, arrowScale, arrowColor, if isCenter then 1.1 else 0.7)
				bolt:PivotTo(CFrame.lookAt(pStart, pEnd))
				local lastRing = 0
				flyArrow(bolt, pStart, pEnd, 85, 0.35, function(pos)
					if not isCenter then
						return
					end
					local now = os.clock()
					if now - lastRing > 0.04 then
						lastRing = now
						local ring = Instance.new("Part")
						ring.Name = "GaleRing"
						ring.Shape = Enum.PartType.Cylinder
						ring.Size = Vector3.new(0.15, 2.2, 2.2)
						ring.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0)
						ring.Color = GALE_EMERALD
						ring.Material = Enum.Material.Neon
						ring.Transparency = 0.30
						ring.Anchored = true
						ring.CanCollide = false
						ring.CanTouch = false
						ring.CanQuery = false
						ring.CastShadow = false
						ring.Parent = container
						TweenService:Create(ring, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
							Size = Vector3.new(0.15, 3.8, 3.8),
							Transparency = 1,
						}):Play()
						Debris:AddItem(ring, 0.35)
					end
				end, function()
					destroyArrowParts(bolt)
				end)
			end
		else
			-- BASIC: Wind-Step Shot, sleek high-speed arrow with cyan wind trail
			local arrow = buildProjectileArrow(container, 1.15, WIND_CYAN, 0.65)
			arrow:PivotTo(CFrame.lookAt(startPos, aim))
			local arc = math.clamp((aim - startPos).Magnitude * 0.035, 0.2, 1.5)
			flyArrow(arrow, startPos, aim, 75, arc, nil, function()
				destroyArrowParts(arrow)
				spawnImpactBurst(container, aim, WIND_CYAN, 2.0)
			end)
		end
	end

	return self
end
return Feedback
