local curRaid = nil;
local curEncounter = nil;
local curEtalonEdit = nil;

local CSV_DELIMITRIER = "\t"

-- TODO enter combat if no dbm pull emited
function startEncounter()
    inEncounter = true;
    shoutBuffs();
end

function endEncounter()
    inEncounter = false;
    curEncounter["isActive"] = false;
end


---------------------------------------------------------------------------------------------------------------------------
--  RENDER FUNCS
---------------------------------------------------------------------------------------------------------------------------

function floatToCSV(number)
    local b = number.."";
    local res = string.gsub(b,"%.",",")
    
    return res;
end

function formEncountersLine(RaidNo)
    local line = CSV_DELIMITRIER;

    for i, encounter in pairs(RaidUsageLog["Raids"][RaidNo]["Encounters"]) do   
        line = line .. "(" .. encounter["EncNo"] .. ")" .. encounter["EncName"] .. CSV_DELIMITRIER .. 'EP' .. CSV_DELIMITRIER;
    end

    return line;
end

function insertWorldBuffsIntoRaidStart(playerName, encountersList)
    for encIdx, encounter in pairs(encountersList) do
        if encounter["Usages"][playerName] then
            for usageName, usageInfo in pairs(encounter["Usages"][playerName]["Usages"]) do
                -- TODO should add mechanism to check on what encounters player had WB
                if RaidEtalons[usageName]["isImportant"] and RaidEtalons[usageName]["isWorldBuff"] and 
                    (encountersList[1]["Usages"][playerName] == nil or encountersList[1]["Usages"][playerName]["Usages"][usageName] == nil) then

                    raidRegisterPlayerInUsageList(encounter["Usages"][playerName]["Class"], playerName, usageName, "MOVED_WB_FROM?"..encIdx, encountersList[1]["Usages"]);
                end
            end
        end
    end
end

function insertImportant(importantsList, encIdx, usageId, usageName, price)
    local cnt = importantUsages[encIdx]["LinesCnt"];
    if not importantsList[encIdx]["Usages"][usageId] then
        importantsList[encIdx]["Usages"][usageId] = true;

        cnt = cnt+1;
        importantUsages[encIdx]["LinesCnt"] = cnt;
        importantUsages[encIdx]["Lines"][cnt] = {};
        importantUsages[encIdx]["Lines"][cnt]["name"] = usageName;
        importantUsages[encIdx]["Lines"][cnt]["EP"] = price;

        importantUsages[encIdx]["epSum"] = importantUsages[encIdx]["epSum"] + price;
    end

    return cnt;
end


function importantsForPlayerOnAllEncounters(playerName, encountersList)
    local maxPerEncounter = 0;
    local encAmount = 0;
    local wholeSum = 0;
    importantUsages = {};

    for encIdx, encounter in pairs(encountersList) do
        local encounterImportantCnt = 0;

        encAmount = encAmount +1;

        importantUsages[encIdx] = {};
        importantUsages[encIdx]["EncName"] = encounter["EncName"];
        importantUsages[encIdx]["Usages"] = {};
        importantUsages[encIdx]["Lines"] = {};
        importantUsages[encIdx]["LinesCnt"] = 0;
        importantUsages[encIdx]["epSum"] = 0;

        local newCnt = 0;
        if encounter["Usages"][playerName] then
            for usageName, usageInfo in pairs(encounter["Usages"][playerName]["Usages"]) do

                if RaidEtalons[usageName]["isImportant"] then
                    if RaidEtalons[usageName]["isWorldBuff"] then
                        newCnt = insertImportant(importantUsages, 1, usageName, RaidEtalons[usageName]["displayName"], RaidEtalons[usageName]["price"]);
                    else
                        newCnt = insertImportant(importantUsages, encIdx, usageName, RaidEtalons[usageName]["displayName"], RaidEtalons[usageName]["price"]);
                    end

                end

            end
        end

        if newCnt > maxPerEncounter then maxPerEncounter = newCnt; end
    end

    return maxPerEncounter, importantUsages;
end

