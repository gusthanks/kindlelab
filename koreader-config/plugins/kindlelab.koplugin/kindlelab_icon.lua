--[[
KindleLab: read and change the icon of the KOReader tile on the stock Kindle home screen.

The tile is the launcher script documents/KOReader.sh (KindleModding's sh_integration). Its cover is the
image named in the "# Icon:" header line. Pure Lua, no KOReader dependencies, so it can be tested alone.
]]

local M = {}

M.LAUNCHER = "/mnt/us/documents/KOReader.sh"
M.ICON_DIR = "/mnt/us/koreader/kindlelab/icons"
M.BACKUP = "/mnt/us/koreader/kindlelab/KOReader.sh.bak"

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function writeFile(path, data)
    local f, err = io.open(path, "wb")
    if not f then return false, err end
    local ok, werr = f:write(data)
    f:close()
    if not ok then return false, werr end
    return readFile(path) == data, "verify failed"
end

-- Image path in the "# Icon:" line, or nil.
function M.current(launcher)
    local data = readFile(launcher or M.LAUNCHER)
    if not data then return nil end
    return ("\n" .. data):match("\n# Icon: ([^\r\n]+)")
end

-- Point the "# Icon:" line at `image`. Keeps a one-time backup of the original launcher and restores
-- it if the new file does not read back exactly.
function M.set(image, launcher, backup)
    launcher, backup = launcher or M.LAUNCHER, backup or M.BACKUP
    local data = readFile(launcher)
    if not data then return false, "launcher not found: " .. launcher end
    if not readFile(backup) then writeFile(backup, data) end
    local escaped = image:gsub("%%", "%%%%")
    local new, n = ("\n" .. data):gsub("\n# Icon: [^\r\n]*", "\n# Icon: " .. escaped, 1)
    new = new:sub(2)
    if n == 0 then
        -- No icon line yet: add one right after the first line (the shebang).
        local first, rest = data:match("^([^\n]*\n)(.*)$")
        if first then
            new = first .. "# Icon: " .. image .. "\n" .. rest
        else
            new = data .. "\n# Icon: " .. image .. "\n"
        end
    end
    if new == data then return true end
    local ok, err = writeFile(launcher, new)
    if not ok then
        writeFile(launcher, data)
        return false, err
    end
    return true
end

-- Images in the icon folder: { path, stem } sorted by file name.
function M.list(dir, lfs)
    dir = dir or M.ICON_DIR
    local icons = {}
    local ok, iter, dir_obj = pcall(lfs.dir, dir)
    if not ok then return icons end
    for name in iter, dir_obj do
        local stem, ext = name:match("^([^.].*)%.(%w+)$")
        if stem and (ext:lower() == "png" or ext:lower() == "jpg" or ext:lower() == "jpeg") then
            icons[#icons + 1] = { path = dir .. "/" .. name, stem = stem }
        end
    end
    table.sort(icons, function(a, b) return a.stem < b.stem end)
    return icons
end

return M
