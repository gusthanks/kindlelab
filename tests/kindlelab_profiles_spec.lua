-- Tests for kindlelab_profiles.lua: the KindleLab reading profiles (KOReader "Profiles" plugin data).
-- Run: tests/run.sh

package.path = "koreader-config/plugins/kindlelab.koplugin/?.lua;" .. package.path
local P = require("kindlelab_profiles")

local tests, failures = {}, 0
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end
local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
    end
end

test("ensure adds both profiles and their first-opening triggers", function()
    local data, autoexec = {}, {}
    eq(P.ensure(data, autoexec), true, "changed")
    local comic, scan = data[P.COMIC], data[P.SCANNED]
    eq(comic.settings.name, P.COMIC)
    eq(comic.kopt_zoom_mode_genus, "page")
    eq(comic.kopt_zoom_mode_type, "full")
    eq(comic.kopt_trim_page, "none")
    eq(comic.kopt_page_scroll, false, "one page per screen, not continuous")
    eq(#comic.settings.order, 5, "every comic action is listed in order")
    eq(scan.kopt_trim_page, "auto")
    eq(scan.kopt_contrast, 1.5)
    eq(#scan.settings.order, 2, "every action is listed in order")
    local trigger = autoexec.ReaderReadyAll[P.SCANNED]
    eq(trigger.doc_props.keywords, "Tipo: Escaneado")
    eq(trigger.is_new, true, "only the first time the book is opened")
    eq(autoexec.ReaderReadyAll[P.COMIC].doc_props.keywords, "Tipo: Quadrinho")
end)

test("ensure keeps profiles and triggers the reader already changed", function()
    local data = { [P.SCANNED] = { settings = { name = P.SCANNED }, kopt_contrast = 4.0 } }
    local autoexec = { ReaderReadyAll = { [P.SCANNED] = { doc_props = { keywords = "Escaneado" } } } }
    P.ensure(data, autoexec)
    eq(data[P.SCANNED].kopt_contrast, 4.0, "reader's profile untouched")
    eq(autoexec.ReaderReadyAll[P.SCANNED].doc_props.keywords, "Escaneado", "reader's trigger untouched")
    eq(data[P.COMIC] ~= nil, true, "missing profile added")
end)

test("ensure reports no change when everything is there", function()
    local data, autoexec = {}, {}
    P.ensure(data, autoexec)
    eq(P.ensure(data, autoexec), false)
end)

for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
        print("PASS  " .. t.name)
    else
        failures = failures + 1
        print("FAIL  " .. t.name .. "\n      " .. tostring(err))
    end
end
print(string.format("%d tests, %d failures", #tests, failures))
os.exit(failures == 0 and 0 or 1)