function formPlayerLinesForAllEncounters(playerName, encountersList)
    local lines = playerName;
    local maxPerEncounter = 0;
    local encAmount = table.getn(encountersList);

    local playerSum = 0;

    -- Should make: ,USAGE_NAME,EP
    maxPerEncounter, importantUsagesPerEncounters = importantsForPlayerOnAllEncounters(playerName, encountersList);
    
    for lineNo=1,maxPerEncounter do 

        for encNo=1,encAmount do
            if lineNo == 1 then
                playerSum = playerSum + importantUsagesPerEncounters[encNo]["epSum"];
            end

            if importantUsagesPerEncounters[encNo]["Lines"][lineNo] then
                local strEP = floatToCSV(importantUsagesPerEncounters[encNo]["Lines"][lineNo]["EP"]);
                lines = lines .. CSV_DELIMITRIER .. importantUsagesPerEncounters[encNo]["Lines"][lineNo]["name"] .. CSV_DELIMITRIER .. strEP;
            else
                lines = lines .. CSV_DELIMITRIER .. CSV_DELIMITRIER;
            end
        end

        lines = lines .. "\n";
    end

    playerSum = math.floor(playerSum+0.9999); -- ROUND UP

    -- SUM LINE
    lines = lines .. "\n";
    lines = lines .. playerSum .. CSV_DELIMITRIER;
    for encNo=1,encAmount do
        local strEP = floatToCSV(importantUsagesPerEncounters[encNo]["epSum"]);
        lines = lines .. "" .. CSV_DELIMITRIER .. strEP .. CSV_DELIMITRIER
    end

    -- Two empty lines to separate player
    lines = lines .. "\n";
    lines = lines .. "\n";

    lines = lines .. "\n";
    return lines;
end

function renderCSV()
    local RaidNo = twobsSettings["selectedRaid"];
    local classFilter = twobsSettings["classFilter"];
    local result = "";

    result = result .. formEncountersLine(RaidNo) .."\n";
    
    for playerName, playerInfo in pairs(RaidUsageLog["Raids"][RaidNo]["Players"]) do
        if classFilter == "ALL" or playerInfo["Class"] == classFilter then
            
            result = result .. formPlayerLinesForAllEncounters(playerName, RaidUsageLog["Raids"][RaidNo]["Encounters"]);
        end
    end

    return result;
end

function renderBuffs()
    local classFilter = twobsSettings["classFilter"];
    local result = "";

    if not curRaid then return "Рейд пуст"; end
    
    local pIdx = 0;
    local idx = 0;
    for playerName, playerInfo in pairs(curRaid["Buffs"]) do
        pIdx = pIdx + 1;
        if classFilter == "ALL" or playerInfo["Class"] == classFilter then
            result = result .. pIdx .. ")" .. playerName .. " - " .. playerInfo["Class"] .. "\n";

            idx = 0;
            for usageName, usageInfo in pairs(playerInfo["Usages"]) do
                idx = idx + 1;
                result = result .. "    " .. "(" .. idx .. ")" .. RaidEtalons[usageName]["displayName"] .. "\n";
            end

            result = result .. "\n" .. "\n";
        end
    end

    if pIdx == 0 then result = "Нет данных по игрокам с этим фильтром"; end
    return result;
end

---------------------------------------------------------------------------------------------------------------------------
--  RENDER FUNCS END
---------------------------------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------------------------------
--  RAID FUNCS
---------------------------------------------------------------------------------------------------------------------------

local CHECK_TIMER_SECS = 1;
function checkEncounterStage()
    local playersAmount = GetNumGroupMembers();
    if playersAmount == 0 or (not curEncounter) then return; end
    
    local engagedAmount = 0;
    for i = 1,playersAmount do
        if UnitAffectingCombat("raid"..i) then 
            engagedAmount = engagedAmount + 1;
        end
    end
    
    if engagedAmount > 0 then
        if curEncounter["Stage"] == 0 then
            curEncounter["Stage"] = 1; -- if stage was INCOMING and we have fighting players goto ACTIVE stage
            if twobsSettings["stagesMsgs"] then print("ACTIVE NOW", curEncounter["Stage"]); end
        end
    else
        -- there is no fighting players, so if stage was ACTIVE goto ENDED stage
        if curEncounter["Stage"] == 1 then
            curEncounter["Stage"] = 2;
            if twobsSettings["stagesMsgs"] then print("ENDED NOW", curEncounter["Stage"]); end
        end
    end

    -- recheck while encounter not ENDED
    if curEncounter["Stage"] < 2 then
        C_Timer.After(CHECK_TIMER_SECS, checkEncounterStage);
    end
