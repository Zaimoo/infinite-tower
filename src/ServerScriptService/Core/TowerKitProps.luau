--!strict
-- ServerScriptService/Core/TowerKitProps.luau
-- Places Tower Biome Kit meshes (Shared/Config/TowerBiomeKit) for TowerBiomeAssets: clones a template from
-- ServerStorage.TowerBiomeKit, scales it (per axis, so an arch pier or a cliff can be fitted to a box) and
-- tints every MeshPart by its Role from the floor's theme and the biome palette.
--
-- Placed meshes are pure scenery: anchored, no collision, no queries, no touch. Props that must block or
-- support (cliffs, island crowns, arch piers, spire shafts) keep their old part as an invisible collider,
-- so navigation, settling and clearance behave exactly as before. Each placed model carries PropKind, so
-- TowerPropClearance removes it whole together with the prop group it stands in.

local ServerStorage = game:GetService("ServerStorage")

local Kit = require(game.ReplicatedStorage.Shared.Config.TowerBiomeKit)

local TowerKitProps = {}

-- Deepest a placed template may dip below its base (studs).
TowerKitProps.MAX_SINK = 2.5

export type Override = { [string]: { Color: Color3?, Material: Enum.Material?, Transparency: number? } }
export type Resolver = (role: string) -> (Color3, Enum.Material, number)

local cachedFolder: Instance? = nil

local function folder(): Instance?
	if cachedFolder and cachedFolder.Parent then
		return cachedFolder
	end
	cachedFolder = ServerStorage:FindFirstChild(Kit.FolderName)
	return cachedFolder
end

-- True when the template has been imported (it has at least one MeshPart).
function TowerKitProps.Has(name: string): boolean
	local f = folder()
	local t = f and f:FindFirstChild(name)
	return t ~= nil and t:FindFirstChildWhichIsA("MeshPart") ~= nil
end

-- True when every template the kit lists is imported; floors use the kit only then, so a half-finished
-- import never mixes meshes and parts on one floor.
function TowerKitProps.Ready(): boolean
	if not folder() then
		return false
	end
	for name in Kit.Templates do
		if not TowerKitProps.Has(name) then
			return false
		end
	end
	return true
end

function TowerKitProps.Size(name: string): Vector3
	local t = Kit.Templates[name]
	return if t then t.Size else Vector3.one
end

-- Role colours for one floor: the biome palette, then the shared palette, then the floor theme.
function TowerKitProps.Resolver(biome: string, theme: any): Resolver
	local biomeKit = Kit.Biomes[biome]
	local palette = if biomeKit then biomeKit.Palette else {}
	return function(role: string): (Color3, Enum.Material, number)
		local s = palette[role] or Kit.SharedPalette[role]
		if role == "STONE" then
			return theme.CliffColor, theme.CliffMaterial, 0
		elseif role == "TRIM" then
			return theme.TrimColor, theme.TrimMaterial, 0
		elseif role == "ACCENT" then
			return theme.AccentColor, theme.TrimMaterial, 0
		elseif role == "GLOW" then
			return theme.LightColor, Enum.Material.Neon, 0
		elseif s then
			return s.Color, s.Material, s.Transparency or 0
		end
		return theme.TrimColor, theme.TrimMaterial, 0
	end
end

-- Clone template `name` with its origin (footprint centre on the ground, front facing +Z) at baseCF,
-- scaled per axis by `scale`. Returns nil when the template is missing.
function TowerKitProps.Place(parent: Instance, name: string, baseCF: CFrame, scale: Vector3, resolve: Resolver, override: Override?): Model?
	local f = folder()
	local template = f and f:FindFirstChild(name)
	if not template then
		return nil
	end
	-- Roots and rock feet may sink into their support, but never more than MAX_SINK: the settle pass probes
	-- from 4 studs above a prop's lowest point and must start above the ground it stands on.
	local spec = Kit.Templates[name]
	local sink = if spec then -spec.Min.Y * scale.Y else 0
	if sink > TowerKitProps.MAX_SINK then
		baseCF += Vector3.new(0, sink - TowerKitProps.MAX_SINK, 0)
	end
	local model = Instance.new("Model")
	model.Name = "Kit_" .. name
	model:SetAttribute("PropKind", "Kit" .. name)
	model:SetAttribute("KitTemplate", name)
	local shadows = Kit.CastsShadow[name] == true
	for _, source in template:GetChildren() do
		if source:IsA("MeshPart") then
			local role = (source:GetAttribute("Role") :: string?) or source.Name
			local color, material, transparency = resolve(role)
			local o = override and override[role]
			if o then
				color = o.Color or color
				material = o.Material or material
				transparency = o.Transparency or transparency
			end
			local p = source:Clone()
			-- Template parts are axis-aligned at the template origin, so a per-axis scale is exact.
			p.Size = source.Size * scale
			p.CFrame = baseCF * CFrame.new(source.Position * scale) * source.CFrame.Rotation
			p.Color = color
			p.Material = material
			p.Transparency = transparency
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = shadows and role ~= "GLOW" and role ~= "CRYSTAL"
			p.Parent = model
		end
	end
	model.Parent = parent
	return model
end

-- Fits a template over a box part (a cliff, ledge or island block) and hides the part, which stays as the
-- collider and support. Long boxes are tiled along their long side so the rock keeps its proportions; the
-- template's front (+Z) faces `facing` (a world point, normally the room centre).
function TowerKitProps.DressBox(part: BasePart, names: { string }, resolve: Resolver, facing: Vector3, override: Override?): number
	local size = part.Size
	local alongX = size.X >= size.Z
	local long, short = if alongX then size.X else size.Z, if alongX then size.Z else size.X
	local count = math.clamp(math.round(long / math.max(short * 1.25, 30)), 1, 8)
	local tileLong = long / count
	local bottom = part.CFrame * CFrame.new(0, -size.Y / 2, 0)
	-- Template X follows the box's long side; pick the yaw (of the two that do) whose +Z faces `facing`.
	local axis = if alongX then bottom.RightVector else bottom.LookVector
	local front = Vector3.new(-axis.Z, 0, axis.X)
	local toward = facing - part.Position
	if front:Dot(Vector3.new(toward.X, 0, toward.Z)) < 0 then
		front = -front
	end
	local placed = 0
	for i = 1, count do
		local along = (i - (count + 1) / 2) * tileLong
		local name = names[(i + math.floor(part.Position.X + part.Position.Z)) % #names + 1]
		local t = Kit.Templates[name]
		if t then
			local scale = Vector3.new(tileLong / t.Size.X, size.Y / t.Size.Y, short / t.Size.Z)
			-- Lift by the template's dip below its origin, so the rock spans exactly the box's height (the settle
			-- pass probes from just above a prop's lowest point, which must not start inside the ground).
			local at = bottom.Position + axis * along + Vector3.new(0, -t.Min.Y * scale.Y, 0)
			local cf = CFrame.lookAt(at, at + front) * CFrame.Angles(0, math.pi, 0)
			if TowerKitProps.Place(part.Parent :: Instance, name, cf, scale, resolve, override) then
				placed += 1
			end
		end
	end
	if placed > 0 then
		part.Transparency = 1
		part.CastShadow = false
		part:SetAttribute("KitCollider", true)
	end
	return placed
end

return TowerKitProps
