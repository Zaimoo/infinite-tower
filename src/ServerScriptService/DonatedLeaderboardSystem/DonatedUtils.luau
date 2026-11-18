--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("LeaderboardRules"))
local SharedUtils = require(script.Parent.Parent:WaitForChild("PowerLeaderboardSystem"):WaitForChild("PowerUtils"))

local Utils = {}

function Utils.formatRobux(amount: number): string
	return LeaderboardRules.FormatRobux(amount)
end

Utils.parseUserId = SharedUtils.parseUserId
Utils.resolvePath = SharedUtils.resolvePath
Utils.resolveNamesBulk = SharedUtils.resolveNamesBulk
Utils.getUsernamePair = SharedUtils.getUsernamePair
Utils.getAvatarThumb = SharedUtils.getAvatarThumb

return Utils
