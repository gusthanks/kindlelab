--[[
KindleLab plugin: Tools > KindleLab > "Kindle home screen icon".

Lists the images in koreader/kindlelab/icons/ and points the KOReader tile of the stock Kindle home screen
at the one you pick (tap = use it, hold = full-screen preview). The stock home shows the new icon once
KOReader is closed, because the Kindle's scanner is paused while KOReader runs.

Tested on: Kindle Paperwhite 3 (FW 5.16.2.1.1), KOReader v2026.07.1, SimpleUI 3.0.1.
License: MIT (KindleLab).
]]

local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local IconFile = require("kindlelab_icon")

local PT = (G_reader_settings:readSetting("language") or ""):match("^pt") ~= nil

local S = PT and {
    root = "KindleLab",
    icon_menu = "Ícone na tela inicial do Kindle",
    applied = "Pronto! Este é o novo ícone do KOReader.\nEle aparece na tela inicial do Kindle quando você sair do KOReader.",
    failed = "Não consegui trocar o ícone:\n%s",
    none = "Nenhum ícone encontrado em\n%s",
    help = "Toque para usar este ícone. Segure para ver em tela cheia.",
    howto_item = "Como criar um ícone novo",
    howto = "1. Peça a uma IA de imagens (ChatGPT, Gemini…) uma imagem vertical 2:3, só em preto, branco e cinza, com a palavra \"KOReader\" bem legível.\n2. Copie o arquivo PNG para a pasta koreader/kindlelab/icons do Kindle (pelo cabo USB).\n3. Volte aqui e escolha o ícone novo.\n\nO pedido completo para a IA está no GitHub do KindleLab.",
} or {
    root = "KindleLab",
    icon_menu = "Kindle home screen icon",
    applied = "Done! This is the new KOReader icon.\nIt shows up on the Kindle home screen once you exit KOReader.",
    failed = "Could not change the icon:\n%s",
    none = "No icons found in\n%s",
    help = "Tap to use this icon. Hold to preview it full screen.",
    howto_item = "How to make a new icon",
    howto = "1. Ask an image AI (ChatGPT, Gemini…) for a 2:3 portrait image in black, white and gray only, with the word \"KOReader\" clearly legible.\n2. Copy the PNG file to the koreader/kindlelab/icons folder of the Kindle (USB cable).\n3. Come back here and pick the new icon.\n\nThe full AI prompt is in the KindleLab GitHub repository.",
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

local KindleLab = WidgetContainer:extend{
    name = "kindlelab",
    is_doc_only = false,
}

function KindleLab:init()
    if not Device:isKindle() then return end
    self.ui.menu:registerToMainMenu(self)
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

function KindleLab:addToMainMenu(menu_items)
    menu_items.kindlelab = {
        text = S.root,
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = S.icon_menu,
                sub_item_table_func = function() return self:iconItems() end,
            },
        },
    }
end

return KindleLab
