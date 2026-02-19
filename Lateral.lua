local addonName = "Lateral"
local frame = CreateFrame("Frame", "LateralTrackerFrame", UIParent)
Lateral = Lateral or {}

local FRAME_WIDTH = 250
local FRAME_HEIGHT = 30
local FRAME_SPACING = 5
local UPDATE_INTERVAL = 0.05
local DEFAULT_FONT_SIZE = 16
local DEFAULT_PROC_ICON_SIZE = 30
local DEFAULT_PROC_TIMER_FONT_SIZE = 16
local DEFAULT_PROC_STACK_FONT_SIZE = 14
local DEFAULT_PROC_ICON_SPACING = 5
local DEFAULT_POS_X = 0
local DEFAULT_POS_Y = -148
local RUPTURE_BAR_HEIGHT = 2
local BAR_TEXTURE = "Interface\\AddOns\\Lateral\\Flat.tga"

local SND_DURATIONS = {9, 12, 15, 18, 21}
local SND_RANKS = {5171, 6774}

local RUPTURE_DURATIONS = {8, 10, 12, 14, 16}
local RUPTURE_RANKS = {1943, 8639, 8640, 11273, 11274, 11275}

local ENVENOM_DURATIONS = {12, 16, 20, 24, 28}

local EXPOSE_ARMOR_DURATION = 30
local EXPOSE_ARMOR_RANKS = {8647, 8649, 8650, 11197, 11198}

local FLOURISH_DURATIONS = {8, 10, 12, 14, 16}
local FLOURISH_RANKS = {45604}

local TRACKED_PROCCS = {
	[2983] = {}, --Sprint 1
	[8696] = {}, --Sprint 2
	[11305] = {}, --Sprint 3
	[45604] = {}, -- Flourish
	[45080] = {}, -- Molten Emberstone
	[5277] = {}, -- Evasion
	[52561] = {}, --T3.5 3pc
	[52563] = {}, --T3.5 5pc
	[28866] = {}, --Kiss of the Spider
	[29602] = { showStacks = true, stackRule = { base = 65, step = 65 } }, --Jom Gabbar
	[28777] = {}, --Slayer's Crest
	[26480] = { showStacks = true }, --Badge of the Swarmguard
	[51145] = {}, --Shieldrender Talisman
	[23726] = {}, --Venomous Totem
	[13877] = {}, --Blade Flurry
	[13750] = {}, --Adrenaline Rush
	[45425] = {}, --Potion of Quickness
	[16322] = {}, --Juju Flurry
	[26635] = {}, --Berserking
	[52540] = { showStacks = true, duration = 12 }, --Tricks of the Trade
	[14181] = { showStacks = true, duration = 30 }, --Relentless Strikes
}

local powaSurrogate = {
	[2983] = "Interface\\Icons\\Ability_Rogue_Sprint",
	[8696] = "Interface\\Icons\\Ability_Rogue_Sprint",
	[11305] = "Interface\\Icons\\Ability_Rogue_Sprint",
	[45604] = "Interface\\Icons\\Ability_DualWield",
	[45080] = "Interface\\Icons\\INV_Misc_Gem_Ruby_01",
	[5277] = "Interface\\Icons\\Spell_Shadow_ShadowWard", 
	[52540] = "Interface\\Icons\\INV_Misc_Key_03",
	[14181] = "Interface\\Icons\\Ability_Warrior_DecisiveStrike",
	[52561] = "Interface\\Icons\\Ability_Rogue_SliceDice",
	[52563] = "Interface\\Icons\\Spell_Shadow_Curse",
	[28866] = "Interface\\Icons\\INV_Trinket_Naxxramas04",
	[29602] = "Interface\\Icons\\INV_Misc_EngGizmos_19",
	[28777] = "Interface\\Icons\\INV_Trinket_Naxxramas03",
	[26480] = "Interface\\Icons\\INV_Misc_AhnQirajTrinket_04",
	[51145] = "Interface\\Icons\\INV_Misc_StoneTablet_02",
	[23726] = "Interface\\Icons\\Spell_Totem_WardOfDraining",
	[13877] = "Interface\\Icons\\Ability_Warrior_PunishingBlow",
	[13750] = "Interface\\Icons\\Spell_Shadow_ShadowWordDominate",
	[45425] = "Interface\\Icons\\INV_Potion_08",
	[16322] = "Interface\\Icons\\INV_Misc_MonsterScales_17",
	[26635] = "Interface\\Icons\\Racial_Troll_Berserk"
}

local defaultSettings = {
	enabled = true,
	debug = false,
	frameWidth = FRAME_WIDTH,
	frameHeight = FRAME_HEIGHT,
	frameSpacing = FRAME_SPACING,
	fontSize = DEFAULT_FONT_SIZE,
	procIconSize = DEFAULT_PROC_ICON_SIZE,
	procTimerFontSize = DEFAULT_PROC_TIMER_FONT_SIZE,
	procStackFontSize = DEFAULT_PROC_STACK_FONT_SIZE,
	procIconSpacing = DEFAULT_PROC_ICON_SPACING,
	potentialDecimals = 2,
	activeDecimals = 1,
	sndPotentialColor = "4A73FF",
	sndActiveColor = "F7FF59",
	tfbPotentialColor = "4AC7CF",
	tfbActiveColor = "FF3333",
	envenomPotentialColor = "CC33CC",
	envenomActiveColor = "85DE03",
	exposePotentialColor = "CCCCCC",
	exposeActiveColor = "5257A1",
	framePosX = DEFAULT_POS_X,
	framePosY = DEFAULT_POS_Y,
	ruptureBarHeight = RUPTURE_BAR_HEIGHT,
	barTexture = BAR_TEXTURE
}

local activeTalents = {
	envenom = false,
	tasteForBlood = false,
	improvedExpose = false,
	improvedBladeTactics = false,
	universalMaxDuration = 0
}

Lateral.state = Lateral.state or {}
Lateral.state.playerClass = Lateral.state.playerClass or nil
Lateral.state.comboPoints = Lateral.state.comboPoints or 0
Lateral.state.previousComboPoints = Lateral.state.previousComboPoints or 0
Lateral.state.lastComboPoints = Lateral.state.lastComboPoints or 0
Lateral.state.target = Lateral.state.target or {}
Lateral.state.target.guid = Lateral.state.target.guid or nil
Lateral.state.target.hasEnemy = Lateral.state.target.hasEnemy or false
Lateral.state.timers = Lateral.state.timers or {}
Lateral.state.timers.snd = Lateral.state.timers.snd or nil
Lateral.state.timers.tfb = Lateral.state.timers.tfb or nil
Lateral.state.timers.envenom = Lateral.state.timers.envenom or nil
Lateral.state.timers.exposeByGuid = Lateral.state.timers.exposeByGuid or {}
Lateral.state.timers.ruptureByGuid = Lateral.state.timers.ruptureByGuid or {}
Lateral.state.pending = Lateral.state.pending or {}
Lateral.state.pending.expose = Lateral.state.pending.expose or nil
Lateral.state.pending.rupture = Lateral.state.pending.rupture or nil
local trackers = {}
local procIcons = {}
local pendingProcEventState = {}

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
	if Lateral.state.comboPoints == 0 then
		return Lateral.state.previousComboPoints
	else
		return Lateral.state.comboPoints
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

