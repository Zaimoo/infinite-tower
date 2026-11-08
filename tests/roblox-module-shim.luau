-- CLI-only module loading. Deliberately contains no gameplay implementations.
local nodes = {}
local loaders = {}
local loaded = {}
local loading = {}

local function node(path)
	if nodes[path] then return nodes[path] end
	local parentPath, name = string.match(path, "^(.*)%.([^%.]+)$")
	local value = { Name = name or path, Path = path }
	function value:WaitForChild(childName)
		assert(self[childName], "Missing test module: " .. self.Path .. "." .. childName)
		return self[childName]
	end
	function value:FindFirstChild(childName)
		return self[childName]
	end
	nodes[path] = value
	if parentPath then
		value.Parent = node(parentPath)
		value.Parent[value.Name] = value
	end
	return value
end

local function register(path, loader)
	loaders[node(path)] = loader
end

local function require(module)
	assert(loaders[module], "Module not registered: " .. tostring(module and module.Path))
	if loaded[module] ~= nil then return loaded[module] end
	assert(not loading[module], "Cyclic module dependency: " .. module.Path)
	loading[module] = true
	loaded[module] = loaders[module](module)
	loading[module] = nil
	return loaded[module]
end

local game = { ReplicatedStorage = node("ReplicatedStorage") }
local workspace = {
	GetServerTimeNow = function() return os.clock() end,
	GetAttribute = function(_, attr) return nil end,
}
local CFrame = {}
local cframeMeta = {}
function CFrame.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, rx = 0, ry = 0, rz = 0 }, cframeMeta)
end
function CFrame.Angles(rx, ry, rz)
	return setmetatable({ X = 0, Y = 0, Z = 0, rx = rx or 0, ry = ry or 0, rz = rz or 0 }, cframeMeta)
end
CFrame.identity = CFrame.new(0, 0, 0)
cframeMeta.__mul = function(a, b)
	return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z, rx = a.rx + b.rx, ry = a.ry + b.ry, rz = a.rz + b.rz }, cframeMeta)
end
function cframeMeta:Lerp(other, alpha)
	return setmetatable({
		X = self.X + (other.X - self.X) * alpha,
		Y = self.Y + (other.Y - self.Y) * alpha,
		Z = self.Z + (other.Z - self.Z) * alpha,
		rx = self.rx + (other.rx - self.rx) * alpha,
		ry = self.ry + (other.ry - self.ry) * alpha,
		rz = self.rz + (other.rz - self.rz) * alpha,
	}, cframeMeta)
end
cframeMeta.__index = cframeMeta
function game:GetService(serviceName)
	return node(serviceName)
end

local Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r, g, b)
	return { R = r, G = g, B = b }
end
function Color3.fromHex(hex)
	local digits = string.gsub(hex, "^#", "")
	assert(#digits == 6, "Test Color3 expects six hex digits")
	return Color3.fromRGB(tonumber(string.sub(digits, 1, 2), 16), tonumber(string.sub(digits, 3, 4), 16), tonumber(string.sub(digits, 5, 6), 16))
end

local Random = {}
function Random.new()
	return { NextNumber = function() return 0.5 end }
end

local warn = print

local Vector3 = {}
local vectorMeta = {}
vectorMeta.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m < 0.00001 then return Vector3.new(0, 0, 0) end
		return Vector3.new(t.X / m, t.Y / m, t.Z / m)
	elseif k == "Lerp" then
		return function(a, b, alpha) return Vector3.new(a.X + (b.X - a.X) * alpha, a.Y + (b.Y - a.Y) * alpha, a.Z + (b.Z - a.Z) * alpha) end
	elseif k == "Dot" then
		return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	elseif k == "Cross" then
		return function(a, b) return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	end
	return rawget(t, k)
end
function Vector3.new(x, y, z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vectorMeta) end
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
vectorMeta.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMeta.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMeta.__mul=function(a,b)
	if type(a) == "number" then return Vector3.new(b.X*a, b.Y*a, b.Z*a)
	elseif type(b) == "number" then return Vector3.new(a.X*b, a.Y*b, a.Z*b)
	else return Vector3.new(a.X*b.X, a.Y*b.Y, a.Z*b.Z) end
end
local Vector2 = {new=function(x,y) return {X=x,Y=y} end}
