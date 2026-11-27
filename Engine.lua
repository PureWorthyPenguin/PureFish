-- PureFish: Core cast/reel engine (Interact key, Double/Single Right-Click, Spacebar, Mouse 3-5,
-- Action-Bar Fishing key reeling, dedicated keybind, crash-proof Auto-Loot, and Cast Bar hider).
local _, ns = ...

local WATCH_INTERVAL = 0.10 -- 10 Hz only while a fishing pole is equipped (0% CPU otherwise)
local DOUBLECLICK_MIN = 0.04
local CAST_DEBOUNCE = 0.50
local AFTER_COMBAT_PAUSE = 5.0
local STAND_STILL_REQUIRED = 1.0
local OBJECT_HOVER_REACH = 40
local BOTH_BUTTONS_WINDOW = 0.25

local castButton       -- SecureActionButtonTemplate for casting Fishing
local doubleClickOwner -- Dedicated override owner for Double Right-Click (auto-cleared in PostClick)
local watchOwner       -- Dedicated override owner for persistent pole-equipped overrides

local bound = {}       -- [key] = "cast" | "reel"
local fishBarKeys = {} -- [key] = true (keys bound to Fishing on Blizzard action bars)

local previousRightClickTime = 0
local lastDoubleClickCastTime = 0
local doubleClickInteractActive = false

local leftDownAt = -math.huge
local combatEndedAt = -math.huge
local channelEndedAt = -math.huge
local stillSince = nil
local isMoving = false
local wasFishing = false

-- Single Right-Click anti-conflict tracking
local objectTooltipAt = -math.huge
local objectTooltipX, objectTooltipY = 0, 0
local missCastAt = -math.huge
local chanStartAt = nil
local shortEndAt = nil

local EXTRA_MOUSE = {
	{ key = "BUTTON3", mouse = "MiddleButton", setting = "castMouse3" },
	{ key = "BUTTON4", mouse = "Button4",      setting = "castMouse4" },
	{ key = "BUTTON5", mouse = "Button5",      setting = "castMouse5" },
}

local BLIZZARD_BARS = {
	{ "ActionButton",             "ACTIONBUTTON" },
	{ "MultiBarBottomLeftButton", "MULTIACTIONBAR1BUTTON" },
	{ "MultiBarBottomRightButton","MULTIACTIONBAR2BUTTON" },
	{ "MultiBarRightButton",      "MULTIACTIONBAR3BUTTON" },
	{ "MultiBarLeftButton",       "MULTIACTIONBAR4BUTTON" },
	{ "MultiBar5Button",          "MULTIACTIONBAR5BUTTON" },
	{ "MultiBar6Button",          "MULTIACTIONBAR6BUTTON" },
	{ "MultiBar7Button",          "MULTIACTIONBAR7BUTTON" },
}

local function IsKeyHeld(key)
	if not IsKeyDown then
		return false
	end
	local ok, down = pcall(IsKeyDown, key)
	return ok and ns.SafeBool(down)
end

local function CanFishNow(allowMounted)
	if not ns.IsPoleEquipped() then
		return false
	end
	if InCombatLockdown() or ns.SafeBool(UnitAffectingCombat("player")) then
		return false
	end
	if ns.SafeBool(IsPlayerMoving()) or isMoving then
		return false
	end
	if ns.SafeBool(IsMounted()) and not allowMounted then
		return false
	end
	if (IsFlying and ns.SafeBool(IsFlying()))
		or ns.SafeBool(IsFalling())
		or ns.SafeBool(IsStealthed())
		or ns.SafeBool(IsSwimming())
		or ns.SafeBool(IsSubmerged())
		or ns.SafeBool(UnitIsDeadOrGhost("player"))
		or (UnitHasVehicleUI and ns.SafeBool(UnitHasVehicleUI("player")))
		or (UnitInVehicle and ns.SafeBool(UnitInVehicle("player")))
		or (HasFullControl and not ns.SafeBool(HasFullControl())) then
		return false
	end
	if GetNumLootItems() ~= 0 or (LootFrame and ns.SafeBool(LootFrame:IsShown())) then
		return false
	end
	return true
