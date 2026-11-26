# Changelog

## v1.0.1

- Added optional **Also hide friendly player & pet names** sub-setting under **Hide Non-Hostile Nameplates & Names While Fishing** (clears crowded fishing spots of friendly player, pet, guardian, and totem overhead names; crash-safe).
- Stopped forcing `UnitNameHostleNPC = 1` so hostile name/nameplate settings always respect the player's own defaults.
- Updated Settings tooltips to accurately describe nameplate & overhead name hiding behavior.
- Refined the Minimal Fishing Pill with a sleeker translucent backdrop (`0.65` alpha), symmetrical `22x22` Lure & Weapon Swap buttons, and matching rounded borders.

## v1.0.0

- Initial release of PureFish for World of Warcraft Forever.
- Cast & reel support for Interact Key (`F`), camera-safe Double Right-Click, Action-Bar Fishing key reeling, optional Single Right-Click, Spacebar, Mouse 3/4/5, and dedicated Key Bindings.
- One-button Fishing Pole ↔ Combat Weapon toggle, Action Bar macro creator, and automatic combat weapon re-equip.
- Crash-safe CVar vault (`PureFishDB.heldCVars`) with grace timers for Sound Boost, Soft-Target Interact, and Non-Hostile Nameplates.
- Crash-proof event-based Fishing Auto-Loot and optional Hide Fishing Cast Bar.
- Best-lure scanner (keybind + clickable button on the minimal pole-only Fishing Status Pill) with session catch tracker.
- Native Blizzard Settings UI, Addon Compartment integration, and optional orbiting Minimap button.
