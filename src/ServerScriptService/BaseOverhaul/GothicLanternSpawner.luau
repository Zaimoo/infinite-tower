--!strict
-- GothicLanternSpawner.luau
-- Strictly clones the Blender-authored `ReplicatedStorage.Assets.Props.GothicLanternPost`
-- prefab exported from `tools/blender/generate_gothic_lantern_post.py`.
-- Zero procedural Roblox Part fallbacks are permitted here: if the prefab has not
-- been imported into Studio yet, logs a single clean warning and skips spawning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GothicLanternSpawner = {}

GothicLanternSpawner.ASSET_WARNING =
	"[BaseOverhaul] Missing Blender asset: ReplicatedStorage.Assets.Props.GothicLanternPost"

local warnedMissing = false

local STONE_COLOR = Color3.fromHex("#3A3D45")
local TIMBER_COLOR = Color3.fromHex("#3D2B1F")
local IRON_COLOR = Color3.fromHex("#18181C")
local GLASS_COLOR = Color3.fromHex("#D99B52")
local CANDLE_COLOR = Color3.fromHex("#F59E0B")
local LIGHT_COLOR = Color3.fromRGB(255, 165, 65)

local function matchesPart(name: string, token: string): boolean
	return name == token or string.find(name, token, 1, true) ~= nil
end

local function findSubInstance(root: Instance, token: string): Instance?
	local exact = root:FindFirstChild(token, true)
	if exact then
		return exact
	end
	for _, desc in root:GetDescendants() do
		if matchesPart(desc.Name, token) then
			return desc
		end
	end
	return nil
end

local function configurePart(part: BasePart)
	local name = part.Name
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	local hasTexture = part:FindFirstChildWhichIsA("SurfaceAppearance") ~= nil

	if matchesPart(name, "Lantern_StoneBase") then
		part.Material = Enum.Material.Slate
		if not hasTexture then
			part.Color = STONE_COLOR
		end
		part.CanCollide = true
		part.CanQuery = true
		part.Massless = false
	elseif matchesPart(name, "Lantern_TimberArm") or matchesPart(name, "Lantern_TimberPost_Arm") then
		part.Material = Enum.Material.Wood
		if not hasTexture then
			part.Color = TIMBER_COLOR
		end
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
	elseif matchesPart(name, "Lantern_BaseFrame") or matchesPart(name, "Lantern_TimberPost") then
		part.Material = Enum.Material.Wood
		if not hasTexture then
			part.Color = TIMBER_COLOR
		end
		part.CanCollide = true
		part.CanQuery = true
		part.Massless = false
	elseif matchesPart(name, "Lantern_Ironwork") or matchesPart(name, "Lantern_Cage") then
		part.Material = Enum.Material.Metal
		if not hasTexture then
			part.Color = IRON_COLOR
		end
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
	elseif matchesPart(name, "Lantern_Glass") then
		part.Material = Enum.Material.Glass
		if not hasTexture then
			part.Color = GLASS_COLOR
		end
		part.Transparency = 0.65
		part.CastShadow = false
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
	elseif matchesPart(name, "Lantern_CandleCore") then
		part.Material = Enum.Material.Neon
		part.Color = CANDLE_COLOR
		part.CastShadow = false
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
	else
		-- Any other overhanging / unrecognised Blender sub-mesh stays non-colliding
		part.CanCollide = false
		part.CanQuery = false
		part.Massless = true
	end
end

local function attachLightingAndEmbers(root: Instance)
	local vfxTarget: Instance? = findSubInstance(root, "VFX_LanternLight")
	if vfxTarget and not (vfxTarget:IsA("Attachment") or vfxTarget:IsA("BasePart")) then
		vfxTarget = nil
	end
	if not vfxTarget then
		vfxTarget = findSubInstance(root, "Lantern_CandleCore")
	end
	if not vfxTarget or not (vfxTarget:IsA("Attachment") or vfxTarget:IsA("BasePart")) then
		return
	end

	if not root:FindFirstChildWhichIsA("PointLight", true) then
		local light = Instance.new("PointLight")
		light.Name = "WarmGothicLanternLight"
		light.Color = LIGHT_COLOR
		light.Brightness = 1.8
		light.Range = 22
		-- Kept false so StaticGeometry / Future lighting renders stay at 60 FPS across 8 plots
		light.Shadows = false
		light.Parent = vfxTarget
	end

	if not root:FindFirstChildWhichIsA("ParticleEmitter", true) then
		local embers = Instance.new("ParticleEmitter")
		embers.Name = "GothicLanternEmbers"
		embers.Texture = "rbxassetid://243660364"
		embers.Color = ColorSequence.new(Color3.fromRGB(255, 224, 130), Color3.fromRGB(245, 130, 35))
		embers.LightEmission = 0.9
		embers.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.7, 0.09),
			NumberSequenceKeypoint.new(1, 0),
		})
		embers.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		embers.Lifetime = NumberRange.new(1.2, 2.3)
		embers.Rate = 4
		embers.Speed = NumberRange.new(0.4, 1.0)
		embers.SpreadAngle = Vector2.new(35, 35)
		embers.Acceleration = Vector3.new(0, 0.55, 0)
		embers.Drag = 1.5
		embers.Parent = vfxTarget
	end
