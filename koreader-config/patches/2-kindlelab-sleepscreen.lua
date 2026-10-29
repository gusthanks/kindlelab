--[[ KindleLab: sleep screen = cover of the book that is open; in the file browser (no book open),
a random image from the Kindle's own screensaver set, copied to koreader/screensavers.
No "Sleeping" message box.

Applied once (flag kindlelab_sleepscreen_v1): later changes made in the KOReader menu are kept.
Priority 2 (late): G_reader_settings does not exist yet when priority 0/1 patches run.
Install the images first, on the Kindle:
  mkdir -p /mnt/us/koreader/screensavers && cp /usr/share/blanket/screensaver/bg_ss*.png /mnt/us/koreader/screensavers/
]]
local FLAG = "kindlelab_sleepscreen_v1"
if G_reader_settings:isTrue(FLAG) then return end

local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local dir = "/mnt/us/koreader/screensavers"
if lfs.attributes(dir, "mode") ~= "directory" then
    logger.warn("kindlelab-sleepscreen:", dir, "missing, nothing changed")
    return
end

G_reader_settings:saveSetting("screensaver_type", "cover")
G_reader_settings:makeTrue("screensaver_hide_cover_in_filemanager") -- no book open -> random image
G_reader_settings:saveSetting("screensaver_dir", dir)
G_reader_settings:makeFalse("screensaver_show_message")
G_reader_settings:makeTrue("screensaver_hide_fallback_msg")
G_reader_settings:makeTrue(FLAG)
G_reader_settings:flush()
logger.info("kindlelab-sleepscreen: applied")
