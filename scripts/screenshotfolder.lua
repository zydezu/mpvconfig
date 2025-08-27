--[[
    screenshotfolder.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua)

    Place screenshots into folders for each video, along with timestamping them
--]]

local options = {
    screenshot_key = 's',
    file_ext = "png",
    save_location = "~~desktop/mpv/screenshots/",
    time_stamp_format = "%tY-%tm-%td_%tH-%tM-%tS",
    save_as_time_stamp = true,
    save_based_on_chapter_name = false,
    short_saved_message = true,
    include_YouTube_ID = true
}
(require "mp.options").read_options(options)

local title = "default"
local chaptername = ""
local last_timestamp = ""
local count = 0
local current_format = options.file_ext

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
    mp.command("screenshot")
    mp.set_property("sub-pos", sub_pos)

    local msg = options.short_saved_message
        and "Screenshot saved"
        or "Screenshot saved to: " .. mp.command_native({"expand-path", mp.get_property("screenshot-directory")}):gsub("\\", "/")

    mp.osd_message(msg)

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