local addonName = "Lateral"
local frame = CreateFrame("Frame", "LateralTrackerFrame", UIParent)

local FRAME_WIDTH = 250
local FRAME_HEIGHT = 30
local FRAME_SPACING = 5
local UPDATE_INTERVAL = 0.05
local DEFAULT_FONT_SIZE = 16
local DEFAULT_POS_X = 0
local DEFAULT_POS_Y = -148

local SND_DURATIONS = {9, 12, 15, 18, 21}
local SND_RANKS = {5171, 6774}

local RUPTURE_DURATIONS = {8, 10, 12, 14, 16}
local RUPTURE_RANKS = {1943, 8639, 8640, 11273, 11274, 11275}

local ENVENOM_DURATIONS = {12, 16, 20, 24, 28}

local EXPOSE_ARMOR_DURATION = 30
local EXPOSE_ARMOR_RANKS = {8647, 8649, 8650, 11197, 11198}

local defaultSettings = {
	enabled = true,
	debug = false,
	frameWidth = FRAME_WIDTH,
	frameHeight = FRAME_HEIGHT,
	frameSpacing = FRAME_SPACING,
	fontSize = DEFAULT_FONT_SIZE,
	framePosX = DEFAULT_POS_X,
	framePosY = DEFAULT_POS_Y
}

local activeTalents = {
	envenom = false,
	tasteForBlood = false,
	improvedExpose = false
}

local exposeTimers = {}
local playerGUID = nil
local lastExposeGuid = nil
local pendingExpose = nil
local sndManualTimer = nil
local tfbManualTimer = nil
local envenomManualTimer = nil
local lastShowFrame = nil
local lastComboPoints = nil
local lastSliceAndDiceActive = nil
local trackers = {}
trackers.comboPoints = 0
trackers.previousComboPoints = 0

local function LatPrint(message)
	DEFAULT_CHAT_FRAME:AddMessage("[|cff00ff00Lat|cfffffffferal] " .. tostring(message))
end

local function GetTalentPosition(name)
	for i = 1, GetNumTalentTabs() do
		for j = 1, GetNumTalents(i) do
			if GetTalentInfo(i, j) == name then return {i, j} end
		end
	end
end

local function GetComboPointsUsed()
	if trackers.comboPoints == 0 then
		return trackers.previousComboPoints
	else
		return trackers.comboPoints
	end
end

local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function GetPlayerClass()
	local _, class = UnitClass("player")
	return class
end

local function GetComboPointsOnTarget()
	if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") then
		return trackers.comboPoints or 0
	end
	return 0
end

local function RefreshComboPoints()
	local cp = 0
	if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") then
		cp = (GetComboPoints and (GetComboPoints("target") or GetComboPoints())) or 0
		cp = cp or 0
	end
	trackers.previousComboPoints = trackers.comboPoints
	trackers.comboPoints = cp
end

local function GetTalentRankByName(talentName)
	local talentPos = GetTalentPosition(talentName)
	if talentPos then
		local name, iconTexture, tier, column, rank, maxRank = GetTalentInfo(talentPos[1], talentPos[2])
		return rank or 0
	end
	return 0
end

local function UpdateTalentState()
	activeTalents.envenom = GetTalentRankByName("Envenom") > 0
	activeTalents.tasteForBlood = GetTalentRankByName("Taste for Blood") > 0
	activeTalents.improvedExpose = GetTalentRankByName("Improved Expose Armor") > 0
end

local function CreateTrackerFrame(name, frameName, parent)
	local trackerFrame = CreateFrame("Frame", frameName, parent or UIParent)
	trackerFrame:SetWidth(FRAME_WIDTH)
	trackerFrame:SetHeight(FRAME_HEIGHT)
	trackerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -70)
	trackerFrame:SetFrameStrata("MEDIUM")
	local bgTexture = trackerFrame:CreateTexture(nil, "BACKGROUND")
	bgTexture:SetAllPoints(trackerFrame)
	bgTexture:SetTexture(0, 0, 0, 0.64)
	return trackerFrame, bgTexture
end

local function CreateStatusBar(parent, color, frameLevel)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetAllPoints(parent)
	bar:SetStatusBarTexture("Interface\\AddOns\\Lateral\\Flat.tga")
	bar:SetStatusBarColor(unpack(color))
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	if frameLevel then
		bar:SetFrameLevel(frameLevel)
	end
	bar:Hide()
	return bar
end

-- Helper function to create text elements
local function CreateTextElement(parent, point, xOffset, color, size, outline)
	local text = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint(point, parent, point, xOffset, 0)
	text:SetTextColor(unpack(color))
	text:SetFont("Interface\\AddOns\\Lateral\\ABF.ttf", size, outline)
	return text
