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

local function hexEncode(str)
    str = tostring(str or "")
    return (str:gsub(".", function(c)
        return string.format("%02X", string.byte(c))
    end))
end

local function hexDecode(hex)
    hex = tostring(hex or "")
    if hex == "" then
        return ""
    end
    if (#hex % 2) ~= 0 or hex:find("[^0-9A-Fa-f]") then
        error("invalid hex string")
    end
    return (hex:gsub("%x%x", function(pair)
        return string.char(tonumber(pair, 16))
    end))
end

local function splitDelimited(text, delimiter)
    local out = {}
    delimiter = delimiter or "|"
    local pattern = "([^" .. delimiter .. "]*)" .. delimiter .. "?"
    for piece in tostring(text or ""):gmatch(pattern) do
        table.insert(out, piece)
    end
    while #out > 0 and out[#out] == "" do
        table.remove(out)
    end
    return out
end

local PLACEHOLDER_COUNT = 10

local SUPPORTED_EXTRA_TOKENS = {
    "MT1", "MT2",
    "OT1", "OT2",
    "HEALER1", "HEALER2",
    "DPS1", "DPS2", "DPS3", "DPS4", "DPS5", "DPS6",
    "CC1", "CC2",
    "KICK1", "KICK2",
    "DISPEL1", "DISPEL2",
}

local SUPPORTED_TOKEN_MAP = {}
for _, token in ipairs(SUPPORTED_EXTRA_TOKENS) do
    SUPPORTED_TOKEN_MAP[token] = true
end

local AUTO_JOB_MAP = {
    MT1 = "P1",
    OT1 = "P2",
    HEALER1 = "P3",
    HEALER2 = "P4",
    DPS1 = "P5",
    DPS2 = "P6",
    DPS3 = "P7",
    DPS4 = "P8",
    DPS5 = "P9",
    DPS6 = "P10",
    KICK1 = "P5",
    KICK2 = "P6",
    CC1 = "P7",
    CC2 = "P8",
    DISPEL1 = "P3",
    DISPEL2 = "P4",
}

local function normalizeToken(token)
    return tostring(token or ""):upper()
end

local function isPlayerSlotToken(token)
    local num = tonumber(normalizeToken(token):match("^P(%d+)$"))
    return num and num >= 1 and num <= PLACEHOLDER_COUNT
end

local function isSupportedToken(token)
    token = normalizeToken(token)
    return isPlayerSlotToken(token) or SUPPORTED_TOKEN_MAP[token] or false
end

local function getAllSupportedTokens()
    local tokens = {}
    for _, token in ipairs(SUPPORTED_EXTRA_TOKENS) do
        table.insert(tokens, token)
    end
    for i = 1, PLACEHOLDER_COUNT do
        table.insert(tokens, "P" .. tostring(i))
    end
    return tokens
end

local function ensureDB()
    if type(KarazhanLeadAssistDB) ~= "table" then
        KarazhanLeadAssistDB = {}
    end
    local db = KarazhanLeadAssistDB
    db.mode = db.mode or "bosses"
    db.current = db.current or { bosses = "attumen", trash = "stables", utilities = "weeklyprep" }
    db.notes = db.notes or { bosses = {}, trash = {}, utilities = {} }
    db.currentPreset = db.currentPreset or { bosses = {}, trash = {}, utilities = {} }
    db.placeholders = db.placeholders or {}
    db.namedPlaceholders = db.namedPlaceholders or {}
    db.rosterPicker = db.rosterPicker or { token = "MT1", name = "" }
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

local sendLines

local function stripRealm(name)
    name = tostring(name or "")
    return (name:gsub("%-.+$", ""))
end

local function getPlaceholderKey(index)
    return "P" .. tostring(index)
end

local function getPlaceholderStore()
    local db = ensureDB()
    db.placeholders = db.placeholders or {}
    return db.placeholders
end

local function getNamedPlaceholderStore()
    local db = ensureDB()
    db.namedPlaceholders = db.namedPlaceholders or {}
    return db.namedPlaceholders
end

local function getPlaceholderValue(index)
    return trim(getPlaceholderStore()[getPlaceholderKey(index)] or "")
end

local function setPlaceholderValue(index, value)
    getPlaceholderStore()[getPlaceholderKey(index)] = trim(value or "")
end

local function getTokenValue(token)
    token = normalizeToken(token)
    if isPlayerSlotToken(token) then
        local num = tonumber(token:match("^P(%d+)$"))
        return getPlaceholderValue(num)
    end
    if SUPPORTED_TOKEN_MAP[token] then
        return trim(getNamedPlaceholderStore()[token] or "")
    end
    return ""
end

local function setTokenValue(token, value)
    token = normalizeToken(token)
    value = trim(value or "")
    if isPlayerSlotToken(token) then
        local num = tonumber(token:match("^P(%d+)$"))
        setPlaceholderValue(num, value)
        return
    end
    if SUPPORTED_TOKEN_MAP[token] then
        getNamedPlaceholderStore()[token] = value
    end
end

local function findMissingPlaceholders(texts)
    local missingMap = {}
    for _, text in ipairs(texts or {}) do
        text = tostring(text or "")
        for rawToken in text:gmatch("{([%a%d]+)}") do
            local token = normalizeToken(rawToken)
            if isSupportedToken(token) and getTokenValue(token) == "" then
                missingMap[token] = true
            end
        end
    end

    local missing = {}
    for i = 1, PLACEHOLDER_COUNT do
        local token = getPlaceholderKey(i)
        if missingMap[token] then
            table.insert(missing, "{" .. token .. "}")
        end
    end
    for _, token in ipairs(SUPPORTED_EXTRA_TOKENS) do
        if missingMap[token] then
            table.insert(missing, "{" .. token .. "}")
        end
    end
    return missing
end

local function applyPlaceholders(text)
    text = tostring(text or "")
    return (text:gsub("{([%a%d]+)}", function(rawToken)
        local token = normalizeToken(rawToken)
        if isSupportedToken(token) then
            local value = getTokenValue(token)
            if value ~= "" then
                return value
            end
            return "{" .. token .. "}"
        end
        return "{" .. rawToken .. "}"
    end))
end

local function resolveAnnouncementLines(lines)
    local missing = findMissingPlaceholders(lines)
    if #missing > 0 then
        return nil, missing
    end

    local resolved = {}
    for _, line in ipairs(lines or {}) do
        local finalLine = trim(applyPlaceholders(line))
        if finalLine ~= "" then
            table.insert(resolved, finalLine)
        end
    end
    return resolved, nil
end

local function sendResolvedLines(lines)
    local resolved, missing = resolveAnnouncementLines(lines)
    if missing then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Missing placeholder names for " .. table.concat(missing, ", ") .. ". Fill the placeholder panel first.")
        return false
    end
    sendLines(resolved)
    return true
end

local function getCurrentGroupRosterNames()
    local names = {}
    local inRaid = (IsInRaid and IsInRaid()) or (GetNumRaidMembers and GetNumRaidMembers() > 0)
    local inParty = (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0)

    if inRaid then
        local count = (GetNumRaidMembers and GetNumRaidMembers()) or 0
        for i = 1, count do
            local name = GetRaidRosterInfo and select(1, GetRaidRosterInfo(i)) or nil
            name = stripRealm(name)
            if name ~= "" then
                table.insert(names, name)
            end
        end
    elseif inParty then
        local playerName = UnitName and UnitName("player") or nil
        playerName = stripRealm(playerName)
        if playerName ~= "" then
            table.insert(names, playerName)
        end

        local count = (GetNumPartyMembers and GetNumPartyMembers()) or 0
        for i = 1, count do
            local name = UnitName and UnitName("party" .. i) or nil
            name = stripRealm(name)
            if name ~= "" then
                table.insert(names, name)
            end
        end
    else
        local playerName = UnitName and UnitName("player") or nil
        playerName = stripRealm(playerName)
        if playerName ~= "" then
            table.insert(names, playerName)
        end
    end

    return names
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

sendLines = function(lines)
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

local saveCurrentNotes
local savePlaceholderFields
local updateRosterPickerControls
local toggleSetupFrame
local populateSetupExportBox
local importSetupFromBox

local function getPresetById(entry, presetId)
    for _, preset in ipairs(entry.presets or {}) do
        if preset.id == presetId then
            return preset
        end
    end
end

local function getSelectedPresetId(mode, entry)
    local db = ensureDB()
    db.currentPreset[mode] = db.currentPreset[mode] or {}
    local presetId = db.currentPreset[mode][entry.id]
    if presetId and getPresetById(entry, presetId) then
        return presetId
    end
    local firstPreset = entry.presets and entry.presets[1]
    if firstPreset then
        db.currentPreset[mode][entry.id] = firstPreset.id
        return firstPreset.id
    end
    db.currentPreset[mode][entry.id] = nil
    return nil
end

local function updatePresetControls(entry, mode)
    if not ui.presetDropdown or not ui.loadPresetButton then
        return
    end

    local db = ensureDB()
    db.currentPreset[mode] = db.currentPreset[mode] or {}
    local presetId = getSelectedPresetId(mode, entry)

    UIDropDownMenu_Initialize(ui.presetDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, preset in ipairs(entry.presets or {}) do
            info.text = preset.name
            info.value = preset.id
            info.func = function()
                db.currentPreset[mode][entry.id] = preset.id
                UIDropDownMenu_SetSelectedValue(ui.presetDropdown, preset.id)
                UIDropDownMenu_SetText(ui.presetDropdown, preset.name)
            end
            info.checked = (preset.id == db.currentPreset[mode][entry.id])
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetWidth(ui.presetDropdown, 170)

    if entry.presets and #entry.presets > 0 then
        ui.loadPresetButton:Enable()
        if ui.presetAnnounceButton then ui.presetAnnounceButton:Enable() end
        UIDropDownMenu_SetSelectedValue(ui.presetDropdown, presetId)
        local preset = getPresetById(entry, presetId) or entry.presets[1]
        UIDropDownMenu_SetText(ui.presetDropdown, preset and preset.name or "Select preset")
    else
        ui.loadPresetButton:Disable()
        if ui.presetAnnounceButton then ui.presetAnnounceButton:Disable() end
        UIDropDownMenu_SetSelectedValue(ui.presetDropdown, nil)
        UIDropDownMenu_SetText(ui.presetDropdown, "No presets")
    end
end

local function loadPresetIntoFields(preset, silent)
    ui.assign1:SetText(preset.a1 or "")
    ui.assign2:SetText(preset.a2 or "")
    ui.assign3:SetText(preset.a3 or "")
    ui.custom.edit:SetText(preset.custom or "")
    ui.custom.scroll:SetVerticalScroll(0)
    saveCurrentNotes()
    if not silent then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Loaded preset - " .. preset.name)
    end
end

local function applySelectedPreset(silent)
    local entry, mode = getCurrentEntry()
    if not entry then return end
    local presetId = getSelectedPresetId(mode, entry)
    local preset = getPresetById(entry, presetId)
    if not preset then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: No preset available for this entry.")
        return
    end

    loadPresetIntoFields(preset, silent)
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

local function updatePlaceholderFields()
    if not ui.placeholderBoxes then
        return
    end
    for i = 1, PLACEHOLDER_COUNT do
        local box = ui.placeholderBoxes[i]
        if box then
            box:SetText(getPlaceholderValue(i))
        end
    end
end

local function getRosterPickerState()
    local db = ensureDB()
    db.rosterPicker = db.rosterPicker or { token = "MT1", name = "" }
    local token = normalizeToken(db.rosterPicker.token)
    if token == "" or not isSupportedToken(token) then
        token = "MT1"
    end
    db.rosterPicker.token = token
    db.rosterPicker.name = trim(db.rosterPicker.name or "")
    return db.rosterPicker
end

local function getRosterPickerNames()
    local names = {}
    local seen = {}
    for _, name in ipairs(getCurrentGroupRosterNames()) do
        name = stripRealm(name)
        if name ~= "" and not seen[name] then
            seen[name] = true
            table.insert(names, name)
        end
    end
    return names
end

updateRosterPickerControls = function()
    if not ui.slotDropdown or not ui.rosterDropdown then
        return
    end

    local picker = getRosterPickerState()
    local rosterNames = getRosterPickerNames()
    local supportedTokens = getAllSupportedTokens()

    UIDropDownMenu_Initialize(ui.slotDropdown, function(self, level)
        for _, token in ipairs(supportedTokens) do
            local info = UIDropDownMenu_CreateInfo()
            local currentValue = getTokenValue(token)
            local text = "{" .. token .. "}"
            if currentValue ~= "" then
                text = text .. " = " .. currentValue
            end
            info.text = text
            info.value = token
            info.func = function()
                picker.token = token
                UIDropDownMenu_SetSelectedValue(ui.slotDropdown, token)
                UIDropDownMenu_SetText(ui.slotDropdown, "{" .. token .. "}")
            end
            info.checked = (picker.token == token)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetWidth(ui.slotDropdown, 165)
    UIDropDownMenu_SetSelectedValue(ui.slotDropdown, picker.token)
    UIDropDownMenu_SetText(ui.slotDropdown, "{" .. picker.token .. "}")

    UIDropDownMenu_Initialize(ui.rosterDropdown, function(self, level)
        local blankInfo = UIDropDownMenu_CreateInfo()
        blankInfo.text = "- Select player -"
        blankInfo.value = ""
        blankInfo.func = function()
            picker.name = ""
            UIDropDownMenu_SetSelectedValue(ui.rosterDropdown, "")
            UIDropDownMenu_SetText(ui.rosterDropdown, "- Select player -")
        end
        blankInfo.checked = (picker.name == "")
        UIDropDownMenu_AddButton(blankInfo, level)

        for _, name in ipairs(rosterNames) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.value = name
            info.func = function()
                picker.name = name
                UIDropDownMenu_SetSelectedValue(ui.rosterDropdown, name)
                UIDropDownMenu_SetText(ui.rosterDropdown, name)
            end
            info.checked = (picker.name == name)
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetWidth(ui.rosterDropdown, 165)

    local selectedName = picker.name
    local nameFound = false
    for _, name in ipairs(rosterNames) do
        if name == selectedName then
            nameFound = true
            break
        end
    end

    if selectedName ~= "" and nameFound then
        UIDropDownMenu_SetSelectedValue(ui.rosterDropdown, selectedName)
        UIDropDownMenu_SetText(ui.rosterDropdown, selectedName)
    elseif selectedName ~= "" then
        UIDropDownMenu_SetSelectedValue(ui.rosterDropdown, nil)
        UIDropDownMenu_SetText(ui.rosterDropdown, selectedName .. " (manual)")
    else
        UIDropDownMenu_SetSelectedValue(ui.rosterDropdown, "")
        UIDropDownMenu_SetText(ui.rosterDropdown, "- Select player -")
    end

    if ui.tokenValueLabel then
        local currentValue = getTokenValue(picker.token)
        if currentValue ~= "" then
            ui.tokenValueLabel:SetText("Current: {" .. picker.token .. "} = " .. currentValue)
        else
            ui.tokenValueLabel:SetText("Current: {" .. picker.token .. "} is empty")
        end
    end
end

local function assignRosterPickerSelection()
    savePlaceholderFields()
    local picker = getRosterPickerState()
    local token = normalizeToken(picker.token)
    local name = trim(picker.name or "")
    if name == "" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Select a raid member from the roster dropdown first.")
        return
    end

    setTokenValue(token, name)
    local slot = tonumber(token:match("^P(%d+)$"))
    if slot and ui.placeholderBoxes and ui.placeholderBoxes[slot] then
        ui.placeholderBoxes[slot]:SetText(name)
    end
    updateRosterPickerControls()
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Set {" .. token .. "} = " .. name)
end

local function clearRosterPickerSlot()
    savePlaceholderFields()
    local picker = getRosterPickerState()
    local token = normalizeToken(picker.token)
    setTokenValue(token, "")
    local slot = tonumber(token:match("^P(%d+)$"))
    if slot and ui.placeholderBoxes and ui.placeholderBoxes[slot] then
        ui.placeholderBoxes[slot]:SetText("")
    end
    updateRosterPickerControls()
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Cleared {" .. token .. "}.")
end

local function refreshRosterPicker()
    updateRosterPickerControls()
    local count = #getRosterPickerNames()
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Roster dropdown refreshed (" .. tostring(count) .. " player(s)).")
end

local function autoAssignCommonJobs()
    savePlaceholderFields()

    local updated = {}
    local missing = {}

    local orderedTokens = {
        "MT1", "OT1", "HEALER1", "HEALER2",
        "DPS1", "DPS2", "DPS3", "DPS4", "DPS5", "DPS6",
        "KICK1", "KICK2", "CC1", "CC2", "DISPEL1", "DISPEL2",
    }

    for _, token in ipairs(orderedTokens) do
        local sourceToken = AUTO_JOB_MAP[token]
        local sourceValue = sourceToken and getTokenValue(sourceToken) or ""
        if sourceValue ~= "" then
            setTokenValue(token, sourceValue)
            table.insert(updated, "{" .. token .. "}=" .. sourceValue)
        else
            table.insert(missing, "{" .. sourceToken .. "}")
        end
    end

    if updateRosterPickerControls then
        updateRosterPickerControls()
    end

    if #updated == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Auto Kara Jobs needs your flexible slots first. Set {P1}-{P10} so P1/P2 are tanks, P3/P4 are healers, and P5-P10 are DPS, then try again.")
        return
    end

    local summary = table.concat(updated, ", ")
    if #summary > 220 then
        summary = table.concat({updated[1], updated[2], updated[3], updated[4], "..."}, ", ")
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Auto-filled Kara jobs from {P1}-{P10}: " .. summary)
    if #missing > 0 then
        local missingText = table.concat(missing, ", ")
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Still missing source slots for " .. missingText .. ".")
    end
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
    updatePresetControls(entry, mode)
    updatePlaceholderFields()
    updateRosterPickerControls()
    setSelectedTab(mode)
end

saveCurrentNotes = function()
    local entry, mode = getCurrentEntry()
    if not entry then return end
    local saved = getNotesBucket(mode, entry.id)
    saved.a1 = ui.assign1:GetText() or ""
    saved.a2 = ui.assign2:GetText() or ""
    saved.a3 = ui.assign3:GetText() or ""
    saved.custom = ui.custom.edit:GetText() or ""
end

savePlaceholderFields = function()
    if not ui.placeholderBoxes then
        return
    end
    for i = 1, PLACEHOLDER_COUNT do
        local box = ui.placeholderBoxes[i]
        if box then
            setPlaceholderValue(i, box:GetText() or "")
        end
    end
    if updateRosterPickerControls then
        updateRosterPickerControls()
    end
end

local function sortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

local function buildSetupExportString()
    saveCurrentNotes()
    savePlaceholderFields()

    local db = ensureDB()
    local out = {"KLA_SETUP_V1"}

    table.insert(out, table.concat({"MODE", hexEncode(db.mode or "")}, "|"))

    for _, mode in ipairs({"bosses", "trash", "utilities"}) do
        local currentId = db.current and db.current[mode] or nil
        if currentId and currentId ~= "" then
            table.insert(out, table.concat({"CURRENT", hexEncode(mode), hexEncode(currentId)}, "|"))
        end
    end

    for _, mode in ipairs({"bosses", "trash", "utilities"}) do
        local presetBucket = db.currentPreset and db.currentPreset[mode] or nil
        for _, entryId in ipairs(sortedKeys(presetBucket or {})) do
            local presetId = presetBucket[entryId]
            if trim(presetId) ~= "" then
                table.insert(out, table.concat({"PRESET", hexEncode(mode), hexEncode(entryId), hexEncode(presetId)}, "|"))
            end
        end
    end

    for _, mode in ipairs({"bosses", "trash", "utilities"}) do
        local notesBucket = db.notes and db.notes[mode] or nil
        for _, entryId in ipairs(sortedKeys(notesBucket or {})) do
            local saved = notesBucket[entryId] or {}
            table.insert(out, table.concat({
                "ENTRY",
                hexEncode(mode),
                hexEncode(entryId),
                hexEncode(saved.a1 or ""),
                hexEncode(saved.a2 or ""),
                hexEncode(saved.a3 or ""),
                hexEncode(saved.custom or ""),
            }, "|"))
        end
    end

    for i = 1, PLACEHOLDER_COUNT do
        local token = getPlaceholderKey(i)
        local value = getPlaceholderValue(i)
        if value ~= "" then
            table.insert(out, table.concat({"PLACE", hexEncode(token), hexEncode(value)}, "|"))
        end
    end

    for _, token in ipairs(SUPPORTED_EXTRA_TOKENS) do
        local value = getTokenValue(token)
        if value ~= "" then
            table.insert(out, table.concat({"TOKEN", hexEncode(token), hexEncode(value)}, "|"))
        end
    end

    table.insert(out, "END")
    return table.concat(out, "\n")
end

local function importSetupString(rawText)
    local text = trim(rawText or "")
    if text == "" then
        return false, "Paste an exported setup string first."
    end

    local lines = splitLines(text)
    if lines[1] ~= "KLA_SETUP_V1" then
        return false, "That does not look like a Karazhan Lead Assist export string."
    end

    local parsed = {
        mode = nil,
        current = {},
        currentPreset = { bosses = {}, trash = {}, utilities = {} },
        notes = { bosses = {}, trash = {}, utilities = {} },
        placeholders = {},
        namedPlaceholders = {},
    }

    local entryCount = 0
    local tokenCount = 0

    for idx = 2, #lines do
        local line = trim(lines[idx])
        if line ~= "" and line ~= "END" then
            local parts = splitDelimited(line, "|")
            local kind = parts[1]

            if kind == "MODE" and parts[2] then
                local ok, value = pcall(hexDecode, parts[2])
                if ok and (value == "bosses" or value == "trash" or value == "utilities") then
                    parsed.mode = value
                end
            elseif kind == "CURRENT" and parts[2] and parts[3] then
                local okMode, mode = pcall(hexDecode, parts[2])
                local okId, entryId = pcall(hexDecode, parts[3])
                if okMode and okId and parsed.current[mode] ~= nil then
                    parsed.current[mode] = entryId
                elseif okMode and okId and (mode == "bosses" or mode == "trash" or mode == "utilities") then
                    parsed.current[mode] = entryId
                end
            elseif kind == "PRESET" and parts[2] and parts[3] and parts[4] then
                local okMode, mode = pcall(hexDecode, parts[2])
                local okEntry, entryId = pcall(hexDecode, parts[3])
                local okPreset, presetId = pcall(hexDecode, parts[4])
                if okMode and okEntry and okPreset and parsed.currentPreset[mode] then
                    parsed.currentPreset[mode][entryId] = presetId
                end
            elseif kind == "ENTRY" and parts[2] and parts[3] and parts[4] and parts[5] and parts[6] and parts[7] then
                local okMode, mode = pcall(hexDecode, parts[2])
                local okEntry, entryId = pcall(hexDecode, parts[3])
                local okA1, a1 = pcall(hexDecode, parts[4])
                local okA2, a2 = pcall(hexDecode, parts[5])
                local okA3, a3 = pcall(hexDecode, parts[6])
                local okCustom, custom = pcall(hexDecode, parts[7])
                if okMode and okEntry and okA1 and okA2 and okA3 and okCustom and parsed.notes[mode] then
                    parsed.notes[mode][entryId] = { a1 = a1, a2 = a2, a3 = a3, custom = custom }
                    entryCount = entryCount + 1
                end
            elseif kind == "PLACE" and parts[2] and parts[3] then
                local okToken, token = pcall(hexDecode, parts[2])
                local okValue, value = pcall(hexDecode, parts[3])
                token = normalizeToken(token)
                if okToken and okValue and isPlayerSlotToken(token) then
                    parsed.placeholders[token] = value
                    tokenCount = tokenCount + 1
                end
            elseif kind == "TOKEN" and parts[2] and parts[3] then
                local okToken, token = pcall(hexDecode, parts[2])
                local okValue, value = pcall(hexDecode, parts[3])
                token = normalizeToken(token)
                if okToken and okValue and SUPPORTED_TOKEN_MAP[token] then
                    parsed.namedPlaceholders[token] = value
                    tokenCount = tokenCount + 1
                end
            end
        end
    end

    local db = ensureDB()
    db.notes = parsed.notes
    db.currentPreset = parsed.currentPreset
    db.placeholders = parsed.placeholders
    db.namedPlaceholders = parsed.namedPlaceholders
    db.mode = parsed.mode or db.mode or "bosses"
    db.current = db.current or {}
    for _, mode in ipairs({"bosses", "trash", "utilities"}) do
        db.current[mode] = parsed.current[mode] or db.current[mode] or getFirstId(mode)
    end

    if ui.frame and ns.RefreshUI then
        ns.RefreshUI()
    end

    return true, "Imported " .. tostring(entryCount) .. " saved setup(s) and " .. tostring(tokenCount) .. " placeholder mapping(s)."
end

populateSetupExportBox = function()
    if not ui.setupBox then
        return
    end
    local exportText = buildSetupExportString()
    ui.setupBox.edit:SetText(exportText)
    ui.setupBox.scroll:SetVerticalScroll(0)
    ui.setupBox.edit:SetFocus()
    if ui.setupBox.edit.HighlightText then
        ui.setupBox.edit:HighlightText()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Export string generated. Copy the text from the setup window.")
end

importSetupFromBox = function()
    if not ui.setupBox then
        return
    end
    local ok, message = importSetupString(ui.setupBox.edit:GetText() or "")
    if ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: " .. message)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Import failed - " .. message)
    end
end


local function buildStrategyLines(entry)
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
    return lines
end

local function buildAssignmentLines(entry, saved)
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
    return lines
end

local function announceStrategy()
    saveCurrentNotes()
    savePlaceholderFields()
    local entry = getCurrentEntry()
    if not entry then return end
    sendResolvedLines(buildStrategyLines(entry))
end

local function announceAssignments()
    saveCurrentNotes()
    savePlaceholderFields()
    local entry, mode = getCurrentEntry()
    if not entry then return end
    local saved = getNotesBucket(mode, entry.id)
    local lines = buildAssignmentLines(entry, saved)
    if #lines == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: No assignments filled in for this entry yet.")
        return
    end
    sendResolvedLines(lines)
end

local function announceFullCurrentEntry()
    saveCurrentNotes()
    savePlaceholderFields()
    local entry, mode = getCurrentEntry()
    if not entry then return end
    local saved = getNotesBucket(mode, entry.id)
    local lines = {}
    for _, line in ipairs(buildStrategyLines(entry)) do
        table.insert(lines, line)
    end
    for _, line in ipairs(buildAssignmentLines(entry, saved)) do
        table.insert(lines, line)
    end
    if #lines == 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Nothing to announce for this entry yet.")
        return
    end
    sendResolvedLines(lines)
end

local function loadAndAnnouncePreset()
    local entry, mode = getCurrentEntry()
    if not entry then return end
    local presetId = getSelectedPresetId(mode, entry)
    local preset = getPresetById(entry, presetId)
    if not preset then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: No preset available for this entry.")
        return
    end
    loadPresetIntoFields(preset, true)
    announceFullCurrentEntry()
end

local function importRaidToPlaceholders()
    local names = getCurrentGroupRosterNames()
    for i = 1, PLACEHOLDER_COUNT do
        local value = names[i] or ""
        setPlaceholderValue(i, value)
        if ui.placeholderBoxes and ui.placeholderBoxes[i] then
            ui.placeholderBoxes[i]:SetText(value)
        end
    end
    if updateRosterPickerControls then
        updateRosterPickerControls()
    end
    if #names > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: Imported " .. math.min(#names, PLACEHOLDER_COUNT) .. " player name(s) into placeholders.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: No raid or party roster found to import.")
    end
end

local function clearPlaceholders()
    for i = 1, PLACEHOLDER_COUNT do
        setPlaceholderValue(i, "")
        if ui.placeholderBoxes and ui.placeholderBoxes[i] then
            ui.placeholderBoxes[i]:SetText("")
        end
    end
    local namedStore = getNamedPlaceholderStore()
    for token in pairs(namedStore) do
        namedStore[token] = nil
    end
    if updateRosterPickerControls then
        updateRosterPickerControls()
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37KLA|r: All placeholder slots and token mappings cleared.")
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

toggleSetupFrame = function(forceShow)
    if not ui.setupFrame then
        return
    end
    if forceShow == true then
        ui.setupFrame:Show()
    elseif forceShow == false then
        ui.setupFrame:Hide()
    else
        if ui.setupFrame:IsShown() then
            ui.setupFrame:Hide()
        else
            ui.setupFrame:Show()
        end
    end
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
    if ui.frame then
        return ui.frame
    end

    local db = ensureDB()

    local frame = createBackdropFrame("Frame", "KarazhanLeadAssistFrame", UIParent)
    ui.frame = frame
    frame.klaMinWidth = 860
    frame.klaMinHeight = 700
    frame:SetSize(db.frame.width or 980, db.frame.height or 700)
    frame:SetPoint(db.frame.point or "CENTER", UIParent, db.frame.point or "CENTER", db.frame.x or 0, db.frame.y or 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    if frame.SetMinResize then
        frame:SetMinResize(frame.klaMinWidth, frame.klaMinHeight)
    end
    frame:SetResizable(true)
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveFramePosition()
    end)
    frame:SetScript("OnSizeChanged", function(self)
        local width = self:GetWidth() or 0
        local height = self:GetHeight() or 0
        local changed = false
        if width < self.klaMinWidth then
            self:SetWidth(self.klaMinWidth)
            changed = true
        end
        if height < self.klaMinHeight then
            self:SetHeight(self.klaMinHeight)
            changed = true
        end
        if not changed then
            saveFramePosition()
        end
    end)
    frame:Hide()

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

    local setupsButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    setupsButton:SetSize(90, 22)
    setupsButton:SetPoint("TOPRIGHT", -296, -60)
    setupsButton:SetText("Setups")
    setupsButton:SetScript("OnClick", function()
        toggleSetupFrame()
    end)
    ui.setupsButton = setupsButton

    local header = createLabel(frame, "", "large")
    header:SetPoint("TOPLEFT", 18, -100)
    ui.header = header

    local notes = createScrollEditBox(frame, 610, 266, true)
    notes:SetPoint("TOPLEFT", 18, -126)
    ui.notes = notes

    local rightPanel = createBackdropFrame("Frame", nil, frame)
    rightPanel:SetPoint("TOPRIGHT", -18, -126)
    rightPanel:SetSize(320, 563)
    ui.rightPanel = rightPanel

    local rpTitle = createLabel(rightPanel, "Assignments & Custom Notes", "large")
    rpTitle:SetPoint("TOPLEFT", 12, -12)

    local presetLabel = createLabel(rightPanel, "Preset Loader", "small")
    presetLabel:SetPoint("TOPLEFT", 12, -42)
    ui.presetLabel = presetLabel

    local presetDropdown = CreateFrame("Frame", "KarazhanLeadAssistPresetDropdown", rightPanel, "UIDropDownMenuTemplate")
    presetDropdown:SetPoint("TOPLEFT", -4, -52)
    ui.presetDropdown = presetDropdown

    local loadPresetButton = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    loadPresetButton:SetSize(92, 22)
    loadPresetButton:SetPoint("TOPRIGHT", -12, -58)
    loadPresetButton:SetText("Load Preset")
    loadPresetButton:SetScript("OnClick", applySelectedPreset)
    ui.loadPresetButton = loadPresetButton

    local presetAnnounceButton = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    presetAnnounceButton:SetSize(92, 22)
    presetAnnounceButton:SetPoint("TOPRIGHT", -12, -84)
    presetAnnounceButton:SetText("Preset -> Raid")
    presetAnnounceButton:SetScript("OnClick", loadAndAnnouncePreset)
    ui.presetAnnounceButton = presetAnnounceButton

    local assign1Label = createLabel(rightPanel, "Assignment 1", "small")
    assign1Label:SetPoint("TOPLEFT", 12, -118)
    ui.assign1Label = assign1Label

    local assign1 = createSingleLineEditBox(rightPanel, 294, 28)
    assign1:SetPoint("TOPLEFT", 12, -134)
    ui.assign1 = assign1

    local assign2Label = createLabel(rightPanel, "Assignment 2", "small")
    assign2Label:SetPoint("TOPLEFT", 12, -170)
    ui.assign2Label = assign2Label

    local assign2 = createSingleLineEditBox(rightPanel, 294, 28)
    assign2:SetPoint("TOPLEFT", 12, -186)
    ui.assign2 = assign2

    local assign3Label = createLabel(rightPanel, "Assignment 3", "small")
    assign3Label:SetPoint("TOPLEFT", 12, -222)
    ui.assign3Label = assign3Label

    local assign3 = createSingleLineEditBox(rightPanel, 294, 28)
    assign3:SetPoint("TOPLEFT", 12, -238)
    ui.assign3 = assign3

    local customLabel = createLabel(rightPanel, "Custom lead note", "small")
    customLabel:SetPoint("TOPLEFT", 12, -278)

    local custom = createScrollEditBox(rightPanel, 294, 116, false)
    custom:SetPoint("TOPLEFT", 12, -296)
    ui.custom = custom

    local annStrat = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    annStrat:SetSize(140, 24)
    annStrat:SetPoint("BOTTOMLEFT", 12, 80)
    annStrat:SetText("Announce Plan")
    annStrat:SetScript("OnClick", announceStrategy)

    local annAssign = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    annAssign:SetSize(140, 24)
    annAssign:SetPoint("BOTTOMRIGHT", -12, 80)
    annAssign:SetText("Announce Assignments")
    annAssign:SetScript("OnClick", announceAssignments)

    local annFull = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    annFull:SetSize(140, 24)
    annFull:SetPoint("BOTTOMLEFT", 12, 48)
    annFull:SetText("Announce Full")
    annFull:SetScript("OnClick", announceFullCurrentEntry)

    local saveButton = CreateFrame("Button", nil, rightPanel, "UIPanelButtonTemplate")
    saveButton:SetSize(140, 24)
    saveButton:SetPoint("BOTTOMRIGHT", -12, 48)
    saveButton:SetText("Save Notes")
    saveButton:SetScript("OnClick", function()
        saveCurrentNotes()
        savePlaceholderFields()
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

    local placeholderPanel = createBackdropFrame("Frame", nil, frame)
    placeholderPanel:SetPoint("TOPLEFT", 18, -422)
    placeholderPanel:SetSize(610, 267)
    ui.placeholderPanel = placeholderPanel

    local placeholderTitle = createLabel(placeholderPanel, "Placeholder Slots", "large")
    placeholderTitle:SetPoint("TOPLEFT", 12, -12)

    local placeholderHint = createLabel(placeholderPanel, "Use {MT1}, {OT1}, {HEALER1}, {HEALER2}, {DPS1}-{DPS6}, {CC1}, {CC2}, {KICK1}, {KICK2}, and {DISPEL1}-{DISPEL2}. Flexible extras: {P1}-{P10}.", "small")
    placeholderHint:SetPoint("TOPLEFT", 12, -34)
    placeholderHint:SetWidth(350)

    local importRaidButton = CreateFrame("Button", nil, placeholderPanel, "UIPanelButtonTemplate")
    importRaidButton:SetSize(88, 22)
    importRaidButton:SetPoint("TOPRIGHT", -178, -10)
    importRaidButton:SetText("Import Raid")
    importRaidButton:SetScript("OnClick", importRaidToPlaceholders)

    local autoJobsButton = CreateFrame("Button", nil, placeholderPanel, "UIPanelButtonTemplate")
    autoJobsButton:SetSize(88, 22)
    autoJobsButton:SetPoint("TOPRIGHT", -92, -10)
    autoJobsButton:SetText("Auto Jobs")
    autoJobsButton:SetScript("OnClick", autoAssignCommonJobs)

    local clearPlaceholdersButton = CreateFrame("Button", nil, placeholderPanel, "UIPanelButtonTemplate")
    clearPlaceholdersButton:SetSize(78, 22)
    clearPlaceholdersButton:SetPoint("TOPRIGHT", -12, -10)
    clearPlaceholdersButton:SetText("Clear")
    clearPlaceholdersButton:SetScript("OnClick", clearPlaceholders)

    local slotPickerLabel = createLabel(placeholderPanel, "Placeholder", "small")
    slotPickerLabel:SetPoint("TOPLEFT", 12, -84)

    local slotDropdown = CreateFrame("Frame", "KarazhanLeadAssistSlotDropdown", placeholderPanel, "UIDropDownMenuTemplate")
    slotDropdown:SetPoint("TOPLEFT", 78, -72)
    ui.slotDropdown = slotDropdown

    local assignRosterButton = CreateFrame("Button", nil, placeholderPanel, "UIPanelButtonTemplate")
    assignRosterButton:SetSize(92, 22)
    assignRosterButton:SetPoint("TOPRIGHT", -12, -70)
    assignRosterButton:SetText("Set Slot")
    assignRosterButton:SetScript("OnClick", assignRosterPickerSelection)

    local rosterPickerLabel = createLabel(placeholderPanel, "Raid member", "small")
    rosterPickerLabel:SetPoint("TOPLEFT", 12, -114)

    local rosterDropdown = CreateFrame("Frame", "KarazhanLeadAssistRosterDropdown", placeholderPanel, "UIDropDownMenuTemplate")
    rosterDropdown:SetPoint("TOPLEFT", 78, -102)
    ui.rosterDropdown = rosterDropdown

    local refreshRosterButton = CreateFrame("Button", nil, placeholderPanel, "UIPanelButtonTemplate")
    refreshRosterButton:SetSize(78, 22)
    refreshRosterButton:SetPoint("TOPRIGHT", -12, -100)
    refreshRosterButton:SetText("Refresh")
    refreshRosterButton:SetScript("OnClick", refreshRosterPicker)

    local clearSlotButton = CreateFrame("Button", nil, placeholderPanel, "UIPanelButtonTemplate")
    clearSlotButton:SetSize(86, 22)
    clearSlotButton:SetPoint("TOPLEFT", 12, -146)
    clearSlotButton:SetText("Clear Slot")
    clearSlotButton:SetScript("OnClick", clearRosterPickerSlot)

    local tokenValueLabel = createLabel(placeholderPanel, "Current: {MT1} is empty", "small")
    tokenValueLabel:SetPoint("TOPLEFT", 106, -150)
    tokenValueLabel:SetWidth(470)
    ui.tokenValueLabel = tokenValueLabel

    ui.placeholderBoxes = {}
    for i = 1, PLACEHOLDER_COUNT do
        local column = (i <= 5) and 1 or 2
        local row = ((i - 1) % 5) + 1
        local baseX = (column == 1) and 14 or 314
        local y = -174 - ((row - 1) * 18)

        local label = createLabel(placeholderPanel, "{" .. getPlaceholderKey(i) .. "}", "small")
        label:SetPoint("TOPLEFT", baseX, y)

        local box = createSingleLineEditBox(placeholderPanel, 110, 20)
        box:SetPoint("TOPLEFT", baseX + 38, y + 5)
        box:SetScript("OnEditFocusLost", savePlaceholderFields)
        box:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            savePlaceholderFields()
        end)
        ui.placeholderBoxes[i] = box
    end

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

    local setupFrame = createBackdropFrame("Frame", nil, frame)
    setupFrame:SetSize(640, 430)
    setupFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
    setupFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    setupFrame:Hide()
    ui.setupFrame = setupFrame

    local setupTitle = createLabel(setupFrame, "Saved Setups Export / Import", "large")
    setupTitle:SetPoint("TOPLEFT", 12, -12)

    local setupHint = createLabel(setupFrame, "Export all saved assignment notes, preset selections, and placeholder mappings. Paste an exported string back in and click Import Replace to restore it.", "small")
    setupHint:SetPoint("TOPLEFT", 12, -36)
    setupHint:SetWidth(604)

    local setupBox = createScrollEditBox(setupFrame, 610, 290, false)
    setupBox:SetPoint("TOPLEFT", 12, -74)
    ui.setupBox = setupBox

    local setupWarning = createLabel(setupFrame, "Import Replace overwrites your saved notes, preset picks, and placeholder mappings. Built-in encounter data is not changed.", "small")
    setupWarning:SetPoint("TOPLEFT", 12, -370)
    setupWarning:SetWidth(604)

    local exportButton = CreateFrame("Button", nil, setupFrame, "UIPanelButtonTemplate")
    exportButton:SetSize(140, 24)
    exportButton:SetPoint("BOTTOMLEFT", 12, 16)
    exportButton:SetText("Export Saved Setups")
    exportButton:SetScript("OnClick", populateSetupExportBox)

    local importButton = CreateFrame("Button", nil, setupFrame, "UIPanelButtonTemplate")
    importButton:SetSize(140, 24)
    importButton:SetPoint("BOTTOMLEFT", 164, 16)
    importButton:SetText("Import Replace")
    importButton:SetScript("OnClick", importSetupFromBox)

    local setupClearButton = CreateFrame("Button", nil, setupFrame, "UIPanelButtonTemplate")
    setupClearButton:SetSize(100, 24)
    setupClearButton:SetPoint("BOTTOMRIGHT", -116, 16)
    setupClearButton:SetText("Clear Box")
    setupClearButton:SetScript("OnClick", function()
        ui.setupBox.edit:SetText("")
        ui.setupBox.scroll:SetVerticalScroll(0)
    end)

    local setupCloseButton = CreateFrame("Button", nil, setupFrame, "UIPanelButtonTemplate")
    setupCloseButton:SetSize(92, 24)
    setupCloseButton:SetPoint("BOTTOMRIGHT", -12, 16)
    setupCloseButton:SetText("Close")
    setupCloseButton:SetScript("OnClick", function()
        toggleSetupFrame(false)
    end)

    tinsert(UISpecialFrames, frame:GetName())
end

local function slashHandler(msg)
    msg = string.lower(trim(msg or ""))
    if not ui.frame then
        buildUI()
        if ns.RefreshUI and ui.frame then ns.RefreshUI() end
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
    elseif msg == "importraid" or msg == "fillraid" then
        importRaidToPlaceholders()
        return
    elseif msg == "autokarajobs" or msg == "autojobs" or msg == "jobs" then
        autoAssignCommonJobs()
        return
    elseif msg == "clearplaceholders" or msg == "clearph" then
        clearPlaceholders()
        return
    elseif msg == "refreshroster" or msg == "roster" then
        refreshRosterPicker()
        return
    elseif msg == "setup" or msg == "setups" then
        toggleSetupFrame()
        return
    elseif msg == "export" then
        toggleSetupFrame(true)
        populateSetupExportBox()
        return
    elseif msg == "import" then
        toggleSetupFrame(true)
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
    DEFAULT_CHAT_FRAME:AddMessage("  /kla importraid - fill {P1} to {P10} from current group roster")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla autojobs - copy P1/P2 tanks, P3/P4 healers, and P5-P10 DPS into the common raid-job tokens")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla clearplaceholders - clear all player and raid-job token mappings")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla refreshroster - refresh the roster dropdown list")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla setups - open the saved setups export / import window")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla export - open setups window and generate export text")
    DEFAULT_CHAT_FRAME:AddMessage("  /kla import - open setups window for paste-in import")
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
            savePlaceholderFields()
            saveFramePosition()
        end
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        if ui.frame and updateRosterPickerControls then
            updateRosterPickerControls()
        end
    end
end)

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGOUT")
addon:RegisterEvent("RAID_ROSTER_UPDATE")
addon:RegisterEvent("PARTY_MEMBERS_CHANGED")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
