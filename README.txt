Minn Tinkers
============

Personal WoW 3.3.5a quality-of-life addon.

Version: 0.1.14
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
- Mark tank with Star and healer with Moon from RDF/LFG role data.

Felsworn:
- Vengeful Pact reminder button.
- Man'ari Intuition reminder button.

Venomancer:
- Envenomed Weapons reminder button.

Debug commands:
/minn profile
/minn roles
/minn mark
/minn list

Changelog:

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
