-- ImprovedExternalDefs v1.5.40 - focused ally / Spellsteal catalogue + category tests
local _, ns = ...
local L = ns.L or function(s) return s end
local root, content, category
local refreshers = {}
local preview
local classes = {
    { "PALADIN", "Paladin", "Interface\\Icons\\Spell_Holy_SealOfProtection" },
    { "PRIEST", "Priest", "Interface\\Icons\\Spell_Holy_PainSupression", 33206 },
    { "DRUID", "Druid", "Interface\\Icons\\Spell_Druid_Ironbark", 102342 },
    { "MAGE", "Mage", "Interface\\Icons\\Spell_Frost_FrostArmor02" },
    { "SHAMAN", "Shaman", "Interface\\Icons\\Spell_Nature_SkinOfEarth" },
    { "WARRIOR", "Warrior", "Interface\\Icons\\Ability_Warrior_ShieldWall" },
}
-- Resolve real spell textures in the game client; the texture path remains
-- a fallback in case the spell info is unavailable when the panel opens.
function ns.GetDemoSpellTexture(spellID, fallback)
    if spellID and C_Spell and type(C_Spell.GetSpellTexture) == "function" then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and (type(texture) == "number" or type(texture) == "string") then
            return texture
        end
    end
    return fallback
end

-- Native Blizzard dropdowns display every available choice on a single click.
-- They automatically show the selected radio option, and the menu supports
 -- Blizzard's own scrolling/keyboard behavior for longer profile lists.
local function MakeDropdown(parent, choices, currentValue, chooseValue, width)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(width or 255, 29)
    dropdown:SetDefaultText(L("Select..."))
    dropdown:SetupMenu(function(_, rootDescription)
        for _, choice in ipairs(choices()) do
            rootDescription:CreateRadio(L(choice[2]),
                function(value) return currentValue() == value end,
                function(value)
                    if currentValue() ~= value then chooseValue(value) end
                end,
                choice[1])
        end
    end)
    return dropdown
end

local function UpdateDropdown(dropdown)
    -- Necessary when switching profiles or using slash commands instead of
    -- making a selection inside the dropdown itself.
    if dropdown and dropdown.GenerateMenu then dropdown:GenerateMenu() end
end

local previewClassIndex = 1
local previewUseCombatFallback = false
local worldTestButton
function ns.GetPreviewClassInfo()
    local chosen = classes[previewClassIndex]
    return chosen[1], chosen[2], ns.GetDemoSpellTexture(chosen[4], chosen[3])
end
function ns.UpdateTestButton()
    if worldTestButton then
        worldTestButton:SetText(L(ns.IsWorldTestVisible and ns.IsWorldTestVisible() and "Hide 3-icon test" or "Test 3 externals"))
    end
end
local PREVIEW_SECONDS = 30

local function DB() return NoExternalPulseDB end

local function TrackerEnabled()
    -- WoW owns this CVar.  Do not infer tracker state from visible buttons:
    -- no buffs simply means no icon, not that the tracker is disabled.
    local value
    if C_CVar and type(C_CVar.GetCVar) == "function" then
        local ok, result = pcall(C_CVar.GetCVar, "externalDefensivesEnabled")
        if ok then value = result end
    elseif type(GetCVar) == "function" then
        local ok, result = pcall(GetCVar, "externalDefensivesEnabled")
        if ok then value = result end
    end
    if value == true or value == 1 or value == "1" then return true end
    if value == false or value == 0 or value == "0" then return false end
    return nil -- a missing/unreadable CVar is NOT proof the tracker is off
end

local function EnableTracker()
    if InCombatLockdown and InCombatLockdown() then
        return false, "Leave combat before enabling Blizzard External Defensives."
    end
    local setter = C_CVar and C_CVar.SetCVar or SetCVar
    if type(setter) ~= "function" then
        return false, "This WoW client does not expose the External Defensives setting."
    end
    local ok, err = pcall(setter, "externalDefensivesEnabled", "1")
    if not ok then return false, "Blizzard refused the setting change: " .. tostring(err) end
    if TrackerEnabled() ~= true then
        return false, "WoW did not confirm activation. Try enabling External Defensives in Blizzard's settings."
    end
    return true
end


-- Shared with the first-run message; uses Blizzard's own CVar, never aura
-- fields or combat-protected tracker regions.
ns.IsBlizzardTrackerEnabled = TrackerEnabled
ns.EnableBlizzardTracker = EnableTracker

local function Font(parent, text, size, color, width)
    local font = parent:CreateFontString(nil, "OVERLAY")
    font:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    font:SetJustifyH("LEFT")
    if width then font:SetWidth(width) end
    local c = color or { 0.9, 0.9, 0.9 }
    font:SetTextColor(c[1], c[2], c[3])
    font:SetText(L(text))
    return font
end

local function Changed()
    if ns.ProfileSettingsChanged then ns.ProfileSettingsChanged() end
    if ns.ApplySettings then ns.ApplySettings() end
    if ns.RefreshNativeSweep then ns.RefreshNativeSweep() end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

local function Heading(text, x, y)
    local title = Font(content, text, 16, { 1, 0.82, 0.28 })
    title:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    return title
end

