--[[
KindleLab user patch: a tidy library.

  * Hides what is not a book from KOReader's file browser: the dictionaries folder (the stock
    reader keeps using it), shell scripts (the KOReader/KUAL launchers on the stock home screen)
    and the stock "My Clippings.txt".
  * Hides folders that hold no book at all (e.g. an empty news or downloads folder).
  * Keeps CoverBrowser's book-info cache in sync with the disk, so SimpleUI's Authors and Tags
    views and the cover mosaic always match the library: 20 s after start-up it forgets deleted,
    moved or hidden files and indexes, in the background, the books it does not know yet.

Tested on: Kindle Paperwhite 3 (FW 5.16.2.1.1), KOReader v2026.07.1, SimpleUI 3.0.1.
License: MIT (KindleLab).
]]

local logger = require("logger")

local HIDDEN_DIRS = { "^dictionaries$" }
local HIDDEN_FILES = { "%.sh$", "^My Clippings%.txt$" }
-- Cover size stored in the cache (same as CoverBrowser's mosaic on a PW3, 3x2 grid).
local COVER_SPECS = { max_cover_w = 331, max_cover_h = 446 }

local function setup()
    local FileChooser = require("ui/widget/filechooser")
    local DocumentRegistry = require("document/documentregistry")
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")

    for _, p in ipairs(HIDDEN_DIRS) do table.insert(FileChooser.exclude_dirs, p) end
    for _, p in ipairs(HIDDEN_FILES) do table.insert(FileChooser.exclude_files, p) end

    local function matchesAny(name, patterns)
        for _, p in ipairs(patterns) do
            if name:match(p) then return true end
        end
        return false
    end

    local function showDir(name)
        return name:sub(1, 1) ~= "." and not matchesAny(name, FileChooser.exclude_dirs)
    end

    local function isBook(name, path)
        return name:sub(1, 1) ~= "." and not matchesAny(name, FileChooser.exclude_files)
            and DocumentRegistry:hasProvider(path)
    end

    -- Does this folder (or a subfolder, a few levels down) hold at least one book?
    local found_cache = {}
    local function hasBook(dir, depth)
        if depth > 3 then return true end
        local mtime = lfs.attributes(dir, "modification")
        local cached = found_cache[dir]
        if cached and cached.mtime == mtime then return cached.found end
        local found = false
        local ok, iter, dir_obj = pcall(lfs.dir, dir)
        if ok then
            for name in iter, dir_obj do
                if name ~= "." and name ~= ".." then
                    local path = dir .. "/" .. name
                    local mode = lfs.attributes(path, "mode")
                    if (mode == "file" and isBook(name, path))
                            or (mode == "directory" and showDir(name) and hasBook(path, depth + 1)) then
                        found = true
                        pcall(dir_obj.close, dir_obj)
                        break
                    end
                end
            end
        end
        found_cache[dir] = { mtime = mtime, found = found }
        return found
    end

    local orig_getPathList = FileChooser.getPathList
    FileChooser.getPathList = function(self, path, collate, dirs, files)
        local first = #dirs + 1
        orig_getPathList(self, path, collate, dirs, files)
        for i = #dirs, first, -1 do
            local item = dirs[i]
            local p = type(item) == "table" and item.path
            if p and lfs.attributes(p, "mode") == "directory" and not hasBook(p, 0) then
                table.remove(dirs, i)
            end
        end
    end

    -- Book-info cache sync.
    local function walk(dir, out)
        local ok, iter, dir_obj = pcall(lfs.dir, dir)
        if not ok then return end
        for name in iter, dir_obj do
            if name ~= "." and name ~= ".." then
                local path = dir .. "/" .. name
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    if showDir(name) then walk(path, out) end
                elseif mode == "file" and isBook(name, path) then
                    out[#out + 1] = path
                end
            end
        end
    end

    local function isHiddenPath(directory, filename)
        if matchesAny(filename, FileChooser.exclude_files) then return true end
        for segment in directory:gmatch("[^/]+") do
            if matchesAny(segment, HIDDEN_DIRS) then return true end
        end
        return false
    end

    UIManager:scheduleIn(20, function()
        local ok, err = pcall(function()
            local BookInfoManager = package.loaded["bookinfomanager"]
            if not BookInfoManager then return end
            BookInfoManager:removeNonExistantEntries()
            local res = BookInfoManager.db_conn and BookInfoManager.db_conn:exec("SELECT directory, filename FROM bookinfo;")
            if res and res[1] then
                for i, directory in ipairs(res[1]) do
                    local filename = res[2][i]
                    if isHiddenPath(directory, filename) then
                        BookInfoManager:deleteBookInfo(directory .. filename)
                    end
                end
            end
            local books = {}
            walk(G_reader_settings:readSetting("home_dir") or "/mnt/us/documents", books)
            local todo = {}
            for _, path in ipairs(books) do
                if not BookInfoManager:getBookInfo(path, false) then
                    todo[#todo + 1] = { filepath = path, cover_specs = COVER_SPECS }
                end
            end
            if #todo > 0 then
                logger.info("kindlelab-library: indexing", #todo, "books in the background")
                BookInfoManager:extractInBackground(todo)
            end
        end)
        if not ok then logger.warn("kindlelab-library: library sync failed:", err) end
    end)
end

local ok, err = pcall(setup)
if not ok then logger.warn("kindlelab-library: patch not applied:", err) end
