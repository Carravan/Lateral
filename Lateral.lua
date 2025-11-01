local addonName = "Lateral"
local frame = CreateFrame("Frame", "LateralTrackerFrame", UIParent)

local function LatPrint(message)
	DEFAULT_CHAT_FRAME:AddMessage("[|cff00ff00Lat|cfffffffferal] " .. tostring(message))
end

local function NormalizeEffectName(name)
	if not name then return nil end
	return string.gsub(name, " %(%d+%)$", "")
end

local function GetTalentPosition(name)
	for i = 1, GetNumTalentTabs() do
		for j = 1, GetNumTalents(i) do
			if GetTalentInfo(i, j) == name then return {i, j} end
		end
	end
end

-- Tracker data structure to reduce upvalue count
local trackers = {}
trackers.comboPoints = 0
trackers.previousComboPoints = 0

local function GetComboPointsUsed()
	if trackers.comboPoints == 0 then
		return trackers.previousComboPoints
	else
		return trackers.comboPoints
	end
end

local FRAME_WIDTH = 250
local FRAME_HEIGHT = 30
local FRAME_SPACING = 5
local UPDATE_INTERVAL = 0.05

local SND_DURATIONS = {9, 12, 15, 18, 21}
local RUPTURE_DURATIONS = {8, 10, 12, 14, 16}
local ENVENOM_DURATIONS = {12, 16, 20, 24, 28}
local EXPOSE_ARMOR_DURATION = 30

local defaultSettings = {
	enabled = true,
	debug = false
}

-- Helper function to create a uniform tracker frame
local function CreateTrackerFrame(name, frameName, parent)
	local trackerFrame = CreateFrame("Frame", frameName, parent or UIParent)
	trackerFrame:SetWidth(FRAME_WIDTH)
	trackerFrame:SetHeight(FRAME_HEIGHT)
	trackerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -70)
	trackerFrame:SetFrameStrata("MEDIUM")
	
	-- Background texture
	local bgTexture = trackerFrame:CreateTexture(nil, "BACKGROUND")
	bgTexture:SetAllPoints(trackerFrame)
	bgTexture:SetTexture(0, 0, 0, 0.64)
	
	return trackerFrame, bgTexture
end

-- Helper function to create a status bar
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

-- Backward compatibility references
local frame = trackers.snd.frame
local tfbFrame = trackers.tfb.frame
local envenomFrame = trackers.envenom.frame

local exposeTimers = {}
local playerGUID = nil
local lastExposeGuid = nil
local pendingExpose = nil
local sndManualTimer = nil
local tfbManualTimer = nil
local envenomManualTimer = nil

-- (removed unused Compost library)

-- Utility functions
local function GetPlayerClass()
	local _, class = UnitClass("player")
	return class
end

local function GetComboPointsOnTarget()
	-- Only return combo points if we have a valid attackable target
	if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") then
		return trackers.comboPoints or 0
	end
	return 0
end

-- Keep trackers.comboPoints in sync with the game state
local function RefreshComboPoints()
	local cp = 0
	if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") then
		cp = (GetComboPoints and (GetComboPoints("target") or GetComboPoints())) or 0
		cp = cp or 0
	end
	trackers.previousComboPoints = trackers.comboPoints
	trackers.comboPoints = cp
end

-- Generic talent helpers and cached state
local function GetTalentRankByName(talentName)
	local talentPos = GetTalentPosition(talentName)
	if talentPos then
		local name, iconTexture, tier, column, rank, maxRank = GetTalentInfo(talentPos[1], talentPos[2])
		return rank or 0
	end
	return 0
end

local activeTalents = {
	envenom = false,
	tasteForBlood = false,
	improvedExpose = false
}

local function UpdateTalentState()
	activeTalents.envenom = GetTalentRankByName("Envenom") > 0
	activeTalents.tasteForBlood = GetTalentRankByName("Taste for Blood") > 0
	activeTalents.improvedExpose = GetTalentRankByName("Improved Expose Armor") > 0
end

local function CalculatePotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = SND_DURATIONS[comboPoints] or SND_DURATIONS[5]
	local talentRank = GetTalentRankByName("Improved Blade Tactics")
	local talentBonus = talentRank * 0.15 -- 15% per rank
	local finalDuration = baseDuration * (1 + talentBonus)
	
	return finalDuration
end

local function CalculateTasteForBloodPotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = RUPTURE_DURATIONS[comboPoints] or RUPTURE_DURATIONS[5]
	local talentRank = GetTalentRankByName("Taste for Blood")
	local talentBonus = talentRank * 2 -- 2 seconds per rank
	local finalDuration = baseDuration + talentBonus
	
	return finalDuration
end

local function CalculateEnvenomPotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = ENVENOM_DURATIONS[comboPoints] or ENVENOM_DURATIONS[5]
	
	return baseDuration
end

