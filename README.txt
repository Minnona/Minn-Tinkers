Minn Tinkers
============

Personal WoW 3.3.5a quality-of-life addon.

Version: 0.1.49
License: GPL-3.0

Install:
- Extract MinnTinkers into Interface/AddOns/
- Final path should be Interface/AddOns/MinnTinkers/MinnTinkers.toc

Command:
/minn

Settings:
- Module settings are saved per character through MinnTinkersCharDB.
- Raid lockout snapshots are shared across characters through MinnTinkersDB.
- Specs are not used; class tools are separated by class tabs only.
- The addon uses native Interface > AddOns categories.
- /minn and the minimap button reopen the last Minn Tinkers tab used by that character.
- Expand Minn Tinkers with the + button to see:
  - Universal
  - Chat
  - Raid Rolls
  - Raid Lockouts
  - PvP
  - Felsworn
  - Venomancer
  - Debug

Universal:
- Frog minimap button for opening settings.
- Auto-sell grey items.
- Auto-skip safe single-option gossip. Hold Shift while opening an NPC to bypass it for that interaction.
- Smart dungeon rolls.
- Zul'Gurub green/blue Need override for Smart Dungeon Rolls.
- Wardrobe Auto-Accept for appearance collection confirmations.
- Battleground Spoils Auto-Select for single stat-choice reward windows.
- Popup Guard for protected invites, summons, resurrection, dungeon/LFG, and battleground queue popups.
- Mark tank with Star and healer with Moon from RDF/LFG role data, with optional same-dungeon memory through Mythic+ activation.

Chat:
- Temporarily hides selected numbered channels from selected chat windows inside dungeons, raids, and battlegrounds.
- Dungeon, raid, and battleground suppression are separate settings; arenas are not affected.
- You remain joined to suppressed channels, and Raid, Party, Say, Loot, whispers, guild chat, and other message groups are unchanged.
- Original chat-window channel assignments are restored when leaving the instance or disabling the module, including after a /reload inside the instance.

Raid Rolls:
- Raid Roll Helper for master-looter MS/OS rolls.
- Can track your own item links or trusted raid leader/master-looter item announcements.
- Supports flexible safe starts like roll [item] MS, roll 1-100 [item], and [item] x2 roll MS.

Raid Lockouts:
- Automatically collects the current character's saved raids and world bosses when the character is logged in or the page opens.
- Shows current-realm characters in compact raid and world-boss tables with difficulty columns.
- Character names are colored by difficulty and stacked vertically inside each cell.
- Expired binds that Ascension allows you to reset manually remain visible as grey character names.
- Click the logged-in character's name to open Ascension's confirmation for resetting that specific saved ID.
- Common server reset durations appear once beside the raid or world-boss name.
- Ascension standalone world-boss loot locks are merged with standard raid saves when the normal API omits them.
- Hidden per-boss loot timers fill in missing raid reset durations without adding individual boss rows.

PvP:
- Automatically releases your spirit after death in battlegrounds when enabled.
- Shows friendly and enemy flag-carrier names beside the matching Blizzard flag-status rows.
- Separate settings control auto-release, name display, click targeting, friendly Square marking, and enemy Skull marking.
- Click a ready carrier name to target that player when visible.
- Marks the friendly flag carrier with Square and the enemy flag carrier with Skull when unit access and permissions allow.

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

0.1.49
- Recovered missing Molten Core and Zul'Gurub reset durations from Ascension's hidden per-boss loot locks.
- Hidden ordinary raid bosses remain aggregated into their raid row instead of appearing as individual lockouts.

0.1.48
- Made the logged-in character's raid and world-boss table names clickable.
- Clicking a saved ID uses Ascension's native per-map/per-difficulty reset confirmation and refreshes through the existing bind event.
- Offline character names remain informational because one character cannot reset another character's saved IDs.

0.1.47
- Replaced the Raid Lockouts text report with compact raid and world-boss difficulty tables.
- Added the known Ascension world-boss catalog, vertical character lists, row-level reset timers, and grey resettable binds.
- Made lockout tracking automatic and removed the tracker toggle, view, refresh, forget, and status controls.

0.1.46
- Added Ascension standalone world-boss lockouts that are omitted by the standard saved-instance API.
- Custom lockouts are resolved through Ascension's encounter API and deduplicated against standard raid saves.
- Multi-boss raid loot locks remain grouped under their normal saved-instance entry instead of appearing as individual bosses.

0.1.45
- Renamed the Chat page sections to "Mute channels in these chat windows" and "Channels to mute".
- Hidden inactive placeholder chat windows from the selection list.

0.1.44
- Chat suppression now discovers every configured chat tab from its visible tab label, including docked ElvUI tabs.
- Numbered-channel choices now use live chat-frame assignments and the Ascension joined-channel list.

0.1.43
- Added a Chat settings page and per-window numbered-channel suppression module.
- Added separate dungeon, raid, and battleground scope settings; arenas remain excluded.
- Suppressed channels remain joined and return to their original chat windows after leaving the instance or disabling the module.

