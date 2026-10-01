-- Addon
local MOD_NAME = ...;

-- get libs
local LibFroznFunctions = LibStub:GetLibrary("LibFroznFunctions-1.0");

-- TipTac refs
local tt = _G[MOD_NAME];
local configDb, cfg;
local TT_ExtendedConfig;
local TT_CacheForFrames;

-- element registration
local ttStyle = {};

LibFroznFunctions:RegisterForGroupEvents(MOD_NAME, ttStyle, "Style");

-- vars
local lineName = LibFroznFunctions:CreatePushArray();
local lineRealm = LibFroznFunctions:CreatePushArray();
local lineLevel = LibFroznFunctions:CreatePushArray();
local lineInfo = LibFroznFunctions:CreatePushArray();
local lineTargetedBy = LibFroznFunctions:CreatePushArray();

-- String Constants
local TT_LevelMatch = "^"..TOOLTIP_UNIT_LEVEL:gsub("%%[^s ]*s",".+"); -- "Level %s" -> "^Level .+" Was changed to match other localizations properly, used to match: "^"..LEVEL.." .+" -- Doesn't actually match the level line on the russian client! [14.02.24] Doesn't match for Italian client either. [18.07.27] changed the pattern, might match non-english clients now
local TT_LevelMatchPet = TOOLTIP_WILDBATTLEPET_LEVEL_CLASS and ("^"..TOOLTIP_WILDBATTLEPET_LEVEL_CLASS:gsub("%%[^s ]*s",".+")) or "\1NoBattlePetsOnThisClient\1"; -- "Pet Level %s %s" -> "^Pet Level .+ .+". Battle Pets don't exist on WotLK/Ascension, so this global is nil there - fall back to a pattern that can never match instead of crashing.
local TT_Unknown = UNKNOWN; -- "Unknown"
local TT_UnknownObject = UNKNOWNOBJECT; -- "Unknown"
-- FIX: BINDING_HEADER_TARGETING is actually Blizzard's Key Bindings category
-- header, which reads "Targeting Functions" (not just "Targeting" as the
-- original comment assumed) - producing a misleading "Targeting Functions: ..."
-- tooltip line for what is really just "who/what is this unit targeting".
local TT_Targeting = "Targeting";
local TT_TargetedBy = LibFroznFunctions:GetGlobalString("TIPTAC_TARGETED_BY") or "Targeted by"; -- "Targeted by"
local TT_PlayerMap = LibFroznFunctions:GetGlobalString("BRAWL_TOOLTIP_MAP") or "Map"; -- "Map" (Brawler's Guild global, not available in WotLK/Ascension)
local TT_PlayerZone = FRIENDS_LIST_ZONE; -- "Zone: "
local TT_PlayerSubzone = LibFroznFunctions:GetGlobalString("TIPTAC_SUBZONE") or "Subzone"; -- "Subzone"
local TT_MythicPlusDungeonScore = LibFroznFunctions:GetGlobalString("CHALLENGE_COMPLETE_DUNGEON_SCORE") or "Mythic+ Rating: %s"; -- "Mythic+ Rating: %s" (Legion+ global, not available in WotLK/Ascension)
local TT_Mount = LibFroznFunctions:GetGlobalString("RENOWN_REWARD_MOUNT_NAME_FORMAT") or "Mount: %s"; -- "Mount: %s"
local TT_PlayerGuildMemberNote = GUILD .. " " .. LABEL_NOTE; -- "Guild" "Note"
local TT_PlayerGuildOfficerNote = GUILD .. " " .. OFFICER_NOTE_COLON; -- "Guild" "Officer's Note"
local TT_ReactionIcon = {
	[LFF_UNIT_REACTION_INDEX.hostile] = "unit_reaction_hostile",             -- Hostile
	[LFF_UNIT_REACTION_INDEX.caution] = "unit_reaction_caution",             -- Unfriendly
	[LFF_UNIT_REACTION_INDEX.neutral] = "unit_reaction_neutral",             -- Neutral
	[LFF_UNIT_REACTION_INDEX.friendlyPlayer] = "unit_reaction_friendly",     -- Friendly
	[LFF_UNIT_REACTION_INDEX.friendlyPvPPlayer] = "unit_reaction_friendly",  -- Friendly
	[LFF_UNIT_REACTION_INDEX.friendlyNPC] = "unit_reaction_friendly",        -- Friendly
	[LFF_UNIT_REACTION_INDEX.honoredNPC] = "unit_reaction_honored",          -- Honored
	[LFF_UNIT_REACTION_INDEX.reveredNPC] = "unit_reaction_revered",          -- Revered
	[LFF_UNIT_REACTION_INDEX.exaltedNPC] = "unit_reaction_exalted",          -- Exalted
};
local TT_ReactionText = {
	[LFF_UNIT_REACTION_INDEX.tapped] = "Tapped",                            -- no localized string of this
	[LFF_UNIT_REACTION_INDEX.hostile] = FACTION_STANDING_LABEL2,            -- Hostile
	[LFF_UNIT_REACTION_INDEX.caution] = FACTION_STANDING_LABEL3,            -- Unfriendly
	[LFF_UNIT_REACTION_INDEX.neutral] = FACTION_STANDING_LABEL4,            -- Neutral
	[LFF_UNIT_REACTION_INDEX.friendlyPlayer] = FACTION_STANDING_LABEL5,     -- Friendly
	[LFF_UNIT_REACTION_INDEX.friendlyPvPPlayer] = FACTION_STANDING_LABEL5,	-- Friendly
	[LFF_UNIT_REACTION_INDEX.friendlyNPC] = FACTION_STANDING_LABEL5,        -- Friendly
	[LFF_UNIT_REACTION_INDEX.honoredNPC] = FACTION_STANDING_LABEL6,         -- Honored
	[LFF_UNIT_REACTION_INDEX.reveredNPC] = FACTION_STANDING_LABEL7,         -- Revered
	[LFF_UNIT_REACTION_INDEX.exaltedNPC] = FACTION_STANDING_LABEL8,         -- Exalted
	[LFF_UNIT_REACTION_INDEX.dead] = DEAD                                   -- Dead
};
local TT_TipTacDeveloper = LibFroznFunctions:GetGlobalString("TIPTAC_TIPTAC_DEVELOPER") or "Developer of %s"; -- "Developer of %s"

-- colors
local TT_COLOR = {
	text = {
		default = HIGHLIGHT_FONT_COLOR, -- white
		targeting = HIGHLIGHT_FONT_COLOR, -- white
		targetedBy = HIGHLIGHT_FONT_COLOR, -- white
		guildRank = CreateColor(0.8, 0.8, 0.8, 1), -- light+ grey (QUEST_OBJECTIVE_FONT_COLOR)
		unitSpeed = CreateColor(0.8, 0.8, 0.8, 1), -- light+ grey (QUEST_OBJECTIVE_FONT_COLOR)
		mythicPlusPercentMaxCountEnemyForces = LIGHTYELLOW_FONT_COLOR,
		mountName = HIGHLIGHT_FONT_COLOR, -- white
		mountSpeed = LIGHTYELLOW_FONT_COLOR,
		mountSource = LIGHTYELLOW_FONT_COLOR,
		mountLore = LIGHTYELLOW_FONT_COLOR,
		tipTacDeveloper = RED_FONT_COLOR,
		tipTacDeveloperTipTac = EPIC_PURPLE_COLOR
	}
};

--------------------------------------------------------------------------------------------------------
--                                         Style Unit Tooltip                                         --
--------------------------------------------------------------------------------------------------------

-- structure of unit tooltips:
--
-- GameTooltip lines of the player (determined via: UnitIsUnit(unitID, "player")):
--
-- content                                           color                                                                    example
-- ------------------------------------------------  -----------------------------------------------------------------------  ---------------------------------------------------------------------------------------------------
--  1. <name with optional title>                    white (HIGHLIGHT_FONT_COLOR), color based on reaction if PvP is enabled  "Camassea", "Camassea, Hand von A'dal", "Camassea die Ehrfurchtgebietende" or "Chefköchin Camassea"
-- [2. since bc: <guild>]                            white (HIGHLIGHT_FONT_COLOR)                                             "Blood Omen"
-- [3. <reaction, only colorblind mode>]             white (HIGHLIGHT_FONT_COLOR)                                             "Freundlich"
--  4. <level> - <race>, <class> (Spieler)           white (HIGHLIGHT_FONT_COLOR)                                             "Stufe 60 - Nachtelfe, Druidin (Spieler)"
-- [5. since df 10.1.5: [<specialization> ]<class>]  white (HIGHLIGHT_FONT_COLOR)                                             "Gleichgewicht Druidin"
-- [6. <faction>]                                    white (HIGHLIGHT_FONT_COLOR)                                             "Allianz" or "Horde"
-- [7. PvP]                                          white (HIGHLIGHT_FONT_COLOR)
--
-- GameTooltip lines of other player (determined via: UnitIsPlayer(unitID) and not UnitIsUnit(unitID, "player")):
--
-- content                                           color                                                                    example
-- ------------------------------------------------  -----------------------------------------------------------------------  ------------------------------------------
--  1. <name with optional title>[-<realm>]          white (HIGHLIGHT_FONT_COLOR), color based on reaction if PvP is enabled  "Zoodirektorin Silvette-Alleria"
-- [2. since bc: <guild>[-<realm>]]                  white (HIGHLIGHT_FONT_COLOR)                                             "Die teuflischen Engel-Alleria"
-- [3. <reaction, only colorblind mode>]             white (HIGHLIGHT_FONT_COLOR)                                             "Freundlich"
--  4. <level> - <race>, <class> (Spieler)           white (HIGHLIGHT_FONT_COLOR)                                             "Stufe 70 - Leerenelfe, Jägerin (Spieler)"
-- [5. since df 10.1.5: [<specialization> ]<class>]  white (HIGHLIGHT_FONT_COLOR)                                             "Verwüstung Dämonenjäger" or "Druidin"
-- [6. <faction>]                                    white (HIGHLIGHT_FONT_COLOR)                                             "Allianz" or "Horde"
-- [7. PvP]                                          white (HIGHLIGHT_FONT_COLOR)
--
-- GameTooltip lines of NPC (determined via: not UnitIsPlayer(unitID) and not UnitPlayerControlled(unitID) and not UnitIsBattlePet(unitID)):
--
-- content                                color                         example
-- -------------------------------------  ----------------------------  ----------------------------------------------
--  1. <name>                             color based on reaction       "Melris Malagan" or "Stadtwache von Sturmwind" or "Versuchter Unterwerfer" or "Beckenvulpin"
-- [2. <reaction, only colorblind mode>]  white (HIGHLIGHT_FONT_COLOR)  "Ehrfürchtig" or "Neutral"
-- [3. <title>]                           white (HIGHLIGHT_FONT_COLOR)  "Hauptmann der Wache"
--  4. <level>                            white (HIGHLIGHT_FONT_COLOR)  "Stufe 70" or "Stufe 30 (Elite)"
--  5. <faction or creature type>         white (HIGHLIGHT_FONT_COLOR)  "Sturmwind" or "Entartung" or "Humanoid" or "Wildtier". currently unknown if creature type replaces the faction or belongs to a separate line.
-- [6. PvP]                               white (HIGHLIGHT_FONT_COLOR)
--
-- GameTooltip lines of pet (determined via: not UnitIsPlayer(unitID) and UnitPlayerControlled(unitID)):
--
-- content                                                                                        color                                                                    example
-- ---------------------------------------------------------------------------------------------  -----------------------------------------------------------------------  ------------------------------------------
--  1. <name>                                                                                     white (HIGHLIGHT_FONT_COLOR), color based on reaction if PvP is enabled  "Grimkresh" or "Wildwichtel"
-- [2. <reaction, only colorblind mode>]                                                          white (HIGHLIGHT_FONT_COLOR)                                             "Freundlich"
--  3. <"Diener von" or "Wächter von" or "Begleiter von"> <name of controlling player>[-<realm>]  white (HIGHLIGHT_FONT_COLOR)                                             "Diener von Eliyanna-Alleria" or "Wächter von Nijra-Alleria"
--  4. <level>                                                                                    white (HIGHLIGHT_FONT_COLOR)                                             "Stufe 69"
-- [5. PvP]                                                                                       white (HIGHLIGHT_FONT_COLOR)
--
-- GameTooltip lines of battle pet (determined via: UnitIsBattlePetCompanion(unitID)):
--
-- content                                                  color                         example
-- -------------------------------------------------------  ----------------------------  ------------------------------------------
--  1. <name>                                               color based on quality        "Schössling von Teldrassil"
-- [2. <reaction, only colorblind mode>]                    white (HIGHLIGHT_FONT_COLOR)  "Freundlich"
--  3. Gefährte von <name of controlling player>[-<realm>]  white (HIGHLIGHT_FONT_COLOR)  "Gefährte von Camassea"
--  4. <level>, <type>                                      white (HIGHLIGHT_FONT_COLOR)  "Haustierstufe 1, Elementar"
--
-- GameTooltip lines of wild/tameable battle pet (determined via: UnitIsWildBattlePet(unitID)):
--
-- content                                color                         example
-- -------------------------------------  ----------------------------  ------------------------------------------
--  1. <name>                             color based on reaction       "Kaninchen"
-- [2. <reaction, only colorblind mode>]  white (HIGHLIGHT_FONT_COLOR)  "Neutral"
--  3. <level>, <type>                    white (HIGHLIGHT_FONT_COLOR)  "Haustierstufe 1, Kleintier"
--

-- remove unwanted lines from tip, such as "Alliance", "Horde", "PvP" and "Shadow Priest".
function ttStyle:RemoveUnwantedLinesFromTip(tip, unitRecord)
	local creatureFamily = UnitCreatureFamily(unitRecord.id);
	local creatureType = UnitCreatureType(unitRecord.id);
	
	local hideCreatureTypeIfNoCreatureFamily = ((not unitRecord.isPlayer) or (unitRecord.isWildBattlePet)) and
		(not LibFroznFunctions:IsSecretValue(creatureFamily)) and (not creatureFamily) and
		(not LibFroznFunctions:IsSecretValue(creatureType)) and (creatureType);
	local hideSpecializationAndClassText = (cfg.hideSpecializationAndClassText) and (unitRecord.isPlayer) and (LibFroznFunctions.hasWoWFlavor.specializationAndClassTextInPlayerUnitTip) and (unitRecord.className);
	local hideRightClickForFrameSettingsTextInUnitTip = (cfg.hideRightClickForFrameSettingsTextInUnitTip) and (LibFroznFunctions.hasWoWFlavor.rightClickForFrameSettingsTextInUnitTip) and (UNIT_POPUP_RIGHT_CLICK);
	
	local specNames = LibFroznFunctions:CreatePushArray();
	
	if (hideSpecializationAndClassText) then
		local specCount = C_SpecializationInfo.GetNumSpecializationsForClassID(unitRecord.classID);
		
		for i = 1, specCount do
			local specID, specName = GetSpecializationInfoForClassID(unitRecord.classID, i, unitRecord.sex);
			
			specNames:Push(specName);
		end
	end
	
	for i = 2, tip:NumLines() do
		local gttLine = _G["GameTooltipTextLeft" .. i];
		local gttLineText = gttLine:GetText();
		
		if (not LibFroznFunctions:IsSecretValue(gttLineText)) and (type(gttLineText) == "string") then
			local isGttLineTextUnitPopupRightClick = (hideRightClickForFrameSettingsTextInUnitTip) and (gttLineText == UNIT_POPUP_RIGHT_CLICK);
			
			if (isGttLineTextUnitPopupRightClick) or
					((gttLineText == FACTION_ALLIANCE) or (gttLineText == FACTION_HORDE) or (gttLineText == FACTION_NEUTRAL)) or
					(cfg.hidePvpText) and (gttLineText == PVP_ENABLED) or
					(hideCreatureTypeIfNoCreatureFamily) and (gttLineText == creatureType) or
					(hideSpecializationAndClassText) and ((gttLineText == unitRecord.className) or (specNames:Contains(gttLineText:match("^(.+) " .. unitRecord.className .. "$")))) then
				
				gttLine:SetText(nil);
				
				if (isGttLineTextUnitPopupRightClick) and (i > 1) then
					_G["GameTooltipTextLeft" .. (i - 1)]:SetText(nil);
				end
			end
		end
	end
end

-- Add target
local function AddTarget(lineList,target,targetName)
	local isPlayerTarget = UnitIsUnit("player", target);
	if (not LibFroznFunctions:IsSecretValue(isPlayerTarget)) and (isPlayerTarget) then
		lineList:Push(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(cfg.targetYouText));
	else
		local targetReactionColor = CreateColor(unpack(cfg["colorReactText"..LibFroznFunctions:GetUnitReactionIndex(target)]));
		lineList:Push(targetReactionColor:WrapTextInColorCode("["));
		if (UnitIsPlayer(target)) then
			local targetClassID = select(3, UnitClass(target));
			local targetClassColor = LibFroznFunctions:GetClassColor(targetClassID, nil, cfg.enableCustomClassColors and TT_ExtendedConfig.customClassColors or nil) or TT_COLOR.text.targeting;
			lineList:Push(targetClassColor:WrapTextInColorCode(targetName));
		else
			lineList:Push(targetReactionColor:WrapTextInColorCode(targetName));
		end
		lineList:Push(targetReactionColor:WrapTextInColorCode("]"));
	end
end

-- TARGET
function ttStyle:GenerateTargetLines(unitRecord, method)
	local target = unitRecord.id .."target";
	local targetName = UnitName(target);
	if (not LibFroznFunctions:IsSecretValue(targetName)) and (targetName) and (targetName ~= TT_UnknownObject and targetName ~= "" or UnitExists(target)) then
		if (method == "afterName") then
			lineName:Push(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(" : "));
			AddTarget(lineName,target,targetName);
		elseif (method == "belowNameRealm") then
			if (lineRealm:GetCount() > 0) then
				lineRealm:Push("\n");
			end
			lineRealm:Push("  ");
			AddTarget(lineRealm,target,targetName);
		else
			if (lineInfo:GetCount() > 0) then
				lineInfo:Push("\n");
			end
			lineInfo:Push("|cffffd100");
			lineInfo:Push(TT_Targeting);
			lineInfo:Push(": ");
			AddTarget(lineInfo,target,targetName);
		end
	end
end

-- TARGETTED BY
function ttStyle:GenerateTargetedByLines(unitRecord)
	local numUnits, inGroup, inRaid, nameplates;
	
	local numGroup = GetNumGroupMembers();
	if (numGroup) and (numGroup >= 1) then
		numUnits = numGroup;
		inGroup = true;
		inRaid = IsInRaid();
	else
		nameplates = C_NamePlate.GetNamePlates();
		numUnits = #nameplates;
		inGroup = false;
	end
	
	for i = 1, numUnits do
		local unit = inGroup and (inRaid and "raid"..i or "party"..i) or (nameplates[i].namePlateUnitToken or "nameplate"..i);
		local unitTargettingUnit = UnitIsUnit(unit.."target", unitRecord.id);
		
		if (not LibFroznFunctions:IsSecretValue(unitTargettingUnit)) and (unitTargettingUnit) then
			local isPlayerUnit = UnitIsUnit(unit, "player");
			
			if (not LibFroznFunctions:IsSecretValue(isPlayerUnit)) and (not isPlayerUnit) then
				local unitName = UnitName(unit);
				
				if (UnitIsPlayer(unit)) then
					local unitClassID = select(3, UnitClass(unit));
					local unitClassColor = LibFroznFunctions:GetClassColor(unitClassID, nil, cfg.enableCustomClassColors and TT_ExtendedConfig.customClassColors or nil) or TT_COLOR.text.targetedBy;
					lineTargetedBy:Push(unitClassColor:WrapTextInColorCode(unitName));
				else
					local unitReactionColor = CreateColor(unpack(cfg["colorReactText"..LibFroznFunctions:GetUnitReactionIndex(unit)]));
					lineTargetedBy:Push(unitReactionColor:WrapTextInColorCode(unitName));
				end
			end
		end
	end
end

-- highlight TipTac developer
function ttStyle:HighlightTipTacDeveloper(tip, currentDisplayParams, unitRecord, first)
	-- no highlighting of TipTac developer
	if (not cfg.highlightTipTacDeveloper) then
		return;
	end
	
	-- no TipTac developer
	if (not unitRecord.isTipTacDeveloper) then
		return;
	end
	
	-- set top/bottom overlay, only necessary when the tip is first displayed.
	if (first) then
		local style = { -- top overlay from GAME_TOOLTIP_BACKDROP_STYLE_RUNEFORGE_LEGENDARY and bottom overlay from GAME_TOOLTIP_BACKDROP_STYLE_AZERITE_ITEM, see "GameTooltip.lua"
			-- overlayAtlasTop = "AzeriteTooltip-Topper", -- available in DF, but not available in WotLKC
			overlayTextureTop = "Interface\\AddOns\\" .. MOD_NAME .. "\\media\\AzeriteTooltip",
			overlayTextureTopWidth = 95,
			overlayTextureTopHeight = 27,
			overlayTextureTopLeftTexel = 0.0078125,
			overlayTextureTopRightTexel = 0.75,
			overlayTextureTopTopTexel = 0.2265625,
			overlayTextureTopBottomTexel = 0.4375,
			
			overlayAtlasTopScale = 0.75,
			overlayAtlasTopYOffset = 1 - ((cfg.enableBackdrop and TT_ExtendedConfig.tipBackdrop.insets.top or 0) + TT_ExtendedConfig.tipPaddingForGameTooltip.offset),
			
			-- overlayAtlasBottom = "AzeriteTooltip-Bottom", -- available in DF, but not available in WotLKC
			overlayTextureBottom = "Interface\\AddOns\\" .. MOD_NAME .. "\\media\\AzeriteTooltip",
			overlayTextureBottomWidth = 43,
			overlayTextureBottomHeight = 11,
			overlayTextureBottomLeftTexel = 0.539062,
			overlayTextureBottomRightTexel = 0.875,
			overlayTextureBottomTopTexel = 0.453125,
			overlayTextureBottomBottomTexel = 0.539062,
			
			overlayAtlasBottomYOffset = 2 + ((cfg.enableBackdrop and TT_ExtendedConfig.tipBackdrop.insets.bottom or 0) + TT_ExtendedConfig.tipPaddingForGameTooltip.offset)
		};
		
		if (tip.TopOverlay) then
			local isTopOverlayShown = tip.TopOverlay:IsShown();
		
			if (style) and (style.overlayTextureTop) and (not isTopOverlayShown) then -- part from SharedTooltip_SetBackdropStyle() only for top overlay
				-- tip.TopOverlay:SetAtlas(style.overlayAtlasTop, true); -- available in DF, but not available in WotLKC
				tip.TopOverlay:SetTexture(style.overlayTextureTop);
				tip.TopOverlay:SetSize(style.overlayTextureTopWidth, style.overlayTextureTopHeight);
				tip.TopOverlay:SetTexCoord(style.overlayTextureTopLeftTexel, style.overlayTextureTopRightTexel, style.overlayTextureTopTopTexel, style.overlayTextureTopBottomTexel);
				
				tip.TopOverlay:SetScale(style.overlayAtlasTopScale or 1.0);
				tip.TopOverlay:SetPoint("CENTER", tip, "TOP", style.overlayAtlasTopXOffset or 0, style.overlayAtlasTopYOffset or 0);
				tip.TopOverlay:Show();
				
				currentDisplayParams.isSetTopOverlayToHighlightTipTacDeveloper = true;
			end
		end
		
		if (tip.BottomOverlay) then
			local isBottomOverlayShown = tip.BottomOverlay:IsShown();
			
			if (style) and (style.overlayTextureBottom) and (not isBottomOverlayShown) then -- part from SharedTooltip_SetBackdropStyle() only for bottom overlay
				-- tip.BottomOverlay:SetAtlas(style.overlayAtlasBottom, true); -- available in DF, but not available in WotLKC
				tip.BottomOverlay:SetTexture(style.overlayTextureBottom);
				tip.BottomOverlay:SetSize(style.overlayTextureBottomWidth, style.overlayTextureBottomHeight);
				tip.BottomOverlay:SetTexCoord(style.overlayTextureBottomLeftTexel, style.overlayTextureBottomRightTexel, style.overlayTextureBottomTopTexel, style.overlayTextureBottomBottomTexel);
				
				tip.BottomOverlay:SetScale(style.overlayAtlasBottomScale or 1.0);
				tip.BottomOverlay:SetPoint("CENTER", tip, "BOTTOM", style.overlayAtlasBottomXOffset or 0, style.overlayAtlasBottomYOffset or 0);
				tip.BottomOverlay:Show();
				
				currentDisplayParams.isSetBottomOverlayToHighlightTipTacDeveloper = true;
			end
		end
	end
	
	-- add text to level
	-- local tipTacDeveloperIcon = CreateAtlasMarkup("UI-QuestPoiLegendary-QuestBang"); -- available in DF, but not available in WotLKC
	local tipTacDeveloperIcon = CreateTextureMarkup("Interface\\AddOns\\" .. MOD_NAME .. "\\media\\QuestLegendaryMapIcons", 256, 128, nil, nil, 0.26953125, 0.37890625, 0.0390625, 0.2421875);
	local tipTacDeveloperText = (tipTacDeveloperIcon .. " " .. TT_TipTacDeveloper .. " " .. tipTacDeveloperIcon);
	local modNameText = TT_COLOR.text.tipTacDeveloperTipTac:WrapTextInColorCode(MOD_NAME);
	
	lineLevel:Push(TT_COLOR.text.tipTacDeveloper:WrapTextInColorCode(tipTacDeveloperText:format(modNameText)));
	lineLevel:Push("\n");
end

-- PLAYER Styling
function ttStyle:GeneratePlayerLines(tip, currentDisplayParams, unitRecord, first)
	-- gender
	if (cfg.showPlayerGender) then
		local sex = unitRecord.sex;
		if (sex == 2) or (sex == 3) then
			lineLevel:Push(" ");
			lineLevel:Push(CreateColor(unpack(cfg.colorRace)):WrapTextInColorCode(sex == 3 and FEMALE or MALE));
		end
	end
	-- race
	local race = UnitRace(unitRecord.id) or TT_Unknown;
	lineLevel:Push(" ");
	lineLevel:Push(CreateColor(unpack(cfg.colorRace)):WrapTextInColorCode(race));
	-- class (or specialization, if the player has one selected - e.g. shows
	-- "Shadow Hunter" instead of "Witch Doctor" for a Witch Doctor who's
	-- spent talent points into that tree). Same class color either way.
	local classColor = LibFroznFunctions:GetClassColor(unitRecord.classID, 5, cfg.enableCustomClassColors and TT_ExtendedConfig.customClassColors or nil);
	lineLevel:Push(" ");

	local classOrSpecText = unitRecord.className or TT_Unknown;

	if (cfg.showSpecInsteadOfClass) then
		local unitLevel = UnitLevel(unitRecord.id);

		if (unitLevel == -1) or (unitLevel >= 10) then
			-- FIX: try our own working level-10-passive detection first (see
			-- TT_BuildCache and the /ttbuilddump-and-friends diagnostics
			-- further down this file) - the classic talent-tab lookup below
			-- never finds anything on this classless server (GetNumTalentTabs()
			-- returns 0 here, confirmed via /ttspecdbg), so it's kept only as
			-- a harmless fallback.
			local cachedBuild = TT_BuildCache and TT_BuildCache[UnitGUID(unitRecord.id)];

			if (cachedBuild) then
				classOrSpecText = cachedBuild;
			else
				-- LibFroznFunctions:InspectUnit() handles the whole async inspect
				-- dance (rate-limited NotifyInspect + INSPECT_READY) and caches
				-- the result - for "player" it resolves immediately/synchronously
				-- (no inspect needed for yourself). If data isn't ready yet, the
				-- callback fires later and refreshes the tip once it arrives -
				-- same pattern used for mount aura descriptions above.
				local unitCacheRecord = LibFroznFunctions:InspectUnit(unitRecord.id, function(_unitCacheRecord)
					if (type(_unitCacheRecord.talents) == "table") and (_unitCacheRecord.talents.name) then
						tt:UpdateUnitAppearanceToTip(tip, true);
					end
				end);

				local talents = unitCacheRecord and unitCacheRecord.talents;

				if (type(talents) == "table") and (talents.name) and (talents.pointsSpent) then
					local maxPointsSpent = 0;

					for _, points in ipairs(talents.pointsSpent) do
						if (points > maxPointsSpent) then
							maxPointsSpent = points;
						end
					end

					-- only substitute if they've actually put points into a tree -
					-- otherwise a fresh level 10 with 0 points everywhere would
					-- show a "spec" they haven't actually chosen yet.
					if (maxPointsSpent > 0) then
						classOrSpecText = talents.name;
					end
				end
			end
		end
	end

	lineLevel:Push(classColor:WrapTextInColorCode(classOrSpecText));
	-- name
	local nameColor = (cfg.colorNameByClass and classColor) or unitRecord.nameColor;
	local name = (cfg.nameType == "marysueprot" and unitRecord.rpName) or (cfg.nameType == "original" and unitRecord.originalName) or (cfg.nameType == "title" and unitRecord.nameWithTitle) or unitRecord.name;
	if (unitRecord.normalizedForeignRealmName) and (cfg.showRealm ~= "none") then
		if (cfg.showRealm == "show") then
			name = name .. " - " .. unitRecord.normalizedForeignRealmName;
		elseif (cfg.showRealm == "showInNewLine") then
			lineRealm:Push(nameColor:WrapTextInColorCode(unitRecord.normalizedForeignRealmName));
		else
			name = name .. " (*)";
		end
	end
	lineName:Push(nameColor:WrapTextInColorCode(name));
	-- dc, afk or dnd
	if (cfg.showStatus) then
		local isConnected = UnitIsConnected(unitRecord.id);
		local isAFK = UnitIsAFK(unitRecord.id);
		local isDND = UnitIsDND(unitRecord.id);
		local status = (not LibFroznFunctions:IsSecretValue(isConnected) and (not isConnected) and " <DC>") or
			(not LibFroznFunctions:IsSecretValue(isAFK) and isAFK and " <AFK>") or
			(not LibFroznFunctions:IsSecretValue(isAFK) and isDND and " <DND>");
		if (status) then
			lineName:Push(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(status));
		end
	end
	-- map, zone and subzone
	if (cfg.showPlayerLocation ~= "none") then
		-- determine map, zone and subzone text
		local mapText, zoneText, subzoneText;
		
		if (unitRecord.map) and (LibFroznFunctions:ExistsInTable(cfg.showPlayerLocation, { "mapAndZoneAndSubzone", "mapAndZone", "map" })) then
			mapText = unitRecord.map;
		end
		
		if (not unitRecord.isSelf) and (cfg.showPlayerLocationOnlyForeignMap) then
			local playerUnitRecord = LibFroznFunctions:GetUnitRecordFromCache("player");
			
			if (playerUnitRecord) and (mapText == playerUnitRecord.map) then
				mapText = nil;
			end
		end
		
		if (unitRecord.zone) and (LibFroznFunctions:ExistsInTable(cfg.showPlayerLocation, { "mapAndZoneAndSubzone", "mapAndZone", "zoneAndSubzone", "zone" })) then
			zoneText = unitRecord.zone;
			
			if (unitRecord.subzone) and (LibFroznFunctions:ExistsInTable(cfg.showPlayerLocation, { "mapAndZoneAndSubzone", "zoneAndSubzone" })) then
				subzoneText = unitRecord.subzone;
			end
		end
		
		-- add map, zone and subzone text
		if (mapText) and (mapText ~= zoneText) then
			if (lineInfo:GetCount() > 0) then
				lineInfo:Push("\n");
			end
			
			lineInfo:Push("|cffffd100");
			lineInfo:Push(TT_PlayerMap .. ": " .. TT_COLOR.text.default:WrapTextInColorCode(mapText));
		end
		
		if (zoneText) then
			if (lineInfo:GetCount() > 0) then
				lineInfo:Push("\n");
			end
			
			lineInfo:Push("|cffffd100");
			lineInfo:Push(TT_PlayerZone .. TT_COLOR.text.default:WrapTextInColorCode(zoneText));
			
			if (subzoneText) then
				lineInfo:Push("\n");
				lineInfo:Push(TT_PlayerSubzone .. ": " .. TT_COLOR.text.default:WrapTextInColorCode(subzoneText));
			end
		end
	end
	-- guild
	local guildName, guildRankName, guildRankIndex, guildRealm = GetGuildInfo(unitRecord.id);
	if (guildName) then
		local playerGuildName, playerGuildRankName, playerGuildRankIndex, playerGuildRealm = GetGuildInfo("player");
		local isPlayerGuild = (guildName == playerGuildName) and (guildRealm == playerGuildRealm);
		if (cfg.showGuild) then -- show guild
			local textGuildRealm = "";
			if (guildRealm) and (cfg.showGuildRealm ~= "none") then
				if (cfg.showGuildRealm == "show") then
					textGuildRealm = " - " .. guildRealm;
				elseif (cfg.showGuildRealm == "asterisk") then
					textGuildRealm = " (*)";
				end
			end
			local guildColor = (isPlayerGuild and CreateColor(unpack(cfg.colorSameGuild)) or cfg.colorGuildByReaction and unitRecord.reactionColor or CreateColor(unpack(cfg.colorGuild)));
			local text = guildColor:WrapTextInColorCode(format("<%s>", guildName .. textGuildRealm));
			
			if (cfg.showGuildRank and guildRankName) then
				if (cfg.guildRankFormat == "title") then
					text = text .. " " .. TT_COLOR.text.guildRank:WrapTextInColorCode(format("%s", guildRankName));
				elseif (cfg.guildRankFormat == "both") then
					text = text .. " " .. TT_COLOR.text.guildRank:WrapTextInColorCode(format("%s (%s)", guildRankName, guildRankIndex));
				elseif (cfg.guildRankFormat == "level") then
					text = text .. " " .. TT_COLOR.text.guildRank:WrapTextInColorCode(format("%s", guildRankIndex));
				end
			end
			if (guildRealm) and (cfg.showGuildRealm == "showInNewLine") then
				text = text .. "\n" .. guildColor:WrapTextInColorCode(guildRealm);
			end
			currentDisplayParams.mergeLevelLineWithGuildName = false;
			if (not LibFroznFunctions.hasWoWFlavor.guildNameInPlayerUnitTip) then -- no separate line for guild name. merge with reaction (only color blind mode) or level line.
				if (unitRecord.isColorBlind) then
					GameTooltipTextLeft2:SetText(text .. "\n" .. unitRecord.reactionTextInColorBlindMode);
				else
					GameTooltipTextLeft2:SetText(text);
					currentDisplayParams.mergeLevelLineWithGuildName = true;
				end
			else
				GameTooltipTextLeft2:SetText(text);
				lineLevel.Index = (lineLevel.Index + 1);
			end
		else -- don't show guild
			if (LibFroznFunctions.hasWoWFlavor.guildNameInPlayerUnitTip) then -- separate line for guild name
				GameTooltipTextLeft2:SetText(nil);
				lineLevel.Index = (lineLevel.Index + 1);
			end
		end
		-- show member/officer note for player guild
		if (isPlayerGuild) and ((cfg.showGuildMemberNote) or (cfg.showGuildOfficerNote)) then
			local playerGuildClubMemberInfo = LibFroznFunctions:GetPlayerGuildClubMemberInfo(unitRecord.guid);
			
			if (playerGuildClubMemberInfo) then
				if (cfg.showGuildMemberNote) and (playerGuildClubMemberInfo.memberNote) then
					if (lineInfo:GetCount() > 0) then
						lineInfo:Push("\n");
					end
					lineInfo:Push("|cffffd100");
					lineInfo:Push(TT_PlayerGuildMemberNote);
					lineInfo:Push(": ");
					lineInfo:Push(TT_COLOR.text.default:WrapTextInColorCode(playerGuildClubMemberInfo.memberNote));
				end
				
				if (cfg.showGuildOfficerNote) and (playerGuildClubMemberInfo.officerNote) then
					if (lineInfo:GetCount() > 0) then
						lineInfo:Push("\n");
					end
					lineInfo:Push("|cffffd100");
					lineInfo:Push(TT_PlayerGuildOfficerNote);
					lineInfo:Push(": ");
					lineInfo:Push(TT_COLOR.text.default:WrapTextInColorCode(playerGuildClubMemberInfo.officerNote));
				end
			end
		end
	end
end

-- PET Styling
function ttStyle:GeneratePetLines(tip, currentDisplayParams, unitRecord, first)
	lineName:Push(unitRecord.nameColor:WrapTextInColorCode(unitRecord.name));
	lineLevel:Push(" ");
	local petType = UnitBattlePetType(unitRecord.id) or 5;
	lineLevel:Push(CreateColor(unpack(cfg.colorRace)):WrapTextInColorCode(_G["BATTLE_PET_NAME_"..petType] or TT_Unknown));

	if (unitRecord.isWildBattlePet) then
		local race = UnitCreatureFamily(unitRecord.id) or UnitCreatureType(unitRecord.id) or TT_Unknown;
		lineLevel:Push(" ");
		lineLevel:Push(CreateColor(unpack(cfg.colorRace)):WrapTextInColorCode(race));
	else -- unitRecord.isBattlePetCompanion
		if (unitRecord.petOrBattlePetOrNPCTitle) and (unitRecord.petOrBattlePetOrNPCTitle ~= " ") then -- since WoD, npc title can be a single space character
			lineLevel.Index = currentDisplayParams.petLineLevelIndex or 3;
			local expectedLine = 2 + (unitRecord.isColorBlind and 1 or 0);
			if (lineLevel.Index > expectedLine) then
				local gttLine = unitRecord.isColorBlind and GameTooltipTextLeft3 or GameTooltipTextLeft2;
				gttLine:SetText(unitRecord.nameColor:WrapTextInColorCode(format("<%s>",unitRecord.petOrBattlePetOrNPCTitle)));
			end
		end
	end
end

-- NPC Styling
function ttStyle:GenerateNpcLines(tip, currentDisplayParams, unitRecord, first)
	-- name
	lineName:Push(unitRecord.nameColor:WrapTextInColorCode(unitRecord.name));

	-- guild/title
	if (unitRecord.petOrBattlePetOrNPCTitle) and (unitRecord.petOrBattlePetOrNPCTitle ~= " ") then -- since WoD, npc title can be a single space character
		-- Az: this doesn't work with "Mini Diablo" or "Mini Thor", which has the format: 1) Mini Diablo 2) Lord of Terror 3) Player's Pet 4) Level 1 Non-combat Pet
		local gttLine = unitRecord.isColorBlind and GameTooltipTextLeft3 or GameTooltipTextLeft2;
		gttLine:SetText(unitRecord.nameColor:WrapTextInColorCode(format("<%s>",unitRecord.petOrBattlePetOrNPCTitle)));
		lineLevel.Index = (lineLevel.Index + 1);
	end

	-- race
	local creatureFamily = UnitCreatureFamily(unitRecord.id);
	local creatureType = UnitCreatureType(unitRecord.id);
	local race = creatureFamily or creatureType or TT_Unknown;
	lineLevel:Push(" ");
	lineLevel:Push(CreateColor(unpack(cfg.colorRace)):WrapTextInColorCode(race));
	
	-- creature type
	if (unitRecord.isPet) and (creatureFamily) and (creatureType) then
		lineLevel:Push("\n");
		lineLevel:Push(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(creatureType));
	end
