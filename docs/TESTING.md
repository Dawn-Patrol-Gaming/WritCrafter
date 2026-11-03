# WritCrafter in-game tests

Run `/reloadui` after every deploy. Note anything unexpected along with the exact chat output.
A Lua error popup at any point is a failure. Copy its first few lines.

## Milestone 1: scaffold, stock counts, prices, settings

### A. Load
| # | Do | Expect |
|---|---|---|
| A1 | Open the Add-Ons list | WritCrafter 0.1.0 by @g0thiCiCecReaM, enabled, not flagged out of date |
| A2 | `/wc` | The command list, including `/wc selftest` |
| A3 | `/wc foo` | `Unknown command "foo". Type /wc help.` |
| A4 | `/wc stock` with nothing after it | `Add an item link (shift-click an item into chat) or an item ID.` |

### B. Stock counts
The self-test is the main check. It compares WritCrafter's backpack/bank/craft bag count for **every** stackable item you own against the game's own totals (`GetItemLinkStacks`), which is an independent count.

| # | Do | Expect |
|---|---|---|
| B1 | `/wc selftest` | `Self-test passed: N stackable items checked ...` with N in the hundreds. Any mismatch line shows both counts: copy it. |
| B2 | Move part of a craft-bag material to the backpack, then `/wc stock <it>` | Backpack and craft bag split exactly as moved; Usable unchanged (you already did this one) |
| B3 | Put some **potions or food** in the bank and keep some in the backpack (they can't go in the craft bag), then `/wc stock <it>` | Bank and backpack counts match what you see in each window |
| B4 | Walk away from any banker, then `/wc stock` on an item that's only in the bank | Same bank count as B3. This checks that bank contents are readable away from a banker. |
| B5 | Without `/reloadui`: deposit or withdraw part of a stack, then `/wc selftest` again | Still passes. This checks that counts refresh on bag changes. |
| B6 | Bank more than ~240 slots full? Pick something deposited most recently and `/wc stock` it | Matches the bank window total. Items past the first 240 slots sit in the ESO+ bank bag; this checks it's counted. (Skip if your bank isn't that full.) |
| B7 | `/wc stock 150671` (Dragon Rheum, or any ID you don't own) | Name shown, all zeros, no error |

### C. Locked items
Crafting materials can't be locked, so test with potions, food, glyphs or gear.

| # | Do | Expect |
|---|---|---|
| C1 | Lock one stack of potions in the backpack (right-click → Lock) and leave another stack of the same potion unlocked. Then `/wc stock <potion>` | `(N locked)` with N = the locked stack's size; Usable = total − N |
| C2 | Settings → turn off **Don't use locked items** → `/wc stock` again | No "locked" part; Usable = total |
| C3 | Turn it back on, unlock the stack, `/wc stock` again | No "locked" part |

### D. Prices
| # | Do | Expect |
|---|---|---|
| D1 | `/wc price` Columbine | About 745–750g, source ESO-Hub |
| D2 | Settings → Price source → Master Merchant, then `/wc price` Columbine | About 735g, source Master Merchant |
| D3 | Same with Tamriel Trade Centre | A TTC value, source Tamriel Trade Centre |
| D4 | Same with Arkadius Trade Tools (not installed) | `no price data` |
| D5 | Back to Automatic, then `/wc price 150671` (an item you've never held) | Tells us whether ID-only links work: either a price from Master Merchant/TTC, or `no price data`. Either result is fine, just report which. |

### E. Settings storage (server → account → character)
| # | Do | Expect |
|---|---|---|
| E1 | Open the settings panel | Top line: `Server: NA Megaserver   Account: @g0thiCiCecReaM   Character: <this character>` |
| E2 | Character A, scope **All my characters on this server**: set Chat messages to Debug | |
| E3 | Log in character B (also on All my characters) | Chat messages already Debug |
| E4 | On B: switch to **This character only** | Every setting keeps its current value (it starts from a copy) |
| E5 | On B: set Price source to TTC. Log back to A | A still on Automatic |
| E6 | Log back to B | B still on TTC and This character only |
| E7 | Log out, then tell me | I'll read `SavedVariables\WritCrafter.lua` and check the layout: `["NA Megaserver"]["@g0thiCiCecReaM"]["$AccountWide"]` holding `settings`, `characters` (one entry per character ID with name and scope) and `linkCache` |
