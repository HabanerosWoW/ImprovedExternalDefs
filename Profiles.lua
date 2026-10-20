-- ImprovedExternalDefs 1.5.1 - named profiles and backward-compatible EE1 / EE2 / EE3 codes.
-- The existing NoExternalPulseDB SavedVariables name is deliberately retained.
local _, ns = ...
local L = ns.L or function(s) return s end

local KEYS = {
    "enabled", "glow", "glowStyle", "glowThickness", "glowOffset",
    "glowOpacity", "swipe", "swipeOpacity", "swipeReverse",
    "removeSecondsSuffix", "textPosition", "textX", "textY", "textSize",
    "iconOpacity", "soundEnabled", "soundKey", "soundChannel", "soundVolume", "soundPath", "glowSweep",
    "nativeLayout", "nativeFallbackColor", "nativeIconSpacing",
    -- EE8: required for matching the real duration renderer on another character.
    "nativeSweepMode", "nativeClassFilter",
    -- EE9: custom glow and tenths-of-second formatting.
    "glowColorMode", "glowCustomR", "glowCustomG", "glowCustomB", "durationDecimalsThreshold",
    -- EE10: opt-in extra native helpful auras + up to 50 additional buff IDs.
    "extraObsidianScales", "extraIntervene", "extraSpellIDs",
    -- EE11: additional catalog selections and suppressed native externals.
    "selectedExtraSpellIDs", "disabledNativeSpellIDs",
    -- EE12: retired controls; retain fields for importing old EE12 codes.
    "autoExternalDefensives", "autoStealableDefensives",
    -- EE13: optional scaling of native timer fonts with Edit Mode icon size.
    "textAutoScale",
}
local BOOL = { enabled = true, glow = true, swipe = true, swipeReverse = true, removeSecondsSuffix = true, soundEnabled = true, glowSweep = true, nativeSweepMode = true, nativeClassFilter = true, extraObsidianScales = true, extraIntervene = true, autoExternalDefensives = true, autoStealableDefensives = true, textAutoScale = true }
local RANGES = {
    glowThickness = {1, 6}, glowOffset = {0, 6}, glowOpacity = {0.1, 1},
    iconOpacity = {0, 1}, soundVolume = {0, 1},
    swipeOpacity = {0.1, 0.95}, textX = {-50, 50}, textY = {-50, 50},
    textSize = {8, 30}, nativeIconSpacing = {0, 20},
    glowCustomR = {0, 1}, glowCustomG = {0, 1}, glowCustomB = {0, 1},
    durationDecimalsThreshold = {0, 3600},
}
local VALID_STYLES = { BORDER = true, HALO = true, BOTH = true }
local VALID_POSITIONS = { CENTER = true, TOP = true, BOTTOM = true, DEFAULT = true }
local VALID_CHANNELS = { Master = true, SFX = true }
local VALID_SOUND_KEYS = {}
for _, sound in ipairs(ns.SOUND_CHOICES or {}) do VALID_SOUND_KEYS[sound[1]] = true end
local function ValidSoundKey(value)
    if type(value) ~= "string" then return false end
    if VALID_SOUND_KEYS[value] or value == "CUSTOM" or value == "IE_ALERT" then return true end
    return #value > 4 and #value <= 99
        and value:sub(1, 4) == "LSM:" and not value:find("[%c]")
end

local function DB()
    return NoExternalPulseDB
end

local function Snapshot()
    local s = {}
    for _, key in ipairs(KEYS) do s[key] = DB()[key] end
    return s
end

