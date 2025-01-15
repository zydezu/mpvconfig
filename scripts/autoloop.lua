--[[
    autoloop.lua by zydezu
    (https://github.com/zydezu/mpvconfig/blob/main/scripts/autoloop.lua)

    * Based on https://github.com/zc62/mpv-scripts/blob/master/autoloop.lua

    Automatically loop files below a certain length
--]]

local options = {
    autoloop_threshold = 10,    -- automatically set the loop files below this length
    savepos_threshold = 60,     -- save the position on videos above this length 
    play_from_start = true,     -- play autlooping videos from the start
}
require("mp.options").read_options(options)

local loop_overridden = false

local function set_loop()
    if not loop_overridden then
        mp.osd_message("")
        local duration = mp.get_property_native("duration")

        -- Checks whether the loop status was changed for the last file
        local was_loop = mp.get_property_native("loop-file")

        -- Cancel operation if there is no file duration
        if not duration then
            return
        end

        -- Loops file if was_loop is false, and file meets requirements
        if not was_loop then
            if duration <= options.autoloop_threshold then
                print("Autolooped file")
                mp.set_property_native("loop-file", true)
            end
            if duration <= options.autoloop_threshold or duration <= options.savepos_threshold or 
            (mp.get_property_native("current-tracks/video") == nil) or (mp.get_property_native("current-tracks/video")["albumart"] == true) then
                print("Not saving video position")
                mp.set_property_bool("file-local-options/save-position-on-quit", false)
                mp.set_property("file-local-options/watch-later-options", "start") -- so videos don't load paused
                if options.play_from_start and mp.get_property_number("playback-time") > 0 then -- always play video from the start
                    mp.commandv("seek", 0, "absolute-percent", "exact")
                end
            end
        -- Unloops file if was_loop is true, and file does not meet requirements
        elseif was_loop and duration > options.autoloop_threshold then
            mp.set_property_native("loop-file", false)
        end
    end
    mp.observe_property("loop-file", "bool",
        function() loop_overridden = true end
    )
end

mp.register_event("file-loaded", set_loop)