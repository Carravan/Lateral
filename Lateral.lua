local addonName = "Lateral"
local frame = CreateFrame("Frame", "LateralTrackerFrame", UIParent)

local DEBUG_ENABLED = false

local function DebugPrint(message)
    if DEBUG_ENABLED then
        print("[Lateral] " .. tostring(message))
    end
end

local FRAME_WIDTH = 250
local FRAME_HEIGHT = 30
local UPDATE_INTERVAL = 0.05

local BG_COLOR = {0, 0, 0, 0.64}
local POTENTIAL_COLOR = {0.29, 0.45, 1, 1}
local ACTIVE_COLOR = {0.97, 1, 0.35, 1}

local SND_DURATIONS = {9, 12, 15, 18, 21}

local defaultSettings = {
    enabled = true,
    xOffset = 0,
    yOffset = -70,
    locked = false
}

-- Create the main frame
frame:SetWidth(FRAME_WIDTH)
frame:SetHeight(FRAME_HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, -70)
frame:SetFrameStrata("MEDIUM")
frame:SetMovable(true)
frame:EnableMouse(true)

-- Background texture
local bgTexture = frame:CreateTexture(nil, "BACKGROUND")
bgTexture:SetAllPoints(frame)
bgTexture:SetTexture(0, 0, 0, BG_COLOR[4])

-- Potential duration bar (blue)
local potentialBar = CreateFrame("StatusBar", nil, frame)
potentialBar:SetAllPoints(frame)
potentialBar:SetStatusBarTexture("Interface\\AddOns\\Lateral\\Flat.tga")
potentialBar:SetStatusBarColor(unpack(POTENTIAL_COLOR))
potentialBar:SetMinMaxValues(0, 100)
potentialBar:SetValue(0)
potentialBar:Hide()

-- Active duration bar (yellow)
local activeBar = CreateFrame("StatusBar", nil, frame)
activeBar:SetAllPoints(frame)
activeBar:SetStatusBarTexture("Interface\\AddOns\\Lateral\\Flat.tga")
activeBar:SetStatusBarColor(unpack(ACTIVE_COLOR))
activeBar:SetMinMaxValues(0, 100)
activeBar:SetValue(0)
activeBar:SetFrameLevel(potentialBar:GetFrameLevel() + 1)
activeBar:Hide()

-- Potential duration text (right side)
local potentialText = activeBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
potentialText:SetPoint("RIGHT", potentialBar, "RIGHT", -5, 0)
potentialText:SetTextColor(0.16, 1, 0.01, 1)
potentialText:SetFont("Interface\\AddOns\\Lateral\\ABF.ttf", 16)
potentialText:SetDrawLayer("OVERLAY", 3) -- Higher sublevel to appear above active bar

local potentialText2 = potentialBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
potentialText2:SetPoint("RIGHT", potentialBar, "RIGHT", -5, 0)
potentialText2:SetTextColor(0.16, 1, 0.01, 1)
potentialText2:SetFont("Interface\\AddOns\\Lateral\\ABF.ttf", 16)

-- Active duration text (left side)
local activeText = activeBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
activeText:SetPoint("LEFT", activeBar, "LEFT", 5, 0)
activeText:SetTextColor(1, 1, 1, 1)
activeText:SetFont("Interface\\AddOns\\Lateral\\ABF.ttf", 16, "OUTLINE")

