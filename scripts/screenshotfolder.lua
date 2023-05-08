local utils = require 'mp.utils'
local msg = require 'mp.msg'

local options = {
    saveAsTimeStamp = false;
    fileExtension = "jpg"
}
(require 'mp.options').read_options(options)

local currentTime = "0000"
local filename = "default"
local title = "default"
local duplicate = false

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

    mp.set_property("screenshot-directory", "~~desktop/mpv/"..title.."/")
    if options.saveAsTimeStamp then
        mp.set_property("screenshot-template", currentTime)
    end
    mp.set_property("screenshot-format", options.fileExtension)
end

function screenshotdone(event)
    mp.commandv("screenshot");
    mp.set_property("screenshot-template", currentTime .. "(%#02n)")
end

mp.register_event("start-file", init)
mp.add_periodic_timer(1, setFileDir)
mp.add_key_binding("s", "screenshotdone", screenshotdone);