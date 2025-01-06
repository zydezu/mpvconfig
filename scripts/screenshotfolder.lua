--[[
    screenshotfolder.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/screenshotfolder.lua)

    Place screenshots into folders for each video, along with timestamping them
--]]

local options = {
    save_as_time_stamp = true,
    file_ext = "jpg",
    include_YouTube_ID = true
}
(require "mp.options").read_options(options)

local currentTime = "0000"
local filename = "default"
local title = "default"
local count = 0

local function update_time()
    currentTime = os.date("%Y-%m-%d_%H-%M-%S")
end

local function set_file_dir()
    update_time()

    count = 0
    mp.set_property("screenshot-directory", "~~desktop/mpv/screenshots/" .. title .. "/")
    if options.save_as_time_stamp then
        mp.set_property("screenshot-template", "%tX")
    end
    mp.set_property("screenshot-format", options.file_ext)
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

    set_file_dir()
end

local function screenshot_done()
    local temp_sub_pos = mp.get_property("sub-pos")
    mp.commandv("set", "sub-pos", 100)
    mp.commandv("screenshot");
    mp.commandv("set", "sub-pos", temp_sub_pos)
    mp.osd_message("Screenshot taken: " .. mp.command_native({"expand-path", 
                    mp.get_property("screenshot-directory")}) .. mp.get_property("screenshot-template"))
    count = count + 1
    if options.save_as_time_stamp then
        mp.set_property("screenshot-template", "%tY-%tm-%td_%tH-%tM-%tS" .. "(" .. count .. ")")
    end
end

mp.register_event("start-file", init)
mp.register_event("file-loaded", init)
mp.add_periodic_timer(1, set_file_dir)
mp.add_key_binding("s", "screenshot_done", screenshot_done);