local function RefreshTargetState()
	local exists, guid = UnitExists("target")
	Lateral.state.target.guid = nil
	Lateral.state.target.hasEnemy = false
	if exists then
		Lateral.state.target.guid = guid
		Lateral.state.target.hasEnemy = UnitCanAttack("player", "target") and not UnitIsDead("target")
	end
end

local function GetComboPointsOnTarget()
	if Lateral.state.target.hasEnemy then
		return Lateral.state.comboPoints or 0
	end
	return 0
end

local function RefreshComboPoints()
	local cp = 0
	if Lateral.state.target.hasEnemy then
		cp = (GetComboPoints and (GetComboPoints("target") or GetComboPoints())) or 0
		cp = cp or 0
	end
	Lateral.state.previousComboPoints = Lateral.state.comboPoints
	Lateral.state.comboPoints = cp
end

local function GetTalentRankByName(talentName)
	local talentPos = GetTalentPosition(talentName)
	if talentPos then
		
		local name, iconTexture, tier, column, rank, maxRank = GetTalentInfo(talentPos[1], talentPos[2])
		if rank ~= nil and rank > 0 then
			return rank
		else
			return nil
		end
	end
	return nil
end

local function UpdateTalentState()
	activeTalents.envenom = GetTalentRankByName("Envenom")
	activeTalents.tasteForBlood = GetTalentRankByName("Taste for Blood")
	activeTalents.improvedExpose = GetTalentRankByName("Improved Expose Armor")
	activeTalents.improvedBladeTactics = GetTalentRankByName("Improved Blade Tactics")
	-- Recompute and cache the universal max duration using current ranks
	local maxDuration = 0
	do
		local base = SND_DURATIONS[5]
		local rank = activeTalents.improvedBladeTactics or 0
		local bonus = rank * 0.15
		maxDuration = math.max(maxDuration, base * (1 + bonus))
	end
	if activeTalents.tasteForBlood then
		local base = RUPTURE_DURATIONS[5]
		local rank = activeTalents.tasteForBlood or 0
		maxDuration = math.max(maxDuration, base + (rank * 2))
	end
	if activeTalents.envenom then
		maxDuration = math.max(maxDuration, ENVENOM_DURATIONS[5])
	end
	if activeTalents.improvedExpose then
		maxDuration = math.max(maxDuration, EXPOSE_ARMOR_DURATION)
	end
	activeTalents.universalMaxDuration = maxDuration
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
	bar:SetStatusBarTexture((LateralDB and LateralDB.barTexture) or BAR_TEXTURE)
	bar:SetStatusBarColor(unpack(color))
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	if frameLevel then
		bar:SetFrameLevel(frameLevel)
	end
	bar:Hide()
	return bar
end

local function NormalizeHexColor(hex)
	if not hex then return nil end
	local s = tostring(hex)
	s = string.gsub(s, "^#", "")
	s = string.upper(s)
	if string.len(s) ~= 6 then return nil end
	if not string.find(s, "^[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]$") then
		return nil
	end
	return s
end

local function HexToRGB(hex)
	local normalized = NormalizeHexColor(hex)
	if not normalized then return nil end
	local r = tonumber(string.sub(normalized, 1, 2), 16) / 255
	local g = tonumber(string.sub(normalized, 3, 4), 16) / 255
	local b = tonumber(string.sub(normalized, 5, 6), 16) / 255
	return r, g, b
end

local function RGBToHex(r, g, b)
	local function toHex(v)
		local n = math.floor((tonumber(v) or 0) * 255 + 0.5)
		if n < 0 then n = 0 end
		if n > 255 then n = 255 end
		return string.format("%02X", n)
	end
	return toHex(r) .. toHex(g) .. toHex(b)
end

local function ClampDecimals(value)
	local n = tonumber(value) or 0
	n = math.floor(n + 0.5)
	if n < 0 then n = 0 end
	if n > 3 then n = 3 end
	return n
end

local function GetDurationFormat(isPotential)
	local decimals = isPotential and ((LateralDB and LateralDB.potentialDecimals) or 2) or ((LateralDB and LateralDB.activeDecimals) or 1)
	decimals = ClampDecimals(decimals)
	return "%." .. tostring(decimals) .. "f"
end

local function FormatDuration(value, isPotential)
	return string.format(GetDurationFormat(isPotential), tonumber(value) or 0)
end

local function RunNamChecks()
	if not Nampower then
		LatPrint("Nampower unavailable. Please review https://github.com/Carravan/Lateral/blob/main/README.md")
		return
	end

	if not Nampower:HasMinimumVersion(2, 33, 0) then
		LatPrint("Nampower version too old. Please review https://github.com/Carravan/Lateral/blob/main/README.md")
		return
	end

	local requiredCVars = {
		"NP_EnableSpellStartEvents",
		"NP_EnableAuraCastEvents",
	}
	for _, cvarName in ipairs(requiredCVars) do
		local current = GetCVar(cvarName)
		if tostring(current) ~= "1" then
			SetCVar(cvarName, "1")
		end
	end
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
-- Create Rupture (target debuff) thin bar under TFB
trackers.tfb.ruptureBar = CreateFrame("StatusBar", nil, trackers.tfb.frame)
trackers.tfb.ruptureBar:SetMinMaxValues(0, 100)
trackers.tfb.ruptureBar:SetValue(0)
trackers.tfb.ruptureBar:ClearAllPoints()
trackers.tfb.ruptureBar:SetPoint("BOTTOMLEFT", trackers.tfb.frame, "BOTTOMLEFT", 0, 0)
trackers.tfb.ruptureBar:SetPoint("BOTTOMRIGHT", trackers.tfb.frame, "BOTTOMRIGHT", 0, 0)
trackers.tfb.ruptureBar:SetFrameLevel(trackers.tfb.activeBar:GetFrameLevel() + 1)
trackers.tfb.ruptureBar:Hide()

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

-- Proc icon helpers (above snd bar, anchored to LateralTrackerFrame)
local function GetProcIconPath(key)
	local p = powaSurrogate and powaSurrogate[key]
	return p or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function HasActiveProcs()
	for _, meta in pairs(procIcons) do
		if (meta.ends and (meta.ends - GetTime()) > 0) or meta.binaryActive then
			return true
		end
	end
	return false
end

