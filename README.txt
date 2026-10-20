ImprovedExternalDefs v1.5.67 (test) — Native layout / no sounds

This build follows Blizzard Edit Mode for position, size and orientation.
Sound alerts have been removed. Spell tracking, timers, glows and profiles remain.
Please verify in Solo Shuffle before publishing this release.

ImprovedExternalDefs v1.5.60 — WoW Retail / Midnight 12.1.5

Customize Blizzard External Defensives:
- Settings: Icons, Text, Sound, Spells, Profiles
- Native Blizzard-driven combat sweep and class-filtered glows
- Customizable glow, icon transparency, text, alerts and profile sharing

Commands: /IE (settings), /IE test (3-icon test), /IE intro (branded setup guide)

Installation: Install ONLY the ImprovedExternalDefs folder in Interface/AddOns.
Remove the obsolete ExternalDefCDsEdit folder manually (the ZIP no longer includes it).
Existing users: before removing the old folder, first log out normally after
using ImprovedExternalDefs, so WoW saves your current settings into:
  _retail_/WTF/Account/<account>/SavedVariables/ImprovedExternalDefs.lua
No account data, profiles, or SavedVariables files ship in this ZIP.
If migrating straight from ExternalDefCDsEdit without having run a previous
ImprovedExternalDefs version, back up your old SavedVariables and import an
existing profile code; the one-time legacy bridge is not bundled any more.

First-run welcome / tracker-disabled dialog now displays the IE logo and an
Edit Mode guide; /IE intro reopens it without resetting your settings.
If the tracker is off, the Enable tracker button still requires a user click.

Version 1.5.23: Profile codes use EE8 and include nativeSweepMode and nativeClassFilter.
Use /reload after importing a profile that changes these renderer settings.
Older EE1-EE7 codes remain accepted (missing settings use current defaults).

Version 1.5.26:
- Icons tab shows Blizzard External Defensives tracker status.
- If the native tracker is disabled, a warning and Enable button appear.
- Status refreshes when the CVar changes and after entering/leaving combat.
- This is a game CVar, not an addon profile option; no personal settings are included.

Version 1.5.26
- First-run guidance explains Blizzard External Defensives and Edit Mode positioning.
- Disabled Blizzard tracker triggers a login popup with opt-in enable button.
- Test positions ignore secret coordinates and cache the last safe screen position.

Version 1.5.26 adds class/custom glow color selection and fractional-second timers (tenths) using native formatters. For live native timers, /reload is needed after changing decimal format or importing a profile with changed duration formatting.


1.5.27 TEST BUILD — Additional tracked defensives:
- Icons > Additional tracked defensives: Obsidian Scales (363916) and Intervene (147833 / 3411), separately configurable.
- Up to 50 custom helpful BUFF Spell IDs; localization uses WoW C_Spell.
- Extra auras use native HELPFUL and exclude Blizzard EXTERNAL_DEFENSIVE to prevent duplicates; combat rendering should be verified in game.
- Extra aura visibility needs native sweep on and /reload after configuring.
- Extra aura sounds are NOT yet handled by the existing stock-tracker audio detection.
- Export codes EE10 include these settings; EE1-EE9 remain importable.

1.5.28 TEST BUILD — Tracked Spells tab:
- Dedicated Spells tab with a searchable catalogue of 75 defensive Spell IDs.
- Filter by class; names and icons are obtained from the WoW client locale.
- Switch additional helpful buffs on/off independently (all optional spells off by default).
- Blizzard external defensives remain enabled by default; known spells can be hidden
  from ImprovedExternalDefs's managed display, without modifying Blizzard's CVar.
- Obsidian Scales / Intervene preferences from 1.5.27 remain intact.
- Up to fifty manual custom Spell IDs (Add / Del on the Spells tab).
- New EE11 share codes include the selection / native-exclusion lists; EE1-EE10 still import.
- /reload OUT of combat after changing a Spell ID filter.
- Some effects, notably Rewind, may not create a persistent HELPFUL aura;
  selecting their ID does NOT make instant casts trackable.
- Only current auras on the player are shown; it does not track cooldown readiness.
- Sound alerts for OPTIONAL additional auras are not implemented yet.
- Based on a curated set of defensive Spell ID facts in the user-supplied MiniAuras
  12.1 package; no MiniAuras addon source or copyrighted UI components copied.

