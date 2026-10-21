-- Manual verification only: run as a temporary ServerScriptService Script in Studio Play.
-- Not mapped into the place; restores session profiles and encounter actors after the fixture.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer() and game:GetService("RunService"):IsRunning(), "Studio Play server only")
local Http=game:GetService("HttpService")
local RS=game:GetService("ReplicatedStorage")
local Storage=game:GetService("ServerStorage")
local S=require(RS.Shared.Util.StatFormulas)
local B=require(RS.Shared.Config.StatBalance)
local T=require(game.ServerScriptService.Core.TowerFloorService)
local result={}
local p=game.Players:GetPlayers()[1]
local dm=_G.DataManager;local combat=_G.CombatSimulation
local profile=dm.GetProfile(p)
local saved={Heroes=profile.Heroes,Artifacts=profile.Artifacts,Order=profile.DeployedSquadOrder,Currencies=table.clone(profile.Currencies)}
local ts=T.GetState(p);local savedState=table.clone(ts)
local mobBackups={}
local ok,err=pcall(function()
 local room=T.EnsureRoom(5)
 task.wait(1)
 local ledger=T.Encounters[5];assert(ledger and ledger.Slots,"Floor 5 not spawned")
 for _,m in ledger.Slots do mobBackups[m]=table.clone(m) end
 result.SpawnStats={}
 for _,m in ledger.Slots do
  local expected=B.GetFloorStats(5,m.Role);assert(m.MaxHP==expected.MaxHP and m.ATK==expected.ATK)
  table.insert(result.SpawnStats,{Role=m.Role,HP=m.MaxHP,ATK=m.ATK,Gold=m.GoldReward})
 end
 profile.Heroes={};profile.Artifacts={};profile.DeployedSquadOrder={};profile.Currencies={Gold=300000,Gems=1000}
 for i,id in {"hero_han","hero_jenna","hero_aaron","hero_velkist","hero_eolka"} do
  local uuid,h=dm.CreateHeroFromSeed(id);h.Stars=5;h.Level=50;h.QualityScalar=1;h.Assignment="SQUAD_SLOT_"..i;h.CurrentStamina=100;h.ComaUntilTimestamp=0
  local weaponId=({"art_iron_broadsword","art_crystal_greatbow","art_iron_broadsword","art_rusty_daggers","art_ruby_staff"})[i]
  local aid,a=dm.CreateArtifact(weaponId,7,7);assert(require(RS.Shared.Config.ArtifactCatalog).CanHeroEquip(h.Archetype,a.Type));a.EquippedHeroUUID=uuid
  h.EquippedArtifactUUID=aid;profile.Heroes[uuid]=h;profile.Artifacts[aid]=a;table.insert(profile.DeployedSquadOrder,uuid)
 end
 local uid=profile.DeployedSquadOrder[1];local h=profile.Heroes[uid];local aid=h.EquippedArtifactUUID;local a=profile.Artifacts[aid]
 a.Star=6
 local donors={}
 for i=1,6 do local did,donor=dm.CreateArtifact("art_iron_broadsword",1,1);profile.Artifacts[did]=donor;table.insert(donors,did) end
 local success,msg,newStar=dm.UpgradeArtifact(p,aid,donors)
 assert(success,msg);assert(newStar==7 and a.Rarity==7 and profile.Currencies.Gold==50000 and profile.Currencies.Gems==500)
 assert(not dm.UpgradeArtifact(p,aid,donors),"Replay accepted")
 result.Promotion={Star=newStar,Rarity=a.Rarity,Gold=profile.Currencies.Gold,Gems=profile.Currencies.Gems}
 ts.SquadFloorId=5;ts.SquadRoomGeneration=room.RoomGeneration;ts.SquadAssignment=5
 local boss
 for _,m in ledger.Slots do
  if m.Role=="BOSS" then boss=m else m.IsAlive=false;m.RespawnAt=workspace:GetServerTimeNow()+99999 end
 end
 assert(boss)
 boss.MaxHP=B.GetFloorStats(50,"BOSS").MaxHP;boss.CurrentHP=boss.MaxHP;boss.ATK=0
 boss.Position=room.Origin+Vector3.new(0,0,12);boss.HomePosition=boss.Position;boss.BornAt=workspace:GetServerTimeNow()+99999
 boss.Action=nil;boss.State="IDLE";boss.IsAlive=true
 combat.RebuildPlayerSquad(p);combat.RefreshPlayerHeroStats(p)
 task.wait(5)
 combat.RefreshPlayerHeroStats(p)
 local hp=boss.CurrentHP;local started=os.clock()
 task.wait(12)
 local elapsed=os.clock()-started
 result.LiveDPS=(hp-boss.CurrentHP)/elapsed
 result.HPRemoved=hp-boss.CurrentHP;result.Seconds=elapsed
 result.ScheduledDPS=0
 for _,hero in profile.Heroes do result.ScheduledDPS+=S.GetCombatSnapshot(hero,S.GetEquippedArtifact(profile,hero)).DPS end
 assert(result.LiveDPS>1e9,"Live fixture did not reach one billion DPS")
 assert(result.LiveDPS<result.ScheduledDPS*1.3,"Fixture exceeds plausible timing tolerance")
 result.RecurringWeaponRefresh=true
end)
profile.Heroes=saved.Heroes;profile.Artifacts=saved.Artifacts;profile.DeployedSquadOrder=saved.Order;profile.Currencies=saved.Currencies
for key in pairs(ts) do if savedState[key]==nil then ts[key]=nil end end
for key,v in savedState do ts[key]=v end
for m,before in mobBackups do for key in pairs(m) do if before[key]==nil then m[key]=nil end end;for key,v in before do m[key]=v end end
pcall(combat.RebuildPlayerSquad,p)
result.Success=ok;result.Error=err
Storage:SetAttribute("StatVerification",Http:JSONEncode(result))
print("[StatVerification] "..Http:JSONEncode(result))
