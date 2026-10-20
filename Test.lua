-- ImprovedExternalDefs 1.5.26 - secret-safe synthetic test anchoring.
-- No fake auras, secret values, or Blizzard protected-frame changes.
local _, ns = ...
local examples = {
    { class = "PALADIN", label = "PAL", duration = 9, texture = "Interface\\Icons\\Spell_Holy_SealOfProtection" },
    { class = "PRIEST", label = "PRI", duration = 18, spellID = 33206, texture = "Interface\\Icons\\Spell_Holy_PainSupression" },
    { class = "DRUID", label = "DRU", duration = 30, spellID = 102342, texture = "Interface\\Icons\\Spell_Druid_Ironbark" },
}
local icons, testStart, running = {}, nil, false
local runner
-- Keep only public UI coordinates (not live Blizzard frame references). The
-- Blizzard Edit Mode tracker can become tainted/secret after the first test.
local lastScreenPosition

local function IsPublicNumber(n)
    -- Always check secret-ness BEFORE a numeric comparison, even outside
    -- combat. type(secret number) may still report "number" on Midnight.
    if type(issecretvalue) == "function" and issecretvalue(n) then return false end
    return type(n) == "number" and n == n
        and n ~= math.huge and n ~= -math.huge
end

local function SafePosition(frame)
    if not frame or not frame.GetCenter then return false end
    local ok, x, y = pcall(frame.GetCenter, frame)
    return ok and IsPublicNumber(x) and IsPublicNumber(y) and x > 0 and y > 0
end

local function PublicFlag(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then return nil end
    return value == true
end

local function FindNativeSlot()
    local tracker = _G.ExternalDefensivesFrame
    if not tracker then return nil end
    local buttons = tracker.auraFrames
    if type(buttons) == "table" then
        for _, b in ipairs(buttons) do
            if b and PublicFlag(b.isAuraAnchor) ~= true and PublicFlag(b.hasValidInfo)
                and b.Icon and SafePosition(b.Icon) then return b.Icon end
        end
        for _, b in ipairs(buttons) do
            if b and PublicFlag(b.isAuraAnchor) and b.Icon and SafePosition(b.Icon) then return b.Icon end
        end
        for _, b in ipairs(buttons) do
            if b and b.Icon and SafePosition(b.Icon) then return b.Icon end
        end
    end
    if SafePosition(tracker.AuraContainer) then return tracker.AuraContainer end
    if SafePosition(tracker) then return tracker end
    return nil
end

local function MakeEdge(parent)
    local e = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    e:SetColorTexture(1, 1, 1, 1)
    e:SetBlendMode("ADD")
    return e
end


local function NewIcon(i)
    local example = examples[i]
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(32, 32)
    f:SetFrameStrata("TOOLTIP")
    f:EnableMouse(false)
    f:Hide()
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(f)
    local texture = example.texture
    if type(ns.GetDemoSpellTexture) == "function" then
        local ok, resolved = pcall(ns.GetDemoSpellTexture, example.spellID, example.texture)
        if ok and resolved then texture = resolved end
    end
    icon:SetTexture(texture)
    f.icon = icon

    local ok, swipe = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
    if ok and swipe then
        f.sweep = swipe
        swipe:SetAllPoints(f)
        swipe:SetFrameLevel(f:GetFrameLevel() + 1)
        swipe:EnableMouse(false)
        if swipe.SetDrawSwipe then pcall(swipe.SetDrawSwipe, swipe, true) end
        if swipe.SetDrawEdge then pcall(swipe.SetDrawEdge, swipe, false) end
        if swipe.SetDrawBling then pcall(swipe.SetDrawBling, swipe, false) end
        if swipe.SetHideCountdownNumbers then pcall(swipe.SetHideCountdownNumbers, swipe, true) end
    end

    local fallbackFrame = CreateFrame("Frame", nil, f)
    fallbackFrame:SetAllPoints(f)
    fallbackFrame:SetFrameLevel(f:GetFrameLevel() + 2)
    fallbackFrame:EnableMouse(false)
    local fallback = fallbackFrame:CreateTexture(nil, "ARTWORK")
    fallback:SetColorTexture(0, 0, 0, 1)
    fallback:Hide()
    f.fallback = fallback

    local front = CreateFrame("Frame", nil, f)
    front:SetAllPoints(f)
    front:SetFrameLevel(f:GetFrameLevel() + 4)
    front:EnableMouse(false)
    f.glowSweep = ns.CreateGlowSweep(f, icon, f:GetFrameLevel() + 3)
    local halo = front:CreateTexture(nil, "ARTWORK", nil, 7)
    halo:SetTexture("Interface\\AddOns\\ImprovedExternalDefs\\Media\\NeonOutline.tga")
    halo:SetBlendMode("ADD")
    halo:SetPoint("TOPLEFT", icon, "TOPLEFT", -9, 9)
    halo:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 9, -9)
    f.halo = halo
    f.edges = {MakeEdge(front), MakeEdge(front), MakeEdge(front), MakeEdge(front)}
    f.staticGlow = front:CreateTexture(nil, "ARTWORK", nil, 6)
    f.staticGlow:SetBlendMode("BLEND")
    f.staticGlow:Hide()
    local timer = front:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    timer:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    timer:SetJustifyH("CENTER")
    timer:SetTextColor(1, 1, 1)
    timer:SetText(tostring(example.duration))
    f.timer = timer
    local tag = front:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tag:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    tag:SetTextColor(1, 0.82, 0.3)
    tag:SetText(example.label)
    tag:SetPoint("BOTTOM", icon, "TOP", 0, 13)
    f.tag = tag
    f.example = example
    return f
