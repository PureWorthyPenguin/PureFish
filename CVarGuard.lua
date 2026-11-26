-- PureFish: Crash-safe CVar vault (Sound Boost, Soft-Target Interact, Non-Hostile Nameplates).
-- Every temporary CVar modification is snapshotted into PureFishDB.heldCVars before being changed
-- and restored after a grace timer, on logout, or on next login if interrupted by /reload or crash.
local _, ns = ...

local SOUND_GRACE_SECONDS = 5
local NAMEPLATE_GRACE_SECONDS = 5
local SOFTTARGET_GRACE_SECONDS = 10
local RestoreFadedPlates

local tokens = {
	softTarget = 0,
	sound = 0,
	nameplates = 0,
	clickToMove = 0,
}

local function GetVault()
	local db = ns.GetDB and ns.GetDB()
	if not db then
		return nil
	end
	if type(db.heldCVars) ~= "table" then
		db.heldCVars = {}
	end
	return db.heldCVars
end

local function ValuesMatch(a, b)
	if a == b then
		return true
	end
	local na, nb = tonumber(a), tonumber(b)
	if na and nb then
		return math.abs(na - nb) < 0.005
	end
	return false
end

local function ApplyCVar(group, cvar, value)
	local vault = GetVault()
	if not vault then
		return
	end
	if type(vault[group]) ~= "table" then
		vault[group] = {}
	end
	local held = vault[group]
	local targetStr = tostring(value)

	if not held[cvar] then
		local ok, orig = pcall(GetCVar, cvar)
		if not ok or orig == nil then
			return
		end
		held[cvar] = { from = tostring(orig), to = targetStr }
	else
		held[cvar].to = targetStr
	end

	pcall(SetCVar, cvar, targetStr)
end

local function RestoreGroup(group)
	local db = ns.GetDB and ns.GetDB()
	if not db or type(db.heldCVars) ~= "table" then
		return
	end
	local held = db.heldCVars[group]
	if type(held) ~= "table" then
		return
	end

	for cvar, entry in pairs(held) do
		if type(entry) == "table" and entry.from ~= nil then
			local ok, current = pcall(GetCVar, cvar)
			-- Only restore if the CVar still holds our applied value (respects manual user edits)
			if ok and ValuesMatch(current, entry.to) then
				pcall(SetCVar, cvar, entry.from)
			end
		end
	end

	db.heldCVars[group] = nil
	if not next(db.heldCVars) then
		db.heldCVars = nil
	end
end

function ns.RestoreAllCVars()
	tokens.softTarget = tokens.softTarget + 1
	tokens.sound = tokens.sound + 1
	tokens.nameplates = tokens.nameplates + 1
	tokens.clickToMove = tokens.clickToMove + 1
	RestoreGroup("softTarget")
	RestoreGroup("sound")
	RestoreGroup("nameplates")
	RestoreGroup("clickToMove")
	if RestoreFadedPlates then
		RestoreFadedPlates()
	end
end

function ns.UpdateClickToMoveGuard()
	local db = ns.GetDB and ns.GetDB()
	local wantDisable = db and db.disableClickToMoveWithPole and db.castDoubleRightClick
		and not db.castSingleRightClick
		and ns.IsPoleEquipped and ns.IsPoleEquipped()
		and not InCombatLockdown()
		and not ns.SafeBool(UnitAffectingCombat("player"))

	if wantDisable then
		local ok, cur = pcall(GetCVar, "autointeract")
		if ok and tostring(cur) == "1" then
			ApplyCVar("clickToMove", "autointeract", "0")
		end
	else
		RestoreGroup("clickToMove")
	end
end

local function ApplySoftTarget(db)
	tokens.softTarget = tokens.softTarget + 1
	ApplyCVar("softTarget", "SoftTargetInteract", "3")
	ApplyCVar("softTarget", "SoftTargetInteractArc", "2")
	ApplyCVar("softTarget", "SoftTargetInteractRange", "60")
	local iconVal = (db.showBobberIcon ~= false) and "1" or "0"
	ApplyCVar("softTarget", "SoftTargetIconGameObject", iconVal)
	ApplyCVar("softTarget", "SoftTargetIconInteract", iconVal)
end

