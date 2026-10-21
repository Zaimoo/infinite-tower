--!strict
-- Cosmetic server-hit feedback. Never computes damage or changes combat state.
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Format=require(game:GetService("ReplicatedStorage").Shared.Config.StatBalance).Format
local Feedback={}
Feedback.MaxNumbers=32
Feedback.Lifetime=.8
function Feedback.new(parent: Instance): any
	local self: any={Parent=parent,Active={},Expires={},Serial=0}
	function self:Step(now: number)
		for i=#self.Active,1,-1 do
			local part=self.Active[i]
			if not part.Parent or now>=(self.Expires[part] or 0) then
				part:Destroy();self.Expires[part]=nil;table.remove(self.Active,i)
			end
		end
	end
	function self:Clear()
		for _,part in self.Active do part:Destroy() end
		table.clear(self.Active);table.clear(self.Expires)
	end
	function self:Hit(position: Vector3,amount: any,overdrive: boolean?,incoming: boolean?): BasePart?
		if typeof(position)~="Vector3" or type(amount)~="number" or amount~=amount or amount<=0 or amount==math.huge then return nil end
		self:Step(os.clock())
		if #self.Active>=Feedback.MaxNumbers then local oldest=table.remove(self.Active,1);self.Expires[oldest]=nil;oldest:Destroy() end
		self.Serial+=1
		local anchor=Instance.new("Part");anchor.Name="DamageNumber";anchor.Size=Vector3.new(.1,.1,.1)
		anchor.Position=position;anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
		anchor:SetAttribute("Damage",amount);anchor.Parent=self.Parent
		local gui=Instance.new("BillboardGui");gui.Name="DamageLabel";gui.Adornee=anchor;gui.Size=UDim2.fromOffset(140,42)
		gui.AlwaysOnTop=true;gui.MaxDistance=150;gui.LightInfluence=0
		local sideways=((self.Serial%5)-2)*.35;gui.StudsOffsetWorldSpace=Vector3.new(sideways,3.6,0);gui.Parent=anchor
		local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Size=UDim2.fromScale(1,1)
		label.Font=Enum.Font.GothamBold;label.TextSize=overdrive and 28 or 23;label.Text="-"..Format(math.max(1,math.round(amount)))
		label.TextColor3=incoming and Color3.fromRGB(255,116,116) or overdrive and Color3.fromRGB(255,207,89) or Color3.fromRGB(243,255,226)
		label.TextStrokeColor3=Color3.fromRGB(25,28,22);label.TextStrokeTransparency=.2;label.Parent=gui
		TweenService:Create(gui,TweenInfo.new(Feedback.Lifetime,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
			{StudsOffsetWorldSpace=Vector3.new(sideways*1.6,6,0)}):Play()
		TweenService:Create(label,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.Out,0,false,.4),
			{TextTransparency=1,TextStrokeTransparency=1}):Play()
		local spark=Instance.new("Part");spark.Name="HitSpark";spark.Shape=Enum.PartType.Ball;spark.Size=Vector3.new(.5,.5,.5)
		spark.Position=position+Vector3.new(0,2,0);spark.Anchored=true;spark.CanCollide=false;spark.CanTouch=false;spark.CanQuery=false
		spark.Material=Enum.Material.Neon;spark.Color=label.TextColor3;spark.Parent=anchor
		TweenService:Create(spark,TweenInfo.new(.18),{Size=Vector3.new(1.5,1.5,1.5),Transparency=1}):Play()
		Debris:AddItem(spark,.2)
		self.Expires[anchor]=os.clock()+Feedback.Lifetime+.05
		Debris:AddItem(anchor,2)
		table.insert(self.Active,anchor);return anchor
	end
	return self
end
return Feedback