0.1.42
- Fixed trusted raid-leader item links sent through normal /raid chat not reaching Raid Roll Helper.
- Raid warning links remain supported.

0.1.41
- Removed the current-realm and recently-expired checkboxes from Raid Lockouts.
- Raid Lockouts now always shows the current realm and hides expired entries.

0.1.40
- Removed 25p/40p maximum-size labels from raid lockout displays.
- /minn and the minimap button now remember and reopen the last-used settings tab per character.

0.1.39
- Removed the "reset unknown" label; lockouts without an available reset duration are simply listed without a timer.

0.1.38
- Fixed Ascension raid lockouts with a zero reset duration disappearing immediately after collection.
- Lockouts with an unavailable reset duration remain visible instead of being treated as expired.
- Reset parsing now accepts both standard remaining durations and absolute timestamps.

0.1.37
- Added a default-on PvP option to automatically release your spirit after death in battlegrounds.
- Auto-release does not run in arenas, dungeons, raids, or the open world.

0.1.36
- Added an Auto-mark Roles option to remember the dungeon's Star/Moon players through Mythic+ activation.
- Remembered roles follow player GUIDs across party-token changes and clear when leaving or entering another dungeon.
- Keep Marked can restore the cached tank/healer even when Mythic+ activation removes live role data and raid markers.

0.1.35
- Added the Raid Lockouts page and account-wide RaidLockouts module.
- Added event-driven Normal, Heroic, Mythic, Ascended, and unknown custom raid lockout snapshots.
- Added by-raid/by-character views, reset timers, scan ages, realm filtering, expired-data display, refresh, and forget controls.

0.1.34
- Added the PvP settings page and BattlegroundsPvP module.
- Added configurable clickable friendly/enemy flag-carrier names beside the matching Blizzard flag icons.
- Added automatic Square/Skull carrier marking with safe cleanup on drops, returns, captures, and carrier changes.

0.1.33
- Expanded Raid Roll Helper start parsing for common MS/OS wording, polite filler, and roll ranges.
- Roll 99/100 instructions are no longer mistaken for multi-copy counts.
- Oversized or ambiguous copy counts are rejected instead of silently clamped.

0.1.28
- Removed redundant grey footnotes from crowded Universal settings sections.
- Removed the extra Raid Rolls announcement footnote while keeping supported-start examples.
- Existing hover tooltips still describe the settings.

0.1.27
- Added a frog minimap button under Universal.
- Left-click opens Minn Tinkers settings.
- Drag moves the button around the minimap.
- Right-click locks or unlocks the button position.
- Added a settings checkbox for locking and a reset-position button.

0.1.26
- Added Zul'Gurub green/blue Need override for Smart Dungeon Rolls.
- The override rolls Need on green or blue items inside Zul'Gurub when Need is available.
- This works even when general raid auto-rolls are disabled.
- Added a Universal settings checkbox for the ZG override.

0.1.25
- Normalized Smart Dungeon Rolls option button widths.
- Mode buttons now align to the same left edge and width.

0.1.24
- Added Popup Guard under Universal.
- Prevents Escape from cancelling allowlisted StaticPopup dialogs for group invites, summons, resurrection, dungeon/LFG, and battleground queue popups.
- Popup Guard does not auto-accept anything and does not globally block Escape.
- Added per-category toggles plus optional popup-ID debug printing.

0.1.23
- Fixed Raid Roll Helper winner selection so normal one-copy rolls only announce the top winner.
- Multi-copy rolls now announce only the top N winners.

0.1.22
- Moved Raid Roll Helper into a separate Raid Rolls settings tab.
- Restored multi-winner announcements to separate lines, but only for actual winners.
- Winner announcements no longer show MS by default.
- MS/OS labels are only shown when at least one /roll 99 OS roll exists for that item.
- Added more roll-start parsing formats: roll [item], [item] roll, [item] x2 roll, roll [item] x2, and similar count/roll variations.

0.1.21
- Reduced Raid Roll Helper announcement spam.
- Roll start now includes the 15s window, followed only by 10s and 5s countdown messages before the result.
- Winner announcements are compact and only include winner/winners, not a multi-line winner list.
- Removed extra OS fallback chatter from normal results.
- Raid Roll Helper can now auto-start from trusted raid leader or master-looter item announcements.
- Added UI toggles for master-looter and raid-leader announcement tracking.

0.1.20
- Added Battleground Spoils Auto-Select under Universal.
- Auto-selects only when the Battleground Spoils window has exactly one real stat choice.
- Ignores Nevermind/Goodbye style cancel options and does nothing if multiple stat options appear.

0.1.19
- Added Wardrobe Auto-Accept under Universal.
- Auto-accepts only the wardrobe appearance collection confirmation with soulbound and cannot-be-undone warning text.
- Requires a recent Ctrl+Alt item click by default to avoid accepting unrelated soulbound prompts.
- Updated Raid Roll Helper default roll duration to 15 seconds with 15/10/5/3/2/1 countdown behavior.

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
