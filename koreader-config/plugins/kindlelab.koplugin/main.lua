--[[
KindleLab plugin (Tools > KindleLab).

* Type tags for new books: some seconds after the library opens, books not seen before get a
  "Tipo: …" tag (Livro, PDF, Escaneado, Quadrinho, Amazon) in their KOReader custom metadata. The book
  files are never changed. PDFs are checked for a text layer (six sample pages) to spot scanned books.
* Reading profiles: adds "KindleLab: Escaneado" (crop margins + more contrast) and "KindleLab: Quadrinho"
  (whole page) to Tools > Profiles, run automatically the FIRST time a book with that tag is opened.
* Comics: while a "Tipo: Quadrinho" book is open, every page turn does a full e-ink refresh (no ghosting).
  Reader menu: KindleLab > "This book is a comic" adds/removes the tag.
* Kindle only: KindleLab > "Kindle home screen icon" points the KOReader tile of the stock Kindle home
  screen at an image of koreader/kindlelab/icons/ (tap = use it, hold = preview).

Tested on: Kindle Paperwhite 3 (FW 5.16.2.1.1), KOReader v2026.07.1, SimpleUI 3.0.1.
License: MIT (KindleLab).
]]

local DataStorage = require("datastorage")
local Device = require("device")
local Event = require("ui/event")
local InfoMessage = require("ui/widget/infomessage")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local IconFile = require("kindlelab_icon")
local Intake = require("kindlelab_intake")
local ReadingProfiles = require("kindlelab_profiles")
local ReadingList = require("kindlelab_readinglist")
local Types = require("kindlelab_types")

local PT = (G_reader_settings:readSetting("language") or ""):match("^pt") ~= nil
local STATE_FILE = DataStorage:getSettingsDir() .. "/kindlelab_intake.lua"
local PROFILES_FLAG = "kindlelab_profiles_v1"
local TBR_COLLECTION = "To Be Read" -- SimpleUI's list (pt_BR: "Para Ler"); the name is SimpleUI's key
local NOTES_FILE = DataStorage:getDataDir() .. "/kindlelab/estudo.lua"

local S = PT and {
    root = "KindleLab",
    icon_menu = "Ícone na tela inicial do Kindle",
    applied = "Pronto! Este é o novo ícone do KOReader.\nEle aparece na tela inicial do Kindle quando você sair do KOReader.",
    failed = "Não consegui trocar o ícone:\n%s",
    none = "Nenhum ícone encontrado em\n%s",
    help = "Toque para usar este ícone. Segure para ver em tela cheia.",
    howto_item = "Como criar um ícone novo",
    howto = "1. Peça a uma IA de imagens (ChatGPT, Gemini…) uma imagem vertical 2:3, só em preto, branco e cinza, com a palavra \"KOReader\" bem legível.\n2. Copie o arquivo PNG para a pasta koreader/kindlelab/icons do Kindle (pelo cabo USB).\n3. Volte aqui e escolha o ícone novo.\n\nO pedido completo para a IA está no GitHub do KindleLab.",
    comic_item = "Este livro é um quadrinho",
    comic_help = "Coloca a etiqueta \"Tipo: Quadrinho\": página inteira na tela e tela limpa a cada página, sem o \"fantasma\" da página anterior.",
    comic_on = "Marcado como quadrinho.\nPágina inteira e tela limpa a cada página.",
    comic_off = "Não é mais quadrinho.\nA tela volta a limpar como antes.",
    comic_failed = "Não consegui salvar a etiqueta:\n%s",
    list_root = "Lista de leitura",
    list_guide = "Como estudar",
    list_buy = "Livros para comprar",
    list_order = "Como mudar a lista",
    list_order_text = "A lista é a coleção \"Para Ler\" do SimpleUI, que também aparece na tela inicial.\n\n• Incluir: segure o dedo num livro na Biblioteca e toque em \"Adicionar à lista Quero Ler\".\n• Mudar a ordem: Biblioteca > Coleções > Para Ler > Reorganizar.\n• Livros terminados saem da lista sozinhos.",
    list_empty = "A lista \"Para Ler\" está vazia.",
    list_hold = "Toque para abrir. Segure para ver a dica de estudo.",
    list_no_note = "Sem dica para este livro.",
} or {
    root = "KindleLab",
    icon_menu = "Kindle home screen icon",
    applied = "Done! This is the new KOReader icon.\nIt shows up on the Kindle home screen once you exit KOReader.",
    failed = "Could not change the icon:\n%s",
    none = "No icons found in\n%s",
    help = "Tap to use this icon. Hold to preview it full screen.",
    howto_item = "How to make a new icon",
    howto = "1. Ask an image AI (ChatGPT, Gemini…) for a 2:3 portrait image in black, white and gray only, with the word \"KOReader\" clearly legible.\n2. Copy the PNG file to the koreader/kindlelab/icons folder of the Kindle (USB cable).\n3. Come back here and pick the new icon.\n\nThe full AI prompt is in the KindleLab GitHub repository.",
    comic_item = "This book is a comic",
    comic_help = "Adds the \"Tipo: Quadrinho\" tag: whole page on screen and a full refresh on every page, without ghosting.",
    comic_on = "Marked as a comic.\nWhole page and a clean screen on every page.",
    comic_off = "No longer a comic.\nScreen refreshes go back to normal.",
    comic_failed = "Could not save the tag:\n%s",
    list_root = "Reading list",
    list_guide = "How to study",
    list_buy = "Books to buy",
    list_order = "How to change the list",
    list_order_text = "The list is SimpleUI's \"To Be Read\" collection, also shown on the home screen.\n\n• Add: hold a book in the Library and tap \"Add to To Be Read\".\n• Reorder: Library > Collections > To Be Read > Arrange.\n• Finished books leave the list automatically.",
    list_empty = "The \"To Be Read\" list is empty.",
    list_hold = "Tap to open. Hold to see the study tip.",
    list_no_note = "No tip for this book.",
}