local function DrawProcIcon(key)
	local meta = procIcons[key]
	if meta and meta.frame then return meta end

	local size = (LateralDB and LateralDB.procIconSize) or DEFAULT_PROC_ICON_SIZE
	local f = CreateFrame("Frame", nil, LateralTrackerFrame)
	f:SetWidth(size)
	f:SetHeight(size)
	f:SetFrameStrata("MEDIUM")
	f:SetFrameLevel(trackers.snd.frame:GetFrameLevel() + 5)

	local tex = f:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints(f)
	tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	tex:SetTexture(GetProcIconPath(key))

	local timeText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	timeText:SetPoint("CENTER", f, "CENTER", 0, 0)
	timeText:SetFont("Interface\\AddOns\\Lateral\\ABF.ttf", (LateralDB and LateralDB.procTimerFontSize) or DEFAULT_PROC_TIMER_FONT_SIZE, "OUTLINE")
	timeText:SetTextColor(1, 1, 1, 1)
	timeText:SetDrawLayer("OVERLAY", 3)

	local stackText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	stackText:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	stackText:SetFont("Interface\\AddOns\\Lateral\\ABF.ttf", (LateralDB and LateralDB.procStackFontSize) or DEFAULT_PROC_STACK_FONT_SIZE, "OUTLINE")
	stackText:SetTextColor(1, 0.85, 0, 1)
	stackText:SetText("")
	stackText:SetDrawLayer("OVERLAY", 4)

	procIcons[key] = { frame = f, texture = tex, timeText = timeText, stackText = stackText, starts = 0, ends = 0, stacks = nil, stackCount = nil, stackRule = nil, iconKey = key, fullDuration = nil, showStacks = false }
	return procIcons[key]
end

