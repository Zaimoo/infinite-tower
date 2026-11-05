param([string]$OutputPath = (Join-Path $env:TEMP 'forge-workbench-preview.luau'))
$ErrorActionPreference = 'Stop'
$sourceMap = @{}
Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'ForgeWorkbench') -Filter '*.luau' | ForEach-Object {
    $sourceMap[$_.BaseName] = [System.IO.File]::ReadAllText($_.FullName)
}
foreach ($name in @('Fixture', 'DemoTransport')) {
    $sourceMap[$name] = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot ($name + '.luau')))
}
$json = ConvertTo-Json -InputObject $sourceMap -Compress -Depth 5
# JSON is data inside a Luau long string, not shell code. These sources do not contain ]====].
if ($json.Contains(']====]')) { throw 'Unexpected long-string delimiter in source' }
$prefix = "local sourceMap = game:GetService('HttpService'):JSONDecode([====[$json]====])`n"
$harness = @'
local nativeRequire = require
local ui = game:GetService("StarterPlayer").StarterPlayerScripts.UI
local nodes, loaded = {}, {}
local folder = { Parent = ui }
local package = { ForgeWorkbench = folder }
for name in sourceMap do
    nodes[name] = { Name = name, Parent = if name == "Fixture" or name == "DemoTransport" then package else folder }
    if name == "Fixture" or name == "DemoTransport" then package[name] = nodes[name] else folder[name] = nodes[name] end
end
local fakeScripts = Instance.new("Folder")
local proxy = {}
function proxy:GetService(name)
    if name == "Players" and not game:GetService("Players").LocalPlayer then
        return { LocalPlayer = { WaitForChild = function() return fakeScripts end } }
    end
    return game:GetService(name)
end
local function localRequire(module)
    if typeof(module) == "Instance" then return nativeRequire(module) end
    if loaded[module] ~= nil then return loaded[module] end
    local compiled, err = loadstring("return function(script, require, game)\n" .. sourceMap[module.Name] .. "\nend", module.Name)
    assert(compiled, err)
    loaded[module] = compiled()(module, localRequire, proxy)
    return loaded[module]
end
if _G.ForgeWorkbenchReview then _G.ForgeWorkbenchReview.Close() end
local React = nativeRequire(game.ReplicatedStorage.Packages.React)
local ReactRoblox = nativeRequire(game.ReplicatedStorage.Packages.ReactRoblox)
local initial = localRequire(nodes.Fixture)()
local transport = localRequire(nodes.DemoTransport)(initial)
local host = Instance.new("Folder")
host.Name = "ForgeWorkbenchReviewHost"
host.Parent = game:GetService("CoreGui")
local root = ReactRoblox.createRoot(host)
local closed = false
local errors = {}
local logConnection = game:GetService("LogService").MessageOut:Connect(function(message, kind)
    if kind == Enum.MessageType.MessageError then table.insert(errors, message) end
end)
local function close()
    if closed then return end
    closed = true
    root:unmount(); host:Destroy(); fakeScripts:Destroy(); logConnection:Disconnect()
    _G.ForgeWorkbenchReview = nil
end
local function render(width, height, mode, pane)
    local appProps = {
        key = (mode or "EQUIP") .. (pane or "DETAILS"),
        Snapshot = initial, Transport = transport, OnClose = close,
        OnSummon = function()
            local existing = _G.ForgeController
            if existing then close(); existing:Open("SUMMON"); return end
            -- Edit-mode preview: reuse the real banner with fake remotes, so no purchase can occur.
            local gui = Instance.new("ScreenGui")
            gui.Name = "ForgeSummonReview"
            gui.ResetOnSpawn = false
            gui.DisplayOrder = 81
            gui.Parent = game:GetService("CoreGui")
            local remotes = Instance.new("Folder")
            for _, name in {"RequestSummonArtifact", "RequestUpgradeArtifact", "RequestEquipArtifact", "RequestUnequipArtifact", "RequestSellArtifacts", "RequestToggleArtifactLock"} do
                local remote = Instance.new("RemoteFunction"); remote.Name = name; remote.Parent = remotes
            end
            local profile = {Heroes=initial.Heroes,Artifacts=initial.Artifacts,Currencies={Gold=initial.Gold,Gems=initial.Gems},ArtifactBannerPity=0,ArtifactBanner10Pity=0}
            local controller
            controller = nativeRequire(ui.ForgeController).new(gui,remotes,function() return profile end,function() gui:Destroy(); remotes:Destroy() end)
            controller.PerformSummon = function() print("Summon banner review only: no currency spent.") end
            close()
            controller:Open("SUMMON")
            task.delay(300,function() if gui.Parent then controller:Close() end end)
        end,
        InitialHeroId = "hero-jenna-0001", InitialArtifactId = "bow-target", InitialMode = mode or "EQUIP",
        InitialPane = pane,
    }
    _G.ForgeWorkbenchReview.OpenSummon = appProps.OnSummon
    root:render(React.createElement(localRequire(nodes.App), appProps))
end
_G.ForgeWorkbenchReview = { Close = close, Host = host, Render = render, Transport = transport, Nodes = nodes, Require = localRequire, Snapshot = initial, Errors = errors }
render()
task.delay(300, function() if not closed then close() end end)
return "Mounted synthetic Forge review in CoreGui; no profile or place scripts changed. Auto-cleanup in five minutes."
'@
[System.IO.File]::WriteAllText($OutputPath, ($prefix + $harness), [System.Text.UTF8Encoding]::new($false))
Write-Output $OutputPath
