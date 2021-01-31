local curRaid = nil;
local curEncounter = nil;

local CSV_DELIMITRIER = ","

-- TODO enter combat if no dbm pull emited
function startEncounter()
    inEncounter = true;
    ----print("startEncounter");
    raidEncounterInit("ManualStart")
    shoutBuffs();
end

function endEncounter()
    inEncounter = false;
    ----print("endEncounter");

end


---------------------------------------------------------------------------------------------------------------------------
--  RENDER FUNCS
---------------------------------------------------------------------------------------------------------------------------

function formEncountersLine(RaidNo)
    local line = CSV_DELIMITRIER;

    for i, encounter in pairs(RaidUsageLog["Raids"][RaidNo]["Encounters"]) do
        print("["..i.."];");
        print("["..i.."] " .. encounter["EncName"]..';');
        line = line .. encounter["EncName"]..CSV_DELIMITRIER..'EP'..CSV_DELIMITRIER;
    end

    return line;
end

function insertWorldBuffsIntoRaidStart(playerName, encountersList)
    for encIdx, encounter in pairs(encountersList) do
        --print("INS", encIdx, encounter, encounter["Usages"]);
        if encounter["Usages"][playerName] then
            for usageName, usageInfo in pairs(encounter["Usages"][playerName]["Usages"]) do
                if RaidEtalons[usageName]["isImportant"] and RaidEtalons[usageName]["isWorldBuff"] and 
                    (encountersList[1]["Usages"][playerName] == nil or encountersList[1]["Usages"][playerName]["Usages"][usageName] == nil) then
                        
                    raidRegisterPlayerInUsageList(encounter["Usages"][playerName]["Class"], playerName, usageName, "MOVED_WB_FROM?"..encIdx, encountersList[1]["Usages"]);
                end
            end
        end
    end
end

function importantsForPlayerOnAllEncounters(playerName, encountersList)
    local maxPerEncounter = 0;
    local encAmount = 0;
    local wholeSum = 0;
    importantUsages = {};

    for encIdx, encounter in pairs(encountersList) do
        local encounterImportantCnt = 0;
        local epSum = 0;

        encAmount = encAmount +1;

        importantUsages[encIdx] = {};
        importantUsages[encIdx]["EncName"] = encounter["EncName"];
        importantUsages[encIdx]["Count"] = 0;

        epSum = 0;
        print('eeID', encIdx, 'PL', playerName, encounter["Usages"][playerName], encounter["EncName"]);
        if encounter["Usages"][playerName] then
            print('eID', encIdx, 'PL', playerName, 'CNT', encounter["Usages"][playerName]["Count"]);
            for usageName, usageInfo in pairs(encounter["Usages"][playerName]["Usages"]) do
                if RaidEtalons[usageName]["isImportant"] and (RaidEtalons[usageName]["isWorldBuff"] == false or encIdx==1) then
                    encounterImportantCnt = encounterImportantCnt +1;

                    importantUsages[encIdx][encounterImportantCnt] = {};
                    importantUsages[encIdx][encounterImportantCnt]["name"] = RaidEtalons[usageName]["displayName"];
                    importantUsages[encIdx][encounterImportantCnt]["EP"] = RaidEtalons[usageName]["price"];
                    epSum = epSum + RaidEtalons[usageName]["price"];
                end
            end
        end

        wholeSum = wholeSum + epSum;
        importantUsages[encIdx]["epSum"] = epSum;
        importantUsages[encIdx]["Count"] = encounterImportantCnt;
        if maxPerEncounter < encounterImportantCnt then maxPerEncounter = encounterImportantCnt; end
    end

    return maxPerEncounter, wholeSum, importantUsages;
end