local function Check(field, label, x, y)
    local b = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    b:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    b:SetSize(26, 26)
    local labelText = Font(content, label, 13, { 0.94, 0.94, 0.94 })
    labelText:SetPoint("LEFT", b, "RIGHT", 4, 0)
    b:SetScript("OnClick", function(self)
        DB()[field] = not not self:GetChecked()
        Changed()
        if field == "removeSecondsSuffix" and DB().nativeSweepMode then
            print("|cff79d8ffImprovedExternalDefs|r: /reload outside combat to update native timer suffix.")
        elseif field == "extraObsidianScales" or field == "extraIntervene" then
            print("|cff79d8ffImprovedExternalDefs|r: /reload outside combat to update additional tracked buffs.")
        end
    end)
    refreshers[#refreshers + 1] = function() b:SetChecked(not not DB()[field]) end
    return b
end

local function Choice(field, label, items, x, y, width)
    local labelText = Font(content, label, 12, { 0.8, 0.84, 0.9 })
    labelText:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    local dropdown = MakeDropdown(content,
        function() return type(items) == "function" and items() or items end,
        function() return DB()[field] end,
        function(value)
            DB()[field] = value
            Changed()
            if field == "durationDecimalsThreshold" and DB().nativeSweepMode then
                print("|cff79d8ffImprovedExternalDefs|r: /reload outside combat to update live fractional timers.")
            end
        end,
        width)
    dropdown:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 0, -7)
    refreshers[#refreshers + 1] = function() UpdateDropdown(dropdown) end
    return dropdown
end

local function Slider(field, label, lo, hi, step, x, y, formatValue)
    local labelText = Font(content, label, 12, { 0.8, 0.84, 0.9 })
    labelText:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    local valueLabel = Font(content, "", 13, { 1, 0.82, 0.28 })
    valueLabel:SetPoint("TOPRIGHT", content, "TOPLEFT", x + 265, y)
    valueLabel:SetJustifyH("RIGHT")
    local s = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    s:SetPoint("TOPLEFT", labelText, "BOTTOMLEFT", 2, -15)
    s:SetWidth(244)
    s:SetHeight(16)
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    local internalChange = false
    s:SetScript("OnValueChanged", function(_, value)
        if internalChange then return end
        local rounded = math.floor(value / step + 0.5) * step
        rounded = math.max(lo, math.min(hi, rounded))
        if step >= 1 then
            rounded = math.floor(rounded + 0.5)
        else
            rounded = math.floor(rounded * 100 + 0.5) / 100
        end
        DB()[field] = rounded
        Changed()
    end)
    refreshers[#refreshers + 1] = function()
        internalChange = true
        s:SetValue(DB()[field])
        valueLabel:SetText(formatValue and formatValue(DB()[field]) or tostring(DB()[field]))
        internalChange = false
    end
    return s
end

local function MakeEdge(parent)
    local edge = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    edge:SetColorTexture(1, 1, 1, 1)
    edge:SetBlendMode("ADD")
    return edge
end


-- Preview timing is synthetic: no secret aura values or Blizzard frames are read.
-- Kept independent of the live defensive tracker so it works out of combat.
local function UpdatePreviewSeconds()
    if not preview or not preview.timer or not preview.endTime then return end
    local left = math.max(0, preview.endTime - GetTime())
    local d = DB()
    preview.timer:SetText(ns.FormatSyntheticDuration and ns.FormatSyntheticDuration(left)
        or (tostring(math.ceil(left)) .. (d and d.removeSecondsSuffix and "" or "s")))

    -- Fallback when a radial Cooldown widget cannot be used by the client.
    -- A narrow dark overlay retreats to reveal the spell icon instead.
    if preview.fallback then
        local showFallback = d and d.swipe and not preview.nativeRunning
        preview.fallback:SetShown(not not showFallback)
        if showFallback then
            local fraction = left / PREVIEW_SECONDS
            preview.fallback:SetWidth(math.max(0.01, preview.icon:GetWidth() * fraction))
            preview.fallback:SetAlpha(d.swipeOpacity)
            preview.fallback:ClearAllPoints()
            local side = d.swipeReverse and "RIGHT" or "LEFT"
            preview.fallback:SetPoint("TOP" .. side, preview.icon, "TOP" .. side, 0, 0)
            preview.fallback:SetPoint("BOTTOM" .. side, preview.icon, "BOTTOM" .. side, 0, 0)
        end
    end
end

local function RestartPreview()
    if not preview then return end
    local now = GetTime()
    preview.endTime = now + PREVIEW_SECONDS
    preview.nativeRunning = false
    preview.nativeGlowRunning = false
    if preview.glowSweep then
        preview.nativeGlowRunning = pcall(preview.glowSweep.SetCooldown,
            preview.glowSweep, now, PREVIEW_SECONDS)
    end
    local sweep = preview.sweep
    if sweep then
        -- A normal 30-second number is safe to use; no in-game aura data.
        -- This function can be protected on certain clients, so fall back
        -- gracefully if it is rejected.
        local ok = pcall(sweep.SetCooldown, sweep, now, PREVIEW_SECONDS)
        preview.nativeRunning = ok
        if ok then
            sweep:SetShown(not not DB().swipe)
        else
            pcall(sweep.Hide, sweep)
        end
    end
    UpdatePreviewSeconds()
end

function ns.UpdatePreview()
    if not preview or not NoExternalPulseDB then return end
    local d = DB()
    local icon, halo, edges, timer = preview.icon, preview.halo, preview.edges, preview.timer
    local class = classes[previewClassIndex]
    local nativeMode = d.nativeSweepMode == true and d.safeMode ~= true
    local color = (ns.CLASS_COLORS and ns.CLASS_COLORS[class[1]]) or ns.FALLBACK_COLOR or { 1, 1, 1 }
    if nativeMode and previewUseCombatFallback and ns.NativeFallbackGlowColor then
        color = ns.NativeFallbackGlowColor()
    end
    color = ns.GetConfiguredGlowColor and ns.GetConfiguredGlowColor(color) or color
    icon:SetTexture(ns.GetDemoSpellTexture(class[4], class[3]))
    icon:SetAlpha(d.iconOpacity or 1)
    local width, height, factor = 32, 32, 1
    if nativeMode and ns.NativePreviewMetrics then
        width, height, factor = ns.NativePreviewMetrics(preview.iconHolder)
    elseif ns.GetTrackerPreviewMetrics then
        width, height, factor = ns.GetTrackerPreviewMetrics(preview.iconHolder)
    end
    preview.iconHolder:SetSize(width, height)
    ns.PositionGlowSweep(preview.glowSweep, icon, factor)
    ns.StyleGlowSweep(preview.glowSweep, d, color, preview.nativeGlowRunning)
    ns.PaintGlow(icon, halo, edges, preview.staticGlow, preview.glowSweep,
        d, color, factor, true)

    local sweep = preview.sweep
    if sweep then
        pcall(sweep.SetSwipeColor, sweep, 0, 0, 0, d.swipeOpacity)
        if type(sweep.SetReverse) == "function" then
            pcall(sweep.SetReverse, sweep, d.swipeReverse)
        end
        sweep:SetShown(d.swipe and preview.nativeRunning)
    end

    -- Native mode and this preview both use the *same* timer styling function.
    -- Scale is corrected for differences between the tracker and options panel.
    if nativeMode and ns.StyleNativeTimer then
        ns.StyleNativeTimer(timer, icon, factor)
    else
        timer:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", (d.textSize or 14) * factor, "OUTLINE")
        timer:ClearAllPoints()
        if d.textPosition == "TOP" then
            timer:SetPoint("BOTTOM", icon, "TOP", (d.textX or 0) * factor, ((d.textY or 0) + 3) * factor)
        elseif d.textPosition == "BOTTOM" or d.textPosition == "DEFAULT" then
            timer:SetPoint("TOP", icon, "BOTTOM", (d.textX or 0) * factor, ((d.textY or 0) - 3) * factor)
        else
            timer:SetPoint("CENTER", icon, "CENTER", (d.textX or 0) * factor, (d.textY or 0) * factor)
        end
    end
    if preview.modeInfo then
        preview.modeInfo:SetText(L(nativeMode and
          (previewUseCombatFallback and "Combat preview: caster identity hidden" or "Preview: caster class identified") or
          "Preview: classic tracker styling"))
    end
    timer:Show()
    UpdateDropdown(preview.classBtn)
    UpdatePreviewSeconds()
    if ns.RefreshWorldTest then ns.RefreshWorldTest() end
end

-- Build the demo as a self-contained widget, after the main settings are
-- registered. An optional visual method failing must not abort the panel.
local function CreateLivePreview()
    local bg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    -- A self-contained preview BELOW icon controls on the Icons tab.
    bg:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -974)
    bg:SetSize(575, 268)
    bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    bg:SetBackdropColor(0.05, 0.065, 0.09, 0.7)
    bg:SetBackdropBorderColor(0.3, 0.36, 0.46, 0.6)
    local previewTitle = Font(bg, "Live preview", 14, { 1, 0.82, 0.35 })
    previewTitle:SetPoint("TOPLEFT", bg, "TOPLEFT", 12, -10)
    local hint = Font(bg, "Animated 30-second demo using your visual settings", 11, { 0.73, 0.77, 0.82 })
    hint:SetPoint("TOPLEFT", previewTitle, "BOTTOMLEFT", 0, -5)

    -- A dedicated icon holder makes all child visuals share a stable size.
    local holder = CreateFrame("Frame", nil, bg)
    holder:SetSize(32, 32)
    holder:SetPoint("CENTER", bg, "TOPLEFT", 135, -149)
    holder:EnableMouse(false)
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(holder)
    icon:SetTexture(ns.GetDemoSpellTexture(classes[1][4], classes[1][3]))

    -- Native radial cooldown is optional. Do NOT put all preview creation
    -- inside a single pcall: errors in one engine call used to kill the demo.
    local sweep
    local created, result = pcall(CreateFrame, "Cooldown", nil, holder, "CooldownFrameTemplate")
    if created and result then
        sweep = result
        sweep:SetAllPoints(holder)
        sweep:SetFrameLevel(holder:GetFrameLevel() + 1)
        sweep:EnableMouse(false)
        if type(sweep.SetDrawSwipe) == "function" then pcall(sweep.SetDrawSwipe, sweep, true) end
        if type(sweep.SetDrawEdge) == "function" then pcall(sweep.SetDrawEdge, sweep, false) end
        if type(sweep.SetDrawBling) == "function" then pcall(sweep.SetDrawBling, sweep, false) end
        if type(sweep.SetHideCountdownNumbers) == "function" then
            pcall(sweep.SetHideCountdownNumbers, sweep, true)
        end
    end

    -- Fallback linear swipe: guaranteed visible if the native API refuses a
    -- simulated timer. Drawn above icon, below glow and countdown numbers.
    local fallbackFrame = CreateFrame("Frame", nil, holder)
    fallbackFrame:SetAllPoints(holder)
    fallbackFrame:SetFrameLevel(holder:GetFrameLevel() + 2)
    fallbackFrame:EnableMouse(false)
    local fallback = fallbackFrame:CreateTexture(nil, "ARTWORK")
    fallback:SetColorTexture(0, 0, 0, 1)
    fallback:SetWidth(52)
    fallback:SetPoint("TOPLEFT", holder, "TOPLEFT")
    fallback:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT")
    fallback:Hide()

    local glowSweep = ns.CreateGlowSweep(holder, icon, holder:GetFrameLevel() + 3)
    local front = CreateFrame("Frame", nil, bg)
    front:SetAllPoints(bg)
    front:SetFrameLevel(holder:GetFrameLevel() + 4)
    front:EnableMouse(false)
    local halo = front:CreateTexture(nil, "ARTWORK", nil, 7)
    halo:SetTexture("Interface\\AddOns\\ImprovedExternalDefs\\Media\\NeonOutline.tga")
    halo:SetBlendMode("ADD")
    halo:SetPoint("TOPLEFT", icon, "TOPLEFT", -9, 9)
    halo:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 9, -9)
    local edges = { MakeEdge(front), MakeEdge(front), MakeEdge(front), MakeEdge(front) }
    local staticGlow = front:CreateTexture(nil, "ARTWORK", nil, 6)
    staticGlow:SetBlendMode("BLEND")
    staticGlow:Hide()
    -- A FontString must have a font BEFORE its first SetText() call.
    -- Inheriting a Blizzard FontObject provides a valid fallback even if a
    -- custom font path cannot be loaded by this client.
    local timer = front:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timer:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", DB().textSize or 14, "OUTLINE")
    timer:SetJustifyH("CENTER")
    timer:SetTextColor(1, 1, 1)
    timer:SetText(L("30"))

    local classChoices = {}
    for index, info in ipairs(classes) do
        classChoices[#classChoices + 1] = {index, info[2]}
    end
    local classBtn = MakeDropdown(bg,
        function() return classChoices end,
        function() return previewClassIndex end,
        function(index)
            previewClassIndex = index
            ns.UpdatePreview()
        end,
        144)
    local chooseLabel = Font(bg, "Preview spell class", 11, { 0.78, 0.84, 0.90 })
    chooseLabel:SetPoint("TOPLEFT", bg, "TOPLEFT", 318, -62)
    classBtn:SetPoint("TOPLEFT", bg, "TOPLEFT", 308, -86)
    local hidden = CreateFrame("CheckButton", nil, bg, "UICheckButtonTemplate")
    hidden:SetSize(23,23)
    hidden:SetPoint("TOPLEFT", bg, "TOPLEFT", 311, -130)
    hidden:SetChecked(previewUseCombatFallback)
    local hiddenLabel = Font(bg, "Simulate hidden caster class", 11, { 0.85, 0.89, 0.93 })
    hiddenLabel:SetPoint("LEFT", hidden, "RIGHT", 4, 0)
    hidden:SetScript("OnClick", function(self)
        previewUseCombatFallback = not not self:GetChecked()
        ns.UpdatePreview()
    end)
    local modeInfo = Font(bg, "", 11, { 0.72, 0.78, 0.85 }, 240)
    modeInfo:SetPoint("TOPLEFT", bg, "TOPLEFT", 318, -171)
    modeInfo:SetWordWrap(true)
    local replay = CreateFrame("Button", nil, bg, "UIPanelButtonTemplate")
    replay:SetSize(95, 25)
    replay:SetText(L("Replay"))
    replay:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -18, 14)
    replay:SetScript("OnClick", RestartPreview)

    preview = { bg = bg, icon = icon, iconHolder = holder, front = front,
                halo = halo, staticGlow = staticGlow, glowSweep = glowSweep, edges = edges,
                timer = timer, sweep = sweep, fallback = fallback,
                classBtn = classBtn, modeInfo = modeInfo }
    bg:SetScript("OnUpdate", function(self, elapsed)
        self.NEPTick = (self.NEPTick or 0) + elapsed
        if self.NEPTick < 0.08 then return end
        self.NEPTick = 0
        if not preview or not preview.endTime then return end
        if GetTime() >= preview.endTime then RestartPreview() end
        UpdatePreviewSeconds()
    end)
    bg:SetScript("OnShow", function()
        ns.UpdatePreview()
        RestartPreview()
    end)
    ns.UpdatePreview()
    RestartPreview()