end

local function IsCastingAnySpell()
	local ok1, castName = pcall(UnitCastingInfo, "player")
	if ok1 and castName ~= nil then
		return true
	end
	local ok2, chanName = pcall(UnitChannelInfo, "player")
	if ok2 and chanName ~= nil then
		return true
	end
	return false
end

local function InteractTargetNear()
	if ns.SafeBool(UnitExists("softinteract")) then
		return true
	end
	if ns.SafeBool(UnitExists("target")) and CheckInteractDistance then
		local ok, near = pcall(CheckInteractDistance, "target", 3)
		return (not ok) or ns.SafeBool(near)
	end
	return false
end

local function MouseOnUnitOrObject()
	if ns.SafeBool(UnitExists("mouseover")) then
		return true
	end
	if GetTime() - objectTooltipAt > 20 then
		return false
	end
	local cx, cy = GetCursorPosition()
	cx = ns.SafeNumber(cx)
	cy = ns.SafeNumber(cy)
	if not cx or not cy then
		return false
	end
	return ((cx - objectTooltipX) ^ 2 + (cy - objectTooltipY) ^ 2) < (OBJECT_HOVER_REACH ^ 2)
end

-- Scan Blizzard action bars for keys bound to Fishing (spell or macro)
local function ScanActionBarFishingKeys()
	wipe(fishBarKeys)
	local fishNameLower = ns.GetFishingSpellName():lower()
	local ok = pcall(function()
		for _, bar in ipairs(BLIZZARD_BARS) do
			for i = 1, 12 do
				local btn = _G[bar[1] .. i]
				local slot = btn and (btn.action or (btn.CalculateAction and btn:CalculateAction()))
				if type(slot) == "number" then
					local kind, id, subType = GetActionInfo(slot)
					local isFish = false
					if kind == "spell" then
						isFish = ns.IsFishingSpell(id)
					elseif kind == "macro" then
						-- Modern WoW / Forever: GetActionInfo may return resolved spellID in `id`
						-- and the macro's name via GetActionText(slot) rather than macro index.
						if subType == "spell" and ns.IsFishingSpell(id) then
							isFish = true
						end
						local actionText = GetActionText and ns.SafeString(GetActionText(slot))
						if not isFish and actionText == "PureFishPole" then
							isFish = true
						end
						local macroIdx = (actionText and GetMacroIndexByName and GetMacroIndexByName(actionText)) or id
						if not isFish and macroIdx and macroIdx > 0 then
							if GetMacroSpell then
								local mSpell = GetMacroSpell(macroIdx)
								isFish = mSpell ~= nil and ns.IsFishingSpell(mSpell)
							end
							if not isFish and GetMacroInfo then
								local mName, _, mBody = GetMacroInfo(macroIdx)
								local safeName = ns.SafeString(mName)
								local safeBody = ns.SafeString(mBody)
								if safeName == "PureFishPole"
									or (safeBody and safeBody:lower():find(fishNameLower, 1, true)) then
									isFish = true
								end
							end
						end
					end
					if isFish then
						local command = (btn.commandName and btn.commandName ~= "") and btn.commandName or (bar[2] .. i)
						local k1, k2 = GetBindingKey(command)
						if not k1 and command ~= (bar[2] .. i) then
							k1, k2 = GetBindingKey(bar[2] .. i)
						end
						if k1 and k1 ~= "BUTTON2" then fishBarKeys[k1] = true end
						if k2 and k2 ~= "BUTTON2" then fishBarKeys[k2] = true end
					end
				end
			end
		end
	end)
	if not ok then
		wipe(fishBarKeys)
	end
end

local function SetWatchOverride(key, mode)
	mode = mode or false
	if not watchOwner or not castButton or InCombatLockdown() then
		return
	end
	if (bound[key] or false) == mode then
		return
	end
	bound[key] = mode or nil
	if mode == "cast" then
		SetOverrideBindingClick(watchOwner, true, key, castButton:GetName())
	elseif mode == "reel" then
		SetOverrideBinding(watchOwner, true, key, "INTERACTTARGET")
	else
		SetOverrideBinding(watchOwner, true, key, nil)
	end
