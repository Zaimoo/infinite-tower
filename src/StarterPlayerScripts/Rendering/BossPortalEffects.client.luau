--!strict
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local TAG = "BossPortalVortex"
local active: { [Instance]: Tween } = {}

local function animate(instance: Instance)
	if not instance:IsA("BasePart") or active[instance] then return end
	local tween = TweenService:Create(instance, TweenInfo.new(1.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.67,
		Size = instance.Size * 0.93,
	})
	active[instance] = tween
	tween:Play()
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(animate)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
	local tween = active[instance]
	if tween then
		tween:Destroy()
		active[instance] = nil
	end
end)
for _, instance in CollectionService:GetTagged(TAG) do
	animate(instance)
end
