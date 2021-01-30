local ADDON_NAME, _ = ...

--constants
local EVENT_FRAME = CreateFrame("frame", ADDON_NAME.."EventFrame", UIParent)

do
	do
		local previewMythicPlusLevel = 0
		C_EncounterJournal.SetPreviewMythicPlusLevelOld = C_EncounterJournal.SetPreviewMythicPlusLevel
		function C_EncounterJournal.SetPreviewMythicPlusLevel(level)
			previewMythicPlusLevel = level
			C_EncounterJournal.SetPreviewMythicPlusLevelOld(level)
			if EncounterJournal_UpdateDifficulty then
				EncounterJournal_UpdateDifficulty()
			end
		end
		function C_EncounterJournal.GetPreviewMythicPlusLevel()
			return previewMythicPlusLevel
		end
	end

	local MYTHIC_PLUS_DIFFICULTIES = {2, 3, 4, 6, 7, 10, 12, 15}
	local function getMythicPlusDifficultyString(level)
		local i = 1
		while MYTHIC_PLUS_DIFFICULTIES[i + 1] and MYTHIC_PLUS_DIFFICULTIES[i + 1] <= level do
			i = i + 1
		end
		local baselevel, endLvl = MYTHIC_PLUS_DIFFICULTIES[i], MYTHIC_PLUS_DIFFICULTIES[i + 1] and MYTHIC_PLUS_DIFFICULTIES[i + 1] - 1
		local displayString = "Mythic %d - %d"
		if not endLvl then
			displayString = "Mythic %d+"
		elseif baselevel == endLvl then
			displayString = "Mythic %d"
		end
		return displayString:format(baselevel, endLvl)
	end
	local EJ_DIFFICULTIES =	{
		{ size = "5", prefix = PLAYER_DIFFICULTY1, difficultyID = 1 },
		{ size = "5", prefix = PLAYER_DIFFICULTY2, difficultyID = 2 },
		{ size = "5", prefix = PLAYER_DIFFICULTY6, difficultyID = 23 },
		{ size = "5", prefix = PLAYER_DIFFICULTY_TIMEWALKER, difficultyID = 24 },
		{ size = "25", prefix = PLAYER_DIFFICULTY3, difficultyID = 7 },
		{ size = "10", prefix = PLAYER_DIFFICULTY1, difficultyID = 3 },
		{ size = "10", prefix = PLAYER_DIFFICULTY2, difficultyID = 5 },
		{ size = "25", prefix = PLAYER_DIFFICULTY1, difficultyID = 4 },
		{ size = "25", prefix = PLAYER_DIFFICULTY2, difficultyID = 6 },
		{ prefix = PLAYER_DIFFICULTY3, difficultyID = 17 },
		{ prefix = PLAYER_DIFFICULTY1, difficultyID = 14 },
		{ prefix = PLAYER_DIFFICULTY2, difficultyID = 15 },
		{ prefix = PLAYER_DIFFICULTY6, difficultyID = 16 },
		{ prefix = PLAYER_DIFFICULTY_TIMEWALKER, difficultyID = 33 },
	}
	function EncounterJournal_DifficultyInit_New(self, level)
		--copied from AddOns/Blizzard_EncounterJournal/BlizzardEncounterJournal.lua line 2422-2437 version 8.3
		--EJ_DIFFICULTIES is a local from earlier in that file
		local currDifficulty = EJ_GetDifficulty();
		local info = UIDropDownMenu_CreateInfo();
		for i=1,#EJ_DIFFICULTIES do
			local entry = EJ_DIFFICULTIES[i];
			if EJ_IsValidInstanceDifficulty(entry.difficultyID) then
				info.func = EncounterJournal_SelectDifficulty;
				if (entry.size) then
					info.text = string.format(ENCOUNTER_JOURNAL_DIFF_TEXT, entry.size, entry.prefix);
				else
					info.text = entry.prefix;
				end
				info.arg1 = entry.difficultyID;
				info.checked = currDifficulty == entry.difficultyID
				
				--modification
				if entry.difficultyID == 23 then
					info.checked = currDifficulty == 23 and C_EncounterJournal.GetPreviewMythicPlusLevel() == 0
					info.func = function(self, menuLevel)
						EncounterJournal_SelectDifficulty(self, menuLevel)
						C_EncounterJournal.SetPreviewMythicPlusLevel(0)
					end
				end
				--------------

				UIDropDownMenu_AddButton(info);
			end
		end
		-------------------------------------------------------------------------------------------------------

		if EJ_IsValidInstanceDifficulty(23) then
			local currDiff = EJ_GetDifficulty()
			local info = UIDropDownMenu_CreateInfo()
			for i = 1, #MYTHIC_PLUS_DIFFICULTIES do
				local lvl = MYTHIC_PLUS_DIFFICULTIES[i]
				local endLvl = MYTHIC_PLUS_DIFFICULTIES[i + 1]
				endLvl = endLvl and endLvl - 1 or nil
				info.text = getMythicPlusDifficultyString(lvl)
				info.func = function(self, lvl, text)
					EJ_SetDifficulty(23)
					C_EncounterJournal.SetPreviewMythicPlusLevel(lvl)
					--EncounterJournal.encounter.info.difficulty:SetFormattedText(text)
				end
				info.arg1, info.arg2 = lvl, info.text
				local previewLvl = C_EncounterJournal.GetPreviewMythicPlusLevel()
				info.checked = currDiff == 23 and (lvl <= previewLvl and previewLvl <= (endLvl or math.huge))
				UIDropDownMenu_AddButton(info)
			end
		end
	end

	local USELESS_MYTHIC_PLUS_SLOTS = {
		[INVTYPE_HEAD] = true,
		[INVTYPE_SHOULDER] = true,
		[INVTYPE_CHEST] = true,
		[INVTYPE_CLOAK] = true,
		[""] = true,
	}
	local BOSS_LOOT_BUTTON_HEIGHT = 45
	local INSTANCE_LOOT_BUTTON_HEIGHT = 64

	local function isLootUseful(index)
		if EJ_GetDifficulty() == 23 and C_EncounterJournal.GetPreviewMythicPlusLevel() ~= 0 then
			local itemInfo = (C_EncounterJournal.GetLootInfoByIndexOld or C_EncounterJournal.GetLootInfoByIndex)(index)
			if USELESS_MYTHIC_PLUS_SLOTS[itemInfo.slot] then
				return false
			end
		end
		return true
	end
	local function getNumUsefulLoot()
		local usefulLoot = 0
		for i = 1, EJ_GetNumLoot() do
			if isLootUseful(i) then
				usefulLoot = usefulLoot + 1
			end
		end
		return usefulLoot
	end
	local function getActualIndex(index)
		local numUsefulItems, currIndex = 0, 0
		while numUsefulItems < index do
			currIndex = currIndex + 1
			if isLootUseful(currIndex) then
				numUsefulItems = numUsefulItems + 1
			end
		end
		return currIndex
	end
	local function newEJLootUpdate()
		EncounterJournal_UpdateFilterString();
		local scrollFrame = EncounterJournal.encounter.info.lootScroll;
		local offset = HybridScrollFrame_GetOffset(scrollFrame);
		local items = scrollFrame.buttons;
		local item, index;

		local numLoot = getNumUsefulLoot();
		local buttonSize = BOSS_LOOT_BUTTON_HEIGHT;

		for i = 1,#items do
			item = items[i];
			index = i + offset;
			if index <= numLoot then
				if (EncounterJournal.encounterID) then
					item:SetHeight(BOSS_LOOT_BUTTON_HEIGHT);
					item.boss:Hide();
					item.bossTexture:Hide();
					item.bosslessTexture:Show();
				else
					buttonSize = INSTANCE_LOOT_BUTTON_HEIGHT;
					item:SetHeight(INSTANCE_LOOT_BUTTON_HEIGHT);
					item.boss:Show();
					item.bossTexture:Show();
					item.bosslessTexture:Hide();
				end

				item.index = getActualIndex(index);
				EncounterJournal_SetLootButton(item);
			else
				item:Hide();
			end
		end

		local totalHeight = numLoot * buttonSize;
		HybridScrollFrame_Update(scrollFrame, totalHeight, scrollFrame:GetHeight());
	end

	EVENT_FRAME:RegisterEvent("ADDON_LOADED")
	EVENT_FRAME:HookScript("OnEvent", function(self, event, ...)
		if event == "ADDON_LOADED" and ... == "Blizzard_EncounterJournal" then
			UIDropDownMenu_Initialize(EncounterJournalEncounterFrameInfoDifficultyDD, EncounterJournal_DifficultyInit_New, "MENU")

			EncounterJournal_UpdateDifficulty_Old = EncounterJournal_UpdateDifficulty
			function EncounterJournal_UpdateDifficulty(newDifficultyID)
				EncounterJournal_UpdateDifficulty_Old(newDifficultyID)
				if newDifficultyID == 23 and C_EncounterJournal.GetPreviewMythicPlusLevel() ~= 0 then
					EncounterJournal.encounter.info.difficulty:SetText(getMythicPlusDifficultyString(C_EncounterJournal.GetPreviewMythicPlusLevel()))
				end
			end

			EncounterJournal_LootUpdate_Old = EncounterJournal_LootUpdate
			EncounterJournal_LootUpdate = newEJLootUpdate
			EncounterJournal.encounter.info.lootScroll.update = EncounterJournal_LootUpdate

			C_EncounterJournal.SetPreviewMythicPlusLevel(15)
		end
	end)
end