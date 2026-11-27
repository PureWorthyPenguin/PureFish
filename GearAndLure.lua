-- PureFish: Fishing pole detection, weapon swap, combat auto-equip, macro creator, and best-lure engine.
local _, ns = ...

local poleEquipped = false
local bestLure = nil -- { id, bonus, name, count, icon, macroText, isHat }
local lureButton = nil
local pillLureButton = nil
local pendingLureSync = false
local pendingMacroSync = false
local pendingArmorRestore = false
local combatRetryToken = 0
local SyncPoleMacro

local function IsItemFishingPole(itemID)
	if not itemID then
		return false
	end
	local infoFn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if not infoFn then
		return false
	end
	local _, _, _, _, _, classID, subclassID = infoFn(itemID)
	local poleSubclass = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole) or 20
	return classID == 2 and subclassID == poleSubclass
end

local function GetCharData()
	local db = ns.GetDB and ns.GetDB()
	if not db then
		return nil
	end
	if type(db.charData) ~= "table" then
		db.charData = {}
	end
	local key = ns.GetCharKey()
	if type(db.charData[key]) ~= "table" then
		db.charData[key] = {}
	end
	return db.charData[key]
end

function ns.IsPoleEquipped()
	return poleEquipped
end

local function FindItemInBags(targetItemID)
	if not targetItemID then
		return nil, nil
	end
	local numBags = NUM_BAG_SLOTS or 4
	for bag = 0, numBags do
		local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID == targetItemID then
				return bag, slot
			end
		end
	end
	return nil, nil
end

local function GetPoleScore(itemID)
	local quality, ilvl = 0, 0
	if C_Item and C_Item.GetItemQualityByID then
		quality = ns.SafeNumber(C_Item.GetItemQualityByID(itemID)) or 0
	end
	if C_Item and C_Item.GetDetailedItemLevelInfo then
		ilvl = ns.SafeNumber(C_Item.GetDetailedItemLevelInfo(itemID)) or 0
	elseif GetItemInfo then
		local _, _, q, l = GetItemInfo(itemID)
		if quality == 0 then quality = ns.SafeNumber(q) or 0 end
		ilvl = ns.SafeNumber(l) or 0
	end
	return (quality * 10000) + ilvl
end

local function FindAnyPoleInBags()
	local charData = GetCharData()
	local savedPoleID = charData and charData.poleID
	local bestID, bestBag, bestSlot, bestScore = nil, nil, nil, -1
	local numBags = NUM_BAG_SLOTS or 4
	for bag = 0, numBags do
		local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
		for slot = 1, slots do
			local itemID = C_Container.GetContainerItemID(bag, slot)
			if itemID and IsItemFishingPole(itemID) then
				local score = GetPoleScore(itemID)
				if score > bestScore or (score == bestScore and itemID == savedPoleID) then
					bestID, bestBag, bestSlot, bestScore = itemID, bag, slot, score
				end
			end
		end
	end
	return bestID, bestBag, bestSlot
end

local function EquipItemToSlot(itemID, invSlot)
	if not itemID then
		return false
	end
	if GetInventoryItemID("player", invSlot) == itemID then
		return true
	end
	local bag, slot = FindItemInBags(itemID)
	if bag and slot and C_Container and C_Container.PickupContainerItem and EquipCursorItem then
		ClearCursor()
		C_Container.PickupContainerItem(bag, slot)
		if CursorHasItem() then
			EquipCursorItem(invSlot)
			ClearCursor()
			return true
		end
	end
	if C_Item and C_Item.EquipItemByName then
		pcall(C_Item.EquipItemByName, itemID, invSlot)
		return true
	end
	return false
end

