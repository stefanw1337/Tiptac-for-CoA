-----------------------------------------------------------------------
-- TipTacTalents
--
-- Show player talents/specialization including role and talent/specialization icon and the average item level in the tooltip.
--

-- create addon
local MOD_NAME = ...;
local PARENT_MOD_NAME = "TipTac";
local ttt = CreateFrame("Frame", MOD_NAME, nil, BackdropTemplateMixin and "BackdropTemplate");
ttt:Hide();

-- get libs
local LibFroznFunctions = LibStub:GetLibrary("LibFroznFunctions-1.0");

-- register with TipTac core addon if available
local TipTac = _G[PARENT_MOD_NAME];

if (TipTac) then
	LibFroznFunctions:RegisterForGroupEvents(PARENT_MOD_NAME, ttt, PARENT_MOD_NAME .. " - Talents Module");
end

----------------------------------------------------------------------------------------------------
--                                             Config                                             --
----------------------------------------------------------------------------------------------------

-- config
local configDb, cfg;
local TT_ExtendedConfig;
local TT_CacheForFrames;

-- default config
local TTT_DefaultConfig = {
	t_enable = true,                      -- "main switch", addon does nothing if false
	t_showTalents = true,                 -- show talents
	t_talentOnlyInParty = false,          -- only show talents/AIL for party/raid members
	t_talentDontShowOutOfRange = false,   -- don't show talents/AIL for players out of range
	
	t_showRoleIcon = true,                -- show role icon
	t_showTalentIcon = true,              -- show talent icon
	
	t_showTalentText = true,              -- show talent text
	t_colorTalentTextByClass = true,      -- color specialization text by class color
	t_talentFormat = 1,                   -- talent Format
	
	t_showAverageItemLevel = true,        -- show average item level (AIL)
	t_showGearScore = false,              -- show GearScore
	t_gearScoreAlgorithm =                -- GearScore algorithm
		LibFroznFunctions.hasWoWFlavor.defaultGearScoreAlgorithm,
	t_colorAILAndGSTextByQuality = true   -- color average item level and GearScore text by average quality
};

----------------------------------------------------------------------------------------------------
--                                           Variables                                            --
----------------------------------------------------------------------------------------------------

-- text constants
local TTT_TEXT = {
	talentsPrefix = ((LibFroznFunctions.hasWoWFlavor.specializationAvailable) and SPECIALIZATION or TALENTS), -- MoP: Could be changed from TALENTS (Talents) to SPECIALIZATION (Specialization)
	ailAndGSPrefix = STAT_AVERAGE_ITEM_LEVEL, -- Item Level
	onlyGSPrefix = "GearScore",
	loading = SEARCH_LOADING_TEXT, -- Loading...
	outOfRange = ERR_SPELL_OUT_OF_RANGE:sub(1, -2), -- Out of range.
	none = NONE_KEY, -- None
	-- na = NOT_APPLICABLE:lower() -- N/A
};

-- colors
local TTT_COLOR = {
	text = {
		default = HIGHLIGHT_FONT_COLOR, -- white
		spec = HIGHLIGHT_FONT_COLOR, -- white
		pointsSpent = LIGHTYELLOW_FONT_COLOR,
		ail = HIGHLIGHT_FONT_COLOR, -- white
		inlineGSPrefix = LIGHTYELLOW_FONT_COLOR
	}
};

----------------------------------------------------------------------------------------------------
--                                          Setup Addon                                           --
----------------------------------------------------------------------------------------------------

-- EVENT: addon loaded (one-time-event)
function ttt:ADDON_LOADED(event, addOnName, containsBindings)
	-- not this addon
	if (addOnName ~= MOD_NAME) then
		return;
	end
	
	-- setup config
	self:SetupConfig();
	
	-- apply hooks for inspecting
	self:ApplyHooksForInspecting();
	
	-- remove this event handler as it's not needed anymore
	self:UnregisterEvent(event);
	self[event] = nil;
end

-- register events
ttt:SetScript("OnEvent", function(self, event, ...)
	self[event](self, event, ...);
end);

ttt:RegisterEvent("ADDON_LOADED");

-- setup config
function ttt:SetupConfig()
	-- Use TipTac config if installed
	configDb, cfg = LibFroznFunctions:CreateDbWithLibAceDB("TipTac_Config", TTT_DefaultConfig);