end

function GothicLanternSpawner.ResetWarning()
	warnedMissing = false
end

function GothicLanternSpawner.GetTemplate(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("Props")
	local template = props and props:FindFirstChild("GothicLanternPost")
	if template and (template:IsA("Model") or template:IsA("Folder") or template:IsA("BasePart")) then
		return template
	end
	return nil
end

function GothicLanternSpawner.Spawn(parent: Instance, baseCFrame: CFrame, name: string?): Model?
	local template = GothicLanternSpawner.GetTemplate()
	if not template then
		if not warnedMissing then
			warnedMissing = true
			warn(GothicLanternSpawner.ASSET_WARNING)
		end
		return nil
	end

	local cloned = template:Clone()
	local model: Model
	if cloned:IsA("Model") then
		model = cloned
	else
		model = Instance.new("Model")
		if cloned:IsA("BasePart") then
			cloned.Parent = model
		else
			for _, child in cloned:GetChildren() do
				child.Parent = model
			end
			cloned:Destroy()
		end
	end
	model.Name = name or "GothicLanternPost"

	local stoneBase = findSubInstance(model, "Lantern_StoneBase")
	if stoneBase and stoneBase:IsA("BasePart") then
		model.PrimaryPart = stoneBase
	elseif not model.PrimaryPart then
		local firstPart = model:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then
			model.PrimaryPart = firstPart
		end
	end

	for _, desc in model:GetDescendants() do
		if desc:IsA("BasePart") then
			configurePart(desc)
		end
	end

	-- Ensure overhanging arm/cage faces -Z (LookVector) even if Studio's 3D Importer flipped the FBX
	local cage = findSubInstance(model, "Lantern_Cage") or findSubInstance(model, "Lantern_TimberArm")
	local rotFix = CFrame.identity
	if cage and cage:IsA("BasePart") then
		local relCage = model:GetPivot():Inverse() * cage.CFrame
		if relCage.Position.Z > 0.2 then
			rotFix = CFrame.Angles(0, math.pi, 0)
		end
	end

	-- Snap the bottom-center of Lantern_StoneBase flush onto baseCFrame regardless of import pivot offset
	if stoneBase and stoneBase:IsA("BasePart") then
		local relStone = model:GetPivot():Inverse() * stoneBase.CFrame
		local bottomLocal = relStone.Position - Vector3.new(0, stoneBase.Size.Y * 0.5, 0)
		model:PivotTo(baseCFrame * rotFix * CFrame.new(-bottomLocal))
	else
		model:PivotTo(baseCFrame * rotFix)
	end

	attachLightingAndEmbers(model)
	model.Parent = parent
	return model
end

-- Destroys any legacy 3-part / 5-part / orchard primitive streetlamps left over from pre-Blender builds
-- without removing the LampPylons container itself so existing GothicLantern_Rim_* instances stay intact.
function GothicLanternSpawner.CleanupLegacyLamps(root: Instance): number
	local removed = 0
	for _, desc in root:GetDescendants() do
		if desc.Parent == nil then
			continue
		end
		local n = desc.Name
		if
			n == "LampPost"
			or n == "LampCap"
			or n == "LampArm"
			or n == "LampLantern"
			or n == "LanternPost"
			or n == "PaperLantern"
			or string.find(n, "^Lamppost_Plinth_")
			or string.find(n, "^Lamppost_Shaft_")
			or string.find(n, "^Lamppost_Crossbar_")
			or string.find(n, "^Lamppost_CageCap_")
			or string.find(n, "^Lamppost_Lantern_")
		then
			desc:Destroy()
			removed += 1
		end
	end
	return removed
end

GothicLanternSpawner.SpawnGothicLantern = GothicLanternSpawner.Spawn

return GothicLanternSpawner
