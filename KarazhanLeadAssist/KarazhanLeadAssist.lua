local addonName, ns = ...
local data = ns.data

local addon = CreateFrame("Frame")
ns.addon = addon

local function trim(s)
    if not s then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function splitLines(text)
    local lines = {}
    text = tostring(text or "")
    text = text:gsub("\r\n", "\n")
    if text == "" then
        return lines
    end
    for line in text:gmatch("([^\n]*)\n?") do
        if line == "" and #lines > 0 and lines[#lines] == "" then
        else
            table.insert(lines, line)
        end
    end
    while #lines > 0 and lines[#lines] == "" do
        table.remove(lines)
    end
    return lines
end

local function buildChunks(prefix, text, maxLen)
    local chunks = {}
    local current = prefix or ""
    local function pushCurrent()
        if trim(current) ~= "" then
            table.insert(chunks, current)
        end
        current = ""
    end

    for _, rawLine in ipairs(splitLines(text)) do
        local line = trim(rawLine)
        if line == "" then
            pushCurrent()
        else
            if current == "" then
                current = line
            elseif #current + 1 + #line <= maxLen then
                current = current .. " " .. line
            else
                pushCurrent()
                if #line <= maxLen then
                    current = line
                else
                    local remaining = line
                    while #remaining > maxLen do
                        table.insert(chunks, remaining:sub(1, maxLen))
                        remaining = remaining:sub(maxLen + 1)
                    end
                    current = remaining
                end
            end
        end
    end
    pushCurrent()
    return chunks
end

local function ensureDB()
    if type(KarazhanLeadAssistDB) ~= "table" then
        KarazhanLeadAssistDB = {}
    end
    local db = KarazhanLeadAssistDB
    db.mode = db.mode or "bosses"
    db.current = db.current or { bosses = "attumen", trash = "stables", utilities = "weeklyprep" }
    db.notes = db.notes or { bosses = {}, trash = {}, utilities = {} }
    db.frame = db.frame or { point = "CENTER", x = 0, y = 0, width = 980, height = 700 }
    return db
end

local function getList(mode)
    return data[mode] or {}
end

local function getFirstId(mode)
    local list = getList(mode)
    return list[1] and list[1].id or nil
end

local function getEntryById(mode, id)
    for _, entry in ipairs(getList(mode)) do
        if entry.id == id then
            return entry
        end
    end
end

local function getCurrentEntry()
    local db = ensureDB()
    local mode = db.mode
    local id = db.current[mode] or getFirstId(mode)
    local entry = getEntryById(mode, id)
    if not entry then
        id = getFirstId(mode)
        db.current[mode] = id
        entry = getEntryById(mode, id)
    end
    return entry, mode
end

local function getNotesBucket(mode, id)
    local db = ensureDB()
    db.notes[mode] = db.notes[mode] or {}
    db.notes[mode][id] = db.notes[mode][id] or {
        a1 = "",
        a2 = "",
        a3 = "",
        custom = "",
    }
    return db.notes[mode][id]
end

local function createBackdropFrame(frameType, name, parent)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame(frameType, name, parent, template)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
        frame:SetBackdropBorderColor(0.75, 0.65, 0.3, 1)
    end
    return frame
end

local function safeSetFontObject(region, fontName)
    local fontObject = _G[fontName]
    if fontObject and region and region.SetFontObject then
        region:SetFontObject(fontObject)
    end
end

local function createLabel(parent, text, size)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if size == "small" then
        safeSetFontObject(fs, "GameFontHighlightSmall")
    elseif size == "large" then
        safeSetFontObject(fs, "GameFontHighlight")
    end
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    return fs
end

local function createSingleLineEditBox(parent, width, height)
    local box = createBackdropFrame("EditBox", nil, parent)
    box:SetSize(width, height)
    box:SetAutoFocus(false)
    safeSetFontObject(box, "GameFontHighlightSmall")
    box:SetTextInsets(8, 8, 6, 6)
    box:SetMultiLine(false)
    box:EnableMouse(true)
    return box
end

