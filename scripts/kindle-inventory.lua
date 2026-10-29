-- KindleLab: inventory of the books on a Kindle, for scripts/kindle-new-books.py (read-only).
-- Runs ON the Kindle with KOReader's LuaJIT:  ssh kindle 'cd /mnt/us/koreader && ./luajit -' < kindle-inventory.lua
-- Prints JSON: one entry per book file under the documents folder with size, modification time and the
-- KOReader custom metadata (title/authors/keywords) of its .sdr folder. Never writes anything.

package.path = "./common/?.lua;./frontend/?.lua;" .. package.path
local json = require("dkjson")
local lfs = require("libs/libkoreader-lfs")

local ROOT = os.getenv("KINDLELAB_DOCUMENTS") or "/mnt/us/documents"
local SKIP_DIRS = { ["dictionaries"] = true, ["Notícias"] = true }
local SKIP_FILES = { ["My Clippings.txt"] = true }
local BOOK_EXTENSIONS = {}
for ext in ("epub pdf mobi azw azw1 azw3 azw4 kfx prc pdb fb2 fbz txt rtf doc docx odt html htm xhtml md chm "
        .. "cbz cbr cb7 cbt djvu xps"):gmatch("%S+") do
    BOOK_EXTENSIONS[ext] = true
end

local function settings(path)
    local f = loadfile(path)
    if not f then return {} end
    setfenv(f, {})
    local ok, t = pcall(f)
    return ok and type(t) == "table" and t or {}
end

local function pick(t)
    local r = setmetatable({}, { __jsontype = "object" }) -- encode {} as an object, not an array
    for _, key in ipairs({ "title", "authors", "keywords", "language", "series", "description" }) do
        if type(t[key]) == "string" then r[key] = t[key] end
    end
    return r
end

local books = {}
local function walk(dir, depth)
    for name in lfs.dir(dir) do
        if name:sub(1, 1) ~= "." then
            local path = dir .. "/" .. name
            local attr = lfs.attributes(path)
            if attr and attr.mode == "directory" then
                if depth < 3 and not name:match("%.sdr$") and not SKIP_DIRS[name] then walk(path, depth + 1) end
            elseif attr and attr.mode == "file" and not SKIP_FILES[name] then
                local ext = (name:match("%.([^%.]+)$") or ""):lower()
                if BOOK_EXTENSIONS[ext] then
                    local sdr = dir .. "/" .. name:gsub("%.[^%.]+$", "") .. ".sdr"
                    local cm = settings(sdr .. "/custom_metadata.lua")
                    local cover = false
                    for _, s in ipairs({ "jpg", "jpeg", "png", "webp", "gif" }) do
                        if lfs.attributes(sdr .. "/cover." .. s, "mode") == "file" then cover = true end
                    end
                    books[#books + 1] = {
                        path = path, ext = ext, bytes = attr.size, mtime = attr.modification,
                        custom = pick(cm.custom_props or {}), original = pick(cm.doc_props or {}),
                        custom_cover = cover,
                        opened_in_koreader = lfs.attributes(sdr .. "/metadata." .. ext .. ".lua", "mode") == "file",
                    }
                end
            end
        end
    end
end

walk(ROOT, 0)
table.sort(books, function(a, b) return a.path < b.path end)
io.write(json.encode(books))