local function RefreshEquipmentState()
	local prev = poleEquipped
	local mhID = GetInventoryItemID("player", INVSLOT_MAINHAND or 16)
	local ohID = GetInventoryItemID("player", INVSLOT_OFFHAND or 17)
	poleEquipped = IsItemFishingPole(mhID)

	local charData = GetCharData()
	if charData then
		if poleEquipped then
			charData.poleID = mhID
		elseif mhID then
			charData.mainHandID = mhID
			charData.offHandID = ohID or false
		end
	end

	if poleEquipped ~= prev then
		if SyncPoleMacro then
			SyncPoleMacro()
		end
		if ns.OnPoleStateChanged then
			ns.OnPoleStateChanged(poleEquipped)
		end
		if ns.UpdatePill then
			ns.UpdatePill()
		end
		if ns.UpdateMinimapButton then
			ns.UpdateMinimapButton()
		end
	end
end

local function RestoreCombatArmor()
	local db = ns.GetDB and ns.GetDB()
	if not db or not db.swapFishingOutfit then
		pendingArmorRestore = false
		return
	end
	if InCombatLockdown() then
		pendingArmorRestore = true
		return
	end
	pendingArmorRestore = false
	local charData = GetCharData()
	if not charData or type(charData.combatArmor) ~= "table" then
		return
	end
	for _, slotID in ipairs(ns.FISHING_ARMOR_SLOTS or { 1, 8, 10 }) do
		local itemID = charData.combatArmor[slotID]
		if type(itemID) == "number" and GetInventoryItemID("player", slotID) ~= itemID then
			EquipItemToSlot(itemID, slotID)
		end
	end
end

local function EquipFishingArmor()
	local db = ns.GetDB and ns.GetDB()
	if not db or not db.swapFishingOutfit or InCombatLockdown() then
		return
	end
	local charData = GetCharData()
	if not charData or type(charData.fishingArmor) ~= "table" or not next(charData.fishingArmor) then
		return
	end
	if type(charData.combatArmor) ~= "table" then
		charData.combatArmor = {}
	end
	for _, slotID in ipairs(ns.FISHING_ARMOR_SLOTS or { 1, 8, 10 }) do
		local fishItemID = charData.fishingArmor[slotID]
		if type(fishItemID) == "number" then
			local curID = GetInventoryItemID("player", slotID)
			if curID and curID ~= fishItemID then
				charData.combatArmor[slotID] = curID
			end
			if curID ~= fishItemID then
				EquipItemToSlot(fishItemID, slotID)
			end
		end
	end
end

