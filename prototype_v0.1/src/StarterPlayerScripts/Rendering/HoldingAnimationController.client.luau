--!strict
-- StarterPlayerScripts/Rendering/HoldingAnimationController.client.luau
-- Procedural Upper-Arm Holding Pose Animation for Carrying Loot & Relics

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RIGHT_ARM_HOLD = CFrame.Angles(math.rad(152), math.rad(10), math.rad(14))
local LEFT_ARM_HOLD = CFrame.Angles(math.rad(152), math.rad(-10), math.rad(-14))

RunService.Stepped:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and (char:GetAttribute("CarryingLoot") == true or char:GetAttribute("CarryingRelic") ~= nil) then
			-- R15 Characters
			local rUpperArm = char:FindFirstChild("RightUpperArm")
			local rShoulder = rUpperArm and rUpperArm:FindFirstChild("RightShoulder") :: Motor6D?
			local lUpperArm = char:FindFirstChild("LeftUpperArm")
			local lShoulder = lUpperArm and lUpperArm:FindFirstChild("LeftShoulder") :: Motor6D?

			if rShoulder and lShoulder then
				rShoulder.Transform = RIGHT_ARM_HOLD
				lShoulder.Transform = LEFT_ARM_HOLD
			else
				-- R6 Fallback
				local torso = char:FindFirstChild("Torso")
				local r6Right = torso and torso:FindFirstChild("Right Shoulder") :: Motor6D?
				local r6Left = torso and torso:FindFirstChild("Left Shoulder") :: Motor6D?
				if r6Right and r6Left then
					r6Right.Transform = RIGHT_ARM_HOLD
					r6Left.Transform = LEFT_ARM_HOLD
				end
			end
		end
	end
end)