end

local profileUI

local function MakeInput(x, y, width, maxLetters)
    local edit = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    edit:SetSize(width, 24)
    edit:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    edit:SetAutoFocus(false)
    if edit.SetMaxLetters then edit:SetMaxLetters(maxLetters or 1024) end
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return edit
end

local function ProfileMessage(msg, good)
    if profileUI and profileUI.status then
        profileUI.status:SetText(L(msg or ""))
        profileUI.status:SetTextColor(good and 0.45 or 1, good and 0.95 or 0.52, good and 0.55 or 0.48)
    end
end

local function RefreshProfiles()
    if not profileUI or not ns.GetProfileNames then return end
    local name = ns.ActiveProfileName()
    UpdateDropdown(profileUI.switch)
    if not profileUI.export:HasFocus() then
        local code = ns.ExportProfile(name)
        if code then profileUI.export:SetText(code) end
    end
end

local function CreateProfilesPanel()
    if not ns.GetProfileNames then return end
    Heading("Profiles", 24, -26)
    local hint = Font(content, "Export settings with EE13 codes, including text scaling, selected spells, glow colors and timers. Older codes still import.", 11,
        {0.72, 0.77, 0.82}, 560)
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -53)

    local switch = MakeDropdown(content,
        function()
            local choices = {}
            for _, name in ipairs(ns.GetProfileNames()) do
                choices[#choices + 1] = {name, name}
            end
            return choices
        end,
        function() return ns.ActiveProfileName() end,
        function(name)
            local ok, msg = ns.LoadProfile(name)
            ProfileMessage(msg, ok)
        end,
        252)
    switch:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -78)
    local dropdownHint = Font(content, "Click to choose a profile from the list", 10, {0.68, 0.76, 0.84})
    dropdownHint:SetPoint("TOPLEFT", switch, "BOTTOMLEFT", 0, -3)
    local label = Font(content, "New / imported profile name", 11, {0.78, 0.83, 0.89})
    label:SetPoint("TOPLEFT", content, "TOPLEFT", 334, -63)
    local nameInput = MakeInput(336, -87, 240, 28)
    nameInput:SetText(L(""))

    local save = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    save:SetSize(145, 27)
    save:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -131)
    save:SetText(L("Save current"))
    local saveAs = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    saveAs:SetSize(143, 27)
    saveAs:SetPoint("TOPLEFT", content, "TOPLEFT", 179, -131)
    saveAs:SetText(L("Save as new"))
    local delete = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    delete:SetSize(129, 27)
    delete:SetPoint("TOPLEFT", content, "TOPLEFT", 334, -131)
    delete:SetText(L("Delete profile"))

    Heading("Share a profile", 24, -189)
    local exportLabel = Font(content, "Export code (select and press Ctrl+C)", 11, {0.78, 0.83, 0.89})
    exportLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -216)
    local export = MakeInput(28, -238, 538, 5000)
    local copyButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    copyButton:SetSize(173, 26)
    copyButton:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -275)
    copyButton:SetText(L("Select export code"))

    local importLabel = Font(content, "Import code (paste with Ctrl+V, then click Import)", 11, {0.78, 0.83, 0.89})
    importLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -322)
    local import = MakeInput(28, -344, 538, 5000)
    local importButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    importButton:SetSize(173, 26)
    importButton:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -381)
    importButton:SetText(L("Import and activate"))
    local status = Font(content, "", 11, {0.55, 0.98, 0.59}, 540)
    status:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -430)
    status:SetWordWrap(true)
    local warning = Font(content,
        "Profiles include colors, timer format, native mode and sounds. /reload after import to apply native duration formatting. Blizzard Edit Mode positioning is not included.",
        10, {0.66, 0.72, 0.79}, 545)
    warning:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -467)
    warning:SetWordWrap(true)

    profileUI = { switch = switch, name = nameInput, export = export, import = import, status = status }
    save:SetScript("OnClick", function()
        local ok, msg = ns.SaveProfile(ns.ActiveProfileName())
        ProfileMessage(msg, ok)
    end)
    saveAs:SetScript("OnClick", function()
        local name = nameInput:GetText()
        for _, existing in ipairs(ns.GetProfileNames()) do
            if name == existing then ProfileMessage(L("That name already exists. Choose another."), false) return end
        end
        local ok, msg = ns.SaveProfile(name)
        ProfileMessage(msg, ok)
    end)
    local deleteArmedAt = 0
    delete:SetScript("OnClick", function()
        local name = ns.ActiveProfileName()
        if name == "Default" then ProfileMessage(L("The Default profile cannot be deleted."), false) return end
        local now = GetTime()
        if now > deleteArmedAt then
            deleteArmedAt = now + 5
            ProfileMessage(L("Click Delete profile again within 5 seconds to confirm."), false)
            return
        end
        deleteArmedAt = 0
        local ok, msg = ns.DeleteProfile(name)
        ProfileMessage(msg, ok)
    end)
    copyButton:SetScript("OnClick", function()
        local code = ns.ExportProfile(ns.ActiveProfileName())
        if code then
            export:SetText(code)
            export:SetFocus()
            export:HighlightText()
            ProfileMessage(L("Code selected. Press Ctrl+C, then share it."), true)
        end
    end)
    importButton:SetScript("OnClick", function()
        local ok, msg = ns.ImportProfile(import:GetText(), nameInput:GetText())
        if ok then import:SetText(L("")) end
        ProfileMessage(msg, ok)
    end)
    RefreshProfiles()
