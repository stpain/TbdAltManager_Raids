

local addonName, TbdAltManagerRaids = ...;

local playerUnitToken = "player";

local InstanceTexturePath = [[interface/lfgframe/ui-lfg-background-]]

local EJ_DIFFICULTIES = {
	DifficultyUtil.ID.DungeonNormal,
	DifficultyUtil.ID.DungeonHeroic,
	DifficultyUtil.ID.DungeonMythic,
	DifficultyUtil.ID.DungeonChallenge,
	DifficultyUtil.ID.DungeonTimewalker,
	DifficultyUtil.ID.RaidLFR,
	DifficultyUtil.ID.Raid10Normal,
	DifficultyUtil.ID.Raid10Heroic,
	DifficultyUtil.ID.Raid25Normal,
	DifficultyUtil.ID.Raid25Heroic,
	DifficultyUtil.ID.PrimaryRaidLFR,
	DifficultyUtil.ID.PrimaryRaidNormal,
	DifficultyUtil.ID.PrimaryRaidHeroic,
	DifficultyUtil.ID.PrimaryRaidMythic,
	DifficultyUtil.ID.RaidTimewalker,
	DifficultyUtil.ID.Raid40,
};
local function IsEJDifficulty(difficultyID)
    return tContains(EJ_DIFFICULTIES, difficultyID);
end


TbdAltManagerRaids.CallbackRegistry = CreateFromMixins(CallbackRegistryMixin)
TbdAltManagerRaids.CallbackRegistry:OnLoad()
TbdAltManagerRaids.CallbackRegistry:GenerateCallbackEvents({
    "Character_OnAdded",
    "Character_OnChanged",
    "Character_OnRemoved",
    "DataProvider_OnInitialized",
})




local CharacterDefaults = {
    uid = "",
    instances = {},
    encounterJournal = {},
}


local CharacterDataProvider = CreateFromMixins(DataProviderMixin)

function CharacterDataProvider:InsertCharacter(characterUID)

    local character = self:FindElementDataByPredicate(function(characterData)
        return (characterData.uid == characterUID)
    end)

    if not character then        
        local newCharacter = {}
        for k, v in pairs(CharacterDefaults) do
            newCharacter[k] = v
        end

        newCharacter.uid = characterUID

        self:Insert(newCharacter)
        TbdAltManagerRaids.CallbackRegistry:TriggerEvent("Character_OnAdded")
    end
end

function CharacterDataProvider:FindCharacterByUID(characterUID)
    return self:FindElementDataByPredicate(function(character)
        return (character.uid == characterUID)
    end)
end

function CharacterDataProvider:UpdateDefaultKeys()
    for _, character in self:EnumerateEntireRange() do
        for k, v in pairs(CharacterDefaults) do
            if character[k] == nil then
                character[k] = v;
            end
        end
    end
end




TbdAltManagerRaids.Api = {}

function TbdAltManagerRaids.Api.UpdateCharacterEncounterJournal(character, dungeonEncounterID, difficultyID)
    for _, character in CharacterDataProvider:EnumerateEntireRange() do
        if character.encounterJournal then
            for _, encounter in ipairs(character.encounterJournal) do
                if (encounter.dungeonEncounterID == dungeonEncounterID) and (encounter.difficultyID == difficultyID) then
                    encounter.defeated = true
                    TbdAltManagerRaids.CallbackRegistry:TriggerEvent("Character_OnChanged")
                end
            end
        end
    end
end

function TbdAltManagerRaids.Api.ResetBossDefeatedInfo()

    for _, character in CharacterDataProvider:EnumerateEntireRange() do
        if character.instances then
            for _, instanceInfo in ipairs(character.instances) do

                --this instance has reset so set any boss encounter defeat data to false
                if instanceInfo.resetTime > GetServerTime() then
                    
                    if character.encounterJournal then
                        for _, encounter in ipairs(character.encounterJournal) do
                            if encounter.mapID == instanceInfo.instanceID then
                                encounter.defeated = false
                            end
                        end
                    end
                end
            end
        end
    end
    
end

function TbdAltManagerRaids.Api.GetCharacterLockoutsForInstance(instanceID)
    
    local ret = {}

    for _, character in CharacterDataProvider:EnumerateEntireRange() do
        if character.instances then
            for _, instanceInfo in ipairs(character.instances) do
                if instanceInfo.instanceID == instanceID then
                    table.insert(ret, character.uid)
                end
            end
        end
    end

    return ret;
end