end

function raidRegisterPlayerInUsageList(playerClass, playerName, usageId, usageInfo, usageList, regShots)
    regShots = regShots
    if regShots == nil then regShots = true; end

    -- TODO probably should use full playerStr as identifier 
    if usageList[playerName] == nil then
        usageList[playerName] = {};
        usageList[playerName]["Class"] = playerClass;
        usageList[playerName]["Usages"] = {};
        usageList[playerName]["Count"] = 0;
    end

    if curRaid["Players"][playerName] == nil then
        curRaid["Players"][playerName] = {};
        curRaid["Players"][playerName]["MaxUsages"] = 0;
        curRaid["Players"][playerName]["Class"] = playerClass;
    end

    -- TODO Probably i messed up everything by mixing GetTime() and GetServerTime()
    local encounterSeconds = GetTime() - curEncounter["TS"];
    local encounterTimeStr = string.format("%u:%u", math.floor(encounterSeconds/60), encounterSeconds%60);

    usageInstance = usageList[playerName]["Usages"][usageId];
    if usageList[playerName]["Usages"][usageId] == nil then
        local cnt = usageList[playerName]["Count"] + 1;
        usageList[playerName]["Count"] = cnt;

        usageList[playerName]["Usages"][usageId] = {
            ["spellId"] = usageId,
            ["shotsCnt"] = 0,
            ["shots"] = {},
            ["inEncIdx"] = cnt;
        };

        if cnt > curRaid["Players"][playerName]["MaxUsages"] then
            curRaid["Players"][playerName]["MaxUsages"] = cnt;
        end

        usageInstance = usageList[playerName]["Usages"][usageId];
    end

    local shotsCnt = usageInstance["shotsCnt"] +1;

    if regShots then
        usageInstance["shotsCnt"] = shotsCnt;
        usageInstance["shots"][shotsCnt] = {
            ["encounterTime"] = encounterTimeStr;
            ["usageInfo"] = usageInfo;
        }
    end
end

function tryGetEtalon(usageType, usageName, usageId, usageInfo, userClass) 
    -- Register part
    local etalon = RaidEtalons[usageId];
    if etalon == nil then
        local defaultDisplay = string.format ("%s (%s)", usageName, usageId);
        etalon = {
            ["class"] = {},
            ["displayName"] = defaultDisplay,
            ["isImportant"] = (usageType=="A"),
            ["isWorldBuff"] = false,
            ["Type"] = usageType,
            ["price"] = 0,
            ["isNew"] = true,
            ["creationTS"] = GetServerTime(),
            ["modifyTS"] = GetServerTime()
        };
        RaidEtalons[usageId] = etalon
    end

    if not RaidEtalons[usageId]["class"][userClass] then
        RaidEtalons[usageId]["class"][userClass] = true;
    end

    -- overwrite buffs in etalons
    if usageType == "A" then
        RaidEtalons[usageId]["Type"] = "A";
        RaidEtalons[usageId]["isImportant"] = true;
        
        etalon["Type"] = "A";
        etalon["isImportant"] = true;
    end

    return etalon;
end

