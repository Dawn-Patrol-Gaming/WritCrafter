# WritCrafter

An Elder Scrolls Online add-on that crafts everything your daily and master writs need, skips
writs you don't want, and spends the materials you have the most of.

Open a crafting station and the items for your writs are made. Writ boards, delivery crates and
Rolis Hlaalu are handled for you, and the boxes you get back are opened and sorted.

> **Status:** pre-release (0.1.0), in active development and tested on one account. Built for
> Update 51 (API 101051 / 101052), PC/Mac, English client.

## It replaces

WritCrafter does the job of all of these. **Disable them** before using it: they answer the same
dialogs and craft at the same stations, and two add-ons doing that at once will get in each
other's way.

- Dolgubon's Lazy Writ Crafter (and LibLazyCrafting; WritCrafter has its own crafting engine)
- DailyAlchemy
- DailyProvisioning
- WritWorthy
- LibMarify, LibRecipe (no longer needed)

## Requirements

Required libraries (install them from ESOUI or Minion):

| Library | Minimum version |
|---|---|
| LibAddonMenu-2.0 | 43 |
| LibCustomMenu | 730 |
| LibPrice | 70530 |
| LibSets | 9040 |
| LibCharacterKnowledge | 301020 |

Optional, used when installed:

- **LibEsoHubPrices**: ESO Hub prices (the default price source when present)
- **Master Merchant**, **Arkadius' Trade Tools**, **Tamriel Trade Centre**: prices, through LibPrice
- **FCO ItemSaver**: items you've marked are never used, moved, sold or taken apart
- **LibDebugLogger**: keeps WritCrafter's chat lines in its saved file

## Installing

1. Download this repository (Code → Download ZIP) or clone it.
2. Put the folder in your AddOns folder and make sure it's named exactly **`WritCrafter`**:
   `Documents\Elder Scrolls Online\live\AddOns\WritCrafter\WritCrafter.addon`
   (If your Documents folder lives elsewhere, use that one.)
3. Install the required libraries above.
4. In game, enable WritCrafter under Add-ons, disable the add-ons it replaces, and log in.

Settings: **Settings → Add-ons → WritCrafter**, or type `/wc settings`.

## What it does

### Daily writs

- **Writ boards:** opening a board accepts the daily writs of the crafts you tick, then closes it.
- **Crafting:** opening a station crafts whatever your daily writs for that craft still need, then
  leaves the station (both optional).
- **Delivery crates:** opening a crate turns in the finished writs.
- **Storage:** optionally, finished items already in your bank or house storage are used instead of
  crafting new ones. Reagents an alchemy writ asks you to *acquire* are taken from the bank.
- **Status strip:** a row of seven craft icons near your health bar: amber to craft, cyan crafted,
  green turned in. Drag it anywhere.

### Master writs

- **Queue:** right-click a sealed master writ → *WritCrafter: craft this writ*, or open the queue
  window (`/wc queue`) to see every writ in your bags and bank with its cost, vouchers, station and
  status. Sort, filter, and queue or unqueue them all at once.
- **Crafting:** queued and accepted writs are crafted at their station, including **Grand Master
  Crafting Stations** (WritCrafter learns which sets yours have each time you use one).
- **Mimic stones:** used when a style material is excluded or you have none (setting, with a
  per-writ override in the queue window).
- **Accept and turn in:** the *Accept crafted master writs* button or keybind accepts the writs
  whose items are already crafted. Talking to Rolis Hlaalu then hands them all in, ends the
  conversation and accepts the next batch.
- **Accept guard:** using a sealed writ your settings reject, or one this character can't craft
  (unknown motif, recipe or trait), asks first instead of adding a quest you can't finish.
- **Station markers:** in houses, a marker over each station that can craft your queued writs.
- **Never twice:** items already crafted for a writ (in your bag or bank) are set aside for it and
  never crafted again.

### Choosing materials

- Every choice (reagent combination, style material, rune, trait stone) uses what you have the
  **most** of, counting your backpack, craft bag and bank.
- **Exclusions:** materials that are expensive or hard to find are never used, and writs that need
  them are rejected. By default that's expensive materials, every alchemy reagent that isn't an
  overland plant, and style materials NPC stylemasters don't sell. Change any of them in the
  exclusions window (`/wc exclusions`) or by right-clicking a material.
- **Gold writs** can be excluded per craft, and master writs can be rejected above a maximum gold
  cost per voucher.

### Writ rewards

Reward boxes are opened as they arrive (out of combat, with room in your bag), and each kind of
item inside gets the action you choose: leave in bag, deposit at the next bank visit, junk, sell
at the next merchant, deconstruct at the next station or deconstruction assistant, or keep one
stack and sell the rest. Only what the box gave is moved or sold, never items you already had.
Locked items, FCO ItemSaver-marked items and items set aside for writs are never touched.

