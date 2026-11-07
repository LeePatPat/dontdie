local _, addon = ...

local Core = {}
addon.Core = Core

local rules = {
    level = { title = "Level up!", exercise = "star jumps", count = 20 },
    area = { title = "New area discovered", exercise = "squats", count = 10 },
    wipe = { title = "Dungeon wipe", exercise = "push ups", count = 10 },
    stretch = { title = "Missed flight break", exercise = "stretch breaks", count = 1,
        text = "Stand up and stretch for one break." },
}

local function taskKind(task)
    if task.kind then return task.kind end
    for kind, rule in pairs(rules) do
        if task.title == rule.title then return kind end
    end
end

function Core:Init(database, changed)
    self.db = database
    self.db.queue = self.db.queue or {}
    self.db.history = self.db.history or { totals = {}, recent = {} }
    self.changed = changed
    self.combat = false
    self.flying = false
    self.flightSkipped = self.db.flightSkipped or false
    self.snoozed = false
    -- Do not count logging into an already-dead party as a fresh wipe.
    self.wipeArmed = false
end

function Core:Add(kind)
    local rule = rules[kind]
    if not rule then return end
    table.insert(self.db.queue, {
        kind = kind,
        title = rule.title,
        text = rule.text or ("Do " .. rule.count .. " " .. rule.exercise .. "."),
    })
    self.snoozed = false
    self.changed()
end

function Core:SetCombat(active)
    self.combat = active
    self.changed()
end

function Core:SetFlight(active)
    if self.flying == active then
        if not active and self.flightSkipped then
            self.flightSkipped = false
            self.db.flightSkipped = nil
        end
        return
    end
    if self.flying and not active and not self.flightSkipped then
        self:Record("flight")
    end
    self.flying = active
    if active then
        self.snoozed = false
    else
        self.flightSkipped = false
        self.db.flightSkipped = nil
    end
    self.changed()
end

function Core:CheckWipe(allDead)
    -- nil means unavailable or restricted data; never infer a wipe from it.
    if allDead == nil then return end
    if not allDead then
        self.wipeArmed = true
    elseif self.wipeArmed then
        self.wipeArmed = false
        self:Add("wipe")
    end
end

function Core:ResetWipe()
    self.wipeArmed = false
end

function Core:Current()
    if self.combat then return end
    if self.flying and not self.flightSkipped then
        return "flight", "Flight break", "Stand up and stretch until you land."
    end
    -- Repetition exercises wait until the player is back on the ground.
    if self.flying then return end
    if self.snoozed then return end
    local task = self.db.queue[1]
    if task then return task, task.title, task.text end
end

function Core:DebtText()
    local totals, other = {}, 0
    for _, task in ipairs(self.db.queue) do
        local kind = taskKind(task)
        local rule = rules[kind]
        if rule then
            totals[kind] = (totals[kind] or 0) + rule.count
        else
            other = other + 1
        end
    end
    local lines = {}
    for _, kind in ipairs({ "level", "area", "wipe", "stretch" }) do
        local count = totals[kind]
        if count then
            local exercise = kind == "stretch" and count == 1 and "stretch break" or rules[kind].exercise
            lines[#lines + 1] = count .. " " .. exercise
        end
    end
    if other > 0 then lines[#lines + 1] = other .. " other exercise(s)" end
    if #lines == 0 then return "" end
    return "Still owed (including this exercise):\n" .. table.concat(lines, "\n")
end

function Core:Record(kind, task)
    local rule = rules[kind]
    local history = self.db.history
    local count = rule and rule.count or 1
    local text = rule and (count .. " " .. rule.exercise) or
        (kind == "flight" and "Flight stretch break (automatic)" or task.text)
    local totalKey = rule and rule.exercise or (kind == "flight" and "flight breaks" or "other exercises")
    history.totals[totalKey] = (history.totals[totalKey] or 0) + count
    table.insert(history.recent, 1, { timestamp = time(), text = text })
    if #history.recent > 10 then table.remove(history.recent) end
end

function Core:HistoryLines()
    local history = self.db.history
    local totals = history.totals
    local lines = {
        "Don't Die history - this character",
        string.format("Totals: %d star jumps, %d squats, %d push ups, %d flight breaks (automatic).",
            totals["star jumps"] or 0, totals.squats or 0, totals["push ups"] or 0,
            totals["flight breaks"] or 0),
    }
    if totals["other exercises"] then
        lines[#lines + 1] = "Other completed exercises: " .. totals["other exercises"]
    end
    if totals["stretch breaks"] then
        lines[#lines + 1] = "Completed missed-flight stretch breaks: " .. totals["stretch breaks"]
    end
    if #history.recent == 0 then
        lines[#lines + 1] = "No completions recorded yet. Use Done after completing an exercise."
    else
        lines[#lines + 1] = "Latest completions (up to 10):"
        for _, entry in ipairs(history.recent) do
            lines[#lines + 1] = date("%Y-%m-%d %H:%M", entry.timestamp) .. " - " .. entry.text
        end
    end
    return lines
end

function Core:Dismiss(completed)
    local current = self:Current()
    if current == "flight" then
        self.flightSkipped = true
        self.db.flightSkipped = true
        self:Add("stretch")
        self.snoozed = true
    elseif current then
        if completed then
            -- Reminders saved before history support have no kind field.
            self:Record(taskKind(current), current)
            table.remove(self.db.queue, 1)
        else
            self.snoozed = true
        end
    end
    self.changed()
end