function raidRegisterPlayerUsage(playerStr, usageData) -- prob should add usageInfo param
    local usageType, usageName, usageId, usageInfo = strsplit("/", usageData);
    local playerClass, playerName = strsplit("/", playerStr);

    local etalon = tryGetEtalon(usageType, usageName, usageId, usageInfo, playerClass);

    if etalon["isWorldBuff"] then
        if curRaid then raidRegisterPlayerInUsageList(playerClass, playerName, usageId, usageInfo, curRaid["Encounters"][1]); end
    else
        if curEncounter and curEncounter["Stage"]<2 then raidRegisterPlayerInUsageList(playerClass, playerName, usageId, usageInfo, curEncounter["Usages"]); end
    end

    if etalon["Type"] == "A" and curRaid then
        local duration = strsplit("/", usageInfo);
        raidRegisterPlayerInUsageList(playerClass, playerName, usageId, usageInfo, curRaid["Buffs"], false);
    end
end

function raidEncounterInit(tarName)
    if curRaid == nil then return; end
    curEncounter = nil;

    local encIdx = curRaid["EncountersCnt"]+1;
    curRaid["EncountersCnt"] = encIdx;

    curRaid["Encounters"][encIdx] = {};

        curRaid["Encounters"][encIdx]["EncName"] = tarName;
        curRaid["Encounters"][encIdx]["EncNo"] = encIdx;
        curRaid["Encounters"][encIdx]["isActive"] = (encIdx>1);
        curRaid["Encounters"][encIdx]["Stage"] = 0;    -- 0 - INCOMING; 1 - ACTIVE; 2 - ENDED
        curRaid["Encounters"][encIdx]["EncPlayers"] = {};

        local TS = GetServerTime();
        curRaid["Encounters"][encIdx]["TS"] = TS;
        curRaid["Encounters"][encIdx]["Date"] = date("%d/%m/%y %H:%M:%S", TS);
        
        curRaid["Encounters"][encIdx]["Usages"] = {};
        curRaid["Encounters"][encIdx]["MaxCount"] = 0;

    curEncounter = curRaid["Encounters"][encIdx];
    
    if twobsSettings["stagesMsgs"] then print("encINIT", curEncounter["EncName"], curEncounter["isActive"]); end
    checkEncounterStage();
end

function raidInitRaid(raidName)
    curRaid = nil;

    local raidIdx = RaidUsageLog["Count"]+1;
    RaidUsageLog["Count"] = raidIdx;

    RaidUsageLog["Raids"][raidIdx] = {};
        RaidUsageLog["Raids"][raidIdx]["RaidName"] = raidName;

        local TS = GetServerTime();
        RaidUsageLog["Raids"][raidIdx]["TS"] = TS;
        RaidUsageLog["Raids"][raidIdx]["Date"] = date("%d/%m/%y %H:%M:%S", TS);

        RaidUsageLog["Raids"][raidIdx]["EncountersCnt"] = 0;
        RaidUsageLog["Raids"][raidIdx]["Encounters"] = {};

        --RaidUsageLog["Raids"][raidIdx]["LongTermUsages"] = {};
        RaidUsageLog["Raids"][raidIdx]["Buffs"] = {};
        RaidUsageLog["Raids"][raidIdx]["Players"] = {};

    curRaid = RaidUsageLog["Raids"][raidIdx];
    raidEncounterInit("RaidStart");
end

function raidHandleEntering(instName)
    if curRaid == nil or curRaid["RaidName"] ~= instName then
        raidInitRaid(instName);
    end
end
---------------------------------------------------------------------------------------------------------------------------
--  END RAID FUNCS
---------------------------------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------------------------------
--  PERSONAL FUNCS
---------------------------------------------------------------------------------------------------------------------------

function secondsLeftToStr(timeLeft) 
    local minsLeft = math.floor(timeLeft/60);
    --local secsLeft = timeLeft % 60;
    local strLeft = minsLeft..""--..secsLeft;

    return strLeft;
end