end

-- Create Slice and Dice tracker
trackers.snd = {}
trackers.snd.frame, trackers.snd.bgTexture = CreateTrackerFrame("Slice and Dice", "LateralTrackerFrame")
trackers.snd.potentialBar = CreateStatusBar(trackers.snd.frame, {0.29, 0.45, 1, 1})
trackers.snd.activeBar = CreateStatusBar(trackers.snd.frame, {0.97, 1, 0.35, 1}, trackers.snd.potentialBar:GetFrameLevel() + 1)

-- Create Slice and Dice text elements
trackers.snd.potentialText = CreateTextElement(trackers.snd.activeBar, "RIGHT", -5, {0.16, 1, 0.01, 1}, 16)
trackers.snd.potentialText:SetDrawLayer("OVERLAY", 3)
trackers.snd.potentialText2 = CreateTextElement(trackers.snd.potentialBar, "RIGHT", -5, {0.16, 1, 0.01, 1}, 16)
trackers.snd.activeText = CreateTextElement(trackers.snd.activeBar, "LEFT", 5, {1, 1, 1, 1}, 16, "OUTLINE")

-- Create Taste for Blood tracker
trackers.tfb = {}
trackers.tfb.frame, trackers.tfb.bgTexture = CreateTrackerFrame("Taste for Blood", "TasteForBloodTrackerFrame")
trackers.tfb.potentialBar = CreateStatusBar(trackers.tfb.frame, {0.29, 0.78, 0.81, 1})
trackers.tfb.activeBar = CreateStatusBar(trackers.tfb.frame, {1, 0.2, 0.2, 1}, trackers.tfb.potentialBar:GetFrameLevel() + 1)

-- Create Taste for Blood text elements
trackers.tfb.potentialText = CreateTextElement(trackers.tfb.activeBar, "RIGHT", -5, {0.16, 1, 0.01, 1}, 16)
trackers.tfb.potentialText:SetDrawLayer("OVERLAY", 3)
trackers.tfb.potentialText2 = CreateTextElement(trackers.tfb.potentialBar, "RIGHT", -5, {0.16, 1, 0.01, 1}, 16)
trackers.tfb.activeText = CreateTextElement(trackers.tfb.activeBar, "LEFT", 5, {1, 1, 1, 1}, 16, "OUTLINE")
trackers.tfb.centerText = CreateTextElement(trackers.tfb.activeBar, "CENTER", 0, {1, 1, 1, 1}, 16, "OUTLINE")

-- Create Envenom tracker
trackers.envenom = {}
trackers.envenom.frame, trackers.envenom.bgTexture = CreateTrackerFrame("Envenom", "EnvenomTrackerFrame")
trackers.envenom.potentialBar = CreateStatusBar(trackers.envenom.frame, {0.8, 0.2, 0.8, 1})
trackers.envenom.activeBar = CreateStatusBar(trackers.envenom.frame, {0.52, 0.87, 0.01, 1}, trackers.envenom.potentialBar:GetFrameLevel() + 1)

-- Create Envenom text elements
trackers.envenom.potentialText = CreateTextElement(trackers.envenom.activeBar, "RIGHT", -5, {0.16, 1, 0.01, 1}, 16)
trackers.envenom.potentialText:SetDrawLayer("OVERLAY", 3)
trackers.envenom.potentialText2 = CreateTextElement(trackers.envenom.potentialBar, "RIGHT", -5, {0.16, 1, 0.01, 1}, 16)
trackers.envenom.activeText = CreateTextElement(trackers.envenom.activeBar, "LEFT", 5, {1, 1, 1, 1}, 16, "OUTLINE")

-- Create Expose Armor tracker (target debuff)
trackers.expose = {}
trackers.expose.frame, trackers.expose.bgTexture = CreateTrackerFrame("Expose Armor", "ExposeArmorTrackerFrame")
trackers.expose.potentialBar = CreateStatusBar(trackers.expose.frame, {0.8, 0.8, 0.8, 1})
trackers.expose.activeBar = CreateStatusBar(trackers.expose.frame, {0.32, 0.34, 0.63, 1}, trackers.expose.potentialBar:GetFrameLevel() + 1)

-- Create Expose Armor text elements
trackers.expose.potentialText = CreateTextElement(trackers.expose.activeBar, "RIGHT", -5, {0.16, 1, 0.01, 1}, 16)
trackers.expose.potentialText:SetDrawLayer("OVERLAY", 3)
trackers.expose.potentialText2 = CreateTextElement(trackers.expose.potentialBar, "RIGHT", -5, {0.16, 1, 0.01, 1}, 16)
trackers.expose.activeText = CreateTextElement(trackers.expose.activeBar, "LEFT", 5, {1, 1, 1, 1}, 16, "OUTLINE")

