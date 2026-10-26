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
	end

	function self:Clear()
		for _, part in self.Active do
			part:Destroy()
		end
		table.clear(self.Active)
		table.clear(self.Expires)
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

	return self
end
return Feedback
