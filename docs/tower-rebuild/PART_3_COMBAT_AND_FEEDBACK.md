# Part 3 of 5: Working combat and damage feedback

Scope revised by the user on 2026-10-21: **working combat and basic feedback through Part 3**. Animation/art polish, Part 4, and Part 5 are deferred until requested again.

Implementation status: **VERIFIED for the revised combat/feedback gate**. The latest main merge and Studio restoration pass 101 CLI regressions and 17 native checks (11 combat/feedback and six travel). See [verification and handoff](PART_3_VERIFICATION.md) and [merge/restoration evidence](MAIN_MERGE_AND_STUDIO_RESTORE_20261021.md). This is the current stopping point.

## Scope

1. Make floors 1 and 5 directly playable with floor-specific enemies and independent boss state. Floor 50 remains a transport fixture. No boss kill unlocks travel.
2. Make normal mobs acquire same-room players/heroes, chase, face, telegraph, attack, recover, leash/reset, die, and respawn. Assigned squads fight while their connected owner is elsewhere.
3. Preserve assignment, recall, roster rebuild, Overdrive, stamina, coma/wipe, cargo, and deliberate-command progression rules. Transfers and rebuilding do not duplicate or heal heroes.
4. Keep attack damage server-authoritative and once-only. Validate floor, room generation, entity generation, target life, range/shape, line of sight, and safe zones at impact. Cancel invalid/dead/transferred attacks. Reconcile late actions and snapshots without ghost hits or repeated damage.
5. Retain boss HP, cooldowns, life identity, respawn deadline, and reward claims across ordinary travel and room rebuilding. Keep physical drops and extraction rules intact.
6. Provide readable basic feedback: HP bars, warnings before damage, hit sparks, floating actual-damage numbers, and cleanup after death/travel. Distinguish enemy hits, incoming damage, and Overdrive without inventing critical hits.
7. Use the current regular, elite, and boss prototype rigs and clips. Preserve their editable sources and action timing interfaces for the later polish sprint.

## Verification gate

- Default combat works on floors 1 and 5 without a Studio-only preview switch.
- A visiting player can participate; an unattended assigned squad leaves arrival and exchanges real attacks.
- Recall and roster rebuilding preserve surviving hero state; travel preserves cargo and safety guarantees.
- Two clients agree on actor identities and action timelines. Late entry, duplicate START, cancellation, attacker death, and target departure do not replay attacks or duplicate rewards.
- Cross-floor/generation damage, targeting, and participation are rejected. Boss state and reward claims survive travel and geometry rebuilding.
- Damage numbers reflect server-applied HP reduction, including overkill clamping. Numbers expire, remain bounded, and clear with the view.
- Production scripts compile and the existing economy, transport, and combat regressions pass. Record what was actually tested and keep unavailable release checks explicit.

## Deferred to a separate sprint

Final enemy model quality, refined animation clips, foot planting/sliding, deformation, weapon/ground contact, cinematic death/awakening, audio, and polished effects are tracked in [Animation and art polish sprint](deferred/ANIMATION_POLISH_SPRINT.md). They do not prevent Part 3 combat completion or activation of the two test floors. Visible warnings before authoritative damage remain required now.

Do not expand into the other nine biomes in this part. Published-place testing and physical-device certification remain later integration/release checks, not animation prerequisites for this combat sprint.

## Handoff

See [Part 3 verification](PART_3_VERIFICATION.md) for changed files, attack timings, executed checks, evidence, enablement, and remaining work. Parts 1–3 are complete for this milestone. Animation/art polish and Parts 4–5 remain in the deferred backlog; no further implementation is scheduled.

## Execution prompt

Finish Part 3 as a working combat slice on floors 1 and 5, including autonomous squads, reliable authoritative attacks, retained boss/reward state, and basic damage feedback. Use existing prototype visuals. Test actual gameplay and transitions, document evidence, and defer animation/art polish to its separate sprint.