end

-- Modify Tooltip Lines (name + info)
local mapChallengeModeIDToDungeonIndexLookup = {};
local npcIDToEnemyIdxLookup = {};

function ttStyle:ModifyUnitTooltip(tip, currentDisplayParams, unitRecord, first)
	-- obtain unit properties
	unitRecord.reactionColor = CreateColor(unpack(cfg["colorReactText" .. unitRecord.reactionIndex]));
	unitRecord.nameColor = ((not cfg.enableColorName) and CreateColor(GameTooltipTextLeft1:GetTextColor())) or (cfg.colorNameByReaction and unitRecord.reactionColor) or CreateColor(unpack(cfg.colorName));

	-- this is the line index where the level and unit type info is
	lineLevel.Index = 2 + (unitRecord.isColorBlind and UnitIsVisible(unitRecord.id) and 1 or 0);
	
	-- remove unwanted lines from tip
	self:RemoveUnwantedLinesFromTip(tip, unitRecord);
	
	-- highlight TipTac developer
	if (unitRecord.isPlayer) then
		self:HighlightTipTacDeveloper(tip, currentDisplayParams, unitRecord, first);
	end
	
	-- Level + Classification
	lineLevel:Push(((UnitCanAttack(unitRecord.id, "player") or UnitCanAttack("player", unitRecord.id)) and LibFroznFunctions:GetDifficultyColorForUnit(unitRecord.id) or CreateColor(unpack(cfg.colorLevel))):WrapTextInColorCode((cfg["classification_".. (unitRecord.classification or "")] or "%s? "):format(unitRecord.level == -1 and "??" or unitRecord.level)));
	
	-- Reaction Icon
	if (cfg.reactIcon) and (TT_ReactionIcon[unitRecord.reactionIndex]) then
		lineLevel:Push(" " .. LibFroznFunctions:CreateTextureMarkupWithVertexColor("Interface\\AddOns\\" .. MOD_NAME .. "\\media\\" .. TT_ReactionIcon[unitRecord.reactionIndex], 32, 32, nil, nil, 0.219, 0.75, 0.219, 0.75, nil, nil, unitRecord.reactionColor:GetRGB()));
	end
	
	-- Generate Line Modification
	if (unitRecord.isPlayer) then
		self:GeneratePlayerLines(tip, currentDisplayParams, unitRecord, first);
	elseif (cfg.showBattlePetTip) and (unitRecord.isWildBattlePet or unitRecord.isBattlePetCompanion) then
		self:GeneratePetLines(tip, currentDisplayParams, unitRecord, first);
	else
		self:GenerateNpcLines(tip, currentDisplayParams, unitRecord, first);
	end

	-- Current Unit Speed
	if (cfg.showCurrentUnitSpeed) then
		local currentUnitSpeed = GetUnitSpeed(unitRecord.id);
		if (not LibFroznFunctions:IsSecretValue(currentUnitSpeed)) and (currentUnitSpeed > 0) then
			lineLevel:Push(" " .. TT_SafeCreateAtlasMarkup("glueannouncementpopup-arrow"));
			lineLevel:Push(TT_COLOR.text.unitSpeed:WrapTextInColorCode(format("%.0f%%", currentUnitSpeed / BASE_MOVEMENT_SPEED * 100)));
		end
	end
	
	-- Reaction Text
	if (cfg.reactText) then
		local reactTextColor = (cfg.reactColoredText and unitRecord.reactionColor) or CreateColor(unpack(cfg.colorReactText));
		
		lineLevel:Push("\n");
		lineLevel:Push(reactTextColor:WrapTextInColorCode(TT_ReactionText[unitRecord.reactionIndex]));
	end

	-- Faction Text
	if (unitRecord.isPlayer) and (cfg.factionText) then
		local englishFaction, localizedFaction = LibFroznFunctions:GetUnitFactionGroup(unitRecord.id);
		
		if (englishFaction) then
			local factionTextColor = (cfg.enableColorFaction and cfg["colorFaction" .. englishFaction] and CreateColor(unpack(cfg["colorFaction" .. englishFaction]))) or TT_COLOR.text.default;
			
			lineLevel:Push("\n");
			lineLevel:Push(factionTextColor:WrapTextInColorCode(localizedFaction));
		end
	end

	-- Mythic+ Dungeon Score
	if (unitRecord.isPlayer) and (cfg.showMythicPlusDungeonScore) and (C_PlayerInfo) and (C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then
		local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unitRecord.id);
		if (ratingSummary) then
			local mythicPlusDungeonScore = ratingSummary.currentSeasonScore;
			local mythicPlusBestRunLevel;
			if (ratingSummary.runs) then
				for _, ratingMapSummary in ipairs(ratingSummary.runs or {}) do
					if (ratingMapSummary.finishedSuccess) and ((not mythicPlusBestRunLevel) or (mythicPlusBestRunLevel < ratingMapSummary.bestRunLevel)) then
						mythicPlusBestRunLevel = ratingMapSummary.bestRunLevel;
					end
				end
			end
			
			local mythicPlusDungeonScoreText = LibFroznFunctions:CreatePushArray();
			if (cfg.mythicPlusDungeonScoreFormat == "highestSuccessfullRun") then
				if (mythicPlusBestRunLevel) then
					mythicPlusDungeonScoreText:Push(TT_COLOR.text.default:WrapTextInColorCode("+" .. mythicPlusBestRunLevel));
				end
			else
				if (mythicPlusDungeonScore > 0) then
					local mythicPlusDungeonScoreColor = (C_ChallengeMode.GetDungeonScoreRarityColor(mythicPlusDungeonScore) or TT_COLOR.text.default);
					mythicPlusDungeonScoreText:Push(mythicPlusDungeonScoreColor:WrapTextInColorCode(mythicPlusDungeonScore));
				end
			end
			if (mythicPlusDungeonScoreText:GetCount() > 0) then
				if (lineInfo:GetCount() > 0) then
					lineInfo:Push("\n");
				end
				lineInfo:Push("|cffffd100");
				lineInfo:Push(TT_MythicPlusDungeonScore:format(mythicPlusDungeonScoreText:Concat()));
				
				if (cfg.mythicPlusDungeonScoreFormat == "both") and (mythicPlusBestRunLevel) then
					lineInfo:Push(" |cffffff99(+" .. mythicPlusBestRunLevel .. ")|r");
				end
			end
		end
	end

	-- Mythic+ Forces from addon "Mythic Dungeon Tools" (MDT) for NPCs
	if (MDT) and (unitRecord.isNPC) and (cfg.showMythicPlusForcesFromMDT) and (C_MythicPlus.IsMythicPlusActive()) and (UnitCanAttack("player", unitRecord.id)) then
		local mapChallengeModeID = C_ChallengeMode.GetActiveChallengeMapID();
		
		if (mapChallengeModeID) then
			local dungeonIndex = mapChallengeModeIDToDungeonIndexLookup[mapChallengeModeID];
			
			if (not dungeonIndex) and (type(MDT.mapInfo) == "table") then
				for _dungeonIndex, mapInfo in pairs(MDT.mapInfo) do
					if (mapInfo.mapID == mapChallengeModeID) then
						dungeonIndex = _dungeonIndex;
						mapChallengeModeIDToDungeonIndexLookup[mapChallengeModeID] = dungeonIndex;
						break;
					end
				end
			end
			
			if (dungeonIndex) and (type(MDT.dungeonEnemies) == "table") then
				local dungeonEnemies = MDT.dungeonEnemies[dungeonIndex];
				
				if (dungeonEnemies) then
					local enemyIdx = (npcIDToEnemyIdxLookup[mapChallengeModeID] and npcIDToEnemyIdxLookup[mapChallengeModeID][unitRecord.npcID]);
					
					if (not enemyIdx) then
						for _enemyIdx, _dungeonEnemy in pairs(dungeonEnemies) do
							if (_dungeonEnemy.id == unitRecord.npcID) then
								enemyIdx = _enemyIdx;
								
								if (not npcIDToEnemyIdxLookup[mapChallengeModeID]) then
									npcIDToEnemyIdxLookup[mapChallengeModeID] = {};
								end
								
								npcIDToEnemyIdxLookup[mapChallengeModeID][unitRecord.npcID] = enemyIdx;
								
								break;
							end
						end
					end
					
					if (enemyIdx) then
						local dungeonEnemy = MDT.dungeonEnemies[dungeonIndex][enemyIdx];
						
						if (dungeonEnemy) then
							local dungeonTotalCount = (type(MDT.dungeonTotalCount) == "table") and MDT.dungeonTotalCount[dungeonIndex];
							local isTeeming = false;
							local activeKeystoneLevel, activeAffixIDs, wasActiveKeystoneCharged = C_ChallengeMode.GetActiveKeystoneInfo();
							
							if (activeAffixIDs) then
								for _, activeAffixID in ipairs(activeAffixIDs) do
									if (activeAffixID == 5) then -- teeming
										isTeeming = true;
										break;
									end
								end
							end
							
							local countEnemyForces = (isTeeming and dungeonEnemy.teemingCount or dungeonEnemy.count);
							local maxCountEnemyForces = (dungeonTotalCount) and (isTeeming and dungeonTotalCount.teeming or dungeonTotalCount.normal);
							
							if (countEnemyForces) and (MDT.L) and (MDT.L["Forces"]) then
								if (lineInfo:GetCount() > 0) then
									lineInfo:Push("\n");
								end
								
								lineInfo:Push("|cffffd100");
								lineInfo:Push(MDT.L["Forces"] .. " (MDT): " .. TT_COLOR.text.default:WrapTextInColorCode(countEnemyForces));
								
								if (maxCountEnemyForces) and (maxCountEnemyForces > 0) then
									lineInfo:Push(TT_COLOR.text.mythicPlusPercentMaxCountEnemyForces:WrapTextInColorCode(format(" (%.2f%%)", (countEnemyForces / maxCountEnemyForces) * 100)));
								end
							end
						end
					end
				end
			end
		end
	end

	-- Mount
	local lineMount = LibFroznFunctions:CreatePushArray();
	local lineMountLore = LibFroznFunctions:CreatePushArray();
	
	if (unitRecord.isPlayer) and (cfg.showMount) then
		local unitID, filter = unitRecord.id, LFF_AURA_FILTERS.Helpful;
		local index = 0;
		
		LibFroznFunctions:ForEachAura(unitID, filter, nil, function(unitAuraInfo)
			index = index + 1;
			
			local spellID = unitAuraInfo.spellId;
			
			if (spellID) then
				-- FIX: LibFroznFunctions:GetMountFromSpell() can only recognize
				-- mounts that exist in the bundled LFF_SPELLID_TO_MOUNTID_LOOKUP
				-- table, a static dump of RETAIL mount spell data - it has no
				-- idea Ascension's custom mounts even exist. An earlier attempt
				-- here just treated ANY buff with a spellID as "the mount" to
				-- work around that, but that false-positived on ordinary buffs
				-- like "Accursed", "Well Rested" or "Strength" - showing e.g.
				-- "Mount: Well Rested" for a player who was genuinely mounted
				-- on something else entirely.
				--
				-- The reliable, universal signal (confirmed by testing): every
				-- mount's own tooltip description mentions a speed increase
				-- percentage ("Increases speed by 100%", "Increases ground
				-- speed by 60%", etc.) - ordinary buffs don't. Use that as the
				-- real detector for "is this buff actually a mount", and treat
				-- a successful mountID lookup as a bonus signal (and the only
				-- way to enable the collected/source/lore extras) rather than
				-- the sole gate.
				local mountID = LibFroznFunctions:GetMountFromSpell(spellID);

				local auraDescription = LibFroznFunctions:GetAuraDescription(unitID, index, filter, function(_auraDescription)
					if (_auraDescription) and (not LibFroznFunctions:ExistsInTable(_auraDescription, { LFF_AURA_DESCRIPTION.available, LFF_AURA_DESCRIPTION.none })) then
						tt:UpdateUnitAppearanceToTip(tip, true);
					end
				end);

				local mountSpeeds = LibFroznFunctions:CreatePushArray();
				local descriptionAvailable = (auraDescription) and (not LibFroznFunctions:ExistsInTable(auraDescription, { LFF_AURA_DESCRIPTION.available, LFF_AURA_DESCRIPTION.none }));

				-- FIX: matching on any mention of "speed" plus a number was too
				-- loose - buffs/debuffs that just reference movement speed as
				-- part of an unrelated effect (e.g. "Debilitating Venom": "...
				-- slows their movement speed by 40%") got false-positived as
				-- mounts. Every real mount tooltip observed follows the exact
				-- "Increases [ground/flying] speed by X%" template - require
				-- that specific phrasing instead of just "speed" + a number
				-- appearing anywhere in the text.
				--
				-- NOTE: not every custom mount includes the "%" sign (e.g.
				-- "Ironclad War Wolf": "Increases speed by 60." with no
				-- percent symbol at all) - make the "%" optional so both
				-- forms match, and anchor the number extraction to "speed by"
				-- specifically (rather than any "%" anywhere in the text) so
				-- it stays precise either way.
				if (descriptionAvailable) and (auraDescription:find("[Ii]ncreases[^.\n]-speed by %d+%%?")) then
					for mountSpeed in auraDescription:gmatch("[Ss]peed by (%d+)%%?") do
						mountSpeeds:Push(mountSpeed);
					end
				end

				-- FIX: mountID alone was still enough to trigger "looks like a
				-- mount" here, despite the comment above saying it should only be
				-- a bonus signal - that's how "Nightmare" (a custom level-10
				-- passive, unrelated to any mount) got shown as "Mount: Nightmare":
				-- its spellID happens to collide with a real RETAIL mount's
				-- spellID in LFF's static lookup table, and this OR let that
				-- coincidence alone qualify. Require the actual speed-description
				-- match now - mountID stays available below purely as the bonus
				-- signal for collected/source/lore, as originally intended.
				local looksLikeMount = (mountSpeeds:GetCount() > 0);

				if (looksLikeMount) then
					-- determine if mount has already been collected
					local mountText = LibFroznFunctions:CreatePushArray();
					local spacer;
					local mountIsCollected;
					local mountNameAdded = false;
					local mountSourceAdded = false;

					if (mountID) and ((cfg.showMountCollected) or (cfg.showMountSourceIfNotCollected)) then
						mountIsCollected = LibFroznFunctions:IsMountCollected(mountID);
					end

					if (mountID) and (cfg.showMountCollected) then
						if (mountIsCollected) then
							-- mountText:Push(CreateAtlasMarkup("common-icon-checkmark")); -- available in DF, but not available in WotLKC
							mountText:Push(CreateTextureMarkup("Interface\\AddOns\\" .. MOD_NAME .. "\\media\\CommonIcons", 64, 64, 0, 0, 0.000488281, 0.125488, 0.504883, 0.754883));
						else
							-- mountText:Push(CreateAtlasMarkup("common-icon-redx")); -- available in DF, but not available in WotLKC
							mountText:Push(CreateTextureMarkup("Interface\\AddOns\\" .. MOD_NAME .. "\\media\\CommonIcons", 64, 64, 0, 0, 0.126465, 0.251465, 0.504883, 0.754883));
						end
					end

					-- determine mount icon
					if (cfg.showMountIcon) and (unitAuraInfo.icon) then
						mountText:Push(CreateTextureMarkup(unitAuraInfo.icon, 64, 64, 0, 0, 0.07, 0.93, 0.07, 0.93));
					end

					-- determine mount name
					if (cfg.showMountText) and (unitAuraInfo.name) then
						spacer = (mountText:GetCount() > 0) and " " or "";

						mountText:Push(spacer .. TT_COLOR.text.mountName:WrapTextInColorCode(unitAuraInfo.name));

						mountNameAdded = true;
					end

					-- determine mount speed
					if (cfg.showMountSpeed) then
						spacer = (mountText:GetCount() > 0) and " " or "";

						if (mountSpeeds:GetCount() > 0) then
							if (mountNameAdded) then
								mountText:Push(spacer .. TT_COLOR.text.mountSpeed:WrapTextInColorCode("(" .. mountSpeeds:Concat("/") .. "%)"));
							else
								mountText:Push(spacer .. TT_COLOR.text.mountSpeed:WrapTextInColorCode(mountSpeeds:Concat("/") .. "%"));
							end
						end
					end

					-- determine mount source and lore
				-- needs a real mountID (C_MountJournal lookup) - skip gracefully otherwise
				if (mountID) and (C_MountJournal) and ((cfg.showMountSourceIfNotCollected) or (cfg.showMountSource) or (cfg.showMountLore)) then
					local _, description, source = C_MountJournal.GetMountInfoExtraByID(mountID);

					spacer = string.rep(" ", 4);

					if (cfg.showMountSourceIfNotCollected) and (not mountIsCollected) or (cfg.showMountSource) then
						local cleanedSource = "";

						if (type(source) == "string") then
							cleanedSource = strtrim(source);

							if (cleanedSource ~= "") then
								cleanedSource = LibFroznFunctions:RemovePatternFromEndOfTextMultipleTimes(cleanedSource, "|n");
								cleanedSource = LibFroznFunctions:RemoveColorsFromText(cleanedSource);
							end
						end

						if (cleanedSource ~= "") then
							if (mountText:GetCount() > 0) then
								mountText:Push("\n");
							end

							mountText:Push(spacer .. TT_COLOR.text.mountSource:WrapTextInColorCode(cleanedSource:gsub("|n", "|n" .. spacer)));

							mountSourceAdded = true;
						end
					end

					if (cfg.showMountLore) then
						local cleanedDescription = "";

						if (type(description) == "string") then
							cleanedDescription = strtrim(description);

							if (cleanedDescription ~= "") then
								cleanedDescription = LibFroznFunctions:RemovePatternFromEndOfTextMultipleTimes(cleanedDescription, "|n");
								cleanedDescription = LibFroznFunctions:RemoveColorsFromText(cleanedDescription);
							end
						end

						if (cleanedDescription ~= "") then
							local mountLoreText = TT_COLOR.text.mountLore:WrapTextInColorCode(cleanedDescription:gsub("|n", "|n" .. spacer));

							if (mountText:GetCount() > 0) then
								if (mountSourceAdded) then
									lineMountLore:Push("\n" .. spacer .. mountLoreText);
								else
									lineMountLore:Push(spacer .. mountLoreText);
								end
							else
								lineMountLore:Push(TT_Mount:format(mountLoreText));
							end
						end
					end
				end

				-- set mount text
				if (mountText:GetCount() > 0) then
					lineMount:Push(TT_Mount:format(mountText:Concat()));
				end

				return true;
			end
		end
	end, true);
end

	-- Game Mode (Ascension custom: PvE / War / High-Risk) - shows a colored
	-- gradient banner across the top of the tip based on which mode buff the
	-- player has. Uses the existing gradient overlay (layered on top of
	-- whatever background/reaction color is set) instead of the solid
	-- backdrop fill, so it doesn't fight over the single background color
	-- slot and can be shown alongside reaction-based background coloring.
	-- NOTE: "PvE Mode" is confirmed exact text from an in-game tooltip; "War
	-- Mode" and "High-Risk Mode" are best-guess names pending confirmation -
	-- if they don't light up in-game, report the exact buff text shown and
	-- the matching below can be corrected.
	if (unitRecord.isPlayer) and (cfg.modeColoredBackdrop) then
		local unitID, filter = unitRecord.id, LFF_AURA_FILTERS.Helpful;
		local detectedGameModeColor;

		LibFroznFunctions:ForEachAura(unitID, filter, nil, function(unitAuraInfo)
			local name = unitAuraInfo.name;

			if (type(name) == "string") then
				if (name == "PvE Mode") then
					detectedGameModeColor = cfg.colorModeGradientPvE;
					return true;
				elseif (name == "War Mode") then
					detectedGameModeColor = cfg.colorModeGradientWar;
					return true;
				elseif (name:find("High%-?Risk Mode")) then
					detectedGameModeColor = cfg.colorModeGradientHighRisk;
					return true;
				end
			end
		end, true);

		currentDisplayParams.modeGradientColor = detectedGameModeColor;
		tt:SetGradientToTip(tip);
	end

	-- Target
	if (cfg.showTarget ~= "none") then
		self:GenerateTargetLines(unitRecord, cfg.showTarget);
	end

	-- Targeted by
	if (cfg.showTargetedBy) then
		self:GenerateTargetedByLines(unitRecord);
	end

	-- Name Line
	local tipLineNameText = lineName:Concat();
	
	if (lineRealm:GetCount() > 0) then
		tipLineNameText = tipLineNameText .. "\n" .. lineRealm:Concat();
	end
	
	GameTooltipTextLeft1:SetText(tipLineNameText);
	lineName:Clear();
	lineRealm:Clear();

	-- Level Line
	for i = (GameTooltip:NumLines() + 1), lineLevel.Index do
		GameTooltip:AddLine(" ");
	end
	
	local gttLine = _G["GameTooltipTextLeft" .. lineLevel.Index];
	
	-- 8.2 made the default XML template have only 2 lines, so it's possible to get here without the desired line existing (yet?)
	-- Frozn45: The problem showed up in classic. Fixed it with adding the missing lines (see for-loop with GameTooltip:AddLine() above).
	if (gttLine) then
		local tipLineLevelText = TT_COLOR.text.default:WrapTextInColorCode(lineLevel:Concat());
		
		if (currentDisplayParams.mergeLevelLineWithGuildName) then
			local gttLineText = gttLine:GetText();
			
			gttLine:SetText((gttLineText) and (gttLineText ~= " ") and (gttLineText .. "\n" .. tipLineLevelText) or tipLineLevelText);
		else
			gttLine:SetText(tipLineLevelText);
		end
	end

	lineLevel:Clear();
	
	-- Info Line
	if (lineInfo:GetCount() > 0) then
		local tipLineInfoText = lineInfo:Concat();
		
		if (currentDisplayParams.tipLineInfoIndex) then
			_G["GameTooltipTextLeft" .. currentDisplayParams.tipLineInfoIndex]:SetText(tipLineInfoText);
		else
			GameTooltip:AddLine(tipLineInfoText);
			currentDisplayParams.tipLineInfoIndex = GameTooltip:NumLines();
		end
		
		lineInfo:Clear();
	elseif (currentDisplayParams.tipLineInfoIndex) then
		_G["GameTooltipTextLeft" .. currentDisplayParams.tipLineInfoIndex]:SetText(nil);
	end
	
	-- Mount Line
	if (lineMount:GetCount() > 0) then
		local tipLineMountText = lineMount:Concat();
		
		if (currentDisplayParams.tipLineMountIndex) then
			_G["GameTooltipTextLeft" .. currentDisplayParams.tipLineMountIndex]:SetText(tipLineMountText);
		else
			GameTooltip:AddLine(tipLineMountText);
			currentDisplayParams.tipLineMountIndex = GameTooltip:NumLines();
		end
		
		lineMount:Clear();
	elseif (currentDisplayParams.tipLineMountIndex) then
		_G["GameTooltipTextLeft" .. currentDisplayParams.tipLineMountIndex]:SetText(nil);
	end
	
	-- Mount Lore Line
	if (lineMountLore:GetCount() > 0) then
		local tipLineMountLoreText = lineMountLore:Concat();
		
		if (currentDisplayParams.tipLineMountLoreIndex) then
			_G["GameTooltipTextLeft" .. currentDisplayParams.tipLineMountLoreIndex]:SetText(tipLineMountLoreText);
		else
			GameTooltip:AddLine(tipLineMountLoreText, nil, nil, nil, true);
			currentDisplayParams.tipLineMountLoreIndex = GameTooltip:NumLines();
		end
		
		lineMountLore:Clear();
	elseif (currentDisplayParams.tipLineMountLoreIndex) then
		_G["GameTooltipTextLeft" .. currentDisplayParams.tipLineMountLoreIndex]:SetText(nil);
	end
	
	-- Targeted By Line
	if (lineTargetedBy:GetCount() > 0) then
		local tipLineTargetedByText = format(TT_TargetedBy .. " (" .. TT_COLOR.text.default:WrapTextInColorCode(format("%d", lineTargetedBy:GetCount())) .. "): %s", TT_COLOR.text.default:WrapTextInColorCode(lineTargetedBy:Concat(", ")));
		
		if (currentDisplayParams.tipLineTargetedByIndex) then
			_G["GameTooltipTextLeft" .. currentDisplayParams.tipLineTargetedByIndex]:SetText(tipLineTargetedByText);
		else
			GameTooltip:AddLine(tipLineTargetedByText, nil, nil, nil, true);
			currentDisplayParams.tipLineTargetedByIndex = GameTooltip:NumLines();
		end
		
		lineTargetedBy:Clear();
	elseif (currentDisplayParams.tipLineTargetedByIndex) then
		_G["GameTooltipTextLeft" .. currentDisplayParams.tipLineTargetedByIndex]:SetText(nil);
	end
end

--------------------------------------------------------------------------------------------------------
--                                           Element Events                                           --
--------------------------------------------------------------------------------------------------------

function ttStyle:OnConfigLoaded(_TT_CacheForFrames, _configDb, _cfg, _TT_ExtendedConfig)
	TT_CacheForFrames = _TT_CacheForFrames;
	configDb = _configDb;
	cfg = _cfg;
	TT_ExtendedConfig = _TT_ExtendedConfig;
end

function ttStyle:OnTipSetCurrentDisplayParams(TT_CacheForFrames, tip, currentDisplayParams, tipContent)
	-- set current display params for unit appearance
	currentDisplayParams.tipLineInfoIndex = nil;
	currentDisplayParams.tipLineMountIndex = nil;
	currentDisplayParams.tipLineMountLoreIndex = nil;
	currentDisplayParams.tipLineTargetedByIndex = nil;
	currentDisplayParams.petLineLevelIndex = nil;
	currentDisplayParams.mergeLevelLineWithGuildName = nil;
	currentDisplayParams.isSetTopOverlayToHighlightTipTacDeveloper = nil;
	currentDisplayParams.isSetBottomOverlayToHighlightTipTacDeveloper = nil;
end

function ttStyle:OnUnitTipStyle(TT_CacheForFrames, tip, currentDisplayParams, first)
	-- check if modification of unit tip content is enabled
	if (not cfg.showUnitTip) then
		return;
	end
	
	-- check if unit record isn't a secret value
	local unitRecord = currentDisplayParams.unitRecord;
	
	if (unitRecord == LFF_UNIT_RECORD.SecretValue) then
		return;
	end
	
	-- some things only need to be done once initially when the tip is first displayed
	if (first) then
		-- get unit tooltip data because current unit tip may already have been manipulated (e.g. by addon "ElvUI")
		local unitTooltipData = LibFroznFunctions:GetTooltipInfo("GetUnit", unitRecord.id)
		
		unitRecord.isColorBlind = (GetCVar("colorblindMode") == "1");
		unitRecord.originalName = (unitTooltipData) and (unitTooltipData.lines[1]) and (unitTooltipData.lines[1].leftText);
		
		-- find pet, battle pet or NPC title
		if (unitRecord.isPet) or (unitRecord.isBattlePet) or (unitRecord.isNPC) then
			unitRecord.petOrBattlePetOrNPCTitle = nil;
			
			if (unitTooltipData) then
				local unitTooltipDataLine = (unitRecord.isColorBlind and unitTooltipData.lines[3] or unitTooltipData.lines[2]);
				
				if (unitTooltipDataLine) and ((not unitTooltipDataLine.type) or (unitTooltipDataLine.type ~= 0)) then
					unitRecord.petOrBattlePetOrNPCTitle = unitTooltipDataLine.leftText;
				end
			end
			
			if (not LibFroznFunctions:IsSecretValue(unitRecord.petOrBattlePetOrNPCTitle)) and (type(unitRecord.petOrBattlePetOrNPCTitle) == "string") and (unitRecord.petOrBattlePetOrNPCTitle:find(TT_LevelMatch)) then
				unitRecord.petOrBattlePetOrNPCTitle = nil;
			end
		end
		
		-- find battle pet companion level line
		if (unitRecord.isBattlePetCompanion) then
			for i = 2, min(#unitTooltipData.lines, 4) do
				local gttLineText = unitTooltipData.lines[i].leftText;
				
				if (type(gttLineText) == "string") and (gttLineText:find(TT_LevelMatchPet)) then
					currentDisplayParams.petLineLevelIndex = i;
					break;
				end
			end
		end

		-- remember reaction in color blind mode if there is no separate line for guild name
		if (not LibFroznFunctions.hasWoWFlavor.guildNameInPlayerUnitTip) and (unitRecord.isColorBlind) and (unitTooltipData) and (unitTooltipData.lines[2]) then
			unitRecord.reactionTextInColorBlindMode = unitTooltipData.lines[2].leftText;
		end
	end

	self:ModifyUnitTooltip(tip, currentDisplayParams, unitRecord, first);
end

--------------------------------------------------------------------------------
-- DIAGNOSTIC: /ttspecdbg - dumps what GetNumTalentTabs()/GetTalentTabInfo()
-- actually return, for you and (if it's a player) your current target.
--------------------------------------------------------------------------------
-- showSpecInsteadOfClass (see the block above, around line 387) reads
-- talent-tab data through LibFroznFunctions:GetTalents(), which on this
-- WoW version calls the standard, pre-MoP GetNumTalentTabs()/
-- GetTalentTabInfo() API. That's a real, unmodified Blizzard API call - not
-- something this addon invented - so if it comes back empty/blank for a
-- character with an Ascension-only custom class (e.g. Witch Doctor, which
-- doesn't exist in any Blizzard-authored version of WotLK), that's ground
-- truth that Ascension's custom talent trees for those classes aren't
-- exposed through this API at all, and showSpecInsteadOfClass would need an
-- Ascension-specific data source instead of (or in addition to) this one.
-- Checking "self" first is the most reliable test: it needs no inspect/
-- range/faction at all, so if it's ALSO empty for your own character, the
-- API itself is the dead end, not an inspect timing/range issue.
local function DumpTalentTabs(label, isInspect)
	local numTabs = GetNumTalentTabs(isInspect);
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT talent debug]|r " .. label .. ": GetNumTalentTabs(" .. tostring(isInspect) .. ") = " .. tostring(numTabs), 1, 1, 1);

	if (not numTabs) or (numTabs == 0) then
		return;
	end

	local activeGroup = GetActiveTalentGroup and GetActiveTalentGroup(isInspect);

	for tabIndex = 1, numTabs do
		local name, icon, pointsSpent, background, previewPointsSpent, isMaxed = GetTalentTabInfo(tabIndex, isInspect, nil, activeGroup);
		DEFAULT_CHAT_FRAME:AddMessage(("  tab %d: name=%s icon=%s pointsSpent=%s"):format(
			tabIndex, tostring(name), tostring(icon), tostring(pointsSpent)), 1, 1, 1);
	end
end

SLASH_TTSPECDBG1 = "/ttspecdbg";
SlashCmdList["TTSPECDBG"] = function()
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT talent debug]|r --- self ---", 0.2, 1, 0.2);
	DumpTalentTabs("player (self)", false);

	if (UnitExists("target")) and (UnitIsPlayer("target")) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT talent debug]|r --- target: " .. (UnitName("target") or "?") .. " ---", 0.2, 1, 0.2);
		DumpTalentTabs("target (inspect)", true);
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT talent debug]|r (no player target selected - target a player and run /ttspecdbg again to also test inspect)", 1, 1, 1);
	end