Version 1.5.29 test patch:
- Darkness / Ténèbres is now shown once in the Spells list, as an optional aura: 209426.
- The casting spell 196718 was not a Blizzard-native defensive buff and could misleadingly appear selected without producing a tracker icon.
- To track Darkness, enable Darkness (209426) under Spells > Demon Hunter, then /reload outside combat.
- The icon is only expected when your character actually receives the area aura while inside Darkness.
- Combat tracking requires in-game validation. All other prior profiles and features remain unchanged.

1.5.30 TEST BUILD — Darkness compatibility experiment:
- Corrected the extra aura filter from HELPFUL|!EXTERNAL_DEFENSIVE to HELPFUL.
  Candidate includeSpellIDs still limits tracking to the user-selected buffs.
  The former negation could silently exclude a buff with an external flag.
- A single Darkness (209426) checkbox registers BOTH 209426 and 196718 as
  candidate IDs, consistent with the two IDs seen in MiniAuras' spell data.
- Extra spell IDs are excluded from our native EXTERNAL_DEFENSIVE groups when
  they are selected, preventing duplicates if Blizzard classifies them native.
- /ie darknessinfo reports whether the Darkness group was built after /reload.
- This is an unverified experiment. MiniAuras may display Darkness on party
  frames while this addon only shows helpful auras received by 'player'.
- The addon doesn't track casts or Darkness zones outside the player's buffs.
- No changes to CVar settings, saved profile format EE11 or audio detection.

1.5.31 TEST BUILD — Unified additional spell filtering:
- The HELPFUL + includeSpellIDs route that fixed Darkness already applies to
  all optional and manually added buff IDs; this release explicitly standardizes
  candidate spell variants in catalog data (Darkness 209426/196718,
  Intervene 147833/3411) rather than hard-coding Darkness in the tracker.
- Selected extra buffs are excluded from companion native Blizzard groups
  (not from the Blizzard tracker itself) to prevent duplicate icons.
- /ie spellinfo reports the number of registered HELPFUL groups and candidate
  IDs without reading secret combat auras. Use after /reload.
- Spell names and icons still localize from the game client; saved profiles
  and EE11 share codes are unchanged, and no account files are packaged.
- A spell must actually create a beneficial aura on the PLAYER to appear;
  selecting a cast-only or instant-heal ID cannot force an icon.
- User confirmed Darkness while attacking a PvP dummy; verify skirmishes.
- Extra-spell sound alerts are still not supported in this build.


1.5.32 TEST BUILD - Curated talent-aware aura families:
- Anti-Magic Shell / Carapace anti-magie is a single optional checkbox covering
  48707 (regular) AND 410358 (Spellwarding PvP talent buff).
- Darkness remains one checkbox for 209426/196718. Intervene still maps to
  147833/3411. These were already covered in 1.5.31.
- Blessing of Sacrifice is ONE native checkbox for 6940/199448; the old
  duplicate OPTIONAL row has been removed. The active family is routed through
  HELPFUL + includeSpellIDs so the variant need not have Blizzard's external
  category flag. This displays received buffs only, not cooldowns or casts.
- Previous profiles are read unchanged: an old standalone 199448 opt-in is
  respected; using the unified checkbox normalizes that family's toggles.
- The spell search finds known variant IDs (e.g. 410358, 199448) and tooltips
  show the included buff IDs. No MiniAuras files are bundled or needed.
- Variant pairs were cross-referenced against the user-provided MiniAuras
  scanned Retail 12.1 PvP class catalog. SpellNameIndex contains many older
  spells and NPC entries, so it is intentionally NOT imported wholesale.
- Confirm in a Retail PvP match that the correct variant buff is applied to
  YOUR player, then check the icon appears in combat. Reload after changes.
- Sound alerts for additional/non-native buffs are still not supported.


1.5.33 TEST BUILD - Ally-only / Spellsteal defensive catalogue:
- Tracked Spells catalogue reduced from 73 entries to
  24 protective BUFF families: on-player ally externals and defensive Magic
  buffs a Mage can steal. Pure personal nonstealable defensives (Icebound
  Fortitude, Lichborne, Cloak of Shadows, Barkskin, Ice Block, etc.) are gone.
- Existing native aura groups now use a strict ID allowlist. The former
  unlimited EXTERNAL_DEFENSIVE fallback could display uncatalogued buffs.
