local curRaid = nil;
local curEncounter = nil;


---------------------------------------------------------------------------------------------------------------------------
--  RAID FUNCS
---------------------------------------------------------------------------------------------------------------------------


etalons = {
    ["Восполнение маны"] = {["name"]="Восполнение маны", ["isLongTerm"]=false, ["isBuff"]=false, ["price"]=0.5},
    ["Дух Занзы"] = {["name"]="Дух Занзы", ["isLongTerm"]=true, ["isBuff"]=true, ["price"]=1},
    ["Убойное пойло Крига"] = {["name"]="Убойное пойло Крига", ["isLongTerm"]=false, ["isBuff"]=true, ["price"]=0.5},
}

function raidRegisterPlayerInUsageList(player, etalon, usageList)
    if usageList[player] == nil then
        usageList[player] = {
            --["class"] = "priest",
            ["usages"] = {}
        }
    end

    usageName = etalon["name"];
    if usageList[player]["usages"][usageName] == nil then
        usageList[player]["usages"][usageName] = true;
    end
end

function raidRegisterPlayerUsage(player, usage)
    local etalon = etalons[usage];
    if etalon == nil then return; end

    if etalon["isLongTerm"] and curRaid then
        raidRegisterPlayerInUsageList(player, etalon, curRaid["LongTermUsages"]);
    else 
        if etalon["isBuff"] and curEncounter then
            raidRegisterPlayerInUsageList(player, etalon, curEncounter["Buffs"]);
        else 
            raidRegisterPlayerInUsageList(player, etalon, curEncounter["Usages"]);
        end
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
        print("ENC", curRaid["Encounters"][encIdx]["EncName"]);

        local TS = GetServerTime();
        curRaid["Encounters"][encIdx]["TS"] = TS;
        curRaid["Encounters"][encIdx]["Date"] = date("%d/%m/%y %H:%M:%S", TS);
        
        curRaid["Encounters"][encIdx]["Usages"] = {};

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

        RaidUsageLog["Raids"][raidIdx]["LongTermUsages"] = {};
        RaidUsageLog["Raids"][raidIdx]["Buffs"] = {};

    curRaid = RaidUsageLog["Raids"][raidIdx];
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


function shoutBuffs()
    local i = 1;
    while UnitAura("player", i, "HELPFUL") do
        local name, icon, count, debuffType, duration, expirationTime = UnitAura("player", i, "HELPFUL"); 
        AddEventStr("B: " .. name .. " | " .. (expirationTime - GetTime()) .. "/" .. duration);
        i = i + 1;
    end

    local hasMainHandEnchant, mainHandExpiration, mainHandCharges, mainHandEnchantID, hasOffHandEnchant, offHandExpiration, offHandCharges, offHandEnchantId = GetWeaponEnchantInfo();
    if hasMainHandEnchant then
        AddEventStr("WmH: " .. mainHandEnchantID .. " / " .. math.floor(mainHandExpiration/1000)/60);
    end
    if hasOffHandEnchant then
        AddEventStr("WoH: " .. offHandEnchantId .. " / " .. math.floor(offHandExpiration/1000)/60);
    end
end

function shoutUsage(...)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
    local spellId, spellName, spellSchool, amount, overEnergize, powerType

    local is_mine = (sourceFlags%16 == 1);
    if is_mine and subevent == "SPELL_AURA_APPLIED" then
        local spellId, spellName, spellSchool, auraType, amount = select(12, ...);
        
        AddEventStr("SAA" .. " |sId " .. spellId .. " |sN " .. spellName .. " |sS " .. spellSchool .. " |aT " .. auraType );

    end
    if is_mine and subevent == "SPELL_ENERGIZE" then
        local spellId, spellName, spellSchool = select(12, ...);
        local amount, overEnergize, powerType, alternatePowerType = select(15, ...);
        local msg = "SE" .. " |sID " .. spellId .. " |sN " .. spellName .. " |sS " .. spellSchool .. " |a " .. amount .. " |pT " .. powerType;
        if alternatePowerType then
            msg = msg  .. " |apT " .. alternatePowerType;
        end
        AddEventStr(msg);
    end

    if is_mine and subevent == "SPELL_HEAL" then
        local spellId, spellName, spellSchool = select(12, ...);
        local amount, overhealing, absorbed, critical = select(15, ...);
        local msg = "SH" .. " |sID " .. spellId .. " |sN " .. spellName .. " |sS " .. spellSchool .. " |a " .. amount;
        AddEventStr(msg);
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
        print("PULL:",select(2,...));
        if dtar then
            print("TAR:", dtar); 
        else
            dtar = "Unknown";
        end

        print("PT", dtar, curRaid);
        raidEncounterInit(dtar);

        --local zoneName = GetRealZoneText();
        --message("Zone: "..zoneName);
        --print(GetNumSavedInstances(), 'ata', GetSavedInstanceInfo(2), ' tw2 ', GetSavedInstanceInfo(0));
        --Print_Buffs();
    end
end

function handleEnteringWorld(isLogin, isReload)
    local name, type, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapId, lfgID = GetInstanceInfo();
    
    print('ENT', name, type);
    if isReload == false then--(type == "party" or type == "raid") then
        print('ENT RAID', name);
        raidHandleEntering(name);
    end

    print("rl", RaidUsageLog["RaidName"]);
end

function TWObs_OnEvent(...)
    local event, arg1, arg2 = select(1,...);
    --print("EVE", event);

    if event == "CHAT_MSG_ADDON" then
        local prefix, message, chat, sender = select(2,...);

        --print("MSG", prefix);

        if prefix == "D4C" then
            --print("D4C");
            handleDBMevent(strsplit("\t", message));
        end
    end

    --AddEventStr(event);
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        --CLEvent(CombatLogGetCurrentEventInfo());
    end

    if event == "ADDON_LOADED" and arg1 == "twObs" then
        if RaidUsageLog == nil then
            RaidUsageLog = {};
            RaidUsageLog["Count"] = 0;
            RaidUsageLog["Raids"] = {};
        end
    end

    if event == "PLAYER_ENTERING_WORLD" then
        handleEnteringWorld(arg1, arg2);
    end
end

SLASH_TWOBS1 = "/twobs"
SlashCmdList["TWOBS"] = function(msg)
   print("Hello World!")
    _G["TWObs_Frame"]:Show();
 end 