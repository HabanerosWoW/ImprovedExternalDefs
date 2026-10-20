-- ImprovedExternalDefs v1.5.67 (WoW Retail, Midnight 12.1.5)
-- Blizzard-native recipient aura tracking, visuals, and settings.
local ADDON_NAME, ns = ...
local ADDON_VERSION = "1.5.67"
local L = ns.L or function(value) return value end

local pendingSetup = false
local setupErrorReported = false
local DEFAULTS = {
    enabled = true,
    safeMode = false, -- Diagnostics: do not touch the native tracker after /reload.
    nativeSweepMode = true, -- Native Blizzard-driven timers/sweep for new installs.
    nativeLayout = "FOLLOW", -- Always follow Blizzard Edit Mode.
    nativeIconSpacing = 2, -- Pixels between icon slots, before Blizzard scale.
    -- Fine tuning is global like Blizzard Edit Mode position, not a profile field.
    -- These offsets never depend on secret combat aura data.
    centerOffsetX = 0,
    centerOffsetY = 0,
    -- Independent, opt-in real-aura alignment correction measured OUT of combat.
    -- The synthetic /ie test stays on the true Edit Mode preview pivot.
    liveCenterOffsetX = 0,
    liveCenterOffsetY = 0,
    nativeFallbackColor = "WHITE", -- Do not suggest an incorrect caster class when secret.
    nativeClassFilter = true, -- Native class groups, validated in skirmish; reload after toggle.
    extraObsidianScales = true, -- Opt-in/out: helpful aura 363916, including ally-shared Lifecinders.
    extraIntervene = true,      -- Opt-in/out: helpful Intervene auras 147833 and 3411.
    selectedExtraSpellIDs = "", -- Optional defensives enabled from the catalog.
    disabledNativeSpellIDs = "", -- Explicitly hidden Blizzard external spells.
    autoExternalDefensives = false, -- Retired EE12 profile field: always OFF.
    autoStealableDefensives = false, -- Retired EE12 profile field: always OFF.
    extraSpellIDs = "",        -- Sorted comma-separated IDs (up to 50), filtered by WoW's aura engine.
    glow = true,
    glowStyle = "BORDER",   -- BORDER, HALO, BOTH
    glowThickness = 2,
    glowOffset = 0,
    glowOpacity = 0.95,
    glowColorMode = "CLASS", -- CLASS or CUSTOM, independent of the combat class filter.
    glowCustomR = 0.62, glowCustomG = 0.34, glowCustomB = 1.00,
    durationDecimalsThreshold = 0, -- 0, 1..10, 15, 60 or 3600; tenths displayed BELOW threshold.
    glowSweep = false, -- Legacy profile field kept for EE5 code compatibility; no effect.
    iconOpacity = 1.00,  -- Opacity of the icon texture ONLY: glow and timer stay readable.
    soundEnabled = false, -- Opt in: alerts are silent by default.
    soundKey = "RAID_WARNING",
    soundPath = "", -- Optional file under Interface/ (not required for built-ins).
    soundChannel = "Master",
    soundVolume = 0.80,
    swipe = true,
    swipeOpacity = 0.55,
    swipeReverse = false,
    removeSecondsSuffix = true,
    textPosition = "CENTER", -- DEFAULT, CENTER, TOP, BOTTOM
    textX = 0,
    textY = 0,
    textSize = 14,
    textAutoScale = true, -- Scale timer font with actual icon size from Blizzard Edit Mode; manual textSize is the 30px baseline.
}
ns.DEFAULTS = DEFAULTS

local FALLBACK_COLOR = { 1.00, 0.82, 0.35 }
local CLASS_COLORS = {
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    DEMONHUNTER = { 0.64, 0.19, 0.79 },
    DRUID = { 1.00, 0.49, 0.04 },
    EVOKER = { 0.20, 0.58, 0.50 },
    HUNTER = { 0.67, 0.83, 0.45 },
    MAGE = { 0.25, 0.78, 0.92 },
    MONK = { 0.00, 1.00, 0.60 },
    PALADIN = { 0.96, 0.55, 0.73 },
    PRIEST = { 1.00, 1.00, 1.00 },
    ROGUE = { 1.00, 0.96, 0.41 },
    SHAMAN = { 0.00, 0.44, 0.87 },
    WARLOCK = { 0.53, 0.53, 0.93 },
    WARRIOR = { 0.78, 0.61, 0.43 },
}
ns.CLASS_COLORS = CLASS_COLORS
ns.FALLBACK_COLOR = FALLBACK_COLOR

-- Shared between native aura groups, legacy styling, preview and test.
-- No private aura or caster information is inspected to use a custom color.
function ns.GetConfiguredGlowColor(classColor)
    local db = NoExternalPulseDB
    if db and db.glowColorMode == "CUSTOM" then
        return {db.glowCustomR or 0.62, db.glowCustomG or 0.34, db.glowCustomB or 1}
    end
    return classColor or FALLBACK_COLOR
end

-- Static glow only. The old animated glow option was removed because its
-- radial clipping did not match the native border visual. The icon's dark
-- countdown sweep remains fully supported.
-- Each renderer below (live icons, Preview and /ie test) shares PaintGlow.
-- The outer neon texture is completely transparent INSIDE the icon.
-- Soft Glow must never draw an extra solid border or cover the spell artwork.
-- PaintGlow is shared by the native tracker, legacy tracker, /ie test and preview.
local HALO_PAD = 4
local function InsetOffset(db)
    -- Keep the user's spacing slider, but draw the border 2px closer. A
    -- value of 0 places its center slightly inside the icon's actual edge.
    return (db.glowOffset or 0) - 2
end

-- Older Preview and Test files still call these functions. Leave compatible
-- no-op hooks so they cannot create an animated glow or throw Lua errors.
function ns.CreateGlowSweep() return nil end
function ns.StyleGlowSweep() return false end
function ns.PositionGlowSweep() end

function ns.PaintGlow(icon, halo, edges, staticGlow, sweep, db, color, factor, visible)
    if not icon or not db then return end
    factor = factor or 1
    local pad = HALO_PAD * factor
    local t = (db.glowThickness or 2) * factor
    local o = InsetOffset(db) * factor
    local active = not not (visible and db.glow)

    if halo then
        halo:ClearAllPoints()
        halo:SetPoint("TOPLEFT", icon, "TOPLEFT", -pad, pad)
        halo:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", pad, -pad)
        halo:SetVertexColor(color[1], color[2], color[3], 1)
        -- Single additive neon texture, strictly OUTSIDE the artwork.
        halo:SetAlpha((db.glowOpacity or 1) * (db.glowStyle == "BOTH" and 0.72 or 1))
        halo:SetShown(active and (db.glowStyle == "HALO" or db.glowStyle == "BOTH"))
    end
    if staticGlow then staticGlow:Hide() end
    if edges then
        local function Set(edge, p1, r1, x1, y1, p2, r2, x2, y2)
            edge:ClearAllPoints()
            edge:SetPoint(p1, icon, r1, x1, y1)
            edge:SetPoint(p2, icon, r2, x2, y2)
            edge:SetVertexColor(color[1], color[2], color[3], 1)
            edge:SetAlpha(db.glowOpacity or 1)
        end
        Set(edges[1], "TOPLEFT", "TOPLEFT", -o, o, "BOTTOMRIGHT", "TOPRIGHT", o, o-t)
        Set(edges[2], "TOPLEFT", "BOTTOMLEFT", -o, -o+t, "BOTTOMRIGHT", "BOTTOMRIGHT", o, -o)
        Set(edges[3], "TOPLEFT", "TOPLEFT", -o, o-t, "BOTTOMRIGHT", "BOTTOMLEFT", -o+t, -o+t)
        Set(edges[4], "TOPLEFT", "TOPRIGHT", o-t, o-t, "BOTTOMRIGHT", "BOTTOMRIGHT", o, -o+t)
        -- Soft Glow is PURE neon, no hard border; only Border/Both draw lines.
        local show = active and (db.glowStyle == "BORDER" or db.glowStyle == "BOTH")
        for _, edge in ipairs(edges) do edge:SetShown(show) end
    end