-- Get the universal maximum duration for all bars (highest possible duration)
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

-- Track last state to reduce spam
local lastShowFrame = nil
local lastComboPoints = nil
local lastSliceAndDiceActive = nil
local updateCount = 0

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
	updateCount = updateCount + 1
	
	-- Check if addon is enabled
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
	
	-- Only show for Rogues
	if GetPlayerClass() ~= "ROGUE" then
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
		trackers.expose.frame:Hide()
		return
	end
	
	local comboPoints = GetComboPointsOnTarget()
	local hasEnemy = UnitExists("target") and UnitCanAttack("player", "target")
	-- SND time from UNIT_CASTEVENT manual timer only
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
	
	-- Unified visibility logic: show all bars if we have combo points OR any buff/debuff is active
	local shouldShowBars = (comboPoints > 0 and hasEnemy) or sliceAndDiceActive or (activeTalents.tasteForBlood and tasteForBloodActive) or (activeTalents.envenom and envenomActive) or (activeTalents.improvedExpose and exposeActive)
	
	-- Dynamic vertical layout: anchor only active-talent bars below Slice and Dice
	trackers.tfb.frame:ClearAllPoints()
	trackers.envenom.frame:ClearAllPoints()
	trackers.expose.frame:ClearAllPoints()
	local prevFrame = trackers.snd.frame
	if activeTalents.tasteForBlood then
		trackers.tfb.frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, -FRAME_SPACING)
		prevFrame = trackers.tfb.frame
	end
	if activeTalents.envenom then
		trackers.envenom.frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, -FRAME_SPACING)
		prevFrame = trackers.envenom.frame
	end
	if activeTalents.improvedExpose then
		trackers.expose.frame:SetPoint("TOP", prevFrame, "BOTTOM", 0, -FRAME_SPACING)
	end
	
	local universalMaxDuration = GetUniversalMaxDuration()
	
	-- === SLICE AND DICE BAR ===
	-- Show potential duration when we have combo points on an enemy
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
	
	-- Show active duration when Slice and Dice is active
	if sliceAndDiceActive and timeLeft > 0 then
		trackers.snd.activeBar:SetMinMaxValues(0, universalMaxDuration)
		trackers.snd.activeBar:SetValue(timeLeft)
		trackers.snd.activeBar:Show()
		trackers.snd.activeText:SetText(string.format("%.1f", timeLeft))
	else
		trackers.snd.activeBar:Hide()
		trackers.snd.activeText:SetText("")
	end
	
	-- === TASTE FOR BLOOD BAR ===
	if activeTalents.tasteForBlood then
		-- Show potential duration when we have combo points on an enemy
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

		-- Show active duration when Taste for Blood is active
		if tasteForBloodActive and tfbTimeLeft > 0 then
			trackers.tfb.activeBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.tfb.activeBar:SetValue(tfbTimeLeft)
			trackers.tfb.activeBar:Show()
			trackers.tfb.activeText:SetText(string.format("%.1f", tfbTimeLeft))
		else
			trackers.tfb.activeBar:Hide()
			trackers.tfb.activeText:SetText("")
		end
	else
		-- Talent inactive: ensure frame elements are hidden
		trackers.tfb.potentialBar:Hide()
		trackers.tfb.activeBar:Hide()
		trackers.tfb.potentialText:SetText("")
		trackers.tfb.potentialText2:SetText("")
		trackers.tfb.activeText:SetText("")
	end
	
	-- === ENVENOM BAR ===
	if activeTalents.envenom then
		-- Show potential duration when we have combo points on an enemy
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

		-- Show active duration when Envenom is active
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
		-- Talent inactive: ensure frame elements are hidden
		trackers.envenom.potentialBar:Hide()
		trackers.envenom.activeBar:Hide()
		trackers.envenom.potentialText:SetText("")
		trackers.envenom.potentialText2:SetText("")
		trackers.envenom.activeText:SetText("")
	end

	-- === EXPOSE ARMOR BAR (TARGET DEBUFF) ===
	if activeTalents.improvedExpose then
		-- Potential is fixed 30s; show only at 5 combo points on an enemy
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

		-- Active bar when Expose Armor is active on target
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
		-- Talent inactive: ensure frame elements are hidden
		trackers.expose.potentialBar:Hide()
		trackers.expose.activeBar:Hide()
		trackers.expose.potentialText:SetText("")
		trackers.expose.potentialText2:SetText("")
		trackers.expose.activeText:SetText("")
	end
	
	-- === UNIFIED FRAME VISIBILITY ===
	-- Show anchor; show other frames only if their talents are active
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
	-- Handle events that should trigger updates
	if event == "PLAYER_TARGET_CHANGED" then
		RefreshComboPoints()
		if LateralDB then UpdateDisplay() end
		if not playerGUID then local exists, guid = UnitExists("PLAYER"); if exists then playerGUID = guid end end

	elseif event == "PLAYER_COMBO_POINTS" then
		RefreshComboPoints()
		if LateralDB then UpdateDisplay() end

	elseif event == "UNIT_CASTEVENT" then
		-- args: casterGUID, targetGUID, type, spellId
		local casterGUID, targetGUID, evType, spellId = arg1, arg2, arg3, arg4
		if not playerGUID then local exists, guid = UnitExists("PLAYER"); if exists then playerGUID = guid end end

		if LateralDB and LateralDB.debug and casterGUID and playerGUID and casterGUID == playerGUID then
			LatPrint(string.format("DEBUG: %s | %s | %s | %s | %s", tostring(arg1), tostring(arg2), tostring(arg3), tostring(arg4), tostring(arg5)))
		end

		if evType == "CAST" then
			if spellId == 11198 and playerGUID and targetGUID and casterGUID == playerGUID then
				-- schedule a pending apply to be finalized after latency window
				local delay = 0.2
				local _, _, nping = GetNetStats()
				if nping and nping > 0 and nping < 500 then
					delay = 0.05 + (nping / 1000.0)
				end
				pendingExpose = { guid = targetGUID, applyAt = GetTime() + delay }
				lastExposeGuid = targetGUID
			end
			-- Slice and Dice (no target checks) spellId 6774
			if spellId == 6774 and playerGUID and casterGUID == playerGUID then
				local cpUsed = GetComboPointsUsed() or 0
				if cpUsed < 1 then cpUsed = 1 end
				if cpUsed > 5 then cpUsed = 5 end
				local duration = CalculatePotentialDuration(cpUsed)
				sndManualTimer = { starts = GetTime(), ends = GetTime() + duration }
			end
			-- Envenom (no target checks) spellId 52531
			if spellId == 52531 and playerGUID and casterGUID == playerGUID and activeTalents.envenom then
				local cpUsed = GetComboPointsUsed() or 0
				if cpUsed < 1 then cpUsed = 1 end
				if cpUsed > 5 then cpUsed = 5 end
				local duration = CalculateEnvenomPotentialDuration(cpUsed)
				envenomManualTimer = { starts = GetTime(), ends = GetTime() + duration }
			end
			-- Taste for Blood (no target checks) spellId 11275
			if spellId == 11275 and playerGUID and casterGUID == playerGUID and activeTalents.tasteForBlood then
				local cpUsed = GetComboPointsUsed() or 0
				if cpUsed < 1 then cpUsed = 1 end
				if cpUsed > 5 then cpUsed = 5 end
				local duration = CalculateTasteForBloodPotentialDuration(cpUsed)
				tfbManualTimer = { starts = GetTime(), ends = GetTime() + duration }
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
		trackers.snd.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -148)

		trackers.tfb.frame:ClearAllPoints()
		trackers.tfb.frame:SetPoint("TOP", trackers.snd.frame, "BOTTOM", 0, -FRAME_SPACING)

		trackers.envenom.frame:ClearAllPoints()
		trackers.envenom.frame:SetPoint("TOP", trackers.tfb.frame, "BOTTOM", 0, -FRAME_SPACING)

		trackers.expose.frame:ClearAllPoints()
		trackers.expose.frame:SetPoint("TOP", trackers.envenom.frame, "BOTTOM", 0, -FRAME_SPACING)
		
		LatPrint("Lateral loaded. Type /lat for commands.")
	elseif event == "PLAYER_ENTERING_WORLD" then
		-- Cache talent state and begin updates
		UpdateTalentState()
		RefreshComboPoints()
		-- Set up update timer
		frame.updateTimer = 0
		frame:SetScript("OnUpdate", function()
			frame.updateTimer = frame.updateTimer + arg1
			if frame.updateTimer >= UPDATE_INTERVAL then
				-- finalize pending Expose Armor apply if latency window has passed and no failure was detected
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
	if not LateralDB then
		LatPrint("Slice and Dice Tracker: Not yet loaded. Please try again in a moment.")
		return
	end
	
	msg = string.lower(msg or "")
	
	if msg == "toggle" then
		LateralDB.enabled = not LateralDB.enabled
		if LateralDB.enabled then
			LatPrint("Lateral: Enabled")
		else
			LatPrint("Lateral: Disabled")
			trackers.snd.frame:Hide()
			trackers.tfb.frame:Hide()
			trackers.envenom.frame:Hide()
			trackers.expose.frame:Hide()
		end
	elseif msg == "debug" then
		LateralDB.debug = not LateralDB.debug
		if LateralDB.debug then
			LatPrint("Lateral: Debug enabled")
		else
			LatPrint("Lateral: Debug disabled")
		end
	else
		LatPrint("Lateral Commands:")
		LatPrint("/lat toggle - Enable/disable the tracker")
		LatPrint("/lat debug  - Toggle debug logging for UNIT_CASTEVENT")
	end
end
