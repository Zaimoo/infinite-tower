-- Studio-only integration probe; restores the test player's currencies and location.
local deadline=os.clock()+20
repeat task.wait(.1) until (_G.CombatSimulation and _G.RelicService and _G.DataManager) or os.clock()>deadline
local dm,combat,relics=_G.DataManager,_G.CombatSimulation,_G.RelicService
assert(dm and combat and relics,"Runtime failed to initialize")
local player=game.Players:GetPlayers()[1]
local profile=dm.GetProfile(player)
local Tower=require(game.ServerScriptService.Core.TowerFloorService)
local Config=require(game.ReplicatedStorage.Shared.Config.TowerFloorConfig)
local First=require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat)
local state=Tower.GetState(player)
local root=player.Character.HumanoidRootPart
local hum=player.Character:FindFirstChildOfClass("Humanoid")
local saved={Gold=profile.Currencies.Gold,Gems=profile.Currencies.Gems,Pos=root.CFrame,Anchored=root.Anchored,Floor=state.FloorId,Generation=state.RoomGeneration,Bank=state.BankArmed,Assignment=state.SquadAssignment}
local results={Mobs=0,Floors=0,KillPayouts=0,DuplicateClaims=0,Relics=0}
local ok,err=xpcall(function()
 root.Anchored=true
 state.SquadAssignment=state.SquadFloorId
 for _,id in {1,5,25,50} do
  local room=Tower.EnsureRoom(id)
  state.FloorId=id;state.RoomGeneration=room.RoomGeneration
  root.CFrame=room.Arrival
  combat.DebugEncounters:SyncRooms(workspace:GetServerTimeNow())
  local heroes,mobs=combat.DebugEntities()
  local count=0
  local victim=nil
  for _,mob in mobs do
   if mob.TowerEnemy and mob.FloorId==id then
    count+=1
    local spawn=First.Floors[id][mob.Slot]
    assert(math.abs(mob.HomePosition.Y-room.Origin.Y-spawn.Y)<.2,"Mob under platform "..id)
    if mob.Role=="REGULAR" and mob.IsAlive then victim=mob end
   end
  end
  assert(count==#First.Floors[id],"Missing runtime mobs")
  for _,target in combat.DebugEncounters:Targets() do
   assert(not target.Player and heroes[target.NetId]==target,"Player included in aggro or area damage")
  end
  local hp=hum.Health
  combat.DebugEncounters.API.Damage({Player=player,Humanoid=hum},100,victim)
  assert(hum.Health==hp,"Commander took monster damage")
  local beforeGold,beforeGems=profile.Currencies.Gold,profile.Currencies.Gems
  local bags=#workspace.PhysicalLoot:GetChildren()
  local reward=Config.GetKillRewards(id,victim.Role)
  combat.DebugKillTowerMob(victim,player)
  assert(profile.Currencies.Gold==beforeGold+math.round(reward.Gold*dm.GetMarketMultiplier(player)),"Wrong direct gold")
  assert(profile.Currencies.Gems==beforeGems+1,"Wrong flat kill gems")
  assert(#workspace.PhysicalLoot:GetChildren()==bags,"Gold bag spawned")
  combat.DebugKillTowerMob(victim,player)
  assert(profile.Currencies.Gems==beforeGems+1,"Duplicate kill payout")
  results.KillPayouts+=1;results.DuplicateClaims+=1
  local pos=room.Origin+Vector3.new(0,4,60)
  root.CFrame=CFrame.new(pos);state.BankArmed=false
  local relic=relics.SpawnRelic("MANA_GEODE",pos-Vector3.new(0,3,0),player.UserId)
  assert(relics.TryPickupRelic(player,relic),"Pickup failed")
  beforeGold,beforeGems=profile.Currencies.Gold,profile.Currencies.Gems
  relics.ExtractInFloorSafeZone(player)
  assert(profile.Currencies.Gems==beforeGems,"Unsafe extraction paid")
  root.CFrame=room.Arrival
  relics.ExtractInFloorSafeZone(player)
  local expected=math.round(100*(1+.05*(id-1)))
  assert(profile.Currencies.Gems==beforeGems+expected,"Wrong scaled relic payout "..id)
  relics.ExtractInFloorSafeZone(player)
  assert(profile.Currencies.Gems==beforeGems+expected,"Duplicate relic payout")
  results.Relics+=1;results.Mobs+=count;results.Floors+=1
  task.wait()
 end
end,debug.traceback)
relics.DropCarriedRelic(player)
profile.Currencies.Gold=saved.Gold;profile.Currencies.Gems=saved.Gems
state.FloorId=saved.Floor;state.RoomGeneration=saved.Generation;state.BankArmed=saved.Bank;state.SquadAssignment=saved.Assignment
root.CFrame=saved.Pos;root.Anchored=saved.Anchored
dm.SyncProfile(player)
script:SetAttribute("Result",game.HttpService:JSONEncode(results))
script:SetAttribute("Error",if ok then "" else tostring(err))
script:SetAttribute("Done",true)
