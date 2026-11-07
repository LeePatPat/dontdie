local addonName, addon = ...
local Core = addon.Core
local frame = CreateFrame("Frame")
local ready = false
local elapsed = 0
local explorationPatterns = {}

local function readable(value)
    return not issecretvalue or not issecretvalue(value)
end

-- Match the client's localized discovery messages, including positional formats.
local function formatPattern(format)
    local marker = "\001"
    local pattern = format:gsub("%%[%d]+%$[sd]", marker):gsub("%%[sd]", marker)
    pattern = pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    return "^" .. pattern:gsub(marker, ".+") .. "$"
end

local function pollWipe()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "party" or not IsInGroup() then
        Core:ResetWipe()
        return
    end
    -- Modern clients may hide unit state in combat. Inspect only after combat.
    if InCombatLockdown() then return end
    local playerDead = UnitIsDeadOrGhost("player")
    if not readable(playerDead) then return end
    local allDead = not not playerDead
    local count = 0
    for index = 1, GetNumSubgroupMembers() do
        local unit = "party" .. index
        local connected = UnitIsConnected(unit)
        local visible = UnitIsVisible(unit)
        if not readable(connected) or not readable(visible) then return end
        -- Unknown, disconnected, or distant members could still be alive.
        if not connected or not visible then return end
        local dead = UnitIsDeadOrGhost(unit)
        if not readable(dead) then return end
        allDead = allDead and not not dead
        count = count + 1
    end
    if count > 0 then Core:CheckWipe(allDead) end
end

local function poll()
    if not ready then return end
    local flying = UnitOnTaxi("player")
    if readable(flying) then
        if Core.flying and not flying and not Core.flightSkipped then
            PlaySound(SOUNDKIT.RAID_WARNING, "Master")
            print("|cffffd15bDon't Die:|r Flight finished. Stretch break complete.")
        end
        Core:SetFlight(not not flying)
    end
    pollWipe()
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        DontDieDB = DontDieDB or {}
        Core:Init(DontDieDB, function() addon:Refresh() end)
        addon:CreateUI()
        for _, key in ipairs({ "ERR_ZONE_EXPLORED_XP", "ERR_ZONE_EXPLORED" }) do
            if type(_G[key]) == "string" then
                table.insert(explorationPatterns, formatPattern(_G[key]))
            end
        end
        ready = true
        Core:SetCombat(InCombatLockdown())
        return
    end
    if not ready then return end
    if event == "PLAYER_LEVEL_UP" then
        Core:Add("level")
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        if not readable(message) or type(message) ~= "string" then return end
        for _, pattern in ipairs(explorationPatterns) do
            if message:match(pattern) then
                Core:Add("area")
                break
            end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        Core:SetCombat(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Core:SetCombat(false)
        poll()
    elseif event == "PLAYER_ENTERING_WORLD" then
        Core:ResetWipe()
        Core:SetCombat(InCombatLockdown())
        poll()
    elseif event == "GROUP_ROSTER_UPDATE" then
        Core:ResetWipe()
        poll()
    end
end)

frame:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed < 0.5 then return end
    elapsed = 0
    poll()
end)

SLASH_DONTDIE1 = "/dontdie"
SLASH_DONTDIE2 = "/dd"
SlashCmdList.DONTDIE = function(message)
    if not ready then return end
    local command = message:lower():match("^%s*(.-)%s*$")
    if command == "test" then
        Core:Add("level")
    elseif command == "wipe" then
        Core:Add("wipe")
    elseif command == "done" or command == "skip" then
        Core:Dismiss(command == "done")
    elseif command == "history" then
        for _, line in ipairs(Core:HistoryLines()) do print(line) end
    elseif command == "debt" then
        local debt = Core:DebtText()
        if debt == "" then
            print("No exercises owed.")
        else
            debt = debt:gsub("^[^\n]+", "Still owed:", 1)
            for line in debt:gmatch("[^\n]+") do print(line) end
        end
    else
        print("|cffffd15bDon't Die:|r /dd test, /dd done, /dd skip, /dd history, /dd debt, /dd wipe (manual wipe reminder)")
    end
end