local function createScrollEditBox(parent, width, height, readOnly)
    local holder = createBackdropFrame("Frame", nil, parent)
    holder:SetSize(width, height)

    local scroll = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    safeSetFontObject(edit, "GameFontHighlightSmall")
    edit:SetWidth(width - 42)
    edit:SetHeight(math.max(height * 2, 600))
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")
    edit:SetTextInsets(4, 4, 4, 4)
    edit:EnableMouse(true)
    scroll:SetScrollChild(edit)

    if readOnly then
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        edit:SetScript("OnTextChanged", function(self)
            self:SetCursorPosition(0)
            scroll:SetVerticalScroll(0)
        end)
        edit:HighlightText(0, 0)
        edit:SetScript("OnEditFocusGained", function(self) self:ClearFocus() end)
    else
        edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        edit:SetScript("OnTextChanged", function(self)
            scroll:UpdateScrollChildRect()
        end)
        edit:SetScript("OnCursorChanged", function(_, _, y, _, h)
            local offset = scroll:GetVerticalScroll()
            local view = scroll:GetHeight()
            if y < offset then
                scroll:SetVerticalScroll(y)
            elseif (y + h) > (offset + view) then
                scroll:SetVerticalScroll(y + h - view)
            end
        end)
    end

    holder.scroll = scroll
    holder.edit = edit
    return holder
end

