-- PureFish: Native Blizzard Settings UI (Options -> AddOns -> PureFish).
local _, ns = ...

local mainCategory
local refreshCallbacks = {}

local function RefreshUI()
	for _, fn in ipairs(refreshCallbacks) do
		fn()
	end
end
ns.RefreshUI = RefreshUI

local function AttachTooltip(widget, title, text)
	widget:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(title, 1, 0.82, 0)
		if text then
			GameTooltip:AddLine(text, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	widget:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function MakeButton(parent, text, width, height, onClick)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetSize(width or 110, height or 22)
	btn:SetText(text)
	local fs = btn:GetFontString()
	if fs then
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
		fs:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
		fs:SetJustifyH("CENTER")
		fs:SetWordWrap(false)
	end
	if onClick then
		btn:SetScript("OnClick", onClick)
	end
	return btn
end

StaticPopupDialogs["PUREFISH_CONFIRM_RESET"] = {
	text = "Reset all PureFish settings back to Default values?\n(Your saved character weapons are preserved.)",
	button1 = "Reset",
	button2 = "Cancel",
	OnAccept = function()
		if ns.ResetDefaults then
			ns.ResetDefaults()
			RefreshUI()
			if ns.OnEngineSettingsChanged then ns.OnEngineSettingsChanged() end
			if ns.UpdatePill then ns.UpdatePill() end
			if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
			if ns.UpdateCompartmentButton then ns.UpdateCompartmentButton() end
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function MakeCheckbox(parent, label, tip, getFn, setFn)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	if label and label ~= "" then
		local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
		fs:SetText(label)
		cb.label = fs
	end
	cb:SetScript("OnClick", function(self)
		local checked = self:GetChecked() and true or false
		setFn(checked)
		if ns.OnEngineSettingsChanged then ns.OnEngineSettingsChanged() end
		RefreshUI()
	end)
	if tip then
		AttachTooltip(cb, label or "Option", tip)
	end
	cb.Refresh = function(self)
		self:SetChecked(getFn() and true or false)
	end
	return cb
end

local function MakeSlider(parent, label, minVal, maxVal, step, formatFn, tip, getFn, setFn)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(560, 26)

	local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nameFS:SetPoint("LEFT", row, "LEFT", 0, 0)
	nameFS:SetWidth(230)
	nameFS:SetJustifyH("LEFT")
	nameFS:SetText(label)

	local slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(200, 16)
	slider:SetPoint("LEFT", nameFS, "RIGHT", 12, 0)
	slider:SetMinMaxValues(minVal, maxVal)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	slider:SetBackdrop({
		bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
		edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
		tile = true, tileSize = 8, edgeSize = 8,
		insets = { left = 3, right = 3, top = 6, bottom = 6 },
	})
	slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

	local valFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	valFS:SetPoint("LEFT", slider, "RIGHT", 12, 0)
	valFS:SetWidth(80)
	valFS:SetJustifyH("LEFT")

	local updating = false
	slider:SetScript("OnValueChanged", function(_, value)
		if updating then return end
		local snapped = math.floor((value / step) + 0.5) * step
		if snapped < minVal then snapped = minVal end
		if snapped > maxVal then snapped = maxVal end
		valFS:SetText(formatFn(snapped))
		setFn(snapped)
		if ns.OnEngineSettingsChanged then ns.OnEngineSettingsChanged() end
	end)

	if tip then
		AttachTooltip(slider, label, tip)
	end

	row.Refresh = function()
		updating = true
		local v = getFn()
		if v == nil then v = minVal end
		slider:SetValue(v)
		valFS:SetText(formatFn(v))
		updating = false
	end

	row.SetEnabled = function(_, enabled)
		slider:SetEnabled(enabled)
		if enabled then
			nameFS:SetTextColor(1, 1, 1)
			valFS:SetTextColor(1, 0.82, 0)
			slider:SetAlpha(1)
		else
			nameFS:SetTextColor(0.5, 0.5, 0.5)
			valFS:SetTextColor(0.5, 0.5, 0.5)
			slider:SetAlpha(0.5)
		end
	end

	return row
end

local function MakeSectionHeader(parent, text)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetText(text)
	return fs
end

--------------------------------------------------------------------------------
-- MAIN SETTINGS PAGE (PureFish)
--------------------------------------------------------------------------------
local function BuildGeneralPage()
	local canvas = CreateFrame("Frame")
	canvas:Hide()

	local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
	title:SetText("PureFish")

	local resetBtn = MakeButton(canvas, "Reset to Defaults", 130, 22, function()
		StaticPopup_Show("PUREFISH_CONFIRM_RESET")
	end)
	resetBtn:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -24, -14)
	AttachTooltip(resetBtn, "Reset to Defaults", "Resets all PureFish settings back to their default values.")

	local sub = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	sub:SetPoint("RIGHT", resetBtn, "LEFT", -12, 0)
	sub:SetJustifyH("LEFT")
	sub:SetText("Lightweight, zero-dependency fishing QoL addon for WoW Forever. Configure cast/reel keys, weapon auto-swap, crash-safe sound boost, and the minimal fishing pill.")
	sub:SetTextColor(0.75, 0.75, 0.75)

	local divider = canvas:CreateTexture(nil, "ARTWORK")
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -8)
	divider:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -24, -52)
	divider:SetColorTexture(0.35, 0.35, 0.35, 0.6)

	local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -8)
	scroll:SetPoint("BOTTOMRIGHT", canvas, "BOTTOMRIGHT", -32, 12)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(600, 1)
	scroll:SetScrollChild(content)

	local y = -6
	local widgets = {}

	local function Add(widget, height, indent)
		widget:SetPoint("TOPLEFT", content, "TOPLEFT", 4 + (indent or 0), y)
		y = y - (height or 26)
		widgets[#widgets + 1] = widget
		return widget
	end

	local function AddHeader(text)
		y = y - 6
		local fs = MakeSectionHeader(content, text)
		fs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
		y = y - 22
		return fs
	end

	-- Quick Actions Row
	local actionRow = CreateFrame("Frame", nil, content)
	actionRow:SetSize(560, 28)

	local togglePoleBtn = MakeButton(actionRow, "Toggle Pole", 115, 24, function()
		if ns.ToggleFishingPole then ns.ToggleFishingPole() end
	end)
	togglePoleBtn:SetPoint("LEFT", actionRow, "LEFT", 0, 0)
	AttachTooltip(togglePoleBtn, "Toggle Fishing Pole", "Swap between your fishing pole and your saved combat weapons. Also available via /purefish pole, Key Bindings, or Left-Clicking the Addon Compartment / Minimap button.")

	local macroBtn = MakeButton(actionRow, "Create Pole Macro", 155, 24, function()
		if ns.CreatePoleMacro then ns.CreatePoleMacro() end
	end)
	macroBtn:SetPoint("LEFT", togglePoleBtn, "RIGHT", 8, 0)
	AttachTooltip(macroBtn, "Create Smart Fishing Macro", "Creates (or updates) the PureFishPole action-bar macro:\n- Left-Click: Equips your fishing pole, or casts Fishing when equipped (and reels in while channeling).\n- Right-Click: Swaps back to your saved combat weapons.")

	Add(actionRow, 32)

	------------------------------------------------------------------------
	-- Section 1: Cast & Reel With (Pole Equipped Only)
	------------------------------------------------------------------------
	AddHeader("Cast & Reel With (Active Only While Fishing Pole Equipped)")

local function FindControlsCategoryID()
	if Settings and Settings.GetCategory then
		local cat = Settings.GetCategory(CONTROLS_LABEL or "Controls")
		if cat and cat.GetID then
			return cat:GetID()
		end
	end
	if SettingsPanel and SettingsPanel.GetCategoryList then
		local list = SettingsPanel:GetCategoryList()
		local cats = list and list.allCategories
		if type(cats) == "table" then
			local targetName = (CONTROLS_LABEL or "Controls"):lower()
			for _, cat in ipairs(cats) do
				if cat and cat.GetName and cat.GetID then
					local name = ns.SafeString(cat:GetName())
					if name and name:lower() == targetName then
						return cat:GetID()
					end
				end
			end
		end
	end
	return Settings and Settings.KEYBINDINGS_CATEGORY_ID or nil
end

local function FlashSettingsRow(rowFrame)
	if not ns.IsUsableFrame(rowFrame) then
		return
	end
	local overlay = rowFrame.pureFishFlashOverlay
	if not overlay then
		overlay = CreateFrame("Frame", nil, rowFrame)
		overlay:SetAllPoints(rowFrame)
		overlay:SetFrameLevel(rowFrame:GetFrameLevel() + 10)
		local glow = overlay:CreateTexture(nil, "OVERLAY")
		glow:SetAllPoints(overlay)
		glow:SetColorTexture(1.0, 0.82, 0.2, 0.45)
		glow:SetBlendMode("ADD")
		overlay.glow = glow
		rowFrame.pureFishFlashOverlay = overlay
	end
	overlay:Show()
	local elapsed = 0
	local duration = 2.2
	overlay:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt
		if elapsed >= duration then
			self:Hide()
			self:SetScript("OnUpdate", nil)
			return
		end
		-- Smooth double pulse fading out cleanly
		local wave = math.abs(math.sin((elapsed / duration) * math.pi * 2))
		local fade = 1 - (elapsed / duration) * 0.35
		self.glow:SetAlpha(wave * fade * 0.65)
	end)
