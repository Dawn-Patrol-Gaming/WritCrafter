# WritCrafter in-game tests

Run `/reloadui` after every deploy. Note anything unexpected along with the exact chat output.
A Lua error popup at any point is a failure. Copy its first few lines.

Only tests still to do are listed. Passed tests are removed; the full milestone 1–2 list is in this file's git history.

## Milestone 3, step 4: smithing (create + improve) (2026-11-04)

Provisioning, alchemy and enchanting passed. This step spends real materials (base material, trait gem, style material or mimic stone, improvement mats). Start with a **cheap blue or purple** writ in a motif you know.

| # | Do | Expect |
|---|---|---|
| S1 | ~~Blacksmithing writ at an ordinary set station~~ | **Passed 2026-11-05:** Sword of Redistribution, Epic, Charged, Silver Rose (mimic stone, since Rose Engraving is excluded), CP150; created, improved to Epic, green check, padlocked |
| S2 | ~~Grand Master station, set unlocked~~ | **Passed 2026-11-05:** switched the station to the writ's set by itself, crafted and improved |
| S3 (deferred) | Grand Master station, writ for a set you **haven't unlocked** there | `Can't craft a queued writ: <set> isn't unlocked at this Grand Master station`; nothing spent Deferred: every set is unlocked on your Grand Master stations; test when a new station is placed. |
| S4 | ~~A set station for a different set~~ | **Passed 2026-11-05:** `this station can't make Redistributor pieces ...`, nothing spent |
| S5 | ~~Clothier robe and jerkin~~ | **Passed 2026-11-05** |
| S6 | ~~Woodworking staff or shield~~ | **Passed 2026-11-05** |
| S7 | ~~Jewelry ring or necklace~~ | **Passed 2026-11-05** |
| S8 | ~~Excluded style material uses a mimic stone~~ | **Passed 2026-11-05** (seen in S1: Rose Engraving excluded, Crown Mimic Stone used). Mimic stones = Always is optional. |
| S9 | ~~Short on improvement mats~~ | **Passed 2026-11-05** with 2 Zircon Plating in the craft bag: stopped with the shortage message, never improved below 100% |
| S11 | ~~Alchemy/enchanting material only in the bank~~ | **Passed 2026-11-05:** crafted with Emetic Russula held only in the bank. Stations do use bank materials. |
| S10 | ~~Interrupt mid-way, reopen~~ | **Passed 2026-11-05:** continued with the partly made piece instead of crafting a new one |

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

## Results worth keeping
- **D5 (2026-11-04):** `/wc price 150671` on an item never held gave `Dragon Rheum: 1,848g each (Master Merchant)`. Plain ID links get prices, so no built-in fallback price table is needed.
