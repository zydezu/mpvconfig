local options = {
    saveAsTimeStamp = false;
    fileExtension = "jpg"
}
(require 'mp.options').read_options(options)

local currentTime = "0000"
local filename = "default"
local title = "default"
local count = 0

function updateTime()
    currentTime = os.date("%Y-%m-%d_%H-%M-%S")
end

function init()
    filename = mp.get_property("filename")
    title = string.gsub(filename, "%..+$", "")
    setFileDir()
end

function setFileDir()
    updateTime()

    count = 0
    mp.set_property("screenshot-dir", "~~desktop/mpv/screenshots/"..title.."/")
    if options.saveAsTimeStamp then
        mp.set_property("screenshot-template", currentTime)
    end
    mp.set_property("screenshot-format", options.fileExtension)
end

function screenshotdone()
    local tempSubPosition = mp.get_property('sub-pos')
    mp.commandv('set', 'sub-pos', 100)
    mp.commandv("screenshot");
    mp.commandv('set', 'sub-pos', tempSubPosition)
    mp.osd_message("Screenshot taken: " .. mp.command_native({"expand-path", mp.get_property("screenshot-dir")}) .. mp.get_property("screenshot-template"))
    count = count + 1
    if options.saveAsTimeStamp then
        mp.set_property("screenshot-template", currentTime .. "(" .. count .. ")")
    end
end

mp.register_event("start-file", init)
mp.add_periodic_timer(1, setFileDir)
mp.add_key_binding("s", "screenshotdone", screenshotdone);