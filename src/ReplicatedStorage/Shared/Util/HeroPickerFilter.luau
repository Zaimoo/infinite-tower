--!strict
-- Search, sort and role filter for the hero picker drawer (HeroSelectionDrawer), used by Synthesis
-- and Equip Artifact. Pure: the drawer fills each entry's Rarity and Power before calling Apply.
--
--   local shown = HeroPickerFilter.Apply(entries, { Query = "gid", Sort = "LEVEL", Role = "ALL", AvailableOnly = false })
--
-- Order: the selected hero first, then heroes that can be picked, then disabled ones; inside each
-- group the chosen sort, then the caller's order. "RECOMMENDED" keeps the caller's order.

local HeroPickerFilter = {}

export type Sort = "RECOMMENDED" | "LEVEL" | "RARITY" | "POWER" | "NAME"
export type Options = { Query: string?, Sort: Sort?, Role: string?, AvailableOnly: boolean? }

HeroPickerFilter.Sorts = table.freeze({ "RECOMMENDED", "LEVEL", "RARITY", "POWER", "NAME" } :: { Sort })
HeroPickerFilter.SortLabels = table.freeze({
	RECOMMENDED = "Recommended", LEVEL = "Level", RARITY = "Rarity", POWER = "Power", NAME = "Name",
} :: { [string]: string })

-- The next value in a cycle (sort or role buttons), wrapping to the first.
function HeroPickerFilter.Next(list: { string }, current: string): string
	for i, value in list do
		if value == current then return list[i % #list + 1] end
	end
	return list[1]
end

-- "ALL" plus every archetype present in the entries, alphabetical.
function HeroPickerFilter.Roles(entries: { any }): { string }
	local seen, roles = {}, {}
	for _, entry in entries do
		local role = entry.Hero and entry.Hero.Archetype
		if type(role) == "string" and role ~= "" and not seen[role] then
			seen[role] = true
			table.insert(roles, role)
		end
	end
	table.sort(roles)
	table.insert(roles, 1, "ALL")
	return roles
end

local function name(entry: any): string
	return string.lower(tostring(entry.Hero and entry.Hero.DisplayName or ""))
end

local function matches(entry: any, query: string): boolean
	if query == "" then return true end
	local hero = entry.Hero or {}
	for _, field in { hero.DisplayName, hero.Archetype, hero.TemplateId } do
		if type(field) == "string" and string.find(string.lower(field), query, 1, true) then return true end
	end
	return false
end

local function key(entry: any, sort: Sort): number
	local hero = entry.Hero or {}
	if sort == "LEVEL" then return (tonumber(hero.Stars) or 1) * 1000 + (tonumber(hero.Level) or 1) end
	if sort == "RARITY" then return (tonumber(entry.Rarity) or 0) * 1000 + (tonumber(hero.Stars) or 1) * 100 + (tonumber(hero.Level) or 1) / 100 end
	if sort == "POWER" then return tonumber(entry.Power) or 0 end
	return 0
end

function HeroPickerFilter.Apply(entries: { any }, opts: Options?): { any }
	local o = opts or {}
	local query = string.lower((string.gsub(o.Query or "", "^%s*(.-)%s*$", "%1")))
	local sort: Sort = o.Sort or "RECOMMENDED"
	local role = o.Role or "ALL"
	local shown, index = {}, {}
	for i, entry in entries do
		index[entry] = i
		local roleOk = role == "ALL" or (entry.Hero and entry.Hero.Archetype == role)
		local availableOk = not o.AvailableOnly or entry.Selected or not entry.Disabled
		if roleOk and availableOk and matches(entry, query) then table.insert(shown, entry) end
	end
	table.sort(shown, function(a, b)
		if (a.Selected == true) ~= (b.Selected == true) then return a.Selected == true end
		if (a.Disabled == true) ~= (b.Disabled == true) then return b.Disabled == true end
		if sort == "NAME" then
			local an, bn = name(a), name(b)
			if an ~= bn then return an < bn end
		elseif sort ~= "RECOMMENDED" then
			local ak, bk = key(a, sort), key(b, sort)
			if ak ~= bk then return ak > bk end
		end
		return index[a] < index[b]
	end)
	return shown
end

return table.freeze(HeroPickerFilter)
