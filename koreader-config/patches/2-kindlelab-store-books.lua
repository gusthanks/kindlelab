--[[
KindleLab user patch: Kindle store books inside KOReader.

What it does
  * Shows Amazon store books in KOReader's file browser: KFX, Topaz (.azw1), AZW3/AZW4 and
    DRM-protected MOBI/AZW files. KOReader cannot read them, so they get the stock Kindle
    cover and title, and tapping one closes KOReader and opens the book in the Kindle's own
    reader (KOReader's launcher pauses the stock KFX services while KOReader runs).
  * Keep the books in the main documents folder: the Kindle expects store books there (one opened
    from a subfolder was downloaded again into documents/ by the stock system).

What it does NOT do
  * It never reads, decrypts or converts the contents of a protected book. It only reads the
    stock catalog (/var/local/cc.db, read-only) and the stock cover thumbnails.

Tested on: Kindle Paperwhite 3 (FW 5.16.2.1.1), KOReader v2026.07.1, SimpleUI 3.0.1.
License: MIT (KindleLab).
]]

local logger = require("logger")

local function setup()
    local Device = require("device")
    if not Device:isKindle() then return end

    local Document = require("document/document")
    local DocumentRegistry = require("document/documentregistry")
    local UIManager = require("ui/uimanager")
    local lfs = require("libs/libkoreader-lfs")

    local CCDB = "/var/local/cc.db"
    local THUMB_DIR = "/mnt/us/system/thumbnails/"
    local READER_URI = "app://com.lab126.booklet.reader"
    -- Formats KOReader cannot read at all: always handed to the stock reader.
    local STOCK_ONLY = { kfx = true, azw1 = true, azw3 = true, azw4 = true }
    -- Formats KOReader reads unless they are DRM-protected.
    local MOBI_FAMILY = { azw = true, mobi = true, prc = true }

    local function suffix(path)
        return (path:match("%.([^./]+)$") or ""):lower()
    end

    -- PalmDB/MOBI header: record 0 starts at the offset stored at byte 78; its bytes 12-13 hold
    -- the encryption type (0 = none, 1 = old Mobipocket, 2 = Mobipocket DRM). Header only.
    local function mobiEncrypted(path)
        local f = io.open(path, "rb")
        if not f then return false end
        local head = f:read(82)
        local enc
        if head and #head == 82 and head:sub(61, 68) == "BOOKMOBI" then
            local b1, b2, b3, b4 = head:byte(79, 82)
            f:seek("set", ((b1 * 256 + b2) * 256 + b3) * 256 + b4 + 12)
            enc = f:read(2)
        end
        f:close()
        if not enc or #enc < 2 then return false end
        local e1, e2 = enc:byte(1, 2)
        return e1 * 256 + e2 ~= 0
    end

    local drm_cache = {}
    local function isStoreBook(path)
        if type(path) ~= "string" then return false end
        local ext = suffix(path)
        if STOCK_ONLY[ext] then return true end
        if not MOBI_FAMILY[ext] or path:find("/dictionaries/", 1, true) then return false end
        local mtime = lfs.attributes(path, "modification")
        if not mtime then return false end
        local cached = drm_cache[path]
        if cached and cached.mtime == mtime then return cached.store end
        local store = mobiEncrypted(path)
        drm_cache[path] = { mtime = mtime, store = store }
        return store
    end

    -- Stock catalog, keyed by file name: entries still match right after books were moved into
    -- folders, before the stock scanner has caught up with the new paths.
    local catalog, catalog_mtime
    local function catalogEntry(path)
        local mtime = lfs.attributes(CCDB, "modification")
        if not catalog or catalog_mtime ~= mtime then
            catalog, catalog_mtime = {}, mtime
            local ok, err = pcall(function()
                local SQ3 = require("lua-ljsqlite3/init")
                local conn = SQ3.open(CCDB, "ro")
                local res = conn:exec("SELECT p_location, p_cdeKey, p_cdeType, p_titles_0_nominal, j_credits"
                    .. " FROM Entries WHERE p_location LIKE '/mnt/us/documents/%'")
                conn:close()
                if res and res[1] then
                    for i, loc in ipairs(res[1]) do
                        local name = type(loc) == "string" and loc:match("([^/]+)$")
                        if name then
                            catalog[name] = { key = res[2][i], ctype = res[3][i], title = res[4][i], credits = res[5][i] }
                        end
                    end
                end
            end)
            if not ok then logger.warn("kindlelab-store: cannot read the stock catalog:", err) end
        end
        return catalog[path:match("([^/]+)$") or ""]
    end

    -- A "document" that only knows the catalog data and the cover thumbnail.
    local StockDoc = Document:extend{
        provider = "kindlelab_stock",
        provider_name = "Kindle",
    }

    function StockDoc:init()
        self.is_open = true
    end

    function StockDoc:getPageCount()
        return nil
    end

    function StockDoc:getProps()
        local entry = catalogEntry(self.file) or {}
        local authors
        if type(entry.credits) == "string" then
            local names = {}
            for name in entry.credits:gmatch('"display"%s*:%s*"(.-)"') do
                names[#names + 1] = name
            end
            if #names > 0 then authors = table.concat(names, "\n") end
        end
        return { title = entry.title, authors = authors }
    end

    function StockDoc:getCoverPageImage()
        local entry = catalogEntry(self.file)
        if not (entry and entry.key and entry.ctype) then return end
        local thumb = THUMB_DIR .. "thumbnail_" .. entry.key .. "_" .. entry.ctype .. "_portrait.jpg"
        if lfs.attributes(thumb, "mode") ~= "file" then return end
        return require("ui/renderimage"):renderImageFile(thumb, false)
    end

    function StockDoc:close()
        if self.is_open and DocumentRegistry:closeDocument(self.file) == 0 then
            self.is_open = false
        end
        return true
    end

    for ext in pairs(STOCK_ONLY) do
        DocumentRegistry:addProvider(ext, "application/x-kindlelab-" .. ext, StockDoc, 100)
    end

    local orig_getProvider = DocumentRegistry.getProvider
    DocumentRegistry.getProvider = function(self, file, include_aux)
        if isStoreBook(file) then return StockDoc end
        return orig_getProvider(self, file, include_aux)
    end

    local function shq(s)
        return "'" .. s:gsub("'", "'\\''") .. "'"
    end

    -- The application manager wants a percent-encoded path (spaces, accents, parentheses...).
    local function uriPath(path)
        return (path:gsub("[^%w%-%._~/]", function(c) return string.format("%%%02X", c:byte()) end))
    end

    local function ownPid()
        local f = io.open("/proc/self/stat", "r")
        if not f then return 0 end
        local pid = f:read("*n")
        f:close()
        return pid or 0
    end

    local function openInStockReader(file)
        local InfoMessage = require("ui/widget/infomessage")
        UIManager:show(InfoMessage:new{ text = "Abrindo no leitor do Kindle…", timeout = 5 })
        UIManager:forceRePaint()
        -- Once KOReader is gone, its launcher restarts the stock services it paused (kfxreader,
        -- scanner...). Wait for them, then ask the application manager to open the book.
        -- NOTE: BusyBox sleep on the Kindle only takes whole seconds.
        local job = "i=0; while kill -0 " .. ownPid() .. " 2>/dev/null && [ $i -lt 60 ]; do sleep 1; i=$((i+1)); done; "
            .. "i=0; until /sbin/initctl status kfxreader 2>/dev/null | grep -q running || [ $i -ge 20 ]; do sleep 1; i=$((i+1)); done; "
            .. "sleep 2; lipc-set-prop com.lab126.appmgrd start " .. shq(READER_URI .. uriPath(file))
        os.execute("setsid sh -c " .. shq(job) .. " >/dev/null 2>&1 </dev/null &")
        logger.info("kindlelab-store: handing over to the stock reader:", file)
        UIManager:scheduleIn(0.3, function()
            local ReaderUI = require("apps/reader/readerui")
            local FileManager = require("apps/filemanager/filemanager")
            if ReaderUI.instance then ReaderUI.instance:onClose() end
            if FileManager.instance then FileManager.instance:onClose() end
            UIManager:quit()
        end)
    end

    local ReaderUI = require("apps/reader/readerui")
    local orig_showReader = ReaderUI.showReader
    ReaderUI.showReader = function(self, file, provider, ...)
        if type(file) == "string" and lfs.attributes(file, "mode") == "file"
                and (provider == StockDoc or (provider == nil and isStoreBook(file))) then
            return openInStockReader(file)
        end
        return orig_showReader(self, file, provider, ...)
    end

    -- Covers that were missing when a book was indexed (the stock thumbnail appears later, or a
    -- custom cover was added): forget those cache rows, so the library sync indexes them again.
    UIManager:scheduleIn(15, function()
        local ok, err = pcall(function()
            local BookInfoManager = package.loaded["bookinfomanager"]
            if not BookInfoManager then return end
            BookInfoManager:openDbConnection()
            local res = BookInfoManager.db_conn:exec(
                "SELECT directory, filename FROM bookinfo WHERE coalesce(has_cover, '') <> 'Y';")
            if not (res and res[1]) then return end
            local DocSettings = require("docsettings")
            for i, directory in ipairs(res[1]) do
                local path = directory .. res[2][i]
                local retry = DocSettings:findCustomCoverFile(path) ~= nil
                if not retry and isStoreBook(path) then
                    local entry = catalogEntry(path)
                    retry = entry ~= nil and entry.key ~= nil and lfs.attributes(THUMB_DIR .. "thumbnail_"
                        .. entry.key .. "_" .. tostring(entry.ctype) .. "_portrait.jpg", "mode") == "file"
                end
                if retry then BookInfoManager:deleteBookInfo(path) end
            end
        end)
        if not ok then logger.warn("kindlelab-store: cover retry failed:", err) end
    end)

end

local ok, err = pcall(setup)
if not ok then logger.warn("kindlelab-store: patch not applied:", err) end
