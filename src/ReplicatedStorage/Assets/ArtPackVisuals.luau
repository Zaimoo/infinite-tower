--!strict
local ReplicatedStorage=game:GetService('ReplicatedStorage')
local A={}
local aliases={starter_iron_vanguard='hero_han',mob_mana_node='node_mana_crystal_cluster',MANA_GEODE='relic_mana_geode',CURSED_URN='relic_cursed_urn',ABYSSAL_CORE='relic_abyssal_core',CALAMITY_HEART='relic_calamity_heart'}
function A.Resolve(meta)
 if type(meta)=='string' then return aliases[meta] or meta end
 if meta.IsHero then return aliases[meta.TemplateId] or meta.TemplateId or 'hero_han' end
 if meta.MobType=='WORLD_BOSS' then return 'world_boss_sovereign' end
 if meta.MobType=='RIFT_BOSS' then return 'boss_rift_warden' end
 return aliases[meta.SpecId] or meta.SpecId
end
function A.Template(id)
 local assets=ReplicatedStorage:FindFirstChild('Assets');if not assets then return nil end
 local resolved=aliases[id] or id
 for _,folder in assets:GetChildren() do
  if folder:IsA('Folder') then local found=folder:FindFirstChild(resolved);if found and found:IsA('Model') then return found end end
 end
 return nil
end
function A.AttachAt(parent,id,ground,scale)
 local template=A.Template(id);if not template then return nil end
 local art=template:Clone();art.Name='ArtPackVisual'
 if scale and scale~=1 then art:ScaleTo(art:GetScale()*scale) end
 for _,p in art:GetDescendants() do
  if p:IsA('BasePart') then p.Anchored=true;p.CanCollide=p:GetAttribute("ArtPackCollider")==true;p.CanTouch=false;p.CanQuery=p.CanCollide;p.CastShadow=not p.CanCollide end
 end
 art:PivotTo(ground);art.Parent=parent;return art
end
function A.Attach(model,meta,root,bodySize)
 local id=A.Resolve(meta);if not id then return nil end
 local art=A.AttachAt(model,id,root.CFrame*CFrame.new(0,-bodySize.Y*.5,0),1)
 if art then
  for _,p in art:GetDescendants() do if p:IsA("BasePart") then p.CanCollide=false;p.CanTouch=false;p.CanQuery=false end end
  model:SetAttribute('ArtPackAssetId',id);root.Transparency=1
  local head=model:FindFirstChild('Head');if head and head:IsA('BasePart') then head.Transparency=1 end
 end
 return art
end
function A.Mesh(id)
 local template=A.Template(id);if not template then return nil end
 local p=template:FindFirstChildWhichIsA('MeshPart',true)
 if not p then return nil end
 local part=p:Clone();part.CFrame=CFrame.identity;part.Anchored=true;part.CanCollide=false;part.Color=Color3.new(1,1,1);part.Material=Enum.Material.SmoothPlastic;return part
end
function A.SetChestState(facility,mode,amount)
 local anchor=facility:FindFirstChild('GemChest');if not anchor or not anchor:IsA('BasePart') then return end
 local id=mode=='FOOLS_GOLD' and 'prop_gem_chest_overflow' or (mode=='VEIL_OF_POVERTY' and 'prop_gem_chest_empty' or (amount>=20 and 'prop_gem_chest_overflow' or 'prop_gem_chest_empty'))
 if facility:GetAttribute('ArtChestState')==id then return end
 local template=A.Template(id);if not template then return end
 local old=facility:FindFirstChild('ArtPackChest');if old then old:Destroy() end
 local art=A.AttachAt(facility,id,anchor.CFrame*CFrame.new(0,-anchor.Size.Y*.5,0),1.4)
 if art then art.Name='ArtPackChest';anchor.Transparency=1;facility:SetAttribute('ArtChestState',id) end
end
function A.Animate(node,dt,time)
 local art=node.Model:FindFirstChild('ArtPackVisual');if not art then return end
 if not node.ArtBones then
  node.ArtBones={}
  for _,b in art:GetDescendants() do if b:IsA('Bone') then node.ArtBones[b.Name]=b end end
 end
 local moving=(node.GoalPos-node.CurrentPos).Magnitude>.15
 local wave=math.sin(time*9);local attack=node.StateEnum==3
 for name,b in node.ArtBones do
  local angle=0
  if moving then
   local sign=name:find('Left') and 1 or -1
   if name:find('UpperLeg') then angle=wave*.45*sign elseif name:find('UpperArm') then angle=-wave*.35*sign end
  elseif attack and name=='RightUpperArm' then angle=-.6-math.sin(time*7)*.5
  elseif name=='UpperTorso' then angle=math.sin(time*2)*.015 end
  local target=CFrame.Angles(angle,0,0)
  b.Transform=b.Transform:Lerp(target,math.clamp(dt*16,0,1))
 end
end
return A