end

--------------------------------------------------------------------------------
-- DIAGNOSTIC: /ttbuilddump - dumps the widget tree of Ascension's own custom
-- "Build" inspect tab (AscensionInspectFrame > InspectBuildPanel > ...),
-- found via /framestack while hovering it. GetNumTalentTabs()/
-- GetTalentTabInfo() come back empty on this classless server (confirmed via
-- /ttspecdbg above) for both self and inspected targets, so a real
-- replacement has to read this custom panel's own frames/fontstrings/
-- textures directly instead - this dumps exactly what's there (frame names,
-- text, textures) so the actual reader can be written against real data
-- instead of guesses.
--------------------------------------------------------------------------------
local function AppendFrameRegions(lines, frame, indent)
	if (not frame) or (not frame.GetRegions) then return; end

	local regions = { frame:GetRegions() };

	for _, region in ipairs(regions) do
		local objType = region.GetObjectType and region:GetObjectType();

		if (objType == "FontString") then
			local text = region.GetText and region:GetText();
			if (text) and (text ~= "") then
				table.insert(lines, indent .. "  [FontString] " .. tostring(text));
			end
		elseif (objType == "Texture") then
			local tex = region.GetTexture and region:GetTexture();
			if (tex) then
				table.insert(lines, indent .. "  [Texture] " .. tostring(tex));
			end
		end
	end
