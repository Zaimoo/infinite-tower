--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Authority = require(game:GetService("ServerScriptService").Core.ForgeTransactions)
local Catalog = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)
local count = 0

local function test(name: string, run: () -> ())
	run(); count += 1; print("PASS forge authority: " .. name)
end
local function setup()
	local now, serial = 1000, 0
	local api = Authority.new({ Clock = function() return now end, GenerateToken = function() serial += 1; return "undo-" .. serial end })
	local function bow(id: string, owner: string?, locked: boolean?)
		return { UUID = id, TemplateId = "art_crystal_greatbow", DisplayName = "Crystal Greatbow", Type = "BOW", Rarity = 4, Star = 1, Locked = locked or false, EquippedHeroUUID = owner }
	end
	local profile = {
		Currencies = { Gold = 100000, Gems = 600 },
		Heroes = {
			h1 = {UUID="h1",TemplateId="hero_jenna",DisplayName="Jenna",Archetype="Marksman",Stars=1,Level=1,QualityScalar=1,EquippedArtifactUUID="old"},
			h2 = {UUID="h2",TemplateId="hero_jenna",DisplayName="Jenna",Archetype="Marksman",Stars=1,Level=1,QualityScalar=1,EquippedArtifactUUID="held"},
			h3 = {UUID="h3",TemplateId="hero_valeria",DisplayName="Valeria",Archetype="Healer",Stars=1,Level=1},
		},
		Artifacts = {old=bow("old","h1"),held=bow("held","h2"),target=bow("target"),donor=bow("donor"),locked=bow("locked",nil,true)},
	}
	local requestSerial = 0
	local function request(kind: string, fields: any?): any
		requestSerial += 1
		local command: any = {RequestId="request-" .. requestSerial,Kind=kind,ExpectedRevision=api.Snapshot(profile).Revision}
		for key,value in fields or {} do command[key]=value end
		return command
	end
	return api, profile, request, function(seconds: number) now += seconds end
end

