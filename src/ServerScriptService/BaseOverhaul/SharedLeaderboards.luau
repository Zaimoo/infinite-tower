--!strict
-- SharedLeaderboards.luau
-- The world Playtime and Power boards live once, in the Cloister Commons Leaderboard Pavilion,
-- instead of one copy per plot. Mount() adopts an existing board (pavilion, rescued, or the first
-- plot copy) or builds one in code (LeaderboardBoardBuilder), deletes the other plot copies, and seats
-- and scales each board on its pavilion slot.

local Workspace = game:GetService("Workspace")

local LeaderboardBoardBuilder = require(script.Parent:WaitForChild("LeaderboardBoardBuilder"))

local SharedLeaderboards = {}

SharedLeaderboards.BoardScale = 1.6 -- Boards are drawn this much larger than the original art (pavilion is sized for it)

local PLAYTIME = { Name = "AvxsedPlaytimeWS", Screen = "ScreenPlaytime", Slot = "BoardSlot_Playtime" }
local POWER = { Name = "AvxsedPowerWS", Screen = "ScreenPower", Slot = "BoardSlot_Power" }
local BOARDS = { PLAYTIME, POWER }

-- The pavilion that hosts the shared boards, or nil before the hub is built.
function SharedLeaderboards.Host(): Instance?
	local geometry = Workspace:FindFirstChild("BaseOverhaulGeometry")
	local commons = geometry and geometry:FindFirstChild("MastersCommons")
	return commons and commons:FindFirstChild("LeaderboardPavilion")
end

local function findScreen(board: Instance): BasePart?
	local screen = board:FindFirstChild("ScreenPower") or board:FindFirstChild("ScreenPlaytime")
	return if screen and screen:IsA("BasePart") then screen else nil
end

-- Moves every part of `board` rigidly so the screen faces along the slot's LookVector,
-- the board is centred on the slot sideways, and its lowest part rests on the slot.
local function seat(board: Instance, screen: BasePart, slot: BasePart)
	local parts = {}
	for _, d in board:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local slotCF = slot.CFrame
	local align = slotCF * screen.CFrame:Inverse()
	local minX, maxX, minY = math.huge, -math.huge, math.huge
	for _, p in parts do
		local lp = slotCF:PointToObjectSpace((align * p.CFrame).Position)
		minX = math.min(minX, lp.X)
		maxX = math.max(maxX, lp.X)
		minY = math.min(minY, lp.Y - p.Size.Y * 0.5)
	end
	local shift = slotCF * CFrame.new(-(minX + maxX) * 0.5, -minY, 0) * slotCF:Inverse()
	local move = shift * align
	for _, p in parts do
		p.Anchored = true
		p.CFrame = move * p.CFrame
	end

	-- Grow the board about its slot to BoardScale. The scale already applied is stored on the board,
	-- so re-seating on every server start never compounds it.
	local current = board:GetAttribute("BoardScale")
	local factor = SharedLeaderboards.BoardScale / (if type(current) == "number" and current > 0 then current else 1)
	if math.abs(factor - 1) > 1e-3 then
		for _, p in parts do
			local rel = slotCF:ToObjectSpace(p.CFrame)
			p.Size *= factor
			p.CFrame = slotCF * (CFrame.new(rel.Position * factor) * rel.Rotation)
		end
		for _, d in board:GetDescendants() do
			if d:IsA("SurfaceGui") and d.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud then
				d.PixelsPerStud /= factor -- same layout, drawn larger
			elseif d:IsA("Light") then
				(d :: any).Range *= factor
			elseif d:IsA("Attachment") then
				d.Position *= factor
			end
		end
		board:SetAttribute("BoardScale", SharedLeaderboards.BoardScale)
	end
end

-- Detaches the boards from an old Commons so a rebuild can re-mount them.
function SharedLeaderboards.Rescue(container: Instance?): { [string]: Instance }
	local rescued = {}
	local commons = container and container:FindFirstChild("MastersCommons")
	local pavilion = commons and commons:FindFirstChild("LeaderboardPavilion")
	if pavilion then
		for _, spec in BOARDS do
			local board = pavilion:FindFirstChild(spec.Name)
			if board then
				board.Parent = nil
				rescued[spec.Name] = board
			end
		end
	end
	return rescued
end

function SharedLeaderboards.Mount(pavilion: Instance, plotsFolder: Instance, rescued: { [string]: Instance }?)
	for _, spec in BOARDS do
		local board = pavilion:FindFirstChild(spec.Name) or (rescued and rescued[spec.Name])
		for _, plot in plotsFolder:GetChildren() do
			local copy = plot:FindFirstChild(spec.Name)
			if copy then
				if board then
					copy:Destroy()
				else
					board = copy
				end
			end
		end
		if not board then
			-- No board anywhere: build one in code (LeaderboardBoardBuilder), so the hub can never lose it
			board = LeaderboardBoardBuilder.Build(if spec == POWER then "Power" else "Playtime")
		end
		local slot = pavilion:FindFirstChild(spec.Slot)
		local screen = board and findScreen(board)
		if board and screen and slot and slot:IsA("BasePart") then
			screen.Name = spec.Screen
			board.Parent = pavilion
			seat(board, screen, slot)
		elseif board then
			board.Parent = pavilion
			warn("[SharedLeaderboards] could not seat " .. spec.Name)
		end
	end
end

return SharedLeaderboards