-- Shout format:
-- SH|<CLASS>/<PLAYER>|A/<NAME>/<SpellId>/<DURATION>?...
-- SH|<CLASS>/<PLAYER>|I/<NAME>/<SpellId>/INSTANT?...
function shout(spellType, spellName, spellId, spellInfo)
    local localizedClass, englishClass, classIndex = UnitClass("player");
    local playerName, realm = UnitName("player");

    local msg = "SH|"..   englishClass.."/"..playerName   .."|"..   spellType.."/"..spellName.."/"..spellId.."/"..spellInfo;
    
    local instName, instType, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapId, lfgID = GetInstanceInfo();
    if twobsSettings["shoutEverywhere"] or instType == "raid" or instType == "party" then
        C_ChatInfo.SendAddonMessage("TWOBS", msg, "RAID"); -- TODO - should swtich to GUILD or OFFICER (maybe u cannot write to officer?)
    end
end

function shoutBuffs()
    local i = 1;
    while UnitAura("player", i, "HELPFUL") do

        local name, rank, icon, count, duration, expirationTime, _, unitCaster, _, spellId = UnitAura("player", i, "HELPFUL");

        local timeLeft = expirationTime - GetTime();
        local strLeft = secondsLeftToStr(timeLeft);

        shout("A", name, spellId, strLeft);

        i = i + 1;
    end

    local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandCharges, offHandEnchantId = GetWeaponEnchantInfo();
    if hasMainHandEnchant then
        local timeLeft = math.floor(mainHandExpiration/1000);
        local strLeft = secondsLeftToStr(timeLeft);
        local enchName = "Ench:"..mainHandEnchantID; --getEnchantById(mainHandEnchantID);

        shout("A", "Улучшение Правой Руки", "E"..mainHandEnchantID, strLeft);
    end
    if hasOffHandEnchant then
        local timeLeft = math.floor(offHandExpiration/1000);
        local strLeft = secondsLeftToStr(timeLeft);
        local enchName = "Ench:"..offHandEnchantId; --getEnchantById(offHandEnchantId);

        shout("A", "Улучшение Левой Руки", "E"..offHandEnchantId, strLeft);
    end
end

---------------------------------------------------------------------------------------------------------------------------
--  END PERSONAL FUNCS
---------------------------------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------------------------------
--  MAIN EVENTS HANDLING
---------------------------------------------------------------------------------------------------------------------------

typesDict = {
    ["I"] = "МГНВ",
    ["A"] = "БАФФ",
}

local ETALON_BTN_PREFIX = "EtalonStr-"
function AddEtalonStr(i, isImportant, isNew, isWB, type, etalonName, displayName, EP)
    local frame = _G[ETALON_BTN_PREFIX .. i];
    if frame == nil then 
        CreateFrame('Button', ETALON_BTN_PREFIX .. i, _G["Etalons_scrollframe_container"], "EtalonStrTemplate");
        frame = _G[ETALON_BTN_PREFIX .. i];
    end

    if i > 1 then
        frame:SetPoint("TOPLEFT", _G[ETALON_BTN_PREFIX .. i-1], "BOTTOMLEFT", 0, -2);
    else
        frame:SetPoint("TOPLEFT", _G["Etalons_scrollframe_container"], "TOPLEFT", 0, 0);
    end

    local displayNameStr = displayName;
    if isNew then displayNameStr = "* "..displayNameStr; end

    frame:SetAttribute("usageId", etalonName);
    _G[ETALON_BTN_PREFIX .. i .. "Important"]:SetChecked(isImportant);
    _G[ETALON_BTN_PREFIX .. i .. "Id"]:SetText(etalonName);
    _G[ETALON_BTN_PREFIX .. i .. "Name"]:SetText(displayNameStr);
    _G[ETALON_BTN_PREFIX .. i .. "Type"]:SetText(typesDict[type]);
    _G[ETALON_BTN_PREFIX .. i .. "WB"]:SetChecked(isWB);
    _G[ETALON_BTN_PREFIX .. i .. "EP"]:SetText(EP);
    frame:Show();
end

function handleDBMevent(...)
    local dpre, dtim, dinst, dtar = select(1, ...);
    if dpre == "PT" then
        if dtar then
        else
            dtar = "Unknown";
        end

        raidEncounterInit(dtar);
        C_ChatInfo.SendAddonMessage("TWOBS", "EC|START", "RAID");
    end
end

