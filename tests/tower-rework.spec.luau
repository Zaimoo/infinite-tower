local Layout=require(nodes["ReplicatedStorage.Shared.Config.TowerLayout"])
local Floors=require(nodes["ReplicatedStorage.Shared.Config.TowerFloorConfig"])
local Mobs=require(nodes["ReplicatedStorage.Shared.Config.MobCatalog"])
local Combat=require(nodes["ReplicatedStorage.Shared.Config.FirstBiomeCombat"])
local Rules=require(nodes["ReplicatedStorage.Shared.Util.TowerSanctuaryRules"])
local passed=0
local function test(name,fn) fn(); passed+=1; print("PASS "..name) end
test("Canonical biome progression and all five room envelopes",function()
	local order={"verdant_ruins","fungal_hollow","ashen_dunes","frozen_citadel","infernal_foundry","thunder_highlands","corrupted_grove","sunken_sanctuary","astral_archives","abyssal_throne"}
	local widths,depths,heights={380,420,460,510,560},{420,470,520,580,640},{130,140,155,170,190}
	for b,id in order do
		assert(Mobs.Biomes[b].Id==id)
		for i=1,5 do
			assert(Floors.Get((b-1)*5+i).BiomeId==id)
			local room=Layout.Get(i)
			assert(room.Width==widths[i] and room.Depth==depths[i] and room.Height==heights[i])
		end
	end
end)
test("Every terrace connects to sanctuary with broad slopes at most fifteen degrees",function()
	for i=1,5 do
		local room=Layout.Get(i)
		local visited={Sanctuary=true}
		for _=1,10 do
			for _,link in room.Links do
				local length=math.sqrt((link.BX-link.AX)^2+(link.BZ-link.AZ)^2)
				assert(length>0 and link.Width>=24 and math.abs(link.BY-link.AY)/length<=math.tan(math.rad(15)))
				if visited[link.From] or visited[link.To] then visited[link.From]=true; visited[link.To]=true end
			end
		end
		for id,p in room.Platforms do
			assert(visited[id],"Unreachable terrace "..id)
			assert(math.abs(p.X)+p.Width/2<=room.Width/2 and math.abs(p.Z)+p.Depth/2<=room.Depth/2)
		end
	end
end)
test("All fifty floors have supported isolated camps and matching encounter manifests",function()
	local totals={11,15,19,24,29}
	for id=1,50 do
		local floor=Floors.Get(id)
		local room=Layout.Get(floor.IndexInBiome)
		local camps,counts={},{}
		for _,camp in room.Camps do camps["CAMP_"..camp.Id]=camp end
		local placements=Combat.Floors[id]
		assert(#placements==totals[floor.IndexInBiome] and #room.Camps==floor.IndexInBiome+2)
		local bosses,elites=0,0
		for _,p in placements do
			local camp=assert(camps[p.CampId])
			local terrace=room.Platforms[camp.Platform]
			assert(p.Y==terrace.Y and math.abs(p.X-terrace.X)+4<terrace.Width/2 and math.abs(p.Z-terrace.Z)+4<terrace.Depth/2)
			local s=room.Sanctuary
			assert(math.abs(p.X)>s.Width/2 or math.abs(p.Z-s.Z)>s.Depth/2)
			assert(p.LeashRadius==(camp.Boss and 95 or 60))
			counts[p.EnemyId]=(counts[p.EnemyId] or 0)+1
			local role=Mobs.Get(p.EnemyId).Role
			if role=="BOSS" then bosses+=1 elseif role=="ELITE" then elites+=1 end
		end
		assert(bosses==(floor.IndexInBiome==5 and 1 or 0))
		assert(elites==({1,1,2,3,2})[floor.IndexInBiome])
		for _,e in floor.Encounters do assert(counts[e.EnemyId]==e.Count); counts[e.EnemyId]=nil end
		assert(next(counts)==nil)
	end
end)
test("Floor sanctuary extraction rejects unarmed stale expired transitioning or unsafe cargo",function()
	for id=1,50 do
		local location={FloorId=id,RoomGeneration=7,BankArmed=true}
		local cargo={FloorId=id,RoomGeneration=7,DespawnAt=100}
		local safe={CanBankCargo=true}
		assert(Rules.CanExtractFloor(location,cargo,safe,false,50))
		assert(not Rules.CanExtractFloor(location,cargo,{},false,50))
		assert(not Rules.CanExtractFloor(location,cargo,safe,true,50))
		assert(not Rules.CanExtractFloor(location,cargo,safe,false,100))
		location.BankArmed=false; assert(not Rules.CanExtractFloor(location,cargo,safe,false,50)); location.BankArmed=true
		cargo.RoomGeneration=6; assert(not Rules.CanExtractFloor(location,cargo,safe,false,50)); cargo.RoomGeneration=7
		cargo.FloorId=id+1; assert(not Rules.CanExtractFloor(location,cargo,safe,false,50))
	end
	local hub={FloorId=0,RoomGeneration=1,BankArmed=true}
	local cargo={FloorId=0,RoomGeneration=1,DespawnTime=100}
	assert(Rules.CanBank(hub,cargo,{CanBankCargo=true},false,50))
	assert(not Rules.CanExtractFloor(hub,cargo,{CanBankCargo=true},false,50))
	local carriedCargo={FloorId=0,RoomGeneration=1,DespawnTime=math.huge}
	assert(Rules.CanBank(hub,carriedCargo,{CanBankCargo=true},false,100000))
end)
test("Kill gems stay flat while gold and relic odds/value rise on every floor",function()
 for _,role in {"REGULAR","ELITE","BOSS"} do
  local previous=nil
  for floor=1,50 do
   local reward=Floors.GetKillRewards(floor,role)
   assert(reward.Gems==1 and reward.RelicChance>0 and reward.RelicChance<1)
   if previous then
    assert(reward.Gold>previous.Gold and reward.RelicChance>previous.RelicChance)
    assert(reward.RelicMultiplier>previous.RelicMultiplier)
   end
   assert(Floors.RollRelic(floor,role,0,0)=="ABYSSAL_CORE")
   assert(Floors.RollRelic(floor,role,0,.99)=="MANA_GEODE")
   assert(Floors.RollRelic(floor,role,reward.RelicChance,0)==nil)
   previous=reward
  end
 end
end)
print(string.format("Tower rework tests: %d passed",passed))