end

----------------------------------------------------------------------------------------------------
--                                         Element Events                                         --
----------------------------------------------------------------------------------------------------

function ttt:OnApplyConfig(_TT_CacheForFrames, _configDb, _cfg, _TT_ExtendedConfig)
	TT_CacheForFrames = _TT_CacheForFrames;
	TT_ExtendedConfig = _TT_ExtendedConfig;
end

----------------------------------------------------------------------------------------------------
--                                           Inspecting                                           --
----------------------------------------------------------------------------------------------------

-- HOOK: GameTooltip's OnTooltipSetUnit -- will schedule a delayed inspect request
local tttTipLineIndexTalents, tttTipLineIndexAILAndGS;

local function GTT_OnTooltipSetUnit(self, ...)
	-- exit if "main switch" isn't enabled
	if (not cfg.t_enable) then
		return;
	end
	
	-- get the unit id -- check the UnitFrame unit if this tip is from a concated unit, such as "targettarget".
	local _, unitID = LibFroznFunctions:GetUnitFromTooltip(self);
	
	if (LibFroznFunctions:IsSecretValue(unitID)) or (not unitID) then
		local mouseFocus = LibFroznFunctions:GetMouseFocus();
		
		unitID = mouseFocus and mouseFocus.GetAttribute and mouseFocus:GetAttribute("unit");
	end
	
	-- no unit id or unit id is a secret value
	if (LibFroznFunctions:IsSecretValue(unitID)) or (not unitID) then
		return;
	end
	
	-- check if only talents/AIL for people in your party/raid should be shown
	if (cfg.t_talentOnlyInParty) and (not UnitInParty(unitID)) and (not UnitInRaid(unitID)) then
		return;
	end
	
	-- invalidate line indexes
	tttTipLineIndexTalents = nil;
	tttTipLineIndexAILAndGS = nil;
	
	-- inspect unit
	local unitCacheRecord = LibFroznFunctions:InspectUnit(unitID, TTT_UpdateTooltip, true);
	
	if (unitCacheRecord) then
		TTT_UpdateTooltip(unitCacheRecord);
	end
end

-- apply hooks for inspecting during event ADDON_LOADED (one-time-function)
function ttt:ApplyHooksForInspecting()
	-- hooks needs to be applied as late as possible during load, as we want to try and be the
	-- last addon to hook GameTooltip's OnTooltipSetUnit so we always have a "completed" tip to work on.
	
	-- HOOK: GameTooltip's OnTooltipSetUnit -- will schedule a delayed inspect request
	LibFroznFunctions:HookScriptOnTooltipSetUnit(GameTooltip, GTT_OnTooltipSetUnit);
	
	-- remove this function as it's not needed anymore
	self.ApplyHooksForInspecting = nil;
end

----------------------------------------------------------------------------------------------------
--                                         Main Functions                                         --
----------------------------------------------------------------------------------------------------