end

local function RowMatchesText(frame, targetLower)
	if not ns.IsUsableFrame(frame) then
		return false
	end
	local function CheckStr(s)
		local safe = ns.SafeString(s)
		return safe ~= nil and safe:lower():find(targetLower, 1, true) ~= nil
	end
	if frame.Text and frame.Text.GetText and CheckStr(frame.Text:GetText()) then
		return true
	end
	if frame.Label and frame.Label.GetText and CheckStr(frame.Label:GetText()) then
		return true
	end
	if frame.GetElementData then
		local ok, elem = pcall(frame.GetElementData, frame)
		if ok and type(elem) == "table" then
			if CheckStr(elem.name) then return true end
			if type(elem.data) == "table" and CheckStr(elem.data.name) then return true end
		end
	end
	if frame.GetRegions then
		for _, region in ipairs({ frame:GetRegions() }) do
			if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.GetText then
				if CheckStr(region:GetText()) then
					return true
				end
			end
		end
	end
	return false
end

local function OpenControlsAndFlashInteract()
	local catID = FindControlsCategoryID()
	if catID and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(catID)
	end
	C_Timer.After(0.12, function()
		pcall(function()
			local scrollBox = SettingsPanel and SettingsPanel.Container
				and SettingsPanel.Container.SettingsList
				and SettingsPanel.Container.SettingsList.ScrollBox
			if not scrollBox or not scrollBox.ForEachFrame then
				return
			end
			local targetLabel = (BINDING_NAME_INTERACTTARGET or "Interact With Target"):lower()
			scrollBox:ForEachFrame(function(frame)
				if RowMatchesText(frame, targetLabel) then
					FlashSettingsRow(frame)
				end
			end)
		end)
	end)
