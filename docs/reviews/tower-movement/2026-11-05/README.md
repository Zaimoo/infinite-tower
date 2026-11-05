# Phase 0 movement baseline

Source base: `dd64e5e`, merging main `72236cf`. Core source parity verified through Studio MCP before testing. Only Studio diagnostics and test harnesses were added; movement behavior is unchanged.

The reproduction gate passed:

- Floor 18, Basin to East Gallery, five isolated followers at sprint speed: slots 2 and 5 made 8 and 9 backward steps and fell 92.2 and 103.8 studs behind. Both eventually recovered. Fixed-goal controls all reached their six-stud formation offsets. See `controlled.json.gz`.
- Floor 43, isolated actors invoking the native assigned hero state machine: all five heroes reversed during pursuit (8–11 backward samples each), and each acquired the replacement target after the original died. See `isolated-assigned.json.gz`.
- A deliberately enclosed pursuer remained `MOVE_TO_TARGET` through the ten-second test, ending near its starting position. All 91 samples lacked a stuck tracker; the longest uninterrupted stationary interval was 4.20 seconds. Path queries reported `NoPath`. This confirms pursuit bypasses follow-mode recovery.
- Clean assigned and load captures recorded zero runtime errors. Test obstructions and temporary mob entries were removed; pending path computations drained to zero. Studio play was stopped afterward.

## Performance baseline

These are synthetic movement batches with normal server work in the background, not full multiplayer combat certification. Global query counters include background work. Each load ran for five seconds.

| Load | Actors | Batch CPU time, p95 |
| --- | --- | --- |
| One squad | 5 | 4.43 ms |
| Two opposing squads | 10 | 6.78 ms |
| Six floors | 30 | 18.18 ms |

The clean MicroProfiler snapshot contains 63 frames and four complete native hero scopes (p95 0.62 ms). Native hero tick intervals were approximately 109, 108, and 132 ms. This short capture is a reference, not a performance certification.

Client idle observation: median snapshot interval 217 ms; p95 273 ms. The player was stationary, so this does **not** establish moving render lag. Capture moving render lag during final gameplay verification rather than extending this baseline.

## Evidence and reproduction

`summary.json` contains the compact results. Compressed JSON files contain raw movement traces. `movement-load.json`, `native-profile.json`, `client-idle.json`, and `source-parity.json` contain supporting measurements. Interrupted or invalid trial captures were excluded.

- `tests/studio-tower-movement.luau`: fixed/moving goal control; options select a link, direction, and bounded trace.
- `tests/studio-tower-isolated-assigned.luau`: require from a normal server Script during disposable Studio play. Uses a profile-free owner, held attack cooldowns, and temporary target entries; restores native camp entries in cleanup. Floor 43 must have no real squad/visitor.
- `tests/studio-tower-assigned-baseline.luau`: optional observation of a real assigned squad; detects assignment changes. It is not the accepted isolated reproduction above.
- `tests/studio-tower-movement-load.luau`: one/two/six-floor movement batches.

Next: implement connector/landing geometry and preserve directed ramp progress. Moving render lag, full six-floor combat load, and release acceptance remain for later verification.
