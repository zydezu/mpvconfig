--[[
    screenshotfolder.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua)

    * Copying to clipboard code adapted from https://github.com/ObserverOfTime/mpv-scripts/blob/master/clipshot.lua

    Place screenshots into folders for each video, along with timestamping them
--]]

local options = {
    screenshot_key = 's',
    file_ext = "png",
    save_location = "~/Pictures/mpv/screenshots/",
    time_stamp_format = "%tY-%tm-%td_%tH-%tM-%tS",
    show_message = false,
    short_saved_message = true,
    save_as_time_stamp = true,
    save_based_on_chapter_name = false,
    include_YouTube_ID = true,
    copy_to_clipboard = true,
    clipboard_filename = "mpvscreenshot.png",
}
(require "mp.options").read_options(options)

local title = "default"
local chaptername = ""
local last_timestamp = ""
local count = 0
local current_format = options.file_ext
local file, cmd

local platform = mp.get_property_native('platform')
if platform == 'windows' then
    file = os.getenv('TEMP')..'\\'..options.clipboard_filename
    cmd = {
        'powershell', '-NoProfile', '-Command',
        'Add-Type -Assembly System.Windows.Forms, System.Drawing;',
        string.format(
            "[Windows.Forms.Clipboard]::SetImage([Drawing.Image]::FromFile('%s'))",
            file:gsub("'", "''")
        )
    }
elseif platform == 'darwin' then
    file = os.getenv('TMPDIR')..'/'..options.clipboard_filename
    -- png: «class PNGf»
    local type = options.file_ext ~= '' and options.file_ext or 'PNG picture'
    cmd = {
        'osascript', '-e', string.format(
            'set the clipboard to (read (POSIX file %q) as %s)',
            file, type
        )
    }
else
    file = '/tmp/'..options.clipboard_filename
    if os.getenv('XDG_SESSION_TYPE') == 'wayland' then
        cmd = {'sh', '-c', ('wl-copy < %q'):format(file)}
    else
        local type = options.file_ext ~= '' and options.file_ext or 'image/png'
        cmd = {'xclip', '-sel', 'c', '-t', type, '-i', file}
    end
end

local function clipshot(arg)
    mp.commandv('screenshot-to-file', file, arg)
    mp.command_native_async({'run', unpack(cmd)}, function(suc, _, err)
        print(suc and 'Copied screenshot to clipboard' or err, 1)
    end)
end

local function sanitize_filename(name)
    return name and name:gsub('[\\/:*?"<>|]', '') or ""
end

local function extract_youtube_id(filename)
    if not options.include_YouTube_ID then return "" end
    return filename:match("[?&]v=([^&]+)") 
        or filename:match("([%w_-]+)%?si=") 
        or ""
end

local function set_screenshot_template()
    mp.set_property("screenshot-format", current_format)
    mp.set_property("screenshot-directory", options.save_location .. title .. "/")

    local timestamp = mp.command_native({"expand-text", options.time_stamp_format})

    if timestamp ~= last_timestamp then
        count = 0
        last_timestamp = timestamp
    end

    local suffix = (count > 0) and ("(" .. (count+1) .. ")") or ""

    local template
    if options.save_based_on_chapter_name and chaptername ~= "" then
        template = sanitize_filename(chaptername) .. " (" .. timestamp .. ")" .. suffix
    else
        template = timestamp .. suffix
    end

    mp.set_property("screenshot-template", template)
end

local function init()
    local media = mp.get_property("media-title")
    local filename = mp.get_property("filename/no-ext")
    local path = mp.get_property("path")

    if path:match("^[%w]+://") then
        local youtube_id = extract_youtube_id(mp.get_property("filename"))
        filename = media:sub(1, 100):gsub("^%s*(.-)%s*$", "%1") .. (youtube_id ~= "" and (" [" .. youtube_id .. "]") or "")
    end

    title = sanitize_filename(filename)
    count = 0
    set_screenshot_template()
end

local function screenshot_done()
    local sub_pos = mp.get_property("sub-pos")
    mp.set_property("sub-pos", 100)
    mp.commandv("screenshot")
    if options.copy_to_clipboard then clipshot("subtitles") end
    mp.set_property("sub-pos", sub_pos)

    local msg = options.short_saved_message
        and "Screenshot saved"
        or "Screenshot saved to: " .. mp.command_native({"expand-path", mp.get_property("screenshot-directory")}):gsub("\\", "/")

    if options.show_message then mp.osd_message(msg) end

    count = count + 1
    set_screenshot_template()
end

mp.observe_property("chapter-metadata/title", "string", function(_, value)
    chaptername = value or ""
    set_screenshot_template()
end)
mp.observe_property("screenshot-format", "string", function(_, value)
    if value then current_format = value end
end)
mp.register_event("file-loaded", init)
mp.add_key_binding(options.screenshot_key, "screenshot_done", screenshot_done)