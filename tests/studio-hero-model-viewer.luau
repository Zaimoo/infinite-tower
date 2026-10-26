-- Builds a hero model viewer from code (replaces the hand-made ServerStorage.ModelViewer
-- JennaPreview). Run in Studio, Edit or playtest, after syncing src with Rojo; through Studio
-- MCP, wrap this file's body and call it: `return (function() <file> end)()({ Armed = true })`.
--
-- Options:
--   Parent   Instance to build into (default workspace); a folder named HeroModelViewer is
--            replaced inside it
--   Origin   Vector3 of the first hero's feet (default 0, 0, 0)
--   Spacing  studs between heroes (default 6)
--   Armed    equip each hero's archetype weapon (default false)
--   State    HeroClips state to pose, e.g. "Idle", "AttackBasic" (default "Idle")
--   T        clip time 0..1 to pose (default 0)
--   Play     loop the State clip on every hero until the folder is removed (default false);
--            use with Armed = true and State = "AttackSkill" to review signature ultimates
--   Seconds  loop length when playing (default: the clip's own Duration)
--   HeroId   build only this hero (default: all twelve)
--
-- Every part is anchored and posed by writing CFrames (HeroAnimator.ApplyStaticPose), so the
-- lineup also renders correctly in Edit mode and in ViewportFrames.
return function(options: { [string]: any }?)
	local opts = options or {}
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local HeroRig = ReplicatedStorage.Assets.HeroRig
	local Spec = require(HeroRig.HeroRigSpec)
	local Registry = require(HeroRig.HeroRegistry)
	local Costumes = require(HeroRig.HeroCostumes)
	local Sockets = require(HeroRig.HeroSockets)
	local Clips = require(HeroRig.HeroClips)
	local Animator = require(HeroRig.HeroAnimator)
	local Weapons = require(ReplicatedStorage.Assets.WeaponModelBuilder)
	local Catalog = require(ReplicatedStorage.Shared.Config.HeroCatalog)
	local Artifacts = require(ReplicatedStorage.Shared.Config.ArtifactCatalog)

	local builders = {
		weapon_bow = Weapons.BuildBow,
		weapon_sword_shield = Weapons.BuildSwordShield,
		weapon_daggers = Weapons.BuildDaggers,
		weapon_axe = Weapons.BuildAxe,
		weapon_staff = Weapons.BuildStaff,
		weapon_tome = Weapons.BuildTome,
	}

	local parent = opts.Parent or workspace
	local old = parent:FindFirstChild("HeroModelViewer")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "HeroModelViewer"

	local origin: Vector3 = opts.Origin or Vector3.zero
	local spacing: number = opts.Spacing or 6
	local state: string = opts.State or "Idle"
	local t: number = opts.T or 0
	local built = {}
	local playing = {}
	for index, costume in Costumes.List do
		if opts.HeroId and costume.HeroId ~= opts.HeroId then
			continue
		end
		local pivot = CFrame.new(origin + Vector3.new((index - 1) * spacing, Spec.GROUND_OFFSET, 0))
		local rig = Registry.Build(costume.HeroId, pivot)
		local weaponType = nil
		if opts.Armed then
			weaponType = Artifacts.ArchetypeWeaponType[Catalog.Seeds[costume.HeroId].Archetype]
			Sockets.Equip(rig, builders[Sockets.PREFABS[weaponType]](), weaponType)
		end
		-- Weapon parts are held by WeldConstraints to their handle; posing moves the handle
		-- through its socket Weld, so collect them to follow it.
		local weapon = rig:FindFirstChild("EquippedWeapon") :: Model?
		local followers = {}
		if weapon and weapon.PrimaryPart then
			local subAssemblies = {}
			for _, name in { "OffhandShield", "LeftDagger" } do
				local sub = weapon:FindFirstChild(name)
				if sub and sub:IsA("Model") and sub.PrimaryPart then
					table.insert(subAssemblies, sub)
				end
			end
			for _, d in weapon:GetDescendants() do
				if d:IsA("BasePart") then
					-- Each part follows the handle of the assembly it belongs to (the shield or
					-- off-hand dagger, otherwise the main weapon, including the nocked arrow).
					local primary = weapon.PrimaryPart
					for _, sub in subAssemblies do
						if d:IsDescendantOf(sub) then
							primary = sub.PrimaryPart
						end
					end
					if d ~= primary then
						table.insert(followers, { Part = d, Primary = primary, Offset = primary.CFrame:ToObjectSpace(d.CFrame) })
					end
				end
			end
		end
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local clip = Clips.Get(costume.HeroId, weaponType, state)
		if clip then
			Animator.ApplyStaticPose(rig, Animator.Sample(clip, t))
		end
		for _, f in followers do
			f.Part.CFrame = f.Primary.CFrame * f.Offset
		end
		rig.Parent = folder
		table.insert(built, costume.HeroId)
		if clip and opts.Play then
			table.insert(playing, { Rig = rig, Clip = clip, Followers = followers })
			print(string.format("[HeroModelViewer] %s %s: %.2fs, Release %.2f", costume.HeroId, state, clip.Duration, Clips.Marker(clip, "Release", -1)))
		end
	end
	folder.Parent = parent

	-- Loop the clips by writing static poses each frame (works in Edit mode and playtests), with
	-- a short hold on the start pose between loops so the release frame is easy to spot.
	if #playing > 0 then
		local hold = 0.4
		local started = os.clock()
		task.spawn(function()
			while folder.Parent do
				for _, entry in playing do
					local length = opts.Seconds or entry.Clip.Duration
					local elapsed = (os.clock() - started) % (length + hold)
					Animator.ApplyStaticPose(entry.Rig, Animator.Sample(entry.Clip, math.clamp(elapsed / length, 0, 1)))
					for _, f in entry.Followers do
						f.Part.CFrame = f.Primary.CFrame * f.Offset
					end
				end
				task.wait()
			end
		end)
	end
	return built
end
