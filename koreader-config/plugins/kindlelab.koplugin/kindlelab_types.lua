--[[
KindleLab: book type tags ("Tipo: …") for the library's Tags (Etiquetas).

Pure Lua, no KOReader dependencies, so it can be unit tested on a PC (tests/kindlelab_types_spec.lua).
Tags live in the book's KOReader custom metadata (keywords, one per line); the book file is never changed.
]]

local M = {}

M.TAGS = {
    amazon = "Tipo: Amazon",      -- opens in the Kindle's own reader (store books, KFX, Topaz, DRM)
    book = "Tipo: Livro",         -- reflowable e-book opened by KOReader
    pdf = "Tipo: PDF",
    scanned = "Tipo: Escaneado",  -- pages are pictures (no text layer)
    comic = "Tipo: Quadrinho",
}

local TYPE_PREFIX = "Tipo:"
local STOCK_ONLY = { kfx = true, azw1 = true, azw3 = true, azw4 = true }
local MOBI_FAMILY = { mobi = true, azw = true, prc = true }
local REFLOWABLE = { epub = true, fb2 = true, fbz = true, txt = true, rtf = true, doc = true, docx = true,
    html = true, htm = true, xhtml = true, md = true, chm = true, odt = true, pdb = true }
local COMIC_ARCHIVES = { cbz = true, cbr = true, cb7 = true, cbt = true }

-- Lower-case file extension, or nil.
function M.extension(path)
    local ext = tostring(path):match("%.([^%./]+)$")
    return ext and ext:lower() or nil
end

-- MOBI/AZW encryption type (0 = none, 1 = old Mobipocket, 2 = Mobipocket DRM), or nil when the file is
-- not a MOBI. read_at(offset, length) returns the bytes at that offset (header only, never the content).
function M.mobiEncryption(read_at)
    local head = read_at(0, 82)
    if not head or #head < 82 or head:sub(61, 68) ~= "BOOKMOBI" then return nil end
    local a, b, c, d = head:byte(79, 82)
    local record0 = ((a * 256 + b) * 256 + c) * 256 + d
    local enc = read_at(record0 + 12, 2)
    if not enc or #enc < 2 then return nil end
    local x, y = enc:byte(1, 2)
    return x * 256 + y
end

-- Letters in a UTF-8 string: ASCII letters plus one per multibyte character (accented letters).
function M.countLetters(s)
    if type(s) ~= "string" then return 0 end
    local _, ascii = s:gsub("%a", "")
    local _, multibyte = s:gsub("[\194-\244]", "")
    return ascii + multibyte
end

-- Letters in the words of a page's text boxes (any nesting of tables with `word` fields).
function M.lettersInTextBoxes(boxes)
    if type(boxes) ~= "table" then return 0 end
    local total = 0
    for _, v in pairs(boxes) do
        if type(v) == "table" then
            total = total + M.lettersInTextBoxes(v)
        end
    end
    if type(boxes.word) == "string" then
        total = total + M.countLetters(boxes.word)
    end
    return total
end

-- Up to `max` page numbers spread over the book (centres of equal parts; skips the cover in long books).
function M.samplePages(n, max)
    local pages = {}
    if not n or n < 1 then return pages end
    if n <= max then
        for p = 1, n do pages[#pages + 1] = p end
        return pages
    end
    for i = 1, max do
        local p = math.floor((i - 0.5) * n / max) + 1
        if pages[#pages] ~= p then pages[#pages + 1] = p end
    end
    return pages
end

-- true when fewer than 30 % of the sampled pages have real text (50+ letters); nil without a sample.
function M.isScanned(letter_counts)
    if not letter_counts or #letter_counts == 0 then return nil end
    local with_text = 0
    for _, c in ipairs(letter_counts) do
        if c >= 50 then with_text = with_text + 1 end
    end
    return with_text * 10 < #letter_counts * 3
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function splitTags(keywords)
    local tags = {}
    if type(keywords) ~= "string" then return tags end
    for line in keywords:gmatch("[^\n]+") do
        line = trim(line)
        if line ~= "" then tags[#tags + 1] = line end
    end
    return tags
end

function M.hasTag(keywords, tag)
    for _, t in ipairs(splitTags(keywords)) do
        if t == tag then return true end
    end
    return false
end

function M.hasTypeTag(keywords)
    for _, t in ipairs(splitTags(keywords)) do
        if t:sub(1, #TYPE_PREFIX) == TYPE_PREFIX then return true end
    end
    return false
end

-- Keywords with `add` appended (if missing) and `remove` dropped; nil when nothing is left.
function M.withTags(keywords, add, remove)
    local drop, seen, out = {}, {}, {}
    for _, t in ipairs(remove or {}) do drop[t] = true end
    local function push(t)
        if not drop[t] and not seen[t] then
            seen[t] = true
            out[#out + 1] = t
        end
    end
    for _, t in ipairs(splitTags(keywords)) do push(t) end
    for _, t in ipairs(add or {}) do push(t) end
    return #out > 0 and table.concat(out, "\n") or nil
end

-- Type tags for a file format. opts.encryption: MOBI encryption type; opts.scanned: PDF analysis result.
function M.classify(ext, opts)
    opts = opts or {}
    if STOCK_ONLY[ext] then return { M.TAGS.amazon } end
    if MOBI_FAMILY[ext] then
        return { (opts.encryption or 0) ~= 0 and M.TAGS.amazon or M.TAGS.book }
    end
    if ext == "pdf" then
        return opts.scanned and { M.TAGS.pdf, M.TAGS.scanned } or { M.TAGS.pdf }
    end
    if ext == "djvu" then return { M.TAGS.scanned } end
    if COMIC_ARCHIVES[ext] then return { M.TAGS.comic } end
    if REFLOWABLE[ext] then return { M.TAGS.book } end
    return {}
end

-- Tags to add to a book that may already have tags: untyped books get every type tag; typed books only get
-- the "scanned" tag when the analysis finds one (never on comics, which have their own profile).
function M.tagsToAdd(keywords, ext, opts)
    if not M.hasTypeTag(keywords) then return M.classify(ext, opts) end
    opts = opts or {}
    if (ext == "pdf" or ext == "djvu") and opts.scanned
            and not M.hasTag(keywords, M.TAGS.comic) and not M.hasTag(keywords, M.TAGS.scanned) then
        return { M.TAGS.scanned }
    end
    return {}
end

return M
