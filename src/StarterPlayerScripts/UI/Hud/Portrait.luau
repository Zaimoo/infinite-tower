--!strict
-- StarterPlayerScripts/UI/Hud/Portrait.luau
-- Hero portrait for React screens: mounts the shared HeroCard.Portrait (hero-rig viewport, image or
-- archetype fallback) into a frame through a ref. `Dark` silhouettes an unowned hero.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local HeroCard = require(script.Parent.Parent:WaitForChild("HeroCard"))

local function Portrait(props: { TemplateId: string, Archetype: string?, Stars: number?, Size: UDim2?, Dark: boolean? })
	local ref = React.useRef(nil)
	React.useEffect(function()
		local host = ref.current
		if not host then return end
		for _, child in host:GetChildren() do
			if child:IsA("GuiObject") then child:Destroy() end
		end
		local ok, view = pcall(HeroCard.Portrait, host, { TemplateId = props.TemplateId, Archetype = props.Archetype, Stars = props.Stars or 1 })
		if ok and view and props.Dark then
			if view:IsA("ViewportFrame") then
				view.ImageColor3 = Color3.new(0, 0, 0)
				view.ImageTransparency = 0.15
			elseif view:IsA("ImageLabel") then
				view.ImageColor3 = Color3.fromRGB(20, 20, 26)
			end
		end
	end, { props.TemplateId, props.Dark })
	return React.createElement("Frame", { ref = ref, Size = props.Size or UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
end

return Portrait
