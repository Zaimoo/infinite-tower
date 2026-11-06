-- Inject as a temporary server Script during a Studio Play test. Exercises the
-- actual pickup, banking, relic payout and movement cleanup paths on all floors.
assert(game:GetService("RunService"):IsStudio())
local player=assert(game.Players:GetPlayers()[1],"A test player is required")
local dm,combat,relics=_G.DataManager,_G.CombatSimulation,_G.RelicService
assert(dm and combat and relics,"Runtime must be ready")
local Tower=require(game.ServerScriptService.Core.TowerFloorService)
local Layout=require(game.ReplicatedStorage.Shared.Config.TowerLayout)
local RelicConfig=require(game.ReplicatedStorage.Shared.Config.RelicConfig)
local char=assert(player.Character)
local root=assert(char:FindFirstChild("HumanoidRootPart")) :: BasePart
local hum=assert(char:FindFirstChildOfClass("Humanoid"))
local state=Tower.GetState(player)
local profile=assert(dm.GetProfile(player))
local saved={CFrame=root.CFrame,Anchored=root.Anchored,FloorId=state.FloorId,RoomGeneration=state.RoomGeneration,
	BankArmed=state.BankArmed,SquadAssignment=state.SquadAssignment,Gold=profile.Currencies.Gold,Gems=profile.Currencies.Gems,GuardLevel=profile.Facilities.GuardPost.Level}
local results={Floors=0,GoldBanks=0,GemBanks=0,RelicExtractions=0,IdempotencyChecks=0,Mobs=0}
local ok,err=xpcall(function()
	root.Anchored=true
	-- Keep the squad stationed in its existing room while the test moves only the carrier.
	state.SquadAssignment=state.SquadFloorId
	profile.Facilities.GuardPost.Level=0 -- pause passive gold during exact payout checks
	for id=1,50 do
		local room=Tower.EnsureRoom(id)
		local layout=Layout.Get((id-1)%5+1)
		state.FloorId=id; state.RoomGeneration=room.RoomGeneration
		local field=room.Origin+Vector3.new(0,4,layout.Platforms.Basin.Z+34)
		root.CFrame=CFrame.new(field); state.BankArmed=false
		local relic=relics.SpawnRelic("MANA_GEODE",root.Position-Vector3.new(0,3,0),player.UserId)
		assert(relics.TryPickupRelic(player,relic) and state.BankArmed,"Relic pickup failed "..id)
		local beforeGold,beforeGems=profile.Currencies.Gold,profile.Currencies.Gems
		relics.ExtractInFloorSafeZone(player)
		assert(profile.Currencies.Gold==beforeGold and profile.Currencies.Gems==beforeGems,"Unsafe extraction paid")
		root.CFrame=room.Arrival
		relics.ExtractInFloorSafeZone(player)
		local spec=RelicConfig.MANA_GEODE
		local gold=math.round(spec.Payout.Gold*dm.GetMarketMultiplier(player)*relic.RewardMultiplier)
		local gems=math.round(spec.Payout.Gems*relic.GemMultiplier)
		assert(profile.Currencies.Gold==beforeGold+gold and profile.Currencies.Gems==beforeGems+gems,"Relic payout incorrect "..id)
		assert(char:GetAttribute("CarryingRelic")==nil and not relic.Part.Parent,"Relic was not cleaned up")
		relics.ExtractInFloorSafeZone(player)
		assert(profile.Currencies.Gold==beforeGold+gold and profile.Currencies.Gems==beforeGems+gems,"Duplicate extraction paid")
		results.RelicExtractions+=1; results.IdempotencyChecks+=1
		local _,mobs=combat.DebugEntities()
		local n=0
		for _,mob in mobs do
			if mob.TowerEnemy and mob.FloorId==id then
				n+=1; assert(mob.CampId and (mob.LeashRadius==60 or mob.LeashRadius==95))
				assert(math.abs(mob.HomePosition.Y-room.Origin.Y-mob.LocalPosition.Y)<1,"Mob home is not grounded")
			end
		end
		assert(n==#require(game.ReplicatedStorage.Shared.Config.FirstBiomeCombat).Floors[id],"Runtime population mismatch "..id)
		results.Mobs+=n; results.Floors+=1
		script:SetAttribute("Floors",id)
		task.wait()
	end
end,debug.traceback)
relics.DropCarriedRelic(player)
state.FloorId=saved.FloorId; state.RoomGeneration=saved.RoomGeneration; state.BankArmed=saved.BankArmed
state.SquadAssignment=saved.SquadAssignment
root.CFrame=saved.CFrame; root.Anchored=saved.Anchored
profile.Currencies.Gold=saved.Gold; profile.Currencies.Gems=saved.Gems
profile.Facilities.GuardPost.Level=saved.GuardLevel
dm.SyncProfile(player)
script:SetAttribute("Result",game.HttpService:JSONEncode(results))
if not ok then script:SetAttribute("Error",tostring(err)); warn(err) end
script:SetAttribute("Done",true)