test("server snapshot projects only forge data and isolates receipts from profile mutations",function()
	local api,p = setup()
	p.Secret="do not replicate"
	local s=api.Snapshot(p)
	assert(s.Secret==nil and s.Heroes.h1.UUID=="h1" and s.Artifacts.target.UUID=="target")
	p.Artifacts.target.Star=3
	assert(s.Artifacts.target.Star==1)
end)
test("currency ticks keep preview revision stable while every commit checks live funds",function()
	local api,p,request=setup()
	local before=api.Snapshot(p).Revision
	local command=request("UPGRADE",{ArtifactId="target",MaterialIds={"donor"}})
	p.Currencies.Gold=499
	assert(api.Snapshot(p).Revision==before)
	local result=api.Execute(p,command,true)
	assert(not result.Ok and p.Currencies.Gold==499 and p.Artifacts.donor and p.Artifacts.target.Star==1)
end)
test("equipped or locked materials cannot be consumed; locked equipped targets can improve",function()
	local api,p,request=setup()
	for _,id in {"held","locked"} do
		local result=api.Execute(p,request("UPGRADE",{ArtifactId="target",MaterialIds={id}}),true)
		assert(not result.Ok and p.Artifacts[id] and p.Currencies.Gold==100000)
	end
	p.Artifacts.held.Locked=true
	local result=api.Execute(p,request("UPGRADE",{ArtifactId="held",MaterialIds={"donor"}}),true)
	assert(result.Ok and p.Artifacts.held.Star==2 and p.Artifacts.held.Locked and p.Artifacts.held.EquippedHeroUUID=="h2")
	assert(p.Heroes.h2.EquippedArtifactUUID=="held")
end)
test("promotion receipts deduplicate same-ID submissions and do not grant undo",function()
	local api,p,request=setup()
	local command=request("UPGRADE",{ArtifactId="target",MaterialIds={"donor"}})
	local first,committed=api.Execute(p,command,true)
	local repeated,repeatedCommit=api.Execute(p,command,true)
	assert(first.Ok and repeated.Ok and p.Currencies.Gold==99500 and p.Artifacts.target.Star==2)
	assert(committed==true and repeatedCommit==false) -- reward/sync hooks must not run twice
	assert(first.UndoToken==nil and first.Snapshot.Revision==repeated.Snapshot.Revision)
	first.Snapshot.Artifacts.target.Star=7
	assert(api.Reconcile(p,command.RequestId).Snapshot.Artifacts.target.Star==2)
end)
test("cross-type artifact donor of same rarity and stars promotes target",function()
	local api,p,request=setup()
	p.Artifacts.dagger={UUID="dagger",TemplateId="art_viper_kris",DisplayName="Viper Kris",Type="DAGGERS",Rarity=4,Star=1,Locked=false}
	local command=request("UPGRADE",{ArtifactId="target",MaterialIds={"dagger"}})
	local result=api.Execute(p,command,true)
	assert(result.Ok and p.Artifacts.target.Star==2 and p.Artifacts.dagger==nil)
end)
test("moves empty the previous hero and undo restores every affected link",function()
	local api,p,request=setup()
	local result=api.Execute(p,request("EQUIP",{HeroId="h1",ArtifactId="held"}),true)
	assert(result.Ok and result.UndoToken)
	assert(p.Heroes.h2.EquippedArtifactUUID==nil and p.Artifacts.old.EquippedHeroUUID==nil)
	assert(p.Heroes.h1.EquippedArtifactUUID=="held" and p.Artifacts.held.EquippedHeroUUID=="h1")
	p.Currencies.Gold+=123 -- passive income must not discard equipment undo
	local undone=api.Execute(p,request("UNDO",{UndoToken=result.UndoToken}),true)
	assert(undone.Ok and p.Heroes.h1.EquippedArtifactUUID=="old" and p.Heroes.h2.EquippedArtifactUUID=="held")
	assert(p.Artifacts.old.EquippedHeroUUID=="h1" and p.Artifacts.held.EquippedHeroUUID=="h2" and p.Currencies.Gold==100123)
end)
test("unequip is reversible, with no resurrection after an artifact is removed",function()
	local api,p,request=setup()
	local result=api.Execute(p,request("UNEQUIP",{HeroId="h1"}),true)
	assert(result.Ok and p.Heroes.h1.EquippedArtifactUUID==nil and p.Artifacts.old.EquippedHeroUUID==nil)
	p.Artifacts.old=nil
	local undone=api.Execute(p,request("UNDO",{UndoToken=result.UndoToken}),true)
	assert(not undone.Ok and p.Artifacts.old==nil and p.Heroes.h1.EquippedArtifactUUID==nil)
end)
test("undo expires, is single-use, and is bound to the profile",function()
	local api,p,request,advance=setup()
	local result=api.Execute(p,request("UNEQUIP",{HeroId="h1"}),true)
	advance(11)
	assert(not api.Execute(p,request("UNDO",{UndoToken=result.UndoToken}),true).Ok)
	local api2,p2,request2=setup()
	local fresh=api2.Execute(p2,request2("UNEQUIP",{HeroId="h1"}),true)
	assert(api2.Execute(p2,request2("UNDO",{UndoToken=fresh.UndoToken}),true).Ok)
	assert(not api2.Execute(p2,request2("UNDO",{UndoToken=fresh.UndoToken}),true).Ok)
	assert(not api.Execute(p,request("UNDO",{UndoToken=fresh.UndoToken}),true).Ok)
end)
test("stale previews and legacy equipment/lock changes reject without partial mutation",function()
	local api,p,request=setup()
	local command=request("UPGRADE",{ArtifactId="target",MaterialIds={"donor"}})
	p.Artifacts.donor.Locked=true
	local result=api.Execute(p,command,true)
	assert(not result.Ok and p.Currencies.Gold==100000 and p.Artifacts.target.Star==1 and p.Artifacts.donor)
end)
test("replays after receipt expiry remain harmless because progression revision changed",function()
	local api,p,request,advance=setup()
	local command=request("UPGRADE",{ArtifactId="target",MaterialIds={"donor"}})
	assert(api.Execute(p,command,true).Ok)
	advance(601)
	assert(not api.Execute(p,command,true).Ok and p.Currencies.Gold==99500 and p.Artifacts.target.Star==2)
end)
test("NaN revisions, spoofed IDs, duplicate donors and unknown operations cannot mutate",function()
	local api,p,request=setup()
	local payloads={
		request("EQUIP",{ExpectedRevision=0/0,HeroId="h1",ArtifactId="target"}),
		request("EQUIP",{HeroId={},ArtifactId="target"}),
		request("UPGRADE",{ArtifactId="target",MaterialIds={"donor","donor"}}),
		request("GRANT_CURRENCY"),
		request("LOCK",{ArtifactId="target",Locked="true"}),
	}
	for _,payload in payloads do assert(not api.Execute(p,payload,true).Ok) end
	assert(p.Currencies.Gold==100000 and p.Artifacts.target.Star==1 and p.Heroes.h1.EquippedArtifactUUID=="old")
end)
test("upgrade gate and archetype restrictions are enforced by the server",function()
	local api,p,request=setup()
	assert(not api.Execute(p,request("UPGRADE",{ArtifactId="target",MaterialIds={"donor"}}),false).Ok)
	assert(not api.Execute(p,request("EQUIP",{HeroId="h3",ArtifactId="target"}),true).Ok)
	assert(p.Artifacts.donor and p.Currencies.Gold==100000)
end)
test("inconsistent forward or reciprocal equipment pointers fail before mutations",function()
	local api,p,request=setup()
	p.Heroes.h2.EquippedArtifactUUID="old"
	assert(not api.Execute(p,request("EQUIP",{HeroId="h1",ArtifactId="target"}),true).Ok)
	assert(p.Heroes.h1.EquippedArtifactUUID=="old" and p.Artifacts.old.EquippedHeroUUID=="h1")
end)
test("request rate limits reset with time and profile cleanup resets session state",function()
	local api,p,request,advance=setup()
	local denied=false
	for _=1,20 do local result=api.Execute(p,request("LOCK",{ArtifactId="target",Locked=true}),true); if not result.Ok then denied=true end end
	assert(denied)
	advance(2)
	assert(api.Execute(p,request("LOCK",{ArtifactId="target",Locked=false}),true).Ok)
	api.Forget(p)
	assert(api.Snapshot(p).Revision==1)
end)
print(string.format("Forge authority: %d cases passed",count))
