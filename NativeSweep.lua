-- ImprovedExternalDefs v1.5.17 - outer-only neon glow and matched synthetic native tests.
-- Uses documented game UI widgets and their secure engine duration bindings.
-- DOES NOT copy or embed any code or media from Externals On Me.
local _, ns = ...
local managed, stock, parent, testPivot
local slots = {}
local initialized, attempts, problem = false, 0, nil
local darknessGroupCreated = false
local anchorHooked = false
-- The Blizzard Edit Mode preview can be offset within its large stock
-- AuraContainer. Sample its dedicated placeholder outside combat and use its
-- center as the centered layout's true position reference.
local MAX_ICONS = 5
local GROUP = "EDCDExternalDefensiveBuffs"
-- Native class-filtered AuraGroups: each matches a family of spell IDs in
-- Blizzard's C++ filtering layer. A group has a preconfigured class glow;
-- Lua NEVER tests spell identity or caster during combat. The fallback group
-- catches spells not represented by the class maps.
-- Server-side filtering is supported on this client; grouping may
-- still change cross-class ordering in some layouts.
-- Class-colored native externals. Additional opt-in spells are handled by
-- HELPFUL + includeSpellIDs below. Keeping this list small prevents stray
-- personal defensive IDs from entering a class group accidentally.
local CLASS_GROUPS = {
    {class="PALADIN", ids={6940, 199448, 1022, 204018}},
    {class="PRIEST", ids={33206, 47788}},
    {class="DRUID", ids={102342}},
    {class="MONK", ids={116849}},
    {class="EVOKER", ids={357170, 374227}},
}
local classGroupsAdded = 0
local additionalGroupKeys = {}
local nativeGroupKeys = {}

-- All lists are configured while out of combat, before AddAuraGroup creates
-- protected native buttons. Spell names are never used to identify auras.
-- An explicit Spell ID whitelist is already provided through includeSpellIDs.
-- Do NOT negate EXTERNAL_DEFENSIVE here: some additional buffs share Blizzard
-- category flags without appearing on the stock tracker. Such a negation
-- rejects the aura before the ID filter can match it (e.g. Darkness).
local EXTRA_FILTER = "HELPFUL"

local function CSVSet(value, maxCount)
    local output, count = {}, 0
    if type(value) ~= "string" then return output end
    for digits in value:gmatch("%d+") do
        local id = tonumber(digits)
        if id and id > 0 and id <= 99999999 and not output[id] and count < maxCount then
            output[id] = true
            count = count + 1
        end
    end
    return output
end

local function HiddenNativeIDs(db)
    local disabled = CSVSet(db.disabledNativeSpellIDs, 100)
    -- These older dedicated options are retained in existing profiles.
    if db.extraIntervene == false then
        disabled[147833] = true
        disabled[3411] = true
    end
    if db.extraObsidianScales == false then disabled[363916] = true end
    -- A native checkbox hides its complete verified aura family. Preserve
    -- old profiles that independently opted into an OPTIONAL variant (e.g.
    -- Sacrifice 199448), without rewriting their saved selections.
    local legacyOptional = CSVSet(db.selectedExtraSpellIDs, 100)
    for _, entry in ipairs(ns.SpellCatalog or {}) do
        if entry.kind == "NATIVE" and entry.auraIDs and disabled[entry.id] then
            for _, auraID in ipairs(entry.auraIDs) do
                if auraID ~= entry.id and not legacyOptional[auraID] then
                    disabled[auraID] = true
                end
            end
        end
    end
    return disabled
end

-- The Blizzard category itself may contain auras outside this addon's strict
-- external/stealable defensive scope. Only catalogued NATIVE defensive IDs
-- are allowed through the standard native groups. Everything else must be
-- explicitly enabled as SPECIAL / OPTIONAL / custom HELPFUL candidates.
local function NativeAllowedIDs(hidden)
    local allowed = {}
    for _, entry in ipairs(ns.SpellCatalog or {}) do
        if entry.kind == "NATIVE" then
            for _, id in ipairs(entry.auraIDs or {entry.id}) do
                if not hidden[id] then allowed[id] = true end
            end
        end
    end
    return allowed
end

