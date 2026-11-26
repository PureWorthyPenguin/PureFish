# PureFish

**Lightweight, zero-dependency fishing quality-of-life addon for World of Warcraft Forever.**

PureFish streamlines fishing with one-key casting and reeling, camera-safe double right-click, a smart all-in-one action-bar macro, automatic combat weapon re-equip, crash-safe sound and nameplate controls, a 1-click best-lure helper, and a minimal pole-only Blizzard-styled status pill — built in the clean, native style of the Pure suite (`PureFade`, `PureGrid`).

## Features

- **Flexible Cast & Reel Inputs (Active Only While Fishing Pole Equipped):**
  - **Interact Key (default ON):** Press your game's Interact key (e.g. `F`) to cast when nothing is near, and press again to reel in — includes a live binding indicator and one-click shortcut to `Gameplay > Controls > Interact With Target`.
  - **Double Right-Click (default ON):** Camera-safe double right-click to cast and reel, keeping normal right-click and camera turning untouched, with a crash-safe **Click-to-Move** pause while a pole is equipped.
  - **Action-Bar Fishing Key Reels In (default ON):** Pressing your Fishing spell or `PureFishPole` macro keybind on Blizzard action bars while channeling reels in instead of recasting.
  - **Optional Inputs:** Single Right-Click (with anti-conflict guards & missed-cast pause), Spacebar (while standing still; reverts to Jump while moving), Middle Mouse / Mouse 4 / Mouse 5, and dedicated Key Bindings (`Options > Key Bindings > AddOns > PureFish`).
  - **Bobber Soft-Target Icon (default ON):** Automatically enables Soft-Target Interact while fishing with a toggleable native icon above the bobber.
- **Smart Fishing Pole ↔ Weapon Swap & Combat Auto-Equip:**
  - Automatically picks your best fishing pole in bags (highest quality & item level) and remembers your last combat Main Hand & Off Hand per character.
  - **Auto-Equip Weapons on Combat (default ON):** Swaps back to your saved combat weapons immediately when entering combat.
  - **Smart All-in-One Action-Bar Macro (`PureFishPole`):** Left-Click equips your pole or casts Fishing when equipped (and dynamically switches its icon/tooltip); Right-Click swaps back to your saved combat weapons.
- **Crash-Safe CVar Vault:**
  - Temporarily boosted **Sound** (off by default, raise-only Master & SFX sliders, optional Mute Music/Ambience & Background Sound), **Soft-Target**, and **Click-to-Move** CVars are snapshotted in `PureFishDB` and restored automatically on weapon swap, combat, logout, or `/reload` after a crash.
- **Hide Non-Hostile Nameplates & Names While Fishing (default ON):**
  - Hides neutral/friendly nameplates (compatible with default Blizzard nameplates and custom nameplate addons like Platynator, zero mouseover flicker) and non-hostile NPC overhead names while leaving **hostile red nameplates**, **enemy players**, and the **bobber gear icon** untouched.
  - Includes an optional **Also hide friendly player & pet names** sub-setting for crowded fishing spots.
- **Crash-Proof Fishing Auto-Loot (default ON):**
  - Event-based fishing auto-loot that never touches WoW's built-in Auto Loot setting.
- **Best-Lure Helper & Minimal Pole-Only Fishing Pill (default ON):**
  - Sleek draggable Blizzard-styled pill anchored at top-center by default — visible only while a fishing pole is equipped and auto-hidden in combat.
  - Shows a 1-click Lure button (automatically picks your highest-bonus lure in bags) with countdown timer, Fishing skill, session catch counter (hover for full item breakdown, right-click to reset), and a quick Weapon Swap button displaying your saved weapon's icon.
- **Addon Compartment & Optional Minimap Button:**
  - Addon Compartment enabled by default; optional orbiting Minimap button (off by default).

## Slash Commands

- `/purefish` — Open PureFish settings (`Options > AddOns > PureFish`)
- `/purefish pole` — Toggle between your fishing pole and saved combat weapons
- `/purefish macro` — Create/update the smart `PureFishPole` action-bar macro
- `/purefish pill` — Toggle the Minimal Fishing Pill
- `/purefish reset` — Reset Fishing Pill and Minimap button positions

## License

MIT License — Copyright (c) 2026 WorthyPenguin.