local function ApplyLayoutSettings()
	if not LateralDB then return end
	-- Dimensions
	local w = LateralDB.frameWidth or FRAME_WIDTH
	local h = LateralDB.frameHeight or FRAME_HEIGHT
	trackers.snd.frame:SetWidth(w)
	trackers.snd.frame:SetHeight(h)
	trackers.tfb.frame:SetWidth(w)
	trackers.tfb.frame:SetHeight(h)
	trackers.envenom.frame:SetWidth(w)
	trackers.envenom.frame:SetHeight(h)
	trackers.expose.frame:SetWidth(w)
	trackers.expose.frame:SetHeight(h)
	-- Position
	local px = LateralDB.framePosX or DEFAULT_POS_X
	local py = LateralDB.framePosY or DEFAULT_POS_Y
	trackers.snd.frame:ClearAllPoints()
	trackers.snd.frame:SetPoint("CENTER", UIParent, "CENTER", px, py)
	-- Fonts
	local fontSize = LateralDB.fontSize or DEFAULT_FONT_SIZE
	local function SetAllFonts(size)
		local fontPath = "Interface\\AddOns\\Lateral\\ABF.ttf"
		trackers.snd.potentialText:SetFont(fontPath, size)
		trackers.snd.potentialText2:SetFont(fontPath, size)
		trackers.snd.activeText:SetFont(fontPath, size, "OUTLINE")
		trackers.tfb.potentialText:SetFont(fontPath, size)
		trackers.tfb.potentialText2:SetFont(fontPath, size)
		trackers.tfb.activeText:SetFont(fontPath, size, "OUTLINE")
		if trackers.tfb.centerText then trackers.tfb.centerText:SetFont(fontPath, size, "OUTLINE") end
		trackers.envenom.potentialText:SetFont(fontPath, size)
		trackers.envenom.potentialText2:SetFont(fontPath, size)
		trackers.envenom.activeText:SetFont(fontPath, size, "OUTLINE")
		trackers.expose.potentialText:SetFont(fontPath, size)
		trackers.expose.potentialText2:SetFont(fontPath, size)
		trackers.expose.activeText:SetFont(fontPath, size, "OUTLINE")
	end
	SetAllFonts(fontSize)
end

local function CalculatePotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = SND_DURATIONS[comboPoints]
	local talentRank = GetTalentRankByName("Improved Blade Tactics")
	local talentBonus = talentRank * 0.15
	local finalDuration = baseDuration * (1 + talentBonus)
	
	return finalDuration
end

local function CalculateTasteForBloodPotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = RUPTURE_DURATIONS[comboPoints]
	local talentRank = GetTalentRankByName("Taste for Blood")
	local talentBonus = talentRank * 2
	local finalDuration = baseDuration + talentBonus
	
	return finalDuration
end

local function CalculateEnvenomPotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = ENVENOM_DURATIONS[comboPoints]
	
	return baseDuration
end

local function GetUniversalMaxDuration()
	local maxDuration = 0

	do
		local base = SND_DURATIONS[5]
		local rank = GetTalentRankByName("Improved Blade Tactics")
		local bonus = rank * 0.15
		maxDuration = math.max(maxDuration, base * (1 + bonus))
	end

	if activeTalents.tasteForBlood then
		local base = RUPTURE_DURATIONS[5]
		local rank = GetTalentRankByName("Taste for Blood")
		maxDuration = math.max(maxDuration, base + (rank * 2))
	end

	if activeTalents.envenom then
		maxDuration = math.max(maxDuration, ENVENOM_DURATIONS[5])
	end

	if activeTalents.improvedExpose then
		maxDuration = math.max(maxDuration, EXPOSE_ARMOR_DURATION)
	end

	return maxDuration
end

local function GetExposeArmorTimeLeftForTarget()
    local exists, guid = UnitExists("TARGET")
    if not exists or not guid then return 0, false end
    local timer = exposeTimers[guid]
    if timer and timer.ends then
        local remaining = timer.ends - GetTime()
        if remaining > 0 then
            return remaining, true
        end
    end
    return 0, false
end

