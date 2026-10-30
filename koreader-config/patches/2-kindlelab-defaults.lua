-- KindleLab: gentle first-run defaults. Never force a language, font, mascot or existing choice.
-- Loaded at priority 2, after G_reader_settings exists, before plugins start.
local FLAG = 'kindlelab_defaults_v1'
if G_reader_settings:isTrue(FLAG) then return end
for key, value in pairs({
    home_dir = '/mnt/us/documents',
    download_dir = '/mnt/us/documents',
    lock_home_folder = true,
    collate = 'title',
}) do
    if G_reader_settings:readSetting(key) == nil then
        G_reader_settings:saveSetting(key, value)
    end
end
G_reader_settings:makeTrue(FLAG)
G_reader_settings:flush()
