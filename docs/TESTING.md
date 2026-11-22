# WritCrafter in-game tests

Run `/reloadui` after every deploy. Note anything unexpected along with the exact chat output.
A Lua error popup at any point is a failure. Copy its first few lines.

Every test still to do is under **To do**, grouped by when you can run it. Tests waiting on the
alt accounts are under **Deferred**. Everything after that is history: what passed, and notes
worth keeping. Passed tests are removed from To do; the full milestone 1–2 list is in this file's
git history.

## To do

Turn Debug chat on (`/wc debug`) before starting.

### Any time

| # | Do | Expect |
|---|---|---|
| OP11 | Reward items set to Deposit and Sell: a bank visit, then a merchant | Deposited and sold as before, and gone from the list afterwards (not tried again next visit) |
| RG2 | A bank visit with reward items to deposit, then a merchant with items to sell (or GR3/GR4 again) | Still one at a time and as quick as before: the request queue now only listens to the bag it's working on |

### On the next daily run

| # | Do | Expect |
|---|---|---|
| OC4 | A daily that needs something you don't have: open its station, fetch the item, open the station again | Searched again and crafted, as before |

### Whenever it happens

| # | Do | Expect |
|---|---|---|
| DC7 | A deconstruction batch doesn't go through | Within about 8 seconds: `Writ rewards to deconstruct ... no progress` (or a similar message) and the red banner, with no hang. Say what you saw, with the Debug lines |
| RW20 | Optional, rare. It only happens when placing the goods frees no slot: a provisioning or alchemy daily whose extras stay in the same stack, or an acquire reagent from the craft bag. Fill the backpack completely after crafting it, then turn it in | Chat: `Can't turn in <writ>: your backpack is full ...`, and the writ stays at Sign the Manifest. Make room and talk to the crate again: it's turned in. (Seen 2026-11-11 with a provisioner writ, with no message then.) Gear writs free their own slots when the goods are placed, so they never hit this |
| B3 | Optional. A character with **no** sealed writs in the backpack or bank receives one (mail, loot, trade) while the inventory is open | Its badge appears without `/reloadui`, which checks that the idle path wakes up |
| EV1 | During an event, turn in a daily writ that gives an event box (e.g. Zenithar's Abundance) | Untested so far. Any container arriving right after a crafting quest completes is treated as a reward box, so it should open by itself, list its contents in chat, and apply your reward actions to the kinds WritCrafter knows (anything else stays in the bag). Say what the box was and what happened |
| EV2 | An event (or other non-daily) quest the game lists as a crafting quest | Untested so far. If its tasks read like a daily writ's (`Craft ...`, `Acquire ...`), the matching station should craft them; if not, nothing should happen, with no error. Writ boards and crates only handle daily writs. Say which quest it was, with `/wc quests` and the Debug lines |

## Deferred: alt accounts (no ESO Plus, low-level crafters)
Deferred until the free Epic accounts have characters that can craft. Every crafter on the main account is max level, and without ESO Plus there's no craft bag, so materials live in the backpack and bank.

| # | Do | Expect |
|---|---|---|
| N1 | Alchemy daily with an "acquire a reagent" condition, reagent only in the bank | Before the bank-withdrawal step exists: `<reagent> isn't in your craft bag; take it from the bank`. After it: withdrawn automatically when you open the bank |
| N2 | Any daily or master writ whose materials are only in the bank | Crafts at the station using bank materials (stations use the bank) |
| N3 | `/wc stock <material>` and the exclusions window's "You have" | Backpack + bank counts, craft bag 0 |
| N4 | Settings, tooltips, badges | Same as on ESO Plus; nothing assumes a craft bag |
| L1 | Enchanting daily on a low-level crafter (was ED2) | Uses the potency rune for that writ's level (e.g. Jora/Porade at low level), not the max-level Repora/Itade |
| L2 | Alchemy and provisioning dailies on a low-level crafter | Uses the solvent and recipe for that writ's level; nothing assumes max skills (e.g. fewer potions or dishes per craft) |
| L3 | Smithing dailies on a low-level crafter | Uses the base material for that writ's level |
| LR1 | Provisioning daily for a recipe this character doesn't know: open the station (nothing crafted), learn the recipe, open the station again (no `/reloadui`). (Main-account characters know every recipe.) | Crafts on the second visit |

## History

Passed tests and what was learned, newest first.

### Data tables in WritCrafter's own order (2026-11-22)

What changed: the smithing templates and enchanting glyphs, first gathered from WritWorthy's
data, sorted by their own keys, the essence runes by item ID, and the motif chapter aliases
replaced by the game's constants (PLAN.md §12, code-origin check).

**DT1 passed 2026-11-22:** `/wc checkdata` at an enchanting station and at an alchemy station:
enchanting runes and glyphs all 114 checks match, smithing items and materials all 53, solvents
all 18, reagent effects all 153 (91 skipped for traits not yet discovered). The two enchanting
master writs (Superb Glyph of Increase Physical Harm, Truly Superb Glyph of Disease Resist) and
the alchemy one (16 Stealth-Draining Poison IX) crafted as before.

### Replaced add-on warning and shorter settings texts (2026-11-22)

What changed: a dialog when the UI loads if Dolgubon's Lazy Writ Crafter, WritWorthy,
DailyAlchemy or DailyProvisioning is running (`Core/Replaced.lua`, setting Warn About Replaced
Add-ons under General); the long settings texts and tooltips shortened, with the details moved to
README's "Settings in detail".

**RA1–RA4 passed 2026-11-22:** no dialog with none of them installed, and the setting is there,
ticked; with WritWorthy copied back and enabled, the dialog listed it a few seconds after the UI
loaded and came back after `/reloadui`; Don't Warn Again stopped it, with the chat line, and
unticked the setting; with WritWorthy installed but unticked, no dialog.

**ST1 passed 2026-11-22:** the Writ Rewards and Material Exclusions texts and the shortened
tooltips read cleanly, with the line breaks and dash lists showing as intended.

### Second optimization pass (2026-11-22)

What changed: see PLAN.md, milestone 7, "Second pass": bulk queueing sends one change notice,
stock lookups no longer build tables, and five duplicated pieces of logic are shared.

**OP7 passed 2026-11-22** with 7 writs: `/wc queue all` queued 7 and `/wc queue none` removed
the same 7. (Not yet seen with 50+ writs, where the old one-rebuild-per-writ cost showed most.)

**OP9 and OP10 passed 2026-11-22.** The exclusions window sorts and filters by count as before. At the Grand Master stations, with 7 writs queued and a Master Clothier Writ accepted by hand on the way, the Maul of Red Eagle's Fury, the Innate Axiom Hat and the Ancient Dragonguard's Sash were each crafted and improved once, and items were claimed for the right writs, so nothing was made twice. Leaving the blacksmithing station mid-craft and opening it again also worked: the second visit picked the maul up where it stood and made only the one. Deconstructing a queued writ's crafted item, with more writs queued, then visiting the Grand Master Jewelry Crafting station: the writ was no longer counted as crafted, and the Gladiator's Necklace was made again, once, and improved to Epic.

**OP8 passed 2026-11-22.** `/wc perf` on a character with 21 writs, 763 stacks and 695 bag and
bank slots: matching 2.0 ms (20 candidates), stock scan 6.6 ms, verdicts 3.4 ms first time and
0.0 ms cached, shortages 3.6 ms, badges 1.4 ms, journal, accepted writs and daily storage check
0.0 ms (no crafting quests). Compared with 2026-11-08 (54 writs, 833 stacks): verdicts went from
about 0.25 to 0.16 ms per writ and shortages from about 0.23 to 0.17 ms per writ, as expected now
that stock lookups don't build a table each; the stock scan itself is unchanged (it wasn't
touched), and badges are lower mostly because there are fewer writs.