local function LayoutProcIcons()
	local size = (LateralDB and LateralDB.procIconSize) or DEFAULT_PROC_ICON_SIZE
	local spacing = ((LateralDB and LateralDB.procIconSpacing) or DEFAULT_PROC_ICON_SPACING)
	local index = 0
	for _, meta in pairs(procIcons) do
		if meta.frame then meta.frame:Hide() end
	end
	local now = GetTime()
	local activeKeys = {}
	for key, meta in pairs(procIcons) do
		if meta and ((meta.ends and (meta.ends - now) > 0) or meta.binaryActive) then
			table.insert(activeKeys, key)
		end
	end
	table.sort(activeKeys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for i = 1, table.getn(activeKeys) do
		local key = activeKeys[i]
		local meta = procIcons[key]
		if meta and meta.frame and ((meta.ends and (meta.ends - GetTime()) > 0) or meta.binaryActive) then
			meta.frame:ClearAllPoints()
			meta.frame:SetPoint("BOTTOMLEFT", trackers.snd.frame, "TOPLEFT", index * (size + spacing), spacing)
			meta.frame:Show()
			index = index + 1
		end
	end
end

local function SetBinaryProcActive(key, active)
	local meta = DrawProcIcon(key)
	meta.binaryActive = active and true or false
	meta.fullDuration = nil
	meta.starts = 0
	meta.ends = 0
	if meta.timeText then meta.timeText:SetText("") end
	if meta.stackText then meta.stackText:SetText(""); meta.stackText:Hide() end
	if meta.binaryActive then
		meta.frame:Show()
	else
		if meta.frame then meta.frame:Hide() end
	end
	LayoutProcIcons()
end

local function ResetAllProcIcons()
	for _, meta in pairs(procIcons) do
		meta.starts = 0
		meta.ends = 0
		meta.stacks = nil
		meta.stackCount = nil
		meta.stackRule = nil
		meta.binaryActive = false
		meta.fullDuration = nil
		if meta.timeText then meta.timeText:SetText("") end
		if meta.stackText then meta.stackText:SetText(""); meta.stackText:Hide() end
		if meta.frame then meta.frame:Hide() end
	end
	LayoutProcIcons()
end

local function ResizeProcIcons()
	local size = (LateralDB and LateralDB.procIconSize) or DEFAULT_PROC_ICON_SIZE
	local timerFont = (LateralDB and LateralDB.procTimerFontSize) or DEFAULT_PROC_TIMER_FONT_SIZE
	local stackFont = (LateralDB and LateralDB.procStackFontSize) or DEFAULT_PROC_STACK_FONT_SIZE
	for _, meta in pairs(procIcons) do
		if meta.frame then
			meta.frame:SetWidth(size)
			meta.frame:SetHeight(size)
			if meta.timeText then
				meta.timeText:SetFont("Interface\\AddOns\\Lateral\\ABF.ttf", timerFont, "OUTLINE")
			end
			if meta.stackText then
				meta.stackText:SetFont("Interface\\AddOns\\Lateral\\ABF.ttf", stackFont, "OUTLINE")
			end
		end
	end
	LayoutProcIcons()
end

local function ProcConfigUsesStacks(cfg)
	if not cfg then return false end
	return (cfg.showStacks and true or false) or (type(cfg.stackRule) == "table")
end

local function ApplyProcStackDisplay(meta, rawStackCount)
	if not meta or not meta.showStacks then
		if meta and meta.stackText then
			meta.stackText:SetText("")
			meta.stackText:Hide()
		end
		return
	end

	local value = rawStackCount
	if meta.stackRule and type(meta.stackRule) == "table" then
		local count = tonumber(rawStackCount) or 0
		local base = tonumber(meta.stackRule.base) or 0
		local step = tonumber(meta.stackRule.step) or 0
		if count <= 0 then
			value = 0
		elseif step ~= 0 then
			value = base + ((count - 1) * step)
		else
			value = count
		end
		if meta.stackRule.max then
			local maxv = tonumber(meta.stackRule.max)
			if maxv and value > maxv then value = maxv end
		end
	end

	meta.stackCount = tonumber(rawStackCount) or 0
	meta.stacks = value
	if meta.stackText then
		meta.stackText:SetText(tostring(value or ""))
		if value and tonumber(value) and tonumber(value) > 0 then
			meta.stackText:Show()
		else
			meta.stackText:Hide()
		end
	end
end

local function StartOrRefreshProc(key, absoluteEnds, cfg)
	if not key or not absoluteEnds then return end
	local meta = DrawProcIcon(key)
	local now = GetTime()
	meta.starts = now
	meta.ends = absoluteEnds
	meta.fullDuration = absoluteEnds - now
	if meta.fullDuration and meta.fullDuration <= 0 then
		meta.fullDuration = nil
	end
	meta.binaryActive = false
	meta.stackRule = cfg and cfg.stackRule or nil
	meta.showStacks = ProcConfigUsesStacks(cfg)
	meta.texture:SetTexture(GetProcIconPath(key))
	if meta.showStacks then
		ApplyProcStackDisplay(meta, meta.stackCount)
	else
		meta.stacks = nil
		meta.stackCount = nil
		meta.stackText:SetText("")
		meta.stackText:Hide()
	end
	meta.frame:Show()
	LayoutProcIcons()
end

local function RemoveProcByKey(key)
	local meta = procIcons[key]
	if not meta then return end
	meta.starts = 0
	meta.ends = 0
	meta.stacks = nil
	meta.stackCount = nil
	meta.stackRule = nil
	meta.binaryActive = false
	meta.fullDuration = nil
	meta.showStacks = false
	if meta.timeText then meta.timeText:SetText("") end
	if meta.stackText then meta.stackText:SetText(""); meta.stackText:Hide() end
	if meta.frame then meta.frame:Hide() end
	LayoutProcIcons()
end

local function RefreshProcByKey(key)
	local meta = procIcons[key]
	if not meta then return end
	if meta.fullDuration and meta.fullDuration > 0 then
		local now = GetTime()
		meta.starts = now
		meta.ends = now + meta.fullDuration
		meta.binaryActive = false
		if meta.frame then meta.frame:Show() end
		ApplyProcStackDisplay(meta, meta.stackCount)
		LayoutProcIcons()
	end
end

local function UpdateProcStacksByAura(spellId, stackCount)
	local cfg = TRACKED_PROCCS[spellId]
	if not cfg then return end
	local meta = procIcons[spellId]
	if not meta then
		meta = DrawProcIcon(spellId)
	end
	meta.stackRule = cfg and cfg.stackRule or nil
	meta.showStacks = ProcConfigUsesStacks(cfg)
	meta.texture:SetTexture(GetProcIconPath(spellId))
	ApplyProcStackDisplay(meta, stackCount)
end

local function GetOrCreatePendingProcState(spellId)
	local p = pendingProcEventState[spellId]
	if not p then
		p = { durationSec = nil, stackCount = nil, binary = false }
		pendingProcEventState[spellId] = p
	end
	return p
end

local function ClearPendingProcState(spellId)
	if spellId then
		pendingProcEventState[spellId] = nil
	end
end

local function TryActivateProcFromPending(spellId)
	local cfg = TRACKED_PROCCS[spellId]
	local pending = pendingProcEventState[spellId]
	if not cfg or not pending then return end
	local meta = procIcons[spellId]
	if not meta then
		meta = DrawProcIcon(spellId)
	end
	meta.stackRule = cfg and cfg.stackRule or nil
	meta.showStacks = ProcConfigUsesStacks(cfg)
	meta.texture:SetTexture(GetProcIconPath(spellId))

	if pending.binary then
		SetBinaryProcActive(spellId, true)
		return
	end

	if not pending.durationSec or pending.durationSec <= 0 then
		return
	end

	local needsStacks = ProcConfigUsesStacks(cfg)
	if needsStacks and pending.stackCount == nil then
		return
	end

	StartOrRefreshProc(spellId, GetTime() + pending.durationSec, cfg)
	if needsStacks then
		UpdateProcStacksByAura(spellId, pending.stackCount)
	end
end

local function UpdateProcIcons()
	local now = GetTime()
	for key, meta in pairs(procIcons) do
		if meta.ends and (meta.ends - now) > 0 then
			local remain = meta.ends - now
			if remain < 0 then remain = 0 end
			meta.timeText:SetText(string.format("%.1f", remain))
			ApplyProcStackDisplay(meta, meta.stackCount)
			meta.frame:Show()
		elseif meta.binaryActive then
			if meta.timeText then meta.timeText:SetText("") end
			if meta.stackText then meta.stackText:SetText(""); meta.stackText:Hide() end
			meta.frame:Show()
		else
			if meta.frame then meta.frame:Hide() end
		end
	end
	LayoutProcIcons()
end

function Lateral_UpdateProcIcons()
	UpdateProcIcons()
end

function Lateral_OnUpdate()
	Lateral.updateTimer = (Lateral.updateTimer or 0) + arg1
	if Lateral.updateTimer >= UPDATE_INTERVAL then
		if Lateral.state.pending.expose and GetTime() >= Lateral.state.pending.expose.applyAt then
			Lateral.state.timers.exposeByGuid[Lateral.state.pending.expose.guid] = { starts = GetTime(), ends = GetTime() + EXPOSE_ARMOR_DURATION }
			Lateral.state.pending.expose = nil
		end
		if Lateral.state.pending.rupture and GetTime() >= Lateral.state.pending.rupture.applyAt then
			Lateral.state.timers.ruptureByGuid[Lateral.state.pending.rupture.guid] = { starts = GetTime(), ends = GetTime() + (Lateral.state.pending.rupture.duration or 0) }
			Lateral.state.pending.rupture = nil
		end
		Lateral_UpdateProcIcons()
		Lateral_UpdateDisplay()
		Lateral.updateTimer = 0
	end
end

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
	-- Rupture bar height
	if trackers.tfb and trackers.tfb.ruptureBar then
		local rbHeight = tonumber(LateralDB.ruptureBarHeight or RUPTURE_BAR_HEIGHT)
		if rbHeight < 0 then rbHeight = 0 end
		trackers.tfb.ruptureBar:SetHeight(rbHeight)
		if rbHeight == 0 then trackers.tfb.ruptureBar:Hide() end
	end
	ResizeProcIcons()
end

-- Explicitly re-apply the configured texture to all status bars
local function ApplyTextureToAllBars()
	if not LateralDB then return end
	local tex = LateralDB.barTexture or BAR_TEXTURE
	if trackers and trackers.snd then
		if trackers.snd.potentialBar then trackers.snd.potentialBar:SetStatusBarTexture(tex) end
		if trackers.snd.activeBar then trackers.snd.activeBar:SetStatusBarTexture(tex) end
	end
	if trackers and trackers.tfb then
		if trackers.tfb.potentialBar then trackers.tfb.potentialBar:SetStatusBarTexture(tex) end
		if trackers.tfb.activeBar then trackers.tfb.activeBar:SetStatusBarTexture(tex) end
	end
	if trackers and trackers.envenom then
		if trackers.envenom.potentialBar then trackers.envenom.potentialBar:SetStatusBarTexture(tex) end
		if trackers.envenom.activeBar then trackers.envenom.activeBar:SetStatusBarTexture(tex) end
	end
	if trackers and trackers.expose then
		if trackers.expose.potentialBar then trackers.expose.potentialBar:SetStatusBarTexture(tex) end
		if trackers.expose.activeBar then trackers.expose.activeBar:SetStatusBarTexture(tex) end
	end
end

local function ApplyBarColors()
	if not LateralDB then return end
	local function ApplyColor(bar, key, fallback)
		if not bar then return end
		local r, g, b = HexToRGB(LateralDB[key])
		if not r then
			r, g, b = unpack(fallback)
		end
		bar:SetStatusBarColor(r, g, b, 1)
	end

	ApplyColor(trackers.snd and trackers.snd.potentialBar, "sndPotentialColor", {0.29, 0.45, 1})
	ApplyColor(trackers.snd and trackers.snd.activeBar, "sndActiveColor", {0.97, 1, 0.35})
	ApplyColor(trackers.tfb and trackers.tfb.potentialBar, "tfbPotentialColor", {0.29, 0.78, 0.81})
	ApplyColor(trackers.tfb and trackers.tfb.activeBar, "tfbActiveColor", {1, 0.2, 0.2})
	ApplyColor(trackers.envenom and trackers.envenom.potentialBar, "envenomPotentialColor", {0.8, 0.2, 0.8})
	ApplyColor(trackers.envenom and trackers.envenom.activeBar, "envenomActiveColor", {0.52, 0.87, 0.01})
	ApplyColor(trackers.expose and trackers.expose.potentialBar, "exposePotentialColor", {0.8, 0.8, 0.8})
	ApplyColor(trackers.expose and trackers.expose.activeBar, "exposeActiveColor", {0.32, 0.34, 0.63})
end

local function CalculatePotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = SND_DURATIONS[comboPoints]
	local talentRank = activeTalents.improvedBladeTactics or 0
	local talentBonus = talentRank * 0.15
	local finalDuration = baseDuration * (1 + talentBonus)
	return finalDuration
end

local function CalculateTasteForBloodPotentialDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end
	
	local baseDuration = RUPTURE_DURATIONS[comboPoints]
	local talentRank = activeTalents.tasteForBlood or 0
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

local function CalculateFlourishDuration(comboPoints)
	if not comboPoints or comboPoints == 0 then
		return 0
	end

	local baseDuration = FLOURISH_DURATIONS[comboPoints]
	local talentRank = activeTalents.improvedBladeTactics or 0
	local talentBonus = talentRank * 0.15
	return baseDuration * (1 + talentBonus)
end

local function GetExposeArmorTimeLeftForTarget()
    local guid = Lateral.state.target.guid
    if not guid then return 0, false end
    local timer = Lateral.state.timers.exposeByGuid[guid]
    if timer and timer.ends then
        local remaining = timer.ends - GetTime()
        if remaining > 0 then
            return remaining, true
        end
    end
    return 0, false
end

local function GetRuptureTimeLeftForTarget()
    local guid = Lateral.state.target.guid
    if not guid then return 0, false end
    local timer = Lateral.state.timers.ruptureByGuid[guid]
    if timer and timer.ends then
        local remaining = timer.ends - GetTime()
        if remaining > 0 then
            return remaining, true
        end
    end
    return 0, false
end

local function GetRemainingFromTimer(timer)
	if not timer or not timer.ends then return 0 end
	local remaining = timer.ends - GetTime()
	if remaining > 0 then
		return remaining
	end
	return 0
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
	
	if Lateral.state.playerClass ~= "ROGUE" then
		trackers.snd.frame:Hide()
		trackers.tfb.frame:Hide()
		trackers.envenom.frame:Hide()
		trackers.expose.frame:Hide()
		return
	end
	
	local comboPoints = GetComboPointsOnTarget()
	local hasEnemy = Lateral.state.target.hasEnemy
	
	local sliceAndDiceActive = false
	local eventTimeLeft = 0
	if Lateral.state.timers.snd and Lateral.state.timers.snd.ends then
		eventTimeLeft = Lateral.state.timers.snd.ends - GetTime()
		if eventTimeLeft < 0 then eventTimeLeft = 0 end
		if eventTimeLeft == 0 then Lateral.state.timers.snd = nil end
	end
	local timeLeft = eventTimeLeft
	if timeLeft > 0 then sliceAndDiceActive = true end

	local tfbTimeLeft, tasteForBloodActive = 0, false
	if activeTalents.tasteForBlood and Lateral.state.timers.tfb and Lateral.state.timers.tfb.ends then
		tfbTimeLeft = Lateral.state.timers.tfb.ends - GetTime()
		if tfbTimeLeft < 0 then tfbTimeLeft = 0 end
		if tfbTimeLeft == 0 then Lateral.state.timers.tfb = nil else tasteForBloodActive = true end
	end

	local envenomTimeLeft, envenomActive = 0, false
	if activeTalents.envenom and Lateral.state.timers.envenom and Lateral.state.timers.envenom.ends then
		envenomTimeLeft = Lateral.state.timers.envenom.ends - GetTime()
		if envenomTimeLeft < 0 then envenomTimeLeft = 0 end
		if envenomTimeLeft == 0 then Lateral.state.timers.envenom = nil else envenomActive = true end
	end

	local exposeTimeLeft, exposeActive = 0, false
		if activeTalents.improvedExpose then
			exposeTimeLeft, exposeActive = GetExposeArmorTimeLeftForTarget()
		end
	
	local ruptureTimeLeft, ruptureActive = 0, false
	if activeTalents.tasteForBlood then
		ruptureTimeLeft, ruptureActive = GetRuptureTimeLeftForTarget()
	end
	
	Lateral.state.lastComboPoints = comboPoints
	
	local hasProcs = HasActiveProcs()
	local shouldShowBars = hasProcs or (comboPoints > 0 and hasEnemy) or sliceAndDiceActive or (activeTalents.tasteForBlood and tasteForBloodActive) or (activeTalents.envenom and envenomActive) or (activeTalents.improvedExpose and exposeActive)
	
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
	
	local universalMaxDuration = activeTalents.universalMaxDuration or 0
	
	if comboPoints > 0 and hasEnemy then
		local potentialDuration = CalculatePotentialDuration(comboPoints)
		trackers.snd.potentialBar:SetMinMaxValues(0, universalMaxDuration)
		trackers.snd.potentialBar:SetValue(potentialDuration)
		trackers.snd.potentialBar:Show()
		trackers.snd.potentialText:SetText(FormatDuration(potentialDuration, true))
		trackers.snd.potentialText2:SetText(FormatDuration(potentialDuration, true))
	else
		trackers.snd.potentialBar:Hide()
		trackers.snd.potentialText:SetText("")
		trackers.snd.potentialText2:SetText("")
	end
	
	if sliceAndDiceActive and timeLeft > 0 then
		trackers.snd.activeBar:SetMinMaxValues(0, universalMaxDuration)
		trackers.snd.activeBar:SetValue(timeLeft)
		trackers.snd.activeBar:Show()
		trackers.snd.activeText:SetText(FormatDuration(timeLeft, false))
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
			trackers.tfb.potentialText:SetText(FormatDuration(tfbPotentialDuration, true))
			trackers.tfb.potentialText2:SetText(FormatDuration(tfbPotentialDuration, true))
		else
			trackers.tfb.potentialBar:Hide()
			trackers.tfb.potentialText:SetText("")
			trackers.tfb.potentialText2:SetText("")
		end

		if tasteForBloodActive and tfbTimeLeft > 0 then
			trackers.tfb.activeBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.tfb.activeBar:SetValue(tfbTimeLeft)
			trackers.tfb.activeBar:Show()
			trackers.tfb.activeText:SetText(FormatDuration(tfbTimeLeft, false))
			local cpForTfb = (Lateral.state.timers.tfb and Lateral.state.timers.tfb.cp) or Lateral.state.lastComboPoints or comboPoints or 0
			if cpForTfb < 1 then cpForTfb = 1 end
			if cpForTfb > 5 then cpForTfb = 5 end
			local percent = cpForTfb * activeTalents.tasteForBlood
			if trackers.tfb.centerText then
				trackers.tfb.centerText:SetText(string.format("%d%%", percent))
				trackers.tfb.centerText:Show()
			end
			-- Rupture landed bar
			if ruptureActive and ruptureTimeLeft > 0 and trackers.tfb.ruptureBar then
				local rbHeight = (LateralDB and tonumber(LateralDB.ruptureBarHeight or RUPTURE_BAR_HEIGHT))
				if rbHeight > 0 then 
					trackers.tfb.ruptureBar:SetMinMaxValues(0, universalMaxDuration)
					if ruptureTimeLeft > 2  then 
						trackers.tfb.ruptureBar:SetStatusBarColor(1, 1, 1, 1)
						trackers.tfb.ruptureBar:SetStatusBarTexture("Interface\\AddOns\\Lateral\\Flat.tga")
					else
						trackers.tfb.ruptureBar:SetStatusBarColor(0, 1, 0, 1)
						trackers.tfb.ruptureBar:SetStatusBarTexture("Interface\\AddOns\\Lateral\\Solid.tga")
					end
					trackers.tfb.ruptureBar:SetValue(ruptureTimeLeft)
					trackers.tfb.ruptureBar:Show()
				else
					trackers.tfb.ruptureBar:Hide()
				end
			else
				if trackers.tfb.ruptureBar then trackers.tfb.ruptureBar:Hide() end
			end
		else
			trackers.tfb.activeBar:Hide()
			trackers.tfb.activeText:SetText("")
			if trackers.tfb.centerText then
				trackers.tfb.centerText:SetText("")
				trackers.tfb.centerText:Hide()
			end
			if trackers.tfb.ruptureBar then trackers.tfb.ruptureBar:Hide() end
		end
	else
		trackers.tfb.potentialBar:Hide()
		trackers.tfb.activeBar:Hide()
		trackers.tfb.potentialText:SetText("")
		trackers.tfb.potentialText2:SetText("")
		trackers.tfb.activeText:SetText("")
		if trackers.tfb.ruptureBar then trackers.tfb.ruptureBar:Hide() end
	end
	
	if activeTalents.envenom then
		if comboPoints > 0 and hasEnemy then
			local envenomPotentialDuration = CalculateEnvenomPotentialDuration(comboPoints)
			trackers.envenom.potentialBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.envenom.potentialBar:SetValue(envenomPotentialDuration)
			trackers.envenom.potentialBar:Show()
			trackers.envenom.potentialText:SetText(FormatDuration(envenomPotentialDuration, true))
			trackers.envenom.potentialText2:SetText(FormatDuration(envenomPotentialDuration, true))
		else
			trackers.envenom.potentialBar:Hide()
			trackers.envenom.potentialText:SetText("")
			trackers.envenom.potentialText2:SetText("")
		end

		if envenomActive and envenomTimeLeft > 0 then
			trackers.envenom.activeBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.envenom.activeBar:SetValue(envenomTimeLeft)
			trackers.envenom.activeBar:Show()
			trackers.envenom.activeText:SetText(FormatDuration(envenomTimeLeft, false))
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
			trackers.expose.potentialText:SetText(FormatDuration(exposePotential, true))
			trackers.expose.potentialText2:SetText(FormatDuration(exposePotential, true))
		else
			trackers.expose.potentialBar:Hide()
			trackers.expose.potentialText:SetText("")
			trackers.expose.potentialText2:SetText("")
		end

		if exposeActive and exposeTimeLeft > 0 then
			trackers.expose.activeBar:SetMinMaxValues(0, universalMaxDuration)
			trackers.expose.activeBar:SetValue(exposeTimeLeft)
			trackers.expose.activeBar:Show()
			trackers.expose.activeText:SetText(FormatDuration(exposeTimeLeft, false))
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

function Lateral_UpdateDisplay()
	UpdateDisplay()
end

-- Public functions for other addons/macros
function LateralSnD()
	return GetRemainingFromTimer(Lateral.state.timers.snd)
end

function LateralTfB()
	return GetRemainingFromTimer(Lateral.state.timers.tfb)
end

function LateralEnvenom()
	return GetRemainingFromTimer(Lateral.state.timers.envenom)
end

function LateralRupture()
	local remaining = GetRuptureTimeLeftForTarget()
	return remaining or 0
end

function LateralIEA()
	local remaining = GetExposeArmorTimeLeftForTarget()
	return remaining or 0
end

function LateralCP()
	return Lateral.state.comboPoints or 0
end

-- Event handling
local handlers = {}

handlers.PLAYER_TARGET_CHANGED = function(self)
	RefreshTargetState()
	RefreshComboPoints()
	if LateralDB then UpdateDisplay() end
end

handlers.PLAYER_COMBO_POINTS = function(self)
	RefreshTargetState()
	RefreshComboPoints()
	if LateralDB then UpdateDisplay() end
end

handlers.PLAYER_DEAD = function(self)
	Lateral.state.comboPoints = 0
	Lateral.state.previousComboPoints = 0
	Lateral.state.target.hasEnemy = false
	Lateral.state.target.guid = nil
	ResetAllProcIcons()
	if LateralDB then UpdateDisplay() end
end

handlers.SPELL_START_SELF = function(self)
	-- args: itemId, spellId, casterGuid, targetGuid, castFlags, numTargetsHit, numTargetsMissed
	local spellId, targetGUID = arg2, arg4
	if LateralDB and LateralDB.debug and spellId then
		LatPrint(string.format("DEBUG: %s | %s", tostring(targetGUID), tostring(spellId)))
	end

	-- Expose Armor
	if has_value(EXPOSE_ARMOR_RANKS, spellId) and targetGUID then
		local delay = 0.2
		local _, _, nping = GetNetStats()
		if nping and nping > 0 and nping < 500 then
			delay = 0.05 + (nping / 1000.0)
		end
		Lateral.state.pending.expose = { guid = targetGUID, applyAt = GetTime() + delay }
	end

	-- Slice and Dice
	if has_value(SND_RANKS, spellId) then
		local cpUsed = GetComboPointsUsed() or 0
		if cpUsed < 1 then cpUsed = 1 end
		if cpUsed > 5 then cpUsed = 5 end
		local duration = CalculatePotentialDuration(cpUsed)
		Lateral.state.timers.snd = { starts = GetTime(), ends = GetTime() + duration }
	end

	-- Envenom
	if spellId == 52531 and activeTalents.envenom then
		local cpUsed = GetComboPointsUsed() or 0
		if cpUsed < 1 then cpUsed = 1 end
		if cpUsed > 5 then cpUsed = 5 end
		local duration = CalculateEnvenomPotentialDuration(cpUsed)
		Lateral.state.timers.envenom = { starts = GetTime(), ends = GetTime() + duration }
	end

	-- Taste for Blood
	if has_value(RUPTURE_RANKS, spellId) and activeTalents.tasteForBlood then
		local cpUsed = GetComboPointsUsed() or 0
		if cpUsed < 1 then cpUsed = 1 end
		if cpUsed > 5 then cpUsed = 5 end
		local duration = CalculateTasteForBloodPotentialDuration(cpUsed)
		Lateral.state.timers.tfb = { starts = GetTime(), ends = GetTime() + duration, cp = cpUsed }

		if targetGUID then
			local delay = 0.2
			local _, _, nping = GetNetStats()
			if nping and nping > 0 and nping < 500 then
				delay = 0.05 + (nping / 1000.0)
			end
			Lateral.state.pending.rupture = { guid = targetGUID, applyAt = GetTime() + delay, duration = duration }
		end
	end

	-- Flourish
	if has_value(FLOURISH_RANKS, spellId) then
		local cpUsed = GetComboPointsUsed() or 0
		if cpUsed < 1 then cpUsed = 1 end
		if cpUsed > 5 then cpUsed = 5 end
		local duration = CalculateFlourishDuration(cpUsed)
		if duration and duration > 0 then
			StartOrRefreshProc(spellId, GetTime() + duration, TRACKED_PROCCS[spellId])
		end
	end

end

handlers.SPELL_MISS_SELF = function(self)
	-- args: casterGuid, targetGuid, spellId, missInfo
	local spellId = arg3
	if has_value(EXPOSE_ARMOR_RANKS, spellId) then
		if Lateral.state.pending.expose then Lateral.state.pending.expose = nil end
	end
	if has_value(RUPTURE_RANKS, spellId) then
		if Lateral.state.pending.rupture then Lateral.state.pending.rupture = nil end
	end
end

handlers.AURA_CAST_ON_SELF = function(self)
	-- args: spellId, casterGuid, targetGuid, effect, effectAuraName, effectAmplitude, effectMiscValue, durationMs, auraCapStatus
	local spellId, durationMs = arg1, arg8
	if spellId and has_value(FLOURISH_RANKS, spellId) then
		return
	end
	if TRACKED_PROCCS[spellId] then
		local cfg = TRACKED_PROCCS[spellId]
		local pending = GetOrCreatePendingProcState(spellId)
		if durationMs and durationMs == -1 then
			pending.binary = true
			pending.durationSec = nil
			TryActivateProcFromPending(spellId)
			return
		end
		if not durationMs or durationMs <= 0 then return end
		pending.binary = false
		pending.durationSec = durationMs / 1000

		if ProcConfigUsesStacks(cfg) and pending.stackCount == nil then
			pending.stackCount = 1
		end
		TryActivateProcFromPending(spellId)
		return
	end
end

handlers.BUFF_UPDATE_DURATION_SELF = function(self)
	-- args: auraSlot, durationMs, expirationTimeMs, spellId
	local durationMs, spellId = arg2, arg4
	if spellId and has_value(FLOURISH_RANKS, spellId) then
		return
	end
	if spellId and TRACKED_PROCCS[spellId] then
		local cfg = TRACKED_PROCCS[spellId]
		local pending = GetOrCreatePendingProcState(spellId)
		if cfg and cfg.duration and cfg.duration > 0 then
			pending.binary = false
			pending.durationSec = cfg.duration
		elseif durationMs and durationMs > 0 then
			pending.binary = false
			pending.durationSec = durationMs / 1000
		end
		RefreshProcByKey(spellId)
		TryActivateProcFromPending(spellId)
	end
end

handlers.BUFF_ADDED_SELF = function(self)
	-- args: guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state
	local spellId, stackCount = arg3, arg4
	if spellId and has_value(FLOURISH_RANKS, spellId) then
		return
	end
	if spellId and TRACKED_PROCCS[spellId] then
		local cfg = TRACKED_PROCCS[spellId]
		local pending = GetOrCreatePendingProcState(spellId)
		pending.stackCount = stackCount
		-- Some procs do not fire AURA_CAST_ON_SELF. For those, use configured duration.
		if cfg and cfg.duration and cfg.duration > 0 then
			pending.binary = false
			pending.durationSec = cfg.duration
		end
		UpdateProcStacksByAura(spellId, stackCount)
		TryActivateProcFromPending(spellId)
	end
end

handlers.BUFF_REMOVED_SELF = function(self)
	-- args: guid, luaSlot, spellId, stackCount, auraLevel, auraSlot, state
	local spellId = arg3
	if spellId and TRACKED_PROCCS[spellId] then
		RemoveProcByKey(spellId)
		ClearPendingProcState(spellId)
	end
end

handlers.UNIT_DIED = function(self)
	local guid = arg1
	if guid then
		if Lateral.state.timers.exposeByGuid[guid] then
			Lateral.state.timers.exposeByGuid[guid] = nil
			if LateralDB then UpdateDisplay() end
		end
		if Lateral.state.timers.ruptureByGuid[guid] then
			Lateral.state.timers.ruptureByGuid[guid] = nil
			if LateralDB then UpdateDisplay() end
		end
		if Lateral.state.target.guid == guid then
			Lateral.state.target.hasEnemy = false
			Lateral.state.comboPoints = 0
		end
	end
end

handlers.ADDON_LOADED = function(self)
	local loadedName = arg1
	if loadedName ~= addonName then return end
	LateralDB = LateralDB or {}
	for key, value in pairs(defaultSettings) do
		if LateralDB[key] == nil then
			LateralDB[key] = value
		end
	end
	local _, class = UnitClass("player")
	Lateral.state.playerClass = class

	UpdateTalentState()
	RefreshTargetState()
	RefreshComboPoints()

	trackers.snd.frame:ClearAllPoints()
	ApplyLayoutSettings()
	ApplyTextureToAllBars()
	ApplyBarColors()

	trackers.tfb.frame:ClearAllPoints()
	trackers.tfb.frame:SetPoint("TOP", trackers.snd.frame, "BOTTOM", 0, -(LateralDB.frameSpacing or FRAME_SPACING))

	trackers.envenom.frame:ClearAllPoints()
	trackers.envenom.frame:SetPoint("TOP", trackers.tfb.frame, "BOTTOM", 0, -(LateralDB.frameSpacing or FRAME_SPACING))

	trackers.expose.frame:ClearAllPoints()
	trackers.expose.frame:SetPoint("TOP", trackers.envenom.frame, "BOTTOM", 0, -(LateralDB.frameSpacing or FRAME_SPACING))
	LatPrint("Lateral loaded. Type /lat to open settings.")
end

handlers.LEARNED_SPELL_IN_TAB = function(self)
	UpdateTalentState()
	if LateralDB then UpdateDisplay() end
end

handlers.PLAYER_ENTER_COMBAT = handlers.LEARNED_SPELL_IN_TAB

local function SyncPersistentProcsOnWorldEntry()
	local seen = {}
	for auraSlot = 0, 31 do
		local spellId, remainingDurationMs, expirationTimeMs = GetPlayerAuraDuration(auraSlot)
		if spellId and TRACKED_PROCCS[spellId] then
			seen[spellId] = true
			local cfg = TRACKED_PROCCS[spellId]
			if remainingDurationMs and remainingDurationMs > 0 then
				StartOrRefreshProc(spellId, GetTime() + (remainingDurationMs / 1000), cfg)
			elseif remainingDurationMs == 0 then
				SetBinaryProcActive(spellId, true)
			end
		end
	end

	for spellId, _ in pairs(TRACKED_PROCCS) do
		if not seen[spellId] then
			RemoveProcByKey(spellId)
			ClearPendingProcState(spellId)
		end
	end
end

handlers.PLAYER_ENTERING_WORLD = function(self)
	local _, class = UnitClass("player")
	Lateral.state.playerClass = class
	RunNamChecks()
	RefreshTargetState()
	RefreshComboPoints()
	SyncPersistentProcsOnWorldEntry()
end

local function Lateral_OnEvent()
	local handler = handlers[_G.event]
	if handler then
		handler(_G.this)
	end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTER_COMBAT")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
frame:RegisterEvent("SPELL_START_SELF")
frame:RegisterEvent("SPELL_MISS_SELF")
frame:RegisterEvent("AURA_CAST_ON_SELF")
frame:RegisterEvent("BUFF_UPDATE_DURATION_SELF")
frame:RegisterEvent("BUFF_ADDED_SELF")
frame:RegisterEvent("BUFF_REMOVED_SELF")
frame:RegisterEvent("UNIT_DIED")
frame:RegisterEvent("PLAYER_COMBO_POINTS")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", Lateral_OnEvent)
frame:SetScript("OnUpdate", Lateral_OnUpdate)

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
	{text = "Frame Width", editbox = { key = "frameWidth" }, tooltip = "Set bar width"},
	{text = "Frame Height", editbox = { key = "frameHeight" }, tooltip = "Set bar height"},
	{text = "Frame Spacing", editbox = { key = "frameSpacing" }, tooltip = "Set spacing between bars"},
	{text = "Text Size", editbox = { key = "fontSize" }, tooltip = "Set text size for all bar texts"},
	{text = "Potential Timer Decimals", editbox = { key = "potentialDecimals" }, tooltip = "Set decimals for potential durations (0-3)"},
	{text = "Active Timer Decimals", editbox = { key = "activeDecimals" }, tooltip = "Set decimals for active durations (0-3)"},
	{text = "Rupture Bar Height", editbox = { key = "ruptureBarHeight" }, tooltip = "Set Rupture bar height (0 hides)"},
	{text = "Bar Texture Path", editbox = { key = "barTexture" }, tooltip = "Set status bar texture path"},
	{text = "",},
	{text = "SnD Potential Color", editbox = { key = "sndPotentialColor" }, color = { key = "sndPotentialColor" }, tooltip = "Hex color for SnD potential bar, e.g. 4A73FF"},
	{text = "SnD Active Color", editbox = { key = "sndActiveColor" }, color = { key = "sndActiveColor" }, tooltip = "Hex color for SnD active bar, e.g. F7FF59"},
	{text = "TfB Potential Color", editbox = { key = "tfbPotentialColor" }, color = { key = "tfbPotentialColor" }, tooltip = "Hex color for TfB potential bar"},
	{text = "TfB Active Color", editbox = { key = "tfbActiveColor" }, color = { key = "tfbActiveColor" }, tooltip = "Hex color for TfB active bar"},
	{text = "Envenom Potential Color", editbox = { key = "envenomPotentialColor" }, color = { key = "envenomPotentialColor" }, tooltip = "Hex color for Envenom potential bar"},
	{text = "Envenom Active Color", editbox = { key = "envenomActiveColor" }, color = { key = "envenomActiveColor" }, tooltip = "Hex color for Envenom active bar"},
	{text = "Expose Potential Color", editbox = { key = "exposePotentialColor" }, color = { key = "exposePotentialColor" }, tooltip = "Hex color for Expose potential bar"},
	{text = "Expose Active Color", editbox = { key = "exposeActiveColor" }, color = { key = "exposeActiveColor" }, tooltip = "Hex color for Expose active bar"},
	{text = "",},
	{text = "Proc Icon Size", editbox = { key = "procIconSize" }, tooltip = "Set size of proc textures"},
	{text = "Proc Timer Text Size", editbox = { key = "procTimerFontSize" }, tooltip = "Set font size for proc timer"},
	{text = "Proc Stack Text Size", editbox = { key = "procStackFontSize" }, tooltip = "Set font size for proc stack"},
	{text = "Proc Icon Spacing", editbox = { key = "procIconSpacing" }, tooltip = "Set horizontal spacing between proc textures"},
	{text = "",},
	{text = "Horizontal Position", editbox = { key = "framePosX" }, tooltip = "Set horizontal position"},
	{text = "Vertical Position", editbox = { key = "framePosY" }, tooltip = "Set vertical position"},
}