function ns.SaveFishingOutfit()
	local charData = GetCharData()
	if not charData then
		return false
	end
	local saved = {}
	local names = {}
	local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
	for _, slotID in ipairs(ns.FISHING_ARMOR_SLOTS or { 1, 8, 10 }) do
		local itemID = GetInventoryItemID("player", slotID)
		if itemID then
			saved[slotID] = itemID
			names[#names + 1] = (getName and getName(itemID)) or ("Item #" .. tostring(itemID))
		end
	end
	charData.fishingArmor = saved
	if #names > 0 then
		print("|cff66ccffPureFish:|r Saved Fishing Armor: |cffffd100" .. table.concat(names, ", ") .. "|r")
	else
		print("|cff66ccffPureFish:|r No Head, Boots, or Gloves equipped to save.")
	end
	return #names > 0
end

function ns.ClearFishingOutfit()
	local charData = GetCharData()
	if charData then
		charData.fishingArmor = nil
		charData.combatArmor = nil
	end
	pendingArmorRestore = false
	print("|cff66ccffPureFish:|r Saved Fishing Armor cleared.")
end

function ns.GetFishingOutfitSummary()
	local charData = GetCharData()
	if not charData or type(charData.fishingArmor) ~= "table" or not next(charData.fishingArmor) then
		return "None saved (equip fishing hat/boots/gloves & click Save)"
	end
	local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
	local names = {}
	for _, slotID in ipairs(ns.FISHING_ARMOR_SLOTS or { 1, 8, 10 }) do
		local id = charData.fishingArmor[slotID]
		if type(id) == "number" then
			names[#names + 1] = (getName and getName(id)) or ("Item #" .. tostring(id))
		end
	end
	return #names > 0 and table.concat(names, ", ") or "None saved"
end

function ns.EquipSavedWeapons(silent)
	local charData = GetCharData()
	if not charData or not charData.mainHandID then
		if not silent then
			print("|cff66ccffPureFish:|r No saved combat weapon found yet. Equip your normal weapon once so PureFish remembers it.")
		end
		return false
	end

	local mhID = charData.mainHandID
	local ohID = type(charData.offHandID) == "number" and charData.offHandID or nil

	EquipItemToSlot(mhID, INVSLOT_MAINHAND or 16)
	if ohID then
		EquipItemToSlot(ohID, INVSLOT_OFFHAND or 17)
	end
	RestoreCombatArmor()

	-- Retry briefly if GCD or combat swap delayed the off-hand or main-hand
	combatRetryToken = combatRetryToken + 1
	local myToken = combatRetryToken
	local attempts = 0
	local function RetryCheck()
		if myToken ~= combatRetryToken then
			return
		end
		attempts = attempts + 1
		local needMH = GetInventoryItemID("player", INVSLOT_MAINHAND or 16) ~= mhID
		local needOH = ohID and (GetInventoryItemID("player", INVSLOT_OFFHAND or 17) ~= ohID)
		if not needMH and not needOH then
			RefreshEquipmentState()
			return
		end
		if needMH then
			EquipItemToSlot(mhID, INVSLOT_MAINHAND or 16)
		end
		if needOH then
			EquipItemToSlot(ohID, INVSLOT_OFFHAND or 17)
		end
		if attempts < 5 then
			C_Timer.After(0.35, RetryCheck)
		end
	end
	C_Timer.After(0.35, RetryCheck)
	return true
end

function ns.EquipFishingPole(silent)
	if poleEquipped then
		EquipFishingArmor()
		return true
	end
	local poleID = FindAnyPoleInBags()
	if not poleID then
		if not silent then
			print("|cff66ccffPureFish:|r No fishing pole found in your bags.")
		end
		return false
	end
	EquipItemToSlot(poleID, INVSLOT_MAINHAND or 16)
	EquipFishingArmor()
	return true
end

function ns.ToggleFishingPole()
	RefreshEquipmentState()
	if poleEquipped then
		return ns.EquipSavedWeapons(false)
	else
		return ns.EquipFishingPole(false)
	end
end

function ns.GetSavedWeaponIcon()
	local charData = GetCharData()
	if charData and charData.mainHandID then
		local getIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
		local icon = getIcon and getIcon(charData.mainHandID)
		if icon then
			return icon
		end
	end
	return "Interface\\Icons\\INV_Sword_04"
end

function ns.GetSavedGearSummary()
	local charData = GetCharData()
	if not charData or not charData.mainHandID then
		return "None saved yet (equip a weapon once)"
	end
	local getName = (C_Item and C_Item.GetItemNameByID) or GetItemInfo
	local mhName = getName and getName(charData.mainHandID) or ("Item #" .. tostring(charData.mainHandID))
	if type(charData.offHandID) == "number" then
		local ohName = getName and getName(charData.offHandID) or ("Item #" .. tostring(charData.offHandID))
		return mhName .. " + " .. ohName
	end
	return mhName
end

local MACRO_NAME = "PureFishPole"
local MACRO_ICON = "INV_Misc_QuestionMark"

local function BuildPoleMacroBody()
	local fishSpell = ns.GetFishingSpellName()
	if poleEquipped then
		return "#showtooltip " .. fishSpell .. "\n/purefish [btn:2] weapons\n/cast [nobtn:2] " .. fishSpell
	end
	local poleID = FindAnyPoleInBags()
	local tooltipTarget = poleID and ("item:" .. tostring(poleID)) or fishSpell
	return "#showtooltip " .. tooltipTarget .. "\n/purefish equip"
end

SyncPoleMacro = function()
	if InCombatLockdown() then
		pendingMacroSync = true
		return
	end
	local existing = GetMacroIndexByName(MACRO_NAME)
	if not existing or existing <= 0 then
		return
	end
	pendingMacroSync = false
	EditMacro(existing, MACRO_NAME, MACRO_ICON, BuildPoleMacroBody())
end

-- Create or update the smart PureFishPole macro and pick it up for the action bar
function ns.CreatePoleMacro()
	if InCombatLockdown() then
		print("|cff66ccffPureFish:|r Cannot create macro while in combat.")
		return false
	end
	local body = BuildPoleMacroBody()
	local existing = GetMacroIndexByName(MACRO_NAME)
	local idx
	if existing and existing > 0 then
		idx = EditMacro(existing, MACRO_NAME, MACRO_ICON, body)
	else
		local numGlobal = GetNumMacros()
		local perChar = (numGlobal >= (MAX_ACCOUNT_MACROS or 120))
		idx = CreateMacro(MACRO_NAME, MACRO_ICON, body, perChar)
	end
	if idx and idx > 0 then
		PickupMacro(idx)
		print("|cff66ccffPureFish:|r Smart macro |cffffff00" .. MACRO_NAME .. "|r placed on your cursor - Left-Click equips pole / casts Fishing, Right-Click swaps back to weapons!")
		return true
	end
	print("|cff66ccffPureFish:|r Could not create macro (your macro list may be full).")
	return false
end

--------------------------------------------------------------------------------
-- Best Lure Scanner & Secure Button
--------------------------------------------------------------------------------
local function ApplyLureMacroToButton(btn)
	if not btn or InCombatLockdown() then
		pendingLureSync = true
		return
	end
	if bestLure and bestLure.macroText then
		btn:SetAttribute("type", "macro")
		btn:SetAttribute("macrotext", bestLure.macroText)
	else
		btn:SetAttribute("type", nil)
		btn:SetAttribute("macrotext", nil)
	end
end

function ns.RegisterPillLureButton(btn)
	pillLureButton = btn
	ApplyLureMacroToButton(btn)
end

function ns.GetBestLureMacroText()
	return bestLure and bestLure.macroText or nil
end

local function IsInventorySlotReady(slotID)
	if not GetInventoryItemCooldown then
		return true
	end
	local ok, start, duration = pcall(GetInventoryItemCooldown, "player", slotID)
	if not ok then
		return true
	end
	start = ns.SafeNumber(start) or 0
	duration = ns.SafeNumber(duration) or 0
	return start == 0 or duration <= 1.5
end

local function ScanBestLure()
	local found = nil
	local getCount = (C_Item and C_Item.GetItemCount) or GetItemCount
	local getIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

	-- Check equipped on-use Fishing Hat (e.g. Weather-Beaten Fishing Hat, +75)
	local headID = GetInventoryItemID("player", 1)
	local hatInfo = headID and ns.ON_USE_FISHING_HATS and ns.ON_USE_FISHING_HATS[headID]
	if hatInfo and IsInventorySlotReady(1) then
		found = {
			id = headID,
			bonus = hatInfo.bonus,
			name = hatInfo.name,
			count = 1,
			icon = (getIcon and getIcon(headID)) or "Interface\\Icons\\INV_Helmet_31",
			macroText = "/use 1",
			isHat = true,
		}
	end

	-- Check bag lures (pick strictly higher bonus over equipped hat, or any if no hat)
	if getCount then
		for _, lure in ipairs(ns.LURE_LIST) do
			local count = getCount(lure.id) or 0
			if count > 0 then
				if not found or lure.bonus > found.bonus then
					found = {
						id = lure.id,
						bonus = lure.bonus,
						name = lure.name,
						count = count,
						icon = (getIcon and getIcon(lure.id)) or "Interface\\Icons\\INV_Misc_Orb_03",
						macroText = "/use item:" .. lure.id .. "\n/use 16",
						isHat = false,
					}
				end
				break
			end
		end
	end
	bestLure = found
	if InCombatLockdown() then
		pendingLureSync = true
	else
		pendingLureSync = false
		ApplyLureMacroToButton(lureButton)
		ApplyLureMacroToButton(pillLureButton)
	end
	if ns.UpdateCastButtonAction then
		ns.UpdateCastButtonAction()
	end
	if ns.UpdatePill then
		ns.UpdatePill()
	end
end

function ns.GetLureStatus()
	local hasEnchant, expirationMs = false, 0
	if poleEquipped and GetWeaponEnchantInfo then
		local ok, hasMH, expMH = pcall(GetWeaponEnchantInfo)
		if ok and ns.SafeBool(hasMH) then
			hasEnchant = true
			expirationMs = ns.SafeNumber(expMH) or 0
		end
	end
	return {
		hasEnchant = hasEnchant,
		timeLeftSec = math.max(0, math.floor((expirationMs / 1000) + 0.5)),
		bestLure = bestLure,
	}
end

-- Safe Fishing skill reader for WoW Forever
function ns.GetFishingSkillInfo()
	local fishingName = ns.GetFishingSpellName()
	-- Try Classic/Forever Skill Line API first
	if GetNumSkillLines and GetSkillLineInfo then
		local ok, num = pcall(GetNumSkillLines)
		if ok and type(num) == "number" then
			for i = 1, num do
				local sOk, name, isHeader, _, rank, tempModifier, _, maxRank = pcall(GetSkillLineInfo, i)
				if sOk and not isHeader and ns.SafeString(name) == fishingName then
					local r = ns.SafeNumber(rank) or 0
					local m = ns.SafeNumber(maxRank) or 0
					local mod = ns.SafeNumber(tempModifier) or 0
					return r, m, mod
				end
			end
		end
	end
	-- Fallback to Modern Professions API
	if GetProfessions and GetProfessionInfo then
		local ok, _, _, _, fishingIdx = pcall(GetProfessions)
		if ok and fishingIdx then
			local pOk, _, _, rank, maxRank, _, _, _, skillModifier = pcall(GetProfessionInfo, fishingIdx)
			if pOk then
				return ns.SafeNumber(rank) or 0, ns.SafeNumber(maxRank) or 0, ns.SafeNumber(skillModifier) or 0
			end
		end
	end
	return nil, nil, 0
end

function ns.InitGearAndLure()
	if not lureButton then
		local btn = CreateFrame("Button", "PureFishLureButton", UIParent, "SecureActionButtonTemplate")
		btn:RegisterForClicks("AnyDown", "AnyUp")
		btn:Hide()
		lureButton = btn
	end
	RefreshEquipmentState()
	SyncPoleMacro()
	ScanBestLure()
end

local gearFrame = CreateFrame("Frame")
gearFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
gearFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
gearFrame:RegisterEvent("BAG_UPDATE_DELAYED")
gearFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
gearFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
gearFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_EQUIPMENT_CHANGED" then
		RefreshEquipmentState()
		ScanBestLure()
	elseif event == "BAG_UPDATE_DELAYED" then
		ScanBestLure()
	elseif event == "PLAYER_REGEN_DISABLED" then
		local db = ns.GetDB and ns.GetDB()
		if db and db.autoEquipWeaponsInCombat and poleEquipped then
			ns.EquipSavedWeapons(true)
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingArmorRestore then
			RestoreCombatArmor()
		end
		RefreshEquipmentState()
		if pendingMacroSync then
			SyncPoleMacro()
		end
		if pendingLureSync then
			pendingLureSync = false
			ApplyLureMacroToButton(lureButton)
			ApplyLureMacroToButton(pillLureButton)
		end
	end
end)
