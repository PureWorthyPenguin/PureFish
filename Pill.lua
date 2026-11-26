-- PureFish: Optional minimal, pole-only Blizzard-styled Fishing Status Pill & session tracker.
local _, ns = ...

local pillFrame
local lureBtn
local lureIcon
local lureCountFS
local lureTimerFS
local lureGlow
local statusFS
local swapBtn
local swapIcon
local updateTicker

-- Session catch tracking
local sessionTotal = 0
local sessionItems = {} -- [itemName] = { count = n, icon = texture }
local lastLootWindowAt = 0

function ns.RecordFishingLoot(numLoot)
	local now = GetTime()
	-- Guard against duplicate LOOT_READY events for the same bobber
	if (now - lastLootWindowAt) < 0.4 then
		return
	end
	lastLootWindowAt = now

	local addedAny = false
	for slot = 1, numLoot do
		local ok, icon, name, quantity = pcall(GetLootSlotInfo, slot)
		if ok then
			local safeName = ns.SafeString(name)
			local safeQty = ns.SafeNumber(quantity) or 1
			if safeName and safeName ~= "" and safeQty > 0 then
				sessionTotal = sessionTotal + safeQty
				local entry = sessionItems[safeName]
				if not entry then
					entry = { count = 0, icon = icon }
					sessionItems[safeName] = entry
				end
				entry.count = entry.count + safeQty
				addedAny = true
			end
		end
	end

	if addedAny and ns.UpdatePill then
		ns.UpdatePill()
	end
end

function ns.GetSessionStats()
	return sessionTotal, sessionItems
end

function ns.ResetSessionStats()
	sessionTotal = 0
	wipe(sessionItems)
	if ns.UpdatePill then
		ns.UpdatePill()
	end
	print("|cff66ccffPureFish:|r Fishing session counter reset.")
end

local function FormatTimeShort(sec)
	if sec >= 60 then
		return math.ceil(sec / 60) .. "m"
	end
	return sec .. "s"
end

-- Shared tooltip builder for Addon Compartment & Minimap Button
function ns.PopulateStatusTooltip(tooltip, includeDragHint)
	tooltip:SetText("PureFish", 1, 0.82, 0)

	local poleText = ns.IsPoleEquipped() and "|cff55ff55Equipped|r" or "|cffaaaaaaNot Equipped|r"
	tooltip:AddLine("Fishing Pole: " .. poleText, 1, 1, 1)

	local rank, maxRank, mod = ns.GetFishingSkillInfo()
	if rank then
		local skillStr = (mod and mod > 0)
			and string.format("%d |cff55ff55(+%d)|r / %d", rank, mod, maxRank)
			or string.format("%d / %d", rank, maxRank)
		tooltip:AddLine("Skill: " .. skillStr, 1, 1, 1)
	end

	local lure = ns.GetLureStatus()
	if lure.hasEnchant and lure.timeLeftSec > 0 then
		tooltip:AddLine("Lure: |cff55ff55Active (" .. FormatTimeShort(lure.timeLeftSec) .. " left)|r", 1, 1, 1)
	elseif lure.bestLure then
		tooltip:AddLine("Lure: |cffffcc00None|r (" .. lure.bestLure.name .. " x" .. lure.bestLure.count .. " in bags)", 1, 1, 1)
	else
		tooltip:AddLine("Lure: |cffaaaaaaNone in bags|r", 1, 1, 1)
	end

	tooltip:AddLine("Session Catches: |cffffff00" .. tostring(sessionTotal) .. "|r", 1, 1, 1)
	tooltip:AddLine(" ", 1, 1, 1)
	tooltip:AddLine("Left-Click: Toggle Fishing Pole", 0.8, 0.8, 0.8)
	tooltip:AddLine("Right-Click: Open Settings", 0.8, 0.8, 0.8)
	if includeDragHint then
		tooltip:AddLine("Drag: Move Button", 0.65, 0.85, 1.0)
	end
end

local function GetPillTooltipAnchor()
	if pillFrame then
		local _, cy = pillFrame:GetCenter()
		local h = UIParent and UIParent:GetHeight()
		cy = ns.SafeNumber(cy)
		h = ns.SafeNumber(h)
		if cy and h and cy > (h * 0.5) then
			return "ANCHOR_BOTTOM"
		end
	end
	return "ANCHOR_TOP"
end

local function PositionPill()
	if not pillFrame then
		return
	end
	local db = ns.GetDB and ns.GetDB()
	local pos = db and db.pillPos
	pillFrame:ClearAllPoints()
	if type(pos) == "table" and pos.point and pos.x and pos.y then
		pillFrame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
	else
		pillFrame:SetPoint("TOP", UIParent, "TOP", 0, -24)
	end
end

function ns.ResetPillPosition()
	local db = ns.GetDB and ns.GetDB()
	if db then
		db.pillPos = nil
	end
	PositionPill()
	print("|cff66ccffPureFish:|r Fishing pill position reset to default.")
end

