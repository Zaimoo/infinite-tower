--!strict
-- StarterPlayerScripts/UI/Settings/SettingsGraphicsEngine.luau
-- Universal graphics, camera, lighting, and post-processing engine for Infinite Towers.
-- Implements live real-time bindings:
-- 1. Camera FOV with CurrentCamera reconnection guard
-- 2. Lighting Brightness + dedicated SettingsBrightnessCC ColorCorrectionEffect
-- 3. Global Dynamic Shadows + Workspace PointLight/SpotLight/SurfaceLight toggle
-- 4. Bloom & Glow Effects across all Lighting bloom/sunrays/DoF effects
-- 5. Atmospheric Color Correction across environmental CC and Atmosphere density/haze
-- 6. Dynamic Glass Blur (SettingsGlassBlur) with smooth 0.18s open/close tweens

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local SettingsGraphicsEngine = {}

local currentFOV = 70
local currentBrightnessAlpha = 0.20
local currentGlobalShadows = true
local currentBloom = true
local currentColorFX = true
local isModalOpen = false

local isInitialized = false
local isSettingFOV = false

local brightnessCC: ColorCorrectionEffect
local localBloom: BloomEffect
local localColor: ColorCorrectionEffect
local glassBlur: BlurEffect

local trackedLights: { [Light]: boolean } = {}

local function ensureEffect<T>(className: string, name: string): T
	local found = Lighting:FindFirstChild(name)
	if found and found.ClassName == className then
		return found :: any
	end
	if found then found:Destroy() end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst :: any
end

local function applyLightShadow(light: Light)
	if light:GetAttribute("OrigShadows") == nil then
		light:SetAttribute("OrigShadows", light.Shadows)
	end
	light.Shadows = currentGlobalShadows and (light:GetAttribute("OrigShadows") == true)
end

function SettingsGraphicsEngine.updateFOV(fov: number)
	currentFOV = math.clamp(fov, 50, 100)
	local cam = workspace.CurrentCamera
	if cam then
		isSettingFOV = true
		cam.FieldOfView = currentFOV
		isSettingFOV = false
	end
end

function SettingsGraphicsEngine.updateBrightness(sliderAlpha: number)
	currentBrightnessAlpha = math.clamp(sliderAlpha, 0, 1)

	local targetBrightness: number
	local targetCCBrightness: number

	if currentBrightnessAlpha <= 0.20 then
		local t = currentBrightnessAlpha / 0.20
		targetBrightness = 0.2 + t * (1.65 - 0.2)
		targetCCBrightness = -0.18 + t * 0.18
	else
		local t = (currentBrightnessAlpha - 0.20) / 0.80
		targetBrightness = 1.65 + t * (4.5 - 1.65)
		targetCCBrightness = t * 0.22
	end

	Lighting.Brightness = targetBrightness
	if brightnessCC then
		brightnessCC.Brightness = targetCCBrightness
		brightnessCC.Enabled = true
	end
end

function SettingsGraphicsEngine.updateDynamicShadows(enabled: boolean)
	currentGlobalShadows = enabled
	Lighting.GlobalShadows = enabled

	for light, _ in pairs(trackedLights) do
		if light.Parent then
			applyLightShadow(light)
		else
			trackedLights[light] = nil
		end
	end
end

function SettingsGraphicsEngine.updateBloom(enabled: boolean)
	currentBloom = enabled

	if localBloom then
		localBloom.Enabled = enabled
		localBloom.Intensity = 0.50
		localBloom.Size = 18
	end

	for _, child in ipairs(Lighting:GetChildren()) do
		if (child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect"))
			and child.Name ~= "SettingsGlassBlur" then
			child.Enabled = enabled
		end
	end
end

function SettingsGraphicsEngine.updateColorCorrection(enabled: boolean)
	currentColorFX = enabled

	if localColor then
		localColor.Enabled = enabled
		localColor.Contrast = 0.04
		localColor.Saturation = 0.02
	end

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("ColorCorrectionEffect") and child.Name ~= "SettingsBrightnessCC" and child.Name ~= "SettingsLocalColor" then
			child.Enabled = enabled
		end
	end

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		if atmosphere:GetAttribute("OrigDensity") == nil then
			atmosphere:SetAttribute("OrigDensity", atmosphere.Density)
			atmosphere:SetAttribute("OrigHaze", atmosphere.Haze)
			atmosphere:SetAttribute("OrigGlare", atmosphere.Glare)
		end

		if enabled then
			atmosphere.Density = (atmosphere:GetAttribute("OrigDensity") :: number?) or 0.35
			atmosphere.Haze = (atmosphere:GetAttribute("OrigHaze") :: number?) or 0.25
			atmosphere.Glare = (atmosphere:GetAttribute("OrigGlare") :: number?) or 0.25
		else
			atmosphere.Density = 0.10
			atmosphere.Haze = 0
			atmosphere.Glare = 0
		end
	end
end

function SettingsGraphicsEngine.setGlassBlur(isOpen: boolean)
	isModalOpen = isOpen
	if not glassBlur then return end

	local targetSize = if isOpen then 10 else 0
	if isOpen then
		glassBlur.Enabled = true
	end

	local tween = TweenService:Create(
		glassBlur,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = targetSize }
	)
	tween.Completed:Connect(function()
		if not isModalOpen and glassBlur then
			glassBlur.Enabled = false
		end
	end)
	tween:Play()
end

function SettingsGraphicsEngine.init()
	if isInitialized then return end
	isInitialized = true

	brightnessCC = ensureEffect("ColorCorrectionEffect", "SettingsBrightnessCC")
	brightnessCC.Name = "SettingsBrightnessCC"
	brightnessCC.Brightness = 0.0
	brightnessCC.Enabled = true

	localBloom = ensureEffect("BloomEffect", "SettingsLocalBloom")
	localBloom.Intensity = 0.50
	localBloom.Size = 18
	localBloom.Enabled = true

	localColor = ensureEffect("ColorCorrectionEffect", "SettingsLocalColor")
	localColor.Contrast = 0.04
	localColor.Saturation = 0.02
	localColor.Enabled = true

	glassBlur = ensureEffect("BlurEffect", "SettingsGlassBlur")
	glassBlur.Size = 0
	glassBlur.Enabled = false

	-- Track lights in Workspace
	local function checkLight(inst: Instance)
		if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
			trackedLights[inst] = true
			applyLightShadow(inst)
		end
	end

	for _, desc in ipairs(workspace:GetDescendants()) do
		checkLight(desc)
	end

	workspace.DescendantAdded:Connect(checkLight)

	-- Camera guard for FOV
	local function bindCamera(cam: Camera)
		cam.FieldOfView = currentFOV
		cam:GetPropertyChangedSignal("FieldOfView"):Connect(function()
			if not isSettingFOV and math.abs(cam.FieldOfView - currentFOV) > 0.01 then
				-- If camera FOV changed externally (e.g. respawn or teleport), re-assert currentFOV
				isSettingFOV = true
				cam.FieldOfView = currentFOV
				isSettingFOV = false
			end
		end)
	end

	if workspace.CurrentCamera then
		bindCamera(workspace.CurrentCamera)
	end

	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if workspace.CurrentCamera then
			bindCamera(workspace.CurrentCamera)
		end
	end)
end

return SettingsGraphicsEngine