end

function ns.RefreshOptions()
    if not content then return end
    for _, refresh in ipairs(refreshers) do refresh() end
    ns.UpdatePreview()
    RefreshProfiles()
end

function ns.OpenOptions()
    if not category and ns.CreateOptions then ns.CreateOptions() end
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    else
        print("|cff79d8ffImprovedExternalDefs|r: Esc > Options > AddOns > ImprovedExternalDefs")
    end
end

-- Each category owns a separate, real scroll page. This intentionally avoids
-- overlapping absolute-position controls across unrelated settings.
function ns.CreateOptions()
    if root or not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    root = CreateFrame("Frame", "ImprovedExternalDefsOptionsPanel")
    root:SetSize(675, 610)
    root.OnCommit = function() end
    root.OnDefault = function()
        for key, value in pairs(ns.DEFAULTS) do DB()[key] = value end
        Changed()
        RestartPreview()
    end
    root.OnRefresh = function() ns.RefreshOptions() end

    category = Settings.RegisterCanvasLayoutCategory(root, "ImprovedExternalDefs")
    Settings.RegisterAddOnCategory(category)

    local title = Font(root, "ImprovedExternalDefs", 21, { 1, 0.85, 0.50 })
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 19, -8)
    local ver = Font(root, "v1.5.64", 11, { 0.64, 0.72, 0.83 })
    ver:SetPoint("LEFT", title, "RIGHT", 10, -2)

    -- Shared header action stays visible on EVERY tab, even when a page is scrolled.
    -- Test icons are synthetic and never read secret combat aura values.
    worldTestButton = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
    worldTestButton:SetSize(205, 28)
    worldTestButton:SetPoint("TOPRIGHT", root, "TOPRIGHT", -20, -10)
    worldTestButton:SetScript("OnClick", function()
        if not ns.ToggleWorldTest then return end
        local ok, result, message = pcall(ns.ToggleWorldTest)
        if not ok then
            ns.LastWorldTestError = tostring(result)
            print("|cff79d8ffImprovedExternalDefs|r: Test error: " .. ns.LastWorldTestError)
        elseif message then
            print("|cff79d8ffImprovedExternalDefs|r: " .. tostring(message))
        end
        ns.UpdateTestButton()
    end)
    ns.UpdateTestButton()

    local pages, tabButtons = {}, {}
    local pageOrder = { "Icons", "Text", "Spells", "Profiles" }
    local heights = { Icons = 1440, Text = 740, Spells = 2400, Profiles = 660 }
    local function CreatePage(name)
        local scroll = CreateFrame("ScrollFrame", nil, root, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -86)
        scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -26, 0)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(630, heights[name])
        scroll:SetScrollChild(child)
        scroll:Hide()
        pages[name] = scroll
        return child
    end
    for _, name in ipairs(pageOrder) do CreatePage(name) end

    local activeTab
    local function SelectPage(name)
        if not pages[name] then return end
        activeTab = name
        for _, other in ipairs(pageOrder) do
            pages[other]:SetShown(other == name)
            local b = tabButtons[other]
            if b then
                b:SetEnabled(other ~= name)
                if other == name then b:LockHighlight() else b:UnlockHighlight() end
            end
        end
        if name == "Profiles" then RefreshProfiles() end
        if name == "Icons" and preview then ns.UpdatePreview() end
    end
    for i, name in ipairs(pageOrder) do
        local button = CreateFrame("Button", nil, root, "UIPanelButtonTemplate")
        button:SetSize(116, 30)
        button:SetPoint("TOPLEFT", root, "TOPLEFT", 20 + (i - 1) * 121, -46)
        button:SetText(L(name))
        button:SetScript("OnClick", function() SelectPage(name) end)
        tabButtons[name] = button
    end
    -- Keep a single persistent page reference for ns.RefreshOptions()'s guard.
    -- Helper constructors use `content` as the *page currently being built*.

    ---------------------------------------------------------
    -- ICONS: icon opacity, class glow, native cooldown sweep
    ---------------------------------------------------------
    local iconsPage = pages.Icons:GetScrollChild()

    -- The Blizzard Edit Mode instructions belong FIRST on the Icons page.
    -- This notice is independent of the user's tracker setting: positioning
    -- and sizing always belong to Blizzard, never to the addon profile.
    local editModeGuide = CreateFrame("Frame", nil, iconsPage, "BackdropTemplate")
    editModeGuide:SetPoint("TOPLEFT", iconsPage, "TOPLEFT", 20, -12)
    editModeGuide:SetSize(575, 124)
    editModeGuide:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    editModeGuide:SetBackdropColor(0.08, 0.10, 0.13, 0.96)
    editModeGuide:SetBackdropBorderColor(0.82, 0.59, 0.20, 0.95)

    local guideTitle = Font(editModeGuide, "ICON POSITION AND SIZE", 15,
        {1, 0.83, 0.37}, 547)
    guideTitle:SetPoint("TOPLEFT", editModeGuide, "TOPLEFT", 13, -10)
    local guideBody = Font(editModeGuide,
        "Move and resize the defensive icons in Blizzard's Edit Mode:",
        12, {0.96, 0.96, 0.94}, 545)
    guideBody:SetPoint("TOPLEFT", editModeGuide, "TOPLEFT", 13, -41)
    guideBody:SetWordWrap(true)
    local guidePath = Font(editModeGuide,
        "ESC > Edit Mode > External Defensives",
        13, {1, 0.83, 0.37}, 545)
    guidePath:SetPoint("TOPLEFT", editModeGuide, "TOPLEFT", 13, -67)
    local guideFooter = Font(editModeGuide,
        "The settings below customize their appearance, not their position or size.",
        11, {0.74, 0.82, 0.91}, 545)
    guideFooter:SetPoint("TOPLEFT", editModeGuide, "TOPLEFT", 13, -96)
    guideFooter:SetWordWrap(true)

    -- Preserve all established Icons controls and their relative spacing.
    -- Shifting the *settings parent* below the guide leaves the existing
    -- preview, centered layout, and mouse interactions unchanged.
    content = CreateFrame("Frame", nil, iconsPage)
    content:SetPoint("TOPLEFT", iconsPage, "TOPLEFT", 0, -150)
    content:SetSize(630, 1250)
    Heading("Icon appearance", 24, -18)
    Check("enabled", "Disable Blizzard icon pulsing", 24, -54)
    Check("glow", "Enable class-colored glow", 24, -89)
    Choice("glowStyle", "Glow style", {
        { "BORDER", "Clean border" }, { "HALO", "Soft glow" }, { "BOTH", "Border + soft glow" },
    }, 24, -146, 254)
    Slider("glowThickness", "Border thickness", 1, 6, 1, 24, -219,
        function(n) return n .. " px" end)
    Slider("glowOffset", "Border spacing", 0, 6, 1, 24, -298,
        function(n) return n .. " px" end)
    Slider("glowOpacity", "Glow intensity", 0.1, 1, 0.05, 24, -377,
        function(n) return math.floor(n * 100 + 0.5) .. "%" end)
    Slider("iconOpacity", "Icon opacity", 0, 1, 0.05, 24, -456,
        function(n) return math.floor(n * 100 + 0.5) .. "%" end)

    Choice("glowColorMode", "Glow color", {
        { "CLASS", "Class colors (automatic)" },
        { "CUSTOM", "Custom color (all defensives)" },
    }, 24, -530, 254)

    local customColorButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    customColorButton:SetSize(183, 27)
    customColorButton:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -608)
    customColorButton:SetText(L("Choose glow color..."))
    local swatch = content:CreateTexture(nil, "ARTWORK")
    swatch:SetSize(25, 25)
    swatch:SetPoint("LEFT", customColorButton, "RIGHT", 13, 0)
    swatch:SetTexture("Interface\\Buttons\\WHITE8X8")
    local pickerHint = Font(content, "Applies one glow color to every defensive, even in combat.",
        10, {0.69, 0.76, 0.83}, 270)
    pickerHint:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -642)
    pickerHint:SetWordWrap(true)
    local function RefreshCustomColor()
        swatch:SetVertexColor(DB().glowCustomR, DB().glowCustomG, DB().glowCustomB)
        customColorButton:SetEnabled(DB().glowColorMode == "CUSTOM")
        swatch:SetAlpha(DB().glowColorMode == "CUSTOM" and 1 or 0.45)
    end
    customColorButton:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            print("|cff79d8ffImprovedExternalDefs|r: Choose your custom color outside combat.")
            return
        end
        if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then return end
        local oldR, oldG, oldB = DB().glowCustomR, DB().glowCustomG, DB().glowCustomB
        ColorPickerFrame:SetupColorPickerAndShow({
            r = oldR, g = oldG, b = oldB, hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                DB().glowCustomR, DB().glowCustomG, DB().glowCustomB = r, g, b
                Changed()
            end,
            cancelFunc = function()
                DB().glowCustomR, DB().glowCustomG, DB().glowCustomB = oldR, oldG, oldB
                Changed()
            end,
        })
    end)
    refreshers[#refreshers + 1] = RefreshCustomColor

    -- The tracker is a Blizzard feature. Show a warning ONLY when its own
    -- CVar is disabled. None of our profile data changes this game setting.
    local trackerStatus = Font(content, "", 12, {0.55, 0.90, 0.66}, 290)
    trackerStatus:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -718)

    local trackerWarning = CreateFrame("Frame", nil, content, "BackdropTemplate")
    trackerWarning:SetPoint("TOPLEFT", content, "TOPLEFT", 20, -716)
    trackerWarning:SetSize(290, 140)
    trackerWarning:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    trackerWarning:SetBackdropColor(0.18, 0.09, 0.025, 0.90)
    trackerWarning:SetBackdropBorderColor(0.70, 0.40, 0.14, 0.86)
    local warningTitle = Font(trackerWarning, "Blizzard tracker is disabled", 12,
        {1, 0.78, 0.35}, 268)
    warningTitle:SetPoint("TOPLEFT", trackerWarning, "TOPLEFT", 10, -9)
    local warningBody = Font(trackerWarning,
        "Enable Blizzard External Defensives to show buffs. Move/resize icons in Esc > Edit Mode > External Defensives.",
        10, {0.95, 0.89, 0.80}, 266)
    warningBody:SetPoint("TOPLEFT", trackerWarning, "TOPLEFT", 10, -37)
    warningBody:SetWordWrap(true)
    local enableTrackerButton = CreateFrame("Button", nil, trackerWarning, "UIPanelButtonTemplate")
    enableTrackerButton:SetSize(262, 27)
    enableTrackerButton:SetPoint("BOTTOM", trackerWarning, "BOTTOM", 0, 10)
    enableTrackerButton:SetText(L("Enable Blizzard External Defensives"))

    local function RefreshTrackerStatus()
        local state = TrackerEnabled()
        trackerWarning:SetShown(state == false)
        trackerStatus:SetShown(state ~= false)
        if state == true then
            trackerStatus:SetText(L("Blizzard External Defensives: Enabled"))
            trackerStatus:SetTextColor(0.55, 0.90, 0.66)
        elseif state == nil then
            trackerStatus:SetText(L("Blizzard tracker status unavailable"))
            trackerStatus:SetTextColor(0.92, 0.77, 0.48)
        end
        if state == false then
            local inCombat = InCombatLockdown and InCombatLockdown()
            enableTrackerButton:SetEnabled(not inCombat)
            enableTrackerButton:SetText(L(inCombat and "Enable after combat" or
                "Enable Blizzard External Defensives"))
        end
    end
    enableTrackerButton:SetScript("OnClick", function()
        local success, err = EnableTracker()
        RefreshTrackerStatus()
        if success then
            print("|cff79d8ffImprovedExternalDefs|r: Blizzard External Defensives enabled. If the tracker is still missing, type /reload outside combat.")
        else
            print("|cff79d8ffImprovedExternalDefs|r: " .. tostring(err))
        end
    end)
    ns.RefreshTrackerStatus = RefreshTrackerStatus
    refreshers[#refreshers + 1] = RefreshTrackerStatus
    local trackerEvents = CreateFrame("Frame", nil, root)
    trackerEvents:RegisterEvent("CVAR_UPDATE")
    trackerEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
    trackerEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
    trackerEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    trackerEvents:SetScript("OnEvent", function(_, event, name)
        if event ~= "CVAR_UPDATE" or
            (type(name) == "string" and name:lower() == "externaldefensivesenabled") then
            RefreshTrackerStatus()
        end
    end)
    RefreshTrackerStatus()

    Heading("Cooldown sweep", 335, -18)
    Check("swipe", "Show dark cooldown sweep", 335, -54)
    Check("swipeReverse", "Reverse sweep", 335, -89)
    Slider("swipeOpacity", "Sweep darkness", 0.1, 0.95, 0.05, 335, -151,
        function(n) return math.floor(n * 100 + 0.5) .. "%" end)

    Heading("Combat tracker layout", 335, -264)
    local nativeModeHint = Font(content,
        "Icon position, size, orientation and spacing are controlled only through Blizzard Edit Mode.",
        11, {0.86, 0.77, 0.56}, 270)
    nativeModeHint:SetPoint("TOPLEFT", content, "TOPLEFT", 338, -300)
    nativeModeHint:SetWordWrap(true)
    Choice("nativeFallbackColor", "Fallback glow color", {
        {"WHITE", "Neutral white"}, {"GOLD", "Blizzard gold"},
        {"PALADIN", "Paladin pink"}, {"PRIEST", "Priest white"},
        {"DRUID", "Druid orange"}, {"SHAMAN", "Shaman blue"},
        {"MONK", "Monk green"}, {"EVOKER", "Evoker teal"},
    }, 335, -464, 254)
    Check("nativeClassFilter", "Combat class-colored glows", 335, -546)
    local classHint = Font(content,
        "Uses native aura groups to color known external defensives. Reload outside combat after changing this option. Requires native sweep mode.",
        10, {0.85, 0.76, 0.58}, 270)
    classHint:SetPoint("TOPLEFT", content, "TOPLEFT", 338, -584)
    classHint:SetWordWrap(true)
    Check("nativeSweepMode", "Use native combat sweep (requires /reload)", 335, -641)

    local testHint = Font(content,
        "Use the Test 3 externals button at the top of this panel from any tab. " ..
        "The simulated Paladin, Priest and Druid borders use their class colors when combat class glows are enabled.",
        11, {0.68, 0.76, 0.86}, 510)
    testHint:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -690)
    testHint:SetWordWrap(true)
    -- The live preview is entirely contained in the Icons page.
    local previewOK, previewErr = pcall(CreateLivePreview)
    if not previewOK then
        print("|cff79d8ffImprovedExternalDefs|r: Preview error: " .. tostring(previewErr))
        local warn = Font(content, "Live preview unavailable; enable Lua errors for details.", 12,
            {1, 0.55, 0.55}, 520)
        warn:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -974)
    end

    ---------------------------------------------------------
    -- TEXT: same settings that style live/native timers
    ---------------------------------------------------------
    content = pages.Text:GetScrollChild()
    Heading("Remaining time", 24, -18)
    Check("removeSecondsSuffix", "Hide 's' after the remaining seconds", 24, -58)

    -- Preserve the original 60s / Always options for existing profiles.
    -- Decimals are shown only BELOW the selected threshold.
    local decimalChoices = { { 0, "Off (whole seconds)" } }
    for seconds = 1, 10 do
        decimalChoices[#decimalChoices + 1] = { seconds, string.format(L("Below %d seconds"), seconds) }
    end
    decimalChoices[#decimalChoices + 1] = { 15, string.format(L("Below %d seconds"), 15) }
    decimalChoices[#decimalChoices + 1] = { 60, "Below 60 seconds" }
    decimalChoices[#decimalChoices + 1] = { 3600, "Always (tenths)" }
    Choice("durationDecimalsThreshold", "Fractional seconds", decimalChoices, 329, -58, 259)
    local decimalsHint = Font(content,
        "Shows tenths (3.7), not thousandths (3.700). Native combat timer: /reload after changing the fraction setting or the 's' suffix.",
        11, {0.80, 0.76, 0.54}, 255)
    decimalsHint:SetPoint("TOPLEFT", content, "TOPLEFT", 331, -144)
    decimalsHint:SetWordWrap(true)
    Choice("textPosition", "Timer position", {
        { "CENTER", "Center" }, { "TOP", "Above icon" },
        { "BOTTOM", "Below icon" }, { "DEFAULT", "Blizzard default" },
    }, 24, -126, 265)
    Slider("textSize", "Font size", 8, 30, 1, 24, -214,
        function(n) return n .. " pt" end)
    Check("textAutoScale", "Scale timer text with icons", 330, -214)
    local scaleHint = Font(content,
        "When enabled, the font size follows Blizzard Edit Mode icon scaling. Font size above is the baseline for a 30px icon. Turn off to keep a fixed size.",
        11, {0.72, 0.79, 0.89}, 265)
    scaleHint:SetPoint("TOPLEFT", content, "TOPLEFT", 335, -261)
    scaleHint:SetWordWrap(true)
    Slider("textX", "Horizontal offset (X)", -50, 50, 1, 24, -297,
        function(n) return n .. " px" end)
    Slider("textY", "Vertical offset (Y)", -50, 50, 1, 24, -380,
        function(n) return n .. " px" end)
    local timerHint = Font(content,
        "These settings also update the Live Preview on the Icons tab. Blizzard handles native cooldown durations in combat. Fractional seconds require /reload.",
        12, {0.72, 0.79, 0.89}, 535)
    timerHint:SetPoint("TOPLEFT", content, "TOPLEFT", 26, -484)
    timerHint:SetWordWrap(true)

    ---------------------------------------------------------
    -- SPELLS: per-spell native visibility + optional helpful buffs
    ---------------------------------------------------------
    content = pages.Spells:GetScrollChild()
    local spellsContent = content
    Heading("Tracked spells", 24, -18)
    local intro = Font(spellsContent,
        "Choose which defensives to display: buffs received from allies or stolen with Spellsteal. Blizzard-tracked spells are enabled by default; additional spells are optional.",
        11, {0.76, 0.83, 0.90}, 555)
    intro:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", 24, -55)
    intro:SetWordWrap(true)

    local function ParseIDs(source)
        local set = {}
        for digits in tostring(source or ""):gmatch("%d+") do
            local id = tonumber(digits)
            if id and id >= 1 and id <= 99999999 then set[id] = true end
        end
        return set
    end
    local function SaveIDs(set)
        local ids = {}
        for id, enabled in pairs(set) do if enabled then ids[#ids+1] = id end end
        table.sort(ids)
        return table.concat(ids, ",")
    end
    local function SpellName(id, fallback)
        if C_Spell and type(C_Spell.GetSpellName) == "function" then
            local ok, name = pcall(C_Spell.GetSpellName, id)
            if ok and type(name) == "string" and name ~= "" then return name end
        end
        return fallback or ("Spell " .. id)
    end
    local function ClassLabel(class)
        if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] then
            return LOCALIZED_CLASS_NAMES_MALE[class]
        end
        local labels = {DEATHKNIGHT="Death Knight", DEMONHUNTER="Demon Hunter",
            DRUID="Druid", EVOKER="Evoker", HUNTER="Hunter", MAGE="Mage",
            MONK="Monk", PALADIN="Paladin", PRIEST="Priest", ROGUE="Rogue",
            SHAMAN="Shaman", WARLOCK="Warlock", WARRIOR="Warrior"}
        return labels[class] or class
    end
    local function IsSelected(spell)
        local db = DB()
        if spell.kind == "SPECIAL" then
            if spell.id == 363916 then return db.extraObsidianScales == true end
            return db.extraIntervene == true
        end
        if spell.kind == "NATIVE" then
            if not ParseIDs(db.disabledNativeSpellIDs)[spell.id] then return true end
            -- Previously OPTIONAL variants retain their opt-in selection
            -- when a native family becomes a single checkbox in 1.5.32.
            local selected = ParseIDs(db.selectedExtraSpellIDs)
            for _, auraID in ipairs(spell.auraIDs or {}) do
                if selected[auraID] then return true end
            end
            return false
        end
        return ParseIDs(db.selectedExtraSpellIDs)[spell.id] == true
    end
    local hint = Font(spellsContent,
        "Emerald Communion and Tranquility indicate that an ALLY is channeling, even if you are out of range or receive no healing. Their icons appear beside the main row. Use /reload after changing tracked spells.",
        11, {0.95, 0.79, 0.51}, 555)
    hint:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", 24, -109)
    hint:SetWordWrap(true)
    local status = Font(spellsContent, "", 11, {0.73, 0.95, 0.74}, 540)
    status:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", 24, -166)

    local classChoices = { {"ALL", "All classes"} }
    local classSeen = {}
    for _,entry in ipairs(ns.SpellCatalog or {}) do
        if not classSeen[entry.class] then classSeen[entry.class] = true end
    end
    for _,class in ipairs({"DEATHKNIGHT","DEMONHUNTER","DRUID","EVOKER","HUNTER","MAGE","MONK","PALADIN","PRIEST","ROGUE","SHAMAN","WARLOCK","WARRIOR"}) do
        if classSeen[class] then classChoices[#classChoices+1] = {class, ClassLabel(class)} end
    end
    local selectedClass = "ALL"
    local query = ""
    local refreshCatalog
    local classLabel = Font(spellsContent, "Class", 12, {0.8, 0.84, 0.9})
    classLabel:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", 24, -193)
    local classDropdown
    classDropdown = MakeDropdown(spellsContent, function() return classChoices end,
        function() return selectedClass end,
        function(value)
            selectedClass = value
            UpdateDropdown(classDropdown)
            if refreshCatalog then refreshCatalog() end
            pages.Spells:SetVerticalScroll(0)
        end, 247)
    classDropdown:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", 24, -213)
    local searchLabel = Font(spellsContent, "Search localized name or Spell ID", 12, {0.8, 0.84, 0.9})
    searchLabel:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", 330, -193)
    local searchBox = MakeInput(330, -214, 268, 12)
    searchBox:SetText(L(""))

    local items = {}
    for _, spell in ipairs(ns.SpellCatalog or {}) do
        local cb = CreateFrame("CheckButton", nil, spellsContent, "UICheckButtonTemplate")
        cb:SetSize(25, 25)
        local icon = spellsContent:CreateTexture(nil, "ARTWORK")
        icon:SetSize(26, 26)
        icon:SetPoint("LEFT", cb, "RIGHT", 1, 0)
        -- Textures cannot receive mouse events. Put a transparent mouse-enabled
        -- frame exactly over the spell icon so hovering it shows the same
        -- tooltip as hovering the checkbox (without changing checkbox clicks).
        local iconHover = CreateFrame("Frame", nil, spellsContent)
        iconHover:SetSize(26, 26)
        iconHover:SetPoint("CENTER", icon, "CENTER")
        iconHover:SetFrameLevel(cb:GetFrameLevel() + 1)
        iconHover:EnableMouse(true)
        local caption = Font(spellsContent, "", 11, {0.94, 0.95, 0.97}, 217)
        caption:SetPoint("LEFT", icon, "RIGHT", 7, 0)
        caption:SetWordWrap(false)
        local badge = Font(spellsContent, spell.kind == "NATIVE" and "Blizzard" or
            (spell.kind == "SPECIAL" and "Extra" or (spell.kind == "CAST" and "Caster" or "Optional")), 9,
            {0.63, 0.73, 0.82})
        badge:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -2)
        local outOfRangeWarning
        if spell.kind == "CAST" then
            outOfRangeWarning = Font(spellsContent, "OUT OF RANGE: icon may still appear", 10,
                {1.00, 0.28, 0.28}, 240)
            outOfRangeWarning:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -1)
            outOfRangeWarning:SetWordWrap(false)
        end
        local function ShowTip(owner)
            if not GameTooltip then return end
            GameTooltip:SetOwner(owner or cb, "ANCHOR_RIGHT")
            local publicID = spell.displayID or spell.id
            local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, publicID)
            if not ok then GameTooltip:AddLine(SpellName(publicID, spell.english)) end
            if spell.auraIDs then
                GameTooltip:AddLine(L("Buff Spell IDs: ") .. table.concat(spell.auraIDs, ", "), 0.75, 0.85, 0.98)
            else
                GameTooltip:AddLine(L(spell.kind == "CAST" and "Caster aura Spell ID: " or "Buff Spell ID: ") .. publicID, 0.75, 0.85, 0.98)
            end
            if spell.source == "CAST" then
                GameTooltip:AddLine(L("WARNING: This icon can appear even if you are out of range or receive no healing. It tracks the allied caster, not you."), 1, 0.35, 0.35, true)
            elseif spell.source == "STEAL" then
                GameTooltip:AddLine(L("Stealable defensive Magic buff"), 0.7, 0.85, 1)
            elseif spell.source == "BOTH" then
                GameTooltip:AddLine(L("Ally defensive / Spellsteal"), 0.7, 0.85, 1)
            else
                GameTooltip:AddLine(L("Defensive received from an ally"), 0.7, 0.85, 1)
            end
            if spell.note then GameTooltip:AddLine(L(spell.note), 0.9, 0.75, 0.5, true) end
            GameTooltip:Show()
        end
        cb:SetScript("OnEnter", ShowTip)
        cb:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        iconHover:SetScript("OnEnter", ShowTip)
        iconHover:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        cb:SetScript("OnClick", function(button)
            if InCombatLockdown and InCombatLockdown() then
                button:SetChecked(IsSelected(spell))
                status:SetText(L("Change tracked spells outside combat."))
                return
            end
            local enabled = not not button:GetChecked()
            local db = DB()
            if spell.kind == "SPECIAL" then
                if spell.id == 363916 then db.extraObsidianScales = enabled
                else db.extraIntervene = enabled end
            elseif spell.kind == "NATIVE" then
                local disabled = ParseIDs(db.disabledNativeSpellIDs)
                for _, auraID in ipairs(spell.auraIDs or {spell.id}) do
                    disabled[auraID] = not enabled or nil
                end
                db.disabledNativeSpellIDs = SaveIDs(disabled)
                -- Clear the pre-1.5.32 separate OPTIONAL variant toggle, so
                -- turning OFF the native family really turns off both IDs.
                if spell.auraIDs then
                    local enabledExtra = ParseIDs(db.selectedExtraSpellIDs)
                    for _, auraID in ipairs(spell.auraIDs) do
                        enabledExtra[auraID] = nil
                    end
                    db.selectedExtraSpellIDs = SaveIDs(enabledExtra)
                end
            else
                local enabledExtra = ParseIDs(db.selectedExtraSpellIDs)
                enabledExtra[spell.id] = enabled or nil
                db.selectedExtraSpellIDs = SaveIDs(enabledExtra)
            end
            -- Aura sounds are registered with Blizzard separately from the
            -- visual tracker. Unregister a newly unchecked spell IMMEDIATELY,
            -- even though its protected visual group needs /reload.
            status:SetText(L("Saved! Sounds updated now; /reload outside combat to update the icons."))
            Changed()
        end)
        items[#items+1] = {spell=spell,cb=cb,icon=icon,iconHover=iconHover,caption=caption,badge=badge,warning=outOfRangeWarning}
    end
    refreshCatalog = function()
        local shown = 0
        for _, item in ipairs(items) do
            local spell = item.spell
            local publicID = spell.displayID or spell.id
            local localized = SpellName(publicID, spell.english)
            local matchesClass = selectedClass == "ALL" or selectedClass == spell.class
            local idsForSearch = spell.auraIDs and table.concat(spell.auraIDs, " ") or tostring(publicID)
            local searchText = (localized .. " " .. spell.english .. " " .. idsForSearch .. " " .. spell.id):lower()
            local matchesSearch = query == "" or searchText:find(query, 1, true) ~= nil
            local display = matchesClass and matchesSearch
            item.cb:SetShown(display)
            item.icon:SetShown(display)
            item.iconHover:SetShown(display)
            item.caption:SetShown(display)
            item.badge:SetShown(display)
            if item.warning then item.warning:SetShown(display) end
            if display then
                local col, line = shown % 2, math.floor(shown / 2)
                local x, y = 19 + col * 303, -460 - line * 47
                item.cb:ClearAllPoints()
                item.cb:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", x, y)
                item.cb:SetChecked(IsSelected(spell))
                item.caption:SetText(localized .. " (" .. publicID .. ")")
                local origin = spell.source == "CAST" and "Party caster" or
                    (spell.source == "STEAL" and "Spellsteal" or
                    (spell.source == "BOTH" and "Ally / Spellsteal" or "Ally"))
                local state = spell.kind == "NATIVE" and "Blizzard" or
                    (spell.kind == "SPECIAL" and "Extra" or (spell.kind == "CAST" and "Caster" or "Optional"))
                item.badge:SetText(L(origin) .. "  -  " .. L(state) ..
                    ((spell.auraIDs and #spell.auraIDs > 1) and
                        ("  -  " .. #spell.auraIDs .. " IDs") or ""))
                local tex = ns.GetDemoSpellTexture(publicID, 134400)
                item.icon:SetTexture(tex)
                shown = shown + 1
            end
        end
        spellsContent:SetHeight(math.max(1100, 535 + math.ceil(shown / 2) * 47))
        if shown == 0 then status:SetText(L("No spells found for this filter.")) end
    end
    searchBox:SetScript("OnTextChanged", function(self)
        query = (self:GetText() or ""):lower():match("^%s*(.-)%s*$") or ""
        refreshCatalog()
    end)
    refreshers[#refreshers+1] = refreshCatalog
    refreshCatalog()
    ---------------------------------------------------------
    -- Custom IDs from 1.5.27, now on the Spells tab
    ---------------------------------------------------------
    local customLabel = Font(spellsContent, "Custom Spell IDs (up to 50)", 11, {0.8, 0.87, 0.94}, 300)
    customLabel:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", 24, -254)
    -- Custom IDs have their own scrollable list; the normal catalogue starts
    -- below this block and is never pushed around when 50 IDs are entered.
    local customBox = MakeInput(330, -253, 160, 12)
    local customBtn = CreateFrame("Button", nil, spellsContent, "UIPanelButtonTemplate")
    customBtn:SetSize(85, 26)
    customBtn:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", 501, -252)
    customBtn:SetText(L("Add / Del"))

    local customScroll = CreateFrame("ScrollFrame", nil, spellsContent, "UIPanelScrollFrameTemplate")
    customScroll:SetPoint("TOPLEFT", spellsContent, "TOPLEFT", 24, -299)
    customScroll:SetSize(561, 135)
    local scrollBackground = customScroll:CreateTexture(nil, "BACKGROUND")
    scrollBackground:SetAllPoints()
    scrollBackground:SetColorTexture(0.06, 0.09, 0.14, 0.55)
    local customChild = CreateFrame("Frame", nil, customScroll)
    customChild:SetSize(535, 135)
    customScroll:SetScrollChild(customChild)

    local rows = {}
    local requestedSpells = {}
    local RefreshCustomList
    local function RemoveCustomSpell(id)
        if InCombatLockdown and InCombatLockdown() then
            status:SetText(L("Change tracked spells outside combat."))
            return
        end
        local ids = ParseIDs(DB().extraSpellIDs)
        if not ids[id] then return end
        ids[id] = nil
        DB().extraSpellIDs = SaveIDs(ids)
        status:SetText(string.format(L("Removed custom spell %d. /reload to apply."), id))
        if ns.QueueAuraSoundSync then ns.QueueAuraSoundSync(true) end
        Changed()
    end
    local function CustomRow(index)
        if rows[index] then return rows[index] end
        local row = CreateFrame("Frame", nil, customChild)
        row:SetSize(262, 25)
        row:EnableMouse(true)
        local background = row:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.17, 0.22, 0.29, 0.45)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
        icon:SetPoint("LEFT", row, "LEFT", 3, 0)
        local name = Font(row, "", 11, {0.93, 0.94, 0.95}, 202)
        name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        name:SetWordWrap(false)
        local remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        remove:SetSize(21, 21)
        remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        remove:SetText("X")
        remove:SetScript("OnClick", function()
            if row.spellID then RemoveCustomSpell(row.spellID) end
        end)
        local function ShowCustomTooltip(owner)
            if not GameTooltip or not row.spellID then return end
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, row.spellID)
            if not ok then GameTooltip:AddLine(SpellName(row.spellID)) end
            GameTooltip:AddLine(L("Custom Spell ID: ") .. row.spellID, 0.72, 0.86, 0.99)
            GameTooltip:Show()
        end
        row:SetScript("OnEnter", ShowCustomTooltip)
        row:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        remove:SetScript("OnEnter", ShowCustomTooltip)
        remove:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        rows[index] = {frame=row, icon=icon, name=name}
        return rows[index]
    end
    local emptyListText = Font(customChild, "No custom Spell IDs yet.", 11, {0.67, 0.76, 0.85})
    emptyListText:SetPoint("TOPLEFT", customChild, "TOPLEFT", 9, -12)

    RefreshCustomList = function()
        local ids = {}
        for id in pairs(ParseIDs(DB().extraSpellIDs)) do ids[#ids + 1] = id end
        table.sort(ids)
        customLabel:SetText(L("Custom Spell IDs (up to 50)") .. " (" .. #ids .. "/50)")
        emptyListText:SetShown(#ids == 0)
        for i, id in ipairs(ids) do
            local row = CustomRow(i)
            row.frame.spellID = id
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", customChild, "TOPLEFT", ((i - 1) % 2) * 269, -math.floor((i - 1) / 2) * 28 - 3)
            row.icon:SetTexture(ns.GetDemoSpellTexture(id, 134400))
            row.name:SetText(SpellName(id, L("Unknown spell")) .. " (" .. id .. ")")
            row.frame:Show()
            -- Spell data are loaded asynchronously for IDs not yet cached.
            -- This uses only the manually entered number, never combat auras.
            if C_Spell and type(C_Spell.RequestLoadSpellData) == "function" and not requestedSpells[id] then
                requestedSpells[id] = true
                pcall(C_Spell.RequestLoadSpellData, id)
            end
        end
        for i = #ids + 1, #rows do rows[i].frame:Hide() end
        customChild:SetHeight(math.max(135, math.ceil(#ids / 2) * 28 + 5))
        local maxScroll = math.max(0, customChild:GetHeight() - customScroll:GetHeight())
        if customScroll:GetVerticalScroll() > maxScroll then customScroll:SetVerticalScroll(maxScroll) end
    end
    local spellLoadListener = CreateFrame("Frame", nil, spellsContent)
    spellLoadListener:RegisterEvent("SPELL_DATA_LOAD_RESULT")
    spellLoadListener:SetScript("OnEvent", function(_, _, spellID, success)
        if success and ParseIDs(DB().extraSpellIDs)[spellID] then
            RefreshCustomList()
        end
    end)
    refreshers[#refreshers + 1] = RefreshCustomList
    RefreshCustomList()

    customBtn:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            status:SetText(L("Change tracked spells outside combat.")) return end
        local typed = customBox:GetText() or ""
        if not typed:match("^[1-9]%d*$") then status:SetText(L("Enter a numeric Spell ID.")) return end
        local id = tonumber(typed)
        if not id or id > 99999999 then status:SetText(L("Invalid Spell ID.")) return end
        local ids = ParseIDs(DB().extraSpellIDs)
        if ids[id] then
            ids[id] = nil
            status:SetText(string.format(L("Removed custom spell %d. /reload to apply."), id))
        else
            local count = 0
            for _ in pairs(ids) do count = count + 1 end
            if count >= 50 then status:SetText(L("Limit: 50 custom Spell IDs.")) return end
            ids[id] = true
            status:SetText(string.format(L("Added custom spell %d. /reload to apply."), id))
        end
        DB().extraSpellIDs = SaveIDs(ids)
        if ns.QueueAuraSoundSync then ns.QueueAuraSoundSync(true) end
        customBox:SetText("")
        customBox:ClearFocus()
        Changed()
    end)

    ---------------------------------------------------------
    -- PROFILES: saved configurations, import / export, reset
    ---------------------------------------------------------
    content = pages.Profiles:GetScrollChild()
    local profilesOK, profilesErr = pcall(CreateProfilesPanel)
    if not profilesOK then
        print("|cff79d8ffImprovedExternalDefs|r: Profiles error: " .. tostring(profilesErr))
    end
    local reset = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    reset:SetPoint("TOPLEFT", content, "TOPLEFT", 24, -545)
    reset:SetSize(170, 29)
    reset:SetText(L("Reset to defaults"))
    reset:SetScript("OnClick", function() root.OnDefault() end)
    local resetHint = Font(content, "Resets current settings; saved profiles can still be loaded.",
        11, {0.73, 0.78, 0.85}, 385)
    resetHint:SetPoint("LEFT", reset, "RIGHT", 12, 0)

    -- Default landing page and updates.
    SelectPage("Icons")
    ns.RefreshOptions()
end
