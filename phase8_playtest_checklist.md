# Phase 8 Playtest Checklist

## Goal
Phase 8 focuses on readability, decision clarity, and a stable vertical-slice playthrough. The player should understand what changed in their build and why a choice is risky or useful.

## How To Run
```powershell
powershell -ExecutionPolicy Bypass -File G:\FurrySTS\run_game.ps1
```

## Quick Validation
```powershell
powershell -ExecutionPolicy Bypass -File G:\FurrySTS\run_game.ps1 -CheckOnly
powershell -ExecutionPolicy Bypass -File G:\FurrySTS\scripts\tests\run_smoke.ps1
```

## Manual Flow
1. Start from Hub and confirm the selected hero, D6 loadout, equipment slots, and start-run button are visible.
2. Confirm Hub shows a replaceable hero portrait placeholder and background art placeholder.
3. Enter Run and confirm the current node panel shows current build, equipment, enchant summary, and node art placeholder.
4. Resolve a battle node and confirm reward cards explain whether they change D6, equipment, growth, or enchant slots.
5. Pick at least one build-changing reward and confirm the next node details show the changed build.
6. Pick or create at least one enchant reward and confirm the Run detail panel lists die id, face index, and enchant effect.
7. Enter a later battle and confirm the Battle UI shows player/enemy art placeholders and the dice tooltip shows the enchant on the affected face.
8. Visit event, shop, supply, and rest nodes if available; each should present a clear reason to choose or skip.
9. Finish, evacuate, or fail a Run and confirm the result returns to Hub without blocking controls.

## Node Decision Checks
- Event: should offer stable resources, risky build power, or paid/signature enchant routing.
- Event variants: signal/cache/forge events should not feel identical; each should expose at least one unique option.
- Supply: should feel safe and free, with recovery or next-fight stabilization.
- Shop: should show prices clearly, disable unaffordable purchases, and offer a free leave option.
- Rest: should force a clear single pick between run durability, next-fight safety, damage preparation, and Credits.

## Acceptance Checks
- No critical action button is off-screen at 1280x720.
- Placeholder art slots should be visible but must not block clicks or hide critical controls.
- Reward cards must not require code knowledge to understand the effect.
- Reward cards should show a BD hint, for example Cyan reactor burst, Helios mark execution, Aurian counter, or a general economy/safety role.
- A new player can tell what their current D6 build is inside Run.
- A new player can tell which die face has an enchant and what that enchant does.
- Enemy intent should show not only damage, but also whether the enemy is blocking, locking dice, draining resources, taxing rerolls, clearing marks, or countering a build axis.
- Challenge should come from telegraphed resource pressure and timing decisions, not from invisible random punishment.
- Equipment and active item effects must not allow using more than 3 D6 actions per turn.
- Known balance warnings are acceptable; crashes, unreadable text, and blocked controls are not.

## Known Follow-Ups
- Hub does not yet have a long-term enchant inventory or enchant management screen.
- Enemy counter-design exists as a first pass and still needs tuning.
- Story/relationship presentation is still minimal.
