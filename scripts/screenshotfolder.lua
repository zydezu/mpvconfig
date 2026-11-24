--[[
    screenshotfolder.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua)

    * Copying to clipboard code adapted from https://github.com/ObserverOfTime/mpv-scripts/blob/master/clipshot.lua

    Place screenshots into folders for each video, along with timestamping them
--]]

local options = {
    -- General
    screenshot_key = 's',

    -- Screenshot settings
    file_ext = "png",
    image_quality = 80,  -- 0-100, quality for lossy formats (jpg, webp, jxl, avif)
    png_compression = 7, -- 0-9, png only: lower is faster/bigger, higher is slower/smaller
    save_location = "~/Pictures/mpv/screenshots/",
    time_stamp_format = "%tY-%tm-%td_%tH-%tM-%tS",

    -- OSD message settings
    show_message = false,
    short_saved_message = true,

    -- Screenshot folder settings
    save_as_time_stamp = true,
    save_based_on_chapter_name = false,
    include_YouTube_ID = true,

    -- Clipboard settings
    copy_to_clipboard = true,
}
(require "mp.options").read_options(options)

local title = "default"
local chaptername = ""
local last_timestamp = ""
local count = 0
local current_format = options.file_ext

---@diagnostic disable-next-line: deprecated
local unpack = table.unpack or unpack

local platform = mp.get_property_native('platform')

-- Build the command that puts the image file in the clipboard
local function clipboard_command(path)
    if platform == 'windows' then
        return {
            'powershell', '-NoProfile', '-Command',
            'Add-Type -Assembly System.Windows.Forms, System.Drawing;',
            string.format(
                "[Windows.Forms.Clipboard]::SetImage([Drawing.Image]::FromFile('%s'))",
                path:gsub("'", "''")
            )
        }
    elseif platform == 'darwin' then
        -- png: «class PNGf»
        local type = options.file_ext ~= '' and options.file_ext or 'PNG picture'
        return {
            'osascript', '-e', string.format(
            'set the clipboard to (read (POSIX file %q) as %s)',
            path, type
        )
        }
    elseif os.getenv('XDG_SESSION_TYPE') == 'wayland' then
        return { 'sh', '-c', ('wl-copy < %q'):format(path) }
    else
        local type = options.file_ext ~= '' and options.file_ext or 'image/png'
        return { 'xclip', '-sel', 'c', '-t', type, '-i', path }
    end
end

-- Copy an already saved screenshot to the clipboard
local function clipshot(path)
    mp.command_native_async({ 'run', unpack(clipboard_command(path)) }, function(suc, _, err)
        print(suc and 'Copied screenshot to clipboard' or err)
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

-- Apply the image quality for the currently selected screenshot format
local function set_image_quality()
    local quality = math.max(0, math.min(100, options.image_quality))

    if current_format == "jpg" or current_format == "jpeg" then
        mp.set_property_number("screenshot-jpeg-quality", quality)
    elseif current_format == "webp" then
        mp.set_property_number("screenshot-webp-quality", quality)
    elseif current_format == "png" then
        mp.set_property_number("screenshot-png-compression",
            math.max(0, math.min(9, options.png_compression)))
    elseif current_format == "jxl" then
        -- jxl uses a "distance" instead of a quality: 0 is lossless, 15 is worst
        mp.set_property_number("screenshot-jxl-distance", (100 - quality) / 100 * 15)
    elseif current_format == "avif" then
        -- avif uses CRF instead of a quality: 0 is best, 63 is worst
        local crf = math.floor((100 - quality) * 63 / 100 + 0.5)
        local opts = mp.get_property("screenshot-avif-opts") or ""
        opts = opts:gsub("%s*crf=[^,]*", ""):gsub(",,+", ","):gsub("^,", ""):gsub(",$", "")
        mp.set_property("screenshot-avif-opts",
            (opts ~= "" and opts .. "," or "") .. "crf=" .. crf)
    end
end

local function set_screenshot_template()
    mp.set_property("screenshot-format", current_format)
    set_image_quality()
    mp.set_property("screenshot-directory", options.save_location .. title .. "/")

    local timestamp = mp.command_native({ "expand-text", options.time_stamp_format })

    if timestamp ~= last_timestamp then
        count = 0
        last_timestamp = timestamp
    end

    local suffix = (count > 0) and ("(" .. (count + 1) .. ")") or ""

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
        filename = media:sub(1, 100):gsub("^%s*(.-)%s*$", "%1") ..
            (youtube_id ~= "" and (" [" .. youtube_id .. "]") or "")
    end

    title = sanitize_filename(filename)
    count = 0
    set_screenshot_template()
end

local function screenshot_done()
    local sub_pos = mp.get_property("sub-pos")
    mp.set_property("sub-pos", 100)
    local res = mp.command_native({ "screenshot" })
    mp.set_property("sub-pos", sub_pos)

    -- Reuse the file that was just written instead of taking a second
    -- screenshot for the clipboard, so both get the same frame.
    if options.copy_to_clipboard and res and res.filename then
        clipshot(res.filename)
    end

    local msg = options.short_saved_message
        and "Screenshot saved"
        or "Screenshot saved to: " ..
        mp.command_native({ "expand-path", mp.get_property("screenshot-directory") }):gsub("\\", "/")

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
