--!strict
-- Phase 6 penalties and run-loop tuning. Plain data; every value is a working number to tune in playtest.
local Config = {}

-- A downed hero stands back up on a floor transition at this fraction of max HP.
Config.ReviveHPFraction = 0.30
-- Recalling an assigned squad (to any floor) heals every hero this fraction of max HP
-- (downed heroes stand back up at it). Recalling to the hub heals fully.
Config.RecallFloorHealFraction = 0.30
-- An assigned squad (until recalled) sends knocked-out heroes to the floor's sanctuary. Once the
-- whole squad is down it heals fully there and heads back out after this many seconds.
Config.AssignedRegroupSeconds = 4
-- Standing heroes inside a tower sanctuary heal this fraction of max HP per second.
Config.SanctuaryHealPerSecond = 0.10
-- A wipe removes this fraction of the Gold and Gems earned since the last bank in the run.
Config.WipeLossFraction = 0.25
-- Climb streak: each cleared floor in a row adds this to banked relic value, up to the cap.
Config.StreakBonusPerFloor = 0.10
Config.StreakBonusCap = 1.0
-- Gems a brand-new profile starts with (one 10-pull with its guaranteed Rare).
Config.StarterGems = 900

return table.freeze(Config)
