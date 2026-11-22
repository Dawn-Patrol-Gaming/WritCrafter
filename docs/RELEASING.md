# Releasing on ESOUI

ESOUI's moderators review every upload against the "Before you release" thread
(https://www.esoui.com/forums/showthread.php?t=10790) and run an automated addon check on the zip.
They treat the whole thread as rules, including the parts it calls best practice, and flag
anything missing in a comment on the add-on. Earlier uploads (Character Homes, 2026) were flagged
for an outdated `## APIVersion:`, SavedVariables not split by server, and a `.png` in the zip, and
were pointed at the AI disclosure and credits. Go through every item below before each upload.

Also covered by: the upload rules (t=11), what add-ons must not do (t=9865), and the author's
BookStack notes "ESO Addon Development".

## Before every upload

### Manifest (`WritCrafter.txt`)

- [ ] `## Version:` and `## AddOnVersion:` both raised.
- [ ] `## APIVersion:` is the current live value, plus the PTS value if there is one (at most two).
      Check in game with `/script d(GetAPIVersion())`.
- [ ] Every `## DependsOn:` entry has `>=` with the library's own `## AddOnVersion:`, read from
      its installed manifest. Raise them after testing with newer library versions.
- [ ] Separated by spaces only, a space after each colon, no line over 301 bytes, UTF-8 without BOM.
- [ ] The ZeniMax add-on terms comment lines are still at the top.

### Description (the ESOUI page, from `README.md`)

- [ ] **AI disclosure first**, at the very top.
- [ ] **Required libraries next**, so they're seen at a glance on ESOUI and in Minion.
- [ ] Credits for every add-on, author or resource used for code, ideas, concepts, assets or
      information (README's Credits section), and their licences followed. Add any new ones.
- [ ] Describes what the add-on does **now**: new features, changed commands and settings.
- [ ] English. No swear words in the name.
- [ ] Changes go in the **Changelog** tab, newest first, not in the description.

### Code

- [ ] No chat message on load. Chat output only answers a command, reports a problem, or is
      Debug level (and goes to LibDebugLogger).
- [ ] One global table (`WritCrafter`), plus only what XML, keybindings and saved variables need,
      all prefixed with the add-on's name. `scripts/check.lua` checks for stray globals.
- [ ] Event filters on inventory, combat and effect events.
- [ ] SavedVariables split by server (`GetWorldName()`), characters by character ID. A change to
      the layout carries old data over instead of wiping it (docs/SAVEDVARS.md).
- [ ] Nothing from the "must not do" list: no private functions, no starting interactions for the
      player, no server request floods (bank moves and sales go one at a time).

### Zip

- [ ] Deployed with `.\scripts\Deploy.ps1` first: the installed `AddOns\WritCrafter` folder then
      holds only the manifest, the files it loads and `README.md` (no images, `docs`, `scripts`,
      `.git` or hidden files). Zip that folder itself, so the zip holds one `WritCrafter` folder.
      No zips inside.
- [ ] Screenshots go in the add-on page's pictures, never in the zip.

### After uploading

- [ ] Watch ESOUI private messages and the add-on's comments for the moderator review and the
      automated addon-check report. Fix everything they mention in the next version, and reply.
- [ ] In the add-on's settings on ESOUI, choose whether others may upload patches.
