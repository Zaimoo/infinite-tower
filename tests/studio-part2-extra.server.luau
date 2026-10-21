-- Temporary probes for existing elite AoE isolation and live-drop room retention.
local T=require(game.ServerScriptService.Core.TowerFloorService)
local p=game.Players:GetPlayers()[1]
local heroes,mobs=_G.CombatSimulation.DebugEntities()
local hero=heroes[next(heroes)]
local saved={Position=hero.Position,FloorId=hero.FloorId,RoomGeneration=hero.RoomGeneration,HP=hero.CurrentHP}
local results={}
local function record(name,fn)
	local ok,err=pcall(fn);table.insert(results,{Name=name,Passed=ok,Error=not ok and tostring(err) or nil})
end
record("Existing elite AoE cannot damage a different FloorId even with identical physical coordinates",function()
	local first,fifth=T.EnsureRoom(1),T.EnsureRoom(5)
	local pos=fifth.Origin
	hero.FloorId=1;hero.RoomGeneration=first.RoomGeneration;hero.Position=pos
	mobs[3000000001]={NetId=3000000001,EntityGeneration=1,FloorId=5,RoomGeneration=fifth.RoomGeneration,SpecId="elite_corrupted_stalker",
		DisplayName="ISOLATION FIXTURE",MobType="RING2_ELITE",IsAlive=true,Position=pos,HomePosition=pos,ATK=20,CurrentHP=10,MaxHP=10,
		AoERadius=30,NextAoECastTime=1,AoEDetonateTime=os.clock()-1,Phase=1,Yaw=0,PunishWindowUntil=0,RingIndex=2}
	task.wait(.35)
	assert(hero.CurrentHP==saved.HP)
end)
mobs[3000000001]=nil;hero.Position=saved.Position;hero.FloorId=saved.FloorId;hero.RoomGeneration=saved.RoomGeneration
_G.CombatSimulation.RebuildPlayerSquad(p)
record("Live dropped loot pins its room until the physical item is removed",function()
	local room=T.EnsureRoom(4)
	local loot=_G.CombatSimulation.SpawnPhysicalLoot("GOLD",1,room.Arrival.Position,p)
	room.EmptySince=os.clock()-61;task.wait(1.2)
	assert(T.GetRoom(4)==room and loot.Part.Parent)
	loot.Part:Destroy();room.EmptySince=os.clock()-61;task.wait(1.2)
	assert(T.GetRoom(4)==nil)
end)
game.ReplicatedStorage:SetAttribute("Part2ExtraTests",game.HttpService:JSONEncode(results))
script:Destroy()