- Spellwarding: legacy 48707 checkbox still functions, but only the targeted
  410358 BUFF is matched; personal DK 48707 no longer tracked by that option.
- Retained legacy settings, optional selections, tests, sounds, and visuals.
  Old optional IDs not in the new catalogue are ignored by the curated list;
  users' custom ID box remains a deliberate advanced override.
- New option labels distinguish ally-only buffs and stealable defensives.
- Added a few external auras not in the former catalogue (Power Word: Shield,
  Power Word: Barrier, Blessing of Sanctuary) and kept mage barriers because
  they are genuinely spellstealable MAGIC protective buffs.
- Data-only selection: no combat spell querying or caster inspection.
- IMPORTANT: The external player and Spellsteal must actually grant an aura
  with the listed buff ID; not all spells cast/steal apply an aura to you.
  /reload after changing selections. Verify in actual PvP.

1.5.34 EXPERIMENTAL - Blizzard category tracking:
- Spells -> Experimental Blizzard filters adds two OFF-by-default options.
- Auto external: HELPFUL|EXTERNAL_DEFENSIVE with excludeSpellIDs only. Known opt-outs and explicit extras are excluded to avoid duplicate icons.
- Auto stealable: HELPFUL|BIG_DEFENSIVE|DISPELLABLE|!EXTERNAL_DEFENSIVE with native isStealable and excludeSpellIDs filters.
- Both filters run inside Blizzard's aura container; Lua never examines secret combat spell identities to decide inclusion.
- Blizzard controls which auras get native category labels: this DOES NOT promise every talent-modified mage barrier appears, or that classification is perfect.
- Experimental external icons may use neutral glow when their class is unknown.
- Requires /reload outside combat. Disable to restore 1.5.33 curated behavior.
- Profiles use EE12 codes; EE1 through EE11 import is retained.

1.5.35 RETAIL 12.1.5 CATALOGUE AUDIT - DATA ONLY
- Existing working rendering/filtering/API code is UNCHANGED. Experimental
  Blizzard category switches remain OFF by default in existing profiles.
- Six OPTIONAL defensive buff families added, OFF by default for profile safety:
  Warrior Interpose 1244091; Safeguard 424655; Storm Shield 438598;
  Paladin Barrier of Faith shields 395180 / 388536;
  Paladin Aura Mastery with Concentration Aura 317929 (NOT caster-only 31821);
  Monk Chi Cocoon 406139 / 1260681.
- The cast 148039 is not used for Barrier of Faith; its two direct protective
  aura IDs are listed. Spell-ID variants are candidate BUFF IDs, not talents.
- New entries are separated where a single spell may apply multiple distinct
  buffs. This avoids silently activating a second aura under an existing toggle.
- The three warrior effects may overlap; you can choose their visibility.
- All previous 24 catalogue rows stay the same, including validated spells.
- Source: WoW 12.1.5 spell records and Blizzard Midnight changes. All new
  entries require in-game testing; do not claim 100% completeness.
- Existing EE12 import/export stays identical; no saved data was bundled.
- In Spells select an OPTIONAL new buff, then /reload OUTSIDE combat.

1.5.36 - CHI COCOON RECIPIENT ID (Retail 12.1.5)
- Add observed Chi Cocoon recipient aura 406220 to monk optional family.
- One checkbox now includes 406139 / 406220 / 1260681.
- No engine, renderer, timers, profiles or other spell-family modifications.
- Enable Chi Cocoon in Spells (MONK), reload out of combat, test buff.
- Identified from a live user buff report, cross-checked with spell data.

1.5.37 - SANCTIFIED GROUND (Retail 12.1.5)
- Add Holy Priest PvP Sanctified Ground as optional ally buff (289655).
- 289655 is the beneficial anti-silence / anti-interrupt aura, distinct from the ground-effect cast 289657.
- One entry under Spells > Priest, disabled by default; enable and /reload OUT of combat.
- All engine files, profiles, glows, sounds and previously tested spell mappings are unchanged.
- Requires verification of the received buff in game; selecting an entry does not force it to appear if absent.

1.5.38 STABLE CANDIDATE - RENAMED TO ImprovedExternalDefs (Retail 12.1.5)
- Renamed installed addon folder, .toc and Lua entrypoint.
- Options title, category, chat messages, tracker notices, resource paths
  and version text now say ImprovedExternalDefs.
