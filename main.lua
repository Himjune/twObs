--message('My first addon2!');

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

function CLEvent(...)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
    local spellId, spellName, spellSchool, amount, overEnergize, powerType

    local is_mine = (sourceFlags%16 == 1);
    local sIs_mine = "NOT_MINE";
    if is_mine then
        sIs_mine = "MINE";
    end

    spellId, spellName, spellSchool = select(12, ...)
    
    if is_mine then
        AddEventStr("CL" .. " | " .. subevent .. " | " .. spellName .. " | " .. sIs_mine .. "->" .. sourceName);
    end
end

function TWObs_OnEvent(event)
    --AddEventStr(event);
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        CLEvent(CombatLogGetCurrentEventInfo());
    end
end