local NAMES = PT and {
    ["woodcut-reader"] = "Leitor sob a árvore (xilogravura)",
    ["pixel-vampire"] = "Vampirinho leitor (pixel art)",
    ["open-book-sun"] = "Livro e sol (minimalista)",
    ["pixel-cat"] = "Gato no livro (pixel art)",
    ["owl"] = "Coruja de óculos (minimalista)",
    ["capybara"] = "Capivara na rede (xilogravura)",
    ["art-deco-shelf"] = "Estante e lua (art déco)",
} or {
    ["woodcut-reader"] = "Reader under a tree (woodcut)",
    ["pixel-vampire"] = "Little reading vampire (pixel art)",
    ["open-book-sun"] = "Open book and sun (minimal)",
    ["pixel-cat"] = "Cat on a book (pixel art)",
    ["owl"] = "Owl with glasses (minimal)",
    ["capybara"] = "Capybara in a hammock (woodcut)",
    ["art-deco-shelf"] = "Bookshelf and moon (art deco)",
}

local function label(stem)
    return NAMES[stem] or (stem:gsub("[_%-]+", " "):gsub("^%l", string.upper))
end

local function readerIsOpen()
    local ReaderUI = package.loaded["apps/reader/readerui"]
    return ReaderUI ~= nil and ReaderUI.instance ~= nil
end

local function matchesAny(name, patterns)
    for _, p in ipairs(patterns or {}) do
        if name:match(p) then return true end
    end
    return false
end

