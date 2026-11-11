# WritCrafter in-game tests

Run `/reloadui` after every deploy. Note anything unexpected along with the exact chat output.
A Lua error popup at any point is a failure. Copy its first few lines.

Only tests still to do are listed. Passed tests are removed; the full milestone 1–2 list is in this file's git history.

## Daily writ status strip (2026-11-10)

New file, so a **full relog**.

All passed 2026-11-11: WS1–WS8 (default spot above the health, magicka and stamina bars, draggable straight away after a reset; seven craft icons, amber to craft, cyan once crafted, green once turned in, gone after the last turn-in; kept through reloads; movable, position remembered, hidden over menus and by its setting; the game's own icons). Cyan comes from WritCrafter finishing at the station with nothing left to craft for that writ: the game doesn't call a writ waiting for delivery complete. The game's own "quest advanced, main step changed" signal doesn't come when a writ's crafting is done, only when the goods are placed in the crate (seen 2026-11-11), so a writ crafted by hand stays amber until it's turned in.


## Daily writ dialogs: writ boards and delivery crates (2026-11-10)

New file, so a **full relog**.

Passed 2026-11-10: WD1–WD4 (settings; boards accept the ticked crafts' writs and close; crates turn writs in). WD8 answered: the number the game passes with a dialog option is always 0 (Rolis, boards, crates), so options carry no quest; board options read `<Examine the Blacksmith Writs.>`, which contain the learned quest names. WD5 passed (unticked craft: crate left alone). WD10 passed: the delivery crate reported `unit type 3, an object: true` and was turned in through that route; a writ container from the reward stayed closed and a Shipment of Ounces was opened. WD12 passed 2026-11-11: every ticked writ taken from both boards in one go; the board sometimes falls back to its front page without telling add-ons, so WritCrafter now looks at the page half a second after each accept and picks Pull itself (a little slower than Dolgubon's; the pauses can be shortened in milestone 7). WD6, WD7 and WD9 passed 2026-11-11: a writ that would hand over an excluded reagent is left at the crate; other NPCs' finished quests are left alone; all seven daily writ quest names are learned (`blacksmith writ = 1`, `clothier writ = 2`, `enchanter writ = 3`, `alchemist writ = 4`, `provisioner writ = 5`, `woodworker writ = 6`, `jewelry crafting writ = 7`). WD11 passed 2026-11-11 (second character, names learned on the first): each smithing station only searched its own writ's tasks and its Deliver Goods task. All daily writ dialog tests are done.


## Milestone 6, step 1: writ reward boxes (2026-11-10)

New file, so this deploy needs a **full relog**. Set a few actions first in Settings → Writ Rewards (e.g. Survey Reports → Deposit, Repair Kits → Sell, Recipes → Junk).

Passed 2026-11-11: RW1 (Writ Rewards settings), RW2 (boxes open by themselves, one chat line each), RW3 (Junk), RW4 (Deposit at the bank), RW5 (Sell at a merchant), RW15 (no loot window flashing), RK1 (recipes split by quality, Keep a Stack, Sell the Rest offered), RX2 (extra crafted items sold at a merchant, the writ's own kept). Also passed: RW7 (automatic opening off: boxes stay closed), RW10 and RW13 (Master Writ, Survey and Other Containers settings), RX1 (Extra Crafted Potions, Poisons & Food setting). RW12, RW14, RW16 and RW17 passed 2026-11-11: survey containers set to Open are opened; shipments inside boxes are opened and sorted; the corner counts the boxes; every box opened during quick crate turn-ins (one attempt ignored by the game and retried). A box landing while another box is being opened is listed as that box's contents in chat, though it's still opened. RK3 and RX3 passed 2026-11-11: Keep a Stack sold exactly what the boxes gave above a full stack (1 repair kit, 3 soul gems), nothing you had before; several Deposit items (three extra crafted stacks and a survey) all went into the bank. RW6 passed 2026-11-11: with 2 free slots the box stayed closed; once room was made and the house storage closed, both waiting boxes opened by themselves. (A completely full backpack stops the game itself from finishing the turn-in; Sign the Manifest again once there's room.) RK2 passed 2026-11-11: green recipes sold; a blue recipe marked `(to deposit)` and taken by the bank (`Deposited 1`). RW11 passed 2026-11-11: an Unknown Jewelry Crafter Writ (a master writ container) stayed closed on Leave Closed. RW19 dropped: the "Unknown ... Writ" items boxes give are master writ containers, so they follow Master Writ Containers, not Sealed Master Writs (that one only applies to the sealed writs inside an opened container); the undeposited Unknown Blacksmithing Writ was on Leave Closed. RX4 passed 2026-11-11: with extras on Leave in Bag, no `Extra from crafting` line and the 3 extra potions stayed in the bag through the bank and a merchant. Also seen 2026-11-11: an alchemy writ whose acquire reagent (Mudcrab Chitin) is excluded was left at the crate with the `Not turning in` message, as intended. RW9 dropped: master writ turn-ins at Rolis give only vouchers and gold, no box.

| # | Do | Expect |
|---|---|---|
| RW8 | Other containers (a style page, a box from a dungeon, a mail attachment) | Never opened by WritCrafter: only a container arriving within a few seconds of completing a crafting quest counts |
| RW20 | Optional, rare: only happens when placing the goods frees no slot, i.e. a provisioning or alchemy daily whose extras stay in the same stack (or an acquire reagent from the craft bag). Fill the backpack completely after crafting it, then turn it in | Chat: `Can't turn in <writ>: your backpack is full ...`; the writ stays at Sign the Manifest. Make room, talk to the crate again: it's turned in (seen 2026-11-11 with a provisioner writ, no message then). Gear writs free their own slots when the goods are placed, so they never hit this |
| RW18 | Settings → Writ Rewards: **Exemplary Gear (for Research)** after Intricate Gear (Leave in Bag by default); set it to Deposit, get a purple traited piece from a box (e.g. an Exemplary Swift Ring), open the bank | Chat marks it `(to deposit)` and the bank takes it. Any purple (or gold) weapon, armor or jewelry piece with a trait other than ornate or intricate counts; the white and green gear boxes give (e.g. a Rubedite Maul) is left alone |

## Milestone 5, step 4: station markers (2026-11-10)

All passed 2026-11-10 (SM1–SM12): houses only; every station found from the house's furniture (shipped crafting-station furnishing list, then the name, then what you've used), in your houses and friends'; cyan markers, turned to the camera, gone once the writ is crafted; Off / All Writs in Your Bag / Queued Writs Only; greyed out and nothing drawn while Essential Housing Tools' master writ markers are on; `/wc stations` diagnostic. SM6 not needed.

