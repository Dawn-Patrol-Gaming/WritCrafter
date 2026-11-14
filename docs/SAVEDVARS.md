# WritCrafter saved variables: developer reference

What's in `WritCrafter.lua` under SavedVariables, what each value means, who writes it, and when
it's forgotten. The code that owns the layout is `Core/SavedVars.lua`; each section below names
the file that owns that table.

## 1. The file

| | |
|---|---|
| Location | `<ESO folder>\live\SavedVariables\WritCrafter.lua` (`pts` instead of `live` on the test server) |
| Global variable | `WritCrafterVars` (from `## SavedVariables:` in `WritCrafter.addon`) |
| Written | Only on `/reloadui`, logout or quitting. A crash loses everything since the last of those |
| Editing by hand | Only with the game closed: the game rewrites the whole file from memory on the next reload or logout, wiping out any edit made while it runs |
| Version | `SV_VERSION = 2` in `Core/SavedVars.lua`. Changing it makes `ZO_SavedVars` throw the old data away and start fresh: every setting, queue and mark is lost |

The file is local to one computer. Nothing in it syncs between machines; copying the whole file
(game closed on both) moves everything, for every character on the account.

## 2. Layout

One account-wide table per megaserver, the same layout as the CharacterHomes addon. There is no
per-character saved variable: characters live inside the account-wide table, keyed by ID.

```
WritCrafterVars
└─ ["NA Megaserver"]                    -- GetWorldName(); "EU Megaserver", "PTS" are separate
   └─ ["@account"]                      -- ZO_SavedVars adds the account level
      └─ ["$AccountWide"]               -- ZO_SavedVars:NewAccountWide's own key
         ├─ version       = 2           -- written by ZO_SavedVars, see SV_VERSION
         ├─ settings      = {...}       -- shared settings (section 3)
         ├─ characters    = {...}       -- per character, by character ID (section 4)
         ├─ linkCache     = {...}       -- account-wide data (section 5)
         ├─ writQuests    = {...}
         ├─ grandMaster   = {...}
         ├─ stations      = {...}
         └─ stationKinds  = {...}
```

In code: `WC.sv` is the `$AccountWide` table, `WC.character` is this character's entry in
`characters`, and `WC.settings` is whichever settings table is active (section 4.1).

Tables other than `settings`, `characters` and `linkCache` are created the first time they're
needed (`WC.sv.x = WC.sv.x or {}`), so a file can lack them; that means "nothing learned yet".

### Number codes used throughout

**Craft** values are the game's `CRAFTING_TYPE_*` constants:

| 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|
| Blacksmithing | Clothier | Enchanting | Alchemy | Provisioning | Woodworking | Jewelry |

**uid** keys are an item's unique ID as a decimal string (`Id64ToString(GetItemUniqueId(...))`,
`WC.Util.UniqueId`). The game assigns it per item and keeps it when the item moves between bags,
so it's the same on every computer. Splitting a stack gives the new stack a new ID.

**itemId** keys are numbers (`GetItemId`), the same for every copy of that item.

**Links** are full item links (`|H0:item:...|h|h`), stored so a writ or item can be decoded
without finding it in a bag.

## 3. Settings (`settings`)

Owned by `Core/SavedVars.lua` (`WC.DEFAULTS`); shown in `UI/Settings.lua`. The same keys exist in
a character's own `settings` once it has used "This Character Only" (section 4.1).

On every load, `PruneRemoved` drops keys that are no longer in `WC.DEFAULTS` (so a setting must
be added there or it disappears at the next reload) and `FillDefaults` adds any missing key with
its default. A file can therefore be missing keys, but never keeps stale ones, except inside
item-ID tables (`expensive`, `reagents`, `excludeGold`, `rewardActions`), whose default is `{}`
and which are not pruned key by key.

### Prices and exclusions

| Key | Values | Default | Meaning |
|---|---|---|---|
| `priceSource` | `"auto"`, `"esohub"`, `"mm"`, `"ttc"`, `"att"` | `"auto"` | Where prices come from (`Core/Price.lua`). Auto: ESO Hub, then LibPrice's MM / ATT / TTC |
| `expensive` | `[itemId] = true/false` | `{}` | Your own "too expensive" marks on non-reagent materials. Only stored when different from the default (`Policy.SetExpensive`), so later changes to the shipped defaults still reach untouched items. `true` = excluded, `false` = allowed although the default excludes it |
| `reagents` | `[itemId] = true/false` | `{}` | Alchemy reagents' allow list, stored the same way. `true` = allowed, `false` = excluded. The default allows overland plants that aren't expensive (`Policy.IsReagentAllowedByDefault`). Too-expensive marks never apply to reagents; old ones are removed on load |
| `excludeGold` | `[craft] = true` | `{}` | Exclude Gold Writs: master writs of that craft asking for gold quality are rejected. Unticked crafts are removed, not stored as `false` |
| `liveCeilings` | bool | `false` | Re-check against live prices: exclude anything priced above its category's ceiling |
| `ceilings` | `{ reagent, rune, trait, ingredient }` gold per unit | 300 / 500 / 1000 / 300 | The ceilings `liveCeilings` uses. Fixed keys: unknown ones are pruned |
| `mimic` | `"never"`, `"needed"`, `"always"` | `"needed"` | Mimic stones for master writ style materials. Needed = when the style material is excluded or you have none. A writ's own choice in the queue window (section 4.3) wins |
| `maxGoldPerVoucher` | number, `0` = off | `0` | Reject master writs whose materials cost more than this per voucher |

