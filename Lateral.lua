local addonName = "Lateral"
local frame = CreateFrame("Frame", "LateralTrackerFrame", UIParent)

local DEBUG_ENABLED = false

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

local FRAME_WIDTH = 250
local FRAME_HEIGHT = 30
local FRAME_SPACING = 5
local UPDATE_INTERVAL = 0.05

local BG_COLOR = {0, 0, 0, 0.64}
local POTENTIAL_COLOR = {0.29, 0.45, 1, 1}
local ACTIVE_COLOR = {0.97, 1, 0.35, 1}

local SND_DURATIONS = {9, 12, 15, 18, 21}
local RUPTURE_DURATIONS = {8, 10, 12, 14, 16}
local ENVENOM_DURATIONS = {12, 16, 20, 24, 28}

local defaultSettings = {
	enabled = true
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
	bgTexture:SetTexture(0, 0, 0, BG_COLOR[4])
	
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

-- Tracker data structure to reduce upvalue count
local trackers = {}

-- Create Slice and Dice tracker
trackers.snd = {}
trackers.snd.frame, trackers.snd.bgTexture = CreateTrackerFrame("Slice and Dice", "LateralTrackerFrame")
trackers.snd.potentialBar = CreateStatusBar(trackers.snd.frame, POTENTIAL_COLOR)
trackers.snd.activeBar = CreateStatusBar(trackers.snd.frame, ACTIVE_COLOR, trackers.snd.potentialBar:GetFrameLevel() + 1)

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

-- Backward compatibility references
local frame = trackers.snd.frame
local tfbFrame = trackers.tfb.frame
local envenomFrame = trackers.envenom.frame

-- Buff tracking variables
local sliceAndDiceData = {
	isActive = false,
	timeLeft = 0,
	maxDuration = 0,
	buffIndex = nil
}

local tasteForBloodData = {
	isActive = false,
	timeLeft = 0,
	maxDuration = 0,
	buffIndex = nil
}

local envenomData = {
	isActive = false,
	timeLeft = 0,
	maxDuration = 0,
	buffIndex = nil
}

-- Libraries
local compost = nil

-- Create tooltip for buff name detection (hidden)
local tooltip = CreateFrame("GameTooltip", "SliceDiceTooltip", nil, "GameTooltipTemplate")
tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Utility functions
local function GetPlayerClass()
	local _, class = UnitClass("player")
	return class
end

local function GetComboPointsOnTarget()
	-- Only return combo points if we have a valid attackable target
	if UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDead("target") then
		return GetComboPoints("target") or GetComboPoints() or 0
	end
	return 0
end

-- Get buff name using tooltip scanning (ElkBuffBar method)
local function GetBuffName(buffIndex)
	tooltip:SetPlayerBuff(buffIndex)
	local toolTipText = getglobal("SliceDiceTooltipTextLeft1")
	if toolTipText then
		return toolTipText:GetText()
	end
	return nil
end

-- Get Slice and Dice duration using reliable buff tracking
local function GetSliceAndDiceTimeLeft()
	local buffIndex = 0
	
	-- Scan through all beneficial buffs
	while true do
		local index, untilCancelled = GetPlayerBuff(buffIndex, "HELPFUL")
		if index < 0 then break end
		
		-- Get buff name
		local buffName = GetBuffName(index)
		
		if buffName == "Slice and Dice" then
			local timeLeft = GetPlayerBuffTimeLeft(index)
			
			-- Update tracking data
			sliceAndDiceData.isActive = true
			sliceAndDiceData.timeLeft = timeLeft
			sliceAndDiceData.buffIndex = index
			
			-- Track maximum duration seen (for refresh detection)
			if timeLeft > sliceAndDiceData.maxDuration then
				sliceAndDiceData.maxDuration = timeLeft
			end
			
			return timeLeft
		end
		
		buffIndex = buffIndex + 1
	end
	
	-- No Slice and Dice found
	sliceAndDiceData.isActive = false
	sliceAndDiceData.timeLeft = 0
	sliceAndDiceData.buffIndex = nil
	return 0
end

-- Get Taste for Blood duration using reliable buff tracking
local function GetTasteForBloodTimeLeft()
	local buffIndex = 0
	
	-- Scan through all beneficial buffs
	while true do
		local index, untilCancelled = GetPlayerBuff(buffIndex, "HELPFUL")
		if index < 0 then break end
		
		-- Get buff name
		local buffName = GetBuffName(index)
		
		if buffName == "Taste for Blood" then
			local timeLeft = GetPlayerBuffTimeLeft(index)
			
			-- Update tracking data
			tasteForBloodData.isActive = true
			tasteForBloodData.timeLeft = timeLeft
			tasteForBloodData.buffIndex = index
			
			-- Track maximum duration seen (for refresh detection)
			if timeLeft > tasteForBloodData.maxDuration then
				tasteForBloodData.maxDuration = timeLeft
			end
			
			return timeLeft
		end
		
		buffIndex = buffIndex + 1
	end
	
	-- No Taste for Blood found
	tasteForBloodData.isActive = false
	tasteForBloodData.timeLeft = 0
	tasteForBloodData.buffIndex = nil
	return 0
end

-- Get Envenom duration using reliable buff tracking
local function GetEnvenomTimeLeft()
	local buffIndex = 0
	
	-- Scan through all beneficial buffs
	while true do
		local index, untilCancelled = GetPlayerBuff(buffIndex, "HELPFUL")
		if index < 0 then break end
		
		-- Get buff name
		local buffName = GetBuffName(index)
		
		if buffName == "Envenom" then
			local timeLeft = GetPlayerBuffTimeLeft(index)
			
			-- Update tracking data
			envenomData.isActive = true
			envenomData.timeLeft = timeLeft
			envenomData.buffIndex = index
			
			-- Track maximum duration seen (for refresh detection)
			if timeLeft > envenomData.maxDuration then
				envenomData.maxDuration = timeLeft
			end
			
			return timeLeft
		end
		
		buffIndex = buffIndex + 1
	end
	
	-- No Envenom found
	envenomData.isActive = false
	envenomData.timeLeft = 0
	envenomData.buffIndex = nil
	return 0
end

local function GetImprovedSliceAndDiceRank()
	local talentPos = GetTalentPosition("Improved Blade Tactics")
	if talentPos then
		local name, iconTexture, tier, column, rank, maxRank = GetTalentInfo(talentPos[1], talentPos[2])
		return rank or 0
	end
	return 0
end

local function GetTasteForBloodRank()
	local talentPos = GetTalentPosition("Taste for Blood")
	if talentPos then
		local name, iconTexture, tier, column, rank, maxRank = GetTalentInfo(talentPos[1], talentPos[2])
		return rank or 0
	end
	return 0
end

local function CalculatePotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = SND_DURATIONS[comboPoints] or SND_DURATIONS[5]
	local talentRank = GetImprovedSliceAndDiceRank()
	local talentBonus = talentRank * 0.15 -- 15% per rank
	local finalDuration = baseDuration * (1 + talentBonus)
	
	return finalDuration
end

local function CalculateMaxDuration()
	local baseDuration = SND_DURATIONS[5] -- 5 combo points max
	local talentRank = GetImprovedSliceAndDiceRank()
	local talentBonus = talentRank * 0.15
	local maxDuration = baseDuration * (1 + talentBonus)
	
	return maxDuration
end

local function CalculateTasteForBloodPotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = RUPTURE_DURATIONS[comboPoints] or RUPTURE_DURATIONS[5]
	local talentRank = GetTasteForBloodRank()
	local talentBonus = talentRank * 2 -- 2 seconds per rank
	local finalDuration = baseDuration + talentBonus
	
	return finalDuration
end

local function CalculateTasteForBloodMaxDuration()
	local baseDuration = RUPTURE_DURATIONS[5] -- 5 combo points max
	local talentRank = GetTasteForBloodRank()
	local talentBonus = talentRank * 2 -- 2 seconds per rank
	local maxDuration = baseDuration + talentBonus
	
	return maxDuration
end

local function CalculateEnvenomPotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = ENVENOM_DURATIONS[comboPoints] or ENVENOM_DURATIONS[5]
	
	-- Envenom duration is fixed by combo points, no talent modifications
	return baseDuration
end

local function CalculateEnvenomMaxDuration()
	local maxDuration = ENVENOM_DURATIONS[5] -- 5 combo points max
	
	-- Envenom duration is fixed, no talent modifications
	return maxDuration
end

-- Get the universal maximum duration for all bars (highest possible duration)
local function GetUniversalMaxDuration()
	local sndMax = CalculateMaxDuration()
	local tfbMax = CalculateTasteForBloodMaxDuration()
	local envenomMax = CalculateEnvenomMaxDuration()
	
	-- Return the highest duration for consistent bar scaling
	return math.max(sndMax, tfbMax, envenomMax)
end

-- Track last state to reduce spam
local lastShowFrame = nil
local lastComboPoints = nil
local lastSliceAndDiceActive = nil
local updateCount = 0

local function UpdateDisplay()
	updateCount = updateCount + 1
	
	-- Check if addon is enabled
	if not LateralDB then
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
		return
	end
	
	if not LateralDB.enabled then
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
		return
	end
	
	-- Only show for Rogues
	if GetPlayerClass() ~= "ROGUE" then
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
		return
	end
	
	local comboPoints = GetComboPointsOnTarget()
	local hasEnemy = UnitExists("target") and UnitCanAttack("player", "target")
	local timeLeft = GetSliceAndDiceTimeLeft()
	local sliceAndDiceActive = sliceAndDiceData.isActive
	local tfbTimeLeft = GetTasteForBloodTimeLeft()
	local tasteForBloodActive = tasteForBloodData.isActive
	local envenomTimeLeft = GetEnvenomTimeLeft()
	local envenomActive = envenomData.isActive
	
	lastComboPoints = comboPoints
	lastSliceAndDiceActive = sliceAndDiceActive
	
	-- Unified visibility logic: show all bars if we have combo points OR any buff is active
	local shouldShowBars = (comboPoints > 0 and hasEnemy) or sliceAndDiceActive or tasteForBloodActive or envenomActive
	
	-- Set fixed positions for all frames (always maintain consistent positioning)
	trackers.tfb.frame:ClearAllPoints()
	trackers.tfb.frame:SetPoint("TOP", trackers.snd.frame, "BOTTOM", 0, -FRAME_SPACING)
	trackers.envenom.frame:ClearAllPoints()
	trackers.envenom.frame:SetPoint("TOP", trackers.tfb.frame, "BOTTOM", 0, -FRAME_SPACING)
	
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
	
	-- === ENVENOM BAR ===
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
	
	-- === UNIFIED FRAME VISIBILITY ===
	-- Show/hide all frames together based on unified condition
	if shouldShowBars then
		trackers.snd.frame:Show()
		trackers.tfb.frame:Show()
		trackers.envenom.frame:Show()
	else
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
	end
end

-- Event handling
local function OnEvent()
	-- Handle events that should trigger updates
	if event == "PLAYER_TARGET_CHANGED" then
		if LateralDB then UpdateDisplay() end
	elseif event == "PLAYER_AURAS_CHANGED" then
		if LateralDB then UpdateDisplay() end
	elseif event == "ACTIONBAR_UPDATE_USABLE" then
		if LateralDB then UpdateDisplay() end
	end
	
	if event == "ADDON_LOADED" and arg1 == addonName then
		
		-- Initialize Compost library
		if AceLibrary and AceLibrary:HasInstance("Compost-2.0") then
			compost = AceLibrary("Compost-2.0")
		end
		
		-- Initialize saved variables
		LateralDB = LateralDB or {}
		
		for key, value in pairs(defaultSettings) do
			if LateralDB[key] == nil then
				LateralDB[key] = value
			end
		end
		
		-- Position frames at fixed default locations
		trackers.snd.frame:ClearAllPoints()
		trackers.snd.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -148)
		-- Position TFB frame below the main frame
		trackers.tfb.frame:ClearAllPoints()
		trackers.tfb.frame:SetPoint("TOP", trackers.snd.frame, "BOTTOM", 0, -FRAME_SPACING)
		-- Position Envenom frame below the TFB frame
		trackers.envenom.frame:ClearAllPoints()
		trackers.envenom.frame:SetPoint("TOP", trackers.tfb.frame, "BOTTOM", 0, -FRAME_SPACING)
		
		-- Print loaded message now that addon is fully initialized
		LatPrint("Lateral loaded. Type /lat for commands.")
	elseif event == "PLAYER_LOGIN" then
		-- Set up update timer
		frame.updateTimer = 0
		frame:SetScript("OnUpdate", function()
			frame.updateTimer = frame.updateTimer + arg1
			if frame.updateTimer >= UPDATE_INTERVAL then
				UpdateDisplay()
				frame.updateTimer = 0
			end
		end)
	end
end



-- Register events
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_AURAS_CHANGED")
frame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")

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
		end


	else
		LatPrint("Lateral Commands:")
		LatPrint("/lat toggle - Enable/disable the tracker")
	end
end