local function UpdatePillContents()
	if not pillFrame then
		return
	end

	-- Lure button
	local lure = ns.GetLureStatus()
	if lure.hasEnchant and lure.timeLeftSec > 0 then
		lureIcon:SetTexture((lure.bestLure and lure.bestLure.icon) or "Interface\\Icons\\INV_Misc_Orb_03")
		lureIcon:SetDesaturated(false)
		lureTimerFS:SetText(FormatTimeShort(lure.timeLeftSec))
		if lure.timeLeftSec <= 30 then
			lureTimerFS:SetTextColor(1.0, 0.45, 0.25)
			lureGlow:Show()
		else
			lureTimerFS:SetTextColor(0.35, 1.0, 0.35)
			lureGlow:Hide()
		end
		lureCountFS:SetText("")
	elseif lure.bestLure then
		lureIcon:SetTexture(lure.bestLure.icon)
		lureIcon:SetDesaturated(false)
		lureTimerFS:SetText("")
		lureCountFS:SetText(tostring(lure.bestLure.count))
		lureGlow:Show()
	else
		lureIcon:SetTexture("Interface\\Icons\\INV_Misc_Orb_03")
		lureIcon:SetDesaturated(true)
		lureTimerFS:SetText("")
		lureCountFS:SetText("")
		lureGlow:Hide()
	end

	-- Centered status text (Skill | Catches)
	local rank, maxRank, mod = ns.GetFishingSkillInfo()
	local skillText
	if rank then
		if mod and mod > 0 then
			skillText = string.format("|cffffd100%d|r|cff55ff55+%d|r/%d", rank, mod, maxRank)
		else
			skillText = string.format("|cffffd100%d|r/%d", rank, maxRank)
		end
	else
		skillText = "|cffffd100Fishing|r"
	end
	statusFS:SetText(string.format("%s  |cff666666|||r  |cffffffff%d|r caught", skillText, sessionTotal))

	if swapIcon and ns.GetSavedWeaponIcon then
		swapIcon:SetTexture(ns.GetSavedWeaponIcon())
	end
end

local function StartTicker()
	if not updateTicker then
		updateTicker = C_Timer.NewTicker(1.0, function()
			if pillFrame and pillFrame:IsShown() then
				UpdatePillContents()
			end
		end)
	end
end

local function StopTicker()
	if updateTicker then
		updateTicker:Cancel()
		updateTicker = nil
	end
end

function ns.UpdatePill()
	if not pillFrame then
		return
	end
	local db = ns.GetDB and ns.GetDB()
	local wantShow = db and db.showFishingPill and ns.IsPoleEquipped() and not InCombatLockdown()
		and not ns.SafeBool(UnitAffectingCombat("player"))

	if wantShow then
		UpdatePillContents()
		if not InCombatLockdown() then
			pillFrame:SetAlpha(1)
			pillFrame:Show()
		else
			pillFrame:SetAlpha(1)
		end
		StartTicker()
	else
		StopTicker()
		if not InCombatLockdown() then
			pillFrame:Hide()
		else
			pillFrame:SetAlpha(0)
		end
	end
end

