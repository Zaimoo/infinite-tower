--!strict
-- Atomic, non-yielding star promotion. Acquisition and rarity never change here.
local B=require(script.Parent.Parent.Config.StatBalance)
local P={}
function P.Promote(profile: any, targetUUID: any, donors: any): (boolean,string,number?)
	if type(profile)~="table" or type(targetUUID)~="string" or type(donors)~="table" then return false,"Invalid promotion request",nil end
	local inventory=profile.Artifacts
	local target=inventory and inventory[targetUUID]
	if not target then return false,"Weapon not found",nil end
	if not B.Integer(target.Star,1,7) or not B.Integer(target.Rarity,1,16) then return false,"Invalid weapon progression",nil end
	local rule=B.WeaponPromotionCosts[target.Star]
	if not rule then return false,"Maximum 7-star rank reached",target.Star end
	local count=0
	for key in pairs(donors) do
		if not B.Integer(key,1,rule.Donors) then return false,"Invalid donor list",target.Star end
		count+=1
	end
	if count~=rule.Donors then return false,string.format("Promotion requires exactly %d copies",rule.Donors),target.Star end
	local seen={}
	for i=1,rule.Donors do
		local uuid=donors[i]
		if type(uuid)~="string" or uuid==targetUUID or seen[uuid] then return false,"Invalid or duplicate donor",target.Star end
		seen[uuid]=true
		local donor=inventory[uuid]
		if not donor or donor.TemplateId~=target.TemplateId then return false,"Donors must be other copies of the same weapon",target.Star end
		if donor.Locked or donor.EquippedHeroUUID then return false,"Cannot consume locked or equipped weapons",target.Star end
		for _,hero in pairs(profile.Heroes or {}) do
			if hero.EquippedArtifactUUID==uuid then return false,"Cannot consume an equipped weapon",target.Star end
		end
	end
	local currencies=profile.Currencies
	if not currencies or not B.Finite(currencies.Gold) or not B.Finite(currencies.Gems)
		or currencies.Gold<rule.Gold or currencies.Gems<rule.Gems then return false,"Not enough Gold or Gems",target.Star end
	-- All checks precede every mutation. No callbacks or yields in this commit.
	currencies.Gold-=rule.Gold;currencies.Gems-=rule.Gems
	for i=1,rule.Donors do inventory[donors[i]]=nil end
	target.Star+=1
	return true,string.format("Promoted to %d stars",target.Star),target.Star
end
return P