### Inventory and tooltips

- Badges on sealed writs: crafted (green), partly crafted (amber), rejected (red), queued (blue),
  missing materials (yellow). A padlock marks items set aside for a writ.
- Writ tooltips say why a writ is rejected and list the materials it will use.

## Commands

`/wc` and `/writcrafter` work the same. `/wc` alone shows this list in chat.

| Command | What it does |
|---|---|
| `/wc settings` | Open the settings |
| `/wc queue` | Show or hide the master writ queue window |
| `/wc exclusions` | Choose which materials writs may not use |
| `/wc stock <item link>` | How many of an item you have, and how many WritCrafter can use |
| `/wc price <item link>` | The price WritCrafter uses for an item, and its source |
| `/wc reagents` | The solvents and reagents your alchemy daily can use |
| `/wc quests` | Your crafting quests' tasks and what WritCrafter reads from them |
| `/wc stations` | What the station markers are working from in this house |
| `/wc debug` | Turn detailed chat messages on or off |
| `/wc selftest` | Check WritCrafter's stack counts against the game's own |
| `/wc perf` | Time the work behind the bag and bank windows |
| `/wc checkdata` | Compare WritCrafter's built-in data with the game (after game updates) |

Shift-click an item into chat to get its link for `stock` and `price`.

**Keybinds** (Controls → Keybindings → WritCrafter, none set by default): show or hide the master
writ queue, accept crafted master writs.

## Settings

Settings are shared by all your characters on a server (**Account Wide**). Any character can
switch to **This Character Only** under General; it starts from a copy of the shared settings.

| Section | What's in it |
|---|---|
| Crafting | On-screen notices, sounds, leaving the station afterwards |
| Daily Writs | Crafting, using stored items, handing over excluded reagents, boards and crates per craft, the status strip |
| Master Writs | Crafting, taking items out of storage, Rolis turn-ins, the accept guard, station markers, writ tooltips, mimic stones, max gold per voucher, gold writs, material exclusions, price ceilings |
| Writ Rewards | Opening boxes, the chat summary, and an action for each kind of reward |
| Inventory Icons | Each badge on or off, and their position |
| General | Settings scope, price source, chat detail |

## Known limitations

- English client only for now. Daily writ names are learned in your language as you craft them,
  but other text still expects English.
- Daily alchemy writs that need an excluded reagent are not abandoned for you: WritCrafter won't
  hand the reagent over (unless you allow it) and leaves the writ at the crate.
- Station markers are shown in houses only.
- There's no warning yet if one of the replaced add-ons is still enabled.

## For developers

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
docs/      design plan, in-game test list, saved variables reference
scripts/   deploy and offline checks
```

- [docs/PLAN.md](docs/PLAN.md): design, decisions and milestones
- [docs/TESTING.md](docs/TESTING.md): in-game tests still to run
- [docs/SAVEDVARS.md](docs/SAVEDVARS.md): every saved setting and table, and how they work

### Deploying

`scripts\Deploy.ps1` checks the code, then copies the add-on into your AddOns folder as
`AddOns\WritCrafter`, leaving out `docs`, `scripts`, `.git` and Markdown files. From the repository
folder in PowerShell:

```powershell
.\scripts\Deploy.ps1
```

It deploys to `Documents\Elder Scrolls Online\live\AddOns\WritCrafter` (your Windows Documents
folder, wherever it is). To deploy somewhere else, pass the destination; it must end in a folder
named `WritCrafter`:

```powershell
.\scripts\Deploy.ps1 -Destination "E:\Games\Elder Scrolls Online\live\AddOns\WritCrafter"
```

The destination is mirrored, so files deleted from the repository are deleted there too. Saved
variables are never touched. If PowerShell refuses to run scripts, use
`powershell -ExecutionPolicy Bypass -File scripts\Deploy.ps1`.

Then `/reloadui` in game, or log out and back in when files were added or removed (the game only
reads the file list at login).

### Offline checks

Deploy.ps1 runs both checkers when it finds them and refuses to deploy if either reports a problem:

- `scripts/check.lua`, with **LuaJIT** (Lua 5.1, like the game): every file in the manifest exists
  and compiles, and no accidental globals. Install with `winget install DEVCOM.LuaJIT`.
- `scripts/check_lua.py`, with **Python 3**: local functions called before they're defined,
  `a, b = x and f()`, `tonumber` of a function call, and other mistakes that only fail in game.

Run them by hand from the repository folder:

```powershell
luajit scripts\check.lua
python -I scripts\check_lua.py
```

New Lua files must be added to `WritCrafter.addon` in load order.

## Author

@g0thiCiCecReaM (NA)

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its
affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of
ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
