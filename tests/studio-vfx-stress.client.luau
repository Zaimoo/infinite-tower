-- Combat VFX stress test (docs/projectile-skill-vfx-plan.md, Phase 6). Run on the CLIENT of a
-- playtest after syncing src with Rojo: in Studio's Command Bar switch the context to Client,
-- or through Studio MCP run it in the client datamodel, as
--   (function() <file> end)()({ Heroes = 30, Seconds = 10 })
--
-- It plays fake HERO_CUEs for all 12 heroes around the camera on a private pool (the game's own
-- effects are untouched) at a typical attack rate, then prints and returns:
--   AvgStepMs / PeakStepMs  cost of CombatVfx.Step per frame (target: under 1 ms average)
--   PeakLive, Refused       live effects at the busiest frame, effects refused over budget
--   AvgFps                  frame rate during the run
--
-- Options:
--   Heroes    simulated heroes attacking (default 30: six full squads)
--   Seconds   run length (default 10)
--   Quality   "High" | "Medium" | "Low" (default: the player's setting)
--   Rate      attacks per hero per second (default 1.25)
return function(options: { [string]: any }?)
	local opts = options or {}
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")
	assert(RunService:IsClient(), "run the VFX stress test on the client")

	local CombatVfx = ReplicatedStorage.Assets.CombatVfx
	local SkillVfx = require(CombatVfx.SkillVfx)
	local VfxPool = require(CombatVfx.VfxPool)
	local VfxPrimitives = require(CombatVfx.VfxPrimitives)
	local HeroClips = require(ReplicatedStorage.Assets.HeroRig.HeroClips)
	local Catalog = require(ReplicatedStorage.Shared.Config.SkillVfxCatalog)

	local heroCount: number = opts.Heroes or 30
	local seconds: number = opts.Seconds or 10
	local rate: number = opts.Rate or 1.25
	local pool = VfxPool.new(Workspace)
	pool.Folder.Name = "VfxStressTest"
	-- Same rule as EntityRenderer: the lower of the Settings UI choice and Roblox's graphics slider,
	-- unless the Quality option forces one.
	local VfxQuality = require(CombatVfx.VfxQuality)
	local chosen = VfxQuality.Lower(
		VfxQuality.Parse(Players.LocalPlayer:GetAttribute("Settings_Quality")),
		VfxQuality.FromRobloxLevel(UserSettings().GameSettings.SavedQualityLevel.Value)
	)
	pool:SetQuality(opts.Quality or chosen)
	VfxPrimitives.Prewarm(pool)

	local heroIds = {}
	for heroId in Catalog.Heroes do
		table.insert(heroIds, heroId)
	end
	table.sort(heroIds)

	local camera = Workspace.CurrentCamera
	local focus = camera.CFrame.Position + camera.CFrame.LookVector * 30
	focus = Vector3.new(focus.X, camera.CFrame.Position.Y - 4, focus.Z)
	local rng = Random.new(7)

	-- Each simulated hero stands on a ring around the focus and attacks a point near the centre.
	local actors = {}
	for i = 1, heroCount do
		local angle = i / heroCount * math.pi * 2
		local heroId = heroIds[(i - 1) % #heroIds + 1]
		table.insert(actors, {
			HeroId = heroId,
			Weapon = HeroClips.OverrideWeapon[heroId],
			Position = focus + Vector3.new(math.cos(angle) * 18, 0, math.sin(angle) * 18),
			NextAt = rng:NextNumber(0, 1 / rate),
			Attacks = 0,
		})
	end
	local allies = {}
	for i = 1, 5 do
		table.insert(allies, actors[i].Position)
	end

	local function cueFor(actor: any, now: number): any
		actor.Attacks += 1
		-- Basic, Basic, Special, ... with an ultimate every 15th attack (the gauge rhythm).
		local tier = if actor.Attacks % 15 == 0 then 3 elseif actor.Attacks % 3 == 0 then 2 else 1
		local aim = focus + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		local ranged = actor.Weapon == "BOW" or actor.Weapon == "STAFF" or actor.Weapon == "TOME"
		return {
			Tier = tier,
			NetId = 1000 + actor.Attacks,
			EntityGeneration = 1,
			CastSeconds = 1,
			ReleaseSeconds = 0,
			TravelSeconds = if tier == 3 then 0.35 elseif ranged then 0.25 else 0,
			StartServerTime = now,
			Aim = aim,
		}
	end

	local frames, totalStep, peakStep, peakLive, refused = 0, 0, 0, 0, 0
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		local now = Workspace:GetServerTimeNow()
		local elapsed = os.clock() - started
		for _, actor in actors do
			if elapsed >= actor.NextAt then
				actor.NextAt += 1 / rate
				local cue = cueFor(actor, now)
				local origin = actor.Position + Vector3.new(0, 2.5, 0)
				SkillVfx.Play(pool, {
					HeroId = actor.HeroId,
					WeaponType = actor.Weapon,
					Cue = cue,
					Origin = origin,
					Target = function(): Vector3
						return cue.Aim + Vector3.new(0, 2, 0)
					end,
					Self = function(): Vector3
						return actor.Position
					end,
					Allies = function()
						return allies
					end,
					RecentHits = function(_kind: string, center: Vector3, radius: number): { Vector3 }
						return { center + Vector3.new(math.min(radius, 4), 0, 0), center - Vector3.new(0, 0, math.min(radius, 4)) }
					end,
					Now = now,
					Owned = actor.HeroId == heroIds[1],
				})
			end
		end
		local before = os.clock()
		pool:Step(now, dt)
		local stepMs = (os.clock() - before) * 1000
		frames += 1
		totalStep += stepMs
		peakStep = math.max(peakStep, stepMs)
		peakLive = math.max(peakLive, pool:Count()) -- Stats() would reset the refused counter
	end)

	task.wait(seconds)
	connection:Disconnect()
	local stats = pool:Stats()
	refused += stats.Refused
	pool:Clear()
	pool.Folder:Destroy()

	local result = {
		Heroes = heroCount,
		Frames = frames,
		AvgFps = math.round(frames / seconds),
		AvgStepMs = math.round(totalStep / math.max(1, frames) * 1000) / 1000,
		PeakStepMs = math.round(peakStep * 1000) / 1000,
		PeakLive = peakLive,
		Refused = refused,
		Quality = stats.Quality,
	}
	print(string.format("[VfxStress] %d heroes, %ds at %s: avg %.3f ms, peak %.3f ms, peak live %d, refused %d, %d fps",
		result.Heroes, seconds, result.Quality, result.AvgStepMs, result.PeakStepMs, result.PeakLive, result.Refused, result.AvgFps))
	return result
end