function formPlayerLinesForAllEncounters(playerName, encountersList)
    local lines = playerName;
    local maxPerEncounter = 0;
    local encAmount = table.getn(encountersList);

    local playerSum = 0;

    --print("encAMOUNT", encAmount);

    insertWorldBuffsIntoRaidStart(playerName, encountersList);

    -- Should make: ,USAGE_NAME,EP
    maxPerEncounter, playerSum, importantUsagesPerEncounters = importantsForPlayerOnAllEncounters(playerName, encountersList);
    
    for lineNo=1,maxPerEncounter do 

        for encNo=1,encAmount do
            if importantUsagesPerEncounters[encNo][lineNo] then
                --print("INS", encNo, lineNo);
                --print("C", importantUsagesPerEncounters[encNo][lineNo]);
                lines = lines .. CSV_DELIMITRIER .. importantUsagesPerEncounters[encNo][lineNo]["name"] .. CSV_DELIMITRIER .. importantUsagesPerEncounters[encNo][lineNo]["EP"];
            else
                lines = lines .. CSV_DELIMITRIER .. CSV_DELIMITRIER;
            end
        end

        lines = lines .. "\n";
    end

    -- SUM LINE
    lines = lines .. playerSum .. CSV_DELIMITRIER;
    for encNo=1,encAmount do
        --print("SL", lines);
        lines = lines .. "" .. CSV_DELIMITRIER .. importantUsagesPerEncounters[encNo]["epSum"] .. CSV_DELIMITRIER
    end

    lines = lines .. "\n";
    for encNo=1,encAmount do    -- Empty line to separate players
        lines = lines .. "" .. CSV_DELIMITRIER .. "" .. CSV_DELIMITRIER
    end

    lines = lines .. "\n";
    return lines;
end

function renderCSV(RaidNo)
    local result = "";

    result = result .. formEncountersLine(RaidNo).."\n";
    
    for playerName, playerInfo in pairs(RaidUsageLog["Raids"][RaidNo]["Players"]) do
        --print("REND", playerName);
        result = result .. formPlayerLinesForAllEncounters(playerName, RaidUsageLog["Raids"][RaidNo]["Encounters"]);
    end

    return result;
end

---------------------------------------------------------------------------------------------------------------------------
--  RENDER FUNCS END
---------------------------------------------------------------------------------------------------------------------------




---------------------------------------------------------------------------------------------------------------------------
--  RAID FUNCS
---------------------------------------------------------------------------------------------------------------------------


function raidRegisterPlayerInUsageList(playerClass, playerName, usageId, usageInfo, usageList)

    ------print("REGl", usageId, "into", usageList, "for", playerClass, playerName);

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
    ------print("ENCtime", encounterSeconds, curEncounter["TS"], GetTime());
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
    usageInstance["shotsCnt"] = shotsCnt;
    usageInstance["shots"][shotsCnt] = {
        ["encounterTime"] = encounterTimeStr;
        ["usageInfo"] = usageInfo;
    }
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

    return etalon;
end

function raidRegisterPlayerUsage(playerStr, usageData) -- prob should add usageInfo param
    local usageType, usageName, usageId, usageInfo = strsplit("/", usageData);
    local playerClass, playerName = strsplit("/", playerStr);

    ----print("REG", usageType, usageName, usageId, usageInfo, "for", playerStr);

    local isBuff = (usageType == "A");

    local etalon = tryGetEtalon(usageType, usageName, usageId, usageInfo, playerClass);

    if etalon["isWorldBuff"] then
        if curRaid then raidRegisterPlayerInUsageList(playerClass, playerName, usageId, usageInfo, curRaid["Encounters"][1]); end
    else
        if curEncounter then raidRegisterPlayerInUsageList(playerClass, playerName, usageId, usageInfo, curEncounter["Usages"]); end
    end

    if etalon["Type"] == "A" then
        local duration = strsplit("/", usageInfo);
        raidRegisterPlayerInUsageList(playerClass, playerName, usageId, usageInfo, curRaid["Buffs"]);
    end
end

function raidEncounterInit(tarName)
    if curRaid == nil then return; end
    curEncounter = nil;

    local encIdx = curRaid["EncountersCnt"]+1;
    curRaid["EncountersCnt"] = encIdx;

    curRaid["Encounters"][encIdx] = {};

        local encounterTitle = string.format ("%u) %s", encIdx, tarName);
        curRaid["Encounters"][encIdx]["EncName"] = encounterTitle;
        curRaid["Encounters"][encIdx]["EncNo"] = encIdx;
        ------print("ENC", curRaid["Encounters"][encIdx]["EncName"]);

        local TS = GetServerTime();
        curRaid["Encounters"][encIdx]["TS"] = TS;
        curRaid["Encounters"][encIdx]["Date"] = date("%d/%m/%y %H:%M:%S", TS);
        
        curRaid["Encounters"][encIdx]["Usages"] = {};
        curRaid["Encounters"][encIdx]["MaxCount"] = 0;

    curEncounter = curRaid["Encounters"][encIdx];
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
    raidInitRaid(instName);
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
    local playerName, realm = UnitName("player")

    local msg = "SH|"..   englishClass.."/"..playerName   .."|"..   spellType.."/"..spellName.."/"..spellId.."/"..spellInfo;
    ------print("SHOUTED", msg);
    C_ChatInfo.SendAddonMessage("TWOBS", msg, "RAID"); -- TODO - should swtich to GUILD or OFFICER (maybe u cannot write to officer?)