- /IE (case-insensitive: /ie) is the primary command, including /IE test,
  /IE status, /IE version and every previous subcommand.
- Older shortcuts (/ee, /edcd, /nep, /externaldefcds, /externaledit) still work
  for existing macros. Old EE1-EE12 profile code formats remain compatible.
- Removed unavailable Barrier of Faith row from the Retail 12.1.5 catalogue.
- Other spell and tracking logic remains unchanged from 1.5.37.
- Package includes a tiny no-op legacy addon folder to load old saved data
  automatically. This bridge can be removed after first successful logout.
- Storm Shield is still untested in-game; don't claim complete coverage.

1.5.39 - GROUP-HEAL BUFF + CLEANER SPELLS PAGE (Retail 12.1.5)
- NEW: Divine Hymn (Holy Priest), candidate *recipient* aura 64844 (4%
  increased healing received per tick, lasts 15s). Optional and unchecked
  until enabled under Spells -> Priest; /reload required. Needs live test.
- Tranquility NOT added yet: cast spell 740 and healing trigger 1264659
  do not establish a useful aura on the protected teammate in current data.
  Please test whether the recipient actually gains a HELPFUL aura before
  adding an ID to avoid a misleading nonfunctional checkbox.
- Removed the Experimental Blizzard filters section and both experimental
  group modes. Prior native/class-based and custom-ID engines unchanged.
- Preserved EE12 format/field positions so older saved/exported profiles
  import; the two legacy experimental flags are forced to false.
- Kept /IE and all existing shortcut aliases, existing settings, and the
  previous SavedVariables imports from older versions.
- Tranquility (NOT YET TRACKED) and Divine Hymn (UNTESTED) should not be
  reported as validated until confirmed in Retail combat.

1.5.40 - BRANDED SETUP GUIDE & CLEAN PACKAGE (Retail 12.1.5)
- First-run welcome and disabled-tracker dialogs include the official IE logo.
- Guidance for enabling Blizzard External Defensives and positioning the tracker
  via Esc > Edit Mode remains visible.
- Added /ie intro to preview the guide at any time.
- The ZIP contains ONLY ImprovedExternalDefs (no legacy bridge).
- Existing native aura tracking and validated spells are unchanged.
- Divine Hymn confirmed in-game in v1.5.39; Tranquility remains excluded.


1.5.41 experimental: Icons > Combat tracker layout > Centered single row uses
Blizzard AuraContainer CENTER alignment and keeps a large one-line capacity.
No custom repositioning of protected aura frames in combat. This alignment
needs in-game validation on Retail 12.1.5. Other orientations are unchanged.
Sound tracking now counts the visible addon-managed aura buttons (including
additional HELPFUL auras), rather than only the stock tracker. Sounds are
triggered by positive increases in count; same-count replacements can be
missed and must be tested in-game. Older profiles remain importable.