local function Validate(source)
    if type(source) ~= "table" then return nil, "Invalid profile data." end
    local result = {}
    for _, key in ipairs(KEYS) do
        local value = source[key]
        -- Older SavedVariables profiles had no sound settings, and before
        -- v1.4.3 there was no icon opacity. Apply safe opt-in defaults.
        if value == nil and ns.DEFAULTS and ns.DEFAULTS[key] ~= nil then
            value = ns.DEFAULTS[key]
        end
        if BOOL[key] then
            if value ~= true and value ~= false then return nil, "Invalid " .. key end
        elseif key == "glowColorMode" then
            if value ~= "CLASS" and value ~= "CUSTOM" then return nil, "Invalid glow color mode." end
        elseif key == "glowStyle" then
            if not VALID_STYLES[value] then return nil, "Invalid glow style." end
        elseif key == "textPosition" then
            if not VALID_POSITIONS[value] then return nil, "Invalid timer position." end
        elseif key == "nativeLayout" then
            if value ~= "HORIZONTAL" and value ~= "VERTICAL" and value ~= "FOLLOW" and value ~= "CENTERED" then
                return nil, "Invalid native layout." end
        elseif key == "nativeFallbackColor" then
            local valid = {WHITE=true, GOLD=true, PALADIN=true, PRIEST=true,
                DRUID=true, SHAMAN=true, MONK=true, EVOKER=true}
            if not valid[value] then return nil, "Invalid native fallback color." end
        elseif key == "extraSpellIDs" or key == "selectedExtraSpellIDs" or key == "disabledNativeSpellIDs" then
            if type(value) ~= "string" or #value > 900 then
                return nil, "Invalid selected Spell ID list."
            end
            if value ~= "" then
                if not value:match("^%d[%d,]*$") or value:find(",,") or value:sub(-1) == "," then
                    return nil, "Invalid custom Spell ID list."
                end
                local used, count = {}, 0
                for component in (value .. ","):gmatch("(.-),") do
                    local spellID = tonumber(component)
                    if not spellID or spellID < 1 or spellID > 99999999 or used[spellID] then
                        return nil, "Invalid or duplicate Spell ID."
                    end
                    used[spellID] = true
                    count = count + 1
                end
                if count > (key == "extraSpellIDs" and 50 or 100) then
                    return nil, "Too many spell IDs." end
            end
        elseif key == "soundKey" then
            if not ValidSoundKey(value) then return nil, "Invalid alert sound." end
        elseif key == "soundPath" then
            local normalized = ns.NormalizeSoundPath and ns.NormalizeSoundPath(value)
            if normalized == nil then return nil, "Invalid custom audio path." end
            value = normalized
        elseif key == "soundChannel" then
            if not VALID_CHANNELS[value] then return nil, "Invalid audio channel." end
        elseif key == "durationDecimalsThreshold" then
            -- New thresholds 1..10 and 15 coexist with legacy 60/Always.
            -- Validate types before comparisons so malformed profile imports
            -- cannot throw a Lua error while parsing a code.
            if type(value) ~= "number" or value ~= value or
                (value ~= 0 and value ~= 15 and value ~= 60 and value ~= 3600 and
                 (value < 1 or value > 10 or value % 1 ~= 0)) then
                return nil, "Invalid fractional-seconds threshold."
            end
        else
            local bounds = RANGES[key]
            if type(value) ~= "number" or value ~= value or value < bounds[1] or value > bounds[2] then
                return nil, "Invalid " .. key
            end
            if key ~= "glowOpacity" and key ~= "iconOpacity" and key ~= "swipeOpacity" and key ~= "soundVolume" and key ~= "glowCustomR" and key ~= "glowCustomG" and key ~= "glowCustomB" and value % 1 ~= 0 then
                return nil, "Invalid whole-number value for " .. key
            end
        end
        result[key] = value
    end
    -- Existing EE12 export codes keep the same fields and lengths, but these
    -- experiments have been retired: do not reactivate them when importing.
    result.autoExternalDefensives = false
    result.autoStealableDefensives = false
    return result
end

local function NameOK(name)
    return type(name) == "string" and #name > 0 and #name <= 28
        and name:match("%S") and not name:find("[%c]", 1)
end

function ns.InitProfiles()
    local db = DB()
    if type(db.profiles) ~= "table" then
        db.profiles = { Default = Snapshot() }
        db.activeProfile = "Default"
    end
    if type(db.profiles.Default) ~= "table" then db.profiles.Default = Snapshot() end
    if type(db.activeProfile) ~= "string" or type(db.profiles[db.activeProfile]) ~= "table" then
        db.activeProfile = "Default"
        db.profiles.Default = Snapshot()
    end
end

