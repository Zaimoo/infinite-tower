--!strict
-- Actual Forge host. Real profile/receipts in the React workbench, original summon and sell flows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local App = require(script.Parent.ForgeWorkbench.App)
local LegacyForge = require(script.Parent.ForgeController)

local Controller = {}
Controller.__index = Controller

local function snapshotFromProfile(profile: any): any
	local snapshot = { Revision = profile.ForgeRevision or 0, Heroes = {}, Artifacts = {}, Gold = profile.Currencies.Gold, Gems = profile.Currencies.Gems }
	for id, hero in profile.Heroes or {} do snapshot.Heroes[id] = table.clone(hero) end
	for id, artifact in profile.Artifacts or {} do snapshot.Artifacts[id] = table.clone(artifact) end
	return snapshot
end

function Controller.new(gui: ScreenGui, remotes: Folder, getProfile: () -> any, onClose: (() -> ())?)
	local self: any = setmetatable({}, Controller)
	self.GetProfile = getProfile
	self.OnClose = onClose
	self.Destination = "NONE"
	self.Mode = "EQUIP"
	self.OpenGeneration = 0
	-- HUDController's existing modal arbitration observes Root.Visible. This transparent marker
	-- represents BOTH destinations without placing the new UI inside the old scaled window.
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
	self.Transport = {
		Execute = function(command) return self.Request:InvokeServer("EXECUTE", command) end,
		Reconcile = function(id) return self.Request:InvokeServer("RECONCILE", id) end,
	}
	self.Legacy = LegacyForge.new(gui, remotes, getProfile, function()
		if not self.Switching then self:Close() end
	end)
	local legacySetTab = self.Legacy.SetTab
	self.Legacy.AssignTabBtn.Text = "ARTIFACTS"
	self.Legacy.UpgradeTabBtn.Text = "SELL ARTIFACTS"
	-- The original upgrade button also calls SetTab("UPGRADE"). Route that intent to SELL here;
	-- the only upgrade destination is now the shared React detail panel.
	self.Legacy.SetTab = function(legacy, tab)
		if tab == "SUMMON" or self.OpeningSell then legacySetTab(legacy, tab)
		elseif tab == "UPGRADE" then self:OpenSell()
		else self:Open("ASSIGN") end
	end
	local legacyToggleSell = self.Legacy.ToggleSellMode
	self.Legacy.ToggleSellMode = function(legacy, enabled)
		if enabled == false and self.Destination == "SELL" then self:Open("ASSIGN")
		else legacyToggleSell(legacy, enabled) end
	end
	local legacyRefresh = self.Legacy.Refresh
	self.Legacy.Refresh = function(legacy)
		if self.Destination == "SELL" and not self.OpeningSell and not legacy.Busy and not legacy.SellMode then
			self:Open("ASSIGN")
		else legacyRefresh(legacy) end
	end
	self.AppCallbacks = {
		OnClose = function() self:Close() end,
		OnSummon = function() self:Open("SUMMON") end,
		OnSell = function() self:OpenSell() end,
		OnSnapshot = function(snapshot)
			if not self.Snapshot or snapshot.Revision >= self.Snapshot.Revision then self.Snapshot = snapshot end
		end,
		OnContextChanged = function(heroId, artifactId, mode)
			self.HeroId, self.ArtifactId, self.Mode = heroId, artifactId, mode
		end,
	}
	return self
end

function Controller:_hideLegacy()
	self.Switching = true
	self.Legacy:Close()
	self.Switching = false
end

function Controller:_render()
	if self.Destination ~= "ARTIFACTS" or not self.Snapshot then return end
	self.ReactRoot:render(React.createElement(App, {
		key = self.OpenGeneration,
		Snapshot = self.Snapshot, Transport = self.Transport,
		InitialHeroId = self.HeroId, InitialArtifactId = self.ArtifactId, InitialMode = self.Mode,
		OnClose = self.AppCallbacks.OnClose, OnSummon = self.AppCallbacks.OnSummon,
		OnSell = self.AppCallbacks.OnSell, OnSnapshot = self.AppCallbacks.OnSnapshot,
		OnContextChanged = self.AppCallbacks.OnContextChanged,
	}))
end

function Controller:Open(initialTab: string?)
	if initialTab == "SUMMON" then
		self.Destination = "SUMMON"
		self.OpenGeneration += 1
		self.ReactRoot:render(nil)
		self.Root.Visible = true
		self.Switching = true
		self.Legacy:Open("SUMMON")
		self.Switching = false
		return
	end
	self:_hideLegacy()
	self.Destination = "ARTIFACTS"
	self.Root.Visible = true
	if initialTab == "UPGRADE" then self.Mode = "UPGRADE" end
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
	self.Destination = "SELL"
	self.OpenGeneration += 1
	self.ReactRoot:render(nil)
	self.Root.Visible = true
	self.OpeningSell = true
	self.Legacy:Open("ASSIGN")
	self.OpeningSell = false
	self.Legacy:ToggleSellMode(true)
end

function Controller:Close()
	self.OpenGeneration += 1
	self.Destination = "NONE"
	self.Root.Visible = false
	self.ReactRoot:render(nil)
	self:_hideLegacy()
	if self.OnClose then self.OnClose() end
end

function Controller:Refresh()
	if not self.Root.Visible then return end
	if self.Destination == "SUMMON" or self.Destination == "SELL" then self.Legacy:Refresh(); return end
	local profile = self.GetProfile()
	if not profile then return end
	local nextSnapshot = snapshotFromProfile(profile)
	if not self.Snapshot or nextSnapshot.Revision >= self.Snapshot.Revision then self.Snapshot = nextSnapshot; self:_render() end
end

return Controller
