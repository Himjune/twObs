--message('My first addon2!');

function AddEventStr(msg)
    local i = 0;

    while _G["EventStr" .. i] do
        i = i + 1;
    end

    frame = CreateFrame('Button', "EventStr" .. i, _G["Events_scrollframe_container"], "EventStrTemplate");
    if i > 0 then
        _G["EventStr" .. i]:SetPoint("TOPLEFT", _G["EventStr" .. i-1], "BOTTOMLEFT", 0, -2);
    else
        _G["EventStr" .. i]:SetPoint("TOPLEFT", _G["Events_scrollframe_container"], "TOPLEFT", 0, -10);
    end
    _G["EventStr" .. i .. "Info"]:SetText(msg);
    frame:Show();
end

TWObs_Frame:Show();
AddEventStr("msg01");
AddEventStr("msg02");
AddEventStr("msg03");
AddEventStr("msg04");
AddEventStr("msg05");