### Crafting

| Key | Default | Meaning |
|---|---|---|
| `autoCraft` | `true` | Craft queued master writs at stations |
| `autoCraftDaily` | `true` | Craft daily writ quests at stations |
| `bankWithdrawDaily` | `false` | Daily writs: take finished items out of storage instead of crafting |
| `bankWithdrawMaster` | `true` | Master writs: take their crafted items out of storage. (Before 2026-11-09 one `bankWithdraw` key covered both; `PruneRemoved` carries an old `false` over) |
| `dailyAcquireExcluded` | `false` | Hand Over Excluded Reagents: an alchemy writ's "acquire" reagent is handed over even if excluded |
| `acceptGuard` | `true` | Ask before accepting a sealed master writ you can't craft (`Writs/AcceptGuard.lua`) |
| `leaveStation` | `true` | Leave the station once writ crafting there is done |

### Dialogs (Rolis, writ boards, delivery crates)

| Key | Default | Meaning |
|---|---|---|
| `rolisTurnIn` | `true` | Step through the master writ turn-in when you talk to Rolis Hlaalu |
| `rolisClose` | `true` | End the conversation after the last master writ is handed in |
| `rolisAcceptNext` | `true` | Then accept the next batch of crafted writs |
| `dailyAccept` | `{ [craft] = true }` for all 7 | Accept that craft's daily writ at writ boards |
| `dailyTurnIn` | `{ [craft] = true }` for all 7 | Turn that craft's daily writ in at delivery crates |

### Writ rewards (`Rewards/Rewards.lua`)

| Key | Default | Meaning |
|---|---|---|
| `rewardOpenBoxes` | `true` | Open writ reward boxes as they arrive |
| `rewardSummary` | `true` | List what each box gave in chat |
| `rewardActions` | `{}` | `[kind] = action`, one entry per reward kind you've changed. A missing kind uses its default: Leave in Bag, except `containers` (Open) |

Actions: `"leave"`, `"deposit"` (next bank visit), `"junk"` (now), `"sell"` (next merchant),
`"open"` (containers only), `"deconstruct"` (next matching station or deconstruction assistant),
`"keepStack"` (at merchants, sell what rewards gave beyond one full stack).

Kinds, in settings order, with the actions each allows (`Rewards.KINDS`):

| Kind | Allowed | What it is |
|---|---|---|
| `writContainers` | leave, open, deposit | "Unknown ... Writ" containers of sealed master writs |
| `surveyContainers` | leave, open, deposit | Containers of survey reports |
| `containers` | leave, open, deposit | Any other container ("Shipment of Ingots"); default Open |
| `materials` | leave, deposit, junk, sell | Anything the craft bag takes: raw and refined materials, runes, reagents |
| `improvement` | leave, deposit, junk, sell | Smithing improvement boosters (tempers, resins, tannins, platings) |
| `surveys` | leave, deposit, junk, sell | Survey reports |
| `masterWrits` | leave, deposit | Sealed master writs |
| `repairKits` | leave, deposit, junk, sell, keepStack | Repair kits |
| `ornate` | leave, deposit, junk, sell, deconstruct | Ornate gear and jewelry |
| `intricate` | leave, deposit, junk, sell, deconstruct | Intricate gear and jewelry |
| `researchGear` | leave, deposit, junk, sell | Purple or gold gear with a trait (other than ornate or intricate) to research |
| `soulGems` | leave, deposit, keepStack | Soul gems |
| `glyphs` | leave, deposit, junk, sell, deconstruct | Glyphs |
| `recipesFine` | leave, deposit, junk, sell | White and green recipes |
| `recipesSuperior` | leave, deposit, junk, sell | Blue recipes |
| `recipesEpic` | leave, deposit, junk, sell | Purple and gold recipes |
| `psijic` | leave, deposit | Psijic Ambrosia recipe fragments |
| `extras` | leave, deposit, sell | Not from boxes: what a writ craft makes beyond what the writ needs (potions, poisons, food) |