function handleEnteringWorld(isLogin, isReload)
    local name, type, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapId, lfgID = GetInstanceInfo();
    local cnt = RaidUsageLog["Count"];
    
    if not (type == "raid" or type == "party" or twobsSettings["registerAnyLoc"]) then
        return;
    end

    if isReload then
        if cnt > 0 then 
            curRaid = RaidUsageLog["Raids"][cnt];
            local eCnt = curRaid["EncountersCnt"];
            curEncounter = curRaid["Encounters"][eCnt];
        else
            raidHandleEntering(name);
        end

    -- NO RELOAD
    else
        if cnt > 0 then 
            if RaidUsageLog["Raids"][cnt]["RaidName"] ~= name then
                raidHandleEntering(name);
            else
                curRaid = RaidUsageLog["Raids"][cnt];
                local cnt = curRaid["EncountersCnt"];
                curEncounter = curRaid["Encounters"][cnt];
            end            
        else
            raidHandleEntering(name);
        end
    end

end

function TWObs_OnEvent(...)
    local event, arg1, arg2, arg3, arg4 = select(1,...);

    if event == "CHAT_MSG_ADDON" then
        local prefix, message, chat, sender = select(2,...);


        if prefix == "D4C" then
            handleDBMevent(strsplit("\t", message));
        end

        if prefix == "TWOBS" then
            local type, playerStr, usageData = strsplit("|", message);

            if type == "SH" then
                raidRegisterPlayerUsage(playerStr, usageData);
            end

            if type == "EC" and message == "EC|START" then
                startEncounter();
            end
            if type == "EC" and message == "EC|END" then
                endEncounter();
            end

            -- player status:
            -- "ST|<CLASS>/<NAME>|ENGAGE/ALIVE"
            -- "ST|<CLASS>/<NAME>|AVOID/DEAD"
            if type == "ST" then
                local type, playerStr, statusData = strsplit("|", message);
                --handlePlayerStatus(playerStr, statusData);
            end
        end
    end
    
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellId = select(2,...);
        local spellName, rank, icon, castTime, minRange, maxRange, sId = GetSpellInfo(spellId);

        shout("I", spellName, spellId, "INSTANT&");
    end

    if event == "ADDON_LOADED" and arg1 == "twObs" then
        if RaidUsageLog == nil then
            RaidUsageLog = {};
            RaidUsageLog["Count"] = 0;
            RaidUsageLog["Raids"] = {};
        end

        if RaidEtalons == nil then
            RaidEtalons = {};
        end

        if inEncounter == nil then
            inEncounter = false; 
        end

        if twobsSettings == nil then
            twobsSettings = {};
            twobsSettings["encAutoEnd"] = false;
            twobsSettings["encEndMsg"] = false;
            twobsSettings["classFilter"] = "ALL";
            twobsSettings["shoutEverywhere"] = false;
            twobsSettings["selectedRaid"] = 1;
        end

        local regPrefixResult = C_ChatInfo.RegisterAddonMessagePrefix("TWOBS");
    end

    if event == "PLAYER_ENTERING_WORLD" then
        handleEnteringWorld(arg1, arg2);
    end

    -- raidCheck inited
    if event == "READY_CHECK" then
        if curRaid then
            curRaid["Buffs"] = {};
        end

        local playerName, realm = UnitName("player")
        if arg1 == playerName then shoutBuffs(); end
    end

    if event == "PLAYER_REGEN_ENABLED" then
        local deadOrGhost = UnitIsDeadOrGhost("player");
        local localizedClass, englishClass, classIndex = UnitClass("player");
        local playerName, realm = UnitName("player");
    
        local msg = "ST|"..   englishClass.."/"..playerName   .."|"..   "AVOID".."/";
        if deadOrGhost then 
            msg = msg.."DEAD";
        else
            msg = msg.."ALIVE";
        end

        --C_ChatInfo.SendAddonMessage("TWOBS", msg, "RAID");
    end
    
    if event == "PLAYER_REGEN_DISABLED" then

        local deadOrGhost = UnitIsDeadOrGhost("player");
        local localizedClass, englishClass, classIndex = UnitClass("player");
        local playerName, realm = UnitName("player");
    
        local msg = "ST|"..   englishClass.."/"..playerName   .."|"..   "ENGAGE".."/";
        if deadOrGhost then 
            msg = msg.."DEAD";
        else
            msg = msg.."ALIVE";
        end

        --C_ChatInfo.SendAddonMessage("TWOBS", msg, "RAID");
    end

    if event == "RAID_INSTANCE_WELCOME" then
        --print("INST", arg1, arg2, arg3, arg4);
    end

    -- me confirmed readycheck
    if event == "READY_CHECK_CONFIRM" then    
        if arg1 == "player" and arg2 then shoutBuffs(); end
    end
