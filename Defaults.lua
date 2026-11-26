-- PureFish: Defaults, constants, lure table, and WoW Forever (16001) safety helpers.
local _, ns = ...

ns.ADDON_ICON = "Interface\\Icons\\Trade_Fishing"
ns.DEFAULT_MINIMAP_ANGLE = 220

-- Global keybinding header & labels for Bindings.xml
BINDING_HEADER_PUREFISH = "PureFish"
BINDING_NAME_PUREFISH_CAST = "Cast / Reel In"
BINDING_NAME_PUREFISH_POLE = "Toggle Fishing Pole"
_G["BINDING_NAME_CLICK PureFishLureButton:LeftButton"] = "Apply Best Lure"

-- Safe value helpers for WoW Forever (secret values & forbidden frames)
local issecretvalue = _G.issecretvalue

function ns.IsSecret(val)
	return issecretvalue ~= nil and issecretvalue(val) == true
end

function ns.SafeNumber(val)
	if type(val) ~= "number" or (issecretvalue and issecretvalue(val)) then
		return nil
	end
	return val
end

function ns.SafeString(val)
	if type(val) ~= "string" or (issecretvalue and issecretvalue(val)) then
		return nil
	end
	return val
end

function ns.SafeBool(val)
	if issecretvalue and issecretvalue(val) then
		return false
	end
	return val and true or false
end

function ns.IsUsableFrame(obj)
	if type(obj) ~= "table" or type(obj.GetObjectType) ~= "function" then
		return false
	end
	if obj.IsForbidden and obj:IsForbidden() then
		return false
	end
	return true
end

function ns.DeepCopy(src)
	if type(src) ~= "table" then
		return src
	end
	local copy = {}
	for k, v in pairs(src) do
		copy[k] = ns.DeepCopy(v)
	end
	return copy
end

function ns.GetCharKey()
	local name = UnitName("player") or "Unknown"
	local realm = GetRealmName() or "Unknown"
	return name .. "-" .. realm
end

-- Fishing spell IDs across ranks / WoW Forever
ns.FISHING_SPELL_IDS = {
	[7620]   = true, -- Apprentice Fishing
	[7731]   = true, -- Journeyman Fishing
	[7732]   = true, -- Expert Fishing
	[18248]  = true, -- Artisan Fishing
	[33095]  = true, -- Master Fishing
	[51294]  = true, -- Grand Master Fishing
	[131474] = true, -- Fishing (generic)
	[131476] = true, -- Fishing (cast)
	[131490] = true, -- Fishing (pole cast)
}

local cachedFishingName

function ns.GetFishingSpellName()
	if cachedFishingName then
		return cachedFishingName
	end
	local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(7620)
	name = ns.SafeString(name)
	if not name then
		name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(131474)
		name = ns.SafeString(name)
	end
	if name then
		cachedFishingName = name
	end
	return name or "Fishing"
end

function ns.GetKnownFishingSpellID()
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		for spellID in pairs(ns.FISHING_SPELL_IDS) do
			if C_SpellBook.IsSpellKnown(spellID) then
				return spellID
			end
		end
	end
	return 7620
end

function ns.IsFishingSpell(spellID)
	local safeStr = ns.SafeString(spellID)
	if safeStr then
		return safeStr == ns.GetFishingSpellName()
	end
	local id = ns.SafeNumber(spellID)
	if not id then
		return false
	end
	if ns.FISHING_SPELL_IDS[id] then
		return true
	end
	local name = C_Spell and C_Spell.GetSpellName and ns.SafeString(C_Spell.GetSpellName(id))
	return name ~= nil and name == ns.GetFishingSpellName()
end

function ns.IsChannelingFishing()
	local ok, name, _, _, _, _, _, _, spellID = pcall(UnitChannelInfo, "player")
	if not ok then
		return false
	end
	if ns.IsFishingSpell(spellID) then
		return true
	end
	local safeName = ns.SafeString(name)
	return safeName ~= nil and safeName == ns.GetFishingSpellName()
end

-- Priority-ordered fishing lures (highest skill bonus first)
ns.LURE_LIST = {
	{ id = 6533, bonus = 100, name = "Aquadynamic Fish Attractor" },
	{ id = 7307, bonus = 75,  name = "Flesh Eating Worm" },
	{ id = 6532, bonus = 75,  name = "Bright Baubles" },
	{ id = 6530, bonus = 50,  name = "Nightcrawlers" },
	{ id = 6811, bonus = 50,  name = "Aquadynamic Fish Lens" },
	{ id = 6529, bonus = 25,  name = "Shiny Bauble" },
}

-- Default account-wide settings
function ns.BuildDefaultSettings()
	return {
		-- Cast & Reel With (active only while a fishing pole is equipped)
		castInteractKey           = true,   -- Default ON (e.g. F)
		castDoubleRightClick       = true,   -- Default ON (camera-safe)
		doubleClickSpeed           = 0.25,   -- 0.10..0.60s window
		doubleClickMounted         = false,  -- Allow double-click cast while mounted
		recastOnDoubleClick        = false,  -- false = double-click reels in; modifier + double-click recasts
		disableClickToMoveWithPole = true,   -- Default ON: crash-safe pause of Click-to-Move while pole equipped
		castSingleRightClick      = false,  -- Optional single right-click (with anti-conflict guards)
		singleRightClickMissPause = 15,     -- 0..30s pause after failed cast
		castSpacebar              = false,  -- Optional spacebar while standing still
		castMouse3                = false,  -- Optional Middle Mouse
		castMouse4                = false,  -- Optional Mouse 4
		castMouse5                = false,  -- Optional Mouse 5
		actionBarKeyReelsIn       = true,   -- Default ON: pressing Fishing on action bar reels in
		showBobberIcon            = true,   -- Default ON: Soft-Target interact icon over bobber

		-- Gear & Combat
		autoEquipWeaponsInCombat  = true,   -- Default ON: auto-swap back to saved weapons on combat

		-- Quality of Life
		autoLootFishing           = true,   -- Default ON: event-based fishing auto-loot (never edits CVar)
		hideFishingCastBar        = false,  -- Default OFF: hide player cast bar while fishing
		hideNonHostileNameplates  = true,   -- Default ON: crash-safe nameplate/name hide while fishing
		hideFriendlyPlayerNames   = false,  -- Default OFF: also hide friendly player & pet overhead names

		-- Sound Boost While Fishing
		soundBoostEnabled         = false,  -- Default OFF
		soundMasterVolume         = 0.80,   -- Raise-only target (0..1)
		soundSfxVolume            = 1.00,   -- Raise-only target (0..1)
		soundMuteMusicAmbience    = false,  -- Optional mute music, ambience, pet sounds
		soundEnableBackground     = true,   -- Keep sound playing while alt-tabbed

		-- Minimal Fishing Pill & Buttons
		showFishingPill           = true,   -- Default ON (pole-only)
		lockFishingPill           = false,
		pillPos                   = nil,    -- { point, relPoint, x, y }
		showCompartmentButton     = true,   -- Default ON
		showMinimapButton         = false,  -- Default OFF
		lockMinimapButton         = false,
		minimapAngle              = ns.DEFAULT_MINIMAP_ANGLE,
	}
end