end

local function ClearAllWatchOverrides()
	if InCombatLockdown() or not watchOwner then
		return
	end
	ClearOverrideBindings(watchOwner)
	wipe(bound)
end

local function ClearDoubleClickOverrides()
	if InCombatLockdown() or not doubleClickOwner then
		return
	end
	doubleClickInteractActive = false
	ClearOverrideBindings(doubleClickOwner)
end

--------------------------------------------------------------------------------
-- Conditional Pole-Equipped Watcher (0% idle CPU when no pole is equipped)
--------------------------------------------------------------------------------
local watchFrame = CreateFrame("Frame")
local watchElapsed = 0

local function ShouldWatchRun()
	return castButton ~= nil and (ns.IsPoleEquipped() or next(bound) ~= nil or ns.IsChannelingFishing())
end

local function UpdateWatchLoopState()
	if ShouldWatchRun() then
		if not watchFrame:GetScript("OnUpdate") then
			watchElapsed = WATCH_INTERVAL
			watchFrame:SetScript("OnUpdate", function(_, elapsed)
				watchElapsed = watchElapsed + elapsed
				if watchElapsed < WATCH_INTERVAL then
					return
				end
				watchElapsed = 0
				ns.EvaluateWatchBindings()
			end)
		end
	else
		watchFrame:SetScript("OnUpdate", nil)
	end
end

function ns.EvaluateWatchBindings()
	if InCombatLockdown() then
		return
	end
	if not ShouldWatchRun() then
		ClearAllWatchOverrides()
		UpdateWatchLoopState()
		return
	end

	local db = ns.GetDB and ns.GetDB()
	if not db then
		return
	end

	local now = GetTime()
	local pole = ns.IsPoleEquipped()
	local fishing = ns.IsChannelingFishing()

	if ns.SafeBool(IsPlayerMoving()) or isMoving then
		stillSince = nil
	elseif not stillSince then
		stillSince = now
	end

	local settled = stillSince ~= nil and (now - stillSince >= STAND_STILL_REQUIRED)
	local baseReady = pole and not fishing and not IsCastingAnySpell() and CanFishNow(false)
		and (now - channelEndedAt >= 0.35)

	local desired = {} -- [key] = "cast" | "reel"

	-- 1. Dedicated Keybind (PUREFISH_CAST): reel while channeling
	if fishing then
		local k1, k2 = GetBindingKey("PUREFISH_CAST")
		if k1 then desired[k1] = "reel" end
		if k2 then desired[k2] = "reel" end
	end

	-- 2. Action-Bar Fishing Key Reels In
	if fishing and db.actionBarKeyReelsIn then
		if not wasFishing then
			ScanActionBarFishingKeys()
		end
		for key in pairs(fishBarKeys) do
			desired[key] = "reel"
		end
	end
	wasFishing = fishing

	-- 3. Interact Key (e.g. F): cast when idle & nothing near; native INTERACTTARGET reels while channeling
	if db.castInteractKey and baseReady and not InteractTargetNear() then
		local k1, k2 = GetBindingKey("INTERACTTARGET")
		if k1 and k1 ~= "BUTTON2" and not desired[k1] then desired[k1] = "cast" end
		if k2 and k2 ~= "BUTTON2" and not desired[k2] then desired[k2] = "cast" end
	end

	-- 4. Spacebar (JUMP): cast when standing still, reel while channeling, Jump while moving
	if db.castSpacebar then
		local k1, k2 = GetBindingKey("JUMP")
		local spaceMode = (fishing and "reel") or (baseReady and settled and "cast") or nil
		if spaceMode then
			if k1 and not desired[k1] then desired[k1] = spaceMode end
			if k2 and not desired[k2] then desired[k2] = spaceMode end
		end
	end

	-- 5. Extra Mouse Buttons (Middle / Mouse 4 / Mouse 5)
	local mouseFree = not MouseOnUnitOrObject()
	for _, m in ipairs(EXTRA_MOUSE) do
		if db[m.setting] and not IsMouseButtonDown(m.mouse) then
			local mode = (fishing and "reel") or (baseReady and mouseFree and "cast") or nil
			if mode and not desired[m.key] then
				desired[m.key] = mode
			end
		end
	end

	-- 6. Single Right-Click (optional, OFF by default)
	if db.castSingleRightClick and not IsMouseButtonDown("RightButton") then
		local leftFree = not IsMouseButtonDown("LeftButton") and (now - leftDownAt >= BOTH_BUTTONS_WINDOW)
		local missPause = tonumber(db.singleRightClickMissPause) or 15
		local singleReady = baseReady and settled and leftFree and mouseFree
			and (now - combatEndedAt >= AFTER_COMBAT_PAUSE)
			and (now - missCastAt >= missPause)
		local singleReel = fishing and leftFree and not ns.SafeBool(UnitExists("mouseover"))
		if singleReady then
			desired["BUTTON2"] = "cast"
		elseif singleReel then
			desired["BUTTON2"] = "reel"
		end
	end

	-- Apply desired overrides (never swap a key that is currently held down)
	for key, mode in pairs(desired) do
		if not IsKeyHeld(key) then
			SetWatchOverride(key, mode)
		end
	end

	-- Clear any previously bound keys no longer desired
	for key in pairs(bound) do
		if not desired[key] and not IsKeyHeld(key) then
			SetWatchOverride(key, false)
		end
	end