end

local function IsSecret(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

-- Verified SoundKit constants from Blizzard's own SoundKitConstants.lua.
-- Fixed known IDs also work if a given client does not expose SOUNDKIT.
local SOUND_CHOICES = {
    {"RAID_WARNING",              "Raid warning",       8959},
    {"READY_CHECK",               "Ready check",        8960},
    {"MAP_PING",                  "Map ping",           3175},
    {"TELL_MESSAGE",              "Whisper",            3081},
    {"ALARM_CLOCK_WARNING_1",     "Alarm clock 1",      18871},
    {"ALARM_CLOCK_WARNING_2",     "Alarm clock 2",      12867},
    {"ALARM_CLOCK_WARNING_3",     "Alarm clock 3",      12889},
    {"UI_BATTLEGROUND_COUNTDOWN_FINISHED", "Battleground start", 25478},
    {"RAID_BOSS_EMOTE_WARNING",   "Boss warning",      12197},
    {"UI_BNET_TOAST",             "Notification",      18019},
    {"IG_MAINMENU_OPTION_CHECKBOX_ON", "Checkbox tick", 856},
    {"IG_MAINMENU_OPTION_CHECKBOX_OFF", "Checkbox untick", 857},
    {"IG_MAINMENU_OPEN",          "Menu open",          850},
    {"IG_MAINMENU_CLOSE",         "Menu close",         851},
    {"IG_CHARACTER_INFO_TAB",     "Character tab",      841},
}
ns.SOUND_CHOICES = SOUND_CHOICES
local soundIDs = {}
for _, sound in ipairs(SOUND_CHOICES) do soundIDs[sound[1]] = sound[3] end

-- LibSharedMedia is optional. We only read it if another addon provides it.
local function GetSharedMedia()
    if type(LibStub) ~= "function" and type(LibStub) ~= "table" then return nil end
    local ok, lib = pcall(LibStub, "LibSharedMedia-3.0", true)
    if ok and type(lib) == "table" and type(lib.List) == "function"
        and type(lib.Fetch) == "function" then return lib end
    return nil
end
ns.GetSharedMedia = GetSharedMedia

function ns.GetSoundChoices()
    local choices = {}
    for _, item in ipairs(SOUND_CHOICES) do
        choices[#choices + 1] = {item[1], L("Blizzard: ") .. L(item[2])}
    end
    table.insert(choices, 1, {"IE_ALERT", L("IE notification (native aura alert)")})
    choices[#choices + 1] = {"CUSTOM", L("Custom audio file")}
    local lib = GetSharedMedia()
    if lib then
        local ok, names = pcall(lib.List, lib, "sound")
        if ok and type(names) == "table" then
            for _, name in ipairs(names) do
                if type(name) == "string" and #name > 0 and #name <= 95 and name ~= "None" then
                    choices[#choices + 1] = {"LSM:" .. name, "SharedMedia: " .. name}
                end
            end
        end
    end
    -- A previously selected SharedMedia choice must remain visible if its
    -- sound pack is disabled; selecting another sound still works normally.
    local current = NoExternalPulseDB and NoExternalPulseDB.soundKey
    if type(current) == "string" and current:sub(1, 4) == "LSM:" then
        local found = false
        for _, pair in ipairs(choices) do
            if pair[1] == current then found = true break end
        end
        if not found then choices[#choices + 1] = {current, L("Unavailable: ") .. current:sub(5)} end
    end
    return choices
end

function ns.NormalizeSoundPath(path)
    if type(path) ~= "string" or #path > 190 then return nil end
    path = path:gsub("/", "\\"):match("^%s*(.-)%s*$")
    if #path == 0 then return "" end
    local lower = path:lower()
    if not lower:match("^interface\\") or path:find("%.%.")
        or path:find("[%c]") or not (lower:sub(-4) == ".ogg"
            or lower:sub(-4) == ".mp3" or lower:sub(-4) == ".wav") then
        return nil
    end
    return path
end

local function PlayFile(path, channel)
    if type(path) ~= "string" or path == "" then return false end
    if type(PlaySoundFile) ~= "function" then return false end
    local ok, success = pcall(PlaySoundFile, path, channel)
    return ok and success ~= false and success ~= nil
end

-- Blizzard SoundKit sounds support volumeOverride on Retail 12.1+.
-- PlaySoundFile (custom / SharedMedia) uses the selected channel's game volume.
function ns.PlayAlertSound()
    local db = NoExternalPulseDB
    if not db then return false end
    local key = db.soundKey
    local channel = (db.soundChannel == "SFX" and "SFX") or "Master"
    if key == "IE_ALERT" then
        return PlayFile("Interface\\AddOns\\ImprovedExternalDefs\\Media\\IEAlert.ogg", channel)
    elseif key == "CUSTOM" then
        local path = ns.NormalizeSoundPath(db.soundPath)
        return path and PlayFile(path, channel) or false
    elseif type(key) == "string" and key:sub(1, 4) == "LSM:" then
        local lib = GetSharedMedia()
        if not lib then return false end
        local ok, path = pcall(lib.Fetch, lib, "sound", key:sub(5), true)
        return ok and PlayFile(path, channel) or false
    end
    if type(key) ~= "string" or not soundIDs[key] then key = "RAID_WARNING" end
    local id = (type(SOUNDKIT) == "table" and SOUNDKIT[key]) or soundIDs[key]
    if C_Sound and type(C_Sound.PlaySound) == "function" then
        local ok, success = pcall(C_Sound.PlaySound, id, channel, false, false, nil, db.soundVolume or 0.8)
        if ok then return success ~= false and success ~= nil end
    end
    if type(PlaySound) == "function" then
        local ok, success = pcall(PlaySound, id, channel)
        return ok and success ~= false
    end
    return false
end

-- Recipient audio is registered by SoundAlerts.lua via Blizzard's native
-- aura-sound API. Icon update events do not infer buff additions/removals.

local function Print(msg)
    print("|cff79d8ffImprovedExternalDefs|r: " .. msg)
end


local function InitializeDB()
    if type(NoExternalPulseDB) ~= "table" then NoExternalPulseDB = {} end
    -- Upgrade v1.5.14: its labels were reversed. Preserve the visual
    -- orientation users had selected, while correcting the displayed label.
    local upgradeAxis = NoExternalPulseDB.nativeLayout ~= nil
        and NoExternalPulseDB.nativeAxisCorrected ~= true
    for key, default in pairs(DEFAULTS) do
        if NoExternalPulseDB[key] == nil then NoExternalPulseDB[key] = default end
    end
    NoExternalPulseDB.nativeLayout = "FOLLOW"
    NoExternalPulseDB.soundEnabled = false
    NoExternalPulseDB.glowSweep = false
    -- Retired experiment cannot be reactivated by pre-1.5.39 SavedVariables.
    NoExternalPulseDB.autoExternalDefensives = false
    NoExternalPulseDB.autoStealableDefensives = false
    if ns.InitProfiles then ns.InitProfiles() end
    NoExternalPulseDB.nativeLayout = "FOLLOW"
    -- Legacy axis migration is no longer relevant: Blizzard owns orientation.
    if false and upgradeAxis then
        local switched = { HORIZONTAL = "VERTICAL", VERTICAL = "HORIZONTAL" }
        NoExternalPulseDB.nativeLayout = switched[NoExternalPulseDB.nativeLayout]
            or NoExternalPulseDB.nativeLayout
        for _, profile in pairs(NoExternalPulseDB.profiles or {}) do
            if type(profile) == "table" then
                profile.nativeLayout = switched[profile.nativeLayout] or profile.nativeLayout
            end
        end
    end
    NoExternalPulseDB.nativeAxisCorrected = true
end
ns.InitializeDB = InitializeDB

-- Legacy-mode visual anti-pulse: the Blizzard AuraButton updates
-- its own alpha on each frame when its remaining duration is low. Changing
-- AuraContainer:GetAuraWarningAlphaForDuration (old approach) tainted the
-- native countdown in combat. Do not replace any Blizzard functions or call
-- SetAlpha on the native aura button. Instead, tell its VISUAL children to
-- ignore alpha inherited from the pulsing button. Blizzard still owns the
-- native button, its update script, its Duration FontString and aura timing.
-- Apply this only OUT of combat; changing the setting requires /reload during
-- combat, and the tracker continues to update itself without addon writes.
local antiPulseWarningShown = false
local function ApplyAntiPulseVisuals(button)
    if not button or not NoExternalPulseDB then return end
    if InCombatLockdown and InCombatLockdown() then
        pendingSetup = true
        return
    end
    local enabled = NoExternalPulseDB.enabled == true
    -- The first two are the critical regions for a native defensive. Count
    -- and other decorative regions should also stay fully opaque.
    local regions = {
        Icon = button.Icon, Duration = button.Duration, Count = button.Count,
        Symbol = button.Symbol, DebuffBorder = button.DebuffBorder,
        TempEnchantBorder = button.TempEnchantBorder,
        NEPSwipe = button.NEPSwipe, NEPFront = button.NEPFront,
        NEPGlow = button.NEPGlow, NEPStaticGlow = button.NEPStaticGlow,
    }
    -- The overlay itself and all its textures should ignore the native
    -- button alpha; do not override the native button's SetAlpha method.
    if button.NEPBorders then
        for i, edge in ipairs(button.NEPBorders) do
            regions["Border" .. i] = edge
        end
    end
    for _, region in pairs(regions) do
        if region and type(region.SetIgnoreParentAlpha) == "function" then
            local ok = pcall(region.SetIgnoreParentAlpha, region, enabled)
            if not ok and enabled and not antiPulseWarningShown then
                antiPulseWarningShown = true
                print("|cff79d8ffImprovedExternalDefs|r: A Blizzard region rejected visual anti-pulse; native countdown is left untouched.")
            end
        elseif region and enabled and not antiPulseWarningShown then
            antiPulseWarningShown = true
            print("|cff79d8ffImprovedExternalDefs|r: This client cannot decouple native icon alpha; safe fallback is Blizzard pulsing.")
        end
    end
end

-- In Midnight, caster/aura fields may be secret in combat. Never inspect them.
local function GetCasterClass(button)
    if not button or not button.buttonInfo or not C_UnitAuras
        or type(C_UnitAuras.GetAuraDataByAuraInstanceID) ~= "function" then return nil end
    local id = button.buttonInfo.auraInstanceID
    if IsSecret(id) or id == nil then return nil end
    local unit = (PlayerFrame and PlayerFrame.unit) or "player"
    if IsSecret(unit) then return nil end
    local ok, auraData = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, id)
    if not ok or IsSecret(auraData) or type(auraData) ~= "table" then return nil end
    local caster = auraData.sourceUnit
    if IsSecret(caster) or type(caster) ~= "string" then return nil end
    local classOk, _, class = pcall(UnitClass, caster)
    if not classOk or IsSecret(class) or type(class) ~= "string" then return nil end
    return class
end

-- LIVE COUNTDOWN (Midnight 12.1+):
-- Never replace Blizzard's duration text binding with a second FontString.
-- When auras become secret in combat, a copied string can retain its last
-- pre-combat value (e.g. 60). The original Blizzard Duration FontString is
-- driven by the game's own engine and continues to count down.
-- Do not call SetDurationText here: it can displace the secure native binding.
local function PositionText(button)
    local text = button and button.Duration
    if not text or not button.Icon then return end
    if InCombatLockdown and InCombatLockdown() then
        pendingSetup = true
        return
    end
    local db = NoExternalPulseDB
    if not db then return end
    local x, y = db.textX or 0, db.textY or 0
    text:ClearAllPoints()
    if db.textPosition == "TOP" then
        text:SetPoint("BOTTOM", button.Icon, "TOP", x, y + 3)
    elseif db.textPosition == "BOTTOM" or db.textPosition == "DEFAULT" then
        text:SetPoint("TOP", button.Icon, "BOTTOM", x, y - 3)
    else
        text:SetPoint("CENTER", button.Icon, "CENTER", x, y)
    end
    text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", db.textSize or 14, "OUTLINE")
    text:SetJustifyH("CENTER")
    -- Only restore visibility here while out of combat. Never call SetText().
    text:SetAlpha(1)
end

-- Native suffix option, best effort: only act on an EXISTING Blizzard
-- DurationTextBinding if it exposes a formatter hook. Never create another
-- timer, never inspect or rewrite a secret seconds string, and never modify
-- the native duration binding itself. If the field isn't exposed on this
-- client, Blizzard's default "s" is deliberately kept.
local numberFormatter
local function ApplyNativeSuffixFormat(button)
    if InCombatLockdown and InCombatLockdown() then return end
    if not NoExternalPulseDB or not NoExternalPulseDB.removeSecondsSuffix then return end
    local binding = button and (button.DurationTextBinding or button.durationTextBinding)
    if not binding or type(binding.SetFormatter) ~= "function" then return end
    if not numberFormatter and C_StringUtil
        and type(C_StringUtil.CreateNumericRuleFormatter) == "function" then
        local ok, formatter = pcall(C_StringUtil.CreateNumericRuleFormatter)
        if ok then numberFormatter = formatter end
    end
    if not numberFormatter then return end
    -- Do not change this binding's Duration object, FontString, or Enabled
    -- state: Blizzard owns all three, including the secret-safe live updates.
    pcall(binding.SetFormatter, binding, numberFormatter)
end

-- Native Blizzard's timer remains authoritative. Do not mirror or rewrite
-- duration values in an UpdateDuration post-hook, especially in combat.
local function SyncDuration(button)
    ApplyNativeSuffixFormat(button)
end

-- A clean four-sided outline, with independently configurable thickness/offset.
local function MakeBorderEdge(button)
    local edge = button:CreateTexture(nil, "OVERLAY", nil, 7)
    edge:SetColorTexture(1, 1, 1, 1)
    edge:SetBlendMode("ADD")
    edge:Hide()
    return edge
end


-- Apply alpha to the SPELL ART only, not the container or its timer/glow.
-- The native tracker may refresh icon transparency on Update(), so this is
-- also called from that secure post-hook. No access to protected aura data.
local function ApplyIconOpacity(button)
    if button and button.Icon and NoExternalPulseDB then
        button.Icon:SetAlpha(NoExternalPulseDB.iconOpacity or 1)
    end
end

local function ApplyGlow(button)
    if not button or not button.NEPGlow or not button.NEPBorders then return end
    local db = NoExternalPulseDB
    local visible = not button.isExample and button.hasValidInfo and button:IsShown()
    local color = (visible and CLASS_COLORS[GetCasterClass(button)]) or FALLBACK_COLOR
    ns.PaintGlow(button.Icon, button.NEPGlow, button.NEPBorders,
        button.NEPStaticGlow, button.NEPGlowSweep, db,
        ns.GetConfiguredGlowColor(color), 1, visible)
end

-- Midnight combat fix: a new buff often causes Blizzard to SHOW an already
-- prepared aura button while in combat. The regular ApplyGlow deliberately
-- stops during combat because hasValidInfo and aura metadata may be secret.
-- Instead, only style our OWN pre-created textures. Do not read aura IDs,
-- duration values, caster data, or change the native frame / timer.
-- If Blizzard hides an aura button, its child glow automatically hides too.
local function HideCombatGlow(button)
    if not button then return end
    if button.NEPGlow then button.NEPGlow:Hide() end
    if button.NEPStaticGlow then button.NEPStaticGlow:Hide() end
    if button.NEPBorders then
        for _, edge in ipairs(button.NEPBorders) do edge:Hide() end
    end
end

local function ShowCombatGlow(button)
    if not button or not button.NEPGlow or not NoExternalPulseDB then return end
    -- Only check UI visibility; never branch on hasValidInfo in combat.
    -- The Update hook is also used for pre-created hidden slots, so skip them.
    if not button:IsShown() or not button.Icon or not button.Icon:IsShown() then
        HideCombatGlow(button)
        return
    end
    local db = NoExternalPulseDB
    if not db.glow then
        HideCombatGlow(button)
        return
    end
    -- Preserve class color when the glow was painted before combat. When a
    -- NEW aura appears in combat the caster is secret, so use fallback gold.
    local shown = (button.NEPGlow and button.NEPGlow:IsShown())
    if not shown and button.NEPBorders then
        for _, edge in ipairs(button.NEPBorders) do
            if edge:IsShown() then shown = true break end
        end
    end
    if shown then return end
    ns.PaintGlow(button.Icon, button.NEPGlow, button.NEPBorders,
        button.NEPStaticGlow, button.NEPGlowSweep, db, FALLBACK_COLOR, 1, true)
end

-- A native cooldown swipe. The game engine animates the shaded sector from an
-- aura duration object, without exposing secret timing values to addon Lua.
local function StyleSwipe(button)
    local swipe = button.NEPSwipe
    if not swipe then return end
    local db = NoExternalPulseDB
    swipe:SetDrawSwipe(true)
    swipe:SetDrawEdge(false)
    swipe:SetDrawBling(false)
    swipe:SetSwipeColor(0, 0, 0, db.swipeOpacity)
    if type(swipe.SetReverse) == "function" then
        swipe:SetReverse(db.swipeReverse)
    end
    if type(swipe.SetHideCountdownNumbers) == "function" then
        swipe:SetHideCountdownNumbers(true)
    end
end

-- Sweep diagnostics: no chat spam in combat; /ie sweepdebug prints results.
-- These methods can be protected on Retail Midnight and may reject calls
-- originating in an addon even when the inputs are passed through untouched.
local sweepStats = { successful = 0, errors = {}, paths = {}, failures = 0 }
local function SweepRecord(code, reason)
    sweepStats.paths[code] = (sweepStats.paths[code] or 0) + 1
    if reason and sweepStats.errors[code] == nil then
        sweepStats.errors[code] = tostring(reason):sub(1, 180)
    end
end

-- Midnight 12.1.5 limits C_UnitAuras.GetAuraDuration() to untainted
-- callers while auras are secret. Our hooks are addon/tainted code. Never
-- retry protected aura queries during combat just to paint a cosmetic swipe.
local function RestrictedAuraAccess()
    if InCombatLockdown and InCombatLockdown() then return true end
    -- In arenas, restrictions can remain active even when the player is
    -- briefly not in combat. This native check is optional across builds.
    if C_Secrets and type(C_Secrets.HasSecretRestrictions) == "function" then
        local ok, restricted = pcall(C_Secrets.HasSecretRestrictions)
        if ok and restricted == true then return true end
    end
    return false
end

-- Native Blizzard's duration binding may already hold the exact
-- DurationObject used to drive the ticking timer. We only READ this object;
-- we never SetDuration(), write its text, or rebind the native timer.
local function TryNativeDuration(button, swipe)
    local ok, result = pcall(function()
        local b = button.DurationTextBinding or button.durationTextBinding
            or button.durationBinding or button.DurationBinding
        if not b or type(b.GetDuration) ~= "function" then
            return "missing"
        end
        local duration = b:GetDuration()
        if not duration then return "empty" end
        swipe:SetCooldownFromDurationObject(duration)
        return "bound"
    end)
    if ok and result == "bound" then return true end
    if not ok then
        SweepRecord("native-rejected", result)
    else
        SweepRecord("native-" .. tostring(result))
    end
    return false
end

local function TryAuraDuration(button, swipe)
    if not (C_UnitAuras and type(C_UnitAuras.GetAuraDuration) == "function") then
        SweepRecord("aura-api-missing")
        return false
    end
    -- auraInstanceID may be secret. NEVER compare, cache, print, or convert it
    -- in combat. Transfer it directly to native APIs, inside a protected call.
    local ok, result = pcall(function()
        local info = button.buttonInfo
        if not info then return "no-info" end
        local duration = C_UnitAuras.GetAuraDuration("player", info.auraInstanceID)
        if not duration then return "no-duration" end
        swipe:SetCooldownFromDurationObject(duration)
        return "bound"
    end)
    if ok and result == "bound" then return true end
    if not ok then
        SweepRecord("aura-rejected", result)
    else
        SweepRecord("aura-" .. tostring(result))
    end
    return false
end

local function TryBindNativeSwipe(button)
    local swipe = button and button.NEPSwipe
    if not swipe then return false end
    if TryNativeDuration(button, swipe) then
        sweepStats.successful = sweepStats.successful + 1
        SweepRecord("bound-native")
        return true
    end
    if TryAuraDuration(button, swipe) then
        sweepStats.successful = sweepStats.successful + 1
        SweepRecord("bound-aura")
        return true
    end
    sweepStats.failures = sweepStats.failures + 1
    return false
end

local function SyncSwipe(button)
    local swipe = button and button.NEPSwipe
    local db = NoExternalPulseDB
    if not swipe or not db then return end
    if button.NEPIntrinsicSwipe then
        -- Do not call SetCooldown(), Show(), Hide(), or query auras here.
        -- Blizzard drives the registered cooldown, even for secret auras.
        pcall(swipe.SetDrawSwipe, swipe, not not db.swipe)
        return
    end
    if not db.swipe or button.isExample or not button.hasValidInfo or not button:IsShown() then
        swipe:Hide()
        button.NEPCombatSwipeBound = false
        button.NEPSwipeAuraID = nil
        return
    end
    -- Do not probe GetAuraDuration on restricted addon execution paths.
    -- Existing OOC-bound sweeps may continue ticking in the native widget.
    if RestrictedAuraAccess() then
        if not button.NEPCombatSwipeBound then swipe:Hide() end
        return
    end
    -- Never rebind the same aura on every Blizzard UI update. Aura IDs may
    -- only be compared OUTSIDE combat and only when they are not secret.
    local info = button.buttonInfo
    local id = info and info.auraInstanceID
    local idUsable = id ~= nil and not IsSecret(id)
    local now = GetTime()
    if button.NEPCombatSwipeBound and swipe:IsShown() then
        if not idUsable or id == button.NEPSwipeAuraID then return end
    end
    if button.NEPSwipeOutsideRetryAt and now < button.NEPSwipeOutsideRetryAt then return end
    button.NEPSwipeOutsideRetryAt = now + 0.5
    -- Prefer the native binding; it avoids having to ask for the secret aura
    -- instance ID. OOC the traditional aura lookup remains as a fallback.
    if TryBindNativeSwipe(button) then
        button.NEPCombatSwipeBound = true
        button.NEPSwipeAuraID = idUsable and id or nil
        swipe:Show()
    else
        button.NEPCombatSwipeBound = false
        swipe:Hide()
    end
end

-- Combat path never changes Blizzard's timer, button or aura metadata.
-- The caller only changes the addon-owned NEPSwipe overlay.
local function SyncCombatSwipe(button)
    local swipe = button and button.NEPSwipe
    local db = NoExternalPulseDB
    if not swipe or not db then return end
    if button.NEPIntrinsicSwipe then return end -- engine owns this frame
    if not db.swipe then
        swipe:Hide()
        button.NEPCombatSwipeBound = false
        return
    end
    -- A cooldown successfully configured before combat can keep animating
    -- natively; a newly applied combat aura cannot be bound here without
    -- querying protected aura data. No GetAuraDuration calls or retries.
    if button.NEPCombatSwipeBound then return end
    swipe:Hide()
end

local function PrintSweepDiagnostics()
    Print("Sweep test: " .. sweepStats.successful .. " successful binding(s), " .. sweepStats.failures .. " failed attempt(s).")
    local labels = {
        "bound-native", "bound-aura", "native-missing", "native-empty",
        "native-rejected", "aura-no-info", "aura-no-duration",
        "aura-api-missing", "aura-rejected", "intrinsic-unavailable",
        "intrinsic-existing", "intrinsic-registered", "intrinsic-rejected", "intrinsic-get-empty",
    }
    for _, label in ipairs(labels) do
        local count = sweepStats.paths[label]
        if count then
            Print(label .. " x" .. count .. (sweepStats.errors[label] and " (" .. sweepStats.errors[label] .. ")" or ""))
        end
    end
    Print("Combat-safe mode: native intrinsic swipes are engine-driven; other new secret auras skip the sweep.")
    if sweepStats.successful == 0 and not sweepStats.paths["intrinsic-registered"]
        and not sweepStats.paths["intrinsic-existing"] then
        Print("No sweep could bind. Blizzard-native timer is unaffected.")
    end
end

-- 12.1 native AuraButton route. If this Blizzard tracker button really
-- supports the intrinsic AuraButton duration registration, the WoW engine
-- can drive our swipe in combat without returning any aura data to Lua.
-- Not all stock aura trackers use this intrinsic. We never replace methods
-- or read protected data here, and registration runs outside combat only.
local function TryRegisterIntrinsicSwipe(button)
    if not button or button.NEPIntrinsicSwipe or not button.NEPSwipe then return end
    if InCombatLockdown and InCombatLockdown() then return end
    if not NoExternalPulseDB or not NoExternalPulseDB.swipe then return end
    if button.NEPIntrinsicSweepChecked then return end
    button.NEPIntrinsicSweepChecked = true

    local getNative = button.GetDurationCooldown
    local setNative = button.SetDurationCooldown
    if type(getNative) ~= "function" and type(setNative) ~= "function" then
        SweepRecord("intrinsic-unavailable")
        return
    end

    if type(getNative) == "function" then
        local ok, native = pcall(getNative, button)
        if ok and native and type(native.SetDrawSwipe) == "function" then
            -- Prefer an existing engine-bound cooldown; no reassignment.
            button.NEPSwipe:Hide()
            button.NEPSwipe = native
            button.NEPIntrinsicSwipe = true
            pcall(StyleSwipe, button)
            SweepRecord("intrinsic-existing")
            return
        end
    end

    if type(setNative) == "function" then
        local ok, message = pcall(setNative, button, button.NEPSwipe)
        if ok then
            button.NEPIntrinsicSwipe = true
            pcall(StyleSwipe, button)
            SweepRecord("intrinsic-registered")
        else
            SweepRecord("intrinsic-rejected", message)
        end
    else
        SweepRecord("intrinsic-get-empty")
    end
end

local function SyncGlowSweep(button)
    local cd = button and button.NEPGlowSweep
    if not cd then return end
    local db = NoExternalPulseDB
    if not (db.glow and db.glowSweep) or button.isExample
        or not button.hasValidInfo or not button:IsShown() then
        cd:Hide()
        button.NEPGlowSweepAuraID = nil
        return
    end
    local info = button.buttonInfo
    local id = info and info.auraInstanceID
    if IsSecret(id) or id == nil or not (C_UnitAuras and C_UnitAuras.GetAuraDuration) then
        cd:Hide()
        button.NEPGlowSweepAuraID = nil
        return
    end
    if button.NEPGlowSweepAuraID ~= id then
        local ok, duration = pcall(C_UnitAuras.GetAuraDuration, "player", id)
        if not ok or not duration then cd:Hide() return end
        if not pcall(cd.SetCooldownFromDurationObject, cd, duration) then
            cd:Hide()
            return
        end
        button.NEPGlowSweepAuraID = id
    end
    local color = CLASS_COLORS[GetCasterClass(button)] or FALLBACK_COLOR
    ns.StyleGlowSweep(cd, db, color, true)
end

local function PrepareButton(button)
    if not button or button.NEPGlow then return end
    if InCombatLockdown and InCombatLockdown() then
        pendingSetup = true
        return
    end
    if not button.Icon or not button.Duration then return end
    -- Cooldown is above the icon, while our dedicated foreground layer keeps
    -- the glow and timer visibly above the dark sweep.
    local swipe = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    swipe:SetAllPoints(button.Icon)
    swipe:SetFrameLevel(button:GetFrameLevel() + 1)
    swipe:EnableMouse(false)
    swipe:Hide()
    button.NEPSwipe = swipe
    -- A rejected cooldown API must not prevent icon/timer setup.
    if not pcall(StyleSwipe, button) then swipe:Hide() end
    pcall(TryRegisterIntrinsicSwipe, button)

    local front = CreateFrame("Frame", nil, button)
    front:SetAllPoints(button)
    front:SetFrameLevel(button:GetFrameLevel() + 3)
    front:EnableMouse(false)
    button.NEPFront = front
    button.NEPGlowSweep = ns.CreateGlowSweep(button, button.Icon, button:GetFrameLevel() + 2)

    local halo = front:CreateTexture(nil, "ARTWORK", nil, 7)
    halo:SetTexture("Interface\\AddOns\\ImprovedExternalDefs\\Media\\NeonOutline.tga")
    halo:SetBlendMode("ADD")
    halo:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -9, 9)
    halo:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 9, -9)
    halo:Hide()
    button.NEPGlow = halo
    local staticGlow = front:CreateTexture(nil, "ARTWORK", nil, 6)
    staticGlow:SetBlendMode("BLEND") -- same blending as Cooldown:SetSwipeTexture
    staticGlow:Hide()
    button.NEPStaticGlow = staticGlow
    button.NEPBorders = { MakeBorderEdge(front), MakeBorderEdge(front), MakeBorderEdge(front), MakeBorderEdge(front) }
    -- Aura sounds are independent of native icon slots (SoundAlerts.lua).
    -- Native Blizzard font owns the ticking value even during combat.
    -- Keep our glow foreground layer, but never rebind the aura timer.
    PositionText(button)
    hooksecurefunc(button, "Update", function(self)
        -- Never modify Blizzard's active buttons from an addon execution path
        -- in combat. Audio registration is handled outside these hooks.
        if InCombatLockdown and InCombatLockdown() then
            -- This changes only addon-owned overlay textures and NEVER the
            -- native frame, aura metadata, or Duration FontString.
            pcall(ShowCombatGlow, self)
            pcall(SyncCombatSwipe, self)
            return
        end
        -- Blizzard may reset the text anchors when the icon is re-used or
        -- refreshed. Reapply requested layout only OUT of combat; the native
        -- FontString is still exclusively driven by Blizzard's duration engine.
        pcall(PositionText, self)
        -- Outside combat, style using non-secret button data.
        pcall(SyncDuration, self)
        pcall(ApplyIconOpacity, self)
        pcall(ApplyGlow, self)
        pcall(SyncSwipe, self)
        pcall(SyncGlowSweep, self)
        pcall(ApplyGlow, self)
    end)
    hooksecurefunc(button, "UpdateDuration", function(self)
        if InCombatLockdown and InCombatLockdown() then return end
        pcall(PositionText, self)
        pcall(SyncDuration, self)
        pcall(SyncSwipe, self)
        pcall(SyncGlowSweep, self)
        pcall(ApplyGlow, self)
    end)
    button:HookScript("OnHide", function(self)
        -- An aura can vanish and the same Blizzard slot can be re-used.
        -- Forget our previous duration object; never write native timers.
        self.NEPCombatSwipeBound = false
        self.NEPCombatSwipeRetryAt = nil
        self.NEPSwipeOutsideRetryAt = nil
        if self.NEPSwipe and not self.NEPIntrinsicSwipe then self.NEPSwipe:Hide() end
        if InCombatLockdown and InCombatLockdown() then
            -- Reset ONLY our overlays while Blizzard reorders its buttons.
            pcall(HideCombatGlow, self)
            return
        end
        if self.NEPSwipe and not self.NEPIntrinsicSwipe then self.NEPSwipe:Hide() end
        self.NEPSwipeAuraID = nil
        if self.NEPGlowSweep then self.NEPGlowSweep:Hide() end
        self.NEPGlowSweepAuraID = nil
        if self.NEPGlow then self.NEPGlow:Hide() end
        if self.NEPStaticGlow then self.NEPStaticGlow:Hide() end
        if self.NEPBorders then
            for _, edge in ipairs(self.NEPBorders) do edge:Hide() end
        end
    end)
    -- A newly shown defensive may appear before Update() is dispatched.
    button:HookScript("OnShow", function(self)
        -- Rebind next incoming external, even if this icon slot was reused.
        self.NEPCombatSwipeBound = false
        self.NEPCombatSwipeRetryAt = nil
        self.NEPSwipeOutsideRetryAt = nil
        if InCombatLockdown and InCombatLockdown() then
            pcall(ShowCombatGlow, self)
            pcall(SyncCombatSwipe, self)
        else
            pcall(ApplyGlow, self)
        end
    end)
end

local function ApplyAppearance()
    if InCombatLockdown and InCombatLockdown() then
        pendingSetup = true
        return
    end
    local frame = ExternalDefensivesFrame
    if not frame or not frame.auraFrames then return end
    for _, button in ipairs(frame.auraFrames) do
        if not button.isAuraAnchor then
            local ok, err = pcall(function()
                PrepareButton(button)
                if button.NEPGlow then
                    ApplyAntiPulseVisuals(button)
                    PositionText(button)
                    ApplyIconOpacity(button)
                    SyncDuration(button)
                    ApplyGlow(button)
                    StyleSwipe(button)
                    pcall(TryRegisterIntrinsicSwipe, button)
                    SyncSwipe(button)
                    SyncGlowSweep(button)
                    ApplyGlow(button)
                end
            end)
            if not ok and not setupErrorReported then
                setupErrorReported = true
                Print("One icon could not be styled: " .. tostring(err))
            end
        end
    end
end

local function Setup()
    InitializeDB()
    -- In strict diagnostics we don't read, hook, parent, reposition or
    -- replace ANY Blizzard tracker button/region/method. This mode requires
    -- a UI reload to start clean because earlier taint cannot be undone.
    if not NoExternalPulseDB.safeMode then
        if not NoExternalPulseDB.nativeSweepMode then ApplyAppearance() end
    end
    if ns.UpdatePreview then ns.UpdatePreview() end
end
local function SafeSetup()
    local ok, err = pcall(Setup)
    if not ok and not setupErrorReported then
        setupErrorReported = true
        Print("Style initialization warning: " .. tostring(err))
    end
    return ok
end
ns.ApplySettings = SafeSetup

local function Status()
    local d = NoExternalPulseDB
    Print("Version " .. ADDON_VERSION)
    Print("Safe mode: " .. tostring(d.safeMode) .. " (change requires /reload)")
    Print("Native engine-driven sweep mode: " .. tostring(d.nativeSweepMode) .. " | layout=" .. tostring(d.nativeLayout) .. " | spacing=" .. tostring(d.nativeIconSpacing) .. "px | unknown class=" .. tostring(d.nativeFallbackColor))
    Print("Combat class-colored glow: " .. tostring(d.nativeClassFilter))
    Print("Visual anti-pulse: " .. tostring(d.enabled) .. " (parent-alpha isolation) | Class glow: " .. tostring(d.glow) .. " / " .. d.glowStyle)
    Print("Timer: " .. d.textPosition .. " X=" .. d.textX .. " Y=" .. d.textY .. " size=" .. d.textSize .. " auto-scale=" .. tostring(d.textAutoScale) .. " hide 's'=" .. tostring(d.removeSecondsSuffix))
    Print("Icon opacity: " .. math.floor(d.iconOpacity * 100 + 0.5) .. "%")
    Print("Sound alert: " .. tostring(d.soundEnabled) .. " | sound=" .. tostring(d.soundKey) .. " | channel=" .. tostring(d.soundChannel))
    if ns.AuraSoundStatus then Print(ns.AuraSoundStatus()) end
    Print("Cooldown sweep: " .. tostring(d.swipe) .. " | darkness=" .. math.floor(d.swipeOpacity * 100 + 0.5) .. "% | reverse=" .. tostring(d.swipeReverse))
end

local function SetNumber(field, value, lo, hi)
    local n = tonumber(value)
    if not n or n < lo or n > hi then
        Print("Expected value: " .. tostring(lo) .. " to " .. tostring(hi))
        return false
    end
    NoExternalPulseDB[field] = math.floor(n + 0.5)
    return true
end

local function Help()
    Print("/ie : options | on/off : visual anti-pulse | safemode on/off : isolate native tracker")
    Print("/ie glow on/off | style border/halo/both | nativesweep on/off | nativeinfo")
    Print("/ie test [on/off] : simulate 3 externals (9s, 18s, 30s) at the tracker")
    Print("/ie intro : show the illustrated External Defensives setup guide")
    Print("/ie classfilter on/off | classinfo : native class-colored glow (requires /reload)")
    Print("/ie darknessinfo : verify Darkness spell selection and native group (no aura reads)")
    Print("/ie spellinfo : show native HELPFUL tracking diagnostics for all selected spells")
    Print("/ie casterinfo : show allied Emerald Communion / Tranquility diagnostics (/ie communioninfo also works)")
    Print("/ie profile : manage named profiles and import/export codes")
    Print("Icon position, scale and orientation: Blizzard Edit Mode only. No sound alerts.")
    Print("/ie iconopacity 0..1 | swipe on/off | sweepopacity 0.1..0.95 | reverse on/off | sweepdebug")
    Print("/ie suffix on/off (on = remove 's') | text center/top/bottom/default")
    Print("/ie x N | y N | size N | thickness N | offset N | opacity 0.1..1 | status | version | reset")
end

SLASH_IMPROVEDEXTERNALDEFS1 = "/ie"
SLASH_IMPROVEDEXTERNALDEFS2 = "/improvedexternaldefs"
-- Legacy shortcuts retained for existing macros and scripts.
SLASH_IMPROVEDEXTERNALDEFS3 = "/edcd"
SLASH_IMPROVEDEXTERNALDEFS4 = "/ee"
SLASH_IMPROVEDEXTERNALDEFS5 = "/nep"
SLASH_IMPROVEDEXTERNALDEFS6 = "/externaldefcds"
SLASH_IMPROVEDEXTERNALDEFS7 = "/externaledit"
SlashCmdList.IMPROVEDEXTERNALDEFS = function(input)
    InitializeDB()
    local command, argument = (input or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local db = NoExternalPulseDB
    if command == "" or command == "config" or command == "options" then
        if ns.OpenOptions then
            local ok, err = pcall(ns.OpenOptions)
            if not ok then Print("Could not open options: " .. tostring(err)) end
        else Help() end
        return
    elseif command == "intro" or command == "welcome" then
        if ns.ShowTrackerIntroduction then
            ns.ShowTrackerIntroduction()
        else
            Print("Setup guide is not available yet. Try again after loading.")
        end
        return
    elseif command == "profile" or command == "profiles" then
        if ns.OpenOptions then ns.OpenOptions() end
        return
    elseif command == "test" then
        if not ns.ToggleWorldTest then Print("Test module unavailable.") return end
        local ok, result, message = pcall(ns.ToggleWorldTest, argument == "" and "toggle" or argument)
        if not ok then
            ns.LastWorldTestError = tostring(result)
            Print("Test error: " .. ns.LastWorldTestError)
        else
            Print(message or "Test updated.")
        end
        return
    elseif command == "testerror" then
        Print("Last 3-icon test error: " .. tostring(ns.LastWorldTestError or "none"))
        return
    elseif command == "soundtest" then
        Print("Sound alerts have been removed.")
        return
    elseif command == "soundstatus" then
        Print("Sound alerts are disabled in this version.")
        return
    elseif command == "sweepdebug" then
        PrintSweepDiagnostics()
        return
    elseif command == "nativeinfo" then
        if ns.NativeSweepStatus then Print(ns.NativeSweepStatus()) else Print("Native sweep module not loaded.") end
        return
    elseif command == "editanchor" then
        if not ns.CaptureNativeEditModeAnchor then Print("Edit Mode capture unavailable.") return end
        local ok, message = ns.CaptureNativeEditModeAnchor()
        Print((ok and "|cff55ff99" or "|cffff9966") .. tostring(message) .. "|r")
        return
    elseif command == "alignprobe" or command == "aligncapture" then
        if not ns.NativeLiveAlignmentProbe then Print("Alignment diagnostic unavailable.") return end
        local ok, message = ns.NativeLiveAlignmentProbe(command == "aligncapture")
        Print((ok and "|cff55ff99" or "|cffff9966") .. tostring(message) .. "|r")
        return
    elseif command == "alignreset" then
        if not ns.ResetNativeLiveAlignment then Print("Alignment reset unavailable.") return end
        local ok, message = ns.ResetNativeLiveAlignment()
        Print((ok and "|cff55ff99" or "|cffff9966") .. tostring(message) .. "|r")
        return
    elseif command == "communioninfo" or command == "casterinfo" then
        Print(ns.PartyCasterStatus and ns.PartyCasterStatus() or "Party caster tracker not loaded")
        return
    elseif command == "classinfo" then
        if ns.NativeClassFilterStatus then Print(ns.NativeClassFilterStatus())
        else Print("Class-filter module not loaded.") end
        return
    elseif command == "darknessinfo" then
        if ns.DarknessTrackingStatus then Print(ns.DarknessTrackingStatus())
        else Print("Darkness tracking module not loaded.") end
        return
    elseif command == "spellinfo" then
        if ns.ExtraSpellTrackingStatus then Print(ns.ExtraSpellTrackingStatus())
        else Print("Extra spell tracking module not loaded.") end
        return
    elseif command == "classfilter" then
        if argument ~= "on" and argument ~= "off" then
            Print("Usage: /ie classfilter on/off | requires /reload outside combat")
            return
        end
        db.nativeClassFilter = argument == "on"
        Print("Combat class glows " .. (db.nativeClassFilter and "enabled" or "disabled") .. ". Type /reload outside combat to apply.")
        if ns.RefreshOptions then ns.RefreshOptions() end
        return
    elseif command == "nativesweep" then
        if argument ~= "on" and argument ~= "off" then Print("Usage: /ie nativesweep on/off") return end
        db.nativeSweepMode = argument == "on"
        Print("Native engine-driven mode set to " .. tostring(db.nativeSweepMode) .. ". /reload OUTSIDE COMBAT to apply.")
        return
    elseif command == "nativelayout" or command == "centeroffset" or command == "nativespacing" then
        Print("Icon layout and spacing are now controlled by Blizzard Edit Mode only.")
        return
    elseif command == "nativecolor" then
        local choices = {white="WHITE", pink="PALADIN", gold="GOLD", druid="DRUID", priest="PRIEST", paladin="PALADIN", shaman="SHAMAN", monk="MONK", evoker="EVOKER"}
        if not choices[argument] then Print("Usage: /ie nativecolor white/pink/gold/druid/priest/paladin/shaman/monk/evoker") return end
        db.nativeFallbackColor = choices[argument]
        if ns.RefreshNativeSweep then ns.RefreshNativeSweep() end
        if ns.ProfileSettingsChanged then ns.ProfileSettingsChanged() end
        Print("Fallback glow: " .. db.nativeFallbackColor)
        return
    elseif command == "safemode" then
        if argument ~= "on" and argument ~= "off" then
            Print("Usage: /ie safemode on OR /ie safemode off")
            return
        end
        db.safeMode = argument == "on"
        Print("Safe mode set to " .. tostring(db.safeMode) .. ". Type /reload OUT OF COMBAT to apply.")
        return
    elseif command == "sound" then
        Print("Sound alerts have been removed from ImprovedExternalDefs.")
        return
    elseif command == "on" or command == "off" then
        db.enabled = (command == "on")
        if InCombatLockdown and InCombatLockdown() then
            Print("Visual anti-pulse will apply when combat ends; /reload is recommended.")
        end
    elseif command == "glow" then
        if argument ~= "on" and argument ~= "off" then Help() return end
        db.glow = argument == "on"
    elseif command == "swipe" or command == "reverse" then
        if argument ~= "on" and argument ~= "off" then Help() return end
        db[command == "swipe" and "swipe" or "swipeReverse"] = argument == "on"
    elseif command == "iconopacity" then
        local n = tonumber(argument)
        if not n or n < 0 or n > 1 then Print("Expected value: 0 to 1") return end
        db.iconOpacity = math.floor(n * 100 + 0.5) / 100
    elseif command == "sweepopacity" then
        local n = tonumber(argument)
        if not n or n < 0.1 or n > 0.95 then Print("Expected value: 0.1 to 0.95") return end
        db.swipeOpacity = n
    elseif command == "suffix" then
        if argument ~= "on" and argument ~= "off" then Help() return end
        db.removeSecondsSuffix = argument == "on"
    elseif command == "style" then
        local allowed = { border = "BORDER", halo = "HALO", both = "BOTH" }
        if not allowed[argument] then Help() return end
        db.glowStyle = allowed[argument]
    elseif command == "text" then
        local allowed = { center = "CENTER", centre = "CENTER", top = "TOP", bottom = "BOTTOM", default = "DEFAULT" }
        if not allowed[argument] then Help() return end
        db.textPosition = allowed[argument]
    elseif command == "x" then
        if not SetNumber("textX", argument, -50, 50) then return end
    elseif command == "y" then
        if not SetNumber("textY", argument, -50, 50) then return end
    elseif command == "size" then
        if not SetNumber("textSize", argument, 8, 30) then return end
    elseif command == "thickness" then
        if not SetNumber("glowThickness", argument, 1, 6) then return end
    elseif command == "offset" then
        if not SetNumber("glowOffset", argument, 0, 6) then return end
    elseif command == "opacity" then
        local n = tonumber(argument)
        if not n or n < 0.1 or n > 1 then Print("Expected value: 0.1 to 1") return end
        db.glowOpacity = n
    elseif command == "status" then
        Status()
        return
    elseif command == "version" then
        Print("Version " .. ADDON_VERSION)
        return
    elseif command == "reset" then
        for k, v in pairs(DEFAULTS) do db[k] = v end
    else
        Help()
        return
    end
    if ns.ProfileSettingsChanged then ns.ProfileSettingsChanged() end
    SafeSetup()
    if ns.RefreshOptions then pcall(ns.RefreshOptions) end
    Status()
end

local function SafeOptions()
    if ns.CreateOptions then
        local ok, err = pcall(ns.CreateOptions)
        if not ok then Print("Options initialization warning: " .. tostring(err)) end
    end
end

-- Branded first-run / disabled-tracker guide. This is a normal Blizzard
-- StaticPopup with an inserted art frame (no custom secure UI or aura reads).
-- The logo belongs to ImprovedExternalDefs; users may preview via /ie intro.
-- Blizzard owns positioning, cancellation and confirmation buttons.
local trackerNoticeScheduled = false
local trackerNoticeShownThisLogin = false
local logoPath = "Interface\\AddOns\\ImprovedExternalDefs\\Media\\AddonLogo.tga"

local function CreateTrackerGuide(message)
    -- A new frame per variant prevents a previous popup from stealing the
    -- same inserted frame. The frame is not a tracked WoW aura frame.
    local artwork = CreateFrame("Frame")
    artwork:SetSize(302, 226)

    local logo = artwork:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(logoPath)
    logo:SetSize(94, 94)
    logo:SetPoint("TOP", artwork, "TOP", 0, -2)

    local instructions = artwork:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetWidth(290)
    instructions:SetPoint("TOP", logo, "BOTTOM", 0, -9)
    instructions:SetJustifyH("CENTER")
    instructions:SetJustifyV("TOP")
    instructions:SetText(message)
    return artwork
end

local disabledGuide = CreateTrackerGuide(
    "|cffffb96a" .. L("SETUP REQUIRED") .. "|r\n" ..
    L("Blizzard's External Defensives tracker is disabled.") .. "\n" ..
    L("Enable it below to display defensive buffs.") .. "\n\n" ..
    "|cffffb96a" .. L("MOVE AND RESIZE YOUR ICONS") .. "|r\n" ..
    L("Esc > Edit Mode > External Defensives")
)
local welcomeGuide = CreateTrackerGuide(
    "|cffffb96a" .. L("EXTERNAL DEFENSIVES") .. "|r\n" ..
    L("Keep Blizzard's tracker enabled to display buffs.") .. "\n\n" ..
    "|cffffb96a" .. L("MOVE AND RESIZE YOUR ICONS") .. "|r\n" ..
    L("Esc > Edit Mode > External Defensives") .. "\n\n" ..
    L("Glows, timers & profiles: /ie")
)

local function ShowTrackerGuide(which, artwork)
    if type(StaticPopup_Show) ~= "function" then return false end
    -- Blizzard 11.2+ sometimes leaves an inserted frame hidden after its
    -- first use; showing it before every StaticPopup_Show avoids that issue.
    artwork:Show()
    return StaticPopup_Show(which, nil, nil, nil, artwork) ~= nil
end

local function TrackerPopupReady(force)
    if not ns.IsBlizzardTrackerEnabled then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local enabled = ns.IsBlizzardTrackerEnabled()
    if enabled == false then
        if ShowTrackerGuide("IMPROVEDEXTERNALDEFS_TRACKER_DISABLED", disabledGuide) then
            trackerNoticeShownThisLogin = true
        end
    elseif enabled == true and NoExternalPulseDB and
           (force or not NoExternalPulseDB.trackerIntroSeen) then
        if ShowTrackerGuide("IMPROVEDEXTERNALDEFS_TRACKER_WELCOME", welcomeGuide) then
            NoExternalPulseDB.trackerIntroSeen = true
            trackerNoticeShownThisLogin = true
        end
    end
end

-- Optional manual preview for existing users who have already seen the guide.
ns.ShowTrackerIntroduction = function()
    if InCombatLockdown and InCombatLockdown() then
        Print("Leave combat before opening the setup guide.")
        return
    end
    TrackerPopupReady(true)
end

local function RegisterTrackerPopups()
    if not StaticPopupDialogs then return end
    StaticPopupDialogs.IMPROVEDEXTERNALDEFS_TRACKER_DISABLED = {
        text = "|cffffb96aImprovedExternalDefs|r",
        button1 = L("Enable tracker"),
        button2 = L("Later"),
        OnAccept = function()
            local ok, err = false, "The Blizzard setting is not available."
            if ns.EnableBlizzardTracker then ok, err = ns.EnableBlizzardTracker() end
            if ok then
                if ns.RefreshTrackerStatus then ns.RefreshTrackerStatus() end
                Print("Blizzard External Defensives enabled. Move/resize icons in Esc > Edit Mode.")
            else
                Print(err or "Could not enable the Blizzard tracker.")
            end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs.IMPROVEDEXTERNALDEFS_TRACKER_WELCOME = {
        text = "|cffffb96aImprovedExternalDefs|r",
        button1 = L("Got it"),
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end
RegisterTrackerPopups()

local function ScheduleTrackerNotice()
    if trackerNoticeScheduled then return end
    trackerNoticeScheduled = true
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(1.0, function()
            if not trackerNoticeShownThisLogin then TrackerPopupReady() end
        end)
    else
        TrackerPopupReady()
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(self, event, arg)
    if event == "PLAYER_LOGIN" then
        InitializeDB()
        -- Always register settings FIRST. A Blizzard icon/swipe incompatibility
        -- must never prevent the category from being created.
        SafeOptions()
        SafeSetup()
    elseif event == "ADDON_LOADED" and arg == ADDON_NAME then
        InitializeDB()
        SafeOptions()
    elseif event == "ADDON_LOADED" and arg == "Blizzard_BuffFrame" then
        SafeSetup()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Skip old preexisting auras while loading/teleporting.
        SafeOptions()
        SafeSetup()
        ScheduleTrackerNotice()
        if NoExternalPulseDB and NoExternalPulseDB.safeMode then
            Print("Safe Mode is ON: native anti-pulse is disabled. Type /ie safemode off, then /reload to test visual anti-pulse.")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingSetup then
            pendingSetup = false
            SafeSetup()
        end
        if trackerNoticeScheduled and not trackerNoticeShownThisLogin then
            TrackerPopupReady()
        end
    end
end)