end

local function Stop()
    running, testStart = false, nil
    for _, f in ipairs(icons) do f:Hide() end
    if runner then runner:Hide() end
    if ns.UpdateTestButton then ns.UpdateTestButton() end
end

-- Shared tracker scale for both the 3-icon test and the Settings live preview.
function ns.GetTrackerFontScale()
    local slot = FindNativeSlot()
    if not slot then return 1 end
    local okUI, uiScale = pcall(UIParent.GetEffectiveScale, UIParent)
    local okNative, nativeScale = pcall(slot.GetEffectiveScale, slot)
    if okUI and okNative and IsPublicNumber(uiScale) and uiScale > 0
        and IsPublicNumber(nativeScale) and nativeScale > 0 then
        return nativeScale / uiScale
    end
    return 1
end

-- Translate native tracker units into arbitrary UI parents (including the
-- Settings panel). This keeps border thickness, halo extent, icon size and
-- text identical onscreen, rather than showing a 52px mock icon.
function ns.GetTrackerPreviewMetrics(destination)
    local slot = FindNativeSlot()
    local function ScaleOf(region)
        if not region or not region.GetEffectiveScale then return nil end
        local ok, scale = pcall(region.GetEffectiveScale, region)
        if ok and IsPublicNumber(scale) and scale > 0 then return scale end
    end
    local destScale = ScaleOf(destination) or ScaleOf(UIParent) or 1
    local targetScale = ScaleOf(slot) or ScaleOf(UIParent) or 1
    local factor = targetScale / destScale
    local w, h
    if slot and slot.GetSize then
        local ok, width, height = pcall(slot.GetSize, slot)
        if ok then w, h = width, height end
    end
    if not IsPublicNumber(w) or w < 8 or w > 256 then w = 32 end
    if not IsPublicNumber(h) or h < 8 or h > 256 then h = 32 end
    return w * factor, h * factor, factor
end

