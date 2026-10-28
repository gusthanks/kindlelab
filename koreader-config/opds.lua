-- KOReader OPDS catalog list -> /mnt/us/koreader/settings/opds.lua
-- Free, public-domain books from Project Gutenberg. Change "l.pt" to your language code
-- (l.en, l.es, l.fr, l.de, ...) to filter by language.
-- Checked 2026-10 from a PW3: these work. Removed KOReader defaults that did not:
-- Standard Ebooks (HTTP 401, patrons only), ManyBooks and Feedbooks (Cloudflare 403),
-- Internet Archive bookserver (timeout).
return {
    ["servers"] = {
        [1] = {
            ["title"] = "Project Gutenberg — livros em português",
            ["url"] = "https://www.gutenberg.org/ebooks/search.opds/?query=l.pt",
        },
        [2] = {
            ["title"] = "Project Gutenberg — todos os idiomas",
            ["url"] = "https://www.gutenberg.org/ebooks.opds/?format=opds",
        },
    },
}
