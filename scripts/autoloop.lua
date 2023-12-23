-- Automatically set loop-file=inf for duration <= given length. Default is 5s
-- Use autoloop_duration=n in script-opts/autoloop.conf to set your preferred length
-- Alternatively use script-opts=autoloop-autoloop_duration=n in mpv.conf (takes priority)
-- Also disables the save-position-on-quit for this file, if it qualifies for looping.

local o = {
    autoloop_duration = 10,
    dontsaveduration = 60, -- don't save position in videos under this length 
                           -- (set the same as autoloop_duration to disable this function)
    playfromstart = true -- doesn't 'resume-playback' looping videos
}
(require 'mp.options').read_options(o)

function set_loop()
    local duration = mp.get_property_native("duration")

    -- Checks whether the loop status was changed for the last file
    was_loop = mp.get_property_native("loop-file")

    -- Cancel operation if there is no file duration
    if not duration then
        return
    end

    -- Loops file if was_loop is false, and file meets requirements
    if not was_loop then
        if duration <= o.autoloop_duration then
            print("Autolooped file")
            mp.set_property_native("loop-file", true)
        end
        if duration <= o.autoloop_duration or duration <= o.dontsaveduration then
            mp.set_property_bool("file-local-options/save-position-on-quit", false)
            mp.set_property("file-local-options/watch-later-options", "start") -- so videos don't load paused
            if o.playfromstart and mp.get_property_number("playback-time") > 0 then -- always play video from the start
                mp.commandv('seek', 0, 'absolute-percent', 'exact')
            end
        end
    -- Unloops file if was_loop is true, and file does not meet requirements
    elseif was_loop and duration > o.autoloop_duration then
        mp.set_property_native("loop-file", false)
    end
end

mp.register_event("file-loaded", set_loop)