end

-- shows a copyable, selectable text window - same pattern as
-- zzz_pfQuestFix's /pfmapdebug window, since chat-frame output can't be
-- multi-line-selected/copied easily.
local function ShowBuildDumpWindow(text)
	local frame = _G.ttBuildDumpFrame;
	if not frame then
		frame = CreateFrame("Frame", "ttBuildDumpFrame", UIParent);
		frame:SetSize(750, 500);
		frame:SetPoint("CENTER");
		frame:SetMovable(true);
		frame:EnableMouse(true);
		frame:RegisterForDrag("LeftButton");
		frame:SetScript("OnDragStart", frame.StartMoving);
		frame:SetScript("OnDragStop", frame.StopMovingOrSizing);
		frame:SetFrameStrata("DIALOG");
		frame:SetClampedToScreen(true);
		if frame.SetBackdrop then
			frame:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true, tileSize = 32, edgeSize = 32,
				insets = { left = 11, right = 12, top = 12, bottom = 11 },
			});
		end

		local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton");
		closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5);
		closeButton:SetScript("OnClick", function() frame:Hide(); end);

		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal");
		title:SetPoint("TOP", frame, "TOP", 0, -16);
		title:SetText("Ascension Inspect Build Panel Dump");

		local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate");
		scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40);
		scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 20);

		local editBox = CreateFrame("EditBox", nil, scrollFrame);
		editBox:SetMultiLine(true);
		editBox:SetFontObject(GameFontHighlightSmall);
		editBox:SetWidth(scrollFrame:GetWidth() - 20);
		editBox:SetHeight(2000);
		editBox:SetTextInsets(8, 8, 8, 8);
		editBox:SetAutoFocus(false);
		editBox:SetMaxLetters(0);
		editBox:EnableMouse(true);
		editBox:SetScript("OnEscapePressed", function() frame:Hide(); end);
		scrollFrame:SetScrollChild(editBox);

		frame.editBox = editBox;
		_G.ttBuildDumpFrame = frame;
	end

	frame.editBox:SetText(text);
	frame.editBox:SetCursorPosition(0);
	frame.editBox:HighlightText();
	frame.editBox:SetFocus();
	frame:Show();