local function ApplySoundBoost(db)
	if not db.soundBoostEnabled then
		return
	end
	tokens.sound = tokens.sound + 1

	ApplyCVar("sound", "Sound_EnableAllSound", "1")
	ApplyCVar("sound", "Sound_EnableSFX", "1")

	-- Raise-only for Master and SFX volumes so we never lower louder user settings
	local wantMaster = tonumber(db.soundMasterVolume)
	local curMaster = tonumber(GetCVar("Sound_MasterVolume"))
	if wantMaster and curMaster and curMaster < wantMaster - 0.005 then
		ApplyCVar("sound", "Sound_MasterVolume", string.format("%.2f", wantMaster))
	end

	local wantSfx = tonumber(db.soundSfxVolume)
	local curSfx = tonumber(GetCVar("Sound_SFXVolume"))
	if wantSfx and curSfx and curSfx < wantSfx - 0.005 then
		ApplyCVar("sound", "Sound_SFXVolume", string.format("%.2f", wantSfx))
	end

	if db.soundMuteMusicAmbience then
		ApplyCVar("sound", "Sound_EnableMusic", "0")
		ApplyCVar("sound", "Sound_EnableAmbience", "0")
		ApplyCVar("sound", "Sound_EnablePetSounds", "0")
	end

	if db.soundEnableBackground then
		ApplyCVar("sound", "Sound_EnableSoundWhenGameIsInBG", "1")
	end
end

local nameplateFadeActive = false
local fadedPlates = {}
local fadedFrames = {} -- individual plate/child frames currently pinned to alpha 0
local alphaHooked = {} -- frames with one-time hooksecurefunc on SetAlpha
local plateGuardTicker = nil

local function ShouldFadePlate(unit)
	if not unit then
		return false
	end
	-- Never fade the bobber / soft-interact target (which holds the golden gear icon)
	if UnitIsUnit and ns.SafeBool(UnitIsUnit(unit, "softinteract")) then
		return false
	end
	if ns.SafeBool(UnitAffectingCombat(unit)) then
		return false
	end
	-- Only fade real neutral/friendly units (reaction >= 4); GameObjects (bobber) have nil reaction
	-- and hostile red mobs have reaction <= 3.
	local reaction = ns.SafeNumber(UnitReaction("player", unit))
	return reaction ~= nil and reaction >= 4
end

local function PinFrameAlpha(frame, hide)
	if not ns.IsUsableFrame(frame) then
		return
	end
	if hide then
		fadedFrames[frame] = true
		if not alphaHooked[frame] then
			alphaHooked[frame] = true
			hooksecurefunc(frame, "SetAlpha", function(self, a)
				if nameplateFadeActive and fadedFrames[self] and type(a) == "number" and a > 0 then
					self:SetAlpha(0)
				end
			end)
		end
		frame:SetAlpha(0)
	else
		fadedFrames[frame] = nil
		frame:SetAlpha(1)
	end
end

local function SetPlateHidden(plate, hide)
	if not ns.IsUsableFrame(plate) then
		return
	end
	PinFrameAlpha(plate, hide)
	if plate.UnitFrame and ns.IsUsableFrame(plate.UnitFrame) then
		PinFrameAlpha(plate.UnitFrame, hide)
	end
	if plate.GetChildren then
		for _, child in ipairs({ plate:GetChildren() }) do
			if ns.IsUsableFrame(child) then
				PinFrameAlpha(child, hide)
			end
		end
	end
end

local function ApplyPlateAlpha(plate, unit)
	if not ns.IsUsableFrame(plate) then
		return
	end
	if nameplateFadeActive and ShouldFadePlate(unit) then
		SetPlateHidden(plate, true)
		fadedPlates[plate] = true
	elseif fadedPlates[plate] then
		SetPlateHidden(plate, false)
		fadedPlates[plate] = nil
	end
end

local function UpdateAllNonHostilePlates()
	if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
		return
	end
	for i = 1, 40 do
		local unit = "nameplate" .. i
		local plate = C_NamePlate.GetNamePlateForUnit(unit)
		if plate then
			ApplyPlateAlpha(plate, unit)
		end
	end
end

RestoreFadedPlates = function()
	nameplateFadeActive = false
	if plateGuardTicker then
		plateGuardTicker:Cancel()
		plateGuardTicker = nil
	end
	for plate in pairs(fadedPlates) do
		SetPlateHidden(plate, false)
	end
	wipe(fadedPlates)
	wipe(fadedFrames)
end