end

function ns.OnPoleStateChanged(equipped)
	if equipped then
		missCastAt = -math.huge
		stillSince = GetTime() - STAND_STILL_REQUIRED -- just equipped pole: ready immediately
		if ns.UpdateClickToMoveGuard then
			ns.UpdateClickToMoveGuard()
		end
	else
		ClearAllWatchOverrides()
		ClearDoubleClickOverrides()
		-- Done fishing: immediately restore nameplates, sound, soft-target, and Click-to-Move
		if ns.RestoreAllCVars then
			ns.RestoreAllCVars()
		end
	end
	if ns.UpdateFindFishTracking then
		ns.UpdateFindFishTracking(equipped)
	end
	if ns.UpdateCastButtonAction then
		ns.UpdateCastButtonAction()
	end
	UpdateWatchLoopState()
end

--------------------------------------------------------------------------------
-- Dedicated Keybind Callback (PUREFISH_CAST)
--------------------------------------------------------------------------------
function ns.CastOrReelFromKeybind()
	if InCombatLockdown() or not ns.IsPoleEquipped() or ns.IsChannelingFishing() then
		return
	end
	if not CanFishNow(false) then
		return
	end
	if ns.UpdateCastButtonAction then
		ns.UpdateCastButtonAction()
	end
	local k1, k2 = GetBindingKey("PUREFISH_CAST")
	if k1 then
		SetOverrideBindingClick(doubleClickOwner, true, k1, castButton:GetName())
	end
	if k2 then
		SetOverrideBindingClick(doubleClickOwner, true, k2, castButton:GetName())
	end
	C_Timer.After(0.15, function()
		if not InCombatLockdown() and not doubleClickInteractActive then
			ClearOverrideBindings(doubleClickOwner)
		end
	end)
end

--------------------------------------------------------------------------------
-- Hide Fishing Cast Bar Hook
--------------------------------------------------------------------------------
local hookedCastBars = {}

local function UpdateFishingCastBar(bar)
	if not ns.IsUsableFrame(bar) then
		return
	end
	local db = ns.GetDB and ns.GetDB()
	if not db or not db.hideFishingCastBar then
		if bar.pureFishHidden then
			bar.pureFishHidden = nil
			if bar:IsShown() then
				bar:SetAlpha(1)
			end
		end
		return
	end
	if ns.IsChannelingFishing() then
		bar.pureFishHidden = true
		bar:SetAlpha(0)
	elseif bar.pureFishHidden and IsCastingAnySpell() then
		-- Another (non-Fishing) spell started casting: hand the bar back immediately
		bar.pureFishHidden = nil
		bar:SetAlpha(1)
	end
