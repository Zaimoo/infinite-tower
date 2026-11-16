--!strict
-- StarterPlayerScripts/UI/Hud/PassRemotes.luau
-- Client requests for the Battle Pass and potions (GDD §4.9). Both remotes answer { Ok, Message };
-- the state itself arrives in the profile sync (Store.Profile.BattlePass / Potions / Boosts), so
-- there is nothing to mirror here. The server decides every claim and every potion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PassRemotes = {}

local function invoke(folderName: string, remoteName: string, ...: any): (boolean, string?)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local folder = remotes:WaitForChild(folderName, 10)
	local remote = folder and folder:WaitForChild(remoteName, 10)
	if not remote or not remote:IsA("RemoteFunction") then return false, "Still loading. Try again." end
	local args = table.pack(...)
	local ok, result = pcall(function() return remote:InvokeServer(table.unpack(args, 1, args.n)) end)
	if not ok or type(result) ~= "table" then return false, "Couldn't reach the server. Try again." end
	return result.Ok == true, if type(result.Message) == "string" then result.Message else nil
end

-- "CLAIM" (track, level), "CLAIM_ALL". Yields. Returns (ok, message).
function PassRemotes.Pass(action: string, track: string?, level: number?): (boolean, string?)
	return invoke("BattlePassRemotes", "BattlePassRequest", action, track, level)
end

-- Drinks one potion. Yields. Returns (ok, message).
function PassRemotes.UsePotion(potionId: string): (boolean, string?)
	return invoke("PotionRemotes", "PotionRequest", "USE", potionId)
end

return PassRemotes
