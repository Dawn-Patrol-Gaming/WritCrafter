# WritCrafter

> **Made with AI:** most of WritCrafter's code was written by Claude (Anthropic's AI) under the
> author's direction. Every feature is tested in game by the author, but not every line has been
> reviewed by hand.

> **Required libraries:** LibAddonMenu-2.0, LibCustomMenu, LibPrice, LibSets and
> LibCharacterKnowledge (versions below). Install them from ESOUI or with Minion.

An Elder Scrolls Online add-on that crafts everything your daily and master writs need, skips
writs you don't want, and spends the materials you have the most of.

Open a crafting station and the items for your writs are made. Writ boards, delivery crates and
Rolis Hlaalu are handled for you, and the boxes you get back are opened and sorted.

> **Status:** pre-release (0.1.0), in active development and tested on one account. Built for
> Update 51 (API 101051 / 101052), PC/Mac, English client.

## Requirements

Required libraries:

| Library | Minimum version |
|---|---|
| LibAddonMenu-2.0 | 43 |
| LibCustomMenu | 730 |
| LibPrice | 70550 |
| LibSets | 9040 |
| LibCharacterKnowledge | 301040 |

Optional, used when installed:

- **LibEsoHubPrices**: ESO Hub prices (the default price source when present)
- **Master Merchant**, **Arkadius' Trade Tools**, **Tamriel Trade Centre**: prices, through LibPrice
- **FCO ItemSaver**: items you've marked are never used, moved, sold or taken apart
- **AwesomeGuildStore**: WritCrafter's lines still show on guild store tooltips
- **LibDebugLogger**: keeps WritCrafter's chat lines in its saved file

## WritCrafter and the add-ons it learned from

WritCrafter is one player's take on writ crafting: the parts of **Dolgubon's Lazy Writ
Crafter**, **WritWorthy**, **DailyAlchemy** and **DailyProvisioning** that I actually use, put
together in one add-on and tuned to how I play. It's deliberately smaller than they are, and
it isn't as robust: they've been tested by many players across years of game updates, and
WritCrafter hasn't.

Those add-ons are mature, full-featured and translated into many languages, and their authors
have kept them going for years. WritCrafter wouldn't exist without them (see Credits). If you
use and like what they offer, they may well be the better choice for you.

### What the others offer

**Dolgubon's Lazy Writ Crafter** (Dolgubon) is the long-standing all-in-one writ crafter,
translated into 7 languages and available on console too. Beyond what WritCrafter covers, it
offers:
- a craft multiplier, to make several days' worth of daily writ items at once;
- writ and reward statistics;
- more ways to handle rewards: Destroy, event boxes (anniversary, Zenithar), and an alert for
  valuable rewards;
- mimic stones by price (when the style material costs over 1,000 or 3,000 gold);
- plenty of extras around writs: a status bar, reticle colours at stations, a daily reset
  warning, stealing protection, hireling mail handling, and travel to a crafting house.

**WritWorthy** (ziggr, Sharlikran) is the master writ specialist, translated into 6 languages.
Beyond what WritCrafter covers, it offers:
- a material shopping list for your queued writs, in a window or in chat;
- an AwesomeGuildStore filter on what a master writ really costs per voucher, purchase price
  included;
- HomeStationMarker support for marking house stations.

**DailyAlchemy** and **DailyProvisioning** (Marify) each do one craft's daily writs with a lot
of control, translated into 9 languages. Beyond what WritCrafter covers, they offer:
- a choice of how reagents are picked: by stock, by price (Master Merchant, TTC or ATT), or in
  your own order;