end

local function EnsureCastBarHooked()
	for _, frameName in ipairs({ "PlayerCastingBarFrame", "CastingBarFrame" }) do
		local bar = _G[frameName]
		if ns.IsUsableFrame(bar) and bar.HookScript and not hookedCastBars[bar] then
			hookedCastBars[bar] = true
			bar:HookScript("OnEvent", UpdateFishingCastBar)
			bar:HookScript("OnShow", UpdateFishingCastBar)
			bar:HookScript("OnHide", function(self)
				self.pureFishHidden = nil
			end)
			hooksecurefunc(bar, "SetAlpha", function(self, a)
				if self.pureFishHidden and type(a) == "number" and a > 0 then
					local db = ns.GetDB and ns.GetDB()
					if db and db.hideFishingCastBar and not (IsCastingAnySpell() and not ns.IsChannelingFishing()) then
						self:SetAlpha(0)
					else
						self.pureFishHidden = nil
					end
				end
			end)
			UpdateFishingCastBar(bar)
		end
	end
end

function ns.RefreshCastBarVisibility()
	for bar in pairs(hookedCastBars) do
		UpdateFishingCastBar(bar)
	end
end

--------------------------------------------------------------------------------
-- Initialization & Event Dispatcher
--------------------------------------------------------------------------------
function ns.UpdateCastButtonAction()
	if not castButton or InCombatLockdown() then
		return
	end
	local db = ns.GetDB and ns.GetDB()
	local lureMacro = ns.GetBestLureMacroText and ns.GetBestLureMacroText()
	local lureStatus = ns.GetLureStatus and ns.GetLureStatus()
	local wantLure = db and db.castAppliesMissingLure
		and ns.IsPoleEquipped and ns.IsPoleEquipped()
		and lureStatus and not lureStatus.hasEnchant
		and lureMacro ~= nil
	if wantLure then
		castButton:SetAttribute("type", "macro")
		castButton:SetAttribute("macrotext", lureMacro)
		castButton:SetAttribute("spell", nil)
	else
		castButton:SetAttribute("type", "spell")
		castButton:SetAttribute("spell", ns.GetFishingSpellName())
		castButton:SetAttribute("macrotext", nil)
	end
end

local function UpdateSecureButtonKeyDown()
	if castButton and not InCombatLockdown() then
		castButton:SetAttribute("useKeyDowns", GetCVarBool("ActionButtonUseKeyDown"))
		ns.UpdateCastButtonAction()
	end
end

function ns.InitEngine()
	if not castButton then
		local btn = CreateFrame("Button", "PureFishCastButton", UIParent, "SecureActionButtonTemplate")
		btn:RegisterForClicks("AnyDown", "AnyUp")
		btn:SetAttribute("type", "spell")
		btn:SetAttribute("spell", ns.GetFishingSpellName())
		btn:SetScript("PreClick", function(self)
			if not InCombatLockdown() then
				local both = IsMouseButtonDown("LeftButton") or (GetTime() - leftDownAt < BOTH_BUTTONS_WINDOW)
				if both then
					self:SetAttribute("type", nil)
				else
					ns.UpdateCastButtonAction()
				end
			end
		end)
		btn:SetScript("PostClick", function(self, _, down)
			if self.fromDoubleClick then
				MouselookStart()
				if not down then
					MouselookStop()
					self.fromDoubleClick = false
				end
			end
		end)
		SecureHandlerWrapScript(btn, "PostClick", btn, [[
			local useKeyDowns = self:GetAttribute("useKeyDowns")
			if useKeyDowns then
				if down then
					self:ClearBindings()
				end
			else
				if not down then
					self:ClearBindings()
				end
			end
		]])
		castButton = btn
		doubleClickOwner = btn
		watchOwner = CreateFrame("Frame", "PureFishWatchOwner", UIParent)
		UpdateSecureButtonKeyDown()
	end

	EnsureCastBarHooked()
	if ns.UpdateClickToMoveGuard then
		ns.UpdateClickToMoveGuard()
	end
	UpdateWatchLoopState()