Milestone 5 is complete.

## Milestone 5, step 3: Accept & Turn In at Rolis (2026-11-10)

All passed 2026-11-10: RT1–RT10 (settings and keybind; crafted writs accepted one after another, a second of the same kind skipped, writs with banked items left alone, nothing-to-accept message; handed in at Rolis without clicking, conversation closed or left open by the setting, next batch accepted afterwards; nothing picked for unfinished writs, at other NPCs, or with the setting off). QR1 (identical writs: the queued one claims the items) passed too.

| # | Do | Expect |
|---|---|---|
| RT11 | With an accepted (unfinished) enchanting master writ and many crafted enchanting writs in the backpack, press Accept crafted writs | No enchanting writ is used at all (first try 2026-11-10: it went through the bag trying each one); the other crafts' writs are accepted, one per craft. With nothing else to accept: `No crafted master writs in your backpack to accept (or you already have their quests).` straight away |

## Milestone 5, step 2: queue window extras (2026-11-10)

All passed 2026-11-10: QX1 (Station column), QX3 (station sorting), QX4 and QX5 (Mimic box: follows the setting, hover tooltip, click flips it without queuing, verdict follows), QX6 (a chosen mimic stone used at the station and remembered after a reload), QX7 and QX8 (max gold per voucher box, kept in step with Settings even while open), QX9 (Writ column leads with the craft). Rows that can't be queued fade as a whole, except the Mimic box. QX2 skipped (see Results worth keeping).

## Milestone 5, step 1: queue window (2026-11-08)

