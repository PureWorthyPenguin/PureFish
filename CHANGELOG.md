# Changelog

## v1.1.1

- Fixed a conflict between **Hide Fishing Cast Bar** and UI fading addons like **PureFade** (cast bar now stays cleanly hidden throughout the Fishing cast and fade-out, without flickering or getting stuck when Fishing ends, while normal spell casts appear immediately).

## v1.1.0

- **True 1-Button Fishing (Optional):** New setting **Cast Key Applies Missing Lure First** automatically applies your best available lure (or equipped on-use Fishing Hat) on the first press of any cast key, then casts Fishing on the next press.
- **Lure-Expiring Chime & Pulse:** Optional subtle sound cue and lure icon pulse when your active lure drops to `<= 30s` or expires.
- **Auto-Toggle "Find Fish" Tracking:** Automatically enables *Find Fish* minimap tracking when you equip your fishing pole (if learned) and crash-safely restores your previous tracking (*Find Herbs*, *Find Minerals*, etc.) when you swap back to weapons.
- **Expanded Lure & On-Use Fishing Hat Support:** Added *Sharpened Fish Hook* (+100), *Glow Worm* (+100), and equipped *Weather-Beaten Fishing Hat* (+75 on-use) support to the lure scanner.
- **Optional Fishing Armor Swap:** Save your fishing Head, Boots, and Gloves in 1 click to swap alongside your pole (with automatic post-combat armor restore if combat interrupts fishing).
- **Minimal Fishing Pill Customization:** Added **Pill Scale** (`75%–150%`) and **Pill Background Opacity** (`0%–100%`) sliders with quick **Reset** buttons in Settings.
- **Richer Live Session Tooltip:** Hovering the Fishing Pill now displays live-updating session duration, catches/hour, skill-ups gained, escaped fish count, Vendor Value, and optional **Auctionator Value** alongside the item breakdown.
- **Settings Search Bar:** Added a live search filter at the top of `Options > AddOns > PureFish`.
- **Getaway / Low-Skill Lure Nudge:** Pulses the Pill's lure icon and prints a subtle throttled hint if a fish escapes or skill is too low while fishing without an active lure.

## v1.0.2

- Updated default Minimap button angle to `192°` so PureFade (`164°`), PureFish (`192°`), and PureGrid (`220°`) sit cleanly in alphabetical order with zero overlap.
- Stopped modifying `nameplateShowFriends` / `nameplateShowFriendlyPlayers` CVars and skipped redundant `SetCVar` writes when already at target values, eliminating stacking enemy nameplate resets between recasts.
- Standardized between-cast CVar grace timers to `10s` across Sound, Nameplates, and Soft-Target (still restoring instantly on weapon swap or combat).
- Tightened `SoftTargetInteractRange` from `60` to `30` yards (keeping `Arc = 2`) so panning the camera doesn't grab distant NPCs while still allowing wide-angle bobber reeling.

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
