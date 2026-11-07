local addon = {}
time = os.time
date = os.date
assert(loadfile("DontDie/Core.lua"))("DontDie", addon)
local Core = addon.Core
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end
local function reset(database)
    Core:Init(database or {}, function() end)
end

reset()
Core:Add("level")
Core:Add("area")
check(#Core.db.queue == 2, "Events must queue without overwriting")
local _, title, text = Core:Current()
check(title == "Level up!" and text == "Do 20 star jumps.", "Level exercise")
Core:SetCombat(true)
check(Core:Current() == nil, "Combat hides exercises")
Core:Dismiss()
check(#Core.db.queue == 2, "Hidden exercises cannot be dismissed")
Core:SetCombat(false)
Core:SetFlight(true)
check(Core:Current() == "flight", "Flight takes priority")
Core:Dismiss()
check(Core:Current() == nil and #Core.db.queue == 3, "Skip flight preserves exercises and adds stretch debt")
Core:SetFlight(false)
check(Core:Current() == nil, "Landing does not immediately reopen skipped work")
Core:Add("wipe")
Core:Dismiss(true)
local _, _, areaText = Core:Current()
check(areaText == "Do 10 squats.", "Queue resumes after landing")
Core:SetFlight(true)
check(Core:Current() == "flight", "Next flight restores stretch reminder")
local saved = Core.db
reset(saved)
check(#Core.db.queue == 3, "Pending exercises and stretch debt survive reload")

reset()
Core:CheckWipe(true)
check(#Core.db.queue == 0, "Already-dead party at login is not a wipe")
Core:CheckWipe(false)
Core:CheckWipe(nil)
Core:CheckWipe(true)
Core:CheckWipe(true)
check(#Core.db.queue == 1, "One reminder per all-dead transition")
Core:CheckWipe(false)
Core:CheckWipe(true)
check(#Core.db.queue == 2, "Later wipes count")

-- Exercise actual event routing with a small client API mock.
local frame
function CreateFrame()
    frame = { scripts = {}, events = {} }
    function frame:RegisterEvent(event) self.events[event] = true end
    function frame:SetScript(event, handler) self.scripts[event] = handler end
    return frame
end
local combat, flying, inDungeon = false, false, false
local dead, connected, visible = {}, {}, {}
local secret = {}
function issecretvalue(value) return value == secret end
function InCombatLockdown() return combat end
function UnitOnTaxi() return flying end
function IsInInstance() return inDungeon, inDungeon and "party" or "none" end
function IsInGroup() return true end
function GetNumSubgroupMembers() return 2 end
function UnitIsDeadOrGhost(unit) return dead[unit] or false end
function UnitIsConnected(unit) return connected[unit] ~= false end
function UnitIsVisible(unit) return visible[unit] ~= false end
ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained"
ERR_ZONE_EXPLORED = "Discovered %s."
SlashCmdList = {}
SOUNDKIT = { RAID_WARNING = 8959 }
local sounds = 0
function PlaySound() sounds = sounds + 1 end
function addon:CreateUI() end
function addon:Refresh() end
DontDieDB = nil
assert(loadfile("DontDie/Events.lua"))("DontDie", addon)
local function event(name, ...) frame.scripts.OnEvent(frame, name, ...) end
local function tick() frame.scripts.OnUpdate(frame, 0.5) end
event("ADDON_LOADED", "Unrelated")
check(DontDieDB == nil, "Ignore unrelated addon loads")
event("ADDON_LOADED", "DontDie")
event("PLAYER_ENTERING_WORLD")
event("CHAT_MSG_SYSTEM", "Unrelated system message")
event("CHAT_MSG_SYSTEM", secret)
check(#Core.db.queue == 0, "Ignore unrelated and restricted messages")
event("CHAT_MSG_SYSTEM", "Discovered Elwynn Forest: 100 experience gained")
event("CHAT_MSG_SYSTEM", "Discovered Stormwind.")
check(#Core.db.queue == 2, "Discovery messages with and without XP")
event("PLAYER_LEVEL_UP", 12)
check(#Core.db.queue == 3, "Level event")
combat = true
event("PLAYER_REGEN_DISABLED")
check(Core:Current() == nil, "Combat event hides reminder")
combat = false
event("PLAYER_REGEN_ENABLED")
flying = true
tick()
check(Core:Current() == "flight", "Taxi polling starts stretch")
flying = false
tick()
check(Core:Current() ~= "flight", "Landing ends stretch")
check(sounds == 1, "Landing sounds an alert")

inDungeon = true
tick()
dead.player, dead.party1 = true, true
tick()
check(#Core.db.queue == 3, "One survivor prevents wipe")
dead.party2 = true
combat = true
tick()
check(#Core.db.queue == 3, "Never inspect party deaths in combat")
combat = false
tick()
tick()
check(#Core.db.queue == 4, "Trash wipe detected once after combat")
dead.player = false
tick()
connected.party2 = false
dead.player = true
tick()
check(#Core.db.queue == 4, "Disconnected member prevents uncertain wipe")
connected.party2 = true
dead.party2 = secret
tick()
check(#Core.db.queue == 4, "Restricted death state prevents uncertain wipe")
dead.party2 = false
tick()
inDungeon = false
dead.party2 = true
tick()
check(#Core.db.queue == 4, "Outdoor deaths do not count")
SlashCmdList.DONTDIE("wipe")
check(#Core.db.queue == 5, "Manual wipe fallback")

-- Reload with a localized format that uses positional parameters and punctuation.
ERR_ZONE_EXPLORED_XP = "Entdeckt: %1$s (%2$d EP)."
event("ADDON_LOADED", "DontDie")
local before = #Core.db.queue
event("CHAT_MSG_SYSTEM", "Entdeckt: Wald von Elwynn (100 EP).")
event("CHAT_MSG_SYSTEM", "Entdeckt: Wald von Elwynn 100 EP")
check(#Core.db.queue == before + 1, "Localized positional formats escape punctuation")

-- History records completion, not dismissal, and preserves old saved reminders.
reset({ queue = { { title = "Level up!", text = "Do 20 star jumps." } } })
check(#Core.db.history.recent == 0, "Existing saves start with empty history")
Core:Dismiss(true)
check(Core.db.history.totals["star jumps"] == 20, "Legacy queued exercise counts on completion")
Core:Add("area")
Core:Dismiss(false)
check(Core.db.history.totals.squats == nil, "Skipped exercise does not count")
Core:SetCombat(true)
Core:Dismiss(true)
check(Core.db.history.totals.squats == nil and #Core.db.queue == 1,
    "Cannot complete a hidden exercise during combat")
Core:SetCombat(false)
Core:Add("wipe")
SlashCmdList.DONTDIE("done")
check(Core.db.history.totals.squats == 10, "Done command records repetitions")
SlashCmdList.DONTDIE("skip")
check(Core.db.history.totals["push ups"] == nil, "Skip command does not record repetitions")
Core:Add("level")
Core:Dismiss(true)
check(Core.db.history.totals["push ups"] == 10, "Push up completion counted")
Core:Dismiss(true)
Core:SetFlight(true)
Core:SetFlight(false)
Core:SetFlight(false)
check(Core.db.history.totals["flight breaks"] == 1, "Unskipped flight counts once on landing")
Core:SetFlight(true)
Core:Dismiss(false)
Core:SetFlight(false)
check(Core.db.history.totals["flight breaks"] == 1, "Skipped flight does not count")
Core:Add("area")
Core:Dismiss(true)
check(Core.db.history.totals["stretch breaks"] == 1, "Missed flight debt counts only when manually completed")
Core:Dismiss(true)
for _ = 1, 12 do Core:Add("level"); Core:Dismiss(true) end
check(#Core.db.history.recent == 10 and Core.db.history.totals["star jumps"] == 280,
    "Keep latest ten records while retaining all-time totals")
local historySave = Core.db
reset(historySave)
check(Core.db.history.totals["star jumps"] == 280 and #Core.db.history.recent == 10,
    "History survives reload")
check(type(Core.db.history.recent[1].timestamp) == "number", "Record completion time")
local output = {}
local originalPrint = print
print = function(line) output[#output + 1] = line end
SlashCmdList.DONTDIE(" history ")
print = originalPrint
check(#output == 14 and output[2]:find("280 star jumps") and output[5]:find("20 star jumps"),
    "History command prints totals and timestamped recent entries")
reset()
check(Core:HistoryLines()[3]:find("No completions"), "Empty history gives useful guidance")

-- Skips preserve debt and snooze until a new reminder trigger.
Core:Add("level")
Core:Dismiss(false)
check(#Core.db.queue == 1 and Core:Current() == nil, "Skip retains owed task and closes popup")
Core:SetCombat(true)
Core:SetCombat(false)
Core:SetFlight(false)
check(Core:Current() == nil, "Combat changes and repeated polls do not end snooze")
Core:Add("area")
check(Core:Current() == Core.db.queue[1], "Next trigger resumes oldest owed task")
local debt = Core:DebtText()
check(debt:find("20 star jumps") and debt:find("10 squats"), "Summary lists old debt and new work")
Core:Dismiss(false)
Core:Dismiss(false)
check(#Core.db.queue == 2 and #Core.db.history.recent == 0, "Repeated skip neither duplicates debt nor records completion")
local debtSave = Core.db
reset(debtSave)
check(#Core.db.queue == 2 and Core:Current() ~= nil, "Reload preserves debt and resumes reminder")
Core:Dismiss(true)
check(#Core.db.queue == 1 and Core.db.history.totals["star jumps"] == 20,
    "Done removes only current debt and records it once")
Core:Dismiss(true)
check(#Core.db.queue == 0 and Core:DebtText() == "", "Completing all debt clears summary")

Core:SetFlight(true)
Core:Dismiss(false)
check(#Core.db.queue == 1 and Core.db.queue[1].kind == "stretch", "Skipped flight creates one owed stretch")
local flightSave = Core.db
reset(flightSave)
Core:SetFlight(true)
Core:Dismiss(false)
check(#Core.db.queue == 1, "Reloading and skipping the same flight cannot duplicate debt")
Core:SetFlight(false)
Core:SetFlight(true)
Core:Dismiss(false)
check(#Core.db.queue == 2, "A different skipped flight adds its own stretch debt")
check(Core:DebtText():find("2 stretch breaks"), "Debt summary aggregates multiple skipped flights")

-- Listing debt must not alter reminders or completion state.
local function commandOutput(command)
    local lines = {}
    local savedPrint = print
    print = function(line) lines[#lines + 1] = line end
    SlashCmdList.DONTDIE(command)
    print = savedPrint
    return lines
end
reset()
local debtOutput = commandOutput("debt")
check(#debtOutput == 1 and debtOutput[1] == "No exercises owed.", "Debt command handles empty queue")
Core:Add("level")
Core:Add("level")
Core:Add("area")
Core:Add("wipe")
Core:Add("stretch")
Core:Dismiss(false)
local debtQueue = Core.db.queue
local debtHistory = Core.db.history
debtOutput = commandOutput("  DEBT  ")
check(#debtOutput == 5 and debtOutput[1] == "Still owed:", "Debt command accepts case and whitespace without popup wording")
check(debtOutput[2] == "40 star jumps" and debtOutput[3] == "10 squats" and
    debtOutput[4] == "10 push ups" and debtOutput[5] == "1 stretch break",
    "Debt command aggregates each outstanding exercise on its own line")
check(Core.snoozed and Core:Current() == nil, "Debt listing preserves skipped reminder snooze")
check(Core.db.queue == debtQueue and #debtQueue == 5 and debtQueue[1].kind == "level",
    "Debt listing preserves queue and order")
check(Core.db.history == debtHistory and #debtHistory.recent == 0 and next(debtHistory.totals) == nil,
    "Debt listing never records completion")
Core:SetCombat(true)
check(#commandOutput("debt") == 5 and Core.combat, "Debt command works during combat without changing combat state")
Core:SetCombat(false)
Core:SetFlight(true)
check(#commandOutput("debt") == 5 and Core.flying and Core:Current() == "flight",
    "Debt command works during flight without changing flight reminder")
check(commandOutput("")[1]:find("/dd debt", 1, true), "Slash help includes debt command")

-- Use the actual reminder buttons and font strings to verify debt presentation.
local widgets = {}
local Widget = {}
Widget.__index = Widget
for _, method in ipairs({ "SetSize", "SetPoint", "SetFrameStrata", "SetClampedToScreen",
    "SetMovable", "EnableMouse", "RegisterForDrag", "SetBackdrop", "SetBackdropColor",
    "SetBackdropBorderColor", "SetWidth", "SetJustifyH", "StartMoving", "StopMovingOrSizing" }) do
    Widget[method] = function() end
end
function Widget:SetScript(eventName, handler) self.scripts[eventName] = handler end
function Widget:SetText(text) self.text = text end
function Widget:Show() self.shown = true end
function Widget:Hide() self.shown = false end
function Widget:SetShown(shown) self.shown = shown end
function CreateFrame(_, name)
    local control = setmetatable({ scripts = {}, shown = true }, Widget)
    widgets[#widgets + 1] = control
    if name then _G[name] = control end
    return control
end
function Widget:CreateFontString() return CreateFrame() end
assert(loadfile("DontDie/UI.lua"))("DontDie", addon)
Core:Init({}, function() addon:Refresh() end)
addon:CreateUI()
local doneButton, skipButton, debtLabel
for _, control in ipairs(widgets) do
    if control.text == "Done" then doneButton = control end
    if control.text == "Skip" then skipButton = control end
end
Core:Add("level")
skipButton.scripts.OnClick()
check(not DontDieReminder.shown and #Core.db.queue == 1,
    "Actual Skip button hides reminder while preserving debt")
Core:Add("area")
for _, control in ipairs(widgets) do
    if control.text and control.text:find("Still owed") then debtLabel = control end
end
check(DontDieReminder.shown and debtLabel and debtLabel.text:find("20 star jumps") and
    debtLabel.text:find("10 squats"), "Next popup renders old debt and new work")
doneButton.scripts.OnClick()
check(#Core.db.queue == 1 and Core.db.history.totals["star jumps"] == 20 and
    not debtLabel.text:find("star jumps"), "Actual Done button clears only current exercise and updates debt")
Core:Add("wipe")
check(debtLabel.text:find("10 squats") and debtLabel.text:find("10 push ups"),
    "Popup refreshes debt even when current exercise stays the same")
print("Passed " .. checks .. " checks")