### ESOUI rules review (2026-11-22)

What changed: README reworked as the ESOUI description and player guide (AI disclosure first,
then required libraries, credits, every command, resetting); `DependsOn` raised to LibPrice 70550
and LibCharacterKnowledge 301040; the request queue's bag event filtered to the bag it's working
on; `/wc` isn't taken from another add-on that already has it; Deploy.ps1 leaves only uploadable
files in the AddOns folder.

**RG1 and RG3 passed 2026-11-22:** after logging out fully WritCrafter loaded with no dependency
warning, and `/writcrafter` and `/wc` both showed the command list. RG3 led to a change: replies
now repeat the command you typed (RG4).

**RG4 passed 2026-11-22:** `/writcrafter` lists every command as `/writcrafter ...` with `Commands (/wc works the same):`, its unknown-command and usage replies say `/writcrafter`, `/wc` does the same the other way round, and the settings texts say `/wc`.

### Slash commands (2026-11-22)

What changed: new `/wc accept`, `/wc queue all`, `/wc queue none` (or `clear`), `/wc markers off|all|queued`,
`/wc guard on|off` and `/wc reset` (asks first, then clears this account's WritCrafter data on
this server and reloads).

**SC1 passed 2026-11-22:** `/wc accept` accepted crafted writs like the button, and `/wc` lists the new commands.

