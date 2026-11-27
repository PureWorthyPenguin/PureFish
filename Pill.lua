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

-- Session catch tracking (persists across /reload and short breaks < 5 min)
local SESSION_EXPIRE_SECONDS = 300
local sessionTotal = 0
local sessionItems = {} -- [itemName] = { count = n, icon = texture }
local sessionStartWallTime = nil
local sessionStartSkill = nil
local sessionGetaways = 0
local sessionVendorCopper = 0
local sessionAHCopper = 0
local lastLootWindowAt = 0

local function GetSessionCharData()
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

local function SaveSessionToDB()
	local charData = GetSessionCharData()
	if not charData then
		return
	end
	if not sessionStartWallTime then
		charData.session = nil
		return
	end
	charData.session = {
		total = sessionTotal,
		items = sessionItems,
		startWallTime = sessionStartWallTime,
		lastActivityAt = time(),
		startSkill = sessionStartSkill,
		getaways = sessionGetaways,
		vendorCopper = sessionVendorCopper,
		ahCopper = sessionAHCopper,
	}
end

local function LoadSessionFromDB()
	local charData = GetSessionCharData()
	local s = charData and charData.session
	if type(s) ~= "table" or not s.startWallTime or not s.lastActivityAt then
		return
	end
	if (time() - s.lastActivityAt) > SESSION_EXPIRE_SECONDS then
		charData.session = nil
		return
	end
	sessionTotal = tonumber(s.total) or 0
	sessionItems = type(s.items) == "table" and s.items or {}
	sessionStartWallTime = tonumber(s.startWallTime)
	sessionStartSkill = tonumber(s.startSkill)
	sessionGetaways = tonumber(s.getaways) or 0
	sessionVendorCopper = tonumber(s.vendorCopper) or 0
	sessionAHCopper = tonumber(s.ahCopper) or 0
end

local function FormatCoins(copper)
	copper = math.floor(copper or 0)
	if copper <= 0 then
		return "0c"
	end
	local coinFn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
	if coinFn then
		local ok, str = pcall(coinFn, copper)
		if ok and type(str) == "string" and str ~= "" then
			return str
		end
	end
	local g = math.floor(copper / 10000)
	local s = math.floor((copper % 10000) / 100)
	local c = copper % 100
	if g > 0 then
		return string.format("|cffffd100%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", g, s, c)
	elseif s > 0 then
		return string.format("|cffc7c7cf%ds|r |cffeda55f%dc|r", s, c)
	end
	return string.format("|cffeda55f%dc|r", c)
end

local function GetAuctionatorPrice(itemLink)
	if not itemLink or not (_G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1) then
		return 0
	end
	local api = _G.Auctionator.API.v1
	if api.GetAuctionPriceByItemLink then
		local ok, price = pcall(api.GetAuctionPriceByItemLink, "PureFish", itemLink)
		local n = ok and ns.SafeNumber(price)
		if n and n > 0 then
			return n
		end
	end
	return 0
end

-- Lure expiring & getaway nudge state
local lureAlertArmed = false
local lastNudgeChatAt = -math.huge

local function EnsureSessionStarted()
	if not sessionStartWallTime then
		sessionStartWallTime = time()
	end
	if not sessionStartSkill and ns.GetFishingSkillInfo then
		local rank = ns.GetFishingSkillInfo()
		if rank then
			sessionStartSkill = rank
		end
	end
end

function ns.RecordFishingLoot(numLoot)
	local now = GetTime()
	-- Guard against duplicate LOOT_READY events for the same bobber
	if (now - lastLootWindowAt) < 0.4 then
		return
	end
	lastLootWindowAt = now
	EnsureSessionStarted()

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
				if GetLootSlotLink then
					local lOk, link = pcall(GetLootSlotLink, slot)
					local safeLink = lOk and ns.SafeString(link)
					if safeLink then
						local infoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
						if infoFn then
							local iOk, _, _, _, _, _, _, _, _, _, _, sellPrice = pcall(infoFn, safeLink)
							local copper = iOk and ns.SafeNumber(sellPrice) or 0
							if copper > 0 then
								sessionVendorCopper = sessionVendorCopper + (copper * safeQty)
							end
						end
						local ahPrice = GetAuctionatorPrice(safeLink)
						if ahPrice > 0 then
							sessionAHCopper = sessionAHCopper + (ahPrice * safeQty)
						end
					end
				end
				addedAny = true
			end
		end
	end

	if addedAny then
		SaveSessionToDB()
		if ns.UpdatePill then
			ns.UpdatePill()
		end
	end
end

function ns.RecordFishingGetaway()
	EnsureSessionStarted()
	sessionGetaways = sessionGetaways + 1
	SaveSessionToDB()
	if ns.UpdatePill then
		ns.UpdatePill()
	end
end

function ns.NudgeLureIfMissing(reason)
	local lure = ns.GetLureStatus and ns.GetLureStatus()
	if not lure or lure.hasEnchant or not lure.bestLure then
		return
	end
	if lureGlow then
		lureGlow:Show()
		lureGlow:SetAlpha(1)
	end
	local now = GetTime()
	if (now - lastNudgeChatAt) >= 60 then
		lastNudgeChatAt = now
		print("|cff66ccffPureFish:|r " .. (reason or "No lure active")
			.. " - click the Lure icon on the pill (or press your lure keybind) to apply |cffffd100"
			.. lure.bestLure.name .. "|r (+" .. tostring(lure.bestLure.bonus) .. ").")
	end
end

function ns.GetSessionStats()
	return sessionTotal, sessionItems
end

