return {--do NOT change this line
 -- KOReader news downloader feed list (Brazilian Portuguese example).
 -- Each line = one site; limit = how many articles to fetch.
 -- download_full_article=true fetches each page and keeps the element in filter_element.
 -- KOReader's HTML parser stops at 5000 nodes, so very heavy pages (e.g. some big news
 -- portals) may come out empty; prefer feeds that already carry the full text.
 { "https://feeds.bbci.co.uk/portuguese/rss.xml", limit = 8, download_full_article=true, include_images=false, enable_filter=true, filter_element = "main", block_element = ""},
 { "https://agenciabrasil.ebc.com.br/rss/ultimasnoticias/feed.xml", limit = 8, download_full_article=true, include_images=false, enable_filter=true, filter_element = "main", block_element = ""},
 { "https://tecnoblog.net/feed/", limit = 8, download_full_article=false, include_images=false, enable_filter=false, filter_element = "", block_element = ""},
}--do NOT change this line