All passed 2026-11-10: QW1–QW13 (list, tooltips, queue and unqueue, override after confirm, can't-queue message, crafted rows, Show filter, sorting, Enqueue/Dequeue all, summary, live updates, keybind, `/wc help`).

## Fixes of 2026-11-09: alchemy pair search, storage switches

All passed 2026-11-10: AD13 (Essence of Stamina crafted), BS1 (the two new switches in Settings), BS2 (daily switch off: a new item crafted, the stored one left in the bank), BS3 (acquire reagent still taken out with the daily switch off), BS4 (daily switch on: station skips, bank hands it over), BS5 (master switch off: an accepted writ's item in the bank, station crafted another, bank took nothing). A sealed writ with its item in the bank still counts as crafted whatever the switch says; the switch only controls taking items out of storage.

## Milestone 4, step 3: daily enchanting writs (2026-11-05)

All passed. 2026-11-07: Q2, CD1 (alchemy and solvents), RG1, AD11, AD12, FB6, SS6. 2026-11-08: SS4m (smithing master writ create and improve sounds), SS6b (start sound at a smithing station, now played before the first craft). AD10 skipped (see Results worth keeping).

## Milestone 4, step 4: daily smithing writs (2026-11-07)

Passed 2026-11-08: blacksmithing daily at a Grand Master station with No Item Set (3 Rubedite pieces, leave station); a daily and a queued master writ in the same visit at a Grand Master station with Quests only ticked, both crafted; SD1 and SD2 (dailies at ordinary blacksmithing, clothing, woodworking and jewelry stations); SD3 (master writ then dailies in one Grand Master visit: all completed; a daily-only visit starts on No Item Set); SD6 (revisiting all seven stations: no repeat searches of other crafts' tasks, finished stations do nothing); EX1 and EX2 (exclusions window: Not excluded filter, Mark all, Clear marks, wider layout); SD5 (no allowed style material); SS4 (start sound and create glow with a smithing daily); reworded style-material message; corner message moved to the top edge; DB1, DB2, DB3 and DB5 (blue padlock on daily items, gold on master items, tooltip line; kept through "Deliver" and a reload, cleared on turn-in); BW1 (a finished daily item in the bank is taken out when you open the bank); BW2 (locked, traited, above-normal and FCO-marked gear left in the bank); BW3 (house storage chest); BW4 (backpack full message); BW9 (a daily item left in storage isn't crafted again); DB4 (items taken out of storage get the blue padlock); DB6 (blue padlock kept through logout and login); SD4 ("Craft Two Platinum Necklaces: 0 / 2" made both in one craft); MA1 (gold padlock and tooltip for an accepted writ's item, kept through "Deliver" and a relog, cleared on turn-in or abandon); MH1 (master writ items in house storage chests: padlock, taken out when the chest opens, not crafted again); MA2 (accepted master writs crafted at their stations: smithing with improving, enchanting, alchemy, provisioning); DS1 (no daily searches of accepted master writs' delivery tasks, all master writ types); MA3 (queued then accepted: crafted, no queue-removal message); MA5 (setting renamed; off stops accepted writs too); BW8 (one free slot: one item taken, then the backpack-full message); BW7 (sealed writ in the backpack: its items come out of the bank; a writ in the bank and its items stay); BW6 (setting "Take writ items out of storage" and its tooltip). MA1b (accepted writ at "Deliver": its item taken out of the bank); BW5 (accepted master writ's item taken out of the bank); MA4 (accepted writ's item in the bank: station doesn't craft another).

## Optimization pass (2026-11-08)

All passed (OP1–OP6, results under Performance below). The journal is now read once and remembered until a quest changes or the backpack changes; accepted master writs are worked out once per read; items are only re-matched when the set of accepted writs changes; the daily storage check is remembered until a bag changes. Behaviour was unchanged in every rerun test.

## Milestone 4, steps 1 and 2: daily provisioning and alchemy writs

All passed (2026-11-05/06). Findings worth keeping: acquire conditions count the backpack and craft bag but not the bank, so non-ESO Plus players need the bank withdrawal; with ESO Plus an excluded acquire reagent in the craft bag is taken at turn-in anyway (PLAN §2.3). None of the replaced addons played cooking sounds either.

### Earlier
| # | Do | Expect |
|---|---|---|
| B3 | Optional, whenever it happens naturally: a character with **no** sealed writs in backpack or bank receives one (mail, loot, trade) while the inventory is open | Its badge appears without `/reloadui` (this checks the idle path wakes up) |

Performance, measured with `/wc perf` on the writ-heavy character (60 writs, 695 bag and bank slots):

| | Before (baseline) | After (optimized) |
|---|---|---|
| Already-crafted matching | 3.8 ms, 84 candidates | 2.0 ms, 14 candidates |
| Stock scan | 3.2 ms | 2.0 ms |
| Writ verdicts, first time | 129.8 ms | 8.6 ms |
| Badges, all slots | 1.6 ms | 0.8 ms |

Material shortages (yellow badge), added 2026-11-06: 9.6 ms for all 66 writs at once (verdicts 9.4 ms first time, badges 1.6 ms for 695 slots). Only on-screen rows are worked out, after bags settle, while a bag window is open.

Optimization pass, 2026-11-08 (`/wc perf` right after login, 54 writs, 833 stacks, 695 bag and bank slots, 7 crafting quests with 17 tasks, 1 accepted master writ): journal read 0.2 ms, then 0.0 ms while remembered; accepted master writs 0.2 ms; storage check for 13 daily tasks 4.0 ms first time, 0.0 ms remembered (it used to run on every station check). Others: matching 2.6 ms, stock scan 6.0 ms, verdicts 13.4 ms first time, shortages 12.4 ms, badges 3.2 ms. Rerun in the house after a relog and a quiet minute (17:05): matching 3.2 ms, stock 6.0 ms, verdicts 10.6 ms, shortages 11.6 ms, badges 2.6 ms, journal 0.2 ms, accepted 0.4 ms, storage check 6.2 ms (house chests included). After the fixes (OP6, 17:12, after a reload): storage check 0.8 ms first time (was 5.6–6.2: storage is now scanned once for all tasks, not once per task); badges 2.6 ms, unchanged by removing the per-slot strings. Badges were 1.6 ms on 2026-11-06 once the yellow shortage badge existed (0.8 ms was before it), so the daily and accepted-writ checks add about 1 ms across all 695 slots, about 0.04 ms for the 20 or so rows on screen. Left as is. OP2 passed (17:33, after a full round of dailies on another character): all six crafting stations crafted their dailies in one visit each; that character's badges took 0.6 ms with 2 writs, so the badge cost is mostly the master writ badges. OP3 passed (17:54–17:58): an accepted alchemy master writ crafted 16 poisons alongside the daily, both were skipped at the station while in storage, and the quest turned in (accepted writs back to 0). OP4 passed: a daily item left in the bank was skipped at its station and taken out at the bank. OP5 passed: accepting a master writ whose item was already banked gave it the gold padlock without `/reloadui`, and the station skipped it.

## Later: on the alt accounts (no ESO Plus, low-level crafters)
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

## Results worth keeping
- **QX2 skipped (2026-11-10):** every set is on the user's Grand Master stations, and the list is shared by all characters on the account, so no writ shows a set station. The `<set> (<zone>)` text (LibSets zone) stays untested until someone with fewer attuned sets uses it.
- **QO1 (2026-11-08), not a bug:** a queued master writ wasn't crafted because **Craft queued master writs at stations** was off (debug: `auto-craft false`; the writ was still queued and found). The Quests only filter doesn't affect WritCrafter: dailies crafted at a Grand Master station with it ticked.
- **AD10 skipped (2026-11-07):** solvent in house storage. Moving 31k Alkahest isn't practical, and the solvent lookup only searches backpack, bank and craft bag (as AD11 checks for reagents), so without the solvent nothing is crafted either way.
- **MM2 (2026-11-06):** the warning clears as stock changes. It can't be watched live, because the bank and mail windows replace the inventory window, but it's right the next time a bag list opens.
- **D5 (2026-11-04):** `/wc price 150671` on an item never held gave `Dragon Rheum: 1,848g each (Master Merchant)`. Plain ID links get prices, so no built-in fallback price table is needed.
