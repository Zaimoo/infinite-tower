--!strict
-- Signed route progress prevents sideways motion and back-and-forth shuffling
-- from continuously resetting recovery. Replanning alone does not reset age.
local Recovery={}
function Recovery.Update(s: any,intent: string,now: number,advance: number,remaining: number): string
	if s.Intent~=intent or not s.LastCall or now-s.LastCall>.5 then
		s.Intent=intent;s.ProgressAt=now;s.Net=0;s.RepathAt=now
	end
	s.LastCall=now
	if remaining<.5 then s.ProgressAt=now;s.Net=0;return "ARRIVED" end
	s.Net+=advance
	if s.Net>=.75 then s.ProgressAt=now;s.Net=0 end
	local age=now-s.ProgressAt
	if age>=3 then return "UNREACHABLE" end
	if age>=1 and now-s.RepathAt>=1 then s.RepathAt=now;return "REPATH" end
	return if advance>.01 then "ADVANCING" else "BLOCKED"
end
function Recovery.Pause(s: any) s.LastCall=nil end
return Recovery
