--[[
KindleLab reading profiles for KOReader's built-in "Profiles" plugin (Tools > Profiles).

Each profile runs automatically the FIRST time a book with its tag is opened (Profiles auto-execution:
"on book opening" + "if book metadata contains" + "and if book is new"), so later manual changes in a book are
never undone. Readers can edit or delete them in Tools > Profiles; ensure() never overwrites their changes.
Values use the same arguments as the bottom-menu buttons (Dispatcher "kopt_*" actions, PDF/DjVu only).
Pure Lua: tested on a PC (tests/kindlelab_profiles_spec.lua).
]]

local T = require("kindlelab_types")

local M = {}

M.COMIC = "KindleLab: Quadrinho"
M.SCANNED = "KindleLab: Escaneado"

local function definitions()
    return {
        [M.COMIC] = {
            tag = T.TAGS.comic,
            actions = {
                -- whole page on screen, one page per screen (not continuous), no margin cropping, normal contrast
                { "kopt_zoom_mode_genus", "page" },
                { "kopt_zoom_mode_type", "full" },
                { "kopt_page_scroll", false },
                { "kopt_trim_page", "none" },
                { "kopt_contrast", 1.0 },
            },
        },
        [M.SCANNED] = {
            tag = T.TAGS.scanned,
            actions = {
                -- crop the white margins of the scan and darken greyish text a little
                { "kopt_trim_page", "auto" },
                { "kopt_contrast", 1.5 },
            },
        },
    }
end

local function profileData(name, def)
    local data = { settings = { name = name, order = {} } }
    for i, action in ipairs(def.actions) do
        data[action[1]] = action[2]
        data.settings.order[i] = action[1]
    end
    return data
end

-- Adds the missing KindleLab profiles to `data` (Profiles' settings table) and their triggers to `autoexec`
-- (G_reader_settings "profiles_autoexec"). Returns true when something was added.
function M.ensure(data, autoexec)
    local changed = false
    autoexec.ReaderReadyAll = autoexec.ReaderReadyAll or {}
    for name, def in pairs(definitions()) do
        if data[name] == nil then
            data[name] = profileData(name, def)
            changed = true
        end
        if autoexec.ReaderReadyAll[name] == nil then
            autoexec.ReaderReadyAll[name] = { doc_props = { keywords = def.tag }, is_new = true }
            changed = true
        end
    end
    return changed
end

return M
