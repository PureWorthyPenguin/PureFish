-- PureFish: Addon entry point, SavedVariables, Addon Compartment, keybind globals, and /purefish slash command.
local ADDON_NAME, ns = ...

local function MergeDefaults(db)
	local def = ns.BuildDefaultSettings()
	for k, v in pairs(def) do
		if db[k] == nil then
			db[k] = ns.DeepCopy(v)
		end
	end
end

local function InitSavedVariables()
	if type(PureFishDB) ~= "table" then
		PureFishDB = {}
	end
	MergeDefaults(PureFishDB)
end

function ns.GetDB()
	return PureFishDB
end

function ns.ResetDefaults()
	local savedCharData = PureFishDB and PureFishDB.charData
	local savedHeldCVars = PureFishDB and PureFishDB.heldCVars
	PureFishDB = ns.BuildDefaultSettings()
	PureFishDB.charData = savedCharData
	PureFishDB.heldCVars = savedHeldCVars
	print("|cff66ccffPureFish:|r All settings reset to defaults.")
end

-- Global keybinding callbacks (used by Bindings.xml)
function PureFish_CastOrReel()
	if ns.CastOrReelFromKeybind then
		ns.CastOrReelFromKeybind()
	end
end

function PureFish_TogglePole()
	if ns.ToggleFishingPole then
		ns.ToggleFishingPole()
	end
end

-- Addon Compartment dynamic registration (Left-Click: Toggle Pole, Right-Click: Settings)
local compartmentData = {
	text = "PureFish",
	icon = ns.ADDON_ICON,
	registerForAnyClick = true,
	notCheckable = true,
	func = function(_, menuInputData)
		local buttonName = type(menuInputData) == "table" and menuInputData.buttonName or menuInputData
		if buttonName == "RightButton" then
			if ns.OpenSettings then
				ns.OpenSettings()
			end
		else
			if ns.ToggleFishingPole then
				ns.ToggleFishingPole()
			end
		end
	end,
	funcOnEnter = function(menuButtonFrame)
		GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
		if ns.PopulateStatusTooltip then
			ns.PopulateStatusTooltip(GameTooltip, false)
		end
		GameTooltip:Show()
	end,
	funcOnLeave = function()
		GameTooltip:Hide()
	end,
}

local compartmentRegistered = false

local function RemoveFromCompartment()
	if not AddonCompartmentFrame then
		return false
	end
	if AddonCompartmentFrame.UnregisterAddon then
		AddonCompartmentFrame:UnregisterAddon(compartmentData)
		if AddonCompartmentFrame.UpdateDisplay then
			AddonCompartmentFrame:UpdateDisplay()
		end
		return true
	end
	local removed = false
	for _, field in pairs(AddonCompartmentFrame) do
		if type(field) == "table" then
			for i = #field, 1, -1 do
				if field[i] == compartmentData then
					table.remove(field, i)
					removed = true
				end
			end
		end
	end
	if removed and AddonCompartmentFrame.UpdateDisplay then
		AddonCompartmentFrame:UpdateDisplay()
	end
	return removed
end

function ns.UpdateCompartmentButton()
	if not AddonCompartmentFrame then
		return
	end
	local db = ns.GetDB and ns.GetDB()
	local shouldShow = not db or db.showCompartmentButton ~= false

	if shouldShow then
		if not compartmentRegistered and AddonCompartmentFrame.RegisterAddon then
			AddonCompartmentFrame:RegisterAddon(compartmentData)
			compartmentRegistered = true
		end
	else
		if compartmentRegistered then
			if RemoveFromCompartment() then
				compartmentRegistered = false
			else
				print("|cff66ccffPureFish:|r Type |cffffff00/reload|r to remove the Addon Compartment button.")
			end
		end
	end
end

-- Slash command: /purefish
SLASH_PUREFISH1 = "/purefish"
SlashCmdList["PUREFISH"] = function(msg)
	local raw = msg or ""
	local hasCond = raw:find("%[") ~= nil
	if hasCond and SecureCmdOptionParse then
		raw = SecureCmdOptionParse(raw)
		if not raw then
			return
		end
	end
	local cmd = strtrim((raw or ""):lower())
	if cmd == "pole" or cmd == "swap" then
		if ns.ToggleFishingPole then ns.ToggleFishingPole() end
	elseif cmd == "equip" then
		if ns.EquipFishingPole then ns.EquipFishingPole(false) end
	elseif cmd == "weapons" then
		if ns.EquipSavedWeapons then ns.EquipSavedWeapons(false) end
	elseif cmd == "macro" then
		if ns.CreatePoleMacro then ns.CreatePoleMacro() end
	elseif cmd == "pill" then
		local db = ns.GetDB and ns.GetDB()
		if db then
			db.showFishingPill = not db.showFishingPill
			if ns.UpdatePill then ns.UpdatePill() end
			print("|cff66ccffPureFish:|r Minimal Fishing Pill " .. (db.showFishingPill and "|cff55ff55enabled|r." or "|cffff6666disabled|r."))
		end
	elseif cmd == "reset" then
		if ns.ResetPillPosition then ns.ResetPillPosition() end
		if ns.ResetMinimapButtonPosition then ns.ResetMinimapButtonPosition() end
	elseif cmd == "debug" then
		if ns.PrintDebug then ns.PrintDebug() end
	else
		if ns.OpenSettings then ns.OpenSettings() end
	end
end

-- Lifecycle events
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			InitSavedVariables()
			ns.InitUI()
		end
	elseif event == "PLAYER_LOGIN" then
		ns.InitGearAndLure()
		ns.InitEngine()
		ns.InitPill()
		ns.InitMinimapButton()
		ns.UpdateCompartmentButton()
	end
end)