**SC2 passed 2026-11-22:** `/wc queue clear` emptied the queue and `/wc queue all` queued every writ you can craft, with the counts in chat and the window keeping up. Afterwards `/wc queue none` was added as another word for `clear` (SC6).

**SC6 passed 2026-11-22:** `/wc queue none` empties the queue like `clear`, the usage line suggests `none`, and `/wc` lists `queue none (or clear)`.

**SC3 passed 2026-11-22:** `/wc markers all`, `none`, `off`, `queued` and `queue` change the markers straight away and name the setting in chat (`none` = `off`, `queue` = `queued`); with no word it says the current one, a wrong word gives the usage line, and the settings panel matches.

**SC4 passed 2026-11-22:** `/wc guard on|off` changes the setting and says so, with no word it says the current one, a wrong word gives the usage line, and the settings checkbox matches.

**SC5 passed 2026-11-22:** `/wc reset` wiped the saved data and settings and reloaded.

### Station markers defer to the game's (2026-11-22)

What changed: a station that fits an accepted master writ still to craft already has the game's
own quest marker, so WritCrafter no longer adds its cyan one there (see PLAN.md, milestone 5,
step 4).

**SM1–SM5 passed 2026-11-22** with Station Markers on Only Queued: with only accepted writs
there were no cyan markers and `/wc stations` counted the accepted writ still to craft; the
game's marker covered the Rubedite Pauldron's station, so no station was left unmarked; a
queued writ for that same station got no cyan marker, while one for another station did; and
opening the station crafted both the accepted and the queued writ in one visit, leaving no
marker of either kind.

### Guidelines review fixes (2026-11-21)

What changed: bank moves and merchant sales now go one at a time, each after the server has made the one before (instead of all in the same frame); bag-change handlers ignore gear wear and weapon charge; the quiet-loot hook sits on the loot window's class; every WritCrafter string was renamed (`SI_WRITCRAFTER_*` → `WRITCRAFTER_*`); the manifest was renamed `WritCrafter.txt`.

**GR1 and GR2 passed 2026-11-21**, after logging out fully: WritCrafter is listed and enabled
with the `.txt` manifest, with no dependency or out-of-date warning, and the settings, queue
window, exclusions window, writ tooltips and `/wc` all show their text after the string rename.

**GR6 and GR4 passed 2026-11-22** on the daily run: reward boxes opened quietly with the loot
window hook on its class, and reward items marked Sell were all sold one at a time. GR3 passed
the same day: bank deposits go over one at a time, and the speed is fine (no need to switch
`REQUEST_ONE_AT_A_TIME` off). GR4 passed again too. GR5 passed: closing the bank straight away
gave no error. GR7 passed: no stutter during a fight in heavy armour, and the queue window was up
to date afterwards.

### Milestone 6, step 2: deconstruct writ rewards (2026-11-13)