end

function ns.OnEngineSettingsChanged()
	if ns.OnCVarSettingsChanged then
		ns.OnCVarSettingsChanged()
	end
	ns.RefreshCastBarVisibility()
	if not InCombatLockdown() then
		ns.UpdateCastButtonAction()
		ns.EvaluateWatchBindings()
	end
	UpdateWatchLoopState()
end

function ns.PrintDebug()
	ScanActionBarFishingKeys()
	local barList = {}
	for k in pairs(fishBarKeys) do barList[#barList + 1] = k end
	table.sort(barList)
	local boundList = {}
	for k, m in pairs(bound) do boundList[#boundList + 1] = k .. "=" .. tostring(m) end
	table.sort(boundList)
	local db = ns.GetDB and ns.GetDB()
	print("|cff66ccffPureFish Debug:|r pole=" .. tostring(ns.IsPoleEquipped())
		.. " fishing=" .. tostring(ns.IsChannelingFishing())
		.. " barReelSetting=" .. tostring(db and db.actionBarKeyReelsIn))
	print("  Action-bar Fishing keys found: " .. (#barList > 0 and table.concat(barList, ", ") or "NONE"))
	print("  Active overrides: " .. (#boundList > 0 and table.concat(boundList, ", ") or "NONE"))
end

-- World tooltip watcher for Single Right-Click object guard
GameTooltip:HookScript("OnShow", function(self)
	local owner = self:GetOwner()
	if (owner == nil or owner == UIParent or owner == WorldFrame) and not ns.IsChannelingFishing()
		and (GetTime() - channelEndedAt > 3) then
		objectTooltipAt = GetTime()
		local cx, cy = GetCursorPosition()
		objectTooltipX = ns.SafeNumber(cx) or 0
		objectTooltipY = ns.SafeNumber(cy) or 0
	end
end)

local lastGetawayAt = 0

local function HandleFishingFeedbackText(msg, isErrorEvent)
	if not msg then
		return
	end
	local lower = msg:lower()
	local now = GetTime()
	if lower:find("fish got away", 1, true) then
		if (now - lastGetawayAt) >= 0.5 then
			lastGetawayAt = now
			if ns.RecordFishingGetaway then
				ns.RecordFishingGetaway()
			end
			if ns.NudgeLureIfMissing then
				ns.NudgeLureIfMissing("Fish got away")
			end
		end
	elseif lower:find("skill", 1, true) and lower:find("high enough", 1, true) then
		if ns.NudgeLureIfMissing then
			ns.NudgeLureIfMissing("Skill too low for this water")
		end
	end
	if isErrorEvent then
		local justCast = (chanStartAt and (now - chanStartAt < 1.5)) or (shortEndAt and (now - shortEndAt < 1.0))
		if justCast or lower:find("fishable water", 1, true) then
			missCastAt = now
		end
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_STARTED_MOVING")
eventFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
eventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
eventFrame:RegisterEvent("GLOBAL_MOUSE_UP")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
eventFrame:RegisterEvent("UI_INFO_MESSAGE")
eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")

eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
	if event == "PLAYER_REGEN_DISABLED" then
		ClearAllWatchOverrides()
		ClearDoubleClickOverrides()
	elseif event == "PLAYER_REGEN_ENABLED" then
		combatEndedAt = GetTime()
		UpdateSecureButtonKeyDown()
		UpdateWatchLoopState()
	elseif event == "PLAYER_STARTED_MOVING" then
		isMoving = true
		stillSince = nil
	elseif event == "PLAYER_STOPPED_MOVING" then
		isMoving = false
		stillSince = GetTime()
	elseif event == "CVAR_UPDATE" then
		if arg1 == "ActionButtonUseKeyDown" then
			UpdateSecureButtonKeyDown()
		end
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
		if ns.IsFishingSpell(arg3) or ns.IsChannelingFishing() then
			chanStartAt = GetTime()
			shortEndAt = nil
			EnsureCastBarHooked()
			ns.RefreshCastBarVisibility()
			if ns.OnFishingCVarsStart then
				ns.OnFishingCVarsStart()
			end
			if not InCombatLockdown() then
				ScanActionBarFishingKeys()
				ns.EvaluateWatchBindings()
			end
			UpdateWatchLoopState()
		end
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if ns.IsFishingSpell(arg3) then
			local now = GetTime()
			channelEndedAt = now
			shortEndAt = (chanStartAt and (now - chanStartAt < 1.5)) and now or nil
			chanStartAt = nil
			ns.RefreshCastBarVisibility()
			if ns.OnFishingCVarsStop then
				ns.OnFishingCVarsStop()
			end
			if not InCombatLockdown() then
				ns.EvaluateWatchBindings()
			end
			UpdateWatchLoopState()
		end
	elseif event == "UNIT_SPELLCAST_FAILED" then
		if ns.IsFishingSpell(arg3) then
			missCastAt = GetTime()
		end
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_INVENTORY_CHANGED" then
		if ns.IsPoleEquipped() then
			ns.UpdateCastButtonAction()
		end
	elseif event == "UI_ERROR_MESSAGE" or event == "UI_INFO_MESSAGE" then
		if ns.IsPoleEquipped() then
			local msg = ns.SafeString(type(arg2) == "string" and arg2 or arg1)
			HandleFishingFeedbackText(msg, event == "UI_ERROR_MESSAGE")
		end
	elseif event == "CHAT_MSG_SYSTEM" then
		if ns.IsPoleEquipped() then
			local msg = ns.SafeString(arg1)
			HandleFishingFeedbackText(msg, false)
		end
	elseif event == "LOOT_READY" then
		if IsFishingLoot and ns.SafeBool(IsFishingLoot()) then
			missCastAt = -math.huge
			local numLoot = GetNumLootItems()
			if numLoot and numLoot > 0 then
				if ns.RecordFishingLoot then
					ns.RecordFishingLoot(numLoot)
				end
				local db = ns.GetDB and ns.GetDB()
				if db and db.autoLootFishing then
					for slot = numLoot, 1, -1 do
						LootSlot(slot)
					end
				end
			end
		end
	elseif event == "GLOBAL_MOUSE_DOWN" then
		if arg1 == "LeftButton" then
			leftDownAt = GetTime()
			return
		end
		local db = ns.GetDB and ns.GetDB()
		if not db or not db.castDoubleRightClick or db.castSingleRightClick then
			return
		end
		if arg1 == "RightButton" and not IsMouseButtonDown("LeftButton") and not InCombatLockdown() then
			if GetNumLootItems() == 0 then
				local now = GetTime()
				local delta = now - previousRightClickTime
				local maxWindow = tonumber(db.doubleClickSpeed) or 0.25
				if (now - lastDoubleClickCastTime) >= CAST_DEBOUNCE
					and delta >= DOUBLECLICK_MIN and delta <= maxWindow then
					if ns.IsChannelingFishing() then
						local wantRecast = (db.recastOnDoubleClick and not IsModifierKeyDown())
							or (not db.recastOnDoubleClick and IsModifierKeyDown())
						if wantRecast and CanFishNow(db.doubleClickMounted) then
							castButton.fromDoubleClick = true
							SetOverrideBindingClick(doubleClickOwner, true, "BUTTON2", castButton:GetName())
							lastDoubleClickCastTime = now
						else
							doubleClickInteractActive = true
							SetOverrideBinding(doubleClickOwner, true, "BUTTON2", "INTERACTTARGET")
						end
					elseif CanFishNow(db.doubleClickMounted) then
						castButton.fromDoubleClick = true
						SetOverrideBindingClick(doubleClickOwner, true, "BUTTON2", castButton:GetName())
						lastDoubleClickCastTime = now
					end
					previousRightClickTime = 0
					return
				end
			end
			previousRightClickTime = GetTime()
		end
	elseif event == "GLOBAL_MOUSE_UP" then
		if doubleClickInteractActive and arg1 == "RightButton" and not InCombatLockdown() then
			ClearDoubleClickOverrides()
		end
	end
end)
