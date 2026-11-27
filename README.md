# PureFish

**Lightweight, zero-dependency fishing quality-of-life addon for World of Warcraft Forever.**

PureFish streamlines fishing with one-key casting and reeling, camera-safe double right-click, a smart all-in-one action-bar macro, automatic combat weapon re-equip, crash-safe sound and nameplate controls, a 1-click best-lure helper, and a minimal pole-only Blizzard-styled status pill — built in the clean, native style of the Pure suite (`PureFade`, `PureGrid`).

## Features

- **Flexible Cast & Reel Inputs (Active Only While Fishing Pole Equipped):**
  - **Interact Key (default ON):** Press your game's Interact key (e.g. `F`) to cast when nothing is near, and press again to reel in — includes a live binding indicator and one-click shortcut to `Gameplay > Controls > Interact With Target`.
  - **Double Right-Click (default ON):** Camera-safe double right-click to cast and reel, keeping normal right-click and camera turning untouched, with a crash-safe **Click-to-Move** pause while a pole is equipped.
  - **Action-Bar Fishing Key Reels In (default ON):** Pressing your Fishing spell or `PureFishPole` macro keybind on Blizzard action bars while channeling reels in instead of recasting.
  - **1-Button Auto-Lure on Cast (optional):** Automatically applies your best bag lure or equipped on-use Fishing Hat on the first press of your cast key when no lure is active, then casts Fishing on the next press.
  - **Optional Inputs:** Single Right-Click (with anti-conflict guards & missed-cast pause), Spacebar (while standing still; reverts to Jump while moving), Middle Mouse / Mouse 4 / Mouse 5, and dedicated Key Bindings (`Options > Key Bindings > AddOns > PureFish`).
  - **Bobber Soft-Target Icon (default ON):** Automatically enables Soft-Target Interact while fishing with a toggleable native icon above the bobber.
- **Smart Fishing Pole ↔ Weapon Swap, Outfit Swap, Tracking & Combat Auto-Equip:**
  - Automatically picks your best fishing pole in bags (highest quality & item level) and remembers your last combat Main Hand & Off Hand per character.
  - **Auto-Equip Weapons on Combat (default ON):** Swaps back to your saved combat weapons immediately when entering combat.
  - **Optional Fishing Armor Swap:** Save your fishing Head, Boots, and Gloves in 1 click to swap alongside your pole (automatically restores combat armor after combat ends).
  - **Auto-Toggle Find Fish Tracking (default ON):** Enables *Find Fish* minimap tracking while a pole is equipped (if learned) and crash-safely restores your previous tracking when swapping back to weapons.
  - **Smart All-in-One Action-Bar Macro (`PureFishPole`):** Left-Click equips your pole or casts Fishing when equipped (and dynamically switches its icon/tooltip); Right-Click swaps back to your saved combat weapons.
- **Crash-Safe CVar Vault:**
  - Temporarily boosted **Sound** (off by default, raise-only Master & SFX sliders, optional Mute Music/Ambience & Background Sound), **Soft-Target**, and **Click-to-Move** CVars are snapshotted in `PureFishDB` and restored automatically on weapon swap, combat, logout, or `/reload` after a crash.
- **Hide Non-Hostile Nameplates & Names While Fishing (default ON):**
  - Hides neutral/friendly nameplates (compatible with default Blizzard nameplates and custom nameplate addons like Platynator, zero mouseover flicker) and non-hostile NPC overhead names while leaving **hostile red nameplates**, **enemy players**, and the **bobber gear icon** untouched.
  - Includes an optional **Also hide friendly player & pet names** sub-setting for crowded fishing spots.
- **Crash-Proof Fishing Auto-Loot (default ON):**
  - Event-based fishing auto-loot that never touches WoW's built-in Auto Loot setting.
- **Best-Lure Helper & Minimal Pole-Only Fishing Pill (default ON):**
  - Sleek draggable translucent pill anchored at top-center by default — visible only while a fishing pole is equipped and auto-hidden in combat, with configurable **Scale** (`75%–150%`) and **Background Opacity** (`0%–100%`).
  - Supports Classic/TBC/WotLK lures plus equipped on-use Fishing Hats (*Weather-Beaten Fishing Hat*), with an optional **Lure-Expiring Chime & Pulse** (`<= 30s`) and a getaway/low-skill lure nudge.
  - Hovering the pill shows rich, live-updating session stats (**duration**, **catches/hour**, **skill-ups gained**, **escaped count**, **Vendor Value**, optional **Auctionator Value**, and full item breakdown; right-click to reset).
- **Live Settings Search Bar, Addon Compartment & Optional Minimap Button:**
  - Filter any option live at the top of `Options > AddOns > PureFish`.
  - Addon Compartment enabled by default; optional orbiting Minimap button (off by default).

## Slash Commands

- `/purefish` — Open PureFish settings (`Options > AddOns > PureFish`)
- `/purefish pole` — Toggle between your fishing pole and saved combat weapons
- `/purefish macro` — Create/update the smart `PureFishPole` action-bar macro
- `/purefish pill` — Toggle the Minimal Fishing Pill
- `/purefish reset` — Reset Fishing Pill and Minimap button positions

## License

MIT License — Copyright (c) 2026 WorthyPenguin.
