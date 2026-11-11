# WritCrafter — Design Plan (v2, after first round of answers)

One addon that crafts everything your journal's crafting writs need (daily and master),
refuses writs it shouldn't do, and always spends the materials you have the most of.

Replaces: **DailyAlchemy, DailyProvisioning, DolgubonsLazyWritCreator, LibLazyCrafting,
LibMarify, LibRecipe, PotionMaker, WritWorthy.** All eight are fully replaced; the crafting
engine (LibLazyCrafting's job) is built into WritCrafter.

Target: PC/Mac, NA server data, APIVersion `101051 101052` (Update 51, released 2026-09-28).

### Decisions so far
| Q | Answer |
|---|---|
| LibLazyCrafting | **Absorb** into WritCrafter (own crafting engine). |
| Acceptable reagents | **Overland plants only**: the 18 classic plant/fungus nodes plus Nightshade and Crimson Nirnroot. |
| "Expensive" | **List + price ceiling**, any item can be marked "too expensive" in settings, and the defaults come from your current price data (§5). |
| Optional v1 features | **Writ reward handling**, the **potion search UI**, and **WritWorthy's master writ queue window** (§2.6.1). Not in v1: pre-craft multiplier. |

---

## 1. Core behaviour

| # | Requirement | How it's handled |
|---|---|---|
| R1 | Auto-craft items for every crafting writ in the journal, daily and master | Read quest conditions at each station, queue crafts, craft on station open (toggle per craft). |
| R2 | Auto-decline alchemy writs needing reagents that aren't overland plants (no chest-only reagents) | Reagent source table (§4). Daily writs can't be previewed, so a rejected one is **abandoned right after you accept it**, with a chat line saying why. Sealed master writs are **never auto-accepted** and get a red tooltip line. |
| R3 | User-configurable rejection; expensive or hard-to-find items rejected by default | Per-category price ceiling plus a per-item override (Allow / Too expensive / Default), seeded from your price data (§5). |
| R4 | Exclude gold (legendary) master writs, per craft type | 7 checkboxes (BS / CL / WW / JW / EN / AL / PR). Excluded writs are never auto-accepted or queued. |
| R5 | Reject writs needing hard-to-find components (prismatic glyphs, rare jewelry traits, …) | Rare-component rules (§6), each one a toggle, on by default. |
| R6 | Use the components you have the most of first | Every choice point (reagent combo, style stone, trait gem when there's a choice, rune stack) picks the option with the highest **minimum stock** across its inputs. Stock = backpack + craft bag + bank. Ties go to the cheapest. |
| R7 | Up to date with current recipes (Update 51) | §3. Reagent traits are read from the game API at load and checked against a static U51 table. |
| R8 | Work with the Grand Master Crafting Stations | §2.6.2. |
| R9 | Never craft items that already exist for current writs in bag or bank | §2.6.3: inventory scan plus a reservation ledger; only the shortfall is crafted. |
| R10 | Inventory icon on each writ that's already crafted | §2.6.4: plus queued, rejected and reserved-item icons, each toggleable. |

---

## 2. Feature inventory of each replaced addon

Legend: **Keep** = in v1 · **Merge** = kept, folded into a shared feature · **Later** = not in v1, could be added · **Skip** = dropped

### 2.1 Dolgubon's Lazy Writ Creator (4.0.5.7.9)

| Feature | Verdict | Notes |
|---|---|---|
| Daily writ autocraft for all 7 crafts, per-craft on/off | **Keep** | Core. |
| Alchemy mode `Off / All / Skip Autocraft` | **Merge** | Becomes the per-craft toggle plus R2/R3 rules. |
| Show craft window / AutoCraft on station open / keybind "Craft items" | **Keep** | A simple "what will be made" panel and a keybind. |
| Exit crafting window when done / hide window when done | **Keep** | |
| Master writ crafting from active quests | **Keep** | |
| Right-click sealed writ → craft (LibCustomMenu) | **Keep** | Adds "Accept", "Queue", "Always ignore". |
| Queue all sealed writs | **Merge** | Into the queue window's "Enqueue All" (§2.6.1). |
| Withdraw writ items from bank, auto bank dialog, despawn banker | **Keep** | One shared bank module. |
| Style stones used (list) / "lowest amount first" | **Merge** | Flipped to **most first** (R6). The per-style allow list stays. |
| Mimic stones for master writs (never / always / if no stone / if price > 1k / > 3k) | **Keep** | Default "when needed": style material too expensive (§5.5) or none in stock. Never replaces an unknown motif. |
| Automatic quest dialog (boards, turn-ins, "Accept the contract") | **Keep** | |
| Abandon "deliver \<item\>" writs | **Merge** | One case of the general reject engine. |
| Craft multiplier / smart multiplier (3-day cycle) | **Later** | Not picked for v1. |
| Consumable multiplier (single / full stack) | **Merge** | With the DA/DP "bulk creation" option. |
| **Writ reward handling**: per reward type × per craft: Leave in bag / Deposit / Junk / Destroy / Deconstruct. Types: mats, surveys, master writs, repair kits, ornate, intricate, soul gems, glyphs, recipes, Psijic fragments, gold mats (non-ESO+) | **Keep** | You picked it. "Destroy" is an option that's off unless you choose it per type. |
| Loot reward containers on receipt / open on login / keep "new" status | **Keep** | Part of reward handling. |
| Loot Anniversary / Zenithar boxes | **Keep** | Part of reward handling. |
| Valuable reward alert | **Keep** | Part of reward handling. |
| Reticle colour at stations | **Later** | |
| Status bar (icons, inventory tracker, colours, position) | **Later** | |
| Hireling mail loot/delete | **Skip** | Not writ crafting. |
| Daily reset warning, stealing protection, easy jewelry-writ DELETE, hide quest announcements, quest buffer, port to crafting house | **Skip** | |
| Writ stats window / reward statistics | **Skip** | |
| Count unearned vouchers / count surveys | **Merge** | Voucher count joins `/wc vouchers`; surveys skipped. |
| Account-wide vs character settings | **Keep** | |
| Skins, onomatopoeia, April Fools quest, tutorial, changelog popup, feedback/donate | **Skip** | |
| Console/gamepad UI | **Skip** | PC only. |
| 7 translations | **Later** | English first; all strings in one table. |

### 2.2 LibLazyCrafting (4.042): absorbed

Only the parts writs need are rebuilt (written fresh, using LLC only as an API reference; it ships with no license):

| LLC capability | Verdict | Notes |
|---|---|---|
| Request queue, per-station dispatch, craft-complete events, retry on failure | **Keep** | Core of `Engine/`. |
| Smithing: create by level / CP + pattern + style + trait + set | **Keep** | Daily and master writs. |
| Smithing: improve to target quality | **Keep** | Master writs (purple/gold). |
| Smithing: deconstruct | **Keep** | Needed by the "Deconstruct" reward action. |
| Enchanting: glyph by potency + essence + aspect IDs | **Keep** | |
| Alchemy: craft by solvent + reagent item IDs | **Keep** | |
| Provisioning: craft by recipe / result item | **Keep** | |
| Furniture crafting | **Skip** | |
| Glyph-to-gear attach, CraftSmithingItemFromLink helpers, set tables | **Skip** | The set index comes from the game API; LibSets is optional. |
| LLC's public API for other addons | **Skip** | WritCrafter won't be a library. |

### 2.3 DailyAlchemy (1.6.0, already U51)

**Reagent count (decided 2026-11-05):** daily alchemy writs always use **two** reagents; only master writs use three. "Acquire a reagent" conditions count the craft bag (confirmed), so with ESO Plus they complete on pickup.

**Excluded acquire reagents (noted 2026-11-05):** with ESO Plus the game counts the craft bag for "acquire" conditions and takes the reagents itself at turn-in, whatever WritCrafter's exclusions say. WritCrafter can't stop that, so: (1) on pickup, warn when an alchemy daily will hand over an excluded reagent (or its potion needs one), and abandon it when auto-abandon is on; (2) automatic turn-in never turns in a writ that would hand over an excluded reagent.

| Feature | Verdict | Notes |
|---|---|---|
| Daily alchemy writ solve and craft | **Keep** | |
| Master alchemy writ ("A Masterful Concoction") | **Keep** | |
| Witches Festival writ | **Keep** | |
| Reagent priority: stock / MM / TTC / ATT / manual | **Merge** | Stock first (R6), price breaks ties; the manual order becomes the allow/expensive overrides. |
| Bulk creation + quantity | **Merge** | Consumable multiplier. |
| Retrieve from bank + delay | **Merge** | Shared bank module. |
| Auto exit station | **Merge** | |
| Don't use locked items (FCOItemSaver) | **Keep, always on** | No setting: game-locked and FCO ItemSaver-marked items are never handed in, spent, deconstructed, junked or destroyed. FCOIS only guards the game's windows, so WritCrafter checks marks itself. Optional dependency. |
| Context menu craft/cancel sealed writ | **Merge** | |
| Log / debug log toggles | **Merge** | One log-level setting. |

### 2.4 DailyProvisioning (1.5.3, APIVersion 101038)

| Feature | Verdict | Notes |
|---|---|---|
| Daily provisioning writ / master ("A Masterful Feast") / Witches Festival | **Keep** | |
| Bulk, bank retrieve, auto exit | **Merge** | |
| Disable if recipe unknown | **Merge** | Into the reject engine. |
| Static FoodAndDrink recipe table | **Skip** | Uses the game API instead. |

### 2.5 PotionMaker (5.11.0): potion search UI kept

| Feature | Verdict | Notes |
|---|---|---|
| Potion search tab at the alchemy station (LibAlchemyStation) | **Keep** | Pick 1–3 traits → list reagent combos you can make. |
| Async search (LibAsync) | **Keep** | |
| Results sorted by stock (R6), with your allowed / too-expensive flags shown | **Keep** | New; ties the UI to the same rules. |
| Filters: use selected reagents only, include missing reagents, include unknown traits, quest-condition potions only, need solvent | **Keep** | |
| Favorites (mark combo, list by reagents / potion / traits) | **Keep** | Cheap to keep. |
| Auto-switch potion/poison tab | **Keep** | |
| ItemSaver / FCOItemSaver protection | **Merge** | Shared lock check. |
| Reagents sorted by quantity | **Merge** | Always on (R6). |
| Main menu entry (LibMainMenu-2.0) | **Keep (optional)** | Only if LibMainMenu-2.0 is installed. |
| Training mode (unknown traits only), fake 3rd slot | **Later** | |
| Show alchemy XP messages, hide new-trait popup, same window coords | **Skip** | |

### 2.6 WritWorthy (7.5.9)

| Feature | Verdict | Notes |
|---|---|---|
| Sealed writ tooltip: materials, total cost, gold per voucher | **Keep** | Plus our accept/reject verdict and the reasons. |
| Tooltip warnings: motif / trait / recipe / skill missing, set trait count | **Keep** | Feed the reject engine. |
| Max gold per voucher | **Keep** | Reject rule, off by default. |
| Include writs from the bank | **Keep** | Default off. |
| Auto-accept writ quests from inventory | **Keep** | With R4/R5 filters. |
| **Master writ queue window** | **Keep** | You picked it. See §2.6.1. |
| Material list window (have / buy / price for queued writs) | **Later** | Shopping list for everything queued. |
| HomeStationMarker integration (marks house stations with queued work) | **Skip** | Not installed. |
| Material list in chat | **Skip** | |
| AGS cost-per-voucher | **Later** | |
| Force EN, station colours, duplicate CMW tooltips, profiler, discover/forget/port | **Skip** | |

#### 2.6.1 Master writ queue window (from WritWorthy)

The time saver: **craft every sealed writ in your bag without accepting any of them**, then accept and turn them all in at once.

**Right-click queueing stays permanently** (decided 2026-11-04): right-clicking a sealed writ offers "craft this writ" / "don't craft this writ", sharing the same per-character queue as the window. The window adds bulk actions and overview; it doesn't replace the right-click.

Workflow:
1. Open the window (`/wc` or a keybind). Every sealed writ in your bag is listed (bank too, if that setting is on).
2. **Enqueue All**, or tick individual rows.
3. Visit each station. Queued items for that station craft automatically, and you're dropped out of the station when it's done.
4. Stand at Rolis Hlaalu and press **Accept & Turn In**. Each crafted writ is opened, accepted and handed in one after another, with no dialog clicking.

What's in the window:

| Part | Behaviour |
|---|---|
| Columns | Queued ☐, Mimic ☐, type, item / glyph / potion / food, quality, detail columns (trait, set, motif, …), vouchers, material cost, cost per voucher. All sortable. |
| Row state | Not queued / Queued / Completed / Can't queue. A row that can't be queued shows the reason when you hover it. |
| Enqueue All / Dequeue All | Enqueue All only takes rows that pass every rule (R2–R5, knowledge, max gold per voucher). |
| Manual override (new) | A row rejected only by *policy* (too expensive, gold writ excluded, rare component) can still be ticked by hand, after a confirm. Enqueue All never does this. "Can't craft" rows (unknown motif, recipe or trait) can't be overridden. |
| Mimic ☐ per row | Defaults from the global mimic policy; you can flip it per writ. |
| Sort by Station | Groups rows in station order so you walk the stations once. |
| Max gold per voucher | Edit box in the window, same setting as the tooltip rule. |
| Summary bar | Queued: writs, vouchers, mat cost, cost per voucher. Completed: the same four. |
| Persistence | Queued and completed state is saved per character, keyed by each writ's unique ID, so it survives reloads, logouts and moving writs to the bank. |
| Stock-first | Crafts drawn from the queue still follow R6 (most-stocked reagents and style stones first). |

#### 2.6.2 Grand Master Crafting Stations ("master crafter tables")

Added in Update 40: one furnishing per craft (Blacksmithing, Clothing, Woodworking, Jewelry). You feed it attuned set stations, and it can then craft every set it has consumed (80 attunable sets). In the API this is the **consolidated station**: `GetCraftingInteractionMode() == CRAFTING_INTERACTION_MODE_CONSOLIDATED_STATION`, plus `GetNumConsolidatedSmithingSets`, `GetConsolidatedSmithingItemSetIdByIndex`, `IsConsolidatedSmithingItemSetIdUnlocked`, `SetActiveConsolidatedSmithingSetByIndex` and `GetActiveConsolidatedSmithingItemSetId`.

**Why WritWorthy struggles there.** WritWorthy does all its crafting through LibLazyCrafting 4.042. From reading the code (not yet reproduced in game):
1. **Pattern offsets disagree.** The "can I craft this?" check uses no set-pattern offset at a Grand Master station (`Smithing.lua:448`), but the actual craft call always adds the set-station offset for set items (`Smithing.lua:1295-1298`). One of the two is wrong at these stations, so items either fail as uncraftable or the request is built with the wrong pattern.
2. **Set switching is done by clicking the UI.** On keyboard, LLC changes the active set by clearing the search box and selecting a tree node (`Smithing.lua:1258-1261`), and doesn't wait for the switch before crafting. Only the gamepad/console path calls `SetActiveConsolidatedSmithingSetByIndex`. Result: it crafts with the previous set still active, or fails.
3. **Wrong-station false positives.** `canCraftItemHere` (`Smithing.lua:546-549`) says yes whenever the set is unlocked in your Grand Master station, even at an ordinary single-set station.
4. **Set probe can error.** `GetCurrentSetInteractionIndex` (`Smithing.lua:515-537`) probes with set-station pattern numbers. At a Grand Master station that can return "no set", and it then indexes `SetIndexes[nil]`, which throws a Lua error.
5. **WritWorthy's own check** (`WritWorthy_Window.lua:1439`) treats every set except the currently selected one as "wrong station", and **Sort by Station** doesn't know Grand Master stations exist.

**How WritCrafter handles them (first-class, not bolted on):**
| Area | Design |
|---|---|
| Where can this be made? | Every smithing request records its options: *Grand Master* (set unlocked there), *the set's own station* (name and zone), or *any station* (no set). |
| Crafting at a Grand Master station | Takes every queued request whose set is unlocked there, grouped by set. Switches sets through `SetActiveConsolidatedSmithingSetByIndex` and **waits until `GetActiveConsolidatedSmithingItemSetId()` confirms the switch** before crafting. Restores your previous selection when done. |
| Patterns | No hardcoded offsets. Pattern indexes are found at runtime by probing `GetSmithingPatternResultLink` + `GetItemLinkSetInfo` at the current station. The result link is checked for the right set, item and trait before every craft. |
| Ordinary set station | Crafts only that station's set; never assumes Grand Master unlocks apply. |
| No-set items (daily writs) and improvement at a Grand Master station | Supported if the station allows them (check in game). Otherwise skipped with a chat line telling you which station to use. |
| Knowing your unlocked sets away from the station | The unlocked-set list is cached per account each time you use a Grand Master station, so tooltips and the queue window know about it anywhere. |
| Queue window | A **Station** column shows *Grand Master*, the set station and zone, or *Any*. **Sort by Station** puts all Grand Master rows together, so one visit per craft clears them. |
| Tooltips | "Craftable at your Grand Master station" vs "Needs the \<set\> station in \<zone\>". |
| Universal deconstruction station | Used for the "Deconstruct" reward action (`CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION`). |

**In-game checklist for milestone 3.** For each of the four crafts at a Grand Master station: craft a set item; switch sets mid-queue; craft a no-set item; improve to purple/gold. Then at an ordinary set station, confirm it only crafts that set.

#### 2.6.3 Never re-craft what's already made

Before anything is queued or crafted, WritCrafter checks whether a matching item **already exists** in your backpack, bank or ESO+ bank, whether it was made by WritCrafter, another addon or by hand. It only crafts the shortfall.

| Writ | What counts as "already made" |
|---|---|
| Daily writ (in the journal) | Any item where `DoesItemLinkFulfillJournalQuestCondition` passes for that condition. Its count is subtracted from what's needed. Matching items in the bank are withdrawn instead of crafted. |
| Sealed master writ, smithing | Same base item and material level (CP150/160), set, trait, motif, quality, crafted by a player. |
| Sealed master writ, enchanting | Same glyph, potency level and quality. |
| Sealed master writ, alchemy | Same potion or poison, read by its effects and solvent level from the link (works for the new U51 potion types too). |
| Sealed master writ, provisioning | Same result item and quantity. |

**Reservations.** Each matching item (or each unit of a stack) is **assigned to one writ**. Two identical writs need two items; one item never counts for both. Assignments are rebuilt from a fresh inventory scan on login, on bag/bank changes and when the queue window opens, so selling, deconstructing or using an item un-assigns it automatically. The queue window's saved "completed" state is a hint only: the scan decides.

**Protection.** Items assigned to a writ are never touched by WritCrafter's own reward actions (deposit, junk, destroy, deconstruct). They also get a small "reserved for a writ" icon (see §2.6.4), so you don't sell them by mistake.

**Turn-in.** A crafted item has to be in your backpack when you accept its sealed writ. **Accept & Turn In** first lists any assigned items still in the bank, and withdraws them when a bank is open.

#### 2.6.4 Writ status icons in your inventory

A small icon is drawn next to each sealed master writ in the backpack, bank, ESO+ bank and house storage lists:

| Icon | Meaning | Default |
|---|---|---|
| ✔ green | **Crafted**: an item for this writ is already in your bag or bank (§2.6.3) | On (you asked for this) |
| ⏳ yellow | **Queued** in the queue window, not crafted yet | On |
| ✖ red | **Rejected** or can't be crafted (hover the writ for the reason) | On |
| 🔒 on the crafted item itself | **Reserved** for a writ | On |

Each icon has its own on/off setting, plus an icon position nudge (left/right offset). That keeps it from overlapping icons from other addons you run, such as FCOItemSaver, IIfA, CraftStore or AdvancedFilters. Hovering a writ shows the same status as a tooltip line (e.g. "Crafted — item is in your bank").
Implementation: a post-hook on the inventory list row setup for each bag's list view, reusing one texture control per row. Row status comes from the reservation ledger (§2.6.3), so it's an O(1) lookup while scrolling.

### 2.7 LibMarify / 2.8 LibRecipe: **Skip** (game API + ~50 lines of our own helpers)

### 2.9 Library dependencies (revised)

| Library | Verdict | Why |
|---|---|---|
| LibAddonMenu-2.0 | **Required** | Settings panel |
| LibCustomMenu | **Required** | Right-click actions on sealed writs and items |
| LibPrice | **Required** | MM / TTC / ATT live prices |
| LibAlchemyStation | **Required** | Potion search tab |
| LibAsync | **Required** | Potion search + alchemy solver off the main frame |
| LibEsoHubPrices | **Optional** | Read directly; LibPrice has no ESO-Hub source, and it's the best-covered source in your data |
| LibMainMenu-2.0 | **Optional** | Main-menu button for potion search |
| LibSets | **Required** | Traits needed per crafted set (rejects writs you can't craft) |
| LibCharacterKnowledge | **Required** | Motif knowledge from anywhere, not just at a station |
| FCOItemSaver | **Optional** | Locked-item protection |
| LibLazyCrafting | **Dropped** | Absorbed |
| LibAlchemy | **Dropped** | Optimises by price, not stock; its U51 DB is only a cross-check |
| LibItemLink, LibMarify, LibRecipe | **Dropped** | Unused or replaced by the game API |

---

## 3. Update 51 crafting changes to build in

Source: UESP's copy of the Update 51 patch notes. News post 70379 is the Update 51 alchemy-changes post, confirmed by the "Addon formulas for alchemy changes" session, which updated your DailyAlchemy for it.

- Increase Spell Power + Increase Weapon Power → **Increase Power**; Spell + Weapon Critical → **Critical**
- **Maim removed** (old Maim potions became Cowardice); **Enervation** now counters **Force**
- New traits: **Mending, Vexation, Damage Shield, Heal Absorption**
- New reagents: Cultivated Cryptpods 224357 (solo dungeons), Daedra-Blood Maggots 224358 (IC sewers), Fossilized Verminous Bones 224359 (treasure maps), Winter's Grave Tongue 224360 (icy zones, wood/undead)
- 14 reagents with changed traits: Blue Entoloma, Stinkhorn, Namira's Rot, White Cap, Blessed Thistle, Lady's Smock, Bugloss, Nirnroot, Water Hyacinth, Torchbug Thorax, Spider Egg, Butterfly Wing, Scrib Jelly, Powdered Mother of Pearl
- Master writs with impossible combos were rewritten. **Known bug**: the poison writ asking for Cowardice + Hindrance + Detection can't be done, so it's auto-rejected with a "hold this writ" note.
- No provisioning, enchanting or equipment recipe changes were found in the U51 notes.

### 3.1 Lessons from the DailyAlchemy Update 51 update (earlier session)
- **Reagent data source.** Use the reagent tables in the installed addons, not UESP's list. Dolgubon's `Alchemy.lua` (`reagentInfo`), `WritWorthy_Alchemy.lua` and `LibAlchemy_Database.lua` agree on the traits of all 38 reagents, and they show **17** reagents changed, against the 14 in UESP's patch-note list. WritCrafter's static table is cross-checked against all three, and against the game API at load.
- **Effect IDs** pair up: odd = effect, even = its counter (… 33/34 Damage Shield / Heal Absorption, 35/36 Force / Enervation, 37/38 Mending / Vexation). Old IDs 13, 14, 17, 18 still resolve to Increase Power, Cowardice, Critical, Enervation. Heroism's counter is **Timidity** (DailyAlchemy had it wrong on three reagents).
- **Potion naming changed.** Update 51 names a potion by a new trait priority, so a combo that *contains* the requested effect can produce a differently named potion. Daily writs therefore only use **two-reagent combos whose result has exactly the requested effect and nothing else**. All 34 effects still have 3–24 such combos.
- **Check the result before crafting.** At the station, `GetAlchemyResultingItemLink` must match the writ (and `DoesItemLinkFulfillJournalQuestCondition` must pass). Any combo that would make the wrong item is skipped.
- **Master writs** read their three effects straight from the sealed writ's item-link fields, which works in every client language.
- **Known gap: no item IDs for the new potion types** (Essence of Force, Mending, Vexation, Damage Shield, Heal Absorption and their poisons). Outside a station, tooltips, the queue window and potion search show these by trait names and price them from their reagents. The real potion name only comes from the station's result link.

---

## 4. Reagent source categories (R2)

| Category | Reagents | Default |
|---|---|---|
| **Overland plants** (20) | Blessed Thistle, Blue Entoloma, Bugloss, Columbine, Corn Flower, Crimson Nirnroot, Dragonthorn, Emetic Russula, Imp Stool, Lady's Smock, Luminous Russula, Mountain Flower, Namira's Rot, Nightshade, Nirnroot, Stinkhorn, Violet Coprinus, Water Hyacinth, White Cap, Wormwood | Allowed, unless too expensive (§5.1) |
| Critter / animal parts | Beetle Scuttle, Butterfly Wing, Fleshfly Larva, Mudcrab Chitin, Scrib Jelly, Spider Egg, Torchbug Thorax | Rejected |
| Zone-specific creatures | Clam Gall, Powdered Mother of Pearl, Chaurus Egg, Vile Coagulant, Dragon's Blood, Dragon's Bile, Dragon Rheum | Rejected |
| U51 special sources | Cultivated Cryptpods, Daedra-Blood Maggots, Fossilized Verminous Bones, Winter's Grave Tongue | Rejected |

Any reagent can be overridden in settings.

---

## 5. "Too expensive" defaults from your price data

**Method.** Unit price = ESO-Hub NA *suggested sale price* (LibEsoHubPrices data dated 2026-11-02), cross-checked against the median per-unit price in your own MasterMerchant sales history (GS00–GS17, 4,818 items). Where the two disagree, ESO-Hub wins because it has thousands of sales against MM's handful (e.g. Winter's Grave Tongue: one MM sale at 60,000g vs ESO-Hub ~325g).

**Ceilings are per category** because writs use very different quantities of each. Every ceiling sits in a natural price gap in your data, so the default list is stable against normal price drift:

| Category | Default ceiling | Gap it sits in |
|---|---|---|
| Alchemy reagents | **300g** | Bugloss ~185 → Violet Coprinus ~480 |
| Enchanting runes | **500g** | Oko ~225 → Indeko ~860 |
| Trait materials | **1,000g** | Cobalt ~370 → Titanium ~2,030 |
| Provisioning ingredients | **300g** | Bervez Juice ~45 → Cyrodiil Citrus ~650 |
| Style materials | **1,000g** → use a mimic stone instead of rejecting | Ancient Sandstone ~830 → Funerary Wrappings ~1,075 |
| Improvement mats (temper/resin/tannin/plating) | not price-filtered | Listed under each smithing craft in the exclusions window, none excluded by default; excluding one rejects writs that need it and stops improving at that tier. The gold-writ toggles (R4) still apply |

The shipped default list is fixed from today's snapshot. A setting **"Re-check against live prices"** (default off) re-applies the ceilings on login.

### 5.1 Alchemy reagents marked too expensive (allowed plants only)
| Reagent | ESO-Hub | Your MM |
|---|---|---|
| Columbine | ~750 | 735 |
| Violet Coprinus | ~480 | 549 |

Allowed plants for comparison: Bugloss ~185, Mountain Flower ~138, Crimson Nirnroot ~125, everything else under 100g.
(All non-plant reagents are already rejected by §4: Dragon Rheum ~1,825, Dragon's Blood ~1,500, Fossilized Bones ~1,495, Mudcrab Chitin ~740, …)

### 5.2 Enchanting runes marked too expensive
| Rune | ESO-Hub | Your MM | Effect |
|---|---|---|---|
| Hakeijo | ~14,800 | 16,000 | Prismatic Defense / Onslaught glyphs |
| Kuta | ~5,000 | 5,000 | Gold (legendary) aspect |
| Indeko | ~860 | 400 | |

### 5.3 Trait materials marked too expensive
| Material | Trait | ESO-Hub | Your MM |
|---|---|---|---|
| Aurbic Amber | Jewelry Infused | ~37,000 | 37,448 |
| Potent Nirncrux | Weapon Nirnhoned | ~11,000 | 13,500 |
| Dibellium | Jewelry Harmony | ~6,750 | 8,500 |
| Dawn-Prism | Jewelry Triune | ~5,450 | 6,325 |
| Fortified Nirncrux | Armor Nirnhoned | ~4,500 | 5,000 |
| Gilding Wax | Jewelry Swift | ~3,650 | 3,850 |
| Slaughterstone | Jewelry Bloodthirsty | ~3,275 | 3,583 |
| Titanium | Jewelry Protective | ~2,030 | 2,000 |

Allowed: Cobalt (Arcane) ~370, Zinc (Robust) ~237, Antimony (Healthy) ~190, and all weapon/armor trait gems (< 10g).

### 5.4 Provisioning ingredients marked too expensive
Aetherial Dust ~145,500 · Rubyblossom Extract ~90,000 · Perfect Roe ~37,500 · Diminished Aetherial Dust ~30,800 · Red Lichen ~3,000 · Cyrodiil Citrus ~650

### 5.5 Style materials over the ceiling (use a mimic stone)
Dragon Bone ~5,900 · Pristine Daedric Heart ~3,750 · Stendarr Stamp ~4,400 · Ivory Brigade Clasp ~4,500 · Shimmering Sand ~3,000 · Culanda Lacquer ~2,300 · Vitrified Malondo ~2,200 · Arkthzand Sprocket ~1,800 · Tempered Brass ~1,400 · Funerary Wrappings ~1,075 · Voskrona Jade Clusters ~1,000

### 5.6 Worth knowing
- **Zircon Plating (~2,650)** is needed for *purple* jewelry master writs. It isn't price-filtered (improvement mats are exempt), so purple jewelry writs are allowed. Gold improvement mats (Chromium ~11,200, Tempering Alloy ~9,200, Dreugh Wax ~7,750, Rosin ~800) only matter for gold writs (R4).
- The reagent prices in DailyAlchemy's built-in table run about double your data for cheap plants, so we don't reuse its numbers.

---

## 6. Rare-component rules (R5), all on by default

| Craft | Rejected by default | Rule source |
|---|---|---|
| Enchanting | Prismatic Defense / Onslaught | Hakeijo is too expensive (§5.2) |
| Enchanting | Gold glyphs | Kuta (§5.2) and the gold toggle (R4) |
| Jewelry | Infused, Harmony, Triune, Swift, Bloodthirsty, Protective | §5.3 |
| BS / CL / WW | Nirnhoned | §5.3 |
| BS / CL / WW / JW | Motif unknown (a mimic stone only replaces the material of a known style) | Can't craft |
| BS / CL / WW / JW | Style material too expensive and mimic policy "never" | Rejected |
| Smithing sets | Set trait count not met / set unknown | Can't craft |
| Provisioning | Recipe unknown; any ingredient too expensive | §5.4 |
| Alchemy | Any combo needing a rejected reagent; known-impossible writ | §3, §4, §5.1 |
| Any master writ | Gold per voucher above ceiling (off by default) | Carried over from WritWorthy |

---

## 7. Architecture

```
WritCrafter/
  WritCrafter.addon        APIVersion 101051 101052
                           DependsOn: LibAddonMenu-2.0 LibCustomMenu LibPrice LibAlchemyStation LibAsync
                           OptionalDependsOn: LibEsoHubPrices LibMainMenu-2.0 LibSets LibCharacterKnowledge FCOItemSaver
  Strings/en.lua
  Data/Reagents.lua        U51 reagents: id, 4 traits, source category
  Data/PriceDefaults.lua   §5 ceilings + default too-expensive item ids (snapshot 2026-11-02)
  Core/                    Init, SavedVars, Log, Inventory (stock counts, locks), Bank, Price (LibPrice + ESO-Hub),
                           Reservations (match existing items to writs, one item per writ)
  Engine/                  Queue, Smithing (create / improve / deconstruct), Enchanting, Alchemy, Provisioning
  Rules/                   Reject engine: evaluate(writ) → {ok, reasons[]}; per-category rules
  Writs/                   Daily (journal parsing, auto-abandon), Master (sealed-writ link parsing, auto-accept, queue)
  Solver/Alchemy.lua       valid combos → filter → max-min-stock → price tie-break
  Rewards/                 container looting, per-type actions, valuable alerts
  UI/                      Tooltip, InventoryIcons, StationPanel, ContextMenu, QueueWindow, PotionSearch (LibAlchemyStation tab), Settings,
                           ExclusionsWindow (material exclusions: full per-category lists rebuilt on open, opened from the
                           settings' category buttons or /wc exclusions; the settings panel keeps only non-item options)
```

Every planned craft is checked with `DoesItemLinkFulfillJournalQuestCondition` before crafting, so a wrong guess never wastes materials.

### 7.1 Only run when there's writ work
WritCrafter is only for crafting writs, so with nothing writ-related in play it should cost next to nothing. **Writ work** means either of:
- **sealed master writs** in the backpack or bank, or
- **crafting writ quests** in the journal: daily writs (all seven crafts) and accepted master writs.

With neither, WritCrafter stays idle: a bag change costs one item-type check of the changed slot (no bag scan, no list redraw), opening a crafting station does nothing, and craft bag changes are ignored outright (materials are never writ items). A single `HasWritWork()` check, kept current by bag changes for sealed writs and by `EVENT_QUEST_ADDED` / `EVENT_QUEST_REMOVED` / `EVENT_QUEST_COMPLETE` for quests, gates everything below.

| Feature | Runs when |
|---|---|
| Writ tooltips | hovering a sealed writ (always on demand) |
| Badges and already-crafted matching (M2) | sealed writs exist |
| Already-crafted matching for daily writs (M4) | daily writ quests exist |
| Crafting engine, station panel, auto-craft (M3–M5) | writ quests exist (daily or accepted master) |
| Queue window (M5) | sealed writs or master writ quests exist |
| Reward handling (M6) | writ reward containers arrive (turn-in), regardless of the above |

Everything else stays on demand: rules, prices and the alchemy solver run only when a tooltip or plan asks; stock is scanned only when asked.

**Status:** the sealed-writ half is built (M2: `Reservations` tracks the sealed writ count and ignores irrelevant bag changes). The quest half and `HasWritWork()` arrive with the quest code in M3/M4; M2 has no quest-driven features yet.

---

## 8. Milestones

1. **Scaffold**: manifest, settings skeleton, saved vars, logging, inventory counts, price lookups.
2. **Rules, detection and read-only UI**: data tables, reject engine, sealed writ verdicts, already-crafted detection and reservations (§2.6.3), inventory status icons (§2.6.4). No crafting, so it's safe to check every verdict and icon in game against writs and items you already have.
3. **Crafting engine**: queue, then provisioning → alchemy → enchanting → smithing create → improve → deconstruct, each verified at a station before the next. Smithing is tested at **Grand Master stations and ordinary set stations** from the start (§2.6.2 checklist).
4. **Daily writs**: all 7 crafts, bank withdraw, auto-exit, quest dialog, alchemy auto-abandon. Also done here (2026-11-08): crafting, badges and storage withdrawal for **accepted** master writs, house storage chests.
   - **Optimization pass before milestone 5** (asked 2026-11-08), once milestone 4's tests pass. **Done and tested 2026-11-08** (TESTING.md OP1–OP6) for all suspects below except the "Deliver Goods" one: no language-independent way found yet to tell a delivery task from a craft task. Measure first (extend `/wc perf`), change only what the numbers show, keep behaviour identical, then rerun the tests that cover what changed. Known suspects:
     - The journal is rescanned in many places per station step (`Daily.Conditions` from each job's State, Progress, Check and Craft; `Master.Accepted`; the storage check; `OnGone`). One cached snapshot, cleared by quest events.
     - `Master.Accepted` rebuilds writ objects on every call, and for daily quests without a record it checks every task's master writ info on every call. Cache writs per record, and remember quests that aren't master writs.
     - Every quest progress change re-matches all bags (`Reservations` goes dirty). During a run of daily crafts that's one full re-match per craft when a bag window next draws; check whether progress changes need a re-match at all once a writ's details are remembered.
     - The storage checks (`Bank.Stored` for dailies) scan the whole bank on every Check call; one scan per station visit would do.
     - A daily quest's "Deliver Goods" task is searched by every smithing resolver once per session (seen in debug 2026-11-08). Skip tasks of a quest whose crafting tasks are all done, without reading the task text.
     - Dead code and duplicates left by this milestone's rewrites (e.g. the two "is this a master writ condition" paths).
5. **Master writs**: sealed-writ parsing, the queue window (§2.6.1) with saved per-character state, crafting from the queue, Accept & Turn In at Rolis, mimic policy, voucher count.
   - **Build order (2026-11-08):** (1) queue window: list of backpack and bank writs, queue/unqueue by click, override of rejected writs after a confirm, Show filter, sortable columns, Sort by station, Enqueue/Dequeue all, summary, `/wc queue` and a keybind (done, tested 2026-11-10). (2) Window extras: per-row Mimic, a Station column (Grand Master / set station / any) from a cached list of your Grand Master sets, the max gold per voucher box (done, tested 2026-11-10: the Grand Master set list is remembered account-wide per server, added to each time you use a Grand Master station; a Mimic choice is per character, keyed by the writ's link, and forgotten once the writ is gone). (3) Accept & Turn In at Rolis (done, tested 2026-11-10: an Accept crafted writs button and keybind use crafted backpack writs whose items are in the backpack, like WritWorthy did; talking to Rolis stays manual, and the turn-in options are then picked by type, completing only accepted master writ quests; switches for turning in, closing the conversation afterwards, and accepting the next batch). (4) Station markers (done, tested 2026-11-10; **houses only**, decided 2026-11-10: out in the world you're at the station when you need it. Stations come from the house's furniture: Data/Stations.lua lists every crafting-station furnishing by item ID (from UESP, worked out to furniture IDs in game; covers themed stations like the Maormer Cookfire and the Grand Master stations), then the name (attuned set stations carry the set; names can be cut short, so sets match by their start), then furniture you've used. Missing furnishings get added to the list when reported; Off / All Writs in Your Bag / Queued Writs Only, off by default; greyed out and drawing nothing while Essential Housing Tools' master writ markers are on). Sealed-writ parsing, crafting from the queue and the mimic policy were already done in milestones 2 and 3.
   - **Station markers for queued writs** (asked 2026-11-06, deferred to this milestone): an icon over each station that can craft a queued master writ: the set's own crafting stations and Grand Master stations that have the set (in houses and in the world), plus the alchemy, enchanting and provisioning stations for those writs. Needs the stations' positions (ordinary set stations are fixed per zone; house stations are found as you visit them), 3D markers above them, and map pins. Prior art: **HomeStationMarker** (by WritWorthy's author), a separate addon that WritWorthy and LibLazyCrafting both call (`HomeStationMarker.AddMarker(setId, craftingType)` / `DeleteMarker`) to mark stations **inside player houses**; it records house station positions itself. Not installed now (checked 2026-11-06). **Already covered in houses by Essential Housing Tools** (installed): its setting "Show Master Writ crafting station Points of Interest" (on by default) puts a gold crafting icon over each attuned set station in a house for every master writ in your **backpack** not yet crafted for (not bank, not accepted quests). It has no API for other addons. So WritCrafter's part is only what EHT leaves out: Grand Master stations (their names carry no set, so EHT can't match them), stations outside houses, and possibly "queued writs only".
     - **Settings (decided 2026-11-06, revised):** station markers *Off / All master writs in your bag / Queued writs only*, **Off by default**. WritCrafter is the newcomer, so it defers to Essential Housing Tools entirely: while EHT is loaded with its master writ markers on (`EHT.GetSetting("ShowMasterWritPOIs")`, read with a nil check since it isn't ours), WritCrafter draws **no markers anywhere** (not even Grand Master or outdoor stations), its setting is forced Off and greyed out, and the tooltip says why ("Essential Housing Tools is marking stations; turn its master writ markers off to use these"). Only with EHT absent or its option off can the player turn WritCrafter's markers on, by hand. If EHT's option is turned on later, WritCrafter's markers switch off again.
     - **Look:** the same marker the game shows over a station for a daily writ (its floating quest marker, compass pin and map pin textures), tinted a different colour so it reads as "master writ". Addons can't add entries to the game's own quest markers, so WritCrafter draws these itself from the game's textures; positions come from WritCrafter, not the quest.
   - **Daily writ dialogs** (built 2026-11-10, in testing; the milestone 4 "quest dialog" item): accept daily writs at writ boards and turn them in at delivery crates, each per craft (all on by default). Not relying on English where possible (user, 2026-11-10): each daily writ's quest name is learned in the game's language the first time a station claims that quest, and boards and turn-ins match learned names; a crate's turn-in option is recognised by the quest the game attaches to it, if it does (checked with WD8); the English writ words and crate wording in Strings/en.lua are only a first-day fallback. A writ that would hand over an excluded reagent is never turned in for you. Still open from milestone 4: the alchemy pickup warning / auto-abandon.
6. **Reward handling** (decided 2026-11-10). One action per reward kind (not per craft): Leave in Bag (default), Deposit (at the next bank visit), Junk (right away), Sell (at the next merchant); no Destroy. Reward boxes open automatically by default. A reward box is recognised language-independently: a container arriving within a few seconds of completing a crafting quest.
   - Step 1 (built 2026-11-10, in testing): open boxes, chat summary, Leave / Deposit / Junk / Sell per kind.
   - Step 2: **Deconstruct** for ornate and intricate gear and glyphs, at the next matching station (smithing, enchanting, or the universal deconstruction station). Done as **one batch**, the way the game's deconstruction screen sends several selected items at once (`PrepareDeconstructMessage` / `AddItemToDeconstructMessage` / `SendDeconstructMessage`), not one item at a time: Dolgubon's one-at-a-time deconstruction usually only got through one or two items (user, 2026-11-10).
   - Later in the milestone: valuable-reward alert, Zenithar and anniversary boxes.
7. **Clean-up and optimization pass** (reviewed 2026-11-11, scheduled as its own milestone so fixing what's broken now comes first). Behaviour stays identical; done in four batches, each deployed and checked in game on its own with TESTING.md rows for the flows it touches. Commit a known-good state before starting.
   - **Batch A, speed:**
     - `Inventory.FindForStation` walks backpack, bank and ESO Plus bank on every call, and alchemy calls it per reagent: `AlchemySolver.Choose` (about 70 full scans per master alchemy craft), `OwnedReagents`, and the daily pair sort's comparator (four lookups per comparison). Enchanting, `Rules.Evaluate` and `/wc checkdata` use it too. Record each item's station slot and usable total during the stock scan `Inventory` already does (same order: craft bag, largest backpack stack, largest bank stack; protected stacks skipped), so a lookup reads that record. Invalidate the inventory as a station opens, since FCO ItemSaver marks fire no bag event.
     - Rewards' `FindByUid` walks the backpack once per waiting box (`WaitingCount`) and per remembered Deposit/Sell item: build one unique-ID-to-slot table per pass.
   - **Batch B, shared helpers:** one small shared file for what's copied across files: item name from an ID or link (7 copies plus about 20 inline), chat with a format string (5), item unique ID (3: Master, DailyItems, Rewards), secure UseItem / RequestMoveItem (5), the generic item link format (Inventory, Reservations), house storage bag lists (Reservations, Bank), the station location table (Alchemy, Enchanting engines), craft names (Engine, Markers), and the "run once things settle" delay (5). A bag-slot iterator for the ~15 copies of the `ZO_GetNextBagSlotIndex` loop. Alchemy's `OwnedSolvents` is `Inventory.OwnedItemIds` for potion and poison bases.
   - **Batch C, duplicated logic:**
     - `Master.lua`: `Build` (from a sealed writ's link) and `FromInfo` (from an accepted quest) set the same per-craft writ fields; one builder fed by either source.
     - `Engine/Alchemy.lua`: the unique reagent pairs list and the owned-reagents-plus-solvents list are built twice (daily search and `/wc reagents`).
     - `Engine/Engine.lua`: sealed and accepted master writ jobs repeat their Progress and Craft; `Daily.lua` has the "forget failed searches" loop twice. The alchemy and enchanting crafters share the iterations step (max possible, capped, one batch while unknown).
   - **Batch D, UI and tidying:**
     - The queue and exclusion windows share an identical sort comparator, combo filler and scroll-list refill: one list helper.
     - The corner message and problem banner (about 100 lines) live in the crafting engine but Rewards uses them too: move them to their own UI file.
     - Misplaced comments (above `Engine.SayCrafting` / `CraftSounds`, `Rewards.OpenWaiting`), smithing's registration loop over a one-item list, Rewards' `MayTouch` checking the lock twice (`Inventory.IsProtected` already does), the Grand Master listener registered at file load instead of in `Init`.
   - Also then: the writ board pauses (0.2 s before answering a page, 0.5 s check after each accept) can be shortened to get closer to Dolgubon's speed.
8. **Potion search UI**.
9. **Migration**: warn if any replaced addon is still enabled (they'd fight over auto-dialog and autocraft).
10. **Help window** (last, decided 2026-11-06): `/wc help` opens a window where players can read about every feature (badges, tooltips, exclusions, queue, crafting notices and sounds, daily and master writ handling, bank withdrawal) and every command, instead of the chat list it prints now.

Testing: pure logic (solver, rules, link parsing, price defaults) gets offline Lua unit tests with stubbed game APIs. Anything touching stations, quests or the bank is checked by you in game at each milestone.

---

## 9. Defaults assumed unless you say otherwise
- PC/Mac only, English only in v1.
- Settings storage follows CharacterHomes: one account-wide table per megaserver (`WritCrafterVars[server][@account]["$AccountWide"]`). It holds a shared `settings` section and a `characters` table keyed by character ID (name stored alongside, so renames are safe). Default scope: **Account Wide** (all your characters on that server). A character can switch to **This character only**, which starts from a copy of the shared settings. Per-character writ state (queued/completed) goes in the same `characters` entry.
- All code written fresh; the replaced addons are API references only (WritWorthy reserves rights and discourages forks; LibLazyCrafting has no license file; LibEsoHubPrices is CC BY-NC-ND, so we read its data at runtime but never copy it into our files).
- Stock = backpack + craft bag + bank; house storage not counted.
- Daily writ rejection = auto-abandon with a chat message.
- Gold master writs: all types allowed until you tick an exclusion.
- Reward handling: when a writ reward box is looted, each kind of item in it (crafting mats, surveys, sealed master writs, repair kits, ornate/intricate gear, soul gems, glyphs, recipes, Psijic fragments, gold, gold mats) gets one action: **Leave in bag**, **Deposit** (moved to the bank the next time you open it), **Junk** (marked to sell), **Destroy**, or **Deconstruct** (at the next matching station). Default for every kind: **Leave in bag**, so nothing happens to your loot until you pick an action. Dolgubon ships the same defaults. Reward boxes are auto-looted when received (Dolgubon's default too).
- Name **WritCrafter**, slash command `/wc` (toggles the queue window); keybinds for the window, "Craft items" and "Accept & Turn In".

## 10. Still open
- Nothing. All questions answered and the §9 defaults accepted (2026-11-03).

## 11. Later (after the base is working)
- **Diagnostic commands stay in the release** (decided 2026-11-06) and are documented in the help window (milestone 10):
  - `/wc stock <item>`: backpack, bank, craft bag and usable counts.
  - `/wc price <item>`: the price WritCrafter uses and its source.
  - `/wc selftest`: every stack count against the game's own totals.
  - `/wc perf`: timings of the work behind bag and bank windows.
  - `/wc debug`: debug chat messages on or off.
  - `/wc checkdata`: compares the built-in data with the game: reagent effects (every owned reagent pair, predicted by the game), runes and glyphs (including the glyph the game makes from owned runes), and smithing items, base materials and improvement materials. **Run it after every major game update**; reagent effects are the most likely to change (Update 51 moved several).
    - **The game is the authority for reagent effects** (decided 2026-11-06). The table was built from Dolgubon's, WritWorthy, LibAlchemy and UESP, and the old addons are what broke on Update 51, so none of those sources is trusted on its own. `checkdata` reports how many of the table's effects the game has confirmed (two reagents sharing an effect, and the game's predicted potion having it) and lists the rest. Effects stay unconfirmed until you own the reagent, have discovered its traits, and own another reagent that shares the effect.
- **Keep a reserve, per writ category** (asked 2026-11-05): a setting per category (blacksmithing, clothing, woodworking, jewelry, alchemy, enchanting, provisioning) such as "don't use a material if you'd have fewer than N left". Acts as a temporary, automatic exclusion that lifts on restocking, so manual exclusions stay for things never to be used. Chat explains it ("Low on X, keeping a reserve of N"), distinct from "excluded". The user currently does this by hand, excluding whatever is low.
  - **Style materials:** one floor for all style materials. When a writ's style material is below it, a mimic stone is used instead (Mimic stones "When needed"), or the writ waits (Mimic stones "Never").
  - **Improvement materials, one floor per tier:** green, blue, purple and gold (Honing Stone / Dwarven Oil / Grain Solvent / Tempering Alloy and the clothing, woodworking and jewelry equivalents). Improving stops at the tier whose material would drop below its floor, with the same "low on" message, and never improves below 100%.
  - Goal: no stock management by hand; floors are set once and WritCrafter stays out of the reserves.