end

function TWOBS_formatExport()
    local formatedCSV = renderCSV();
    TWOBS_export_dump:SetText(formatedCSV);
end

function TWOBS_formatBuffs()
    local formatedBuffs = renderBuffs();
    TWOBS_export_dump:SetText(formatedBuffs);
end

function TWOBS_showEtalons()
    if _G["Etalons_scrollframe_container"] == nil or RaidEtalons == nil then return; end

    local kids = { _G["Etalons_scrollframe_container"]:GetChildren() };

    for _, child in ipairs(kids) do
        child:Hide();
    end

    local idx = 0;
    local filter = "ALL";
    if twobsSettings and twobsSettings["classFilter"] then filter = twobsSettings["classFilter"]; end

    local keys = {};
    for etalonName, etalonInfo in pairs(RaidEtalons) do
        if filter == "ALL" or etalonInfo["class"][filter] then
            idx = idx+1;
            keys[idx] = etalonName;
        end
    end

    table.sort(keys, function(a, b) 
        return RaidEtalons[a]["displayName"]:upper() < RaidEtalons[b]["displayName"]:upper();
    end);

    idx = 0;
    for _,k in pairs(keys) do
        idx = idx+1;
        AddEtalonStr(idx, RaidEtalons[k]["isImportant"], RaidEtalons[k]["isNew"], RaidEtalons[k]["isWorldBuff"],
                        RaidEtalons[k]["Type"], k, RaidEtalons[k]["displayName"], RaidEtalons[k]["price"]);
    end

    --TWOBS_etalons_nodata_label:Hide();
    if idx == 0 then
        --TWOBS_etalons_nodata_label:Show();
    end
end

function TWOBS_EtalonButton_OnClick(bName, button)
    curEtalonEdit = _G[bName]:GetAttribute("usageId");

    local curEtalonInstance = RaidEtalons[curEtalonEdit];

    _G["TWOBS_etalon_edit_name"]:SetText(curEtalonInstance["displayName"]);

    _G["TWOBS_etalon_edit_title"]:SetText("Применение: " .. curEtalonEdit);
    _G["TWOBS_etalon_edit_type"]:SetText(typesDict[curEtalonInstance["Type"]]);

    _G["TWOBS_etalon_edit_important"]:SetChecked(curEtalonInstance["isImportant"]);
    _G["TWOBS_etalon_edit_wb"]:SetChecked(curEtalonInstance["isWorldBuff"]);

    _G["TWOBS_etalon_edit_EP"]:SetText(curEtalonInstance["price"]);
    
    _G["TWOBS_etalon_edit_popup"]:Show();
end

function TWOBS_EtalonButton_Save()
    local isValid = true;

    local newName = _G["TWOBS_etalon_edit_name"]:GetText();
    if newName == "" then
        message("Имя не может быть пустым!");
        isValid = false;

        return;
    end

    local newEP = _G["TWOBS_etalon_edit_EP"]:GetText();
    newEP = tonumber(newEP);
    if newEP == nil then
        message("Значение ЕР ошибочно (нужно число, с точкой для дробей)!");
        isValid = false;

        return;
    end

    
    RaidEtalons[curEtalonEdit]["displayName"] = newName;
    RaidEtalons[curEtalonEdit]["isImportant"] = _G["TWOBS_etalon_edit_important"]:GetChecked();
    RaidEtalons[curEtalonEdit]["isWorldBuff"] = _G["TWOBS_etalon_edit_wb"]:GetChecked();
    RaidEtalons[curEtalonEdit]["price"] = newEP;
    RaidEtalons[curEtalonEdit]["isNew"] = false;
    
    TWOBS_showEtalons();
    TWOBS_etalon_edit_popup:Hide();
