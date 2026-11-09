# WritCrafter in-game tests

Run `/reloadui` after every deploy. Note anything unexpected along with the exact chat output.
A Lua error popup at any point is a failure. Copy its first few lines.

Only tests still to do are listed. Passed tests are removed; the full milestone 1–2 list is in this file's git history.

## Milestone 5, step 1: queue window (2026-11-08)

New files, so this deploy needs a **full relog** (character select and back), not `/reloadui`.

| # | Do | Expect |
|---|---|---|
| QW1 | `/wc queue` on the writ-heavy character | Window lists every sealed writ in your backpack and bank: the writ's own description in its quality colour, Where (Backpack/Bank), Vouchers, Cost, Per voucher. Station order: blacksmithing, clothing, woodworking, jewelry, alchemy, enchanting, provisioning |
| QW2 | Hover a row | The writ's tooltip (with WritCrafter's lines) to the left of the window |
| QW3 | Click a writ that's allowed (empty box) | Box ticked; the writ's inventory badge turns to the queued hammer; right-click on it offers "don't craft". Click again: unticked |
| QW4 | Click a greyed-out writ (rejected by your settings) | "Queue anyway?" dialog, in front of the window, with the writ and the reason. Confirm: ticked, inventory badge is the queued hammer (not the red X), and the station crafts it. Cancel: nothing changes |
| QW5 | Click a writ with a red X (can't craft) | Chat: `Can't queue <writ>: <reason>`; nothing queued |
| QW6 | Writs already crafted | Green check; clicking does nothing |
| QW7 | Show: Queued / Not queued / Already crafted / Can't craft | Only those rows |
| QW8 | Click each column heading, then again; then **Sort by station** | Sorts, reverses; Sort by station goes back to station order |
| QW9 | **Enqueue all**, then **Dequeue all** (also with a Show filter on) | Enqueue all ticks only allowed writs among those shown (never greyed or red X ones); Dequeue all unticks the ones shown |
| QW10 | Summary line at the bottom | Queued writs, their vouchers, material cost and cost per voucher; already-crafted writs and vouchers. Changes as you tick |
| QW11 | With the window open, move a writ between backpack and bank, or right-click queue one in the inventory | Within a second the row's Where, or its box, updates |
| QW12 | Controls > Keybindings > Addons: "Show or hide the master writ queue"; set a key and press it twice | Opens, then closes |
| QW13 | `/wc help` | Lists `/wc queue` |

## Fix: alchemy daily missed a plain potion (2026-11-09)

| # | Do | Expect |
|---|---|---|
| AD13 | `/reloadui`, then open the alchemy station with **Craft Essence of Stamina** (first try: "none of your solvents and reagent pairs make this", though Lorkhan's Tears and five Restore Stamina reagents were there) | Crafts it, e.g. `Crafting 4 x Essence of Stamina with Lorkhan's Tears, Blessed Thistle, Columbine` (a pair that shares only Restore Stamina). With Debug chat on, no long pause |
| BS1 | `/reloadui`. Settings → Crafting | "Take writ items out of storage" is now two switches: **Daily writs: use items already in storage** (off) and **Master writs: take items out of storage** (on, or off if you had the old switch off) |
| BS2 | Daily switch off: leave a finished daily item (e.g. a potion or glyph the daily wants) in the bank, open that station | Crafts a new one; no `you already have ... in storage` message. Opening the bank leaves the stored one there |
| BS3 | Daily switch off: an alchemy daily whose acquire reagent is only in the bank, open the bank | The reagent is still taken out |
| BS4 | Daily switch on | Same as before: the station skips the craft (`you already have ... in storage`) and the bank hands it over |
| BS5 | Master switch off: an accepted master writ whose item is in the bank | The station crafts another; opening the bank takes nothing for master writs. Switch on: as before (skipped, then taken out) |

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
- **QO1 (2026-11-08), not a bug:** a queued master writ wasn't crafted because **Craft queued master writs at stations** was off (debug: `auto-craft false`; the writ was still queued and found). The Quests only filter doesn't affect WritCrafter: dailies crafted at a Grand Master station with it ticked.
- **AD10 skipped (2026-11-07):** solvent in house storage. Moving 31k Alkahest isn't practical, and the solvent lookup only searches backpack, bank and craft bag (as AD11 checks for reagents), so without the solvent nothing is crafted either way.
- **MM2 (2026-11-06):** the warning clears as stock changes. It can't be watched live, because the bank and mail windows replace the inventory window, but it's right the next time a bag list opens.
- **D5 (2026-11-04):** `/wc price 150671` on an item never held gave `Dragon Rheum: 1,848g each (Master Merchant)`. Plain ID links get prices, so no built-in fallback price table is needed.
