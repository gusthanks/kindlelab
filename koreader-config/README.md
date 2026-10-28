# KOReader config templates

Used by [`scripts/build-koreader-config.py`](../scripts/build-koreader-config.py), see
[docs/04](../docs/04-koreader.md).

| File | Ends up at | What |
|---|---|---|
| `opds.lua` | `/mnt/us/koreader/settings/opds.lua` | Free-book catalogs (Project Gutenberg, filtered by language) |
| `feeds-pt-BR.lua` | `<news dir>/feed_config.lua` | News feeds (Brazilian Portuguese example) |

Both are plain Lua tables. The build script checks them with `luajit` before writing anything.
Adding a feed for your language? Copy `feeds-pt-BR.lua` to `feeds-<lang>.lua` and open a pull
request. Prefer feeds that already carry the full article text.