function ns.GetProfileNames()
    ns.InitProfiles()
    local names = {}
    for name, value in pairs(DB().profiles) do
        if NameOK(name) and Validate(value) then names[#names + 1] = name end
    end
    table.sort(names, function(a, b)
        if a == "Default" then return true end
        if b == "Default" then return false end
        return a:lower() < b:lower()
    end)
    return names
end

function ns.ActiveProfileName()
    return DB().activeProfile or "Default"
end

function ns.ProfileSettingsChanged()
    ns.InitProfiles()
    DB().profiles[DB().activeProfile] = Snapshot()
end

local function Refresh()
    if ns.ApplySettings then ns.ApplySettings() end
    if ns.RefreshNativeSweep then ns.RefreshNativeSweep() end
    if ns.RefreshOptions then ns.RefreshOptions() end
end

function ns.SaveProfile(name)
    if not NameOK(name) then return false, "Use a profile name of 1-28 characters." end
    ns.ProfileSettingsChanged()
    DB().profiles[name] = Snapshot()
    DB().activeProfile = name
    Refresh()
    return true, L("Saved profile: ") .. name
end

function ns.LoadProfile(name)
    ns.InitProfiles()
    local saved, err = Validate(DB().profiles[name])
    if not saved then return false, err or "Profile not found." end
    local oldNative = DB().nativeSweepMode
    local oldFilter = DB().nativeClassFilter
    local oldDecimals = DB().durationDecimalsThreshold
    local oldSuffix = DB().removeSecondsSuffix
    local oldObsidian, oldIntervene, oldExtraIDs = DB().extraObsidianScales, DB().extraIntervene, DB().extraSpellIDs
    local oldChosen, oldHidden = DB().selectedExtraSpellIDs, DB().disabledNativeSpellIDs
    local oldAutoExt, oldAutoSteal = DB().autoExternalDefensives, DB().autoStealableDefensives
    -- Persist unsaved changes to the outgoing profile, not the incoming one.
    if DB().activeProfile ~= name then ns.ProfileSettingsChanged() end
    DB().activeProfile = name
    for _, key in ipairs(KEYS) do DB()[key] = saved[key] end
    Refresh()
    local reload = oldNative ~= saved.nativeSweepMode or oldFilter ~= saved.nativeClassFilter
        or oldDecimals ~= saved.durationDecimalsThreshold or oldSuffix ~= saved.removeSecondsSuffix
        or oldObsidian ~= saved.extraObsidianScales or oldIntervene ~= saved.extraIntervene
        or oldExtraIDs ~= saved.extraSpellIDs or oldChosen ~= saved.selectedExtraSpellIDs
        or oldHidden ~= saved.disabledNativeSpellIDs
        or oldAutoExt ~= saved.autoExternalDefensives or oldAutoSteal ~= saved.autoStealableDefensives
    return true, L("Loaded profile: ") .. name ..
        (reload and L(" | /reload outside combat to apply native tracker settings.") or "")
end

function ns.DeleteProfile(name)
    ns.InitProfiles()
    if name == "Default" then return false, "The Default profile cannot be deleted." end
    if not DB().profiles[name] then return false, "Profile not found." end
    DB().profiles[name] = nil
    if DB().activeProfile == name then
        DB().activeProfile = "Default"
        local saved = Validate(DB().profiles.Default)
        if saved then
            for _, key in ipairs(KEYS) do DB()[key] = saved[key] end
        end
    end
    Refresh()
    return true, L("Deleted profile: ") .. name
end

-- Hex encoding prevents commas/newlines in custom paths or SharedMedia names
-- from corrupting the fixed-field export format. The decoder never evaluates Lua.
local function HexEncode(str)
    return (str:gsub(".", function(char) return string.format("%02X", char:byte()) end))
end
local function HexDecode(value)
    if type(value) ~= "string" or #value % 2 ~= 0 or value:find("[^0-9a-fA-F]") then return nil end
    return (value:gsub("%x%x", function(pair) return string.char(tonumber(pair, 16)) end))
end

function ns.ExportProfile(name)
    ns.InitProfiles()
    if name == DB().activeProfile then ns.ProfileSettingsChanged() end
    local saved = Validate(DB().profiles[name])
    if not saved then return nil, "Profile unavailable." end
    local parts = {}
    for _, key in ipairs(KEYS) do
        local value = saved[key]
        if key == "soundKey" or key == "soundPath" or key == "extraSpellIDs" or key == "selectedExtraSpellIDs" or key == "disabledNativeSpellIDs" then
            parts[#parts + 1] = HexEncode(value)
        else
            parts[#parts + 1] = BOOL[key] and (value and "1" or "0") or tostring(value)
        end
    end
    -- Fixed field order / strict validation; no arbitrary Lua code or external libraries.
    return "EE13:" .. table.concat(parts, ",")
end

local function UniqueName(name)
    local base = (NameOK(name) and name or "Imported"):sub(1, 28)
    if not DB().profiles[base] then return base end
    for i = 2, 999 do
        local suffix = " (" .. i .. ")"
        local candidate = base:sub(1, 28 - #suffix) .. suffix
        if not DB().profiles[candidate] then return candidate end
    end
    return nil
end

function ns.ImportProfile(code, requestedName)
    ns.InitProfiles()
    if type(code) ~= "string" or #code > 5000 then return false, "Invalid or oversized code." end
    local stripped = code:match("^%s*(.-)%s*$")
    local prefix = stripped:sub(1, 5) == "EE13:" and "EE13:" or
        (stripped:sub(1, 5) == "EE12:" and "EE12:" or
        (stripped:sub(1, 5) == "EE11:" and "EE11:" or
        (stripped:sub(1, 5) == "EE10:" and "EE10:" or stripped:sub(1, 4))))
    if prefix ~= "EE1:" and prefix ~= "EE2:" and prefix ~= "EE3:" and prefix ~= "EE4:" and prefix ~= "EE5:" and prefix ~= "EE6:" and prefix ~= "EE7:" and prefix ~= "EE8:" and prefix ~= "EE9:" and prefix ~= "EE10:" and prefix ~= "EE11:" and prefix ~= "EE12:" and prefix ~= "EE13:" then
        return false, "Invalid profile code (EE1-EE13 formats are supported)."
    end
    local items = {}
    for item in (stripped:sub(#prefix + 1) .. ","):gmatch("(.-),") do
        items[#items + 1] = item
    end
    -- EE1: 14, EE2: 15, EE3: 19, EE4: 20, EE5: 21, EE6: 23,
    -- EE7: 24, EE8: 26, EE9: 31, EE10: 34, EE11: 36, EE12: 38, EE13: 39.
    local expected = prefix == "EE1:" and 14 or
        (prefix == "EE2:" and 15 or (prefix == "EE3:" and 19 or
        (prefix == "EE4:" and 20 or (prefix == "EE5:" and 21 or
        (prefix == "EE6:" and 23 or (prefix == "EE7:" and 24 or
        (prefix == "EE8:" and 26 or (prefix == "EE9:" and 31 or
        (prefix == "EE10:" and 34 or (prefix == "EE11:" and 36 or (prefix == "EE12:" and 38 or #KEYS)))))))))))
    if #items ~= expected then return false, "Invalid code length." end
    local values = {}
    for i, key in ipairs(KEYS) do
        local s = items[i]
        if s == nil and ns.DEFAULTS[key] ~= nil then
            values[key] = ns.DEFAULTS[key]
        elseif (prefix == "EE4:" or prefix == "EE5:" or prefix == "EE6:" or prefix == "EE7:" or prefix == "EE8:" or prefix == "EE9:" or prefix == "EE10:" or prefix == "EE11:" or prefix == "EE12:" or prefix == "EE13:") and
            (key == "soundKey" or key == "soundPath" or
             ((prefix == "EE10:" or prefix == "EE11:" or prefix == "EE12:" or prefix == "EE13:") and key == "extraSpellIDs") or
             ((prefix == "EE11:" or prefix == "EE12:" or prefix == "EE13:") and (key == "selectedExtraSpellIDs" or key == "disabledNativeSpellIDs"))) then
            values[key] = HexDecode(s)
        elseif BOOL[key] then
            if s ~= "0" and s ~= "1" then return false, "Invalid boolean in code." end
            values[key] = s == "1"
        elseif RANGES[key] then
            values[key] = tonumber(s)
        else
            values[key] = s
        end
    end
    if prefix == "EE6:" then
        local switched = { HORIZONTAL = "VERTICAL", VERTICAL = "HORIZONTAL" }
        values.nativeLayout = switched[values.nativeLayout] or values.nativeLayout
    end
    local validated, err = Validate(values)
    if not validated then return false, err end
    validated.nativeLayout = "FOLLOW"
    validated.soundEnabled = false
    local name = UniqueName(requestedName)
    if not name then return false, "Too many similarly named profiles." end
    local oldNative = DB().nativeSweepMode
    local oldFilter = DB().nativeClassFilter
    local oldDecimals = DB().durationDecimalsThreshold
    local oldSuffix = DB().removeSecondsSuffix
    local oldObsidian, oldIntervene, oldExtraIDs = DB().extraObsidianScales, DB().extraIntervene, DB().extraSpellIDs
    local oldChosen, oldHidden = DB().selectedExtraSpellIDs, DB().disabledNativeSpellIDs
    local oldAutoExt, oldAutoSteal = DB().autoExternalDefensives, DB().autoStealableDefensives
    ns.ProfileSettingsChanged()
    DB().profiles[name] = validated
    DB().activeProfile = name
    for _, key in ipairs(KEYS) do DB()[key] = validated[key] end
    Refresh()
    local reload = oldNative ~= validated.nativeSweepMode or oldFilter ~= validated.nativeClassFilter
        or oldDecimals ~= validated.durationDecimalsThreshold or oldSuffix ~= validated.removeSecondsSuffix
        or oldObsidian ~= validated.extraObsidianScales or oldIntervene ~= validated.extraIntervene
        or oldExtraIDs ~= validated.extraSpellIDs or oldChosen ~= validated.selectedExtraSpellIDs
        or oldHidden ~= validated.disabledNativeSpellIDs
        or oldAutoExt ~= validated.autoExternalDefensives or oldAutoSteal ~= validated.autoStealableDefensives
    return true, L("Imported and activated: ") .. name ..
        (reload and L(" | /reload outside combat to apply native tracker settings.") or "")
end