1.5.42 TEST: reworked sound alerts using WoW 12.1+ Blizzard-owned
C_UnitAuras.AddAuraSound on player recipient buff IDs. No aura scanning,
visibility counting or sound decisions from combat-secret data. Native
sound registrations follow the same whitelist as the visible aura container,
including manually selected spells and tested talent variants. Settings
changes re-register outside combat, and /ie soundstatus reports failures.
For SoundKit choices, in-combat delegated audio uses bundled IE chime (the
preview keeps Blizzard's original SoundKit); custom/SharedMedia file paths
play directly. Bundled sound is short due to the 12.1.5 5-second limit.
CENTERED layout now uses a horizontal axis and 4096px maximum line length
instead of the incorrect 256px line length. Single-row center behavior
remains experimental until tested on the actual 12.1.5 game client.


v1.5.45 - Edit Mode positioning test
- The 3-icon test point is now saved in UIParent screen coordinates, independent of the live AuraContainer.
- /ie editanchor while Blizzard Edit Mode is open captures its actual preview icon center.
- /ie aligncapture (outside combat, exactly one live aura) moves only the real aura row to that center.
- Both commands use public geometry only; no protected aura data is read.
- Live tracking, sound and catalog are unchanged.


v1.5.47 - Edit Mode capture fallback (diagnostic)
- /ie editanchor now searches Blizzard's visible AuraButtons for the leftmost example icon (60s); it does not require isAuraAnchor.
- If none is accessible it prints counts and preserves all coordinates.
- Saved Edit Mode reference is never overwritten automatically by simply reopening Edit Mode.
- No tracking, sound or layout engine changes.

1.5.47 TEST: centered single-row pivot now derives from the same native Blizzard Edit Mode starting corner used by Horizontal/Vertical. Ignores saved legacy manual calibration values; never moves aura icons in combat.

1.5.48 TEST: Native dynamic row centering experiment. Same Blizzard Edit Mode first-icon center as v1.5.47, but custom AuraContainer now uses a LEFT flow layout anchor instead of CENTER. Blizzard 12.1 dynamically resizes native aura containers to aura group bounds; this should allow the row to remain centered as the container width changes. Requires validation with 1/2/3 concurrent real auras, especially during combat. Horizontal/Vertical unchanged. No aura IDs, sound logic or profiles changed.

1.5.49 TEST — Emerald Communion (370960): an EVOKER/Party caster aura, not a player buff. Optional Spells > Evoker check box, OFF by default; enable and /reload. A separate Blizzard-native AuraContainer for each party1..party4 displays the 5-second caster aura when active; it does not prove that the player is being healed. Allied UNIT_SPELLCAST payloads can be secret in 12.1.5 PvP, so the addon does not compare them in Lua or synthesize a cast notification. The auxiliary icons are adjacent to the main centered row on the right and do not change the main anchor or reposition other icons. Requires live validation with an allied Preservation Evoker inside an arena; may be unavailable when Blizzard prohibits party aura containers. /ie communioninfo shows initialization status. No automatic sound for this icon.

1.5.50 TEST (Retail 12.1.5)
- Add Evoker Rewind (363534) as an OPTIONAL recipient-side 4-second helpful periodic-heal aura. It uses the already-validated player native AuraContainer; default OFF, opt-in in Spells > Evoker, /reload. Not yet validated in-game.
- Give the allied Emerald Communion icon the same native icon style, timer, sweep, class-colored glow, and options as the main tracker. It remains a separate party-unit AuraContainer, appended to the RIGHT on the SAME horizontal baseline. Player buff layout, native centered pivot, geometry, sounds, and profile structure remain unmodified.
- Limit: Blizzard AuraContainer:SetUnit is per container. Party-caster icons can't join the player AuraGroups' automatically centered width, and the addon may not reposition protected icons based on their active counts in combat. This build does NOT guarantee that an active Communion icon will be included in the combined mathematical center; it preserves the main centered recipient row with the cast indicator visually adjacent.

1.5.51 TEST (Retail 12.1.5)
- Add optional Druid Tranquility (740), followed on party1..party4 using the Druid's beneficial self aura during the channel. It is a CASTER indicator, NOT proof the player receives healing; off by default, select in Spells > Druid then /reload.
- Generalize the already player-tested Emerald Communion party-caster tracker to accept both caster aura IDs, with each spell having its own class-colored styling. The underlying Blizzard AuraContainers still do all combat-safe aura matching.
- Preserve Communion (370960), Evoker Rewind, native centered recipient layout, other spells, sound behavior, visual styling and saved settings.
- Party-caster icons remain separate adjacent native containers, not mathematically part of the automatically centered PLAYER aura group. No in-combat repositioning or secret aura reads.
- New /ie casterinfo command (old /ie communioninfo works) summarizes enabled caster spells and initialization status.
- Tranquility 740 must still be validated on WoW Retail 12.1.5 in game; some talent variants may have different caster auras.

1.5.52 TEST - Sound selection fix (Retail 12.1.5): Blizzard AddAuraSound subscriptions now follow the user's Spells checkboxes strictly. Disabled native/extras/variants/Caster-only/legacy custom matches cannot trigger recipient audio. Unchecking a spell immediately unregisters its sound out of combat; /reload is still required to update the protected visual aura groups. Unknown user-entered custom IDs remain opt-in. Main aura layout, including centered single row, is unchanged.

Version 1.5.53 — User-requested quality-of-life improvements:
- 50 custom helpful buff Spell IDs (Spells page, native whitelist, sound whitelist and profile imports).
- Longer profile code input/output boxes support 50 IDs; EE12 import/export unchanged.
- Red OUT OF RANGE note next to Tranquility and Emerald Communion, with a tooltip warning.
- Auto-localized interface for frFR and English clients via GetLocale(); other clients currently use English fallback.
- Same centered-row tracking as v1.5.52; no aura tracking or sound engine changes.

1.5.55 TEST: AMZ audio only tracks recipient aura 145629 (not cast ID 51052); up to 5s native sound throttle for repeated applications, no change to visual tracking. Spells explanations made clearer in FR/EN. Sound repeat edge cases >5s still require in-game validation.

1.5.56 — Quality of life
- Removed special Rewind explanation from the Spells tab (spell remains tracked).
- Custom Spell IDs list now shows locally resolved spell name and icon; scrolling 2-column list supports 50 entries and refreshes after Blizzard loads spell data.
- Fractional timer thresholds: Off, 1..10 seconds, 15 seconds, plus legacy 60 seconds and Always (preserved for older profiles). Decimal and sound systems unchanged.

1.5.57 — Proportional duration text (Retail 12.1.5)
- Text > Scale text with icon size follows the Blizzard Edit Mode iconScale,
  using 30px as the reference size for the manual Font size control.
- Enabled by default; uncheck for previous fixed-font behavior.
- Live native auras, 3-icon test and Icons page preview use the same scaling.
- Text scale updates out of combat when Blizzard updates the Edit Mode layout;
  no secret aura reads or protected font modifications during combat.
- EE13 export codes preserve this new boolean; older EE1-EE12 codes import
  with the default scaling option. Native centered layout and sound logic unchanged.


v1.5.59 - Icons-page Edit Mode guidance
- Prominent first-section notice explains that Blizzard Edit Mode owns the external-defensives position and icon size; localized in French and English.
- The previous hard-to-see instruction at the bottom of the page was removed.
- All Icons-tab controls and live preview move together below the new notice; no tracking, layout, timer, or sound logic changed.


v1.5.60 - Final centered-row UI label
- Centered single row no longer says experimental in either French or English.
- The option selection message and tooltip use normal, stable wording.
- No changes to audio processing, aura tracking or layouts. Sound volume
  remains constrained by WoW native sound APIs; custom and SharedMedia files
  use their in-game audio channel, not a per-file amplifier.

v1.5.62 TEST — Ground-area re-entry sound behavior (Retail 12.1.5)
- Based on the successful v1.5.61 AMZ no-throttle experiment: an alert plays
  when entering/re-entering a protected ground area, not on aura expiration.
- Zero throttle on actual player buffs for AMZ (145629), Darkness (209426),
  Spirit Link Totem (325174), Power Word: Barrier (81782), and Sanctified
  Ground (289655). Ordinary defensive buffs keep their 0.25s throttle.
- Sound registration only: cast IDs 51052/196718/98008 are not sound targets;
  they remain untouched in the visual tracking catalog.
- The spell checkbox still controls whether its aura sound is registered.
- Does not change native aura containers, centered layout, profiles, timers,
  localization, SharedMedia sound playback or caster-side trackers.
- Verified by Lua/static tests; real WoW behavior for zones other than AMZ
  must still be confirmed in game.


v1.5.63 MAINTENANCE AUDIT (based on 1.5.62)
- Removed an inactive, commented-out icon-snapshot sound engine and its noop
  ScheduleSoundScan() calls. Sounds are handled only in SoundAlerts.lua.
- Removed unused GetContainer() helper and unused Edit Mode capture flag.
- Updated stale implementation comments and outdated spell-tooltip notes.
- NO change to aura groups, centered row, Edit Mode scale, active sound
  registrations/throttles, profile structure, default settings or SavedVariables.
- Live tests required before shipping: compare to the known-good 1.5.62.


v1.5.64 TEST — party-caster audio for Communion / Tranquility
- The recipient sound subscriptions remain unchanged (including zone re-entry).
- Uses C_UnitAuras.AddAuraSound(Added) for party1..party4 and spell IDs 370960 / 740, only when the matching Spells checkboxes are enabled.
- Subscriptions use the same saved opt-ins as the visual caster tracker and are refreshed after group roster changes.
- No cast event reading, no combat-log parsing, no in-combat frame updates.
- Diagnostic: /ie soundstatus now lists recipient and caster subscription counts and refusals.
- IMPORTANT: the party-unit sound registration still needs live verification on Retail 12.1.5.