Retired kinds may still be in old files: `recipes` (split into the three recipe kinds) and
`researchJewelry` (became `researchGear`). They're read as fallbacks (`FORMERLY` in Rewards.lua)
until the new kind gets its own entry.

### Notices and sounds

| Key | Default | Meaning |
|---|---|---|
| `craftNotice` | `true` | On-screen alerts and the red failure banner |
| `soundStart` | `true` | Sound when writ crafting starts at a station |
| `soundDone` | `true` | Sound when it's done |
| `soundProblem` | `true` | Sound when something couldn't be crafted |
| `soundSlot` | `true` | Slotting sounds (solvent/reagents, runes, item placed) |
| `soundRunes` | `true` | Enchanting's spoken rune names |
| `soundSuccess` | `true` | The station's success sound as each item is made |

### Display

| Key | Values | Default | Meaning |
|---|---|---|---|
| `writStatus` | bool | `true` | The daily writ status strip |
| `writStatusX`, `writStatusY` | `false` or screen pixels | `false` | The strip's left/top once you've dragged it; `false` = default spot above the attribute bars |
| `stationMarkers` | `"off"`, `"all"`, `"queued"` | `"off"` | Markers over house stations for master writs: off, every writ in your bag, queued writs only |
| `tooltip` | bool | `true` | WritCrafter's lines on master writ tooltips |
| `tooltipMaterials` | bool | `true` | The materials list in those tooltips |
| `iconCrafted` | bool | `true` | Inventory badge: writ crafted (green), partly crafted (amber) |
| `iconRejected` | bool | `true` | Inventory badge: writ rejected by your settings (red) |
| `iconQueued` | bool | `true` | Inventory badge: writ queued (blue) |
| `iconMissing` | bool | `true` | Inventory badge: not enough of some material (yellow) |
| `iconReserved` | bool | `true` | Padlock on items set aside for a writ (gold) or made for a daily writ (blue) |
| `iconOffsetX`, `iconOffsetY` | pixels | `0` | Moves the inventory badges |
| `logLevel` | `1` errors, `2` normal, `3` debug | `2` | Chat detail (`Core/Log.lua`). Debug lines also go to LibDebugLogger |

## 4. Per character (`characters`)

Keyed by character ID as a string (`GetCurrentCharacterId()`), which survives renames and is the
same on every computer. A character's entry is created the first time it logs in with
WritCrafter. The tables after `settings` are created when first needed.

### 4.1 Identity and settings scope (`Core/SavedVars.lua`)

| Key | Meaning |
|---|---|
| `name` | The character's name, refreshed every login. Only for reading the file and the settings menu |
| `scope` | `"server"`: uses the shared `settings` (Account Wide). `"character"`: uses its own `settings` (This Character Only) |
| `characterSeeded` | `true` once the character has switched to This Character Only at least once |
| `settings` | Only present when `characterSeeded`. Same keys as section 3. The first switch copies the shared settings in, so nothing has to be set up again |

Switching back to Account Wide keeps the character's own `settings` in the file; switching to
This Character Only again brings them back.

### 4.2 Master writs

| Key | Owner | Format | Meaning | Forgotten |
|---|---|---|---|---|
| `queue` | `Engine/Queue.lua` | `[uid] = { link, override }` | Sealed master writs you queued (right-click or queue window). `override = true` when queued although your settings reject it; stations craft it anyway | When unqueued or the writ is used; entries whose link no longer parses are dropped |
| `mimic` | `Core/Policy.lua` | `[writLink] = true/false` | A writ's own Mimic choice from the queue window. Keyed by link, so identical writs share it. Missing = follow the `mimic` setting | When no writ with that link is left in this character's bags or the bank |
| `acceptedWrits` | `Writs/Master.lua` | `[quest name] = { info, required }` | Details of accepted master writ quests, kept because the craft task leaves the journal once done and the details with it. One per quest name: only one master writ of each kind can be accepted | When the quest is turned in or abandoned |

`acceptedWrits[...].info` is what `GetQuestConditionMasterWritInfo` returns
(`Master.ReadInfo`): `itemId` (glyph, food or potion; 0 for gear), `materialId` (enchanting level
or alchemy solvent), `craft`, `quality`, `templateId`, `setId`, `trait`, `style`, and `effects`
(alchemy effects packed one per byte). `required` is the quest's count.

### 4.3 Daily writs