-- update tooltip with the unit cache record
function TTT_UpdateTooltip(unitCacheRecord)
	-- exit if "main switch" isn't enabled
	if (not cfg.t_enable) then
		return;
	end
	
	-- exit if unit from unit cache record doesn't match the current displaying unit
	local _, unitID = LibFroznFunctions:GetUnitFromTooltip(GameTooltip);
	
	if (LibFroznFunctions:IsSecretValue(unitID)) or (not unitID) then
		return;
	end
	
	local unitGUID = UnitGUID(unitID);
	
	if (unitGUID ~= unitCacheRecord.guid) then
		return;
	end
	
	-- update tooltip with the unit cache record
	
	-- talents
	if (cfg.t_showTalents) and (unitCacheRecord.talents) then
		local specText = LibFroznFunctions:CreatePushArray();

		-- FIX: this server's real specialization API doesn't exist here -
		-- GetNumTalentTabs() always returns 0 (confirmed via /ttspecdbg), so the
		-- LibFroznFunctions talent lookup below can never resolve to a real
		-- name/pointsSpent table on this client. TipTac's own build-capture
		-- code (modules/ttStyle.lua) has a working alternative: it scans the
		-- native Inspect "Build" tab for the level-10 passive that defines a
		-- build, and caches it by GUID in TT_BuildCache. Use that here first.
		local cachedBuild = TT_BuildCache and TT_BuildCache[unitGUID];

		if (cachedBuild) then
			if (cfg.t_showRoleIcon) and (unitCacheRecord.talents.role) then
				specText:Push(LibFroznFunctions:CreateMarkupForRoleIcon(unitCacheRecord.talents.role));
			end

			local spacer = (specText:GetCount() > 0) and " " or "";

			if (cfg.t_colorTalentTextByClass) then
				local classColor = LibFroznFunctions:GetClassColor(unitCacheRecord.classID, 5, cfg.enableCustomClassColors and TT_ExtendedConfig.customClassColors or nil);
				specText:Push(spacer .. classColor:WrapTextInColorCode(cachedBuild));
			else
				specText:Push(spacer .. cachedBuild);
			end

		-- talents available but no inspect data
		elseif (unitCacheRecord.talents == LFF_TALENTS.available) then
			if (unitCacheRecord.canInspect) then
				specText:Push(TTT_TEXT.loading);
			else
				-- check if talents/AIL for people out of range shouldn't be shown
				if (not cfg.t_talentDontShowOutOfRange) then
					specText:Push(TTT_TEXT.outOfRange);
				end
			end
		
		-- no talents available
		elseif (unitCacheRecord.talents == LFF_TALENTS.na) then
			specText:Clear();
		
		-- no talents found
		elseif (unitCacheRecord.talents == LFF_TALENTS.none) then
			specText:Push(TTT_TEXT.none);
		
		-- talents found
		else
			local spacer, color;
			local talentFormat = (cfg.t_talentFormat or 1);
			local specNameAdded = false;
			
			if (cfg.t_showRoleIcon) and (unitCacheRecord.talents.role) then
				specText:Push(LibFroznFunctions:CreateMarkupForRoleIcon(unitCacheRecord.talents.role));
			end
			
			if (cfg.t_showTalentIcon) and (unitCacheRecord.talents.iconFileID) then
				spacer = (specText:GetCount() > 0) and " " or "";

				specText:Push(spacer .. LibFroznFunctions:CreateMarkupForClassIcon(unitCacheRecord.talents.iconFileID));
			end
			
			if (cfg.t_showTalentText) and ((talentFormat == 1) or (talentFormat == 2)) and (unitCacheRecord.talents.name) then
				spacer = (specText:GetCount() > 0) and " " or "";

				if (cfg.t_colorTalentTextByClass) then
					local classColor = LibFroznFunctions:GetClassColor(unitCacheRecord.classID, 5, cfg.enableCustomClassColors and TT_ExtendedConfig.customClassColors or nil);
					specText:Push(spacer .. classColor:WrapTextInColorCode(unitCacheRecord.talents.name));
				else
					specText:Push(spacer .. unitCacheRecord.talents.name);
				end
				
				specNameAdded = true;
			end
			
			if (cfg.t_showTalentText) and ((talentFormat == 1) or (talentFormat == 3)) and (unitCacheRecord.talents.pointsSpent) then
				spacer = (specText:GetCount() > 0) and " " or "";
				
				if (specNameAdded) then
					specText:Push(spacer .. TTT_COLOR.text.pointsSpent:WrapTextInColorCode("(" .. table.concat(unitCacheRecord.talents.pointsSpent, "/") .. ")"));
				else
					specText:Push(spacer .. TTT_COLOR.text.pointsSpent:WrapTextInColorCode(table.concat(unitCacheRecord.talents.pointsSpent, "/")));
				end
			end
		end
		
		-- show spec text
		if (specText:GetCount() > 0) then
			local tipLineTextTalents = LibFroznFunctions:FormatText("{prefix}: {specText}", {
				prefix = TTT_TEXT.talentsPrefix,
				specText = TTT_COLOR.text.spec:WrapTextInColorCode(specText:Concat())
			});
			
			if (tttTipLineIndexTalents) then
				_G["GameTooltipTextLeft" .. tttTipLineIndexTalents]:SetText(tipLineTextTalents);
			else
				GameTooltip:AddLine(tipLineTextTalents);
				tttTipLineIndexTalents = GameTooltip:NumLines();
			end
		end
	end
	
	-- average item level and GearScore
	if ((cfg.t_showAverageItemLevel) or (cfg.t_showGearScore)) and (unitCacheRecord.averageItemLevel) then
		local ailAndGSText = LibFroznFunctions:CreatePushArray();
		local useOnlyGSPrefix = false;
		
		-- average item level available or no item data
		if (unitCacheRecord.averageItemLevel == LFF_AVERAGE_ITEM_LEVEL.available) then
			if (unitCacheRecord.canInspect) then
				ailAndGSText:Push(TTT_TEXT.loading);
			else
				-- check if talents/AIL for people out of range shouldn't be shown
				if (not cfg.t_talentDontShowOutOfRange) then
					ailAndGSText:Push(TTT_TEXT.outOfRange);
				end
			end
		
		-- no average item level available
		elseif (unitCacheRecord.averageItemLevel == LFF_AVERAGE_ITEM_LEVEL.na) then
			ailAndGSText:Clear();
		
		-- no average item level found
		elseif (unitCacheRecord.averageItemLevel == LFF_AVERAGE_ITEM_LEVEL.none) then
			ailAndGSText:Push(TTT_TEXT.none);
		
		-- average item level found
		elseif (unitCacheRecord.averageItemLevel) then
			local spacer;
			
			-- average item level
			if (cfg.t_showAverageItemLevel) then
				local averageItemLevel = (unitCacheRecord.averageItemLevel.value > 0) and unitCacheRecord.averageItemLevel.value or "-";
				
				if (cfg.t_colorAILAndGSTextByQuality) then
					ailAndGSText:Push(unitCacheRecord.averageItemLevel.qualityColor:WrapTextInColorCode(averageItemLevel));
				else
					ailAndGSText:Push(averageItemLevel);
				end
			end
			
			-- GearScore
			if (cfg.t_showGearScore) then
				spacer = (ailAndGSText:GetCount() > 0) and ("  " .. TTT_COLOR.text.inlineGSPrefix:WrapTextInColorCode("GS: ")) or "";
				
				if (ailAndGSText:GetCount() == 0) then
					useOnlyGSPrefix = true;
				end
				
				local gearScore;
				
				if (cfg.t_gearScoreAlgorithm == LFF_GEAR_SCORE_ALGORITHM.TacoTip) then -- TacoTip's GearScore algorithm
					gearScore = (unitCacheRecord.averageItemLevel.TacoTipGearScore > 0) and unitCacheRecord.averageItemLevel.TacoTipGearScore or "-";
					
					if (cfg.t_colorAILAndGSTextByQuality) then
						ailAndGSText:Push(spacer .. unitCacheRecord.averageItemLevel.TacoTipGearScoreQualityColor:WrapTextInColorCode(gearScore));
					else
						ailAndGSText:Push(spacer .. gearScore);
					end
				else -- TipTac's GearScore algorithm
					gearScore = (unitCacheRecord.averageItemLevel.TipTacGearScore > 0) and unitCacheRecord.averageItemLevel.TipTacGearScore or "-";
					
					if (cfg.t_colorAILAndGSTextByQuality) then
						ailAndGSText:Push(spacer .. unitCacheRecord.averageItemLevel.TipTacGearScoreQualityColor:WrapTextInColorCode(gearScore));
					else
						ailAndGSText:Push(spacer .. gearScore);
					end
				end
			end
		end
		
		-- show ail and GS text
		if (ailAndGSText:GetCount() > 0) then
			local tipLineTextAverageItemLevel = LibFroznFunctions:FormatText("{prefix}: {averageItemLevelAndGearScore}", {
				prefix = useOnlyGSPrefix and TTT_TEXT.onlyGSPrefix or TTT_TEXT.ailAndGSPrefix,
				averageItemLevelAndGearScore = TTT_COLOR.text.ail:WrapTextInColorCode(ailAndGSText:Concat())
			});
			
			if (tttTipLineIndexAILAndGS) then
				_G["GameTooltipTextLeft" .. tttTipLineIndexAILAndGS]:SetText(tipLineTextAverageItemLevel);
			else
				GameTooltip:AddLine(tipLineTextAverageItemLevel);
				tttTipLineIndexAILAndGS = GameTooltip:NumLines();
			end
		end
	end
	
	-- recalculate size of tip to ensure that it has the correct dimensions
	LibFroznFunctions:RecalculateSizeOfGameTooltip(GameTooltip);
