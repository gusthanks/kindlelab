-- Tests for koreader-config/plugins/kindlelab.koplugin/kindlelab_types.lua (pure Lua, no KOReader).
-- Run: tests/run.sh   (or: luajit tests/kindlelab_types_spec.lua from the repo root)

package.path = "koreader-config/plugins/kindlelab.koplugin/?.lua;" .. package.path
local T = require("kindlelab_types")

local tests, failures = {}, 0
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end
local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
    end
end
local function listEq(actual, expected, what)
    eq(type(actual), "table", what)
    eq(table.concat(actual, "|"), table.concat(expected, "|"), what)
end

-- A fake MOBI header: 60-byte PDB name, "BOOKMOBI" at 60, record 0 offset (big endian) at 78,
-- encryption type (2 bytes) at record0 + 12.
local function fakeMobi(encryption)
    local record0 = 96
    local head = string.rep("n", 60) .. "BOOKMOBI" .. string.rep("\0", 10)
        .. string.char(0, 0, 0, record0) .. string.rep("\0", record0 - 82)
    return head .. string.rep("\0", 12) .. string.char(math.floor(encryption / 256), encryption % 256)
        .. string.rep("\0", 20)
end
local function readerFor(data)
    return function(offset, len) return data:sub(offset + 1, offset + len) end
end

test("extension is lower case and ignores folders with dots", function()
    eq(T.extension("/mnt/us/documents/Livro.PDF"), "pdf")
    eq(T.extension("/mnt/us/doc.s/sem_extensao"), nil)
    eq(T.extension("a.b/c.epub"), "epub")
end)

test("mobiEncryption reads the encryption type of a MOBI header", function()
    eq(T.mobiEncryption(readerFor(fakeMobi(0))), 0, "DRM-free")
    eq(T.mobiEncryption(readerFor(fakeMobi(2))), 2, "Mobipocket DRM")
end)

test("mobiEncryption returns nil for files that are not MOBI", function()
    eq(T.mobiEncryption(readerFor("%PDF-1.7 " .. string.rep("x", 200))), nil, "pdf")
    eq(T.mobiEncryption(readerFor("curto")), nil, "short file")
end)

test("countLetters counts ASCII and accented letters, not digits or spaces", function()
    eq(T.countLetters("Olá, mundo 123"), 8)
    eq(T.countLetters(""), 0)
    eq(T.countLetters(nil), 0)
end)

test("lettersInTextBoxes sums the words of nested text boxes", function()
    local boxes = { { { word = "Olá" }, { word = "mundo" } }, { { word = "123" } }, size = 42 }
    eq(T.lettersInTextBoxes(boxes), 8)
    eq(T.lettersInTextBoxes(nil), 0)
end)

test("samplePages spreads pages and avoids the cover when the book is long", function()
    listEq(T.samplePages(100, 6), { 9, 26, 42, 59, 76, 92 })
    listEq(T.samplePages(4, 6), { 1, 2, 3, 4 })
    listEq(T.samplePages(0, 6), {})
end)

test("isScanned: pages without text mean a scanned PDF", function()
    eq(T.isScanned({ 0, 0, 3, 0, 0, 0 }), true, "image pages")
    eq(T.isScanned({ 1800, 2100, 0, 1500, 2300, 1900 }), false, "text with one picture page")
    eq(T.isScanned({ 1200, 0, 0, 0, 0, 0 }), true, "only one page with text")
    eq(T.isScanned({}), nil, "no sample")
end)

test("tag helpers keep order, avoid duplicates and match whole lines", function()
    local kw = "História\nTipo: PDF"
    eq(T.hasTag(kw, "Tipo: PDF"), true)
    eq(T.hasTag(kw, "Tipo: PD"), false, "partial line")
    eq(T.hasTypeTag(kw), true)
    eq(T.hasTypeTag("História"), false)
    eq(T.hasTypeTag(nil), false)
    eq(T.withTags(kw, { "Tipo: Escaneado", "Tipo: PDF" }), "História\nTipo: PDF\nTipo: Escaneado")
    eq(T.withTags(kw, { T.TAGS.comic }, { T.TAGS.pdf }), "História\nTipo: Quadrinho")
    eq(T.withTags(nil, { "Tipo: Livro" }), "Tipo: Livro")
    eq(T.withTags("Tipo: PDF", nil, { "Tipo: PDF" }), nil, "empty result")
end)

test("classify by format", function()
    listEq(T.classify("kfx"), { "Tipo: Amazon" }, "kfx")
    listEq(T.classify("azw1"), { "Tipo: Amazon" }, "topaz")
    listEq(T.classify("azw", { encryption = 2 }), { "Tipo: Amazon" }, "mobi with DRM")
    listEq(T.classify("mobi", { encryption = 0 }), { "Tipo: Livro" }, "mobi without DRM")
    listEq(T.classify("epub"), { "Tipo: Livro" }, "epub")
    listEq(T.classify("pdf", { scanned = false }), { "Tipo: PDF" }, "text pdf")
    listEq(T.classify("pdf", { scanned = true }), { "Tipo: PDF", "Tipo: Escaneado" }, "scanned pdf")
    listEq(T.classify("pdf"), { "Tipo: PDF" }, "pdf not analysed")
    listEq(T.classify("djvu"), { "Tipo: Escaneado" }, "djvu")
    listEq(T.classify("cbz"), { "Tipo: Quadrinho" }, "comic archive")
    listEq(T.classify("xyz"), {}, "unknown format")
end)

test("tagsToAdd: new books get every type tag", function()
    listEq(T.tagsToAdd(nil, "pdf", { scanned = true }), { "Tipo: PDF", "Tipo: Escaneado" })
    listEq(T.tagsToAdd("Ficção", "epub", {}), { "Tipo: Livro" })
end)

test("tagsToAdd: already typed books only get the missing scan tag", function()
    listEq(T.tagsToAdd("Tipo: PDF", "pdf", { scanned = true }), { "Tipo: Escaneado" }, "scan found")
    listEq(T.tagsToAdd("Tipo: PDF", "pdf", { scanned = false }), {}, "text pdf")
    listEq(T.tagsToAdd("Tipo: PDF\nTipo: Quadrinho", "pdf", { scanned = true }), {}, "comics are not 'scanned'")
    listEq(T.tagsToAdd("Tipo: Livro", "epub", {}), {}, "nothing to do")
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
