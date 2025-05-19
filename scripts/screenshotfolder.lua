--[[
    screenshotfolder.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua)

    Place screenshots into folders for each video, along with timestamping them
--]]

local options = {
    screenshot_key = 's',
    file_ext = "jpg",
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
local count = 0

local function set_screenshot_template()
    local function safe_chaptername(name)
        return name:gsub('[\\/:*?"<>|]', '')
    end

    local function set_screenshot_template_no_chapter()
        mp.set_property("screenshot-directory", options.save_location .. title .. "/")
        if options.save_as_time_stamp then
            mp.set_property("screenshot-template", options.time_stamp_format .. ((count > 0) and ("(" .. count .. ")") or ""))
        end
    end

    local function set_screenshot_template_with_chapter()
        local safe_chapter = safe_chaptername(chaptername)
        if safe_chapter ~= "" then
            mp.set_property("screenshot-template", safe_chapter .. " (" .. options.time_stamp_format .. ")" .. ((count > 0) and ("(" .. count .. ")") or ""))
        else
            set_screenshot_template_no_chapter()
        end
    end

    mp.set_property("screenshot-format", options.file_ext)
    if options.save_based_on_chapter_name then
        set_screenshot_template_with_chapter()
    else
        set_screenshot_template_no_chapter()
    end
end

local function reset_count()
    count = 0
    set_screenshot_template()
end

local function init()
    local function is_url(s)
        local url_pattern = "^[%w]+://[%w%.%-_]+%.[%a]+[-%w%.%-%_/?&=]*"
        return string.match(s, url_pattern) ~= nil
    end

    local filename = mp.get_property("filename/no-ext")
    local media = mp.get_property("media-title")
    local path = mp.get_property("path")

    if is_url(path) and path or nil then
        local youtube_ID = ""
        local _, _, videoID = string.find(mp.get_property("filename"), "([%w_-]+)%?si=")
        local videoIDMatch = mp.get_property("filename"):match("[?&]v=([^&]+)")
        if options.include_YouTube_ID then
            if (videoIDMatch) then
                youtube_ID = " [" .. videoIDMatch .. "]"
            elseif (videoID) then
                youtube_ID = " [" .. videoID .. "]"
            end
        end
        filename = string.gsub(media:sub(1, 100), "^%s*(.-)%s*$", "%1") .. youtube_ID
    end
    title = filename:gsub('[\\/:*?"<>|]', "")

    set_screenshot_template()
end

local function screenshot_done()
    local temp_sub_pos = mp.get_property("sub-pos")
    mp.commandv("set", "sub-pos", 100)
    mp.commandv("screenshot");
    mp.commandv("set", "sub-pos", temp_sub_pos)
    if options.short_saved_message then
        mp.osd_message("Screenshot saved")
    else
        mp.osd_message("Screenshot saved to: " ..
            mp.command_native({"expand-path", mp.get_property("screenshot-directory")}):gsub("\\", "/"))
    end
    count = count + 1
    set_screenshot_template()
end

mp.observe_property("chapter-metadata/title", "string", function(_, value)
    chaptername = value or ""
    set_screenshot_template()
end)

mp.register_event("start-file", init)
mp.register_event("file-loaded", init)
mp.add_periodic_timer(1, reset_count)
mp.add_key_binding(options.screenshot_key, "screenshot_done", screenshot_done);