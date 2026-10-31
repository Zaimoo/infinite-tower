--!strict
local Players     = game:GetService("Players")
local UserService  = game:GetService("UserService")

local Utils = {}

function Utils.formatPower(power: number): string
	power = math.max(0, math.floor(power or 0))
	if power >= 1_000_000_000_000 then
		return (string.gsub(string.format("%.1fT PWR", power / 1e12), "%.0T", "T"))
	elseif power >= 1_000_000_000 then
		return (string.gsub(string.format("%.1fB PWR", power / 1e9), "%.0B", "B"))
	elseif power >= 1_000_000 then
		return (string.gsub(string.format("%.1fM PWR", power / 1e6), "%.0M", "M"))
	elseif power >= 10_000 then
		return (string.gsub(string.format("%.1fK PWR", power / 1e3), "%.0K", "K"))
	else
		local formatted = tostring(power)
		local k
		while true do
			formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
			if k == 0 then break end
		end
		return formatted .. " PWR"
	end
end

function Utils.parseUserId(key: any): number?
	local s = typeof(key) == "string" and key or tostring(key or "")
	s = s:gsub("^u", "")
	return tonumber(s) or tonumber(s:match("(%d+)$"))
end

function Utils.resolvePath(pathParts: { string }, root: Instance?, timeout: number?): Instance?
	local current: Instance = root or workspace
	for _, name in ipairs(pathParts) do
		local nextInst = current:FindFirstChild(name)
		if not nextInst then
			local ok, result = pcall(function()
				return current:WaitForChild(name, timeout or 5)
			end)
			if not ok or not result then
				warn("[PowerUtils] Path resolve gagal di segment:", name)
				return nil
			end
			nextInst = result
		end
		current = nextInst
	end
	return current
end

local usernameCache: { [number]: string } = {}
local displayNameCache: { [number]: string } = {}

function Utils.resolveNamesBulk(userIds: { number })
	local toQuery = {}
	local seen: { [number]: boolean } = {}
	for _, uid in ipairs(userIds) do
		if uid and not usernameCache[uid] and not seen[uid] then
			table.insert(toQuery, uid)
			seen[uid] = true
		end
	end
	if #toQuery == 0 then return end

	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, toQuery)
	if ok and typeof(infos) == "table" then
		for _, inf in ipairs(infos) do
			if inf and inf.Id then
				if inf.Username then usernameCache[inf.Id] = inf.Username end
				if inf.DisplayName and inf.DisplayName ~= "" then
					displayNameCache[inf.Id] = inf.DisplayName
				end
			end
		end
	end
end

function Utils.getUsernamePair(userId: number): (string, string)
	local p = Players:GetPlayerByUserId(userId)
	if p then return p.Name, p.DisplayName end

	local uname = usernameCache[userId]
	if not uname or uname == "" then
		local ok, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		uname = ok and result or ("User" .. userId)
		usernameCache[userId] = uname
	end
	local dname = displayNameCache[userId]
	if not dname or dname == "" then dname = uname end
	return uname, dname
end

function Utils.getAvatarThumb(userId: number, thumbType: string?, w: number?, h: number?): string
	return string.format(
		"rbxthumb://type=%s&id=%d&w=%d&h=%d",
		thumbType or "AvatarBust", userId, w or 150, h or 150
	)
end

return Utils