end

SLASH_TTBUILDDUMP1 = "/ttbuilddump";
SlashCmdList["TTBUILDDUMP"] = function()
	local scrollChild = _G["InspectBuildPanelBuildScrollChild"];

	if (not scrollChild) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT build dump]|r InspectBuildPanelBuildScrollChild not found - open Inspect on a player/NPC and click the \"Build\" tab first, then run /ttbuilddump again.", 1, 0.3, 0.3);
		return;
	end

	local lines = {};

	local buildPanel = _G["InspectBuildPanel"];
	if (buildPanel) then
		table.insert(lines, "--- InspectBuildPanel top-level regions ---");
		AppendFrameRegions(lines, buildPanel, "");
	end

	table.insert(lines, "--- InspectBuildPanelBuildScrollChild children ---");

	local children = { scrollChild:GetChildren() };
	local shownCount = 0;

	for i, child in ipairs(children) do
		if (child.IsShown) and (child:IsShown()) then
			shownCount = shownCount + 1;
			local name = child.GetName and child:GetName() or ("child#" .. i);
			table.insert(lines, "  " .. name);
			AppendFrameRegions(lines, child, "  ");

			-- one level of grandchildren, in case name/rank/icon live on a
			-- sub-frame rather than directly on the row
			local grandchildren = child.GetChildren and { child:GetChildren() } or {};
			for gi, gchild in ipairs(grandchildren) do
				local gname = gchild.GetName and gchild:GetName() or ("grandchild#" .. gi);
				table.insert(lines, "    " .. gname);
				AppendFrameRegions(lines, gchild, "    ");
			end
		end
	end

	if (shownCount == 0) then
		table.insert(lines, "  (no shown children found - is the Build tab actually open/populated right now?)");
	end

	ShowBuildDumpWindow(table.concat(lines, "\n"));
	DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT build dump]|r Window opened - select and copy the text.", 0.2, 1, 0.2);
