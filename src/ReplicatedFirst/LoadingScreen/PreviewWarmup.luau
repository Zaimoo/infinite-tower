--!strict
-- ReplicatedFirst/LoadingScreen/PreviewWarmup.luau
-- Draws every hero and weapon template once, behind the join loading screen.
-- PreloadAsync only downloads an asset. A mesh or texture is decoded and sent to the GPU the first
-- time something renders it, so the first hero card or artifact card to show a template used to
-- appear without its hair mesh, face decal or weapon textures for a moment. Rendering all the
-- templates here, in the same kind of ViewportFrame the cards use, pays that cost while the
-- loading screen still covers the HUD.
-- The viewports then stay for the whole session, shrunk to a couple of pixels. Roblox releases a
-- mesh or texture soon after the last thing rendering it goes, and the card would pop in again
-- while it reloaded; a static ViewportFrame is not redrawn, so keeping these costs memory only.

local PreviewWarmup = {}

local CELL = 14 -- studs between models in the grid; the largest weapon is shorter than this
local FIELD_OF_VIEW = 50
local SIZE = 256 -- px per viewport while the loading screen covers it
local SHRUNK = 2 -- px per viewport once the loading screen is gone
local CLONES_PER_FRAME = 8 -- so the loading bar keeps animating while the grids fill

export type Warmup = {
	Shrink: () -> (),
}

-- One viewport holding a grid of every model in `folder`. Yields while it clones.
local function fill(gui: ScreenGui, folder: Instance): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = folder.Name
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromOffset(SIZE, SIZE)
	viewport.Parent = gui

	local templates: { Model } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(templates, child)
		end
	end

	-- A square grid in the XY plane, seen from -Z (the side hero templates face).
	local columns = math.max(1, math.ceil(math.sqrt(#templates)))
	local rows = math.max(1, math.ceil(#templates / columns))
	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	local centre = Vector3.new((columns - 1) * CELL / 2, (rows - 1) * CELL / 2, 0)
	local distance = math.max(columns, rows) * CELL * 0.5 / math.tan(math.rad(FIELD_OF_VIEW / 2)) + CELL
	camera.CFrame = CFrame.lookAt(centre - Vector3.new(0, 0, distance), centre)
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	for index, template in templates do
		local model = template:Clone()
		for _, descendant in model:GetDescendants() do
			-- Effects never show on a card, and an emitter would make the viewport redraw every frame.
			if descendant:IsA("LuaSourceContainer") or descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		local cell = index - 1
		local place = Vector3.new((cell % columns) * CELL, (cell // columns) * CELL, 0)
		local bounds = model:GetBoundingBox()
		model:PivotTo(model:GetPivot() + (place - bounds.Position))
		model.Parent = viewport
		if index % CLONES_PER_FRAME == 0 then
			task.wait()
		end
	end
	return viewport
end

-- `folders` hold the template models (Assets.Heroes, Assets.Weapons), one viewport each. The gui's
-- name starts with "LoadingScreen" so PreloadManifest skips it. Yields while it clones.
function PreviewWarmup.Start(playerGui: Instance, displayOrder: number, folders: { Instance }): Warmup
	local gui = Instance.new("ScreenGui")
	gui.Name = "LoadingScreenWarmup"
	gui.DisplayOrder = displayOrder
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local viewports: { ViewportFrame } = {}
	local shrunk = false
	local function place(viewport: ViewportFrame, slot: number)
		local px = if shrunk then SHRUNK else SIZE
		viewport.Size = UDim2.fromOffset(px, px)
		viewport.Position = UDim2.fromOffset((slot - 1) * px, 0)
	end
	local warmup: Warmup = {
		Shrink = function()
			shrunk = true
			for slot, viewport in viewports do
				place(viewport, slot)
			end
		end,
	}
	for slot, folder in folders do
		local viewport = fill(gui, folder)
		table.insert(viewports, viewport)
		place(viewport, slot)
	end
	return warmup
end

return PreviewWarmup
