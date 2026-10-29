--[[
KindleLab: give new books their type tag ("Tipo: …") without touching the book files.

processBook() is pure and tested on a PC with fake adapters (tests/kindlelab_intake_spec.lua).
koreaderAdapters() wires it to KOReader:
  * current(): the book's custom metadata (custom_metadata.lua in its .sdr) or, for books without one,
    the original metadata from the CoverBrowser cache (nil = not indexed yet, false = unreadable);
  * analyze(): MOBI/AZW header (DRM flag) or, for PDFs, the text layer of up to six pages;
  * save(): writes the keywords to custom_metadata.lua and updates the cache row.
]]

local T = require("kindlelab_types")

local Intake = {}

-- What needs a look inside the file, and only when the answer can still change the tags.
local ANALYSIS = { pdf = "scan", mobi = "drm", azw = "drm", prc = "drm" }

local function needsAnalysis(keywords, ext)
    local kind = ANALYSIS[ext]
    if not kind then return false end
    if not T.hasTypeTag(keywords) then return true end
    return kind == "scan" and not T.hasTag(keywords, T.TAGS.comic) and not T.hasTag(keywords, T.TAGS.scanned)
end

-- Handles one book. state.seen[path] = true once nothing more is to be done for it.
-- Returns "seen" | "unsupported" | "pending" | "unchanged" | "tagged", added_tags | "error", message
function Intake.processBook(path, deps, state)
    if state.seen[path] then return "seen" end
    local ext = T.extension(path)
    if #T.classify(ext, {}) == 0 then
        state.seen[path] = true
        return "unsupported"
    end
    local current = deps.current(path)
    if current == false then
        state.seen[path] = true
        return "unsupported"
    end
    if not current then return "pending" end

    local opts = {}
    if needsAnalysis(current.keywords, ext) then
        local ok, result = pcall(deps.analyze, path, ext)
        if ok and type(result) == "table" then opts = result end
    end
    local add = T.tagsToAdd(current.keywords, ext, opts)
    if #add == 0 then
        state.seen[path] = true
        return "unchanged"
    end
    local ok, err = deps.save(path, T.withTags(current.keywords, add), current.original)
    if not ok then return "error", err end
    state.seen[path] = true
    return "tagged", add
end

local ORIGINAL_PROPS = { "title", "authors", "series", "series_index", "language", "keywords", "description", "pages" }

-- Interprets a CoverBrowser cache row: nil = not indexed yet, false = KOReader cannot read the book,
-- otherwise { keywords, original } where original = the book's own metadata (no custom file exists yet).
-- in_progress is 0 when done and > 0 while indexing (careful: 0 is true in Lua).
function Intake.fromCacheRow(info)
    if not info or (tonumber(info.in_progress) or 0) > 0 then return nil end
    if info.unsupported then return false end
    local original = {}
    for _, key in ipairs(ORIGINAL_PROPS) do original[key] = info[key] end
    return { keywords = info.keywords, original = original }
end

function Intake.koreaderAdapters()
    local DocSettings = require("docsettings")
    local DocumentRegistry = require("document/documentregistry")
    local BookInfoManager = package.loaded["bookinfomanager"] -- loaded by the CoverBrowser plugin

    local function customFile(path)
        local file = DocSettings:findCustomMetadataFile(path)
        return file and DocSettings.openSettingsFile(file)
    end

    local deps = {}

    function deps.current(path)
        local custom = customFile(path)
        if custom then
            local custom_props = custom:readSetting("custom_props") or {}
            local keywords = custom_props.keywords
            if keywords == nil then keywords = (custom:readSetting("doc_props") or {}).keywords end
            return { keywords = keywords }
        end
        if not BookInfoManager then return nil end
        return Intake.fromCacheRow(BookInfoManager:getBookInfo(path, false))
    end

    function deps.analyze(path, ext)
        if ext == "pdf" then
            local doc = DocumentRegistry:openDocument(path)
            if not doc then return {} end
            local ok, result = pcall(function()
                if doc.is_locked or not doc.getPageTextBoxes then return {} end
                local counts = {}
                for _, page in ipairs(T.samplePages(doc:getPageCount(), 6)) do
                    counts[#counts + 1] = T.lettersInTextBoxes(doc:getPageTextBoxes(page))
                end
                return { scanned = T.isScanned(counts) }
            end)
            doc:close()
            if not ok then error(result) end
            return result
        end
        local f = io.open(path, "rb")
        if not f then return {} end
        local encryption = T.mobiEncryption(function(offset, length)
            f:seek("set", offset)
            return f:read(length)
        end)
        f:close()
        return { encryption = encryption }
    end

    function deps.save(path, keywords, original)
        local custom = customFile(path)
        if not custom then
            custom = DocSettings.openSettingsFile()
            custom:saveSetting("doc_props", original or {}) -- copy of the original metadata, as KOReader does
        end
        local custom_props = custom:readSetting("custom_props", {})
        custom_props.keywords = keywords
        if not custom:flushCustomMetadata(path) then return nil, "could not write custom metadata" end
        if BookInfoManager then
            pcall(BookInfoManager.setBookInfoProperties, BookInfoManager, path, { keywords = keywords })
        end
        return true
    end

    return deps
end

return Intake
