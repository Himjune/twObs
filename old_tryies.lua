

function CLEvent(...)
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

function Print_Buffs()
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