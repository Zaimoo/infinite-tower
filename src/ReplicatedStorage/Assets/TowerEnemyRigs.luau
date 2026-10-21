--!strict
-- Editable native model source. Each limb is articulated by a named Motor6D.
-- These are original part-built rigs, not animated versions of the legacy meshes.
local Config=require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat)
local R={}
local stone=Color3.fromRGB(73,88,85)
local lightStone=Color3.fromRGB(116,137,120)
local bark=Color3.fromRGB(65,48,37)
local moss=Color3.fromRGB(65,111,54)
local gold=Color3.fromRGB(188,151,69)
local glow=Color3.fromRGB(153,240,125)
local function part(parent,name,size,color,shape)
	local p=Instance.new("Part");p.Name=name;p.Size=size;p.Color=color;p.Material=Enum.Material.SmoothPlastic
	if shape then p.Shape=shape end
	p.CanCollide=false;p.CanTouch=false;p.CanQuery=true;p.Massless=true;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
	p.Parent=parent;return p
end
function R.Build(model: Model,root: BasePart,enemyId: string): any
	local spec=assert(Config.Get(enemyId),"Missing tower enemy rig: "..enemyId)
	local folder=Instance.new("Model");folder.Name="TowerEnemyArt";folder.Parent=model
	local rig: any={Joints={},Parts={},Root=root,Model=folder,Spec=spec,EnemyId=enemyId,Distance=0}
	local function limb(name,parent,size,offset,color,shape)
		local p=part(folder,name,size,color,shape);p.CFrame=parent.CFrame*offset
		p:SetAttribute("NetId",model:GetAttribute("NetId"));table.insert(rig.Parts,p)
		local pivot=CFrame.identity
		if name=="ArmL" or name=="ArmR" or name=="ForearmL" or name=="ForearmR" or name=="LegL" or name=="LegR" or name=="KneeL" or name=="KneeR" then
			pivot=CFrame.new(0,size.Y/2,0)
		elseif name=="Head" then pivot=CFrame.new(0,-size.Y/2,0)
		elseif name:match("^Leg%-1") then pivot=CFrame.new(size.X/2,0,0)
		elseif name:match("^Leg1_") then pivot=CFrame.new(-size.X/2,0,0) end
		local bind=offset*pivot
		local j=Instance.new("Motor6D");j.Name=name;j.Part0=parent;j.Part1=p;j.C0=bind;j.C1=pivot;j.Parent=parent
		rig.Joints[name]={Motor=j,Bind=bind};return p
	end
	local function detail(name,parent,size,offset,color,shape,material)
		local p=part(folder,name,size,color,shape);p.CFrame=parent.CFrame*offset
		if material then p.Material=material end
		p:SetAttribute("NetId",model:GetAttribute("NetId"));table.insert(rig.Parts,p)
		local w=Instance.new("WeldConstraint");w.Part0=parent;w.Part1=p;w.Parent=p;return p
	end
	if enemyId=="mob_moss_crawler" then
		local body=limb("Body",root,Vector3.new(3.2,1.5,4.4),CFrame.new(0,.35,0),bark,Enum.PartType.Ball)
		for i=1,3 do
			local shell=detail("OverlappingCarapace",body,Vector3.new(3.35,1.05,1.7),CFrame.new(0,.6,(i-2)*1.25)*CFrame.Angles(math.rad((i-2)*8),0,0),i%2==0 and moss or lightStone,Enum.PartType.Ball)
			detail("ShellRidge",shell,Vector3.new(.22,.26,1.3),CFrame.new(0,.5,0),gold)
		end
		local head=limb("Head",body,Vector3.new(2.2,1.3,1.5),CFrame.new(0,-.1,-2.7),stone,Enum.PartType.Ball)
		for _,side in {-1,1} do
			detail("AmberEye",head,Vector3.new(.4,.45,.32),CFrame.new(side*.75,.28,-.65),Color3.fromRGB(255,197,88),Enum.PartType.Ball,Enum.Material.Neon)
			local jaw=limb(side==-1 and "JawL" or "JawR",head,Vector3.new(.45,.45,1.65),CFrame.new(side*.7,-.45,-.95)*CFrame.Angles(0,side*-.28,0),gold)
			detail("Fang",jaw,Vector3.new(.25,.65,.3),CFrame.new(0,-.2,-.65)*CFrame.Angles(.5,0,0),lightStone)
			for i=1,3 do
				local hip=limb("Leg"..side.."_"..i,body,Vector3.new(1.65,.34,.42),CFrame.new(side*1.75,-.35,(i-2)*1.5)*CFrame.Angles(0,side*(i-2)*-.3,side*-.25),bark)
				local shin=limb("Knee"..side.."_"..i,hip,Vector3.new(.32,1.15,.35),CFrame.new(side*.8,-.65,0)*CFrame.Angles(0,0,side*.28),lightStone)
				detail("RootToe",shin,Vector3.new(.45,.22,.8),CFrame.new(0,-.55,-.2),gold)
			end
		end
	else
		local boss=spec.Role=="BOSS";local scale=boss and 2 or 1
		local function v(x,y,z) return Vector3.new(x,y,z)*scale end
		local function cf(x,y,z) return CFrame.new(v(x,y,z)) end
		local torso=limb("Body",root,v(3.1,3.4,1.8),cf(0,.45,0),boss and stone or bark)
		detail("ChestSlab",torso,v(2.7,2.1,.6),cf(0,.25,-1.05)*CFrame.Angles(.08,0,0),lightStone)
		local core=detail("Heartstone",torso,v(.8,1.25,.3),cf(0,.4,-1.4)*CFrame.Angles(0,0,.65),glow,nil,Enum.Material.Neon)
		local l=Instance.new("PointLight");l.Range=boss and 16 or 8;l.Brightness=.45;l.Color=glow;l.Parent=core
		local head=limb("Head",torso,v(1.8,1.6,1.6),cf(0,2.55,0),lightStone)
		detail("Brow",head,v(2,.5,1.85),cf(0,.35,-.06)*CFrame.Angles(0,0,.03),stone)
		for _,side in {-1,1} do
			detail("Eye",head,v(.32,.22,.2),cf(side*.48,.05,-.85),glow,nil,Enum.Material.Neon)
			local crown=detail("BranchCrown",head,v(.32,1.85,.36),cf(side*1.1,1.1,.15)*CFrame.Angles(0,0,-side*.5),bark)
			detail("CrownLeaf",crown,v(.7,.22,.7),cf(0,.75,0)*CFrame.Angles(0,.4,0),moss)
			local arm=limb(side==-1 and "ArmL" or "ArmR",torso,v(1.25,2.1,1.25),cf(side*2.15,.25,0)*CFrame.Angles(0,0,side*.1),boss and stone or bark)
			detail("MossShoulder",arm,v(1.8,.8,1.7),cf(0,.9,0)*CFrame.Angles(.12,0,side*.12),moss,Enum.PartType.Ball)
			local fore=limb(side==-1 and "ForearmL" or "ForearmR",arm,v(1.45,1.9,1.5),cf(0,-1.8,-.12),boss and lightStone or bark)
			for finger=1,3 do detail("RootFinger",fore,v(.27,.9,.35),cf((finger-2)*.43,-1.1,-.4)*CFrame.Angles(.25,0,0),gold) end
			local thigh=limb(side==-1 and "LegL" or "LegR",torso,v(1.1,1.6,1.25),cf(side*.88,-2.35,0),stone)
			local shin=limb(side==-1 and "KneeL" or "KneeR",thigh,v(1,1.3,1.15),cf(0,-1.35,0),lightStone)
			detail("RootFoot",shin,v(1.4,.6,2.1),cf(0,-.72,-.4),bark)
			for i=1,3 do detail("GrowingMoss",torso,v(.7,.28,.7),cf(side*(1.1+i*.1),.9-i*.5,.3)*CFrame.Angles(.3,0,.4),moss,Enum.PartType.Ball) end
		end
		if boss then
			for i=1,5 do
				local a=(i-3)*.3
				detail("AncientCrown",head,v(.32,1.7-math.abs(i-3)*.22,.55),cf((i-3)*.48,1.35,.1)*CFrame.Angles(0,0,-a),gold)
			end
			detail("BackMonolith",torso,v(2.2,4.1,1.2),cf(0,.85,1.25)*CFrame.Angles(.12,0,0),stone)
		end
	end
	model:SetAttribute("TowerEnemyId",enemyId);model:SetAttribute("ArtPackAssetId",enemyId)
	folder:SetAttribute("Source","TowerEnemyRigs.luau");folder:SetAttribute("RigFamily",spec.RigFamily)
	return rig
end
return R