end

function selectClassFilter(self, dropDownFrame)
    twobsSettings["classFilter"] = self.value;
    UIDropDownMenu_SetSelectedValue(dropDownFrame, self.value);

    TWOBS_showEtalons();
end

function scfEtalons(self)
    selectClassFilter(self, _G["TWOBS_etalons_class_dropdown"]);
end
function scfExport(self)
    selectClassFilter(self, _G["TWOBS_export_class_dropdown"]);
end

function addDropDownButton(text, value, func)
    local info = UIDropDownMenu_CreateInfo()

    info.text = text;
    info.checked = false;
    info.value = value;
    info.func = func;
    UIDropDownMenu_AddButton(info);
end

function TWOBS_class_dropdown_OnLoad(self)
    local func = nil;
    if self == _G["TWOBS_etalons_class_dropdown"] then func = scfEtalons; end
    if self == _G["TWOBS_export_class_dropdown"] then func = scfExport; end

    addDropDownButton("Все классы", "ALL", func);
    addDropDownButton("Воины", "WARRIOR", func);
    addDropDownButton("Жрецы", "PRIEST", func);
    addDropDownButton("Маги", "MAGE", func);
    addDropDownButton("Колдуны", "WARLOCK", func);
    addDropDownButton("Разбойники", "ROGUE", func);
    addDropDownButton("Друиды", "DRUID", func);
    addDropDownButton("Паладины", "PALADIN", func);
    addDropDownButton("Шаманы", "WARLOCK", func);
    addDropDownButton("Охотники", "HUNTER", func);
    
    local selected = "ALL";
    if twobsSettings and twobsSettings["classFilter"] then
        selected = twobsSettings["classFilter"];
    end
    UIDropDownMenu_SetSelectedValue(self, selected);
end


function selectRaid(self)
    twobsSettings["selectedRaid"] = self.value;
    UIDropDownMenu_SetSelectedValue(_G["TWOBS_export_raid_dropdown"], self.value);

    TWOBS_formatExport();
end

function TWOBS_raid_dropdown_OnLoad(self)
    UIDropDownMenu_SetWidth(self, 300);

    if (RaidUsageLog == nil) then return; end

    local func = nil;
    if self == _G["TWOBS_etalons_class_dropdown"] then func = scfEtalons; end
    if self == _G["TWOBS_export_class_dropdown"] then func = scfExport; end

    for i, raid in pairs(RaidUsageLog["Raids"]) do
        local raidStr = raid["Date"].. ": " ..raid["RaidName"] .. " ("..i..")";
        addDropDownButton(raidStr, i, selectRaid);
    end

    
    local selected = 1;
    if twobsSettings["selectedRaid"] then
        selected = twobsSettings["selectedRaid"]
    else
        if RaidUsageLog and RaidUsageLog["Count"] then
            selected = RaidUsageLog["Count"];
        end
    end
    UIDropDownMenu_SetSelectedValue(self, selected);
end

SLASH_TWOBS1 = "/twobs"
SlashCmdList["TWOBS"] = function(msg)
    local done = false;
    if msg == "start" then
        C_ChatInfo.SendAddonMessage("TWOBS", "EC|START", "RAID");
        done = true;
    end
   
    if msg == "end" then
        C_ChatInfo.SendAddonMessage("TWOBS", "EC|END", "RAID");
        done = true;
    end
     
    if msg == "stat" then
        done = true;
    end

    if msg == "exp" then
    _G["TWOBS_export"]:Show();
        done = true;
    end

    if msg == "eta" then
    _G["TWObs_Frame"]:Show();
        done = true;
    end
    
    if done then
        return;
    end
    _G["TWObs_Frame"]:Show();
 end 