local function UpdateDisplay()

	if not LateralDB then
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
		trackers.expose.frame:Hide()
		return
	end
	
	if not LateralDB.enabled then
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
		trackers.expose.frame:Hide()
		return
	end
	
	if GetPlayerClass() ~= "ROGUE" then
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
		trackers.expose.frame:Hide()
		return
	end
	
	local comboPoints = GetComboPointsOnTarget()
	local hasEnemy = UnitExists("target") and UnitCanAttack("player", "target")
	local sliceAndDiceActive = false
	local eventTimeLeft = 0
	if sndManualTimer and sndManualTimer.ends then
		eventTimeLeft = sndManualTimer.ends - GetTime()
		if eventTimeLeft < 0 then eventTimeLeft = 0 end
		if eventTimeLeft == 0 then sndManualTimer = nil end
	end
	local timeLeft = eventTimeLeft
	if timeLeft > 0 then sliceAndDiceActive = true end

	local tfbTimeLeft, tasteForBloodActive = 0, false
	if activeTalents.tasteForBlood and tfbManualTimer and tfbManualTimer.ends then
		tfbTimeLeft = tfbManualTimer.ends - GetTime()
		if tfbTimeLeft < 0 then tfbTimeLeft = 0 end
		if tfbTimeLeft == 0 then tfbManualTimer = nil else tasteForBloodActive = true end
	end

	local envenomTimeLeft, envenomActive = 0, false
	if activeTalents.envenom and envenomManualTimer and envenomManualTimer.ends then
		envenomTimeLeft = envenomManualTimer.ends - GetTime()
		if envenomTimeLeft < 0 then envenomTimeLeft = 0 end
		if envenomTimeLeft == 0 then envenomManualTimer = nil else envenomActive = true end
	end

	local exposeTimeLeft, exposeActive = 0, false
		if activeTalents.improvedExpose then
			exposeTimeLeft, exposeActive = GetExposeArmorTimeLeftForTarget()
		end
	
	lastComboPoints = comboPoints
	lastSliceAndDiceActive = sliceAndDiceActive
	
	local shouldShowBars = (comboPoints > 0 and hasEnemy) or sliceAndDiceActive or (activeTalents.tasteForBlood and tasteForBloodActive) or (activeTalents.envenom and envenomActive) or (activeTalents.improvedExpose and exposeActive)
	
	trackers.tfb.frame:ClearAllPoints()
	trackers.envenom.frame:ClearAllPoints()
	trackers.expose.frame:ClearAllPoints()
	local prevFrame = trackers.snd.frame
	local spacing = (LateralDB and LateralDB.frameSpacing) or FRAME_SPACING
	if activeTalents.tasteForBlood then
		trackers.tfb.frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, -spacing)
		prevFrame = trackers.tfb.frame
	end
	if activeTalents.envenom then
		trackers.envenom.frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, -spacing)
		prevFrame = trackers.envenom.frame
	end
	if activeTalents.improvedExpose then
		trackers.expose.frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, -spacing)
	end
	
	local universalMaxDuration = GetUniversalMaxDuration()
	
	if comboPoints > 0 and hasEnemy then
		local potentialDuration = CalculatePotentialDuration(comboPoints)
		trackers.snd.potentialBar:SetMinMaxValues(0, universalMaxDuration)
		trackers.snd.potentialBar:SetValue(potentialDuration)
		trackers.snd.potentialBar:Show()
		trackers.snd.potentialText:SetText(string.format("%.2f", potentialDuration))
		trackers.snd.potentialText2:SetText(string.format("%.2f", potentialDuration))
	else
		trackers.snd.potentialBar:Hide()
		trackers.snd.potentialText:SetText("")
		trackers.snd.potentialText2:SetText("")
	end
	
	if sliceAndDiceActive and timeLeft > 0 then
		trackers.snd.activeBar:SetMinMaxValues(0, universalMaxDuration)
		trackers.snd.activeBar:SetValue(timeLeft)
		trackers.snd.activeBar:Show()
		trackers.snd.activeText:SetText(string.format("%.1f", timeLeft))
	else
		trackers.snd.activeBar:Hide()
		trackers.snd.activeText:SetText("")
	end
	
	if activeTalents.tasteForBlood then
		if comboPoints > 0 and hasEnemy then
			local tfbPotentialDuration = CalculateTasteForBloodPotentialDuration(comboPoints)
			trackers.tfb.potentialBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.tfb.potentialBar:SetValue(tfbPotentialDuration)
			trackers.tfb.potentialBar:Show()
			trackers.tfb.potentialText:SetText(string.format("%.2f", tfbPotentialDuration))
			trackers.tfb.potentialText2:SetText(string.format("%.2f", tfbPotentialDuration))
		else
			trackers.tfb.potentialBar:Hide()
			trackers.tfb.potentialText:SetText("")
			trackers.tfb.potentialText2:SetText("")
		end

		if tasteForBloodActive and tfbTimeLeft > 0 then
			trackers.tfb.activeBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.tfb.activeBar:SetValue(tfbTimeLeft)
			trackers.tfb.activeBar:Show()
			trackers.tfb.activeText:SetText(string.format("%.1f", tfbTimeLeft))
			-- Show CP-based percentage text in center (cp at activation * 3%)
			local cpForTfb = (tfbManualTimer and tfbManualTimer.cp) or lastComboPoints or comboPoints or 0
			if cpForTfb < 1 then cpForTfb = 1 end
			if cpForTfb > 5 then cpForTfb = 5 end
			local percent = cpForTfb * 3
			if trackers.tfb.centerText then
				trackers.tfb.centerText:SetText(string.format("%d%%", percent))
				trackers.tfb.centerText:Show()
			end
		else
			trackers.tfb.activeBar:Hide()
			trackers.tfb.activeText:SetText("")
			if trackers.tfb.centerText then
				trackers.tfb.centerText:SetText("")
				trackers.tfb.centerText:Hide()
			end
		end
	else
		trackers.tfb.potentialBar:Hide()
		trackers.tfb.activeBar:Hide()
		trackers.tfb.potentialText:SetText("")
		trackers.tfb.potentialText2:SetText("")
		trackers.tfb.activeText:SetText("")
	end
	
	if activeTalents.envenom then
		if comboPoints > 0 and hasEnemy then
			local envenomPotentialDuration = CalculateEnvenomPotentialDuration(comboPoints)
			trackers.envenom.potentialBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.envenom.potentialBar:SetValue(envenomPotentialDuration)
			trackers.envenom.potentialBar:Show()
			trackers.envenom.potentialText:SetText(string.format("%.2f", envenomPotentialDuration))
			trackers.envenom.potentialText2:SetText(string.format("%.2f", envenomPotentialDuration))
		else
			trackers.envenom.potentialBar:Hide()
			trackers.envenom.potentialText:SetText("")
			trackers.envenom.potentialText2:SetText("")
		end

		if envenomActive and envenomTimeLeft > 0 then
			trackers.envenom.activeBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.envenom.activeBar:SetValue(envenomTimeLeft)
			trackers.envenom.activeBar:Show()
			trackers.envenom.activeText:SetText(string.format("%.1f", envenomTimeLeft))
		else
			trackers.envenom.activeBar:Hide()
			trackers.envenom.activeText:SetText("")
		end
	else
		trackers.envenom.potentialBar:Hide()
		trackers.envenom.activeBar:Hide()
		trackers.envenom.potentialText:SetText("")
		trackers.envenom.potentialText2:SetText("")
		trackers.envenom.activeText:SetText("")
	end

	if activeTalents.improvedExpose then
		if comboPoints == 5 and hasEnemy then
			local exposePotential = EXPOSE_ARMOR_DURATION
			trackers.expose.potentialBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.expose.potentialBar:SetValue(exposePotential)
			trackers.expose.potentialBar:Show()
			trackers.expose.potentialText:SetText(string.format("%.2f", exposePotential))
			trackers.expose.potentialText2:SetText(string.format("%.2f", exposePotential))
		else
			trackers.expose.potentialBar:Hide()
			trackers.expose.potentialText:SetText("")
			trackers.expose.potentialText2:SetText("")
		end

		if exposeActive and exposeTimeLeft > 0 then
			trackers.expose.activeBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.expose.activeBar:SetValue(exposeTimeLeft)
			trackers.expose.activeBar:Show()
			trackers.expose.activeText:SetText(string.format("%.1f", exposeTimeLeft))
		else
			trackers.expose.activeBar:Hide()
			trackers.expose.activeText:SetText("")
		end
	else
		trackers.expose.potentialBar:Hide()
		trackers.expose.activeBar:Hide()
		trackers.expose.potentialText:SetText("")
		trackers.expose.potentialText2:SetText("")
		trackers.expose.activeText:SetText("")
	end
	
	if shouldShowBars then
		trackers.snd.frame:Show()
		if activeTalents.tasteForBlood then trackers.tfb.frame:Show() else trackers.tfb.frame:Hide() end
		if activeTalents.envenom then trackers.envenom.frame:Show() else trackers.envenom.frame:Hide() end
		if activeTalents.improvedExpose then trackers.expose.frame:Show() else trackers.expose.frame:Hide() end
	else
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
		trackers.expose.frame:Hide()
	end
