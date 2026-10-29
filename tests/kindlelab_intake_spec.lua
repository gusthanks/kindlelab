-- Tests for kindlelab_intake.lua: tagging new books, with fake KOReader adapters.
-- Run: tests/run.sh

package.path = "koreader-config/plugins/kindlelab.koplugin/?.lua;" .. package.path
local Intake = require("kindlelab_intake")

local tests, failures = {}, 0
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end
local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what or "value", tostring(expected), tostring(actual)), 2)
    end
end

-- Fake adapters: a library of books with cached keywords; records every save and analysis.
local function fakeDeps(books, analysis)
    local d = { saved = {}, analysed = {}, asked = {} }
    function d.current(path)
        d.asked[#d.asked + 1] = path
        local b = books[path]
        if not b then return nil end
        return { keywords = b.keywords, original = { title = b.title, keywords = b.keywords } }
    end
    function d.analyze(path, ext)
        d.analysed[#d.analysed + 1] = path
        local a = analysis and analysis[path]
        if a == "boom" then error("cannot open " .. path) end
        return a or {}
    end
    function d.save(path, keywords, original)
        d.saved[#d.saved + 1] = { path = path, keywords = keywords, original = original }
        return true
    end
    return d
end

test("a new e-book gets its type tag and is remembered", function()
    local d = fakeDeps({ ["/b/Livro.epub"] = { keywords = "Ficção", title = "Livro" } })
    local state = { seen = {} }
    local result, added = Intake.processBook("/b/Livro.epub", d, state)
    eq(result, "tagged")
    eq(table.concat(added, "|"), "Tipo: Livro")
    eq(#d.saved, 1, "saves")
    eq(d.saved[1].keywords, "Ficção\nTipo: Livro")
    eq(d.saved[1].original.title, "Livro", "original props kept for the new custom file")
    eq(state.seen["/b/Livro.epub"], true, "remembered")
    eq(#d.analysed, 0, "e-books need no analysis")
end)

test("a book that is not indexed yet waits for the next run", function()
    local d = fakeDeps({})
    local state = { seen = {} }
    eq(Intake.processBook("/b/Novo.pdf", d, state), "pending")
    eq(state.seen["/b/Novo.pdf"], nil, "not remembered")
    eq(#d.saved, 0)
end)

test("books already handled are skipped without reading anything", function()
    local d = fakeDeps({ ["/b/X.pdf"] = { keywords = nil } })
    local state = { seen = { ["/b/X.pdf"] = true } }
    eq(Intake.processBook("/b/X.pdf", d, state), "seen")
    eq(#d.asked, 0, "no lookups")
end)

test("a typed PDF is analysed once and gets the scanned tag", function()
    local d = fakeDeps({ ["/b/Scan.pdf"] = { keywords = "História\nTipo: PDF" } },
        { ["/b/Scan.pdf"] = { scanned = true } })
    local state = { seen = {} }
    eq(Intake.processBook("/b/Scan.pdf", d, state), "tagged")
    eq(d.saved[1].keywords, "História\nTipo: PDF\nTipo: Escaneado")
end)

test("typed e-books and comics are left alone without analysis", function()
    local d = fakeDeps({
        ["/b/A.epub"] = { keywords = "Tipo: Livro" },
        ["/b/Comic.pdf"] = { keywords = "Tipo: PDF\nTipo: Quadrinho" },
    })
    local state = { seen = {} }
    eq(Intake.processBook("/b/A.epub", d, state), "unchanged")
    eq(Intake.processBook("/b/Comic.pdf", d, state), "unchanged")
    eq(#d.analysed, 0, "no analysis")
    eq(#d.saved, 0, "no writes")
    eq(state.seen["/b/Comic.pdf"], true)
end)

test("a PDF that cannot be analysed still gets its format tag", function()
    local d = fakeDeps({ ["/b/Quebrado.pdf"] = { keywords = nil } }, { ["/b/Quebrado.pdf"] = "boom" })
    local state = { seen = {} }
    eq(Intake.processBook("/b/Quebrado.pdf", d, state), "tagged")
    eq(d.saved[1].keywords, "Tipo: PDF")
end)

test("files that are not books are remembered and never read", function()
    local d = fakeDeps({})
    local state = { seen = {} }
    eq(Intake.processBook("/b/notas.xyz", d, state), "unsupported")
    eq(state.seen["/b/notas.xyz"], true)
    eq(#d.asked, 0)
end)

test("books KOReader cannot read are remembered and skipped", function()
    local d = fakeDeps({})
    d.current = function() return false end
    local state = { seen = {} }
    eq(Intake.processBook("/b/Ruim.epub", d, state), "unsupported")
    eq(state.seen["/b/Ruim.epub"], true)
    eq(#d.saved, 0)
end)

test("cache rows: in_progress 0 means indexed (0 is true in Lua)", function()
    local done = Intake.fromCacheRow({ in_progress = 0, title = "Livro", keywords = "Ficção", pages = 12 })
    eq(type(done), "table", "indexed row")
    eq(done.keywords, "Ficção")
    eq(done.original.title, "Livro")
    eq(done.original.pages, 12)
    eq(Intake.fromCacheRow({ in_progress = 1 }), nil, "still being indexed")
    eq(Intake.fromCacheRow({ in_progress = 0, unsupported = "no provider" }), false, "unreadable")
    eq(Intake.fromCacheRow(nil), nil, "no row yet")
end)

test("a failed save is retried next time", function()
    local d = fakeDeps({ ["/b/L.epub"] = { keywords = nil } })
    d.save = function() return nil, "read-only" end
    local state = { seen = {} }
    eq(Intake.processBook("/b/L.epub", d, state), "error")
    eq(state.seen["/b/L.epub"], nil)
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
