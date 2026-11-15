--!strict
-- StarterPlayerScripts/UI/FriendInvite.luau
-- Opens Roblox's invite-friends prompt (docs/first-session-and-social-plan.md B5). The friend boost
-- (GDD §4.8) rewards playing together: +10% Gold per Roblox friend in the server, up to +30%.
-- Sending an invite earns nothing by itself.

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local FriendInvite = {}

local busy = false

-- Shows the prompt when this player may send invites (some accounts can't); otherwise does nothing.
function FriendInvite.Prompt()
	if busy then return end
	busy = true
	task.spawn(function()
		local player = Players.LocalPlayer
		local ok, canSend = pcall(function() return SocialService:CanSendGameInviteAsync(player) end)
		if ok and canSend then
			pcall(function() SocialService:PromptGameInvite(player) end)
		end
		busy = false
	end)
end

return FriendInvite
