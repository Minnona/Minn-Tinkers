# AGENTS.md — Minn Tinkers

## Project

This repository contains **Minn Tinkers**, a lightweight World of Warcraft **3.3.5a / Ascension** personal quality-of-life addon.

Primary goal: keep the addon practical, fast, compact, and safe. Avoid anything that can create unnecessary repeated work in the WoW client.

Repo:

```text
Minnona/Minn-Tinkers
```

User's local addon path:

```bash
/mnt/data/Games/AscensionWoW/resources/ascension-live/Interface/AddOns/MinnTinkers
```

User updates with:

```bash
cd /mnt/data/Games/AscensionWoW/resources/ascension-live/Interface/AddOns/MinnTinkers
git pull
```

Then in game:

```text
/reload
```

## Hard rules

1. Keep code lightweight and event-driven.
2. Avoid permanent `OnUpdate` loops. Use `OnUpdate` only while actively waiting, scanning, dragging, timing, or retrying, then clear it.
3. Do not add new slash commands unless there is a strong reason. Prefer the `/minn` settings UI.
4. Do not create wrapper/patch modules for small edits, UI cleanup, spacing fixes, or behavior tweaks. Edit the real module directly.
5. Only create a new module when it is actually a new feature.
6. Keep the Universal settings page compact. Do not add redundant grey footnotes when hover tooltips already explain settings.
7. Use native `Interface > AddOns` child pages/settings, not a large custom config window.
8. Preserve WoW 3.3.5a compatibility. Avoid modern Lua features.
9. Be careful with protected WoW actions. Do not auto-cast protected spells; use secure buttons when needed.
10. For risky automation, use strict matching, allowlists, bounded windows, and fail-safe behavior.

## Coding style

Use old-Lua compatible code.

Prefer:

```lua
unpack
table.getn
pairs
ipairs
```

Avoid:

```lua
table.unpack
goto
local <const>
bit32
Lua 5.2+ assumptions
```

Keep functions small and direct. Avoid clever abstraction unless it clearly reduces repeated code without hiding behavior.

When adding saved variables/defaults, preserve existing user settings and add migration only when needed.

## Performance rules

Event-driven modules are preferred.

Acceptable `OnUpdate` use:

```text
- short popup scan window
- drag tracking while actively dragging
- roll/timer countdown while a roll is active
- bounded retry while waiting for item info
- delayed one-shot check that clears itself
```

Unacceptable pattern:

```text
- permanent frame-by-frame polling while the module is simply enabled
- repeated scans when an event would work
- unbounded retries
- timers that never clear
```

Every temporary `OnUpdate` must have a clear stop condition.

## UI rules

Settings are built through module `BuildOptions` methods and native Interface Options child pages.

`/minn` and the minimap button reopen the last-used child page stored per character, falling back to Universal if that page is unavailable.

Keep UI compact:

```text
- main module checkbox is usually enough
- avoid redundant sub-checkboxes
- avoid grey explanatory footnotes unless they prevent confusion
- use hover tooltip text for details
- align option buttons consistently
```

Do not reintroduce these deleted patch-layer files:

```text
Modules/CompactOptions.lua
Modules/SmartDungeonRollsLayout.lua
```

Reason: UI cleanup must be folded into the real module files.

## Module creation rule

Create a new module only for a real new feature, such as:

```text
- new automation category
- new independent game event workflow
- new UI feature with its own lifecycle
```

Do not create a new module for:

```text
- spacing fixes
- hiding text
- one checkbox change
- cleanup wrappers
- monkey-patching existing modules
```

For existing behavior, edit the existing module directly.

## Slash command policy

Public command surface should stay small:

```text
/minn
/minn help
/minn roll [item]
/minn roll 3 [item]
/minn roll status
/minn roll log
/minn roll cancel
/minn roll ml
```

Advanced/dev commands, if needed, belong under:

```text
/minn debug ...
```

Do not advertise debug commands in the normal UI unless troubleshooting.

## Current addon categories

Expected settings pages:

```text
Universal
Raid Rolls
Raid Lockouts
PvP
Felsworn
Venomancer
Debug
```

Future polish may split Universal if overcrowded, but keep native Interface Options child pages.

Possible future split:

```text
Universal
Loot
Raid Rolls
Protection
Felsworn
Venomancer
Debug
```

## Current important modules

### MinimapButton.lua

Frog minimap button using:

```lua
Interface\\Icons\\Spell_Shaman_Hex
```

Behavior:

```text
Left-click: open settings
Drag: move around minimap
Right-click: lock/unlock position
```

`OnUpdate` should only run while actively dragging.

### AutoSkipGossip.lua

Auto-skips gossip only when there is exactly one gossip option and no quest options.

Current intended UI:

```text
main module checkbox only
```

No print checkbox, no try button, no grey note.

Shift while opening/talking to NPC bypasses it for that interaction.

### SmartDungeonRolls.lua

Handles safe dungeon loot rolls.

Default behavior:

```text
5-man dungeons: enabled
raids: disabled
Green/Blue equipment: DE if possible, else Greed
Purple equipment: Manual
Need usable profession recipes
Unusable/known recipes: Greed
Lockboxes: Greed
Other drops: Manual
```

Performance: `START_LOOT_ROLL` only, bounded item-info retry, clear `OnUpdate` when done.

Option buttons should keep the same left edge and width directly in this file.

### SmartDungeonRollsZG.lua

Zul'Gurub override for Smart Dungeon Rolls.

Behavior:

```text
- default ON
- only inside Zul'Gurub
- only green/blue quality items
- rolls Need only when Need is available
- works even if general raid auto-rolls are OFF
```

This is an acceptable separate module because it is a real feature, but it may be folded into `SmartDungeonRolls.lua` later if simplifying file count.

