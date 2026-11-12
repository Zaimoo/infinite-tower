--!strict
-- Cosmetic server-hit feedback. Never computes damage or changes combat state.
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local RunService=game:GetService("RunService")
local Format=require(game:GetService("ReplicatedStorage").Shared.Config.StatBalance).Format
local Feedback={}
Feedback.MaxNumbers=32
Feedback.Lifetime=.8
-- Damage/heal numbers are pooled: a hit re-dresses a parked anchor + BillboardGui + TextLabel instead of
-- building three new instances every hit. Parked entries sit outside the DataModel.
Feedback.PoolSize=32

type Entry = { Anchor: Part, Gui: BillboardGui, Label: TextLabel, Tweens: { Tween } }

-- Short-lived spark/slash parts: no shadows, touch or queries.
local function fxPart(name: string, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

function Feedback.new(parent: Instance): any
	local self: any = {
		Parent = parent,
		Active = {},
		Expires = {},
		Entries = {} :: { [Part]: Entry },
		Pool = {} :: { Entry },
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
				table.remove(self.Active, i)
				self:Release(part)
			end
		end
	end

	-- Parks a number for reuse. One whose anchor was destroyed from outside (the renderer empties its
	-- folder when the view changes) is dropped instead, as is anything past the pool size.
	function self:Release(part: Part)
		self.Expires[part] = nil
		local entry = self.Entries[part]
		if not entry or part.Parent ~= self.Parent or #self.Pool >= Feedback.PoolSize then
			self.Entries[part] = nil
			part:Destroy()
			return
		end
		for _, tween in entry.Tweens do
			tween:Cancel()
		end
		table.clear(entry.Tweens)
		part.Parent = nil
		table.insert(self.Pool, entry)
	end

	function self:Clear()
		for _, part in self.Active do
			self:Release(part)
		end
		table.clear(self.Active)
		table.clear(self.Expires)
		self.ScreenShakeMag = 0
	end

	-- An anchor/gui/label ready for a new number, from the pool when one is free. Callers set the text
	-- and style; everything a caller might leave unset is reset here.
	function self:Acquire(anchorName: string, guiName: string, position: Vector3, size: UDim2, maxDistance: number, offset: Vector3): Entry
		if #self.Active >= Feedback.MaxNumbers then
			self:Release(table.remove(self.Active, 1))
		end
		local entry: Entry? = table.remove(self.Pool)
		if entry then
			for _, child in entry.Anchor:GetChildren() do
				if child ~= entry.Gui then
					child:Destroy() -- sparks still fading from its last use
				end
			end
			entry.Anchor:SetAttribute("Damage", nil)
			entry.Anchor:SetAttribute("Heal", nil)
		else
			local anchor = Instance.new("Part")
			anchor.Size = Vector3.new(0.1, 0.1, 0.1)
			anchor.Transparency = 1
			anchor.Anchored = true
			anchor.CanCollide = false
			anchor.CanTouch = false
			anchor.CanQuery = false
			anchor.CastShadow = false
			local gui = Instance.new("BillboardGui")
			gui.AlwaysOnTop = true
			gui.LightInfluence = 0
			gui.Adornee = anchor
			gui.Parent = anchor
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Parent = gui
			entry = { Anchor = anchor, Gui = gui, Label = label, Tweens = {} }
			self.Entries[anchor] = entry
		end
		local e = entry :: Entry
		e.Anchor.Name = anchorName
		e.Anchor.Position = position
		e.Gui.Name = guiName
		e.Gui.Size = size
		e.Gui.MaxDistance = maxDistance
		e.Gui.StudsOffsetWorldSpace = offset
		e.Label.Font = Enum.Font.GothamBold
		e.Label.TextTransparency = 0
		e.Anchor.Parent = self.Parent
		return e
	end

	-- Tweens on pooled instances are tracked so a recycled number never inherits a running one.
	function self:Tween(entry: Entry, instance: Instance, info: TweenInfo, goal: { [string]: any })
		local tween = TweenService:Create(instance, info, goal)
		table.insert(entry.Tweens, tween)
		tween:Play()
	end

	function self:Hit(position: Vector3, amount: any, hitType: any, incoming: boolean?, archetype: string?): BasePart?
		if typeof(position) ~= "Vector3" or type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
			return nil
		end
		self:Step(os.clock())
		self.Serial += 1

		local isCritOrSpecial = hitType == "CRITICAL" or hitType == "SPECIAL" or hitType == true
		local isWeak = hitType == "WEAK" or hitType == "RESISTED"
		local isIncoming = incoming == true

		local sideways = ((self.Serial % 5) - 2) * 0.35
		local entry = self:Acquire("DamageNumber", "DamageLabel", position,
			if isCritOrSpecial then UDim2.fromOffset(130, 36) else UDim2.fromOffset(140, 42), 160, Vector3.new(sideways, 3.6, 0))
		local anchor, gui, label = entry.Anchor, entry.Gui, entry.Label
		anchor:SetAttribute("Damage", amount)

		if isIncoming then
			-- 1. Player Hero Damage (incoming): Crimson font with warning flash
			label.TextSize = 25
			label.Text = "-" .. Format(math.max(1, math.round(amount)))
			label.TextColor3 = Color3.fromRGB(245, 45, 55)
			label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
			label.TextStrokeTransparency = 0.05
			self:Tween(entry, label, TweenInfo.new(0.08, Enum.EasingStyle.Linear), {
				TextStrokeColor3 = Color3.fromRGB(100, 10, 10),
				TextStrokeTransparency = 0.2,
			})
			self:Tween(entry, gui, TweenInfo.new(Feedback.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffsetWorldSpace = Vector3.new(sideways * 1.5, 5.5, 0),
			})
			self:Tween(entry, label, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.4), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})

		elseif isCritOrSpecial then
			-- 2. Critical Hit / Special: Yellow/Orange bold font, 1.25x scale with elastic pop
			label.TextSize = 18
			label.Text = "-" .. Format(math.max(1, math.round(amount))) .. "!"
			label.TextColor3 = Color3.fromRGB(255, 175, 30)
			label.TextStrokeColor3 = Color3.fromRGB(55, 18, 5)
			label.TextStrokeTransparency = 0.15
			self:Tween(entry, gui, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(175, 52),
				StudsOffsetWorldSpace = Vector3.new(sideways * 1.8, 6.2, 0),
			})
			self:Tween(entry, label, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				TextSize = 30,
			})
			self:Tween(entry, label, TweenInfo.new(0.4, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.45), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
			self:ScreenShake(0.20, 0.20)

		elseif isWeak then
			-- 3. Weak / Resisted: Gray font
			label.TextSize = 19
			label.Font = Enum.Font.GothamMedium
			label.Text = "-" .. Format(math.max(1, math.round(amount)))
			label.TextColor3 = Color3.fromRGB(160, 160, 165)
			label.TextStrokeColor3 = Color3.fromRGB(35, 35, 40)
			label.TextStrokeTransparency = 0.3
			self:Tween(entry, gui, TweenInfo.new(Feedback.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffsetWorldSpace = Vector3.new(sideways * 1.2, 4.8, 0),
			})
			self:Tween(entry, label, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.35), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})

		else
			-- 4. Standard Hit: White font with slight float-up and fade
			label.TextSize = 23
			label.Text = "-" .. Format(math.max(1, math.round(amount)))
			label.TextColor3 = Color3.fromRGB(250, 250, 250)
			label.TextStrokeColor3 = Color3.fromRGB(25, 28, 22)
			label.TextStrokeTransparency = 0.25
			self:Tween(entry, gui, TweenInfo.new(Feedback.Lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				StudsOffsetWorldSpace = Vector3.new(sideways * 1.4, 5.2, 0),
			})
			self:Tween(entry, label, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false, 0.4), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			})
		end

		-- Distinct elemental bursts for Scholar and Berserker archetypes + Directional slash
		local sparkPos = position + Vector3.new(0, 1.8, 0)
		if archetype == "Scholar" then
			-- Arcane / Lightning burst (Cyan & Violet)
			local arcaneSpark = fxPart("ArcaneBurst", anchor)
			arcaneSpark.Shape = Enum.PartType.Ball
			arcaneSpark.Size = Vector3.new(0.6, 0.6, 0.6)
			arcaneSpark.Position = sparkPos
			arcaneSpark.Material = Enum.Material.Neon
			arcaneSpark.Color = Color3.fromRGB(90, 240, 255)
			TweenService:Create(arcaneSpark, TweenInfo.new(0.20), { Size = Vector3.new(2.4, 2.4, 2.4), Transparency = 1 }):Play()
			Debris:AddItem(arcaneSpark, 0.22)

			local shockRing = fxPart("ArcaneRing", anchor)
			shockRing.Shape = Enum.PartType.Cylinder
			shockRing.Size = Vector3.new(0.12, 1.2, 1.2)
			shockRing.CFrame = CFrame.new(sparkPos) * CFrame.Angles(0, 0, math.rad(90))
			shockRing.Color = Color3.fromRGB(195, 75, 255)
			shockRing.Material = Enum.Material.Neon
			TweenService:Create(shockRing, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.12, 3.8, 3.8), Transparency = 1 }):Play()
			Debris:AddItem(shockRing, 0.26)

		elseif archetype == "Berserker" then
			-- Seismic / Earth burst (Amber & Slate fragments)
			local seismicSpark = fxPart("SeismicBurst", anchor)
			seismicSpark.Shape = Enum.PartType.Ball
			seismicSpark.Size = Vector3.new(0.7, 0.7, 0.7)
			seismicSpark.Position = sparkPos
			seismicSpark.Material = Enum.Material.Neon
			seismicSpark.Color = Color3.fromRGB(255, 145, 35)
			TweenService:Create(seismicSpark, TweenInfo.new(0.22), { Size = Vector3.new(2.6, 2.6, 2.6), Transparency = 1 }):Play()
			Debris:AddItem(seismicSpark, 0.24)

			local dustShock = fxPart("SeismicShock", anchor)
			dustShock.Shape = Enum.PartType.Cylinder
			dustShock.Size = Vector3.new(0.15, 1.4, 1.4)
			dustShock.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			dustShock.Color = Color3.fromRGB(140, 110, 85)
			dustShock.Material = Enum.Material.Slate
			TweenService:Create(dustShock, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, 4.2, 4.2), Transparency = 1 }):Play()
			Debris:AddItem(dustShock, 0.30)

		else
			-- Standard hit spark & directional slash
			local spark = fxPart("HitSpark", anchor)
			spark.Shape = Enum.PartType.Ball
			spark.Size = Vector3.new(0.5, 0.5, 0.5)
			spark.Position = sparkPos
			spark.Material = Enum.Material.Neon
			spark.Color = label.TextColor3
			TweenService:Create(spark, TweenInfo.new(0.18), { Size = Vector3.new(1.6, 1.6, 1.6), Transparency = 1 }):Play()
			Debris:AddItem(spark, 0.20)

			-- Directional slash along swing plane
			local slash = fxPart("DirectionalSlash", anchor)
			slash.Size = Vector3.new(0.08, 0.35, 1.8)
			local slashYaw = (self.Serial % 8) * (math.pi / 4)
			slash.CFrame = CFrame.new(sparkPos) * CFrame.Angles(math.rad(25), slashYaw, math.rad(35))
			slash.Color = if isCritOrSpecial then Color3.fromRGB(255, 205, 80) else Color3.fromRGB(255, 255, 255)
			slash.Material = Enum.Material.Neon
			TweenService:Create(slash, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(0.08, 0.7, 3.2),
				Transparency = 1,
			}):Play()
			Debris:AddItem(slash, 0.18)
		end

		self.Expires[anchor] = os.clock() + Feedback.Lifetime + 0.05
		table.insert(self.Active, anchor)
		return anchor
	end

	function self:Special(position: Vector3, amount: any, hitType: any, incoming: boolean?, archetype: string?): BasePart?
		return self:Hit(position, amount, "SPECIAL", incoming, archetype)
	end
	function self:Skill(position: Vector3,amount: any,skillName: string?): BasePart?
		if typeof(position)~="Vector3" or type(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge then return nil end
		self:Step(os.clock())
		self.Serial+=1
		local sideways=((self.Serial%5)-2)*.45
		local entry=self:Acquire("DamageNumber_Skill","DamageLabel",position,UDim2.fromOffset(170,50),180,Vector3.new(sideways,4.2,0))
		local anchor,gui,label=entry.Anchor,entry.Gui,entry.Label
		anchor:SetAttribute("Damage",amount)
		label.TextSize=32
		label.Text="-"..Format(math.max(1,math.round(amount))).."!"
		label.TextColor3=Color3.fromRGB(255,215,60) -- Radiant Skill Gold
		label.TextStrokeColor3=Color3.fromRGB(80,20,10);label.TextStrokeTransparency=.1
		self:Tween(entry,gui,TweenInfo.new(Feedback.Lifetime+.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
			{StudsOffsetWorldSpace=Vector3.new(sideways*2.0,7.2,0)})
		self:Tween(entry,label,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,.45),
			{TextTransparency=1,TextStrokeTransparency=1})
		local spark=fxPart("HitSpark_Skill",anchor);spark.Shape=Enum.PartType.Ball;spark.Size=Vector3.new(1.2,1.2,1.2)
		spark.Position=position+Vector3.new(0,2,0)
		spark.Material=Enum.Material.Neon;spark.Color=label.TextColor3
		TweenService:Create(spark,TweenInfo.new(.3),{Size=Vector3.new(3.2,3.2,3.2),Transparency=1}):Play()
		Debris:AddItem(spark,.35)
		self.Expires[anchor]=os.clock()+Feedback.Lifetime+.15
		table.insert(self.Active,anchor);return anchor
	end
	function self:Heal(position: Vector3,amount: any): BasePart?
		if typeof(position)~="Vector3" or type(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge then return nil end
		self:Step(os.clock())
		self.Serial+=1
		local sideways=((self.Serial%5)-2)*.35
		local entry=self:Acquire("HealNumber","HealLabel",position,UDim2.fromOffset(140,42),150,Vector3.new(sideways,3.6,0))
		local anchor,gui,label=entry.Anchor,entry.Gui,entry.Label
		anchor:SetAttribute("Heal",amount)
		label.TextSize=25
		label.Text="+"..Format(math.max(1,math.round(amount)))
		label.TextColor3=Color3.fromRGB(80,255,120) -- Restorative Green
		label.TextStrokeColor3=Color3.fromRGB(15,40,20);label.TextStrokeTransparency=.2
		self:Tween(entry,gui,TweenInfo.new(Feedback.Lifetime,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
			{StudsOffsetWorldSpace=Vector3.new(sideways*1.4,5.8,0)})
		self:Tween(entry,label,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,.4),
			{TextTransparency=1,TextStrokeTransparency=1})
		local spark=fxPart("HealSpark",anchor);spark.Shape=Enum.PartType.Ball;spark.Size=Vector3.new(.6,.6,.6)
		spark.Position=position+Vector3.new(0,2,0)
		spark.Material=Enum.Material.Neon;spark.Color=label.TextColor3
		TweenService:Create(spark,TweenInfo.new(.22),{Size=Vector3.new(1.8,1.8,1.8),Transparency=1}):Play()
		Debris:AddItem(spark,.25)
		self.Expires[anchor]=os.clock()+Feedback.Lifetime+.05
		table.insert(self.Active,anchor);return anchor
	end

	return self
end
return Feedback
