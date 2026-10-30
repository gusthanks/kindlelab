--[[
Reading list helpers for the KindleLab plugin (pure Lua, no KOReader dependencies).

The list itself is SimpleUI's "To Be Read" collection (KOReader collection, manual order). This module
only orders its items and joins optional study notes from koreader/kindlelab/estudo.lua:

    return {
        guide = "How to study (shown from the menu)",
        buy = { "Book to buy — Author", ... },
        books = { ["file name.epub"] = { title = "...", stage = "...", note = "..." } },
    }
]]

local M = {}

function M.basename(path)
    return (path:gsub(".*/", ""))
end

-- Table check without trusting the file: returns a normalized copy or nil.
function M.validNotes(t)
    if type(t) ~= "table" then return nil end
    if t.books ~= nil and type(t.books) ~= "table" then return nil end
    if t.buy ~= nil and type(t.buy) ~= "table" then return nil end
    if t.guide ~= nil and type(t.guide) ~= "string" then return nil end
    return { guide = t.guide, buy = t.buy or {}, books = t.books or {} }
end

-- Loads the notes file in an empty environment (data only); missing/broken file = empty notes.
function M.loadNotes(path)
    local empty = { buy = {}, books = {} }
    local chunk = loadfile(path)
    if not chunk then return empty end
    if setfenv then setfenv(chunk, {}) end
    local ok, data = pcall(chunk)
    return ok and M.validNotes(data) or empty
end

-- coll: KOReader ReadCollection table { [file] = { file = ..., order = n } }.
function M.entries(coll, notes)
    local books = (notes and notes.books) or {}
    local list = {}
    for file, item in pairs(coll or {}) do
        list[#list + 1] = { file = item.file or file, order = tonumber(item.order) }
    end
    table.sort(list, function(a, b)
        if a.order and b.order and a.order ~= b.order then return a.order < b.order end
        if a.order and not b.order then return true end
        if b.order and not a.order then return false end
        return a.file < b.file
    end)
    for i, e in ipairs(list) do
        local name = M.basename(e.file)
        local n = books[name] or {}
        e.position = i
        e.title = n.title or name
        e.stage = n.stage
        e.note = n.note
    end
    return list
end

function M.label(e)
    local text = string.format("%d. %s", e.position, e.title)
    if e.stage then text = text .. " · " .. e.stage end
    return text
end

function M.buyText(notes)
    if not notes or not notes.buy or #notes.buy == 0 then return nil end
    local lines = {}
    for _, b in ipairs(notes.buy) do lines[#lines + 1] = "• " .. b end
    return table.concat(lines, "\n")
end

return M