### RaidRollHelper.lua

Own tab: **Raid Rolls**.

Behavior:

```text
- 15s roll window by default
- countdown only at 10s and 5s
- announces only winner/winners
- does not list everyone who rolled
- one-copy roll announces only top winner
- multi-copy roll announces top N winners, one per line
- hides MS label by default
- shows MS/OS labels only when someone used /roll 99
```

Supported starts note can remain in UI:

```text
[item], roll [item], [item] roll, 2 [item], [item] x2 roll, roll [item] x2
```

Do not add the removed announcement-behavior grey footnote back.

Trusted announcer mode can start from:

```text
- your own item links
- detected master looter item links
- raid leader item links
```

Parser must stay allowlist-based: require exactly one item link, accept only known roll/count/loot wording, and reject unknown conversational text.

### RaidLockouts.lua

Own tab: **Raid Lockouts**, between Raid Rolls and PvP.

Stores account-wide character snapshots under `MinnTinkersDB.raidLockouts`. Scans only through `RequestRaidInfo` / `UPDATE_INSTANCE_INFO` and instance/login events; do not add permanent polling. Use the API-provided difficulty name first, preserve unknown custom difficulties, show offline scan age, and never imply that an offline character was queried live. Ascension may return a zero reset duration for a visibly locked raid; retain those lockouts without a timer instead of treating them as immediately expired.

### BattlegroundsPvP.lua

Own tab: **PvP**.

Shows friendly/enemy flag-carrier names beside the matching Blizzard flag-status rows. The PvP page exposes battleground auto-release, name display, click targeting, friendly Square marking, and enemy Skull marking as separate default-on settings. Auto-release must run only from `PLAYER_DEAD` while `IsInInstance()` reports `pvp`. Target buttons must use secure actions and fail closed while a changed carrier is combat-locked. Clear only markers the module verified it applied. Detection must remain event-driven with bounded discovery retries.

### WardrobeAutoAccept.lua

Auto-accepts wardrobe/transmog appearance confirmation after Ctrl+Alt item click.

Safety rules:

```text
- module enabled
- always require recent Ctrl+Alt item click internally
- popup text must match wardrobe appearance collection
- popup text must include soulbound warning
- popup text must include cannot-be-undone warning
- accept button must look like Accept
```

Current intended UI:

```text
main module checkbox only
```

No “Require recent Ctrl+Alt item click” checkbox. That safety guard is mandatory.

### BattlegroundSpoils.lua

Auto-selects the only real non-cancel choice from Battleground Spoils gossip.

Behavior:

```text
- confirm window is Battleground Spoils
- ignore Nevermind / Goodbye / cancel options
- auto-select if exactly one real non-cancel option remains
- do nothing if 2+ real choices appear
```

Must handle labels like:

```text
Intellect
Tank
future single-option choices
```

Current intended UI:

```text
main module checkbox only
```

### PopupGuard.lua

Prevents Escape from accidentally cancelling protected popups.

Rules:

```text
- allowlist-only
- does not auto-accept
- does not globally block Escape
- patches only selected StaticPopup definitions
```

Protected categories:

```text
Group invites
Summons
Resurrection popups
Dungeon/LFG invites/proposals
Battleground queue popups
```

If a popup still closes with Esc, enable popup-ID debug, capture ID, and add it to the allowlist.

### AutoMarkRoles.lua

Marks RDF/LFG roles:

```text
Tank = Star
Healer = Moon
```

The default-on `rememberDungeonRoles` option remembers the current dungeon's Star/Moon identities by GUID/name so Keep Marked can restore them after Mythic+ activation removes role data and markers. Ignore difficulty changes when deciding whether it is the same dungeon. Clear memory after leaving, entering a different dungeon, disabling the option, or losing that group member. Event-driven delayed checks only; no permanent loop.

### VengefulPact.lua / ManariIntuition.lua / EnvenomedWeapons.lua

Class-specific reminder/secure button modules.

Future polish target: avoid permanent `OnUpdate`; only run while pending, visible, or in relevant state.

## Versioning

Current expected version after latest handoff:

```text
0.1.40
```

When changing files, bump TOC version only when it is a real user-facing patch. Keep README/README.txt in sync if doing a release-style update.

## Pre-change checks

Before editing:

```bash
git status
git log --oneline -10
sed -n '1,80p' MinnTinkers.toc
```

Check removed patch modules are not referenced:

```bash
grep -R "CompactOptions\|SmartDungeonRollsLayout" -n .
```

They should not appear in TOC or active load paths.

## Testing checklist

After changes, reason through or test in-game where possible:

```text
/minn opens settings
frog minimap button opens settings
Universal page remains compact
Auto-skip gossip has no sub-options
Wardrobe Auto-Accept has no sub-options and still requires Ctrl+Alt internally
Battleground Spoils auto-selects exactly one real option like Tank
Smart Dungeon Rolls buttons align
ZG green/blue Need override defaults ON
Raid Rolls tab keeps Supported starts note only
Raid roll one item announces only one winner
Raid roll 3x item announces only three winners, one per line
Raid Lockouts shows Normal/Heroic/Mythic/Ascended saves across scanned characters
Raid Lockouts labels offline snapshots with their last scan age
Auto-mark Roles restores remembered Star/Moon players after Mythic+ activation
Temporary OnUpdate handlers clear when done
```

## Response style to Minn

Be direct and practical.

When a patch is done, reply with:

```text
Done directly in GitHub.
What changed.
Pull/reload commands.
Any test needed.
```

Use this pull command:

```bash
cd /mnt/data/Games/AscensionWoW/resources/ascension-live/Interface/AddOns/MinnTinkers
git pull
```

Then:

```text
/reload
```

Avoid fluff. Do not over-explain unless asked.