end

	local interactRow = CreateFrame("Frame", nil, content)
	interactRow:SetSize(560, 26)

	local interactCB = MakeCheckbox(interactRow, "Interact Key",
		"Press your game's Interact with Target key to cast Fishing when standing still and nothing is near to interact with. Press it again to reel in the bobber.",
		function() return ns.GetDB().castInteractKey end,
		function(v) ns.GetDB().castInteractKey = v end)
	interactCB:SetPoint("LEFT", interactRow, "LEFT", 0, 0)

	local interactBindBtn = MakeButton(interactRow, "Set Interact Key", 115, 20, OpenControlsAndFlashInteract)
	interactBindBtn:SetPoint("LEFT", interactCB, "LEFT", 240, 0)
	AttachTooltip(interactBindBtn, "Open Controls > Interact With Target", "Jumps straight to Gameplay > Controls and highlights Interact With Target so you can bind your key (e.g. F).")

	interactRow.Refresh = function()
		interactCB:Refresh()
		local k1 = GetBindingKey("INTERACTTARGET")
		if k1 and k1 ~= "" then
			interactCB.label:SetText("Interact Key |cff55ff55(" .. k1 .. ")|r")
			interactBindBtn:SetText("Change Key")
		else
			interactCB.label:SetText("Interact Key |cffffaa33(Not Bound)|r")
			interactBindBtn:SetText("Set Interact Key")
		end
	end
	Add(interactRow, 26)

	Add(MakeCheckbox(content, "Double Right-Click (Camera-Safe)",
		"Double right-click anywhere in the world to cast Fishing, and double right-click again to reel in. Single right-click and camera turning remain completely untouched.",
		function() return ns.GetDB().castDoubleRightClick end,
		function(v) ns.GetDB().castDoubleRightClick = v end))

	local dcSpeedSlider = Add(MakeSlider(content, "Double-Click Window", 0.10, 0.60, 0.05,
		function(v) return string.format("%.2fs", v) end,
		"Maximum time between two right-clicks to count as a double-click.",
		function() return ns.GetDB().doubleClickSpeed end,
		function(v) ns.GetDB().doubleClickSpeed = v end), 28, 22)

	local dcMountedCB = Add(MakeCheckbox(content, "Allow Double Right-Click while mounted",
		"Allows double right-click casting to dismount and cast Fishing.",
		function() return ns.GetDB().doubleClickMounted end,
		function(v) ns.GetDB().doubleClickMounted = v end), 26, 22)

	local dcRecastCB = Add(MakeCheckbox(content, "Double Right-Click recasts while fishing (modifier key reels)",
		"Off (default): Double right-click reels in, and Shift/Ctrl/Alt + double right-click recasts. On: inverted.",
		function() return ns.GetDB().recastOnDoubleClick end,
		function(v) ns.GetDB().recastOnDoubleClick = v end), 26, 22)

	local dcCtmCB = Add(MakeCheckbox(content, "Temporarily disable Click-to-Move while pole equipped",
		"Prevents WoW's Click-to-Move setting from walking on the first right-click while holding a fishing pole. Restores your Click-to-Move setting automatically when you swap back to weapons, enter combat, or reload (crash-safe).",
		function() return ns.GetDB().disableClickToMoveWithPole end,
		function(v) ns.GetDB().disableClickToMoveWithPole = v end), 26, 22)

	Add(MakeCheckbox(content, "Action-Bar Fishing Key Reels In",
		"When you press your normal Fishing spell or macro on a Blizzard action bar while already channeling, it reels in the bobber instead of recasting.",
		function() return ns.GetDB().actionBarKeyReelsIn end,
		function(v) ns.GetDB().actionBarKeyReelsIn = v end))

	Add(MakeCheckbox(content, "Single Right-Click (Overrides Double Right-Click)",
		"Cast and reel with a single right-click when standing still with a pole equipped. Includes anti-conflict guards for NPCs, objects, combat, and running with both mouse buttons.",
		function() return ns.GetDB().castSingleRightClick end,
		function(v) ns.GetDB().castSingleRightClick = v end))

	local missPauseSlider = Add(MakeSlider(content, "Pause After Missed Cast", 0, 30, 1,
		function(v) return v == 0 and "Off" or (tostring(v) .. "s") end,
		"After a failed cast away from water, Single Right-Click pauses for this long so you can interact normally.",
		function() return ns.GetDB().singleRightClickMissPause end,
		function(v) ns.GetDB().singleRightClickMissPause = v end), 28, 22)

	Add(MakeCheckbox(content, "Spacebar (Jump Key while standing still)",
		"Press Spacebar to cast when standing still with a pole equipped, and press again to reel in. Reverts to normal Jump the instant you start moving.",
		function() return ns.GetDB().castSpacebar end,
		function(v) ns.GetDB().castSpacebar = v end))

	Add(MakeCheckbox(content, "Middle Mouse Button (Mouse 3)",
		"Press Middle Mouse to cast and reel in while a fishing pole is equipped.",
		function() return ns.GetDB().castMouse3 end,
		function(v) ns.GetDB().castMouse3 = v end))

	Add(MakeCheckbox(content, "Mouse Button 4 (Side Button)",
		"Press Mouse Button 4 to cast and reel in while a fishing pole is equipped.",
		function() return ns.GetDB().castMouse4 end,
		function(v) ns.GetDB().castMouse4 = v end))

	Add(MakeCheckbox(content, "Mouse Button 5 (Side Button)",
		"Press Mouse Button 5 to cast and reel in while a fishing pole is equipped.",
		function() return ns.GetDB().castMouse5 end,
		function(v) ns.GetDB().castMouse5 = v end))

	Add(MakeCheckbox(content, "Show Interact Icon Above Bobber",
		"Displays WoW's native Soft-Target interact icon over your fishing bobber while casting, confirming that pressing your reel key will catch it. Restored safely when fishing ends.",
		function() return ns.GetDB().showBobberIcon end,
		function(v) ns.GetDB().showBobberIcon = v end))

	local bindNote = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bindNote:SetText("Tip: You can also bind dedicated keys in Options > Key Bindings > AddOns > PureFish (Cast/Reel, Toggle Pole, Apply Best Lure).")
	bindNote:SetTextColor(0.65, 0.80, 1.0)
	bindNote:SetWidth(550)
	bindNote:SetJustifyH("LEFT")
	Add(bindNote, 30, 4)

	------------------------------------------------------------------------
	-- Section 2: Gear & Combat
	------------------------------------------------------------------------
	AddHeader("Gear & Combat")

	Add(MakeCheckbox(content, "Auto-Equip Saved Weapons on Entering Combat",
		"Automatically swaps back to your saved combat Main Hand (and Off Hand) the moment you enter combat while holding a fishing pole.",
		function() return ns.GetDB().autoEquipWeaponsInCombat end,
		function(v) ns.GetDB().autoEquipWeaponsInCombat = v end))

	local savedGearFS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	savedGearFS:SetTextColor(0.8, 0.8, 0.8)
	savedGearFS:SetWidth(550)
	savedGearFS:SetJustifyH("LEFT")
	Add(savedGearFS, 22, 4)

	------------------------------------------------------------------------
	-- Section 3: Sound Boost While Fishing
	------------------------------------------------------------------------
	AddHeader("Sound Boost While Fishing (Crash-Safe)")

	Add(MakeCheckbox(content, "Boost Sound While Fishing",
		"Temporarily raises Master and Sound Effects volumes while fishing so the bobber splash stands out. Original volumes are saved to PureFishDB and restored after a 5s grace timer, on logout, or on reload after a crash.",
		function() return ns.GetDB().soundBoostEnabled end,
		function(v) ns.GetDB().soundBoostEnabled = v end))

	local masterSlider = Add(MakeSlider(content, "Master Volume (Raise-Only)", 0, 1, 0.05,
		function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
		"Target Master volume while fishing. Never lowers your volume if it is already higher.",
		function() return ns.GetDB().soundMasterVolume end,
		function(v) ns.GetDB().soundMasterVolume = v end), 28, 22)

	local sfxSlider = Add(MakeSlider(content, "Sound Effects Volume (Raise-Only)", 0, 1, 0.05,
		function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end,
		"Target Sound Effects volume while fishing (the bobber splash is a sound effect). Never lowers your volume if it is already higher.",
		function() return ns.GetDB().soundSfxVolume end,
		function(v) ns.GetDB().soundSfxVolume = v end), 28, 22)

	local muteMusicCB = Add(MakeCheckbox(content, "Mute Music, Ambience & Pet Sounds while fishing",
		"Temporarily mutes music, ambient noise, and pet sounds while fishing so only the splash is audible.",
		function() return ns.GetDB().soundMuteMusicAmbience end,
		function(v) ns.GetDB().soundMuteMusicAmbience = v end), 26, 22)

	local bgSoundCB = Add(MakeCheckbox(content, "Enable Sound in Background while fishing",
		"Allows you to hear the bobber splash even when WoW is in the background or alt-tabbed.",
		function() return ns.GetDB().soundEnableBackground end,
		function(v) ns.GetDB().soundEnableBackground = v end), 26, 22)

	------------------------------------------------------------------------
	-- Section 4: Quality of Life
	------------------------------------------------------------------------
	AddHeader("Quality of Life")

	Add(MakeCheckbox(content, "Auto-Loot Fishing Loot",
		"Automatically loots caught fish even if WoW's built-in Auto Loot is turned OFF. Never modifies your game Auto Loot setting, so it is 100% crash-safe.",
		function() return ns.GetDB().autoLootFishing end,
		function(v) ns.GetDB().autoLootFishing = v end))

	Add(MakeCheckbox(content, "Hide Fishing Cast Bar",
		"Hides your player cast bar while channeling Fishing. Normal spell casts remain unaffected.",
		function() return ns.GetDB().hideFishingCastBar end,
		function(v) ns.GetDB().hideFishingCastBar = v end))

	Add(MakeCheckbox(content, "Hide Non-Hostile Nameplates & Names While Fishing",
		"Temporarily hides friendly and neutral nameplates (works with Blizzard plates and Platynator) plus non-hostile NPC names while fishing. Hostile mobs, enemy players, and the bobber gear icon remain untouched. Crash-safe with instant restore on weapon swap or combat (and a 5s grace timer between casts).",
		function() return ns.GetDB().hideNonHostileNameplates end,
		function(v) ns.GetDB().hideNonHostileNameplates = v end))

	local friendlyNamesCB = Add(MakeCheckbox(content, "Also hide friendly player & pet names",
		"Also hides friendly players' overhead names, pets, guardians, and totems while fishing - ideal for crowded fishing spots. Restored automatically when fishing ends.",
		function() return ns.GetDB().hideFriendlyPlayerNames end,
		function(v) ns.GetDB().hideFriendlyPlayerNames = v end), 26, 22)

	------------------------------------------------------------------------
	-- Section 5: Minimal Fishing Pill
	------------------------------------------------------------------------
	AddHeader("Minimal Fishing Pill")

	Add(MakeCheckbox(content, "Show Minimal Fishing Pill (Pole Equipped Only)",
		"Displays a sleek, compact bar while a fishing pole is equipped showing a 1-click Lure button/timer, Fishing skill, session catches, and a Weapon Swap button. Auto-hides in combat.",
		function() return ns.GetDB().showFishingPill end,
		function(v)
			ns.GetDB().showFishingPill = v
			if ns.UpdatePill then ns.UpdatePill() end
		end))

	Add(MakeCheckbox(content, "Lock Fishing Pill Position",
		"Prevents accidentally dragging the Minimal Fishing Pill.",
		function() return ns.GetDB().lockFishingPill end,
		function(v) ns.GetDB().lockFishingPill = v end))

	local resetPillBtn = MakeButton(content, "Reset Pill Position", 190, 22, function()
		if ns.ResetPillPosition then ns.ResetPillPosition() end
	end)
	AttachTooltip(resetPillBtn, "Reset Pill Position", "Returns the Minimal Fishing Pill to its default position at the top-center of the screen.")
	Add(resetPillBtn, 32)

	------------------------------------------------------------------------
	-- Section 6: Minimap Button & Addon Compartment (matches PureGrid)
	------------------------------------------------------------------------
	AddHeader("Minimap Button & Addon Compartment")

	Add(MakeCheckbox(content, "Show Addon Compartment Button",
		"Shows PureFish inside Blizzard's Minimap Addon Compartment menu (Left-Click: Toggle Pole, Right-Click: Settings).",
		function() return ns.GetDB().showCompartmentButton end,
		function(v)
			ns.GetDB().showCompartmentButton = v
			if ns.UpdateCompartmentButton then ns.UpdateCompartmentButton() end
		end))

	Add(MakeCheckbox(content, "Show Minimap Button",
		"Shows a standalone draggable PureFish button around the Minimap edge (off by default).",
		function() return ns.GetDB().showMinimapButton end,
		function(v)
			ns.GetDB().showMinimapButton = v
			if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
		end))

	Add(MakeCheckbox(content, "Lock Minimap Button",
		"Prevents dragging the Minimap button.",
		function() return ns.GetDB().lockMinimapButton end,
		function(v) ns.GetDB().lockMinimapButton = v end))

	local resetMiniBtn = MakeButton(content, "Reset Minimap Position", 190, 22, function()
		if ns.ResetMinimapButtonPosition then ns.ResetMinimapButtonPosition() end
	end)
	AttachTooltip(resetMiniBtn, "Reset Minimap Position", "Resets the orbiting Minimap button back to its default angle.")
	Add(resetMiniBtn, 32)

	content:SetHeight(math.abs(y) + 24)

	local function RefreshPage()
		local db = ns.GetDB and ns.GetDB()
		if not db then return end
		for _, w in ipairs(widgets) do
			if w.Refresh then
				w:Refresh()
			end
		end

		-- Enable/disable dependent controls cleanly
		local dcActive = db.castDoubleRightClick and not db.castSingleRightClick
		dcSpeedSlider:SetEnabled(dcActive)
		dcMountedCB:SetEnabled(dcActive)
		dcRecastCB:SetEnabled(dcActive)
		dcCtmCB:SetEnabled(dcActive)
		if dcMountedCB.label then dcMountedCB.label:SetTextColor(dcActive and 1 or 0.5, dcActive and 1 or 0.5, dcActive and 1 or 0.5) end
		if dcRecastCB.label then dcRecastCB.label:SetTextColor(dcActive and 1 or 0.5, dcActive and 1 or 0.5, dcActive and 1 or 0.5) end
		if dcCtmCB.label then dcCtmCB.label:SetTextColor(dcActive and 1 or 0.5, dcActive and 1 or 0.5, dcActive and 1 or 0.5) end

		missPauseSlider:SetEnabled(db.castSingleRightClick and true or false)

		local snd = db.soundBoostEnabled and true or false
		masterSlider:SetEnabled(snd)
		sfxSlider:SetEnabled(snd)
		muteMusicCB:SetEnabled(snd)
		bgSoundCB:SetEnabled(snd)
		if muteMusicCB.label then muteMusicCB.label:SetTextColor(snd and 1 or 0.5, snd and 1 or 0.5, snd and 1 or 0.5) end
		if bgSoundCB.label then bgSoundCB.label:SetTextColor(snd and 1 or 0.5, snd and 1 or 0.5, snd and 1 or 0.5) end

		local npActive = db.hideNonHostileNameplates and true or false
		friendlyNamesCB:SetEnabled(npActive)
		if friendlyNamesCB.label then friendlyNamesCB.label:SetTextColor(npActive and 1 or 0.5, npActive and 1 or 0.5, npActive and 1 or 0.5) end

		savedGearFS:SetText("Saved Combat Weapons: |cffffd100" .. (ns.GetSavedGearSummary and ns.GetSavedGearSummary() or "None") .. "|r")
	end

	refreshCallbacks[#refreshCallbacks + 1] = RefreshPage
	canvas:SetScript("OnShow", RefreshPage)

	return canvas
end

function ns.InitUI()
	if mainCategory then
		return
	end
	local generalCanvas = BuildGeneralPage()
	mainCategory = Settings.RegisterCanvasLayoutCategory(generalCanvas, "PureFish")
	mainCategory.ID = mainCategory:GetID()
	Settings.RegisterAddOnCategory(mainCategory)
end

function ns.OpenSettings()
	if mainCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(mainCategory:GetID())
	end
end