end

-- Event handling
local function OnEvent()
	if event == "PLAYER_TARGET_CHANGED" then
		RefreshComboPoints()
		if LateralDB then UpdateDisplay() end
		if not playerGUID then local exists, guid = UnitExists("PLAYER"); if exists then playerGUID = guid end end

	elseif event == "PLAYER_COMBO_POINTS" then
		RefreshComboPoints()
		if LateralDB then UpdateDisplay() end

	elseif event == "UNIT_CASTEVENT" then
		-- args: casterGUID, targetGUID, type, spellId, cast duration
		local casterGUID, targetGUID, evType, spellId, castDuration = arg1, arg2, arg3, arg4, arg5
		if not playerGUID then local exists, guid = UnitExists("PLAYER"); if exists then playerGUID = guid end end
		if LateralDB and LateralDB.debug and casterGUID and playerGUID and casterGUID == playerGUID and evType == "CAST" then
			LatPrint(string.format("DEBUG: %s | %s", tostring(arg2), tostring(arg4)))
		end

		if evType == "CAST" then
			-- Expose Armor
			if has_value(EXPOSE_ARMOR_RANKS, spellId) and playerGUID and targetGUID and casterGUID == playerGUID then
				local delay = 0.2
				local _, _, nping = GetNetStats()
				if nping and nping > 0 and nping < 500 then
					delay = 0.05 + (nping / 1000.0)
				end
				pendingExpose = { guid = targetGUID, applyAt = GetTime() + delay }
				lastExposeGuid = targetGUID
			end
			
			-- Slice and Dice
			if has_value(SND_RANKS, spellId) and playerGUID and casterGUID == playerGUID then
				local cpUsed = GetComboPointsUsed() or 0
				if cpUsed < 1 then cpUsed = 1 end
				if cpUsed > 5 then cpUsed = 5 end
				local duration = CalculatePotentialDuration(cpUsed)
				sndManualTimer = { starts = GetTime(), ends = GetTime() + duration }
			end
			
			-- Envenom
			if spellId == 52531 and playerGUID and casterGUID == playerGUID and activeTalents.envenom then
				local cpUsed = GetComboPointsUsed() or 0
				if cpUsed < 1 then cpUsed = 1 end
				if cpUsed > 5 then cpUsed = 5 end
				local duration = CalculateEnvenomPotentialDuration(cpUsed)
				envenomManualTimer = { starts = GetTime(), ends = GetTime() + duration }
			end
			
			-- Taste for Blood
			if has_value(RUPTURE_RANKS, spellId) and playerGUID and casterGUID == playerGUID and activeTalents.tasteForBlood then
				local cpUsed = GetComboPointsUsed() or 0
				if cpUsed < 1 then cpUsed = 1 end
				if cpUsed > 5 then cpUsed = 5 end
				local duration = CalculateTasteForBloodPotentialDuration(cpUsed)
				tfbManualTimer = { starts = GetTime(), ends = GetTime() + duration, cp = cpUsed }
			end
		end
	elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
		-- Detect Expose Armor failures and cancel the last started timer
		local resist_test = "Your (.+) was resisted by (.+)"
		local missed_test = "Your (.+) missed (.+)"
		local parry_test = "Your (.+) is parried by (.+)"
		local immune_test = "Your (.+) fail.+%. (.+) is immune"
		local block_test = "Your (.+) was blocked by (.+)"
		local dodge_test = "Your (.+) was dodged by (.+)"

		local spellName, failedTarget
		local tests = { resist_test, immune_test, missed_test, parry_test, block_test, dodge_test }
		for _, test in pairs(tests) do
			local _, _, foundSpell, foundTarget = string.find(arg1, test)
			if foundSpell and foundTarget then
				spellName = foundSpell
				failedTarget = foundTarget
				break
			end
		end

		if spellName == "Expose Armor" and failedTarget then
			if pendingExpose then pendingExpose = nil end
		end
		
	elseif event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" or event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
		for unit in string.gfind(arg1, '(.+) dies') do
			if UnitExists("target") and UnitName("target") == unit then
				local exists, guid = UnitExists("TARGET")
				if exists and guid and exposeTimers[guid] then exposeTimers[guid] = nil end
				if LateralDB then UpdateDisplay() end
			end
		end
	end
	
	if event == "ADDON_LOADED" and arg1 == addonName then
		LateralDB = LateralDB or {}
		for key, value in pairs(defaultSettings) do
			if LateralDB[key] == nil then
				LateralDB[key] = value
			end
		end
		
		trackers.snd.frame:ClearAllPoints()
		ApplyLayoutSettings()

		trackers.tfb.frame:ClearAllPoints()
		trackers.tfb.frame:SetPoint("TOP", trackers.snd.frame, "BOTTOM", 0, -(LateralDB.frameSpacing or FRAME_SPACING))

		trackers.envenom.frame:ClearAllPoints()
		trackers.envenom.frame:SetPoint("TOP", trackers.tfb.frame, "BOTTOM", 0, -(LateralDB.frameSpacing or FRAME_SPACING))

		trackers.expose.frame:ClearAllPoints()
		trackers.expose.frame:SetPoint("TOP", trackers.envenom.frame, "BOTTOM", 0, -(LateralDB.frameSpacing or FRAME_SPACING))
		LatPrint("Lateral loaded. Type /lat to open settings.")
	elseif event == "PLAYER_ENTERING_WORLD" then
		UpdateTalentState()
		RefreshComboPoints()
		frame.updateTimer = 0
		frame:SetScript("OnUpdate", function()
			frame.updateTimer = frame.updateTimer + arg1
			if frame.updateTimer >= UPDATE_INTERVAL then
				if pendingExpose and GetTime() >= pendingExpose.applyAt then
					exposeTimers[pendingExpose.guid] = { starts = GetTime(), ends = GetTime() + EXPOSE_ARMOR_DURATION }
					pendingExpose = nil
				end
				UpdateDisplay()
				frame.updateTimer = 0
			end
		end)
	elseif event == "LEARNED_SPELL_IN_TAB" or "PLAYER_ENTER_COMBAT" then
		UpdateTalentState()
		if LateralDB then UpdateDisplay() end
	end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_ENTER_COMBAT")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
