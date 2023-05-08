local utils = require 'mp.utils'
local msg = require 'mp.msg'
local assdraw = require 'mp.assdraw'

local options = {
    saveAsTimeStamp = false;
    fileExtension = "jpg"
}
(require 'mp.options').read_options(options)

local currentTime = "0000"
local filename = "default"
local title = "default"
local duplicate = false
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
    mp.set_property("screenshot-directory", "~~desktop/mpv/"..title.."/")
    if options.saveAsTimeStamp then
        mp.set_property("screenshot-template", currentTime)
    end
    mp.set_property("screenshot-format", options.fileExtension)
end
function screenshotdone(event)
    mp.commandv("screenshot");
    mp.osd_message("Screenshot taken: " .. mp.command_native({"expand-path", mp.get_property("screenshot-directory")}) .. mp.get_property("screenshot-template"))
    count = count + 1
    if options.saveAsTimeStamp then
        mp.set_property("screenshot-template", currentTime .. "(" .. count .. ")")
    end
end

mp.register_event("start-file", init)
mp.add_periodic_timer(1, setFileDir)
mp.add_key_binding("s", "screenshotdone", screenshotdone);