function ns.ResetSessionStats()
	sessionTotal = 0
	sessionStartWallTime = nil
	sessionStartSkill = nil
	sessionGetaways = 0
	sessionVendorCopper = 0
	sessionAHCopper = 0
	wipe(sessionItems)
	SaveSessionToDB()
	if ns.UpdatePill then
		ns.UpdatePill()
	end
	print("|cff66ccffPureFish:|r Fishing session counter reset.")
end

local function FormatDuration(sec)
	sec = math.max(0, math.floor(sec))
	if sec < 60 then
		return sec .. "s"
	end
	local m = math.floor(sec / 60)
	local h = math.floor(m / 60)
	if h > 0 then
		return string.format("%dh %dm", h, m % 60)
	end
	return string.format("%dm", m)
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

function ns.ApplyPillStyle()
	if not pillFrame then
		return
	end
	local db = ns.GetDB and ns.GetDB()
	local scale = (db and tonumber(db.pillScale)) or 1.0
	if scale < 0.75 then scale = 0.75 elseif scale > 1.50 then scale = 1.50 end
	local alpha = (db and tonumber(db.pillAlpha))
	if alpha == nil then alpha = 0.65 end
	if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
	pillFrame:SetScale(scale)
	pillFrame:SetBackdropColor(0.06, 0.07, 0.09, alpha)
end

local function UpdatePillContents()
	if not pillFrame then
		return
	end

	local db = ns.GetDB and ns.GetDB()

	-- Lure button + expiring chime
	local lure = ns.GetLureStatus()
	if lure.hasEnchant and lure.timeLeftSec > 0 then
		lureIcon:SetTexture((lure.bestLure and lure.bestLure.icon) or "Interface\\Icons\\INV_Misc_Orb_03")
		lureIcon:SetDesaturated(false)
		lureTimerFS:SetText(FormatTimeShort(lure.timeLeftSec))
		if lure.timeLeftSec > 30 then
			lureAlertArmed = true
			lureTimerFS:SetTextColor(0.35, 1.0, 0.35)
			lureGlow:Hide()
		else
			lureTimerFS:SetTextColor(1.0, 0.45, 0.25)
			lureGlow:Show()
			if lureAlertArmed and db and db.lureExpiringAlert then
				lureAlertArmed = false
				pcall(PlaySound, (SOUNDKIT and SOUNDKIT.UI_BNET_TOAST) or 18019, "Master")
			end
		end
		lureCountFS:SetText("")
	elseif lure.bestLure then
		lureAlertArmed = false
		lureIcon:SetTexture(lure.bestLure.icon)
		lureIcon:SetDesaturated(false)
		lureTimerFS:SetText("")
		lureCountFS:SetText(lure.bestLure.isHat and "" or tostring(lure.bestLure.count))
		lureGlow:Show()
	else
		lureAlertArmed = false
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

local PopulateSessionTooltip

local function StartTicker()
	if not updateTicker then
		updateTicker = C_Timer.NewTicker(1.0, function()
			if pillFrame and pillFrame:IsShown() then
				UpdatePillContents()
				if PopulateSessionTooltip and GameTooltip:IsShown() and GameTooltip:GetOwner() == pillFrame then
					PopulateSessionTooltip(pillFrame)
				end
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

	PopulateSessionTooltip = function(owner)
		GameTooltip:SetOwner(owner, GetPillTooltipAnchor())
		GameTooltip:SetText("PureFish Session", 1, 0.82, 0)
		if sessionStartWallTime then
			local elapsed = math.max(1, time() - sessionStartWallTime)
			local rateStr = ""
			if sessionTotal > 0 and elapsed >= 30 then
				local perHour = math.floor((sessionTotal * 3600 / elapsed) + 0.5)
				rateStr = string.format(" (%d/hr)", perHour)
			end
			GameTooltip:AddDoubleLine("Duration", FormatDuration(elapsed) .. rateStr, 0.8, 0.8, 0.8, 1, 1, 1)
		end
		if sessionStartSkill and ns.GetFishingSkillInfo then
			local curRank = ns.GetFishingSkillInfo()
			if curRank and curRank > sessionStartSkill then
				GameTooltip:AddDoubleLine("Skill Gained", "+" .. tostring(curRank - sessionStartSkill), 0.8, 0.8, 0.8, 0.35, 1.0, 0.35)
			end
		end
		if sessionGetaways > 0 then
			GameTooltip:AddDoubleLine("Escaped", tostring(sessionGetaways), 0.8, 0.8, 0.8, 1.0, 0.55, 0.35)
		end
		if sessionVendorCopper > 0 then
			GameTooltip:AddDoubleLine("Vendor Value", FormatCoins(sessionVendorCopper), 0.8, 0.8, 0.8, 1, 1, 1)
		end
		if sessionAHCopper > 0 then
			GameTooltip:AddDoubleLine("Auctionator Value", FormatCoins(sessionAHCopper), 0.8, 0.8, 0.8, 1, 1, 1)
		end
		if sessionTotal > 0 then
			GameTooltip:AddLine(" ", 1, 1, 1)
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
	end

	f:SetScript("OnEnter", function(self)
		PopulateSessionTooltip(self)
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
	LoadSessionFromDB()
	ns.ApplyPillStyle()
	PositionPill()
	ns.UpdatePill()
end

-- Hide pill during combat, refresh on skill-up or combat end, save timestamp on logout
local pillEvents = CreateFrame("Frame")
pillEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
pillEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
pillEvents:RegisterEvent("SKILL_LINES_CHANGED")
pillEvents:RegisterEvent("PLAYER_LOGOUT")
pillEvents:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGOUT" then
		SaveSessionToDB()
	else
		ns.UpdatePill()
	end
end)
