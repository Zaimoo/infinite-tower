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

local game = {}
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

local Random = {}
function Random.new()
	return { NextNumber = function() return 0.5 end }
end

local warn = print
