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
    spellId, spellName, spellSchool, amount, overEnergize, powerType = select(12, ...)
    AddEventStr("CL" .. " | " .. subevent .. " | " .. spellName .. " | " .. spellSchool .. " | " .. powerType);
    
end

function TWObs_OnEvent(event)
    --AddEventStr(event);
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        CLEvent(CombatLogGetCurrentEventInfo());
    end
end

TWObs_Frame:Show();
AddEventStr("msg01");
AddEventStr("msg02");
AddEventStr("msg03");
AddEventStr("msg04");
AddEventStr("msg05");