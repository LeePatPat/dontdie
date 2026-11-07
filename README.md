# Don't Die (At Your Desk)

A small movement-reminder addon targeting Blizzard's **World of Warcraft: Forever**, interface `16001`.

| Trigger | Reminder |
| --- | --- |
| Level gained | 20 star jumps |
| New area discovered | 10 squats |
| Flight path | Stand and stretch until landing |
| Dungeon party wipe | 10 push ups |

Reminders appear in a draggable panel with an alert sound. Exercises remain owed until you choose **Done**. **Skip** closes the panel and keeps the work as debt for the next reminder. Each popup lists all outstanding work, including its current exercise. The addon hides the panel during combat and resumes afterward unless you skipped it. Flights take priority; queued repetitions wait until landing. Landing plays an alert and prints a message unless you skipped the flight reminder. Pending exercises save per character through reloads and logouts. Completion is self-reported.

## Install

1. Copy the `DontDie` folder into your Forever client's `Interface/AddOns` directory.
2. Confirm the layout is `Interface/AddOns/DontDie/DontDie.toc`, with the three Lua files beside it.
3. Restart the client or type `/reload` if it already recognizes the addon.
4. Enable **Don't Die (At Your Desk)** in the character selection AddOns list.
5. Enter the game and type `/dd test` to preview an exercise reminder.

If a later patch marks the addon out of date, check the client's interface number with `/dump select(4, GetBuildInfo())`. The manifest targets `16001`; a new version requires compatibility verification before updating it.

## Commands

- `/dd` or `/dontdie`: show command help.
- `/dd test`: queue a 20-star-jump reminder.
- `/dd done`: complete the visible reminder.
- `/dd skip`: close the visible reminder and keep its exercise owed. The next new reminder brings back outstanding work.
- `/dd wipe`: manually queue 10 push ups when automatic detection cannot see the party.
- `/dd history`: print lifetime exercise totals and the latest 10 timestamped completions in chat.
- `/dd debt`: list all outstanding exercises in chat, including skipped work. Prints an empty-state message when nothing is owed.

## Completion history

**Done** and `/dd done` record and clear only the current exercise. **Skip** and `/dd skip` do not count as completion or erase debt. An unskipped flight automatically records one flight stretch break on landing; this records the reminder's completion, not proof that you stretched. Flight duration is not tracked.

Skipping a flight adds one manual stretch break to the queue. That debt remains after landing until you complete it with **Done**. It appears in history separately from automatic flight breaks. Reloading during a skipped flight does not add the same debt twice.

The next level, discovery, wipe, or new flight reopens reminders with all owed work listed. Combat changes and flight polling do not immediately reopen a skipped popup. Reloading restores outstanding work and may show it again. Previously discarded skips from older versions cannot be recovered.

Use `/dd debt` to check the queue at any time, including during combat or a flight. Listing debt does not reopen a skipped reminder, complete exercises, or change history. The list includes queued repetitions and missed-flight stretch breaks; an ongoing unskipped flight remains a live reminder until landing.

History saves per character through reloads and logouts. Lifetime totals remain even after older entries leave the latest-10 list. Previously queued reminders still count when completed, but completions from before this update cannot be recovered. `/dd test` creates a normal exercise reminder, so completing it also counts.

## Detection and limits

- Levels use `PLAYER_LEVEL_UP`.
- Discoveries match the client's localized `ERR_ZONE_EXPLORED_XP` and `ERR_ZONE_EXPLORED` system messages. Ordinary zone changes do not count. Discoveries without either message cannot be detected by this version.
- Flights poll `UnitOnTaxi("player")` twice per second. Opening the flight map does not trigger a break. Reloading mid-flight restores the stretch reminder.
- Wipes check for an all-dead party inside a five-player dungeon after combat. This covers trash and boss wipes, without treating a boss reset as a wipe. It requires a prior observation of a living member and visible, connected party members. Solo deaths, raids, and parties already dead on login do not count. Restricted or unavailable unit state is ignored; use `/dd wipe` for these cases.
- No external libraries, automation, exercise sensing, or network service.

## Verification

Run from the repository root:

```sh
lua tests/run.lua
for file in DontDie/*.lua tests/*.lua; do luac -p "$file" || exit; done
```

The Lua harness checks queue persistence, combat deferral, flights, discovery messages, event routing, and wipe deduplication. It mocks the game API; it does not prove the live client delivers those events or messages.

Live-client acceptance still required: test a real level, discovery, flight, and full-party dungeon wipe; confirm the panel hides during combat and pending reminders survive `/reload`.

API reference: [Blizzard's Forever UI source mirror](https://github.com/Gethe/wow-ui-source/tree/forever). The [published version](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/version.txt) was `1.60.1.70790` when checked. Client API declarations include [UnitOnTaxi](https://raw.githubusercontent.com/Gethe/wow-ui-source/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua).