| Key | Owner | Format | Meaning | Forgotten |
|---|---|---|---|---|
| `dailyItems` | `Writs/DailyItems.lua` | `[uid] = quest name` | Items made for (or taken out of storage for) a daily writ, so they keep their blue padlock after the craft step leaves the journal | When that quest is turned in or abandoned, and on login for quests no longer in the journal |
| `dailyAcquire` | `Writs/Dialogs.lua` | `[quest name] = itemId` | The reagent a daily alchemy writ asked you to acquire. The task leaves the journal once the quest moves to delivery, but the crate still takes the reagent | When the quest leaves the journal |
| `writReady` | `UI/WritStatus.lua` | `[quest name] = true` | The writ has nothing left to craft (status strip cyan). The game doesn't call a writ waiting for delivery complete, so WritCrafter records it | When no daily writ is left in the journal |
| `writTurnedIn` | `UI/WritStatus.lua` | `[craft] = true` | That craft's daily writ was turned in (status strip green) | Same as `writReady` |

### 4.4 Writ rewards (`Rewards/Rewards.lua`)

| Key | Format | Meaning | Forgotten |
|---|---|---|---|
| `rewardBoxes` | `[uid] = true` | Reward boxes (and containers set to Open) waiting to be opened: in combat, no backpack room, or several in a row | When opened, or after 3 failed tries (left for you) |
| `rewardTodo` | `[uid] = { action, quantity, link, extra }` | Items waiting for the bank (`"deposit"`), a merchant (`"sell"`) or a station or assistant (`"deconstruct"`). `quantity` is only what the boxes gave: a stack they merged into keeps the rest. `extra = true` for extra crafted items | When done, or when the item is gone, locked, FCO-marked or set aside for a writ by the time it would be acted on |
| `rewardStack` | `[itemId] = { quantity, link }` | Keep a Stack: how many of this item writ rewards have given since the last merchant. Only that many, and only above one full stack, can be sold | After each merchant visit |

The `(to deposit)`, `(to sell)` and `(to deconstruct)` tooltip notes come from `rewardTodo`.
They're per character and per computer, like everything here: an item marked on one computer is
an ordinary item on another until the file is copied.

### 4.5 Potion search (`UI/PotionSearch.lua`)

| Key | Format | Meaning |
|---|---|---|
| `potionFavorites` | `["id:id[:id]"] = { combo, effects }` | Starred reagent combos. The key is the reagent item IDs sorted and joined by `:`; `combo` is the reagent IDs, `effects` the game's alchemy effect IDs the combo makes. Kept until unstarred |

## 5. Account-wide data

| Key | Owner | Format | Meaning |
|---|---|---|---|
| `linkCache` | `Core/Inventory.lua` | `[itemId] = link` | A real link for each stackable item seen in your bags. Price addons key their data by link fields (level, subtype), so the bare `item:<id>:0:0...` link often finds no price. Added to, never pruned |
| `writQuests` | `Writs/Dialogs.lua` | `[lower-case quest name] = craft` | Daily writ quest names, learned in the game's language the first time a station claims that quest. Writ boards and crates match these before the English fallback words in `Strings/en.lua` |
| `grandMaster` | `Engine/Smithing.lua` | `[craft] = { [setId] = true }` | Sets your Grand Master stations have, learned each time you use one, so the queue window's Station column knows them anywhere. Only ever added to. A craft key with an empty table means a Grand Master station for it was seen but had no sets |
| `stations` | `UI/Markers.lua` | `["house:<houseId>:<owner>"] = { { craft, x, y, z, set, gm }, ... }` | Stations you've used in houses (nothing is recorded outside houses). `x, y, z` are world coordinates in centimetres; `set` is the station's set ID, `0` for a plain one; `gm = true` for a Grand Master station. A station within 3 m of a recorded one of the same craft replaces it. Used after the shipped furniture list and the furniture's name, for stations neither identifies |
| `stationKinds` | `UI/Markers.lua` | `[furnitureDataId] = craft` | Station furniture whose name doesn't say its craft ("Maormer Cookfire"), learned when you use one. The ID is the same in every house |

## 6. Working with the file

- **Adding a setting:** add it to `WC.DEFAULTS` with a comment. A key that isn't there is deleted
  on the next load. Tables of item IDs should default to `{}` so they aren't pruned key by key.
- **Adding per-character or account-wide state:** create it lazily (`WC.character.x =
  WC.character.x or {}`) in the module that owns it, add a comment with its format, and add it to
  this file. Decide when it's forgotten; nothing here prunes it for you.
- **Renaming or splitting a key:** carry the old value over (as `PruneRemoved` does for
  `bankWithdraw`, and `FORMERLY` for reward kinds), or players lose their choice.
- **Never bump `SV_VERSION`** unless wiping everything is intended.
- **Reading it while testing:** reload or log out first, then read the file. LibDebugLogger's file
  in the same folder holds the full chat log at debug level.
- **Moving to another computer:** close the game on both, back up the target's file, copy the
  whole file. Whichever copy you take replaces everything on the other machine.
