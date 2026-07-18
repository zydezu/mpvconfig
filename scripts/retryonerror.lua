--[[
    retryonerror.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/retryonerror.lua)

    Automatically retry loading a URL when mpv fails with an error (403 for example)
--]]

local options = {
    max_retries = 3,
}

(require "mp.options").read_options(options)

local retry_count = 0
local saved_path = nil
local saved_pos = nil

local function is_url(s)
    return s and string.match(s, "^[%w]+://") ~= nil
end

-- ensures mpv enters idle mode instead of quitting so our retry can run
mp.set_property("idle", "yes")

mp.register_event("start-file", function()
    local path = mp.get_property("path")
    if path ~= saved_path then
        saved_path = path
        retry_count = 0
    end

    saved_pos = mp.get_property_number("playlist-pos")
end)

mp.register_event("end-file", function(event)
    if event.reason ~= "error" then
        return
    end
    if not is_url(saved_path) then
        return
    end
    if retry_count >= options.max_retries then
        mp.osd_message("Failed to load after " .. options.max_retries .. " retries", 5)
        retry_count = 0
        saved_path = nil
        return
    end
    retry_count = retry_count + 1
    mp.osd_message(string.format("Load error — retrying (%d/%d)...", retry_count, options.max_retries), 5)

    -- put a fresh copy where the failed entry was, play it, then drop the old one
    mp.commandv("loadfile", saved_path, "insert-at", saved_pos)
    mp.commandv("playlist-play-index", saved_pos)
    mp.commandv("playlist-remove", saved_pos + 1)
end)