local function ApplyNameplateHide(db)
	if not db.hideNonHostileNameplates then
		return
	end
	tokens.nameplates = tokens.nameplates + 1

	-- Hide friendly nameplates & non-hostile NPC names via CVars, while leaving
	-- nameplateShowEnemies and UnitNameHostleNPC untouched so user hostile settings are respected.
	ApplyCVar("nameplates", "nameplateShowFriends", "0")
	ApplyCVar("nameplates", "nameplateShowFriendlyPlayers", "0")
	ApplyCVar("nameplates", "UnitNameNPC", "0")
	ApplyCVar("nameplates", "UnitNameNonCombatCreatureName", "0")
	ApplyCVar("nameplates", "UnitNameInteractiveNPC", "0")
	ApplyCVar("nameplates", "UnitNameFriendlySpecialNPCName", "0")

	if db.hideFriendlyPlayerNames then
		ApplyCVar("nameplates", "UnitNameFriendlyPlayerName", "0")
		ApplyCVar("nameplates", "UnitNameFriendlyPetName", "0")
		ApplyCVar("nameplates", "UnitNameFriendlyGuardianName", "0")
		ApplyCVar("nameplates", "UnitNameFriendlyTotemName", "0")
	end

	-- Fade yellow neutral nameplates (reaction >= 4) using combat-safe SetAlpha(0)
	nameplateFadeActive = true
	UpdateAllNonHostilePlates()
	if not plateGuardTicker then
		plateGuardTicker = C_Timer.NewTicker(0.25, function()
			if nameplateFadeActive then
				UpdateAllNonHostilePlates()
			end
		end)
	end
end

function ns.OnFishingCVarsStart()
	local db = ns.GetDB and ns.GetDB()
	if not db then
		return
	end
	ApplySoftTarget(db)
	ApplySoundBoost(db)
	ApplyNameplateHide(db)
end

function ns.OnFishingCVarsStop()
	tokens.softTarget = tokens.softTarget + 1
	local softMine = tokens.softTarget
	C_Timer.After(SOFTTARGET_GRACE_SECONDS, function()
		if softMine == tokens.softTarget and not ns.IsChannelingFishing() then
			RestoreGroup("softTarget")
		end
	end)

	tokens.sound = tokens.sound + 1
	local soundMine = tokens.sound
	C_Timer.After(SOUND_GRACE_SECONDS, function()
		if soundMine == tokens.sound and not ns.IsChannelingFishing() then
			RestoreGroup("sound")
		end
	end)

	tokens.nameplates = tokens.nameplates + 1
	local npMine = tokens.nameplates
	C_Timer.After(NAMEPLATE_GRACE_SECONDS, function()
		if npMine == tokens.nameplates and not ns.IsChannelingFishing() then
			RestoreGroup("nameplates")
			RestoreFadedPlates()
		end
	end)
end

function ns.OnCVarSettingsChanged()
	local db = ns.GetDB and ns.GetDB()
	if not db then
		return
	end
	if not db.soundBoostEnabled then
		tokens.sound = tokens.sound + 1
		RestoreGroup("sound")
	elseif ns.IsChannelingFishing() then
		RestoreGroup("sound")
		ApplySoundBoost(db)
	end

	if not db.hideNonHostileNameplates then
		tokens.nameplates = tokens.nameplates + 1
		RestoreGroup("nameplates")
		RestoreFadedPlates()
	elseif ns.IsChannelingFishing() then
		RestoreGroup("nameplates")
		ApplyNameplateHide(db)
	end

	if ns.IsChannelingFishing() then
		ApplySoftTarget(db)
	end

	ns.UpdateClickToMoveGuard()
end

-- Automatic crash / /reload recovery on login, clean restore on logout, and combat safety for Click-to-Move
local guardFrame = CreateFrame("Frame")
guardFrame:RegisterEvent("PLAYER_LOGIN")
guardFrame:RegisterEvent("PLAYER_LOGOUT")
guardFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
guardFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
guardFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
guardFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
guardFrame:SetScript("OnEvent", function(_, event, arg1)
	if event == "PLAYER_LOGIN" then
		ns.RestoreAllCVars()
		ns.UpdateClickToMoveGuard()
	elseif event == "PLAYER_LOGOUT" then
		ns.RestoreAllCVars()
	elseif event == "PLAYER_REGEN_DISABLED" then
		RestoreGroup("clickToMove")
		RestoreGroup("nameplates")
		RestoreFadedPlates()
	elseif event == "PLAYER_REGEN_ENABLED" then
		ns.UpdateClickToMoveGuard()
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		if nameplateFadeActive and arg1 and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
			local plate = C_NamePlate.GetNamePlateForUnit(arg1)
			if plate then
				ApplyPlateAlpha(plate, arg1)
			end
		end
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		if arg1 and C_NamePlate and C_NamePlate.GetNamePlateForUnit then
			local plate = C_NamePlate.GetNamePlateForUnit(arg1)
			if plate and fadedPlates[plate] then
				SetPlateHidden(plate, false)
				fadedPlates[plate] = nil
			end
		end
	end
end)