end

function shoutBuffs()
    local i = 1;
    while UnitAura("player", i, "HELPFUL") do

        --------print ("UA", UnitAura("player", i, "HELPFUL"));
        local name, rank, icon, count, duration, expirationTime, _, unitCaster, _, spellId = UnitAura("player", i, "HELPFUL");
        --------print ("UA2", expirationTime, spellId, name);

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


iEvent = 0;
function AddEventStr(msg)
    local i = iEvent;
    local frame = CreateFrame('Button', "EventStr" .. i, _G["Events_scrollframe_container"], "EventStrTemplate");
    if i > 0 then
        _G["EventStr" .. i]:SetPoint("TOPLEFT", _G["EventStr" .. i-1], "BOTTOMLEFT", 0, -2);
    else
        _G["EventStr" .. i]:SetPoint("TOPLEFT", _G["Events_scrollframe_container"], "TOPLEFT", 0, -10);
    end
    _G["EventStr" .. i .. "Info"]:SetText(i .. ") " .. msg);
    iEvent = iEvent + 1;
    frame:Show();
end

function handleDBMevent(...)
    local dpre, dtim, dinst, dtar = select(1, ...);
    if dpre == "PT" then
        ------print("PULL:",select(2,...));
        if dtar then
            ------print("TAR:", dtar); 
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
    
    ------print("ENTERING", name, "C", cnt, "L", isLogin, "R", isReload);

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
            if RaidUsageLog["Raids"][cnt] ~= name then
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

    ------print("NOW RAID", curRaid, curRaid["RaidName"]);
    ------print("NOW ENCOUNTER", curEncounter, curEncounter["EncName"]);
end

function TWObs_OnEvent(...)
    local event, arg1, arg2 = select(1,...);
    --------print("EVE", event);

    if event == "CHAT_MSG_ADDON" then
        local prefix, message, chat, sender = select(2,...);

        --------print("MSG", prefix);

        if prefix == "D4C" then
            handleDBMevent(strsplit("\t", message));
        end

        if prefix == "TWOBS" then
            ------print("TWmsg", message);
            local type, playerStr, usageData = strsplit("|", message);

            if type == "SH" then
                ----print("recSH", playerStr, usageData);
                raidRegisterPlayerUsage(playerStr, usageData);
            end

            if type == "EC" and message == "EC|START" then
                ------print("EC", message);
                startEncounter();
            end
            if type == "EC" and message == "EC|END" then
                ------print("EC", message);
                endEncounter();
            end
        end
    end
    
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellId = select(2,...);
        --------print("SCs", unit, castGUID, spellId);
        local spellName, rank, icon, castTime, minRange, maxRange, sId = GetSpellInfo(spellId);

        if inEncounter then shout("I", spellName, spellId, "INSTANT&"); end
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

        if dumps == nil then dumps = {}; end

        local regPrefixResult = C_ChatInfo.RegisterAddonMessagePrefix("TWOBS");
        ----print("RegPREFIX", regPrefixResult);
    end

    if event == "PLAYER_ENTERING_WORLD" then
        handleEnteringWorld(arg1, arg2);
    end

    if event == "READY_CHECK" then
        local playerName, realm = UnitName("player")
        if arg1 == playerName then shoutBuffs(); end
    end

    if event == "READY_CHECK_CONFIRM" then        
        if arg1 == "player" and arg2 then shoutBuffs(); end
    end
end

function TWOBS_formatExport()
    local formatedCSV = renderCSV(1);
    --print ("OUT", formatedCSV);

    TWOBS_export_dump:SetText(formatedCSV);
end

SLASH_TWOBS1 = "/twobs"
SlashCmdList["TWOBS"] = function(msg)
    local done = false;
    if msg == "start" then
        C_ChatInfo.SendAddonMessage("TWOBS", "EC|START", "RAID");
        done = true;
    end
   
    if msg == "end" then
        ------print("endCommand");
        C_ChatInfo.SendAddonMessage("TWOBS", "EC|END", "RAID");
        done = true;
    end
     
    if msg == "stat" then
        ------print("endCommand");
        ----print("inEncounter", inEncounter)
        done = true;
    end

    if done then
        return;
    end
    _G["TWObs_Frame"]:Show();
 end 