-- Installer defaults must never replace the reader's own choices.
local tests, failures = {}, 0
local function test(name, fn) tests[#tests + 1] = {name, fn} end
local function eq(a, b) if a ~= b then error(tostring(a) .. ' ~= ' .. tostring(b), 2) end end
local function settings(data)
    return {
        readSetting = function(_, key) return data[key] end,
        isTrue = function(_, key) return data[key] == true end,
        saveSetting = function(_, key, value) data[key] = value end,
        makeTrue = function(_, key) data[key] = true end,
        makeFalse = function(_, key) data[key] = false end,
        flush = function() end,
    }
end
package.loaded.logger = { info = function() end, warn = function() end }
package.loaded['libs/libkoreader-lfs'] = { attributes = function() return 'directory' end }
local patch = 'koreader-config/patches/'

test('fresh defaults start in documents and keep the back arrow inside the library', function()
    local d = {}
    G_reader_settings = settings(d)
    dofile(patch .. '2-kindlelab-defaults.lua')
    eq(d.home_dir, '/mnt/us/documents')
    eq(d.lock_home_folder, true)
    eq(d.collate, 'title')
    eq(d.kindlelab_defaults_v1, true)
end)

test('existing library, font, language, mascot and false booleans are preserved', function()
    local d = { home_dir = '/mnt/us/my-books', lock_home_folder = false, collate = 'access',
                language = 'de', copt_font_size = 22, mascot = 'mine' }
    G_reader_settings = settings(d)
    dofile(patch .. '2-kindlelab-defaults.lua')
    eq(d.home_dir, '/mnt/us/my-books')
    eq(d.lock_home_folder, false)
    eq(d.collate, 'access')
    eq(d.language, 'de')
    eq(d.copt_font_size, 22)
    eq(d.mascot, 'mine')
    d.home_dir = nil
    dofile(patch .. '2-kindlelab-defaults.lua')
    eq(d.home_dir, nil) -- removed after first run: don't put it back
end)

test('sleep screen fills missing values but preserves explicit choices', function()
    local d = { screensaver_type = 'disable', screensaver_show_message = true,
                screensaver_dir = '/mnt/us/my-pictures', screensaver_hide_cover_in_filemanager = false }
    G_reader_settings = settings(d)
    dofile(patch .. '2-kindlelab-sleepscreen.lua')
    eq(d.screensaver_type, 'disable')
    eq(d.screensaver_show_message, true)
    eq(d.screensaver_dir, '/mnt/us/my-pictures')
    eq(d.screensaver_hide_cover_in_filemanager, false)
    eq(d.kindlelab_sleepscreen_v1, true)
end)

test('fresh sleep screen uses the cover and bundled fallback directory', function()
    local d = {}
    G_reader_settings = settings(d)
    dofile(patch .. '2-kindlelab-sleepscreen.lua')
    eq(d.screensaver_type, 'cover')
    eq(d.screensaver_dir, '/mnt/us/koreader/screensavers')
    eq(d.screensaver_show_message, false)
end)

for _, t in ipairs(tests) do
    local ok, err = pcall(t[2])
    print((ok and 'PASS  ' or 'FAIL  ') .. t[1] .. (ok and '' or '\n      ' .. tostring(err)))
    if not ok then failures = failures + 1 end
end
print(string.format('%d tests, %d failures', #tests, failures))
os.exit(failures == 0 and 0 or 1)
