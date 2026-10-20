-- ImprovedExternalDefs 1.5.51 TEST: optional party-caster channels.
-- Both Emerald Communion and Tranquility have an aura on their CASTER,
-- but do not necessarily put a matching beneficial buff on the recipient.
-- These containers are Blizzard-owned; no inspection of secret aura data,
-- combat-log parsing, or protected in-combat positioning is performed.
local _, ns = ...
local UNIT_COUNT = 4
local SPELLS = {
    {id=370960, class="EVOKER", name="Emerald Communion", key="IE_EmeraldCommunion"},
    {id=740, class="DRUID", name="Tranquility", key="IE_Tranquility"},
}
local installed = false
local initialized, lastIssue = 0, "not initialized"
local tracked = {}
local selectedNames = "none"

local function EnabledSpells()
    local db = NoExternalPulseDB
    if not db or db.safeMode or not db.nativeSweepMode then return {} end
    local ids = {}
    for digits in tostring(db.selectedExtraSpellIDs or ""):gmatch("%d+") do
        ids[tonumber(digits)] = true
    end
    local result = {}
    for _,spec in ipairs(SPELLS) do
        if ids[spec.id] then result[#result+1] = spec end
    end
    return result
end

-- The audio engine uses the same checkbox and native-mode rules as the caster icons.
-- No aura inspection is performed here: only saved selections are read.
ns.GetEnabledPartyCasterSpells = EnabledSpells

local function SetupIcon(button, class)
    -- Reuse the exact Blizzard-native style, timer, sweep, glow and size.
    if type(ns.InitializeCompanionAuraButton) ~= "function" then
        error("native shared aura icon renderer unavailable")
    end
    ns.InitializeCompanionAuraButton(button, class)
end

function ns.AttachEmeraldCommunionTracker(recipientContainer)
    if installed then return end
    local spells = EnabledSpells()
    if #spells == 0 then
        lastIssue = "No party caster spells enabled (Spells > Druid / Evoker, /reload)"
        return
    end
    local names = {}
    for _,spec in ipairs(spells) do names[#names+1] = spec.name end
    selectedNames = table.concat(names, ", ")
    if InCombatLockdown and InCombatLockdown() then
        lastIssue = "initialization deferred; /reload outside combat"
        return
    end
    if not recipientContainer or not AnchorUtil or not AnchorUtil.FlowLayoutAxis then
        lastIssue = "native AuraContainer unavailable"
        return
    end
    if type(recipientContainer.GetWidth) ~= "function" then
        lastIssue = "recipient container invalid"
        return
    end
    local previous = recipientContainer
    local created = {}
    for index=1, UNIT_COUNT do
        local unit = "party" .. index
        local aura = CreateFrame("AuraContainer", nil, recipientContainer, "CustomAuraContainerTemplate")
        aura:SetSize(1,1)
        aura:ClearAllPoints()
        -- Already validated for Communion. Do not move recipient centering.
        local d = NoExternalPulseDB or {}
        local spacing = math.max(0, math.min(20, tonumber(d.nativeIconSpacing) or 2))
        aura:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
        aura:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        aura:SetFlowLayoutAnchorPoint("LEFT")
        aura:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
        aura:SetFlowLayoutMaximumLineSize(128)
        local groupKeys = {}
        for _,spec in ipairs(spells) do
            local key = spec.key .. "_" .. index
            local assignedClass = spec.class
            aura:AddAuraGroup(key, "HELPFUL", {
                maxFrameCount=1,
                candidateFilters={includeSpellIDs={[spec.id]=true}},
                initializeFrame=function(button) SetupIcon(button, assignedClass) end,
                layout={elementWidth=30,elementHeight=30,elementSpacing=2,lineSpacing=2},
            })
            groupKeys[#groupKeys+1] = key
        end
        aura:SetUnit(unit)
        aura:SetEnabled(true)
        tracked[#tracked+1]={frame=aura, keys=groupKeys}
        created[#created+1]=unit
        previous=aura
    end
    installed=true
    tracked.recipient=recipientContainer
    initialized=#created
    lastIssue="party1..party4 native caster auras; adjacent to player row; shared renderer"
end

-- The main centered recipient tracker retains its native anchor.
-- These supplementary party-unit containers are laid out out of combat,
-- and Blizzard controls the icon visibility in combat.
function ns.SyncEmeraldCommunionLayout(size, spacing)
    if not installed or (InCombatLockdown and InCombatLockdown()) then return end
    if type(size) ~= "number" or type(spacing) ~= "number" then return end
    for index,item in ipairs(tracked) do
        local aura = item.frame
        for _,key in ipairs(item.keys) do
            aura:SetAuraGroupLayout(key, {
                elementWidth=size,elementHeight=size,
                elementSpacing=spacing,lineSpacing=spacing,
            })
        end
        aura:ClearAllPoints()
        local previous = index == 1 and tracked.recipient or tracked[index-1].frame
        aura:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
    end
end

function ns.PartyCasterStatus()
    return "Party-caster auras: " .. selectedNames ..
        " | native party containers=" .. initialized .. " | " .. lastIssue ..
        " | does NOT prove healing was received"
end
-- Existing macro/command compatibility.
function ns.EmeraldCommunionStatus()
    return ns.PartyCasterStatus()
end