end

----------------------------------------------------------------------------------------------------
--                                       Debug: Spec Scan                                         --
----------------------------------------------------------------------------------------------------

-- Ascension's real specialization API doesn't exist on this client, but the
-- native "Build" inspect window (AscensionInspectFrame, opened by right-click
-- inspecting a target) does show a real spec label. This scans that frame's
-- text so we can find the exact FontString/frame name holding it, in order to
-- read it live for tooltips instead.
local function CollectFontStrings(frame, depth, lines)
	if (not frame) or (depth > 8) then
		return;
	end

	if (frame.GetRegions) then
		local regions = { frame:GetRegions() };

		for _, region in ipairs(regions) do
			if (region) and (region.GetObjectType) and (region:GetObjectType() == "FontString") then
				local text = region:GetText();

				if (text) and (text ~= "") then
					local regionName = region.GetName and region:GetName();

					table.insert(lines, string.rep("  ", depth) .. (regionName or "(unnamed region)") .. " = \"" .. text .. "\"");
				end
			end
		end
	end

	if (frame.GetChildren) then
		local children = { frame:GetChildren() };

		for _, child in ipairs(children) do
			local childName = child.GetName and child:GetName();

			table.insert(lines, string.rep("  ", depth) .. "[frame] " .. (childName or "(unnamed frame)"));

			CollectFontStrings(child, depth + 1, lines);
		end
	end
