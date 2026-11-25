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
	if type(x) == "table" and x.X ~= nil then
		local ry = 0
		if type(y) == "table" and y.X ~= nil then
			local dx, dz = y.X - x.X, y.Z - x.Z
			if dx * dx + dz * dz > 1e-6 then
				ry = math.atan2(-dx, -dz)
			end
		end
		return setmetatable({ X = x.X, Y = x.Y, Z = x.Z, rx = 0, ry = ry, rz = 0 }, cframeMeta)
	end
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, rx = 0, ry = 0, rz = 0 }, cframeMeta)
end
function CFrame.lookAt(at, target)
	return CFrame.new(at, target)
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
function cframeMeta:Inverse()
	return setmetatable({ X = -self.X, Y = -self.Y, Z = -self.Z, rx = -self.rx, ry = -self.ry, rz = -self.rz }, cframeMeta)
end
cframeMeta.__add = function(a, v)
	return setmetatable({ X = a.X + v.X, Y = a.Y + v.Y, Z = a.Z + v.Z, rx = a.rx, ry = a.ry, rz = a.rz }, cframeMeta)
end
cframeMeta.__index = cframeMeta
function game:GetService(serviceName)
	return node(serviceName)
end

local colorMeta = {}
function colorMeta:Lerp(other, alpha)
	return setmetatable({
		R = self.R + (other.R - self.R) * alpha,
		G = self.G + (other.G - self.G) * alpha,
		B = self.B + (other.B - self.B) * alpha,
	}, colorMeta)
end
colorMeta.__index = colorMeta

local Color3 = {}
function Color3.fromRGB(r, g, b)
	return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, colorMeta)
end
function Color3.new(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, colorMeta)
end
function Color3.fromHex(hex)
	local digits = string.gsub(hex, "^#", "")
	assert(#digits == 6, "Test Color3 expects six hex digits")
	return Color3.fromRGB(tonumber(string.sub(digits, 1, 2), 16), tonumber(string.sub(digits, 3, 4), 16), tonumber(string.sub(digits, 5, 6), 16))
end

local Random = {}
function Random.new(seed)
	local state = ((seed or 1) % 2147483647)
	if state <= 0 then state = 1 end
	local function next01()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_, a, b)
			if a and b then return a + (b - a) * next01() end
			if a then return a * next01() end
			return next01()
		end,
		NextInteger = function(_, a, b)
			local lo = math.min(a, b)
			local hi = math.max(a, b)
			return math.clamp(lo + math.floor(next01() * (hi - lo + 1)), lo, hi)
		end,
	}
end

local warn = print

local Vector3 = {}
local vectorMeta = {}
function vectorMeta:Lerp(other, alpha)
	return Vector3.new(
		self.X + (other.X - self.X) * alpha,
		self.Y + (other.Y - self.Y) * alpha,
		self.Z + (other.Z - self.Z) * alpha
	)
end
vectorMeta.__index = function(t, k)
	if k == "Magnitude" then
		return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
	elseif k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m < 0.00001 then return Vector3.new(0, 0, 0) end
		return Vector3.new(t.X / m, t.Y / m, t.Z / m)
	elseif k == "Lerp" then
		return vectorMeta.Lerp
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
-- Yaw-only approximations (the shim adds Euler angles): enough for facing maths about the vertical.
function cframeMeta:VectorToObjectSpace(v)
	local c, s = math.cos(self.ry), math.sin(self.ry)
	return Vector3.new(v.X * c - v.Z * s, v.Y, v.X * s + v.Z * c)
end
cframeMeta.__index = function(t, k)
	if k == "Position" then return Vector3.new(t.X, t.Y, t.Z) end
	if k == "Rotation" then return setmetatable({ X = 0, Y = 0, Z = 0, rx = t.rx, ry = t.ry, rz = t.rz }, cframeMeta) end
	if k == "LookVector" then return Vector3.new(-math.sin(t.ry), 0, -math.cos(t.ry)) end
	return cframeMeta[k]
end
local Vector2 = {new=function(x,y) return {X=x,Y=y} end}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, {
			__index = function(_, itemName)
				return itemName
			end,
		})
	end,
})

local NumberRange = {
	new = function(a, b) return { Min = a, Max = b or a } end,
}
local NumberSequenceKeypoint = {
	new = function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end,
}
local NumberSequence = {
	new = function(arg)
		if type(arg) == "table" then return { Keypoints = arg } end
		return { Keypoints = { NumberSequenceKeypoint.new(0, arg), NumberSequenceKeypoint.new(1, arg) } }
	end,
}
local ColorSequenceKeypoint = {
	new = function(t, c) return { Time = t, Value = c } end,
}
local ColorSequence = {
	new = function(a, b)
		if type(a) == "table" and not a.R then return { Keypoints = a } end
		return { Keypoints = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } }
	end,
}

local Instance = {}
function Instance.new(className)
	local children = {}
	local attrs = {}
	local inst
	inst = setmetatable({
		ClassName = className,
		Name = className,
		Parent = nil,
		SetAttribute = function(_, k, v) attrs[k] = v end,
		GetAttribute = function(_, k) return attrs[k] end,
		GetAttributes = function() return attrs end,
		GetChildren = function() return children end,
		GetDescendants = function()
			local out = {}
			local function walk(list)
				for _, c in list do
					table.insert(out, c)
					if c._children then walk(c._children) end
				end
			end
			walk(children)
			return out
		end,
		FindFirstChild = function(_, name, recursive)
			for _, c in children do
				if c.Name == name then return c end
				if recursive and c.FindFirstChild then
					local sub = c:FindFirstChild(name, true)
					if sub then return sub end
				end
			end
			return nil
		end,
		FindFirstChildWhichIsA = function(_, className, recursive)
			for _, c in children do
				if c:IsA(className) then return c end
				if recursive and c.FindFirstChildWhichIsA then
					local sub = c:FindFirstChildWhichIsA(className, true)
					if sub then return sub end
				end
			end
			return nil
		end,
		FindFirstChildOfClass = function(self, className, recursive)
			return self:FindFirstChildWhichIsA(className, recursive)
		end,
		GetPivot = function(self) return self.CFrame or CFrame.identity end,
		PivotTo = function(self, cf) self.CFrame = cf end,
		IsA = function(self, name)
			return self.ClassName == name or name == "Instance" or (name == "BasePart" and (self.ClassName == "Part" or self.ClassName == "WedgePart" or self.ClassName == "MeshPart"))
		end,
		Destroy = function() end,
		_children = children,
	}, {
		__newindex = function(t, k, v)
			if k == "Parent" and type(v) == "table" and v._children then
				table.insert(v._children, t)
			end
			rawset(t, k, v)
		end,
	})
	return inst
end
