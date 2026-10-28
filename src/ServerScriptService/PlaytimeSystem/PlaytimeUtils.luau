local Players     = game:GetService("Players")
local UserService  = game:GetService("UserService")

local Utils = {}

function Utils.formatHM(totalSeconds: number): string
	totalSeconds = math.max(0, math.floor(totalSeconds))
	local h = math.floor(totalSeconds / 3600)
	local m = math.floor((totalSeconds % 3600) / 60)
	return string.format("%d h %d m", h, m)
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
				warn("[PlaytimeUtils] Path resolve gagal di segment:", name)
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