end

--------------------------------------------------------------------------------
-- DIAGNOSTIC: /ttfindpassive - scans whatever is CURRENTLY shown in
-- InspectBuildPanelBuildScrollChild (i.e. the Build tab has to already be
-- open on someone, same prerequisite as /ttbuilddump).
--
-- FIX: the previous version resolved each row's name to a spellID via
-- GetSpellInfo(name), then scanned THAT spell's tooltip - this failed for
-- every single row ("could not resolve a spellID via GetSpellInfo()"),
-- because GetSpellInfo(name) only works for spells this client has already
-- cached (e.g. in your own spellbook) - it can't resolve some other
-- player's unfamiliar custom class ability just from its name string.
--
-- Fix: don't re-derive anything - the row itself (or one of its icon
-- sub-frames) already knows how to show the correct tooltip when you
-- actually hover it in-game (confirmed by the screenshot showing "Level 10
-- Passive" on hover). So just trigger that same OnEnter script
-- programmatically against the real GameTooltip and read back what it
-- shows, instead of trying to reconstruct a spellID ourselves.
--------------------------------------------------------------------------------
local function TryTriggerOnEnter(frame)
	if (not frame) or (not frame.GetScript) then
		return false;
	end

	local onEnterScript = frame:GetScript("OnEnter");
	if (not onEnterScript) then
		return false;
	end

	GameTooltip:Hide();
	local ok = pcall(onEnterScript, frame);
	return (ok) and (GameTooltip:IsShown());
end

SLASH_TTFINDPASSIVE1 = "/ttfindpassive";
SlashCmdList["TTFINDPASSIVE"] = function()
	local scrollChild = _G["InspectBuildPanelBuildScrollChild"];

	if (not scrollChild) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT find passive]|r InspectBuildPanelBuildScrollChild not found - open Inspect on a player and click the \"Build\" tab first, then run /ttfindpassive again.", 1, 0.3, 0.3);
		return;
	end

	local children = { scrollChild:GetChildren() };
	local found = {};

	-- DEBUG: a previous run reported "Nothing at all came back", which can
	-- only mean every child failed either the IsShown() check or the
	-- FontString-name scan - count each stage separately so we can actually
	-- see which one, instead of guessing again.
	local totalChildren = #children;
	local shownChildren = 0;
	local namedChildren = 0;

	for _, child in ipairs(children) do
		if (child.IsShown) and (child:IsShown()) then
			shownChildren = shownChildren + 1;

			-- find the row's FontString (name) among its own regions
			local name;
			local regions = { child:GetRegions() };
			for _, region in ipairs(regions) do
				if (region.GetObjectType) and (region:GetObjectType() == "FontString") then
					local text = region.GetText and region:GetText();
					if (text) and (text ~= "") then
						name = text;
						break;
					end
				end
			end

			if (name) then
				namedChildren = namedChildren + 1;
				-- try the row itself, then each of its direct sub-frames
				-- (the tooltip handler commonly lives on an "...Icon" child
				-- rather than the row frame itself)
				local shownTooltip = TryTriggerOnEnter(child);

				if (not shownTooltip) then
					local grandchildren = child.GetChildren and { child:GetChildren() } or {};
					for _, gchild in ipairs(grandchildren) do
						if (TryTriggerOnEnter(gchild)) then
							shownTooltip = true;
							break;
						end
					end
				end

				if (shownTooltip) then
					local level;
					local allLines = {};

					for lineIndex = 1, GameTooltip:NumLines() do
						local lineFontString = _G["GameTooltipTextLeft" .. lineIndex];
						local text = lineFontString and lineFontString:GetText();

						if (text) then
							table.insert(allLines, text);
						end

						-- FIX: was anchored to "^Level", requiring "Level" to
						-- be the literal first character of the line - but
						-- these lines almost certainly carry a leading
						-- |cRRGGBBAA color-code escape sequence baked into
						-- the string itself (GetText() returns the raw
						-- string, codes and all), which pushes "Level" off
						-- position 1. Confirmed directly: a tooltip whose
						-- dumped line text literally read "Level 50 Passive"
						-- still failed this same anchored match. Dropping
						-- the anchor finds it anywhere in the line instead.
						local matchedLevel = text and text:match("Level (%d+) Passive");
						if (matchedLevel) then
							level = matchedLevel;
						end
					end

					-- FIX: previously this silently produced NOTHING when a
					-- tooltip showed but didn't match the level pattern -
					-- always report what was actually seen instead, so a
					-- pattern mismatch is visible instead of invisible.
					if (level) then
						table.insert(found, name .. " -> Level " .. level .. " Passive");
					elseif (#allLines > 0) then
						table.insert(found, name .. " -> tooltip shown, " .. #allLines .. " lines, no \"Level N Passive\" match. Lines: [" .. table.concat(allLines, " | ") .. "]");
					else
						table.insert(found, name .. " -> tooltip shown but GameTooltip:NumLines() was 0");
					end

					GameTooltip:Hide();
				else
					table.insert(found, name .. " -> no OnEnter script produced a tooltip (row and its sub-frames)");
				end
			end
		end
	end

	DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT find passive]|r " .. totalChildren .. " total children, " .. shownChildren .. " shown, " .. namedChildren .. " had a resolvable name.", 0.6, 0.6, 1);

	if (#found == 0) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT find passive]|r Nothing at all came back - see the counts above to see which stage dropped to zero.", 1, 0.3, 0.3);
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT find passive]|r Results:", 0.2, 1, 0.2);
		for _, line in ipairs(found) do
			DEFAULT_CHAT_FRAME:AddMessage("  " .. line, 1, 1, 1);
		end
	end
end;

--------------------------------------------------------------------------------
-- DIAGNOSTIC: /ttautopop <unit> - tests whether the native Build tab's
-- InspectBuildPanelBuildScrollChild populates from NotifyInspect() alone,
-- WITHOUT ever showing the Inspect UI frame.
--
-- FIX: the previous version only listened for INSPECT_READY, and it never
-- fired at all (no "After:" line ever printed) - meaning either this custom
-- classless server's Build system runs on its own event instead of the
-- standard talent-inspect one, or something else entirely is going on.
-- Rather than guess another event name, this now registers for EVERY event
-- (RegisterAllEvents) and prints only the ones whose name contains "INSPECT"
-- or "BUILD", so whatever actually fires gets caught regardless of what
-- it's called. It also does a flat 2-second-later row-count check
-- regardless of any event, in case data shows up without a clean event at
-- all. Stops listening after 10 seconds either way.
--------------------------------------------------------------------------------
local ttAutoPopFrame;

local function CountShownRows()
	local scrollChild = _G["InspectBuildPanelBuildScrollChild"];
	local count = 0;
	if (scrollChild) then
		local children = { scrollChild:GetChildren() };
		for _, child in ipairs(children) do
			if (child.IsShown) and (child:IsShown()) then
				count = count + 1;
			end
		end
	end
	return count, (scrollChild ~= nil);
end

SLASH_TTAUTOPOP1 = "/ttautopop";
SlashCmdList["TTAUTOPOP"] = function(msg)
	local unit = (msg and msg ~= "" and msg) or "target";

	if (not UnitExists(unit)) or (not UnitIsPlayer(unit)) then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT autopop]|r No valid player unit '" .. unit .. "' - target a player (or mouseover one) and run /ttautopop [unit] again.", 1, 0.3, 0.3);
		return;
	end

	local countBefore, panelExistedBefore = CountShownRows();

	DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT autopop]|r Before: InspectBuildPanel " .. (panelExistedBefore and "exists" or "does NOT exist yet") .. ", " .. countBefore .. " shown rows. Calling NotifyInspect('" .. unit .. "') now - do NOT open the Inspect frame. Listening for any INSPECT/BUILD event for 10s...", 0.2, 1, 0.2);

	if (not ttAutoPopFrame) then
		ttAutoPopFrame = CreateFrame("Frame");
	end

	ttAutoPopFrame:UnregisterAllEvents();
	ttAutoPopFrame:RegisterAllEvents();

	local elapsed_total = 0;
	local reportedDelayedCheck = false;

	ttAutoPopFrame:SetScript("OnEvent", function(self, event, ...)
		if (event:upper():find("INSPECT")) or (event:upper():find("BUILD")) then
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT autopop]|r Event fired: " .. event .. " (" .. tostring((...)) .. ")", 0.2, 1, 0.2);

			local countNow = CountShownRows();
			DEFAULT_CHAT_FRAME:AddMessage("  " .. countNow .. " shown rows now (was " .. countBefore .. " before).", 1, 1, 1);
		end
	end);

	ttAutoPopFrame:SetScript("OnUpdate", function(self, elapsed)
		elapsed_total = elapsed_total + elapsed;

		if (not reportedDelayedCheck) and (elapsed_total >= 2) then
			reportedDelayedCheck = true;
			local countNow = CountShownRows();
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT autopop]|r 2s flat check (no event needed): " .. countNow .. " shown rows now (was " .. countBefore .. " before) - " .. (countNow > countBefore and "IT AUTO-POPULATED." or "no change yet."), 0.2, 1, 0.2);
		end

		if (elapsed_total >= 10) then
			self:UnregisterAllEvents();
			self:SetScript("OnUpdate", nil);
			DEFAULT_CHAT_FRAME:AddMessage("|cff33ccff[TT autopop]|r Done listening (10s elapsed).", 0.2, 1, 0.2);
		end
	end);

	NotifyInspect(unit);