-- The native aura container is managed by Blizzard and can inherit forbidden
-- layout aspects even OUT of combat. Anchoring our own frames to it creates
-- UntrustedLayoutScriptExecution taint.  Read public screen coordinates once,
-- then anchor ONLY to UIParent (never to the protected reference object).
local function SnapshotPosition(reference, pivot)
    if not reference or not reference.GetCenter then return nil end
    local ok, x, y = pcall(reference.GetCenter, reference)
    if not ok or not IsPublicNumber(x) or not IsPublicNumber(y) then
        return nil
    end
    local sourceScale = 1
    local uiScale = 1
    if reference.GetEffectiveScale then
        local good, n = pcall(reference.GetEffectiveScale, reference)
        if good and IsPublicNumber(n) and n > 0 then sourceScale = n end
    end
    if UIParent and UIParent.GetEffectiveScale then
        local good, n = pcall(UIParent.GetEffectiveScale, UIParent)
        if good and IsPublicNumber(n) and n > 0 then uiScale = n end
    end
    local ratio = sourceScale / uiScale
    local cx, cy = x * ratio, y * ratio
    local width, height = 0, 0
    if reference.GetSize then
        local good, w, h = pcall(reference.GetSize, reference)
        if good and IsPublicNumber(w) and IsPublicNumber(h) then
            width, height = w * ratio, h * ratio
        end
    end
    pivot = pivot or "CENTER"
    if pivot:find("LEFT", 1, true) then cx = cx - width / 2
    elseif pivot:find("RIGHT", 1, true) then cx = cx + width / 2 end
    if pivot:find("TOP", 1, true) then cy = cy + height / 2
    elseif pivot:find("BOTTOM", 1, true) then cy = cy - height / 2 end
    return cx, cy
end

local function PositionIcons()
    local db = NoExternalPulseDB or {}
    local native = db.nativeSweepMode and not db.safeMode and ns.NativeTestLayout
    local ref, pivot, w, h, scale, gap, horizontal, positiveX, positiveY
    if native then
        ref, pivot, w, h, scale, gap, horizontal, positiveX, positiveY = ns.NativeTestLayout()
    end
    if not ref then
        -- Legacy Blizzard tracker fallback (native mode may not have started).
        local first = FindNativeSlot()
        if not first then
            if not lastScreenPosition then return false end
            -- No Blizzard slot is public any longer. We can still replay the
            -- last SAFE snapshot rather than touching a protected frame.
            ref, pivot = nil, lastScreenPosition.pivot
            w, h, scale, gap = 32, 32, 1, 2
            horizontal, positiveX, positiveY = true, true, false
        else
            ref, pivot = first, "CENTER"
        local dimensionsOK, sw, sh = pcall(first.GetSize, first)
        w, h = dimensionsOK and sw or 32, dimensionsOK and sh or 32
        if not IsPublicNumber(w) or w < 8 or w > 256 then w = 32 end
        if not IsPublicNumber(h) or h < 8 or h > 256 then h = 32 end
        scale = ns.GetTrackerFontScale()
        w, h = w * scale, h * scale
        local container = _G.ExternalDefensivesFrame and _G.ExternalDefensivesFrame.AuraContainer
        local function ContainerFlag(field, default)
            if not container then return default end
            local ok, value = pcall(function() return container[field] end)
            if not ok then return default end
            local public = PublicFlag(value)
            if public == nil then return default end
            return public
        end
        horizontal = ContainerFlag("isHorizontal", true)
        positiveX = ContainerFlag("addIconsToRight", true)
        positiveY = ContainerFlag("addIconsToTop", false)
        local nativePad = container and container.iconPadding or 5
        if not IsPublicNumber(nativePad) then nativePad = 5 end
        gap = nativePad * scale
        end
    end
    local x, y = SnapshotPosition(ref, pivot)
    if not x then
        -- Some layouts cannot expose their coordinates. Try the Blizzard
        -- tracker as another READ-ONLY source; do not anchor to it either.
        local backup = FindNativeSlot()
        if backup then
            local bx, by = SnapshotPosition(backup, "CENTER")
            if bx then x, y, pivot = bx, by, "CENTER" end
        end
    end
    if x then
        -- Refresh cache only with verified public values; this survives the
        -- next click when the Blizzard layout frame exposes secret values.
        lastScreenPosition = { x = x, y = y, pivot = pivot }
    elseif lastScreenPosition then
        x, y, pivot = lastScreenPosition.x, lastScreenPosition.y, lastScreenPosition.pivot
    else
        return false, "Cannot read public tracker coordinates yet. Leave combat and try /reload."
    end
    -- Never feed a secret dimension into SetSize/SetPoint, even if the UI
    -- location itself came from an earlier safe snapshot.
    if not IsPublicNumber(w) or w <= 0 then w = 32 end
    if not IsPublicNumber(h) or h <= 0 then h = 32 end
    if not IsPublicNumber(scale) or scale <= 0 then scale = 1 end
    if not IsPublicNumber(gap) then gap = 2 end
    local centered = db.nativeLayout == "CENTERED" and ref ~= nil and native
    if centered then
        local shown = 0
        for _, icon in ipairs(icons) do if icon:IsShown() then shown = shown + 1 end end
        x = x - math.max(0, shown - 1) * (w + gap) / 2
        pivot = "CENTER"
        horizontal, positiveX = true, true
    end
    local last
    for _, f in ipairs(icons) do
        f:SetSize(w, h)
        f.NEPTrackerScale = scale
        if f:IsShown() then
            f:ClearAllPoints()
            if not last then
                -- IMPORTANT: attach to UIParent only, not to the protected
                -- native container or one of its aura buttons.
                f:SetPoint(pivot, UIParent, "BOTTOMLEFT", x, y)
            elseif horizontal then
                f:SetPoint("CENTER", last, "CENTER", positiveX and (w + gap) or -(w + gap), 0)
            else
                f:SetPoint("CENTER", last, "CENTER", 0, positiveY and (h + gap) or -(h + gap))
            end
            last = f
        end
    end
    return true