function TbdAltManagerRaids.Api.GetPlayerLockouts()

    local ret = {}
    local numSavedInstances = GetNumSavedInstances()
    if numSavedInstances > 0 then
        for i = 1, numSavedInstances do
            local name, lockoutId, reset, difficultyId, locked, extended, instanceIDMostSig, isRaid, maxPlayers, difficultyName, numEncounters, encounterProgress, extendDisabled, instanceID = GetSavedInstanceInfo(i)

            local resetTime = (GetServerTime() + reset);
            local fileID = GetFileIDFromPath(string.format("%s%s", InstanceTexturePath, name:gsub(" ", ""):lower()))
            local instanceData = {
                name = name,
                lockoutId = lockoutId,
                reset = reset,
                difficulty = difficultyId,
                locked = locked,
                extended = extended,
                instanceIDMostSig = instanceIDMostSig,
                isRaid = isRaid,
                maxPlayers = maxPlayers,
                difficultyName = difficultyName,
                numEncounters = numEncounters,
                encounterProgress = encounterProgress,
                instanceID = instanceID,
                resetTime = resetTime,
                fileID = fileID,
            }

            table.insert(ret, instanceData)
        end
        return ret;
    end
end

function TbdAltManagerRaids.Api.ScrapEncounterJournal()

    --remove these functions to reduce the number of calls during load
    --replace at the end of the function
    local EncounterJournal_LootUpdate_Func = EncounterJournal_LootUpdate
    EncounterJournal_LootUpdate = function() end
    local UpdateDifficultyVisibility_Func = UpdateDifficultyVisibility
    UpdateDifficultyVisibility = function() end
    local EncounterJournal_SetTabEnabled_Func = EncounterJournal_SetTabEnabled
    EncounterJournal_SetTabEnabled = function() end

    --force the raid tab into existance
    EJ_ContentTab_SetEnabled(EncounterJournal.raidsTab, true);

    local ret = {}

    local numExpansionTiers = EJ_GetNumTiers()

    for tier = 1, numExpansionTiers - 1 do

        EJ_SelectTier(tier)

        --print("Tier:", tier)

        for j = 1, 12 do

            local instanceID, instanceName, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty, mapID = EJ_GetInstanceByIndex(j, true)

            if instanceID then

                --print("Instance:", instanceName)

                EJ_SelectInstance(instanceID)
                EncounterJournal_DisplayInstance(instanceID, true)

                for index, difficultyID in ipairs(EJ_DIFFICULTIES) do
                    if EJ_IsValidInstanceDifficulty(difficultyID) then

                        EJ_SetDifficulty(difficultyID)
                        for l = 1, 14 do
                            local bossName, description, journalEncounterID, rootSectionID, link, journalInstanceID, dungeonEncounterID, _instanceID = EJ_GetEncounterInfoByIndex(l)

                            -- if tier == 1 then
                            --     print(difficultyID, bossName)
                            -- end

                            if journalEncounterID then
                                local defeatedOnCurrentDifficulty = mapID and dungeonEncounterID and C_RaidLocks.IsEncounterComplete(mapID, dungeonEncounterID, difficultyID);
                                local hasDefeatedBoss = defeatedOnCurrentDifficulty and IsEJDifficulty(difficultyID);

                                -- if tier == 4 then
                                --     print(string.format("Instance: %s Boss: %s Defeated: %s Difficulty: %s", instanceName, bossName, tostring(hasDefeatedBoss), difficultyID))
                                -- end
                                table.insert(ret, {
                                    mapID = mapID,
                                    instanceID = instanceID,
                                    difficultyID = difficultyID,
                                    bossName = bossName,
                                    defeated = hasDefeatedBoss,
                                    journalEncounterID = journalEncounterID,
                                    dungeonEncounterID = dungeonEncounterID, --matches the args for BOSS_KILL
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    --restore the functions
    EncounterJournal_LootUpdate = EncounterJournal_LootUpdate_Func
    UpdateDifficultyVisibility = UpdateDifficultyVisibility_Func
    EncounterJournal_SetTabEnabled = EncounterJournal_SetTabEnabled_Func

    return ret
end

function TbdAltManagerRaids.Api.GetInstanceEncounterData(instanceID)

    local ret = {}

    for _, character in CharacterDataProvider:EnumerateEntireRange() do
        if character.encounterJournal then
            for _, encounter in ipairs(character.encounterJournal) do
                if encounter.mapID == instanceID then
                    table.insert(ret, {
                        character = character.uid,
                        encounter = encounter,
                    })
                end
            end
        end
    end

    return ret;
end













local EventsToRegister = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "ENCOUNTER_END",
    "BOSS_KILL"
}

--Frame to setup event listening
local InstancesEventFrame = CreateFrame("Frame")
for _, event in ipairs(EventsToRegister) do
    InstancesEventFrame:RegisterEvent(event)
end
InstancesEventFrame:SetScript("OnEvent", function(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end)

function InstancesEventFrame:ADDON_LOADED(...)
    if (...) == addonName then
        if TbdAltManager_Instances_SavedVariables == nil then

            CharacterDataProvider:Init({})
            TbdAltManager_Instances_SavedVariables = CharacterDataProvider:GetCollection()
    
        else
    
            local data = TbdAltManager_Instances_SavedVariables
            CharacterDataProvider:Init(data)
            TbdAltManager_Instances_SavedVariables = CharacterDataProvider:GetCollection()
    
        end

        CharacterDataProvider:UpdateDefaultKeys()

        if not CharacterDataProvider:IsEmpty() then
            TbdAltManagerRaids.CallbackRegistry:TriggerEvent("DataProvider_OnInitialized")
        end
    end
end

function InstancesEventFrame:PLAYER_ENTERING_WORLD(...)
    local account = "Default"
    local realm = GetRealmName()
    local name = UnitName(playerUnitToken)

    self.characterUID = string.format("%s.%s.%s", account, realm, name)

    CharacterDataProvider:InsertCharacter(self.characterUID)

    self.character = CharacterDataProvider:FindCharacterByUID(self.characterUID)

    local isInitial, isReload = ...;
    if isInitial then
        C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
        self:FetchData()
        TbdAltManagerRaids.Api.ResetBossDefeatedInfo()
    end

    if ViragDevTool_AddData then
        ViragDevTool_AddData(TbdAltManager_Instances_SavedVariables, addonName)
    end
end

function InstancesEventFrame:FetchData()
    RequestRaidInfo()
    local instanceData = TbdAltManagerRaids.Api.GetPlayerLockouts()
    if instanceData and (#instanceData > 0) then
        self.character.instances = instanceData;
        TbdAltManagerRaids.CallbackRegistry:TriggerEvent("Character_OnChanged")
    end
    local encounterJournal = TbdAltManagerRaids.Api.ScrapEncounterJournal()
    if encounterJournal and (#encounterJournal > 0) then
        self.character.encounterJournal = encounterJournal;
        TbdAltManagerRaids.CallbackRegistry:TriggerEvent("Character_OnChanged")
    end
end

function InstancesEventFrame:ENCOUNTER_END(...)

end

function InstancesEventFrame:BOSS_KILL(...)
    local dungeonEncounterID, _ = ...;
    local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, LfgDungeonID = GetInstanceInfo()
    TbdAltManagerRaids.Api.UpdateCharacterEncounterJournal(self.character, dungeonEncounterID, difficultyID)
end





















TbdAltManagerInstancesMenuChildMixin = {}
















TbdAltManagerInstancesCharacterListItemMixin = {}
function TbdAltManagerInstancesCharacterListItemMixin:SetDataBinding(binding, height)
    self:SetHeight(height)
    self.Label:SetText(binding.name)
end
function TbdAltManagerInstancesCharacterListItemMixin:ResetDataBinding()
    self.Label:SetText("")
end
































TbdAltManagerInstanceLockoutMixin = {}

function TbdAltManagerInstanceLockoutMixin:OnLoad()
    TbdAltManagerRaids.CallbackRegistry:RegisterCallback("Character_OnChanged", self.UpdateCharacterList, self)
end

function TbdAltManagerInstanceLockoutMixin:UpdateCharacterList()
    if self.instanceInfo then
        local encounters = TbdAltManagerRaids.Api.GetInstanceEncounterData(self.instanceInfo.mapID)
        local dp = CreateTreeDataProvider()
        local t = {}
        local nodes = {}
        for _, info in ipairs(encounters) do
            if not t[info.encounter.bossName] then
                nodes[info.encounter.bossName] = dp:Insert({name = info.encounter.bossName})
                nodes[info.encounter.bossName]:ToggleCollapsed()
                t[info.encounter.bossName] = true
            end

            if info.encounter.defeated then
                local _, realm, name = strsplit(".", info.character)
                local difficultyName = DifficultyUtil.GetDifficultyName(info.encounter.difficultyID)
                nodes[info.encounter.bossName]:Insert({name = string.format("|cffffffff%s-%s [%s]", name, realm, difficultyName)})
            end
        end
        self.CharacterList.scrollView:SetDataProvider(dp)
    end
end

function TbdAltManagerInstanceLockoutMixin:SetInstance(instanceInfo)
    self.Art:SetTexture(instanceInfo.buttonImage1)
    self.Label:SetText(instanceInfo.name)
    self.instanceInfo = instanceInfo;
    self:UpdateCharacterList()
end









--need to just keep a ref to the button to set a script later
local MenuEntryToggleButton;

TbdAltManagerInstancesMixin = {
    name = "Raids",
    menuEntry = {
        height = 40,
        template = "TbdAltManagerSideBarListviewItemTemplate",
        initializer = function(frame)
            frame.Label:SetText("Raids")
            frame.Icon:SetAtlas("Raid")
            frame:SetScript("OnMouseUp", function()
                TbdAltsManager.Api.SelectModule("Raids")
            end)
            MenuEntryToggleButton = frame.ToggleButton
            TbdAltsManager.Api.SetupSideMenuItem(frame, false, true)
        end,
    }
}
function TbdAltManagerInstancesMixin:OnLoad()
    TbdAltsManager.Api.RegisterModule(self)

    C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
    --ToggleEncounterJournal()

    RequestRaidInfo()

    local function GetJournalTierInstanceData(tier)
        EJ_SelectTier(tier)
        local t = {}
        for j = 1, 12 do
            local instanceID, instanceName, description, bgImage, buttonImage1, loreImage, buttonImage2, dungeonAreaMapID, link, shouldDisplayDifficulty, mapID = EJ_GetInstanceByIndex(j, true)
            --print(string.format("Tier %d: Index %d: Name: %s", tier, j, (name or "no name returned")))
            if instanceID and instanceName then
                table.insert(t, {
                    instanceID = instanceID,
                    mapID = mapID,
                    name = instanceName,
                    buttonImage1 = buttonImage1,
                })
            end
        end
        return t
    end

    local function CreateChildMenu()
        local numExpansionTiers = EJ_GetNumTiers()
        for i = 1, numExpansionTiers - 1 do
            local tierData = GetJournalTierInstanceData(i)
            local childEntry = {
                height = 22,
                template = "TbdAltManagerInstancesMenuChildTemplate",
                initializer = function(frame)
                    frame.Label:SetText(_G["EXPANSION_NAME"..(i-1)])
                    frame:HookScript("OnMouseUp", function()
                        self:LoadExpansionInstances(tierData)
                        TbdAltsManager.Api.SelectModule("Raids")
                    end)
                end,
            }
            self.menuEntryNode:Insert(childEntry)
        end
    end

    self.LoadChildMenuTicker = C_Timer.NewTicker(0.5, function()
        if EJ_GetNumTiers() == 0 then
            
        else
            CreateChildMenu()
            self.LoadChildMenuTicker:Cancel()
        end
    end)

    MenuEntryToggleButton:SetScript("OnClick", function(button)
        self.menuEntryNode:ToggleCollapsed()
        if self.menuEntryNode:IsCollapsed() then
            button:SetNormalAtlas("128-RedButton-Plus")
            button:SetPushedAtlas("128-RedButton-Plus-Pressed")
        else
            button:SetNormalAtlas("128-RedButton-Minus")
            button:SetPushedAtlas("128-RedButton-Minus-Pressed")
        end
    end)

    self.InstanceContainer4.DividerRight:Hide()


    self:SetScript("OnMouseWheel", function(_, delta)
        if delta == 1 then
            self.ScrollRight:Click()
        else
            self.ScrollLeft:Click()
        end
    end)

end

function TbdAltManagerInstancesMixin:OnShow()
    
end

function TbdAltManagerInstancesMixin:LoadExpansionInstances(data)

    self.ScrollLeft:Hide()
    self.ScrollRight:Hide()

    self.InstanceContainers[1]:ClearAllPoints()
    for _, frame in ipairs(self.InstanceContainers) do
        frame:Hide()
        frame.DividerRight:Hide()
    end

    if #data >= 4 then
        self.InstanceContainers[1]:SetPoint("LEFT", 31, 0)
        for i = 1, 4 do
            self.InstanceContainers[i]:Show()
            self.InstanceContainers[i]:SetInstance(data[i])
            if i < 4 then
                self.InstanceContainers[i].DividerRight:Show()
            end
        end

        self.ScrollLeft:Show()
        self.ScrollRight:Show()

        self.InstanceContainerScrollOffset = 0;

        self.ScrollLeft:SetScript("OnClick", function()
            if self.InstanceContainerScrollOffset == 0 then
                return

            else
                self.InstanceContainerScrollOffset = self.InstanceContainerScrollOffset - 1

                for i = 1, 4 do
                    local indexOffset = self.InstanceContainerScrollOffset + i
                    if data[indexOffset] then
                        self.InstanceContainers[i]:SetInstance(data[indexOffset])
                    end
                end
            end
        end)

        self.ScrollRight:SetScript("OnClick", function()

            if self.InstanceContainerScrollOffset == (#data - 4) then
                return

            else
                self.InstanceContainerScrollOffset = self.InstanceContainerScrollOffset + 1

                for i = 1, 4 do
                    local indexOffset = self.InstanceContainerScrollOffset + i
                    if data[indexOffset] then
                        self.InstanceContainers[i]:SetInstance(data[indexOffset])
                    end
                end
            end
        end)


    else

        self.InstanceContainers[1]:SetPoint("LEFT", 31 + 127, 0)
        for i = 1, #data do
            self.InstanceContainers[i]:Show()
            self.InstanceContainers[i]:SetInstance(data[i])

            if i < #data then
                self.InstanceContainers[i].DividerRight:Show()
            end
        end

    end
end