end;

--------------------------------------------------------------------------------
-- FEATURE: show a unit's level-10 "build" passive in tooltips instead of
-- their plain class name (cfg.showSpecInsteadOfClass) - this is what all
-- the /ttbuilddump, /ttfindpassive and /ttautopop diagnostics above were
-- for. The classic-era talent-tab lookup this option originally relied on
-- (GeneratePlayerLines, below the tables section) never finds anything on
-- this classless server (GetNumTalentTabs() returns 0 here, confirmed via
-- /ttspecdbg), so this replaces that data source with a working one.
--
-- Mechanism, each piece confirmed via live testing above:
--  1. NotifyInspect is hooked to remember which unit/GUID is currently
--     being inspected, regardless of what UI triggered the inspect.
--  2. on INSPECT_TALENT_READY, repeatedly re-scan (throttled, up to 10s -
--     Details' own code shows this event can fire several times before
--     data settles) whatever is currently shown in
--     InspectBuildPanelBuildScrollChild for the one row whose own tooltip
--     (triggered via its real OnEnter script, not a spellID lookup - that
--     fails for other players' unfamiliar spells) says "Level 10 Passive".
--  3. cache the result by GUID, persisted in TT_BuildCache (SavedVariables)
--     so it survives relogs, and look it up when generating tooltip text.
--
-- IMPORTANT LIMITATION, confirmed conclusively via /ttautopop (started from
-- a genuinely empty Build panel, 0 rows both before AND after 10s of
-- INSPECT_TALENT_READY firing 4 times without the Inspect UI ever being
-- shown): the Build panel only ever gets created/populated when the player
-- manually opens Inspect and clicks the "Build" tab on someone. There is no
-- way to make this automatic for arbitrary units on this client - this only
-- ever shows a build for someone who has actually been inspected that way
-- at some point (this session or a past one, since it's cached).
--------------------------------------------------------------------------------
TT_BuildCache = TT_BuildCache or {}; -- [guid] = "Passive Name", persisted via SavedVariables

-- FIX (confirmed live, cross-contamination bug): originally tracked "who was
-- inspected" via a single shared lastInspectedGUID, updated by hooking
-- NotifyInspect() globally. That's wrong - NotifyInspect() gets called
-- constantly by OTHER features that have nothing to do with the visible
-- native Inspect "Build" tab (TipTacTalents' own AIL/gear hover lookup via
-- LibFroznFunctions:InspectUnit(), Details' ilevel tracker looping
-- party/raid, etc.). Confirmed live: inspecting player A (opening their
-- Build tab) then merely HOVERING player B's tooltip - no manual inspect of
-- B at all - caused B to get A's real detected build, because
-- lastInspectedGUID had already moved on to B (from the incidental
-- background inspect triggered by hovering B's tooltip) by the time the
-- in-flight scan of A's still-open Build tab finished and wrote its result.
--
-- Fix: stop tracking "who was inspected" via a global hook entirely. Read
-- the native Inspect frame's OWN unit reference directly instead
-- (AscensionInspectFrame.unit / InspectFrame.unit - both confirmed real,
-- working fields on this client: Details' core/gears.lua and iLvLSimple
-- already rely on them) at the moment a scan actually succeeds, so a result
-- always gets attributed to whoever the Inspect UI is ACTUALLY showing right
-- then - never to some other unit that happened to be hovered afterward.
local function GetInspectFrameUnit()
	local insp = _G["AscensionInspectFrame"] or _G["InspectFrame"];
	if (insp) and (insp.IsShown) and (insp:IsShown()) and (insp.unit) and (UnitExists(insp.unit)) then
		return insp.unit;
	end
	return nil;
end

local function ScanBuildPanelForLevel10()
	local scrollChild = _G["InspectBuildPanelBuildScrollChild"];
	if (not scrollChild) then
		return nil;
	end

	local children = { scrollChild:GetChildren() };

	for _, child in ipairs(children) do
		if (child.IsShown) and (child:IsShown()) then
			local name;
			local regions = { child:GetRegions() };
			for _, region in ipairs(regions) do
				if (region.GetObjectType) and (region:GetObjectType() == "FontString") then
					local text = region.GetText and region:GetText();
					if (text) and (text ~= "") then
						name = text;
						break;
					end
				end
			end

			if (name) then
				local shownTooltip = TryTriggerOnEnter(child);

				if (not shownTooltip) then
					local grandchildren = child.GetChildren and { child:GetChildren() } or {};
					for _, gchild in ipairs(grandchildren) do
						if (TryTriggerOnEnter(gchild)) then
							shownTooltip = true;
							break;
						end
					end
				end

				if (shownTooltip) then
					local isLevel10 = false;

					for lineIndex = 1, GameTooltip:NumLines() do
						local lineFontString = _G["GameTooltipTextLeft" .. lineIndex];
						local text = lineFontString and lineFontString:GetText();

						if (text) and (text:match("Level 10 Passive")) then
							isLevel10 = true;
							break;
						end
					end

					GameTooltip:Hide();

					if (isLevel10) then
						return name;
					end
				end
			end
		end
	end

	return nil;
end

local buildCaptureFrame = CreateFrame("Frame");
buildCaptureFrame:RegisterEvent("INSPECT_TALENT_READY");

local capturing = false;
local scanAccumulator = 0;
local SCAN_INTERVAL = 1; -- throttle: GameTooltip actually flashes on screen during a scan, don't do it every frame

buildCaptureFrame:SetScript("OnEvent", function(self)
	local unit = GetInspectFrameUnit();
	if (unit) and (not TT_BuildCache[UnitGUID(unit)]) then
		capturing = true;
		scanAccumulator = 0;
	end
end);

buildCaptureFrame:SetScript("OnUpdate", function(self, elapsed)
	if (not capturing) then
		return;
	end

	-- FIX: previously gave up after a fixed 10s from the event firing, even
	-- if the player just hadn't clicked over to the "Build" tab yet within
	-- that window. Keep watching for as long as the Inspect window is
	-- actually open instead, and stop as soon as it closes.
	if (not GetInspectFrameUnit()) then
		capturing = false;
		return;
	end

	scanAccumulator = scanAccumulator + elapsed;

	if (scanAccumulator < SCAN_INTERVAL) then
		return;
	end
	scanAccumulator = 0;

	local found = ScanBuildPanelForLevel10();

	if (found) then
		-- re-derive the unit fresh, right now, rather than trusting anything
		-- captured earlier - ties the result to whoever the Inspect UI is
		-- actually showing at this exact instant (see the cross-contamination
		-- fix note above).
		local currentUnit = GetInspectFrameUnit();

		if (currentUnit) then
			TT_BuildCache[UnitGUID(currentUnit)] = found;
			-- capture finishes asynchronously (up to SCAN_INTERVAL seconds after
			-- the tooltip was already generated with the old text), so force a
			-- refresh of whatever tip is currently showing - same pattern used
			-- for the LibFroznFunctions:InspectUnit() callback above. No-ops
			-- safely if GameTooltip isn't currently showing a unit appearance.
			tt:UpdateUnitAppearanceToTip(GameTooltip, true);
		end

		capturing = false;
	end
end);

-- /ttlink [unit] - show a copyable ability name for the detected build of "unit" (defaults to "target"),
-- to paste into db.ascension.gg's search or the CoA Builder's "Search selected CoA talents" box.
-- NOTE: db.ascension.gg only has stable direct links in the form "?spell=<numeric id>" - we only ever
-- learn the ability's NAME from the tooltip scan, never its id, and neither db.ascension.gg nor the CoA
-- Builder expose a name-based search URL (confirmed by testing both sites) - so we hand back the exact
-- name text to paste, rather than guessing/constructing a link that might be wrong.
StaticPopupDialogs["TT_SHOW_BUILD_LOOKUP"] = {
	text = "Detected build for %s - copy the name below and paste it into db.ascension.gg's search, or the CoA Builder's \"Search selected CoA talents\" box, to look up their spec.",
	button1 = "Close",
	hasEditBox = 1,
	hasWideEditBox = 1,
	showAlert = 1,
	OnShow = function(self, data)
		local editBox = _G[self:GetName().."WideEditBox"];
		editBox:SetText(data.passiveName);
		editBox:SetFocus();
		editBox:HighlightText();
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

SLASH_TTLINK1 = "/ttlink";
SlashCmdList["TTLINK"] = function(msg)
	local unit = (msg and msg ~= "") and msg or "target";
	if (not UnitExists(unit)) then
		print("|cffffd200TipTac:|r /ttlink - no unit \""..unit.."\" - target someone first, or pass a unit id/name.");
		return;
	end

	local guid = UnitGUID(unit);
	local passiveName = guid and TT_BuildCache[guid];
	if (not passiveName) then
		print("|cffffd200TipTac:|r No build detected yet for "..(UnitName(unit) or unit)..". Inspect them and open the native \"Build\" tab once so it can be captured, then try /ttlink again.");
		return;
	end

	StaticPopup_Show("TT_SHOW_BUILD_LOOKUP", UnitName(unit) or unit, nil, {passiveName = passiveName});
end

function ttStyle:OnTipResetCurrentDisplayParams(TT_CacheForFrames, tip, currentDisplayParams)
	-- hide tip's top/bottom overlay currently highlighting TipTac developer
	if (currentDisplayParams.isSetTopOverlayToHighlightTipTacDeveloper) and (tip.TopOverlay) then
		tip.TopOverlay:Hide();
	end
	if (currentDisplayParams.isSetBottomOverlayToHighlightTipTacDeveloper) and (tip.BottomOverlay) then
		tip.BottomOverlay:Hide();
	end
	
	-- reset current display params for unit appearance
	currentDisplayParams.tipLineInfoIndex = nil;
	currentDisplayParams.tipLineMountIndex = nil;
	currentDisplayParams.tipLineMountLoreIndex = nil;
	currentDisplayParams.tipLineTargetedByIndex = nil;
	currentDisplayParams.petLineLevelIndex = nil;
	currentDisplayParams.mergeLevelLineWithGuildName = nil;
	currentDisplayParams.isSetTopOverlayToHighlightTipTacDeveloper = nil;
	currentDisplayParams.isSetBottomOverlayToHighlightTipTacDeveloper = nil;
end