end

local function UpdateTimer(f, remaining)
    local db = NoExternalPulseDB
    f.timer:SetText(ns.FormatSyntheticDuration and ns.FormatSyntheticDuration(remaining)
        or (tostring(math.ceil(remaining)) .. (db.removeSecondsSuffix and "" or "s")))
    if f.fallback:IsShown() then
        f.fallback:SetWidth(math.max(0.01, f:GetWidth() * remaining / f.example.duration))
    end
end

local function CreateRunner()
    if runner then return end
    runner = CreateFrame("Frame", nil, UIParent)
    runner:Hide()
    runner:RegisterEvent("PLAYER_REGEN_DISABLED")
    runner:SetScript("OnEvent", Stop)
    runner:SetScript("OnUpdate", function(self, elapsed)
        self.tick = (self.tick or 0) + elapsed
        if self.tick < 0.07 then return end
        self.tick = 0
        if not running or not testStart then return end
        local now = GetTime()
        local any, changed = false, false
        for _, f in ipairs(icons) do
            local remaining = math.max(0, testStart + f.example.duration - now)
            if remaining <= 0 then
                if f:IsShown() then f:Hide() changed = true end
            else
                any = true
                UpdateTimer(f, remaining)
            end
        end
        if changed then PositionIcons() end  -- remaining externals collapse together
        if not any then Stop() end
    end)
end

