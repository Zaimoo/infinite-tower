--!strict
-- StarterPlayerScripts/UI/SquadLockModal.luau
-- The squad can't change while the Master or the squad is in the tower or a raid
-- (DataManager.squadLockReason). AssignHeroRole then answers (false, message, code); any window that
-- moves squad heroes passes the code here and the refusal shows as a modal instead of a status line.
-- In the tower the modal offers the way out: Return to Hub closes the open windows and travels home.

local Kit = require(script.Parent:WaitForChild("Kit"))

local SquadLockModal = {}

-- True when `code` is a squad-lock refusal (and the modal was shown).
function SquadLockModal.Show(code: any, message: any): boolean
	if code ~= "SQUAD_LOCKED_TOWER" and code ~= "SQUAD_LOCKED_RAID" then return false end
	local inTower = code == "SQUAD_LOCKED_TOWER"
	Kit.Confirm.Ask({
		Tier = "Soft",
		Title = if inTower then "Squad locked in the tower" else "Squad locked during the raid",
		Body = if inTower
			then "You can't change your squad while you or your squad are in the tower. Return to the hub first, then change your heroes."
			else tostring(message or "You can't change your squad during a raid."),
		ConfirmText = if inTower then "Return to Hub" else "OK",
		CancelText = if inTower then "Stay" else "Close",
		OnConfirm = if inTower then function()
			if _G.OpenMasterModal then _G.OpenMasterModal("NONE") end
			if _G.RequestTowerHub then _G.RequestTowerHub() end
		end else nil,
	})
	return true
end

return table.freeze(SquadLockModal)
