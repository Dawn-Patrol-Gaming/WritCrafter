# WritCrafter: developer notes

The player guide is [README.md](../README.md), which is also installed and uploaded with the add-on. This file stays
in the repository.

## Layout

```
Core/      start-up, saved variables, inventory and prices, exclusion policy, slash commands
Data/      built-in game data: alchemy, smithing, enchanting, station furniture, default prices
Writs/     reading daily and master writs; boards, crates, Rolis, bank, accept guard
Engine/    the crafting engine and one crafter per station type, plus the master writ queue
Solver/    alchemy reagent search
Rules/     whether a master writ is accepted, and why not
Rewards/   writ reward boxes and what happens to their contents
UI/        settings, windows, tooltips, inventory icons, notices, status strip, markers
Strings/   all player-facing text (en.lua)
docs/      design plan, in-game test list, saved variables reference, these notes
scripts/   deploy and offline checks
```

- [PLAN.md](PLAN.md): design, decisions and milestones
- [TESTING.md](TESTING.md): in-game tests still to run
- [SAVEDVARS.md](SAVEDVARS.md): every saved setting and table, and how they work
- [RELEASING.md](RELEASING.md): the ESOUI rules every upload must follow, as a checklist

## Deploying

`scripts\Deploy.ps1` checks the code, then copies exactly what may be uploaded to ESOUI into your
AddOns folder as `AddOns\WritCrafter`: the manifest, every file it loads, and `README.md`.
Anything else in that folder is removed (old files, stray or hidden files, empty folders), so the
installed folder is always ready to zip for an upload. From the repository folder in PowerShell:

```powershell
.\scripts\Deploy.ps1
```

It deploys to `Documents\Elder Scrolls Online\live\AddOns\WritCrafter` (your Windows Documents
folder, wherever it is). To deploy somewhere else, pass the destination; it must end in a folder
named `WritCrafter`:

```powershell
.\scripts\Deploy.ps1 -Destination "E:\Games\Elder Scrolls Online\live\AddOns\WritCrafter"
```

It stops without copying if the manifest lists a missing file or a file type ESOUI doesn't
allow. Saved variables are never touched. If PowerShell refuses to run scripts, use
`powershell -ExecutionPolicy Bypass -File scripts\Deploy.ps1`.

Then `/reloadui` in game, or log out and back in when files were added or removed (the game only
reads the file list at login).

## Packaging for ESOUI

Deploy, then zip the installed `AddOns\WritCrafter` folder itself (not its contents), so the zip
holds one `WritCrafter` folder. Go through [RELEASING.md](RELEASING.md) before uploading.

## Offline checks

Deploy.ps1 runs both checkers when it finds them and refuses to deploy if either reports a
problem:

- `scripts/check.lua`, with **LuaJIT** (Lua 5.1, like the game): every file in the manifest exists
  and compiles, and no accidental globals. Install with `winget install DEVCOM.LuaJIT`.
- `scripts/check_lua.py`, with **Python 3**: local functions called before they're defined,
  `a, b = x and f()`, `tonumber` of a function call, and other mistakes that only fail in game.

Run them by hand from the repository folder:

```powershell
luajit scripts\check.lua
python -I scripts\check_lua.py
```

New Lua files must be added to `WritCrafter.txt` in load order.

## Code-origin check

`scripts/check_origin.py` compares WritCrafter's Lua with other add-ons' and lists anything
shared: identical token runs, the same logic with identifiers renamed, identical lines, and
item IDs in the same order. Every match needs a look: most are game API idioms or game data,
and game data taken from another add-on must be credited in the README. Pass the folders of the
add-ons WritCrafter replaces (they're kept outside `live\AddOns` once disabled):

```powershell
python -I scripts\check_origin.py . "<path>\WritWorthy" "<path>\DolgubonsLazyWritCreator" "<path>\LibLazyCrafting" "<path>\DailyAlchemy" "<path>\DailyProvisioning"
```

Last run 2026-11-22: no logic copied; see PLAN.md §12 for what it found.