- crafting extra potions or food in bulk while you're at the station;
- Witches Festival writs (WritCrafter hasn't been tested with event writs yet).

All four have been used by many players for years. WritCrafter is a new pre-release, tested on
one account, English only, and PC/Mac only.

### What's in WritCrafter

The parts I use, in one place, plus a few ideas of my own:
- **Daily and master writs for all seven crafts,** writ boards, delivery crates, Rolis Hlaalu,
  reward boxes and a master writ queue, all in one add-on.
- **Uses what you have the most of:** reagents, style materials, runes and trait stones are
  picked by your stock across backpack, craft bag and bank.
- **Material exclusions:** expensive or hard-to-get materials are never used, and writs that
  would need them are marked as rejected.
- **Accept guard:** using a sealed master writ you can't or don't want to craft asks first.
- **Never crafts twice:** items already made for a writ, in your bag or bank, are set aside for
  it with a padlock.
- **Grand Master Crafting Stations:** every queued set the station has is crafted in one visit.
- **Reward actions per kind of item,** including deconstructing gear and glyphs in one batch and
  keeping one stack while selling the rest.
- **Station markers in houses** and a **daily writ status strip.**

### If you switch

Disable the add-ons above before using WritCrafter: they answer the same dialogs and craft at
the same stations, and two add-ons doing that at once will get in each other's way. If any of
them is still running, WritCrafter says so in a dialog when the UI loads (you can turn this off
under Settings, General).

- Dolgubon's Lazy Writ Crafter, and LibLazyCrafting unless another add-on needs it
  (WritCrafter has its own crafting engine)
- WritWorthy
- DailyAlchemy
- DailyProvisioning
- LibMarify and LibRecipe are no longer needed, unless another add-on uses them

**Keep PotionMaker:** WritCrafter doesn't replace it. It searches for potions, which WritCrafter
doesn't do, and the two don't get in each other's way.

## Installing

1. Install the required libraries above.
2. Put the `WritCrafter` folder in your AddOns folder, named exactly **`WritCrafter`**:
   `Documents\Elder Scrolls Online\live\AddOns\WritCrafter\WritCrafter.txt`
   (If your Documents folder lives elsewhere, use that one.)
3. In game, enable WritCrafter under Add-ons, disable the add-ons it replaces, and log in.

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
- **Accept and turn in:** the *Accept crafted master writs* button, keybind or `/wc accept` accepts
  the writs whose items are already crafted. Talking to Rolis Hlaalu then hands them all in, ends
  the conversation and accepts the next batch.
- **Accept guard:** using a sealed writ your settings reject, or one this character can't craft
  (unknown motif, recipe or trait), asks first instead of adding a quest you can't finish.
- **Station markers:** in houses, a marker over each station that can craft your queued writs. A
  station the game already marks for a writ you've accepted keeps only the game's marker.
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
The gold from turning in writs and from selling their rewards can be banked too, and so can
the writ vouchers master writs pay.

### Inventory and tooltips

- Badges on sealed writs: crafted (green), partly crafted (amber), rejected (red), queued (blue),
  missing materials (yellow). A padlock marks items set aside for a writ.
- Writ tooltips say why a writ is rejected and list the materials it will use.

## Commands

`/wc` and `/writcrafter` work the same: every command below also works as `/writcrafter settings`,
`/writcrafter queue` and so on, and the replies use whichever you typed. If another add-on already
uses `/wc`, WritCrafter leaves it alone and only `/writcrafter` works. `/wc` alone shows this list
in chat.

| Command | What it does |
|---|---|
| `/wc settings` | Open the settings |
| `/wc queue` | Show or hide the master writ queue window |
| `/wc queue all` | Queue every writ you can craft, in your backpack and bank |
| `/wc queue none` | Empty the queue (`/wc queue clear` does the same) |
| `/wc accept` | Accept the crafted master writs in your backpack |
| `/wc exclusions` | Choose which materials writs may not use |
| `/wc markers none\|all\|queued` | Station markers: none, every writ in your bag, or queued writs only (`off` works the same as `none`, and `queue` as `queued`) |
| `/wc guard on\|off` | Turn the accept guard (Ask Before Accepting Writs You Can't Craft) on or off |
| `/wc stock <item link>` | How many of an item you have, and how many WritCrafter can use |
| `/wc price <item link>` | The price WritCrafter uses for an item, and its source |
| `/wc reagents` | The solvents and reagents your alchemy daily can use |
| `/wc quests` | Your crafting quests' tasks and what WritCrafter reads from them |
| `/wc stations` | What the station markers are working from in this house |
| `/wc debug` | Turn detailed chat messages on or off |
| `/wc selftest` | Check WritCrafter's stack counts against the game's own |
| `/wc perf` | Time the work behind the bag and bank windows |
| `/wc checkdata` | Compare WritCrafter's built-in data with the game (after game updates) |
| `/wc reset` | Clear everything WritCrafter has saved on this server (asks first, then reloads). See below |

`markers` and `guard` without a word say what they're set to now. Shift-click an item into chat to
get its link for `stock` and `price`.

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
| General | Settings scope, the replaced add-ons warning, price source, chat detail |

WritCrafter keeps its data separately for each megaserver (NA, EU, PTS), so one never overwrites
the other.

### Settings in detail

The settings themselves keep their explanations short; the details are here.

**Settings scope**
- Switching a character back to Account Wide picks up the shared settings as they were. The
  character's own are kept for next time and never copied over the shared ones.

**Taking items out of storage**
- **Daily writs** (off by default): finished potions, food, drinks, glyphs and plain gear (no
  trait, normal quality) in your bank or a house storage chest are taken out when you open it,
  and stations don't craft another meanwhile.
- Never taken for a daily writ: excluded materials, locked or FCO ItemSaver-marked items, and
  items set aside for sealed master writs.
- Reagents an alchemy writ asks you to *acquire* are taken out of the bank either way, since
  they can't be crafted.
- **Master writs** (on by default): the crafted items for writs you've accepted, and for sealed
  writs in your backpack, are taken out ready to turn in. Stations don't craft another for an
  accepted writ whose item is in storage. Writs left in the bank keep their items there.

**Hand Over Excluded Reagents** (alchemy dailies)
- Exclusions still decide which reagents potions are crafted with; this only covers a reagent
  the writ asks you to acquire.
- Off: a writ that would hand over an excluded reagent is left at the crate for you.

**Mimic stones**
- When Needed: when the style material is excluded, or you have none of it.
- Never: writs whose style material is excluded are rejected.
- Always: on every master writ that has a style. You still need to know the motif either way.
  Mimic stones are never used for daily writs.

**Accept guard**: covers writs your settings reject, and writs this character can't craft
(unknown recipe, motif or trait, or the Update 51 game bug).

**Writ rewards**
- **Opening boxes:** out of combat, with at least 4 free backpack slots. Otherwise as soon as
  that's true, also after a relog. With opening off, boxes are left for you.
- **Deconstruct** (ornate and intricate gear, glyphs): taken apart all at once, after any writ
  crafting at that station, or at a deconstruction assistant.
- **Keep a Stack, Sell the Rest** (repair kits, soul gems): at each merchant, what the boxes gave
  is sold once you have more than one full stack in your backpack. What you had before is
  never sold.
- **Extra Crafted Potions, Poisons & Food:** what a writ craft makes beyond what the writ needs
  (skills make several per craft). Only that amount is deposited or sold, never the writ's own.
- **Gold from Turning In Writs** and **Gold from Selling Writ Rewards** (both Deposit by
  default): the gold the game pays for each writ you turn in (daily or master), and what
  WritCrafter's own sales of writ rewards bring in, are added up and deposited the next time
  you open your bank (the bank itself, not house storage). Only that amount, and never more
  than you're carrying then; gold you had before stays with you. Junk you sell yourself isn't
  counted.
- **Writ Vouchers** (Deposit by default): the vouchers each master writ pays when you turn it
  in are added up and deposited at your next bank visit, like the gold: never more than you're
  carrying, and vouchers you had before stay with you. Withdraw them again before buying from
  Rolis Hlaalu.
- **Containers:** other containers (e.g. a shipment of ingots) are opened by default. Master
  writ and survey containers stay closed unless you choose Open; what they hold then follows
  its own setting.
- Materials that go to the craft bag stay there.

**Station markers**
- Found from your house's furniture, without opening anything. Houses only.
- Greyed out while Essential Housing Tools shows its own master writ markers; turn those off to
  use WritCrafter's.

**Status strip**: faded icons are writs not picked up yet. The strip goes away once the last
daily writ is turned in, and remembers where you dragged it.

**Notices**: a short message in the top-right corner when writ crafting starts and finishes at a
station, and a large one in the middle of the screen when something can't be crafted. Sounds
have their own settings.

**Padlocks**: gold for items assigned to a master writ (sealed, or accepted and not yet turned
in); blue for items made for a daily writ, until it's turned in.

## Resetting WritCrafter

`/wc reset` asks first, then clears everything WritCrafter has saved for your account **on the
server you're on** and reloads the UI. Your other megaservers, other add-ons, the game's own
settings and your items are not touched. It can't be undone, so to keep a way back, first copy
`Documents\Elder Scrolls Online\live\SavedVariables\WritCrafter.lua` somewhere safe. To restore
it, quit the game fully, copy it back, then start the game.

What a reset clears:

1. **Every setting goes back to its default,** for the shared settings and every character's own:
   material exclusions (too-expensive marks, reagent choices, gold writs per craft, price
   ceilings), reward actions, daily writ boards and crates per craft, station markers, mimic
   stones, max gold per voucher, sounds, badges, the status strip's position, price source and
   chat detail. Every character goes back to Account Wide.
2. **Work in progress is forgotten:**
   - every character's master writ queue, and any per-writ mimic choices;
   - reward items waiting for the bank or a merchant (they stay in your backpack and are no
     longer deposited or sold for you), reward boxes waiting to be opened, and Keep a Stack counts;
   - daily writs in progress: items already crafted for a daily lose their badge, an alchemy
     reagent waiting to be handed over may not be, and the status strip may be wrong until the
     next daily reset;
   - accepted master writs are mostly found again in your quest journal, but one whose crafting
     step is already done may lose its details (and its items' badges) until it's turned in.
3. **What WritCrafter has learned comes back as you play:**
   - which sets your Grand Master stations hold: until you use each one once, the queue window
     and the markers point to each set's own station;
   - house stations: those found from the game's furniture list or by name come back at once; a
     station WritCrafter only knew because you'd used it needs using once more;
   - daily writ quest names (English is built in; other languages are relearned at the next
     station);
   - item links used for prices: some items may show no price until they've been in your bags.

The best time to reset is right after a full turn-in, with nothing queued, no daily writs in
progress and no reward items waiting: then only points 1 and 3 apply.

## Known limitations

- English client only for now. Daily writ names are learned in your language as you craft them,
  but other text still expects English.
- Daily alchemy writs that need an excluded reagent are not abandoned for you: WritCrafter won't
  hand the reagent over (unless you allow it) and leaves the writ at the crate.
- Station markers are shown in houses only.

## Credits

No code was copied from other add-ons. These were read as references for how the game behaves,
and ideas and game data came from them; thank you to their authors:

- **Dolgubon's Lazy Writ Crafter** and **LibLazyCrafting** (Dolgubon): how daily writs are matched
  to crafts, telling master writ crafts apart by the sealed writ's icon, the item IDs of writ
  reward containers, opening reward containers, hiding the loot window while boxes are opened,
  provisioning quantities, and alchemy reagent data to cross-check.
- **WritWorthy** (ziggr, Sharlikran): the Accept & Turn In design for master writs (accept with a
  button, then hand in at Rolis Hlaalu), how long to wait before accepting a writ's quest,
  provisioning quantities, alchemy reagent data to cross-check, and the game data behind
  WritCrafter's master writ tables: the smithing items (template numbers, sample items,
  material counts) and the enchanting glyphs and runes. WritCrafter's tables are written in its
  own format and checked against the game itself (`/wc checkdata`).
- **DailyAlchemy** and **DailyProvisioning** (Marify): how daily alchemy and provisioning writs
  are read and crafted.
- **LibAlchemy** (Hyperioxes): alchemy reagent data to cross-check.
- **UESP**: the list of crafting station furnishings, and the Update 51 alchemy changes.
- Prices come from **LibPrice** (Master Merchant, Arkadius' Trade Tools, Tamriel Trade Centre) and
  **LibEsoHubPrices** (ESO Hub), read while you play.

## Author

@g0thiCiCecReaM (NA)

Developer notes, the design plan and the test list are in the repository's `docs` folder:
https://github.com/Dawn-Patrol-Gaming/WritCrafter

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its
affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of
ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