function ns.RefreshWorldTest()
    if not running then return end
    local db = NoExternalPulseDB
    if not db then return end
    PositionIcons()
    local native = db.nativeSweepMode and not db.safeMode
    for _, f in ipairs(icons) do
        local scale = f.NEPTrackerScale or 1
        local classColor = ns.CLASS_COLORS[f.example.class] or ns.FALLBACK_COLOR or {1, 1, 1}
        -- In native class-filter mode, Blizzard groups each known external
        -- with a predetermined class. Our synthetic sample spells belong to
        -- those same groups, so show the SAME fixed class border colors.
        -- Only non-classified native mode uses the neutral fallback color.
        if native and not db.nativeClassFilter and ns.NativeFallbackGlowColor then
            classColor = ns.NativeFallbackGlowColor()
        end
        classColor = ns.GetConfiguredGlowColor and ns.GetConfiguredGlowColor(classColor) or classColor
        f.icon:SetAlpha(db.iconOpacity or 1)
        ns.PaintGlow(f.icon, f.halo, f.edges, f.staticGlow, f.glowSweep,
            db, classColor, scale, f:IsShown())
        if f.tag then f.tag:SetShown(not native) end
        if native and ns.StyleNativeTimer then
            ns.StyleNativeTimer(f.timer, f.icon, scale)
        else
            f.timer:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", (db.textSize or 14) * scale, "OUTLINE")
            f.timer:ClearAllPoints()
            local x, y = (db.textX or 0) * scale, (db.textY or 0) * scale
            if db.textPosition == "TOP" then
                f.timer:SetPoint("BOTTOM", f.icon, "TOP", x, y + 3 * scale)
            elseif db.textPosition == "BOTTOM" or db.textPosition == "DEFAULT" then
                f.timer:SetPoint("TOP", f.icon, "BOTTOM", x, y - 3 * scale)
            else
                f.timer:SetPoint("CENTER", f.icon, "CENTER", x, y)
            end
        end
        if f.sweep then
            pcall(f.sweep.SetSwipeColor, f.sweep, 0, 0, 0, db.swipeOpacity)
            if f.sweep.SetReverse then pcall(f.sweep.SetReverse, f.sweep, db.swipeReverse) end
            f.sweep:SetShown(db.swipe and f.nativeRunning and f:IsShown())
        end
        f.fallback:SetShown(db.swipe and not f.nativeRunning and f:IsShown())
        if f.fallback:IsShown() then
            f.fallback:SetAlpha(db.swipeOpacity)
            f.fallback:ClearAllPoints()
            local side = db.swipeReverse and "RIGHT" or "LEFT"
            f.fallback:SetPoint("TOP" .. side, f.icon, "TOP" .. side)
            f.fallback:SetPoint("BOTTOM" .. side, f.icon, "BOTTOM" .. side)
            f.fallback:SetWidth(f:GetWidth())
        end
        UpdateTimer(f, math.max(0, testStart + f.example.duration - GetTime()))
    end
    PositionIcons()
end

function ns.IsWorldTestVisible()
    return running
end

function ns.ToggleWorldTest(arg)
    arg = arg or "toggle"
    if arg == "off" or (arg ~= "on" and running) then
        Stop()
        return false, "Test hidden."
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot start the test in combat."
    end
    local foundReference = false
    local anchorOk, anchorOrError = pcall(function()
        if ns.NativeTestLayout then return ns.NativeTestLayout() end
    end)
    if not anchorOk then
        ns.LastWorldTestError = tostring(anchorOrError)
        return false, "Test anchor error: " .. ns.LastWorldTestError
    end
    foundReference = anchorOrError ~= nil
    if not foundReference and not lastScreenPosition then
        local slotOk, slotOrError = pcall(FindNativeSlot)
        if not slotOk then
            ns.LastWorldTestError = tostring(slotOrError)
            return false, "Blizzard tracker lookup error: " .. ns.LastWorldTestError
        end
        if not slotOrError then
            return false, "Blizzard External Defensives tracker not found. Enable it in Edit Mode."
        end
    end
    -- Keep all WoW-dependent creation and styling in one protected transaction.
    -- A failure cannot leave the test half-running with orphaned icons on-screen.
    local ok, err = pcall(function()
        CreateRunner()
        for i = 1, #examples do
            if not icons[i] then icons[i] = NewIcon(i) end
        end
        testStart, running = GetTime(), true
        for _, f in ipairs(icons) do
            f.nativeRunning = false
            f.nativeGlowRunning = false
            if f.glowSweep then
                f.nativeGlowRunning = pcall(f.glowSweep.SetCooldown, f.glowSweep,
                    testStart, f.example.duration)
            end
            if f.sweep then
                f.nativeRunning = pcall(f.sweep.SetCooldown, f.sweep, testStart, f.example.duration)
            end
            f:Show()
        end
        runner:Show()
        local placed, reason = PositionIcons()
        if not placed then error(reason or "Could not position the test icons") end
        ns.RefreshWorldTest()
        -- RefreshWorldTest positions once more after configuring visuals.
    end)
    if not ok then
        ns.LastWorldTestError = tostring(err)
        Stop()
        return false, "Test error: " .. ns.LastWorldTestError
    end
    ns.LastWorldTestError = nil
    if ns.UpdateTestButton then ns.UpdateTestButton() end
    return true, "3 externals simulated: Paladin 9s, Priest 18s, Druid 30s."
end