local function Lateral_OptionChange()
	if LateralDB then
		ApplyBarColors()
		UpdateDisplay()
	end
end

local function IsLayoutSettingKey(key)
	return key == "frameWidth" or key == "frameHeight" or key == "frameSpacing" or key == "fontSize" or key == "ruptureBarHeight" or key == "procIconSize" or key == "procTimerFontSize" or key == "procStackFontSize" or key == "procIconSpacing" or key == "framePosX" or key == "framePosY"
end

local function IsDecimalKey(key)
	return key == "potentialDecimals" or key == "activeDecimals"
end

local function IsColorKey(key)
	return key == "sndPotentialColor" or key == "sndActiveColor" or key == "tfbPotentialColor" or key == "tfbActiveColor" or key == "envenomPotentialColor" or key == "envenomActiveColor" or key == "exposePotentialColor" or key == "exposeActiveColor"
end

local function Lateral_OpenColorPicker(colorKey)
	if not LateralDB or not colorKey or not ColorPickerFrame then return end
	local r, g, b = HexToRGB(LateralDB[colorKey] or "FFFFFF")
	if not r then r, g, b = 1, 1, 1 end
	local previous = { r = r, g = g, b = b }
	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.opacityFunc = nil
	ColorPickerFrame.func = function()
		local nr, ng, nb = ColorPickerFrame:GetColorRGB()
		LateralDB[colorKey] = RGBToHex(nr, ng, nb)
		ApplyBarColors()
		Lateral_OptionChange()
	end
	ColorPickerFrame.cancelFunc = function()
		LateralDB[colorKey] = RGBToHex(previous.r, previous.g, previous.b)
		ApplyBarColors()
		Lateral_OptionChange()
	end
	ShowUIPanel(ColorPickerFrame)
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
			if this.key == "barTexture" then
				local txt = this:GetText() or ""
				LateralDB.barTexture = txt
				ApplyTextureToAllBars()
				Lateral_OptionChange()
			elseif IsColorKey(this.key) then
				local normalized = NormalizeHexColor(this:GetText())
				if normalized then
					LateralDB[this.key] = normalized
					ApplyBarColors()
					Lateral_OptionChange()
				else
					if LateralDB[this.key] ~= nil then
						this:SetText(tostring(LateralDB[this.key]))
					end
				end
			else
				local num = tonumber(this:GetText())
				if num then
					if IsDecimalKey(this.key) then
						num = ClampDecimals(num)
					end
					LateralDB[this.key] = num
					if IsLayoutSettingKey(this.key) then
						ApplyLayoutSettings()
					end
					Lateral_OptionChange()
				else
					-- restore current stored value if input invalid
					if LateralDB[this.key] ~= nil then
						this:SetText(tostring(LateralDB[this.key]))
					end
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
		fb.color = val.color

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
			if this.color and this.color.key then
				Lateral_OpenColorPicker(this.color.key)
				return
			end
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
