# Assigned vs Active Squad: UX Plan

Status: mostly implemented (see GDD §2.5, run loop item 6, "Commands" and "Readability").

| Item | State |
| --- | --- |
| §1 Mode badge and card rail colour | Done (`Hud/Components.SquadStatusCard`, `Hud/HudApp`) |
| §2 Sanctuary and Regroup chips | Done. The regroup countdown comes from `SquadStatus.RegroupIn`. The Recalled chip is suppressed while assigned but still keys off the local cooldown |
| §3 Mode switch banners and regroup strip | Done (`SquadModeBanner` in `HudApp`, `Components.ModeBanner`). No sounds yet |
| §4 `[E]` relabel, Focus and Overdrive greyed out | Done (`Hud/Whistles`, `Input/MasterController`), gated on the server too. The one-time first-assign hint is not built |
| §5 World readability | Teal hero outline done (`EntityRenderer`). Resting pose and dotted line not built |
| §6 Tower menu | Recall shows its heal and greys out while active; Assign reads ASSIGNED HERE or MOVE SQUAD HERE; plain-language errors. The split between recall here and recall to me, and per-floor squad status, are not built |
| Open question 1 (commands while assigned) | Decided: blocked |
| Legacy HUD | Wrong "100% revive" text fixed; wipe and partial banners hidden while assigned |

## The two loops

| | **Active** (default) | **Assigned** |
| --- | --- | --- |
| How you enter it | Deploy, `[E]` recall, or Recall in the tower menu | Assign in the tower menu |
| Where the squad is | Follows the Master | Roams its assigned floor around the floor anchor, whether or not the Master is there |
| Knockout | Hero collapses where it falls and stays down until a floor change or going home | Hero is carried to the floor's sanctuary |
| Whole squad down | Wipe: carried relic, streak and 25% of unbanked Gold and Gems are lost, and the Master goes home | Heals fully in the sanctuary after 4 s and heads back out, with no penalty |
| Master commands | Focus (click), Overdrive `[Q]`, Recall `[E]` | Recall `[E]` only (see open question 1) |
| Rewards | Everything | Kill Gold, Gems and XP anywhere; relics and floor progress only with the Master on the floor |
| How you leave it | Assign | Recall (tower menu or `[E]`): +30% HP on a floor, 100% at the hub |

The problem today: nothing on screen says which loop the squad is in. This matters most when the Master stands on the assigned floor, because both loops then look the same, but the knockout rules, the wipe stakes and the controls differ. The player should always be able to answer three questions at a glance: whether the squad is with them, what happens if it goes down, and how to get it back.

## 1. Mode badge on the Squad Status Card (highest value)

`Hud/Components.SquadStatusCard`, header row ("Squad Status").

- Add a pill to the right of the header:
  - Active: **WITH YOU**, warm orange. Hover or long-press text: "Knockouts stay down · wipe ends the run".
  - Assigned: **ASSIGNED · F12**, teal. Hover or long-press text: "Knockouts rest at sanctuary · press E to recall".
- Data: `Self.SquadAssignment` is already published by `TowerFloorService.Context`, and `TowerController` already reads it. Pass it into `HudApp.buildRows` as a prop.
- While assigned, tint the card border teal so the mode reads at a glance on mobile, where the pill is small.

## 2. Per-hero chips for the assigned loop

`STATE_CHIPS` in `Components.luau`, populated in `HudApp.buildRows`.

- **Sanctuary** (green-teal): an assigned hero that is knocked out and resting. Replaces "Down", which in the active loop means "lost until a floor change". The server sends this as a new `HERO_STATES` enum value, derived from `RestingFloor`; it does not change the save.
- **Regrouping 3s** on every tile while `AssignedRegroupAt` is pending, with the countdown. This needs a field on the existing `SquadStatus` remote payload.
- Fix the existing **Recalled** chip: it currently keys off the local whistle cooldown, so it lights up even when the recall was rejected. Drive it from the server context instead.

## 3. Mode switch moments

These are the moments where the player crosses between loops. Each one should be unmistakable, not just a toast.

- **Assign:** banner "Squad assigned to Floor N. It fights on its own until you recall it." Play a short horn sound, and the squad visibly marches off toward the floor anchor.
- **Recall:** banner "Squad recalled: +30% HP. With you again." Play a whistle sound, and show a brief teal-to-orange ring pulse on each hero as it snaps back.
- **Assigned wipe → regroup:** a centred, non-blocking strip: "Squad fell on Floor N · regrouping in 4… 3…". This replaces the current WARN toast, which reads like a failure.
- **Active wipe:** keep the existing hard red treatment. The contrast between the two wipe screens is the point.

## 4. Input affordances

`Input/MasterController.client.luau`, right rail.

- While assigned, relabel the `[E]` button **Recall Squad**, with a teal ring and the floor number. While active, label it **Regroup**. The same key does a different job, so the label should say so.
- While assigned, grey out Focus and Overdrive with the tooltip "Recall your squad to command it" (see open question 1).
- On the first assign of a session, show a one-time hint under the button: "Press E anywhere to bring them back."

## 5. World readability with the Master on the assigned floor

`Rendering/EntityRenderer.client.luau`.

- Assigned heroes get a thin teal ground ring under their feet; active heroes get no ring, as today. This tells you that "those heroes next to me are not guarding me".
- Knocked-out heroes resting in the sanctuary use a kneeling/resting pose and a soft green glow, not the collapsed knockout pose.
- Optionally, show a faint dotted line from the Master to the squad centre when the Master is on the assigned floor and more than about 40 studs from the squad. Use it only if the ring alone tests poorly.

## 6. Tower menu

`UI/TowerController.client.luau`, floor list (it already tags floors as SQUAD and YOU + SQUAD).

- Split the action buttons by loop. On the squad's floor, show **Recall here** and **Recall to me** as separate buttons instead of a single Recall.
- Show the heal each recall would give: "+30% HP" or "Full heal (hub)".
- Add a short status line under the SQUAD tag: "farming · 4/5 standing" or "regrouping".

## Open questions

1. **Commands while assigned.** The server currently still accepts Focus (`FocusTargetRemote`) when the Master is on the assigned floor, and Overdrive anywhere. A clean split says that an assigned squad ignores Master commands. Recommendation: block Focus and Overdrive while assigned (a small server change), and keep `[E]` as the one bridge back to the active loop.
2. **Penalty-free farming next to the Master.** The Master can assign the squad to the floor they are on and fight beside it with no wipe risk. The cost is no command over the squad, and the squad roams instead of escorting the Master. If that proves too strong in playtests, the assigned loop on the Master's own floor could withhold relics, which are already the Master-present reward.
3. **Should a recall on the same floor cost anything?** Right now recalling an assigned squad on the floor you are on gives +30% HP and revives knocked-out heroes. That is generous: assign, wipe, recall gives a free revive at 30%. The 6 s recall cooldown and the 4 s regroup limit how often this can happen, so it is probably fine. Watch it in the playtest.

## Suggested build order

1. Mode badge and `[E]` relabel (§1, §4). Client-only; the data already exists.
2. Sanctuary and Regrouping chips (§2). Small server payload addition.
3. Mode switch banners (§3).
4. World rings and resting pose (§5).
5. Tower menu split (§6).
6. Command gating (open question 1), once decided.
