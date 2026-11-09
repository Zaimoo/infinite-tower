--!strict

export type Lesson = { Id: string, Title: string, Description: string, Target: string?, Control: string? }

local function lesson(id: string, title: string, description: string, target: string?): Lesson
	return table.freeze({ Id = id, Title = title, Description = description, Target = target })
end

return table.freeze({
	Ready = lesson("Ready", "Ready your squad", "Choose a rested hero for your squad.", "Squad"),
	Visit = lesson("Visit", "Enter Floor 1", "Open the Tower gate and choose Floor 1.", "Tower"),
	Clear = lesson("Clear", "Defeat the Floor 1 boss", "Fight alongside your squad. Defeat enemies to summon the floor boss.", nil),
	Return = lesson("Return", "Return to safety", "Use Hub to return, or keep climbing if your squad is ready.", "Hub"),
	Bank = lesson("Bank", "Bank your relic", "Carry your relic to a sanctuary or an extraction pad to keep its rewards.", "Bank"),
	Equip = lesson("Equip", "Equip a weapon", "Equip a compatible weapon to improve your squad’s damage.", "Blacksmith"),
	Upgrade = lesson("Upgrade", "Upgrade a weapon", "Use matching unequipped weapons to raise its star rank.", "Blacksmith"),
	GuardPost = lesson("GuardPost", "Earn passive Gold", "Assign a spare hero at the Guard Post to earn Gold while you’re away.", "GuardPost"),
	Market = lesson("Market", "Staff the Market", "Assign a spare hero to boost Tower loot and relic payouts.", "Market"),
	TrainingGrounds = lesson("TrainingGrounds", "Staff the Training Grounds", "Assign a spare hero to boost squad attack and health.", "TrainingGrounds"),
	GodsBlessing = lesson("GodsBlessing", "Staff God’s Blessing", "Assign an acolyte to improve your summon luck.", "GodsBlessing"),
	Tree = lesson("Tree", "Grow your fortress", "Build an affordable upgrade to improve your fortress.", "Upgrades"),
	Summon = lesson("Summon", "Recruit another hero", "Visit the Summoning Altar to grow your roster.", "Summoning"),
	Synthesis = lesson("Synthesis", "Train a hero in The Pit", "Preview how much XP a spare hero would give before consuming it.", "ThePit"),
	Promotion = lesson("Promotion", "Promote a hero", "Use Promotion Stones to raise a capped hero’s star rank.", "ThePit"),
	Raid = lesson("Raid", "Join the raid", "The Raid Portal in the Commons is open. Watch for the boss’s attack warnings.", "Raid"),
})