local function getGroupChannel()
    local inRaid = (IsInRaid and IsInRaid()) or (GetNumRaidMembers and GetNumRaidMembers() > 0)
    local inParty = (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0)
    if inRaid then
        local canWarn = (UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
        if canWarn then
            return "RAID_WARNING"
        end
        return "RAID"
    elseif inParty then
        return "PARTY"
    end
    return nil
end

local function sendLines(lines)
    local channel = getGroupChannel()
    if not channel then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Not in a group. Printing locally.")
        for _, line in ipairs(lines) do
            DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r " .. line)
        end
        return
    end
    for _, line in ipairs(lines) do
        if trim(line) ~= "" then
            SendChatMessage(line, channel)
        end
    end
end

local function formatEntryNotes(entry)
    local out = {}
    table.insert(out, entry.name)
    table.insert(out, string.rep("=", #entry.name))
    table.insert(out, "")
    for _, section in ipairs(entry.sections or {}) do
        table.insert(out, section[1] .. ":")
        table.insert(out, section[2])
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

local ui = {
    tabs = {},
}

local function setSelectedTab(mode)
    for key, button in pairs(ui.tabs) do
        if key == mode then
            button:LockHighlight()
            button:SetAlpha(1)
        else
            button:UnlockHighlight()
            button:SetAlpha(0.7)
        end
    end
end

local function saveFramePosition()
    local db = ensureDB()
    local point, _, _, x, y = ui.frame:GetPoint(1)
    db.frame.point = point
    db.frame.x = x
    db.frame.y = y
    db.frame.width = ui.frame:GetWidth()
    db.frame.height = ui.frame:GetHeight()
end

local function updateDropdown()
    local db = ensureDB()
    local mode = db.mode
    UIDropDownMenu_Initialize(ui.dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, entry in ipairs(getList(mode)) do
            info.text = entry.name
            info.value = entry.id
            info.func = function()
                db.current[mode] = entry.id
                UIDropDownMenu_SetSelectedValue(ui.dropdown, entry.id)
                if ns.RefreshUI then ns.RefreshUI() end
            end
            info.checked = (db.current[mode] == entry.id)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetWidth(ui.dropdown, 280)
    UIDropDownMenu_SetSelectedValue(ui.dropdown, db.current[mode])
    local entry = getEntryById(mode, db.current[mode])
    UIDropDownMenu_SetText(ui.dropdown, entry and entry.name or "Select entry")
end

local function updateNotesFields(entry, mode)
    local saved = getNotesBucket(mode, entry.id)
    local labels = entry.assignLabels or {"Assignment 1", "Assignment 2", "Assignment 3"}
    ui.assign1Label:SetText(labels[1] or "Assignment 1")
    ui.assign2Label:SetText(labels[2] or "Assignment 2")
    ui.assign3Label:SetText(labels[3] or "Assignment 3")

    ui.assign1:SetText(saved.a1 or "")
    ui.assign2:SetText(saved.a2 or "")
    ui.assign3:SetText(saved.a3 or "")
    ui.custom.edit:SetText(saved.custom or "")
    ui.custom.scroll:SetVerticalScroll(0)
end

function ns.RefreshUI()
    local entry, mode = getCurrentEntry()
    if not entry then return end
    ui.header:SetText(entry.name)
    ui.modeLabel:SetText((mode == "bosses" and "Bosses") or (mode == "trash" and "Trash") or "Utilities")
    ui.notes.edit:SetText(formatEntryNotes(entry))
    ui.notes.scroll:SetVerticalScroll(0)
    updateDropdown()
    updateNotesFields(entry, mode)
    setSelectedTab(mode)
end

local function saveCurrentNotes()
    local entry, mode = getCurrentEntry()
    if not entry then return end
    local saved = getNotesBucket(mode, entry.id)
    saved.a1 = ui.assign1:GetText() or ""
    saved.a2 = ui.assign2:GetText() or ""
    saved.a3 = ui.assign3:GetText() or ""
    saved.custom = ui.custom.edit:GetText() or ""
end

local function announceStrategy()
    saveCurrentNotes()
    local entry, mode = getCurrentEntry()
    if not entry then return end
    local lines = {}
    for _, line in ipairs(entry.announce or {}) do
        table.insert(lines, line)
    end
    local customText = trim(ui.custom.edit:GetText() or "")
    if customText ~= "" then
        local customChunks = buildChunks("Lead note: ", customText, 220)
        for _, chunk in ipairs(customChunks) do
            table.insert(lines, chunk)
        end
    end
    sendLines(lines)
end

local function announceAssignments()
    saveCurrentNotes()
    local entry, mode = getCurrentEntry()
    if not entry then return end
    local saved = getNotesBucket(mode, entry.id)
    local labels = entry.assignLabels or {"Assignment 1", "Assignment 2", "Assignment 3"}
    local lines = {}
    if trim(saved.a1) ~= "" then
        table.insert(lines, labels[1] .. ": " .. trim(saved.a1))
    end
    if trim(saved.a2) ~= "" then
        table.insert(lines, labels[2] .. ": " .. trim(saved.a2))
    end
    if trim(saved.a3) ~= "" then
        table.insert(lines, labels[3] .. ": " .. trim(saved.a3))
    end
    if #lines == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: No assignments filled in for this entry yet.")
        return
    end
    sendLines(lines)
end

local countdownFrame = CreateFrame("Frame")
countdownFrame:Hide()
countdownFrame.remaining = 0
countdownFrame.lastSecond = nil

countdownFrame:SetScript("OnUpdate", function(self, elapsed)
    self.remaining = self.remaining - elapsed
    local second = math.ceil(self.remaining)
    if second ~= self.lastSecond then
        self.lastSecond = second
        if second == 10 or second == 5 or second == 4 or second == 3 or second == 2 or second == 1 then
            sendLines({"Pull in " .. second .. "..."})
        elseif second <= 0 then
            sendLines({"Pull!"})
            self:Hide()
        end
    end
end)

local function startPullCountdown()
    countdownFrame.remaining = 10.05
    countdownFrame.lastSecond = nil
    countdownFrame:Show()
end

local function matchTargetToCurrentMode()
    local target = UnitName and UnitName("target") or nil
    if not target or target == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: No target selected.")
        return
    end
    local lower = string.lower(target)
    local db = ensureDB()
    local mode = db.mode
    for _, entry in ipairs(getList(mode)) do
        if string.find(string.lower(entry.name), lower, 1, true) or string.find(lower, string.lower(entry.name), 1, true) then
            db.current[mode] = entry.id
            ns.RefreshUI()
            return
        end
        for _, alias in ipairs(entry.aliases or {}) do
            if string.find(lower, string.lower(alias), 1, true) then
                db.current[mode] = entry.id
                ns.RefreshUI()
                return
            end
        end
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Could not match target to a " .. mode .. " entry.")
end

local function setMode(mode)
    local db = ensureDB()
    db.mode = mode
    if not db.current[mode] then
        db.current[mode] = getFirstId(mode)
    end
    ns.RefreshUI()
end

local function createTab(parent, text, mode, xOffset)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(110, 24)
    button:SetPoint("TOPLEFT", 18 + xOffset, -36)
    button:SetText(text)
    button:SetScript("OnClick", function()
        setMode(mode)
    end)
    ui.tabs[mode] = button
end

local function buildUI()
    local db = ensureDB()

    local frame = createBackdropFrame("Frame", "KarazhanLeadAssistFrame", UIParent)
    frame:SetSize(db.frame.width or 980, db.frame.height or 700)
    frame:SetPoint(db.frame.point or "CENTER", UIParent, db.frame.point or "CENTER", db.frame.x or 0, db.frame.y or 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetMinResize(860, 620)
    frame:SetResizable(true)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveFramePosition()
    end)
    frame:SetScript("OnSizeChanged", function(self)
        saveFramePosition()
    end)
    frame:Hide()

    ui.frame = frame

    local title = createLabel(frame, "Karazhan Lead Assist", "large")
    title:SetPoint("TOPLEFT", 18, -14)
    ui.title = title

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    local resize = CreateFrame("Button", nil, frame)
    resize:SetPoint("BOTTOMRIGHT", -8, 8)
    resize:SetSize(16, 16)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        saveFramePosition()
    end)

    createTab(frame, "Bosses", "bosses", 0)
    createTab(frame, "Trash", "trash", 116)
    createTab(frame, "Utilities", "utilities", 232)

    local modeLabel = createLabel(frame, "Bosses", "small")
    modeLabel:SetPoint("TOPLEFT", 18, -68)
    ui.modeLabel = modeLabel

    local dropdown = CreateFrame("Frame", "KarazhanLeadAssistDropdown", frame, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 72, -57)
    ui.dropdown = dropdown

    local targetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    targetButton:SetSize(90, 22)
    targetButton:SetPoint("TOPRIGHT", -200, -60)
    targetButton:SetText("Use Target")
    targetButton:SetScript("OnClick", matchTargetToCurrentMode)

    local pullButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    pullButton:SetSize(90, 22)
    pullButton:SetPoint("TOPRIGHT", -104, -60)
    pullButton:SetText("Pull 10")
    pullButton:SetScript("OnClick", startPullCountdown)

    local readyButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    readyButton:SetSize(90, 22)
    readyButton:SetPoint("TOPRIGHT", -8, -60)
    readyButton:SetText("Ready Check")
    readyButton:SetScript("OnClick", function()
        if DoReadyCheck then
            DoReadyCheck()
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Ready check is not available in this client build.")
        end
    end)

    local header = createLabel(frame, "", "large")
    header:SetPoint("TOPLEFT", 18, -100)
    ui.header = header

    local notes = createScrollEditBox(frame, 610, 320, true)
    notes:SetPoint("TOPLEFT", 18, -126)
    ui.notes = notes

    local rightPanel = createBackdropFrame("Frame", nil, frame)
    rightPanel:SetPoint("TOPRIGHT", -18, -126)
    rightPanel:SetSize(320, 500)
    ui.rightPanel = rightPanel

    local rpTitle = createLabel(rightPanel, "Assignments & Custom Notes", "large")
    rpTitle:SetPoint("TOPLEFT", 12, -12)

    local assign1Label = createLabel(rightPanel, "Assignment 1", "small")
    assign1Label:SetPoint("TOPLEFT", 12, -42)
    ui.assign1Label = assign1Label

    local assign1 = createSingleLineEditBox(rightPanel, 294, 28)
    assign1:SetPoint("TOPLEFT", 12, -58)
    ui.assign1 = assign1

    local assign2Label = createLabel(rightPanel, "Assignment 2", "small")
    assign2Label:SetPoint("TOPLEFT", 12, -94)
    ui.assign2Label = assign2Label

    local assign2 = createSingleLineEditBox(rightPanel, 294, 28)
    assign2:SetPoint("TOPLEFT", 12, -110)
    ui.assign2 = assign2

    local assign3Label = createLabel(rightPanel, "Assignment 3", "small")
    assign3Label:SetPoint("TOPLEFT", 12, -146)
    ui.assign3Label = assign3Label

    local assign3 = createSingleLineEditBox(rightPanel, 294, 28)
    assign3:SetPoint("TOPLEFT", 12, -162)
    ui.assign3 = assign3

    local customLabel = createLabel(rightPanel, "Custom lead note", "small")
    customLabel:SetPoint("TOPLEFT", 12, -202)

    local custom = createScrollEditBox(rightPanel, 294, 170, false)
    custom:SetPoint("TOPLEFT", 12, -220)
    ui.custom = custom

    local annStrat = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    annStrat:SetSize(140, 24)
    annStrat:SetPoint("BOTTOMLEFT", 12, 48)
    annStrat:SetText("Announce Plan")
    annStrat:SetScript("OnClick", announceStrategy)

    local annAssign = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    annAssign:SetSize(140, 24)
    annAssign:SetPoint("BOTTOMRIGHT", -12, 48)
    annAssign:SetText("Announce Assignments")
    annAssign:SetScript("OnClick", announceAssignments)

    local saveButton = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    saveButton:SetSize(140, 24)
    saveButton:SetPoint("BOTTOMLEFT", 12, 16)
    saveButton:SetText("Save Notes")
    saveButton:SetScript("OnClick", function()
        saveCurrentNotes()
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Notes saved for this entry.")
    end)

    local clearButton = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    clearButton:SetSize(140, 24)
    clearButton:SetPoint("BOTTOMRIGHT", -12, 16)
    clearButton:SetText("Clear Custom")
    clearButton:SetScript("OnClick", function()
        ui.custom.edit:SetText("")
        saveCurrentNotes()
    end)

    local function attachAutosave(box)
        box:SetScript("OnEditFocusLost", saveCurrentNotes)
        box:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            saveCurrentNotes()
        end)
    end

    attachAutosave(assign1)
    attachAutosave(assign2)
    attachAutosave(assign3)
    custom.edit:SetScript("OnEditFocusLost", saveCurrentNotes)

    tinsert(UISpecialFrames, frame:GetName())
end

local function slashHandler(msg)
    msg = string.lower(trim(msg or ""))
    if not ui.frame then
        buildUI()
        if ns.RefreshUI then ns.RefreshUI() end
    end
    if msg == "" or msg == "show" or msg == "open" then
        if ui.frame:IsShown() then
            ui.frame:Hide()
        else
            ui.frame:Show()
            ns.RefreshUI()
        end
        return
    elseif msg == "boss" or msg == "bosses" then
        ui.frame:Show()
        setMode("bosses")
        return
    elseif msg == "trash" then
        ui.frame:Show()
        setMode("trash")
        return
    elseif msg == "util" or msg == "utils" or msg == "utilities" then
        ui.frame:Show()
        setMode("utilities")
        return
    elseif msg == "plan" or msg == "announce" then
        announceStrategy()
        return
    elseif msg == "assign" or msg == "assignments" then
        announceAssignments()
        return
    elseif msg == "pull" then
        startPullCountdown()
        return
    elseif msg == "target" then
        matchTargetToCurrentMode()
        return
    elseif msg == "ready" or msg == "readycheck" then
        if DoReadyCheck then DoReadyCheck() end
        return
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37Karazhan Lead Assist|r commands:")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla - open / close")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla bosses | trash | utilities")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla plan - announce built-in plan + custom note")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla assignments - announce the three assignment fields")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla pull - 10 second pull countdown")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla target - match current target to an entry")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla ready - start ready check")
end

addon:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then
            return
        end
        ensureDB()
        SLASH_KARAZHANLEADASSIST1 = "/kla"
        SLASH_KARAZHANLEADASSIST2 = "/karalead"
        SlashCmdList["KARAZHANLEADASSIST"] = slashHandler
        buildUI()
        ns.RefreshUI()
    elseif event == "PLAYER_LOGOUT" then
        if ui.frame then
            saveCurrentNotes()
            saveFramePosition()
        end
    end
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGOUT")