frame:RegisterEvent("UNIT_CASTEVENT")
frame:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
frame:RegisterEvent("PLAYER_COMBO_POINTS")
frame:SetScript("OnEvent", OnEvent)

-- Slash commands
SLASH_LATERAL1 = "/lat"
SLASH_LATERAL2 = "/lateral"

SlashCmdList["LATERAL"] = function(msg)
	DoDropDown()
	if LateralOptionsMenu then
		LateralOptionsMenu:Show()
	end
end


local buttonheight = 16

local lateralMenuArray = {
	{text = "Enabled", toggle = "enabled", tooltip = "Enable/disable the tracker UI"},
	{text = "Debug Logging", toggle = "debug", tooltip = "Toggle debug logging for UNIT_CASTEVENT"},
	{text = "",},
	{text = "Frame Width", editbox = { key = "frameWidth" }, tooltip = "Set frame width"},
	{text = "Frame Height", editbox = { key = "frameHeight" }, tooltip = "Set frame height"},
	{text = "Frame Spacing", editbox = { key = "frameSpacing" }, tooltip = "Set spacing between frames"},
	{text = "Text Size", editbox = { key = "fontSize" }, tooltip = "Set text size for all tracker texts"},
	{text = "",},
	{text = "Horizontal Position", editbox = { key = "framePosX" }, tooltip = "Set horizontal position"},
	{text = "Vertical Position", editbox = { key = "framePosY" }, tooltip = "Set vertical position"},
}

