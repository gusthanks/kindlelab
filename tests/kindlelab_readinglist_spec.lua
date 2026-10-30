-- Tests for koreader-config/plugins/kindlelab.koplugin/kindlelab_readinglist.lua (pure Lua, no KOReader).
-- Run: tests/run.sh   (or: luajit tests/kindlelab_readinglist_spec.lua from the repo root)

package.path = "koreader-config/plugins/kindlelab.koplugin/?.lua;" .. package.path
local R = require("kindlelab_readinglist")

local tests, failures = {}, 0
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end
local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
    end
end

test("basename strips folders", function()
    eq(R.basename("/mnt/us/documents/Livro bom.epub"), "Livro bom.epub")
    eq(R.basename("solto.pdf"), "solto.pdf")
end)

test("entries follow the manual collection order, not table order", function()
    local coll = {
        ["/mnt/us/documents/b.epub"] = { file = "/mnt/us/documents/b.epub", order = 2 },
        ["/mnt/us/documents/a.epub"] = { file = "/mnt/us/documents/a.epub", order = 1 },
        ["/mnt/us/documents/c.epub"] = { file = "/mnt/us/documents/c.epub", order = 3 },
    }
    local list = R.entries(coll, nil)
    eq(#list, 3)
    eq(list[1].file, "/mnt/us/documents/a.epub")
    eq(list[3].file, "/mnt/us/documents/c.epub")
    eq(list[2].position, 2)
end)

test("items without order keep a stable alphabetical order after the ordered ones", function()
    local coll = {
        ["/x/z.epub"] = { file = "/x/z.epub" },
        ["/x/y.epub"] = { file = "/x/y.epub" },
        ["/x/first.epub"] = { file = "/x/first.epub", order = 1 },
    }
    local list = R.entries(coll, nil)
    eq(list[1].file, "/x/first.epub")
    eq(list[2].file, "/x/y.epub")
    eq(list[3].file, "/x/z.epub")
end)

test("study notes are matched by file name and fall back to the file name", function()
    local coll = {
        ["/d/manifesto.epub"] = { file = "/d/manifesto.epub", order = 1 },
        ["/d/outro.pdf"] = { file = "/d/outro.pdf", order = 2 },
    }
    local notes = { books = { ["manifesto.epub"] = { title = "Manifesto", stage = "Etapa 1", note = "Leia duas vezes." } } }
    local list = R.entries(coll, notes)
    eq(list[1].title, "Manifesto")
    eq(list[1].stage, "Etapa 1")
    eq(list[1].note, "Leia duas vezes.")
    eq(list[2].title, "outro.pdf")
    eq(list[2].note, nil)
end)

test("menu label numbers the books and shows the stage", function()
    eq(R.label({ position = 3, title = "O 18 de Brumário", stage = "Etapa 1" }), "3. O 18 de Brumário · Etapa 1")
    eq(R.label({ position = 1, title = "Livro" }), "1. Livro")
end)

test("loadNotes accepts only a table with optional books/guide/buy fields", function()
    eq(R.validNotes(nil), nil)
    eq(R.validNotes("texto"), nil)
    eq(R.validNotes({ books = "errado" }), nil)
    local ok = R.validNotes({ guide = "Método", buy = { "A" }, books = {} })
    eq(type(ok), "table")
    eq(ok.guide, "Método")
    local empty = R.validNotes({})
    eq(type(empty.books), "table")
    eq(type(empty.buy), "table")
end)

test("loadNotes returns an empty structure when the file is missing or broken", function()
    local n = R.loadNotes("/nao/existe/estudo.lua")
    eq(type(n.books), "table")
    eq(next(n.books), nil)
end)

test("buyText lists books to buy one per line", function()
    eq(R.buyText({ buy = { "Livro A — Autor", "Livro B" } }), "• Livro A — Autor\n• Livro B")
    eq(R.buyText({ buy = {} }), nil)
end)

for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then print("ok   " .. t.name) else failures = failures + 1; print("FAIL " .. t.name .. "\n     " .. tostring(err)) end
end
print(string.format("%d tests, %d failures", #tests, failures))
os.exit(failures == 0 and 0 or 1)