function ns.InitPill()
	if pillFrame then
		return
	end

	local f = CreateFrame("Frame", "PureFishPill", UIParent, "BackdropTemplate")
	f:SetSize(242, 34)
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = false,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	f:SetBackdropColor(0.06, 0.07, 0.09, 0.65)
	f:SetBackdropBorderColor(0.55, 0.48, 0.30, 0.85)

	f:SetScript("OnDragStart", function(self)
		local db = ns.GetDB and ns.GetDB()
		if db and db.lockFishingPill then
			return
		end
		if not InCombatLockdown() then
			self:StartMoving()
		end
	end)

	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint(1)
		local db = ns.GetDB and ns.GetDB()
		if db and point then
			db.pillPos = {
				point = point,
				relPoint = relPoint,
				x = math.floor((x or 0) + 0.5),
				y = math.floor((y or 0) + 0.5),
			}
		end
	end)

	f:SetScript("OnMouseUp", function(_, button)
		if button == "RightButton" then
			ns.ResetSessionStats()
		end
	end)

	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, GetPillTooltipAnchor())
		GameTooltip:SetText("PureFish Session", 1, 0.82, 0)
		if sessionTotal > 0 then
			local list = {}
			for name, entry in pairs(sessionItems) do
				list[#list + 1] = { name = name, count = entry.count }
			end
			table.sort(list, function(a, b)
				if a.count ~= b.count then
					return a.count > b.count
				end
				return a.name < b.name
			end)
			for _, item in ipairs(list) do
				GameTooltip:AddDoubleLine(item.name, "x" .. tostring(item.count), 1, 1, 1, 1, 0.82, 0)
			end
		else
			GameTooltip:AddLine("No catches yet this session.", 0.75, 0.75, 0.75)
		end
		GameTooltip:AddLine(" ", 1, 1, 1)
		local db = ns.GetDB and ns.GetDB()
		if not db or not db.lockFishingPill then
			GameTooltip:AddLine("Drag: Move Pill", 0.65, 0.85, 1.0)
		end
		GameTooltip:AddLine("Right-Click: Reset Session Counter", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)

	f:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- Rounded minimalistic border matching the pill's exact UI-Tooltip-Border style
	local function StyleMinimalIconButton(btn, iconTex)
		iconTex:ClearAllPoints()
		iconTex:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
		iconTex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
		iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local b = CreateFrame("Frame", nil, btn, "BackdropTemplate")
		b:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
		b:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
		b:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 10,
		})
		b:SetBackdropBorderColor(0.55, 0.48, 0.30, 0.85)
	end

	-- 1. Clickable Lure Button (SecureActionButtonTemplate)
	lureBtn = CreateFrame("Button", "PureFishPillLureButton", f, "SecureActionButtonTemplate")
	lureBtn:SetSize(22, 22)
	lureBtn:SetPoint("LEFT", f, "LEFT", 7, 0)
	lureBtn:RegisterForClicks("AnyUp", "AnyDown")

	lureIcon = lureBtn:CreateTexture(nil, "ARTWORK")
	StyleMinimalIconButton(lureBtn, lureIcon)

	lureGlow = lureBtn:CreateTexture(nil, "OVERLAY")
	lureGlow:SetPoint("TOPLEFT", lureBtn, "TOPLEFT", -2, 2)
	lureGlow:SetPoint("BOTTOMRIGHT", lureBtn, "BOTTOMRIGHT", 2, -2)
	lureGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	lureGlow:SetBlendMode("ADD")
	lureGlow:SetVertexColor(1.0, 0.82, 0.2, 0.9)
	lureGlow:Hide()

	lureCountFS = lureBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	lureCountFS:SetPoint("BOTTOMRIGHT", lureBtn, "BOTTOMRIGHT", 1, -1)

	lureTimerFS = lureBtn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	lureTimerFS:SetPoint("CENTER", lureBtn, "CENTER", 0, 0)

	lureBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, GetPillTooltipAnchor())
		local lure = ns.GetLureStatus()
		if lure.hasEnchant and lure.timeLeftSec > 0 then
			GameTooltip:SetText("Fishing Lure Active", 0.35, 1.0, 0.35)
			GameTooltip:AddLine("Remaining: " .. FormatTimeShort(lure.timeLeftSec), 1, 1, 1)
			if lure.bestLure then
				GameTooltip:AddLine("Click to refresh with " .. lure.bestLure.name .. " (x" .. lure.bestLure.count .. ")", 0.8, 0.8, 0.8)
			end
		elseif lure.bestLure then
			GameTooltip:SetText("Apply " .. lure.bestLure.name, 1, 0.82, 0)
			GameTooltip:AddLine("+" .. tostring(lure.bestLure.bonus) .. " Fishing (" .. tostring(lure.bestLure.count) .. " in bags)", 1, 1, 1)
			GameTooltip:AddLine("Left-Click to apply to your pole", 0.55, 1.0, 0.55)
		else
			GameTooltip:SetText("No Fishing Lure", 0.8, 0.8, 0.8)
			GameTooltip:AddLine("No fishing lures found in your bags.", 0.7, 0.7, 0.7)
		end
		GameTooltip:Show()
	end)
	lureBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	ns.RegisterPillLureButton(lureBtn)

	-- 2. Weapon Swap Button (right side)
	swapBtn = CreateFrame("Button", nil, f)
	swapBtn:SetSize(22, 22)
	swapBtn:SetPoint("RIGHT", f, "RIGHT", -7, 0)
	swapBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

	swapIcon = swapBtn:CreateTexture(nil, "ARTWORK")
	swapIcon:SetTexture(ns.GetSavedWeaponIcon and ns.GetSavedWeaponIcon() or "Interface\\Icons\\INV_Sword_04")
	StyleMinimalIconButton(swapBtn, swapIcon)

	swapBtn:SetScript("OnClick", function()
		ns.ToggleFishingPole()
	end)
	swapBtn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, GetPillTooltipAnchor())
		GameTooltip:SetText("Equip Saved Weapons", 1, 0.82, 0)
		GameTooltip:AddLine("Saved: " .. ns.GetSavedGearSummary(), 1, 1, 1, true)
		GameTooltip:AddLine("Left-Click to swap back to combat weapons", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	swapBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- 3. Centered Status Readout (Skill | Session Catches)
	statusFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusFS:SetPoint("LEFT", lureBtn, "RIGHT", 6, 0)
	statusFS:SetPoint("RIGHT", swapBtn, "LEFT", -6, 0)
	statusFS:SetJustifyH("CENTER")
	statusFS:SetWordWrap(false)

	pillFrame = f
	PositionPill()
	ns.UpdatePill()
end

-- Hide pill during combat, refresh on skill-up or combat end
local pillEvents = CreateFrame("Frame")
pillEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
pillEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
pillEvents:RegisterEvent("SKILL_LINES_CHANGED")
pillEvents:SetScript("OnEvent", function()
	ns.UpdatePill()
end)