local function Lateral_OptionChange()
	if LateralDB then
		UpdateDisplay()
	end
end

local function Lateral_MenuRefreshChecks()
	for i, val in ipairs(lateralMenuArray) do
		local b = getglobal("LateralOptionsMenubutton"..i)
		if b and val.toggle and b.chk and b.chk.tex then
			if LateralDB and LateralDB[val.toggle] then
				b.chk.tex:SetTexture("Interface/Buttons/UI-CheckBox-Check")
			else
				b.chk.tex:SetTexture("Interface/Buttons/UI-CheckBox-Check-Disabled")
			end
		end
	end
end

local function Lateral_InitializeEditBox()
	if LateralMenuEditBoxContainer then return end
	local f = CreateFrame("Frame", "LateralMenuEditBoxContainer", LateralOptionsMenu)
	f:SetWidth(140)
	f:SetHeight(36)
	f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
	f:SetBackdropColor(0,0,0,1)
	f:SetPoint("CENTER",UIParent,"CENTER",-100,0)
	f:Hide()

	f.e = CreateFrame("EditBox", "LateralMenuEditBox", f, "InputBoxTemplate")
	f.e:SetFontObject("GameFontHighlight")
	f.e:SetWidth(110)
	f.e:SetHeight(18)
	f.e:SetAutoFocus(false)
	f.e:SetPoint("CENTER",0,0)
	f.e:SetText("")
	f.e:EnableKeyboard()
	f.e:SetScript("OnEnterPressed", function()
		this:ClearFocus()
		if this.key and LateralDB then
			local num = tonumber(this:GetText())
			if num then
				LateralDB[this.key] = num
				ApplyLayoutSettings()
				Lateral_OptionChange()
			else
				-- restore current stored value if input invalid
				if LateralDB[this.key] ~= nil then
					this:SetText(tostring(LateralDB[this.key]))
				end
			end
		end
	end)
	f.e:SetScript("OnEscapePressed", function()
		this:ClearFocus()
		if this.key and LateralDB and LateralDB[this.key] ~= nil then
			this:SetText(tostring(LateralDB[this.key]))
		end
	end)