Only a `/reloadui`. Set Settings → Writ Rewards → **Ornate Gear**, **Intricate Gear** and **Glyphs** to the new **Deconstruct** (only items from writ boxes opened after this change count; ones already in your bag aren't marked). Debug chat on.

Passed 2026-11-13: DC1 (the Deconstruct choice), DC2 (pieces marked `(to deconstruct)` and kept), DC6 (enchanting station with nothing marked: nothing happened). Also seen: a Platinum Necklace, a Ruby Ash Inferno Staff, a Rubedite Girdle and Rubedo Leather Boots were each taken apart at their own station (`Deconstructing 1 writ reward item(s).`). The glyph that day was left alone because Glyphs was still on Leave in Bag when its box opened. DC5 passed 2026-11-13: Giladil the Ragpicker took 5 marked pieces of four kinds (a necklace, a bow, a jerkin, a cuirass and a glyph) apart in one batch (`Deconstructing 5 writ reward item(s).`), so glyphs come apart too. A marked piece locked afterwards was left alone (2026-11-13). DC3 and DC4 passed 2026-11-22: writ crafting and then deconstruction in the same station visit, with the station still closing afterwards (DC3), and marked glyphs extracted together at the enchanting station (DC4). Debug chat now names the station: `Clothing station (2) opened: ...`, `Deconstruction assistant or station (0) opened: ...`.

### Hand Over Excluded Reagents (2026-11-12)

All passed 2026-11-13: HX1 (the setting), HX2 (with it on, an alchemy writ whose acquire task wanted excluded Spider Egg was turned in at the crate; potions still weren't crafted with excluded reagents). HX3 (off) is the old behaviour, already passed as WD6.

### Settings scope: back to Account Wide (2026-11-12)

Checked offline with the real settings code (account values never overwritten; the character's own come back when switched to again). Passed in game 2026-11-14 (SC1).

### Milestone 9, Accept Guard (2026-11-14)

New file (Writs/AcceptGuard.lua), so a **full relog**. (Potion search, tested alongside it,
was dropped 2026-11-19: PotionMaker stays for that.)

**Accept Guard** (Settings → Master Writs → Ask Before Accepting Writs You Can't Craft, on by
default): using a sealed master writ your settings would reject, or that you can't craft
(unknown recipe, motif or trait), asks before the quest is added, the way the queue window asks
before queueing a rejected writ. This is new, unverified ground (a game-wide hook on accepting
any quest) and needs careful testing.

AG1 failed 2026-11-21: the quest was added with no dialog. Cause: the guard only watched
`CallSecureProtected`, which only add-ons use; the game's own inventory calls `UseItem` directly,
so a writ used by hand was never seen. `UseItem` itself can't be hooked (tried: "Attempt to
access a private function 'UseItem'" at load). Reworked 2026-11-21: the guard now remembers the
sealed writ slot you last hovered, right-clicked, double-clicked or selected on gamepad, and
when a quest is offered within 10 seconds of that (or with the mouse still on it), outside any
NPC conversation, and the writ is still there, it checks that writ. Only a `/reloadui`.

With Debug chat on, each offer after touching a writ prints one of:
`Accept guard: <writ> used by hand, craftable`, `..., will ask: <reason>`, or
`Accept guard: quest offered, not checked (last writ touched N ms ago, talking to an NPC: ...)`.
If AG1 still fails, copy that line: "talking to an NPC: true" would mean using a writ counts as
a conversation, and the guard needs another way to tell.

Second try 2026-11-21 (Use key while hovering): the writ was recognised (`... used by hand, will
ask: Motif not known: Pellitine`) but Accept still went through. The guard forgot its decision 5
seconds after the offer appeared, a leftover from the first design; it now keeps it until the
next quest offer. Clicking Accept now also prints `Accept guard: Accept clicked for <writ>:
turned away` (or `..., nothing to turn away`).

**AG1 passed 2026-11-21** (third build): a Master Clothier Writ with an unknown motif (Minotaur)
was recognised when used by hand and its Accept turned away, twice in a row
(`Accept clicked for [Master Clothier Writ]: turned away`). AG2, AG3 and AG4 passed the same
day: Cancel leaves the writ in the backpack with no quest; Accept Anyway adds the quest and uses
up the writ; a writ you can craft is accepted as before, with no dialog. AG8 passed the same day:
an NPC's quest accepted just after hovering an uncraftable writ went through, no dialog. AG6
passed too: an ordinary NPC quest accepted right after using a master writ was not affected.

AG9 failed 2026-11-21 for right-click → Use: the guard checked the wrong writ. Clicking Use closes
the menu, and the writ under the mouse is then the row below; remembering the right-clicked writ
didn't help either. Guessing from the mouse was dropped. Reworked 2026-11-21: however the
inventory uses an item, it calls `IsItemUsable(bag, slot)` for that exact item, then
`ClearCursor()`, then `UseItem`, so the guard takes the item from the last `IsItemUsable` call
made in the same frame as a `ClearCursor()`. No mouse involved. The debug line now reads
`Accept guard: <writ> used (by hand), ...`.

**AG9 passed 2026-11-21** with that build: four Gold Jewelry Crafting writs, each
right-clicked with a craftable writ just below, moving the mouse down onto it quickly after
clicking Use. Each time the right-clicked writ was checked and its Accept turned away.
Double-click and the Use key passed in the same session. AG10 passed too: Clothier, Blacksmithing
and Woodworking writs you can craft were accepted with no dialog (`... used (by hand), craftable`).

**AG5 passed 2026-11-22:** Accept Crafted Writs still accepted the crafted writs with no
dialog, so the guard doesn't stop WritCrafter's own automation.

**AG7 passed 2026-11-22:** with Ask Before Accepting Writs You Can't Craft off, an uncraftable writ was accepted straight away with no dialog.

### Milestone 7, batch A: speed (2026-11-11)

Nothing should behave differently; it should just be quicker, mostly at alchemy stations. Only a `/reloadui`. Tests that need daily writs or reward boxes wait for another day.

Passed 2026-11-11 (on the full milestone 7 build, after a relog): OA1 (`/wc checkdata`: every check matches), OA2 (queue window verdicts and costs), OA3 (master alchemy writ: 16 Essence of Ravage Health in 4 batches), OA4 (master enchanting writ). OA5 dropped: it needs FCO ItemSaver, which isn't installed (materials can't be locked in the game itself). The check that skips FCO-marked stacks is the same one as before; only where it runs moved. OA6 and OA7 passed 2026-11-13 (full daily run): alchemy and enchanting dailies crafted as before (`/wc reagents` not rerun); reward boxes opened, the bank and a merchant took what they should.

### Milestone 7, batch B: shared helpers (2026-11-11)

New file (Core/Util.lua), so a **full relog**. Copies of small helpers (item and craft names, chat lines, item IDs, using and moving items, house storage, the "once things settle" delay) now come from one file, and bag loops share one helper. Nothing should look or behave differently; a Lua error anywhere is the thing to watch for.

Passed 2026-11-11: OB5 (`/wc stations` found all 15 stations and marked the 4 for queued writs; `/wc checkdata`, `/wc stock` and `/wc perf` as before; the stock scan, which now also records station slots, takes 3.4 ms for 801 stacks). OB1–OB4 passed 2026-11-11: badges and tooltips in the inventory, bank and house storage; the queue window and right-click queueing; queued master writs of all seven crafts crafted (smithing created with a mimic stone and improved to Epic or Legendary, provisioning 8 in two batches, alchemy 16, enchanting glyphs); Rolis accepted and turned in 7, then 2, then 1 (journal full in between). OB7 passed 2026-11-13: a full daily run (boards, all seven stations, crates, reward boxes, merchant, bank) on the new code. OB6 passed 2026-11-13: craft names in the Settings per-craft lists.

### Milestone 7, batch C: duplicated logic (2026-11-11)

Only a `/reloadui`. Master writ parsing (sealed writs and accepted quests now share one builder; checked offline against the old code on every craft, both sources, legacy alchemy effects included: identical), the alchemy pair lists, the engine's master writ jobs, the batch-count step of every crafter, and the daily "search again" rule each exist once now. Nothing should behave differently.

Passed 2026-11-11: OC1 (queue window verdicts, vouchers, costs and descriptions for writs of every craft). OC3 passed 2026-11-13: daily writs at every station, same crafts and batch counts as before. OC2 passed 2026-11-13: seven queued master writs crafted across all seven stations, then two newly accepted writs (enchanting, alchemy) crafted right after at their own stations.

### Milestone 7, batch D: UI sharing and tidying (2026-11-11)

New file (UI/Notices.lua), so a **full relog**. The queue and exclusion windows share their sorting, dropdowns and list refill; the corner message and problem banner moved out of the crafting engine into their own file; small tidy-ups. Nothing should look or behave differently.

Passed 2026-11-11: OD1 (queue window sorting, filter, Sort by station), OD2 (exclusions window categories, filter, search, sorting). OD6 passed 2026-11-13: the `Opening writ rewards: X of N` corner counter during a daily run. OD3 passed 2026-11-13: the top-right `crafting started` and `done` messages. OD5 passed 2026-11-13: after using four Grand Master stations (blacksmithing, clothing, jewelry, woodworking), their sets were known for queueing. OD4 passed 2026-11-13: the red `WritCrafter couldn't craft everything` banner, naming the excluded reagents an alchemy daily needed; after allowing some and reopening the station, it crafted.

### Daily writ status strip (2026-11-10)

New file, so a **full relog**.

All passed 2026-11-11: WS1–WS8 (default spot above the health, magicka and stamina bars, draggable straight away after a reset; seven craft icons, amber to craft, cyan once crafted, green once turned in, gone after the last turn-in; kept through reloads; movable, position remembered, hidden over menus and by its setting; the game's own icons). Cyan comes from WritCrafter finishing at the station with nothing left to craft for that writ: the game doesn't call a writ waiting for delivery complete. The game's own "quest advanced, main step changed" signal doesn't come when a writ's crafting is done, only when the goods are placed in the crate (seen 2026-11-11), so a writ crafted by hand stays amber until it's turned in.


### Daily writ dialogs: writ boards and delivery crates (2026-11-10)

New file, so a **full relog**.

Passed 2026-11-10: WD1–WD4 (settings; boards accept the ticked crafts' writs and close; crates turn writs in). WD8 answered: the number the game passes with a dialog option is always 0 (Rolis, boards, crates), so options carry no quest; board options read `<Examine the Blacksmith Writs.>`, which contain the learned quest names. WD5 passed (unticked craft: crate left alone). WD10 passed: the delivery crate reported `unit type 3, an object: true` and was turned in through that route; a writ container from the reward stayed closed and a Shipment of Ounces was opened. WD12 passed 2026-11-11: every ticked writ taken from both boards in one go; the board sometimes falls back to its front page without telling add-ons, so WritCrafter now looks at the page half a second after each accept and picks Pull itself (a little slower than Dolgubon's; the pauses can be shortened in milestone 7). WD6, WD7 and WD9 passed 2026-11-11: a writ that would hand over an excluded reagent is left at the crate; other NPCs' finished quests are left alone; all seven daily writ quest names are learned (`blacksmith writ = 1`, `clothier writ = 2`, `enchanter writ = 3`, `alchemist writ = 4`, `provisioner writ = 5`, `woodworker writ = 6`, `jewelry crafting writ = 7`). WD11 passed 2026-11-11 (second character, names learned on the first): each smithing station only searched its own writ's tasks and its Deliver Goods task. All daily writ dialog tests are done.


### Milestone 6, step 1: writ reward boxes (2026-11-10)

New file, so this deploy needs a **full relog**. Set a few actions first in Settings → Writ Rewards (e.g. Survey Reports → Deposit, Repair Kits → Sell, Recipes → Junk).

Passed 2026-11-11: RW1 (Writ Rewards settings), RW2 (boxes open by themselves, one chat line each), RW3 (Junk), RW4 (Deposit at the bank), RW5 (Sell at a merchant), RW15 (no loot window flashing), RK1 (recipes split by quality, Keep a Stack, Sell the Rest offered), RX2 (extra crafted items sold at a merchant, the writ's own kept). Also passed: RW7 (automatic opening off: boxes stay closed), RW10 and RW13 (Master Writ, Survey and Other Containers settings), RX1 (Extra Crafted Potions, Poisons & Food setting). RW12, RW14, RW16 and RW17 passed 2026-11-11: survey containers set to Open are opened; shipments inside boxes are opened and sorted; the corner counts the boxes; every box opened during quick crate turn-ins (one attempt ignored by the game and retried). A box landing while another box is being opened is listed as that box's contents in chat, though it's still opened. RK3 and RX3 passed 2026-11-11: Keep a Stack sold exactly what the boxes gave above a full stack (1 repair kit, 3 soul gems), nothing you had before; several Deposit items (three extra crafted stacks and a survey) all went into the bank. RW6 passed 2026-11-11: with 2 free slots the box stayed closed; once room was made and the house storage closed, both waiting boxes opened by themselves. (A completely full backpack stops the game itself from finishing the turn-in; Sign the Manifest again once there's room.) RK2 passed 2026-11-11: green recipes sold; a blue recipe marked `(to deposit)` and taken by the bank (`Deposited 1`). RW11 passed 2026-11-11: an Unknown Jewelry Crafter Writ (a master writ container) stayed closed on Leave Closed. RW19 dropped: the "Unknown ... Writ" items boxes give are master writ containers, so they follow Master Writ Containers, not Sealed Master Writs (that one only applies to the sealed writs inside an opened container); the undeposited Unknown Blacksmithing Writ was on Leave Closed. RX4 passed 2026-11-11: with extras on Leave in Bag, no `Extra from crafting` line and the 3 extra potions stayed in the bag through the bank and a merchant. Also seen 2026-11-11: an alchemy writ whose acquire reagent (Mudcrab Chitin) is excluded was left at the crate with the `Not turning in` message, as intended. RW8 passed 2026-11-12: containers that weren't writ rewards were left unopened while reward boxes were being handled. RW18 passed 2026-11-13: an Exemplary Swift Necklace from a jewelry box was marked `(to deposit)` and taken by the bank, along with an Unknown Blacksmithing Writ (Master Writ Containers → Deposit). RW9 dropped: master writ turn-ins at Rolis give only vouchers and gold, no box.

### Milestone 5, step 4: station markers (2026-11-10)

All passed 2026-11-10 (SM1–SM12): houses only; every station found from the house's furniture (shipped crafting-station furnishing list, then the name, then what you've used), in your houses and friends'; cyan markers, turned to the camera, gone once the writ is crafted; Off / All Writs in Your Bag / Queued Writs Only; greyed out and nothing drawn while Essential Housing Tools' master writ markers are on; `/wc stations` diagnostic. SM6 not needed.

Milestone 5 is complete.

### Milestone 5, step 3: Accept & Turn In at Rolis (2026-11-10)

RT11 passed 2026-11-14: with an unfinished enchanting master writ accepted, Accept crafted writs skipped all crafted enchanting writs and only accepted the other crafts'.

All passed 2026-11-10: RT1–RT10 (settings and keybind; crafted writs accepted one after another, a second of the same kind skipped, writs with banked items left alone, nothing-to-accept message; handed in at Rolis without clicking, conversation closed or left open by the setting, next batch accepted afterwards; nothing picked for unfinished writs, at other NPCs, or with the setting off). QR1 (identical writs: the queued one claims the items) passed too.

### Milestone 5, step 2: queue window extras (2026-11-10)

All passed 2026-11-10: QX1 (Station column), QX3 (station sorting), QX4 and QX5 (Mimic box: follows the setting, hover tooltip, click flips it without queuing, verdict follows), QX6 (a chosen mimic stone used at the station and remembered after a reload), QX7 and QX8 (max gold per voucher box, kept in step with Settings even while open), QX9 (Writ column leads with the craft). Rows that can't be queued fade as a whole, except the Mimic box. QX2 skipped (see Results worth keeping).

### Milestone 5, step 1: queue window (2026-11-08)

All passed 2026-11-10: QW1–QW13 (list, tooltips, queue and unqueue, override after confirm, can't-queue message, crafted rows, Show filter, sorting, Enqueue/Dequeue all, summary, live updates, keybind, `/wc help`).

### Fixes of 2026-11-09: alchemy pair search, storage switches

All passed 2026-11-10: AD13 (Essence of Stamina crafted), BS1 (the two new switches in Settings), BS2 (daily switch off: a new item crafted, the stored one left in the bank), BS3 (acquire reagent still taken out with the daily switch off), BS4 (daily switch on: station skips, bank hands it over), BS5 (master switch off: an accepted writ's item in the bank, station crafted another, bank took nothing). A sealed writ with its item in the bank still counts as crafted whatever the switch says; the switch only controls taking items out of storage.

### Milestone 4, step 3: daily enchanting writs (2026-11-05)

All passed. 2026-11-07: Q2, CD1 (alchemy and solvents), RG1, AD11, AD12, FB6, SS6. 2026-11-08: SS4m (smithing master writ create and improve sounds), SS6b (start sound at a smithing station, now played before the first craft). AD10 skipped (see Results worth keeping).

### Milestone 4, step 4: daily smithing writs (2026-11-07)

Passed 2026-11-08: blacksmithing daily at a Grand Master station with No Item Set (3 Rubedite pieces, leave station); a daily and a queued master writ in the same visit at a Grand Master station with Quests only ticked, both crafted; SD1 and SD2 (dailies at ordinary blacksmithing, clothing, woodworking and jewelry stations); SD3 (master writ then dailies in one Grand Master visit: all completed; a daily-only visit starts on No Item Set); SD6 (revisiting all seven stations: no repeat searches of other crafts' tasks, finished stations do nothing); EX1 and EX2 (exclusions window: Not excluded filter, Mark all, Clear marks, wider layout); SD5 (no allowed style material); SS4 (start sound and create glow with a smithing daily); reworded style-material message; corner message moved to the top edge; DB1, DB2, DB3 and DB5 (blue padlock on daily items, gold on master items, tooltip line; kept through "Deliver" and a reload, cleared on turn-in); BW1 (a finished daily item in the bank is taken out when you open the bank); BW2 (locked, traited, above-normal and FCO-marked gear left in the bank); BW3 (house storage chest); BW4 (backpack full message); BW9 (a daily item left in storage isn't crafted again); DB4 (items taken out of storage get the blue padlock); DB6 (blue padlock kept through logout and login); SD4 ("Craft Two Platinum Necklaces: 0 / 2" made both in one craft); MA1 (gold padlock and tooltip for an accepted writ's item, kept through "Deliver" and a relog, cleared on turn-in or abandon); MH1 (master writ items in house storage chests: padlock, taken out when the chest opens, not crafted again); MA2 (accepted master writs crafted at their stations: smithing with improving, enchanting, alchemy, provisioning); DS1 (no daily searches of accepted master writs' delivery tasks, all master writ types); MA3 (queued then accepted: crafted, no queue-removal message); MA5 (setting renamed; off stops accepted writs too); BW8 (one free slot: one item taken, then the backpack-full message); BW7 (sealed writ in the backpack: its items come out of the bank; a writ in the bank and its items stay); BW6 (setting "Take writ items out of storage" and its tooltip). MA1b (accepted writ at "Deliver": its item taken out of the bank); BW5 (accepted master writ's item taken out of the bank); MA4 (accepted writ's item in the bank: station doesn't craft another).

### Optimization pass (2026-11-08)

All passed (OP1–OP6, results under Performance below). The journal is now read once and remembered until a quest changes or the backpack changes; accepted master writs are worked out once per read; items are only re-matched when the set of accepted writs changes; the daily storage check is remembered until a bag changes. Behaviour was unchanged in every rerun test.

### Milestone 4, steps 1 and 2: daily provisioning and alchemy writs

All passed (2026-11-05/06). Findings worth keeping: acquire conditions count the backpack and craft bag but not the bank, so non-ESO Plus players need the bank withdrawal; with ESO Plus an excluded acquire reagent in the craft bag is taken at turn-in anyway (PLAN §2.3). None of the replaced addons played cooking sounds either.

### Performance (milestones 2-4)
Performance, measured with `/wc perf` on the writ-heavy character (60 writs, 695 bag and bank slots):

| | Before (baseline) | After (optimized) |
|---|---|---|
| Already-crafted matching | 3.8 ms, 84 candidates | 2.0 ms, 14 candidates |
| Stock scan | 3.2 ms | 2.0 ms |
| Writ verdicts, first time | 129.8 ms | 8.6 ms |
| Badges, all slots | 1.6 ms | 0.8 ms |

Material shortages (yellow badge), added 2026-11-06: 9.6 ms for all 66 writs at once (verdicts 9.4 ms first time, badges 1.6 ms for 695 slots). Only on-screen rows are worked out, after bags settle, while a bag window is open.

Optimization pass, 2026-11-08 (`/wc perf` right after login, 54 writs, 833 stacks, 695 bag and bank slots, 7 crafting quests with 17 tasks, 1 accepted master writ): journal read 0.2 ms, then 0.0 ms while remembered; accepted master writs 0.2 ms; storage check for 13 daily tasks 4.0 ms first time, 0.0 ms remembered (it used to run on every station check). Others: matching 2.6 ms, stock scan 6.0 ms, verdicts 13.4 ms first time, shortages 12.4 ms, badges 3.2 ms. Rerun in the house after a relog and a quiet minute (17:05): matching 3.2 ms, stock 6.0 ms, verdicts 10.6 ms, shortages 11.6 ms, badges 2.6 ms, journal 0.2 ms, accepted 0.4 ms, storage check 6.2 ms (house chests included). After the fixes (OP6, 17:12, after a reload): storage check 0.8 ms first time (was 5.6–6.2: storage is now scanned once for all tasks, not once per task); badges 2.6 ms, unchanged by removing the per-slot strings. Badges were 1.6 ms on 2026-11-06 once the yellow shortage badge existed (0.8 ms was before it), so the daily and accepted-writ checks add about 1 ms across all 695 slots, about 0.04 ms for the 20 or so rows on screen. Left as is. OP2 passed (17:33, after a full round of dailies on another character): all six crafting stations crafted their dailies in one visit each; that character's badges took 0.6 ms with 2 writs, so the badge cost is mostly the master writ badges. OP3 passed (17:54–17:58): an accepted alchemy master writ crafted 16 poisons alongside the daily, both were skipped at the station while in storage, and the quest turned in (accepted writs back to 0). OP4 passed: a daily item left in the bank was skipped at its station and taken out at the bank. OP5 passed: accepting a master writ whose item was already banked gave it the gold padlock without `/reloadui`, and the station skipped it.

## Results worth keeping
- **QX2 skipped (2026-11-10):** every set is on the user's Grand Master stations, and the list is shared by all characters on the account, so no writ shows a set station. The `<set> (<zone>)` text (LibSets zone) stays untested until someone with fewer attuned sets uses it.
- **QO1 (2026-11-08), not a bug:** a queued master writ wasn't crafted because **Craft queued master writs at stations** was off (debug: `auto-craft false`; the writ was still queued and found). The Quests only filter doesn't affect WritCrafter: dailies crafted at a Grand Master station with it ticked.
- **AD10 skipped (2026-11-07):** solvent in house storage. Moving 31k Alkahest isn't practical, and the solvent lookup only searches backpack, bank and craft bag (as AD11 checks for reagents), so without the solvent nothing is crafted either way.
- **MM2 (2026-11-06):** the warning clears as stock changes. It can't be watched live, because the bank and mail windows replace the inventory window, but it's right the next time a bag list opens.
- **D5 (2026-11-04):** `/wc price 150671` on an item never held gave `Dragon Rheum: 1,848g each (Master Merchant)`. Plain ID links get prices, so no built-in fallback price table is needed.