-- Apply named spell selection without reading auras in combat. The engine
-- receives immutable spell-ID candidate filters at initialization.
local function AdditionalGroups(db)
    local used = {}
    local classIDs = {}
    local allowed = CSVSet(db.selectedExtraSpellIDs, 100)
    local hidden = HiddenNativeIDs(db)
    -- A checkbox can represent several *buff* IDs (cast versus received
    -- aura, or multiple supported buff variants). This is data-driven for
    -- every selected spell, rather than special-casing Darkness in the tracker.
    local catalogIndex = {}
    for _, entry in ipairs(ns.SpellCatalog or {}) do
        catalogIndex[entry.id] = entry
        for _, variantID in ipairs(entry.auraIDs or {}) do
            if not catalogIndex[variantID] then
                catalogIndex[variantID] = entry
            end
        end
    end
    local function Add(id, class)
        local entry = catalogIndex[id]
        local auraIDs = entry and entry.auraIDs or {id}
        local key = class or (entry and entry.class) or "OTHER"
        for _, auraID in ipairs(auraIDs) do
            -- Protected-aura matching happens inside Blizzard's engine.
            -- Never inspect spell identity, duration or caster in combat.
            if not hidden[auraID] and not used[auraID] then
                used[auraID] = true
                if not classIDs[key] then classIDs[key] = {} end
                classIDs[key][#classIDs[key] + 1] = auraID
            end
        end
    end
    if db.extraObsidianScales == true then Add(363916, "EVOKER") end
    if db.extraIntervene == true then Add(147833, "WARRIOR") end
    for _,entry in ipairs(ns.SpellCatalog or {}) do
        -- A native spell with multiple verified buff IDs needs HELPFUL
        -- matching for the full family: talent variants might not carry the
        -- native EXTERNAL_DEFENSIVE flag. Redirect it away from the standard
        -- group, preserving exactly one icon per actual aura.
        if entry.kind == "NATIVE" and entry.auraIDs then
            local selected = not hidden[entry.id]
            for _, auraID in ipairs(entry.auraIDs) do
                if allowed[auraID] then selected = true end
            end
            if selected then Add(entry.id, entry.class) end
        end
    end
    for _,entry in ipairs(ns.SpellCatalog or {}) do
        if entry.kind == "OPTIONAL" and allowed[entry.id] then
            Add(entry.id, entry.class)
        end
    end
    local custom = CSVSet(db.extraSpellIDs, 50)
    for id in pairs(custom) do
        local entry = catalogIndex[id]
        Add(id, entry and entry.class or "OTHER")
    end
    local keys, groups = {}, {}
    for class in pairs(classIDs) do keys[#keys+1] = class end
    table.sort(keys)
    for _,class in ipairs(keys) do
        table.sort(classIDs[class])
        groups[#groups+1] = {key=class, class=(class ~= "OTHER" and class or nil), ids=classIDs[class]}
    end
    return groups
end
local function SpellIDSet(ids)
    local result = {}
    for _, id in ipairs(ids) do result[id] = true end
    return result
end
local function UsesClassGroups()
    local db = NoExternalPulseDB
    return db and db.nativeClassFilter == true
end
-- Public spell artwork can occasionally identify an external when the game's
-- icon texture is readable. Unknown/secret art is NEVER inspected or compared.
-- No caster or aura duration data is queried here in combat.
local spellArtClasses = {
    [33206]="PRIEST", [47788]="PRIEST", [102342]="DRUID", [6940]="PALADIN",
    [1022]="PALADIN", [204018]="PALADIN", [116849]="MONK", [357170]="EVOKER",
    [374227]="EVOKER",
}
local textureClassMap = {}
local function BuildTextureClassMap()
    if not (C_Spell and type(C_Spell.GetSpellTexture)=="function") then return end
    for spell, class in pairs(spellArtClasses) do
        local ok, id = pcall(C_Spell.GetSpellTexture, spell)
        if ok and type(id)=="number" and not (type(issecretvalue)=="function" and issecretvalue(id)) then
            if textureClassMap[id] and textureClassMap[id] ~= class then
                textureClassMap[id] = false -- ambiguous icon, do not guess
            elseif textureClassMap[id] == nil then
                textureClassMap[id] = class
            end
        end
    end
end

local function Database() return NoExternalPulseDB end
local function Enabled()
    return Database() and Database().nativeSweepMode and not Database().safeMode
end
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local function Log(message)
    print("|cff79d8ffImprovedExternalDefs|r: " .. tostring(message))
end
local function IsSecret(x)
    return type(issecretvalue) == "function" and issecretvalue(x)
end
local function IsEditing()
    if parent and type(parent.IsEditing) == "function" then
        local ok, isEditing = pcall(parent.IsEditing, parent)
        if ok and not IsSecret(isEditing) then return isEditing == true end
    end
    return false
end
-- The stock Blizzard aura container is hidden with zero alpha when the
-- supplementary tracker is active. Zero alpha does NOT prevent its aura
-- buttons from receiving hover events, so those invisible native buttons
-- can still display tooltips over our visible icons. Only disable mouse
-- MOTION (tooltips), never mouse clicks or the Blizzard aura engine.
-- Perform the change outside combat and avoid restricted OnEnter scripts.
local mouseMotionDisabled = setmetatable({}, {__mode="k"})
local function DisableAuraHover(frame)
    if not frame or mouseMotionDisabled[frame] or InCombat() then return end
    if type(frame.SetMouseMotionEnabled) ~= "function" then return end
    local ok = pcall(frame.SetMouseMotionEnabled, frame, false)
    if ok then mouseMotionDisabled[frame] = true end
end
local function DisableNativeAuraHover()
    if not stock or not parent or InCombat() then return end
    DisableAuraHover(stock)
    -- Blizzard's stock tracker keeps the buttons in auraFrames, independent
    -- of the custom AuraButtons created by our native supplementary groups.
    if type(parent.auraFrames) == "table" then
        for _, button in ipairs(parent.auraFrames) do
            DisableAuraHover(button)
        end
    end
end
local function SetLegacyVisibility()
    if InCombat() or not managed or not stock then return end
    -- Preserve the stock Blizzard aura processing: hiding the stock frame
    -- outright can stop Blizzard's aura updates. Alpha alone does not stop
    -- tooltips, hence the targeted mouse-motion suppression above.
    DisableNativeAuraHover()
    local edit = IsEditing()
    stock:SetAlpha(edit and 1 or 0)
    managed:SetShown(not edit)
end

-- The icon is 30 layout units at Blizzard's default Edit Mode scale.
-- Read only public frame dimensions OUTSIDE combat. Do not inspect aura
-- durations or modify protected layout at runtime.  The preview/test can
-- have a different parent scale (fontFactor), so divide that out before
-- applying the true Edit Mode icon multiplier.
local BASE_ICON_SIZE = 30
local lastPreviewWidth, lastPreviewHeight, lastNativeEffectiveScale = 30, 30, 1
local function TimerFontSize(d, icon, fontFactor)
    local size = (d.textSize or 14) * fontFactor
    if d.textAutoScale ~= true then return size end
    local width
    if icon and type(icon.GetWidth) == "function" then
        local ok, measured = pcall(icon.GetWidth, icon)
        if ok and type(measured) == "number" and not IsSecret(measured)
            and measured == measured and measured > 0 then
            width = measured
        end
    end
    if not width then
        -- Last public native layout metric, cached only out of combat.
        width = lastPreviewWidth and lastPreviewWidth * fontFactor or BASE_ICON_SIZE * fontFactor
    end
    local multiplier = width / (BASE_ICON_SIZE * fontFactor)
    if multiplier < 0.3 or multiplier > 3 then multiplier = 1 end
    return math.max(6, math.min(42, size * multiplier))
end

local function FontStyle(text, icon, fontFactor)
    local d = Database()
    fontFactor = fontFactor or 1
    text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", TimerFontSize(d, icon, fontFactor), "OUTLINE")
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:ClearAllPoints()
    local x, y = (d.textX or 0) * fontFactor, (d.textY or 0) * fontFactor
    if d.textPosition == "TOP" then
        text:SetPoint("BOTTOM", icon, "TOP", x, y + 3 * fontFactor)
    elseif d.textPosition == "BOTTOM" or d.textPosition == "DEFAULT" then
        text:SetPoint("TOP", icon, "BOTTOM", x, y - 3 * fontFactor)
    else
        text:SetPoint("CENTER", icon, "CENTER", x, y)
    end
end

-- Shared styling for real native AuraButtons and the settings demo.
-- A pure visual function: never reads or changes the aura's secret duration.
ns.StyleNativeTimer = FontStyle

local nativeTestAnchor = "TOPLEFT"
local nativeTestHorizontal, nativeTestRight, nativeTestUp = true, true, false
local function PublicNumber(value, fallback)
    if type(value) == "number" and not IsSecret(value) and value > 0 then return value end
    return fallback
end
function ns.NativePreviewMetrics(previewHolder)
    -- Values are cached outside combat. Settings preview may be created even
    -- when real aura slots are hidden or the native frame is protected.
    local previewScale = 1
    if previewHolder and type(previewHolder.GetEffectiveScale) == "function" then
        local ok, measured = pcall(previewHolder.GetEffectiveScale, previewHolder)
        if ok then previewScale = PublicNumber(measured, 1) end
    end
    local factor = lastNativeEffectiveScale / previewScale
    factor = math.max(0.5, math.min(3, factor))
    return lastPreviewWidth * factor, lastPreviewHeight * factor, factor
end
-- Provides display geometry to the independent 3-icon test. No aura values
-- are read: all numbers come from the tracker layout cached outside combat.
function ns.NativeTestLayout()
    if not Enabled() or not managed then return nil end
    local uiScale = 1
    if UIParent and UIParent.GetEffectiveScale then
        local ok, measured = pcall(UIParent.GetEffectiveScale, UIParent)
        if ok then uiScale = PublicNumber(measured, 1) end
    end
    local factor = math.max(0.5, math.min(3, lastNativeEffectiveScale / uiScale))
    local d = Database() or {}
    local spacing = tonumber(d.nativeIconSpacing) or 2
    spacing = math.max(0, math.min(20, spacing)) * factor
    -- The test always marks the desired Edit Mode point. It must NOT
    -- inherit any calibration applied to the real AuraContainer's flow.
    local reference = Database() and Database().nativeLayout == "CENTERED" and testPivot or managed
    return reference, nativeTestAnchor,
        lastPreviewWidth * factor, lastPreviewHeight * factor,
        factor, spacing, nativeTestHorizontal, nativeTestRight, nativeTestUp
end
function ns.NativeFallbackGlowColor()
    local db = Database() or {}
    if db.glowColorMode == "CUSTOM" then return ns.GetConfiguredGlowColor() end
    local palette = ns.CLASS_COLORS or {}
    local fallback = db.nativeFallbackColor or "WHITE"
    if fallback == "GOLD" then return ns.FALLBACK_COLOR or {1, .82, .35} end
    if fallback == "WHITE" then return {1, 1, 1} end
    return palette[fallback] or {1, 1, 1}
end

-- Native duration text formatter. The game's engine passes secret duration
-- values to this object internally, so addons never read or compare them.
-- A decimal displays tenths (3.7), not three-digit milliseconds (3.700).
local durationFormats = {}
local function DurationFormatter()
    local db = Database()
    local threshold = db.durationDecimalsThreshold or 0
    local noSuffix = db.removeSecondsSuffix == true
    if threshold == 0 and not noSuffix then return nil end -- stock Blizzard formatting
    local key = tostring(threshold) .. (noSuffix and ":no-s" or ":s")
    if durationFormats[key] then return durationFormats[key] end
    local api = C_StringUtil
    local rounding = Enum and Enum.NumericRuleFormatRounding
    if not api or type(api.CreateNumericRuleFormatter) ~= "function" or not rounding then return nil end
    local ok, result = pcall(function()
        local format = api.CreateNumericRuleFormatter()
        local breakpoints = {}
        if threshold > 0 then
            breakpoints[#breakpoints + 1] = {
                threshold = 0, step = 0.1, rounding = rounding.Up, min = 0,
                format = noSuffix and "%.1f" or "%.1fs",
            }
        end
        breakpoints[#breakpoints + 1] = {
            threshold = threshold, step = 1, rounding = rounding.Up, min = 0,
            format = noSuffix and "%d" or "%ds",
        }
        format:SetBreakpoints(breakpoints)
        return format
    end)
    if ok and result then durationFormats[key] = result end
    return ok and result or nil
end

-- Only synthetic, local timers use these arithmetic operations; never apply
-- this helper to real aura values, which can be secret in combat.
function ns.FormatSyntheticDuration(seconds)
    local db = Database() or {}
    local threshold = db.durationDecimalsThreshold or 0
    local suffix = db.removeSecondsSuffix and "" or "s"
    if threshold > 0 and seconds < threshold then
        local tenths = math.ceil(math.max(0, seconds) * 10 - 1e-7) / 10
        return string.format("%.1f%s", tenths, suffix)
    end
    return tostring(math.ceil(math.max(0, seconds))) .. suffix
end

local function AuraGlowColor(icon)
    local palette = ns.CLASS_COLORS or {}
    local neutral = ns.NativeFallbackGlowColor()
    if icon and icon.GetTexture then
        local ok, texture = pcall(icon.GetTexture, icon)
        -- Reading/comparing protected combat texture values is forbidden.
        if ok and type(texture)=="number" and not IsSecret(texture) then
            local class = textureClassMap[texture]
            if class and palette[class] then return palette[class] end
        end
    end
    return neutral
end

local function GlowRegions(owner, icon)
    local layer = CreateFrame("Frame", nil, owner)
    layer:SetAllPoints(owner)
    layer:SetFrameLevel(owner:GetFrameLevel() + 5)
    layer:SetIgnoreParentAlpha(true)
    local halo = layer:CreateTexture(nil, "ARTWORK", nil, 1)
    halo:SetTexture("Interface\\AddOns\\ImprovedExternalDefs\\Media\\NeonOutline.tga")
    halo:SetBlendMode("ADD")
    local edges = {}
    for i = 1,4 do
        local edge = layer:CreateTexture(nil, "OVERLAY", nil, 3)
        edge:SetColorTexture(1,1,1,1)
        edge:SetBlendMode("ADD")
        edges[i] = edge
    end
    return layer, halo, edges
end

local function StyleManaged(slot)
    local d = Database()
    local icon, cd, text = slot.icon, slot.cooldown, slot.duration
    icon:SetAlpha(d.iconOpacity or 1)
    cd:SetDrawSwipe(d.swipe ~= false)
    cd:SetDrawBling(false)
    cd:SetDrawEdge(false)
    cd:SetHideCountdownNumbers(true)
    cd:SetSwipeColor(0, 0, 0, d.swipeOpacity or .55)
    if cd.SetReverse then cd:SetReverse(d.swipeReverse == true) end
    FontStyle(text, icon)
    -- The native aura button keeps duration data hidden; use public artwork
    -- only when accessible, and a neutral user-selected glow otherwise.
    local color = ns.GetConfiguredGlowColor(
        slot.classKey and ns.CLASS_COLORS[slot.classKey] or AuraGlowColor(icon))
    ns.PaintGlow(icon, slot.halo, slot.edges, nil, nil, d,
        color, 1, true)
    slot.halo:SetIgnoreParentAlpha(true)
    for _, edge in ipairs(slot.edges) do edge:SetIgnoreParentAlpha(true) end
end

local function InitializeButton(button, assignedClass)
    attempts = attempts + 1
    -- The callback is used by Blizzard's native CustomAuraContainerTemplate.
    -- On real AuraButtons the engine supplies these two registration methods.
    local ok, errorText = pcall(function()
        -- AuraButton tooltip handling is intrinsic on Retail 12.1+. Apply
        -- this BEFORE binding aura icon/duration widgets, while the native
        -- initializeFrame callback still permits changes to the button.
        -- Do not HookScript or modify GameTooltip globally.
        DisableAuraHover(button)
        assert(type(button.SetDurationCooldown) == "function", "No SetDurationCooldown on custom AuraButton")
        assert(type(button.SetDurationText) == "function", "No SetDurationText on custom AuraButton")

        button:SetSize(30, 40)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(30, 30)
        icon:SetPoint("TOP", button, "TOP", 0, 0)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:SetIgnoreParentAlpha(true)
        local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cooldown:SetAllPoints(icon)
        cooldown:SetFrameLevel(button:GetFrameLevel() + 1)
        cooldown:EnableMouse(false)
        cooldown:SetIgnoreParentAlpha(true)
        local overlay = CreateFrame("Frame", nil, button)
        overlay:SetAllPoints(button)
        overlay:SetFrameLevel(button:GetFrameLevel() + 8)
        overlay:SetIgnoreParentAlpha(true)
        local duration = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        duration:SetIgnoreParentAlpha(true)
        -- Complete registration BEFORE the button can receive protected aura
        -- data; WoW's engine will advance BOTH the timer and swipe thereafter.
        button:SetIcon(icon)
        local format = DurationFormatter()
        if format then
            button:SetDurationText(duration, {textFormatter=format})
        else
            button:SetDurationText(duration)
        end
        button:SetDurationCooldown(cooldown)
        -- Mouse-motion was disabled at the start of initializeFrame, before
        -- Blizzard's aura-duration bindings could protect the button.
        -- SetHideTooltipInCombat is only a secondary safeguard; we also want
        -- tooltips disabled outside combat.
        if type(button.SetHideTooltipInCombat) == "function" then
            pcall(button.SetHideTooltipInCombat, button, true)
        end
        local glowLayer, halo, edges = GlowRegions(button, icon)
        local record = {frame=button, icon=icon, cooldown=cooldown,
            duration=duration, glowLayer=glowLayer, halo=halo, edges=edges,
            classKey=assignedClass}
        slots[#slots + 1] = record
        StyleManaged(record)
        -- Do not HookScript("OnShow") on an intrinsic AuraButton: after
        -- assignment to the native AuraContainer it has forbidden script
        -- aspects. StyleManaged() above applies the chosen appearance without
        -- installing any forbidden handler (the source of login chat spam).
    end)
    if not ok then
        problem = tostring(errorText)
        Log("Native sweep button initialization failed: " .. problem)
    end
end


-- Party caster AuraContainers follow different units, so they cannot join
-- the player-only aura group. Share the SAME native rendering setup (timer,
-- glow, swipe, icon size, class colors) to make the adjacent icon blend into
-- the row without touching the validated Edit Mode centered anchor.
function ns.InitializeCompanionAuraButton(button, assignedClass)
    -- Separate caster-side auras use exactly the native recipient visual
    -- styling, with their own caster class rather than always EVOKER.
    InitializeButton(button, assignedClass or "EVOKER")
end

-- The Edit Mode icon position is already correctly implemented by the native
-- HORIZONTAL/VERTICAL modes. CENTERED reuses THAT EXACT Blizzard anchor.
-- Previous manually captured positions/offsets are intentionally ignored:
-- the stock container center is NOT the Edit Mode's first preview icon.
function ns.CaptureNativeEditModeAnchor()
    return false, "No capture needed: Centered uses the same native Blizzard anchor as Horizontal."
end

local function Layout()
    if not managed or not stock or InCombat() then return end
    local layoutMode = "FOLLOW"
    local centered = layoutMode == "CENTERED"
    local horizontal = centered or layoutMode == "HORIZONTAL" or
        (layoutMode == "FOLLOW" and stock.isHorizontal ~= false)
    local growRight = stock.addIconsToRight ~= false
    local growUp = stock.addIconsToTop == true
    local scale = stock.iconScale
    if type(scale) ~= "number" or IsSecret(scale) then scale = 1 end
    -- Native center alignment must use a HORIZONTAL flow axis, rather than
    -- the old HORIZONTAL-mode inversion used for left/right growth.  The
    -- anchor point denotes center of layout, NOT a fixed first button.
    -- All layout writes happen only out of combat.
    local anchor = centered and "CENTER" or
        (growRight and (growUp and "BOTTOMLEFT" or "TOPLEFT")
        or (growUp and "BOTTOMRIGHT" or "TOPRIGHT"))
    local size = 30 * scale
    lastPreviewWidth, lastPreviewHeight = size, size
    nativeTestAnchor = anchor
    nativeTestHorizontal, nativeTestRight, nativeTestUp = horizontal, centered or growRight, growUp
    if managed and type(managed.GetEffectiveScale) == "function" then
        local ok, measured = pcall(managed.GetEffectiveScale, managed)
        if ok then lastNativeEffectiveScale = PublicNumber(measured, 1) end
    end
    -- v1.5.14 reserved 60px of horizontal room for a 30px icon in the
    -- vertical option. That produced the large gaps visible to players.
    -- Give each icon exactly one square cell, plus the explicit spacing.
    local width, height = size, size
    local spacing = stock.iconSpacing or 2
    if type(spacing) ~= "number" or IsSecret(spacing) then spacing = 2 end
    spacing = math.max(0, math.min(20, spacing)) * scale
    managed:ClearAllPoints()
    if centered then
        -- Horizontal and Vertical use the native Edit Mode starting CORNER.
        -- With one aura, Blizzard's first icon occupies one (size x size)
        -- cell starting at that corner. Its CENTER, not stock:GetCenter(),
        -- is the fixed pivot we want to center a row of N actual auras on.
        local nativeCorner = growRight and (growUp and "BOTTOMLEFT" or "TOPLEFT")
            or (growUp and "BOTTOMRIGHT" or "TOPRIGHT")
        local dx = (growRight and 1 or -1) * size / 2
        local dy = (growUp and 1 or -1) * size / 2
        -- Native AuraContainer lays out the actual buffs in combat. This
        -- placement happens ONLY outside combat and never inspects the aura.
        managed:SetPoint("CENTER", stock, nativeCorner, dx, dy)

        -- The synthetic /ie test must have the same point WITHOUT being
        -- attached to an aura frame (which can become protected/secret).
        -- Copy only public out-of-combat geometry to a UIParent marker.
        testPivot:ClearAllPoints()
        local ok, left, right, top, bottom = pcall(function()
            return stock:GetLeft(), stock:GetRight(), stock:GetTop(), stock:GetBottom()
        end)
        local okScale, nativeScale = pcall(stock.GetEffectiveScale, stock)
        local okUI, uiScale = pcall(UIParent.GetEffectiveScale, UIParent)
        local function Valid(n)
            return type(n) == "number" and not IsSecret(n) and n == n and
                n ~= math.huge and n ~= -math.huge
        end
        if ok and okScale and okUI and Valid(left) and Valid(right) and
            Valid(top) and Valid(bottom) and Valid(nativeScale) and
            Valid(uiScale) and nativeScale > 0 and uiScale > 0 then
            local cornerX = growRight and left or right
            local cornerY = growUp and bottom or top
            local ratio = nativeScale / uiScale
            testPivot:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
                (cornerX + dx) * ratio, (cornerY + dy) * ratio)
        else
            -- Safe visual fallback. If geometry is protected, the reference
            -- is still the correct Blizzard CORNER, never the frame center.
            testPivot:SetPoint("CENTER", stock, nativeCorner, dx, dy)
        end
    else
        managed:SetPoint(anchor, stock, anchor, 0, 0)
    end
    managed:SetFlowLayoutAxis(centered and AnchorUtil.FlowLayoutAxis.Horizontal or
        (horizontal and AnchorUtil.FlowLayoutAxis.Vertical or AnchorUtil.FlowLayoutAxis.Horizontal))
    -- In centered mode the managed AuraContainer itself is anchored at the
    -- desired Edit Mode icon CENTER (see SetPoint above). Since Blizzard 12.1
    -- automatically resizes an AuraContainer to the bounds of its active
    -- AuraGroups, the group's LEFT edge must follow the container's LEFT edge.
    -- Center-anchoring the FIRST aura (as in 1.5.47) grows to the right and
    -- never centers the combined width. The LEFT anchor allows the native
    -- container's dynamic width to shift the entire row symmetrically.
    -- This uses only native layout; NO addon combat positioning/aura counts.
    managed:SetFlowLayoutAnchorPoint(centered and "LEFT" or anchor)
    managed:SetFlowLayoutGrowthDirection((centered or growRight) and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left,
        (not centered and growUp) and AnchorUtil.FlowDirection.Up or AnchorUtil.FlowDirection.Down)
    local stride = stock.iconStride
    if centered then
        -- This API accepts a PIXEL length, not an icon count!  256px only
        -- fits ~8 icons and wrapped class groups into vertical rows in 1.5.41.
        -- 4096px fits even 30+ buff icons on one row. No manual combat layout.
        stride = 4096
    elseif layoutMode ~= "FOLLOW" or type(stride) ~= "number"
        or IsSecret(stride) or stride < 1 then stride = 8 end
    managed:SetFlowLayoutMaximumLineSize(stride)
    local groupLayout = {
        elementSpacing=spacing, lineSpacing=spacing,
        elementWidth=width, elementHeight=height,
    }
    if UsesClassGroups() then
        for _, groupKey in ipairs(nativeGroupKeys) do
            managed:SetAuraGroupLayout(groupKey, groupLayout)
        end
    elseif classGroupsAdded > 0 then
        managed:SetAuraGroupLayout(GROUP, groupLayout)
    end
    for _, key in ipairs(additionalGroupKeys) do
        managed:SetAuraGroupLayout(key, groupLayout)
    end
    for _,slot in ipairs(slots) do
        local b = slot.frame
        b:SetSize(width, height)
        slot.icon:ClearAllPoints()
        slot.icon:SetSize(size, size)
        slot.icon:SetPoint("CENTER", b, "CENTER")
        StyleManaged(slot)
    end
    -- Keep companion icon geometry synchronized with the player native row.
    -- Both calls run only out of combat; secure aura layout stays Blizzard-owned.
    if ns.SyncEmeraldCommunionLayout then
        local ok, err = pcall(ns.SyncEmeraldCommunionLayout, size, spacing)
        if not ok then Log("Party caster layout sync failed: " .. tostring(err)) end
    end
    SetLegacyVisibility()
end

-- Sound selection is deliberately stricter than tracking group generation.
-- Sound API registrations are independent from visible Blizzard AuraContainers:
-- a spell can trigger a sound even if no button is displayed unless we restrict
-- its spell ID here. The SPELLS checkbox is always authoritative for audio.
-- Only inspect the player's saved config OUTSIDE combat. Never read aura data.
-- IDs on the recipient, not the spell used to create a ground zone.
-- Display groups still retain their existing IDs; this table affects only audio.
local ZONE_RECIPIENT_SOUND_IDS = {
    [145629] = 145629, -- Anti-Magic Zone (51052 casts the zone)
    [209426] = 209426, -- Darkness (196718 casts the zone)
    [325174] = 325174, -- Spirit Link (98008 casts the totem)
}

function ns.GetTrackedAuraSoundIDs()
    local db = Database()
    if not db or not Enabled() then return {} end

    local opted = CSVSet(db.selectedExtraSpellIDs, 100)
    local disabled = HiddenNativeIDs(db)
    local custom = CSVSet(db.extraSpellIDs, 50)
    local result, catalogIDs = {}, {}

    for _, entry in ipairs(ns.SpellCatalog or {}) do
        -- Track cast IDs AND their variations as catalogued, so an explicit
        -- unchecked family cannot be re-enabled by an old custom ID.
        catalogIDs[entry.id] = true
        for _, id in ipairs(entry.auraIDs or {entry.id}) do
            catalogIDs[id] = true
        end
    end

    for _, entry in ipairs(ns.SpellCatalog or {}) do
        -- CAST entries (Communion / Tranquility) are on a party member, NOT
        -- on the recipient. This is the recipient-only audio engine.
        if entry.kind ~= "CAST" then
            local selected = false
            if entry.kind == "NATIVE" then
                -- Mirrors the NATIVE checkbox (with legacy selected variants).
                selected = not disabled[entry.id]
                if not selected then
                    for _, id in ipairs(entry.auraIDs or {}) do
                        if opted[id] and not disabled[id] then selected = true end
                    end
                end
            elseif entry.kind == "SPECIAL" then
                if entry.id == 363916 then
                    selected = db.extraObsidianScales == true
                elseif entry.id == 147833 then
                    selected = db.extraIntervene == true
                end
            elseif entry.kind == "OPTIONAL" then
                selected = opted[entry.id] == true
            end

            if selected then
                for _, id in ipairs(entry.auraIDs or {entry.id}) do
                    -- Respect individual hidden variants of native families.
                    -- A legacy variant opt-in may leave the NATIVE base off:
                    -- register only the variant the user actually enabled.
                    local nativeSelected = entry.kind ~= "NATIVE"
                        or not disabled[entry.id] or opted[id]
                    if nativeSelected and not disabled[id] then
                        -- Ground-zone cast IDs are intentionally excluded
                        -- from recipient audio; use actual player buff IDs.
                        local recipientID = ZONE_RECIPIENT_SOUND_IDS[entry.id]
                        if not recipientID or id == recipientID then
                            result[id] = true
                        end
                    end
                end
            end
        end
    end

    -- Unknown custom Spell IDs remain explicit opt-ins. Known catalogued
    -- IDs must respect their own checkbox, even if in an old custom list.
    for id in pairs(custom) do
        if not catalogIDs[id] and not disabled[id] then
            result[id] = true
        end
    end
    return result
end

local function CreateManaged()
    if initialized or not Enabled() then return true end
    if InCombat() then return false end
    if not (ExternalDefensivesFrame and ExternalDefensivesFrame.AuraContainer
        and type(AnchorUtil)=="table") then return false end
    if not (AuraContainerInbound and type(AuraContainerInbound)=="table") then
        problem = "Blizzard AuraContainerInbound unavailable"
        Log("Native sweep cannot start: " .. problem)
        return false
    end
    parent = ExternalDefensivesFrame
    stock = parent.AuraContainer
    local ok, err = pcall(function()
        -- Geometry-only marker: it has no textures and never reads aura data.
        testPivot = CreateFrame("Frame", nil, UIParent)
        testPivot:SetSize(1, 1)
        testPivot:EnableMouse(false)
        managed = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
        managed:SetSize(1,1)
        local right = AnchorUtil.FlowDirection.Right
        managed:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
        managed:SetFlowLayoutAnchorPoint("TOPLEFT")
        managed:SetFlowLayoutGrowthDirection(right, AnchorUtil.FlowDirection.Down)
        managed:SetFlowLayoutMaximumLineSize(8)
        managed:SetUnit("player")
        classGroupsAdded = 0
        additionalGroupKeys = {}
        nativeGroupKeys = {}
        local extraGroups = AdditionalGroups(Database())
        -- Each selected extra ID is owned by the additional HELPFUL group.
        -- Exclude those IDs from the standard EXTERNAL_DEFENSIVE groups to
        -- prevent duplicate icons if Blizzard also classifies the buff there.
        local disabledNative = HiddenNativeIDs(Database())
        darknessGroupCreated = false
        for _, extra in ipairs(extraGroups) do
            for _, id in ipairs(extra.ids) do
                disabledNative[id] = true
                if id == 209426 or id == 196718 then
                    darknessGroupCreated = true
                end
            end
        end
        local nativeAllowed = NativeAllowedIDs(disabledNative)
        if UsesClassGroups() then
            -- Class groups use a strict whitelist, not "all external auras".
            -- Everything not declared NATIVE in SpellCatalog is excluded.
            local assigned = {}
            for _, group in ipairs(CLASS_GROUPS) do
                local visible = {}
                for _, id in ipairs(group.ids) do
                    if assigned[id] then error("Duplicate class-filter spell ID: " .. id) end
                    assigned[id] = true
                    if nativeAllowed[id] then visible[#visible+1] = id end
                end
                if #visible > 0 then
                    local assignedClass = group.class
                    local groupKey = GROUP .. "_" .. assignedClass
                    managed:AddAuraGroup(groupKey, "HELPFUL|EXTERNAL_DEFENSIVE", {
                        maxFrameCount=MAX_ICONS,
                        candidateFilters={includeSpellIDs=SpellIDSet(visible)},
                        initializeFrame=function(button) InitializeButton(button, assignedClass) end,
                        layout={elementWidth=30, elementHeight=30, elementSpacing=2, lineSpacing=2},
                    })
                    nativeGroupKeys[#nativeGroupKeys+1] = groupKey
                    classGroupsAdded = classGroupsAdded + 1
                end
            end
            -- No unrestricted fallback. Future native entries that are not
            -- in CLASS_GROUPS still display, with neutral fallback coloring.
            local remaining = {}
            for id in pairs(nativeAllowed) do
                if not assigned[id] then remaining[#remaining+1] = id end
            end
            if #remaining > 0 then
                managed:AddAuraGroup(GROUP .. "_OTHER", "HELPFUL|EXTERNAL_DEFENSIVE", {
                    maxFrameCount=MAX_ICONS,
                    candidateFilters={includeSpellIDs=SpellIDSet(remaining)},
                    initializeFrame=InitializeButton,
                    layout={elementWidth=30, elementHeight=30, elementSpacing=2, lineSpacing=2},
                })
                nativeGroupKeys[#nativeGroupKeys+1] = GROUP .. "_OTHER"
                classGroupsAdded = classGroupsAdded + 1
            end
        else
            -- An empty includeSpellIDs set must never be passed as a filter:
            -- depending on the client, that could behave like "include all".
            -- With all native entries disabled, create no native group.
            if next(nativeAllowed) ~= nil then
                managed:AddAuraGroup(GROUP, "HELPFUL|EXTERNAL_DEFENSIVE", {
                    maxFrameCount=MAX_ICONS,
                    candidateFilters={includeSpellIDs=nativeAllowed},
                    initializeFrame=InitializeButton,
                    layout={elementWidth=30, elementHeight=40, elementSpacing=5, lineSpacing=5},
                })
                classGroupsAdded = 1
            end
        end
        -- Do not change Blizzard's default tracker or its CVar. Each
        -- chosen OPTIONAL / SPECIAL / manual spell uses the SAME native
        -- HELPFUL + includeSpellIDs filtering that worked for Darkness.
        -- Exclude chosen IDs from the companion native groups to avoid
        -- rendering the same aura twice if Blizzard also labels it external.
        for _, extra in ipairs(extraGroups) do
            local groupKey = GROUP .. "_EXTRA_" .. extra.key
            local assignedClass = extra.class
            managed:AddAuraGroup(groupKey, EXTRA_FILTER, {
                maxFrameCount=MAX_ICONS,
                candidateFilters={includeSpellIDs=SpellIDSet(extra.ids)},
                initializeFrame=function(button) InitializeButton(button, assignedClass) end,
                layout={elementWidth=30, elementHeight=30, elementSpacing=2, lineSpacing=2},
            })
            additionalGroupKeys[#additionalGroupKeys + 1] = groupKey
        end
        managed:SetEnabled(true)
    end)
    if not ok then
        problem = tostring(err)
        if managed then managed:Hide() end
        managed = nil
        Log("Native sweep setup refused: " .. problem)
        return false
    end
    initialized = true
    -- The separate native party-caster tracker is strictly auxiliary; it
    -- cannot alter the centered recipient container or its layout in combat.
    if ns.AttachEmeraldCommunionTracker then
        local good, message = pcall(ns.AttachEmeraldCommunionTracker, managed)
        if not good then Log("Party caster indicators could not initialize: " .. tostring(message)) end
    end
    BuildTextureClassMap()
    local laidOut, layoutError = pcall(Layout)
    if not laidOut then
        problem = "Initial layout failed: " .. tostring(layoutError)
        Log(problem)
        if managed then managed:Hide() end
        if stock then stock:SetAlpha(1) end
        return false
    end
    -- Update on Edit Mode/size changes, never alter the protected layout
    -- while in combat. Native aura timing remains managed by the client.
    if not anchorHooked and type(hooksecurefunc)=="function" then
        anchorHooked = true
        if type(parent.UpdateGridLayout)=="function" then
            hooksecurefunc(parent,"UpdateGridLayout",function() if not InCombat() then pcall(Layout) end end)
        end
        if type(parent.SetIsEditing)=="function" then
            hooksecurefunc(parent,"SetIsEditing",function()
                if not InCombat() then
                    -- Re-sample the preview while Edit Mode is open and
                    -- reapply its saved position when the user closes it.
                    pcall(Layout)
                end
            end)
        end
    end
    return true
end
-- Legacy diagnostics from v1.5.44-46 are intentionally inactive.
-- They attempted to calibrate the centered row relative to a synthetic
-- marker instead of the already-correct native Blizzard Edit Mode anchor.
function ns.NativeLiveAlignmentProbe()
    return false, "Manual calibration disabled. Centered uses native AuraContainer bounds and Edit Mode origin."
end
function ns.ResetNativeLiveAlignment()
    local db = Database()
    if not db then return false, "Settings unavailable." end
    db.centerOffsetX, db.centerOffsetY = 0, 0
    db.liveCenterOffsetX, db.liveCenterOffsetY = 0, 0
    db.editAnchorFractionX, db.editAnchorFractionY = nil, nil
    return true, "Legacy calibration values cleared; native anchoring is unchanged."
end

-- Safe diagnostics: no protected aura values are queried.
function ns.DarknessTrackingStatus()
    local db = Database() or {}
    local ids = CSVSet(db.selectedExtraSpellIDs, 100)
    local custom = CSVSet(db.extraSpellIDs, 50)
    local configured = ids[209426] or custom[209426] or custom[196718]
    return "Darkness selected=" .. tostring(not not configured) ..
        " | paired IDs=196718,209426" ..
        " | HELPFUL + spell ID filter" ..
        " | native mode=" .. tostring(not not Enabled()) ..
        " | group registered=" .. tostring(darknessGroupCreated and initialized) ..
        " | /reload after changing Spells" ..
        " | error=" .. tostring(problem or "none")
end

function ns.ExtraSpellTrackingStatus()
    local db = Database() or {}
    local groups = AdditionalGroups(db)
    local count = 0
    for _, group in ipairs(groups) do count = count + #group.ids end
    return "additional spell groups=" .. tostring(#groups) ..
        " | candidate buff IDs=" .. tostring(count) ..
        " | filter=HELPFUL + includeSpellIDs" ..
        " | renderer ready=" .. tostring(initialized) ..
        " | active groups=" .. tostring(#additionalGroupKeys) ..
        " | /reload required after changing Spells" ..
        " | error=" .. tostring(problem or "none")
end

function ns.NativeClassFilterStatus()
    local db = Database() or {}
    local spells = 0
    for _, group in ipairs(CLASS_GROUPS) do spells = spells + #group.ids end
    return "Class-colored glow=" .. tostring(db.nativeClassFilter) ..
        " | native mode=" .. tostring(Enabled()) ..
        " | groups registered=" .. tostring(classGroupsAdded) ..
        " | recognized spell IDs=" .. tostring(spells) ..
        " | extra groups=" .. tostring(#additionalGroupKeys) ..
        " | native container=" .. tostring(initialized) ..
        " | last error=" .. tostring(problem or "none") ..
        ". A registered group does not prove that combat filtering worked."
end
function ns.NativeSweepStatus()
    return "Native sweep mode="..tostring(Enabled())..
        " | layout="..tostring(Database() and Database().nativeLayout)..
        " | spacing="..tostring(Database() and Database().nativeIconSpacing).."px"..
        " | centered-origin=native Blizzard Edit Mode first-icon center"..
        " | class groups="..tostring(classGroupsAdded).." | container="..tostring(initialized).." | slots="..tostring(#slots)..
        " | attempts="..tostring(attempts).." | last error="..tostring(problem or "none")
end
function ns.RefreshNativeSweep()
    if Enabled() and initialized and not InCombat() then pcall(Layout) end
end

-- Edit Mode may change AuraContainer.iconScale without invoking the layout
-- hooks above AFTER the new value is committed. The next /reload used to be
-- the only way to re-read it, leaving the duration font at the old size.
-- Watch only public Edit Mode geometry, never live aura data. A small polling
-- interval lets the user's slider resize the timer immediately, without
-- trying to manipulate protected aura frames in combat.
local editModeScaleWatcher = CreateFrame("Frame")
local editModeScaleElapsed = 0
editModeScaleWatcher:SetScript("OnUpdate", function(_, elapsed)
    if not initialized or not Enabled() or InCombat() then
        editModeScaleElapsed = 0
        return
    end
    editModeScaleElapsed = editModeScaleElapsed + elapsed
    if editModeScaleElapsed < 0.15 then return end
    editModeScaleElapsed = 0
    if not stock then return end
    local currentScale = stock.iconScale
    if type(currentScale) ~= "number" or IsSecret(currentScale)
        or currentScale <= 0 then return end
    local width = 30 * currentScale
    if math.abs(width - lastPreviewWidth) < 0.01 then return end
    local ok, err = pcall(Layout)
    if not ok then
        Log("Edit Mode font-size refresh failed: " .. tostring(err))
        return
    end
    -- Refresh the 3-icon sample and the options preview using the newly
    -- cached native icon size; this does not change the centering anchor.
    if type(ns.UpdatePreview) == "function" then
        pcall(ns.UpdatePreview)
    end
    -- The settings preview may not exist yet. A live /ie test must still
    -- follow Edit Mode scaling even with the addon options closed.
    if type(ns.RefreshWorldTest) == "function" then
        pcall(ns.RefreshWorldTest)
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent",function(_,event)
    if Enabled() and not initialized and not InCombat() then
        pcall(CreateManaged)
    elseif Enabled() and initialized and event == "PLAYER_REGEN_ENABLED" then
        pcall(Layout)
    end
end)