-- Book candidates under the home folder, skipping what the library hides (dictionaries, scripts...),
-- sidecar folders and the news download folder.
local function listBooks()
    local FileChooser = require("ui/widget/filechooser")
    local home = G_reader_settings:readSetting("home_dir") or "/mnt/us/documents"
    local news_dir
    pcall(function()
        news_dir = LuaSettings:open(DataStorage:getSettingsDir() .. "/news_settings.lua"):readSetting("custom_dl_dir")
    end)
    news_dir = news_dir and news_dir:gsub("/+$", "")
    local books = {}
    local function walk(dir, depth)
        local ok, iter, dir_obj = pcall(lfs.dir, dir)
        if not ok then return end
        for name in iter, dir_obj do
            if name:sub(1, 1) ~= "." then
                local path = dir .. "/" .. name
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    if depth < 3 and not name:match("%.sdr$") and path ~= news_dir
                            and not matchesAny(name, FileChooser.exclude_dirs) then
                        walk(path, depth + 1)
                    end
                elseif mode == "file" and not matchesAny(name, FileChooser.exclude_files) then
                    books[#books + 1] = path
                end
            end
        end
    end
    walk(home, 0)
    return books
end

local intake_running = false
local library_opened_before = false

local KindleLab = WidgetContainer:extend{
    name = "kindlelab",
    is_doc_only = false,
}

function KindleLab:init()
    self.ui.menu:registerToMainMenu(self)
    if self.ui.document then return end -- reader: see onReaderReady / onCloseDocument
    UIManager:nextTick(function() self:ensureProfiles() end)
    -- First library of the session: give the library patch time to index new books (it starts at 20 s).
    UIManager:scheduleIn(library_opened_before and 5 or 45, function() KindleLab.runIntake() end)
    library_opened_before = true
end

-- Adds the KindleLab reading profiles once; afterwards they belong to the reader (edit/delete freely).
function KindleLab:ensureProfiles()
    if G_reader_settings:isTrue(PROFILES_FLAG) then return end
    local profiles = self.ui and self.ui.profiles
    if not profiles or not profiles.data then return end
    local autoexec = G_reader_settings:readSetting("profiles_autoexec", {})
    local ok, changed = pcall(ReadingProfiles.ensure, profiles.data, autoexec)
    if not ok then
        logger.warn("kindlelab: reading profiles not added:", changed)
        return
    end
    if changed then
        profiles.autoexec = autoexec
        profiles.updated = true
        profiles:onFlushSettings()
    end
    G_reader_settings:saveSetting("profiles_autoexec", autoexec)
    G_reader_settings:makeTrue(PROFILES_FLAG)
    G_reader_settings:flush()
    logger.info("kindlelab: reading profiles ready")
end

-- Tags the books not seen before, one at a time so the screen stays responsive.
function KindleLab.runIntake(attempt)
    attempt = attempt or 1
    if intake_running or readerIsOpen() then return end
    local state_file = LuaSettings:open(STATE_FILE)
    local state = { seen = state_file:readSetting("seen", {}) }
    local queue = {}
    for _, path in ipairs(listBooks()) do
        if not state.seen[path] then queue[#queue + 1] = path end
    end
    if #queue == 0 then return end
    intake_running = true
    local deps = Intake.koreaderAdapters()
    local i, tagged, pending = 0, 0, 0
    local finish
    local function step()
        if readerIsOpen() then return finish() end
        i = i + 1
        local path = queue[i]
        if not path then return finish() end
        local ok, result, detail = pcall(Intake.processBook, path, deps, state)
        if not ok then
            logger.warn("kindlelab-intake:", path, result)
        elseif result == "tagged" then
            tagged = tagged + 1
            logger.info("kindlelab-intake: tagged", path, table.concat(detail, ", "))
        elseif result == "pending" then
            pending = pending + 1
        elseif result == "error" then
            logger.warn("kindlelab-intake: could not tag", path, detail)
        end
        UIManager:scheduleIn(0.1, step)
    end
    finish = function()
        intake_running = false
        state_file:saveSetting("seen", state.seen)
        state_file:flush()
        if tagged > 0 then UIManager:broadcastEvent(Event:new("BookMetadataChanged")) end
        logger.info("kindlelab-intake:", tagged, "tagged,", pending, "waiting for the library index")
        if pending > 0 and attempt < 4 and not readerIsOpen() then
            UIManager:scheduleIn(30, function() KindleLab.runIntake(attempt + 1) end)
        end
    end
    step()
end

-- Comics: full e-ink refresh on every page turn while the book is open (in memory only, never saved).
function KindleLab:isComic()
    return Types.hasTag(self.ui.doc_props and self.ui.doc_props.keywords, Types.TAGS.comic)
end

function KindleLab:startComicRefresh()
    if self.saved_refresh_count == nil then
        self.saved_refresh_count = UIManager.FULL_REFRESH_COUNT
        UIManager.FULL_REFRESH_COUNT = 1
    end
end

function KindleLab:stopComicRefresh()
    if self.saved_refresh_count ~= nil then
        UIManager.FULL_REFRESH_COUNT = self.saved_refresh_count
        self.saved_refresh_count = nil
    end
end

function KindleLab:onReaderReady()
    if self:isComic() then self:startComicRefresh() end
end

function KindleLab:onCloseDocument()
    self:stopComicRefresh()
end

function KindleLab:setComic(on)
    local file = self.ui.document.file
    local keywords = self.ui.doc_props.keywords
    local new_keywords = on and Types.withTags(keywords, { Types.TAGS.comic }, { Types.TAGS.scanned })
        or Types.withTags(keywords, nil, { Types.TAGS.comic })
    local original = {}
    pcall(function() original = self.ui.document:getProps() or {} end)
    local ok, err = Intake.koreaderAdapters().save(file, new_keywords, original)
    if not ok then
        UIManager:show(InfoMessage:new{ text = string.format(S.comic_failed, tostring(err)) })
        return
    end
    self.ui.doc_props.keywords = new_keywords
    if self.ui.doc_settings and self.ui.doc_settings.getCustomMetadataFile then
        pcall(self.ui.doc_settings.getCustomMetadataFile, self.ui.doc_settings, true)
    end
    if on then
        self:startComicRefresh()
        local profiles = self.ui.profiles
        if profiles and profiles.data and profiles.data[ReadingProfiles.COMIC] then
            profiles:onProfileExecute(ReadingProfiles.COMIC)
        end
    else
        self:stopComicRefresh()
    end
    UIManager:broadcastEvent(Event:new("BookMetadataChanged"))
    UIManager:show(InfoMessage:new{ text = on and S.comic_on or S.comic_off, timeout = 4 })
end

local function preview(path)
    local ok, bb = pcall(function()
        local w = math.floor(Device.screen:getWidth() * 0.4)
        return require("ui/renderimage"):renderImageFile(path, false, w, math.floor(w * 1.5))
    end)
    return ok and bb or nil
end

function KindleLab:iconItems()
    local items = {}
    for _, icon in ipairs(IconFile.list(IconFile.ICON_DIR, lfs)) do
        items[#items + 1] = {
            text = label(icon.stem),
            help_text = S.help,
            keep_menu_open = true,
            checked_func = function() return IconFile.current() == icon.path end,
            callback = function(touchmenu_instance)
                local ok, err = IconFile.set(icon.path)
                if ok then
                    logger.info("kindlelab: tile icon set to", icon.path)
                    UIManager:show(InfoMessage:new{ text = S.applied, image = preview(icon.path), show_icon = false })
                else
                    UIManager:show(InfoMessage:new{ text = string.format(S.failed, tostring(err)) })
                end
                if touchmenu_instance then touchmenu_instance:updateItems() end
            end,
            hold_callback = function()
                UIManager:show(require("ui/widget/imageviewer"):new{
                    file = icon.path,
                    fullscreen = true,
                    with_title_bar = true,
                    title_text = label(icon.stem),
                })
            end,
        }
    end
    if #items == 0 then
        items[1] = { text = string.format(S.none, IconFile.ICON_DIR), enabled = false }
    end
    items[#items].separator = true
    items[#items + 1] = {
        text = S.howto_item,
        keep_menu_open = true,
        callback = function() UIManager:show(InfoMessage:new{ text = S.howto }) end,
    }
    return items
end

-- Reading list: SimpleUI's "To Be Read" collection in its manual order, plus optional study notes.
function KindleLab:openBook(file)
    if self.ui.document and self.ui.switchDocument then
        self.ui:switchDocument(file)
    else
        require("apps/reader/readerui"):showReader(file)
    end
end

local function showText(text)
    UIManager:show(InfoMessage:new{ text = text, show_icon = false })
end

function KindleLab:readingListItems()
    local notes = ReadingList.loadNotes(NOTES_FILE)
    local coll
    pcall(function()
        local RC = require("readcollection")
        RC:_read()
        coll = RC.coll and RC.coll[TBR_COLLECTION]
    end)
    local items = {}
    if notes.guide then
        items[#items + 1] = { text = S.list_guide, keep_menu_open = true, callback = function() showText(notes.guide) end }
    end
    local list = ReadingList.entries(coll, notes)
    if #list == 0 then
        items[#items + 1] = { text = S.list_empty, enabled = false }
    end
    if #items > 0 then items[#items].separator = true end
    for _, e in ipairs(list) do
        items[#items + 1] = {
            text = ReadingList.label(e),
            help_text = S.list_hold,
            callback = function() self:openBook(e.file) end,
            hold_callback = function()
                showText(e.title .. (e.stage and ("\n" .. e.stage) or "") .. "\n\n" .. (e.note or S.list_no_note))
            end,
        }
    end
    if #items > 0 then items[#items].separator = true end
    local buy = ReadingList.buyText(notes)
    if buy then
        items[#items + 1] = { text = S.list_buy, keep_menu_open = true, callback = function() showText(buy) end }
    end
    items[#items + 1] = { text = S.list_order, keep_menu_open = true, callback = function() showText(S.list_order_text) end }
    return items
end

function KindleLab:addToMainMenu(menu_items)
    menu_items.kindlelab_reading_list = {
        text = S.list_root,
        sorting_hint = "tools",
        sub_item_table_func = function() return self:readingListItems() end,
    }
    local items = {}
    if self.ui.document then
        items[#items + 1] = {
            text = S.comic_item,
            help_text = S.comic_help,
            checked_func = function() return self:isComic() end,
            callback = function() self:setComic(not self:isComic()) end,
            separator = true,
        }
    end
    if Device:isKindle() then
        items[#items + 1] = {
            text = S.icon_menu,
            sub_item_table_func = function() return self:iconItems() end,
        }
    end
    if #items == 0 then return end
    menu_items.kindlelab = {
        text = S.root,
        sorting_hint = "tools",
        sub_item_table = items,
    }
end

return KindleLab