end

local function Lateral_InitializeMenu()
	if LateralOptionsMenu then return end

	local f = CreateFrame("Button","LateralOptionsMenu",UIParent)
	f:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 }})
	f:SetBackdropColor(0,0,0)
	f:SetWidth(180)
	f:SetHeight(buttonheight*(getn(lateralMenuArray)+3))
	f:SetPoint("CENTER",UIParent)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:EnableMouseWheel()
	f.offset = 0
	f.fs = f:CreateFontString('$parentTitle', "ARTWORK", "GameFontNormalLarge")
	f.fs:SetText("Lateral")
	f.fs:SetPoint("TOPLEFT",12,-12)
	f.fsv = f:CreateFontString('$parentVersion', "ARTWORK", "GameFontNormalSmall")
	f.fsv:SetText("Settings")
	f.fsv:SetPoint("TOPLEFT",80,-18)
	f:SetScript("OnDragStart", function()
		LateralOptionsMenu:StartMoving()
	end)
	f:SetScript("OnDragStop", function()
		this:StopMovingOrSizing()
	end)
	f:SetScript("OnShow", function()
		Lateral_MenuRefreshChecks()
	end)
	f:Hide()
	local fx = CreateFrame("Button","$parentXbutton",f,"UIPanelCloseButton")
	fx:SetPoint("TOPRIGHT",0,0)

	Lateral_InitializeEditBox()

	for i, val in ipairs(lateralMenuArray) do
		local fb = CreateFrame("Button", "$parentbutton"..i, f)
		fb:SetWidth(120)
		fb:SetHeight(buttonheight)
		fb:SetHighlightTexture("Interface/Buttons/UI-Listbox-Highlight","ADD")
		fb.fs = fb:CreateFontString('$parenttext', "ARTWORK", "GameFontHighlightSmall")
		fb.fs:SetText(val.text)
		fb.fs:SetPoint("LEFT",0,0)
		fb.toggle = val.toggle
		fb.tooltip = val.tooltip
		fb.editbox = val.editbox

		if val.toggle then
			fb.chk = CreateFrame("Frame","$parentCheckmark",fb)
			fb.chk:SetWidth(20)
			fb.chk:SetHeight(20)
			fb.chk.tex = fb.chk:CreateTexture()
			if LateralDB and LateralDB[fb.toggle] then
				fb.chk.tex:SetTexture("Interface/Buttons/UI-CheckBox-Check")
			else
				fb.chk.tex:SetTexture("Interface/Buttons/UI-CheckBox-Check-Disabled")
			end
			fb.chk.tex:SetAllPoints()
			fb.chk:SetPoint("RIGHT",fb,"LEFT",0,0)
		end

		fb:SetScript("OnClick", function()
			if this.toggle and LateralDB then
				LateralDB[this.toggle] = not LateralDB[this.toggle]
				if LateralDB[this.toggle] then
					this.chk.tex:SetTexture("Interface/Buttons/UI-CheckBox-Check")
				else
					this.chk.tex:SetTexture("Interface/Buttons/UI-CheckBox-Check-Disabled")
				end
				Lateral_OptionChange()
			end
		end)
		fb:SetScript("OnEnter", function()
			if this.tooltip then
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				GameTooltip:SetText(this.tooltip, nil, nil, nil, nil, 1)
			end
			if this.editbox and this.editbox.key and LateralMenuEditBoxContainer and LateralMenuEditBox then
				LateralMenuEditBox.key = this.editbox.key
				if LateralDB and LateralDB[this.editbox.key] ~= nil then
					LateralMenuEditBox:SetText(tostring(LateralDB[this.editbox.key]))
				else
					LateralMenuEditBox:SetText("")
				end
				LateralMenuEditBoxContainer:ClearAllPoints()
				LateralMenuEditBoxContainer:SetPoint("RIGHT",this,"LEFT",-3,0)
				LateralMenuEditBoxContainer:Show()
			else
				if LateralMenuEditBoxContainer then
					LateralMenuEditBoxContainer:Hide()
				end
			end
		end)
		fb:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		fb:SetPoint("TOP","LateralOptionsMenu","TOP",0,-buttonheight*(i+1))
	end
end

-- Public entry point
function DoDropDown()
	Lateral_InitializeMenu()
end
