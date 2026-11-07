--!strict
-- Shared accessibility pass for imperative and React screen UI. Preserve font families,
-- authored sizes, borders and fades; cover lazily mounted windows as well as the HUD.
local TextReadability = {}
local INK = Color3.fromRGB(10, 6, 14)

function TextReadability.Watch(root: Instance)
	local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	local function visit(instance: Instance)
		if not (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox")) then return end
		if not instance:FindFirstAncestorOfClass("ScreenGui") or watched[instance] then return end
		watched[instance] = true
		local obj = instance :: TextLabel
		local connections: { RBXScriptConnection } = {}
		local function apply()
			if not obj.Parent then return end
			local face = obj.FontFace
			if face.Weight.Value < Enum.FontWeight.ExtraBold.Value then
				obj.FontFace = Font.new(face.Family, Enum.FontWeight.ExtraBold, face.Style)
			end
			local ink: UIStroke? = nil
			for _, child in obj:GetChildren() do
				if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
					ink = child
					break
				end
			end
			if not ink then
				ink = Instance.new("UIStroke")
				ink.Name = "ReadabilityInk"
				ink.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
				ink.Parent = obj
			end
			local stroke = ink :: UIStroke
			-- Dark lettering on gold buttons needs a light outline.
			local color = obj.TextColor3
			stroke.Color = if math.max(color.R, color.G, color.B) < 0.3 then Color3.fromRGB(255, 239, 190) else INK
			stroke.Thickness = if obj.TextScaled then 2.5 else math.clamp(obj.TextSize * 0.12, 1.8, 3)
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Transparency = obj.TextTransparency
			obj.TextStrokeTransparency = 1 -- avoid stacking the legacy one-pixel stroke
		end
		apply()
		for _, property in { "FontFace", "TextSize", "TextScaled", "TextColor3", "TextTransparency" } do
			table.insert(connections, obj:GetPropertyChangedSignal(property):Connect(apply))
		end
		table.insert(connections, obj.Destroying:Connect(function()
			for _, connection in connections do connection:Disconnect() end
		end))
	end
	for _, descendant in root:GetDescendants() do task.defer(visit, descendant) end
	return root.DescendantAdded:Connect(function(descendant) task.defer(visit, descendant) end)
end

return TextReadability
