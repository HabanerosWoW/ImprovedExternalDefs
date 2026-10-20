-- ImprovedExternalDefs v1.5.64 - Retail 12.1.5 focused defensive buffs, not a complete
-- spellbook or a list of every personal defensive. Every row must pass one
-- of two checks: (1) another player can protect the PLAYER with it, or
-- (2) it is a defensive MAGIC buff that a Mage can Spellsteal.
--
-- These IDs describe beneficial auras on the player, not cooldown casts.
-- Where a cast ID differs from its aura ID, auraIDs must contain ONLY the
-- candidate buff IDs. Talent/spec variants are resolved by Blizzard's
-- native HELPFUL candidate filters during combat, never by Lua aura reads.
--
-- kind=NATIVE: Blizzard external-category buff (on by default).
-- kind=SPECIAL: existing opt-ins for Obsidian Scales / Intervene.
-- kind=OPTIONAL: deliberate opt-in; NOT automatically shown.
-- source=ALLY: cast/applied to you by a teammate or protective area.
-- source=STEAL: magical personal defensive that may be Spellstolen.
-- source=BOTH: both an ally's buff and a stealable defensive.
local _, ns = ...
ns.SpellCatalog = {
    -- DEATH KNIGHT: 48707 is personal-only, cannot be Spellstolen.
    -- Keep its legacy option key (48707) but track ONLY the ally-targeted
    -- Spellwarding buff 410358. Users of the 1.5.32 checkbox keep it enabled.
    {id=48707, displayID=410358, class="DEATHKNIGHT", kind="OPTIONAL", source="ALLY", english="Anti-Magic Shell", auraIDs={410358}, note="Spellwarding PvP talent: tracks the ally-applied buff (410358), not the personal shell (48707)."},
    {id=145629, class="DEATHKNIGHT", kind="OPTIONAL", source="ALLY", english="Anti-Magic Zone", auraIDs={145629,51052}},

    -- DEMON HUNTER: a protective area; neither Blur nor Demon Spikes
    -- can be applied to an ally or stolen as a Magic buff.
    {id=209426, class="DEMONHUNTER", kind="OPTIONAL", source="ALLY", english="Darkness", auraIDs={209426,196718}},

    -- DRUID: personal Barkskin and Survival Instincts intentionally absent.
    {id=102342, class="DRUID", kind="NATIVE", source="ALLY", english="Ironbark"},
    -- Tranquility is tracked as a channeling aura ON THE ALLIED DRUID,
    -- not a buff on the player. Shares the caster-side native AuraContainer
    -- approach already validated for the Evoker's Emerald Communion.
    {id=740, class="DRUID", kind="CAST", source="CAST", english="Tranquility", note="Shows while an allied Druid channels Tranquility (740), even if you are out of range or receive no healing. Optional; requires /reload."},

    -- EVOKER: with Lifecinders, Obsidian Scales can protect an ally.
    {id=363916, class="EVOKER", kind="SPECIAL", source="ALLY", english="Obsidian Scales", note="Ally-shared version requires the Lifecinders talent."},
    {id=357170, class="EVOKER", kind="NATIVE", source="ALLY", english="Time Dilation"},
    {id=374227, class="EVOKER", kind="NATIVE", source="ALLY", english="Zephyr"},
    -- Preservation Evoker Rewind: beneficial 4-second periodic-heal aura on
    -- nearby allies. Unlike Emerald Communion this belongs to the PLAYER
    -- HELPFUL group, so the main centered row handles it automatically.
    {id=363534, class="EVOKER", kind="OPTIONAL", source="ALLY", english="Rewind", note="4-second Rewind healing-over-time aura on the recipient; opt-in and /reload required. To validate the aura ID in-game on Retail 12.1.5."},
    -- Caster-side exception: when an allied Evoker channels Emerald Communion,
    -- the beneficial aura exists on the EVOKER, not necessarily on the player.
    -- A separate Blizzard-native party-unit AuraContainer tracks it; this ID
    -- must NEVER be added to our player/recipient defensive aura groups.
    {id=370960, class="EVOKER", kind="CAST", source="CAST", english="Emerald Communion", note="Shows when an allied Evoker channels Emerald Communion, even if you are out of range or receive no healing. Requires /reload."},

    -- HUNTER
    {id=53480, class="HUNTER", kind="OPTIONAL", source="ALLY", english="Roar of Sacrifice"},

    -- MAGE: personal barriers qualify ONLY because they are stealable
    -- Magic defensive buffs. Ice Block is not a regular stealable barrier.
    -- Mass Barrier was removed in Midnight 12.0 (do not list 414660).
    {id=11426, class="MAGE", kind="OPTIONAL", source="STEAL", english="Ice Barrier"},
    {id=235313, class="MAGE", kind="OPTIONAL", source="STEAL", english="Blazing Barrier"},
    {id=235450, class="MAGE", kind="OPTIONAL", source="STEAL", english="Prismatic Barrier"},

    -- MONK
    {id=116849, class="MONK", kind="NATIVE", source="ALLY", english="Life Cocoon"},
    -- Celestial Harmony/Chi-Ji/Yu'lon and Midnight variants. The recipient
    -- gains a separate absorb BUFF; do not confuse it with a personal brew.
    {id=406139, class="MONK", kind="OPTIONAL", source="ALLY", english="Chi Cocoon", auraIDs={406139,406220,1260681}, note="Celestial Harmony Chi Cocoon shields. 406220 observed on a recipient in Retail 12.1.5; other variants still require live verification. Optional and OFF by default."},

    -- PALADIN: only actual protective buffs, not instantaneous healing.
    {id=1022, class="PALADIN", kind="NATIVE", source="BOTH", english="Blessing of Protection"},
    {id=6940, class="PALADIN", kind="NATIVE", source="ALLY", english="Blessing of Sacrifice", auraIDs={6940,199448}},
    {id=204018, class="PALADIN", kind="NATIVE", source="ALLY", english="Blessing of Spellwarding"},
    {id=210256, class="PALADIN", kind="OPTIONAL", source="BOTH", english="Blessing of Sanctuary"},
    -- 31821 mainly enhances the caster's selected aura. 317929 is a timed
    -- recipient-side anti-interrupt/silence aura with Concentration Aura.
    {id=317929, class="PALADIN", kind="OPTIONAL", source="ALLY", english="Aura Mastery (Concentration)", note="Concentration Aura variant only: ally immunity to silence and interrupts; NOT the caster-only 31821 buff."},

    -- PRIEST: shield, single-target externals, and area reduction.
    {id=47788, class="PRIEST", kind="NATIVE", source="ALLY", english="Guardian Spirit"},
    {id=33206, class="PRIEST", kind="NATIVE", source="ALLY", english="Pain Suppression"},
    {id=17, class="PRIEST", kind="OPTIONAL", source="BOTH", english="Power Word: Shield"},
    {id=81782, class="PRIEST", kind="OPTIONAL", source="ALLY", english="Power Word: Barrier"},
    -- Holy Priest PvP talent Sanctified Ground: 289657 creates the zone;
    -- 289655 is the actual beneficial silence/interrupt immunity aura
    -- on allies standing within the area.
    {id=289655, class="PRIEST", kind="OPTIONAL", source="ALLY", english="Sanctified Ground", note="Holy Priest PvP talent: immunity to silence and interrupts while affected by Sanctified Ground. 289655 is the recipient buff; 289657 creates the area. Enable manually and test in Retail 12.1.5."},
    -- Divine Hymn: 64843 is the priest's channel. 64844 is the timed
    -- 4%-per-stack healing-received aura actually granted to nearby allies.
    {id=64844, class="PRIEST", kind="OPTIONAL", source="ALLY", english="Divine Hymn", note="Holy Priest: healing-received buff (+4% per application, 15 sec). 64843 is the cast, not the buff. Requires /reload."},

    -- SHAMAN: the aura from Spirit Link Totem is separate from its cast.
    -- 325174 was the old optional entry; keep as the selection ID.
    {id=325174, displayID=98008, class="SHAMAN", kind="OPTIONAL", source="ALLY", english="Spirit Link", auraIDs={98008,325174}},

    -- WARLOCK: a magical spell-reflect buff which can be Spellstolen.
    {id=212295, class="WARLOCK", kind="OPTIONAL", source="STEAL", english="Nether Ward"},

    -- WARRIOR: 147833/3411 are known Intervene auras.
    {id=147833, class="WARRIOR", kind="SPECIAL", source="ALLY", english="Intervene", auraIDs={147833,3411}},
    -- Separate buffs can coexist with Intervene, so these MUST remain
    -- individually selectable instead of auto-showing duplicates of one CD.
    {id=1244091, class="WARRIOR", kind="OPTIONAL", source="ALLY", english="Interpose", note="Midnight 12.0 Arms/Fury alternative to Intervene. Beneficial mitigation aura on allies within 3 yards; test in-game."},
    {id=424655, class="WARRIOR", kind="OPTIONAL", source="ALLY", english="Safeguard", note="PvP talent reduces an ally's damage taken after Intervene; separate 5-sec buff. Test in-game."},
    {id=438598, class="WARRIOR", kind="OPTIONAL", source="ALLY", english="Storm Shield", note="Mountain Thane talent: 5-sec magic absorb on Intervene target; separate buff. Test in-game."},
    {id=97463, class="WARRIOR", kind="OPTIONAL", source="ALLY", english="Rallying Cry"},
}
