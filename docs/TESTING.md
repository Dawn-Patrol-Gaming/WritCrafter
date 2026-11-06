# WritCrafter in-game tests

Run `/reloadui` after every deploy. Note anything unexpected along with the exact chat output.
A Lua error popup at any point is a failure. Copy its first few lines.

Only tests still to do are listed. Passed tests are removed; the full milestone 1–2 list is in this file's git history.

## Milestone 4, step 3: daily enchanting writs (2026-11-05)

| # | Do | Expect |
|---|---|---|
| Q2 | Craft a queued writ at its station | Once crafted the hammer turns into the green check |
| CD1 | `/wc checkdata` | Alchemy: `all N checks match` (about 152), a line naming the reagents with undiscovered traits, then `Confirmed by the game: X of 152 reagent effects` and the reagents still unconfirmed. Any problem line left involves fully discovered reagents, so it's real: paste it. Enchanting 114 and smithing 53 **passed 2026-11-06**. Alchemy history: run 1 counted only pairs that make nothing; run 2 made no potions (solvent slot dropped by a coding mistake); run 3 matched 152 pairs, with the other 75 all being 'game makes nothing' pairs involving rare reagents (undiscovered traits) |
| AD10 | Alchemy daily with the solvent it needs in house storage (other solvents may stay in your bags) | Banner and chat: `none of your solvents and reagent pairs make this; the right solvent or a reagent is probably missing`. With **no** solvent anywhere reachable: `you don't have a solvent`. Nothing crafted. The acquire condition is unaffected |
| AD11 | Same, but the reagents that make it in house storage instead (keep the solvent) | Same `none of your solvents and reagent pairs make this` message. Take them back out and reopen the station (no `/reloadui`): crafts normally |
| AD12 | At an alchemy station with an **enchanting or provisioning** daily you can't make | No alchemy message about it: only alchemy quests' conditions are reported at the alchemy station |
| FB6 | Settings → Crafting: turn off **On-screen notices while crafting writs** and **Leave the station when writ crafting is done** (not the daily/master auto-craft switches). Craft a writ, and one that fails | No top-right message and no mid-screen banner; the start/done/error sounds still play (they have their own switches, SS6); the station stays open afterwards; chat lines still appear. Turn both back on after |
| SS4 | Smithing writ: create, then each improve | Create glow when the piece appears; item-placed then improve-success sound for each tier |
| SS6 | Turn each sound off in turn | Only that sound stops. Turning off on-screen notices hides the alerts and banner but keeps the start/done/problem sounds; turning those sounds off keeps the alerts silent |

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
| L3 | Smithing dailies on a low-level crafter (once built) | Uses the base material for that writ's level |

## Results worth keeping
- **MM2 (2026-11-06):** the warning clears as stock changes. It can't be watched live, because the bank and mail windows replace the inventory window, but it's right the next time a bag list opens.
- **D5 (2026-11-04):** `/wc price 150671` on an item never held gave `Dragon Rheum: 1,848g each (Master Merchant)`. Plain ID links get prices, so no built-in fallback price table is needed.
