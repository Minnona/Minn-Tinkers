Minn Tinkers
============

Personal WoW 3.3.5a quality-of-life addon.

Version: 0.1.18
License: GPL-3.0

Install:
- Extract MinnTinkers into Interface/AddOns/
- Final path should be Interface/AddOns/MinnTinkers/MinnTinkers.toc

Command:
/minn

Settings:
- Saved per character through MinnTinkersCharDB.
- Specs are not used; class tools are separated by class tabs only.
- The addon uses native Interface > AddOns categories.
- Expand Minn Tinkers with the + button to see:
  - Universal
  - Felsworn
  - Venomancer
  - Debug

Universal:
- Auto-sell grey items.
- Auto-skip safe single-option gossip. Hold Shift while opening an NPC to bypass it for that interaction.
- Smart dungeon rolls.
- Raid Roll Helper for master-looter MS/OS rolls.
- Mark tank with Star and healer with Moon from RDF/LFG role data.

Felsworn:
- Vengeful Pact reminder button.
- Man'ari Intuition reminder button.

Venomancer:
- Envenomed Weapons reminder button.

Main commands:
/minn
/minn help

Raid Roll Helper commands:
/minn roll [item]
/minn roll 3 [item]
/minn roll status
/minn roll log
/minn roll cancel
/minn roll ml

Most other controls are handled through the settings UI.
Advanced/dev actions are under /minn debug.

Changelog:

0.1.18
- Simplified public slash commands.
- Kept /minn for settings and /minn roll for Raid Roll Helper.
- Moved master-looter check to /minn roll ml.
- Moved old utility/dev slash actions under /minn debug instead of advertising many top-level commands.
- Removed Raid Roll Helper top-level slash hook and non-/minn roll aliases.
- Added Raid Roll Helper UI buttons for master-looter check, status, log, cancel, duration, and channel.

0.1.17
- Added Raid Roll Helper under Universal.
- Auto-starts MS/OS rolls when master looter links exactly one item in raid/party chat.
- Supports multi-copy rolls such as 3 [item], where the top 3 valid rolls win.
- Accepts only the first valid roll per player and announces duplicate rolls.
- Uses 10/5/3/2/1 countdown behavior.
- Handles cutoff ties with named rerolls for the tied players and item.
- Added /minn roll [item], /minn roll 3 [item], /minn roll status, /minn roll log, /minn roll cancel, and /minn ml.

0.1.16
- Fixed Universal page layout so wrapped text no longer overlaps nearby controls.
- Widened Smart Dungeon Rolls option buttons to better fit long labels.
- Increased settings page content width and checkbox text width for cleaner spacing.

0.1.15
- Added Smart Dungeon Rolls universal module.
- Green/blue equipment can auto-disenchant, greed, pass, or stay manual.
- Purple equipment stays manual by default, with optional unusable handling.
- Recipes can Need when they match your professions and required skill.
- Lockboxes can Greed, Pass, stay Manual, or Need if Lockpicking is detected.
- Added /minn rolls, /minn rolls pause 60, and /minn rolls resume.

0.1.14
- Fixed reminder spell buttons using Blizzard button backdrops when pressed.
- Reminder buttons now use plain secure buttons with Minn Tinkers styling only.
- Improved Vengeful Pact/tanking aura detection after clicking the reminder button.
- Added repeated short post-click aura checks and a passive visible-button sanity check.
- Buff name matching is more tolerant for upgraded/custom spell names.

0.1.13
- Added Auto-skip gossip under Universal.
- Auto-skip gossip only clicks when there is exactly one gossip option and no quest options.
- Holding Shift while opening/talking to an NPC bypasses gossip auto-skip for that interaction.
- Added /minn gossip manual test command.

0.1.12
- Removed spec-based logic.
- Class tools are separated by class tabs only.
- Removed unnecessary class availability notes.

0.1.11
- Reworked settings UI to use native Interface > AddOns child pages.

0.1.10
- Added ElvUI-like skin.
- Added per-character settings.
- Added Envenomed Weapons reminder.

0.1.9
- Added role-based marking.
- Tank gets Star.
- Healer gets Moon.

0.1.8
- Added Man'ari Intuition reminder.

0.1.7
- Added Vengeful Pact reminder button.

0.1.0
- Initial addon base.
- Added AutoSellGrey.