-- Buff tracking variables
local sliceAndDiceData = {
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

local function GetImprovedSliceAndDiceRank()
    -- Check for Improved Slice and Dice talent in Assassination tree (tab 1, talent 6)
    local tabIndex = 1
    local talentIndex = 6
    
    local name, iconTexture, tier, column, rank, maxRank = GetTalentInfo(tabIndex, talentIndex)
    return rank or 0
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

-- Track last state to reduce spam
local lastShowFrame = nil
local lastComboPoints = nil
local lastSliceAndDiceActive = nil
local updateCount = 0

local function UpdateDisplay()
    updateCount = updateCount + 1
    
    -- Check if addon is enabled
    if not LateralDB then
        frame:Hide()
        return
    end
    
    if not LateralDB.enabled then
        frame:Hide()
        return
    end
    
    -- Only show for Rogues
    if GetPlayerClass() ~= "ROGUE" then
        frame:Hide()
        return
    end
    
    local comboPoints = GetComboPointsOnTarget()
    local hasEnemy = UnitExists("target") and UnitCanAttack("player", "target")
    local timeLeft = GetSliceAndDiceTimeLeft()
    local sliceAndDiceActive = sliceAndDiceData.isActive
    
    lastComboPoints = comboPoints
    lastSliceAndDiceActive = sliceAndDiceActive
    
    local showFrame = false
    
    -- Show potential duration bar when we have combo points on an enemy
    if comboPoints > 0 and hasEnemy then
        showFrame = true
        local potentialDuration = CalculatePotentialDuration(comboPoints)
        local maxDuration = CalculateMaxDuration()
        
        potentialBar:SetMinMaxValues(0, maxDuration)
        potentialBar:SetValue(potentialDuration)
        potentialBar:Show()
        
        potentialText:SetText(string.format("%.2f", potentialDuration))
        potentialText2:SetText(string.format("%.2f", potentialDuration))
    else
        potentialBar:Hide()
        potentialText:SetText("")
        potentialText2:SetText("")
    end
    
    -- Show active duration bar when Slice and Dice is active
    if sliceAndDiceActive and timeLeft > 0 then
        showFrame = true
        local maxDuration = CalculateMaxDuration()
        
        activeBar:SetMinMaxValues(0, maxDuration)
        activeBar:SetValue(timeLeft)
        activeBar:Show()
        
        activeText:SetText(string.format("%.1f", timeLeft))
    else
        activeBar:Hide()
        activeText:SetText("")
    end
    
    -- Handle frame visibility
    if showFrame then
        frame:Show()
    else
        frame:Hide()
    end
    
    lastShowFrame = showFrame
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
        DebugPrint("ADDON_LOADED event for SliceDiceTracker!")
        
        -- Initialize Compost library
        if AceLibrary and AceLibrary:HasInstance("Compost-2.0") then
            compost = AceLibrary("Compost-2.0")
        end
        
        -- Initialize saved variables
        DebugPrint("LateralDB before init: " .. tostring(LateralDB))
        LateralDB = LateralDB or {}
        DebugPrint("LateralDB after init: " .. tostring(LateralDB))
        
        for key, value in pairs(defaultSettings) do
            if LateralDB[key] == nil then
                LateralDB[key] = value
                DebugPrint("Set " .. key .. " = " .. tostring(value))
            else
                DebugPrint("Kept existing " .. key .. " = " .. tostring(LateralDB[key]))
            end
        end
        
        -- Set position from saved variables
        frame:SetPoint("CENTER", UIParent, "CENTER", 
                      LateralDB.xOffset, LateralDB.yOffset)
        DebugPrint("Frame positioned at: " .. LateralDB.xOffset .. ", " .. LateralDB.yOffset)
        DebugPrint("Frame setup - Width: " .. frame:GetWidth() .. ", Height: " .. frame:GetHeight() .. ", Visible: " .. tostring(frame:IsVisible()))
        
        -- Print loaded message now that addon is fully initialized
        print("Lateral loaded. Type /lat for commands.")
    elseif event == "PLAYER_LOGIN" then
        DebugPrint("PLAYER_LOGIN event - Setting up OnUpdate timer with interval " .. UPDATE_INTERVAL)
        -- Set up update timer
        frame.updateTimer = 0
        frame:SetScript("OnUpdate", function()
            frame.updateTimer = frame.updateTimer + arg1
            if frame.updateTimer >= UPDATE_INTERVAL then
                UpdateDisplay()
                frame.updateTimer = 0
            end
        end)
        DebugPrint("OnUpdate script set successfully")
    end
end

-- Make frame draggable
frame:SetScript("OnMouseDown", function()
    if IsAltKeyDown() and LateralDB and not LateralDB.locked then
        frame:StartMoving()
    end
end)

frame:SetScript("OnMouseUp", function()
    frame:StopMovingOrSizing()
    if LateralDB then
        local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint()
        LateralDB.xOffset = xOfs
        LateralDB.yOffset = yOfs
    end
end)

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
    DebugPrint("Slash command called with: '" .. tostring(msg) .. "'")
    DebugPrint("LateralDB state: " .. tostring(LateralDB))
    
    if not LateralDB then
        DebugPrint("LateralDB is nil in slash command!")
        print("Slice and Dice Tracker: Not yet loaded. Please try again in a moment.")
        return
    end
    
    msg = string.lower(msg or "")
    
    if msg == "toggle" then
        LateralDB.enabled = not LateralDB.enabled
        if LateralDB.enabled then
            print("Lateral: Enabled")
        else
            print("Lateral: Disabled")
            frame:Hide()
        end
    elseif msg == "lock" then
        LateralDB.locked = true
        print("Lateral: Frame locked")
    elseif msg == "unlock" then
        LateralDB.locked = false
        print("Lateral: Frame unlocked")
    elseif msg == "reset" then
        LateralDB.xOffset = -252
        LateralDB.yOffset = -125
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -125)
        print("Lateral: Position reset")
    elseif msg == "status" then
        if sliceAndDiceData.isActive then
            print("Lateral: Slice and Dice ACTIVE - " .. math.floor(sliceAndDiceData.timeLeft) .. "s remaining")
        else
            print("Lateral: Slice and Dice INACTIVE")
        end
        local comboPoints = GetComboPoints()
        if comboPoints > 0 then
            local potential = CalculatePotentialDuration(comboPoints)
            print("  Potential with " .. comboPoints .. " combo points: " .. math.floor(potential) .. "s")
        end
        print("  Frame is " .. (LateralDB.locked and "LOCKED" or "UNLOCKED"))
    else
        print("Lateral Commands:")
        print("/lat toggle - Enable/disable the tracker")
        print("/lat lock - Lock frame position")
        print("/lat unlock - Unlock frame position")
        print("/lat reset - Reset position to center")
        print("/lat status - Show current status")
        print("Alt+drag to move the frame (when unlocked)")
    end
end
