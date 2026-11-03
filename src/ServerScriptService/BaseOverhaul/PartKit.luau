--!strict
-- PartKit.luau
-- Shared part constructors for the BaseOverhaul builders. Props are applied by name;
-- `Decorative = true` disables collision, touch, query and shadows (mobile-friendly scenery).

local PartKit = {}

local function apply(p: BasePart, props: { [string]: any })
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local isDecorative = props.Decorative == true
	p.CanCollide = not isDecorative
	p.CanTouch = not isDecorative
	p.CanQuery = not isDecorative
	if isDecorative then
		p.CastShadow = false
	end
	for k, v in pairs(props) do
		if k ~= "Decorative" and k ~= "Parent" then
			(p :: any)[k] = v
		end
	end
	p.Parent = props.Parent
end

function PartKit.Part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	apply(p, props)
	return p
end

function PartKit.Wedge(props: { [string]: any }): WedgePart
	local w = Instance.new("WedgePart")
	apply(w, props)
	return w
end

function PartKit.CornerWedge(props: { [string]: any }): CornerWedgePart
	local c = Instance.new("CornerWedgePart")
	apply(c, props)
	return c
end

return PartKit