end

local function ShowSpecDebugWindow(text)
	local f = _G["ttTalentsSpecDebugFrame"];

	if (not f) then
		f = CreateFrame("Frame", "ttTalentsSpecDebugFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate");
		f:SetSize(600, 520);
		f:SetPoint("CENTER");
		f:SetFrameStrata("DIALOG");
		f:SetMovable(true);
		f:EnableMouse(true);
		f:RegisterForDrag("LeftButton");
		f:SetScript("OnDragStart", f.StartMoving);
		f:SetScript("OnDragStop", f.StopMovingOrSizing);
		f:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true, tileSize = 32, edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 }
		});

		local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton");
		closeBtn:SetPoint("TOPRIGHT", -4, -4);

		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
		title:SetPoint("TOP", 0, -16);
		title:SetText("TipTacTalents - Spec Scan Debug (Ctrl+A, Ctrl+C to copy)");
		f.title = title;

		local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate");
		scrollFrame:SetPoint("TOPLEFT", 20, -44);
		scrollFrame:SetPoint("BOTTOMRIGHT", -36, 20);

		local editBox = CreateFrame("EditBox", nil, scrollFrame);
		editBox:SetMultiLine(true);
		editBox:SetFontObject(ChatFontNormal);
		editBox:SetWidth(540);
		editBox:SetAutoFocus(false);
		editBox:SetScript("OnEscapePressed", function() f:Hide(); end);
		scrollFrame:SetScrollChild(editBox);
		f.editBox = editBox;
	end

	f.editBox:SetText(text);
	f.editBox:HighlightText();
	f:Show();
end

SLASH_TIPTACTALENTSDEBUG1 = "/ttt";
SlashCmdList["TIPTACTALENTSDEBUG"] = function(msg)
	msg = (msg or ""):lower();

	if (msg == "specdebug") then
		local lines = {};

		table.insert(lines, "target = " .. tostring(UnitName("target")));
		table.insert(lines, "mouseover = " .. tostring(UnitName("mouseover")));
		table.insert(lines, "");

		local inspectFrame = _G["AscensionInspectFrame"];

		if (not inspectFrame) then
			table.insert(lines, "AscensionInspectFrame not found as a global.");
			table.insert(lines, "");
			table.insert(lines, "Globals containing \"Inspect\":");

			for k, v in pairs(_G) do
				if (type(k) == "string") and (k:find("Inspect")) and (type(v) == "table") and (v.IsObjectType) then
					table.insert(lines, "  " .. k);
				end
			end
		else
			table.insert(lines, "AscensionInspectFrame found. IsShown=" .. tostring(inspectFrame:IsShown()));
			table.insert(lines, "");

			CollectFontStrings(inspectFrame, 0, lines);
		end

		ShowSpecDebugWindow(table.concat(lines, "\n"));
	end
end
