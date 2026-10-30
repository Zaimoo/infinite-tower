--!strict
-- Pure authority checks shared by banking/extraction and regression tests.
local Rules = {}
function Rules.CanBank(location: any, cargo: any, safety: any, transitioning: boolean, now: number): boolean
	return location ~= nil and cargo ~= nil and safety ~= nil and safety.CanBankCargo == true
		and location.BankArmed == true and not transitioning
		and location.FloorId == cargo.FloorId and location.RoomGeneration == cargo.RoomGeneration
		and (cargo.DespawnTime == math.huge or now < (cargo.DespawnTime or cargo.DespawnAt or 0))
end
function Rules.CanExtractFloor(location: any, cargo: any, safety: any, transitioning: boolean, now: number): boolean
	return location ~= nil and type(location.FloorId)=="number" and location.FloorId>=1 and location.FloorId<=50
		and location.FloorId%1==0 and Rules.CanBank(location,cargo,safety,transitioning,now)
end
return table.freeze(Rules)
