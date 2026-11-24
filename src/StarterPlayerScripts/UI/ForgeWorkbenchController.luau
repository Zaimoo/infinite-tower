--!strict
-- Smelter Workbench host: server-owned artifact inventory, equipping, star promotion, selling,
-- Open Forge odds/pricing reference, and quick navigation to the Forge Fortress Tree branches.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local App = require(script.Parent.ForgeWorkbench.App)
local InventoryCapacity = require(ReplicatedStorage.Shared.Util.InventoryCapacity)
local FortressTree = require(ReplicatedStorage.Shared.Util.FortressTree)
local RollLuck = require(ReplicatedStorage.Shared.Util.RollLuck)

local Controller = {}
Controller.__index = Controller

local function snapshotFromProfile(profile: any): any
	if not profile then return nil end
	if profile.Revision ~= nil and profile.Gold ~= nil and profile.Artifacts ~= nil then return profile end
	local gold = if profile.Currencies then profile.Currencies.Gold else (profile.Gold or 0)
	local gems = if profile.Currencies then profile.Currencies.Gems else (profile.Gems or 0)
	local snapshot = { Revision = profile.ForgeRevision or 0, Heroes = {}, Artifacts = {}, Gold = gold, Gems = gems }
	for id, hero in profile.Heroes or {} do snapshot.Heroes[id] = table.clone(hero) end
	for id, artifact in profile.Artifacts or {} do snapshot.Artifacts[id] = table.clone(artifact) end
	snapshot.ArtifactCap = InventoryCapacity.ArtifactCap(profile.FortressTree)
	return snapshot
end

function Controller.new(gui: ScreenGui, remotes: Folder, getProfile: () -> any, onClose: (() -> ())?)
	local self: any = setmetatable({}, Controller)
	self.GetProfile = getProfile
	self.OnClose = onClose
	self.Destination = "NONE"
	self.Mode = "EQUIP"
	self.OpenGeneration = 0
	-- HUDController's modal arbitration observes Root.Visible.
	local marker = Instance.new("Frame")
	marker.Name = "ForgeWorkbenchOpenState"
	marker.BackgroundTransparency = 1
	marker.Size = UDim2.fromOffset(0, 0)
	marker.Visible = false
	marker.Parent = gui
	self.Root = marker
	local host = Instance.new("Folder")
	host.Name = "ForgeWorkbenchHost"
	host.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self.ReactRoot = ReactRoblox.createRoot(host)
	self.Request = remotes:WaitForChild("ForgeWorkbenchRequest") :: RemoteFunction
	self.RequestSell = remotes:WaitForChild("RequestSellArtifacts") :: RemoteFunction
	self.Transport = {
		Execute = function(command) return self.Request:InvokeServer("EXECUTE", command) end,
		Reconcile = function(id) return self.Request:InvokeServer("RECONCILE", id) end,
	}
	self.AppCallbacks = {
		OnClose = function() self:Close() end,
		OnOpenUpgrades = function()
			self:Close()
			local openBranch = (_G :: any).OpenFortressBranch
			if type(openBranch) == "function" then
				openBranch("ForgePedestals")
			elseif type((_G :: any).OpenFacilityHUD) == "function" then
				(_G :: any).OpenFacilityHUD("FortressTree")
			end
		end,
		OnSell = function() self:OpenSell() end,
		OnSellArtifacts = function(ids)
			local ok, message = self.RequestSell:InvokeServer(ids)
			local fresh = self.Request:InvokeServer("STATE")
			self.Snapshot = fresh
			self:_render()
			return ok, message
		end,
		OnSnapshot = function(snapshot)
			if not self.Snapshot or snapshot.Revision >= self.Snapshot.Revision then self.Snapshot = snapshot end
		end,
		OnContextChanged = function(heroId, artifactId, mode)
			self.HeroId, self.ArtifactId, self.Mode = heroId, artifactId, mode
		end,
		OnBusyChanged = function(busy) self.Busy = busy end,
	}
	return self
end

function Controller:_render()
	if (self.Destination ~= "ARTIFACTS" and self.Destination ~= "SELL") or not self.Snapshot then return end
	local profile = self.GetProfile()
	local rollLuck = if profile then RollLuck.ForProfile(profile) else 0
	local pedestals = if profile then FortressTree.ForgePedestals(profile.FortressTree) else 1
	self.ReactRoot:render(React.createElement(App, {
		key = self.OpenGeneration,
		Snapshot = self.Snapshot,
		Transport = self.Transport,
		RollLuck = rollLuck,
		Pedestals = pedestals,
		InitialHeroId = self.HeroId,
		InitialArtifactId = self.ArtifactId,
		InitialMode = self.Mode,
		OnClose = self.AppCallbacks.OnClose,
		OnOpenUpgrades = self.AppCallbacks.OnOpenUpgrades,
		InitialPane = if self.Destination == "SELL" then "SELL" else "INVENTORY",
		OnSellArtifacts = self.AppCallbacks.OnSellArtifacts,
		OnSell = self.AppCallbacks.OnSell,
		OnSnapshot = self.AppCallbacks.OnSnapshot,
		OnContextChanged = self.AppCallbacks.OnContextChanged,
		OnBusyChanged = self.AppCallbacks.OnBusyChanged,
	}))
end

function Controller:Open(initialTab: string?)
	if _G.SetModalFocusMode then
		_G.SetModalFocusMode(true)
	end
	self.Destination = "ARTIFACTS"
	self.Root.Visible = true
	self.Mode = if initialTab == "UPGRADE" then "UPGRADE" else "EQUIP"
	self.OpenGeneration += 1
	local generation = self.OpenGeneration
	local profile = self.GetProfile()
	if profile then self.Snapshot = snapshotFromProfile(profile); self:_render() end
	task.spawn(function()
		local ok, snapshot = pcall(function() return self.Request:InvokeServer("STATE") end)
		if self.OpenGeneration ~= generation or self.Destination ~= "ARTIFACTS" then return end
		if ok and type(snapshot) == "table" then
			if not self.Snapshot or snapshot.Revision >= self.Snapshot.Revision then self.Snapshot = snapshot end
			self:_render()
		elseif not self.Snapshot then self:Close() end
	end)
end

function Controller:OpenSell()
	if _G.SetModalFocusMode then
		_G.SetModalFocusMode(true)
	end
	self.Destination = "SELL"
	self.OpenGeneration += 1
	self.Root.Visible = true
	local profile = self.GetProfile()
	if profile then self.Snapshot = snapshotFromProfile(profile) end
	self:_render()
end

function Controller:IsOpen(): boolean
	return self.Destination ~= "NONE" or (self.Root ~= nil and self.Root.Visible)
end

function Controller:Close()
	self.OpenGeneration += 1
	self.Destination = "NONE"
	self.Root.Visible = false
	self.ReactRoot:render(nil)
	if _G.SetModalFocusMode then
		_G.SetModalFocusMode(false)
	end
	if self.OnClose then self.OnClose() end
end

function Controller:Refresh()
	if not self.Root.Visible then return end
	local profile = self.GetProfile()
	if not profile then return end
	local nextSnapshot = snapshotFromProfile(profile)
	if not self.Snapshot or nextSnapshot.Revision >= self.Snapshot.Revision then self.Snapshot = nextSnapshot; self:_render() end
end

return Controller
